# SuperConvert 4: Works of Art, desktop INIT, New Print Shop and Babelfish

Reference for the four SuperConvert 4.0 formats MegaconvertGS does not have yet:

- the "Works of Art (Springboard Publ.)" load format (monochrome),
- the "Desktop background image INIT" save format,
- "New Print Shop graphics" (listed by the original, never implemented),
- the four Babelfish™ entries (True Color / PixelMap Import, True Color / PixelMap Export).

Everything was read from the original program files (data fork, OMF load file; resource fork)
and from the help file "SuperConv.Help" that ships with it. Conventions are those of
`superconvert-ui-data.md`: numbers starting with $ are hexadecimal, rectangles are
top,left,bottom,right with bottom/right exclusive, words are little-endian, addresses are given as
segment name and offset, "file $xxxxx" is a data fork offset. Segments used here: 5 MAINE, 6 FRED,
8 LONGCODE, 9 OSAYCANYOU, 22 ~JumpTable, 25 DYNAMDESK. Routine names in brackets ([Lwoa],
[CreateDesk] ...) are the names stored in the program itself. "SC" below means SuperConvert 4.0.

Anything that was inferred rather than read directly is marked "(uncertain)" and listed again in
section 5.

## Contents

- 1. Works of Art (Springboard Publisher)
- 2. Desktop background image INIT
- 3. New Print Shop graphics
- 4. Babelfish imports and exports
- 5. Uncertain points

## 1. Works of Art (Springboard Publisher)

### 1.1 Load record and help

Load record MAINE $31A6 (file $139E3), computer type 0 "Apple II family", entry 7:

```
$31A6 C0320000 00 04 F7 F7 00000000 01000000 FFFFFF00 0000 0000 BAAE0600 E1320000
```

| Field | Value |
|---|---|
| Name | "Works of Art (Springboard Publ.)" (MAINE $32C0) |
| Kind / icon | 4, monochrome image |
| File type | $F7 only |
| Aux type | $0000 only |
| EOF | 1 - $FFFFFF |
| Loader | JSL FRED $AEBA [Lwoa] (file $2D79E) |
| Help tag | "LFWOA" |

Help topic LFWOA (help file text):

```
Format: Works of Art
Machines: Apple IIs with 128K
Programs: Springboard Publisher
Resulting picture: 270 x 360 monochrome images.

This format contains multiple pages of graphics: a dialog box will be
presented to allow you to select the desired page to load.  You can quickly go
to another page by doing a Reload (Apple-R).
```

"Reload" is File > "Re-convert last file" ($0114, Apple-R): it runs the loader on the same file
again, so the page dialog comes back.

### 1.2 File layout

The file is a small container: a 16-byte header, a directory of 16-byte entries, and a data area
holding the chunks one after the other in directory order.

Header (offset 0, 16 bytes):

| Offset | Size | Meaning |
|---|---|---|
| +$00 | 5 | not read by SC |
| +$05 | 2 | signature "SS" ($53 $53); anything else gives error $FF00 |
| +$07 | 4 | not read by SC |
| +$0B | 2 | N = number of directory entries |
| +$0D | 1 | B = first block of the data area; data area starts at file offset B × 512 |
| +$0E | 2 | not read by SC |

Directory: N entries of 16 bytes at file offset $10 (read straight after the header, no seek):

| Offset | Size | Meaning |
|---|---|---|
| +$00 | 2 | chunk type |
| +$02 | 2 | chunk ID |
| +$04 | 4 | not read by SC |
| +$08 | 2 | chunk length in bytes (only this word is used; the following 2 bytes may be the high word of a 32-bit length (uncertain)) |
| +$0A | 6 | not read by SC |

Chunk position: chunk k (0-based directory index) starts at

```
offset(k) = B * 512 + length(0) + length(1) + ... + length(k-1)
```

A chunk is looked up by (type, ID) with FRED $B23C, which searches the directory from the last
entry down to entry 0 and takes the first match (so with duplicates the last one wins). It sets
the file mark to offset(k) and the "bytes left in this chunk" counter (FRED $B23A) to its length.
Not found gives error $FF04.

SC uses three kinds of chunk and ignores all others:

| Type | ID | Content |
|---|---|---|
| 0 | 4 | list of page names (1.3) |
| n (1, 2, ...) | $0B | bitmap of page n, n = position of the page name in the list (1.4) |
| 0 | 3 | list of rectangles, used only by the Tab key (1.9); optional |

Limits of the original code (an implementation should check instead):

- B must be below 128: the offset is built as (B × 2) swapped into the high byte (ASL, XBA), which
  is wrong for B × 2 ≥ 256.
- The directory (N × 16 bytes) and later the rectangle chunk are read into the shared buffer
  LONGCODE $4F88 without a length check. The zero-filled area there runs to LONGCODE $9789
  (18434 bytes) (uncertain: other routines use parts of it).
- N × 16 is computed in 16 bits.

### 1.3 Page name list (type 0, ID 4)

| Offset | Size | Meaning |
|---|---|---|
| +0 | 2 | count C of names (must be at least 1: C = 0 loops 65536 times) |
| +2 | 1 | not read by SC (the rectangle list has 8 here, its entry size; 0 is a safe value) |
| +3 | | C Pascal strings, one after the other |

The whole chunk is read into the screen image buffer (the 64 KB block whose pointer is at MAINE
$00E4 and direct page $14); the screen image has already been discarded when a load starts. For the list control,
SC builds C members of 5 bytes (pointer to the string, flag byte) at MAINE $4017. That area is 512
bytes long (MAINE $4017-$4216), so more than 102 names would overwrite program code (uncertain:
size taken from the zero-filled area). The first member is preselected (flag $80).

### 1.4 Page bitmap (type n, ID $0B)

A 10-byte header, then compressed data up to the end of the chunk.

| Offset | Size | Value required by SC |
|---|---|---|
| +0 | 2 | not checked |
| +2 | 2 | 0 (left) |
| +4 | 2 | 0 (top) |
| +6 | 2 | $010D = 269 (right, inclusive) |
| +8 | 2 | $0167 = 359 (bottom, inclusive) |

Any other values give error $FF04 "Cannot handle this variation on the selected type". The
picture is always 270 pixels wide and 360 high.

Compressed data: a sequence of codes, read until the chunk is used up exactly. Each code produces
"cells"; a cell is one 7-bit value covering 7 horizontal pixels (1.5).

| First byte c | Meaning |
|---|---|
| $00-$7F | literal: one cell with value c |
| $80-$FF | run: L = ((c >> 4) & 7) + 1 pattern bytes (1-8); R = c & $0F. If R < 8: count = R. If R ≥ 8: count = ((R & 7) << 8) + next byte (0-2047). Then the L pattern bytes follow. The pattern (L cells, each byte & $7F) is produced count + 1 times |

So a run gives 1-8 repeats in the short form and 1-2048 repeats in the long form, of a pattern
of 1-8 cells. Bit 7 of every cell byte is ignored. In the long form the extra count byte comes
before the pattern bytes.

Examples:

| Bytes | Cells |
|---|---|
| `2A` | one cell $2A |
| `83 7F` | $7F four times |
| `88 09 7F` | $7F ten times (count $009) |
| `8F FF 00` | $00 2048 times |
| `9F FF 2A 55` | $2A, $55 repeated 2048 times (4096 cells) |
| `F0 01 02 03 04 05 06 07 08` | the 8 cells 01 ... 08 once |

