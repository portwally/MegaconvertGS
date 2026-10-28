# Check 1: the box sizes the scaler can meet, and the incremental span walk.
#
# The source/output pairs come from Sizes (and Quick) in RemapSeg.s for every picture
# size the program accepts (1..4096 each way, NewTrue's limit), each scale step (0..22),
# both pixel shapes, 320 and 640 width. For each pair every span is computed both ways:
#   SpanOf:      a = i*src/out, b = (i+1)*src/out, b = a+1 if equal, b = min(b, src)
#   incremental: a, r carried from column to column (a += src/out, r += src%out, carry)
# and must agree for every column the scaler computes.
import os
StepN = [1, 1, 1, 1, 1, 1, 1, 1, 2, 1, 3, 2, 3, 4, 1, 5, 4, 3, 5, 2, 5, 3, 4]
StepD = [16, 12, 10, 8, 6, 5, 4, 3, 5, 2, 5, 3, 4, 5, 1, 4, 3, 2, 3, 1, 2, 1, 1]


def scale(a, s): return a * StepN[s] // StepD[s]


def pairs_x():
    out = set()
    for rw in range(1, 4097):
        for tall in (0, 1):
            for wide in (0, 1):                 # 320 (and multipalette) / 640 modes
                if wide: nw = rw if tall else rw * 2
                else: nw = max(1, rw >> 1) if tall else rw
                sw = 640 if wide else 320
                for s in range(23):
                    ww = scale(nw, s) or 1
                    ow = min(sw, ww)
                    cw = rw * ow // ww or 1
                    out.add((cw, ow, ow))       # (src, out, columns computed)
                # Quick remap: the whole picture at its 320 mode size, the top left screenful
                nq = max(1, rw >> 1) if tall else rw
                out.add((rw, nq, min(nq, 320)))
    return out


def pairs_y():
    out = set()
    for rh in range(1, 4097):
        for s in range(23):
            wh = scale(rh, s) or 1
            oh = min(200, wh)
            ch = rh * oh // wh or 1
            out.add((ch, oh, oh))
        out.add((rh, rh, min(rh, 200)))         # Quick
    return out


def spans_ref(src, out, n):
    r = []
    for i in range(n):
        a = i * src // out
        b = (i + 1) * src // out
        if b == a: b += 1
        if b > src: b = src
        r.append((a, b))
    return r


def spans_dda(src, out, n):
    """No multiply or divide per column: one division per picture (src/out, src%out)."""
    qd, rd = divmod(src, out)
    r = []
    a, ra = 0, 0                     # a = i*src//out, ra = i*src%out
    b, rb = qd, rd                   # b = (i+1)*src//out
    if rb >= out: b, rb = b + 1, rb - out
    for i in range(n):
        bb = b + 1 if b == a else b
        if bb > src: bb = src
        r.append((a, bb))
        a, ra = b, rb
        b, rb = b + qd, rb + rd
        if rb >= out: b, rb = b + 1, rb - out
    return r


if __name__ == "__main__":
    px, py = pairs_x(), pairs_y()
    print("distinct (source, output) pairs: across", len(px), " down", len(py))
    lens_x, lens_y = set(), set()
    bad = 0
    checked = 0
    for pairs, lens in ((px, lens_x), (py, lens_y)):
        for src, out, n in sorted(pairs):
            ref = spans_ref(src, out, n)
            if spans_dda(src, out, n) != ref: bad += 1
            checked += n
            for a, b in ref: lens.add(b - a)
            # 16-bit sums: every box is at most 255 * n, as checked below
    print("spans compared:", checked, " mismatches:", bad)
    print("span lengths across:", min(lens_x), "..", max(lens_x), " down:", min(lens_y), "..", max(lens_y))
    ns = sorted({a * b for a in lens_x for b in lens_y})
    print("box sizes n = across x down:", len(ns), "values, largest", ns[-1])
    print("n <= 257 (sums fit 16 bits):", sum(1 for n in ns if n <= 257), " larger:", [n for n in ns if n > 257][:12], "...")
    # Which combinations really occur together? lengths come in pairs (k, k+1) per axis
    import json
    json.dump({"x": sorted(lens_x), "y": sorted(lens_y), "n": ns},
              open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "box_sizes.json"), "w"))
