# Makes src/FilterTabs.s, the tables that let the Filter segment's integer arithmetic give
# exactly what GS Remap's filters give with floating point (Filters.swift):
#  - Increase/Decrease contrast: GS Remap scales each pixel by table[top] * 255 / top
#    (top = its largest channel; table from a sine curve) and rounds. For each top, a
#    multiplier K with (c * K + $8000) >> 16 equal to that for every channel c <= top.
#  - Find edges: GS Remap rounds (Double(100 - f) / 20 + 1.5) * (n4 - s / 4); the exact
#    value is (130 - f) * d / 80 (d = 4 * n4 - s), and where the floating point product
#    falls just below a half, GS Remap rounds down. Those cases (factor, d) are listed.
# The sine comes from the same system library GS Remap uses (run this on the Mac).
# python3 test/make_filter_tables.py
import math, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

def swift_round(x):           # Swift's .rounded(): to nearest, halves away from zero
    return math.floor(x + 0.5) if x >= 0 else -math.floor(-x + 0.5)

def contrast_table(increase):
    t = []
    for v in range(256):
        x = v / 255
        curve = (math.sin(math.pi * (x - 0.5)) + 1) / 2
        t.append(min(1, max(0, x + (0.5 if increase else -0.5) * (curve - x))))
    return t

def multipliers(increase):
    T = contrast_table(increase)
    assert swift_round(T[0] * 255) == 0        # a black pixel stays black
    ks = [0]
    for top in range(1, 256):
        scale = T[top] * 255 / top
        lo, hi = 0, 1 << 32
        for c in range(1, top + 1):
            w = min(255, swift_round(c * scale))
            if w == 255:                       # (the code keeps results to 255)
                lo = max(lo, math.ceil(254.5 * 65536 / c))
                continue
            lo = max(lo, math.ceil((w - 0.5) * 65536 / c))
            hi = min(hi, math.ceil((w + 0.5) * 65536 / c) - 1)
        assert lo <= hi, top
        k = lo
        for c in range(top + 1):               # check, as the code computes it
            want = min(255, swift_round(c * scale))
            assert min(255, (c * k + 0x8000) >> 16) == want, (top, c)
        ks.append(k)
    return ks

def edge_exceptions():
    out = []
    for f in range(100):
        gain = (100 - f) / 20 + 1.5
        for d in range(1, 1021):
            num = (130 - f) * d
            exact = num // 80 + (1 if 2 * (num % 80) >= 80 else 0)
            got = swift_round(gain * (d / 4))
            if min(255, got) != min(255, exact):
                assert got == exact - 1, (f, d)
                out.append((f, d))
    return out

lines = ["* FilterTabs.s - tables for the Filter segment (made by test/make_filter_tables.py).", "",
         "* Contrast: for each largest channel value (top), the multiplier K: a channel c",
         "* becomes (c * K + $8000) >> 16 (at most 255).", ""]
for name, inc in (("KMore", True), ("KLess", False)):
    ks = multipliers(inc)
    lines.append(f"{name:<12s}=     *")
    for i in range(0, 256, 8):
        lines.append("            adrl  " + ",".join(f"${k:06X}" for k in ks[i:i + 8]))
lines += ["", "* Find edges: the factors and differences d where the result is one less than",
          "* (130 - factor) * d / 80 rounded (a factor byte, a d word; $FF ends).", "EdgeEx      =     *"]
for f, d in edge_exceptions():
    lines.append(f"            db    {f}")
    lines.append(f"            dw    {d}")
lines.append("            db    $FF")
open(os.path.join(ROOT, "src", "FilterTabs.s"), "w").write("\n".join(lines) + "\n")
print(len(lines), "lines")
