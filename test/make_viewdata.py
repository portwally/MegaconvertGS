# Makes src/ViewData.s, data View approximation takes from SuperConvert 4.0 (see
# docs/superconvert-image-window.md 10.5): the words (four 320 mode pixels) drawn for a
# grey level 0-63 and for a 5-bit colour level 0-31. Reads SuperConvert's data fork.
#   python3 test/make_viewdata.py <SuperConvert data fork>
import os, sys
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
d = open(sys.argv[1], "rb").read()
out = ["* ViewData.s - View approximation's level patterns, from SuperConvert 4.0 (made by",
       "* test/make_viewdata.py): a word of four 320 mode pixels for each level."]
for label, off, n in (("GreyLevels", 0x57066, 64), ("ColLevels", 0x570E6, 32)):
    b = d[off:off + 2 * n]
    words = [b[i] | b[i + 1] << 8 for i in range(0, len(b), 2)]
    out += ["", f"{label:<12s}=     *"] + ["            dw    " + ",".join(f"${w:04X}" for w in words[i:i + 8]) for i in range(0, n, 8)]
def bytes_table(label, what, values):
    out.extend(["", f"* {what}", f"{label:<12s}=     *"])
    for i in range(0, len(values), 16):
        out.append("            db    " + ",".join(f"${v:02X}" for v in values[i:i + 16]))
# View X4 magnified: each picture byte as four bytes of 320 mode pixels, each pixel four
# times as wide (320 mode lines); a 640 mode pixel k (0: bits 7-6) of value v becomes two
# 320 mode pixels of value 4k + v.
bytes_table("X320A", "X4, 320 mode lines", [b for v in range(256) for b in ((v >> 4) * 17, (v >> 4) * 17, (v & 15) * 17, (v & 15) * 17)])
bytes_table("X640A", "X4, 640 mode lines", [b for v in range(256) for b in ((v >> 6) * 17, (((v >> 4) & 3) + 4) * 17, (((v >> 2) & 3) + 8) * 17, ((v & 3) + 12) * 17)])
# View half size: a 640 mode byte's pixels 0 and 2 (every other one), in bits 7-4.
bytes_table("HalfHi", "half size: pixels 0 and 2 of a byte, in bits 7-4", [(v & 0xC0) | ((v & 0x0C) << 2) for v in range(256)])
open(os.path.join(ROOT, "src", "ViewData.s"), "w").write("\n".join(out) + "\n")
