#!/bin/bash
# Works SuperConvert's main windows with the mouse (the CLICK test command): chooses
# IBM PC & compatibles in Load formats, asks for Info on format, double-clicks the
# Windows bitmap format, which loads a picture through the file dialog (keys typed into
# the emulator), chooses $C1 in Save formats and saves with Save..., and checks the file
# against GS Remap's.
cd "$(dirname "$0")/.."
[ -d build/fixtures/true ] || python3 -I test/make_true.py build/fixtures/true > /dev/null
(cd test/sc4save && swift build -c release > /dev/null 2>&1)
COMMANDS=test/desk.test UI_PICTURE=build/fixtures/true/B24.BMP UI_TYPE=060000 \
    KEYS="53:return,57:SU,60:return,140:OUT,145:return" RUN_SECONDS=300 DUMP_EVERY=10 \
    ./test/run.sh > /dev/null
python3 -I test/check_desk.py
