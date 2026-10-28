#!/bin/bash
# Times saving in each format, each true colour filter and the monochrome conversions in
# the emulator (TIMING 1: each command's ticks), and prints the seconds each one took.
# Not a check: the save, filters and mono suites check the results.
cd "$(dirname "$0")/.."
[ -f build/fixtures/S320.c1 ] || ./test/fixtures.sh > /dev/null
[ -f build/fixtures/true/PHOTO.PNG ] || python3 -I test/make_true.py build/fixtures/true > /dev/null
python3 -I - > build/timing.test <<'PY'
print("TIMING 1")
print("LOAD AS png *:MCTRUE:RGB8.PNG")
for f in ["c1", "apf", "packed", "pw", "hex", "gif", "png", "tiff"]:
    print(f"SAVE AS {f} *:MCOUT:T.{f.upper()}")
print("SAVE RGB *:MCOUT:T.RGB")
print("SNAP")
for k in range(10):
    print(f"FILTER {k}")
    print("BACK")
for k in (2, 0):
    for m in range(1, 5):
        print(f"MONO {k} 1 1 {m}")
print("MONOOUT 0 1 1 1 1")
print("MONOOUT 2 1 1 1 1")
print("LOAD AS c1 *:MCTEST:S640.C1")
for f in ["gif", "png", "tiff"]:
    print(f"SAVE AS {f} *:MCOUT:U.{f.upper()}")
print("SHOW")
PY
COMMANDS=build/timing.test RUN_SECONDS="${RUN_SECONDS:-3000}" DUMP_EVERY=600 ./test/run.sh > /dev/null
tr '\r' '\n' < build/test/results/MC.LOG#040000 | python3 -I -c '
import sys, re
prev = None
for line in sys.stdin:
    line = line.rstrip()
    m = re.match(r"TIME \$([0-9A-F]+)", line)
    if not m:
        prev = line
    elif prev and not prev.startswith(("BACK", "SNAP", "TIMING", "SHOW")):
        print(f"{int(m.group(1), 16) / 60:7.1f} s  {prev.split(": ok")[0]}")
'
