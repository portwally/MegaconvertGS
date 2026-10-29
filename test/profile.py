# Where the time went: test/dump.lua's samples (run with PROFILE=file) mapped to the
# source through the assembler listings. Usage: profile.py samples [lines]
import sys, os, re, glob, collections
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
counts = {}
for line in open(sys.argv[1]):
    k, n = line.split(); counts[int(k, 16)] = int(n)
banks = {int(f[-2:], 16): open(f, "rb").read() for f in glob.glob(sys.argv[1] + ".[0-9A-F][0-9A-F]")}
pat = re.compile(r"^\s*\d+ \|\s*\d+\s+(\S+)\s+(\d+) \| (\w[\w ]*?)\s*\|[^|]*\|([^|]*)\|[^|]*\| 00/([0-9A-F]{4}) : ([0-9A-F ]+?)\s*\|")
built = os.path.getmtime(os.path.join(root, "build", "MegaconvertGS"))
where = {}                                          # (bank, address): (file, line)
for lst in sorted(glob.glob(os.path.join(root, "build", "MegaconvertGS_S*_Output.txt"))):
    if os.path.getmtime(lst) < built - 600: continue      # (left from an older build)
    code = []                                   # (offset, bytes, file, line, relocated)
    for l in open(lst, errors="replace"):
        m = pat.match(l)
        if m and m.group(3) in ("Code", "Data"):
            b = bytes(int(x, 16) for x in m.group(6).split())
            code.append((int(m.group(5), 16), b, m.group(1), int(m.group(2)), m.group(4).strip() != ""))
    # Find the segment in the busy banks: runs of 16 known bytes (relocated operands
    # are not known), and the place most of them agree on.
    img = {}
    for off, b, f, ln, reloc in code:
        for j, x in enumerate(b): img[off + j] = None if reloc and j else x
    if not img: continue
    votes = collections.Counter()
    for start in range(0, max(img), 64):
        seq = [img.get(start + j) for j in range(16)]
        if None in seq: continue
        for bk, mem in banks.items():
            for m in re.finditer(re.escape(bytes(seq)), mem):
                votes[(bk, m.start() - start)] += 1
    if not votes: continue
    (bank, base), n = votes.most_common(1)[0]
    if n < 4: continue
    print(f"{os.path.basename(lst)}: bank {bank:02X} at {base:04X} ({n} anchors)")
    for off, b, f, ln, reloc in code:
        for j in range(len(b)): where[(bank, base + off + j)] = (f, ln)
src = {}
def label(f, ln):
    if f not in src:
        src[f] = open(os.path.join(root, "src", f), errors="replace").read().split("\n")
    lines = src[f]
    for i in range(ln - 1, -1, -1):
        t = lines[i]
        if t and t[0] not in " *;:" and not t.startswith("\t"):
            return t.split()[0]
    return "?"
tot = sum(counts.values())
inb = collections.Counter(); per_line = collections.Counter(); other = 0
for k, c in counts.items():
    if (k >> 16, k & 0xFFFF) in where:
        f, ln = where[(k >> 16, k & 0xFFFF)]
        inb[(f, label(f, ln))] += c; per_line[(f, ln)] += c
    else:
        other += c
print(f"{tot} samples, {other} elsewhere (toolbox, other segments) {100 * other / tot:.1f}%")
for (f, lab), c in inb.most_common(40):
    print(f"{100 * c / tot:5.1f}%  {lab:14s} {f}")
nl = int(sys.argv[2]) if len(sys.argv) > 2 else 0
for (f, ln), c in per_line.most_common(nl):
    print(f"{100 * c / tot:5.1f}%  {f}:{ln}  {src[f][ln - 1].strip()}")
