#!/bin/bash
# TIFF Save Options (docs/superconvert-file.md 4.9), answered by the TIFFOPT test command:
# palette images in either byte order (more compatible bits or the fewest), a 640 mode one,
# the true colour image as RGB, and both in one file; read back by test/check_tiffopt.py.
cd "$(dirname "$0")/.."
[ -f build/fixtures/S320.c1 ] || ./test/fixtures.sh > /dev/null
COMMANDS=test/tiffopt.test RUN_SECONDS=400 DUMP_EVERY=100 ./test/run.sh > /dev/null
python3 -I test/check_tiffopt.py
