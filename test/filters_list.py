# The filter test's cases (test/filters.sh): each picture, then each operation on a
# fresh copy of it (SNAP keeps the picture as loaded, BACK brings it back). An operation
# is (FILTER number, factor) or ("t", rotate/flip bits).
# Run as a script, prints the test commands.
PICTURES = {"N": "NOISE.BMP", "T": "TALL.BMP", "W": "WIDE.BMP", "S": "SMOOTH.BMP"}
ALL = ([(k, 50) for k in (0, 1, 2, 3, 6, 8, 9)]
       + [(4, f) for f in (0, 1, 2, 3, 25, 50, 74, 94, 96, 97, 99)]       # blur
       + [(5, f) for f in (0, 1, 50, 98, 99)]                             # sharpen
       + [(7, f) for f in (0, 28, 38, 48, 74, 84, 89, 99)]                # find edges
       + [("t", b) for b in range(1, 8)])
SOME = [(k, 50) for k in range(10)] + [("t", b) for b in range(1, 8)]
CASES = {"N": ALL, "T": SOME, "W": SOME, "S": [(0, 50), (1, 50), (8, 50), (9, 50)]}

def name(tag, op):
    k, f = op
    return f"{tag}.T{f}" if k == "t" else f"{tag}.F{k}.{f}"

if __name__ == "__main__":
    for tag, pic in PICTURES.items():
        print(f"LOAD *:MCFILTER:{pic}")
        print(f"SAVE RGB *:MCOUT:{tag}.IN")
        print("SNAP")
        for op in CASES[tag]:
            print("BACK")
            print(f"TURN {op[1]}" if op[0] == "t" else f"FILTER {op[0]} {op[1]}")
            print(f"SAVE RGB *:MCOUT:{name(tag, op)}")
