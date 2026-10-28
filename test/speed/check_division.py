# Check 2: dividing a box sum by its pixel count without DivAvg.
#
# For every box size n that can occur with n <= 257 (so that 255 * n fits 16 bits) and
# every sum S = 0 .. 255*n (the sum of n channel values 0..255), this compares:
#   DivAvg   - the 65816 routine in RemapSeg.s, step by step (divisor * 128, 8 rounds)
#   floor    - S // n
#   shift    - S >> k, for n = 2^k
#   table    - a quotient table for n, built by counting (no division): q repeats n times
#   div8     - an 8-round restoring division with 16-bit registers (for larger n)
#   recip    - (S * m) >> k with m = ceil(2^k / n), the smallest k that is exact
# Box sizes above 257 keep today's 32-bit sums and DivAvg (they only happen when the
# output is a few pixels wide or tall: see check_spans.py).
import json, os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
ns = [n for n in json.load(open(os.path.join(HERE, "box_sizes.json")))["n"] if n <= 257]


def divavg(lo, hi, d):
    """DivAvg as written: (hi:lo) / Divisor when the answer is below 256."""
    if d == 1: return lo
    dd = (d << 7) & 0xFFFFFFFF          # DdHi:DdLo = divisor * 128
    v = (hi << 16) | lo
    q = 0
    for _ in range(8):
        q = (q << 1) & 0xFFFF
        if v >= dd:                      # SBC pair, carry set: no borrow
            v -= dd
            q += 1
        dd >>= 1
    return q


def div8_16(s, n):
    """The same 8 rounds, all in 16-bit registers (n <= 257: n*128 <= 32896, s < 65536)."""
    d = (n << 7) & 0xFFFF
    q = 0
    for _ in range(8):
        q <<= 1
        if s >= d:
            s -= d
            q |= 1
        d >>= 1
    return q


def table(n):
    t = []
    q = 0
    while len(t) < 255 * n + 1:
        t.extend([q] * n)
        q += 1
    return t[:255 * n + 1]


def smallest_recip(n, smax):
    k = max(1, smax.bit_length())
    while True:
        m = -(-(1 << k) // n)
        if all((s * m) >> k == s // n for s in range(smax + 1)):
            return k, m
        k += 1


if __name__ == "__main__":
    tot = bad = 0
    pow2 = tabs = d8 = 0
    tab_bytes_max = 0
    rec = []
    for n in ns:
        smax = 255 * n
        t = table(n) if n <= 64 else None
        k2 = n.bit_length() - 1
        is_pow2 = n & (n - 1) == 0
        for s in range(smax + 1):
            f = s // n
            if divavg(s & 0xFFFF, s >> 16, n) != f: bad += 1
            if is_pow2 and (s >> k2) != f: bad += 1
            if t is not None and t[s] != f: bad += 1
            if div8_16(s, n) != f: bad += 1
            tot += 1
        if is_pow2: pow2 += 1
        elif t is not None:
            tabs += 1
            tab_bytes_max = max(tab_bytes_max, smax + 1)
        else: d8 += 1
        if n in (3, 5, 6, 9, 12, 25, 63, 255):
            k, m = smallest_recip(n, smax)
            rec.append((n, smax.bit_length(), k, m, m.bit_length(), (smax * m).bit_length()))
    print(f"box sizes checked: {len(ns)} (n = 1..257 that occur), sums checked: {tot}, mismatches: {bad}")
    print(f"powers of two (shift): {pow2}; quotient tables (n <= 64): {tabs}, largest {tab_bytes_max} bytes; "
          f"8-round division (64 < n <= 257): {d8}")
    print("reciprocal multiply, smallest exact k:  n, sum bits, k, m, m bits, product bits")
    for r in rec: print("   ", r)
