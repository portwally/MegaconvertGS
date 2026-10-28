# Makes the test pictures for MegaconvertGS's own load formats (TGA, PICT) in
# build/fixtures/newfmt, written from known pixels, with the picture each must load as
# (NAME.exp: width, height as two 16-bit numbers, then the RGB bytes), and newfmt.types
# (each file's ProDOS type) and newfmt.list (name, format id).
#   python3 test/make_newfmt.py build/fixtures
import os, sys, struct, math, subprocess, shutil
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pngread import read_png

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
out = os.path.join(sys.argv[1], "newfmt")
os.makedirs(out, exist_ok=True)
types, listing = [], []

def save(name, data, fid, pixels, w, h, ftype="060000"):
    open(os.path.join(out, name), "wb").write(data)
    open(os.path.join(out, name + ".exp"), "wb").write(struct.pack("<HH", w, h) +
        bytes(c for row in pixels for p in row for c in p))
    types.append((name, ftype))
    listing.append((name, fid))

def scene(w, h):
    """Colours that change across and down, with some flat areas for runs."""
    rows = []
    for y in range(h):
        row = []
        for x in range(w):
            if (x // 12 + y // 9) % 4 == 0:
                row.append((200, 40, 90))                 # flat: long runs
            else:
                row.append((int(127 + 120 * math.sin(x / 9 + y / 15)) & 255,
                            (x * 255 // max(1, w - 1)) & 255, (y * 7 + x) & 255))
        rows.append(row)
    return rows

# ---- TGA ----
def five(v): return (v << 3) | (v >> 2)

def tga(name, rows, kind, depth, rle=False, top=False, rtl=False, idtext=b"", cmap=None,
        cfirst=0, csize=24, alpha=None):
    """kind 1 colour-mapped (rows of indices), 2 true colour, 3 grey (rows of greys)."""
    h, w = len(rows), len(rows[0])
    desc = (0x20 if top else 0) | (0x10 if rtl else 0) | (8 if depth == 32 else (1 if depth == 16 else 0))
    hdr = struct.pack("<BBBHHBHHHHBB", len(idtext), 1 if cmap is not None else 0, kind + (8 if rle else 0),
                      cfirst, len(cmap) if cmap is not None else 0, csize if cmap is not None else 0,
                      0, 0, w, h, depth, desc)
    def colour(c, bits, a=255):
        r, g, b = c
        if bits in (15, 16): return struct.pack("<H", ((r >> 3) << 10) | ((g >> 3) << 5) | (b >> 3) | (0x8000 if bits == 16 else 0))
        if bits == 24: return bytes((b, g, r))
        return bytes((b, g, r, a))
    def value(v, x, y):
        if kind == 2: return colour(v, depth, alpha(x, y) if alpha else 255)
        return bytes((v,))
    mapdata = b"".join(colour(c, csize) for c in cmap) if cmap is not None else b""
    order = [rows[y] for y in (range(h) if top else range(h - 1, -1, -1))]
    stream = []
    for i, r in enumerate(order):
        y = i if top else h - 1 - i
        xs = range(w - 1, -1, -1) if rtl else range(w)
        stream += [value(r[x], x, y) for x in xs]
    if not rle:
        body = b"".join(stream)
    else:                                   # packets across the whole picture (so across rows)
        body, i = bytearray(), 0
        while i < len(stream):
            n = 1
            while i + n < len(stream) and n < 128 and stream[i + n] == stream[i]: n += 1
            if n >= 2:
                body += bytes((0x80 | (n - 1),)) + stream[i]; i += n
            else:
                j = i + 1
                while j < len(stream) and j - i < 128 and not (j + 1 < len(stream) and stream[j + 1] == stream[j]): j += 1
                body += bytes((j - i - 1,)) + b"".join(stream[i:j]); i = j
    return hdr + idtext + mapdata + bytes(body)

def tga_expected(rows, kind, depth, cmap=None, cfirst=0, csize=24):
    def q(c, bits):
        if bits in (15, 16): return tuple(five(v >> 3) for v in c)
        return tuple(c)
    if kind == 2: return [[q(c, depth) for c in r] for r in rows]
    if kind == 3: return [[(v, v, v) for v in r] for r in rows]
    return [[q(cmap[v - cfirst], csize) if 0 <= v - cfirst < len(cmap) else (0, 0, 0) for v in r] for r in rows]

S = scene(100, 60)
for name, kw in [("T24.TGA", dict(depth=24)), ("T24TOP.TGA", dict(depth=24, top=True)),
                 ("T32.TGA", dict(depth=32, top=True, alpha=lambda x, y: (x * 3) & 255)),
                 ("T16.TGA", dict(depth=16)), ("T15RLE.TGA", dict(depth=15, rle=True)),
                 ("T24RLE.TGA", dict(depth=24, rle=True)), ("T24RTL.TGA", dict(depth=24, rtl=True)),
                 ("T32RLE.TGA", dict(depth=32, rle=True, alpha=lambda x, y: 0)),
                 ("TID.TGA", dict(depth=24, idtext=b"MegaconvertGS test picture"))]:
    save(name, tga(name, S, 2, **kw), "tga", tga_expected(S, 2, kw["depth"]), 100, 60)
pal = [((i * 37) & 255, (i * 91) & 255, (255 - i * 5) & 255) for i in range(200)]
idx = [[(x // 4 + y // 3 * 7) % 200 for x in range(90)] for y in range(50)]
save("TMAP.TGA", tga("TMAP.TGA", idx, 1, 8, cmap=pal), "tga", tga_expected(idx, 1, 8, pal), 90, 50)
pal16 = pal[:120]
idx2 = [[10 + ((x // 3 + y) % 120) if (x + y) % 17 else 3 for x in range(90)] for y in range(50)]
save("TMAPRLE.TGA", tga("TMAPRLE.TGA", idx2, 1, 8, rle=True, cmap=pal16, cfirst=10, csize=16), "tga",
     tga_expected(idx2, 1, 8, pal16, 10, 16), 90, 50)
grey = [[(x * 3 + y * 2) & 255 if (x // 10) % 2 else 128 for x in range(80)] for y in range(40)]
save("TGREY.TGA", tga("TGREY.TGA", grey, 3, 8), "tga", tga_expected(grey, 3, 8), 80, 40)
save("TGREYRLE.TGA", tga("TGREYRLE.TGA", grey, 3, 8, rle=True, top=True), "tga", tga_expected(grey, 3, 8), 80, 40)
# One as macOS writes it.
src = os.path.join(root, "build", "fixtures", "true", "RGB8.PNG")
dst = os.path.join(out, "SIPS.TGA")
if os.path.exists(src) and subprocess.run(["sips", "-s", "format", "tga", src, "--out", dst],
                                          capture_output=True).returncode == 0:
    w, h, px = read_png(src)
    rows = [[tuple(px[(y * w + x) * 3:(y * w + x) * 3 + 3]) for x in range(w)] for y in range(h)]
    save("SIPS.TGA", open(dst, "rb").read(), "tga", rows, w, h)


# ---- PICT ----
def be(*v): return b"".join(struct.pack(">H", x & 0xFFFF) for x in v)
def be32(v): return struct.pack(">I", v)

def packbits(data):
    out, i = bytearray(), 0
    while i < len(data):
        n = 1
        while i + n < len(data) and n < 128 and data[i + n] == data[i]: n += 1
        if n >= 3:
            out += bytes((257 - n,)) + data[i:i + 1]; i += n
        else:
            j = i
            while j < len(data) and j - i < 128:
                if j + 2 < len(data) and data[j] == data[j + 1] == data[j + 2]: break
                j += 1
            out += bytes((j - i - 1,)) + data[i:j]; i = j
    return bytes(out)

def packwords(words):
    out, i = bytearray(), 0
    while i < len(words):
        n = 1
        while i + n < len(words) and n < 128 and words[i + n] == words[i]: n += 1
        if n >= 2:
            out += bytes((257 - n,)) + be(words[i]); i += n
        else:
            j = i
            while j < len(words) and j - i < 128 and not (j + 1 < len(words) and words[j + 1] == words[j]): j += 1
            out += bytes((j - i - 1,)) + be(*words[i:j]); i = j
    return bytes(out)

class Pict:
    """A picture: frame (top, left, bottom, right); images drawn as QuickDraw would."""
    def __init__(self, frame, v=2):
        self.frame, self.v, self.body = frame, v, bytearray()
        t, l, b, r = frame
        self.canvas = None
        self.scale = None
    def op(self, n, data=b""):
        if self.v == 2:
            if len(self.body) % 2: self.body += b"\0"
            self.body += be(n)
        else:
            self.body += bytes((n,))
        self.body += data
    def image(self, opno, head, rows_data, src, dst, bounds, colours, rgn=False):
        """colours: rows of RGB for the bounds' pixels."""
        rect = lambda r: be(*r)
        data = head + rect(src) + rect(dst) + be(0)
        if rgn: data += be(10) + rect(dst)
        self.op(opno, data + rows_data)
        if self.scale is None:
            nx, dx = src[3] - src[1], dst[3] - dst[1]
            ny, dy = src[2] - src[0], dst[2] - dst[0]
            self.scale = (nx, dx, ny, dy)
            fw, fh = self.frame[3] - self.frame[1], self.frame[2] - self.frame[0]
            self.w, self.h = fw * nx // dx, fh * ny // dy
            self.canvas = [[(255, 255, 255)] * self.w for _ in range(self.h)]
        nx, dx, ny, dy = self.scale
        ox = (dst[1] - self.frame[1]) * nx // dx + bounds[1] - src[1]
        oy = (dst[0] - self.frame[0]) * ny // dy + bounds[0] - src[0]
        for j, row in enumerate(colours):
            for i, c in enumerate(row):
                by, bx = bounds[0] + j, bounds[1] + i
                if not (src[0] <= by < src[2] and src[1] <= bx < src[3]): continue
                X, Y = i + ox, j + oy
                if 0 <= X < self.w and 0 <= Y < self.h: self.canvas[Y][X] = c
    def data(self, header=False):
        out = be(0) + be(*self.frame)
        if self.v == 2:
            out += be(0x0011, 0x02FF, 0x0C00, 0xFFFE, 0) + be32(0x00480000) * 2 + be(*self.frame) + be32(0)
        else:
            out += b"\x11\x01"
        body = bytes(self.body)
        end = (b"\0" if self.v == 2 and len(body) % 2 else b"") + (be(0x00FF) if self.v == 2 else b"\xff")
        return (bytes(512) if header else b"") + out + body + end

def pixhead(rowbytes, bounds, packtype, pixtype, size, cmp, csize):
    return be(rowbytes | 0x8000, *bounds) + be(0, packtype) + be32(0) + be32(0x00480000) * 2 + \
        be(pixtype, size, cmp, csize) + be32(0) * 3

def rowcount(rb, n): return bytes((n,)) if rb <= 250 else be(n)

def indexed(p, idx, pal, bits, bounds, src=None, dst=None, packed=True, device=False, rgn=False, bitmap=False):
    h, w = len(idx), len(idx[0])
    assert bounds[2] - bounds[0] == h and bounds[3] - bounds[1] == w
    src = src or bounds; dst = dst or bounds
    rb = ((w * bits + 15) // 16) * 2
    if bitmap:
        head = be(rb, *bounds)
        colours = [[(0, 0, 0) if v else (255, 255, 255) for v in r] for r in idx]
    else:
        head = pixhead(rb, bounds, 0, 0, bits, 1, bits)
        order = list(range(len(pal)))
        head += be32(0) + be(0x8000 if device else 0, len(pal) - 1)
        values = order if device else [len(pal) - 1 - k for k in order]   # (by value: listed backwards)
        table = {}
        for k in order:
            v = k if device else values[k]
            head += be(0 if device else v) + be(*(c * 257 for c in pal[v]))
            table[v] = pal[v]
        colours = [[table.get(v, (0, 0, 0)) for v in r] for r in idx]
    rows = bytearray()
    for r in idx:
        bitsrow = 0
        for v in r: bitsrow = (bitsrow << bits) | v
        bitsrow <<= rb * 8 - w * bits
        raw = bitsrow.to_bytes(rb, "big")
        if packed and rb >= 8:
            pk = packbits(raw); rows += rowcount(rb, len(pk)) + pk
        else:
            rows += raw
    p.image((0x98 if packed else 0x90) | (1 if rgn else 0), head, bytes(rows), src, dst, bounds, colours, rgn)

def direct(p, rows_rgb, bits, packtype, bounds, src=None, dst=None, cmp=3, alpha=0):
    h, w = len(rows_rgb), len(rows_rgb[0])
    src = src or bounds; dst = dst or bounds
    rb = w * (4 if bits == 32 else 2)
    head = be32(0xFF) + pixhead(rb, bounds, packtype, 16, bits, cmp, 8 if bits == 32 else 5)
    data, colours = bytearray(), []
    for y, r in enumerate(rows_rgb):
        if bits == 16:
            words = [((c[0] >> 3) << 10) | ((c[1] >> 3) << 5) | (c[2] >> 3) for c in r]
            colours.append([tuple(five(v >> 3) for v in c) for c in r])
            if packtype == 1 or rb < 8: data += be(*words)
            else:
                pk = packwords(words); data += rowcount(rb, len(pk)) + pk
        else:
            colours.append(list(r))
            if packtype == 1 or rb < 8: data += b"".join(bytes((alpha,) + c) for c in r)
            elif packtype == 2: data += b"".join(bytes(c) for c in r)
            else:
                planes = ([bytes([(x * 7 + y) & 255 for x in range(w)])] if cmp == 4 else []) + \
                         [bytes(c[k] for c in r) for k in range(3)]
                pk = packbits(b"".join(planes)); data += rowcount(rb, len(pk)) + pk
    p.image(0x9A, head, bytes(data), src, dst, bounds, colours)

def skips(p):
    """Commands that are passed over."""
    p.op(0x1E)                                    # DefHilite
    p.op(0x01, be(10, 0, 0, 500, 500))            # Clip
    p.op(0xA1, be(100, 5) + b"odd!!")             # LongComment, odd length
    p.op(0x03, be(4)); p.op(0x0D, be(12))         # TxFont, TxSize
    p.op(0x1A, be(1, 2, 3))                       # RGBFgCol
    p.op(0x29, bytes((5, 3)) + b"Hi!")            # DHText
    p.op(0x22, be(1, 2) + b"\x01\x02")            # ShortLine
    p.op(0x31, be(0, 0, 5, 5))                    # paintRect
    p.op(0x70, be(18, 0, 0, 5, 5, 0, 0, 5, 5))    # framePoly
    if p.v == 2:
        p.op(0x0200, b"abcd")                     # (reserved: 4 bytes)
        p.op(0x8201, be32(3) + b"xyz")            # (reserved: a long length)
        p.op(0xA0, be(1))                         # ShortComment

def pict_save(name, p, header=False):
    save(name, p.data(header), "pict", p.canvas, p.w, p.h)

pal = [((i * 53) & 255, (i * 29 + 40) & 255, (200 - i) & 255) for i in range(200)]
def pattern(w, h, n, f=lambda x, y: x // 3 + y // 2):
    return [[(f(x, y) if (x // 9 + y // 7) % 3 else 1) % n for x in range(w)] for y in range(h)]

p = Pict((0, 0, 40, 300)); skips(p)
indexed(p, pattern(300, 40, 200), pal, 8, (0, 0, 40, 300)); pict_save("P8.PCT", p)
p = Pict((10, 20, 60, 140))
indexed(p, pattern(120, 50, 100), pal[:100], 8, (10, 20, 60, 140), device=True); pict_save("P8HDR.PCT", p, header=True)
p = Pict((0, 0, 33, 77)); skips(p)
indexed(p, pattern(77, 33, 16), pal[:16], 4, (0, 0, 33, 77)); pict_save("P4.PCT", p)
p = Pict((0, 0, 30, 90))
indexed(p, pattern(90, 30, 4), pal[:4], 2, (0, 0, 30, 90), packed=False); pict_save("P2.PCT", p)
p = Pict((0, 0, 48, 200), v=1); skips(p)
indexed(p, pattern(200, 48, 2, lambda x, y: (x * x + y * 3) // 7), None, 1, (0, 0, 48, 200), bitmap=True)
pict_save("P1V1.PCT", p)
p = Pict((0, 0, 20, 40))
indexed(p, pattern(40, 20, 2), None, 1, (0, 0, 20, 40), bitmap=True, rgn=True); pict_save("P1RGN.PCT", p)
img = scene(100, 60)
for name, kw in [("P32.PCT", dict(packtype=4)), ("P32P0.PCT", dict(packtype=0)),
                 ("P32A.PCT", dict(packtype=4, cmp=4)), ("P32U.PCT", dict(packtype=1)),
                 ("P24.PCT", dict(packtype=2))]:
    p = Pict((0, 0, 60, 100)); skips(p)
    direct(p, img, 32, bounds=(0, 0, 60, 100), **kw); pict_save(name, p)
for name, pt in [("P16.PCT", 3), ("P16P0.PCT", 0), ("P16U.PCT", 1)]:
    p = Pict((0, 0, 60, 100)); skips(p)
    direct(p, img, 16, pt, (0, 0, 60, 100)); pict_save(name, p)
p = Pict((0, 0, 60, 100))
direct(p, img[:30], 32, 4, (0, 0, 30, 100)); p.op(0xA0, be(2))
direct(p, img[30:], 32, 4, (30, 0, 60, 100)); pict_save("PBAND.PCT", p)
p = Pict((0, 0, 30, 50))
direct(p, img, 32, 4, (0, 0, 60, 100), dst=(0, 0, 30, 50)); pict_save("PSCALE.PCT", p)
p = Pict((0, 0, 60, 100))
indexed(p, pattern(60, 40, 200), pal, 8, (0, 0, 40, 60), src=(5, 5, 35, 55), dst=(10, 20, 40, 70))
indexed(p, pattern(60, 40, 200, lambda x, y: x + y), pal, 8, (0, 0, 40, 60), dst=(30, 70, 70, 130))
pict_save("PPART.PCT", p)
# Two as ImageMagick writes them (with a Mac file's 512 bytes): 256 colours, and true colour.
magick = shutil.which("magick")
if magick and os.path.exists(src):
    for name, args in (("MAGICK8.PCT", ["-colors", "256", "-type", "Palette"]), ("MAGICK32.PCT", ["-type", "TrueColor"])):
        dst = os.path.join(out, name)
        subprocess.run([magick, src] + args + ["PICT:" + dst], check=True, capture_output=True)
        ref = dst + ".png"
        subprocess.run([magick, src] + args + ["-depth", "8", "PNG24:" + ref], check=True, capture_output=True)
        w, h, px = read_png(ref)
        os.remove(ref)
        save(name, open(dst, "rb").read(), "pict",
             [[tuple(px[(y * w + x) * 3:(y * w + x) * 3 + 3]) for x in range(w)] for y in range(h)], w, h)


# ---- ZX Spectrum (screen images: the expected colours are the Super Hi-Res palette's) ----
def shr(c): return tuple(((c >> s) & 15) * 17 for s in (8, 4, 0))
ZXPAL = [0x000, 0x00D, 0xD00, 0xD0D, 0x0D0, 0x0DD, 0xDD0, 0xDDD,
         0x000, 0x00F, 0xF00, 0xF0F, 0x0F0, 0x0FF, 0xFF0, 0xFFF]

def zx(bits, attrs):
    """bits[y][x] 0/1 for 256 x 192; attrs[row][col] (24 x 32) or None."""
    d = bytearray(6144 if attrs is None else 6912)
    for y in range(192):
        for xb in range(32):
            v = 0
            for b in range(8): v = v << 1 | bits[y][xb * 8 + b]
            d[((y & 0xC0) << 5) | ((y & 7) << 8) | ((y & 0x38) << 2) | xb] = v
    if attrs is not None:
        for r in range(24):
            for c in range(32): d[6144 + r * 32 + c] = attrs[r][c]
    rows = []
    for y in range(192):
        row = []
        for x in range(256):
            a = 0x38 if attrs is None else attrs[y >> 3][x >> 3]
            i = (a & 7) if bits[y][x] else (a >> 3) & 7
            if a & 0x40: i += 8
            row.append(shr(ZXPAL[i]))
        rows.append(row)
    return bytes(d), rows

zbits = [[1 if ((x * 7 + y * 3) % 11 < 4 or (x // 16 + y // 12) % 5 == 0) else 0 for x in range(256)] for y in range(192)]
zattr = [[(r * 32 + c) * 37 % 256 for c in range(32)] for r in range(24)]   # every ink, paper, bright, flash
data, rows = zx(zbits, zattr)
save("ZX.SCR", data, "zx", rows, 256, 192)
data, rows = zx(zbits, None)
save("ZXBW.SCR", data, "zx", rows, 256, 192)

# ---- MSX (BSAVE files) ----
MS3 = [0, 36, 73, 109, 146, 182, 219, 255]
MSOWN = [(0, 0, 0), (0, 0, 0), (1, 6, 1), (3, 7, 3), (1, 1, 7), (2, 3, 7), (5, 1, 1), (2, 6, 7),
         (7, 1, 1), (7, 3, 3), (6, 6, 1), (6, 6, 4), (1, 4, 1), (6, 2, 5), (5, 5, 5), (7, 7, 7)]
MSPAL4 = [0x000, 0x000, 0x2D2, 0x6F6, 0x22F, 0x46F, 0xB22, 0x4DF,
          0xF22, 0xF66, 0xDD2, 0xDD9, 0x292, 0xD4B, 0xBBB, 0xFFF]

def bsave(vram, start, end):
    return bytes([0xFE]) + struct.pack("<HHH", start, end, start) + bytes(vram[start:end + 1])

# Screen 2: names in another order than 0-255, each cell line with its own colours.
vram = bytearray(0x10000)
for i in range(768): vram[0x1800 + i] = (i * 13 + 7) % 256
for t in range(3):
    for n in range(256):
        for l in range(8):
            vram[t * 2048 + n * 8 + l] = (n * 29 + l * 7 + t * 3) & 255
            vram[0x2000 + t * 2048 + n * 8 + l] = ((n + l + t) % 16) << 4 | (n * 3 + l) % 16
rows = []
for y in range(192):
    row = []
    t, l = y >> 6, y & 7
    for x in range(256):
        name = vram[0x1800 + (y >> 3) * 32 + (x >> 3)]
        bits, col = vram[t * 2048 + name * 8 + l], vram[0x2000 + t * 2048 + name * 8 + l]
        i = col >> 4 if bits >> (7 - (x & 7)) & 1 else col & 15
        row.append(shr(MSPAL4[i]))
    rows.append(row)
save("MSX.SC2", bsave(vram, 0, 0x37FF), "msx2", rows, 256, 192)

def msx_palette(pal):
    """16 (r, g, b) of 3 bits as the video memory's 32 bytes."""
    return b"".join(bytes(((r << 4) | b, g)) for r, g, b in pal)

def nibble_screen(name, fid, w, palat, own_pal, ext_end):
    vram = bytearray(0x10000)
    per = w // 2
    for y in range(212):
        for xb in range(per):
            vram[y * per + xb] = ((xb * 3 + y) % 16) << 4 | (xb + y * 5) % 16
    pal = [((i * 3) % 8, (i * 5 + 1) % 8, (7 - i) % 8) for i in range(16)]
    if not own_pal: vram[palat:palat + 32] = msx_palette(pal)
    use = MSOWN if own_pal else pal
    rows = []
    for y in range(212):
        row = []
        for x in range(w):
            v = vram[y * per + x // 2]
            i = v >> 4 if x % 2 == 0 else v & 15
            r, g, b = use[i]
            row.append((MS3[r], MS3[g], MS3[b]))
        rows.append(row)
    save(name, bsave(vram, 0, ext_end), fid, rows, w, 212)

nibble_screen("MSX.SC5", "msx5", 256, 0x7680, False, 0x769F)
nibble_screen("MSXOWN.GE5", "msx5", 256, 0x7680, True, 0x69FF)
nibble_screen("MSX.SC7", "msx7", 512, 0xFA80, False, 0xFA9F)

vram = bytearray(0x10000)
for y in range(212):
    for x in range(256): vram[y * 256 + x] = (x + y * 3) & 255
rows = [[(MS3[(v >> 2) & 7], MS3[v >> 5], (0, 85, 170, 255)[v & 3]) for v in vram[y * 256:y * 256 + 256]] for y in range(212)]
save("MSX.SC8", bsave(vram, 0, 0xD3FF), "msx8", rows, 256, 212)


# ---- Commodore 64: Art Studio (hires) and Advanced Art Studio (multicolour) ----
C64PAL = [0x000, 0xFFF, 0xD00, 0x0DD, 0xD0D, 0x0D0, 0x00D, 0xFE0,
          0xF70, 0xB50, 0xF88, 0x666, 0x999, 0xBFB, 0xBBF, 0xCCC]
bitmap = bytes((i * 73 + (i >> 5) * 11) & 255 for i in range(8000))
screen = bytes((i * 29 + 5) & 255 for i in range(1000))
colram = bytes((i * 7 + 3) & 15 for i in range(1000))
rows = []
for y in range(200):
    row = []
    for x in range(320):
        cell = (y >> 3) * 40 + (x >> 3)
        b = bitmap[cell * 8 + (y & 7)]
        row.append(shr(C64PAL[screen[cell] >> 4 if b >> (7 - (x & 7)) & 1 else screen[cell] & 15]))
    rows.append(row)
save("ARTST.ART", b"\x00\x20" + bitmap + screen + bytes((6,)) + bytes(6), "artst", rows, 320, 200)
back = 11
rows = []
for y in range(200):
    row = []
    for x in range(160):
        cell = (y >> 3) * 40 + (x >> 2)
        pair = bitmap[cell * 8 + (y & 7)] >> (6 - 2 * (x & 3)) & 3
        c = (back, screen[cell] >> 4, screen[cell] & 15, colram[cell] & 15)[pair]
        row += [shr(C64PAL[c])] * 2
    rows.append(row)
save("AAS.AAS", b"\x00\x20" + bitmap + screen + bytes((6, back)) + bytes(14) + colram, "aas", rows, 320, 200)

# ---- Amstrad CPC screens (16K, line y at (y & 7) x 2048 + (y >> 3) x 80) ----
CPCPAL = [0x008, 0xFF0, 0x0FF, 0xF00, 0xFFF, 0x000, 0x00F, 0xF0F,
          0x088, 0x880, 0x88F, 0xF88, 0x0F0, 0x8F8, 0x008, 0xF88]
cpc = bytearray((i * 37 + (i >> 7) * 5) & 255 for i in range(16384))
def line(y): return (y & 7) * 2048 + (y >> 3) * 80
def amsdos(body):
    h = bytearray(128)
    h[1:9] = b"SCREEN  "; h[9:12] = b"SCR"; h[18] = 2
    h[24:26] = struct.pack("<H", len(body)); h[64:66] = struct.pack("<H", len(body))
    h[67:69] = struct.pack("<H", sum(h[:67]))
    return bytes(h) + body
for mode, name, head in ((0, "CPC0.SCR", False), (1, "CPC1.SCR", True), (2, "CPC2.SCR", False)):
    rows = []
    for y in range(200):
        row = []
        for xb in range(80):
            b = cpc[line(y) + xb]
            if mode == 0:
                for sh in (0, 1):
                    v = b << sh & 255
                    i = (v >> 7 & 1) | (v >> 3 & 1) << 1 | (v >> 5 & 1) << 2 | (v >> 1 & 1) << 3
                    row += [shr(CPCPAL[i])] * 2
            elif mode == 1:
                for k in range(4): row.append(shr(CPCPAL[(b >> (7 - k) & 1) | (b >> (3 - k) & 1) << 1]))
            else:
                for k in range(8): row.append(shr(CPCPAL[b >> (7 - k) & 1]))
        rows.append(row)
    save(name, amsdos(bytes(cpc)) if head else bytes(cpc), "cpc%d" % mode, rows, 640 if mode == 2 else 320, 200)

# Named as a PICT, but a PPM: Open goes on to what it is.
ppm_rows = scene(40, 30)
save("NOTPICT.PCT", b"P6 40 30 255\n" + bytes(c for r in ppm_rows for p in r for c in p), "pnm", ppm_rows, 40, 30)

open(os.path.join(sys.argv[1], "newfmt.types"), "w").write("".join(f"{n} {t}\n" for n, t in types))
open(os.path.join(sys.argv[1], "newfmt.list"), "w").write("".join(f"{n} {f}\n" for n, f in listing))
