# Box sizes n (pixels per output pixel) each remap meets, to choose tests covering every
# division method: 1, power of two (shift), n <= 64 (table), 64 < n <= 257 (8 rounds), > 257 (as today).
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from model import Remap
def kind(n):
    if n == 1: return "1"
    if n & (n - 1) == 0: return "shift"
    if n <= 64: return "table"
    if n <= 257: return "8 rounds"
    return "as today"
def boxes(src, mode, hs, vs):
    r = Remap(src, mode, 0, 1, hs, vs, 0, screen_before=0)
    r.cur_screen_bytes = None
    if hs == 255: r.fit()
    r.normalise(); r.get_proto(); r.sizes()
    xs = r.spans(r.srcw, r.spanw, r.outw); ys = r.spans(r.srch, r.spanh, r.outh)
    lx = {b - a for a, b in xs}; ly = {b - a for a, b in ys}
    ns = sorted({a * b for a in lx for b in ly})
    return r.outw, r.outh, ns
print("in the suites today:")
for lab, a in (("R01 RGB fitted", ("RGB", 0, 255, 255)), ("R09 RGB 640", ("RGB", 1, 255, 255)),
               ("R20 BIG 19/9", ("BIG", 0, 19, 9)), ("R21 BIG 9/14", ("BIG", 0, 9, 14)),
               ("R23 S64 320", ("S64", 0, 255, 255)), ("R27 TNY 14/14", ("TNY", 0, 14, 14)),
               ("BIG.PNG load", ("BIG", 0, 255, 255)), ("HUGE.PNG load", ("HUGE", 0, 255, 255))):
    w, h, ns = boxes(*a)
    print(f"   {lab:16s} {w}x{h}  n = {ns}  -> {sorted({kind(n) for n in ns})}")
print("candidates for new REMAP WITH lines (BIG.PNG 400x300, HUGE.PNG 700x500):")
for src in ("BIG", "HUGE"):
    for hs, vs in ((0, 0), (1, 1), (2, 2), (3, 3), (4, 4), (2, 5), (0, 3)):
        w, h, ns = boxes(src, 0, hs, vs)
        print(f"   {src} steps {hs}/{vs}: {w}x{h} n = {ns} -> {sorted({kind(n) for n in ns})}")
