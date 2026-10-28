# Check 6: multipalette's choice of palette for a line, trying the line's own palette
# first. Original (RemapRender.s Multi :line/:try/:px): palettes 0..count-1, BestCost =
# $FFFF, a palette is dropped once its running cost overflows 16 bits or is >= BestCost,
# kept if it ends below; result: the first palette with the lowest cost, or the line's
# owner if none ends below $FFFF. Variant: the owner first (same rules), then the others,
# dropped once the cost overflows or is > BestCost, kept if lower, or equal with a lower
# palette number (only once some palette has been kept). Compared on every line of
# every pass of the multipalette remaps of the test picture and the photos, and on
# random cost tables; also counts the pixels summed.
import os, sys, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from model import Remap, dist

def choose_orig(line, mind, owner, count, n):
    best_cost, best_p = 0xFFFF, owner
    for p in range(count):
        c = 0; ok = True
        for x in line:
            n[0] += 1; c += mind[p][x]
            if c > 0xFFFF or c >= best_cost: ok = False; break
        if ok: best_cost, best_p = c, p
    return best_p

def choose_owner_first(line, mind, owner, count, n):
    best_cost, best_p, found = 0xFFFF, owner, False
    order = [owner] + [p for p in range(count) if p != owner]
    for p in order:
        c = 0; ok = True
        for x in line:
            n[0] += 1; c += mind[p][x]
            if c > 0xFFFF or c > best_cost: ok = False; break
        if not ok: continue
        if c < best_cost or (found and c == best_cost and p < best_p):
            best_cost, best_p, found = c, p, True
    return best_p

def cases():
    for src, tech in (("RGB", 0), ("RGB", 1), ("RGB", 2), ("photo:Parrot", 0), ("photo:Zebra", 0), ("photo:Parrot", 2)):
        r = Remap(src, 3, 3 if tech else 0, 1, 255, 255, tech - 1 if tech else 0, screen_before=0)
        r.cur_screen_bytes = None
        # run up to the passes with the model, then replay the passes here
        r.fit(); r.normalise(); r.get_proto(); r.sizes(); r.make_planes()
        H = r.outh; count = 8 if r.mptech in (1, 4) else 16; count = min(count, H)
        passes = 0 if r.mptech >= 3 else (8 if r.mptech == 2 else 2)
        owner = [y * count // H for y in range(H)]
        tables = r.mp_tables(owner, count, None)
        present = sorted({c for row in r.planesC for c in row})
        for _ in range(passes):
            mind = [{c: min([dist(c, e & 0xFFF) for e in tables[p] if not e & 0x8000] or [0xFFFF]) for c in present}
                    for p in range(count)]
            changed = False
            for y in range(H):
                yield r.planesC[y], mind, owner[y], count
                n = [0]; b = choose_orig(r.planesC[y], mind, owner[y], count, n)
                if b != owner[y]: owner[y] = b; changed = True
            if not changed: break
            tables = r.mp_tables(owner, count, tables)

if __name__ == "__main__":
    tot = bad = 0; n1 = [0]; n2 = [0]
    for line, mind, own, count in cases():
        tot += 1
        if choose_orig(line, mind, own, count, n1) != choose_owner_first(line, mind, own, count, n2): bad += 1
    rnd = random.Random(4)
    m1 = [0]; m2 = [0]
    for k in range(20000):         # random lines and distances, with ties and overflows
        count = rnd.choice((2, 8, 16)); w = rnd.choice((1, 5, 40, 320))
        cols = list(range(rnd.choice((2, 6, 50))))
        mind = [{c: rnd.choice((0, 1, 2, rnd.randrange(300), rnd.randrange(3000))) for c in cols} for _ in range(count)]
        line = [rnd.choice(cols) for _ in range(w)]
        own = rnd.randrange(count)
        tot += 1
        if choose_orig(line, mind, own, count, m1) != choose_owner_first(line, mind, own, count, m2): bad += 1
    print(f"lines compared: {tot}, mismatches: {bad}")
    print(f"pixels summed on the remaps' lines: original {n1[0]}, owner first {n2[0]} ({100 * n2[0] / n1[0]:.0f} %)")
