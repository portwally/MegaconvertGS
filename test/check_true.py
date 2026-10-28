# Checks the true colour pictures MegaconvertGS loaded in the emulator (test/true.sh):
#  - the decoded pixels against GS Remap's decoding (exact, except JPEG and 16-bit
#    samples, where decoders may round differently);
#  - the fitted size against GS Remap's "fit to screen";
#  - the remapped screen against GS Remap's remap of the same decoded pixels.
import os, sys, subprocess
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pngread import read_png, write_png

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
fix = os.path.join(root, "build", "fixtures", "true")
res = os.path.join(root, "build", "test", "results")
work = os.path.join(root, "build", "test", "expected")
os.makedirs(work, exist_ok=True)
sc4 = os.environ.get("SC4", os.path.expanduser("~/Documents/GS Remap/.build/release/sc4"))
kinds = {"PNG": "png", "GIF": "gif", "BMP": "bmp", "JPG": "jpeg"}
NEAR = {"RGB16.PNG": 1, "B555.BMP": 7, "B565.BMP": 7}       # largest difference allowed per sample

log = {}
for line in open(os.path.join(res, "MC.LOG#040000"), "rb").read().decode().split("\r"):
    if line.startswith("LOAD *:MCTRUE:"):
        name, _, result = line[len("LOAD *:MCTRUE:"):].partition(": ")
        log[name] = result

def result(name):
    for f in os.listdir(os.path.join(res, "MCOUT")):
        if f.split("#")[0] == name:
            return open(os.path.join(res, "MCOUT", f), "rb").read()
    return None

def fit(w, h):
    steps = [(1, 16), (1, 12), (1, 10), (1, 8), (1, 6), (1, 5), (1, 4), (1, 3), (2, 5), (1, 2), (3, 5), (2, 3),
             (3, 4), (4, 5), (1, 1)]
    step = 14
    while step > 0:
        n, d = steps[step]
        if w * n // d <= 320 and h * n // d <= 200: break
        step -= 1
    n, d = steps[step]
    return min(320, max(1, w * n // d)), min(200, max(1, h * n // d))

ok = True
for name in sorted(os.listdir(fix)):
    problems, notes = [], ""
    entry = log.get(name)
    if name == "JPROG.JPG":
        good = entry == "error $FFFE"
        print(f"{name:12s} {'OK (progressive: not supported yet)' if good else 'FAIL: ' + str(entry)}")
        ok &= good
        continue
    if entry is None or not entry.startswith("ok"):
        print(f"{name:12s} FAIL: {entry}"); ok = False; continue
    parts = entry.replace(",", "").split()
    w, h, ow, oh, ticks = (int(parts[i].strip("$"), 16) for i in (4, 5, 7, 8, 10))
    notes = f"  {ticks / 60:5.1f} s"
    ref = os.path.join(work, name + ".png")
    if not os.path.exists(ref):
        subprocess.run([sc4, "load", os.path.join(fix, name), ref, kinds[name[-3:]]], check=True, capture_output=True)
    rw, rh, want = read_png(ref)
    got = result(name + ".R")
    if (w, h) != (rw, rh): problems.append(f"size {w}x{h}, GS Remap {rw}x{rh}")
    elif got is None or len(got) != len(want): problems.append("no RGB result")
    else:
        diffs = [abs(a - b) for a, b in zip(got, want)]
        worst = max(diffs)
        if name.endswith(".JPG"):
            # JPEG decoders differ in their rounding and chroma smoothing, so compare
            # with libjpeg's fast integer decoder without smoothing (djpeg), which this
            # decoder follows, and only note how far GS Remap's (Apple's) decoder is.
            ppm = subprocess.run(["djpeg", "-dct", "fast", "-nosmooth", "-ppm", os.path.join(fix, name)],
                                 capture_output=True, check=True).stdout
            kind, _, _, data = ppm.split(b"\n", 3)
            if kind == b"P5": data = bytes(c for v in data for c in (v, v, v))
            lib = [abs(a - b) for a, b in zip(got, data)]
            mean = sum(diffs) / len(diffs)
            notes += f"  (libjpeg: largest difference {max(lib)}; GS Remap: mean {mean:.2f})"
            if max(lib) > 6: problems.append(f"too far from libjpeg{notes}")
        elif worst > NEAR.get(name, 0):
            bad = sum(1 for d in diffs if d)
            first = next(i for i, d in enumerate(diffs) if d) // 3
            problems.append(f"{bad} samples differ (largest {worst}), first at x={first % w} y={first // w}")
    if fit(w, h) != (ow, oh): problems.append(f"fitted {ow}x{oh}, GS Remap would fit {fit(w, h)}")
    screen = result(name + ".C")
    if got is not None and len(got) == w * h * 3 and screen is not None:
        src = os.path.join(work, name + ".decoded.png")
        write_png(src, w, h, got)
        out = os.path.join(work, name + ".remap.c1")
        subprocess.run([sc4, "remap", src, out, "--size", f"{ow}x{oh}"], check=True, capture_output=True)
        expect = open(out, "rb").read()
        bad = sum(1 for a, b in zip(screen[:32000], expect[:32000]) if a != b)
        if bad: problems.append(f"remap: {bad} pixel bytes differ")
        if screen[32256:32288] != expect[32256:32288]: problems.append("remap: palette differs")
    elif screen is None:
        problems.append("no remapped screen")
    print(f"{name:12s} {'OK' + notes if not problems else 'FAIL: ' + '; '.join(problems)}")
    ok &= not problems
sys.exit(0 if ok else 1)
