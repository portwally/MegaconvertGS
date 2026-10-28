import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from optmodel import Opt, STEPS, K
from model import HZ
def run(src, mode, pal, alg, steps, s2t=False, quick=False):
    if quick: r = Opt(src, "q", 0, 0, 0, 0, 0, quick=True, with_s2t=s2t, steps=steps)
    else:
        r = Opt(src, mode, pal, alg, 255, 255, 0, screen_before=0, with_s2t=s2t, steps=steps)
        r.cur_screen_bytes = None
    r.run(); return K * r.cost.total() / HZ
plan = [()] + [tuple(STEPS[:k + 1]) for k in range(len(STEPS))]
print("case".ljust(40) + "".join(f"{s:>8s}" for s in ["now"] + STEPS))
for lab, a, extra in (("RGB8.PNG load (decode 26.3 s + remap)", ("RGB", 0, 0, 1), 26.3),
                      ("BIG.PNG load (decode 47.6 s + remap)", ("BIG", 0, 0, 1), 47.6),
                      ("HUGE.PNG load (decode ? + remap)", ("HUGE", 0, 0, 1), 0.0),
                      ("photo 320x200 Parrot, remap only", ("photo:Parrot", 0, 0, 1), 0.0),
                      ("photo 400x300 Parrot, remap only", ("photo:Parrot400", 0, 0, 1), 0.0),
                      ("photo Parrot to 640, remap only", ("photo:Parrot", 1, 0, 1), 0.0),
                      ("photo Parrot multipalette", ("photo:Parrot", 3, 0, 1), 0.0)):
    print(lab.ljust(40) + "".join(f"{extra + run(*a, st):8.1f}" for st in plan))
