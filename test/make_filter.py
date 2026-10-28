# Makes the pictures for the filter test (test/filters.sh): 24-bit BMP files of random
# pixels (fixed seed), one wide enough to meet most neighbourhoods, one a single pixel
# wide and one a single pixel high (the edges repeat), and a smooth one with few greys.
#   python3 test/make_filter.py <folder>
import os, random, struct, sys

def bmp(path, w, h, pixel):
    stride = (w * 3 + 3) & ~3
    rows = b""
    for y in range(h - 1, -1, -1):                    # bottom-up
        row = b"".join(bytes(reversed(pixel(x, y))) for x in range(w))   # BGR
        rows += row + b"\0" * (stride - w * 3)
    head = struct.pack("<2sIHHI", b"BM", 54 + len(rows), 0, 0, 54)
    info = struct.pack("<IiiHHIIiiII", 40, w, h, 1, 24, 0, len(rows), 2835, 2835, 0, 0)
    open(path, "wb").write(head + info + rows)

out = sys.argv[1]
os.makedirs(out, exist_ok=True)
rnd = random.Random(20261028)
noise = {}
def noisy(x, y):
    if (x, y) not in noise: noise[(x, y)] = tuple(rnd.randrange(256) for _ in range(3))
    return noise[(x, y)]
PICTURES = {"NOISE.BMP": (101, 61, noisy),
            "TALL.BMP": (1, 23, lambda x, y: tuple(rnd.randrange(256) for _ in range(3))),
            "WIDE.BMP": (29, 1, lambda x, y: tuple(rnd.randrange(256) for _ in range(3))),
            "SMOOTH.BMP": (64, 40, lambda x, y: (60 + x, 70 + y, 80 + (x + y) // 2))}
for name, (w, h, f) in PICTURES.items():
    bmp(os.path.join(out, name), w, h, f)
with open(os.path.join(os.path.dirname(out), "filter.types"), "w") as t:
    for name in PICTURES: t.write(f"{name} 060000\n")
