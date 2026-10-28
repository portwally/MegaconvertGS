#!/bin/bash
# Loads every test file of the other computers' formats in the emulator, by its format
# and (where MegaconvertGS can tell) by itself, and compares the results with GS Remap.
cd "$(dirname "$0")/.."
python3 -I test/make_other.py build/fixtures/other > /dev/null
python3 -I - > build/other.test <<'PY'
for line in open("build/fixtures/other.list"):
    name, fmt, *auto = line.split()
    print(f"LOAD AS {fmt} *:MCOTHER:{name}")
    print(f"SAVE C1 *:MCOUT:{name}.C")
    print(f"SAVE RGB *:MCOUT:{name}.R")
    if auto: print(f"LOAD *:MCOTHER:{name}")
print("SHOW")
PY
COMMANDS=build/other.test RUN_SECONDS="${RUN_SECONDS:-3000}" DUMP_EVERY=200 ./test/run.sh > /dev/null
python3 -I test/check_other.py
