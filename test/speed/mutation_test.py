# The checks must fail when the fast version is wrong: a few deliberate errors.
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import check_division as cd, check_calcpal as cc, check_best as cb, check_spans as cs
from model import dist

# division: a table off by one at one entry, and a reciprocal one bit too short
t = cd.table(9); t[100] += 1
print("bad quotient table caught:", sum(1 for s in range(255 * 9 + 1) if t[s] != s // 9))
k, m = 11, -(-(1 << 11) // 9)
print("too-short reciprocal for n=9 caught:", sum(1 for s in range(255 * 9 + 1) if (s * m) >> k != s // 9))
# spans: the walk without the carry
def dda_nocarry(src, out, n):
    qd, rd = divmod(src, out); r = []; a = 0; b = qd
    for i in range(n):
        bb = b + 1 if b == a else b
        r.append((a, min(bb, src))); a = b; b += qd
    return r
print("span walk without carry caught:", sum(1 for (s, o, n) in [(400, 266, 266), (700, 280, 280), (300, 200, 200)]
                                          if dda_nocarry(s, o, n) != cs.spans_ref(s, o, n)))
# calcpal: Dist without the |a+b+c|/4 term, bias without the carry, mul/div with a wrong table entry
print("Dist without the last term caught:", sum(1 for c1 in range(0, 4096, 7) for c2 in range(0, 4096, 5)
                                               if cc.R3 and (abs(3*(((c1>>8)&15)-((c2>>8)&15)))+abs(4*(((c1>>4)&15)-((c2>>4)&15)))+abs(2*((c1&15)-(c2&15)))) != dist(c1, c2)) > 0)
cc.T50[7][13] += 1
print("bad T50 entry caught:", sum(1 for count in range(65536) for d in (13,) if cc.mul_div50(count, d) != count * d // 50) > 0)
cc.T50[7][13] -= 1
# best: ties to the lower index instead of the higher
def best_lowtie(c, r, g, b):
    bi, bs = 0, 0x7D00
    for i in range(len(c)):
        ar, ag, ab, pen, _ = c[i]
        if pen < 0: continue
        s = 3*abs(ar-r) + 4*abs(ag-g) + 2*abs(ab-b) + (pen >> 4)
        if s < bs: bs, bi = s, i
    return bi
from model import DefProtos, INT
c = cb.build([e & 0xFFF for e in DefProtos[0][:16]], True)
print("ties to the lower index caught:", sum(1 for col in range(4096)
      if best_lowtie(c, INT[col>>8], INT[(col>>4)&15], INT[col&15]) != cb.best_ref(c, INT[col>>8], INT[(col>>4)&15], INT[col&15])) > 0)
