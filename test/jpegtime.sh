#!/bin/bash
# Times loading JPEG pictures in the emulator and checks each one against libjpeg's
# fast integer decoder (djpeg), as the true suite does. Not part of all.sh.
# The timing photos come from JPEG_PHOTO (any picture ImageMagick reads): 640 x 480 and
# 320 x 200, baseline and progressive, quality 80 (folder MCJSPEED).
cd "$(dirname "$0")/.."
d=build/fixtures/jspeed
if [ -n "$JPEG_PHOTO" ] || [ ! -f $d/P640.JPG ]; then
    [ -n "$JPEG_PHOTO" ] || { echo "set JPEG_PHOTO to a photo to time with" >&2; exit 1; }
    rm -rf $d; mkdir -p $d
    magick "$JPEG_PHOTO" -resize 640x480^ -gravity center -extent 640x480 $d/p640.ppm
    magick $d/p640.ppm -resize 320x200^ -gravity center -extent 320x200 $d/p320.ppm
    cjpeg -quality 80 -outfile $d/P640.JPG $d/p640.ppm
    cjpeg -quality 80 -outfile $d/P320.JPG $d/p320.ppm
    cjpeg -quality 80 -progressive -outfile $d/P640P.JPG $d/p640.ppm
    cjpeg -quality 80 -progressive -outfile $d/P320P.JPG $d/p320.ppm
    head -c 9000 $d/P320.JPG > $d/PCUT.JPG          # cut short
    rm $d/*.ppm
fi
(cd $d && ls *.JPG | sed 's/$/ 060000/') > build/fixtures/jspeed.types
[ -f build/fixtures/true/PHOTO.PNG ] || python3 -I test/make_true.py build/fixtures/true > /dev/null
python3 -I - > build/jpegtime.test <<'PY'
import os
for folder, path in (("MCJSPEED", "build/fixtures/jspeed"), ("MCTRUE", "build/fixtures/true")):
    for n in sorted(os.listdir(path)):
        if n.endswith(".JPG"):
            print(f"LOAD *:{folder}:{n}")
            print(f"SAVE RGB *:MCOUT:{n}.R")
print("SHOW")
PY
COMMANDS=build/jpegtime.test RUN_SECONDS="${RUN_SECONDS:-3000}" DUMP_EVERY=600 ./test/run.sh > /dev/null
rm -f build/fixtures/jspeed.types
python3 -I - <<'PY'
import os, subprocess
res = "build/test/results"
log = open(os.path.join(res, "MC.LOG#040000"), "rb").read().decode().split("\r")
outs = {f.split("#")[0]: f for f in os.listdir(os.path.join(res, "MCOUT"))}
total, ok = 0, True
for line in log:
    if not line.startswith("LOAD *:"): continue
    path, _, result = line[len("LOAD *:"):].partition(": ")
    folder, name = path.split(":")
    if not result.startswith("ok"):
        print(f"{name:13s} FAIL: {result}"); ok = False; continue
    parts = result.replace(",", "").split()
    w, h, ticks = (int(parts[i].strip("$"), 16) for i in (4, 5, 10))
    src = os.path.join("build/fixtures", "jspeed" if folder == "MCJSPEED" else "true", name)
    ppm = subprocess.run(["djpeg", "-dct", "fast", "-nosmooth", "-ppm", src], capture_output=True).stdout
    kind, _, _, data = ppm.split(b"\n", 3)
    if kind == b"P5": data = bytes(c for v in data for c in (v, v, v))
    got = open(os.path.join(res, "MCOUT", outs[name + ".R"]), "rb").read() if name + ".R" in outs else b""
    worst = max((abs(a - b) for a, b in zip(got, data)), default=999) if len(got) == len(data) else 999
    if name == "PCUT.JPG" and len(got) == len(data):
        # Cut short: the rows the data holds decoded as libjpeg does.
        top = w * 3 * 64
        worst = max(abs(a - b) for a, b in zip(got[:top], data[:top]))
    flag = "OK" if worst <= 6 else "FAIL"
    if worst > 6: ok = False
    total += ticks
    print(f"{name:13s} {w:4d}x{h:<4d} {ticks / 60:6.1f} s   libjpeg difference {worst:3d}  {flag}")
print(f"total {total / 60:.1f} s", "all OK" if ok else "PROBLEMS")
PY
