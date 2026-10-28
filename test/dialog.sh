#!/bin/bash
# Works the Remap dialog with clicks (the CLICKS test command), remaps through it, and
# compares each screen with GS Remap's for the options the clicks chose.
cd "$(dirname "$0")/.."
[ -f build/fixtures/S320.c1 ] || ./test/fixtures.sh > /dev/null
[ -d build/fixtures/true ] || python3 -I test/make_true.py build/fixtures/true > /dev/null
(cd test/sc4save && swift build -c release > /dev/null 2>&1)
python3 -I test/dialog_list.py commands > build/dialog.test
COMMANDS=build/dialog.test RUN_SECONDS="${RUN_SECONDS:-2000}" DUMP_EVERY=100 ./test/run.sh > /dev/null
python3 -I test/check_dialog.py
