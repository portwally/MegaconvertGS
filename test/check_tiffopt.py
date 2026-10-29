# Checks the TIFF Save Options test (test/tiffopt.sh): each file read as TIFF (either byte
# order, its directories sorted), the palette image's pixels against the screen image's colours,
# the RGB image against the true colour picture, and the options' tags.
import os, struct, sys
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
res = os.path.join(root, "build", "test", "results")
ok = True
def report(label, problem):
    global ok
    print(f"{label:58s} {'OK' if not problem else 'FAIL: ' + problem}")
    ok &= not problem
def result(name):
    for f in os.listdir(os.path.join(res, "MCOUT")):
        if f.split("#")[0] == name: return open(os.path.join(res, "MCOUT", f), "rb").read()

def tiff(d):
    e = {b"II": "<", b"MM": ">"}[d[:2]]
    assert struct.unpack(e + "H", d[2:4])[0] == 42
    off, ifds = struct.unpack(e + "I", d[4:8])[0], []
    size = {1: 1, 2: 1, 3: 2, 4: 4, 5: 8}
    while off:
        n = struct.unpack(e + "H", d[off:off + 2])[0]
        tags, order = {}, []
        for k in range(n):
            t, ty, c = struct.unpack(e + "HHI", d[off + 2 + 12 * k:off + 10 + 12 * k])
            field = d[off + 10 + 12 * k:off + 14 + 12 * k]
            raw = field if size[ty] * c <= 4 else d[struct.unpack(e + "I", field)[0]:][:size[ty] * c]
            if ty == 2: v = raw[:c].rstrip(b"\0").decode("latin-1")
            elif ty == 5: v = [struct.unpack(e + "II", raw[8 * i:8 * i + 8]) for i in range(c)]
            else:
                f = {1: "B", 3: "H", 4: "I"}[ty]
                v = list(struct.unpack(e + f * c, raw[:size[ty] * c]))
            tags[t] = v; order.append(t)
        ifds.append((tags, order == sorted(order)))
        off = struct.unpack(e + "I", d[off + 2 + 12 * n:off + 6 + 12 * n])[0]
    return e, ifds

def pixels(d, tags):
    w, h = tags[256][0], tags[257][0]
    strip = d[tags[273][0]:tags[273][0] + tags[279][0]]
    if tags[262][0] == 2:
        return [tuple(strip[3 * (y * w + x):3 * (y * w + x) + 3]) for y in range(h) for x in range(w)]
    b = tags[258][0]; row = (w * b + 7) // 8; cm = tags[320]; n = 1 << b
    out = []
    for y in range(h):
        for x in range(w):
            bit = x * b
            v = (int.from_bytes(strip[y * row:(y + 1) * row], "big") >> (row * 8 - bit - b)) & (n - 1)
            out.append((cm[v] >> 12, cm[n + v] >> 12, cm[2 * n + v] >> 12))
    return out

def screen_colours(c1, w):
    out = []
    mode640 = w == 640
    for y in range(200):
        scb = c1[32000 + y]
        pal = [int.from_bytes(c1[32256 + 32 * (scb & 15) + 2 * i:][:2], "little") for i in range(16)]
        for x in range(w):
            if mode640:
                v = c1[y * 160 + x // 4] >> (6 - 2 * (x & 3)) & 3
                c = pal[[8, 12, 0, 4][x & 3] + v] if scb & 0x80 else pal[v]
            else:
                b = c1[y * 160 + x // 2]
                c = pal[b >> 4 if x % 2 == 0 else b & 15]
            out.append((c >> 8 & 15, c >> 4 & 15, c & 15))
    return out

s320 = open(os.path.join(root, "build", "fixtures", "S320.c1"), "rb").read()
s640 = open(os.path.join(root, "build", "fixtures", "S640.c1"), "rb").read()
for name, label, endian, scr, w, bits_ok, unit, desc in (
        ("TIFP", "palette image, Intel, compatible, a description", "<", s320, 320, (4, 8), 2, "Hello IIgs"),
        ("TIFPM", "palette image, Motorola, fewest bits, no unit", ">", s320, 320, None, 1, None),
        ("TIF640", "palette image of a 640 mode screen, Motorola", ">", s640, 640, (1, 4, 8), 2, None)):
    d = result(name)
    if d is None: report(label, "no file"); continue
    try:
        e, ifds = tiff(d)
        tags, srt = ifds[0]
        prob = None
        if e != endian or len(ifds) != 1 or not srt: prob = f"order {e}, {len(ifds)} images, sorted {srt}"
        elif (tags[256][0], tags[257][0], tags[262][0], tags[259][0]) != (w, 200, 3, 1): prob = "size or kind"
        elif bits_ok and tags[258][0] not in bits_ok: prob = f"{tags[258][0]} bits"
        elif tags[296][0] != unit or tags.get(270) != desc: prob = f"unit {tags[296]}, {tags.get(270)!r}"
        elif tags[305] != "MegaconvertGS 0.9" or tags[316] != "Apple IIgs" or len(tags[306]) != 19: prob = "Software, DateTime, HostComputer"
        elif pixels(d, tags) != screen_colours(scr, w): prob = "pixels differ"
        report(label, prob)
        if name == "TIFPM":
            n = len({p for p in screen_colours(scr, w)})
            report("  the fewest bits for its colours", None if (1 << tags[258][0]) >= n > (1 << (tags[258][0] - 1)) or tags[258][0] == 1
                   else f"{tags[258][0]} bits for {n} colours")
    except Exception as ex:
        report(label, f"not readable ({ex})")
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pngread import read_png
pw_, ph_, px = read_png(os.path.join(root, "build", "fixtures", "true", "RGB8.PNG"))
want_rgb = [tuple(px[3 * i:3 * i + 3]) for i in range(pw_ * ph_)]
scr = result("TIFBSCR")
for name, label, n_img in (("TIFB", "both: the RGB image, then the screen's, Motorola", 2),
                           ("TIFR", "the true colour image only, as RGB, Intel", 1)):
    d = result(name)
    if d is None: report(label, "no file"); continue
    try:
        e, ifds = tiff(d)
        t0 = ifds[0][0]
        prob = None
        if len(ifds) != n_img or not all(s for _, s in ifds): prob = f"{len(ifds)} images"
        elif (t0[262][0], t0[258], t0[277][0], t0[254][0]) != (2, [8, 8, 8], 3, 0): prob = "the RGB image's tags"
        elif pixels(d, t0) != want_rgb: prob = "RGB pixels differ"
        elif n_img == 2:
            t1 = ifds[1][0]
            if t1[254][0] != 1 or t1[262][0] != 3: prob = "the second image's tags"
            elif pixels(d, t1) != screen_colours(scr, t1[256][0]): prob = "palette pixels differ"
            elif t0.get(270) != "Both": prob = "description"
        report(label, prob)
    except Exception as ex:
        report(label, f"not readable ({ex})")
sys.exit(0 if ok else 1)
