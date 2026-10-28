# Checks the help text (help/MCGS.Help.txt) and the help test (test/help.sh): every page a
# button or a navigation line names exists, every menu item has a page (Menu item help:
# "I" and its number), lines fit the window, texts stay under 320 characters; and the
# pages the emulator laid out (HELPLOG) match a model of the layout rules (Help.s).
import os, re, sys
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ok = True
def report(label, problem):
    global ok
    print(f"{label:58s} {'OK' if not problem else 'FAIL: ' + problem}")
    ok &= not problem
text = open(os.path.join(root, "help", "MCGS.Help.txt"), encoding="ascii").read().split("\n")
if text and text[-1] == "": text.pop()
labels = {}
for i, line in enumerate(text):
    if line.startswith(".") and i > 0: labels.setdefault(line[1:].upper(), i + 1)
refs = []
for i, line in enumerate(text):
    if line.startswith("\\"):
        f = line[2:].split("~")[1:]
        refs += [(f[k + 1], i + 1) for k in range(0, len(f) - 1, 2) if f[k]]
    elif line.startswith("^") and not line[1:2].isdigit():
        refs += [(r, i + 1) for r in line[1:].split("~")[1:] if r]
missing = [f"{r} (line {n})" for r, n in refs if r.upper() not in labels]
report("every page a button or navigation line names exists", None if not missing else ", ".join(missing[:5]))
src = open(os.path.join(root, "src", "MegaconvertGS.s"), encoding="latin-1").read()
items = sorted({int(n) for n in re.findall(r"asc   '--[^']*\\N(\d+)", src) if int(n) >= 250})
nopage = [n for n in items if f"I{n}" not in labels]
report(f"every menu item ({len(items)}) has a page", None if not nopage else repr(nopage))
long = [i + 1 for i, l in enumerate(text) if len(l) > 80 and not l.startswith(("\\", "^", "."))]
report("text lines at most 80 characters", None if not long else repr(long[:5]))

def layout(label):                             # Help.s Layout: (buttons, height, nav)
    start = labels.get(label.upper())
    i = start if start is not None else 1      # (not found: the file's start)
    v, buttons = 3, 0
    while i < len(text):
        line = text[i]
        if line == "": v += 5; i += 1; continue
        c = line[0]
        if c in ".>": i += 1; continue
        if c == "=":
            if line[1:2] == "1": v += 1
            elif line[1:2] == "2": v -= 9
            i += 1; continue
        if c == "\\":
            f = line[2:].split("~")[1:]
            buttons += sum(1 for k in range(0, len(f) - 1, 2) if f[k])
            v += 15; i += 1; continue
        if c == "^" and not line[1:2].isdigit():
            nav = (line[1:].split("~") + ["", "", "", ""])[1:4]
            return buttons, v + 3, nav
        n, size = 1, len(line)
        while i + n < len(text):
            nxt = text[i + n]
            if not nxt or not (0x20 <= ord(nxt[0]) <= 0x2D or nxt[0].isalnum()): break
            if size + 1 + len(nxt) + 1 >= 320: break
            size += 1 + len(nxt); n += 1
        v += 9 * n; i += n
    return buttons, v + 3, ["", "", ""]

res = os.path.join(root, "build", "test", "results")
log = [l for l in open(os.path.join(res, "MC.LOG#040000"), "rb").read().decode("latin-1").split("\r") if l]
logs = [l.split(": ", 1)[1] for l in log if l.startswith("HELPLOG:")]
for (label, shown), got in zip((("HOME", "HOME"), ("LOADING", "LOADING"), ("I297", "I297"), ("MENUS", "MENUS"),
                                ("NOSUCHPAGE", "NOSUCHPAGE"), ("NOSUCHPAGE", "NOSUCHPAGE"), ("REMAP", "REMAP"),
                                ("HOME", "HOME")), logs):
    b, h, nav = layout(label)
    want = f"{shown}: prev {nav[0]}, next {nav[1]}, back {nav[2]}, buttons {b}, height {h}"
    report(f"the page {label} laid out as the model", None if got == want else f"{got!r}, not {want!r}")
report("a topic button clicked, then Back: its page, then HOME again",
       None if len(logs) == 8 else f"{len(logs)} pages logged")
sys.exit(0 if ok else 1)
