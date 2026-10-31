# Reads MegaconvertGS's own lists and texts for the manual: the Load formats window's
# computer types and formats (src/DeskLists.s), the Save formats list, and each format's
# Info on format text (src/FormatInfo.s), as the program shows them.
import os, re
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(ROOT, "src")

def merlin_strings(text):
    """The characters of Merlin asc/dfb data: quoted pieces and hex bytes."""
    out = []
    for piece in re.findall(r"'[^']*'|\b[0-9A-F]{2}\b", text):
        if piece.startswith("'"): out.append(piece[1:-1])
        else: out.append({0x27: "’", 0x0D: "\n", 0xAA: "™", 0xC9: "…"}.get(int(piece, 16), ""))
    return "".join(out)

def equates():
    eq = {}
    for line in open(os.path.join(SRC, "Equates.s"), encoding="latin-1"):
        m = re.match(r"^(\w+)\s*=\s*(\$?[0-9A-Fa-f]+)\b", line)
        if m:
            v = m.group(2); eq[m.group(1)] = int(v[1:], 16) if v.startswith("$") else int(v)
    return eq

def code(line):
    """A source line without its comment (a ';' outside quotes)."""
    quoted = False
    for i, ch in enumerate(line):
        if ch == "'": quoted = not quoted
        elif ch == ";" and not quoted: return line[:i]
    return line

def labelled_text(src, label):
    """The asc lines from a label up to the next label."""
    m = re.search(r"^" + re.escape(label) + r"\s+(asc|dfb|str).*?(?=^\w|\Z)", src, re.S | re.M)
    if not m: return ""
    body = "\n".join(code(l) for l in m.group(0).split("\n"))
    body = re.sub(r"^" + re.escape(label), "", body)
    return body

def load_lists():
    src = open(os.path.join(SRC, "DeskLists.s"), encoding="latin-1").read()
    eq = equates()
    names = {}
    for m in re.finditer(r"^(\w+)\s+dfb\s+\d+\s*\n\s+asc\s+(.*)$", src, re.M):
        names[m.group(1)] = merlin_strings(m.group(2))
    types = []
    for k in range(eq.get("NTypes", 14) if "NTypes" in eq else 14):
        tname = names.get(f"TyName{k}")
        if tname is None: break
        m = re.search(rf"^FmMems{k}\s+=\s+\*\s*\n(.*?)(?=^\w+\s+=|^\w+\s+dfb|\Z)", src, re.S | re.M)
        fmts = []
        if m:
            for nm, num, icon in re.findall(r"adrl\s+(FmName\w+)\s*\n\s+db\s+\S+\s*\n\s+dw\s+(\w+),(\d+),", m.group(1)):
                n = eq[num] if num in eq else int(num)
                fmts.append((names[nm], n, int(icon)))
        types.append((tname, fmts))
    saves = []
    m = re.search(r"^SaveMems\s+=\s+\*\s*\n(.*?)(?=^\w+\s+dfb)", src, re.S | re.M)
    for nm, num, icon in re.findall(r"adrl\s+(SvName\w+)\s*\n\s+db\s+\S+\s*\n\s+dw\s+(\w+),(\d+),", m.group(1)):
        saves.append((names[nm], int(num), int(icon)))
    return types, saves

def info_texts():
    src = open(os.path.join(SRC, "FormatInfo.s"), encoding="latin-1").read()
    def table(label):
        m = re.search(rf"^{label}\s+da\s+(.*?)(?=^\s*$|^\w+\s+asc)", src, re.S | re.M)
        return [x.strip() for x in re.findall(r"[\w$]+", m.group(1)) if x not in ("da",)]
    def text(label):
        if label in ("0", ""): return None
        t = merlin_strings(labelled_text(src, label))
        t = re.sub(r"^\d\d/", "", t)
        t = re.sub(r"/\^#0$", "", t)
        return t
    fmt = {i: text(l) for i, l in enumerate(table("FmtInfo"))}
    sav = {i: text(l) for i, l in enumerate(table("SaveInfo"))}
    return fmt, sav

if __name__ == "__main__":
    types, saves = load_lists()
    fmt, sav = info_texts()
    for t, fs in types:
        print("==", t)
        for name, n, icon in fs:
            print(f"   {n:3d} {icon} {name:45s} {(fmt.get(n) or 'NO TEXT')[:60]!r}")
    print("== saves")
    for name, n, icon in saves:
        print(f"   {n:3d} {name:45s} {(sav.get(n) or 'NO TEXT')[:60]!r}")
