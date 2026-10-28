# Checks the Examine file test (test/examine.sh): the windows' states from the log, their
# screens against models of the dump lines and the histogram made from the files' bytes.
import os, re, sys
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
res = os.path.join(root, "build", "test", "results")
ref = os.path.join(root, "build", "test", "ref")
ok = True
def report(label, problem):
    global ok
    print(f"{label:64s} {'OK' if not problem else 'FAIL: ' + problem}")
    ok &= not problem

log = [l for l in open(os.path.join(res, "MC.LOG#040000"), "rb").read().decode("latin-1").split("\r") if l]
states = {}
for l in log:
    m = re.match(r"EXAMINE (\d+) .*?: mode (\d+), top (\d+), lines (\d+), shift (\d+), thumb (\d+), "
                 r"max (\d+), value (none|\d+)(?:: (.*))?$", l)
    if m:
        states[int(m[1])] = dict(mode=int(m[2]), top=int(m[3]), lines=int(m[4]), shift=int(m[5]),
                                 thumb=int(m[6]), max=int(m[7]),
                                 value=None if m[8] == "none" else int(m[8]), info=m[9])

def reffile(name, fork=False):
    for f in os.listdir(ref):
        if f.split("#")[0] == name and f.endswith("_ResourceFork.bin") == fork:
            return open(os.path.join(ref, f), "rb").read()
s320 = open(os.path.join(root, "build", "fixtures", "S320.c1"), "rb").read()
readme, readme_res = reffile("Read.Me"), reffile("Read.Me", True)
keyboard_res, clipboard = reffile("Keyboard", True), reffile("Clipboard")

def screen(k):
    name = "EXAM" + chr(65 + k)
    for f in os.listdir(os.path.join(res, "MCOUT")):
        if f.split("#")[0] == name:
            return open(os.path.join(res, "MCOUT", f), "rb").read()
