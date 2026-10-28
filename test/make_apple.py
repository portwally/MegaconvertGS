# Makes Apple II and IIgs test files in build/fixtures/apple, each named after
# the format's short id, plus a list of (file, id) to load in apple.list.
import sys, os, math, struct, random

out = sys.argv[1]
fix = os.path.join(os.path.dirname(out), "")
os.makedirs(out, exist_ok=True)
rnd = random.Random(1987)
items = []

def save(name, data, fmt, auto=False):
    open(os.path.join(out, name), "wb").write(bytes(data))
    items.append((name, fmt, auto))

def scene(w, h):
    rows = []
    for y in range(h):
        row = []
        for x in range(w):
            X, Y = x * 320 / w, y * 200 / h
            t = Y / 200
            r, g, b = 40 + 200 * t, 30 + 90 * t * t, 160 - 100 * t
            if math.hypot(X - 210, Y - 80) < 30: r, g, b = 255, 230, 140
            if 30 < X < 90 and 120 < Y < 180: r, g, b = 20, 160, 60
            row.append((int(r) & 255, int(g) & 255, int(b) & 255))
        rows.append(row)
    return rows

def packbytes(data):
    """Apple PackBytes: runs (flag 01) and literals (flag 00), at most 64 each."""
    o, i = bytearray(), 0
    while i < len(data):
        j = i
        while j < len(data) and j - i < 64 and data[j] == data[i]: j += 1
        if j - i >= 3:
            o += bytes([0x40 | (j - i - 1), data[i]]); i = j; continue
        j = i
        while j < len(data) and j - i < 64 and not (j + 2 < len(data) and data[j] == data[j + 1] == data[j + 2]): j += 1
        o += bytes([j - i - 1]) + data[i:j]; i = j
    return bytes(o)

