#!/bin/bash
# Screen > Use as desktop background and Extras > Revert to normal desktop: the desktop
# message each leaves (the SAVE DESK test command) is checked against the original's
# layout (docs/superconvert-extras.md 4.2) for a full 640 screen, a small picture
# (centred), one of 188 lines (at the bottom) and a full 320 screen. Then View half size
# and Histogram equalization are chosen from the menus (Esc ends the view and cancels the
# Remap dialog that follows the filter), and the filter's result is checked against
# GS Remap's.
cd "$(dirname "$0")/.."
[ -f build/fixtures/S640.c1 ] || ./test/fixtures.sh > /dev/null
[ -d build/fixtures/true ] || python3 -I test/make_true.py build/fixtures/true > /dev/null
(cd test/sc4save && swift build -c release > /dev/null 2>&1)
KEYS=$(python3 -I -c "print(','.join(f'{t}:esc' for t in range(150, 1000, 12)))")
COMMANDS=test/desktop.test KEYS="$KEYS" RUN_SECONDS=1000 DUMP_EVERY=50 ./test/run.sh > /dev/null
python3 -I test/check_desktop.py
