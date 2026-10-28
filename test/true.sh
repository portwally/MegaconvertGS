#!/bin/bash
# Loads every true colour test picture in the emulator, saves what MegaconvertGS
# decoded and how it remapped it, and compares both with GS Remap.
cd "$(dirname "$0")/.."
[ -d build/fixtures/true ] || python3 -I test/make_true.py build/fixtures/true
python3 -I - > build/true.test <<'PY'
import os
for n in sorted(os.listdir("build/fixtures/true")):
    print(f"LOAD *:MCTRUE:{n}")
    print(f"SAVE RGB *:MCOUT:{n}.R")
    print(f"SAVE C1 *:MCOUT:{n}.C")
print("SHOW")
PY
COMMANDS=build/true.test RUN_SECONDS="${RUN_SECONDS:-1800}" DUMP_EVERY=60 ./test/run.sh > /dev/null
python3 -I test/check_true.py
