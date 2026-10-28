# Checks the other computers' files MegaconvertGS loaded in the emulator (test/other.sh)
# against GS Remap: screens byte for byte (pixels, line modes, the colour tables in use),
# true colour and black & white pictures pixel for pixel, plus their remap, and what Open
# recognised by itself.
import os, sys, subprocess, re
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pngread import read_png, write_png

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
fix = os.path.join(root, "build", "fixtures", "other")
res = os.path.join(root, "build", "test", "results")
work = os.path.join(root, "build", "test", "expected")
os.makedirs(work, exist_ok=True)
sc4 = os.environ.get("SC4", os.path.expanduser("~/Documents/GS Remap/.build/release/sc4"))
IDS = ["degas", "degaselite", "neo", "tiny", "spu", "spc", "iff", "doodle", "koala", "c64ps", "mpnt640",
       "mpnt320", "mpntmono", "macsm", "gem", "pcx", "fliaway", "sun", "sgi", "pnm", "rle", "ipi", "qrt", "tiff"]
CODES = {fid: 27 + i for i, fid in enumerate(IDS)}
NEAR = {"DEEP.TIF": 1, "PAL.TIF": 1, "PAL4.TIF": 1}   # 16-bit samples and colour maps: rounding

log = open(os.path.join(res, "MC.LOG#040000"), "rb").read().decode().split("\r")
forced, auto = {}, {}
for line in log:
    m = re.match(r"LOAD AS (\S+) \*:MCOTHER:(\S+): (.*)", line)
    if m: forced[m.group(2)] = m.group(3)
    m = re.match(r"LOAD \*:MCOTHER:(\S+): (.*)", line)
    if m: auto[m.group(1)] = m.group(2)

def result(name):
    for f in os.listdir(os.path.join(res, "MCOUT")):
        if f.split("#")[0] == name:
            return open(os.path.join(res, "MCOUT", f), "rb").read()
    return None

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
for line in open(os.path.join(root, "build", "fixtures", "other.list")):
    name, fmt, *wants_auto = line.split()
    problems, notes = [], ""
    entry = forced.get(name, "")
    if not entry.startswith("ok"):
        print(f"{name:13s} {fmt:8s} FAIL: {entry or 'not loaded'}"); ok = False; continue
    if f"format ${CODES[fmt]:04X}" not in entry: problems.append(f"loaded as {entry}")
    m = re.search(r"ticks \$([0-9A-F]+)", entry)
    if m: notes = f"  {int(m.group(1), 16) / 60:5.1f} s"
    src = os.path.join(fix, name)
    ref = os.path.join(work, name + ".ref")
    kind = subprocess.run([sc4, "load", src, ref + ".c1", fmt], check=True, capture_output=True,
                          text=True).stdout.split()[0]
    if kind != "screen":                       # a true colour or black & white picture: a PNG
        os.replace(ref + ".c1", ref + ".png")
        w, h, want = read_png(ref + ".png")
        got = result(name + ".R")
        if not got or len(got) != len(want):
            problems.append("no matching RGB result")
        else:
            worst = max(abs(a - b) for a, b in zip(got, want))
            if worst > NEAR.get(name, 0):
                n = sum(1 for a, b in zip(got, want) if a != b)
                first = next(i for i, (a, b) in enumerate(zip(got, want)) if a != b) // 3
                problems.append(f"{n} RGB samples differ (largest {worst}), first at x={first % w} y={first // w}")
        parts = entry.replace(",", "").split()
        ow, oh = int(parts[7].strip("$"), 16), int(parts[8].strip("$"), 16)
        tall = "size" in entry and fmt == "iff" and name == "HIRES.IFF"
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
        want = open(ref + ".c1", "rb").read()
        got = result(name + ".C")
        problems += compare_screens(got, want) if got else ["no screen saved"]
    if wants_auto:
        a = auto.get(name, "")
        if f"format ${CODES[fmt]:04X}" not in a: problems.append(f"Open recognised it as: {a}")
        else: notes += "  (recognised)"
    print(f"{name:13s} {fmt:8s} {'OK' + notes if not problems else 'FAIL: ' + '; '.join(problems)}")
    ok &= not problems
sys.exit(0 if ok else 1)
