# Checks the 640 mode Convert to true color test (test/smooth.sh).
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from smooth_model import smooth
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
res = os.path.join(root, "build", "test", "results")
ok = True
def report(label, problem):
    global ok
    print(f"{label:52s} {'OK' if not problem else 'FAIL: ' + problem}")
    ok &= not problem
def result(name):
    for f in os.listdir(os.path.join(res, "MCOUT")):
        if f.split("#")[0] == name: return open(os.path.join(res, "MCOUT", f), "rb").read()
def exact(scr, w, h, m640):
    out = bytearray()
    for y in range(h):
        p = scr[0x7D00 + y] & 15
        P = [(scr[0x7E00 + p * 32 + 2 * i] | scr[0x7E01 + p * 32 + 2 * i] << 8) & 0xFFF for i in range(16)]
        for x in range(w):
            if m640:
                c = P[[8, 12, 0, 4][x & 3] + ((scr[y * 160 + x // 4] >> (6 - 2 * (x & 3))) & 3)]
            else:
                c = P[(scr[y * 160 + x // 2] >> (4 if x % 2 == 0 else 0)) & 15]
            out += bytes((((c >> 8) & 15) * 17, ((c >> 4) & 15) * 17, (c & 15) * 17))
    return bytes(out)
s640 = open(os.path.join(root, "build", "fixtures", "S640.c1"), "rb").read()
s320 = open(os.path.join(root, "build", "fixtures", "S320.c1"), "rb").read()
sm, ex = smooth(s640), exact(s640, 640, 200, True)
for name, label, want in (("SM.RGB", "Smoothed, as the model", sm), ("EX.RGB", "Exact, as GS Remap's", ex),
                          ("W1.RGB", "the window: Smoothed chosen", sm),
                          ("W2.RGB", "the window again: Smoothed remembered", sm),
                          ("W3.RGB", "a 320 mode image: no window, exact", exact(s320, 320, 200, False))):
    got = result(name)
    report(label, None if got == want else ("no file" if got is None else
           f"{sum(a != b for a, b in zip(got, want))} bytes differ"))
sys.exit(0 if ok else 1)
