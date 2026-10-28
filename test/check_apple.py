# Checks the Apple II and IIgs files MegaconvertGS loaded in the emulator (test/apple.sh)
# against GS Remap: screens byte for byte (pixels, line modes, the colour tables in use),
# true colour pictures pixel for pixel, plus their remap, and what Open recognised by itself.
# GS Remap's command-line tool has no Apple II character set, so text screens are drawn
# here with the same glyphs (src/Glyphs.s) the way GS Remap draws them.
import os, sys, subprocess, re
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pngread import read_png, write_png

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
fix = os.path.join(root, "build", "fixtures", "apple")
res = os.path.join(root, "build", "test", "results")
work = os.path.join(root, "build", "test", "expected")
os.makedirs(work, exist_ok=True)
sc4 = os.environ.get("SC4", os.path.expanduser("~/Documents/GS Remap/.build/release/sc4"))
TRUE = {"tscan", "drm3200", "ast", "ceyes", "3200", "3200c"}
CODES = {"hgr": 9, "hgrbw": 10, "dhr": 11, "dhrbw": 12, "psbw": 13, "psgs": 14, "cgt": 15, "icon": 16,
         "tscan": 17, "tdm40": 18, "tdm80": 19, "drm": 20, "drm3200": 21, "ast": 22, "ceyes": 23,
         "3200": 24, "3200c": 25, "pwgold": 26}

log = open(os.path.join(res, "MC.LOG#040000"), "rb").read().decode().split("\r")
forced, auto = {}, {}
for line in log:
    m = re.match(r"LOAD AS (\S+) \*:MCAPPLE:(\S+): (.*)", line)
    if m: forced[m.group(2)] = m.group(3)
    m = re.match(r"LOAD \*:MCAPPLE:(\S+): (.*)", line)
    if m: auto[m.group(1)] = m.group(2)

def result(name):
    for f in os.listdir(os.path.join(res, "MCOUT")):
        if f.split("#")[0] == name:
            return open(os.path.join(res, "MCOUT", f), "rb").read()
    return None

def glyphs():
    g = []
    for line in open(os.path.join(root, "src", "Glyphs.s")):
        m = re.search(r"hex\s+([0-9A-F]{16})", line)
        if m: g.append(bytes.fromhex(m.group(1)))
    return g

