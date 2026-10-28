#!/bin/bash
# Extras > System info report (docs/superconvert-extras.md 5.5): the report built in its
# TextEdit window and saved as a text file (the test's path, without the window's buttons).
# Checked: the title with the version, the five sections in order with their figures, the
# lines broken at spaces past 76 characters, a TXT file.
cd "$(dirname "$0")/.."
COMMANDS=test/sysinfo.test RUN_SECONDS=120 DUMP_EVERY=50 ./test/run.sh > /dev/null
python3 -I test/check_sysinfo.py
