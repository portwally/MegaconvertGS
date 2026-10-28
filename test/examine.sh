#!/bin/bash
# File > Examine file... (docs/superconvert-file.md 7), without its file dialog: the
# EXAMINE test command opens a file's window, takes steps (the mode buttons, the scroll
# bar's arrows, pages and thumb, the pointer over the histogram) and saves the screen.
# Checked against the files' bytes (S320.C1; Read.Me's two forks, the Keyboard control
# panel's resource fork and the Clipboard file from the System disk): each dump line's
# characters and colours, scrolled lines the same as drawn afresh, the last partial line,
# the start mode and dimmed buttons, the histogram's bars, scales and info line.
cd "$(dirname "$0")/.."
[ -f build/fixtures/S320.c1 ] || ./test/fixtures.sh > /dev/null
COMMANDS=test/examine.test RUN_SECONDS=300 DUMP_EVERY=100 ./test/run.sh > /dev/null
rm -rf build/test/ref; mkdir -p build/test/ref
VOLUME="$(cadius CATALOG build/test/boot.po | awk '/^\//{print $1; exit}')"
for f in Read.Me System/CDevs/Keyboard System/Clipboard; do
    (cd build/test/ref && cadius EXTRACTFILE ../boot.po "$VOLUME$f" . > /dev/null)
done
python3 -I test/check_examine.py
