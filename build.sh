#!/bin/bash
# Assembles MegaconvertGS with Merlin 32.
#   MERLIN32   path to the Merlin32 binary (default: the copy in ~/Downloads)
set -e
ROOT="$(cd "$(dirname "$0")" && pwd)"
MERLIN32="${MERLIN32:-$HOME/Downloads/Merlin32_v1.2_b2/MacOs/Merlin32}"
[ -x "$MERLIN32" ] || MERLIN32="$HOME/Downloads/Merlin32_v1.2_b2 2/MacOs/Merlin32"
mkdir -p "$ROOT/build"
python3 -I "$ROOT/test/labels.py" "$ROOT/src"      # (duplicate local labels: Merlin takes the first)
cd "$ROOT/src"
"$MERLIN32" -V "$ROOT/src/macros" link.s > "$ROOT/build/merlin.log" 2>&1 || { tail -20 "$ROOT/build/merlin.log"; exit 1; }
grep -iE "error" "$ROOT/build/merlin.log" && exit 1
mv -f MegaconvertGS "$ROOT/build/MegaconvertGS"
mv -f MegaconvertGS_*_Output.txt MegaconvertGS_Symbols.txt _FileInformation.txt "$ROOT/build/" 2>/dev/null || true
tr '\n' '\r' < "$ROOT/help/MCGS.Help.txt" > "$ROOT/build/MCGS.Help"   # (the help text, beside the program)
python3 -I "$ROOT/art/make_title.py" "$ROOT/art/MegaconvertGS_Title.shr" "$ROOT/build/MCGS.Title"   # (the title picture, beside it too)
echo "built build/MegaconvertGS ($(wc -c < "$ROOT/build/MegaconvertGS") bytes)"