Reading is clipped to the chunk: a read of k bytes when fewer remain reads only what remains; a
read when nothing remains gives error $004C "Unexpected end of file". The loop stops as soon as
the chunk is used up after a complete code.

### 1.5 Pixel layout

Cells fill the page in vertical strips 7 pixels wide, going down the first strip, up the second,
down the third and so on (serpentine). A strip holds 360 cells, one per row. Strip s covers
pixels x = 7s ... 7s + 6; 39 strips (14040 cells) cover x = 0 ... 272.

```
           strip 0      strip 1      strip 2           strip 38
           x 0-6        x 7-13       x 14-20     ...   x 266-272
           (down)       (up)         (down)            (down)
row 0      cell 0       cell 719     cell 720          cell 13680
row 1      cell 1       cell 718     cell 721          cell 13681
...
row 359    cell 359     cell 360     cell 1079         cell 14039
```

Inside a cell, bit b (0 = least significant) is pixel x = 7s + b: bit 0 is the leftmost pixel, as
on the Apple II hi-res screen. SC reverses the bits with the table FRED $81FB (file $2AADF, 128
used entries, entry i = i with its 8 bits reversed) and ORs the result into the monochrome rows at
the right bit offset. A set bit becomes a set monochrome bit, which SC shows as white
(superconvert-image-window.md 1.2); the page starts all clear (black). Whether a set bit is paper
or ink in Springboard Publisher itself was not checked (uncertain); if pages come out inverted,
Monochrome > Negative image fixes them.

Decoder (what SC does, with the two places where it differs from a clean decoder):

```
W = 270; H = 360; bpr = (W + 7) / 8 = 34          ; monochrome bytes per row
clear the bitmap (bit 7 of byte 0 = pixel 0, 1 = white)
strip = 0; y = 0; down = true

put(c):                                   ; one cell, c = byte & $7F
    for b = 0 to 6:
        if c & (1 << b):
            x = 7 * strip + b
            set pixel (x, y)              ; see note (a)
    if down: if y == 359: strip += 1; down = false   else y += 1
    else:    if y == 0:   strip += 1; down = true    else y -= 1

decode(data):                             ; data = chunk bytes after the 10-byte header
    while bytes remain:
        c = next byte
        if c < $80: put(c)
        else:
            L = ((c >> 4) & 7) + 1
            count = c & $0F
            if count >= 8: count = ((count & 7) << 8) | next byte
            pattern = next L bytes
            repeat count + 1 times: for each p in pattern: put(p & $7F)
```

