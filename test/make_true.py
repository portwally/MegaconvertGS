# Makes the true colour test pictures (PNG, GIF, BMP, JPEG) in build/fixtures/true,
# drawn from scratch and written by hand, so every variant of each format is covered.
# JPEGs are made with cjpeg. Each file name is a valid ProDOS name.
import sys, os, math, struct, zlib, subprocess

out = sys.argv[1]
os.makedirs(out, exist_ok=True)

def scene(w, h):
    """A sunset over water, with a box and a moon: rows of (r, g, b)."""
    rows = []
    for y in range(h):
        row = []
        Y = y * 200 / h
        for x in range(w):
            X = x * 320 / w
            if Y < 120:
                t = Y / 120
                r, g, b = 40 + 200 * t, 30 + 90 * t * t, 120 - 40 * t
                if math.hypot(X - 210, Y - 95) < 22: r, g, b = 255, 230, 140
                if Y > 100 + 10 * math.sin(X / 23): r, g, b = 60, 30, 70
            else:
                t = (Y - 120) / 80
                r, g, b = 120 - 80 * t, 50 - 20 * t, 90 - 30 * t
                if abs(X - 210 + 6 * math.sin(Y)) < 18 - 10 * t and int(Y) % 3: r, g, b = 250, 190, 110
            if 30 < X < 70 and 140 < Y < 180: r, g, b = 20, 160, 60
            if (X - 60) ** 2 + (Y - 40) ** 2 < 300: r, g, b = 230, 230, 255
            r = int(r) ^ ((x * 7 + y * 3) & 7)   # a little texture, so no two rows are alike
            row.append((max(0, min(255, r)), int(g), int(b)))
        rows.append(row)
    return rows

def grey(p): return (5 * p[0] + 8 * p[1] + 3 * p[2]) >> 4

