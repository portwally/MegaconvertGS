# Checks the Save conversion dialogs test (test/savedlg.sh).
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from savedlg_model import canvas, apf, paintworks
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
s320 = open(os.path.join(root, "build", "fixtures", "S320.c1"), "rb").read()
s640 = open(os.path.join(root, "build", "fixtures", "S640.c1"), "rb").read()
for name, label, scr, args, width in [
        ("A396", "Apple Preferred, one page (396) high, centred", s320, (0, 0, 160, 200, 160, 396, 0, -98), 320),
        ("A400", "Apple Preferred, two screens high, top", s320, (0, 0, 160, 200, 160, 400, 0, 0), 320),
        ("AONE", "Apple Preferred, one screen", s320, (0, 0, 160, 200, 160, 200, 0, 0), 320),
        ("ACLIP", "Apple Preferred, the selection (Same as clipping)", s320, (20, 10, 25, 60, 25, 60, 0, 0), 50),
        ("AWIDE", "Apple Preferred, two screens wide, left (640 mode)", s640, (0, 0, 160, 200, 320, 200, 0, 0), 1280)]:
    d = result(name)
    if d is None: report(label, "no file"); continue
    w, pals, lines = apf(d)
    want = canvas(scr, *args)
    report(label, None if (w, pals, lines) == (width, scr[0x7E00:0x8000], want) else
           f"width {w}, {len(lines)} lines, {sum(a != b for a, b in zip(lines, want))} differ")
d = result("PW396")
if d is None: report("PaintWorks: 396 lines from the clipping, centred", "no file")
else:
    pal, lines = paintworks(d, 396)
    want = [b + bytes(160 - len(b)) for _, b in canvas(s320, 20, 10, 25, 60, 160, 396, (25 - 160) >> 1, (60 - 396) >> 1)]
    report("PaintWorks: 396 lines from the clipping, centred",
           None if pal == s320[0x7E00:0x7E20] and lines == want else f"{sum(a != b for a, b in zip(lines, want))} lines differ")
report("GIF at the original size: as without the dialogs",
       None if result("G640") is not None and result("G640") == result("G640D") else "differs")
warn = [l.split(": ", 1)[1] for l in log if l.startswith("SAVEWARN:")]
report("no warnings for Apple Preferred, PaintWorks (320), GIF",
       None if warn[:3] == ["ok $0000"] * 3 else repr(warn[:3]))
report("PaintWorks of a 640 mode picture: the warning; cancelled",
       None if warn[3:4] == ["ok $0001"] and result("PW640") is None else repr((warn[3:4], result("PW640") is None)))
report("a Finder icon too large: the alert; nothing saved", None if result("ICON") is None else "saved")
report("PaintWorks of a multipalette picture: warned, saved anyway",
       None if warn[4:5] == ["ok $0004"] and result("PWMP") is not None else repr((warn[4:5], result("PWMP") is None)))
for name, start, sep, end in (("HEXOPT", "/* ", " , ", " */"), ("HEXDEF", " dc h'", " ", "'")):
    d = result(name)
    want = "".join(start + sep.join("%02X" % b for b in s640[y * 160:(y + 1) * 160]) + end + "\r"
                   for y in range(200)).encode()
    report(f"Hex data: {start!r} before, {sep!r} between, {end!r} after",
           None if d == want else "no file" if d is None else "differs")
report("Hex data through its options window (OK): as with the defaults",
       None if result("HEXWIN") is not None and result("HEXWIN") == result("HEXDEF") else "differs")
report("GIF with the upload note and progress: as without them",
       None if result("GIFNOTE") is not None and result("GIFNOTE") == result("G640D") else "differs")
def icon_record(d):
    r = d[26:]
    path, name = r[2:66], r[66:82]
    return (path[1:1 + path[0]].decode("latin-1"), name[1:1 + name[0]].decode("latin-1"),
            int.from_bytes(r[82:84], "little"), int.from_bytes(r[84:86], "little"), r[86:])
dlg, plain = result("ICONDLG"), result("ICONPLAIN")
if dlg is None or plain is None:
    report("Finder icon through its criteria dialog (Save)", "no file")
else:
    p1, n1, t1, a1, icons1 = icon_record(dlg)
    p0, n0, t0, a0, icons0 = icon_record(plain)
    report("Finder icon, the dialog's defaults: type, aux, name, this program",
           None if (n1, t1, a1) == ("S640.C1", 0xC1, 0) and p1.endswith(":System:Finder") else repr((p1, n1, t1, a1)))
    report("Finder icon without the dialog: any file, no program, same icons",
           None if (p0, n0, t0, a0) == ("", "*", 0, 0) and icons0 == icons1 else repr((p0, n0, t0, a0)))
import zlib, struct
def png(d):
    if d is None or d[:8] != b"\x89PNG\r\n\x1a\n": return None
    i, chunks = 8, []
    while i < len(d):
        n = struct.unpack(">I", d[i:i + 4])[0]
        chunks.append((d[i + 4:i + 8], d[i + 8:i + 8 + n])); i += 12 + n
    hdr = dict(chunks)[b"IHDR"]
    w, h = struct.unpack(">II", hdr[:8])
    try: raw = zlib.decompress(b"".join(c for t, c in chunks if t == b"IDAT"))
    except zlib.error: return None
    rows, prev, filters = [], bytes(w), []
    for y in range(h):
        f, line = raw[y * (w + 1)], bytearray(raw[y * (w + 1) + 1:(y + 1) * (w + 1)])
        filters.append(f)
        if f == 2: line = bytearray((a + b) & 255 for a, b in zip(line, prev))
        elif f != 0: return None
        rows.append(bytes(line)); prev = rows[-1]
    return rows, filters, [c for t, c in chunks if t == b"tEXt"], dict(chunks)[b"PLTE"]
base = png(result("PNGDEF"))
for name, label, want_f, want_t, same in (
        ("PNGOPT9", "PNG level 9, filter None, comments", {0}, [b"Comment\x00Made by MegaconvertGS"], False),
        ("PNGOPT1", "PNG level 1, filter Auto: as without options", None, [], True),
        ("PNGWIN", "PNG through its options window (OK): level 6, None", {0}, [], False)):
    d = result(name)
    p = png(d)
    if base is None or p is None:
        report(label, "no file or not readable"); continue
    prob = None
    if (p[0], p[3]) != (base[0], base[3]): prob = "pixels differ"
    elif want_f is not None and set(p[1]) != want_f: prob = f"filters {sorted(set(p[1]))}"
    elif p[2] != want_t: prob = f"tEXt {p[2]!r}"
    elif same and d != result("PNGDEF"): prob = "bytes differ"
    elif not same and len(d) >= len(result("PNGDEF")) and name != "PNGWIN": prob = f"{len(d)} bytes, not smaller"
    report(label, prob)
sys.exit(0 if ok else 1)
