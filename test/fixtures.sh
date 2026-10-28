#!/bin/bash
# Makes the test pictures in build/fixtures: an original scene, converted by the
# GS Remap command-line tool (SC4) into each Super Hi-Res format under test.
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SC4="${SC4:-$HOME/Documents/GS Remap/.build/release/sc4}"
F="$ROOT/build/fixtures"
rm -rf "$F"; mkdir -p "$F"
python3 -I - "$F/scene.bmp" <<'PY'
# A sunset over water with a few shapes, drawn from scratch and written as a 24-bit BMP.
import sys, math, struct
w, h = 320, 200
rows = []
for y in range(h):
    row = bytearray()
    for x in range(w):
        if y < 120:
            t = y / 120
            r, g, b = 40 + 200 * t, 30 + 90 * t * t, 120 - 40 * t
            if math.hypot(x - 210, y - 95) < 22: r, g, b = 255, 230, 140
            if y > 100 + 10 * math.sin(x / 23): r, g, b = 60, 30, 70
        else:
            t = (y - 120) / 80
            r, g, b = 120 - 80 * t, 50 - 20 * t, 90 - 30 * t
            if abs(x - 210 + 6 * math.sin(y)) < 18 - 10 * t and y % 3: r, g, b = 250, 190, 110
        if 30 < x < 70 and 140 < y < 180: r, g, b = 20, 160, 60          # a green box
        if (x - 60) ** 2 + (y - 40) ** 2 < 300: r, g, b = 230, 230, 255  # a moon
        row += bytes((int(b), int(g), int(r)))
    rows.append(bytes(row))
data = b"".join(reversed(rows))                                         # BMP rows go bottom up
header = struct.pack("<2sIHHI", b"BM", 54 + len(data), 0, 0, 54)
info = struct.pack("<IiiHHIIiiII", 40, w, h, 1, 24, 0, len(data), 2835, 2835, 0, 0)
open(sys.argv[1], "wb").write(header + info + data)
PY
"$SC4" remap "$F/scene.bmp" "$F/S320.c1" > /dev/null
"$SC4" remap "$F/scene.bmp" "$F/S320.apf" > /dev/null
"$SC4" remap "$F/scene.bmp" "$F/S320.packed" > /dev/null
"$SC4" remap "$F/scene.bmp" "$F/S320.pw" > /dev/null
"$SC4" remap "$F/scene.bmp" "$F/S640.apf" --mode 640d --palette calc > /dev/null
"$SC4" remap "$F/scene.bmp" "$F/S640.c1" --mode 640d --palette calc > /dev/null
"$SC4" remap "$F/scene.bmp" "$F/S320.png" > /dev/null
ls -la "$F" | awk 'NR>1{print $5, $9}'
