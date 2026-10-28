# Checks the picture MegaconvertGS saved through its menus and dialogs.
# Run after the UI test in test/README or ./test/ui.sh
import os, subprocess, sys
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
res = os.path.join(root, "build", "test", "results")
sc4 = os.environ.get("SC4", os.path.expanduser("~/Documents/GS Remap/.build/release/sc4"))
log = open(os.path.join(res, "MC.LOG#040000"), "rb").read().decode().split("\r")
ok = log[:3] == ["MENU 259: ok", "MENU 260: ok", "QUIT: ok"]
print(f"{'menu commands':34s} {'OK' if ok else 'FAIL: ' + repr(log)}")
saved = [f for f in os.listdir(res) if f.split("#")[0] == "OUT"]
if not saved:
    print(f"{'OUT saved through the dialogs':34s} FAIL: no file"); sys.exit(1)
out = os.path.join(root, "build", "test", "OUT.decoded.c1")
subprocess.run([sc4, "load", os.path.join(res, saved[0]), out, "shr"], check=True, capture_output=True)
want = open(os.path.join(root, "build", "fixtures", "S320.c1"), "rb").read()
got = open(out, "rb").read()
same = got[:32000] == want[:32000] and got[32256:32288] == want[32256:32288]
print(f"{'OUT saved through the dialogs':34s} {'OK' if same else 'FAIL: picture differs'}")
sys.exit(0 if ok and same else 1)
