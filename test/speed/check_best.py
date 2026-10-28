# Check 3: a faster Best that always picks the same candidate.
#
# Best (RemapRender.s) scans candidates from the last to the first and keeps a score only
# if it is strictly lower: the winner is the lowest score, ties going to the highest
# index, or candidate 0 when nothing scores below $7D00. Three changes are tested:
#   A. compaction: candidates with a reserved entry are dropped, and of candidates with
#      the same (AvgR, AvgG, AvgB, Penalty) only the highest index is kept (they always
#      score the same, so a lower one can never win). Scanned high to low, as now.
#   B. table scoring: 3|r-R| + 4|g-G| + 2|b-B| read from three tables of |k| * weight,
#      indexed by r - R + 255 (on the 65816: (dp),y with a pointer set from the target);
#      penalty >> 4 stored with the candidate. Checked for every r, R in 0..255.
#   C. pruning: the compacted candidates sorted by AvgG, searched outwards from the
#      target's G; stop when 4 * |AvgG - G| on both sides is above the best score (no
#      candidate further out can then win or tie). Ties go to the higher index.
# Targets: every 12-bit colour (the first Best of each Lookup), the second Best's target
# that each one leads to, every grey level (v, v, v), and random targets in 0..255.
import os, sys, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from model import (INT, CalcProtos, DefProtos, GreyProtos, Other320, Other640, Other640D, Remap)

W3 = [3 * abs(k - 255) for k in range(511)]
W4 = [4 * abs(k - 255) for k in range(511)]
W2 = [2 * abs(k - 255) for k in range(511)]


def build(pal, pattern):
    n = len(pal)
    cands = []

    def add(idx, byte):
        k = len(idx)
        sr = sum(INT[(pal[i] >> 8) & 15] for i in idx)
        sg = sum(INT[(pal[i] >> 4) & 15] for i in idx)
        sb = sum(INT[pal[i] & 15] for i in idx)
        dis = any(pal[i] & 0x8000 for i in idx)

        def div(s):
            q = s // k
            return 1 if q == 0 and s != 0 else q
        r, g, b = div(sr), div(sg), div(sb)
        sp = 0
        for i in idx:
            sp += 3 * abs(INT[(pal[i] >> 8) & 15] - r) + 4 * abs(INT[(pal[i] >> 4) & 15] - g) \
                + 2 * abs(INT[pal[i] & 15] - b)
        cands.append((r, g, b, -1 if dis else div(sp), byte))

    if pattern and n == 16:
        for i in range(256): add([i >> 4, i & 15], i)
    elif pattern and n == 4:
        for i in range(256): add([i >> 6, (i >> 4) & 3, (i >> 2) & 3, i & 3], i)
    elif pattern and n == 8:
        for i in range(256): add([i >> 6, ((i >> 4) & 3) + 4, (i >> 2) & 3, (i & 3) + 4], i)
    elif n == 8:
        for i in range(16): add([i >> 2, (i & 3) + 4], (i << 4) | i)
    elif n == 4:
        for i in range(4): add([i], i * 0x55)
    else:
        for i in range(n): add([i], (i << 4) | i)
    return cands


def best_ref(c, r, g, b):
    bi, bs = 0, 0x7D00
    for i in range(len(c) - 1, -1, -1):
        ar, ag, ab, pen, _ = c[i]
        if pen < 0: continue
        s = 3 * abs(ar - r) + 4 * abs(ag - g) + 2 * abs(ab - b) + (pen >> 4)
        if s < bs: bs, bi = s, i
    return bi


def compact(c):
    seen = {}
    for i in range(len(c) - 1, -1, -1):          # highest index first: it is kept
        ar, ag, ab, pen, _ = c[i]
        if pen < 0: continue
        key = (ar, ag, ab, pen)
        if key not in seen: seen[key] = i
    keep = sorted(seen.values(), reverse=True)
    return [(i, c[i][0], c[i][1], c[i][2], c[i][3] >> 4) for i in keep]


def best_compact_tables(k, r, g, b):
    """A + B: the compacted list, high index to low, scores from the tables."""
    bi, bs = 0, 0x7D00
    for i, ar, ag, ab, p16 in k:
        s = W3[ar - r + 255] + W4[ag - g + 255] + W2[ab - b + 255] + p16
        if s < bs: bs, bi = s, i
    return bi


def prepare_sorted(k):
    s = sorted(k, key=lambda t: (t[2], -t[0]))
    start = [0] * 257
    j = 0
    for gv in range(257):
        while j < len(s) and s[j][2] < gv: j += 1
        start[gv] = j
    return s, start


