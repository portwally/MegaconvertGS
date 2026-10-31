# Build check: AlertWindow takes "/" as a separator and "^" and "#" as codes, so the
# Info on format texts (src/FormatInfo.s, between "93/" and the closing "/^#0") must
# not hold them.
import re, sys
src = open(sys.argv[1], encoding="latin-1").read()
bad = []
for m in re.finditer(r"^(Fi\w+)\s+asc\s+'93/(.*?)/\^#0'", src, re.S | re.M):
    text = re.sub(r"'(,[0-9A-F]{2})*\s*\n\s*asc\s+('|[0-9A-F]{2},')", "", m.group(2))
    if re.search(r"[/^#]", text.replace("',27,'", "")):
        bad.append(m.group(1))
if bad:
    print("FormatInfo.s: / ^ or # inside the text of " + ", ".join(bad)); sys.exit(1)
