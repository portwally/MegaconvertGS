#!/bin/bash
# Boots MegaconvertGS in MAME (from Ample) in a window and saves pictures of the screen.
# Window mode on purpose: full-screen MAME blanks the Mac's display.
#   BOOT_DISK   System 6 hard disk image to start from (copied, never changed)
#   RUN_SECONDS emulated seconds to run (default 240)
#   SC4         GS Remap command-line tool, used to turn screen dumps into PNG files
#   UI_PICTURE  a file put on the disk as SUNSET (for KEYS tests), of type UI_TYPE
#               (type and aux type, default C00002: Apple Preferred); a file
#               saved as OUT, also at the top of the disk, is copied back to build/test/results
#   KEYS        keys to press, see dump.lua
#   TITLE       1: the title picture (MCGS.Title) beside the program
#   BABELFISH   the Babelfish archive (babelfish.bxy): installed on the disk
#   COMMANDS    test command file to run (copied to the disk as MC.TEST); its pictures
#               come from build/fixtures (folder MCTEST) and build/fixtures/true (folder
#               MCTRUE), and results go to folder MCOUT
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BOOT_DISK="${BOOT_DISK:-$ROOT/System604.img}"
RUN_SECONDS="${RUN_SECONDS:-240}"
MAME="${MAME:-/Applications/Emulatoren/Ample.app/Contents/MacOS/mame64}"
ROMS="${ROMS:-$HOME/Library/Application Support/Ample/roms}"
SC4="${SC4:-$HOME/Documents/GS Remap/.build/release/sc4}"
OUT="$ROOT/build/test"

rm -rf "$OUT"; mkdir -p "$OUT/stage" "$OUT/screens"
# cadius recognises the disk format by its extension, so the copy keeps it.
EXT="${BOOT_DISK##*.}"; [ "$EXT" = "img" ] && EXT=po     # .img here means raw ProDOS order
DISK="$OUT/boot.$EXT"
cp "$BOOT_DISK" "$DISK"
# The program takes the Finder's place, so GS/OS starts it as soon as it has booted.
# A startup program chosen with Set Start (System/SetStart.data) would win, so that goes too.
VOLUME="$(cadius CATALOG "$DISK" | awk '/^\//{print $1; exit}')"
# cadius exits 0 even when it fails, so look for its error lines instead.
disk() { local out; out="$(cadius "$@" 2>&1)"; if grep -q "Error" <<< "$out"; then echo "$out" >&2; exit 1; fi; }
cp "$ROOT/build/MegaconvertGS" "$OUT/stage/Finder#B3DB03"
disk DELETEFILE "$DISK" "${VOLUME}System/Finder"
cadius DELETEFILE "$DISK" "${VOLUME}System/SetStart.data" > /dev/null 2>&1 || true
disk ADDFILE "$DISK" "${VOLUME}System" "$OUT/stage/Finder#B3DB03"
# Its help text beside it (prefix 1 is the program's folder).
cp "$ROOT/build/MCGS.Help" "$OUT/stage/MCGS.Help#040000"
disk ADDFILE "$DISK" "${VOLUME}System" "$OUT/stage/MCGS.Help#040000"
# The title picture only when asked for (TITLE=1): the tests start without it.
if [ -n "$TITLE" ]; then
    cp "$ROOT/build/MCGS.Title" "$OUT/stage/MCGS.Title#C10000"
    disk ADDFILE "$DISK" "${VOLUME}System" "$OUT/stage/MCGS.Title#C10000"
fi

