# A model of MegaconvertGS's Remap: the same steps as RemapSeg.s / RemapRender.s
# (and ScreenToTrue in True.s), done in Python, counting 65816 cycles for each
# routine from the instruction timings (native mode, 16-bit A and X/Y, direct page
# page-aligned). It gives where the time goes, per stage.
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from collections import defaultdict
from images import load

INT = [0, 1, 5, 10, 18, 28, 41, 56, 73, 92, 113, 137, 163, 192, 222, 255]
StepN = [1, 1, 1, 1, 1, 1, 1, 1, 2, 1, 3, 2, 3, 4, 1, 5, 4, 3, 5, 2, 5, 3, 4]
StepD = [16, 12, 10, 8, 6, 5, 4, 3, 5, 2, 5, 3, 4, 5, 1, 4, 3, 2, 3, 1, 2, 1, 1]
ModeN = [16, 4, 8, 16]

CalcProtos = [[0x0000, 0x4777, 0x4841, 0x472C, 0x400F, 0x4080, 0x4F70, 0x4D00,
               0x4FA9, 0x4FF0, 0x40E0, 0x44DF, 0x4DAF, 0x478F, 0x4CCC, 0x0FFF],
              [0x0000, 0x4F00, 0x40F0, 0x0FFF] + [0] * 12,
              [0x0000, 0x4F00, 0x40F0, 0x0FFF, 0x0000, 0x400F, 0x4FF0, 0x0FFF] + [0] * 8]
DefProtos = [[0x000, 0x777, 0x841, 0x72C, 0x00F, 0x080, 0xF70, 0xD00,
              0xFA9, 0xFF0, 0x0E0, 0x4DF, 0xDAF, 0x78F, 0xCCC, 0xFFF],
             [0x000, 0xF00, 0x0F0, 0xFFF] + [0] * 12,
             [0x000, 0xF00, 0x0F0, 0xFFF, 0x000, 0x00F, 0xFF0, 0xFFF] + [0] * 8]
GreyProtos = [[0x000, 0x111, 0x222, 0x333, 0x444, 0x555, 0x666, 0x777,
               0x888, 0x999, 0xAAA, 0xBBB, 0xCCC, 0xDDD, 0xEEE, 0xFFF],
              [0x000, 0x777, 0xCCC, 0xFFF] + [0] * 12,
              [0x000, 0x888, 0xDDD, 0xFFF, 0x000, 0x444, 0xBBB, 0xFFF] + [0] * 8]
Other320 = [[0x0000, 0x8777, 0x8841, 0x872C, 0x800F, 0x8080, 0x8F70, 0x8D00,
             0x8FA9, 0x8FF0, 0x80E0, 0x84DF, 0x8DAF, 0x878F, 0x8CCC, 0x0FFF],
            [0x0000, 0x0D03, 0x0852, 0x0F60, 0x0070, 0x0555, 0x00D0, 0x0FF0,
             0x0009, 0x0D0D, 0x0AAA, 0x0F98, 0x022F, 0x06AF, 0x00F9, 0x0FFF],
            [0x0000, 0x8D03, 0x8852, 0x0F60, 0x8070, 0x8555, 0x00D0, 0x8FF0,
             0x8009, 0x0D0D, 0x8AAA, 0x8F98, 0x022F, 0x86AF, 0x80F9, 0x0FFF],
            [0x0000, 0x4777, 0x4841, 0x472C, 0x400F, 0x4080, 0x4F70, 0x4D00,
             0x4FA9, 0x4FF0, 0x40E0, 0x44DF, 0x4DAF, 0x878F, 0x8CCC, 0x0FFF],
            [0x0000, 0x4777, 0x4841, 0x472C, 0x400F, 0x4080, 0x4F70, 0x4D00,
             0x8FA9, 0x8FF0, 0x80E0, 0x84DF, 0x8DAF, 0x878F, 0x8CCC, 0x0FFF],
            [0x0000, 0x000F, 0x00F0, 0x00FF, 0x0F00, 0x0F0F, 0x0FF0, 0x8FFF,
             0x8000, 0x0222, 0x0444, 0x0666, 0x0999, 0x0BBB, 0x0DDD, 0x0FFF]]
Other640 = [[0x0000, 0x8F00, 0x80F0, 0x0FFF] + [0] * 12, [0x0000, 0x00FF, 0x0F0F, 0x0FF0] + [0] * 12,
            [0x0F00, 0x00F0, 0x000F, 0x0FFF] + [0] * 12, [0x0000, 0x8F00, 0x0AAA, 0x0FFF] + [0] * 12]
