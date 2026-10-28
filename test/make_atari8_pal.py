# The Atari 8-bit's 256 colours (16 hues x 16 luminances; the low bit of the
# luminance is ignored) as Super Hi-Res colours ($0RGB, 4 bits each), for
# src/Atari8.s. An approximation of the NTSC GTIA: hue 0 is grey; hues 1-15 go
# round the colour wheel from gold (1) through red, purple, blue, cyan and green
# to light orange (15), 24 degrees apart; luminance sets the lightness.
#   python3 test/make_atari8_pal.py       (prints the table; also used by the tests)
import colorsys

def atari_rgb(v):
    """Colour register value v as (r, g, b), 0-255."""
    hue, lum = v >> 4, (v & 0x0E) / 14
    if hue == 0:
        g = round(lum * 255)
        return (g, g, g)
    angle = (40 - (hue - 1) * 24) % 360
    r, g, b = colorsys.hls_to_rgb(angle / 360, 0.08 + 0.84 * lum, 0.6)
    return tuple(round(c * 255) for c in (r, g, b))

def atari_shr(v):
    """The same as a Super Hi-Res colour word."""
    r, g, b = (round(c * 15 / 255) for c in atari_rgb(v))
    return r << 8 | g << 4 | b

if __name__ == "__main__":
    print("* The Atari 8-bit's colours by register value (test/make_atari8_pal.py).")
    for i in range(0, 256, 8):
        print(("A8Pal       " if i == 0 else "            ") + "dw    " + ",".join("$%03X" % atari_shr(v) for v in range(i, i + 8)))
