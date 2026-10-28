#!/bin/bash
# The image window's tools (docs/superconvert-image-window.md 6-8), through the DESK test
# command: selections dragged in the picture (new, moved, a corner, an edge, at 2X zoom,
# a double click for all of it), snapped to bytes or pixels; the pointer's shape codes;
# the keys that bring a part into view; pixel peek; Copy of a selection; Crop to
# selection for a screen, a true colour and a monochrome image; Discard this and other
# image types; Use image's palette; Apple-w. Results are checked against the documented behaviour and the
# cropped pictures against crops made here.
cd "$(dirname "$0")/.."
[ -f build/fixtures/S320.c1 ] || ./test/fixtures.sh > /dev/null
[ -d build/fixtures/true ] || python3 -I test/make_true.py build/fixtures/true > /dev/null
COMMANDS=test/tools.test RUN_SECONDS=400 DUMP_EVERY=50 ./test/run.sh > /dev/null
python3 -I test/check_tools.py
