# Makes the test files for test/a2more.sh in build/fixtures/a2more, from the Apple II
# suite's pictures (test/make_apple.py: HGR.PIC, DHR.PIC, DHRBW.PIC), with their types in
# build/fixtures/a2more.types.
import sys, os
fix = sys.argv[1]
apple = os.path.join(fix, "apple")
out = os.path.join(fix, "a2more")
os.makedirs(out, exist_ok=True)
pic = lambda n: open(os.path.join(apple, n), "rb").read()
hgr = pic("HGR.PIC")[:8192].ljust(8192, b"\0")
dhr = pic("DHR.PIC")[:16384].ljust(16384, b"\0")
dhrbw = pic("DHRBW.PIC")[:16384].ljust(16384, b"\0")
types = []
def save(name, data, t="060000"):
    open(os.path.join(out, name), "wb").write(bytes(data)); types.append((name, t))

def lz4fh(data):
    """fadden's LZ4FH (fhpack): magic $66, then tokens (literals in the high 4 bits, match
    length - 4 in the low 4, 15 = plus a byte; match addon 253 = none, 254 = end), the
    literals, and a match's place as an offset from the output's start (2 bytes)."""
    o, i, lits = bytearray([0x66]), 0, bytearray()
    def emit(lit, mlen, moff):
        while len(lit) > 255:                     # long literal runs: 255 at a time, no match
            o.extend([0xFF, 255 - 15]); o.extend(lit[:255]); o.extend([253 - 0]); lit = lit[255:]
            o[-1] = 253
        n = len(lit)
        tok = (min(n, 15) << 4)
        if mlen is None: tok |= 15
        else: tok |= min(mlen - 4, 15)
        o.append(tok)
        if n >= 15: o.append(n - 15)
        o.extend(lit)
        if mlen is None: o.append(254); return
        if mlen - 4 >= 15: o.append(mlen - 4 - 15)
        o.extend((moff & 255, moff >> 8))
    while i < len(data):
        best, boff = 0, 0
        for start in range(0, i):
            k = 0
            while i + k < len(data) and k < 255 + 4 - 2 and data[start + k] == data[i + k]: k += 1
            if k > best: best, boff = k, start
            if best >= 200: break
        if best >= 4:
            emit(lits, best, boff); lits = bytearray(); i += best
        else:
            lits.append(data[i]); i += 1
    emit(lits, None, 0)
    return bytes(o)

def unlz4fh(c):                                   # (the decoder, to check the encoder)
    o, ip = bytearray(8192), 1; op = 0
    while True:
        t = c[ip]; ip += 1
        n = t >> 4
        if n == 15: n += c[ip]; ip += 1
        o[op:op + n] = c[ip:ip + n]; ip += n; op += n
        m = t & 15
        if m == 15:
            a = c[ip]; ip += 1
            if a == 253: continue
            if a == 254: return bytes(o)
            m += a
        m += 4
        off = c[ip] | c[ip + 1] << 8; ip += 2
        for _ in range(m): o[op] = o[off]; op += 1; off += 1

