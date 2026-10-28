#!/bin/bash
# Load & convert (docs/superconvert-file.md 3): the file dialog (SuperConvert's, with its
# check boxes) opened from the menu and a file loaded with Return; the file filter of many
# formats rated over the test folders (the QUEUE test command adds a folder's pictures as
# "Load all pictures within selected folders" does) against test/loadconv_list.py's model;
# Load next loading the queue's files in turn, and Cancel remaining files.
cd "$(dirname "$0")/.."
[ -f build/fixtures/S320.c1 ] || ./test/fixtures.sh > /dev/null
[ -d build/fixtures/true ] || python3 -I test/make_true.py build/fixtures/true > /dev/null
[ -f build/fixtures/apple.types ] || python3 -I test/make_apple.py build/fixtures > /dev/null
[ -f build/fixtures/other.types ] || python3 -I test/make_other.py build/fixtures > /dev/null
cp System604.img build/vol.po                          # (cadius goes by the extension)
VOL=$(cadius CATALOG build/vol.po | awk '/^\//{print $1; exit}' | tr / :); rm -f build/vol.po
python3 -I test/loadconv_list.py commands "$VOL" > build/loadconv.test
COMMANDS=build/loadconv.test KEYS="70:return" RUN_SECONDS=600 DUMP_EVERY=60 ./test/run.sh > /dev/null
python3 -I test/check_loadconv.py