def best_pruned(sk, r, g, b, count):
    """C: outward from G in the list sorted by AvgG."""
    s, start = sk
    bi, bs, found = 0, 0x7D00, False
    hi = start[g]
    lo = hi - 1
    n = len(s)
    while True:
        dh = s[hi][2] - g if hi < n else 1 << 30
        dl = g - s[lo][2] if lo >= 0 else 1 << 30
        if dh <= dl:
            if 4 * dh > bs: break
            t = s[hi]
            hi += 1
        else:
            if 4 * dl > bs: break
            t = s[lo]
            lo -= 1
        i, ar, ag, ab, p16 = t
        count[0] += 1
        sc = W3[ar - r + 255] + W4[ag - g + 255] + W2[ab - b + 255] + p16
        if sc < bs or (found and sc == bs and i > bi):
            bs, bi, found = sc, i, True
    return bi


def palettes():
    pals = []
    for m, n in ((0, 16), (1, 4), (2, 8)):
        for p in (DefProtos[m], GreyProtos[m]):
            pals.append(("fixed", [e & 0x0FFF for e in p[:n]]))
        for p in [Other320, Other640, Other640D][m]:
            pals.append(("other", list(p[:n])))
    # calculated palettes of the test pictures and photos (from the model)
    for src, mode in (("RGB", 0), ("RGB", 1), ("RGB", 2), ("BIG", 0), ("HUGE", 0), ("SCR", 1), ("S64", 0),
                      ("photo:Parrot", 0), ("photo:Sunflower", 0), ("photo:Zebra", 0), ("photo:Earth", 0),
                      ("photo:Parrot", 1), ("photo:Parrot", 2)):
        r = Remap(src, mode, 0, 1, 255, 255, 0, screen_before=0)
        r.cur_screen_bytes = None
        r.run()
        pals.append(("calc " + src + " mode %d" % mode, list(r.palout)))
    rnd = random.Random(1)
    for k in range(24):
        n = (16, 4, 8)[k % 3]
        p = [rnd.randrange(4096) for _ in range(n)]
        if k % 4 == 1:                         # some reserved entries
            for j in rnd.sample(range(n), max(1, n // 3)): p[j] |= 0x8000
        if k % 4 == 2:                         # duplicated entries
            for j in range(n // 2): p[n - 1 - j] = p[j]
        if k % 6 == 5:                         # every entry reserved: Best gives 0
            p = [e | 0x8000 for e in p]
        pals.append(("random", p))
    return pals


if __name__ == "__main__":
    # B: the tables against the arithmetic, every candidate value and target value
    bad_t = sum(1 for a in range(256) for t in range(256)
                if W3[a - t + 255] != 3 * abs(a - t) or W4[a - t + 255] != 4 * abs(a - t)
                or W2[a - t + 255] != 2 * abs(a - t))
    print("score tables, all 65536 (candidate, target) pairs per weight: mismatches", bad_t)
    rnd = random.Random(7)
    tot = bad_a = bad_c = 0
    full = exam = 0
    sizes = []
    for kind, pal in palettes():
        for pattern in (True, False):
            c = build(pal, pattern)
            k = compact(c)
            sk = prepare_sorted(k)
            sizes.append((kind, len(pal), pattern, len(c), len(k)))
            targets = []
            for col in range(4096):
                r, g, b = INT[col >> 8], INT[(col >> 4) & 15], INT[col & 15]
                targets.append((r, g, b))
                f = best_ref(c, r, g, b)
                if pattern:
                    ar, ag, ab = c[f][:3]
                    targets.append((min(255, max(0, 2 * r - ar)), min(255, max(0, 2 * g - ag)),
                                    min(255, max(0, 2 * b - ab))))
            targets += [(v, v, v) for v in range(256)]
            targets += [(rnd.randrange(256), rnd.randrange(256), rnd.randrange(256)) for _ in range(3000)]
            for r, g, b in targets:
                want = best_ref(c, r, g, b)
                if best_compact_tables(k, r, g, b) != want: bad_a += 1
                cnt = [0]
                if best_pruned(sk, r, g, b, cnt) != want: bad_c += 1
                exam += cnt[0]
                full += len(c)
                tot += 1
    print(f"targets checked: {tot}; mismatches: compacted+tables {bad_a}, pruned {bad_c}")
    print(f"candidates scored: original {full}, pruned {exam} ({100 * exam / full:.1f} %)")
    agg = {}
    total = {}
    for kind, n, pattern, a, b in sizes:
        key = (kind.split()[0], n, pattern)
        agg.setdefault(key, []).append(b)
        total[key] = a
    print("compacted list sizes (kind, entries, pattern): min/avg/max of the kept candidates")
    for key in sorted(agg):
        v = agg[key]
        print("   ", key, min(v), round(sum(v) / len(v), 1), max(v), " of", total[key])
