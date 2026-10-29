# Checks MegaconvertGS's Apple II save formats (test/a2save.sh): each saved file against a
# model of Save.s's rules (model() below), made from the screen saved as $C1 beside it.
# Pictures loaded from Apple II files must also save back as they were.
import os, sys
PICTURES = [  # tag, file on the test disk, load format id, width, height
    ("S32", "MCTEST:S320.C1", "c1", 320, 200),
    ("S64", "MCTEST:S640.C1", "c1", 640, 200),
    ("HGR", "MCAPPLE:HGR.PIC", "hgr", 280, 192),
    ("DHR", "MCAPPLE:DHR.PIC", "dhr", 280, 192),
    ("DHB", "MCAPPLE:DHRBW.PIC", "dhrbw", 560, 192),
    ("HGB", "MCAPPLE:HGRBW.PIC", "hgrbw", 280, 192),
    ("LOR", "MCNEWFMT:LORES", "lores", 280, 192),
    ("DLR", "MCNEWFMT:DLORES", "dlores", 280, 192),
]
FORMATS = ["hgr", "hgrbw", "dhr", "dhrbw", "lores", "dlores", "hgrp", "hgrbwp", "dhrp", "dhrbwp"]
# Apple II files of type $08 (test/make_newfmt.py): each opened by itself must give the
# picture it was made from, loaded as that format.
OPENS = [("HGR.PK", "MCAPPLE:HGR.PIC", "hgr"), ("DHR.PK", "MCAPPLE:DHR.PIC", "dhr"),
         ("FOT1", "MCAPPLE:HGR.PIC", "hgr"), ("FOT4", "MCAPPLE:HGR.PIC", "hgrbw"),
         ("FOT2", "MCAPPLE:DHR.PIC", "dhrbw"), ("FOT3", "MCAPPLE:DHRBW.PIC", "dhr")]
# saved as it was loaded: (tag, format) -> the original file
SAME = {("DHR", "dhr"): "DHR.PIC", ("DHB", "dhrbw"): "DHRBW.PIC", ("HGB", "hgrbw"): "HGRBW.PIC",
        ("LOR", "lores"): "../newfmt/LORES", ("DLR", "dlores"): "../newfmt/DLORES"}
if sys.argv[1:] == ["commands"]:
    for tag, disk, fid, w, h in PICTURES:
        print(f"LOAD AS {fid} *:{disk}")
        print(f"SAVE C1 *:MCOUT:{tag}.C")
        for fmt in FORMATS:
            print(f"SAVE AS {fmt} *:MCOUT:{tag}.{fmt.upper()}")
    for k, (name, orig, fid) in enumerate(OPENS):
        print(f"LOAD AS {fid} *:{orig}")
        print(f"SAVE C1 *:MCOUT:O{k}A")
        print(f"LOAD *:MCNEWFMT:{name}")
        print(f"SAVE C1 *:MCOUT:O{k}B")
    print("SHOW")
    sys.exit()

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
res = os.path.join(root, "build", "test", "results", "MCOUT")
def ours(name):
    for f in os.listdir(res):
        if f.split("#")[0] == name:
            return open(os.path.join(res, f), "rb").read(), f.split("#")[1] if "#" in f else ""
    return None, ""

A2PAL = [0x000, 0xD03, 0x852, 0xF60, 0x070, 0x555, 0x0D0, 0xFF0,
         0x009, 0xD0D, 0xAAA, 0xF98, 0x22F, 0x6AF, 0x0F9, 0xFFF]
HCAND = [0, 15, 9, 6, 12, 3]

def colours(scr, w, h):
    """The 12-bit colour shown at each pixel of the picture (top left of the screen)."""
    rows = []
    for y in range(h):
        scb = scr[0x7D00 + y]
        pal = [scr[0x7E00 + (scb & 15) * 32 + 2 * i] | scr[0x7E00 + (scb & 15) * 32 + 2 * i + 1] << 8 for i in range(16)]
        line = scr[y * 160:(y + 1) * 160]
        if scb & 0x80:
            row = [pal[(8, 12, 0, 4)[x & 3] + (line[x >> 2] >> (6 - 2 * (x & 3)) & 3)] & 0xFFF for x in range(w)]
        else:
            row = [pal[line[x >> 1] >> (0 if x & 1 else 4) & 15] & 0xFFF for x in range(w)]
        rows.append(row)
    return rows

