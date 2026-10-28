# Checks the Preferences test (test/prefs.sh).
import os, sys
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
res = os.path.join(root, "build", "test", "results")
log = [l for l in open(os.path.join(res, "MC.LOG#040000"), "rb").read().decode("latin-1").split("\r") if l]
prefs = [l.split(": ", 1)[1] for l in log if l.startswith("PREFS:")]
ok = True
def report(label, problem):
    global ok
    print(f"{label:52s} {'OK' if not problem else 'FAIL: ' + problem}")
    ok &= not problem
want = ["00000000", "00000000", "00100101", "00100101"]
labels = ["all options off at first (no file yet)", "options cleared", "options read back from the file",
          "the dialog's OK keeps them"]
for i, (l, w) in enumerate(zip(labels, want)):
    report(l, None if i < len(prefs) and prefs[i] == w else repr(prefs[i] if i < len(prefs) else None))
d = os.path.join(root, "build", "test", "prefs_file")
files = [f for f in os.listdir(d) if f.upper().startswith("MCGS.PREFS#")] if os.path.isdir(d) else []
data = open(os.path.join(d, files[0]), "rb").read() if files else None
want = bytes([0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1, 0])
report("9:MCGS.Prefs: 16 bytes, type $5A", None if data == want and files[0].endswith("#5A0000")
       else repr((files, data)))
sys.exit(0 if ok else 1)
