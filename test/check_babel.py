# Checks the Babelfish test (test/babel.sh): build/babel1 holds the run with Babelfish,
# build/test/results the run without it.
import os, sys
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ok = True
def report(label, problem):
    global ok
    print(f"{label:64s} {'OK' if not problem else 'FAIL: ' + problem}")
    ok &= not problem
def logof(d):
    raw = open(os.path.join(d, "MC.LOG#040000"), "rb").read().decode("latin-1")
    return [l for l in raw.split("\r") if l]
def files(d):
    out = {}
    folder = os.path.join(d, "MCOUT")
    for f in os.listdir(folder):
        if "#" in f and not f.endswith("_ResourceFork.bin"):
            out[f.split("#")[0]] = (f.split("#")[1], open(os.path.join(folder, f), "rb").read())
    return out
res1 = os.path.join(root, "build", "babel1")
log = logof(res1)
out = files(res1)
fixtures = os.path.join(root, "build", "fixtures")

def answer(cmd, n=1):
    hits = [l.split(": ", 1)[1] for l in log if l.split(": ", 1)[0] == cmd]
    return hits[n - 1] if len(hits) >= n else None
def lasts():
    return [l.split(": ", 1)[1] for l in log if l.startswith("BFLAST")]
def same(a, b):
    if a not in out or b not in out: return "missing " + (a if a not in out else b)
    x, y = out[a][1], out[b][1]
    if x == y: return None
    return f"{sum(p != q for p, q in zip(x, y)) + abs(len(x) - len(y))} bytes differ"
def visible(name):
    """A $C1 screen as it shows: its pixels, line modes and the colour tables they use."""
    d = out[name][1]
    used = sorted({d[0x7D00 + y] & 15 for y in range(200)})
    return d[:0x7D00 + 200] + b"".join(d[0x7E00 + 32 * t:0x7E20 + 32 * t] for t in used)
def seen(a, b):
    if a not in out or b not in out: return "missing " + (a if a not in out else b)
    return None if visible(a) == visible(b) else "differ"
def ppm(data):
    parts = data.split(b"\n", 3)
    w, h = map(int, parts[1].split())
    return w, h, parts[3][:w * h * 3]

b = lasts()
def via(k, name, kind):
    line = b[k] if k < len(b) else ""
    want = f"ok{name} ${kind:04X}"
    return None if line.startswith(want) else repr(line)

# Imports
report("Apple Preferred: loaded as format 54 (PixelMap import)", None if answer("LOAD AS bfpix *:MCTEST:S320.APF") == "ok, format $0036" else answer("LOAD AS bfpix *:MCTEST:S320.APF"))
report("... by the Apple Preferred Format translator, a PixelMap", via(0, "Apple Preferred Format", 2))
report("... the same screen as the file loaded directly", seen("I1.C", "N1.C"))
report("$C1 640 mode screen: by Super Hi-Res Screen Image", via(1, "Super Hi-Res Screen Image", 2))
report("... the same screen as the file loaded directly", seen("I2.C", "N2.C"))
report("MacPaint (576 x 720): a true colour image", None if "size $0240 $02D0" in (answer("LOAD AS bfpix *:MCOTHER:PAINT.MAC") or "") else answer("LOAD AS bfpix *:MCOTHER:PAINT.MAC"))
report("... by the MacPaint translator", via(2, "MacPaint*", 2))
mac = open(os.path.join(fixtures, "other", "PAINT.MAC"), "rb").read()[512:]
bits, i = bytearray(), 0
while len(bits) < 72 * 720:
    c = mac[i]; i += 1
    if c < 128: bits += mac[i:i + c + 1]; i += c + 1
    else: bits += bytes([mac[i]]) * (257 - c); i += 1
