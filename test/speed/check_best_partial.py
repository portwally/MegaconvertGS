# Check 3b: Best in its own order (last candidate to first, strict "lower"), on the
# compacted list, scoring green + penalty first, then red, then blue, and leaving a
# candidate as soon as the partial score is not below the best (the terms are never
# negative, so its full score could not be lower either). Same targets as check_best.py,
# plus the real lookups of the photos; and the cycles of each Best variant on those.
import os, sys, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from check_best import build, best_ref, compact, prepare_sorted, best_pruned, palettes, W3, W4, W2
from model import INT, Remap

def best_partial(k, r, g, b, stat):
    bi, bs = 0, 0x7D00
    for i, ar, ag, ab, p16 in k:
        s = W4[ag - g + 255] + p16
        if s >= bs: stat[0] += 1; continue
        s += W3[ar - r + 255]
        if s >= bs: stat[1] += 1; continue
        s += W2[ab - b + 255]
        stat[2] += 1
        if s < bs: bs, bi = s, i; stat[3] += 1
    return bi

if __name__ == "__main__":
    rnd = random.Random(7)
    tot = bad = 0
    for kind, pal in palettes():
        for pattern in (True, False):
            c = build(pal, pattern); k = compact(c)
            targets = [(INT[col >> 8], INT[(col >> 4) & 15], INT[col & 15]) for col in range(4096)]
            if pattern:
                for (r, g, b) in list(targets):
                    f = best_ref(c, r, g, b); ar, ag, ab = c[f][:3]
                    targets.append((min(255, max(0, 2*r-ar)), min(255, max(0, 2*g-ag)), min(255, max(0, 2*b-ab))))
            targets += [(v, v, v) for v in range(256)]
            targets += [(rnd.randrange(256), rnd.randrange(256), rnd.randrange(256)) for _ in range(3000)]
            for r, g, b in targets:
                tot += 1
                if best_partial(k, r, g, b, [0, 0, 0, 0]) != best_ref(c, r, g, b): bad += 1
    print(f"partial-score early exit, original order: {tot} targets, mismatches {bad}")
    # cycles per Best call on real workloads (the lookups a remap makes)
    print("cycles per Best call on real lookups (first and second Best of each colour present):")
    print("   case                               original  compact+tables  +early exit  sorted walk")
    for src, mode in (("RGB", 0), ("photo:Parrot", 0), ("photo:Zebra", 0), ("photo:Parrot", 1), ("photo:Parrot", 2)):
        r = Remap(src, mode, 0, 1, 255, 255, 0, screen_before=0); r.cur_screen_bytes = None; r.run()
        c = build(list(r.palout), True); k = compact(c); sk = prepare_sorted(k)
        cols = sorted({x for row in r.planesC for x in row})
        targets = []
        for col in cols:
            t = (INT[col >> 8], INT[(col >> 4) & 15], INT[col & 15]); targets.append(t)
            f = best_ref(c, *t); ar, ag, ab = c[f][:3]; R, G, B = t
            targets.append((min(255, max(0, 2*R-ar)), min(255, max(0, 2*G-ag)), min(255, max(0, 2*B-ab))))
        orig = comp = part = walk = 0
        for t in targets:
            # original: 169 a usable candidate (3 Abs at 17), 16 a reserved one, 41 a call
            orig += 41 + sum(16 if cc[3] < 0 else 169 for cc in c)
            comp += 60 + 60 * len(k)                              # A+B: 60 a candidate
            st = [0, 0, 0, 0]; best_partial(k, *t, st)
            part += 60 + 7 + 27 * st[0] + 47 * st[1] + 66 * st[2] + 15 * st[3] + 7 * len(k)
            cnt = [0]; best_pruned(sk, *t, cnt)
            walk += 100 + 85 * cnt[0]
        n = len(targets)
        print(f"   {src:14s} mode {mode} ({len(k):3d} kept) {orig/n:9.0f} {comp/n:14.0f} {part/n:12.0f} {walk/n:12.0f}")
