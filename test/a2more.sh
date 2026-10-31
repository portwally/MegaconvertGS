#!/bin/bash
# More Apple II pictures (Apple.s, Formats.s PairDHR): LZ4FH-packed HiRes (fadden's fhpack,
# type $08/$8066), Double HiRes in two files (NAME.BIN + NAME.AUX, Beagle Graphics and
# bmp2dhr), bmp2dhr's picture pieces (.DHR, .DHM masks) and .A2FM names, and a 320 x 200
# PPM, which is a ComputerEyes file's size. Each is compared with the plain file of the
# same picture loaded as before (test/make_a2more.py makes them from the apple suite's).
# Also Apple Preferred pictures larger than a screen or with MULTIPAL (3200 colors), as
# true colour pictures compared with what GS Remap reads.
cd "$(dirname "$0")/.."
[ -f build/fixtures/S320.c1 ] || ./test/fixtures.sh > /dev/null
python3 -I test/make_apple.py build/fixtures/apple build/fixtures > /dev/null
python3 -I test/make_a2more.py build/fixtures
COMMANDS=test/a2more.test RUN_SECONDS=400 DUMP_EVERY=100 ./test/run.sh > /dev/null
python3 -I test/check_a2more.py
