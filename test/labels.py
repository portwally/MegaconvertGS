# Finds local labels (":name") defined twice under the same global label. Merlin 32
# accepts them without a word and sends every branch to the first one, so the build
# stops on them (build.sh runs this first).
import glob, os, re, sys
src = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "src")
found = 0
for f in sorted(glob.glob(os.path.join(src, "*.s"))):
    scope, seen = None, {}
    for i, l in enumerate(open(f, encoding="latin-1"), 1):
        m = re.match(r"^([A-Za-z_][A-Za-z0-9_]*)\b", l)
        if m and not re.match(r"^\S+\s+(=|equ\b)", l, re.I):
            scope, seen = m.group(1), {}
            continue
        m = re.match(r"^(:[A-Za-z0-9_]+)\b", l)
        if m:
            if m.group(1) in seen:
                print(f"{os.path.basename(f)}:{i}: {m.group(1)} again under {scope} (first at line {seen[m.group(1)]})")
                found += 1
            seen.setdefault(m.group(1), i)
sys.exit(1 if found else 0)
