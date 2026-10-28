# Writes the Works of Art test files (docs/superconvert-formats-extra.md 1.11) into the
# folder given, and woa.types beside it: TEST.WOA (two pages, "PAGE ONE" and "CHECKER", and
# a rectangle list) and three damaged copies: BAD1 (no "SS"), BAD2 (page 1's right edge
# not 269), BAD3 (page 1's length one byte short: its last code lacks its pattern).
import os, struct, sys

def run(count, pattern):                       # one code: pattern repeated count times
    c = count - 1
    head = 0x80 | (len(pattern) - 1) << 4
    if c < 8:
        return bytes([head | c]) + bytes(pattern)
    return bytes([head | 8 | c >> 8, c & 0xFF]) + bytes(pattern)

page_hdr = struct.pack('<5H', 0, 0, 0, 269, 359)
page1 = page_hdr + (run(10, [0x7F]) + run(350, [0x00]) +
                    run(10, [0x7F]) + run(450, [0x00]) +
                    bytes([0x01]) +
                    run(2048, [0x00]) * 6 + run(931, [0x00]))
page2 = page_hdr + run(2048, [0x2A, 0x55]) * 3 + run(876, [0x2A, 0x55])
names = struct.pack('<HB', 2, 0) + b'\x08PAGE ONE' + b'\x07CHECKER'
rects = struct.pack('<HB', 2, 8) + struct.pack('<8H', 0, 0, 13, 9, 0, 0, 269, 359)

def woa(chunks):
    header = bytearray(16)
    header[5:7] = b'SS'
    struct.pack_into('<H', header, 0x0B, len(chunks))
    header[0x0D] = 1
    directory = b''.join(struct.pack('<HH4xH6x', t, i, len(d)) for t, i, d in chunks)
    head = bytes(header) + directory
    return head + bytes(512 - len(head)) + b''.join(d for _, _, d in chunks)

chunks = [(0, 4, names), (1, 0x0B, page1), (2, 0x0B, page2), (0, 3, rects)]
good = woa(chunks)
assert len(good) == 621
out = sys.argv[1]
os.makedirs(out, exist_ok=True)
files = {"TEST.WOA": good}
bad = bytearray(good); bad[5] = 0x54; files["BAD1.WOA"] = bytes(bad)
bad = bytearray(good); bad[0x21A] = 0x0E; files["BAD2.WOA"] = bytes(bad)
bad = bytearray(good); bad[0x28] = 0x2B; files["BAD3.WOA"] = bytes(bad)
for name, data in files.items():
    open(os.path.join(out, name), "wb").write(data)
with open(os.path.join(out, "..", "woa.types"), "w") as f:
    for name in files:
        f.write(f"{name} F70000\n")