def runs(data):
    """SuperConvert's own run coding: op 0 (byte repeated n+1 times, n < 32),
    op 1 (13-bit count), op 6 (n literal bytes), op 7 (13-bit count), op 2 (2-byte unit)."""
    o, i = bytearray(), 0
    while i < len(data):
        j = i
        while j < len(data) and data[j] == data[i] and j - i < 8000: j += 1
        n = j - i
        if n >= 3:
            if n <= 32: o += bytes([(0 << 5) | (n - 1), data[i]])
            else: o += bytes([(1 << 5) | ((n - 1) >> 8), (n - 1) & 255, data[i]])
            i = j; continue
        if i + 6 <= len(data) and data[i:i + 2] == data[i + 2:i + 4] == data[i + 4:i + 6]:
            k = i
            while k + 2 <= len(data) and data[k:k + 2] == data[i:i + 2] and (k - i) // 2 < 32: k += 2
            o += bytes([(2 << 5) | ((k - i) // 2 - 1)]) + data[i:i + 2]; i = k; continue
        j = i
        while j < len(data) and j - i < 6000 and not (j + 2 < len(data) and data[j] == data[j + 1] == data[j + 2]): j += 1
        n = j - i
        if n < 32: o += bytes([(6 << 5) | n]) + data[i:j]
        else: o += bytes([(7 << 5) | (n >> 8), n & 255]) + data[i:j]
        i = j
    return bytes(o)

def lzw(data):
    """GIF-style LZW with 8-bit symbols, as DreamGrafix writes it."""
    clear, end = 256, 257
    acc = bytearray(); buf = nbits = 0
    def emit(code, size):
        nonlocal buf, nbits
        buf |= code << nbits; nbits += size
        while nbits >= 8: acc.append(buf & 255); buf >>= 8; nbits -= 8
    size, nxt = 9, 258
    table = {bytes([i]): i for i in range(256)}
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
            emit(clear, size); table = {bytes([i]): i for i in range(256)}; size, nxt = 9, 258
        w = bytes([c])
    emit(table[w], size); emit(end, size)
    if nbits: acc.append(buf & 255)
    return bytes(acc)

# Apple II screens
hgr = bytearray(8192)
for y in range(192):
    base = (y & 7) * 0x400 + ((y >> 3) & 7) * 0x80 + (y >> 6) * 0x28
    for c in range(40):
        v = (c * 5 + y * 3) % 128 if (y // 16 + c // 4) % 3 else rnd.randrange(256)
        hgr[base + c] = v | (0x80 if (c + y // 24) % 2 else 0)
save("HGR.PIC", hgr, "hgr", auto=True)
save("HGRBW.PIC", hgr[:8184], "hgrbw")
dhr = bytearray(rnd.randrange(256) if (i // 40) % 3 == 0 else (i * 7) & 0x7F for i in range(16384))
save("DHR.PIC", dhr, "dhr", auto=True)
save("DHRBW.PIC", dhr, "dhrbw")

# Print Shop
ps = bytearray(((x * 11 + y) % 7 == 0) * 0xFF ^ rnd.randrange(16) for y in range(52) for x in range(11))
save("PSBW.GR", ps, "psbw", auto=True)
psgs = bytearray(rnd.randrange(256) for _ in range(1716))
save("PSGS.GR", psgs, "psgs", auto=True)
cgt = psgs + bytearray(rnd.randrange(256) for _ in range(1716)) + b"BIRD\0TREE\0"
save("GRAPHIC.CGT0", cgt, "cgt")

# Finder icon file: header, one icon record (large and small icons)
def icon_image(w, h, seed):
    r = random.Random(seed)
    row = w // 2
    img = bytes(r.randrange(256) for _ in range(row * h))
    mask = bytes((0xFF if 2 <= y < h - 2 else 0x0F) for y in range(h) for _ in range(row))
    return struct.pack("<HHHH", 0x8000, row * h, h, w) + img + mask
large, small = icon_image(30, 14, 1), icon_image(10, 6, 2)
rec = struct.pack("<H", 86 + len(large) + len(small)) + bytes(64)          # length, path (unused)
rec += bytes([5]) + b"HELLO" + bytes(10) + bytes(82 - 82)
rec = rec[:66] + bytes([5]) + b"HELLO" + bytes(10)
rec += struct.pack("<HHHH", 0x0006, 0, 0, 0)                               # type and aux etc.
rec = rec[:86] + large + small
rec = struct.pack("<H", len(rec)) + rec[2:]
icons = bytes(4) + struct.pack("<H", 1) + bytes(20) + rec + struct.pack("<H", 0)
save("ICONS", icons, "icon", auto=True)

# ThunderScan: 256-byte header, 4-bit grey
for name, w, h, tall in (("SCAN1", 200, 90, 0), ("SCAN2", 120, 160, 1)):
    hd = bytearray(256)
    struct.pack_into("<H", hd, 0x0F, w); struct.pack_into("<H", hd, 0x1E, h - 1); hd[0x0A] = tall
    data = bytes((((x * 15 // (w // 2)) << 4) | ((y * 15) // h)) for y in range(h) for x in range(w // 2))
    save(name, hd + data, "tscan")

# TDM text screens: codes for text, inverse and flashing characters
t40 = bytearray(1024)
for row in range(24):
    base = (row & 7) * 0x80 + (row >> 3) * 0x28
    for col in range(40):
        t40[base + col] = (0xA0 + (row * 40 + col) % 96) if row % 4 else (row * 40 + col) % 128
save("TEXT40", t40, "tdm40")
t80 = bytearray(2048)
for row in range(24):
    base = (row & 7) * 0x80 + (row >> 3) * 0x28
    for col in range(80):
        at = base + col // 2 + (1024 if col & 1 else 0)
        t80[at] = (0xC1 + (row + col) % 58) if (row + col) % 5 else 0x60 + col % 32
save("TEXT80", t80, "tdm80")

# 3200 color pictures
img = scene(320, 200)
pix = bytearray(32000); tables = bytearray()
for y in range(200):
    tab = [((y * 3 + i * 7) % 16) << 8 | (i << 4) | ((y // 13 + i) % 16) for i in range(16)]
    for x in range(320):
        r, g, b = img[y][x]
        v = (r // 16 + g // 32 + x // 40) % 16
        pix[y * 160 + x // 2] |= v << 4 if x % 2 == 0 else v
    tables += b"".join(struct.pack("<H", c) for c in reversed(tab))
save("BROOKS.3200", pix + tables, "3200", auto=True)
save("APP.3201", b"APP\0" + tables + packbytes(pix), "3200c", auto=True)
t = runs(bytes(tables)); p = runs(bytes(pix))
save("SC.3200C", b"SC4\0\0" + struct.pack("<H", len(t)) + t + p, "3200c")

# DreamGrafix: a $C1 screen and a 3200 picture, LZW packed
shr = open(os.path.join(sys.argv[2], "S320.c1"), "rb").read()
save("DG.SHR", lzw(shr), "drm")
save("DG.3200", lzw(bytes(pix + tables)), "drm3200")

# Digitizers
ast = bytearray(96000)
for p in range(3):
    for y in range(200):
        for x in range(320):
            v = img[y][x][p] >> 4
            ast[p * 32000 + y * 160 + x // 2] |= v << 4 if x % 2 == 0 else v
save("AST.PIC", ast, "ast", auto=True)
for name, stride in (("CEYES1", 64000), ("CEYES2", 65535)):
    ce = bytearray(stride * 3 if stride == 65535 else stride * 2 + 64000)
    for p in range(3):
        for x in range(320):
            for y in range(200):
                ce[p * stride + x * 200 + y] = (img[y][x][p] >> 2) | (0xC0 if (x + y) % 9 == 0 else 0)
    save(name, ce, "ceyes", auto=True)

# Paintworks Gold: a 320-header Apple Preferred file, a raw screen, a Paint file
save("PWG.APF", open(os.path.join(sys.argv[2], "S320.apf"), "rb").read(), "pwgold")
save("PWG.SHR", shr, "pwgold")
paint = bytearray(0x222) + packbytes(shr[:160 * 150])
save("PWG.PNT", paint, "pwgold")

with open(os.path.join(out, "..", "apple.list"), "w") as f:
    for name, fmt, auto in items:
        f.write(f"{name} {fmt} {'auto' if auto else ''}\n")
types = {"ICONS": "CA0000", "DG.SHR": "C08005", "DG.3200": "C08005"}
with open(os.path.join(out, "..", "apple.types"), "w") as f:
    for name, fmt, auto in items:
        f.write(f"{name} {types.get(name, '060000')}\n")
print(len(items), "Apple II and IIgs test files")
