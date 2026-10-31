#!/bin/bash
# Makes the manual (docs/MegaconvertGS-Manual.pdf): screenshots taken in MAME with the
# sample pictures of GOLDEN (an HDV disk of Apple II and IIgs pictures; its folders go to
# the top of the boot disk),
# then build/manual/manual.html (make_manual.py), printed to PDF by Chrome, twice (the
# second time with the contents' page numbers).
#   GOLDEN     the sample disk (default ~/Downloads/Testbilder/GoldenStandard.hdv)
#   BABELFISH  the Babelfish archive, for its dialog (default build/babelfish/babelfish.bxy)
#   SKIP_SHOTS=1  only the PDF, from the screenshots there are
set -e
cd "$(dirname "$0")/../.."
ROOT="$PWD"
GOLDEN="${GOLDEN:-$HOME/Downloads/Testbilder/GoldenStandard.hdv}"
BABELFISH="${BABELFISH:-$ROOT/build/babelfish/babelfish.bxy}"
SC4="${SC4:-$HOME/Documents/GS Remap/.build/release/sc4}"
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
M="$ROOT/build/manual"; SHOTS="$M/shots"
mkdir -p "$SHOTS"
# A copy of test/run.sh working in build/manual/test, so the tests can run beside it.
RUN="$M/run.sh"
sed -e "s|^ROOT=.*|ROOT=\"$ROOT\"|" -e "s|^OUT=.*|OUT=\"$M/test\"|" test/run.sh > "$RUN"; chmod +x "$RUN"
T="$M/test"
png() { "$SC4" view "$1" "$SHOTS/$2.png" > /dev/null; }      # a $C1 screen or SHR dump
grab() {   # the last screen dump at or before second $1 of the run, as shot $2
    local f; f=$(ls "$T"/screens/screen_*.shr | awk -F_ -v t="$1" '{n=$NF; sub(/\.shr/,"",n); if (n+0 <= t) last=$0} END {print last}')
    png "$f" "$2"
}
if [ -z "$SKIP_SHOTS" ]; then
    [ -n "$NO_BUILD" ] || ./build.sh > /dev/null
    # The boot disk with the samples on it (GOLDEN.STANDARD at the top).
    BOOT="$M/boot.po"; cp "$ROOT/System604.img" "$BOOT"
    rm -rf "$M/golden"; mkdir -p "$M/golden"
    (cd "$M/golden" && cadius EXTRACTVOLUME "$GOLDEN" . > /dev/null)
    find "$M/golden" -name _FileInformation.txt -delete
    VOL="$(cadius CATALOG "$BOOT" | awk '/^\//{print $1; exit}')"
    cadius ADDFOLDER "$BOOT" "$VOL" "$M/golden/GOLDEN.STANDARD" > /dev/null
    png "$ROOT/art/MegaconvertGS_Title.shr" TITLE

    # 1. Windows (SHOT) and results ($C1 saves).
    BOOT_DISK="$BOOT" COMMANDS=docs/manual/shots.test RUN_SECONDS=6000 DUMP_EVERY=300 "$RUN" > /dev/null
    tr '\r' '\n' < "$T/results/MC.LOG#040000" > "$M/main.log" || true
    for f in "$T"/results/MCOUT/*; do
        n="$(basename "$f")"; n="${n%%#*}"
        case "$n" in *.RGB|_FileInformation.txt) ;; *) png "$f" "$n" ;; esac
    done
    # 2. Modal windows, from timed screen dumps: Remap, Preferences, Info on format.
    BOOT_DISK="$BOOT" COMMANDS=docs/manual/dialogs.test KEYS="78:esc,92:esc,108:return" RUN_SECONDS=125 DUMP_EVERY=2 \
        "$RUN" > /dev/null
    grab 76 REMAPDLG; grab 90 PREFS; grab 106 SAVEINFO
    # 3. Babelfish's Open dialog.
    if [ -f "$BABELFISH" ]; then
        BOOT_DISK="$BOOT" BABELFISH="$BABELFISH" COMMANDS=docs/manual/babel.test KEYS="88:esc" RUN_SECONDS=100 DUMP_EVERY=2 \
            "$RUN" > /dev/null
        grab 86 BFOPEN
    fi
fi
# The PDF: once to find the chapters' pages, then with them in the contents.
python3 -I docs/manual/make_manual.py
"$CHROME" --headless --disable-gpu --no-pdf-header-footer --allow-file-access-from-files \
    --print-to-pdf="$M/pass1.pdf" "file://$M/manual.html" 2> /dev/null
python3 -I - "$M/pass1.pdf" "$M/pages.txt" <<'PY'
import subprocess, sys, re
n = int(re.search(r"Pages:\s+(\d+)", subprocess.run(["pdfinfo", sys.argv[1]], capture_output=True, text=True).stdout).group(1))
pages = {}
for p in range(1, n + 1):
    t = subprocess.run(["pdftotext", "-f", str(p), "-l", str(p), sys.argv[1], "-"], capture_output=True, text=True).stdout
    m = re.search(r"CHAPTER (\d+)", t)
    if m and m.group(1) not in pages: pages[m.group(1)] = p
open(sys.argv[2], "w").write("\n".join(f"{k} {v}" for k, v in pages.items()))
PY
PAGES="$M/pages.txt" python3 -I docs/manual/make_manual.py
"$CHROME" --headless --disable-gpu --no-pdf-header-footer --allow-file-access-from-files \
    --print-to-pdf="$ROOT/docs/MegaconvertGS-Manual.pdf" "file://$M/manual.html" 2> /dev/null
echo "docs/MegaconvertGS-Manual.pdf: $(pdfinfo "$ROOT/docs/MegaconvertGS-Manual.pdf" | awk '/Pages/{print $2}') pages"
