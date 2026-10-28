# Checks the Remap dialog test (test/dialog.sh): each screen remapped through the dialog
# against GS Remap's remap with the options the clicks chose (test/sc4save's sc4remap).
import os, sys, subprocess
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from dialog_list import SOURCES, RUNS
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
res = os.path.join(root, "build", "test", "results")
work = os.path.join(root, "build", "test", "expected", "dialog")
os.makedirs(work, exist_ok=True)
tool = os.path.join(root, "test", "sc4save", ".build", "release", "sc4remap")
log = open(os.path.join(res, "MC.LOG#040000"), "rb").read().decode().split("\r")
menus = [l for l in log if l.startswith("MENU 271")]
ok = True
for k, (name, src, load, clicks, want_opts) in enumerate(RUNS):
    disk, local, fid = SOURCES[src]
    ref = os.path.join(work, name + ".c1")
    args = ["q"] if want_opts == "q" else [str(o) for o in want_opts]
    r = subprocess.run([tool, os.path.join(root, local), fid, ref] + args, capture_output=True, text=True)
    got = None
    for f in os.listdir(os.path.join(res, "MCOUT")):
        if f.split("#")[0] == name + ".C": got = open(os.path.join(res, "MCOUT", f), "rb").read()
    problems = []
    if r.returncode: problems.append("reference: " + r.stderr.strip())
    elif got is None: problems.append(f"no result ({menus[k] if k < len(menus) else 'not run'})")
    else:
        want = open(ref, "rb").read()
        bad = sum(1 for a, b in zip(got[:32000], want[:32000]) if a != b)
        if bad: problems.append(f"{bad} pixel bytes differ")
        if got[32000:32200] != want[32000:32200]: problems.append("line modes differ")
        for t in sorted({b & 15 for b in want[32000:32200]}):
            if got[32256 + t * 32:32288 + t * 32] != want[32256 + t * 32:32288 + t * 32]:
                problems.append(f"colour table {t} differs")
    label = f"{name} {src} {'quick remap' if want_opts == 'q' else ' '.join(args)}"
    print(f"{label:34s} {'OK' if not problems else 'FAIL: ' + '; '.join(problems)}")
    ok &= not problems
sys.exit(0 if ok else 1)
