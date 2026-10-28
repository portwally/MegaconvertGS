# Check 4: a faster CalcPalette with the same results.
#
#  a. Dist from tables: per colour 3r, 4g, 2b; per target the same; then
#     |a| + |b| + |c| + (|a+b+c| >> 2) from an |x| table and an |x|>>2 table.
#     Checked for all 4096 x 4096 colour pairs.
#  b. The popularity bias d * peak / 9 (today Mul16 + Div32 for every colour) from a
#     table bias[d], d = 0..90 (the largest distance to $777), filled by adding peak
#     and carrying the remainder (one division per palette). Stored as min(q, $FFFF):
#     the colour's count is at least 1, so a quotient above $FFFF saturates either way.
#     Checked for every peak 1..65535 and every d.
#  c. Reduce's count * d / 50 (today Mul16 + Div32 for each near colour) as
#     a*d + T50[b][d] where count = 50a + b, found from count = 256h + l:
#     a = 5h + Q[6h+l], b = R[6h+l] (Q, R: quotient and remainder by 50, 1786 entries),
#     T50: floor(b*d/50) for b, d < 50 (2500 bytes). Checked for every count and d < 50.
#  d. The whole CalcPalette over the list of colours present (in colour order) instead
#     of 4096-entry scans, with a-c, against the original, on the test pictures', the
#     photos', multipalette's per-palette and random histograms, for every prototype.
import os, sys, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from model import (dist, brightness, CalcProtos, DefProtos, GreyProtos, Other320, Other640, Other640D, Remap)

ABS = {x: abs(x) for x in range(-160, 161)}
ABS4 = {x: abs(x) >> 2 for x in range(-160, 161)}
R3 = [3 * ((c >> 8) & 15) for c in range(4096)]
G4 = [4 * ((c >> 4) & 15) for c in range(4096)]
B2 = [2 * (c & 15) for c in range(4096)]


def dist_tab(c, t):
    a = R3[c] - R3[t]
    b = G4[c] - G4[t]
    cc = B2[c] - B2[t]
    return ABS[a] + ABS[b] + ABS[cc] + ABS4[a + b + cc]


