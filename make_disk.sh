#!/bin/bash
# Makes build/MegaconvertGS.po, an 800K ProDOS disk with the program, its help text and its
# title picture, as released. Run ./build.sh first. Needs cadius.
set -e
ROOT="$(cd "$(dirname "$0")" && pwd)"
B="$ROOT/build"
DISK="$B/MegaconvertGS.po"
STAGE="$B/disk"
for f in MegaconvertGS MCGS.Help MCGS.Title; do
    [ -f "$B/$f" ] || { echo "build/$f is missing: run ./build.sh first" >&2; exit 1; }
done
rm -rf "$STAGE" "$DISK"; mkdir -p "$STAGE"
# cadius takes each file's type and aux type from the end of its name.
cp "$B/MegaconvertGS" "$STAGE/MegaconvertGS#B3DB03"     # S16 (GS/OS application)
cp "$B/MCGS.Help" "$STAGE/MCGS.Help#040000"             # TXT
cp "$B/MCGS.Title" "$STAGE/MCGS.Title#C10000"           # PIC (a $C1 screen)
# cadius exits 0 even when it fails, so look for its error lines instead.
disk() { local out; out="$(cadius "$@" 2>&1)"; if grep -q "Error" <<< "$out"; then echo "$out" >&2; exit 1; fi; }
disk CREATEVOLUME "$DISK" MegaconvertGS 800KB
for f in "$STAGE"/*; do disk ADDFILE "$DISK" /MegaconvertGS "$f"; done
rm -rf "$STAGE"
cadius CATALOG "$DISK"
