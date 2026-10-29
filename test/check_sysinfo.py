# Checks the System info report test (test/sysinfo.sh).
import os, re, sys
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
res = os.path.join(root, "build", "test", "results")
ok = True
def report(label, problem):
    global ok
    print(f"{label:58s} {'OK' if not problem else 'FAIL: ' + problem}")
    ok &= not problem
names = [f for f in os.listdir(os.path.join(res, "MCOUT")) if f.split("#")[0] == "REPORT"]
if not names:
    report("the report saved", "no file"); sys.exit(1)
report("the report saved as a text file (TXT, aux 0)", None if names[0].endswith("#040000") else names[0])
text = open(os.path.join(res, "MCOUT", names[0]), "rb").read().decode("latin-1")
lines = text.split("\r")
report("its title, with the version", None if lines[0] == "MegaconvertGS 1.1 System Info:" else repr(lines[0]))
heads = ["MEMORY USAGE:  TotalMem=", "LOAD FILES IN MEMORY:  ", "STARTED TOOLSETS:  ",
         "MISCELLANEOUS:  GS/OS v", "BATTERY RAM (non-255 values):  "]
starts = [next((i for i, l in enumerate(lines) if l.startswith(h)), None) for h in heads]
report("the five sections, in order, each on a new line",
       None if None not in starts and starts == sorted(starts) else repr(starts))
long = [l for l in lines if " " in l[77:]]          # (a last word may run past)
report("lines broken at spaces past 76 characters", None if not long else f"{len(long)} long lines")
report("no character $A7 left (prerelease versions as B)", None if "\xa7" not in text else "found")
flat = " ".join(lines)
m = re.search(r"TotalMem=(\d+)K, FreeMem=(\d+)K, RealFreeMem=(\d+)K, MaxBlock=(\d+)K, (\d+) handles\.", flat)
report("memory figures (4 MB card: TotalMem 4224K)",
       None if m and int(m[1]) == 4224 and 0 < int(m[4]) <= int(m[3]) <= int(m[1]) and int(m[5]) > 50
       else repr(m and m.groups()))
ranges = re.findall(r"\$([0-9A-F])xxx=(\d+)K/(\d+)K", flat)
report("memory by ID range", None if len(ranges) >= 3 and ranges == sorted(ranges, key=lambda r: r[0]) else repr(ranges))
files = re.findall(r"\$([0-9A-F]{4}) ([^,]+?)(?=, \$|\s*STARTED)", flat[flat.find("LOAD FILES"):flat.find("STARTED TOOLSETS") + 16])
fnames = [f[1] for f in files]
report("load files: the application and the system's",
       None if "Finder" in fnames and "TOOL.SETUP" in fnames and any(n.endswith(".FST") for n in fnames)
       else repr(fnames[:12]))
tools = re.findall(r"\$([0-9A-F]{2}) v(\d+)\.(\d+)", flat[flat.find("STARTED TOOLSETS"):flat.find("MISCELLANEOUS")])
ids = [int(t[0], 16) for t in tools]
report("started tool sets (QuickDraw II, TextEdit, ...)",
       None if {1, 2, 3, 4, 6, 14, 15, 16, 20, 21, 34} <= set(ids) and ids == sorted(ids) else repr(ids))
m = re.search(r"MISCELLANEOUS:  GS/OS v(\d+)\.(\d+), ROM ID \$([0-9A-F]{4}) & features \$([0-9A-F]{4}),  key translation (\d+)", flat)
report("versions: GS/OS (4.2 in System 6.0.4), ROM 3", None if m and int(m[1]) >= 3 and m[3] == "0003" else repr(m and m.groups()))
bat = re.findall(r"\$([0-9A-F]{2})=(\d+)", flat[flat.find("BATTERY RAM"):])
report("battery RAM values (not 255)", None if len(bat) > 20 and all(int(v) != 255 for _, v in bat) else repr(bat[:8]))
sys.exit(0 if ok else 1)
