# Makes src/ImgData.s, data the screen image window takes from SuperConvert 4.0 (see
# docs/superconvert-image-window.md): the true colour dither table, the info bar's and
# its pop-ups' icons, the marching ants patterns, and the window's cursors (rCursor
# resources). Reads SuperConvert's program file (its data fork and resource fork).
#   python3 test/make_imgdata.py <SuperConvert data fork> <its resource fork>
import os, struct, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
d = open(sys.argv[1], "rb").read()
SEG9 = 0x52D2B                      # file offset of segment OSAYCANYOU's start

def hexlines(b, per=32):
    return ["            hex   " + b[i:i + per].hex().upper() for i in range(0, len(b), per)]

out = ["* ImgData.s - the screen image window's data, from SuperConvert 4.0 (made by",
       "* test/make_imgdata.py).", "",
       "* Dither: one 640 mode byte (four pixels) for each 12-bit colour $0RGB, for even",
       "* (first 4096) and odd (next 4096) rows of the picture.", "DitherTab   =     *"]
dither = d[0x57C3A:0x57C3A + 8192]
assert len(dither) == 8192
out += hexlines(dither)
ICONS = [("IcArrow", 0x4839, "pop-up arrow with its divider"),
         ("IcActArr", 0x48A5, "pop-up arrow on white (actions)"),
         ("IcZoom0", 0x4A1D, "magnifier: actual size"),
         ("IcZoomS", 0x4A65, "magnifier: shrunk"),
         ("IcZoomL", 0x4AAD, "magnifier: zoomed"),
         ("IcSelect", 0x498D, "tool: selection"),
         ("IcPeek", 0x49D5, "tool: pixel peek"),
         ("Ic320", 0x48FD, "pop-up item: 320-sized pixels"),
         ("Ic640", 0x4945, "pop-up item: 640-sized pixels")]
for label, off, what in ICONS:
    f = SEG9 + off
    typ, size, h, w = struct.unpack_from("<HHHH", d, f)
    rec = d[f:f + 8 + 2 * size]
    out += ["", f"* {what} ({w * 2} x {h})", f"{label:<12s}=     *"] + hexlines(rec, 20)
# Marching ants (4.5): ANTS[i] at +32 i and STEP[i] = ANTS[i] XOR ANTS[i + 1] at +32 i + 16;
# only the first 16 bytes of a pattern count in 640 mode (8 rows of 2 bytes), so STEP[3]'s
# second half, past the table, is never used (16 zero bytes here).
ants = d[SEG9 + 0x4E8F:SEG9 + 0x4E8F + 128]
out += ["", "* Marching ants: ANTS[i] = AntsTab + 32 i, STEP[i] = AntsTab + 32 i + 16",
        "AntsTab     =     *"] + hexlines(ants + bytes(16))
# The cursors: QuickDraw cursor records (height, width in words, image, mask, hot spot).
r = open(sys.argv[2], "rb").read()
w16 = lambda b, i: struct.unpack_from("<H", b, i)[0]
w32 = lambda b, i: struct.unpack_from("<I", b, i)[0]
m = w32(r, 4); index = m + w16(r, m + 14); used = w32(r, m + 24)
res, p, found = {}, index, 0
while found < used and p + 20 <= len(r):
    t = w16(r, p)
    if t:
        rid, off, size = w32(r, p + 2), w32(r, p + 6), w32(r, p + 12)
        res[(t, rid)] = r[off:off + size]; found += 1
    p += 20
CURSORS = [(1, "NW-SE double arrow (corners top left, bottom right)"), (2, "vertical double arrow (top, bottom edges)"),
           (3, "horizontal double arrow (left, right edges)"), (4, "NE-SW double arrow (corners top right, bottom left)"),
           (5, "new selection"), (6, "pixel peek"), (8, "move the selection")]
for rid, what in CURSORS:
    b = res[(0x8027, rid)]
    h, wd = w16(b, 0), w16(b, 2)
    out += ["", f"* rCursor {rid}: {what}", f"Cur{rid:<9d}=     *"] + hexlines(b[:8 + 4 * h * wd], 20)
open(os.path.join(ROOT, "src", "ImgData.s"), "w").write("\n".join(out) + "\n")
print(len(out), "lines")