Other640D = [[0x0000, 0x8F00, 0x80F0, 0x0FFF, 0x0000, 0x800F, 0x8FF0, 0x0FFF] + [0] * 8,
             [0x0000, 0x000F, 0x0FF0, 0x0FFF, 0x0000, 0x0F00, 0x00F0, 0x0FFF] + [0] * 8,
             [0x0000, 0x8F00, 0x0777, 0x0FFF, 0x0000, 0x800F, 0x0CCC, 0x0FFF] + [0] * 8]
OtherSets = [Other320, Other640, Other640D, None]


def popc(v): return bin(v).count("1")


# ---------------------------------------------------------------- cycle costs
# Each function returns the cycles of one call of the routine (including its JSR
# and RTS), from the 65816 timings of the instructions in the listing.

def c_mul16(x):
    """SegLib/True Mul16: 45 + per bit of X (the loop runs over X's bits): 37 for a
    0 bit, 68 for a 1 bit."""
    n = x.bit_length()
    ones = popc(x)
    return 45 + 37 * (n - ones) + 68 * ones


def c_div32(q):
    """SegLib Div32: 32 rounds of 58 cycles (+4 for each 1 bit of the quotient)."""
    return 1895 + 4 * popc(q)


def c_divavg(n, q):
    """DivAvg: 37 for divisor 1; else 7 shifts to scale the divisor, then 8 rounds."""
    if n == 1: return 37
    return 652 + 17 * popc(q)


def c_abs(v): return 15 if v >= 0 else 19      # JSR Abs (positive or negative)


def c_dist(c1, c2):
    """Dist: 231 + four calls of Abs."""
    a = 3 * (((c1 >> 8) & 15) - ((c2 >> 8) & 15))
    b = 4 * (((c1 >> 4) & 15) - ((c2 >> 4) & 15))
    c = 2 * ((c1 & 15) - (c2 & 15))
    d = abs(a) + abs(b) + abs(c) + (abs(a + b + c) >> 2)
    return d, 231 + c_abs(a + b + c) + c_abs(a) + c_abs(b) + c_abs(c)


def dist(c1, c2):
    a = 3 * (((c1 >> 8) & 15) - ((c2 >> 8) & 15))
    b = 4 * (((c1 >> 4) & 15) - ((c2 >> 4) & 15))
    c = 2 * ((c1 & 15) - (c2 & 15))
    return abs(a) + abs(b) + abs(c) + (abs(a + b + c) >> 2)


def brightness(c): return 5 * ((c >> 8) & 15) + 8 * ((c >> 4) & 15) + 3 * (c & 15)


def is_grey(c): return ((c >> 8) & 15) == ((c >> 4) & 15) == (c & 15)


# Fixed costs (cycles), counted from the listings:
C = dict(
    setline=146,             # JSR SetLine: colour word and grey level from CR, CG, CB
    unit_px=63,              # ScaleRow 1:1 loop around SetLine: 3 loads, AND, STA, loop
    gen_px=295,              # ScaleRow general path, per output pixel, without the source
                             # pixels, the Mul16 and the three DivAvg (incl. SetLine)
    gen_srcrow=55,           # ... per source row of the box
    gen_srcpix=91,           # ... per source pixel (3 channels: LDA [q1],y / AND / ADC / STA)
    scalerow=93,             # ScaleRow per line, besides SpanOf and Mul16
    spanof=99,               # SpanOf besides its 2 Mul16 and 2 Div32
    col=69,                  # MakePlanes' column loop besides SpanOf
    store_px=61,             # MakePlanes: copying LineC (words) and LineY (bytes) into the planes
    row_store=88,            # MakePlanes per line, besides PlaneRow's Mul16
    getline_px=59,           # GetLine per pixel (both copies)
    getline=68,              # GetLine per call besides PlaneRow's Mul16
    hist_px=38,              # HistLines per pixel
    hist_row=42,             # HistLines per line taken
    hist_skip=56,            # HistLines per line not taken (multipalette)
    hist_clear=53253,        # HistLines: 4096 words cleared
    scan0=19,                # CalcPalette's 4096-entry scans, per zero entry
    count_nz=26,             # ... counting, per non-zero entry
    argmax_less=26, argmax_eq=24, argmax_gt=40,
    bias_nz=109,             # bias loop per non-zero entry, besides Dist, Mul16, Div32
    reduce_far=43,           # Reduce per non-zero entry with d >= 50, besides Dist
    reduce_near=97,          # Reduce per non-zero entry with d < 50, besides Dist, Mul16, Div32
    calc_fixed=2000,         # CalcPalette's copies, slot scans
    calc_assign=20000,       # matching and darkest-first filling (calculated slots)
    cand2=904, cand4=1481, cand1=603,   # BuildCands per candidate (2, 4 or 1 entries)
    best_call=41,            # Best besides its candidates
    best_cand=118,           # Best per usable candidate besides its 3 Abs
    best_improve=13,         # ... when it becomes the best so far
    best_reserved=16,        # ... a candidate with a reserved entry
    lookup_pat=227,          # Lookup (pattern) besides its 2 Best
    lookup_close=54,         # Lookup (closest) besides Best
    miss_col=227,            # RenderLines colour cache miss (bit cache, SetTarget...) besides Lookup
    hit_col=84,              # RenderLines colour pixel, cache hit, up to the byte
    grey_px=55,              # RenderLines grey pixel, cache hit
    miss_grey=23,            # grey miss besides Lookup
    bytes_px=18,             # choosing the even/odd line byte
    put320=74, put640=81,    # JSR PutPixel
    loop_px=19,              # RenderLines pixel loop
    row_render=3286,         # RenderLines per line: ClearRowOut, StoreRow (besides GetLine)
    cache_clear=4869,
    diff_px320=430, diff_px640=484, diff_px640d=498,   # Diffuse per pixel
    diff_row=3286 + 18060 + 30,   # Diffuse per line: ClearRowOut, StoreRow, the swap of 645 words
    diff_level=74,           # Diffuse: each of the 256 grey levels, besides Lookup
    quick_px=224,            # Quick remap per pixel (+9 per channel at or above the threshold)
    clear_screen=229400,     # ClearScreen
    remap_fixed=60000,       # Normalise, GetProto, Sizes, PutTable, NewHandle/DisposeHandle...
    s2t_320=296, s2t_640=359,  # ScreenToTrue per pixel
    s2t_row=120,
    fill_byte=15,            # NewTrue's FillBig, per byte
    mindist_entry=52,        # MinDist per palette entry besides Dist
    mindist_col=50,
    cost_px=50,              # Multi: a line's cost, per pixel tried
    cost_line=150,
)


