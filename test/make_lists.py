# Makes src/DeskLists.s, the Load formats and Save formats lists (Merlin source), from
# SuperConvert's lists (docs/superconvert-ui-data.json): its computer types, each type's
# formats and its save formats, in its order and with its names, and the icons it draws
# in the lists. Each entry gives the MegaconvertGS format or save number that does the
# work (numbers past the last format, fmtCount - 1, or the last save, 12, aren't
# implemented yet) and its icon: what kind of picture it makes (1 screen, 2 true color,
# 3 both, 4 monochrome), as MegaconvertGS makes it.
# python3 test/make_lists.py
import json, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = json.load(open(os.path.join(ROOT, "docs", "superconvert-ui-data.json")))

S, C, SC, M = 1, 2, 3, 4      # icons: screen, true color, both, monochrome
# Not implemented yet: the Babelfish imports 53 and 54; saves: the Babelfish exports 14
# and 15. New Print Shop graphics (51) is left out of the list altogether (DROPPED): no
# description of its Apple II files exists, and SuperConvert never loaded it either.
TYPES = [
    ("Apple II family", [("fmtHGRBW", S), ("fmtHGR", S), ("fmtDHRBW", S), ("fmtDHR", S),
        ("fmtPSBW", S), ("51", S), ("fmtTScan", C), ("52", M), ("fmtTDM40", S), ("fmtTDM80", S)]),
    ("Apple IIgs specific", [("0", S), ("fmtC1", S), ("fmtDG", S), ("fmtDG3200", C), ("fmtPWGold", S),
        ("fmtPSGS", S), ("fmtCGT", S), ("fmtIcon", S), ("fmtAST", C), ("fmtCEyes", C), ("fmt3200", C),
        ("fmt3200C", C)]),
    # (high resolution Atari pictures become true color pictures here, monochrome
    # images in SuperConvert)
    ("Atari ST", [("fmtDegas", SC), ("fmtDegasE", SC), ("fmtNeo", SC), ("fmtTiny", SC), ("fmtSPU", C),
        ("fmtSPC", C)]),
    ("Amiga", [("fmtIFF", C)]),
    ("Commodore 64/128", [("fmtDoodle", S), ("fmtKoala", S), ("fmtC64PS", S)]),
    ("Macintosh", [("fmtMac640", S), ("fmtMac320", S), ("fmtMacMono", C), ("fmtMacSM", C)]),
    ("IBM PC & compatibles", [("fmtBMP", C), ("fmtGEM", C), ("fmtPCX", C), ("fmtIFF", C), ("fmtFli", C)]),
    ("Unix machines", [("fmtSun", C), ("fmtSGI", C), ("fmtPNM", C)]),
    ("Computer-independent", [("fmtJPEG", C), ("fmtGIF", C), ("fmtPNG", C), ("fmtRLE", S), ("fmtIPI", C),
        ("fmtIPI", C), ("fmtQRT", C)]),
    ("External (Babelfish™)", [("53", C), ("54", S)]),
]
# MegaconvertGS's own: TIFF, TGA and PICT to load (their file filters: types $06 or
# $04, or none, at least 8, 18 or 10 bytes).
EXTRA_FORMATS = {"Commodore 64/128": [("fmtArtSt", S, "Art Studio (OCP)"),
                                      ("fmtAAS", S, "Advanced Art Studio (OCP)")],
                 "Computer-independent": [("fmtTIFF", C, "TIFF (Tagged Image File Format)"),
                                          ("fmtTGA", C, "Truevision Targa (.TGA)")],
                 "Macintosh": [("fmtPICT", C, "QuickDraw picture (PICT)")]}
EXTRA_FILTERS = {"fmtTIFF": bytes.fromhex("000000000000060400000000080000000000ff000000ffff"),
                 "fmtTGA": bytes.fromhex("000000000000060400000000120000000000ff000000ffff"),
                 "fmtPICT": bytes.fromhex("0000000000000604000000000a0000000000ff000000ffff")}
