# The remaps test/remap2.sh tries: picture, then mode, palette, rendering, steps across
# and down (255: fitted), other, and for palette 5 (stored) the screen Store palette was
# used on first (a picture above, or an earlier run's result). Prints the test commands
# with "commands".
import sys
SOURCES = {  # tag: disk file, local file, load format id
    "RGB": ("MCTRUE:RGB8.PNG", "build/fixtures/true/RGB8.PNG", "png"),
    "BIG": ("MCTRUE:BIG.PNG", "build/fixtures/true/BIG.PNG", "png"),
    "GRY": ("MCTRUE:GREY8.PNG", "build/fixtures/true/GREY8.PNG", "png"),
    "TNY": ("MCTRUE:PAL4.PNG", "build/fixtures/true/PAL4.PNG", "png"),
    "SCR": ("MCTEST:S320.C1", "build/fixtures/S320.c1", "c1"),
    "S64": ("MCTEST:S640.C1", "build/fixtures/S640.c1", "c1"),
}
F = 255
RUNS = [  # name, source, mode, palette, algorithm, h, v, other
    ("R01", "RGB", 0, 0, 1, F, F, 0), ("R02", "RGB", 0, 0, 0, F, F, 0), ("R03", "RGB", 0, 1, 1, F, F, 0),
    ("R04", "RGB", 0, 2, 2, F, F, 0), ("R05", "RGB", 0, 2, 1, F, F, 0), ("R06", "RGB", 0, 3, 1, F, F, 1),
    ("R07", "RGB", 0, 3, 2, F, F, 0), ("R08", "RGB", 0, 3, 1, F, F, 3), ("R09", "RGB", 1, 0, 1, F, F, 0),
    ("R10", "RGB", 1, 0, 0, F, F, 0), ("R11", "RGB", 1, 2, 2, F, F, 0), ("R12", "RGB", 1, 3, 1, F, F, 1),
    ("R13", "RGB", 2, 0, 1, F, F, 0), ("R14", "RGB", 2, 0, 0, F, F, 0), ("R15", "RGB", 2, 1, 1, F, F, 0),
    ("R16", "RGB", 2, 3, 2, F, F, 2), ("R17", "RGB", 3, 0, 1, F, F, 0), ("R18", "RGB", 3, 3, 1, F, F, 2),
    ("R19", "RGB", 3, 3, 1, F, F, 0), ("R20", "BIG", 0, 0, 1, 19, 9, 0), ("R21", "BIG", 0, 0, 1, 9, 14, 0),
    ("R22", "SCR", 1, 0, 1, F, F, 0), ("R23", "S64", 0, 0, 1, F, F, 0), ("R24", "S64", 2, 0, 1, F, F, 0),
    ("R25", "GRY", 0, 0, 2, F, F, 0), ("R26", "GRY", 1, 2, 2, F, F, 0), ("R27", "TNY", 0, 1, 0, 14, 14, 0),
    # The picture's current palette (each straight after loading: it is the screen's palette)
    ("R28", "RGB", 0, 4, 1, F, F, 0), ("R29", "SCR", 0, 4, 0, F, F, 0), ("R30", "S64", 1, 4, 1, F, F, 0),
    ("R31", "S64", 2, 4, 1, F, F, 0), ("R32", "S64", 0, 4, 1, F, F, 0), ("R33", "GRY", 0, 4, 2, F, F, 0),
    # The stored palette (Screen > Store palette), each unlike the calculated one: colours
    # from a 320 screen for a grey picture, then not in 640 mode; from a 640 dither screen;
    # from earlier results (640 dither, 640 four colours, greys with error diffusion, and
    # four colours not in 640 dither mode)
    ("S01", "GRY", 0, 5, 1, F, F, 0, "SCR"), ("S02", "RGB", 1, 5, 1, F, F, 0, "SCR"),
    ("S03", "GRY", 2, 5, 1, F, F, 0, "S64"), ("S04", "GRY", 2, 5, 0, F, F, 0, "R13"),
    ("S05", "GRY", 1, 5, 1, F, F, 0, "R09"), ("S06", "RGB", 0, 5, 2, F, F, 0, "R04"),
    ("S07", "S64", 2, 5, 1, F, F, 0, "R09"),
    # Quick remap
    ("Q01", "RGB", "q", 0, 0, 0, 0, 0), ("Q02", "BIG", "q", 0, 0, 0, 0, 0), ("Q03", "S64", "q", 0, 0, 0, 0, 0),
]
if __name__ == "__main__" and sys.argv[1:] == ["commands"]:
    loaded = None
    for name, src, *opts in RUNS:
        disk, local, fid = SOURCES[src]
        if len(opts) > 6:                   # Store palette on that screen first
            store = opts.pop()
            print(f"LOAD AS c1 *:{SOURCES[store][0] if store in SOURCES else 'MCOUT:' + store + '.C'}")
            print("MENU 295")
            loaded = None
        if src != loaded or opts[1] == 4:   # (REMAP starts again from the loaded picture)
            print(f"LOAD AS {fid} *:{disk}")
            loaded = src
        if opts[0] == "q":
            print("REMAP QUICK")
        else:
            print("REMAP WITH " + " ".join(str(o) for o in opts))
        print(f"SAVE C1 *:MCOUT:{name}.C")
    print("SHOW")