class Cost:
    def __init__(self):
        self.c = defaultdict(float)

    def add(self, stage, cycles):
        self.c[stage] += cycles

    def total(self):
        return sum(self.c.values())


# ---------------------------------------------------------------- the remap

class Remap:
    def __init__(self, tag, mode, pal, alg, hs, vs, other, screen_before=None, quick=False,
                 with_s2t=False):
        self.tag = tag
        w, h, rgb, tall, scr = load(tag)
        self.rw, self.rh, self.rgb, self.rtall = w, h, rgb, tall
        self.stride = 3 * w
        self.scr = scr
        self.screen640 = screen_before          # the screen picture's first line in 640 mode?
        self.cost = Cost()
        self.mode, self.pal, self.alg = mode, pal, alg
        self.other = [0, 0, 0, 0]
        if mode != "q":
            self.other[mode] = other
        self.hs, self.vs = hs, vs
        self.quick = quick
        self.with_s2t = with_s2t
        self.stats = defaultdict(int)

    # -- options
    def natural(self, mode):
        nh = self.rh
        if mode in (1, 2):
            nw = self.rw if self.rtall else self.rw * 2
        else:
            nw = self.rw
            if self.rtall:
                nw = self.rw >> 1
                if nw == 0: nw = 1
        return nw, nh

    def screenw(self): return 640 if self.mode in (1, 2) else 320

    def scale(self, a, s): return a * StepN[s] // StepD[s]

    def fit(self):
        nw, nh = self.natural(self.mode)
        s = 14
        while True:
            w = self.scale(nw, s)
            if not self.screenw() < w:
                if self.scale(nh, s) < 201: break
            if s == 0: break
            s -= 1
        self.hs = self.vs = s

    def get_proto(self):
        self.mptech = 0
        m = self.mode
        if m == 3:
            if self.pal == 3:
                t = self.other[3]
                self.mptech = (t if t < 4 else 3) + 1
            proto = CalcProtos[0]
        elif self.pal == 4:
            proto = self.cur_proto()
        elif self.pal == 3:
            lst = OtherSets[m]
            k = min(self.other[m], len(lst) - 1)
            proto = lst[k]
        else:
            proto = [CalcProtos, DefProtos, GreyProtos][self.pal][m]
        self.protoN = ModeN[m]
        self.proto = list(proto[:16]) + [0] * (16 - len(proto[:16]))

    def cur_proto(self):
        d = self.cur_screen
        off = 32256 if self.mode == 0 else 32256 + 16
        import struct
        return [v & 0x0FFF for v in struct.unpack("<16H", d[off:off + 32])]

    def pal_ok(self, p):
        m = self.mode
        if p == 5: return False
        if p in (1, 2): return m != 3
        if p == 4:
            if m == 3: return False
            return (1 if m in (1, 2) else 0) == self.screen640
        return True

    def diffusion_ok(self):
        if self.mode == 3: return False
        self.get_proto()
        for e in self.proto[:self.protoN]:
            if e & 0x8000: continue
            if e & 0x4000: return False
            if not is_grey(e): return False
        return True

    def normalise(self):
        if not self.pal_ok(self.pal): self.pal = 0
        if self.alg == 2 and not self.diffusion_ok(): self.alg = 1

    # -- sizes
    def sizes(self):
        nw, nh = self.natural(self.mode)
        ww = self.scale(nw, self.hs) or 1
        wh = self.scale(nh, self.vs) or 1
        self.outw = min(self.screenw(), ww)
        self.outh = min(200, wh)
        cw = self.rw * self.outw // ww or 1
        ch = self.rh * self.outh // wh or 1
        self.srcw, self.spanw, self.srch, self.spanh = cw, self.outw, ch, self.outh

    @staticmethod
    def spans(src, out, n):
        r = []
        for i in range(n):
            a = i * src // out
            b = (i + 1) * src // out
            if b == a: b += 1
            if b > src: b = src
            r.append((a, b))
        return r

    def cost_spanof(self, src, out, i):
        a = i * src // out
        b = (i + 1) * src // out
        return C["spanof"] + 2 * c_mul16(src) + c_div32(a) + c_div32(b)

    # -- 1. planes
    def make_planes(self):
        cost = self.cost
        W, H = self.outw, self.outh
        self.xs = self.spans(self.srcw, self.spanw, W)
        self.ys = self.spans(self.srch, self.spanh, H)
        for i in range(W):
            cost.add("MakePlanes: spans", C["col"] + self.cost_spanof(self.srcw, self.spanw, i))
        unit = self.spanw == self.srcw and self.spanh == self.srch
        self.unit = unit
        plrow = 3 * W
        rgb, stride = self.rgb, self.stride
        self.planesC, self.planesY = [], []
        for y in range(H):
            y0, y1 = self.ys[y]
            cost.add("MakePlanes: spans", C["scalerow"] + self.cost_spanof(self.srch, self.spanh, y)
                     + c_mul16(stride))
            lc, ly = [0] * W, [0] * W
            if unit:
                base = y0 * stride
                for x in range(W):
                    o = base + 3 * x
                    r, g, b = rgb[o], rgb[o + 1], rgb[o + 2]
                    lc[x] = ((r & 0xF0) << 4) | (g & 0xF0) | (b >> 4)
                    ly[x] = (5 * r + 8 * g + 3 * b) >> 4
                cost.add("MakePlanes: ScaleRow 1:1", W * (C["unit_px"] + C["setline"]))
                self.stats["px_unit"] += W
            else:
                rn = y1 - y0
                cyc = 0
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
                    base_c = C["gen_px"] + rn * (C["gen_srcrow"] + C["gen_srcpix"] * xn) + c_mul16(rn)
                    div_c = c_divavg(n, r) + c_divavg(n, g) + c_divavg(n, b)
                    cost.add("MakePlanes: box sums", base_c)
                    cost.add("MakePlanes: DivAvg", div_c)
                    self.stats["div_n%d" % n] += 1
                    self.stats["srcpix"] += n
                self.stats["px_gen"] += W
            cost.add("MakePlanes: store", C["row_store"] + c_mul16(plrow) + W * C["store_px"])
            self.planesC.append(lc)
            self.planesY.append(ly)

    def getline_cost(self):
        return C["getline"] + c_mul16(3 * self.outw) + C["getline_px"] * self.outw

    # -- 2. histogram and palette
    def hist_lines(self, la, lb, owner=None, own=None, stage="HistLines"):
        cost = self.cost
        hist = [0] * 4096
        cost.add(stage, C["hist_clear"] + 19)
        for y in range(la, lb):
            if owner is not None and owner[y] != own:
                cost.add(stage, C["hist_skip"])
                continue
            cost.add(stage, C["hist_row"] + self.getline_cost() + C["hist_px"] * self.outw)
            for c in self.planesC[y]:
                if hist[c] != 0xFFFF: hist[c] += 1
        return hist

    def scan_cost(self, hist):
        nz = sum(1 for v in hist if v)
        return nz, (4096 - nz) * C["scan0"]

    def argmax(self, hist, stage):
        peak, idx = 0, 0
        cyc = 25
        for c in range(4096):
            v = hist[c]
            if v > peak:
                peak, idx = v, c
                cyc += C["argmax_gt"]
            elif v == peak:
                cyc += C["argmax_eq"]
            else:
                cyc += C["argmax_less"]
        self.cost.add(stage, cyc)
        return idx, peak

    def reduce(self, hist, colour, stage):
        colour &= 0x0FFF
        cyc = 20
        for c in range(4096):
            v = hist[c]
            if v == 0:
                cyc += C["scan0"]
                continue
            d, dc = c_dist(c, colour)
            cyc += dc
            if d < 50:
                p = v * d
                q = p // 50
                cyc += C["reduce_near"] + c_mul16(d) + c_div32(q)
                hist[c] = q if q else 1
                self.stats["reduce_near"] += 1
            else:
                cyc += C["reduce_far"]
                self.stats["reduce_far"] += 1
        self.cost.add(stage, cyc)

    def calc_palette(self, hist_in, stage="CalcPalette"):
        cost = self.cost
        hist = list(hist_in)
        proto = list(self.proto[:self.protoN])
        count = self.protoN
        cost.add(stage, C["calc_fixed"])
        if count == 8:
            self.merge(proto, 0, 4)
            self.merge(proto, 3, 7)
        nz = sum(1 for v in hist if v)
        distinct = nz
        cost.add(stage, (4096 - nz) * C["scan0"] + nz * C["count_nz"])
        free = 0
        for e in proto:
            if e & 0x8000: continue
            if e & 0x4000:
                free += 1
            elif hist[e & 0x0FFF]:
                distinct -= 1
                hist[e & 0x0FFF] = 0
        chosen = []
        if free > 0:
            if free >= distinct:
                cost.add(stage, 4096 * C["scan0"] + nz * 31)
                for c in range(4096):
                    if hist[c] and len(chosen) < 16: chosen.append(c)
            else:
                _, peak = self.argmax(hist, stage)
                p8 = peak >> 3
                cyc = 0
                for c in range(4096):
                    v = hist[c]
                    if not v:
                        cyc += C["scan0"]
                        continue
                    d, dc = c_dist(c, 0x777)
                    q = d * peak // 9
                    cyc += C["bias_nz"] + dc + c_mul16(peak) + c_div32(q)
                    if q > 0xFFFF:
                        hist[c] = 0xFFFF
                    else:
                        hist[c] = min(0xFFFF, v + p8 + q)
                    self.stats["bias_nz"] += 1
                cost.add(stage, cyc)
                for e in proto:
                    if e & 0xC000 == 0:
                        self.reduce(hist, e, stage)
                        self.stats["reduce_calls"] += 1
                remaining = free
                while remaining > 0 and len(chosen) < 16:
                    remaining -= 1
                    idx, pk = self.argmax(hist, stage)
                    if pk == 0: break
                    self.reduce(hist, idx, stage)
                    self.stats["reduce_calls"] += 1
                    hist[idx] = 0
                    chosen.append(idx)
                    cost.add(stage, 100)
            cost.add(stage, C["calc_assign"])
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
        self.stats["distinct"] = max(self.stats["distinct"], nz)
        return out

    @staticmethod
    def merge(p, a, b):
        fa, fb = p[a] & 0xC000, p[b] & 0xC000
        if fa == 0 and fb == 0x4000:
            p[b] = p[a]
        elif fa == 0x4000 and fb == 0:
            p[a] = p[b]
            p[b] = 0xFFFF
        elif fa == 0x4000 and fb == 0x4000:
            p[b] = 0xFFFF

    # -- 3. candidates
    def build_cands(self, palout, pattern, stage):
        n = self.protoN
        cands = []

        def add(idx, byte):
            k = len(idx)
            sr = sum(INT[(palout[i] >> 8) & 15] for i in idx)
            sg = sum(INT[(palout[i] >> 4) & 15] for i in idx)
            sb = sum(INT[palout[i] & 15] for i in idx)
            dis = any(palout[i] & 0x8000 for i in idx)

            def div(s):
                q = s // k
                return 1 if q == 0 and s != 0 else q
            r, g, b = div(sr), div(sg), div(sb)
            sp = 0
            for i in idx:
                sp += 3 * abs(INT[(palout[i] >> 8) & 15] - r)
                sp += 4 * abs(INT[(palout[i] >> 4) & 15] - g)
                sp += 2 * abs(INT[palout[i] & 15] - b)
            cands.append((r, g, b, -1 if dis else div(sp), byte))

        if pattern and n == 16:
            for i in range(256): add([i >> 4, i & 15], i)
            per = C["cand2"]
        elif pattern and n == 4:
            for i in range(256): add([i >> 6, (i >> 4) & 3, (i >> 2) & 3, i & 3], i)
            per = C["cand4"]
        elif pattern and n == 8:
            for i in range(256): add([i >> 6, ((i >> 4) & 3) + 4, (i >> 2) & 3, (i & 3) + 4], i)
            per = C["cand4"]
        elif n == 8:
            for i in range(16): add([i >> 2, (i & 3) + 4], (i << 4) | i)
            per = C["cand2"]
        elif n == 4:
            for i in range(4): add([i], i * 0x55)
            per = C["cand1"] + 400
        else:
            for i in range(n): add([i], (i << 4) | i)
            per = C["cand1"]
        self.cost.add(stage, 1600 + len(cands) * per)
        return cands

    def best(self, cands, r, g, b, stage):
        bi, bs = 0, 0x7D00
        cyc = C["best_call"]
        for i in range(len(cands) - 1, -1, -1):
            ar, ag, ab, pen, _ = cands[i]
            if pen < 0:
                cyc += C["best_reserved"]
                continue
            dr, dg, db = ar - r, ag - g, ab - b
            s = 3 * abs(dr) + 4 * abs(dg) + 2 * abs(db) + (pen >> 4)
            cyc += C["best_cand"] + c_abs(dr) + c_abs(dg) + c_abs(db)
            if s < bs:
                bs, bi = s, i
                cyc += C["best_improve"]
        self.cost.add(stage, cyc)
        self.stats["best_calls"] += 1
        self.stats["best_cands"] += len(cands)
        return bi

    def lookup(self, cands, pattern, r, g, b, stage):
        first = self.best(cands, r, g, b, stage)
        if not pattern:
            self.cost.add(stage, C["lookup_close"])
            by = cands[first][4]
            return by << 8 | by
        self.cost.add(stage, C["lookup_pat"])
        ar, ag, ab = cands[first][:3]
        r2 = min(255, max(0, 2 * r - ar))
        g2 = min(255, max(0, 2 * g - ag))
        b2 = min(255, max(0, 2 * b - ab))
        second = self.best(cands, r2, g2, b2, stage)

        def sw(v): return ((v << 4) | (v >> 4)) & 0xFF
        if second > first: return second << 8 | sw(first)
        return first << 8 | sw(second)

    # -- 4. rendering
    def render_lines(self, palout, la, lb):
        cost = self.cost
        grey = all(e & 0x8000 or is_grey(e & 0x0FFF) for e in palout[:self.protoN])
        if grey:
            pattern = self.alg == 1
        else:
            pattern = self.alg != 0
        cands = self.build_cands(palout, pattern, "BuildCands")
        cost.add("RenderLines", C["cache_clear"] + 1300)
        if grey and self.alg == 2:
            return self.diffuse(palout, cands, la, lb)
        W = self.outw
        put = C["put320"] if self.protoN == 16 else C["put640"]
        cache = {}
        gcache = {}
        for y in range(la, lb):
            cost.add("RenderLines", C["row_render"] + self.getline_cost())
            if grey:
                for v in self.planesY[y]:
                    if v not in gcache:
                        gcache[v] = self.lookup(cands, pattern, v, v, v, "Best (Lookup)")
                        cost.add("RenderLines", C["miss_grey"])
                cost.add("RenderLines", W * (C["grey_px"] + C["bytes_px"] + put + C["loop_px"]))
            else:
                for c in self.planesC[y]:
                    if c not in cache:
                        cache[c] = self.lookup(cands, pattern, INT[(c >> 8) & 15], INT[(c >> 4) & 15],
                                               INT[c & 15], "Best (Lookup)")
                        cost.add("RenderLines", C["miss_col"] - C["hit_col"])
                cost.add("RenderLines", W * (C["hit_col"] + C["bytes_px"] + put + C["loop_px"]))
        self.stats["lookups"] += len(cache) + len(gcache)

    def diffuse(self, palout, cands, la, lb):
        cost = self.cost
        for v in range(256):
            self.lookup(cands, False, v, v, v, "Best (Lookup)")
            cost.add("Diffuse", C["diff_level"])
        cost.add("Diffuse", 14200)
        W = self.outw
        px = {16: C["diff_px320"], 4: C["diff_px640"], 8: C["diff_px640d"]}[self.protoN]
        for y in range(la, lb):
            cost.add("Diffuse", C["diff_row"] + self.getline_cost() + W * px)
        self.stats["lookups"] += 256

    # -- multipalette
    def multi(self):
        cost = self.cost
        H, W = self.outh, self.outw
        count = 8 if self.mptech in (1, 4) else 16
        count = min(count, H)
        passes = 0 if self.mptech >= 3 else (8 if self.mptech == 2 else 2)
        owner = [y * count // H for y in range(H)]
        cost.add("Multi: other", H * (c_mul16(count) + c_div32(0) + 40))
        tables = self.mp_tables(owner, count, None)
        if passes:
            present_hist = self.hist_lines(0, H, stage="Multi: Present")
            plist = [c for c in range(4096) if present_hist[c]]
            cost.add("Multi: Present", 4096 * 19 + len(plist) * 30)
            for _ in range(passes):
                # MinDist: each palette's distance to each present colour
                mind = []
                for p in range(count):
                    row = {}
                    cyc = 0
                    for c in plist:
                        best = 0xFFFF
                        cyc += C["mindist_col"]
                        for e in tables[p]:
                            if e & 0x8000:
                                cyc += 20
                                continue
                            d, dc = c_dist(c, e & 0x0FFF)
                            cyc += C["mindist_entry"] + dc
                            if d < best: best = d
                        row[c] = best
                    mind.append(row)
                    cost.add("Multi: MinDist", cyc)
                changed = False
                for y in range(H):
                    cost.add("Multi: line costs", self.getline_cost() + C["cost_line"])
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
                        cost.add("Multi: line costs", 60 + n * C["cost_px"])
                        if not worse:
                            best_cost, best_p = cst, p
                    if best_p != owner[y]:
                        owner[y] = best_p
                        changed = True
                if not changed: break
                tables = self.mp_tables(owner, count, tables)
        # render each run of lines
        y = 0
        while y < H:
            e = y + 1
            while e < H and owner[e] == owner[y]: e += 1
            cost.add("Multi: other", 1500)
            self.render_lines(tables[owner[y]], y, e)
            y = e
        self.owner = owner

    def mp_tables(self, owner, count, prev):
        out = []
        for p in range(count):
            self.cost.add("Multi: tables", 5000)
            if p in owner:
                hist = self.hist_lines(0, self.outh, owner, p, stage="Multi: tables")
            else:
                if prev is not None:
                    out.append(prev[p])
                    continue
                hist = [0] * 4096
                self.cost.add("Multi: tables", C["hist_clear"])
            out.append(self.calc_palette(hist, stage="Multi: CalcPalette"))
        return out

    # -- quick remap
    def run_quick(self):
        cost = self.cost
        nw, nh = self.natural(0)
        self.mode = 0
        self.outw = min(nw, 320)
        self.outh = min(nh, 200)
        self.srcw, self.spanw, self.srch, self.spanh = self.rw, nw, self.rh, nh
        self.protoN = 16
        self.make_planes()
        cost.add("Quick: render", C["clear_screen"])
        th = [5, 12, 14, 9]
        for y in range(self.outh):
            cost.add("Quick: render", C["row_render"] + self.getline_cost())
            for x, c in enumerate(self.planesC[y]):
                t = th[(y & 1) * 2 + (x & 1)]
                bits = sum(1 for v in ((c >> 8) & 15, (c >> 4) & 15, c & 15) if v >= t)
                cost.add("Quick: render", C["quick_px"] + 9 * bits)

    def s2t(self):
        """ScreenToTrue (with NewTrue's fill), when the remap starts from a screen."""
        w, h = self.rw, self.rh
        px = C["s2t_640"] if self.rtall else C["s2t_320"]
        self.cost.add("ScreenToTrue", h * (C["s2t_row"] + c_mul16(3 * w)) + w * h * px)
        self.cost.add("ScreenToTrue: fill", 3 * w * h * C["fill_byte"])

    def run(self):
        if self.with_s2t: self.s2t()
        if self.quick:
            self.run_quick()
            return self
        self.cur_screen = self.cur_screen_bytes
        if self.hs == 255:
            self.fit()
        self.normalise()
        self.get_proto()
        self.sizes()
        self.cost.add("Other", C["remap_fixed"] + C["clear_screen"])
        self.make_planes()
        if self.mode == 3:
            self.multi()
        else:
            hist = self.hist_lines(0, self.outh)
            palout = self.calc_palette(hist)
            self.palout = palout
            self.render_lines(palout, 0, self.outh)
        return self


# The remap2 suite (test/remap2_list.py) with the measured times (build/suite_remap2.txt).
RUNS = [("R01", "RGB", 0, 0, 1, 255, 255, 0, 18.6), ("R02", "RGB", 0, 0, 0, 255, 255, 0, 17.5),
        ("R03", "RGB", 0, 1, 1, 255, 255, 0, 17.2), ("R04", "RGB", 0, 2, 2, 255, 255, 0, 23.3),
        ("R05", "RGB", 0, 2, 1, 255, 255, 0, 19.1), ("R06", "RGB", 0, 3, 1, 255, 255, 1, 17.2),
        ("R07", "RGB", 0, 3, 2, 255, 255, 0, 23.1), ("R08", "RGB", 0, 3, 1, 255, 255, 3, 18.2),
        ("R09", "RGB", 1, 0, 1, 255, 255, 0, 54.4), ("R10", "RGB", 1, 0, 0, 255, 255, 0, 53.3),
        ("R11", "RGB", 1, 2, 2, 255, 255, 0, 67.7), ("R12", "RGB", 1, 3, 1, 255, 255, 1, 54.1),
        ("R13", "RGB", 2, 0, 1, 255, 255, 0, 54.7), ("R14", "RGB", 2, 0, 0, 255, 255, 0, 53.6),
        ("R15", "RGB", 2, 1, 1, 255, 255, 0, 54.1), ("R16", "RGB", 2, 3, 2, 255, 255, 2, 68.7),
        ("R17", "RGB", 3, 0, 1, 255, 255, 0, 46.5), ("R18", "RGB", 3, 3, 1, 255, 255, 2, 20.9),
        ("R19", "RGB", 3, 3, 1, 255, 255, 0, 37.4), ("R20", "BIG", 0, 0, 1, 19, 9, 0, 61.9),
        ("R21", "BIG", 0, 0, 1, 9, 14, 0, 50.9), ("R22", "SCR", 1, 0, 1, 255, 255, 0, 61.9),
        ("R23", "S64", 0, 0, 1, 255, 255, 0, 95.5), ("R24", "S64", 2, 0, 1, 255, 255, 0, 31.9),
        ("R25", "GRY", 0, 0, 2, 255, 255, 0, 4.6), ("R26", "GRY", 1, 2, 2, 255, 255, 0, 16.5),
        ("R27", "TNY", 0, 1, 0, 14, 14, 0, 4.2), ("R28", "RGB", 0, 4, 1, 255, 255, 0, 17.2),
        ("R29", "SCR", 0, 4, 0, 255, 255, 0, 24.1), ("R30", "S64", 1, 4, 1, 255, 255, 0, 50.8),
        ("R31", "S64", 2, 4, 1, 255, 255, 0, 50.8), ("R32", "S64", 0, 4, 1, 255, 255, 0, 95.5),
        ("R33", "GRY", 0, 4, 2, 255, 255, 0, 4.5),
        ("Q01", "RGB", "q", 0, 0, 0, 0, 0, 14.5), ("Q02", "BIG", "q", 0, 0, 0, 0, 0, 14.5),
        ("Q03", "S64", "q", 0, 0, 0, 0, 0, 93.4)]


def suite(verbose=True):
    """Replays the suite in order: a screen source is turned into a true colour picture
    on its first remap after loading (SourceTrue); the screen picture before each remap
    is the previous result (for the 'current' palette)."""
    import struct
    loaded = None
    have_true = False
    screen = None        # bytes of the current screen picture (C1 layout), approximated
    results = []
    prev_mode_640 = 0
    cur_bytes = None
    for name, src, mode, pal, alg, h, v, other, secs in RUNS:
        reload = src != loaded or pal == 4
        if reload:
            loaded = src
            w, hh, rgb, tall, scr = load(src)
            have_true = scr is None
            if scr is not None:
                cur_bytes = scr
                prev_mode_640 = 1 if scr[32000] & 0x80 else 0
            else:
                # a true colour picture is remapped when it is loaded: 320 mode, calculated
                r0 = Remap(src, 0, 0, 1, 255, 255, 0, screen_before=0)
                r0.cur_screen_bytes = None
                r0.run()
                cur_bytes = screen_bytes(r0)
                prev_mode_640 = 0
        s2t = not have_true
        if mode == "q":
            r = Remap(src, "q", 0, 0, 0, 0, 0, quick=True, with_s2t=s2t)
            r.run()
            prev_mode_640 = 0
        else:
            r = Remap(src, mode, pal, alg, h, v, other, screen_before=prev_mode_640, with_s2t=s2t)
            r.cur_screen_bytes = cur_bytes
            r.run()
            prev_mode_640 = 1 if mode in (1, 2) else 0
            cur_bytes = screen_bytes(r)
        have_true = True
        results.append((name, src, mode, pal, alg, secs, r))
    return results


def screen_bytes(r):
    """Enough of the result's C1 bytes for the 'current palette' of the next remap."""
    import struct
    pal = getattr(r, "palout", None)
    b = bytearray(32768)
    if pal is None:
        return bytes(b)
    n = len(pal)
    entries = [(pal[i % n]) & 0x0FFF for i in range(16)]
    b[32256:32288] = struct.pack("<16H", *entries)
    if r.mode in (1, 2):
        for y in range(200): b[32000 + y] = 0x80
    return bytes(b)


HZ = 2863636   # 14.31818 MHz / 5


if __name__ == "__main__":
    res = suite()
    tot_pred = tot_meas = 0
    for name, src, mode, pal, alg, secs, r in res:
        cyc = r.cost.total()
        pred = cyc / HZ
        tot_pred += pred
        tot_meas += secs
        st = r.stats
        print(f"{name} {src:4s} m={mode} p={pal} a={alg} out={r.outw}x{r.outh} measured {secs:5.1f}s "
              f"model {pred:5.1f}s ratio {secs / pred:4.2f}  lookups {st['lookups']} distinct {st['distinct']}")
    print(f"total measured {tot_meas:.1f}s model {tot_pred:.1f}s ratio {tot_meas / tot_pred:.3f}")
