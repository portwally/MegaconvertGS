# Check 5: the smaller table and loop changes.
#  a. SetLine from tables: colour word (also doubled, as an index) and grey level from
#     byte tables: (R&$F0)<<4 | (G&$F0) | B>>4 and (5R + 8G + 3B) >> 4. All 2^24 RGB.
#  b. Writing output bytes directly: 2 pixels a byte (320) or 4 (640) from the pattern
#     bytes, against PutPixel ORing into a cleared RowOut. Random lines.
#  c. Diffuse: the grey shown (GreyOf) for the byte chosen for each level depends only on
#     the level and the column (mod 2 in 320 mode, mod 4 in 640): a table per palette.
#  d. Quick remap: the ordered dither as a table per (line parity, column parity).
#  e. ScreenToTrue from a per-line table of the 16 colours times 17, against the
#     per-pixel code; random screens, both modes, mixed lines (a 640 line in a 320
#     picture reads past its table: such lines keep the per-pixel code).
import os, sys, random, struct
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from model import INT, DefProtos, GreyProtos, Other320, Other640, Other640D, is_grey
from check_best import build, best_ref
from images import SCREENS

# ---------------------------------------------------------------- a
TRc = [(r & 0xF0) << 4 for r in range(256)]
TGc = [g & 0xF0 for g in range(256)]
TBc = [b >> 4 for b in range(256)]
Y5 = [5 * r for r in range(256)]
Y8 = [8 * g for g in range(256)]
Y3 = [3 * b for b in range(256)]


def check_setline():
    bad = 0
    for r in range(256):
        for g in range(256):
            cg = TRc[r] | TGc[g]
            yg = Y5[r] + Y8[g]
            for b in range(256):
                c = cg | TBc[b]
                if c != ((r & 0xF0) << 4 | (g & 0xF0) | (b >> 4)): bad += 1
                if 2 * c != (((r & 0xF0) << 5) | ((g & 0xF0) << 1) | ((b >> 4) << 1)): bad += 1
                if (yg + Y3[b]) >> 4 != (5 * r + 8 * g + 3 * b) >> 4: bad += 1
    return bad

# ---------------------------------------------------------------- b
ColMask = [0xC0, 0x30, 0x0C, 0x03]


def putpixel_row(bytes_, wide):
    row = bytearray(160)
    for x, v in enumerate(bytes_):
        if not wide:
            row[x >> 1] |= (v & 0xF0) if x % 2 == 0 else (v & 0x0F)
        else:
            row[x >> 2] |= v & ColMask[x & 3]
    return bytes(row)


def direct_row(bytes_, wide):
    row = bytearray(160)
    if not wide:
        for k in range(0, len(bytes_) - 1, 2):
            row[k >> 1] = (bytes_[k] & 0xF0) | (bytes_[k + 1] & 0x0F)
        if len(bytes_) % 2: row[len(bytes_) >> 1] = bytes_[-1] & 0xF0
    else:
        for k in range(0, len(bytes_), 4):
            v = 0
            for j in range(4):
                if k + j < len(bytes_): v |= bytes_[k + j] & ColMask[j]
            row[k >> 2] = v
    return bytes(row)


def check_rows():
    rnd = random.Random(5)
    bad = 0
    for t in range(20000):
        wide = t % 2
        w = rnd.randint(1, 640 if wide else 320)
        bs = [rnd.randrange(256) for _ in range(w)]
        if putpixel_row(bs, wide) != direct_row(bs, wide): bad += 1
    return bad

# ---------------------------------------------------------------- c


def grey_of(pal, n, pbyte, x):
    if n == 16:
        v = (pbyte & 15) if x & 1 else (pbyte >> 4)
    else:
        v = (pbyte >> (2 * (3 - (x & 3)))) & 3
        if n == 8 and x & 1: v += 4
    return INT[(pal[v] >> 4) & 15]


def check_diffuse():
    bad = cases = 0
    pals = []
    for m, n in ((0, 16), (1, 4), (2, 8)):
        pals.append(GreyProtos[m][:n])
        for p in [Other320, Other640, Other640D][m]:
            if all(e & 0x8000 or is_grey(e & 0xFFF) for e in p[:n]): pals.append(p[:n])
    rnd = random.Random(9)
    for k in range(30):
        n = (16, 4, 8)[k % 3]
        pals.append([rnd.randrange(16) * 0x111 | (0x8000 if rnd.random() < .2 else 0) for _ in range(n)])
    for pal in pals:
        n = len(pal)
        cands = build(pal, False)                     # Diffuse looks up with closest match
        gv = []
        for v in range(256):
            f = best_ref(cands, v, v, v)
            gv.append(cands[f][4])
        period = 2 if n == 16 else 4
        table = [[grey_of(pal, n, gv[v], x) for x in range(period)] for v in range(256)]
        width = 320 if n == 16 else 640
        for v in range(256):
            for x in range(width):
                cases += 1
                if table[v][x % period] != grey_of(pal, n, gv[v], x): bad += 1
    return cases, bad

