#!/bin/bash
# Saves several pictures in every save format in the emulator and compares the files
# with GS Remap's (test/sc4save, built on GS Remap's engine).
cd "$(dirname "$0")/.."
[ -f build/fixtures/S320.c1 ] || ./test/fixtures.sh > /dev/null
[ -d build/fixtures/true ] || python3 -I test/make_true.py build/fixtures/true > /dev/null
python3 -I test/make_apple.py build/fixtures/apple build/fixtures > /dev/null
(cd test/sc4save && swift build -c release > /dev/null 2>&1)
python3 -I test/save_list.py commands > build/save.test
COMMANDS=build/save.test RUN_SECONDS="${RUN_SECONDS:-1500}" DUMP_EVERY=100 ./test/run.sh > /dev/null
python3 -I test/check_save.py