Q50 = [x // 50 for x in range(1786)]
R50 = [x % 50 for x in range(1786)]
T50 = [[(b * d) // 50 for d in range(50)] for b in range(50)]


def mul_div50(count, d):
    h, l = count >> 8, count & 255
    x = 6 * h + l
    a = 5 * h + Q50[x]
    b = R50[x]
    return a * d + T50[b][d]


def bias_table(peak):
    """bias[d] = min(d * peak // 9, $FFFF) without dividing per entry."""
    qd, rd = divmod(peak, 9)
    t, q, r = [], 0, 0
    for d in range(91):
        t.append(min(q, 0xFFFF))
        q += qd
        r += rd
        if r >= 9:
            q += 1
            r -= 9
    return t


# ---------------------------------------------------------------- CalcPalette, both ways

def merge(p, a, b):
    fa, fb = p[a] & 0xC000, p[b] & 0xC000
    if fa == 0 and fb == 0x4000: p[b] = p[a]
    elif fa == 0x4000 and fb == 0:
        p[a] = p[b]
        p[b] = 0xFFFF
    elif fa == 0x4000 and fb == 0x4000: p[b] = 0xFFFF


def finish(proto, chosen, count):
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
    return out


def calc_orig(proto_in, hist_in):
    proto, hist = list(proto_in), list(hist_in)
    count = len(proto)
    if count == 8:
        merge(proto, 0, 4)
        merge(proto, 3, 7)
    distinct = sum(1 for v in hist if v)
    free = 0
    for e in proto:
        if e & 0x8000: continue
        if e & 0x4000: free += 1
        elif hist[e & 0x0FFF]:
            distinct -= 1
            hist[e & 0x0FFF] = 0
    chosen = []

    def argmax():
        bi, pk = 0, 0
        for c in range(4096):
            if hist[c] > pk: pk, bi = hist[c], c
        return bi, pk

    def reduce(t):
        t &= 0x0FFF
        for c in range(4096):
            if hist[c]:
                d = dist(c, t)
                if d < 50: hist[c] = max(1, hist[c] * d // 50)

    if free > 0:
        if free >= distinct:
            for c in range(4096):
                if hist[c] and len(chosen) < 16: chosen.append(c)
        else:
            _, peak = argmax()
            for c in range(4096):
                if hist[c]:
                    q = dist(c, 0x777) * peak // 9
                    hist[c] = 0xFFFF if q > 0xFFFF else min(0xFFFF, hist[c] + (peak >> 3) + q)
            for e in proto:
                if e & 0xC000 == 0: reduce(e)
            remaining = free
            while remaining > 0 and len(chosen) < 16:
                remaining -= 1
                bi, pk = argmax()
                if pk == 0: break
                reduce(bi)
                hist[bi] = 0
                chosen.append(bi)
    return finish(proto, chosen, count)


def calc_fast(proto_in, hist_in):
    """Over the list of colours present, with the tables of a-c."""
    proto = list(proto_in)
    count = len(proto)
    if count == 8:
        merge(proto, 0, 4)
        merge(proto, 3, 7)
    plist = [c for c in range(4096) if hist_in[c]]      # built once, in colour order
    cnt = {c: hist_in[c] for c in plist}
    distinct = len(plist)
    free = 0
    for e in proto:
        if e & 0x8000: continue
        if e & 0x4000: free += 1
        elif cnt.get(e & 0x0FFF, 0):
            distinct -= 1
            cnt[e & 0x0FFF] = 0
    chosen = []

    def argmax():
        bi, pk = 0, 0
        for c in plist:
            if cnt[c] > pk: pk, bi = cnt[c], c
        return bi, pk

    def reduce(t):
        t &= 0x0FFF
        for c in plist:
            v = cnt[c]
            if v:
                d = dist_tab(c, t)
                if d < 50:
                    q = mul_div50(v, d)
                    cnt[c] = q if q else 1

    if free > 0:
        if free >= distinct:
            for c in plist:
                if cnt[c] and len(chosen) < 16: chosen.append(c)
        else:
            _, peak = argmax()
            bt = bias_table(peak)
            p8 = peak >> 3
            for c in plist:
                v = cnt[c]
                if v:
                    cnt[c] = min(0xFFFF, v + p8 + bt[dist_tab(c, 0x777)])
            for e in proto:
                if e & 0xC000 == 0: reduce(e)
            remaining = free
            while remaining > 0 and len(chosen) < 16:
                remaining -= 1
                bi, pk = argmax()
                if pk == 0: break
                reduce(bi)
                cnt[bi] = 0
                chosen.append(bi)
    return finish(proto, chosen, count)


def protos():
    out = []
    for m, n in ((0, 16), (1, 4), (2, 8)):
        out.append(CalcProtos[m][:n])
        out.append(DefProtos[m][:n])
        out.append(GreyProtos[m][:n])
        for p in [Other320, Other640, Other640D][m]: out.append(p[:n])
    return out


def histograms():
    hs = []
    for src, mode in (("RGB", 0), ("BIG", 0), ("HUGE", 0), ("SCR", 0), ("S64", 0), ("GRY", 0), ("TNY", 0),
                      ("photo:Parrot", 0), ("photo:Sunflower", 0), ("photo:Zebra", 0), ("photo:Earth", 0),
                      ("photo:Parrot400", 0), ("photo:Parrot", 1)):
        r = Remap(src, mode, 0, 1, 255, 255, 0, screen_before=0)
        r.cur_screen_bytes = None
        r.run()
        hist = [0] * 4096
        for row in r.planesC:
            for c in row:
                if hist[c] != 0xFFFF: hist[c] += 1
        hs.append(("picture " + src, hist))
        if src == "photo:Parrot" and mode == 0:     # multipalette: bands of 12 or 13 lines
            for p in range(16):
                hb = [0] * 4096
                for y in range(200):
                    if y * 16 // 200 == p:
                        for c in r.planesC[y]: hb[c] += 1
                hs.append(("band", hb))
    rnd = random.Random(3)
    for k in range(60):
        hist = [0] * 4096
        n = rnd.choice((3, 10, 17, 40, 200, 900, 2500, 4096))
        big = k % 5 == 0
        for c in rnd.sample(range(4096), n):
            hist[c] = rnd.choice((1, 2, 3, 65535)) if big else rnd.randrange(1, 300 if k % 2 else 65536)
        if k % 7 == 3:                              # ties for the largest count
            for c in rnd.sample(range(4096), 5): hist[c] = max(hist)
        hs.append(("random", hist))
    return hs


if __name__ == "__main__":
    bad = sum(1 for c1 in range(4096) for c2 in range(4096) if dist_tab(c1, c2) != dist(c1, c2))
    mx = max(dist(c, 0x777) for c in range(4096))
    print(f"a. Dist from tables, all 16777216 colour pairs: mismatches {bad}; largest distance to $777: {mx}")
    bad = 0
    for peak in range(1, 65536):
        t = bias_table(peak)
        for d in range(91):
            q = d * peak // 9
            if t[d] != min(q, 0xFFFF): bad += 1
            for v in (1, peak):                         # a colour's count: 1 .. peak
                want = 0xFFFF if q > 0xFFFF else min(0xFFFF, v + (peak >> 3) + q)
                if min(0xFFFF, v + (peak >> 3) + t[d]) != want: bad += 1
    print(f"b. bias table, every peak 1..65535 and d 0..90 (counts 1 and peak): mismatches {bad}")
    bad = sum(1 for count in range(65536) for d in range(50) if mul_div50(count, d) != count * d // 50)
    print(f"c. count*d/50 by tables, every count 0..65535 and d 0..49: mismatches {bad}")
    n = bad = 0
    for kind, h in histograms():
        for p in protos():
            n += 1
            if calc_orig(p, h) != calc_fast(p, h):
                bad += 1
                print("   differs:", kind, [hex(e) for e in p])
    print(f"d. CalcPalette over the colour list with a-c: {n} (histogram, prototype) cases, mismatches {bad}")
