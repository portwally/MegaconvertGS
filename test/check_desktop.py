# Checks the desktop background test (test/desktop.sh): every command ran; the desktop
# messages Use as desktop background left are the original's (docs/superconvert-extras.md
# 4.2), and there is none at the start and after Revert to normal desktop; Histogram
# equalization from the menu gives GS Remap's result.
import os, sys, subprocess
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
res = os.path.join(root, "build", "test", "results")
work = os.path.join(root, "build", "test", "expected")
os.makedirs(work, exist_ok=True)
log = open(os.path.join(res, "MC.LOG#040000"), "rb").read().decode().split("\r")
cmds = [l for l in open(os.path.join(root, "test", "desktop.test")).read().split("\n") if l]


def model(scr, w, h, is640):
    """The desktop message: 8 bytes (+6: 1, a picture follows), then 200 lines of 160
    bytes, the light blue dither ($DD) with the picture's lines centred across (cut on the
    right), from the top (200 lines or more), at the bottom (187 or more) or centred below
    the menu bar."""
    m = bytearray(b"\xDD" * 0x7D08)
    m[6:8] = b"\x01\x00"
    bpl = (w + 3) // 4 if is640 else (w + 1) // 2
    x0 = (160 - bpl) // 2 if bpl < 160 else 0
    bpl = min(bpl, 160)
    if h >= 200: h, r0 = 200, 0
    elif h >= 187: r0 = 200 - h
    else: r0 = (187 - h) // 2 + 13
    for i in range(h):
        o = 8 + (r0 + i) * 160 + x0
        m[o:o + bpl] = scr[i * 160:i * 160 + bpl]
    return bytes(m)


def result(name):
    for f in os.listdir(os.path.join(res, "MCOUT")):
        if f.split("#")[0] == name: return open(os.path.join(res, "MCOUT", f), "rb").read()


ok = True
def report(label, problem):
    global ok
    print(f"{label:52s} {'OK' if not problem else 'FAIL: ' + problem}")
    ok &= not problem


none = {"D0.BIN", "D2.BIN", "D6.BIN"}
want = [c + (": no desktop message" if c.split(":")[-1] in none else ": ok") for c in cmds]
got = [l.split(", ticks")[0].split(", format")[0] for l in log[:len(want)]]
report("commands", None if got == want else repr([g for g, w in zip(got, want) if g != w] or log))
s640 = open(os.path.join(root, "build", "fixtures", "S640.c1"), "rb").read()
for name, label, scr, w, h, m640 in [
        ("D1.BIN", "S640.C1, 640 x 200: the whole screen", s640, 640, 200, True),
        ("D3.BIN", "GREY8.PNG, 157 x 93: centred", result("G.C"), 157, 93, False),
        ("D4.BIN", "STORED.PNG as monochrome, 61 x 188: at the bottom", result("M.C"), 61, 188, False),
        ("D5.BIN", "RGB8.PNG, 320 x 200: the whole screen", result("R.C"), 320, 200, False)]:
    msg = result(name)
    if msg is None or scr is None: report(label, "no file"); continue
    want = model(scr, w, h, m640)
    bad = [i for i in range(6, len(want)) if i >= len(msg) or msg[i] != want[i]]
    report(label, None if len(msg) == len(want) and not bad else
           f"{len(msg)} bytes, {len(bad)} differ" + (f" from {bad[0]:#x}" if bad else ""))
ref = os.path.join(work, "desktop_eq.rgb")
inp = result("IN.RGB")
if inp is None: report("Histogram equalization from the menu", "no file")
else:
    src = os.path.join(work, "desktop_in.rgb")
    open(src, "wb").write(inp)
    subprocess.run([os.path.join(root, "test", "sc4save", ".build", "release", "sc4filter"), src, "320", "200",
                    ref, "0"], check=True, capture_output=True)
    report("Histogram equalization from the menu, as GS Remap",
           None if result("EQ.RGB") == open(ref, "rb").read() else "differs")
sys.exit(0 if ok else 1)
