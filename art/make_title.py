# Makes MCGS.Title, the picture MegaconvertGS shows at start-up: the title screen
# (MegaconvertGS_Title.shr, a $C1 screen in 320 mode) with the credits drawn in the
# empty band at the bottom, in a small pixel font so the longer line fits.
# The band's lines use palettes 14 and 15, which hold only a few dark blues (most
# entries repeated): their pixels are re-indexed to free entries for the text colours.
#   python3 art/make_title.py art/MegaconvertGS_Title.shr build/MCGS.Title
import sys

LINES = [("2026 Walter Tengler", 178, 0xDDE),
         ("A successor to SuperConvert by Jason Harper and Ian Brumby", 189, 0xA9E)]

# Glyphs: 8 rows (capitals rows 0-5, small letters 2-5, descenders 6-7).
G = {
    "0": [".##.", "#..#", "#.##", "##.#", "#..#", ".##."],
    "2": [".##.", "#..#", "...#", "..#.", ".#..", "####"],
    "6": [".##.", "#...", "###.", "#..#", "#..#", ".##."],
    "A": [".##.", "#..#", "#..#", "####", "#..#", "#..#"],
    "B": ["###.", "#..#", "###.", "#..#", "#..#", "###."],
    "C": [".###", "#...", "#...", "#...", "#...", ".###"],
    "H": ["#..#", "#..#", "####", "#..#", "#..#", "#..#"],
    "I": ["###", ".#.", ".#.", ".#.", ".#.", "###"],
    "J": ["...#", "...#", "...#", "...#", "#..#", ".##."],
    "S": [".###", "#...", ".##.", "...#", "...#", "###."],
    "T": ["#####", "..#..", "..#..", "..#..", "..#..", "..#.."],
    "W": ["#...#", "#...#", "#...#", "#.#.#", "##.##", "#...#"],
    "a": ["", "", ".###", "#..#", "#..#", ".###"],
    "b": ["#...", "#...", "###.", "#..#", "#..#", "###."],
    "c": ["", "", ".##", "#..", "#..", ".##"],
    "d": ["...#", "...#", ".###", "#..#", "#..#", ".###"],
    "e": ["", "", ".##.", "####", "#...", ".###"],
    "g": ["", "", ".###", "#..#", "#..#", ".###", "...#", ".##."],
    "l": ["#", "#", "#", "#", "#", "#"],
    "m": ["", "", "####.", "#.#.#", "#.#.#", "#.#.#"],
    "n": ["", "", "###.", "#..#", "#..#", "#..#"],
    "o": ["", "", ".##.", "#..#", "#..#", ".##."],
    "p": ["", "", "###.", "#..#", "#..#", "###.", "#...", "#..."],
    "r": ["", "", "#.#", "##.", "#..", "#.."],
    "s": ["", "", ".###", "##..", "..##", "###."],
    "t": ["", ".#.", "###", ".#.", ".#.", "..#"],
    "u": ["", "", "#..#", "#..#", "#..#", ".###"],
    "v": ["", "", "#...#", "#...#", ".#.#.", "..#.."],
    "y": ["", "", "#..#", "#..#", "#..#", ".###", "...#", ".##."],
}

def width(ch): return 3 if ch == " " else max(len(r) for r in G[ch])

def text_width(s): return sum(width(c) for c in s) + len(s) - 1

src, dst = sys.argv[1], sys.argv[2]
d = bytearray(open(src, "rb").read())
assert len(d) == 32768
scb = d[32000:32200]

def pal(p): return [d[32256 + p * 32 + 2 * i] | d[32256 + p * 32 + 2 * i + 1] << 8 for i in range(16)]

def get(x, y):
    b = d[y * 160 + x // 2]
    return b >> 4 if x % 2 == 0 else b & 15

def put(x, y, v):
    i = y * 160 + x // 2
    d[i] = (d[i] & 0x0F) | (v << 4) if x % 2 == 0 else (d[i] & 0xF0) | v

for text, top, colour in LINES:
    p = scb[top] & 15
    rows = [y for y in range(200) if scb[y] & 15 == p]
    assert all(scb[y] & 15 == p for y in range(top, top + 8)), "a line of text across two palettes"
    old = pal(p)
    keep = sorted(set(old), key=old.index)             # the colours it really has
    assert len(keep) <= 15
    new = keep + [0] * (15 - len(keep)) + [colour]      # entry 15: the text
    for y in rows:
        for x in range(320):
            put(x, y, new.index(old[get(x, y)]))
    for i, c in enumerate(new):
        d[32256 + p * 32 + 2 * i] = c & 255
        d[32256 + p * 32 + 2 * i + 1] = c >> 8
    x = (320 - text_width(text)) // 2
    for ch in text:
        if ch != " ":
            for r, row in enumerate(G[ch]):
                for c, bit in enumerate(row):
                    if bit == "#": put(x + c, top + r, 15)
        x += width(ch) + 1

open(dst, "wb").write(d)
