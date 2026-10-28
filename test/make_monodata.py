# Makes src/MonoData.s, what the monochrome dialogs take from SuperConvert 4.0 (see
# docs/superconvert-truecolor.md 7.1 and 8.1): their pop-up menus, texts and the arrow
# icon, byte for byte. Reads SuperConvert's data fork.
#   python3 test/make_monodata.py <SuperConvert data fork>
import os, struct, sys
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
d = open(sys.argv[1], "rb").read()
FRED, OSAY = 0x228E4, 0x52D2B          # segments 6 and 9

def menu(off):          # Menu Manager text up to and including the "." line
    e = d.index(b"\r.", off) + 2
    return d[off:e] + b"\x00"
def pstr(off): return d[off:off + 1 + d[off]]
def raw(off, n): return d[off:off + n]

items = [
    ("PopHSize", menu(FRED + 0xC6EA), "ToMono: horizontal size pop-up"),
    ("PopVSize", menu(FRED + 0xC73F), "ToMono: vertical size pop-up"),
    ("PopMethod", menu(FRED + 0xC792), "ToMono: rendering method pop-up"),
    ("PopAspect", menu(FRED + 0x8592), "FromMono: aspect ratio pop-up"),
    ("PopScale", menu(FRED + 0x85F5), "FromMono: scaling pop-up"),
    ("PopShrink", menu(FRED + 0x864E), "FromMono: shrink as pop-up"),
    ("TxWillBe", raw(FRED + 0xC601, 28), "ToMono: the size text (28 characters, substitutions)"),
    ("TxResult", raw(FRED + 0x837B, 16), "FromMono: \"Resulting image:\""),
    ("TxPixels", raw(FRED + 0x83AB, 62), "FromMono: the sizes text (62 characters, substitutions)"),
    ("TxSkipMe", pstr(OSAY + 0x0F16), "the SKIP ME check box"),
    ("TxInfoOpt", pstr(FRED + 0xC6B5), "Info on options..."),
    ("TxOKm", pstr(OSAY + 0x0EF7), "OK"),
    ("TxCancelm", pstr(OSAY + 0x0EE8), "Cancel"),
    ("Tx320Mode", pstr(FRED + 0x843D), "FromMono to screen: radio 16"),
    ("Tx640Mode", pstr(FRED + 0x8470), "FromMono to screen: radio 17"),
    ("Tx320Pix", pstr(FRED + 0x84A3), "FromMono to true colour: radio 16"),
    ("Tx640Pix", pstr(FRED + 0x84DE), "FromMono to true colour: radio 17"),
]
out = ["* MonoData.s - the monochrome dialogs' menus, texts and arrow icon, from SuperConvert",
       "* 4.0 (made by test/make_monodata.py)."]
for label, b, what in items:
    out += ["", f"* {what}: {b[:60]!r}", f"{label:<12s}=     *"]
    for i in range(0, len(b), 24):
        out.append("            hex   " + b[i:i + 24].hex().upper())
for label, off, what in (("MIcScr", 0x4453, "screen image"), ("MIcTrue", 0x44AB, "true colour image"),
                         ("MIcMono", 0x456F, "monochrome image")):
    o = OSAY + off
    typ, size, h, w = struct.unpack_from("<HHHH", d, o)
    out += ["", f"* the {what} icon ({w * 2} x {h})", f"{label:<12s}=     *"]
    b = d[o:o + 8 + 2 * size]
    for i in range(0, len(b), 20):
        out.append("            hex   " + b[i:i + 20].hex().upper())
o = OSAY + 0x47C1
typ, size, h, w = struct.unpack_from("<HHHH", d, o)
out += ["", f"* the arrow between the icons ({w * 2} x {h})", "IcArrowR    =     *"]
b = d[o:o + 8 + 2 * size]
for i in range(0, len(b), 20):
    out.append("            hex   " + b[i:i + 20].hex().upper())
open(os.path.join(ROOT, "src", "MonoData.s"), "w").write("\n".join(out) + "\n")
print(len(out))
