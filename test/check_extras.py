# Checks the Extras test (test/extras.sh).
import os, sys
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
res = os.path.join(root, "build", "test", "results")
log = [l for l in open(os.path.join(res, "MC.LOG#040000"), "rb").read().decode("latin-1").split("\r") if l]
ok = True
def report(label, problem):
    global ok
    print(f"{label:58s} {'OK' if not problem else 'FAIL: ' + problem}")
    ok &= not problem
def result(name):
    for f in os.listdir(os.path.join(res, "MCOUT")):
        if f.split("#")[0] == name + ".C": return open(os.path.join(res, "MCOUT", f), "rb").read()
def pixels(img):
    return [(img[y * 160 + x // 4] >> (6 - 2 * (x & 3))) & 3 for y in range(200) for x in range(640)]
std = bytes.fromhex("0000000ff000ff0f" * 4)       # $000 $F00 $0F0 $FFF, four times
for name, label in (("FONTS0", "Available font list"), ("FONTS1", "More available fonts"), ("KEYS", "Font key chart")):
    img = result(name)
    if img is None: report(label, "no image"); continue
    px = pixels(img)
    black = sum(1 for v in px if v == 0)
    report(label + ": a 640 mode image, standard colours",
           None if all(b == 0x80 for b in img[0x7D00:0x7DC8]) and img[0x7E00:0x7E20] == std else "modes or colours")
    report(label + ": text drawn on white", None if 1000 < black < 60000 and px.count(3) > 60000 else f"{black} black pixels")
    if name == "KEYS":
        report(label + ": codes in green and red", None if px.count(2) > 500 and px.count(1) > 500 else
               f"green {px.count(2)}, red {px.count(1)}")
images = [l.split(": ", 1)[1] for l in log if l.startswith("IMAGES:")]
report("each leaves just the screen image", None if images == ["screen 1, true 0, mono 0"] * 2 else repr(images))
sys.exit(0 if ok else 1)
