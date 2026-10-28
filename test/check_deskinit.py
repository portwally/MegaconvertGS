# Checks the desktop background INIT test (test/deskinit.sh): each file is a one-segment
# OMF load file (version 2, static code, no relocation) whose data ends in the desktop
# message packed with PackBytes: 4 + 2 bytes of $DD, $0001, then the picture's 200 lines
# (docs/superconvert-formats-extra.md 2.3), here whole screens copied unchanged.
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
        if f.split("#")[0] == name: return f, open(os.path.join(res, "MCOUT", f), "rb").read()
    return None, None
def unpackbytes(d, want):
    out, i = bytearray(), 0
    while len(out) < want and i < len(d):
        f = d[i]; i += 1
        n = (f & 0x3F) + 1
        k = f >> 6
        if k == 0: out += d[i:i + n]; i += n
        elif k == 1: out += bytes([d[i]]) * n; i += 1
        elif k == 2: out += d[i:i + 4] * n; i += 4
        else: out += bytes([d[i]]) * (4 * n); i += 1
    return bytes(out[:want])
w = lambda d, o: int.from_bytes(d[o:o + 2], "little")
l = lambda d, o: int.from_bytes(d[o:o + 4], "little")
for name, fixture in (("DESK320", "S320.c1"), ("DESK640", "S640.c1")):
    fname, d = result(name)
    if d is None: report(name, "no file"); continue
    report(f"{name}: type $B7, aux $0000", None if fname.endswith("#B70000") else fname)
    hdr = (l(d, 0), l(d, 8), d[13], d[14], d[15], l(d, 16), w(d, 20), w(d, 34), w(d, 40), w(d, 42))
    count = l(d, 0x38)
    report(f"{name}: OMF header (lengths, version 2, one static segment)",
           None if hdr == (len(d), count, 0, 4, 2, 0x10000, 0, 1, 0x2C, 0x37) and d[0x37] == 0xF2 else repr(hdr))
    body = d[0x3C:0x3C + count]
    report(f"{name}: no relocation, END last", None if len(d) == 0x3C + count + 1 and d[-1] == 0 else "more records")
    code = next((k for k in range(40, 600) if w(body, k - 2) == count - k), None)
    if code is None: report(f"{name}: the packed message", "not found"); continue
    msg = unpackbytes(body[code:], 32008)
    pic = open(os.path.join(root, "build", "fixtures", fixture), "rb").read()[:32000]
    want = bytes([0xDD] * 6) + b"\x01\x00" + pic
    report(f"{name}: the packed desktop message (the whole screen)", None if msg == want else
           f"{sum(a != b for a, b in zip(msg, want))} bytes differ")
sys.exit(0 if ok else 1)
