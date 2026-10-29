#!/bin/bash
# Save conversion's dialogs (docs/superconvert-file.md 4.3-4.6), answered by the SAVEDLG
# test command (size item, alignment item, warning answer): Apple Preferred files of one
# page, two screens high, one screen, a selection's clipping and two screens wide;
# PaintWorks' 396 lines from a clipping; GIF at the original size; the warnings (640 mode
# and multiple colour tables for PaintWorks, cancelled and saved anyway) and the icon size
# limit; Hex data's options (HEXOPT: what goes before, between and after); with SAVEDLG 3
# the formats' own windows, closed with Return: Hex data's options, the GIF upload note and
# progress, the Finder icon's criteria, Apple II save options (its last choices, Pattern
# and Keep proportions, from A2OPT). The files are checked against
# test/savedlg_model.py's pictures and each other.
cd "$(dirname "$0")/.."
[ -f build/fixtures/S320.c1 ] || ./test/fixtures.sh > /dev/null
python3 -I test/make_apple.py build/fixtures/apple build/fixtures > /dev/null
cp System604.img build/vol.po                          # (cadius goes by the extension)
VOL=$(cadius CATALOG build/vol.po | awk '/^\//{print $1; exit}' | tr / :); rm -f build/vol.po
sed "s/:VOL:/$VOL/g" test/savedlg.test > build/savedlg.test
KEYS=$(python3 -I -c "print(','.join(f'{t}:return' for t in range(50, 900, 4)))")
COMMANDS=build/savedlg.test KEYS="$KEYS" RUN_SECONDS=900 DUMP_EVERY=100 ./test/run.sh > /dev/null
python3 -I test/check_savedlg.py
