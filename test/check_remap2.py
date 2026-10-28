# Checks MegaconvertGS's remaps with each mode, palette and rendering (test/remap2.sh)
# against GS Remap's (test/sc4save's sc4remap): pixels, line modes, the colour tables in use.
import os, sys, subprocess, re
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from remap2_list import SOURCES, RUNS
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
res = os.path.join(root, "build", "test", "results")
work = os.path.join(root, "build", "test", "expected", "remap2")
os.makedirs(work, exist_ok=True)
tool = os.path.join(root, "test", "sc4save", ".build", "release", "sc4remap")
log = open(os.path.join(res, "MC.LOG#040000"), "rb").read().decode().split("\r")
remaps = [l for l in log if l.startswith("REMAP WITH") or l.startswith("REMAP QUICK")]
MODES = ["320", "640", "640 dither", "multipalette"]
PALS = ["calculated", "default", "greys", "other", "current", "stored"]
ALGS = ["closest", "pattern", "diffusion"]
def result(name):
    for f in os.listdir(os.path.join(res, "MCOUT")):
        if f.split("#")[0] == name + ".C": return os.path.join(res, "MCOUT", f)
ok = True
for k, (name, src, mode, pal, alg, h, v, other, *store) in enumerate(RUNS):
    disk, local, fid = SOURCES[src]
    ref = os.path.join(work, name + ".c1")
    extra = []
    if store:                               # the screen Store palette was used on
        extra = [os.path.join(root, SOURCES[store[0]][1]) if store[0] in SOURCES else result(store[0]) or "-"]
    r = subprocess.run([tool, os.path.join(root, local), fid, ref, str(mode), str(pal), str(alg), str(h), str(v),
                        str(other)] + extra, capture_output=True, text=True)
    if mode == "q":
        label = f"{name} {src} quick remap"
    else:
        label = f"{name} {src} {MODES[mode]}, {PALS[pal]}{'' if pal != 3 else ' ' + str(other)}, {ALGS[alg]}" + \
                ("" if h == 255 else f", steps {h}/{v}") + (f" (from {store[0]})" if store else "")
    entry = remaps[k] if k < len(remaps) else "not run"
    m = re.search(r"ticks \$([0-9A-F]+)", entry)
    secs = f"{int(m.group(1), 16) / 60:5.1f} s" if m else ""
    got = result(name)
    if got: got = open(got, "rb").read()
    problems = []
    if r.returncode: problems.append("reference: " + r.stderr.strip())
    elif got is None: problems.append(f"no result ({entry})")
    else:
        want = open(ref, "rb").read()
        bad = sum(1 for a, b in zip(got[:32000], want[:32000]) if a != b)
        if bad: problems.append(f"{bad} pixel bytes differ")
        if got[32000:32200] != want[32000:32200]: problems.append("line modes differ")
        for t in sorted({b & 15 for b in want[32000:32200]}):
            if got[32256 + t * 32:32288 + t * 32] != want[32256 + t * 32:32288 + t * 32]:
                problems.append(f"colour table {t} differs")
    print(f"{label:58s} {'OK ' + secs if not problems else 'FAIL: ' + '; '.join(problems)}")
    ok &= not problems
sys.exit(0 if ok else 1)
