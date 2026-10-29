# Checks the pictures of MegaconvertGS's own load formats (test/newfmt.sh) against the
# pixels each was written from (NAME.exp: width, height, RGB bytes), and that Open
# recognised each by its name.
import os, re, struct, sys
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
fix = os.path.join(root, "build", "fixtures", "newfmt")
res = os.path.join(root, "build", "test", "results")
CODES = {"tga": 55, "pict": 56, "pnm": 46, "zx": 57, "msx2": 58, "msx5": 59, "msx7": 60, "msx8": 61,
         "artst": 62, "aas": 63, "cpc0": 64, "cpc1": 65, "cpc2": 66, "fli": 67, "amica": 68,
         "mic": 69, "gr8": 70, "gr9": 71, "c64ps": 36, "lores": 72, "dlores": 73}
AUTO = {"cpc0": "cpc1", "cpc2": "cpc1"}   # what Open makes of each by itself, where it differs
SCREEN = {"zx", "msx2", "artst", "aas", "cpc0", "cpc1", "cpc2", "fli", "amica", "mic", "gr8", "gr9", "c64ps", "lores", "dlores"}   # screen images: in the saved screen's colours

def screen_rgb(c1, w, h):
    """The top left w x h of a $C1 screen as RGB (w 640: 640 mode lines)."""
    out = bytearray()
    for y in range(h):
        p = c1[32000 + y] & 15
        for x in range(w):
            if w == 640:                         # 2 bits a pixel; the pixel's group of 4 entries
                v = (x % 4) * 4 + (c1[y * 160 + x // 4] >> (6 - 2 * (x % 4)) & 3)
                v = (v + 8) % 16                 # (the leftmost pixel of a byte: entries 8-11)
            else:
                b = c1[y * 160 + x // 2]
                v = b >> 4 if x % 2 == 0 else b & 15
            c = c1[32256 + p * 32 + v * 2] | c1[32256 + p * 32 + v * 2 + 1] << 8
            out += bytes((((c >> 8) & 15) * 17, ((c >> 4) & 15) * 17, (c & 15) * 17))
    return bytes(out)
log = open(os.path.join(res, "MC.LOG#040000"), "rb").read().decode("latin-1").split("\r")
forced, auto = {}, {}
for line in log:
    m = re.match(r"LOAD AS (\S+) \*:MCNEWFMT:(\S+): (.*)", line)
    if m: forced[m.group(2)] = m.group(3)
    m = re.match(r"LOAD \*:MCNEWFMT:(\S+): (.*)", line)
    if m: auto[m.group(1)] = m.group(2)
def result(name):
    for f in os.listdir(os.path.join(res, "MCOUT")):
        if f.split("#")[0] == name:
            return open(os.path.join(res, "MCOUT", f), "rb").read()
ok = True
for line in open(os.path.join(root, "build", "fixtures", "newfmt.list")):
    name, fmt, *auto_fmt = line.split()
    problems = []
    entry = forced.get(name, "")
    if not entry.startswith("ok"):
        print(f"{name:13s} {fmt:5s} FAIL: {entry or 'not loaded'}"); ok = False; continue
    code = f"format ${CODES[fmt]:04X}"
    if code not in entry: problems.append(f"loaded as {entry}")
    exp = open(os.path.join(fix, name + ".exp"), "rb").read()
    w, h = struct.unpack("<HH", exp[:4]); want = exp[4:]
    if fmt in SCREEN:
        c1 = result(name + ".C")
        got = screen_rgb(c1, w, h) if c1 and len(c1) == 32768 else None
    else:
        got = result(name + ".R")
    if not got or len(got) != len(want):
        problems.append(f"RGB result {len(got) if got else 0} bytes, not {len(want)}")
    elif got != want:
        n = sum(1 for a, b in zip(got, want) if a != b)
        first = next(i for i, (a, b) in enumerate(zip(got, want)) if a != b) // 3
        worst = max(abs(a - b) for a, b in zip(got, want))
        problems.append(f"{n} samples differ (largest {worst}), first at x={first % w} y={first // w}")
    by_name = f"format ${CODES[auto_fmt[0] if auto_fmt else AUTO.get(fmt, fmt)]:04X}"   # (a CPC screen: mode 1, or its .PAL's)
    if by_name not in auto.get(name, ""): problems.append(f"by name: {auto.get(name, 'not loaded')}")
    m = re.search(r"ticks \$([0-9A-F]+)", entry)
    t = f"  {int(m.group(1), 16) / 60:5.1f} s" if m else ""
    print(f"{name:13s} {fmt:5s} {w:4d}x{h:<4d} {'OK' if not problems else 'FAIL: ' + '; '.join(problems)}{t}")
    ok &= not problems
sys.exit(0 if ok else 1)
