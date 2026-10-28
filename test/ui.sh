#!/bin/bash
# Opens a picture and saves it again through the real menus and file dialogs.
# MAME can't send Command-key shortcuts, so the menu items come from test/ui.test;
# the dialogs are answered with typed keys.
cd "$(dirname "$0")/.."
COMMANDS=test/ui.test UI_PICTURE=build/fixtures/S320.apf \
    KEYS="60:SU,63:return,80:OUT,84:return" RUN_SECONDS=100 DUMP_EVERY=10 ./test/run.sh > /dev/null
python3 -I test/check_ui.py
