#!/bin/bash
# The Apple II save formats (HiRes and Double HiRes, colour and black & white): screens
# saved in the emulator, each file compared byte for byte with test/check_a2save.py's
# model of them, made from the same screen saved as $C1.
cd "$(dirname "$0")/.."
[ -f build/fixtures/S320.c1 ] || ./test/fixtures.sh > /dev/null
python3 -I test/make_apple.py build/fixtures/apple build/fixtures > /dev/null
python3 -I test/check_a2save.py commands > build/a2save.test
COMMANDS=build/a2save.test RUN_SECONDS="${RUN_SECONDS:-900}" DUMP_EVERY=100 ./test/run.sh > /dev/null
python3 -I test/check_a2save.py
