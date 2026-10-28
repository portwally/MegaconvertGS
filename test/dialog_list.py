# The Remap dialog test (test/dialog.sh): clicks given to the dialog (CLICKS), and the
# remap GS Remap makes with the options they should have chosen. Prints the test
# commands with "commands".
import sys

# Where to click, in the dialog's own coordinates (v, h).
MODE = [(16, 60), (26, 60), (36, 60), (46, 60)]             # 320, 640, 640 dither, multipalette
DEFAULT, GREYS, CALC, STORED, CURRENT = (69, 60), (79, 60), (89, 60), (99, 60), (109, 60)
OTHER, GET_OTHER = (120, 15), (120, 92)
CLOSEST, PATTERN, DIFFUSION = (144, 60), (154, 60), (164, 60)
H_LESS, H_MORE, V_LESS, V_MORE = (87, 385), (87, 605), (101, 356), (163, 356)
INFO, CANCEL, QUICK, NORMAL = (21, 300), (127, 260), (143, 260), (160, 260)
def ITEM(i): return (22 + 11 * i, 100)                     # a line of the Get other list
# The scroll boxes' places for each scale step, as in RemapUI.s (HPos, VPos): a
# click there in the track picks that step.
HPOS = [3, 4, 4, 5, 7, 9, 11, 14, 17, 21, 26, 28, 32, 34, 43, 53, 57, 64, 71, 85, 106, 128, 170]
VPOS = [1, 1, 1, 1, 2, 2, 3, 3, 4, 5, 6, 7, 8, 8, 10, 13, 14, 15, 17, 21, 26, 31, 41]
def H_STEP(k): return (87, 410 + HPOS[k])
def V_STEP(k): return (112 + VPOS[k], 356)

SOURCES = {  # tag: disk file, local file, load format id
    "RGB": ("MCTRUE:RGB8.PNG", "build/fixtures/true/RGB8.PNG", "png"),
    "BIG": ("MCTRUE:BIG.PNG", "build/fixtures/true/BIG.PNG", "png"),
}
F = 255
# name, picture, load it first, clicks, GS Remap's options (mode palette rendering
# h-step v-step other; "q": quick remap)
RUNS = [
    ("D01", "RGB", True, [MODE[2], DEFAULT, CLOSEST, NORMAL], (2, 1, 0, F, F, 0)),
    ("D02", "RGB", False, [MODE[0], CALC, PATTERN, H_MORE, H_MORE, V_LESS, NORMAL], (0, 0, 1, 16, 13, 0)),
    ("D03", "RGB", False, [MODE[0], GET_OTHER, ITEM(2), PATTERN, NORMAL], (0, 3, 1, F, F, 2)),
    ("D04", "RGB", False, [MODE[0], GREYS, DIFFUSION, H_STEP(0), NORMAL], (0, 2, 2, 0, 14, 0)),
    ("D05", "RGB", False, [MODE[3], GET_OTHER, ITEM(3), PATTERN, NORMAL], (3, 3, 1, F, F, 3)),
    ("D06", "RGB", False, [QUICK], "q"),
    ("D07", "RGB", True, [MODE[0], CURRENT, PATTERN, NORMAL], (0, 4, 1, F, F, 0)),
    ("D08", "RGB", True, [MODE[0], CALC, PATTERN, CANCEL], (0, 0, 1, F, F, 0)),
    # Multipalette: Default and Error diffusion can't be chosen, so the clicks do nothing.
    ("D09", "RGB", False, [MODE[0], CALC, CLOSEST, MODE[3], DEFAULT, DIFFUSION, NORMAL], (3, 0, 0, F, F, 0)),
    ("D10", "RGB", False, [MODE[0], CALC, PATTERN, H_STEP(9), V_STEP(19), NORMAL], (0, 0, 1, 9, 19, 0)),
    # Stored palette and Other (before Get other...) are greyed out: those clicks do nothing.
    ("D12", "RGB", False, [MODE[1], CALC, STORED, OTHER, PATTERN, NORMAL], (1, 0, 1, F, F, 0)),
    ("D11", "BIG", True, [MODE[0], CALC, PATTERN, V_MORE, NORMAL], (0, 0, 1, 11, 12, 0)),
]

if __name__ == "__main__" and sys.argv[1:] == ["commands"]:
    for name, src, load, clicks, _ in RUNS:
        disk, local, fid = SOURCES[src]
        if load:
            print(f"LOAD AS {fid} *:{disk}")
        print("CLICKS " + " ".join(f"{v} {h}" for v, h in clicks))
        print("MENU 271")
        print(f"SAVE C1 *:MCOUT:{name}.C")
    print("SHOW")
