# Makes src/FilterData.s, data the True color dialogs take from SuperConvert 4.0 (see
# docs/superconvert-truecolor.md): the progress dialog's two apple pictures, empty and
# full (64 x 32 pixels, 640 mode, 16 bytes a row). Reads SuperConvert's data fork.
#   python3 test/make_filterdata.py <SuperConvert data fork>
import os, sys
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
d = open(sys.argv[1], "rb").read()
out = ["* FilterData.s - the progress dialog's apple pictures, from SuperConvert 4.0 (made by",
       "* test/make_filterdata.py): 64 x 32 pixels, 16 bytes a row."]
for label, off in (("AppleFull", 0x4EEA1), ("AppleEmpty", 0x4F0A1)):
    b = d[off:off + 512]
    out += ["", f"{label:<12s}=     *"] + ["            hex   " + b[i:i + 32].hex().upper() for i in range(0, 512, 32)]
open(os.path.join(ROOT, "src", "FilterData.s"), "w").write("\n".join(out) + "\n")
