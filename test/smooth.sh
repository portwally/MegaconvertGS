#!/bin/bash
# Screen > Convert to true color of a 640 mode screen image (docs/superconvert-truecolor.md
# 10): Exact (GS Remap's conversion) and Smoothed (dither patterns become one colour,
# against test/smooth_model.py), chosen with the SMOOTH test command; then the window
# itself (Smoothed chosen with S and OK, then remembered), and none for a 320 mode image.
cd "$(dirname "$0")/.."
[ -f build/fixtures/S640.c1 ] || ./test/fixtures.sh > /dev/null
COMMANDS=test/smooth.test KEYS="80:s,82:return,100:return" RUN_SECONDS=300 DUMP_EVERY=60 ./test/run.sh > /dev/null
python3 -I test/check_smooth.py
