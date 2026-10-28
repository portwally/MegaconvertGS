#!/bin/bash
# Runs every emulator test suite, one after the other, and says which passed.
# Each suite's full report goes to build/suite_<name>.txt.
cd "$(dirname "$0")/.."
./build.sh > /dev/null || { echo "build failed"; exit 1; }
[ -f build/fixtures/S320.c1 ] || ./test/fixtures.sh > /dev/null
failed=0
suite() {
    local name="$1"; shift
    if "$@" > "build/suite_$name.txt" 2>&1; then
        echo "$name: ok ($(grep -c "OK" "build/suite_$name.txt") checks)"
    else
        echo "$name: FAILED"; grep "FAIL" "build/suite_$name.txt" | head -10; failed=1
    fi
}
suite basic bash -c 'COMMANDS=test/basic.test RUN_SECONDS=200 ./test/run.sh > /dev/null && python3 -I test/check_basic.py'
suite remap bash -c 'COMMANDS=test/remap.test RUN_SECONDS=400 ./test/run.sh > /dev/null && python3 -I test/check_remap.py'
suite ui ./test/ui.sh
suite true ./test/true.sh
suite apple ./test/apple.sh
suite other ./test/other.sh
suite save ./test/save.sh
suite remap2 ./test/remap2.sh
suite dialog ./test/dialog.sh
suite desk ./test/desk.sh
suite filters ./test/filters.sh
suite mono ./test/mono.sh
suite desktop ./test/desktop.sh
suite paths ./test/paths.sh
suite edit ./test/edit.sh
suite tools ./test/tools.sh
suite loadconv ./test/loadconv.sh
suite prefs ./test/prefs.sh
suite extras ./test/extras.sh
suite smooth ./test/smooth.sh
suite savedlg ./test/savedlg.sh
suite sysinfo ./test/sysinfo.sh
suite examine ./test/examine.sh
suite oscope ./test/oscope.sh
suite woa ./test/woa.sh
suite deskinit ./test/deskinit.sh
suite help ./test/help.sh
suite tiffopt ./test/tiffopt.sh
exit $failed
