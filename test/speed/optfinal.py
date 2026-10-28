import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from optmodel import Opt, STEPS, K
from model import HZ
def run(src, mode, pal, alg, steps, s2t=False, quick=False):
    if quick: r = Opt(src, "q", 0, 0, 0, 0, 0, quick=True, with_s2t=s2t, steps=steps)
    else:
        r = Opt(src, mode, pal, alg, 255, 255, 0, screen_before=0, with_s2t=s2t, steps=steps)
        r.cur_screen_bytes = None
    r.run(); return r
for title, a in (("R01 RGB 320 calc pattern", ("RGB", 0, 0, 1)), ("R09 RGB 640 calc pattern", ("RGB", 1, 0, 1)),
                 ("R04 RGB 320 greys diffusion", ("RGB", 0, 2, 2)),
                 ("R23 S64 320 calc pattern (with ScreenToTrue)", ("S64", 0, 0, 1, True)),
                 ("Q03 S64 quick (with ScreenToTrue)", ("S64", 0, 0, 0, True, True)),
                 ("HUGE.PNG default", ("HUGE", 0, 0, 1))):
    for steps, lab in (((), "now"), (tuple(STEPS[:6]), "steps 1-6"), (tuple(STEPS), "all")):
        r = run(*a[:4], steps, *a[4:])
        tot = r.cost.total()
        print(f"{title} [{lab}] {K*tot/HZ:.1f} s: " + ", ".join(f"{k} {K*v/HZ:.2f}" for k, v in sorted(r.cost.c.items(), key=lambda kv: -kv[1]) if v > 0.01 * tot))
