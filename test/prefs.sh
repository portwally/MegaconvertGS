#!/bin/bash
# Preferences (docs/superconvert-extras.md 2.5): options set with the PREF test command,
# saved to 9:MCGS.Prefs (PREFSAVE), cleared, read back (PREFLOAD); the dialog opened from
# the menu and closed with Return (OK) keeps them; the file's 16 bytes are checked.
cd "$(dirname "$0")/.."
COMMANDS=test/prefs.test KEYS="58:return,70:return" RUN_SECONDS=150 DUMP_EVERY=30 ./test/run.sh > /dev/null
D=build/test/prefs_file; mkdir -p "$D"
VOL=$(cp System604.img build/vol.po; cadius CATALOG build/vol.po | awk '/^\//{print $1; exit}'; rm -f build/vol.po)
(cd "$D" && cadius EXTRACTFILE ../after.po "${VOL}System/MCGS.Prefs" . > /dev/null 2>&1)
python3 -I test/check_prefs.py
