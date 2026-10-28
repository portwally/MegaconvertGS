# Checks the image window's tools test (test/tools.sh): each logged result against the
# documented behaviour (docs/superconvert-image-window.md), the Clipboard's picture of a
# selection and the three crops against the same done here. Use image's palette is checked
# through the hardware's line modes and colour table 15 (DESK 11), with the pointer moved
# over the picture and away (CLICK x y 0).
import os, sys
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
res = os.path.join(root, "build", "test", "results")
log = [l for l in open(os.path.join(res, "MC.LOG#040000"), "rb").read().decode("latin-1").split("\r") if l]
cmds = [l for l in open(os.path.join(root, "test", "tools.test")).read().split("\n") if l]
ok = True
def report(label, problem):
    global ok
    print(f"{label:58s} {'OK' if not problem else 'FAIL: ' + problem}")
    ok &= not problem
def result(name):
    for f in os.listdir(os.path.join(res, "MCOUT")):
        if f.split("#")[0] == name: return open(os.path.join(res, "MCOUT", f), "rb").read()
got = {}
for i, c in enumerate(cmds):          # the n-th time each command was logged
    got.setdefault(c, []).append(log[i][len(c) + 2:] if i < len(log) and log[i].startswith(c + ":") else None)
def entry(cmd, n=1):
    e = got.get(cmd, [])
    return e[n - 1] if len(e) >= n else None
WANT = [  # label, command, occurrence, logged result
    ("no selection at first: the whole picture", "DESK 5", 1, "ok 0 0 0 200 640 | Image: 320 x 200"),
    ("a new selection, snapped to bytes", "DESK 5", 2, "ok 1 10 20 60 100 | Selection: 40 x 50"),
    ("pointer: top left corner", "DESK 9 10 20 0", 1, "ok 7"),
    ("pointer: inside (move)", "DESK 9 35 60 0", 1, "ok 5"),
    ("pointer: bottom right corner", "DESK 9 60 100 0", 1, "ok 3"),
    ("pointer: left edge", "DESK 9 35 20 0", 1, "ok 4"),
    ("pointer: outside (new selection)", "DESK 9 100 300 0", 1, "ok 11"),
    ("pointer with Option: the nearest corner", "DESK 9 100 300 2048", 1, "ok 3"),
    ("the selection moved", "DESK 5", 3, "ok 1 20 40 70 120 | Selection: 40 x 50"),
    ("its bottom right corner dragged", "DESK 5", 4, "ok 1 20 40 80 140 | Selection: 50 x 60"),
    ("its left edge dragged (snapped)", "DESK 5", 5, "ok 1 20 32 80 140 | Selection: 54 x 60"),
    ("key 3: the bottom right corner in view", "DESK 8", 1, "ok 50 0"),
    ("key 7: the top left corner in view", "DESK 8", 2, "ok 0 0"),
    ("pixel peek: screen image", "DESK 5", 6, "ok 1 20 32 80 140 | 4,5    P0  I2  $217"),
    ("a double click outside: all of it", "DESK 5", 7, "ok 1 0 0 200 640 | Selection: 320 x 200"),
    ("a click outside without a drag: none", "DESK 5", 8, "ok 0 0 0 200 640 | Image: 320 x 200"),
    ("a selection at 2X zoom (snapped, halved)", "DESK 5", 9, "ok 1 11 20 31 40 | Selection: 10 x 20"),
    ("Crop to selection: screen image", "DESK 5", 10, "ok 0 0 0 20 20 | Screen image: 10 x 20"),
    ("a true colour selection (320-sized pixels)", "DESK 5", 11, "ok 1 10 20 50 102 | Selection: 41 x 40"),
    ("pixel peek: grey true colour image", "DESK 5", 12, "ok 1 10 20 50 102 | 30,30    Gray 93"),
    ("Crop to selection: true colour image", "DESK 5", 13, "ok 0 0 0 40 82 | Image: 41 x 40"),
    ("a monochrome selection (640-sized pixels)", "DESK 5", 14, "ok 1 5 7 40 77 | Selection: 70 x 35"),
    ("Crop to selection: monochrome image", "DESK 5", 15, "ok 0 0 0 35 70 | Image: 70 x 35"),
    ("Discard other image types", "IMAGES", 1, "screen 0, true 0, mono 1"),
    ("Discard this image type: none left", "IMAGES", 2, "screen 0, true 0, mono 0"),
    ("Apple-w: every image goes", "IMAGES", 3, "screen 0, true 0, mono 0"),
    ("Use image's palette: the picture's lines and colours", "DESK 11 150", 1, "ok 8F 000 427 1A3 FFF"),
    ("Use image's palette: other lines as they were", "DESK 11 20", 1, "ok 80 000 427 1A3 FFF"),
    ("Use image's palette: the desktop's again outside", "DESK 11 150", 2, "ok 80 000 427 1A3 FFF"),
]
for label, cmd, n, want in WANT:
    g = entry(cmd, n)
    report(label, None if g == want else repr(g))
s320 = open(os.path.join(root, "build", "fixtures", "S320.c1"), "rb").read()
# Copy with the selection (20, 32, 80, 140): 320 mode pixels 16-69 of lines 20-79.
sel = result("SEL.C")
def px(img, x, y): return (img[y * 160 + x // 2] >> (4 if x % 2 == 0 else 0)) & 15
if sel is None: report("Copy: the selection on the Clipboard", "no file")
else:
    bad = sum((px(sel, x, y) != (px(s320, x, y) if 16 <= x < 70 and 20 <= y < 80 else 0))
              for y in range(200) for x in range(320))
    report("Copy: the selection on the Clipboard", f"{bad} pixels differ" if bad else None)
# Crop of the screen image to (11, 20, 31, 40): bytes 5-9 of lines 11-30.
crop = result("CROP.C")
want = bytearray(32768)
for i in range(20): want[i * 160:i * 160 + 5] = s320[(11 + i) * 160 + 5:(11 + i) * 160 + 10]
for i in range(200): want[0x7D00 + i] = s320[0x7D00 + 11 + i] if i < 20 else s320[0x7D00 + 11]
want[0x7E00:] = s320[0x7E00:]
report("Crop: the screen image's bytes, lines and modes", None if crop == bytes(want) else "differs")
g, W = result("G.RGB"), 157
want = b"".join(g[((10 + r) * W + 10) * 3:((10 + r) * W + 51) * 3] for r in range(40))
report("Crop: the true colour image's pixels", None if result("CT.RGB") == want else "differs")
m, st = result("G.MONO"), (157 + 7) // 8
ns, out = (70 + 7) // 8, bytearray(9 * 35)
for y in range(35):
    for x in range(70):
        if (m[(5 + y) * st + (7 + x) // 8] >> (7 - (7 + x) % 8)) & 1: out[y * ns + x // 8] |= 0x80 >> (x % 8)
report("Crop: the monochrome image's bits", None if result("CM.MONO") == bytes(out) else "differs")
sys.exit(0 if ok else 1)
