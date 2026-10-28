# Checks the filter test (test/filters.sh): what MegaconvertGS's filters and rotate/flip
# made of each picture against GS Remap's (sc4filter on the same input), byte for byte.
import os, re, struct, subprocess, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from filters_list import PICTURES, CASES, name

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
res = os.path.join(root, "build", "test", "results")
work = os.path.join(root, "build", "test", "expected", "filters")
os.makedirs(work, exist_ok=True)
tool = os.path.join(root, "test", "sc4save", ".build", "release", "sc4filter")
log = {}
for line in open(os.path.join(res, "MC.LOG#040000"), "rb").read().decode().split("\r"):
    m = re.match(r"(FILTER|TURN) .*?: (.*)", line)
    if m: log.setdefault("ops", []).append(m.group(2))

def ours(n):
    for f in os.listdir(os.path.join(res, "MCOUT")):
        if f.split("#")[0] == n: return open(os.path.join(res, "MCOUT", f), "rb").read()
    return None

OPS = ["equalize", "median", "sigma", "emboss", "blur", "sharpen", "solarize", "edges", "more", "less"]
ok = True
for tag, pic in PICTURES.items():
    d = open(os.path.join(root, "build", "fixtures", "filter", pic), "rb").read()
    w, h = struct.unpack_from("<ii", d, 18)
    src = os.path.join(work, tag + ".in")
    inp = ours(tag + ".IN")
    if inp is None or len(inp) != w * h * 3:
        print(f"{pic:12s} FAIL: no input saved"); ok = False; continue
    open(src, "wb").write(inp)
    for op in CASES[tag]:
        n = name(tag, op)
        ref = os.path.join(work, n)
        arg = f"t{op[1]}" if op[0] == "t" else str(op[0])
        r = subprocess.run([tool, src, str(w), str(h), ref, arg, str(op[1])], capture_output=True, text=True)
        label = f"{pic} " + (f"turn {op[1]}" if op[0] == "t" else f"{OPS[op[0]]} {op[1]}")
        got = ours(n)
        want = open(ref, "rb").read()
        if got == want:
            print(f"{label:28s} OK")
        else:
            ok = False
            diff = "missing" if got is None else (f"{len(got)} bytes, want {len(want)}" if len(got) != len(want)
                   else f"{sum(a != b for a, b in zip(got, want))} bytes differ, first at {next(i for i in range(len(got)) if got[i] != want[i])}")
            print(f"{label:28s} FAIL: {diff}")
sys.exit(0 if ok else 1)