def comps(c):
    return [(c >> 8 & 15) * 17, (c >> 4 & 15) * 17, (c & 15) * 17]

def near(v, cands):
    """The closest of cands to channels v (squared differences / 4, the first of equals)."""
    best = None
    for k, n in enumerate(cands):
        d = sum((abs(x - y) >> 2) ** 2 for x, y in zip(comps(A2PAL[n]), v))
        if best is None or d < best[0]:
            best = (d, k)
    return best[1]

TOLO = [0, 1, 8, 9, 4, 5, 12, 13, 2, 3, 10, 11, 6, 7, 14, 15]
def TEXTOFF(t):
    return (t & 7) * 128 + (t >> 3) * 40

def rowoff(y):
    return (y & 7) * 0x400 + (y >> 3 & 7) * 0x80 + (y >> 6) * 40

def model(rows, w, h, fmt):
    """Save.s's Apple II saver: the picture stretched to the screen, each place the average
    of the pixels it covers (channels 0-255, rounded down; columns i w / W up to (i + 1) w / W,
    lines y h / 192 up to (y + 1) h / 192, one at least), then with Floyd-Steinberg errors (7, 3, 5 and the rest of 16ths, rounded down; dropped at the
    edges) taken to the closest it can be."""
    places = {"hgr": 140, "hgrbw": 280, "dhr": 140, "dhrbw": 560, "lores": 40, "dlores": 80}[fmt]
    lo = fmt.endswith("lores")
    H = 48 if lo else 192
    bw = fmt.endswith("bw")
    top = 2550 if bw else 255
    nch = 1 if bw else 3
    out = bytearray({"hgr": 8192, "hgrbw": 8192, "dhr": 16384, "dhrbw": 16384, "lores": 1024, "dlores": 2048}[fmt])
    err = [[0] * (places + 2) for _ in range(nch)]          # for this line, at place + 1
    for y in range(H):
        r0, r1 = y * h // H, (y + 1) * h // H
        lines = rows[r0:max(r1, r0 + 1)]
        vals = []
        for i in range(places):
            x0, x1 = i * w // places, (i + 1) * w // places
            px = [comps(line[x]) for line in lines for x in range(x0, max(x1, x0 + 1))]
            vals.append([sum(p[ch] for p in px) // len(px) for ch in range(3)])
        nxt = [[0] * (places + 2) for _ in range(nch)]
        if fmt == "hgr":                                    # each byte's colour pair
            vote = [0] * 40
            for i, c in enumerate(vals):
                k = HCAND[near(c, HCAND)]
                vote[2 * i // 7] += 1 if k in (12, 3) else -1 if k in (9, 6) else 0
            dotcol = [(12 if d % 2 == 0 else 3) if vote[d // 7] > 0 else (9 if d % 2 == 0 else 6) for d in range(280)]
        dots = []
        carry = [0] * nch
        for i, c in enumerate(vals):
            base = [3 * c[0] + 6 * c[1] + c[2]] if bw else c
            v = [min(max(x + err[ch][i + 1] + carry[ch], 0), top) for ch, x in enumerate(base)]
            if bw:
                on = v[0] >= 1275
                p = [2550 if on else 0]
                dots.append(1 if on else 0)
            else:
                cands = [0, 15, dotcol[2 * i], dotcol[2 * i + 1]] if fmt == "hgr" else list(range(16))
                k = near(v, cands)
                p = comps(A2PAL[cands[k]])
                if lo:
                    dots.append(cands[k])
                elif fmt == "hgr":
                    dots += [(0, 0), (1, 1), (1, 0), (0, 1)][k]
                else:
                    n = cands[k]
                    dots += [n >> 3 & 1, n >> 2 & 1, n >> 1 & 1, n & 1]
            for ch in range(nch):
                e = v[ch] - p[ch]
                e7, e3, e5 = 7 * e >> 4, 3 * e >> 4, 5 * e >> 4
                carry[ch] = e7
                nxt[ch][i] += e3
                nxt[ch][i + 1] += e5
                nxt[ch][i + 2] += e - e7 - e3 - e5
        for ch in range(nch):                                # (the edges' errors dropped)
            nxt[ch][0] = 0
            nxt[ch][places + 1] = 0
        err = nxt
        if lo:                                              # the text page: LoRes colour numbers
            for i, n in enumerate(dots):
                c = TOLO[n]
                at = TEXTOFF(y >> 1) + (i >> 1 if fmt == "dlores" else i)
                if fmt == "dlores":
                    if i & 1: at += 1024
                    else: c = (c >> 1 | c << 3) & 15
                out[at] |= c << (4 if y & 1 else 0)
            continue
        for g in range(len(dots) // 7):
            byte = sum(dots[7 * g + i] << i for i in range(7))
            if fmt == "hgr" and vote[g] > 0:
                byte |= 0x80
            if fmt.startswith("hgr"):
                out[rowoff(y) + g] = byte
            else:
                out[rowoff(y) + g // 2 + (8192 if g & 1 else 0)] = byte
    return bytes(out)

def unpackbytes(d):
    o, i = bytearray(), 0
    while i < len(d):
        f = d[i]; n = (f & 0x3F) + 1; i += 1
        k = f >> 6
        if k == 0: o += d[i:i + n]; i += n
        elif k == 1: o += bytes([d[i]]) * n; i += 1
        elif k == 2: o += d[i:i + 4] * n; i += 4
        else: o += bytes([d[i]]) * (n * 4); i += 1
    return bytes(o)

def visible(data, size):
    """The screen bytes of a HiRes page (or two): the low 7 bits, no screen holes; of a
    text page (or two): all 8 bits, no screen holes."""
    keep = bytearray()
    if size <= 2048:
        for half in range(0, size, 1024):
            for t in range(24):
                keep += data[half + TEXTOFF(t):half + TEXTOFF(t) + 40]
        return bytes(keep)
    for half in range(0, size, 8192):
        for y in range(192):
            keep += bytes(b & 0x7F for b in data[half + rowoff(y):half + rowoff(y) + 40])
    return bytes(keep)

ok = True
for tag, disk, fid, w, h in PICTURES:
    scr, _ = ours(f"{tag}.C")
    if scr is None or len(scr) != 32768:
        print(f"{tag}: no $C1 screen saved"); ok = False; continue
    rows = colours(scr, w, h)
    for fmt in FORMATS:
        name = f"{tag}.{fmt.upper()}"
        got, typ = ours(name)
        packed = fmt.endswith("p")
        want = model(rows, w, h, fmt[:-1] if packed else fmt)
        if packed and got is not None:
            got = unpackbytes(got)
        if got is None:
            print(f"{name:12} not saved"); ok = False; continue
        res_ = "OK" if got == want else "DIFFERENT"
        if got != want:
            ok = False
            diff = [i for i in range(len(want)) if i >= len(got) or got[i] != want[i]]
            res_ += f" ({len(got)} bytes, {len(diff)} differ, first at {diff[0] if diff else '-'})"
        want_aux = "060400" if fmt.endswith("lores") else ("084000" if fmt.startswith("hgr") else "084001") if packed else "062000"
        if not typ.upper().startswith(want_aux):
            res_ += f" (type {typ}, not ${want_aux[:2]}/${want_aux[2:]})"; ok = False
        extra = ""
        if (tag, fmt) in SAME:
            orig = open(os.path.normpath(os.path.join(root, "build", "fixtures", "apple", SAME[(tag, fmt)])), "rb").read()
            same = visible(orig, len(want)) == visible(got, len(want))
            extra = "  saved as loaded" if same else "  NOT as loaded"
            ok &= same
        print(f"{name:12} {typ:10} {res_}{extra}")
log = open(os.path.join(root, "build", "test", "results", "MC.LOG#040000"), "rb").read().decode().split("\r")
for k, (name, orig, fid) in enumerate(OPENS):
    a, _ = ours(f"O{k}A")
    b, _ = ours(f"O{k}B")
    how = next((l.split(": ", 1)[1] for l in log if l.startswith(f"LOAD *:MCNEWFMT:{name}:")), "?")
    good = a is not None and a == b
    ok &= good
    print(f"{name:12} opened by itself {'as ' + fid + ' OK' if good else 'DIFFERENT'}  ({how})")
print("all OK" if ok else "FAILED")
sys.exit(0 if ok else 1)
