# The cost model with the proposed changes, step by step (cumulative). The remap itself
# is the same (same results, same lookups); only the cycles charged change, using the
# cycle counts of the proposed loops (see speed-plan.md for the loops).
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from model import Remap, C, c_mul16, c_div32, c_divavg, c_dist, INT, HZ, RUNS, screen_bytes, is_grey
from images import load
from check_best import compact, prepare_sorted, best_pruned, best_ref

STEPS = ["box", "s2t", "best", "render", "calc", "multi", "direct"]
K = 1.05

N = dict(
    col=40, row=60,                      # spans by stepping (no Mul16/Div32)
    copy_px=170,                         # spans of one: 3 loads, colour and grey from tables, line stores
    copy_rep=25,                         # ... the same source pixel as the column before (enlarging)
    gen_setup=30, gen_srcrow=38, gen_srcpix=71, gen_dispatch=12, gen_compute=110,
    small_base=140, small_px=39,         # boxes up to 2 x 2, unrolled: 140 + 39 per source pixel
    store_px=42, row_store=60,
    hist_inline=26,                      # the histogram counted while the line is made
    hist_px_inplace=36, hist_row=100, hist_skip=40, hist_clear_list=15000,
    cands2=500, cands4=700, cands1=300, cand_sort=60000,
    best_call=100, best_examined=85, lookup_pat=150, lookup_close=50,
    render_col320=47, render_col640=50, render_grey=50, render_row=150, render_miss=60,
    diff_px320=225, diff_px640=240, diff_row=150, diff_row_px=13, diff_level=40,
    quick_px=35, quick_row=150, quick_tables=200000,
    plist=78000, count_nz=15, all_nz=30, argmax_base=50, argmax_nz=24, bias_table=2730,
    bias_nz=150, reduce_base=50, reduce_zero=15, reduce_far=130, reduce_near=330, choose=100,
    s2t_320=62, s2t_640=50, s2t_row=900,
    mindist_entry=125, mindist_col=50, cost_px=35, cost_line=100,
)


def div_cost(n):
    if n == 1: return 0
    if n & (n - 1) == 0: return 4 + 2 * (n.bit_length() - 1)
    if n <= 64: return 15
    return 170


