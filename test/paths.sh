#!/bin/bash
# The folders the file dialogs open in (docs/superconvert-file.md 2.1 and 5): Open starts
# in the folder of the last load, Save in the folder of the last save, and File > Exchange
# load/save paths swaps the two. The dialogs are worked with Return (open the first file,
# save under the name offered); the PATHS test command logs the folders kept.
cd "$(dirname "$0")/.."
[ -f build/fixtures/S320.c1 ] || ./test/fixtures.sh > /dev/null
cp System604.img build/vol.po                          # (cadius goes by the extension)
VOL=$(cadius CATALOG build/vol.po | awk '/^\//{print $1; exit}' | tr / :); rm -f build/vol.po
sed "s/:VOL:/$VOL/g" test/paths.test > build/paths.test
KEYS=$(python3 -I -c "print(','.join(f'{t}:return' for t in range(60, 400, 8)))")
COMMANDS=build/paths.test KEYS="$KEYS" RUN_SECONDS=400 DUMP_EVERY=50 ./test/run.sh > /dev/null
python3 -I test/check_paths.py "$VOL"
