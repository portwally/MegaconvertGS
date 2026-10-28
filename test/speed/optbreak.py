import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from optmodel import Opt, STEPS, K
from model import HZ
def run(src, mode, pal, alg, steps, s2t=False):
    r = Opt(src, mode, pal, alg, 255, 255, 0, screen_before=0, with_s2t=s2t, steps=steps)
    r.cur_screen_bytes = None
    r.run()
    return r
def line(title, rows):
    print(f"{title:44s}" + " ".join(f"{x:7.1f}" for x in rows))
plan = [()] + [tuple(STEPS[:k + 1]) for k in range(len(STEPS))]
print(f"{'case':44s}" + " ".join(f"{s:>7s}" for s in ["now"] + STEPS))
cases = [("photo Parrot 320x200 -> 320 calc pattern", "photo:Parrot", 0, 0, 1, False),
         ("photo Sunflower -> 320 calc pattern", "photo:Sunflower", 0, 0, 1, False),
         ("photo Zebra -> 320 calc pattern", "photo:Zebra", 0, 0, 1, False),
         ("photo Parrot -> 640 calc pattern", "photo:Parrot", 1, 0, 1, False),
         ("photo Parrot 400x300 default (fitted)", "photo:Parrot400", 0, 0, 1, False),
         ("BIG.PNG 400x300 default (fitted)", "BIG", 0, 0, 1, False),
         ("HUGE.PNG 700x500 default (fitted)", "HUGE", 0, 0, 1, False),
         ("photo Parrot multipalette standard", "photo:Parrot", 3, 0, 1, False)]
final = {}
for title, src, mode, pal, alg, s2t in cases:
    rows = []
    for st in plan:
        r = run(src, mode, pal, alg, st, s2t)
        rows.append(K * r.cost.total() / HZ)
    final[title] = r
    line(title, rows)
print()
for title in ("photo Parrot 320x200 -> 320 calc pattern", "photo Parrot 400x300 default (fitted)",
              "photo Parrot multipalette standard"):
    r = final[title]; tot = r.cost.total()
    print(title, "after all steps:", round(K * tot / HZ, 1), "s")
    for k, v in sorted(r.cost.c.items(), key=lambda kv: -kv[1])[:9]:
        print(f"   {k:28s} {K * v / HZ:6.2f} s {100 * v / tot:5.1f} %")
    print("   Best calls", r.stats["best_calls"], "candidates scored", r.stats["best_cands"],
          "per call", round(r.stats["best_cands"] / max(1, r.stats["best_calls"]), 1))