class Opt(Remap):
    def __init__(self, *a, steps=(), **kw):
        super().__init__(*a, **kw)
        self.on = set(steps)

    # ---------------------------------------------------------------- MakePlanes
    def make_planes(self):
        if "box" not in self.on:
            r = super().make_planes()
            if "render" in self.on and self.mode != 3 and not self.quick:
                self.cost.add("MakePlanes: histogram", self.outw * self.outh * N["hist_inline"])
            return r
        cost = self.cost
        W, H = self.outw, self.outh
        self.xs = self.spans(self.srcw, self.spanw, W)
        self.ys = self.spans(self.srch, self.spanh, H)
        cost.add("MakePlanes: spans", W * N["col"] + H * N["row"] + 2 * 2000)
        rgb, stride = self.rgb, self.stride
        self.planesC, self.planesY = [], []
        allone_x = all(b - a == 1 for a, b in self.xs)
        fused = "render" in self.on and self.mode != 3 and not self.quick
        for y in range(H):
            y0, y1 = self.ys[y]
            rn = y1 - y0
            lc, ly = [0] * W, [0] * W
            cyc_box = cyc_div = 0
            prev = None
            for x in range(W):
                x0, x1 = self.xs[x]
                xn = x1 - x0
                sr = sg = sb = 0
                for sy in range(y0, y1):
                    o = sy * stride + 3 * x0
                    for k in range(xn):
                        sr += rgb[o]; sg += rgb[o + 1]; sb += rgb[o + 2]
                        o += 3
                n = xn * rn
                r, g, b = sr // n, sg // n, sb // n
                lc[x] = ((r & 0xF0) << 4) | (g & 0xF0) | (b >> 4)
                ly[x] = (5 * r + 8 * g + 3 * b) >> 4
                if allone_x and rn == 1:
                    cyc_box += N["copy_rep"] if prev == x0 else N["copy_px"]
                    prev = x0
                elif xn <= 2 and rn <= 2:
                    cyc_box += N["small_base"] + n * N["small_px"]
                elif n <= 257:
                    cyc_box += N["gen_setup"] + rn * (N["gen_srcrow"] + xn * N["gen_srcpix"]) \
                        + N["gen_dispatch"] + N["gen_compute"]
                    cyc_div += 3 * div_cost(n)
                else:
                    cyc_box += C["gen_px"] + rn * (C["gen_srcrow"] + C["gen_srcpix"] * xn) + c_mul16(rn)
                    cyc_div += c_divavg(n, r) + c_divavg(n, g) + c_divavg(n, b)
            direct = "direct" in self.on and allone_x and rn == 1 and self.mode != 3 and not self.quick
            if direct:
                # no planes: the histogram pass converts colour only; the render recomputes
                rep = sum(1 for x in range(1, W) if self.xs[x][0] == self.xs[x - 1][0])
                cost.add("MakePlanes: histogram pass", (W - rep) * 75 + rep * 15 + 100)
                self._direct = True
            else:
                cost.add("MakePlanes: box sums", cyc_box)
                cost.add("MakePlanes: division", cyc_div)
                cost.add("MakePlanes: store", N["row_store"] + W * N["store_px"])
                if fused: cost.add("MakePlanes: histogram", W * N["hist_inline"])
            self.planesC.append(lc)
            self.planesY.append(ly)

    # ---------------------------------------------------------------- histogram
    def hist_lines(self, la, lb, owner=None, own=None, stage="HistLines"):
        fused = "render" in self.on and self.mode != 3 and not self.quick and owner is None \
            and stage == "HistLines"
        if fused:                          # counted in MakePlanes; only the clearing remains
            hist = [0] * 4096
            for y in range(la, lb):
                for c in self.planesC[y]:
                    if hist[c] != 0xFFFF: hist[c] += 1
            self.cost.add("HistLines", C["hist_clear"])
            return hist
        if "multi" not in self.on:
            return super().hist_lines(la, lb, owner, own, stage)
        hist = [0] * 4096
        self.cost.add(stage, N["hist_clear_list"])
        for y in range(la, lb):
            if owner is not None and owner[y] != own:
                self.cost.add(stage, N["hist_skip"])
                continue
            self.cost.add(stage, N["hist_row"] + N["hist_px_inplace"] * self.outw)
            for c in self.planesC[y]:
                if hist[c] != 0xFFFF: hist[c] += 1
        return hist

    # ---------------------------------------------------------------- CalcPalette costs
    def argmax(self, hist, stage):
        if "calc" not in self.on: return super().argmax(hist, stage)
        peak, idx = 0, 0
        for c in range(4096):
            if hist[c] > peak: peak, idx = hist[c], c
        self.cost.add(stage, N["argmax_base"] + self._d * N["argmax_nz"])
        return idx, peak

    def reduce(self, hist, colour, stage):
        if "calc" not in self.on: return super().reduce(hist, colour, stage)
        from model import dist
        colour &= 0x0FFF
        cyc = N["reduce_base"]
        for c in self._plist:
            v = hist[c]
            if v == 0:
                cyc += N["reduce_zero"]
                continue
            d = dist(c, colour)
            if d < 50:
                q = v * d // 50
                hist[c] = q if q else 1
                cyc += N["reduce_near"]
                self.stats["reduce_near"] += 1
            else:
                cyc += N["reduce_far"]
                self.stats["reduce_far"] += 1
        self.cost.add(stage, cyc)

    def calc_palette(self, hist_in, stage="CalcPalette"):
        if "calc" not in self.on: return super().calc_palette(hist_in, stage)
        # same steps as the original; the costs of the list-based version
        self._plist = [c for c in range(4096) if hist_in[c]]
        self._d = len(self._plist)
        before = self.cost.c[stage]
        out = self._calc_logic(hist_in, stage)
        return out

    def _calc_logic(self, hist_in, stage):
        from model import dist, brightness
        cost = self.cost
        hist = list(hist_in)
        proto = list(self.proto[:self.protoN])
        count = self.protoN
        D = self._d
        cost.add(stage, C["calc_fixed"] + N["plist"] + D * N["count_nz"])
        if count == 8:
            self.merge(proto, 0, 4)
            self.merge(proto, 3, 7)
        distinct = D
        free = 0
        for e in proto:
            if e & 0x8000: continue
            if e & 0x4000: free += 1
            elif hist[e & 0x0FFF]:
                distinct -= 1
                hist[e & 0x0FFF] = 0
        chosen = []
        if free > 0:
            if free >= distinct:
                cost.add(stage, D * N["all_nz"])
                for c in self._plist:
                    if hist[c] and len(chosen) < 16: chosen.append(c)
            else:
                _, peak = self.argmax(hist, stage)
                cost.add(stage, N["bias_table"])
                for c in self._plist:
                    v = hist[c]
                    if not v: continue
                    q = dist(c, 0x777) * peak // 9
                    hist[c] = 0xFFFF if q > 0xFFFF else min(0xFFFF, v + (peak >> 3) + q)
                    cost.add(stage, N["bias_nz"])
                for e in proto:
                    if e & 0xC000 == 0: self.reduce(hist, e, stage)
                remaining = free
                while remaining > 0 and len(chosen) < 16:
                    remaining -= 1
                    idx, pk = self.argmax(hist, stage)
                    if pk == 0: break
                    self.reduce(hist, idx, stage)
                    hist[idx] = 0
                    chosen.append(idx)
                    cost.add(stage, N["choose"])
            cost.add(stage, C["calc_assign"])
        # the rest as the original
        k = 0
        while k < len(chosen):
            matched = False
            for j in range(count):
                if proto[j] == chosen[k] | 0x4000:
                    proto[j] = chosen[k]
                    chosen[k] = chosen[-1]
                    chosen.pop()
                    matched = True
                    break
            if not matched: k += 1
        out = [0] * count
        for i in range(count):
            e = proto[i]
            if e & 0xC000 == 0x4000:
                e &= 0x0FFF
                if chosen:
                    best, bv = 0, 1000
                    for n, c in enumerate(chosen):
                        v = 0 if c == e else brightness(c)
                        if v < bv: bv, best = v, n
                    e = chosen[best]
                    chosen[best] = chosen[-1]
                    chosen.pop()
            out[i] = e
        if count == 8:
            if out[4] == 0xFFFF: out[4] = out[0]
            if out[7] == 0xFFFF: out[7] = out[3]
        self.stats["distinct"] = max(self.stats["distinct"], D)
        return out

    # ---------------------------------------------------------------- candidates and Best
    def build_cands(self, palout, pattern, stage):
        if "best" not in self.on:
            c = super().build_cands(palout, pattern, stage)
            self._sorted = None
            return c
        before = self.cost.c[stage]
        c = super().build_cands(palout, pattern, stage)
        self.cost.c[stage] = before
        n = len(c)
        per = N["cands2"] if n == 256 and self.protoN == 16 else N["cands4"] if n == 256 else N["cands1"]
        self.cost.add(stage, 1600 + n * per + (N["cand_sort"] if n == 256 else 3000))
        self._sorted = prepare_sorted(compact(c))
        return c

    def best(self, cands, r, g, b, stage):
        if "best" not in self.on or self._sorted is None:
            return super().best(cands, r, g, b, stage)
        cnt = [0]
        bi = best_pruned(self._sorted, r, g, b, cnt)
        self.cost.add(stage, N["best_call"] + cnt[0] * N["best_examined"])
        self.stats["best_calls"] += 1
        self.stats["best_cands"] += cnt[0]
        return bi

    def lookup(self, cands, pattern, r, g, b, stage):
        if "best" not in self.on: return super().lookup(cands, pattern, r, g, b, stage)
        before = self.cost.c[stage]
        v = super().lookup(cands, pattern, r, g, b, stage)
        # replace the fixed part charged by the base class
        self.cost.c[stage] -= C["lookup_pat"] if pattern else C["lookup_close"]
        self.cost.c[stage] += N["lookup_pat"] if pattern else N["lookup_close"]
        return v

    # ---------------------------------------------------------------- rendering
    def render_lines(self, palout, la, lb):
        if "render" not in self.on: return super().render_lines(palout, la, lb)
        cost = self.cost
        grey = all(e & 0x8000 or is_grey(e & 0x0FFF) for e in palout[:self.protoN])
        pattern = (self.alg == 1) if grey else (self.alg != 0)
        cands = self.build_cands(palout, pattern, "BuildCands")
        cost.add("RenderLines", 1300)
        if grey and self.alg == 2:
            return self.diffuse(palout, cands, la, lb)
        W = self.outw
        px = N["render_grey"] if grey else (N["render_col320"] if self.protoN == 16 else N["render_col640"])
        if getattr(self, "_direct", False): px += 55            # colour or grey again, from the source
        cache, gcache = {}, {}
        for y in range(la, lb):
            cost.add("RenderLines", N["render_row"] + W * px)
            if grey:
                for v in self.planesY[y]:
                    if v not in gcache:
                        gcache[v] = self.lookup(cands, pattern, v, v, v, "Best (Lookup)")
                        cost.add("RenderLines", N["render_miss"])
            else:
                for c in self.planesC[y]:
                    if c not in cache:
                        cache[c] = self.lookup(cands, pattern, INT[(c >> 8) & 15], INT[(c >> 4) & 15],
                                               INT[c & 15], "Best (Lookup)")
                        cost.add("RenderLines", N["render_miss"])
        self.stats["lookups"] += len(cache) + len(gcache)

    def diffuse(self, palout, cands, la, lb):
        if "render" not in self.on: return super().diffuse(palout, cands, la, lb)
        cost = self.cost
        for v in range(256):
            self.lookup(cands, False, v, v, v, "Best (Lookup)")
            cost.add("Diffuse", N["diff_level"])
        cost.add("Diffuse", 20000 + 4000)
        W = self.outw
        px = N["diff_px320"] if self.protoN == 16 else N["diff_px640"]
        for y in range(la, lb):
            cost.add("Diffuse", N["diff_row"] + N["diff_row_px"] * W + W * (px + (55 if getattr(self, "_direct", False) else 25)))
        self.stats["lookups"] += 256

    def run_quick(self):
        if "render" not in self.on: return super().run_quick()
        cost = self.cost
        nw, nh = self.natural(0)
        self.mode = 0
        self.outw = min(nw, 320)
        self.outh = min(nh, 200)
        self.srcw, self.spanw, self.srch, self.spanh = self.rw, nw, self.rh, nh
        self.protoN = 16
        self.make_planes()
        cost.add("Quick: render", C["clear_screen"] + N["quick_tables"])
        cost.add("Quick: render", self.outh * (N["quick_row"] + self.outw * N["quick_px"]))

    def s2t(self):
        if "s2t" not in self.on: return super().s2t()
        w, h = self.rw, self.rh
        px = N["s2t_640"] if self.rtall else N["s2t_320"]
        self.cost.add("ScreenToTrue", h * N["s2t_row"] + w * h * px)

    # ---------------------------------------------------------------- multipalette
    def multi(self):
        if "multi" not in self.on: return super().multi()
        cost = self.cost
        H, W = self.outh, self.outw
        count = 8 if self.mptech in (1, 4) else 16
        count = min(count, H)
        passes = 0 if self.mptech >= 3 else (8 if self.mptech == 2 else 2)
        owner = [y * count // H for y in range(H)]
        cost.add("Multi: other", H * 60)
        tables = self.mp_tables(owner, count, None)
        if passes:
            present = set()
            for row in self.planesC: present.update(row)
            plist = sorted(present)
            cost.add("Multi: Present", 78000 + W * H * N["hist_inline"])
            for _ in range(passes):
                mind = []
                for p in range(count):
                    row = {}
                    cyc = 0
                    for c in plist:
                        best = 0xFFFF
                        cyc += N["mindist_col"]
                        for e in tables[p]:
                            if e & 0x8000:
                                cyc += 15
                                continue
                            from model import dist
                            d = dist(c, e & 0x0FFF)
                            cyc += N["mindist_entry"]
                            if d < best: best = d
                        row[c] = best
                    mind.append(row)
                    cost.add("Multi: MinDist", cyc)
                changed = False
                for y in range(H):
                    cost.add("Multi: line costs", N["cost_line"])
                    best_cost, best_p = 0xFFFF, owner[y]
                    for p in range(count):
                        cst = 0
                        n = 0
                        worse = False
                        for c in self.planesC[y]:
                            n += 1
                            cst += mind[p][c]
                            if cst > 0xFFFF or cst >= best_cost:
                                worse = True
                                break
                        cost.add("Multi: line costs", 40 + n * N["cost_px"])
                        if not worse: best_cost, best_p = cst, p
                    if best_p != owner[y]:
                        owner[y] = best_p
                        changed = True
                if not changed: break
                tables = self.mp_tables(owner, count, tables)
        y = 0
        while y < H:
            e = y + 1
            while e < H and owner[e] == owner[y]: e += 1
            cost.add("Multi: other", 800)
            self.render_lines(tables[owner[y]], y, e)
            y = e
        self.owner = owner


def run_case(name, src, mode, pal, alg, h, v, other, steps, screen640, cur_bytes, s2t):
    if mode == "q":
        r = Opt(src, "q", 0, 0, 0, 0, 0, quick=True, with_s2t=s2t, steps=steps)
    else:
        r = Opt(src, mode, pal, alg, h, v, other, screen_before=screen640, with_s2t=s2t, steps=steps)
        r.cur_screen_bytes = cur_bytes
    r.run()
    return r


def suite_steps():
    """Each remap of the suite, after each step (cumulative)."""
    out = {}
    plan = [()] + [tuple(STEPS[:k + 1]) for k in range(len(STEPS))]
    for name, src, mode, pal, alg, h, v, other, secs in RUNS:
        out[name] = [secs]
    # replay the suite once per step set (the current-palette runs need the screens before)
    for steps in plan:
        loaded = None
        have_true = False
        cur_bytes = None
        prev640 = 0
        for name, src, mode, pal, alg, h, v, other, secs in RUNS:
            if src != loaded or pal == 4:
                loaded = src
                w, hh, rgb, tall, scr = load(src)
                have_true = scr is None
                if scr is not None:
                    cur_bytes = scr
                    prev640 = 1 if scr[32000] & 0x80 else 0
                else:
                    r0 = Remap(src, 0, 0, 1, 255, 255, 0, screen_before=0)
                    r0.cur_screen_bytes = None
                    r0.run()
                    cur_bytes = screen_bytes(r0)
                    prev640 = 0
            r = run_case(name, src, mode, pal, alg, h, v, other, steps, prev640, cur_bytes, not have_true)
            have_true = True
            if mode != "q":
                prev640 = 1 if mode in (1, 2) else 0
                cur_bytes = screen_bytes(r)
            else:
                prev640 = 0
            out[name].append(K * r.cost.total() / HZ)
    return out


if __name__ == "__main__":
    res = suite_steps()
    hdr = "run    measured  model " + " ".join(f"{s:>7s}" for s in STEPS)
    print(hdr)
    tot = [0.0] * (len(STEPS) + 2)
    for name, row in res.items():
        print(f"{name}  {row[0]:7.1f} {row[1]:7.1f} " + " ".join(f"{x:7.1f}" for x in row[2:]))
        for i, x in enumerate(row): tot[i] += x
    print(f"total  {tot[0]:7.1f} {tot[1]:7.1f} " + " ".join(f"{x:7.1f}" for x in tot[2:]))
