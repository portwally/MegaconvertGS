#!/bin/bash
# Loads every Apple II and IIgs test file in the emulator, by its format and
# (where MegaconvertGS can tell) by itself, and compares the results with GS Remap.
cd "$(dirname "$0")/.."
[ -f build/fixtures/S320.c1 ] || ./test/fixtures.sh > /dev/null
python3 -I test/make_apple.py build/fixtures/apple build/fixtures > /dev/null
python3 -I - > build/apple.test <<'PY'
for line in open("build/fixtures/apple.list"):
    name, fmt, *auto = line.split()
    print(f"LOAD AS {fmt} *:MCAPPLE:{name}")
    print(f"SAVE C1 *:MCOUT:{name}.C")
    print(f"SAVE RGB *:MCOUT:{name}.R")
    if auto: print(f"LOAD *:MCAPPLE:{name}")
print("SHOW")
PY
COMMANDS=build/apple.test RUN_SECONDS="${RUN_SECONDS:-1500}" DUMP_EVERY=100 ./test/run.sh > /dev/null
python3 -I test/check_apple.py