if [ -n "$BABELFISH" ]; then
    # Babelfish (Seven Hills' freeware file translators, babelfish.bxy from
    # speccie.uk; BABELFISH is the archive's path) installed as its Read Me says:
    # the INITs, the Convert File NDA and the translators' folder.
    rm -rf "$OUT/bf"; mkdir -p "$OUT/bf"
    (cd "$OUT/bf" && nulib2 -xe "$BABELFISH" > /dev/null)
    BF="$OUT/bf/Babelfish/System"
    bfadd() {   # folder on the disk, file without its #type
        local src="$1" dir="$2" f n t
        for f in "$src"#??????; do
            n="$(basename "$f")"; t="$(echo "${n##*#}" | tr a-f A-F)"
            mkdir -p "$OUT/stage/bf"; rm -f "$OUT/stage/bf/"*
            cp "$f" "$OUT/stage/bf/${n%#*}#$t"
            [ -f "${f}r" ] && cp "${f}r" "$OUT/stage/bf/${n%#*}#${t}_ResourceFork.bin"
            disk ADDFILE "$DISK" "$dir" "$OUT/stage/bf/${n%#*}#$t"
        done
    }
    bfadd "$BF/System.Setup/Babelfish" "${VOLUME}System/System.Setup"
    bfadd "$BF/System.Setup/SFUtility" "${VOLUME}System/System.Setup"
    bfadd "$BF/Desk.Accs/Convert.NDA" "${VOLUME}System/Desk.Accs"
    disk CREATEFOLDER "$DISK" "${VOLUME}System/SHS.Babelfish"
    for f in "$BF"/SHS.Babelfish/*#??????; do
        case "$f" in *Finder.Data*) continue;; esac
        bfadd "${f%#*}" "${VOLUME}System/SHS.Babelfish"
    done
fi

if [ -n "$COMMANDS" ]; then
    disk CREATEFOLDER "$DISK" "${VOLUME}MCTEST"
    disk CREATEFOLDER "$DISK" "${VOLUME}MCOUT"
    for f in "$ROOT"/build/fixtures/S*.c1 "$ROOT"/build/fixtures/S*.apf "$ROOT"/build/fixtures/S*.packed "$ROOT"/build/fixtures/S*.pw; do
        n="$(basename "$f")"; base="${n%.*}"; ext="${n##*.}"
        case "$ext" in c1) t="C10000"; e=C1;; apf) t="C00002"; e=APF;; packed) t="C00001"; e=PACK;; pw) t="C00000"; e=PW;; esac
        cp "$f" "$OUT/stage/$base.$e#$t"
        disk ADDFILE "$DISK" "${VOLUME}MCTEST" "$OUT/stage/$base.$e#$t"
    done
    if [ -d "$ROOT/build/fixtures/true" ]; then
        # True colour pictures (folder MCTRUE), as binary files.
        disk CREATEFOLDER "$DISK" "${VOLUME}MCTRUE"
        for f in "$ROOT"/build/fixtures/true/*; do
            cp "$f" "$OUT/stage/$(basename "$f")#060000"
            disk ADDFILE "$DISK" "${VOLUME}MCTRUE" "$OUT/stage/$(basename "$f")#060000"
        done
    fi
    for group in apple other filter woa newfmt jspeed babel; do
        # More test files (folders MCAPPLE, MCOTHER, MCFILTER, MCWOA, MCNEWFMT, MCJSPEED, MCBABEL), with the file types they need.
        [ -f "$ROOT/build/fixtures/$group.types" ] || continue
        folder="MC$(echo $group | tr a-z A-Z)"
        disk CREATEFOLDER "$DISK" "${VOLUME}$folder"
        while read -r name type; do
            cp "$ROOT/build/fixtures/$group/$name" "$OUT/stage/$name#$type"
            disk ADDFILE "$DISK" "${VOLUME}$folder" "$OUT/stage/$name#$type"
        done < "$ROOT/build/fixtures/$group.types"
    done
    tr '\n' '\r' < "$COMMANDS" > "$OUT/stage/MC.TEST#040000"
    disk ADDFILE "$DISK" "${VOLUME}" "$OUT/stage/MC.TEST#040000"
fi

if [ -n "$UI_PICTURE" ]; then
    # A picture at the top of the disk, where the Open dialog starts.
    cp "$UI_PICTURE" "$OUT/stage/SUNSET#${UI_TYPE:-C00002}"
    disk ADDFILE "$DISK" "${VOLUME}" "$OUT/stage/SUNSET#${UI_TYPE:-C00002}"
fi

# The hard-disk card wants the raw blocks: drop a 2IMG header if there is one.
python3 -I - "$DISK" "$OUT/raw.hdv" <<'PY'
import sys, struct
d = open(sys.argv[1], "rb").read()
if d[:4] == b"2IMG":
    start, length = struct.unpack_from("<II", d, 24)
    d = d[start:start + length]
open(sys.argv[2], "wb").write(d)
PY

KEYS="$KEYS" DUMP_DIR="$OUT/screens" DUMP_EVERY="${DUMP_EVERY:-30}" "$MAME" apple2gs -ramsize 4M -rompath "$ROMS" \
    -sl7 cffa2 -hard1 "$OUT/raw.hdv" -window -nomaximize -sound none -cfg_directory "$OUT/mame" -nvram_directory "$OUT/mame" -snapshot_directory "$OUT/mame" -nothrottle -skip_gameinfo \
    -seconds_to_run "$RUN_SECONDS" -autoboot_script "$ROOT/test/dump.lua" > "$OUT/mame.log" 2>&1

if [ -n "$COMMANDS" ]; then
    # Pull the results back off the disk the emulator wrote to.
    mkdir -p "$OUT/results"
    cp "$OUT/raw.hdv" "$OUT/after.po"
    (cd "$OUT/results" && cadius EXTRACTFOLDER "$OUT/after.po" "${VOLUME}MCOUT" . > /dev/null 2>&1; \
        cadius EXTRACTFILE "$OUT/after.po" "${VOLUME}MC.LOG" . > /dev/null 2>&1) || true
fi
if [ -n "$UI_PICTURE" ]; then
    mkdir -p "$OUT/results"
    cp "$OUT/raw.hdv" "$OUT/after.po"
    (cd "$OUT/results" && cadius EXTRACTFILE "$OUT/after.po" "${VOLUME}OUT" . > /dev/null 2>&1) || true
fi

for f in "$OUT"/screens/*.shr; do "$SC4" view "$f" "${f%.shr}.png"; done
ls "$OUT"/screens/*.png