def text_screen(d, cols):
    """GS Remap's loadTextScreen, as a $C1 file."""
    g, wide = glyphs(), cols == 80
    width, white = cols * 7, (3 if wide else 15)
    pix = [[0] * width for _ in range(192)]
    for row in range(24):
        base = (row & 7) * 0x80 + (row >> 3) * 0x28
        for col in range(cols):
            at = base + col // 2 + (1024 if col & 1 else 0) if wide else base + col
            if at >= len(d): continue
            code = d[at]; ch = code & 0x7F
            if ch < 0x20: ch += 0x40
            inverse = code < 0x80
            glyph = g[ch - 0x20] if 0x20 <= ch <= 0x7E else bytes(8)
            for gy in range(8):
                for gx in range(7):
                    if bool(glyph[gy] & (0x40 >> gx)) != inverse: pix[row * 8 + gy][col * 7 + gx] = white
    out = bytearray(32768)
    for y in range(192):
        for x in range(width):
            if wide: out[y * 160 + x // 4] |= pix[y][x] << (6 - 2 * (x & 3))
            else: out[y * 160 + x // 2] |= pix[y][x] << (4 if x % 2 == 0 else 0)
        out[32000 + y] = 0x80 if wide else 0
    pal = [0x000, 0xF00, 0x0F0, 0xFFF, 0x000, 0x00F, 0xFF0, 0xFFF] * 2 if wide else \
          [0x000, 0x777, 0x841, 0x72C, 0x00F, 0x080, 0xF70, 0xD00, 0xFA9, 0xFF0, 0x0E0, 0x4DF, 0xDAF, 0x78F, 0xCCC, 0xFFF]
    for i, c in enumerate(pal): out[32256 + i * 2:32258 + i * 2] = c.to_bytes(2, "little")
    return bytes(out)

def fit(w, h):
    steps = [(1, 16), (1, 12), (1, 10), (1, 8), (1, 6), (1, 5), (1, 4), (1, 3), (2, 5), (1, 2), (3, 5), (2, 3),
             (3, 4), (4, 5), (1, 1)]
    step = 14
    while step > 0:
        n, d = steps[step]
        if w * n // d <= 320 and h * n // d <= 200: break
        step -= 1
    n, d = steps[step]
    return min(320, max(1, w * n // d)), min(200, max(1, h * n // d))

def compare_screens(got, want):
    problems = []
    bad = sum(1 for a, b in zip(got[:32000], want[:32000]) if a != b)
    if bad: problems.append(f"{bad} pixel bytes differ")
    if got[32000:32200] != want[32000:32200]: problems.append("line modes differ")
    for t in sorted({b & 15 for b in want[32000:32200]}):
        a = [int.from_bytes(got[32256 + t * 32 + i * 2:32258 + t * 32 + i * 2], "little") & 0xFFF for i in range(16)]
        b = [int.from_bytes(want[32256 + t * 32 + i * 2:32258 + t * 32 + i * 2], "little") & 0xFFF for i in range(16)]
        if a != b: problems.append(f"colour table {t} differs")
    return problems

ok = True
for line in open(os.path.join(root, "build", "fixtures", "apple.list")):
    name, fmt, *wants_auto = line.split()
    problems, notes = [], ""
    entry = forced.get(name, "")
    if not entry.startswith("ok"):
        print(f"{name:13s} {fmt:8s} FAIL: {entry or 'not loaded'}"); ok = False; continue
    if f"format ${CODES[fmt]:04X}" not in entry: problems.append(f"loaded as {entry}")
    m = re.search(r"ticks \$([0-9A-F]+)", entry)
    if m: notes = f"  {int(m.group(1), 16) / 60:5.1f} s"
    src = os.path.join(fix, name)
    if fmt in TRUE:
        ref = os.path.join(work, name + ".png")
        subprocess.run([sc4, "load", src, ref, fmt], check=True, capture_output=True)
        w, h, want = read_png(ref)
        got = result(name + ".R")
        if got != want:
            n = sum(1 for a, b in zip(got or b"", want) if a != b)
            problems.append(f"{n} RGB samples differ" if got and len(got) == len(want) else "no matching RGB result")
        parts = entry.replace(",", "").split()
        ow, oh = int(parts[7].strip("$"), 16), int(parts[8].strip("$"), 16)
        tall = fmt == "tscan" and open(src, "rb").read()[0x0A] & 1
        if fit(max(1, w // 2) if tall else w, h) != (ow, oh): problems.append(f"fitted {ow}x{oh}")
        if got and len(got) == len(want):
            png = os.path.join(work, name + ".decoded.png")
            write_png(png, w, h, got)
            out = os.path.join(work, name + ".remap.c1")
            subprocess.run([sc4, "remap", png, out, "--size", f"{ow}x{oh}"], check=True, capture_output=True)
            screen = result(name + ".C")
            expect = open(out, "rb").read()
            if screen is None or screen[:32000] != expect[:32000] or screen[32256:32288] != expect[32256:32288]:
                problems.append("remap differs")
    else:
        if fmt in ("tdm40", "tdm80"):
            want = text_screen(open(src, "rb").read(), 40 if fmt == "tdm40" else 80)
        else:
            ref = os.path.join(work, name + ".c1")
            subprocess.run([sc4, "load", src, ref, fmt], check=True, capture_output=True)
            want = open(ref, "rb").read()
        got = result(name + ".C")
        problems += compare_screens(got, want) if got else ["no screen saved"]
    if wants_auto:
        a = auto.get(name, "")
        if f"format ${CODES[fmt]:04X}" not in a: problems.append(f"Open recognised it as: {a}")
        else: notes += "  (recognised)"
    print(f"{name:13s} {fmt:8s} {'OK' + notes if not problems else 'FAIL: ' + '; '.join(problems)}")
    ok &= not problems
sys.exit(0 if ok else 1)
