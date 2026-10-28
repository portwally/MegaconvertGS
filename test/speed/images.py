# Loads the test pictures as MegaconvertGS holds them: 24-bit RGB rows, plus the
# "tall pixels" flag (ScreenToTrue of a 640 mode screen).
import struct, zlib, os

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
# The test pictures (./test/fixtures.sh and test/make_true.py make them), and
# photographs of your own as 24-bit BMP files (PHOTOS, default test/speed/photos).
FIX = os.path.join(ROOT, "build", "fixtures", "true")
SCREENS = os.path.join(ROOT, "build", "fixtures")
PHOTOS = os.environ.get("PHOTOS", os.path.join(HERE, "photos"))


def read_png(path):
    d = open(path, "rb").read()
    assert d[:8] == b"\x89PNG\r\n\x1a\n", path
    pos, idat, plte = 8, b"", None
    while pos < len(d):
        n = struct.unpack(">I", d[pos:pos + 4])[0]
        t = d[pos + 4:pos + 8]
        body = d[pos + 8:pos + 8 + n]
        if t == b"IHDR":
            w, h, depth, ctype, _, _, inter = struct.unpack(">IIBBBBB", body)
        elif t == b"PLTE":
            plte = body
        elif t == b"IDAT":
            idat += body
        pos += 12 + n
    assert inter == 0
    ch = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}[ctype]
    bits = ch * depth
    stride = (w * bits + 7) // 8
    bpp = max(1, bits // 8)
    raw = zlib.decompress(idat)
    prev = bytearray(stride)
    rgb = bytearray()
    for y in range(h):
        f = raw[y * (stride + 1)]
        row = bytearray(raw[y * (stride + 1) + 1:(y + 1) * (stride + 1)])
        for i in range(stride):
            a = row[i - bpp] if i >= bpp else 0
            b = prev[i]
            c = prev[i - bpp] if i >= bpp else 0
            if f == 1: row[i] = (row[i] + a) & 255
            elif f == 2: row[i] = (row[i] + b) & 255
            elif f == 3: row[i] = (row[i] + ((a + b) >> 1)) & 255
            elif f == 4:
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                row[i] = (row[i] + (a if pa <= pb and pa <= pc else b if pb <= pc else c)) & 255
        prev = row
        for x in range(w):
            if depth == 8:
                s = row[x * ch:(x + 1) * ch]
                if ctype in (0, 4): rgb += bytes((s[0], s[0], s[0]))
                elif ctype == 3: rgb += plte[3 * s[0]:3 * s[0] + 3]
                else: rgb += s[:3]
            elif depth == 4 and ctype == 3:
                v = (row[x >> 1] >> (4 if x % 2 == 0 else 0)) & 15
                rgb += plte[3 * v:3 * v + 3]
            else:
                raise ValueError("unsupported PNG")
    return w, h, bytes(rgb), 0


OFF640 = [8, 12, 0, 4]


def read_c1(path):
    """ScreenToTrue: a $C1 screen as a true colour picture (channels times 17)."""
    d = open(path, "rb").read()
    scb = d[32000:32200]
    wide = sum(1 for s in scb if s & 0x80)
    pic640 = 1 if wide >= 101 else 0              # CountWide: the mode most lines have
    W = 640 if pic640 else 320
    pal = [struct.unpack("<16H", d[32256 + t * 32:32288 + t * 32]) for t in range(16)]
    rgb = bytearray()
    for y in range(200):
        s = scb[y]
        line = d[y * 160:(y + 1) * 160]
        for x in range(W):
            if pic640:
                v = (line[x >> 2] >> (2 * (3 - (x & 3)))) & 3
            else:
                v = (line[x >> 1] >> 4) if x % 2 == 0 else line[x >> 1] & 15
            v = OFF640[x & 3] + v if s & 0x80 else v & 15
            c = pal[s & 15][v]
            rgb += bytes((((c >> 8) & 15) * 17, ((c >> 4) & 15) * 17, (c & 15) * 17))
    return W, 200, bytes(rgb), pic640, d


_cache = {}


def load(tag):
    if tag in _cache: return _cache[tag]
    if tag.startswith("photo:"): return load_photo(tag[6:])
    names = {"RGB": "RGB8.PNG", "BIG": "BIG.PNG", "HUGE": "HUGE.PNG", "GRY": "GREY8.PNG",
             "TNY": "PAL4.PNG", "SCR": "S320.c1", "S64": "S640.c1"}
    p = os.path.join(SCREENS if names[tag].endswith(".c1") else FIX, names[tag])
    if p.endswith(".c1"):
        w, h, rgb, tall, scr = read_c1(p)
    else:
        w, h, rgb, tall = read_png(p)
        scr = None
    _cache[tag] = (w, h, rgb, tall, scr)
    return _cache[tag]


if __name__ == "__main__":
    for t in ("RGB", "BIG", "HUGE", "GRY", "TNY", "SCR", "S64"):
        w, h, rgb, tall, scr = load(t)
        cols = {((rgb[i] >> 4) << 8) | ((rgb[i + 1] >> 4) << 4) | (rgb[i + 2] >> 4) for i in range(0, len(rgb), 3)}
        print(t, w, h, "tall" if tall else "", "distinct 12-bit colours:", len(cols))


def read_bmp(path):
    """24- or 32-bit BMP (as sips writes them), bottom-up or top-down."""
    d = open(path, "rb").read()
    off = struct.unpack("<I", d[10:14])[0]
    _, w, h, _, bpp = struct.unpack("<IiiHH", d[14:30])
    top = h < 0
    h = abs(h)
    bpr = bpp // 8
    stride = (w * bpr + 3) & ~3
    rgb = bytearray()
    for y in range(h):
        sy = y if top else h - 1 - y
        row = d[off + sy * stride: off + sy * stride + w * bpr]
        for x in range(w):
            b, g, r = row[x * bpr:x * bpr + 3]
            rgb += bytes((r, g, b))
    return w, h, bytes(rgb), 0


def load_photo(name):
    key = "photo:" + name
    if key not in _cache:
        w, h, rgb, tall = read_bmp(os.path.join(PHOTOS, name + ".bmp"))
        _cache[key] = (w, h, rgb, tall, None)
    return _cache[key]
