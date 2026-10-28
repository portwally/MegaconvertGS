#!/bin/bash
# Remaps pictures with every mode, palette and rendering in the emulator, and compares
# the screens with GS Remap's (test/sc4save's sc4remap).
cd "$(dirname "$0")/.."
[ -f build/fixtures/S320.c1 ] || ./test/fixtures.sh > /dev/null
[ -f build/fixtures/true/PHOTO.PNG ] || python3 -I test/make_true.py build/fixtures/true > /dev/null
(cd test/sc4save && swift build -c release > /dev/null 2>&1)
python3 -I test/remap2_list.py commands > build/remap2.test
COMMANDS=build/remap2.test RUN_SECONDS="${RUN_SECONDS:-4000}" DUMP_EVERY=200 ./test/run.sh > /dev/null
python3 -I test/check_remap2.py
