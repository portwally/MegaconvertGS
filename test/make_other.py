# Makes test files for the other computers' formats in build/fixtures/other, plus
# other.list (file, format id, "auto" if Open should recognise it) and other.types.
import sys, os, math, struct, random, subprocess

out = sys.argv[1]
os.makedirs(out, exist_ok=True)
for f in os.listdir(out): os.remove(os.path.join(out, f))
rnd = random.Random(2026)
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
            r = int(r) ^ ((x * 5 + y * 3) & 15)
            row.append((max(0, min(255, r)), int(g) & 255, int(b) & 255))
        rows.append(row)
    return rows

def packbits(data):
    """Standard PackBits / ByteRun1: runs of 2-128, literals of 1-128."""
    o, i = bytearray(), 0
    while i < len(data):
        j = i
        while j < len(data) and j - i < 128 and data[j] == data[i]: j += 1
        if j - i >= 2:
            o += bytes([(257 - (j - i)) & 255, data[i]]); i = j; continue
        j = i + 1
        while j < len(data) and j - i < 128 and not (j + 1 < len(data) and data[j] == data[j + 1]): j += 1
        o += bytes([j - i - 1]) + data[i:j]; i = j
    return bytes(o)

def packbytes(data):
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

img = scene(320, 200)

# ---------- Atari ST ----------
def st_memory(res):
    """32000 bytes of screen memory with a picture in it."""
    m = bytearray(32000)
    if res == 0:
        for y in range(200):
            for x in range(320):
                r, g, b = img[y][x]
                v = (r // 64) * 4 + (g // 64) + (x // 80) * 0 if True else 0
                v = ((r >> 6) << 2 | (g >> 6)) ^ ((x // 40 + y // 25) & 1)
                at = y * 160 + (x >> 4) * 8
                for p in range(4):
                    if v >> p & 1: m[at + p * 2 + (0 if (x & 15) < 8 else 1)] |= 0x80 >> (x & 7)
    elif res == 1:
        for y in range(200):
            for x in range(640):
                v = (img[y][x // 2][0] >> 6) ^ ((x // 64) & 1)
                at = y * 160 + (x >> 4) * 4
                for p in range(2):
                    if v >> p & 1: m[at + p * 2 + (0 if (x & 15) < 8 else 1)] |= 0x80 >> (x & 7)
    else:
        for y in range(400):
            for x in range(640):
                if (img[y // 2][x // 2][1] + (x * 7 + y * 3) % 64) > 120: m[y * 80 + x // 8] |= 0x80 >> (x & 7)
    return bytes(m)

def st_palette(ste=False, white0=False):
    pal = []
    for i in range(16):
        r, g, b = (i * 5) % 8, (i * 3 + 2) % 8, (7 - i) % 8
        w = r << 8 | g << 4 | b
        if ste: w |= ((i & 1) << 11) | ((i >> 1 & 1) << 7) | ((i >> 2 & 1) << 3)
        pal.append(w)
    if white0: pal[0] = 0x777
    return pal

def be_words(ws): return b"".join(struct.pack(">H", w) for w in ws)

for res, ext, ste in ((0, "PI1", False), (1, "PI2", True), (2, "PI3", False)):
    save(f"DEGAS.{ext}", struct.pack(">H", res) + be_words(st_palette(ste, res == 2)) + st_memory(res), "degas", True)

def elite(res):
    planes = [4, 2, 1][res]; lines = 400 if res == 2 else 200
    line = 32000 // lines; pb = line // planes
    mem = st_memory(res); raw = bytearray()
    for y in range(lines):
        for p in range(planes):
            for i in range(pb):
                raw.append(mem[y * line + (i // 2) * planes * 2 + p * 2 + (i & 1)])
    return struct.pack(">H", 0x8000 | res) + be_words(st_palette(res == 0)) + packbits(bytes(raw)) + bytes(32)

for res in range(3):
    save(f"ELITE.PC{res + 1}", elite(res), "degaselite", True)

neo = bytearray(128)
struct.pack_into(">H", neo, 2, 0); neo[4:36] = be_words(st_palette())
save("PIC.NEO", neo + st_memory(0), "neo", True)

def tiny(res, extra):
    mem = st_memory(res)
    words = []
    for plane in range(4):
        for col in range(20):
            for row in range(200):
                at = row * 160 + col * 8 + plane * 2
                words.append(mem[at] << 8 | mem[at + 1])
    ctl, data, i = bytearray(), bytearray(), 0
    while i < len(words):
        j = i
        while j < len(words) and words[j] == words[i] and j - i < 3000: j += 1
        n = j - i
        if n >= 2:
            if n < 128: ctl.append(n)
            else: ctl += bytes([0]) + struct.pack(">H", n)
            data += struct.pack(">H", words[i]); i = j; continue
        j = i
        while j < len(words) and j - i < 300 and not (j + 1 < len(words) and words[j] == words[j + 1]): j += 1
        n = j - i
        if n <= 128: ctl.append(256 - n)
        else: ctl += bytes([1]) + struct.pack(">H", n)
        data += b"".join(struct.pack(">H", w) for w in words[i:j]); i = j
    head = bytes([res + (3 if extra else 0)]) + (bytes(4) if extra else b"")
    return head + be_words(st_palette()) + struct.pack(">HH", len(ctl), len(data) // 2) + ctl + data

save("PIC.TNY", tiny(0, False), "tiny", True)
save("ANIM.TN1", tiny(0, True), "tiny", True)

# Spectrum 512
spec_pal = [((y * 7 + i) % 8) << 8 | ((i * 3) % 8) << 4 | ((y + i * 5) % 8) | ((i & 1) << 11 if y % 3 == 0 else 0)
            for y in range(199) for i in range(48)]
spu_mem = bytearray(st_memory(0)); spu_mem[:160] = bytes(160)
save("PIC.SPU", spu_mem + be_words(spec_pal), "spu", True)
planes = bytearray(31840)
for line in range(1, 200):
    for x in range(320):
        v = ((img[line][x][0] >> 4) + x // 20) & 15
        for p in range(4):
            if v >> p & 1: planes[p * 7960 + (line - 1) * 40 + x // 8] |= 0x80 >> (x & 7)
def spc_pack(data):
    o, i = bytearray(), 0
    while i < len(data):
        j = i
        while j < len(data) and j - i < 130 and data[j] == data[i]: j += 1
        if j - i >= 3:
            o += bytes([(2 - (j - i)) & 255, data[i]]); i = j; continue
        j = i + 1
        while j < len(data) and j - i < 128 and not (j + 2 < len(data) and data[j] == data[j + 1] == data[j + 2]): j += 1
        o += bytes([j - i - 1]) + data[i:j]; i = j
    return bytes(o)
bitmap = spc_pack(bytes(planes))
pals = bytearray()
for k in range(199 * 3):
    mask = 0x7FFE if k % 4 else 0xFFFF
    pals += struct.pack(">H", mask)
    for bit in range(16):
        if mask >> bit & 1: pals += struct.pack(">H", spec_pal[(k * 16 + bit) % len(spec_pal)])
save("PIC.SPC", b"SP\0\0" + struct.pack(">II", len(bitmap), len(pals)) + bitmap + pals, "spc", True)

# ---------- Amiga IFF ----------
def chunk(tag, data): return tag + struct.pack(">I", len(data)) + data + (b"\0" if len(data) & 1 else b"")
def ilbm(w, h, planes, value, cmap, camg=None, comp=1, masking=0, chunky=False, old=False):
    rowbytes = (w + 1) & ~1 if chunky else ((w + 15) // 16) * 2
    body = bytearray()
    for y in range(h):
        if chunky:
            row = bytearray(rowbytes)
            for x in range(w): row[x] = value(x, y)
            body += packbits(bytes(row)) if comp else row
            continue
        for p in range(planes + (1 if masking == 1 else 0)):
            row = bytearray(rowbytes)
            for x in range(w):
                v = value(x, y) if p < planes else 0xFF
                if v >> p & 1 if p < planes else True: row[x >> 3] |= 0x80 >> (x & 7)
            body += packbits(bytes(row)) if comp else row
    bmhd = struct.pack(">HHhhBBBBHBBhh", w, h, 0, 0, planes, masking, comp, 0, 0, 10, 11, w, h)
    cm = b"".join(bytes(((c[0] & 0xF0) if old else c[0], (c[1] & 0xF0) if old else c[1], (c[2] & 0xF0) if old else c[2]))
                  for c in cmap)
    data = (b"PBM " if chunky else b"ILBM") + chunk(b"BMHD", bmhd) + (chunk(b"CMAP", cm) if cmap else b"")
    if camg is not None: data += chunk(b"CAMG", struct.pack(">I", camg))
    data += chunk(b"BODY", bytes(body))
    return b"FORM" + struct.pack(">I", len(data)) + data

pal32 = [(i * 8, 255 - i * 7, (i * 37) % 256) for i in range(32)]
save("PIC.IFF", ilbm(160, 100, 5, lambda x, y: (img[y * 2][x * 2][0] >> 3) ^ (x // 16 & 1), pal32), "iff", True)
save("HIRES.IFF", ilbm(200, 80, 4, lambda x, y: (x // 12 + y // 10) & 15, pal32[:16], camg=0x8000, comp=0,
                       masking=1), "iff", True)
save("HAM.IFF", ilbm(120, 60, 6, lambda x, y: ((x * 7 + y * 13) % 64), pal32[:16], camg=0x800), "iff", True)
save("EHB.IFF", ilbm(100, 60, 6, lambda x, y: (x + y * 3) % 64, pal32, camg=0x80), "iff", True)
save("DEEP.IFF", ilbm(64, 40, 24, lambda x, y: (x * 4) | (y * 6) << 8 | ((x + y) * 3 & 255) << 16, []), "iff", True)
save("OLD.IFF", ilbm(80, 50, 4, lambda x, y: (x // 5) & 15, pal32[:16], old=True), "iff", True)
pal256 = [(i, (i * 3) & 255, 255 - i) for i in range(256)]
save("DPAINT.LBM", ilbm(150, 90, 8, lambda x, y: (img[y * 2][x * 2][0] + x) & 255, pal256, chunky=True), "iff", True)

# ---------- Commodore 64 ----------
dd = bytearray(9218)
dd[0:2] = b"\x00\x5c"
for c in range(1000): dd[2 + c] = rnd.randrange(256)
for i in range(8000): dd[1026 + i] = (i * 7 + i // 320) & 255
save("DDPICTURE", dd, "doodle", True)
koala = bytearray(10003)
koala[0:2] = b"\x00\x60"
for i in range(8000): koala[2 + i] = rnd.randrange(256)
for c in range(1000): koala[8002 + c] = (c * 11) & 255; koala[9002 + c] = c & 15
koala[10002] = 6
save("PIC.KOA", koala, "koala", True)
ps = bytearray(8002)
for i in range(8000): ps[2 + i] = 0xAA if (i // 320) % 2 else (i * 3) & 255
save("C64PS.SCR", ps, "c64ps")

# ---------- Macintosh ----------
rows = []
for y in range(720):
    row = bytearray(72)
    for x in range(576):
        if (img[y * 200 // 720][x * 320 // 576][1] + (x ^ y) % 50) > 110: row[x >> 3] |= 0x80 >> (x & 7)
    rows.append(bytes(row))
mac = bytes(512) + b"".join(packbits(r) for r in rows)
save("PAINT.MAC", mac, "mpntmono", True)
save("PAINT640", mac, "mpnt640")
save("PAINT320", mac, "mpnt320")
mb = bytearray(128); mb[1] = 5; mb[2:7] = b"PAINT"; mb[65:69] = b"PNTG"; struct.pack_into(">I", mb, 83, len(mac))
save("PAINTBIN.MAC", mb + mac + bytes(-len(mac) % 128), "mpntmono", True)
sm = bytearray(21888)
for y in range(342):
    for x in range(512):
        if (x * y) % 7 < 3: sm[y * 64 + x // 8] |= 0x80 >> (x & 7)
save("STARTUPSCREEN", sm, "macsm")

# ---------- PC ----------
def gem(w, h, planes, value):
    line = (w + 7) // 8
    data = bytearray(struct.pack(">8H", 1, 8, planes, 2, 85, 85, w, h))
    y = 0
    while y < h:
        rep = 3 if y % 20 == 0 and y + 3 <= h else 1
        if rep > 1: data += bytes([0, 0, 0xFF, rep])
        for p in range(planes):
            row = bytearray(line)
            for x in range(w):
                if value(x, y) >> p & 1: row[x >> 3] |= 0x80 >> (x & 7)
            i = 0
            while i < line:
                if row[i] in (0, 0xFF):
                    j = i
                    while j < line and row[j] == row[i] and j - i < 127: j += 1
                    data.append((0x80 if row[i] else 0) | (j - i)); i = j
                elif i + 4 <= line and row[i:i + 2] == row[i + 2:i + 4]:
                    j = i
                    while j + 2 <= line and row[j:j + 2] == row[i:i + 2] and (j - i) // 2 < 255: j += 2
                    data += bytes([0, (j - i) // 2]) + row[i:i + 2]; i = j
                else:
                    j = min(line, i + 6)
                    data += bytes([0x80, j - i]) + row[i:j]; i = j
        y += rep
    return bytes(data)
save("PIC.IMG", gem(200, 120, 1, lambda x, y: 1 if (img[y][x][0] + x % 13) > 120 else 0), "gem", True)
save("GREY.IMG", gem(150, 90, 4, lambda x, y: (x // 10 + y // 6) & 15), "gem", True)

def pcx(w, h, bits, planes, value, version=5, palette=None, endpal=None, rle=True):
    line = (w * bits + 7) // 8; line += line & 1
    hd = bytearray(128)
    hd[0], hd[1], hd[2], hd[3] = 10, version, 1 if rle else 0, bits
    struct.pack_into("<HHHH", hd, 4, 0, 0, w - 1, h - 1)
    if palette: hd[16:16 + len(palette)] = palette
    hd[65] = planes; struct.pack_into("<H", hd, 66, line)
    body = bytearray()
    for y in range(h):
        raw = bytearray()
        for p in range(planes):
            row = bytearray(line)
            for x in range(w):
                v = value(x, y, p)
                row[(x * bits) // 8] |= v << (8 - bits - (x * bits) % 8)
            raw += row
        if not rle: body += raw; continue
        i = 0
        while i < len(raw):
            j = i
            while j < len(raw) and raw[j] == raw[i] and j - i < 63: j += 1
            if j - i > 1 or raw[i] >= 0xC0: body += bytes([0xC0 | (j - i), raw[i]]); i = j
            else: body.append(raw[i]); i += 1
    return bytes(hd) + bytes(body) + (b"\x0c" + endpal if endpal else b"")
save("MONO.PCX", pcx(150, 80, 1, 1, lambda x, y, p: 1 if (x // 8 + y // 8) % 2 else 0), "pcx", True)
save("EGA.PCX", pcx(160, 100, 1, 4, lambda x, y, p: ((x // 10 + y // 7) >> p) & 1, version=3), "pcx", True)
save("CGA.PCX", pcx(120, 60, 2, 1, lambda x, y, p: (x // 6 + y // 5) & 3,
                    palette=bytes([0, 0, 0, 255, 0, 255, 0, 255, 255, 255, 255, 255])), "pcx", True)
save("VGA.PCX", pcx(160, 100, 8, 1, lambda x, y, p: (img[y * 2][x * 2][0] ^ x) & 255,
                    endpal=bytes(c for i in range(256) for c in (i, 255 - i, (i * 5) & 255))), "pcx", True)
save("TRUE.PCX", pcx(100, 60, 8, 3, lambda x, y, p: img[y * 3][x * 3][p]), "pcx", True)
save("RAW.PCC", pcx(80, 40, 1, 4, lambda x, y, p: ((x + y) >> p) & 1, version=2,
                    palette=bytes(c for i in range(16) for c in (i * 16, 255 - i * 16, i * 9)), rle=False), "pcx", True)

colours = b"".join(struct.pack("<H", (i & 15) | ((i >> 4) & 15) << 4 | ((i >> 2) & 15) << 8 | (i & 7) << 12)
                   for i in range(256))
pix = bytes((img[i // 320][i % 320][0] + i % 320) & 255 for i in range(64000))
packed = packbytes(pix)
save("FRAME1", colours + struct.pack("<H", len(packed)) + packed, "fliaway")
save("FRAME2", colours + struct.pack("<H", 0) + pix, "fliaway")

# ---------- Unix ----------
def sun(w, h, depth, value, maptype=0, cmap=b"", rle=False, rgb=False):
    line = ((w * depth + 15) // 16) * 2
    raw = bytearray()
    for y in range(h):
        row = bytearray(line)
        for x in range(w):
            v = value(x, y)
            if depth == 1:
                if v: row[x >> 3] |= 0x80 >> (x & 7)
            elif depth == 8: row[x] = v
            else:
                at = x * (depth // 8) + (1 if depth == 32 else 0)
                row[at:at + 3] = bytes(v if rgb else v[::-1])
        raw += row
    if rle:
        o, i = bytearray(), 0
        while i < len(raw):
            j = i
            while j < len(raw) and raw[j] == raw[i] and j - i < 256: j += 1
            n = j - i
            if n >= 3 or raw[i] == 0x80:
                if raw[i] == 0x80 and n == 1: o += b"\x80\x00"
                else: o += bytes([0x80, n - 1, raw[i]])
                i = j
            else: o.append(raw[i]); i += 1
        raw = o
    return struct.pack(">8I", 0x59A66A95, w, h, depth, len(raw), 3 if rgb else (2 if rle else 1), maptype, len(cmap)) + cmap + raw
cmap = bytes(range(0, 256, 2)) + bytes(255 - i for i in range(0, 256, 2)) + bytes((i * 3) & 255 for i in range(128))
save("PIC.RAS", sun(160, 100, 8, lambda x, y: (img[y * 2][x * 2][0] // 2 + x) % 128, 1, cmap, rle=True), "sun", True)
save("RGB.RAS", sun(120, 80, 24, lambda x, y: img[y * 2][x * 2]), "sun", True)
save("RGB32.RAS", sun(90, 50, 32, lambda x, y: img[y * 4][x * 3], rgb=True), "sun", True)
save("MONO.RAS", sun(130, 70, 1, lambda x, y: (x // 9 + y // 9) % 2), "sun", True)

def sgi(w, h, chans, value, bpc=1, rle=True):
    hd = bytearray(512)
    struct.pack_into(">HBBHHHH", hd, 0, 474, 1 if rle else 0, bpc, 3 if chans > 1 else 2, w, h, chans)
    rows = [[bytes(c for x in range(w) for c in ((value(x, y, ch),) if bpc == 1 else (value(x, y, ch), 0x5A)))
             for y in range(h)] for ch in range(chans)]
    if not rle: return bytes(hd) + b"".join(r for ch in rows for r in ch)
    table, data = [], bytearray()
    start = 512 + h * chans * 8
    for ch in range(chans):
        for y in range(h):
            r = rows[ch][y]; samples = [r[i] for i in range(0, len(r), bpc)]
            table.append(start + len(data)); enc = bytearray(); i = 0
            while i < w:
                j = i
                while j < w and samples[j] == samples[i] and j - i < 127: j += 1
                if j - i >= 2: enc += bytes([j - i, samples[i]]); i = j
                else:
                    j = i
                    while j < w and j - i < 127 and not (j + 1 < w and samples[j] == samples[j + 1]): j += 1
                    j = max(j, i + 1)
                    enc += bytes([0x80 | (j - i)]) + bytes(samples[i:j]); i = j
            enc.append(0)
            data += enc
    lengths = [0] * len(table)
    return bytes(hd) + b"".join(struct.pack(">I", t) for t in table) + b"".join(struct.pack(">I", l) for l in lengths) + data
save("PIC.SGI", sgi(160, 100, 3, lambda x, y, c: img[y * 2][x * 2][c]), "sgi", True)
save("GREY.BW", sgi(100, 60, 1, lambda x, y, c: (x * 2 + y) & 255, bpc=2, rle=False), "sgi", True)

def pnm_text(kind, w, h, top, value):
    s = f"P{kind}\n# made for MegaconvertGS\n{w} {h}\n" + (f"{top}\n" if kind != 1 else "")
    vals = [value(x, y) for y in range(h) for x in range(w)]
    flat = [c for v in vals for c in (v if isinstance(v, tuple) else (v,))]
    s += "".join(("" if kind == 1 else " ").join(str(v) for v in flat[i:i + 18]) + "\n" for i in range(0, len(flat), 18))
    return s.encode()
save("PIC.PBM", pnm_text(1, 70, 40, 1, lambda x, y: (x // 5 + y // 5) % 2), "pnm", True)
save("PIC.PGM", pnm_text(2, 60, 40, 15, lambda x, y: (x + y) % 16), "pnm", True)
save("PIC.PPM", pnm_text(3, 50, 30, 100, lambda x, y: (x * 2 % 101, y * 3 % 101, (x + y) % 101)), "pnm", True)
p4 = b"P4\n90 50\n" + b"".join(bytes((((x // 9 + y // 7) % 2) * 0xFF) & (0xF0 if x % 2 else 0x3C) for x in range(12)) for y in range(50))
save("BITS.PBM", p4, "pnm", True)
save("GREY.PGM", b"P5 80 50 255\n" + bytes((x * 3 + y) & 255 for y in range(50) for x in range(80)), "pnm", True)
save("DEEP.PGM", b"P5\n60 40\n1000\n" + b"".join(struct.pack(">H", (x * 16 + y * 5) % 1001) for y in range(40) for x in range(60)), "pnm", True)
save("PIC.PPM6", b"P6\n120 80\n255\n" + bytes(c for y in range(80) for x in range(120) for c in img[y * 2][x * 2]), "pnm", True)

# ---------- Computer-independent ----------
def rle_pic(high):
    w, h = (256, 192) if high else (128, 96)
    out = bytearray(b"junk before\x1bG" + (b"H" if high else b"M"))
    runs, colour, total = [], 0, w * h
    while total > 0:
        n = min(total, 1 + (len(runs) * 37) % 90)
        runs.append(n); total -= n
    for k, n in enumerate(runs):
        out.append(32 + n)
        if k % 40 == 39: out += b"\r\n"
    return bytes(out + b"\x1bGN")
save("HI.RLE", rle_pic(True), "rle", True)
save("LO.RLE", rle_pic(False), "rle", True)

ipi = scene(256, 256)
for c, letter in enumerate("RGB"):
    save(f"PIC.{letter}", bytes(ipi[y][x][c] for y in range(256) for x in range(256)), "ipi", letter == "G")

q = bytearray(struct.pack("<HH", 100, 60))
for line in list(range(0, 60, 2)) + list(range(1, 60, 2)):
    q += struct.pack("<H", line)
    for c in range(3): q += bytes(img[line * 3][x * 3][c] for x in range(100))
save("PIC.QRT", q, "qrt", True)

# TIFF, written by ImageMagick from a PNG of the scene
def write_ppm(path, w, h, f):
    open(path, "wb").write(b"P6 %d %d 255\n" % (w, h) + bytes(c for y in range(h) for x in range(w) for c in f(x, y)))
src = os.path.join(out, "src.ppm")
write_ppm(src, 160, 100, lambda x, y: img[y * 2][x * 2])
for name, args in (("NONE.TIF", ["-compress", "none"]), ("LZW.TIF", ["-compress", "lzw"]),
                   ("PRED.TIF", ["-compress", "lzw", "-define", "tiff:predictor=2"]),
                   ("PACK.TIF", ["-compress", "rle"]), ("MOTO.TIF", ["-compress", "lzw", "-endian", "MSB"]),
                   ("GREY.TIF", ["-colorspace", "gray", "-compress", "lzw"]),
                   ("PAL.TIF", ["-colors", "200", "-type", "Palette", "-compress", "none"]),
                   ("PAL4.TIF", ["-colors", "12", "-type", "Palette", "-depth", "4", "-compress", "lzw"]),
                   ("BILEVEL.TIF", ["-threshold", "50%", "-type", "Bilevel", "-compress", "none"]),
                   ("DEEP.TIF", ["-depth", "16", "-compress", "none"])):
    path = os.path.join(out, name)
    subprocess.run(["magick", src] + args + [path], check=True)
    items.append((name, "tiff", True))
os.remove(src)

with open(os.path.join(out, "..", "other.list"), "w") as f:
    for name, fmt, auto in items: f.write(f"{name} {fmt} {'auto' if auto else ''}\n")
with open(os.path.join(out, "..", "other.types"), "w") as f:
    for name, fmt, auto in items: f.write(f"{name} 060000\n")
print(len(items), "test files for other computers' formats")
