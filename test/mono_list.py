# The monochrome test's steps (test/mono.sh). Run as a script: prints the test commands.
# Each step: ("load", picture), ("mono", kind, h, v, method), ("out", kind, aspect, scaling,
# 640, shrink), ("neg",), ("save", what, name) with what "mono", "c1" or "rgb".
PICTURES = ["GREY8.PNG", "RGB8.PNG"]
STEPS = []
for p, t in (("GREY8.PNG", "G"), ("RGB8.PNG", "C")):
    STEPS += [("load", p), ("save", "rgb", f"{t}.IN"), ("save", "c1", f"{t}.SC")]
    for m in (1, 2, 3, 4):
        STEPS += [("mono", 2, 1, 1, m), ("save", "mono", f"{t}.T{m}")]
    STEPS += [("mono", 2, 2, 1, 1), ("save", "mono", f"{t}.T21"),
              ("mono", 2, 1, 4, 2), ("save", "mono", f"{t}.T14")]
    for m in (1, 4):
        STEPS += [("mono", 0, 1, 1, m), ("save", "mono", f"{t}.S{m}")]
    STEPS += [("mono", 0, 2, 2, 1), ("save", "mono", f"{t}.S22")]
    for i, (a, s, m6, sh) in enumerate([(1, 1, 0, 1), (2, 2, 1, 1), (3, 4, 0, 2), (1, 2, 0, 3),
                                         (2, 4, 1, 4), (3, 1, 1, 1), (1, 4, 1, 1), (2, 1, 0, 2)]):
        STEPS += [("out", 2, a, s, m6, sh), ("save", "rgb", f"{t}.R{i}")]
    for i, (a, s, m6, sh) in enumerate([(1, 1, 0, 1), (2, 2, 1, 1), (3, 4, 0, 2), (1, 2, 1, 3)]):
        STEPS += [("mono", 2, 1, 1, 1), ("out", 0, a, s, m6, sh), ("save", "c1", f"{t}.O{i}")]
    STEPS += [("neg",), ("save", "mono", f"{t}.NEG")]

def commands():
    out = []
    for st in STEPS:
        k = st[0]
        if k == "load": out.append(f"LOAD *:MCTRUE:{st[1]}")
        elif k == "mono": out.append("MONO " + " ".join(str(v) for v in st[1:]))
        elif k == "out": out.append("MONOOUT " + " ".join(str(v) for v in st[1:]))
        elif k == "neg": out.append("MONONEG")
        else: out.append(f"SAVE {st[1].upper()} *:MCOUT:{st[2]}")
    return out

if __name__ == "__main__":
    print("\n".join(commands()))
