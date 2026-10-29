#!/bin/bash
# Times fitted remaps of pictures larger than the screen (the TIMING 1 test command logs
# each command's ticks) and compares every screen made with the ones a run with
# REMAP_REF=1 kept (build/remapref): the same bytes, or a difference is reported.
# Not part of all.sh: the true and remap2 suites check the remaps against GS Remap.
cd "$(dirname "$0")/.."
[ -f build/fixtures/true/HUGE.PNG ] || python3 -I test/make_true.py build/fixtures/true > /dev/null
python3 -I - > build/remaptime.test <<'PY'
print("TIMING 1")
runs = [("H", "MCTRUE:HUGE.PNG"), ("B", "MCTRUE:BIG.PNG")]
for tag, path in runs:
    print(f"LOAD *:{path}")
    for m, (mode, pal, alg, other) in enumerate([(0, 0, 1, 0), (1, 0, 1, 0), (2, 0, 2, 0), (3, 0, 1, 0), (0, 2, 0, 0)]):
        print(f"REMAP WITH {mode} {pal} {alg} 255 255 {other}")
        print(f"SAVE C1 *:MCOUT:{tag}{m}.C")
    print(f"REMAP WITH 0 0 1 4 4 0")
    print(f"SAVE C1 *:MCOUT:{tag}S.C")
print("SHOW")
PY
COMMANDS=build/remaptime.test RUN_SECONDS="${RUN_SECONDS:-3000}" DUMP_EVERY=600 ./test/run.sh > /dev/null
if [ -n "$REMAP_REF" ]; then
    rm -rf build/remapref; mkdir -p build/remapref
    cp build/test/results/MCOUT/* build/remapref/
fi
tr '\r' '\n' < build/test/results/MC.LOG#040000 | python3 -I -c '
import sys, re, os
prev = None; total = 0; ok = True
lines = [l.rstrip() for l in sys.stdin]
for i, line in enumerate(lines):
    m = re.match(r"TIME \$([0-9A-F]+)", line)
    if not m:
        prev = line; continue
    if prev.startswith("REMAP") or prev.startswith("LOAD"):
        t = int(m.group(1), 16) / 60
        if prev.startswith("REMAP"): total += t
        print(f"{t:7.1f} s  {prev.split(": ")[0]}")
    elif prev.startswith("SAVE C1"):
        name = prev.split("MCOUT:")[1].split(":")[0]
        got = [f for f in os.listdir("build/test/results/MCOUT") if f.split("#")[0] == name]
        ref = [f for f in os.listdir("build/remapref") if f.split("#")[0] == name] if os.path.isdir("build/remapref") else []
        if not got: print(f"          {name}: not saved"); ok = False
        elif ref:
            a = open("build/test/results/MCOUT/" + got[0], "rb").read(); b = open("build/remapref/" + ref[0], "rb").read()
            if a != b:
                print(f"          {name}: DIFFERS from the reference"); ok = False
print(f"remaps {total:.1f} s", "all the same" if ok else "PROBLEMS")
'
