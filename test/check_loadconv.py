# Checks the Load & convert test (test/loadconv.sh): the dialog loaded the first file it
# offered; each format's filter took exactly the files test/loadconv_list.py's model says;
# Load next loaded the queue's files in order and Cancel remaining files emptied it.
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from loadconv_list import CASES, expected, folder
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
res = os.path.join(root, "build", "test", "results")
log = [l for l in open(os.path.join(res, "MC.LOG#040000"), "rb").read().decode("latin-1").split("\r") if l]
ok = True
def report(label, problem):
    global ok
    print(f"{label:62s} {'OK' if not problem else 'FAIL: ' + problem}")
    ok &= not problem
def result(name):
    for f in os.listdir(os.path.join(res, "MCOUT")):
        if f.split("#")[0] == name: return open(os.path.join(res, "MCOUT", f), "rb").read()
queued = [l.split(": ", 1)[1] for l in log if l.startswith("QUEUED:")]
images = [l.split(": ", 1)[1] for l in log if l.startswith("IMAGES:")]
# The dialog: SuperHiRes chosen, MCTEST; Return opens the first file listed (by name).
s320 = open(os.path.join(root, "build", "fixtures", "S320.c1"), "rb").read()
dlg = result("DLG.C")
report("the file dialog: Return loaded the first file offered",
       None if images[:1] == ["screen 1, true 0, mono 0"] and dlg and dlg[:32000] == s320[:32000]
       else repr((images[:1], dlg is not None)))
for i, (t, f, name) in enumerate(CASES):
    fname, want = expected(t, f, name)
    got = queued[i] if i < len(queued) else None
    report(f"filter: {fname[:40]} ({name})", None if got == want else f"{got!r}, want {want!r}")
n = len(CASES)
first = expected(1, 0, "MCTEST")[1].split()[2:]
report("the queue: every SuperHiRes picture of MCTEST", None if queued[n:n + 1] == ["ok %d %s" % (len(first), " ".join(first))]
       else repr(queued[n:n + 1]))
report("Load next: the first, then the next", None if queued[n + 1:n + 3] == ["ok %d %s" % (len(first) - k, " ".join(first[k:]))
       for k in (1, 2)] else repr(queued[n + 1:n + 3]))
report("Cancel remaining files: none left", None if queued[n + 3:n + 4] == ["ok 0"] else repr(queued[n + 3:n + 4]))
q1, q2 = result("Q1.C"), result("Q2.C")
report("Load next loaded them in order", None if q1 and q2 and q1[:32000] == s320[:32000] and
       q2[:32000] == open(os.path.join(root, "build", "fixtures", "S640.c1"), "rb").read()[:32000] else "differs")
sys.exit(0 if ok else 1)
