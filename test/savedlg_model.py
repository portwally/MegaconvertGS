# The pictures Save conversion makes at a chosen size (docs/superconvert-file.md 4.3, 4.5):
# line r of the new picture is the original's line r + voff from its byte hoff; outside
# it colour 0 and the first or last line's mode. And readers for the files checked.
import struct

def canvas(scr, top, left, sbytes, slines, cbytes, clines, hoff, voff):
    rows = []
    for r in range(clines):
        sr = r + voff
        if 0 <= sr < slines:
            line = bytes(scr[(top + sr) * 160 + left + j + hoff] if 0 <= j + hoff < sbytes else 0
                         for j in range(cbytes))
            scb = scr[0x7D00 + top + sr]
        else:
            line = bytes(cbytes)
            scb = scr[0x7D00 + (top if sr < 0 else top + slines - 1)]
        rows.append((scb, line))
    return rows

def unpack(src, n):
    """PackBytes: n bytes from src; returns them and the bytes used."""
    out, i = bytearray(), 0
    while len(out) < n and i < len(src):
        f = src[i]; i += 1; k = f & 0x3F
        if f >> 6 == 0: out += src[i:i + k + 1]; i += k + 1
        elif f >> 6 == 1: out += bytes([src[i]]) * (k + 1); i += 1
        elif f >> 6 == 2: out += src[i:i + 4] * (k + 1); i += 4
        else: out += bytes([src[i]]) * (4 * (k + 1)); i += 1
    return bytes(out[:n]), i

def apf(d):
    """An Apple Preferred file's MAIN block: width in pixels, colour tables, [(SCB, bytes)]."""
    p = 5 + d[4]
    mode, width, npal = struct.unpack_from("<HHH", d, p); p += 6
    pals = d[p:p + 32 * npal]; p += 32 * npal
    nl = struct.unpack_from("<H", d, p)[0]; p += 2
    dirs = [struct.unpack_from("<HH", d, p + 4 * i) for i in range(nl)]; p += 4 * nl
    bpl = width // (4 if mode & 0x80 else 2)
    lines = []
    for plen, lmode in dirs:
        b, _ = unpack(d[p:p + plen], bpl); p += plen
        lines.append((lmode & 0xFF, b))
    return width, pals, lines

def paintworks(d, lines):
    """A PaintWorks file: colour table 0 and its lines of 160 bytes."""
    pal, p, out = d[:32], 32 + 2 + 512, []
    for _ in range(lines):
        b, used = unpack(d[p:], 160); p += used
        out.append(b)
    return pal, out
