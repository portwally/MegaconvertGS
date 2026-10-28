# SuperConvert's monochrome conversions (docs/superconvert-truecolor.md sections 7 and 8),
# written from the description, as the reference for MegaconvertGS's (test/mono.sh).
#
# A monochrome image: (width, height, rows) with rows a list of bytes objects, one bit a
# pixel, bit 7 leftmost, 1 = white.

RT4 = [0, 0, 1, 2, 4, 7, 10, 14, 19, 25, 31, 39, 47, 56, 66, 77]
GT4 = [0, 1, 2, 4, 8, 13, 20, 28, 38, 49, 62, 76, 92, 110, 129, 150]
BT4 = [0, 0, 0, 1, 2, 3, 4, 5, 7, 9, 11, 14, 17, 20, 24, 28]
RT5 = [0, 0, 0, 1, 1, 2, 3, 4, 5, 6, 8, 10, 11, 13, 16, 18, 20, 23, 26, 29, 32, 35, 39, 42, 46, 50, 54,
       58, 62, 67, 72, 77]
GT5 = [0, 0, 1, 1, 3, 4, 6, 8, 10, 13, 16, 19, 23, 26, 31, 35, 40, 45, 51, 57, 63, 69, 76, 83, 90, 98,
       106, 114, 123, 132, 141, 150]
BT5 = [0, 0, 0, 0, 0, 1, 1, 1, 2, 2, 3, 4, 4, 5, 6, 7, 7, 8, 9, 11, 12, 13, 14, 15, 17, 18, 20, 21, 23,
       25, 26, 28]
