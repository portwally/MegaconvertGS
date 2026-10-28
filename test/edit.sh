#!/bin/bash
# The Edit menu (docs/superconvert-extras.md 3): Copy and Cut put the screen image on the
# Clipboard as a QuickDraw II picture with its first colour table as a $8002 scrap (the
# SAVE SCRAP test command draws the picture back into a screen and logs the colours);
# Cut then discards the screen image, Close every image (the IMAGES test command). A
# multipalette picture gets the warning, which Return dismisses.
cd "$(dirname "$0")/.."
[ -f build/fixtures/S320.c1 ] || ./test/fixtures.sh > /dev/null
[ -d build/fixtures/true ] || python3 -I test/make_true.py build/fixtures/true > /dev/null
KEYS=$(python3 -I -c "print(','.join(f'{t}:return' for t in range(60, 900, 10)))")
COMMANDS=test/edit.test KEYS="$KEYS" RUN_SECONDS=900 DUMP_EVERY=5 ./test/run.sh > /dev/null
python3 -I test/check_edit.py
