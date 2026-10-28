# Makes MegaconvertGS's Finder icon: the converter of the title screen (a grey box,
# a beam into a prism on its screen, a rainbow out of its side), 28 x 16 icon pixels,
# and a small icon for the Finder's list views. Writes a Finder icon file ($CA)
# whose icon goes to files of type S16 ($B3) named MegaconvertGS, and a preview.
#   python3 art/make_icon.py build/MegaconvertGS.Icons build/icon-preview.png [blended.png]
#
# An icon pixel is a pair of 640 mode pixels: the left one black, blue, yellow or
# white, the right one black, red, green or white (the Finder's colours), so most
# colours are a mix of two. Each letter below stands for one pair.
import os, struct, sys
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "test"))
from pngread import write_png

PAIRS = {                       # (left: 0 black 1 blue 2 yellow 3 white, right: 0 black 1 red 2 green 3 white)
    "K": (0, 0), "W": (3, 3), "g": (3, 0), "d": (0, 3),   # black, white, two greys
    "r": (0, 1), "O": (2, 1), "y": (2, 3), "L": (2, 2),   # red, orange, yellow, yellow-green
    "G": (0, 2), "u": (1, 3), "U": (1, 0), "P": (1, 1),   # green, light blue, blue, purple
}
LEFT = [(0, 0, 0), (0, 0, 255), (255, 255, 0), (255, 255, 255)]
RIGHT = [(0, 0, 0), (221, 0, 0), (0, 238, 0), (255, 255, 255)]

def large():
    W, H = 28, 16                                            # (as tall as the Finder's own)
    g = [["."] * W for _ in range(H)]
    def rect(c0, r0, c1, r1, ch):
        for r in range(r0, r1 + 1):
            for c in range(c0, c1 + 1): g[r][c] = ch
    rect(9, 15, 20, 15, "K"); rect(20, 1, 20, 15, "K")       # the box's shadow
    rect(8, 0, 19, 14, "K")                                  # the box, outlined,
    for r in range(1, 14):                                   # in a checkerboard grey
        rect(9, r, 18, r, "g" if r % 2 else "d")
    rect(9, 1, 18, 1, "W")                                   # (its lit top edge)
    rect(10, 2, 16, 9, "K")                                  # the screen
    for r in range(3, 9):                                    # the prism
        half = (r - 3) // 2
        rect(13 - half, r, 13 + half, r, "W")
    rect(0, 5, 8, 5, "K"); rect(0, 7, 8, 7, "K")             # the beam in, edged in black
    rect(0, 6, 11, 6, "W")                                   # (so it shows on white too)
    for k, ch in enumerate("rOyGuP"):                        # the rainbow out
        rect(15 + (k > 2), 4 + k, 27, 4 + k, ch)
    rect(18, 3, 18, 3, "G")                                  # a lamp
    for r in (11, 13):                                       # the vents
        rect(10, r, 15, r, "K")
    return g

def small():
    return [list(s) for s in (
        "..KKKKK.",
        "..KgggK.",
        "KKKKKKyr",
        "WWWKWKyG",
        "KKKKKKuP",
        "..KgggK.",
        "..KKKKKK",
        "........")]

def record(grid):
    """A QuickDraw II colour icon: type, size, height, width, image, mask."""
    h, w = len(grid), len(grid[0])
    rb = (w + 1) // 2
    image, mask = bytearray(rb * h), bytearray(rb * h)
    for y, row in enumerate(grid):
        for x, ch in enumerate(row):
            if ch == ".": continue
            l, r = PAIRS[ch]
            sh = 4 if x % 2 == 0 else 0
            image[y * rb + x // 2] |= (l << 2 | r) << sh
            mask[y * rb + x // 2] |= 15 << sh
    return struct.pack("<HHHH", 0x8000, len(image), h, w) + bytes(image) + bytes(mask)

def pascal(text, field):
    b = text.encode("ascii")[:field - 1]
    return bytes([len(b)]) + b + bytes(field - 1 - len(b))

def icon_file(big, little):
    body = pascal("", 64) + pascal("MegaconvertGS", 16) + struct.pack("<HH", 0xB3, 0) + record(big) + record(little)
    out = bytearray(26); out[4] = 1
    return bytes(out) + struct.pack("<H", len(body) + 2) + body + b"\0\0"

def preview(grids, path, scale=4, blend=False):
    """The icons as the Finder shows them (each 640 mode pixel half as wide as tall) on
    the desktop's blue, side by side; blended: each pair as its mixed colour, as a
    monitor shows it."""
    desk = (102, 119, 255)
    cw, ch = scale, scale * 2                 # a 640 mode pixel
    pad = 6 * scale
    widths = [len(gr[0]) * 2 * cw for gr in grids]
    W = sum(widths) + pad * (len(grids) + 1)
    H = max(len(gr) for gr in grids) * ch + pad * 2
    img = [[desk] * W for _ in range(H)]
    x0 = pad
    for gr, gw in zip(grids, widths):
        y0 = pad + (H - 2 * pad - len(gr) * ch) // 2
        for y, row in enumerate(gr):
            for x, c in enumerate(row):
                if c == ".": continue
                l, r = PAIRS[c]
                mix = tuple((a + b) // 2 for a, b in zip(LEFT[l], RIGHT[r]))
                for half, col in ((0, mix if blend else LEFT[l]), (1, mix if blend else RIGHT[r])):
                    for yy in range(ch):
                        for xx in range(cw):
                            img[y0 + y * ch + yy][x0 + (x * 2 + half) * cw + xx] = col
        x0 += gw + pad
    write_png(path, W, H, bytes(v for row in img for px in row for v in px))

if __name__ == "__main__":
    big, little = large(), small()
    open(sys.argv[1], "wb").write(icon_file(big, little))
    preview([big, little], sys.argv[2])
    if len(sys.argv) > 3: preview([big, little], sys.argv[3], blend=True)