GREY = [(g * g + 127) // 255 for g in range(256)]      # round(g * g / 255); never a tie
PD = [[2, 130, 34, 162, 10, 138, 42, 170], [226, 66, 194, 98, 234, 74, 202, 106],
      [50, 178, 18, 146, 58, 186, 26, 154], [210, 114, 242, 82, 218, 122, 250, 90],
      [14, 142, 46, 174, 6, 134, 38, 166], [238, 78, 206, 110, 230, 70, 198, 102],
      [62, 190, 30, 158, 54, 182, 22, 150], [222, 126, 254, 94, 214, 118, 246, 86]]
HT = [[250, 234, 170, 58, 6, 70, 182, 246], [218, 186, 122, 10, 50, 30, 142, 202],
      [154, 90, 82, 114, 162, 98, 74, 102], [42, 34, 146, 210, 226, 194, 134, 22],
      [2, 66, 178, 242, 254, 238, 174, 62], [54, 26, 138, 206, 222, 190, 126, 14],
      [166, 106, 78, 110, 158, 94, 86, 118], [230, 198, 130, 18, 46, 38, 150, 214]]


def screen_intensity(scr, width, lines, is640):
    """Intensity (0-255) of each pixel of a screen image ($C1 layout, its own size)."""
    out = []
    for y in range(lines):
        scb = scr[0x7D00 + y]
        pal = [scr[0x7E00 + (scb & 15) * 32 + 2 * i] | scr[0x7E00 + (scb & 15) * 32 + 2 * i + 1] << 8
               for i in range(16)]
        def lum(c): return RT4[(c >> 8) & 15] + GT4[(c >> 4) & 15] + BT4[c & 15]
        row = []
        for x in range(width):
            b = scr[y * 160 + (x // 4 if is640 else x // 2)]
            if is640:
                k = x & 3
                row.append(lum(pal[4 * k + ((b >> (6 - 2 * k)) & 3)]))
            else:
                row.append(lum(pal[(b >> 4) if x % 2 == 0 else (b & 15)]))
        out.append(row)
    return out


def true_intensity(rgb, w, h):
    """Intensity of each pixel of a true colour image: a grey image (every pixel R = G = B)
    through GREY, others by their 5-bit channels."""
    grey = all(rgb[i] == rgb[i + 1] == rgb[i + 2] for i in range(0, len(rgb), 3))
    out = []
    for y in range(h):
        row = []
        for x in range(w):
            r, g, b = rgb[(y * w + x) * 3:(y * w + x) * 3 + 3]
            row.append(GREY[g] if grey else RT5[r >> 3] + GT5[g >> 3] + BT5[b >> 3])
        out.append(row)
    return out


def to_mono(lum, H, V, method):
    """method: 1 error diffusion, 2 pattern dither, 3 50% threshold, 4 halftone."""
    sh, sw = len(lum), len(lum[0])
    w, h = min(5000, sw * H), min(5000, sh * V)
    rows = []
    cur = [0] * (w + 4)
    nxt = [0] * (w + 4)
    for y in range(h):
        bits = []
        for x in range(w):
            L = lum[y // V][x // H]
            if method == 3:
                bit = 1 if L >= 128 else 0
            elif method == 2:
                bit = 1 if L >= PD[y & 7][x & 7] else 0
            elif method == 4:
                bit = 1 if L >= HT[y & 7][x & 7] else 0
            else:
                v = L + cur[x + 2]
                if v < 0: bit, e = 0, 0
                elif v >= 256: bit, e = 1, 0
                elif v >= 128: bit, e = 1, v - 255
                else: bit, e = 0, v
                e4 = e >> 2; e8 = e4 >> 1; e16 = e8 >> 1
                cur[x + 3] += e4; cur[x + 4] += e8
                nxt[x] += e16; nxt[x + 1] += e8; nxt[x + 2] += e4; nxt[x + 3] += e8; nxt[x + 4] += e16
            bits.append(bit)
        if method == 1:
            cur, nxt = nxt, [0] * (w + 4)
        rows.append(pack(bits))
    return w, h, rows


def pack(bits):
    out = bytearray((len(bits) + 7) // 8)
    for i, b in enumerate(bits):
        if b: out[i // 8] |= 0x80 >> (i % 8)
    return bytes(out)


def bit(rows, x, y):
    return (rows[y][x // 8] >> (7 - (x & 7))) & 1


# The monochrome image's blocks for each choice: (source pixels across, source rows, output
# pixels across per block, output rows per block); the weight of a black pixel = 16 / (bw x bh).
BLOCKS = {  # (aspect 1 square 2 tall 3 wide, scaling 1 2 4, 640 mode)
    (1, 1, 0): (1, 1, 1, 1), (1, 2, 0): (2, 2, 1, 1), (1, 4, 0): (4, 4, 1, 1),
    (2, 1, 0): (1, 1, 1, 2), (2, 2, 0): (2, 1, 1, 1), (2, 4, 0): (4, 2, 1, 1),
    (3, 1, 0): (1, 1, 2, 1), (3, 2, 0): (1, 2, 1, 1), (3, 4, 0): (2, 4, 1, 1),
    (1, 1, 1): (1, 1, 2, 1), (1, 2, 1): (1, 2, 1, 1), (1, 4, 1): (2, 4, 1, 1),
    (2, 1, 1): (1, 1, 2, 2), (2, 2, 1): (1, 1, 1, 1), (2, 4, 1): (2, 2, 1, 1),
    (3, 1, 1): (1, 1, 4, 1), (3, 2, 1): (1, 2, 2, 1), (3, 4, 1): (1, 4, 1, 1),
}
THRESH = {2: 8, 3: 1, 4: 16}         # shrink: 2 B&W 50%, 3 line art on white, 4 on black


def expand(mono, aspect, scaling, m640, shrink):
    """Values 0 (white) .. 16 (black) for each output pixel, and whether grey levels came out."""
    w, h, rows = mono
    bw, bh, rx, ry = BLOCKS[(aspect, scaling, m640)]
    weight = 16 // (bw * bh)
    ow = (w + bw - 1) // bw * rx
    oh = (h + bh - 1) // bh * ry
    out = []
    for oy in range(oh):
        by = oy // ry
        row = []
        for ox in range(ow):
            bx = ox // rx
            v = 0
            for sy in range(by * bh, min(h, by * bh + bh)):
                for sx in range(bx * bw, min(w, bx * bw + bw)):
                    if not bit(rows, sx, sy): v += weight
            if weight != 16 and shrink != 1:
                v = 16 if v >= THRESH[shrink] else 0
            row.append(v)
        out.append(row)
    greys = shrink == 1 and weight < 16
    return ow, oh, out, greys


SCR320 = [15, 15, 14, 14, 13, 12, 12, 11, 11, 10, 9, 8, 7, 6, 5, 3, 0]
SCR640 = [3, 3, 3, 3, 2, 2, 2, 2, 2, 1, 1, 1, 1, 1, 0, 0, 0]
PAL320 = [0x000, 0x777, 0x841, 0x72C, 0x00F, 0x080, 0xF70, 0xD00, 0xFA9, 0xFF0, 0x0E0, 0x4DF, 0xDAF,
          0x78F, 0xCCC, 0xFFF]
PAL320G = [0x111 * i for i in range(16)]
PAL640 = [0x000, 0xF00, 0x0F0, 0xFFF, 0x000, 0x00F, 0xFF0, 0xFFF] * 2
PAL640G = [0x000, 0x777, 0xCCC, 0xFFF] * 4
TRUEGREY = [255, 247, 239, 230, 221, 211, 202, 191, 180, 169, 156, 143, 128, 110, 90, 64, 0]


def to_screen(mono, aspect, scaling, m640, shrink):
    """A one-screen $C1 picture (clipped to 160 bytes x 200 lines, as MegaconvertGS keeps it),
    and its size in pixels."""
    ow, oh, vals, greys = expand(mono, aspect, scaling, m640, shrink)
    scr = bytearray(32768)
    per = 4 if m640 else 2
    w = min(ow, 160 * per)
    h = min(oh, 200)
    for y in range(h):
        for x in range(w):
            v = vals[y][x]
            if m640:
                scr[y * 160 + x // 4] |= SCR640[v] << (6 - 2 * (x & 3))
            else:
                scr[y * 160 + x // 2] |= SCR320[v] << (4 if x % 2 == 0 else 0)
        scr[0x7D00 + y] = 0x80 if m640 else 0
    pal = (PAL640G if greys else PAL640) if m640 else (PAL320G if greys else PAL320)
    for i, c in enumerate(pal):
        scr[0x7E00 + 2 * i] = c & 255
        scr[0x7E00 + 2 * i + 1] = c >> 8
    return scr, w, h


def to_true(mono, aspect, scaling, m640, shrink):
    ow, oh, vals, greys = expand(mono, aspect, scaling, m640, shrink)
    w, h = min(ow, 2000), min(oh, 2000)
    out = bytearray()
    for y in range(h):
        for x in range(w):
            g = TRUEGREY[vals[y][x]]
            out += bytes((g, g, g))
    return w, h, bytes(out)


def negate(mono):
    w, h, rows = mono
    return w, h, [bytes(b ^ 0xFF for b in r) for r in rows]
