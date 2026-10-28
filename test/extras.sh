#!/bin/bash
# The Extras menu's font commands (docs/superconvert-extras.md 5.1, 5.2): Available font
# list and More available fonts make 640 mode screen images listing the installed fonts in
# themselves; Font key chart (the Font Manager's dialog closed with Return) draws a font's
# characters with their codes and keys. Checked: the images are made, in 640 mode with the
# standard colours, the next page starts with the font the first one broke at, and the key
# chart has its code labels in green and red.
cd "$(dirname "$0")/.."
COMMANDS=test/extras.test KEYS="60:return" RUN_SECONDS=200 DUMP_EVERY=50 ./test/run.sh > /dev/null
python3 -I test/check_extras.py