def px(img, x, y):                       # the window's content: global (2, 30) on
    gx, gy = x + 2, y + 30
    return (img[gy * 160 + gx // 4] >> (6 - 2 * (gx & 3))) & 3

def state(k, label, **want):
    st = states.get(k)
    if st is None:
        report(label, "not logged"); return
    diff = {key: st[key] for key, v in want.items() if st[key] != v}
    report(label, None if not diff else repr(diff))

# The dump: 75 cells of 8 pixels from h 5, line r on rows 14 + 9r to 21 + 9r.
FORE, BACK = [1, 0, 0, 0, 1, 0, 0, 0], [3, 3, 3, 3, 2, 2, 2, 2]
def cells(data, off):
    n = min(16, len(data) - off)
    text = "%06X | " % (off & 0xFFFFFF) + "".join(("%02X " % data[off + j]) if j < n else "   "
                                                   for j in range(16)) + "| "
    out = [(ord(c), 0, 3) for c in text]
    for j in range(16):
        if j < n:
            b = data[off + j]
            c = b & 0x7F
            c = 0xC6 if c == 0x7F else c + 0x40 if c < 0x20 else c
            out.append((c, FORE[b >> 5], BACK[b >> 5]))
        else:
            out.append((0x20, 0, 3))
    return out
glyphs = {}                              # each character's 8 x 8 cell, the same everywhere
def check_dump(k, data, top, label):
    img = screen(k)
    if img is None:
        report(label, "no screen"); return
    bad = []
    if any(px(img, x, 12) != 0 for x in range(0, 612)):
        bad.append("the line under the buttons")
    for r in range(17):
        off = (top + r) * 16
        if off >= len(data):
            if any(px(img, x, y) != 3 for y in range(14 + 9 * r, 22 + 9 * r) for x in range(0, 610)):
                bad.append(f"line {r} drawn past the end")
            continue
        for c, (ch, fore, back) in enumerate(cells(data, off)):
            pix = [px(img, 5 + 8 * c + i, 14 + 9 * r + j) for j in range(8) for i in range(8)]
            if any(p not in (fore, back) for p in pix):
                bad.append(f"line {r} cell {c} ({chr(ch)!r}): colours {sorted(set(pix))}, not {fore}/{back}")
                continue
            bm = tuple(p == fore for p in pix)
            if glyphs.setdefault(ch, bm) != bm:
                bad.append(f"line {r} cell {c}: {chr(ch)!r} drawn differently")
        if any(px(img, x, 22 + 9 * r) != 3 for x in range(0, 610)):
            bad.append(f"line {r}: the row below it")
    report(label, None if not bad else "; ".join(bad[:3]) + (f" (+{len(bad) - 3})" if len(bad) > 3 else ""))

# The histogram: value v's bar on column 40 (v >> 4) + 2 (v & 15) + 2, rows 152 - h to 152,
# h = count x 140 / the largest count; a scale under each group (rows 153-156, pattern rows 1-4).
PAT = {1: [3, 1, 3, 1, 3, 1, 3, 1], 2: [2, 3, 3, 3, 2, 3, 3, 3], 3: [2, 3, 3, 3, 2, 3, 3, 3],
       4: [2, 3, 3, 3, 3, 3, 3, 3]}
def info(v, count, size):
    head = f'"{chr(v)}"' if v >= 0x20 else f"^{chr(v + 64)} "
    d = f"{count * 10000 // size:5d}"
    d = d[:2] + d[2].replace(" ", "0") + "." + d[3].replace(" ", "0") + d[4]
    return f"{head}  ${v:02X} hex  {v:3d} decimal     {count:7d} occurrences, {d}% of file"
def check_hist(k, data, hi, label):
    img = screen(k)
    if img is None:
        report(label, "no screen"); return
    counts = [0] * 256
    for b in data:
        counts[b] += 1
    top = max(counts)
    bad = []
    for v in range(256):
        x = 40 * (v >> 4) + 2 * (v & 15) + 2
        h = counts[v] * 140 // top
        want = [3] * 141
        if counts[v]:
            for y in range(152 - h, 153):
                want[y - 12] = 1 if v == hi else 0
        if [px(img, x, y) for y in range(12, 153)] != want:
            bad.append(f"bar ${v:02X}")
        if any(px(img, x + 1, y) != 3 for y in range(12, 153)):
            bad.append(f"right of bar ${v:02X}")
    if any(px(img, x, y) != 3 for x in (0, 1) for y in range(12, 153)):
        bad.append("left of the bars")
    for y in range(153, 157):
        row = [px(img, x, y) for x in range(636)]
        want = [PAT[y & 7][x & 7] if (x - 1) % 40 < 33 and x < 634 else 3 for x in range(636)]
        if row != want:
            bad.append(f"scale row {y}")
    text = sum(1 for y in range(157, 167) for x in range(636) if px(img, x, y) != 3)
    if (hi is None) != (text == 0) or (hi is not None and text < 50):
        bad.append(f"info line: {text} pixels")
    report(label, None if not bad else "; ".join(bad[:4]) + (f" (+{len(bad) - 4})" if len(bad) > 4 else ""))
    st = states.get(k)
    if st is not None:
        want = info(hi, counts[hi], len(data)) if hi is not None else None
        report(label + ": max and info line", None if st["max"] == top and st["value"] == hi and st["info"] == want
               else f"{st['max']} {st['value']} {st['info']!r}, not {top} {hi} {want!r}")

state(0, "S320.C1: data fork at the start, 2048 lines", mode=1, top=0, lines=2048, shift=0, thumb=0)
check_dump(0, s320, 0, "S320.C1: lines 0-16")
state(1, "two arrow clicks and a page down: top 18", mode=1, top=18, thumb=18)
state(2, "the thumb at 18: top 18", mode=1, top=18, thumb=18)
check_dump(1, s320, 18, "scrolled to 18: lines 18-34")
report("scrolled lines the same as drawn afresh (top 18)", None if screen(1) == screen(2) else "differ")
state(3, "thumb at 30, an arrow and a page up: top 13", mode=1, top=13, thumb=13)
state(4, "the thumb at 13: top 13", mode=1, top=13, thumb=13)
check_dump(3, s320, 13, "scrolled back to 13: lines 13-29")
report("scrolled lines the same as drawn afresh (top 13)", None if screen(3) == screen(4) else "differ")
state(5, "the thumb past the end: the last 17 lines", mode=1, top=2031, thumb=2031)
check_dump(5, s320, 2031, "the last lines")
state(6, "histogram, the pointer between bars then on $55", mode=2, value=0x55)
check_hist(6, s320, 0x55, "S320.C1's histogram, $55 (the largest) shown")
state(7, "histogram, the pointer on $55 then between bars", mode=2, value=None)
check_hist(7, s320, None, "S320.C1's histogram, nothing shown")
report("back to the data fork after the histogram: as at the start",
       None if screen(14) == screen(0) else "differs")
state(14, "histogram, $99 shown, back to the data fork", mode=1, top=0)
state(15, "histogram, the pointer at the bars' top row on $99", mode=2, value=0x99)
check_hist(15, s320, 0x99, "S320.C1's histogram, $99 shown")
state(8, "Read.Me: data fork, 135 lines, thumb at 118", mode=1, top=118, lines=135, thumb=118)
check_dump(8, readme, 118, "Read.Me: the last lines, the last one 6 bytes")
state(9, "Read.Me: resource fork, 38 lines", mode=3, top=0, lines=38)
check_dump(9, readme_res, 0, "Read.Me's resource fork")
state(10, "Keyboard (no data fork): the resource fork at the start", mode=3, top=0, lines=218)
check_dump(10, keyboard_res, 0, "Keyboard's resource fork")
def area(k, x0, x1):
    img = screen(k)
    return [px(img, x, y) for y in range(0, 11) for x in range(x0, x1)]
report("buttons: Resource fork dimmed without one, Data fork without that",
       None if area(0, 320, 450) != area(9, 320, 450) and area(0, 10, 110) != area(10, 10, 110) else "the same")
state(11, "the Clipboard file (2 bytes): histogram, $00 shown", mode=2, value=0)
check_hist(11, clipboard, 0, "the Clipboard file's histogram")
check_hist(12, readme, 0x65, "Read.Me's histogram, 'e' shown")
check_hist(13, readme, 0x0D, "Read.Me's histogram, a return shown (^M)")
hexes = [glyphs.get(ord(c)) for c in "0123456789ABCDEF"]
report("the hex digits all drawn, each differently",
       None if None not in hexes and len(set(hexes)) == 16 else "missing or alike")
report("spaces blank", None if glyphs.get(32) == tuple([False] * 64) else "not blank")
sys.exit(0 if ok else 1)
