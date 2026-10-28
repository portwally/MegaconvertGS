# Where the time goes: the model's stages for the typical cases.
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from model import Remap, HZ, suite
K = 1.05   # the one allowance that matches the measured suite (interrupts, refresh)

def show(title, r, measured=None):
    tot = r.cost.total()
    print(f"\n{title}: model {K * tot / HZ:.1f} s" + (f" (measured {measured} s)" if measured else "")
          + f", output {r.outw}x{r.outh}, lookups {r.stats['lookups']}, distinct {r.stats['distinct']}")
    for k, v in sorted(r.cost.c.items(), key=lambda kv: -kv[1]):
        print(f"   {k:28s} {K * v / HZ:6.2f} s  {100 * v / tot:5.1f} %   {v / 1e6:7.2f} Mcycles")
    st = dict(r.stats)
    print("   stats:", {k: st[k] for k in sorted(st)})

if __name__ == "__main__":
    res = {name: (secs, r) for name, src, mode, pal, alg, secs, r in suite()}
    for n in ("R01", "R04", "R05", "R09", "R11", "R13", "R17", "R20", "R22", "R23", "R24", "Q03"):
        show(n, res[n][1], res[n][0])
    r = Remap("BIG", 0, 0, 1, 255, 255, 0, screen_before=0); r.cur_screen_bytes = None; r.run()
    show("BIG.PNG default remap (fitted 266x200)", r)
    r = Remap("HUGE", 0, 0, 1, 255, 255, 0, screen_before=0); r.cur_screen_bytes = None; r.run()
    show("HUGE.PNG default remap", r)
    for ph in ("Parrot", "Sunflower", "Zebra", "Earth"):
        r = Remap("photo:" + ph, 0, 0, 1, 255, 255, 0, screen_before=0); r.cur_screen_bytes = None; r.run()
        show(f"photo {ph} 320x200 -> 320, calculated, pattern", r)
    r = Remap("photo:Parrot", 1, 0, 1, 255, 255, 0, screen_before=0); r.cur_screen_bytes = None; r.run()
    show("photo Parrot -> 640, calculated, pattern", r)
    r = Remap("photo:Parrot400", 0, 0, 1, 255, 255, 0, screen_before=0); r.cur_screen_bytes = None; r.run()
    show("photo Parrot 400x300 default remap", r)
    r = Remap("photo:Parrot", 3, 0, 1, 255, 255, 0, screen_before=0); r.cur_screen_bytes = None; r.run()
    show("photo Parrot multipalette standard", r)
