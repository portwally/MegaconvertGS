# Checks the main windows test (test/desk.sh): every click was taken, the Windows bitmap
# format loaded SUNSET (a 24-bit BMP), and Save... saved it as OUT, a $C1 screen, as
# GS Remap saves the same picture.
import os, sys, subprocess
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
res = os.path.join(root, "build", "test", "results")
work = os.path.join(root, "build", "test", "expected")
os.makedirs(work, exist_ok=True)
log = open(os.path.join(res, "MC.LOG#040000"), "rb").read().decode().split("\r")
want = [l + ": ok" for l in open(os.path.join(root, "test", "desk.test")).read().split("\n") if l]
ok = log[:len(want)] == want
print(f"{'commands':40s} {'OK' if ok else 'FAIL: ' + repr(log)}")
saved = [f for f in os.listdir(res) if f.split("#")[0] == "OUT"]
if not saved:
    print(f"{'OUT saved as a $C1 screen':40s} FAIL: no file"); sys.exit(1)
ref = os.path.join(work, "desk.c1")
subprocess.run([os.path.join(root, "test", "sc4save", ".build", "release", "sc4save"),
                os.path.join(root, "build", "fixtures", "true", "B24.BMP"), "bmp", ref, "c1"], check=True,
               capture_output=True)
mine = open(os.path.join(res, saved[0]), "rb").read()
same = mine == open(ref, "rb").read() and saved[0].endswith("#C10000")
print(f"{'OUT saved as a $C1 screen, as GS Remap':40s} {'OK' if same else 'FAIL: ' + saved[0] + ' differs'}")
sys.exit(0 if ok and same else 1)
