# Load & convert's file filter test (test/loadconv.sh): for each format chosen in Load
# formats (computer type, format, both from 0), a test folder whose files the filter rates;
# the filter's model, written from docs/superconvert-file.md 3.4 and the format records in
# docs/superconvert-ui-data.json. Prints the test commands with "commands" (VOL: the
# volume name, :NAME:).
import json, os, sys
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
F = os.path.join(ROOT, "build", "fixtures")
CASES = [  # computer type, format, folder
    (1, 0, "MCTEST"), (1, 1, "MCTEST"), (1, 1, "MCAPPLE"), (1, 4, "MCTEST"), (0, 0, "MCAPPLE"),
    (0, 1, "MCAPPLE"), (0, 3, "MCAPPLE"), (1, 7, "MCAPPLE"), (1, 5, "MCAPPLE"), (11, 0, "MCTRUE"),
    (11, 1, "MCTRUE"), (11, 2, "MCOTHER"), (2, 0, "MCOTHER"), (2, 2, "MCOTHER"), (6, 0, "MCOTHER"),
    (5, 0, "MCOTHER"), (4, 1, "MCOTHER"), (11, 7, "MCOTHER"),
]
# Load formats' computer types are SuperConvert's with MegaconvertGS's Amstrad CPC, MSX and
# ZX Spectrum after Unix machines (8-10): the place of each in SuperConvert's list.
SC_TYPE = {0: 0, 1: 1, 2: 2, 3: 3, 4: 4, 5: 5, 6: 6, 7: 7, 11: 8, 12: 9}

def folder(name):
    """The folder's files in the order they were added: (NAME, type, aux, eof)."""
    out = []
    if name == "MCTEST":
        for ext, t in (("c1", "C10000"), ("apf", "C00002"), ("packed", "C00001"), ("pw", "C00000")):
            for f in sorted(os.listdir(F)):
                if f.startswith("S") and f.endswith("." + ext):
                    e = {"c1": "C1", "apf": "APF", "packed": "PACK", "pw": "PW"}[ext]
                    out.append((f.rsplit(".", 1)[0].upper() + "." + e, t, os.path.getsize(os.path.join(F, f))))
    elif name == "MCTRUE":
        for f in sorted(os.listdir(os.path.join(F, "true"))):
            out.append((f.upper(), "060000", os.path.getsize(os.path.join(F, "true", f))))
    else:
        g = name[2:].lower()
        for line in open(os.path.join(F, g + ".types")):
            if line.strip():
                n, t = line.split()
                out.append((n.upper(), t, os.path.getsize(os.path.join(F, g, n))))
    return [(n, int(t[:2], 16), int(t[2:], 16), eof) for n, t, eof in out]

def rate(fmt, ftype, aux, eof):
    """docs/superconvert-file.md 3.4 (no "any type"): 1 dimmed, 2 can be chosen."""
    raw = bytes.fromhex(fmt["rawHex"])
    types = raw[6] | raw[7] << 8
    w = lambda k: raw[k] | raw[k + 1] << 8
    l = lambda k: w(k) | w(k + 2) << 16
    if types == 0xFFFF:
        if ftype == 0x0F: return 2
        for e in fmt["fileTypeList"]["entries"]:
            v = lambda k: int(e[k].strip("$"), 16)
            if v("fileType") != ftype: continue
            lo, hi = lambda x: x & 0xFFFF, lambda x: x >> 16
            if (hi(aux) >= hi(v("auxMin")) and lo(aux) >= lo(v("auxMin")) and hi(aux) <= hi(v("auxMax")) and
                    lo(aux) <= lo(v("auxMax")) and hi(eof) >= hi(v("eofMin")) and lo(eof) >= lo(v("eofMin")) and
                    hi(eof) <= hi(v("eofMax")) and lo(eof) <= lo(v("eofMax"))):
                return 2
        return 1
    if ftype in (raw[6], raw[7]) or (ftype == 0 and types in (0x0406, 0x0604)):
        if eof < l(12) or eof > l(16): return 1
        if (aux & 0xFFFF) < w(20) or (aux & 0xFFFF) > w(22): return 1
        return 2
    return 2 if ftype == 0x0F else 1

def expected(t, f, name):
    fmts = json.load(open(os.path.join(ROOT, "docs", "superconvert-ui-data.json")))["computerTypes"][SC_TYPE[t]]["formats"]
    # (past SuperConvert's formats: MegaconvertGS's TIFF, with make_lists.py's filter)
    fmt = fmts[f] if f < len(fmts) else {"name": "TIFF (Tagged Image File Format)",
                                         "rawHex": "000000000000060400000000080000000000ff000000ffff" + "00" * 8}
    files = [n for n, ftype, aux, eof in folder(name) if rate(fmt, ftype, aux, eof) == 2]
    return fmt["name"], "ok " + " ".join([str(len(files))] + files)

if __name__ == "__main__" and sys.argv[1:2] == ["commands"]:
    vol = sys.argv[2]
    print(f"PREFIX {vol}MCTEST:")
    print("MENU 280")
    print("IMAGES")
    print("SAVE C1 *:MCOUT:DLG.C")
    for t, f, name in CASES:
        print(f"PICK {t} {f}")
        print(f"QUEUE 15 {vol}{name}:")
        print("QUEUED")
        print("MENU 283")
    print("PICK 1 0")
    print(f"QUEUE 15 {vol}MCTEST:")
    print("QUEUED")
    print("MENU 282")
    print("SAVE C1 *:MCOUT:Q1.C")
    print("QUEUED")
    print("MENU 282")
    print("SAVE C1 *:MCOUT:Q2.C")
    print("QUEUED")
    print("MENU 283")
    print("QUEUED")
    print("SHOW")