# Names changed: the PCX loader is tested, so no question marks.
RENAMED = {"PC Paintbrush (.PCX, .PCC) ???": "PC Paintbrush (.PCX, .PCC)"}
# Save numbers in SuperConvert's order; "Icon resource (HyperCard, etc.)" adds to a file.
SAVES = [4, 3, 2, 1, 5, 6, 8, 13, 9, 10, 11, 12, 14, 15]
DROPPED = {"51"}
# MegaconvertGS's own computer types (Amstrad CPC, MSX, ZX Spectrum), after Unix machines (so the rows above stay where
# they were): their formats and file filters (types $06 or $04, or none; EOF 6144-6912
# for the Spectrum, 8 or more for a BSAVE file).
EXTRA_TYPES = [("Amstrad CPC", [("fmtCPC0", S, "Mode 0 screen (.SCR)"), ("fmtCPC1", S, "Mode 1 screen (.SCR)"),
                                ("fmtCPC2", S, "Mode 2 screen (.SCR)")]),
               ("MSX", [("fmtMS2", S, "Screen 2 (.SC2)"), ("fmtMS5", C, "Screen 5 (.SC5, .GE5)"),
                        ("fmtMS7", C, "Screen 7 (.SC7)"), ("fmtMS8", C, "Screen 8 (.SC8)")]),
               ("ZX Spectrum", [("fmtZX", S, "Screen (.SCR)")])]
EXTRA_TYPE_AFTER = "Unix machines"
for fmt in ("fmtMS2", "fmtMS5", "fmtMS7", "fmtMS8"):
    EXTRA_FILTERS[fmt] = bytes.fromhex("000000000000060400000000" + "08000000" + "06000100" + "0000ffff")
for fmt in ("fmtCPC0", "fmtCPC1", "fmtCPC2"):
    EXTRA_FILTERS[fmt] = bytes.fromhex("000000000000060400000000" + "d03f0000" + "00000100" + "0000ffff")
EXTRA_FILTERS["fmtArtSt"] = bytes.fromhex("000000000000060400000000" + "31230000" + "31230000" + "0000ffff")
EXTRA_FILTERS["fmtAAS"] = bytes.fromhex("000000000000060400000000" + "22270000" + "22270000" + "0000ffff")
EXTRA_FILTERS["fmtZX"] = bytes.fromhex("000000000000060400000000" + "00180000" + "001b0000" + "0000ffff")
EXTRA_SAVES = [(7, "Icon resource (new file)"), (16, "BMP (Windows bitmap)")]

types = DATA["computerTypes"]
assert [t["name"] for t in types] == [n for n, _ in TYPES], "computer types differ"
lists = []
filters = []                  # for each list: each format's record bytes and type list
for (name, ours), t in zip(TYPES, types):
    assert len(ours) == len(t["formats"]), name
    fmts = [(code, icon, RENAMED.get(f["name"], f["name"])) for (code, icon), f in zip(ours, t["formats"])]
    keep = [k for k, (code, _, _) in enumerate(fmts) if code not in DROPPED]
    lists.append((name, [fmts[k] for k in keep] + EXTRA_FORMATS.get(name, [])))
    filters.append([(bytes.fromhex(t["formats"][k]["rawHex"]), t["formats"][k].get("fileTypeList")) for k in keep] +
                   [(EXTRA_FILTERS[code], None) for code, _, _ in EXTRA_FORMATS.get(name, [])])
at = [n for n, _ in lists].index(EXTRA_TYPE_AFTER) + 1
for k, (name, fmts) in enumerate(EXTRA_TYPES):
    lists.insert(at + k, (name, fmts))
    filters.insert(at + k, [(EXTRA_FILTERS[code], None) for code, _, _ in fmts])
saves = [(code, s["name"]) for code, s in zip(SAVES, DATA["saveFormats"])] + EXTRA_SAVES
assert len(SAVES) == len(DATA["saveFormats"])

def asc(text):
    """Merlin asc operand: quoted runs, $27 for an apostrophe, $AA for the trademark sign."""
    parts, cur = [], ""
    for ch in text:
        code = {"'": "27", "™": "AA"}.get(ch)
        if code:
            if cur: parts.append("'" + cur + "'"); cur = ""
            parts.append(code)
        else:
            cur += ch
    if cur: parts.append("'" + cur + "'")
    return ",".join(parts)

def pstr(label, text):
    return f"{label:<12s}dfb   {len(text)}\n            asc   " + asc(text)

