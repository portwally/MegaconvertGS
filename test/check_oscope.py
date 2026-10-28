# Checks the Oscilloscope Art test (test/oscope.sh) against a model of SuperConvert's
# conversion (docs/superconvert-extras.md 4.3).
import os, sys
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
res = os.path.join(root, "build", "test", "results")
ok = True
def report(label, problem):
    global ok
    print(f"{label:58s} {'OK' if not problem else 'FAIL: ' + problem}")
    ok &= not problem
def result(name):
    for f in os.listdir(os.path.join(res, "MCOUT")):
        if f.split("#")[0] == name: return open(os.path.join(res, "MCOUT", f), "rb").read()

def oscope(img, width_bytes, lines):
    made = []
    for L in range(200):
        s = img[32000 + L] if L < lines else 0
        p = s & 15
        br = []
        for c in range(16):
            w = img[32256 + p * 32 + 2 * c] | img[32256 + p * 32 + 2 * c + 1] << 8
            br.append((w & 15) + (w >> 4 & 15) + (w >> 8 & 15))
        level, thr = 14 - (L % 28) // 2, 15 if L & 1 else 30
        row = bytearray(160)
        for i in range(160):
            b = img[L * 160 + i] if L < lines and i < width_bytes else 0
            h, l = b >> 4, b & 15
            if s & 0x80:
                b1 = (br[h >> 2] + br[(h & 3) + 4]) // 2
                b2 = (br[(l >> 2) + 8] + br[(l & 3) + 12]) // 2
            else:
                b1, b2 = br[h], br[l]
            row[i] = (level if b1 >= thr else 0) << 4 | (level if b2 >= thr else 0)
        made.append(bytes(row))
    out = bytearray(img)
    for p in range(8):
        cols = [0] + [2 * p << 8 | 2 * p << 4 | b for b in range(7)] + \
               [(2 * p + 1) << 8 | (2 * p + 1) << 4 | b for b in range(7)] + [0xFFF]
        for c, w in enumerate(cols):
            out[32256 + p * 32 + 2 * c:32256 + p * 32 + 2 * c + 2] = w.to_bytes(2, "little")
    a, x = 0x17, 0
    while True:
        while True:
            a *= 2
            if a >= 256: a = (a & 0xFF) ^ 0x1D
            if a < 200: break
        out[x * 160:(x + 1) * 160] = made[a]
        out[32000 + x] = 7 - a // 28
        x += 1
        if a == 0x17: break
    out[199 * 160:200 * 160] = made[0]
    out[32000 + 199] = 7
    return bytes(out), x

for name, fixture, label in (("OSC320", "S320.c1", "a 320 mode screen"), ("OSC640", "S640.c1", "a 640 mode screen")):
    src = open(os.path.join(root, "build", "fixtures", fixture), "rb").read()
    want, rows = oscope(src, 160, 200)
    got = result(name)
    if got is None: report(label, "no file"); continue
    bad = [y for y in range(200) if got[y * 160:(y + 1) * 160] != want[y * 160:(y + 1) * 160]]
    report(f"Oscilloscope Art of {label}: the lines", None if not bad else f"{len(bad)} lines differ, first {bad[0]}")
    report(f"Oscilloscope Art of {label}: modes and colour tables",
           None if got[32000:32200] == want[32000:32200] and got[32256:] == want[32256:] else "differ")
report("the order visits every line once", None if rows == 199 else f"{rows} rows")
sys.exit(0 if ok else 1)
