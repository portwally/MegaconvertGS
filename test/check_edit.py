# Checks the Edit menu test (test/edit.sh): the Clipboard's picture, drawn back, is the
# screen image (whole, or its own size), the colour table scrap is a count of 1 and colour
# table 0, Cut and Close leave the images they should, and the multipalette picture's
# warning came up (and was dismissed).
import os, sys
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
res = os.path.join(root, "build", "test", "results")
log = [l for l in open(os.path.join(res, "MC.LOG#040000"), "rb").read().decode().split("\r") if l]
ok = True
def report(label, problem):
    global ok
    print(f"{label:56s} {'OK' if not problem else 'FAIL: ' + problem}")
    ok &= not problem
def result(name):
    for f in os.listdir(os.path.join(res, "MCOUT")):
        if f.split("#")[0] == name: return open(os.path.join(res, "MCOUT", f), "rb").read()
def entry(cmd, n=1):
    hits = [l for l in log if l.startswith(cmd + ":")]
    return hits[n - 1][len(cmd) + 2:] if len(hits) >= n else None
def pixels(img, w, h, m640):
    ppb = 4 if m640 else 2
    out = []
    for y in range(200):
        for x in range(640 if m640 else 320):
            b = img[y * 160 + x // ppb]
            v = (b >> (6 - 2 * (x & 3))) & 3 if m640 else (b >> (4 if x % 2 == 0 else 0)) & 15
            out.append(v if x < w and y < h else 0)
    return out
s320 = open(os.path.join(root, "build", "fixtures", "S320.c1"), "rb").read()
s640 = open(os.path.join(root, "build", "fixtures", "S640.c1"), "rb").read()
for scrap, label, src, w, h, m640 in [
        ("CP.C", "Copy: S320.C1 on the Clipboard", s320, 320, 200, False),
        ("CT.C", "Cut: S640.C1 on the Clipboard", s640, 640, 200, True),
        ("CG.C", "Copy: GREY8.PNG's screen image (157 x 93)", result("G.C"), 157, 93, False),
        ("CM.C", "Copy: a multipalette screen image", result("M.C"), 320, 200, False)]:
    got = result(scrap)
    if got is None or src is None: report(label, "no file"); continue
    bad = sum(a != b for a, b in zip(pixels(got, w, h, m640), pixels(src, w, h, m640)))
    words = (entry("SAVE SCRAP *:MCOUT:" + scrap) or "").split()[1:]
    want = ["$0001"] + ["$%04X" % ((src[0x7E00 + 2 * i] | src[0x7E01 + 2 * i] << 8) & 0x0FFF) for i in range(16)]
    report(label, None if not bad and words == want else
           f"{bad} pixels differ" + ("" if words == want else f"; colour scrap {words}"))
images = [l.split(": ", 1)[1] for l in log if l.startswith("IMAGES:")]
want = ["screen 1, true 0, mono 0", "screen 0, true 0, mono 0", "screen 1, true 1, mono 1",
        "screen 0, true 1, mono 1", "screen 0, true 0, mono 0"]
labels = ["Copy keeps the image", "Cut of the only image: none left", "a screen, true colour and monochrome image",
          "Cut: the screen image goes, the others stay", "Close: every image goes"]
for i, (l, w) in enumerate(zip(labels, want)):
    report(l, None if i < len(images) and images[i] == w else repr(images[i] if i < len(images) else None))
# The warning stops the commands until Return dismisses it.
report("the multipalette picture's warning, dismissed", None if entry("SAVE SCRAP *:MCOUT:CM.C") else "not dismissed")
sys.exit(0 if ok else 1)
