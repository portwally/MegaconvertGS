# The pictures and save formats test/save.sh tries: prints the test commands.
import sys
PICTURES = [  # tag, folder and file on the test disk, local file, load format id
    ("SCR", "MCTEST:S320.C1", "build/fixtures/S320.c1", "c1"),
    ("ICN", "MCAPPLE:ICONS", "build/fixtures/apple/ICONS", "icon"),
    ("PSG", "MCAPPLE:PSGS.GR", "build/fixtures/apple/PSGS.GR", "psgs"),
    ("BIG", "MCTRUE:BIG.PNG", "build/fixtures/true/BIG.PNG", "png"),
    ("DHB", "MCAPPLE:DHRBW.PIC", "build/fixtures/apple/DHRBW.PIC", "dhrbw"),
]
FORMATS = ["pw", "icon", "iconadd", "ricon", "riconadd", "hex", "gif", "png", "tiff"]
def out(tag, fmt):
    return f"{tag}.{fmt.upper()}"
if __name__ == "__main__" and sys.argv[1:] == ["commands"]:
    for tag, disk, local, fid in PICTURES:
        print(f"LOAD AS {fid} *:{disk}")
        for fmt in FORMATS:
            if fmt in ("iconadd", "riconadd"):       # a file to add to, made first
                print(f"SAVE AS {fmt[:-3]} *:MCOUT:{out(tag, fmt)}")
            print(f"SAVE AS {fmt} *:MCOUT:{out(tag, fmt)}")
    print("SHOW")
