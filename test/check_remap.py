# Compares MegaconvertGS's remaps (made in the emulator) with GS Remap's.
# Run after: COMMANDS=test/remap.test ./test/run.sh
import os, sys, subprocess, shutil
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
fix = os.path.join(root, "build", "fixtures")
res = os.path.join(root, "build", "test", "results", "MCOUT")
work = os.path.join(root, "build", "test", "expected")
sc4 = os.environ.get("SC4", os.path.expanduser("~/Documents/GS Remap/.build/release/sc4"))
os.makedirs(work, exist_ok=True)

def expected(fixture):
    # GS Remap remaps a Super Hi-Res file given without an extension.
    src = os.path.join(work, fixture.replace(".", "_"))
    shutil.copy(os.path.join(fix, fixture), src)
    out = os.path.join(work, fixture + ".remap.c1")
    subprocess.run([sc4, "remap", src, out], check=True, capture_output=True)
    return open(out, "rb").read()

def result(name):
    for f in os.listdir(res):
        if f.split("#")[0] == name:
            return open(os.path.join(res, f), "rb").read()
    raise SystemExit(f"no result {name}")

ok = True
for label, name, fixture in [("320 picture remapped", "R320.C1", "S320.c1"),
                             ("640 picture remapped", "R640.C1", "S640.c1")]:
    got, want = result(name), expected(fixture)
    problems = []
    bad = sum(1 for a, b in zip(got[:32000], want[:32000]) if a != b)
    if bad: problems.append(f"{bad} of 32000 pixel bytes differ")
    if got[32000:32200] != want[32000:32200]: problems.append("SCBs differ")
    gp = [int.from_bytes(got[32256 + i * 2:32258 + i * 2], "little") for i in range(16)]
    wp = [int.from_bytes(want[32256 + i * 2:32258 + i * 2], "little") for i in range(16)]
    if gp != wp:
        problems.append("palette differs\n      got:  " + " ".join(f"{c:03X}" for c in gp) +
                        "\n      want: " + " ".join(f"{c:03X}" for c in wp))
    print(f"{label:24s} {'OK' if not problems else 'FAIL: ' + '; '.join(problems)}")
    ok &= not problems
sys.exit(0 if ok else 1)
