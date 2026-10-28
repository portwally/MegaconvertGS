#!/bin/bash
# Help! and the help window (docs/superconvert-extras.md 2.2-2.4) with MegaconvertGS's own
# help text: the file checked (pages named exist, every menu item has one), and pages opened
# with the HELP test command (and Help!) laid out as test/check_help.py's model says; a
# topic button and the info bar's Back clicked (CLICK) go to their pages.
cd "$(dirname "$0")/.."
COMMANDS=test/help.test RUN_SECONDS=150 DUMP_EVERY=50 ./test/run.sh > /dev/null
python3 -I test/check_help.py