def palette_of(rows, n):
    """A fixed palette of n entries and each pixel's index into it."""
    if n == 256:
        pal = [((i >> 5) * 255 // 7, ((i >> 2) & 7) * 255 // 7, (i & 3) * 85) for i in range(256)]
        idx = [[(p[0] >> 5) << 5 | (p[1] >> 5) << 2 | (p[2] >> 6) for p in row] for row in rows]
    else:
        pal = [(i * 255 // (n - 1), (n - 1 - i) * 255 // (n - 1), (i * 97) % 256) for i in range(n)]
        idx = [[grey(p) * n // 256 for p in row] for row in rows]
    return pal, idx

# ---------- PNG ----------
def pack(samples, depth):
    if depth == 8: return bytes(samples)
    if depth == 16: return b"".join(struct.pack(">H", s) for s in samples)
    out, acc, n = bytearray(), 0, 0
    for s in samples:
        acc = (acc << depth) | s; n += depth
        if n == 8: out.append(acc); acc, n = 0, 0
    if n: out.append(acc << (8 - n))
    return bytes(out)

def filt(raw, prev, bpp, f):
    out = bytearray()
    for i, x in enumerate(raw):
        a = raw[i - bpp] if i >= bpp else 0
        b = prev[i] if prev else 0
        c = prev[i - bpp] if prev and i >= bpp else 0
        if f == 0: v = x
        elif f == 1: v = x - a
        elif f == 2: v = x - b
        elif f == 3: v = x - ((a + b) >> 1)
        else:
            p = a + b - c; pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
            v = x - (a if pa <= pb and pa <= pc else b if pb <= pc else c)
        out.append(v & 255)
    return bytes([f]) + bytes(out)

def png(name, pix, ctype, depth, plte=None, trns=None, interlace=False, level=9, strategy=None):
    """pix: rows of sample tuples (already in the colour type's channels)."""
    h, w = len(pix), len(pix[0])
    ch = len(pix[0][0])
    bpp = max(1, ch * depth // 8)
    passes = [(0, 0, 8, 8), (4, 0, 8, 8), (0, 4, 4, 8), (2, 0, 4, 4), (0, 2, 2, 4), (1, 0, 2, 2), (0, 1, 1, 2)] \
        if interlace else [(0, 0, 1, 1)]
    data, k = bytearray(), 0
    for xs, ys, dx, dy in passes:
        prev = None
        for y in range(ys, h, dy):
            if xs >= w: break
            raw = pack([s for x in range(xs, w, dx) for s in pix[y][x]], depth)
            data += filt(raw, prev, bpp, k % 5); k += 1
            prev = raw
    if strategy is not None:
        c = zlib.compressobj(level, zlib.DEFLATED, 15, 9, strategy); z = c.compress(bytes(data)) + c.flush()
    else:
        z = zlib.compress(bytes(data), level)
    def chunk(t, d): return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d))
    f = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, depth, ctype, 0, 0, int(interlace)))
    if plte: f += chunk(b"PLTE", bytes(c for p in plte for c in p))
    if trns is not None: f += chunk(b"tRNS", trns)
    half = len(z) // 2                                    # two IDAT chunks, to test joining
    f += chunk(b"tEXt", b"Comment\0made for MegaconvertGS") + chunk(b"IDAT", z[:half]) + chunk(b"IDAT", z[half:])
    f += chunk(b"IEND", b"")
    open(os.path.join(out, name), "wb").write(f)

# ---------- GIF ----------
def lzw(data, mincode):
    clear, end = 1 << mincode, (1 << mincode) + 1
    acc = bytearray(); buf = nbits = 0
    def emit(code, size):
        nonlocal buf, nbits
        buf |= code << nbits; nbits += size
        while nbits >= 8: acc.append(buf & 255); buf >>= 8; nbits -= 8
    size = mincode + 1; nxt = end + 1
    table = {bytes([i]): i for i in range(clear)}
    emit(clear, size)
    w = bytes([data[0]])
    for c in data[1:]:
        wc = w + bytes([c])
        if wc in table: w = wc; continue
        emit(table[w], size)
        if nxt < 4096:
            table[wc] = nxt; nxt += 1
            if nxt > (1 << size) and size < 12: size += 1
        else:
            emit(clear, size)
            table = {bytes([i]): i for i in range(clear)}; size = mincode + 1; nxt = end + 1
        w = bytes([c])
    emit(table[w], size); emit(end, size)
    if nbits: acc.append(buf & 255)
    return bytes(acc)

def gif(name, idx, pal, bits, interlace=False, transparent=None, frame=None):
    h, w = len(idx), len(idx[0])
    order = list(range(h))
    if interlace: order = list(range(0, h, 8)) + list(range(4, h, 8)) + list(range(2, h, 4)) + list(range(1, h, 2))
    flat = bytes(v for y in order for v in idx[y])
    mincode = max(2, bits)
    pal = (pal + [(0, 0, 0)] * 256)[:1 << bits]
    f = b"GIF89a" + struct.pack("<HHBBB", w + (frame or 0), h + (frame or 0), 0x80 | 0x70 | (bits - 1), 0, 0)
    f += bytes(c for p in pal for c in p)
    if transparent is not None: f += b"\x21\xF9\x04\x01\x00\x00" + bytes([transparent]) + b"\x00"
    f += b"\x21\xFE\x05hello\x00"                                 # a comment, to be skipped
    f += b"\x2C" + struct.pack("<HHHHB", frame or 0, frame or 0, w, h, 0x40 if interlace else 0)
    z = lzw(flat, mincode)
    f += bytes([mincode]) + b"".join(bytes([len(z[i:i + 255])]) + z[i:i + 255] for i in range(0, len(z), 255))
    f += b"\x00\x3B"
    open(os.path.join(out, name), "wb").write(f)

# ---------- BMP ----------
def bmp(name, rows, bpp, topdown=False, os2=False, pal=None, idx=None, fields=None):
    h, w = len(rows), len(rows[0])
    body = []
    for y in range(h):
        if bpp == 24: r = bytes(c for p in rows[y] for c in (p[2], p[1], p[0]))
        elif bpp == 32: r = bytes(c for p in rows[y] for c in (p[2], p[1], p[0], 0))
        elif bpp == 16:
            if fields: r = b"".join(struct.pack("<H", (p[0] >> 3) << 11 | (p[1] >> 2) << 5 | p[2] >> 3) for p in rows[y])
            else: r = b"".join(struct.pack("<H", (p[0] >> 3) << 10 | (p[1] >> 3) << 5 | p[2] >> 3) for p in rows[y])
        else: r = pack(idx[y], bpp)
        r += b"\0" * (-len(r) % 4)
        body.append(r)
    if not topdown: body.reverse()
    data = b"".join(body)
    if os2:
        info = struct.pack("<IHHHH", 12, w, h, 1, bpp)
        palb = b"".join(bytes((p[2], p[1], p[0])) for p in pal) if pal else b""
    else:
        comp = 3 if fields else 0
        info = struct.pack("<IiiHHIIiiII", 40, w, -h if topdown else h, 1, bpp, comp, len(data), 2835, 2835,
                           len(pal) if pal else 0, 0)
        palb = b"".join(bytes((p[2], p[1], p[0], 0)) for p in pal) if pal else b""
        if fields: palb = struct.pack("<III", 0xF800, 0x07E0, 0x001F)
    off = 14 + len(info) + len(palb)
    open(os.path.join(out, name), "wb").write(struct.pack("<2sIHHI", b"BM", off + len(data), 0, 0, off) + info + palb + data)

# ---------- the pictures ----------
S = scene(157, 93)
big = scene(320, 200)
rgb = [[p for p in row] for row in S]
png("RGB8.PNG", [[p for p in row] for row in big], 2, 8)
png("FIXED.PNG", rgb, 2, 8, strategy=zlib.Z_FIXED)
png("STORED.PNG", scene(61, 47), 2, 8, level=0)
png("RGBA.PNG", [[p + ((0 if (x // 10 + y // 10) % 5 == 0 else 255),) for x, p in enumerate(row)] for y, row in enumerate(S)], 6, 8)
png("GREY8.PNG", [[(grey(p),) for p in row] for row in S], 0, 8)
for d in (1, 2, 4):
    png(f"GREY{d}.PNG", [[(grey(p) >> (8 - d),) for p in row] for row in S], 0, d)
png("GREYKEY.PNG", [[(grey(p) & 0xF0,) for p in row] for row in S], 0, 8, trns=struct.pack(">H", 0x50))
for n, d in ((256, 8), (16, 4), (4, 2), (2, 1)):
    pal, idx = palette_of(S, n)
    png(f"PAL{d}.PNG", [[(i,) for i in row] for row in idx], 3, d, plte=pal)
pal, idx = palette_of(S, 16)
png("INTERP4.PNG", [[(i,) for i in row] for row in idx], 3, 4, plte=pal, interlace=True)
png("TRNS.PNG", [[(i,) for i in row] for row in idx], 3, 4, plte=pal, trns=bytes([255, 0, 255]))
png("RGB16.PNG", [[(p[0] * 257 ^ 0x55, p[1] * 257, p[2] * 257 ^ 0xAA) for p in row] for row in S], 2, 16)
png("INTER.PNG", rgb, 2, 8, interlace=True)
png("GA8.PNG", [[(grey(p), 0 if x % 13 == 0 else 255) for x, p in enumerate(row)] for row in S], 4, 8)
png("RGBKEY.PNG", [[(p[0] & 0xF0, p[1] & 0xF0, p[2] & 0xF0) for p in row] for row in S], 2, 8,
    trns=struct.pack(">HHH", 0x30, 0x10, 0x40))
png("BIG.PNG", scene(400, 300), 2, 8)
# A photograph-like picture: smooth colour waves with a little noise, several hundred
# distinct 12-bit colours (766; the other pictures have 6 to 131).
png("PHOTO.PNG", [[(int(127.5 + 100 * math.sin(x / 47 + y / 71)) ^ ((x * 5 + y * 11) & 3),
                    int(127.5 + 100 * math.sin(y / 53 - x / 89 + 1)),
                    int(100 + 60 * math.cos((x + y) / 67))) for x in range(320)]
                  for y in range(200)], 2, 8)
png("HUGE.PNG", scene(700, 500), 2, 8)

for n, bits, name in ((256, 8, "G8.GIF"), (16, 4, "G16.GIF"), (4, 2, "G4.GIF"), (2, 1, "G2.GIF")):
    pal, idx = palette_of(S, n)
    gif(name, idx, pal, bits)
pal, idx = palette_of(S, 256)
gif("GINTER.GIF", idx, pal, 8, interlace=True)
gif("GTRANS.GIF", idx, pal, 8, transparent=idx[10][10], frame=0)
gif("GFRAME.GIF", idx, pal, 8, frame=9)
pal, idx = palette_of(big, 256)
gif("GBIG.GIF", idx, pal, 8)

bmp("B24.BMP", S, 24)
bmp("B24TD.BMP", S, 24, topdown=True)
bmp("B32.BMP", S, 32)
bmp("BOS2.BMP", S, 24, os2=True)
for n, d in ((256, 8), (16, 4), (2, 1)):
    pal, idx = palette_of(S, n)
    bmp(f"B{d}.BMP", S, d, pal=pal, idx=idx)
bmp("B565.BMP", S, 16, fields=True)
bmp("B555.BMP", S, 16)

def ppm(rows, path, grey_only=False):
    h, w = len(rows), len(rows[0])
    if grey_only: d = b"P5 %d %d 255\n" % (w, h) + bytes(grey(p) for row in rows for p in row)
    else: d = b"P6 %d %d 255\n" % (w, h) + bytes(c for row in rows for p in row for c in p)
    open(path, "wb").write(d)

tmp = os.path.join(out, "src.ppm"); tmpg = os.path.join(out, "src.pgm"); tmpb = os.path.join(out, "big.ppm")
ppm(S, tmp); ppm(S, tmpg, True); ppm(big, tmpb)
for name, args, src in (("J420.JPG", ["-sample", "2x2"], tmp), ("J422.JPG", ["-sample", "2x1"], tmp),
                        ("J444.JPG", ["-sample", "1x1"], tmp), ("JGREY.JPG", ["-grayscale"], tmpg),
                        ("JRST.JPG", ["-restart", "5B"], tmp), ("JOPT.JPG", ["-optimize", "-quality", "95"], tmp),
                        ("JBIG.JPG", ["-quality", "90"], tmpb), ("JPROG.JPG", ["-progressive"], tmp)):
    subprocess.run(["cjpeg"] + args + ["-outfile", os.path.join(out, name), src], check=True)
for f in (tmp, tmpg, tmpb): os.remove(f)
print(len(os.listdir(out)), "true colour pictures")
