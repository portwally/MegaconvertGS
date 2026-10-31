# Checks the more Apple II pictures test (test/a2more.sh).
import os, struct, sys
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
res = os.path.join(root, "build", "test", "results")
log = [l for l in open(os.path.join(res, "MC.LOG#040000"), "rb").read().decode("latin-1").split("\r") if l]
out = {}
for f in os.listdir(os.path.join(res, "MCOUT")):
    if "#" in f: out[f.split("#")[0]] = open(os.path.join(res, "MCOUT", f), "rb").read()
ok = True
def report(label, problem):
    global ok
    print(f"{label:62s} {'OK' if not problem else 'FAIL: ' + problem}")
    ok &= not problem
def answer(cmd):
    for l in log:
        if l.split(": ", 1)[0] == cmd: return l.split(": ", 1)[1]
    return "(not run)"
def loaded(cmd, fmt):
    a = answer(cmd)
    return None if a.startswith(f"ok, format ${fmt:04X}") else a
def same(a, b):
    if a not in out or b not in out: return "missing " + (a if a not in out else b)
    x, y = out[a][:0x7D00 + 200], out[b][:0x7D00 + 200]     # pixels and line modes
    return None if x == y else f"{sum(p != q for p, q in zip(x, y))} bytes differ"
def bmp_size(name):
    d = out.get(name)
    return struct.unpack_from("<ii", d, 18) if d else None

report("LZ4FH: Open knows it (type $08/$8066) as HiRes", loaded("LOAD *:MCA2MORE:LZ.HGR", 9))
report("... the same picture as the plain HiRes file", same("LZ.C", "NHGR.C"))
report("... packed from 8184 bytes (the last hole left out): the same", same("LZ2.C", "NHGR.C"))
report("... as HiRes black & white: the same as the plain file", same("LZBW.C", "NHGRBW.C"))
report("... cut short: damaged ($FFFC)", None if answer("LOAD *:MCA2MORE:LZBAD.HGR") == "error $FFFC" else answer("LOAD *:MCA2MORE:LZBAD.HGR"))
report("PAIR.BIN with PAIR.AUX beside it: Open takes Double HiRes", loaded("LOAD *:MCA2MORE:PAIR.BIN", 11))
report("... the same picture as the 16K file", same("P1.C", "NDHR.C"))
report("PAIR.AUX opened instead: the same", same("P2.C", "NDHR.C"))
report("8184-byte halves, lower-case names: the same", same("P3.C", "NDHR.C"))
report("As Double HiRes black & white: the same as the 16K file", same("P4.C", "NDHRBW.C"))
report("As HiRes (chosen): only the .BIN, as a lone one", same("P5.C", "L.C"))
report("A lone .BIN: HiRes, as before", loaded("LOAD *:MCA2MORE:LONE.BIN", 9))
report("bmp2dhr piece, full screen (FULL.DHR): Double HiRes", loaded("LOAD *:MCA2MORE:FULL.DHR", 11))
report("... the same picture as the 16K file", same("F.C", "NDHR.C"))
report("Piece of 40 bytes x 100 rows: as on a black screen", same("PC.C", "PR.C"))
# (BMP saves draw pixels square: 320 mode twice as wide and tall, 640 mode twice as tall)
report("... its size 140 x 100 (a 280 x 200 BMP)", None if bmp_size("PC.BMP") in ((280, 200), (280, -200)) else repr(bmp_size("PC.BMP")))
report("Mask piece (.DHM): Double HiRes black & white", loaded("LOAD *:MCA2MORE:MASK.DHM", 12))
report("... as on a black screen", same("M.C", "MR.C"))
report("... its size 140 x 50, 640 mode (a 140 x 100 BMP)", None if bmp_size("M.BMP") in ((140, 100), (140, -100)) else repr(bmp_size("M.BMP")))
report(".A2FM: Double HiRes black & white", loaded("LOAD *:MCA2MORE:PIC.A2FM", 12))
report("... the same picture as the file loaded so", same("A.C", "NA.C"))
report("320 x 200 PPM (ComputerEyes' size): a PPM", loaded("LOAD *:MCA2MORE:P320.PPM", 46))
fixdir = os.path.join(root, "build", "fixtures", "a2more")
for name, size, what in (("TALL", "$0140 $0104", "Apple Preferred 320 x 260"), ("WIDE", "$02BC $00D2", "Apple Preferred 700 x 210, 640 mode"),
                         ("M3200", "$0140 $00C8", "Apple Preferred with MULTIPAL (3200 colors)")):
    a = answer(f"LOAD *:MCA2MORE:{name}.APF")
    report(f"{what}: a true colour picture, whole", None if f"size {size}" in a else a)
    want = open(os.path.join(fixdir, name + ".EXP"), "rb").read()
    got = out.get(name + ".R")
    report("... each line in its own colours, as GS Remap reads it",
           None if got == want else "missing" if got is None else f"{sum(got[i:i+3] != want[i:i+3] for i in range(0, len(want), 3))} pixels differ")
sys.exit(0 if ok else 1)