# ---------------------------------------------------------------- d
TH = [5, 12, 14, 9]


def quick_orig(c, x, y):
    t = TH[(y & 1) * 2 + (x & 1)]
    i = (4 if (c >> 8) & 15 >= t else 0) | (2 if (c >> 4) & 15 >= t else 0) | (1 if c & 15 >= t else 0)
    return 15 if i == 7 else i


def check_quick():
    tabs = [[quick_orig(c, px, py) for c in range(4096)] for py in (0, 1) for px in (0, 1)]
    bad = 0
    for y in range(4):
        for x in range(4):
            t = tabs[(y & 1) * 2 + (x & 1)]
            for c in range(4096):
                if t[c] != quick_orig(c, x, y): bad += 1
    return bad

# ---------------------------------------------------------------- e
OFF = [8, 12, 0, 4]


def s2t_orig(scr, W, pic640):
    out = bytearray()
    for y in range(200):
        scb = scr[32000 + y]
        tab = 32256 + (scb & 15) * 32
        for x in range(W):
            if pic640:
                v = (scr[y * 160 + (x >> 2)] >> (2 * (3 - (x & 3)))) & 3
            else:
                b = scr[y * 160 + (x >> 1)]
                v = b & 15 if x & 1 else b >> 4
            v = OFF[x & 3] + v if scb & 0x80 else v & 15
            o = tab + 2 * v
            c = scr[o] | scr[o + 1] << 8 if o + 1 < len(scr) else 0
            out += bytes((((c >> 8) & 15) * 17, ((c >> 4) & 15) * 17, (c & 15) * 17))
    return bytes(out)


def s2t_fast(scr, W, pic640):
    out = bytearray()
    for y in range(200):
        scb = scr[32000 + y]
        line = scr[y * 160:(y + 1) * 160]
        if (scb & 0x80) and not pic640:                    # mixed: the per-pixel code
            out += s2t_orig_line(scr, y, W, pic640)
            continue
        tab = 32256 + (scb & 15) * 32
        rgb = []
        for e in range(16):                                 # the line's 16 colours, times 17
            c = scr[tab + 2 * e] | scr[tab + 2 * e + 1] << 8
            rgb.append(bytes((((c >> 8) & 15) * 17, ((c >> 4) & 15) * 17, (c & 15) * 17)))
        if not pic640:
            for k in range(W >> 1):
                out += rgb[line[k] >> 4] + rgb[line[k] & 15]
            if W & 1: out += rgb[line[W >> 1] >> 4]
        else:
            off = OFF if scb & 0x80 else [0, 0, 0, 0]
            for x in range(W):
                out += rgb[off[x & 3] + ((line[x >> 2] >> (6 - 2 * (x & 3))) & 3)]
    return bytes(out)


def s2t_orig_line(scr, y, W, pic640):
    return s2t_orig_one(scr, y, W, pic640)


def s2t_orig_one(scr, y, W, pic640):
    out = bytearray()
    scb = scr[32000 + y]
    tab = 32256 + (scb & 15) * 32
    for x in range(W):
        if pic640:
            v = (scr[y * 160 + (x >> 2)] >> (2 * (3 - (x & 3)))) & 3
        else:
            b = scr[y * 160 + (x >> 1)]
            v = b & 15 if x & 1 else b >> 4
        v = OFF[x & 3] + v if scb & 0x80 else v & 15
        o = tab + 2 * v
        c = scr[o] | scr[o + 1] << 8 if o + 1 < len(scr) else 0
        out += bytes((((c >> 8) & 15) * 17, ((c >> 4) & 15) * 17, (c & 15) * 17))
    return bytes(out)


def check_s2t():
    rnd = random.Random(11)
    screens = []
    for name in ("S320.c1", "S640.c1"):
        screens.append(open(os.path.join(SCREENS, name), "rb").read())
    for k in range(8):
        s = bytearray(rnd.randrange(256) for _ in range(32768))
        for y in range(200):
            m = rnd.random()
            s[32000 + y] = (rnd.randrange(16)) | (0x80 if (m < 0.5) == (k % 2 == 1) or m < 0.1 else 0)
        screens.append(bytes(s))
    bad = 0
    for s in screens:
        for pic640, W in ((0, 320), (1, 640)):
            if s2t_orig(s, W, pic640) != s2t_fast(s, W, pic640): bad += 1
    return len(screens) * 2, bad


if __name__ == "__main__":
    print("a. SetLine from tables, all 16777216 RGB values (colour, doubled colour, grey): mismatches",
          check_setline())
    print("b. output bytes written directly, 20000 random lines (320 and 640): mismatches", check_rows())
    print("c. Diffuse's grey shown, by level and column parity: (cases, mismatches)", check_diffuse())
    print("d. Quick remap from 4 tables of 4096 entries, every colour and parity: mismatches", check_quick())
    print("e. ScreenToTrue from per-line tables, fixtures and random screens: (pictures, mismatches)", check_s2t())
