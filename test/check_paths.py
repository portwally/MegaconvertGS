# Checks the file dialog folders test (test/paths.sh) from its log: the folder each dialog
# was left in is kept for the next load or save, Exchange load/save paths swaps them, and
# the save went to the save folder (MCOUT).
import os, sys
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
res = os.path.join(root, "build", "test", "results")
vol = sys.argv[1]
log = [l.split(", format")[0] for l in open(os.path.join(res, "MC.LOG#040000"), "rb").read().decode().split("\r") if l]
cmds = [l.replace(":VOL:", vol) for l in open(os.path.join(root, "test", "paths.test")).read().split("\n") if l]
T, O = vol + "MCTEST:", vol + "MCOUT:"
paths = iter([("", ""), (T, ""), (T, O), (T, O), (O, T), (O, T)])
want = [c + (": load %s, save %s" % next(paths) if c == "PATHS" else ": ok") for c in cmds]
ok = True
labels = {3: "Open starts in prefix 8 (none kept yet)", 6: "Save starts in prefix 8 (none kept yet)",
          8: "Open starts in the load folder again", 10: "Exchange load/save paths",
          12: "Open starts in the old save folder"}
for i in sorted(labels):
    good = log[i - 1:i + 2] == want[i - 1:i + 2]
    print(f"{labels[i]:46s} {'OK' if good else 'FAIL: ' + repr(log[i - 1:i + 2])}")
    ok &= good
saved = [f for f in os.listdir(os.path.join(res, "MCOUT")) if f.startswith("S320.")]   # (the first
# file in MCTEST, which Return opened, under the name offered)
print(f"{'Save wrote to the save folder (MCOUT)':46s} {'OK' if saved else 'FAIL: ' + repr(os.listdir(os.path.join(res, 'MCOUT')))}")
ok &= bool(saved)
sys.exit(0 if ok else 1)
