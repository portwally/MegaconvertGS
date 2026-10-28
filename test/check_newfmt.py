# Checks the pictures of MegaconvertGS's own load formats (test/newfmt.sh) against the
# pixels each was written from (NAME.exp: width, height, RGB bytes), and that Open
# recognised each by its name.
import os, re, struct, sys
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
fix = os.path.join(root, "build", "fixtures", "newfmt")
res = os.path.join(root, "build", "test", "results")
CODES = {"tga": 55, "pict": 56, "pnm": 46}
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
    name, fmt = line.split()
    problems = []
    entry = forced.get(name, "")
    if not entry.startswith("ok"):
        print(f"{name:13s} {fmt:5s} FAIL: {entry or 'not loaded'}"); ok = False; continue
    code = f"format ${CODES[fmt]:04X}"
    if code not in entry: problems.append(f"loaded as {entry}")
    exp = open(os.path.join(fix, name + ".exp"), "rb").read()
    w, h = struct.unpack("<HH", exp[:4]); want = exp[4:]
    got = result(name + ".R")
    if not got or len(got) != len(want):
        problems.append(f"RGB result {len(got) if got else 0} bytes, not {len(want)}")
    elif got != want:
        n = sum(1 for a, b in zip(got, want) if a != b)
        first = next(i for i, (a, b) in enumerate(zip(got, want)) if a != b) // 3
        worst = max(abs(a - b) for a, b in zip(got, want))
        problems.append(f"{n} samples differ (largest {worst}), first at x={first % w} y={first // w}")
    if code not in auto.get(name, ""): problems.append(f"by name: {auto.get(name, 'not loaded')}")
    m = re.search(r"ticks \$([0-9A-F]+)", entry)
    t = f"  {int(m.group(1), 16) / 60:5.1f} s" if m else ""
    print(f"{name:13s} {fmt:5s} {w:4d}x{h:<4d} {'OK' if not problems else 'FAIL: ' + '; '.join(problems)}{t}")
    ok &= not problems
sys.exit(0 if ok else 1)
