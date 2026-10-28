# Decodes a printer stream captured from MAME's serial port (the System disk's printer
# driver sends Epson-style bit images: ESC * m nL nH and n columns of 8 dots, the top dot in
# bit 7; ESC J n or CR LF with ESC 3 n move the paper) into rows of dots.
# decode(data) -> list of rows (lists of 0/1); main: writes a PBM picture.
import sys

def decode(d):
    rows, y, spacing, i = {}, 0, 24, 0       # y in 1/216 inch
    def put(x, row, bit):
        rows.setdefault(row, set()).add(x)
    while i < len(d):
        c = d[i]
        if c == 27 and i + 1 < len(d):
            k = d[i + 1]
            if k == ord("*"):
                n = d[i + 3] | d[i + 4] << 8
                cols = d[i + 5:i + 5 + n]
                for x, b in enumerate(cols):
                    for bit in range(8):
                        if b >> (7 - bit) & 1:
                            put(x, y // 3 + bit, 1)
                i += 5 + n; continue
            if k in (ord("K"), ord("L"), ord("Y"), ord("Z")):
                n = d[i + 2] | d[i + 3] << 8
                for x, b in enumerate(d[i + 4:i + 4 + n]):
                    for bit in range(8):
                        if b >> (7 - bit) & 1:
                            put(x, y // 3 + bit, 1)
                i += 4 + n; continue
            if k == ord("3"): spacing = d[i + 2]; i += 3; continue
            if k == ord("J"): y += d[i + 2]; i += 3; continue
            if k in (ord("A"), ord("Q"), ord("l"), ord("C")): i += 3; continue
            i += 2; continue
        if c == 10: y += spacing
        i += 1
    h = max(rows) + 1 if rows else 0
    w = max((max(v) for v in rows.values()), default=-1) + 1
    return [[1 if x in rows.get(r, ()) else 0 for x in range(w)] for r in range(h)]

if __name__ == "__main__":
    img = decode(open(sys.argv[1], "rb").read())
    with open(sys.argv[2], "w") as f:
        f.write(f"P1\n{len(img[0]) if img else 0} {len(img)}\n")
        for r in img: f.write(" ".join(map(str, r)) + "\n")
    dots = [(x, y) for y, r in enumerate(img) for x, v in enumerate(r) if v]
    print(len(img[0]) if img else 0, "x", len(img), "dots", len(dots))
