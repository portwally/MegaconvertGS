# Compares the pictures MegaconvertGS saved in the emulator with the expected ones
# made by GS Remap. Run after: COMMANDS=test/basic.test ./test/run.sh
import sys, os, subprocess
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
fix = os.path.join(root, "build", "fixtures")
res = os.path.join(root, "build", "test", "results", "MCOUT")
sc4 = os.environ.get("SC4", os.path.expanduser("~/Documents/GS Remap/.build/release/sc4"))

def find(name):
    for f in os.listdir(res):
        if f.split("#")[0] == name:
            return os.path.join(res, f)
    return None

def screen(path):
    return open(path, "rb").read()

def as_c1(path, fmt):
    """Decodes a saved file with GS Remap and returns its $C1 bytes."""
    out = os.path.join(root, "build", "test", os.path.basename(path).split("#")[0] + ".decoded.c1")
    subprocess.run([sc4, "load", path, out, fmt], check=True, capture_output=True)
    return open(out, "rb").read()

def compare(label, got, want, palette0_only=False):
    problems = []
    if got[:32000] != want[:32000]:
        bad = sum(1 for a, b in zip(got[:32000], want[:32000]) if a != b)
        problems.append(f"{bad} pixel bytes differ")
    if not palette0_only and got[32000:32200] != want[32000:32200]:
        problems.append("SCBs differ")
    used = {b & 15 for b in want[32000:32200]} if not palette0_only else {0}
    for t in sorted(used):
        a, b = got[32256 + t * 32:32288 + t * 32], want[32256 + t * 32:32288 + t * 32]
        if a != b:
            problems.append(f"colour table {t} differs")
    print(f"{label:34s} {'OK' if not problems else 'FAIL: ' + ', '.join(problems)}")
    return not problems

s320, s640 = screen(os.path.join(fix, "S320.c1")), screen(os.path.join(fix, "S640.c1"))
ok = True
ok &= compare("$C1 loaded, saved as $C1", screen(find("A.C1")), s320)
ok &= compare("Apple Preferred loaded, saved $C1", screen(find("B.C1")), s320)
ok &= compare("PackBytes loaded, saved as $C1", screen(find("C.C1")), s320)
ok &= compare("PaintWorks loaded, saved as $C1", screen(find("D.C1")), s320, palette0_only=True)
ok &= compare("640 Apple Preferred loaded, $C1", screen(find("E.C1")), s640)
ok &= compare("saved Apple Preferred, read back", as_c1(find("B.APF"), "shr"), s320)
ok &= compare("saved PackBytes, read back", as_c1(find("C.PACK"), "shr"), s320)
shots = sorted(f for f in os.listdir(os.path.join(root, "build", "test", "screens")) if f.endswith(".shr"))
ok &= compare("screen after SHOW (last dump)", screen(os.path.join(root, "build", "test", "screens", shots[-1])), s640)
sys.exit(0 if ok else 1)