out = ["* DeskLists.s - the Load formats and Save formats lists, as SuperConvert's (made by",
       "* test/make_lists.py). Members: name (Pascal string), flags (bit 7: chosen), a spare",
       "* byte, the format or save number, the icon (0 folder; else what kind of picture: 1",
       "* screen, 2 true color, 3 both, 4 monochrome), and for a load format its file filter",
       "* (Load & convert's file dialog: docs/superconvert-file.md 3.4): 12 bytes each.", ""]
out.append("NTypes      =     %d" % len(lists))
out.append("TypeMems    =     *")
for i, (name, fmts) in enumerate(lists):
    flag = "$80" if i == 1 else "0"
    out.append(f"            adrl  TyName{i}\n            db    {flag},0\n            dw    {i},0,0")
out.append("* Each type's formats: where its members are, how many.")
out.append("TypeFmts    da    " + ",".join(f"FmMems{i}" for i in range(len(lists))))
out.append("TypeCount   dw    " + ",".join(str(len(f)) for _, f in lists))
for i, (name, fmts) in enumerate(lists):
    out.append(f"FmMems{i}     =     *")
    for j, (code, icon, fname) in enumerate(fmts):
        flag = "$80" if j == 0 else "0"
        out.append(f"            adrl  FmName{i}x{j}\n            db    {flag},0\n            dw    {code},{icon},Filt{i}x{j}")
out.append("NSaves      =     %d" % len(saves))
out.append("SaveMems    =     *")
for j, (code, name) in enumerate(saves):
    flag = "$80" if code == 2 else "0"
    out.append(f"            adrl  SvName{j}\n            db    {flag},0\n            dw    {code},1,0")
for i, (name, fmts) in enumerate(lists):
    out.append(pstr(f"TyName{i}", name))
    for j, (code, icon, fname) in enumerate(fmts):
        out.append(pstr(f"FmName{i}x{j}", fname))
for j, (code, name) in enumerate(saves):
    out.append(pstr(f"SvName{j}", name))
# The file filters: the file types (type A, type B; $FFFF: the list whose address follows),
# aux types and EOFs a file of the format may have; a list: 18-byte entries (file type, aux
# min, aux max, EOF min, EOF max), ending with $FFFF.
out.append("* File filters: types (A, B; $FFFF: a list), aux min, max, EOF min, max.")
for i, fl in enumerate(filters):
    for j, (raw, tlist) in enumerate(fl):
        types = raw[6] | raw[7] << 8
        if types == 0xFFFF:
            out.append(f"Filt{i}x{j:<6d}dw    $FFFF\n            da    FList{i}x{j}")
            out.append(f"FList{i}x{j}   =     *")
            for e in tlist["entries"]:
                v = lambda k: int(e[k].strip("$"), 16)
                out.append(f"            dw    ${v('fileType'):02X}\n            adrl  ${v('auxMin'):X},${v('auxMax'):X},"
                           f"${v('eofMin'):X},${v('eofMax'):X}")
            out.append("            dw    $FFFF")
        else:
            w = lambda k: raw[k] | raw[k + 1] << 8
            l = lambda k: w(k) | w(k + 2) << 16
            out.append(f"Filt{i}x{j:<6d}dw    ${types:04X},${w(20):04X},${w(22):04X}\n            adrl  ${l(12):X},${l(16):X}")

# The list icons, SuperConvert's (QuickDraw II Auxiliary icon records: type, size of the
# image, height, width, the image, its mask), by icon number; 8 is the open folder of the
# chosen computer type. IconTextX: how far the name starts from the icon's place.
icons = DATA["listIcons"]["icons"]
assert [ic["index"] for ic in icons] == list(range(9))
out.append("* The icons (SuperConvert's), by number; 8: the chosen type's open folder.")
out.append("ListIcons   da    " + ",".join(f"ListIcon{i}" for i in range(9)))
out.append("IconTextX   dw    " + ",".join(str(ic["textOffsetWidth"] + 10) for ic in icons))
for ic in icons:
    raw = bytes.fromhex(ic["rawHex"].replace(" ", ""))
    out.append(f"ListIcon{ic['index']}   =     *                     ; {ic['meaning']}")
    for k in range(0, len(raw), 20):
        out.append("            hex   " + raw[k:k + 20].hex().upper())
open(os.path.join(ROOT, "src", "DeskLists.s"), "w").write("\n".join(out) + "\n")
print(len(out), "lines")
