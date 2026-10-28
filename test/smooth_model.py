# Screen > Convert to true color's Smoothed conversion of a 640 mode screen image
# (docs/superconvert-truecolor.md 10.3), as the reference for MegaconvertGS's (test/smooth.sh).
# The pixels' palette entries follow the hardware (8, 12, 0, 4 + the 2-bit value), as
# MegaconvertGS's Exact conversion (GS Remap's) does.
SQ = [0, 1, 4, 9, 17, 27, 39, 54, 70, 90, 111, 135, 161, 190, 221, 255]
TH = [0, 1, 1, 2, 5, 8, 13, 19, 26, 34, 43, 54, 65, 78, 92, 107, 123, 141, 159, 179, 200, 222,
      247, 270, 296, 323, 351, 380, 411, 443, 476, 509]
OFF = [8, 12, 0, 4]

def v5(s):
    return max(k for k in range(32) if TH[k] <= s)

def blend(c1, c2):
    """8-bit R, G, B of colours c1 and c2 ($0RGB) blended; equal channels: grey v5 x 8."""
    ch = [v5(SQ[(c1 >> sh) & 15] + SQ[(c2 >> sh) & 15]) for sh in (8, 4, 0)]
    if ch[0] == ch[1] == ch[2]:
        return (ch[0] * 8,) * 3
    return tuple((c << 3) | (c >> 2) for c in ch)

def smooth_line(scr, y, width):
    scb = scr[0x7D00 + y]
    p = scb & 15
    P = [(scr[0x7E00 + p * 32 + 2 * i] | scr[0x7E01 + p * 32 + 2 * i] << 8) & 0x0FFF for i in range(16)]
    canon = [P.index(P[e]) for e in range(16)]
    code = []
    for x in range(width):
        b = scr[y * 160 + x // 4]
        v = (b >> (6 - 2 * (x & 3))) & 3
        code.append(canon[OFF[x & 3] + v] * 17)
    code += [0x63, 0x64, 0x65]
    n, x = width, 0
    while x < n:
        if code[x] == code[x + 1]:
            a = code[x]
            while x < n and code[x] == a: x += 1
        elif code[x] == code[x + 2] and code[x + 2] == code[x + 4] and code[x + 1] == code[x + 3]:
            a, b = code[x], code[x + 1]
            pair = (b & 0xF0) | (a & 0x0F)
            want = 0
            while x < n and code[x] == (a, b)[want] and code[x] != code[x + 1]:
                code[x] = pair
                want ^= 1
                x += 1
        else:
            x += 1
    out = bytearray()
    for x in range(n):
        c = code[x]
        out += bytes(blend(P[c & 15], P[c >> 4]))
    return bytes(out)

def smooth(scr, width=640, height=200):
    return b"".join(smooth_line(scr, y, width) for y in range(height))