lz = lz4fh(hgr); assert unlz4fh(lz) == hgr, "LZ4FH encoder"
save("LZ.HGR", lz, "088066")
lz2 = lz4fh(hgr[:8184]); assert unlz4fh(lz2)[:8184] == hgr[:8184]
save("LZ2.HGR", lz2, "088066")                    # (8184 bytes: the last hole left out)
save("LZBAD.HGR", lz[:len(lz) // 2], "088066")    # cut short: damaged

save("PAIR.AUX", dhr[:8192], "062000"); save("PAIR.BIN", dhr[8192:], "062000")
save("pair2.aux", dhr[:8184], "062000"); save("pair2.bin", dhr[8192:16376], "062000")
save("LONE.BIN", dhr[8192:], "062000")            # no .AUX: HiRes

def row(y): return (y & 7) * 0x400 + ((y >> 3) & 7) * 0x80 + (y >> 6) * 40
def piece(src, w, h, kind=b"DHR"):
    d = bytearray(kind + bytes((w, h)))
    for y in range(h):
        d += src[row(y):row(y) + w // 2] + src[8192 + row(y):8192 + row(y) + w // 2]
    return bytes(d)
def placed(src, w, h):                            # the piece on a black screen
    d = bytearray(16384)
    for y in range(h):
        for half in (0, 8192):
            d[half + row(y):half + row(y) + w // 2] = src[half + row(y):half + row(y) + w // 2]
    return bytes(d)
save("FULL.DHR", piece(dhr, 80, 192))
save("PIECE.DHR", piece(dhr, 40, 100)); save("PIECEREF", placed(dhr, 40, 100))
save("MASK.DHM", piece(dhrbw, 20, 50, b"DHM")); save("MASKREF", placed(dhrbw, 20, 50))
save("PIC.A2FM", dhrbw)
w, h = 320, 200                                   # exactly a ComputerEyes file's size range
ppm = b"P6\n320 200\n255\n" + bytes(((x * 3 + y) & 255, (y * 5) & 255, (x ^ y) & 255)[c] for y in range(h) for x in range(w) for c in range(3))
assert 192000 <= len(ppm) <= 196608
save("P320.PPM", ppm)

# ---- Apple Preferred pictures larger than a screen, and with a MULTIPAL block (3200
# colors): true colour pictures of their whole size (each line's colours its own).
import struct, random
rnd = random.Random(1986)
def packbytes(d):
    out, i = bytearray(), 0
    while i < len(d):
        n = 1
        while i + n < len(d) and n < 64 and d[i + n] == d[i]: n += 1
        if n >= 3: out += bytes((0x40 | (n - 1), d[i])); i += n; continue
        j = i
        while j < len(d) and j - i < 64:
            if j + 2 < len(d) and d[j] == d[j + 1] == d[j + 2]: break
            j += 1
        out += bytes((j - i - 1,)) + d[i:j]; i = j
    return bytes(out)
def block(name, body): return struct.pack("<I", 5 + len(name) + len(body)) + bytes([len(name)]) + name + body
def apf(w, h, mode, tables, scbs, rows, multipal=None):
    body = struct.pack("<HHH", mode, w, len(tables)) + b"".join(struct.pack("<16H", *t) for t in tables)
    packed = [packbytes(r) for r in rows]
    body += struct.pack("<H", h) + b"".join(struct.pack("<HH", len(p), scbs[y]) for y, p in enumerate(packed)) + b"".join(packed)
    out = block(b"MAIN", body)
    if multipal: out += block(b"MULTIPAL", struct.pack("<H", len(multipal)) + b"".join(struct.pack("<16H", *t) for t in multipal))
    return out
def tab(): return [rnd.randrange(4096) for _ in range(16)]
def expect(w, h, scbs, rows, pals):          # RGB, as GS Remap reads it
    o = bytearray()
    for y in range(h):
        pal, r = pals(y), rows[y]
        for x in range(w):
            if scbs[y] & 0x80: c = [8, 12, 0, 4][x & 3] + ((r[x >> 2] >> (6 - 2 * (x & 3))) & 3)
            else: c = (r[x >> 1] >> 4) if x % 2 == 0 else r[x >> 1] & 15
            e = pal[c]; o += bytes(((e >> 8 & 15) * 17, (e >> 4 & 15) * 17, (e & 15) * 17))
    return bytes(o)
def picture(w, h, bpr):
    return [bytes(((x * 7 + y * 3) // 5 + (y // 9) * 17) & 255 if (x + y) % 11 else rnd.randrange(256) for x in range(bpr)) for y in range(h)]
w, h = 320, 260                               # taller than a screen, two tables by line
t = [tab(), tab()]; scbs = [y % 2 for y in range(h)]; rows = picture(w, h, 160)
save("TALL.APF", apf(w, h, 0, t, scbs, rows), "C00002")
open(os.path.join(out, "TALL.EXP"), "wb").write(expect(w, h, scbs, rows, lambda y: t[scbs[y] & 15]))
w, h = 700, 210                               # 640 mode, wider than a screen
t = [tab()]; scbs = [0x80] * h; rows = picture(w, h, w // 4)
save("WIDE.APF", apf(w, h, 0x80, t, scbs, rows), "C00002")
open(os.path.join(out, "WIDE.EXP"), "wb").write(expect(w, h, scbs, rows, lambda y: t[0]))
w, h = 320, 200                               # a MULTIPAL table for every line
mp = [tab() for _ in range(h)]; scbs = [0] * h; rows = picture(w, h, 160)
save("M3200.APF", apf(w, h, 0, [tab()], scbs, rows, mp), "C00002")
open(os.path.join(out, "M3200.EXP"), "wb").write(expect(w, h, scbs, rows, lambda y: mp[y]))

open(os.path.join(fix, "a2more.types"), "w").write("".join(f"{n} {t}\n" for n, t in types))
