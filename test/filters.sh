#!/bin/bash
# Runs the True color filters and rotate/flip on test pictures in the emulator (the FILTER
# and TURN test commands) and compares each result with GS Remap's (test/sc4save's
# sc4filter, applied to the picture as MegaconvertGS loaded it), byte for byte.
cd "$(dirname "$0")/.."
python3 -I test/make_filter.py build/fixtures/filter
(cd test/sc4save && swift build -c release > /dev/null 2>&1)
python3 -I test/filters_list.py > build/filters.test
COMMANDS=build/filters.test RUN_SECONDS="${RUN_SECONDS:-1500}" DUMP_EVERY=60 ./test/run.sh > /dev/null
python3 -I test/check_filters.py
