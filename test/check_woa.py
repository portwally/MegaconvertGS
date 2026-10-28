# Checks the Works of Art test (test/woa.sh).
import os, re, sys
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
        if f.split("#")[0] == name: return open(os.path.join(res, "MCOUT", f), "rb").read()

def decode(chunk):                             # a clean decoder (1.5): x >= 270 dropped
    bits = bytearray(34 * 360)
    strip, y, down, i = 0, 0, True, 10
    def put(c):
        nonlocal strip, y, down
        if strip >= 39: return
        for b in range(7):
            x = 7 * strip + b
            if c >> b & 1 and x < 270:
                bits[y * 34 + x // 8] |= 0x80 >> (x & 7)
        if down:
            if y == 359: strip += 1; down = False
            else: y += 1
        else:
            if y == 0: strip += 1; down = True
            else: y -= 1
    while i < len(chunk):
        c = chunk[i]; i += 1
        if c < 0x80: put(c); continue
        n, count = ((c >> 4) & 7) + 1, c & 15
        if count >= 8: count = (count & 7) << 8 | chunk[i]; i += 1
        pattern = chunk[i:i + n]; i += n
        for _ in range(count + 1):
            for p in pattern: put(p & 0x7F)
    return bytes(bits)

test = open(os.path.join(root, "build", "fixtures", "woa", "TEST.WOA"), "rb").read()
lengths = [int.from_bytes(test[16 + 16 * k + 8:16 + 16 * k + 10], "little") for k in range(4)]
offs = [512 + sum(lengths[:k]) for k in range(4)]
pages = {1: test[offs[1]:offs[1] + lengths[1]], 2: test[offs[2]:offs[2] + lengths[2]]}
def white(bits):
    return [(x, y) for y in range(360) for x in range(270) if bits[y * 34 + x // 8] >> (7 - x % 8) & 1]

loads = [l for l in log if l.startswith("LOAD")]
images = [l.split(": ", 1)[1] for l in log if l.startswith("IMAGES:")]
for k, name in ((1, "PAGE1"), (2, "PAGE2")):
    got, want = result(name), decode(pages[k])
    report(f"page {k}: loaded as format 52 (Works of Art)", None if "$0034" in loads[k - 1] else loads[k - 1])
    report(f"page {k}: a monochrome image only", None if images[k - 1:k] == ["screen 0, true 0, mono 1"] else repr(images))
    report(f"page {k}: 270 x 360, as the decoder", None if got == want else "no file" if got is None else
           f"{sum(a != b for a, b in zip(got, want))} bytes differ")
w1 = white(decode(pages[1]))
report("PAGE ONE: 141 white pixels where the documentation says",
       None if len(w1) == 141 and (0, 0) in w1 and (13, 359) in w1 and (14, 100) in w1 and (7, 349) not in w1
       else f"{len(w1)} white")
w2 = set(white(decode(pages[2])))
report("CHECKER: white where x + y is odd", None if w2 == {(x, y) for y in range(360) for x in range(270) if (x + y) % 2}
       else "differs")
for line, code, label in ((loads[2], "FFFF", "no \"SS\": not a picture"), (loads[3], "FFFE", "a page not 0, 0, 269, 359: refused"),
                          (loads[4], "FFFC", "data ending inside a code: damaged")):
    report(label, None if f"error ${code}" in line else line)
sys.exit(0 if ok else 1)
