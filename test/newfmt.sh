#!/bin/bash
# MegaconvertGS's own load formats (TGA, PICT, ZX Spectrum, MSX): test files written from known pixels
# (test/make_newfmt.py) loaded in the emulator by their format and by their name, the
# true colour pictures compared pixel for pixel with what was written.
cd "$(dirname "$0")/.."
python3 -I test/make_newfmt.py build/fixtures
python3 -I - > build/newfmt.test <<'PY'
for line in open("build/fixtures/newfmt.list"):
    name, fmt = line.split()
    print(f"LOAD AS {fmt} *:MCNEWFMT:{name}")
    print(f"SAVE RGB *:MCOUT:{name}.R")
    print(f"SAVE C1 *:MCOUT:{name}.C")
    print(f"LOAD *:MCNEWFMT:{name}")
print("SHOW")
PY
COMMANDS=build/newfmt.test RUN_SECONDS="${RUN_SECONDS:-1500}" DUMP_EVERY=200 ./test/run.sh > /dev/null
python3 -I test/check_newfmt.py