rgb = out.get("I3.RGB", ("", b""))[1]
bad = 0
for y in range(720):
    for x in range(576):
        ink = bits[y * 72 + x // 8] >> (7 - x % 8) & 1
        px = rgb[(y * 576 + x) * 3:(y * 576 + x) * 3 + 3]
        if px != (b"\x00\x00\x00" if ink else b"\xff\xff\xff"): bad += 1
report("... black where the MacPaint bits are set, white elsewhere", None if len(rgb) == 576 * 720 * 3 and bad == 0 else f"{bad} pixels differ, {len(rgb)} bytes")
report("Re-convert last file: through the same translator again", via(3, "MacPaint*", 2))
report("... the same picture", same("I3B.RGB", "I3.RGB"))
report("GEM/IMG as PixelMap: by the GEM/IMG translator", via(4, "GEM/IMG", 2))
scr = out.get("I4.C", ("", b""))[1]
w, h, nat = 200, 120, out.get("N4.RGB", ("", b""))[1]
bad = 0
for y in range(h):
    scb = scr[0x7D00 + y]
    for x in range(w):
        if scb & 0x80:
            v = scr[y * 160 + x // 4] >> (6 - 2 * (x % 4)) & 3; c = [8, 12, 0, 4][x % 4] + v
        else:
            v = scr[y * 160 + x // 2] >> (4 if x % 2 == 0 else 0) & 15; c = v
        e = scr[0x7E00 + (scb & 15) * 32 + 2 * c] | scr[0x7E00 + (scb & 15) * 32 + 2 * c + 1] << 8
        got = bytes(((e >> 8 & 15) * 17, (e >> 4 & 15) * 17, (e & 15) * 17))
        if got != nat[(y * w + x) * 3:(y * w + x) * 3 + 3]: bad += 1
report("... its pixels the colours of the file loaded directly", None if len(nat) == w * h * 3 and bad == 0 else f"{bad} pixels differ")
report("GEM/IMG as True Color: refused (it sends a QuickDraw picture)", None if answer("LOAD AS bftrue *:MCOTHER:PIC.IMG") == "error $FFFE" and via(5, "GEM/IMG", 8) is None else answer("LOAD AS bftrue *:MCOTHER:PIC.IMG"))
w, h, raw = ppm(open(os.path.join(fixtures, "other", "PIC.PPM6"), "rb").read())
report("PPM (BFNAME PBM/PGM/PPM): a true colour image, by that translator", via(6, "PBM/PGM/PPM", 4))
report("... the file's pixels exactly", None if out.get("I5.RGB", ("", b""))[1] == raw else "differ")
bw, bh, braw = ppm(open(os.path.join(fixtures, "babel", "BIG.PPM"), "rb").read())
report("300 x 250 PPM (several blocks): the file's pixels exactly", None if out.get("I6.RGB", ("", b""))[1] == braw else "differ")
report("Equal rankings without a name: the first by name (GEM/IMG)", via(8, "GEM/IMG", 0) if via(8, "GEM/IMG", 0) is None else via(8, "GEM/IMG", 0))

# Exports
def typed(name, t):
    return None if name in out and out[name][0] == t else ("missing" if name not in out else out[name][0])
report("PixelMap export, Apple Preferred Format: a $C0/0002 file", typed("E1", "C00002"))
report("... loaded back: the same screen", seen("R1.C", "N1.C"))
report("PixelMap export, Super Hi-Res Screen Image: a $C0/0001 file", typed("E2", "C00001"))
report("... loaded back: the same screen", seen("R2.C", "N1.C"))
report("640 mode PixelMap export (Apple Preferred): loaded back the same", seen("R4.C", "N2.C"))
e3 = out.get("E3.PPM", ("", b""))[1]
report("True Color export, PBM/PGM/PPM: a raw PPM of the picture", None if e3[:15] == b"P6\n320 200\n255\n" and e3[15:] == out.get("N3.RGB", ("", b""))[1] else "differs")
report("... loaded back: the same picture", same("R3.RGB", "N3.RGB"))
report("300 x 250 True Color export: loaded back the same", None if out.get("R5.RGB", ("", b""))[1] == braw else "differs")
report("True Color export without a name: the only one there is (PPM)", None if typed("E6.PPM", "060000") is None and b[12].startswith("okPBM/PGM/PPM") else repr(b[12:13]))
report("True Color export by a translator without it: refused", None if (answer("SAVE AS bftrue *:MCOUT:E7") or "").startswith("error") and "E7" not in out else answer("SAVE AS bftrue *:MCOUT:E7"))
for line in log:
    if line.startswith("SAVE AS") and "E7" not in line and not line.endswith(": ok"):
        report(f"{line.split(': ')[0]}", line)

# Its dialogs (Load & convert, Save conversion, keys typed)
res3 = os.path.join(root, "build", "babel3")
log3 = logof(res3)
out3 = files(res3)
def at(cmd):
    hits = [l.split(": ", 1)[1] for l in log3 if l.split(": ", 1)[0] == cmd]
    return hits[0] if hits else ""
report("Load & convert: Babelfish's Open dialog chose S640.APF", None if at("IMAGES") == "screen 1, true 0, mono 0" and at("BFLAST").startswith("okApple Preferred Format $0002") else at("BFLAST"))
out_keep = out
out = out3
out["N2.C"] = out_keep.get("N2.C", ("", b""))
report("... the picture in it", seen("UI1.C", "N2.C"))
report("Save conversion: Babelfish's Export dialog wrote UIEXP", typed("UIEXP", "C00002"))
report("... loaded back: the same screen", seen("UI2.C", "UI1.C"))
out = out_keep

# Without Babelfish
log2 = logof(os.path.join(root, "build", "test", "results"))
report("No Babelfish: an import says it can't start ($FFF4)", None if log2[0].endswith("error $FFF4") else log2[0])
report("No Babelfish: an export says it can't start ($FFF4)", None if log2[1].endswith("error $FFF4") else log2[1])
report("No Babelfish: other files still load", None if log2[2].endswith("ok, format $0002") else log2[2])
sys.exit(0 if ok else 1)
