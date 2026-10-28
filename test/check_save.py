# Checks the files MegaconvertGS saved in the emulator (test/save.sh) against GS Remap's
# save formats (test/sc4save): Finder icons byte for byte, icon resources resource for
# resource, PaintWorks by its contents (packing may differ), hex data line for line, and
# GIF, PNG and TIFF pixel for pixel, BMP against GS Remap's PNG of the picture. Where GS Remap refuses a picture, so must MegaconvertGS.
import os, sys, subprocess, re, struct
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pngread import read_png
from save_list import PICTURES, FORMATS, out

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
res = os.path.join(root, "build", "test", "results")
work = os.path.join(root, "build", "test", "expected", "save")
os.makedirs(work, exist_ok=True)
ref_tool = os.path.join(root, "test", "sc4save", ".build", "release", "sc4save")
sc4 = os.environ.get("SC4", os.path.expanduser("~/Documents/GS Remap/.build/release/sc4"))

log = {}
for line in open(os.path.join(res, "MC.LOG#040000"), "rb").read().decode().split("\r"):
    m = re.match(r"SAVE AS (\S+) \*:MCOUT:(\S+): (.*)", line)
    if m: log[(m.group(1), m.group(2))] = m.group(3)    # (the last try for each file)

def ours(name, fork=False):
    for f in os.listdir(os.path.join(res, "MCOUT")):
        if f.split("#")[0] == name and f.endswith("_ResourceFork.bin") == fork:
            return open(os.path.join(res, "MCOUT", f), "rb").read()
    return None

def unpackbytes(d):
    o, i = bytearray(), 0
    while i < len(d):
        f = d[i]; n = (f & 0x3F) + 1; i += 1
        k = f >> 6
        if k == 0: o += d[i:i + n]; i += n
        elif k == 1: o += bytes([d[i]]) * n; i += 1
        elif k == 2: o += d[i:i + 4] * n; i += 4
        else: o += bytes([d[i]]) * (n * 4); i += 1
    return bytes(o)

def resources(d):
    """The resources in an Apple IIgs resource fork: sorted (type, id, data)."""
    w = lambda i: struct.unpack_from("<H", d, i)[0]
    l = lambda i: struct.unpack_from("<I", d, i)[0]
    m = l(4); index = m + w(m + 14); used = l(m + 24)
    found, p, out_ = 0, index, []
    while found < used and p + 20 <= len(d):
        if w(p):
            out_.append((w(p), l(p + 2), d[l(p + 6):l(p + 6) + l(p + 12)])); found += 1
        p += 20
    return sorted(out_)

def pixels(path, kind):
    png = path + ".decoded.png"
    subprocess.run([sc4, "load", path, png, kind], check=True, capture_output=True)
    return read_png(png)

ok = True
for tag, disk, local, fid in PICTURES:
    for fmt in FORMATS:
        name = out(tag, fmt)
        if fmt == "bmp":                       # (GS Remap saves no BMP: the picture must
            entry = log.get((fmt, name), "not tried")    # be its PNG's, pixel for pixel)
            problems, note = [], ""
            pref = os.path.join(work, out(tag, "png") + ".png")
            if not entry.startswith("ok"): problems.append(entry)
            elif not os.path.exists(pref): problems.append("no PNG from GS Remap to compare")
            else:
                mine = os.path.join(work, name + ".ours.bmp")
                open(mine, "wb").write(ours(name))
                gw, gh, g = pixels(mine, "bmp")
                ww, wh, wv = pixels(pref, "png")
                if (gw, gh) != (ww, wh): problems.append(f"size {gw}x{gh}, GS Remap's PNG {ww}x{wh}")
                elif g != wv: problems.append(f"{sum(1 for a, b in zip(g, wv) if a != b)} samples differ")
                note = f"{len(ours(name))} bytes, as GS Remap's PNG"
            print(f"{name:10s} {fmt:9s} {'OK  ' + note if not problems else 'FAIL: ' + '; '.join(problems)}")
            ok &= not problems
            continue
        ref = os.path.join(work, name + "." + fmt)
        args = [ref_tool, os.path.join(root, local), fid, ref, {"pw": "c00"}.get(fmt, fmt)]
        if fmt in ("iconadd", "riconadd"):
            args.append(os.path.join(work, out(tag, fmt[:-3]) + "." + fmt[:-3]))
        r = subprocess.run(args, capture_output=True, text=True)
        entry = log.get((fmt, name), "not tried")
        problems = []
        if r.returncode != 0:                  # GS Remap won't: neither should we
            if not entry.startswith("error"): problems.append(f"GS Remap refuses ({r.stderr.strip()}), we said {entry}")
            note = "refused, as in GS Remap"
        elif not entry.startswith("ok"):
            problems.append(f"{entry}")
        else:
            note = ""
            want = open(ref, "rb").read()
            if fmt in ("icon", "iconadd"):
                got = ours(name)
                if got != want: problems.append(f"icon file differs ({len(got or b'')} / {len(want)} bytes)")
            elif fmt in ("ricon", "riconadd"):
                got = ours(name, fork=True)
                if got is None: problems.append("no resource fork")
                elif resources(got) != resources(want):
                    problems.append(f"resources differ: {[(t, i, len(x)) for t, i, x in resources(got)]} / "
                                    f"{[(t, i, len(x)) for t, i, x in resources(want)]}")
            elif fmt == "pw":
                got = ours(name)
                if got[:0x222] != want[:0x222]: problems.append("header differs")
                elif unpackbytes(got[0x222:]) != unpackbytes(want[0x222:]): problems.append("picture differs")
            elif fmt == "hex":
                got = ours(name).replace(b"\r", b"\n")
                if got != want: problems.append("text differs")
            else:
                mine = os.path.join(work, name + ".ours." + fmt)
                open(mine, "wb").write(ours(name))
                gw, gh, g = pixels(mine, fmt if fmt != "tiff" else "tiff")
                ww, wh, wv = pixels(ref, fmt)
                if (gw, gh) != (ww, wh): problems.append(f"size {gw}x{gh}, GS Remap {ww}x{wh}")
                elif g != wv:
                    # macOS colour-manages a TIFF without a colour profile a little
                    # differently: allow a difference of 1 there.
                    worst = max(abs(a - b) for a, b in zip(g, wv))
                    if fmt != "tiff" or worst > 1:
                        problems.append(f"{sum(1 for a, b in zip(g, wv) if a != b)} samples differ (largest {worst})")
                note = f"{len(ours(name))} bytes (GS Remap {len(want)})"
        print(f"{name:10s} {fmt:9s} {'OK  ' + note if not problems else 'FAIL: ' + '; '.join(problems)}")
        ok &= not problems
sys.exit(0 if ok else 1)
