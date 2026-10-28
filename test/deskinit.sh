#!/bin/bash
# Save as Desktop background image INIT (docs/superconvert-formats-extra.md 2): a 320 and a
# 640 mode screen saved, each file checked as an OMF load file holding MegaconvertGS's own
# INIT code and the packed desktop message.
cd "$(dirname "$0")/.."
[ -f build/fixtures/S320.c1 ] || ./test/fixtures.sh > /dev/null
COMMANDS=test/deskinit.test RUN_SECONDS=120 DUMP_EVERY=50 ./test/run.sh > /dev/null
python3 -I test/check_deskinit.py
