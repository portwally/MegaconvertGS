# Checks MegaconvertGS's Apple II save formats (test/a2save.sh): each saved file against a
# model of Save.s's rules, made from the screen saved as $C1 beside it. The picture is
# stretched to the Apple II screen, each place taking the middle of its part of the
# picture; colours go to the closest Apple II colour (HiRes: of six), black & white dots
# are on where 3R + 6G + B is at least 75. Pictures loaded from Apple II files must also
# save back as they were.
import os, sys
PICTURES = [  # tag, file on the test disk, load format id, width, height
    ("S32", "MCTEST:S320.C1", "c1", 320, 200),
    ("S64", "MCTEST:S640.C1", "c1", 640, 200),
    ("HGR", "MCAPPLE:HGR.PIC", "hgr", 280, 192),
    ("DHR", "MCAPPLE:DHR.PIC", "dhr", 280, 192),
    ("DHB", "MCAPPLE:DHRBW.PIC", "dhrbw", 560, 192),
]
FORMATS = ["hgr", "hgrbw", "dhr", "dhrbw"]
# saved as it was loaded: (tag, format) -> the original file
SAME = {("DHR", "dhr"): "DHR.PIC", ("DHB", "dhrbw"): "DHRBW.PIC"}
if sys.argv[1:] == ["commands"]:
    for tag, disk, fid, w, h in PICTURES:
        print(f"LOAD AS {fid} *:{disk}")
        print(f"SAVE C1 *:MCOUT:{tag}.C")
        for fmt in FORMATS:
            print(f"SAVE AS {fmt} *:MCOUT:{tag}.{fmt.upper()}")
    print("SHOW")
    sys.exit()

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
res = os.path.join(root, "build", "test", "results", "MCOUT")
def ours(name):
    for f in os.listdir(res):
        if f.split("#")[0] == name:
            return open(os.path.join(res, f), "rb").read(), f.split("#")[1] if "#" in f else ""
    return None, ""

A2PAL = [0x000, 0xD03, 0x852, 0xF60, 0x070, 0x555, 0x0D0, 0xFF0,
         0x009, 0xD0D, 0xAAA, 0xF98, 0x22F, 0x6AF, 0x0F9, 0xFFF]
HCAND = [0, 15, 9, 6, 12, 3]

def colours(scr, w, h):
    """The 12-bit colour shown at each pixel of the picture (top left of the screen)."""
    rows = []
    for y in range(h):
        scb = scr[0x7D00 + y]
        pal = [scr[0x7E00 + (scb & 15) * 32 + 2 * i] | scr[0x7E00 + (scb & 15) * 32 + 2 * i + 1] << 8 for i in range(16)]
        line = scr[y * 160:(y + 1) * 160]
        if scb & 0x80:
            row = [pal[(8, 12, 0, 4)[x & 3] + (line[x >> 2] >> (6 - 2 * (x & 3)) & 3)] & 0xFFF for x in range(w)]
        else:
            row = [pal[line[x >> 1] >> (0 if x & 1 else 4) & 15] & 0xFFF for x in range(w)]
        rows.append(row)
    return rows

def near(c, cands):
    r, g, b = c >> 8 & 15, c >> 4 & 15, c & 15
    best = None
    for k in cands:
        p = A2PAL[k]
        d = ((p >> 8 & 15) - r) ** 2 + ((p >> 4 & 15) - g) ** 2 + ((p & 15) - b) ** 2
        if best is None or d < best[0]:
            best = (d, k)
    return best[1]

def bright(c):
    return 1 if 3 * (c >> 8 & 15) + 6 * (c >> 4 & 15) + (c & 15) >= 75 else 0

def rowoff(y):
    return (y & 7) * 0x400 + (y >> 3 & 7) * 0x80 + (y >> 6) * 40

def model(rows, w, h, fmt):
    places = {"hgr": 280, "hgrbw": 280, "dhr": 140, "dhrbw": 560}[fmt]
    out = bytearray(8192 if fmt.startswith("hgr") else 16384)
    for y in range(192):
        src = rows[(2 * y + 1) * h // 384]
        vals = [src[(2 * i + 1) * w // (2 * places)] for i in range(places)]
        if fmt == "hgr":
            v = [near(c, HCAND) for c in vals]
            for b in range(40):
                seven = v[7 * b:7 * b + 7]
                bal = sum(1 for c in seven if c in (12, 3)) - sum(1 for c in seven if c in (9, 6))
                byte = 0x80 if bal > 0 else 0
                for i, c in enumerate(seven):
                    x = 7 * b + i
                    on = c == 15 or (c in (9, 12) and x % 2 == 0) or (c in (6, 3) and x % 2 == 1)
                    if on: byte |= 1 << i
                out[rowoff(y) + b] = byte
            continue
        if fmt == "dhr":
            dots = []
            for c in vals:
                k = near(c, range(16))
                dots += [k >> 3 & 1, k >> 2 & 1, k >> 1 & 1, k & 1]
        else:
            dots = [bright(c) for c in vals]
        for g in range(len(dots) // 7):
            byte = sum(dots[7 * g + i] << i for i in range(7))
            if fmt.startswith("hgr"):
                out[rowoff(y) + g] = byte
            else:
                out[rowoff(y) + g // 2 + (8192 if g & 1 else 0)] = byte
    return bytes(out)

def visible(data, size):
    """The screen bytes of a HiRes page (or two): the low 7 bits, no screen holes."""
    keep = bytearray()
    for half in range(0, size, 8192):
        for y in range(192):
            keep += bytes(b & 0x7F for b in data[half + rowoff(y):half + rowoff(y) + 40])
    return bytes(keep)

ok = True
for tag, disk, fid, w, h in PICTURES:
    scr, _ = ours(f"{tag}.C")
    if scr is None or len(scr) != 32768:
        print(f"{tag}: no $C1 screen saved"); ok = False; continue
    rows = colours(scr, w, h)
    for fmt in FORMATS:
        name = f"{tag}.{fmt.upper()}"
        got, typ = ours(name)
        want = model(rows, w, h, fmt)
        if got is None:
            print(f"{name:12} not saved"); ok = False; continue
        res_ = "OK" if got == want else "DIFFERENT"
        if got != want:
            ok = False
            diff = [i for i in range(len(want)) if i >= len(got) or got[i] != want[i]]
            res_ += f" ({len(got)} bytes, {len(diff)} differ, first at {diff[0] if diff else '-'})"
        if not typ.upper().startswith("062000"):
            res_ += f" (type {typ}, not $06/$2000)"; ok = False
        extra = ""
        if (tag, fmt) in SAME:
            orig = open(os.path.join(root, "build", "fixtures", "apple", SAME[(tag, fmt)]), "rb").read()
            same = visible(orig, len(want)) == visible(got, len(want))
            extra = "  saved as loaded" if same else "  NOT as loaded"
            ok &= same
        print(f"{name:12} {typ:10} {res_}{extra}")
print("all OK" if ok else "FAILED")
sys.exit(0 if ok else 1)
