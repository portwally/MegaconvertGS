#!/bin/bash
# Babelfish (src/Babel.s): SuperConvert's True Color and PixelMap imports and exports
# through Seven Hills' freeware translators, installed on the test disk from the
# Babelfish archive (BABELFISH: babelfish.bxy from speccie.uk; build/babelfish/ or
# ~/Downloads/ by default; without it the suite is skipped). Imports by the translator
# ranking the file best or by name (BFNAME), compared with the same files loaded
# directly; exports loaded back; Re-convert last file through the same translator.
# A second run with Babelfish's own dialogs, as a person uses them (Load & convert and
# Save conversion, keys typed into them); a third, short one without Babelfish: the
# start-up error.
cd "$(dirname "$0")/.."
BF="${BABELFISH:-}"
[ -z "$BF" ] && [ -f build/babelfish/babelfish.bxy ] && BF="$PWD/build/babelfish/babelfish.bxy"
[ -z "$BF" ] && [ -f "$HOME/Downloads/babelfish.bxy" ] && BF="$HOME/Downloads/babelfish.bxy"
if [ -z "$BF" ]; then echo "babelfish.bxy not found: skipped OK"; exit 0; fi
mkdir -p build/fixtures/babel
python3 -I - <<'PY'
# BIG.PPM: a raw PPM larger than 64K, so the translator sends it in several blocks.
w, h = 300, 250
rows = bytearray()
for y in range(h):
    for x in range(w):
        rows += bytes(((x * 7 + y) & 255, (y * 3) & 255, (x ^ y) & 255))
open("build/fixtures/babel/BIG.PPM", "wb").write(b"P6\n%d %d\n255\n" % (w, h) + rows)
open("build/fixtures/babel.types", "w").write("BIG.PPM 060000\n")
PY
COMMANDS=test/babel.test BABELFISH="$BF" RUN_SECONDS=700 DUMP_EVERY=100 ./test/run.sh > /dev/null
rm -rf build/babel1; cp -R build/test/results build/babel1
COMMANDS=test/babel3.test BABELFISH="$BF" KEYS="80:S640.A,83:return,105:return" RUN_SECONDS=200 DUMP_EVERY=50 \
    ./test/run.sh > /dev/null
rm -rf build/babel3; cp -R build/test/results build/babel3
COMMANDS=test/babel2.test RUN_SECONDS=150 DUMP_EVERY=50 ./test/run.sh > /dev/null
python3 -I test/check_babel.py