(a) SC writes a cell as a 16-bit OR at byte (7 × strip) / 8 of row y, so in strip 38 (x0 = 266)
data bit 4 and 5 land on x = 270 and 271 (the padding bits of the row's last byte) and data bit 6
(x = 272) lands on pixel 0 of row y + 1 (for row 359 on one extra byte that SetMonoSize allocates
for this). A clean decoder drops pixels with x ≥ 270. Real files presumably have these bits clear
(uncertain).

(b) SC does not stop after 14040 cells; more cells would write past the row ends and past the
buffer. Stop (or reject the file) after 39 strips.

### 1.6 Loader flow (FRED $AEBA [Lwoa])

```
open the file (MAINE $4ADE)
read 16 bytes (header); if bytes 5-6 != "SS": return $FF00
N = word at $0B; B = byte at $0D
read N*16 bytes (directory) into LONGCODE $4F88
find (0, 4); read the whole chunk into the screen buffer          ; error -> $FF04
C = first word; build the list members (1.3), first one selected
open the page window (1.7), wait for OK / Cancel / double-click
    Cancel: close window, close file, return $FFFF (no message)
k = number of the selected name (1-based; NextMember2)
close the window, watch cursor (MAINE $278F), let pending updates draw (FRED $97DF [UpdateAll])
image name (MAINE $3F61, used in the window title) = name k, cut to 31 characters
find (k, $0B)                                                     ; error -> $FF04
read 10 bytes; check left 0, top 0, right 269, bottom 359          ; else $FF04
SetMonoSize(270, 360)  (FRED $87B9: 34 bytes per row; allocates 34*360 + 1 bytes)
ClearMono; decode (1.4, 1.5)
clear LONGCODE $4F88 and $4F8A (words); Tab index FRED $B40E = 0
find (0, 3); if found: read the whole chunk into LONGCODE $4F88
close the file
monochrome options: FRED $80E9 = 1 (Square), $80EB = 1 (1:1), $80ED = 0 (320 mode)
monochrome pixel size MAINE $053A = 0 (320-sized)
return OK
```

Then the common load code (MAINE $45D4) opens the image window on the monochrome image (the only
image type the load produced).

### 1.7 Page dialog

NewWindow2(title 0, refCon 0, content draw OSAYCANYOU $7350 [GenericRedraw], defProc 0,
paramTableDesc 0, paramTableRef FRED $B2C5 (file $2DBA9), type $800E), then ShowWindow.

Template FRED $B2C5: length $50, frame $2000 (alert frame, not visible until ShowWindow),
content procedure OSAYCANYOU $7350, position (screen) 40,110,150,510, plane $FFFFFFFF, control
list FRED $B3CC (inDesc $0003: list of pointers to control templates, ending with 0). All other
fields 0.

| Template | ID | Type | Rect | Flag | More flags | Details |
|---|---|---|---|---|---|---|
| FRED $B315 | 0 | static text $81000000 | 5,270,25,390 | $0000 | $1000 | "Select page" CR "to be loaded:" (25 bytes, FRED $B335) |
| FRED $B34E | 2 | simple button $80000000 | 70,280,85,380 | $0000 | $3000 | "Cancel" (OSAYCANYOU $0EE8), key $1B/$1B (Escape) |
| FRED $B376 | 1 | simple button $80000000 | 90,280,105,380 | $0001 (default) | $3000 | "OK" (OSAYCANYOU $0EF7), key $0D/$0D (Return) |
| FRED $B39E | 3 | list $89000000 | 4,10,106,260 | $0000 | $3400 | listSize C (FRED $B3B8, set at run time), listView 10, listType $0006 (Pascal strings, single selection), listStart 1, listDraw 0 (standard), listMemHeight 10, listMemSize 5, listRef MAINE $4017 |

Event loop: TaskMaster with event mask $FFFF and the task record FRED $B3E0, task mask
$001B0006 (update, find window, content controls, control keys, multi-click, idle). Menus are not
handled while the window is up.

- Result $21 (wInControl) with control 1 (OK, or Return): load the selected page.
- Control 2 (Cancel, or Escape): close the window, close the file, return $FFFF (silent).
- Control 3 (the list) with click count 2 (double-click): the OK button flashes (hilite 2 then 0)
  and the selected page is loaded. Single clicks only select.

If no name is selected when OK is clicked (possible only if the list lets the user deselect), k is
0, the name pointer is read from before the member array, and the page lookup (0, $0B) fails with
$FF04 (uncertain whether the list allows it).

### 1.8 Resulting image

- Monochrome image, 270 × 360 pixels, 34 bytes per row, 1 bit per pixel (1 = white).
- Pixel size 320-sized (MAINE $053A = 0): every pixel takes two 640-mode columns, so the image is
  540 × 360 image units in the window (superconvert-image-window.md section 2). This is the only
  loader that sets 320-sized.
- No screen image and no true color image; the window title is the page name with "(???)".
- Monochrome conversion options set to Square, 1:1, 320 mode, so Monochrome > Convert to screen
  gives a 320-mode screen image of 135 bytes × 360 lines by default.

### 1.9 Rectangle list and the Tab key

Chunk (0, 3), read into LONGCODE $4F88 (file $470DE):

| Offset | Size | Meaning |
|---|---|---|
| +0 | 2 | count; must equal the number of page names C |
| +2 | 1 | entry size, must be 8 |
| +3 | 8 × count | entries: x1, y1, x2, y2 (words, inclusive pixel coordinates) |

Tab key (FRED $A171 [SHRVector] calls FRED $B410, file $2DCF4):

```
if shown type != monochrome or image units != 270 x 360: ignore
if word LONGCODE $4F88 != C (FRED $B3B8) or byte LONGCODE $4F8A != 8: ignore
i = FRED $B40E; FRED $B40E = (i + 1 < C) ? i + 1 : 0       ; advanced even if entry i is bad
(x1, y1, x2, y2) = entry i
if x2 + 1 > 270 or y2 + 1 > 360 or x1 >= x2 + 1 or y1 >= y2 + 1: ignore
erase the selection frame; stored monochrome selection (MAINE $E1A6) =
    (top y1, left x1, bottom y2 + 1, right x2 + 1)
ImgChanged; redraw the frame; scroll so the selection is centred (as key 5)
```

What this means in practice (from the code; not tried on a machine):

1. The width test is in image units, so it only passes with 640-sized pixels (270 units); the
   loader itself sets 320-sized (540 units). The user has to switch to "640-sized pixels" first.
2. Tab writes the stored selection but does not set the monochrome selection flag (MAINE $E184);
   ImgChanged then replaces the rectangle by the whole image unless a monochrome selection already
   existed.
3. Worse, the monochrome drawing routine (MAINE $EE00) builds its strips in the same buffer,
   starting at LONGCODE $4F88, the first time the window is drawn. Strip bytes are made of the
   nibbles $0/$F (320-sized) or the bit pairs 00/11 (640-sized), so the byte at $4F8A can never be
   8 afterwards. Since the window is always drawn right after the load, the check fails and Tab
   does nothing.

The help file does not mention Tab. For MegaconvertGS: if the feature is wanted, keep the list in
its own buffer, compare the image size in pixels, and set the selection flag. If not, the (0, 3)
chunk can be ignored.

### 1.10 Messages

Errors go through the common load error alert (MAINE $4900 / $47F4, StopAlert OSAYCANYOU $0F70):

```
I am having a hard time reading from the file:
NAME
Error code is $XXXX: TEXT.                                   [Continue]
```

NAME is the file name, or the page name once a page has been chosen (the loader has already put
it in MAINE $3F61).

| Code | Text | When |
|---|---|---|
| $FF00 | File is damaged or not of the selected type | bytes 5-6 are not "SS" |
| $FF04 | Cannot handle this variation on the selected type | no chunk (0, 4); no chunk (k, $0B) for the chosen page; page header not 0, 0, 269, 359 |
| $004C | Unexpected end of file | the page data ends inside a code |
| $FF02 | Picture too large | SetMonoSize refuses the size (cannot happen with 270 × 360) |
| GS/OS codes | e.g. $0027 "I/O error!" | open, read or set mark failed |
| $0050 | (error description not available) | a file is already open (should not happen) |
| tool error | the text for that code if the table has one, else "(error description not available)" | NewWindow2 failed |

Not enough memory for the bitmap: SetMonoSize tries PurgeAll and CloseAllNDAs, then shows
AlertWindow "Sorry, there isn't enough memory available (*0K needed) to hold this monochrome
image." (FRED $88D4, *0 = 12 here) and the load ends silently ($FFFF). Cancel in the page dialog
is silent too.

### 1.11 Building a test file

The file below has two pages and a rectangle list. It can be written with this script (ProDOS
file type $F7, aux type $0000; the `#F70000` suffix is the usual way to give CiderPress or
Cadius the type):

```python
# Writes TEST.WOA#F70000 (ProDOS type $F7, aux type $0000): two Works of Art pages.
import struct

def run(count, pattern):                       # one RLE code: pattern repeated count times
    c = count - 1                              # 0-2047
    head = 0x80 | (len(pattern) - 1) << 4
    if c < 8:
        return bytes([head | c]) + bytes(pattern)
    return bytes([head | 8 | c >> 8, c & 0xFF]) + bytes(pattern)

page_hdr = struct.pack('<5H', 0, 0, 0, 269, 359)
page1 = page_hdr + (run(10, [0x7F]) + run(350, [0x00]) +          # strip 0: rows 0-9 white
                    run(10, [0x7F]) + run(450, [0x00]) +          # strip 1: rows 359-350 white
                    bytes([0x01]) +                               # strip 2, row 100: pixel x = 14
                    run(2048, [0x00]) * 6 + run(931, [0x00]))     # rest of the 14040 cells
page2 = page_hdr + run(2048, [0x2A, 0x55]) * 3 + run(876, [0x2A, 0x55])   # checkerboard
names = struct.pack('<HB', 2, 0) + b'\x08PAGE ONE' + b'\x07CHECKER'
rects = struct.pack('<HB', 2, 8) + struct.pack('<8H', 0, 0, 13, 9, 0, 0, 269, 359)

chunks = [(0, 4, names), (1, 0x0B, page1), (2, 0x0B, page2), (0, 3, rects)]
header = bytearray(16)
header[5:7] = b'SS'                                   # signature
struct.pack_into('<H', header, 0x0B, len(chunks))     # number of directory entries
header[0x0D] = 1                                      # chunk data starts at block 1 (offset 512)
directory = b''.join(struct.pack('<HH4xH6x', t, i, len(d)) for t, i, d in chunks)
head = bytes(header) + directory
data = head + bytes(512 - len(head)) + b''.join(d for _, _, d in chunks)
open('TEST.WOA#F70000', 'wb').write(data)
```

The result is 621 bytes; all bytes not listed are 0:

```
0000: 00 00 00 00 00 53 53 00 00 00 00 04 00 01 00 00
0010: 00 00 04 00 00 00 00 00 14 00 00 00 00 00 00 00
0020: 01 00 0B 00 00 00 00 00 2C 00 00 00 00 00 00 00
0030: 02 00 0B 00 00 00 00 00 1A 00 00 00 00 00 00 00
0040: 00 00 03 00 00 00 00 00 13 00 00 00 00 00 00 00
0200: 02 00 00 08 50 41 47 45 20 4F 4E 45 07 43 48 45
0210: 43 4B 45 52 00 00 00 00 00 00 0D 01 67 01 88 09
0220: 7F 89 5D 00 88 09 7F 89 C1 00 01 8F FF 00 8F FF
0230: 00 8F FF 00 8F FF 00 8F FF 00 8F FF 00 8B A2 00
0240: 00 00 00 00 00 00 0D 01 67 01 9F FF 2A 55 9F FF
0250: 2A 55 9F FF 2A 55 9B 6B 2A 55 02 00 08 00 00 00
0260: 00 0D 00 09 00 00 00 00 00 0D 01 67 01
```

Expected results (a decoder written exactly as in 1.5 gave these):

- "PAGE ONE": black 270 × 360 page with 141 white pixels: a 7 × 10 block at x 0-6, rows 0-9; a
  7 × 10 block at x 7-13, rows 350-359 (this checks the upward second strip); one pixel at
  (14, 100) (this checks a strip that starts inside a byte).
- "CHECKER": white where x + y is odd. With SC's exact behaviour (note (a) in 1.5) the column
  x = 0 is also white on the even rows 2-358 (179 extra pixels); a decoder that drops x ≥ 270
  gives a clean checkerboard.
- The window title is the page name; the image is 320-sized (540 × 360 units).

Error tests: change byte 5 to get $FF00; change the byte at $021A (page 1's right edge, $010D) to
get $FF04 for page 1; set page 1's directory length (offset $0028) to $2B instead of $2C to get
$004C (its last code then lacks its pattern byte).

## 2. Desktop background image INIT

### 2.1 Save record and help

Save record MAINE $8F66 (file $197A3), entry 7 of the save list:

```
$8F66 5D910000 00 01 B700 2E494E49 0000 00000000 0400 01 01 829900 00 6DB4 7B910000 0000 0000 0000
```

| Field | Value |
|---|---|
| Name | "Desktop background image INIT" |
| Kind | 1: needs a screen image (made first from a true color image by Remap, or from a monochrome image by Convert to screen) |
| File type / aux type | $B7 (temporary initialization file) / $0000 |
| Default suffix | ".INI" |
| Mac file type | none |
| Warnings | $0004: bit 2, "=> Multiple color palettes." (a line uses a palette other than 0); no size limit |
| Size choices | $01, default $01: only "Same as original" is enabled in "Select size of saved picture" (the dialog is still shown) |
| Options routine | MAINE $9982 (none) |
| Save routine | MAINE $B46D: JSL ~JumpTable $003C, which loads the dynamic segment DYNAMDESK and jumps to DYNAMDESK $0000; then FRED $A3B9 [UnloadAll] |
| Help tag | "SFDESK" |
| Adds to file | no (new file, normal Save dialog) |

Help topic SFDESK (help file text):

```
-=[ Desktop background image INIT ]=-

Default filename ending: INI
Programs: the output of this save format is a program, intended to be placed in
the SYSTEM.SETUP folder within the SYSTEM folder on your startup disk.
Putting one anywhere else has no effect.  When a disk with one of these files
is booted, the picture contained in the file will be installed as the
background image for all normal desktop-style programs.
Picture size: always one screenfull, with the top 13 rows of pixels being
invisible due to the presence of the menu bar.  Larger images are chopped
off at the bottom, smaller ones are centered on a light blue background.
Limitations: any image can be saved in this format, but it won't look right
unless its palette matches the palette of the programs it appears in.  Use
the Remap command to change an image to a different palette or mode.
```

### 2.2 Save flow (DYNAMDESK $0000, file $AE5F6)

By the time the routine runs, the common save code has created and opened the file (type $B7, aux
$0000) under the name chosen in the Save dialog.

```
h = CreateDesk()                         ; LONGCODE $EA8D, 32008-byte desktop message (2.3)
if error: return it (carry set)
ptr = *h; size = $7D08 (32008)
PackBytes(&ptr, &size, DYNAMDESK $0194, $7F00)   ; packs all 32008 bytes into the INIT template
DisposeHandle(h)
write $805E bytes from DYNAMDESK $0061 (the INIT template, 2.4) to the open file (MAINE $4C57)
return (carry set on a write error)
```

The written file is always 32862 ($805E) bytes. Only the packed area changes from save to save.

### 2.3 The desktop message (LONGCODE $EA8D [CreateDesk])

NewHandle($7D08 bytes, SC's memory ID, $C000 locked + fixed). Layout:

| Offset | Size | Content |
|---|---|---|
| +0 | 4 | $DD $DD $DD $DD (Message Center link field; SC leaves the fill value) |
| +4 | 2 | $DD $DD (message type field; the type, 2, is given to MessageCenter separately) |
| +6 | 2 | $0001 = a 32000-byte picture follows (SC's "Revert to normal desktop" sends a 40-byte message with $0000 here and a 32-byte pattern of $DD instead) |
| +8 | 32000 | 200 lines × 160 bytes of super hi-res pixel bytes |

Building it from the screen image (raw bytes in the screen buffer, bytes per line w = MAINE
$00E8, lines h = MAINE $00EE):

```
fill all 32008 bytes with $DD                   ; pixel value 13 everywhere: light blue in the
msg[6..7] = $0001                               ; standard 320 palette
copyW = min(w, 160)
x0 = (w < 160) ? (160 - w) >> 1 : 0             ; bytes from the left
if h >= 200:      rows = 200; y0 = 0            ; top 200 lines, top 13 under the menu bar
else if h >= 187: rows = h;   y0 = 200 - h      ; bottom-aligned
else:             rows = h;   y0 = ((187 - h) >> 1) + 13   ; centred below the menu bar
for r = 0 to rows - 1:
    copy copyW bytes from screen line r to msg[8 + (y0 + r) * 160 + x0]
```

Only pixel bytes are stored: no SCBs, no palettes, so the picture is shown in the mode and
colours of whichever program draws the desktop (hence the help's palette warning and the warning
bit 2). A 640-mode picture in the standard 640 palette suits the Finder.

Examples: a 320 × 200 or 640 × 200 picture (160 bytes × 200 lines) is copied unchanged. A
picture of 80 bytes × 100 lines lands at x0 = 40 bytes, lines 56-155 ((187 - 100) >> 1 + 13 = 56).
A picture of 190 lines starts at line 10. A picture 200 bytes wide keeps its left 160 bytes.

### 2.4 The file, byte for byte

The file is the OMF load file kept in DYNAMDESK from $0061 to $80BE (file $AE657-$B66B4), with
the packed message written into it. Version 2 OMF, one static code segment.

| File offset | Content |
|---|---|
| $0000-$0036 | segment header (below) |
| $0037-$003B | LCONST record: $F2, count $00007FF7 |
| $003C-$0132 | INIT code and variables, segment offsets $0000-$00F6 (2.5) |
| $0133-$8032 | packed message, segment offsets $00F7-$7FF6: PackBytes output, then zeros up to $7F00 bytes |
| $8033-$805C | relocation records |
| $805D | END record $00 |

Header fields: BYTECNT $0000805E, RESSPC 0, LENGTH $00007FF7, LABLEN 0, NUMLEN 4, VERSION 2,
BANKSIZE $00010000, KIND $0000 (static code), ORG 0, ALIGN 0, NUMSEX 0, SEGNUM 1, ENTRY 0,
DISPNAME $002C, DISPDATA $0037, LOADNAME 10 zero bytes, SEGNAME empty (one zero byte).

Fixed bytes before the packed area:

```
0000: 5E 80 00 00 00 00 00 00 F7 7F 00 00 00 00 04 02
0010: 00 00 01 00 00 00 00 00 00 00 00 00 00 00 00 00
0020: 00 00 01 00 00 00 00 00 2C 00 37 00 00 00 00 00
0030: 00 00 00 00 00 00 00 F2 F7 7F 00 00 8F EF 00 00
0040: 3B 38 E9 04 00 1B 0B 1A 5B 8B 4B AB 48 48 F4 00
0050: 00 F4 08 7D AD EF 00 48 F4 00 C0 F4 00 00 F4 00
0060: 00 A2 02 09 22 00 00 E1 68 85 00 68 85 02 B0 47
0070: A0 02 00 A7 00 8D F1 00 B7 00 8D F3 00 48 F4 F7
0080: 00 F4 F7 00 F4 00 7F F4 F1 00 F4 F1 00 F4 F5 00
0090: F4 F5 00 A2 03 27 22 00 00 E1 68 F4 01 00 F4 02
00A0: 00 D4 02 D4 00 A2 01 15 22 00 00 E1 D4 02 D4 00
00B0: A2 02 10 22 00 00 E1 AB 2B A8 A3 06 83 06 A3 05
00C0: 83 05 3B 18 69 04 00 1B 98 C9 01 00 6B 44 65 73
00D0: 6B 74 6F 70 20 62 61 63 6B 67 72 6F 75 6E 64 20
00E0: 49 4E 49 54 20 63 6F 70 79 72 69 67 68 74 20 31
00F0: 39 39 30 20 4A 61 73 6F 6E 20 48 61 72 70 65 72
0100: 2E 20 46 69 6C 65 73 20 67 65 6E 65 72 61 74 65
0110: 64 20 61 72 65 20 66 72 65 65 6C 79 20 64 69 73
0120: 74 72 69 62 75 74 61 62 6C 65 2E 00 00 00 00 00
0130: 00 08 7D
```

File bytes $00CD-$012A are the 94 characters "Desktop background INIT copyright 1990 Jason
Harper. Files generated are freely distributable." (no length byte, no terminator); $012B-$0132
are the INIT's variables: memory ID (word, 0), destination pointer (long, 0) and the size to
unpack ($7D08).

Relocation records after the packed area:

```
8033: F5 02 F0 43 00 F7 00          cRELOC: 2 bytes at seg $0043, shift -16, value $00F7
803A: F5 02 F0 4C 00 F1 00          cRELOC: 2 bytes at seg $004C, shift -16, value $00F1
8041: F5 02 F0 52 00 F5 00          cRELOC: 2 bytes at seg $0052, shift -16, value $00F5
8048: F7 08 00 00 00 00 05 19 3A 3F 46 4F 55
                                    SUPER RELOC2: page 0, 6 offsets $19 $3A $3F $46 $4F $55
8055: F7 03 00 00 00 01 00 01       SUPER RELOC3: page 0, 1 offset $01
805D: 00                            END
```

The packed area: SC hands PackBytes (Miscellaneous Tool Set $2603) the 32008-byte message in one
call with an output buffer of $7F00 bytes; the worst case (32008 + 501 flag bytes) fits. The bytes
after the packed stream are zero in a freshly loaded DYNAMDESK; because the segment is only
unloaded (not necessarily purged) after a save, a second save in the same session may leave bytes
of the previous packed stream there (uncertain). UnPackBytes stops after 32008 output bytes, so
they do no harm. To match SC byte for byte, call the PackBytes tool with the same arguments; any
correct PackBytes stream works for the INIT.

### 2.5 The INIT code (what it does at startup)

At boot, GS/OS loads the files in SYSTEM:SYSTEM.SETUP; a file of type $B7 is loaded, called with
JSL, and removed again. Listing in segment offsets (file offset = segment offset + $3C);
"r" marks a relocated operand:

```
0000  8F EF 00 00  STA >$0000EF       r   save A (the INIT's memory ID (uncertain)) at $EF
0004  3B 38 E9 04 00 1B 0B 1A 5B          4 bytes of locals as direct page
000D  8B 4B AB     PHB / PHK / PLB
0010  48 48        result space
0012  F4 00 00 F4 08 7D                   size $00007D08
0018  AD EF 00 48  LDA $00EF / PHA    r   memory ID
001C  F4 00 C0                            attributes $C000 (locked, fixed)
001F  F4 00 00 F4 00 00                   location 0
0025  A2 02 09 22 00 00 E1                NewHandle
002C  68 85 00 68 85 02                   handle -> dp $00
0032  B0 47        BCS $007B              error: return
0034  A0 02 00 A7 00 8D F1 00 B7 00 8D F3 00   r   $F1/$F3 = *handle
0041  48                                  result space
0042  F4 F7 00 F4 F7 00               r   packed data: pointer to $00F7 (bank, offset)
0048  F4 00 7F                            packed size $7F00
004B  F4 F1 00 F4 F1 00               r   pointer to $00F1 (destination pointer)
0051  F4 F5 00 F4 F5 00               r   pointer to $00F5 (size, $7D08)
0057  A2 03 27 22 00 00 E1                UnPackBytes
005E  68
005F  F4 01 00 F4 02 00 D4 02 D4 00       action 1 (add), type 2, handle
0069  A2 01 15 22 00 00 E1                MessageCenter
0070  D4 02 D4 00 A2 02 10 22 00 00 E1    DisposeHandle(handle)
007B  AB 2B A8                            PLB / PLD / TAY (A = last error)
007E  A3 06 83 06 A3 05 83 05             (no parameters to remove)
0086  3B 18 69 04 00 1B 98 C9 01 00 6B    drop locals; carry set if error; RTL
0091  "Desktop background INIT copyright 1990 Jason Harper. Files generated are freely distributable."
00EF  word   memory ID
00F1  long   destination pointer
00F5  word   $7D08, size to unpack
00F7  ...    packed message ($7F00 bytes)
```

So at startup the INIT allocates 32008 bytes, unpacks the message into them, adds it to the
Message Center as message type 2 (the Message Center keeps its own copy, since the handle is
disposed right after), and returns. Programs that start the Window Manager then use this message
as their desktop (help text; SC's own "Use as desktop background" relies on the same message,
2.7). The INIT does not look at the machine, the mode or any other file.

For MegaconvertGS the template can be copied as it is (it contains the original author's notice),
or replaced by an equivalent INIT that performs the same three calls; the Window Manager only
sees the message.

### 2.6 Size and warning choices

- Size dialog "Select size of saved picture" (superconvert-ui-data.md 9.3): only button 2 "Same
  as original" is enabled and it is the default; the user can still cancel.
- Warning check over all lines (bit 2 only): if any SCB selects a palette other than 0, the alert
  "Can't save, the specified format cannot handle: => Multiple color palettes." appears with
  "Cancel save" and "Save anyway, AT YOUR OWN RISK". No warning for mode, width or height: larger
  pictures are silently cut (2.3).
- The routine uses the screen image as it is when it runs (MAINE $00E8 bytes per line, $00EE
  lines, buffer at direct page $14), after the common save steps.

### 2.7 Related menu items (not a file format)

- Screen > "Use as desktop background" ($0118, LONGCODE $EA3D [UseAsDesk]): makes a screen image
  if needed (FRED $C1FB [MakeScreen]), builds the same message with CreateDesk (SysBeep on
  failure), MessageCenter(1 add, 2, h), DisposeHandle, then LONGCODE $EB9E [NewDeskMsg]:
  Desktop($0008, 0) and Desktop($0005, Desktop($0004, 0)) (taken to be "check for a new desktop
  message" and "set the desktop pattern to the current one", which redraws the desktop
  (uncertain)); then LONGCODE $E920 [CheckDesk].
- "Revert to normal desktop" ($0127, LONGCODE $E997 [RevertDesk]): adds a 40-byte type 2 message
  (+6 = $0000, 32 bytes of $DD), calls Desktop($0008, 0), deletes type 2 messages
  (MessageCenter(3, 2, 0)), NewDeskMsg, and disables the item.
- [CheckDesk] (at start-up, after "Use as desktop background" and after the full-screen views):
  MessageCenter(2 get, 2, h) into an empty handle; enables $0127 if a type 2 message exists (or
  the call ran out of memory, $0201), else disables it.

## 3. New Print Shop graphics

Load record MAINE $3166 (file $139A3), computer type 0, entry 5:

```
$3166 80320000 00 01 F5 F5 00000000 01000000 FFFFFF00 0030 FF5F 00000000 98320000
```

| Field | Value |
|---|---|
| Name | "New Print Shop graphics" (MAINE $3280) |
| Kind / icon | 1, screen image |
| File type | $F5 only |
| Aux type | $3000-$5FFF |
| EOF | 1 - $FFFFFF |
| Mac type | none |
| Loader | 0 (none) |
| Help tag | "LFNPS" |

Behaviour: File > Load & convert tests the loader field before the file dialog (MAINE $4312: the
word at +25 of the record is 0) and shows the common alert with X = $0C:

```
I am having a hard time converting the file:
Error code is $B0B0: This format has not been implemented yet.     [Continue]
```

(the file name line is a single space). No file is opened. "Info on format" works as for any other
format. Help topic LFNPS:

```
Format: New Print Shop graphics
Machines: Apple IIs with 128K
Programs: New Print Shop (not the original Print Shop or Print Shop IIgs)

New Print Shop graphics from other machines are NOT compatible.
```

GS Remap only notes that the loader field is zero (docs/RE-NOTES.md) and lists the format as not
ported (README). No other material at hand describes the file layout. Published descriptions of
Print Shop graphics cover the original Print Shop (88 × 52 pixels, 11 bytes per row, 572 bytes of
bitmap, usually in a 576-byte file) and Print Shop GS (type $F8, aux $C313 monochrome 572 bytes,
aux $C323 colour 1716 bytes, which SC loads as "Print Shop IIgs color graphic"). A converter note
on appleoldies.ca (Mini2Rag) states that "NPS compatible" single graphics are 605 bytes, a 33-byte
header followed by the 572-byte bitmap; it does not give the file type, the header contents, or
the layout of the library files that the $F5 / $3000-$5FFF record suggests. Treat all of this as
unverified: sample New Print Shop disks are needed before implementing anything. Until then
MegaconvertGS should behave as SC does. (MegaconvertGS has since left the entry out of
its Load formats list altogether.)

## 4. Babelfish imports and exports

### 4.1 Records and dispatch

| List | Entry | Name | Kind | Type word | Other fields |
|---|---|---|---|---|---|
| Load, computer type 9 "External (Babelfish™)" | 0 (MAINE $3EB2) | "Babelfish™ True Color Import" | 2 true color | $FFFE | loader MAINE $824C, help "LFBABELTRUE" |
| Load, type 9 | 1 (MAINE $3ED2) | "Babelfish™ PixelMap Import" | 1 screen | $FFFD | loader MAINE $824C, help "LFBABELPIXEL" |
| Save | 12 (MAINE $9024) | "Babelfish™ True Color Export" | 2 true color | $FFFE | no suffix, no sizes, no routines, help "SFBABELTRUE" |
| Save | 13 (MAINE $904A) | "Babelfish™ PixelMap Export" | 1 screen | $FFFD | help "SFBABELPIXEL" |

The loader field of the two load records holds the GIF loader (MAINE $824C) only so that the
"not implemented" test (section 3) passes; it is never called. The type word is tested first:

Load (MAINE $4302): after the format is chosen and the loader test passes, before any file
dialog:

```
type $FFFD: enable "Re-convert last file" ($0114); watch cursor; close the image window
            (all images discarded, MAINE $4217); UpdateAll;
            r = FRED $D4E5 [babelfish_load_pixelmap](screen buffer pointer)
type $FFFE: watch cursor; close the image window; UpdateAll;
            r = FRED $D79A [babelfish_load_truecolor]()
r == 0: continue as after a normal load (MAINE $45D4: show the image; Remap dialog for a true
        color image depending on the preferences)
r != 0: stop the watch cursor, discard the true color and monochrome images, no message
```

So the current image is lost even if the user cancels in Babelfish's dialog. Only the PixelMap
import enables "Re-convert last file".

Save (MAINE $95A7): after the common "make the needed image" step (kind 1: a screen image is made
if missing; kind 2: nothing is made when a screen image exists, see 4.7), before the size dialog,
the warnings, the suffix and the Save dialog:

```
type $FFFD: FRED $D19D [babelfish_save_pixelmap](screen buffer pointer, image name)
type $FFFE: FRED $D2EF [babelfish_save_truecolor](image name)
then UpdateAll; the result is ignored
```

The image name is the Pascal string at MAINE $9498 (the image's name, up to 31 characters, no
suffix).

Help topics LFBABELTRUE, LFBABELPIXEL, SFBABELTRUE, SFBABELPIXEL (summary): Babelfish is a Seven
Hills product, a set of plug-in translators that applications use to import and export data. The
True Color import gives a 24-bit picture of any size; the PixelMap import gives a standard IIgs
screen (320 × 200 × 16 or 640 × 200 × 4, up to 16 palettes, mixed modes), with any conversion
done by Babelfish, not SC. The exports hand Babelfish SC's true color picture or its IIgs screen.

### 4.2 How SC talks to Babelfish

All communication is with the Tool Locator's SendRequest ($1C01, System 6):

```
SendRequest(reqCode, sendHow = $8001, target = pointer to "Seven Hills~Babelfish~",
            dataIn, dataOut)
```

- sendHow $8001 = stop after one + send to name: the request goes to the first request procedure
  registered under the name, the Pascal string FRED $EE88 (file $3176C) $16 "Seven
  Hills~Babelfish~".
- dataIn is a 32-bit value, in every request here an address of a block in SC.
- dataOut points to a reply block. The Tool Locator puts the number of procedures that took the
  request in its first word; Babelfish's result is the second word (0 = OK). Blocks larger than
  that are noted below.
- When SendRequest itself fails (carry set, for example nobody has that name), SC sets the result
  to $FFFF unless Babelfish already stored a non-zero result.

Request codes as SC uses them (names are descriptions of the use, not Babelfish's own names
(uncertain)):

| Code | Used for | dataIn | dataOut |
|---|---|---|---|
| $9001 | start Babelfish | address of SC's memory ID word (MAINE $00A0) | FRED $EE82: count, result, size of the translation record |
| $9002 | shut down (at Quit) | address of MAINE $00A0 | FRED $EE82 |
| $9012 | import: Babelfish's open dialog | FRED $EB1A (import block) | FRED $EB26: count, result |
| $9013 | import: start | FRED $EB1A | FRED $EB26 |
| $9014 | import: get data | address of a long holding the TR pointer | count, result |
| $9015 | export: Babelfish's save dialog | FRED $ECBA (export block) | FRED $ECEB: count, result |
| $9016 | export: start | FRED $ECBA | FRED $ECEB |
| $9017 | export: send data / finish | address of a long holding the TR pointer | count, result |

### 4.3 Start-up and shut-down (FRED $ED07 [setup_babelfish], FRED $EE40)

Every import and export calls setup_babelfish first; it returns 0 when Babelfish is ready:

```
clear the SF reply handles nameRef and pathRef (FRED $ECFD, $ED03)
if already started (FRED $EE7C != 0): return 0
WaitCursor
w = NewWindow2(0, 0, FRED $EE2E (DrawControls), 0, 2, rWindParam1 1, $800E)   ; "Loading Babelfish..."
draw its controls
SendRequest($9001, $8001, name, address of MAINE $00A0, FRED $EE82)
CloseWindow(w)
if SendRequest failed or reply result (FRED $EE84) != 0:
    result = $FFFF if it was 0
    InitCursor
    AlertWindow($0024, 0, 1)          ; rAlertString 1
    return result
TR handle (FRED $ECEF) = NewHandle(reply word +4 (FRED $EE86), SC's ID, $C008, 0)
                                       ; locked, fixed, not crossing a bank; no error check
InitCursor; started = 1; return 0
```

The "Loading Babelfish..." window is rWindParam1 1 (superconvert-ui-data.md 11.1): position
97,220,112,417, frame $206D, one static text "Loading Babelfish..." at 3,2,13,194. It is up only
while the $9001 request runs, which is when Babelfish loads itself.

The alert is rAlertString 1: `22/Unable to startup Babelfish./^#1` (size code 2, icon code 2,
one button: standard button 1, "Cancel", default). AlertWindow flags $0024 are the ones SC uses
for every rAlertString alert (bits 2-1 = 10: the string is a resource ID). After a failed start
the operation stops with no other message; the next import or export tries again.

Shut-down, FRED $EE40, called while quitting (MAINE $08DE): if started,
SendRequest($9002, $8001, name, address of MAINE $00A0, FRED $EE82), DisposeHandle(TR), started
= 0.

### 4.4 Translation record (TR)

A block allocated by SC with the size Babelfish returns from $9001; SC uses the first $28 bytes:

| Offset | Size | Written by | Meaning |
|---|---|---|---|
| +$00 | 2 | SC | $000C |
| +$02 | 2 | SC 0, then Babelfish | status. After $9012/$9015: $8001 = the user cancelled. During an import: 0 = more data to come, non-zero = finished. SC sets $8000 before the last $9017 of an export |
| +$04 | 2 | SC | step: $0007 before $9012, $0003 before $9013, $000E before $9015, $000B before $9016 |
| +$06 | 2 | SC | data kind: 2 = pixel map, 4 = true color |
| +$08-$1B | | SC (0) | not used by SC |
| +$1C | 4 | Babelfish (import), SC (export) | pointer to the data record (4.8) |
| +$20 | 4 | SC | pointer to the chosen pathname: the GS/OS string (length word, characters) in the reply's pathRef handle |
| +$24 | 4 | SC | pointer to the chosen file name as a Pascal string (see 4.5) |

### 4.5 Choosing the file (FRED $E96F [babelfish_getfile](kind), FRED $EB2A [babelfish_putfile](kind, name, data record))

Import block FRED $EB1A (file $313FE), the dataIn of $9012 and $9013:

| Offset | Size | Content |
|---|---|---|
| +0 | 4 | TR pointer (the TR handle dereferenced) |
| +4 | 4 | 0 |
| +8 | 4 | pointer to the SF reply record FRED $ECF3 |

Export block FRED $ECBA (file $3159E), the dataIn of $9015 and $9016:

| Offset | Size | Content |
|---|---|---|
| +0 | 4 | TR pointer |
| +4 | 4 | pointer to the prompt block FRED $ECC6 |
| +8 | 4 | pointer to the SF reply record FRED $ECF3 |

Prompt block FRED $ECC6: word $0003 (perhaps the number of pointers that follow (uncertain)),
pointer to the Pascal string "Export the graphic as:" (FRED $ECD4), long 0, pointer to the default
name (the image name, set on each call).

SF reply record FRED $ECF3 (file $315D7), laid out as Standard File's SFReplyRec2: good (2),
fileType (2), auxFileType (4), nameDesc = 3, nameRef (4), pathDesc = 3, pathRef (4). The 3s mean
"give me new handles"; Babelfish fills in the handles, SC disposes of both at the end of every
import or export, also after errors.

```
getfile(kind):                                   ; putfile is the same with the export block
    TR+0 = $000C; TR+2 = 0; TR+4 = 7 (import) or $000E (export); TR+6 = kind; TR+8..$27 = 0
    putfile only: TR+$1C = data record pointer
    SendRequest($9012 / $9015 ...)               ; Babelfish shows its dialog
    if failed or result != 0: return result (or $FFFF)
    if TR+2 == $8001: return $FFFE               ; cancelled
    HLock(pathRef); TR+$20 = *pathRef + 2        ; GS/OS string after the buffer size word
    HLock(nameRef); p = *nameRef + 2             ; length word of the name
    swap the two bytes of the length word in place; TR+$24 = p + 1
                                                  ; = length byte + characters: a Pascal string
    getfile only: image name MAINE $3F61 = the name, cut to 31 characters (32 or more: 31 with
                  the last one replaced by $C9, an ellipsis)
    TR+4 = 3 (import) or $000B (export)
    SendRequest($9013 / $9016 ...)
    return result (0 = OK)
```

### 4.6 Import (FRED $D4E5, FRED $D79A)

PixelMap import:

```
if setup_babelfish() != 0 or getfile(2) != 0: fail
WaitCursor
while TR+2 == 0: SendRequest($9014 ...); fail on error
InitCursor
R = TR+$1C                                        ; pixel map record (4.8)
L = R+2 (LocInfo), pixels = *(R+14)               ; the LocInfo's own pixel pointer is not used
SCBs     = (R+18 != 0) ? *(R+18) : R+6
palettes = (R+22 != 0) ? *(R+22) : R+10
lines = min(L.bottom - L.top, 400); width = L.width (bytes per row)
while MAINE $4E16(L.portSCB, width, lines) fails: width -= 1   ; at most 320 bytes, 65536 bytes in all
copy lines rows of width bytes (source rows L.width apart) into the screen buffer
BlockMove 400 bytes from SCBs to MAINE $02FA; BlockMove 512 bytes from palettes to MAINE $00FA
DisposeHandle(R+14), DisposeHandle(R+18), DisposeHandle(R+22)
return 0
```

SC always copies 400 SCBs and 16 palettes, so Babelfish must supply that much (uncertain whether
it always does). The whole picture arrives at once, with the reply to the last $9014.

True color import:

```
if setup_babelfish() != 0 or getfile(4) != 0: fail
first = true; row = 0
WaitCursor
loop:
    if TR+2 != 0: InitCursor; return 0            ; finished
    SendRequest($9014 ...); fail on error
    R = TR+$1C                                    ; true color block record (4.8)
    data = (R+12 != 0) ? *(R+12) : R+8
    if first: first = false
        SetMapSize(R+2 width, R+4 height)         ; LONGCODE $AFA9: 1-2000 each, else $FF02
        if it fails: DisposeHandle(R+12); fail
        remap mode LONGCODE $0F31 = 0
    repeat R+6 times:                             ; rows in this block
        line = GetMapLine(row)                    ; LONGCODE $B090
        if line exists: convert width pixels, 3 bytes each, from data (data advances)
        row += 1
    DisposeHandle(R+12)
```

RGB to true color pixel word (FRED $D8F5; R, G, B are 8-bit):

```
if R == G == B: w = $8000 | R                      ; gray, 8 bits kept
else: w = ((R >> 4) << 8) | (G & $F0) | (B >> 4)
        | ((R & 8) << 11) | ((G & 8) << 10) | ((B & 8) << 9)   ; bits 14, 13, 12 = fifth bits
```

(superconvert-image-window.md 1.2: each colour channel keeps its top 5 bits.) The true color
pixel size (320/640-sized) is not changed by the import.

### 4.7 Export (FRED $D19D, FRED $D2EF)

PixelMap export:

```
if setup_babelfish() != 0: fail
LocInfo FRED $D2DF = (portSCB MAINE $00F2 ($80 when the first line is 640 mode, else 0),
                      screen buffer pointer, width MAINE $00E8 (bytes per line),
                      boundsRect 0, 0, MAINE $00EE (lines), MAINE $00F0 (bytes x 4))
if putfile(2, name, FRED $D2C1) != 0: fail        ; pixel map record (4.8)
WaitCursor
SendRequest($9017 ...)                            ; Babelfish takes the picture
TR+2 = $8000; SendRequest($9017 ...)              ; finish
InitCursor; return 0                              ; results of the two $9017 calls ignored
```

True color export:

```
if setup_babelfish() != 0: fail
record FRED $D4D1: +2 = width (LONGCODE $0F3F), +4 = height (LONGCODE $0F41)
left = height
if putfile(4, name, FRED $D4D1) != 0: fail
WaitCursor
src = *(LONGCODE $0F21)                           ; true color pixels, 2 bytes each
repeat:
    n = min(left, 3); left -= n; record +6 = n
    convert width * n pixel words (16-bit product) to RGB at LONGCODE $4F88   ; record +8
    SendRequest($9017 ...)
until left == 0 or (the request failed and its result != 0)
TR+2 = $8000; SendRequest($9017 ...)              ; finish
InitCursor; return 0
```

True color pixel word to RGB (FRED $D3B7):

```
if w & $8000: R = G = B = w & $FF                  ; gray
else: R = ((w >> 4) & $F0) | ((w >> 11) & 8)       ; top 4 bits | fifth bit (bit 14)
      G = (w & $F0)        | ((w >> 10) & 8)       ; bit 13
      B = ((w << 4) & $F0) | ((w >> 9) & 8)        ; bit 12
```

So a colour channel c (0-31) is sent as c << 3 (white $7FFF gives $F8 $F8 $F8); grays are exact.

Notes (from the code; not tried with Babelfish):

- The RGB buffer for 3 rows of a 2000-pixel image is 18000 bytes, inside the LONGCODE $4F88 area
  (1.2).
- The true color export does not make a true color image. The common save step only makes sure
  some image exists, so with only a screen image the routine reads whatever LONGCODE $0F21,
  $0F3F, $0F41 still hold (stale or purged) (uncertain; MegaconvertGS should make the true color
  image first, as Screen > Convert to true color does).

### 4.8 Data records

Pixel map record (export: FRED $D2C1, file $2FBA5; import: TR+$1C), 26 bytes:

| Offset | Size | Export (SC fills) | Import (SC reads) |
|---|---|---|---|
| +0 | 2 | $0008 | not read |
| +2 | 4 | pointer to the LocInfo FRED $D2DF | pointer to a LocInfo (portSCB, width and boundsRect are used) |
| +6 | 4 | pointer to the SCBs, MAINE $02FA (400 bytes) | pointer to the SCBs, used when +18 is 0 |
| +10 | 4 | pointer to the palettes, MAINE $00FA (512 bytes) | pointer to the palettes, used when +22 is 0 |
| +14 | 4 | 0 | handle to the pixel image (required); disposed by SC |
| +18 | 4 | 0 | handle to the SCBs or 0; disposed by SC |
| +22 | 4 | 0 | handle to the palettes or 0; disposed by SC |

LocInfo (QuickDraw II): portSCB (2), ptrToPixImage (4), width in bytes (2), boundsRect top, left,
bottom, right (4 words).

True color block record (export: FRED $D4D1, file $2FDB5; import: TR+$1C), 16 bytes:

| Offset | Size | Export | Import |
|---|---|---|---|
| +0 | 2 | $0007 | not read |
| +2 | 2 | width in pixels | width (used from the first block) |
| +4 | 2 | height in pixels | height (used from the first block) |
| +6 | 2 | rows in this block (1-3) | rows in this block |
| +8 | 4 | pointer to the RGB rows (LONGCODE $4F88) | pointer to the RGB rows, used when +12 is 0 |
| +12 | 4 | 0 | handle to the RGB rows or 0; disposed by SC after each block |

RGB rows: 3 bytes per pixel in the order R, G, B (8 bits each), rows packed with no padding, top
row first.

### 4.9 Messages

| Situation | What the user sees |
|---|---|
| Babelfish not installed or start fails | "Loading Babelfish..." briefly, then the alert "Unable to startup Babelfish." [Cancel] |
| Cancel in Babelfish's dialog | nothing (for an import, the previous image is gone) |
| Any other failure of import or export | nothing from SC (Babelfish may report its own errors (uncertain)) |
| True color import larger than 2000 × 2000 | nothing (SetMapSize returns $FF02, the import fails silently) |
| Not enough memory for the true color image | SetMapSize's memory handling (purge, close NDAs, the memory dialog OSAYCANYOU $7A27) |

Export dialog prompt (given to Babelfish): "Export the graphic as:".

### 4.10 What MegaconvertGS would need

1. Babelfish installed on the IIgs (System 6, Tool Locator with SendRequest). Without it the only
   reachable path is the start-up failure, which can be tested now: the "Loading Babelfish..."
   window and the "Unable to startup Babelfish." alert.
2. The four entries dispatched by their type words before the usual load and save steps: no
   file dialog of our own, no size dialog, no warnings, no suffix; the image name as default name.
3. A start routine (once per session) that sends $9001, allocates the TR with the returned size
   ($C008), and a $9002 at quit.
4. getfile / putfile with the import / export blocks, the SFReplyRec2 (nameDesc = pathDesc = 3),
   the TR fields of 4.4 and the name trick of 4.5; dispose of nameRef and pathRef afterwards.
5. Import: the $9014 loop; pixel maps copied into the screen image (with the 320-byte / 400-line /
   64 KB limits), SCBs and palettes; true color blocks converted row by row with 4.6's formula.
6. Export: the LocInfo-based pixel map record; true color sent in blocks of up to 3 rows of RGB
   with 4.7's formula, then the closing $9017 with TR+2 = $8000.
7. Testing against the real Babelfish: the request meanings and several fields above were read
   from how SC uses them, not from Babelfish documentation. If Babelfish cannot be obtained, keep
   the entries listed and show the start-up alert.

Improvements over the original worth considering: discard the current image only after a
successful import; enable "Re-convert last file" for both imports; make the true color image before
a true color export.

## 5. Uncertain points

- Works of Art: only the header bytes 5-6, $0B-$0C and $0D, the directory words +0, +2, +8, the
  chunk types listed and the page header are known from the code; the other bytes, the meaning of
  the name list's third byte, and whether real files have other chunks were not seen. No real
  Springboard Publisher file was examined; the test file in 1.11 was built from this description
  and checked with a decoder written from the 65816 code, not with SC itself.
- Works of Art: whether set bits are paper or ink in the original program; whether real pages
  leave the bits for x ≥ 270 clear; whether the list control lets the user deselect all names.
- Works of Art: buffer sizes (LONGCODE $4F88 area 18434 bytes, MAINE $4017 area 512 bytes) are
  taken from the extent of the zero-filled areas in the file.
- Works of Art Tab key: the conclusion that it never works after the image is drawn comes from
  reading FRED $B410 and MAINE $EE00; it was not tried on a machine.
- Desktop INIT: that A holds the INIT's memory ID on entry; that the Message Center copies the
  message; that the Window Manager reads message type 2 with +6 = 1 as a 32000-byte picture and
  +6 = 0 as a 32-byte pattern (read from SC's own use and the help text); the meanings of
  Desktop commands $0004, $0005 and $0008; leftovers after the packed stream on a second save.
- New Print Shop: no description of the $F5 files was found; the 605-byte figure comes from a
  third-party converter note.
- Babelfish: request names, the meaning of TR+0, TR+4 and the export prompt block's first word,
  whether $9001 expects the memory ID or its address (SC passes the address of MAINE $00A0),
  whether Babelfish supplies 400 SCBs and 16 palettes for a pixel map, and Babelfish's own error
  reporting. The caption of standard button 1 ("Cancel") and the icon code are taken from the
  Window Manager's conventions.
