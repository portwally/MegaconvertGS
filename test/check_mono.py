# Checks the monochrome test (test/mono.sh): replays its steps with test/mono_model.py,
# SuperConvert's conversions as docs/superconvert-truecolor.md describes them, from the
# pictures as MegaconvertGS loaded them, and compares every file saved.
import os, sys, struct
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import mono_model as M
from mono_list import STEPS
res = sys.argv[1] if len(sys.argv) > 1 else os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "build", "test", "results")

def ours(name):
    for d in (os.path.join(res, "MCOUT"), res):
        if not os.path.isdir(d): continue
        for f in os.listdir(d):
            if f.split("#")[0] == name: return open(os.path.join(d, f), "rb").read()
    return None

SIZES = {"GREY8.PNG": (157, 93), "RGB8.PNG": (320, 200)}
ok = True
true = screen = mono = None
for st in STEPS:
    k = st[0]
    if k == "load":
        w, h = SIZES[st[1]]
        loaded_size = (w, h)
        continue
    if k == "save" and st[2].endswith(".IN"):
        rgb = ours(st[2]); true = (w, h, rgb); continue
    if k == "save" and st[2].endswith(".SC"):
        c1 = ours(st[2])
        sw = 640 if c1[0x7D00] & 0x80 else 320
        # the screen image's own size: the loaded picture fitted (here: as loaded)
        screen = (c1, min(w, sw), min(h, 200), sw == 640)
        continue
    if k == "mono":
        _, kind, H, V, m = st
        if kind == 0:
            c1, sw, sh, is640 = screen
            lum = M.screen_intensity(c1, sw, sh, is640)
        else:
            lum = M.true_intensity(true[2], true[0], true[1])
        mono = M.to_mono(lum, H, V, m)
        continue
    if k == "out":
        _, kind, a, s, m6, sh = st
        if kind == 0:
            c1, ow, oh = M.to_screen(mono, a, s, m6, sh)
            screen = (bytes(c1), ow, oh, bool(m6))
            last = ("c1", bytes(c1))
        else:
            tw, th, rgb = M.to_true(mono, a, s, m6, sh)
            true = (tw, th, rgb)
            last = ("rgb", rgb)
        continue
    if k == "neg":
        mono = M.negate(mono); continue
    what, name = st[1], st[2]
    got = ours(name)
    if what == "mono":
        w2, h2, rows = mono
        want = b"".join(rows)
        if got is not None and len(got) == len(want):     # (only the pixels' bits count)
            mask = bytearray()
            stride = (w2 + 7) // 8
            for _ in range(h2):
                mask += bytes([0xFF] * (stride - 1) + [(0xFF00 >> (w2 - 8 * (stride - 1))) & 0xFF])
            got = bytes(a & m for a, m in zip(got, mask)); want = bytes(a & m for a, m in zip(want, mask))
    elif what == "c1":
        want = last[1] if last and last[0] == "c1" else None
        if got is not None and want is not None:     # pixels, SCBs and colour table 0
            got = got[:0x7E20]; want = want[:0x7E20]
    else:
        want = last[1] if last and last[0] == "rgb" else None
    good = got is not None and want is not None and got == want
    if not good:
        ok = False
        detail = "missing" if got is None else ("no reference" if want is None else
                 f"{len(got)} bytes, want {len(want)}" if len(got) != len(want) else
                 f"{sum(x != y for x, y in zip(got, want))} bytes differ, first at {next(i for i in range(len(got)) if got[i] != want[i])}")
        print(f"{name:12s} FAIL: {detail}")
    else:
        print(f"{name:12s} OK")
    last = None
sys.exit(0 if ok else 1)
