#!/bin/bash
# Screen > Oscilloscope Art (docs/superconvert-extras.md 4.3) on a 320 and a 640 mode
# screen, checked byte for byte against test/check_oscope.py's model of the original.
cd "$(dirname "$0")/.."
[ -f build/fixtures/S320.c1 ] || ./test/fixtures.sh > /dev/null
COMMANDS=test/oscope.test RUN_SECONDS=200 DUMP_EVERY=50 ./test/run.sh > /dev/null
python3 -I test/check_oscope.py
