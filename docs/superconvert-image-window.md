# SuperConvert 4 screen image window

How the original SuperConvert 4.0 shows and handles its image window (the "Screen image"
window), read from the program code in the data fork. This adds to
`superconvert-ui-data.md`, which already has the window template (5.1), the title format
(5.2), the info bar layout, icons and click zones (5.3), the list icons (6) and the texts of
the info bar pop-up menus (10.4). Those are not repeated here. Section 13 lists the points
where that document needs correcting.

Conventions are those of `superconvert-ui-data.md`. Code addresses are given as segment name
and offset: MAINE (segment 5), FRED (6), LONGCODE (8), OSAYCANYOU (9), SUPERFX (10). Many
routines start with their own name in the code (a name header after the entry BRL); the name
is given in square brackets, for example FRED $9D4D [ImgChanged]. Tables also have their data
fork file offset. A "column" is one 640-mode pixel column of the desktop. Rectangles are top,
left, bottom, right.

## Contents

- 1. Image state
- 2. Image units and zoom
- 3. NewImgType and ImgChanged
- 4. Drawing the content
- 5. Title and info bar text
- 6. Mouse in the content
- 7. Info bar pop-up menus
- 8. Keys
- 9. Which image type is shown after each command
- 10. Full-screen views
- 11. Other window behaviour
- 12. Data tables
- 13. Corrections to superconvert-ui-data.md
- 14. Uncertain points

## 1. Image state

### 1.1 Variables

| Address | Meaning | Initial |
|---|---|---|
| MAINE $0528 | shown image type: 1 screen, 2 true color, 3 monochrome | 1 |
| MAINE $052C, $052E, $0530 | screen, true color, monochrome image exists (indexed $052A + 2 × type) | 0 |
| MAINE $0536, $0538, $053A | pixel size per type (indexed $0534 + 2 × type): 0 = 320-sized, 1 = 640-sized. The screen entry is never used | 0, 0, 1 |
| MAINE $00D0 | "Use image's palette" is on | 0 |
| MAINE $00D2 | the image's palettes are loaded in the hardware (4.6) | 0 |
| MAINE $00D4 | "Clicking sets VOC key color" is on | 0 |
| MAINE $00AE | Video Overlay Card tool set started (LONGCODE $E2D4 [InitVOC]) | |
| MAINE $053C | tool: 1 selection mode, 2 pixel peek mode | 1 |
| MAINE $053E | "Menu item help" mode; pop-up choices are ignored while it is set | 0 |
| MAINE $E16E | zoom level, signed: -3 = 1/8 shrink ... 0 = actual size ... 3 = 8X zoom | 0 |
| MAINE $E16A, $E16C | image width and height in image units (section 2) | |
| MAINE $E170, $E172 | zoomed width and height: Act2ZoomR($E16A), Act2ZoomR($E16C) | |
| MAINE $E174 | $E170 + 7, the data width given to the Window Manager | |
| MAINE $E176, $E178 | horizontal snap: half step and mask (6.2) | |
| MAINE $E17A, $E17C | vertical snap: half step and mask | |
| MAINE $E17E | the shown type has a selection; per-type copies at $E180 (screen), $E182 (true color), $E184 (monochrome) | 0 |
| MAINE $E186 | selection rectangle in content (zoomed) coordinates, 8 bytes | |
| MAINE $E18E | selection rectangle of the shown type in image units, 8 bytes; per-type copies at $E196 (screen), $E19E (true color), $E1A6 (monochrome). Without a selection it holds the whole image | |
| MAINE $E1AE | marching ants phase, 0-3 | 0 |
| MAINE $E1D2, $E1D4 | pixel peek point: x in image units, y in lines; $8000 = no point | |
| MAINE $00AC | current cursor code (6.1) | 0 |
| MAINE $F1D0 | set once the first pixel value has been shown; never cleared | 0 |

### 1.2 How the three images are stored

Screen image: the raw SHR bytes in one buffer (pointer at MAINE $00E4). A LocInfo at MAINE
$00E2 describes it for drawing: portSCB $0080 (640 mode, never changed), pointer, width =
bytes per line (MAINE $00E8), boundsRect 0, 0, lines (MAINE $00EE), bytes × 4 (MAINE $00F0).
The 16 palettes (32 bytes each) are at MAINE $00FA, one SCB per line at MAINE $02FA (up to
400). MAINE $00F2 = $80 when the first line is 640 mode; MAINE $00F4 = width in the image's own
pixels. MAINE $4E16 sets the size (bytes per line at most 320, lines at most 400, product at
most 65536); it also clears the screen selection flag ($E180) and sets $052C.

True color image: handle at LONGCODE $0F21, width LONGCODE $0F3F, height LONGCODE $0F41, one
16-bit word per pixel, rows packed (stride = width × 2). Pixel word:

- bit 15 = 1: gray; level = bits 7-0 (0-255).
- bit 15 = 0: bits 11-8, 7-4, 3-0 = top 4 bits of red, green, blue; bits 14, 13, 12 = the lowest
  (fifth) bit of red, green, blue. The low 12 bits are the IIgs colour $0RGB, and each component
  is 5 bits (0-31).

Monochrome image: width FRED $80E3, height FRED $80E5, bytes per row FRED $80E7; FRED $893A
[GetMonoLine] returns a row's address. One bit per pixel, bit 7 leftmost, 1 = white, 0 =
black (this is what the drawing and the pixel peek text show).

## 2. Image units and zoom

All window geometry is in image units: x counts 640-mode columns at actual size, y counts
lines.

| Shown type | Width in image units ($E16A) | Height ($E16C) | Selection step x |
|---|---|---|---|
| Screen | bytes per line × 4 ($00F0) | lines | 4 (one byte) |
| True color, 320-sized | width × 2 | height | 2 |
| True color, 640-sized | width | height | 1 |
| Monochrome, 320-sized | width × 2 | height | 2 |
| Monochrome, 640-sized | width | height | 1 |

So the raw bytes of a screen image always take one column per 640-mode pixel (a 320-mode pixel
takes two columns), and a true color or monochrome pixel takes two columns (320-sized) or one
(640-sized). Every line is one row.

For texts, image units are turned back into pixels by MAINE $F4CF: screen: x / 2 unless the
image has at least one 640-mode line ($048C, the 640-line count from the title routine, is not
0); true color and monochrome: x / 2 when 320-sized.

Zoom conversions, z = $E16E. "Act" is image units, "Zoom" is content coordinates.

```
Act2Zoom(a)   FRED $A0EB   z > 0: a << z      z < 0: a >> -z (arithmetic, rounds down)
Act2ZoomR(a)  FRED $A10D   z > 0: a << z      z < 0: repeat -z times a = (a >> 1) + (a & 1)  (rounds up)
Zoom2Act(a)   FRED $A12E   z > 0: a >> z (arithmetic)                 z < 0: a << -z
Zoom2ActR(a)  FRED $A150   z > 0: repeat z times a = (a >> 1) + (a & 1)    z < 0: a << -z
```

## 3. NewImgType and ImgChanged

FRED $9CDA [NewImgType] takes A = item number - 256 of info bar pop-up 1 (1-6). The zoom
pop-up, crops and the load routines also call it with the shown type to rebuild the window.

```
NewImgType(a):
  if a <= 3:                                   ; show type a
      shownType = a; ExitPals(); ImgChanged(); return
  if a == 6:                                   ; Use image's palette
      ExitPals(); usePal ^= 1; return          ; nothing is redrawn
  s = a - 4                                    ; 0 = 320-sized, 1 = 640-sized
  if pixelSize[shownType] == s: return
  pixelSize[shownType] = s
  if s == 0: storedSel[shownType].left *= 2; storedSel[shownType].right *= 2
  else:      storedSel[shownType].left /= 2; storedSel[shownType].right /= 2
  ImgChanged()
```

FRED $9D4D [ImgChanged] runs after every change of image, type, zoom or pixel size:

```
ImgChanged():
  if not exists[shownType]:
      shownType = first of 1, 2, 3 that exists       ; callers close the window when none is left
      NewImgType(shownType); return
  W, H = image size in image units (section 2); step = 4, 2 or 1
  maskX = Act2Zoom(-step); halfX = (-maskX) >> 1        ; $E178, $E176
  maskY = Act2Zoom(-1);    halfY = (-maskY) >> 1        ; $E17C, $E17A
  Wz = Act2ZoomR(W); Hz = Act2ZoomR(H)                  ; $E170, $E172
  SetDataSize(Wz + 7, Hz, window)
  hasSel = selFlag[shownType]
  if hasSel: selImg = storedSel[shownType]
  else:      selImg = storedSel[shownType] = (0, 0, H, W)
  selWin = (Act2Zoom(selImg.top), Act2Zoom(selImg.left), Act2ZoomR(selImg.bottom), Act2ZoomR(selImg.right))
  peek point = ($8000, $8000)
  build the title and SetWTitle (MAINE $4991, 5.1)
  DrawInfoBar(window)
  enable or disable menu items (table below)
  LONGCODE $0F77 = 0
  InvalRect(0, 0, 10000, 10000) in the window's port   ; whole content redrawn by the update event
```

Menu items set here (MAINE $2F04 enables the item when the flag is not 0, otherwise disables it):

| Items | Enabled when |
|---|---|
| $0109 Screen image info..., $0113 Convert to true color..., $0131 Convert to monochrome... (Screen menu), $012D Store palette | a screen image exists |
| $0116 Convert to screen (Remap)... | a screen or a true color image exists |
| $0123 True color image info..., $011F Convert to monochrome... (True color menu), $0130 View approximation | a true color image exists |
| $0132 Monochrome image info..., $010A Convert to screen..., $0133 Convert to true color... | a monochrome image exists |

The other items of these menus (the View items of the Screen menu, View interlaced on VOC, Use
as desktop background, Oscilloscope Art, Rotate/flip and the filters, Negative image) stay
enabled while the menus are enabled; they make the image they need first (sections 9 and 10).

Data size and origin: the data size is (Wz + 7) × Hz. The window was created with
SetOriginMask($FFF8), so the horizontal origin moves in steps of 8 columns; the extra 7 lets it
reach the last columns. The origin is set to (0, 0) when the window is shown after a load,
Remap or filter (MAINE $428F) and after Crop to selection. Changing the type, the zoom or the
pixel size keeps the current origin. Scroll arrows move 8 columns or 4 rows (template
wScrollHor, wScrollVer).

## 4. Drawing the content

### 4.1 Common part (MAINE $EA30, wContDefProc)

The Window Manager calls it for update events, so the port's visRgn is the area to redraw.

```
DrawContent():
  FillRect((0, Wz, Hz, 10000), BACK)        ; right of the picture
  FillRect((Hz, 0, 10000, 10000), BACK)      ; below the picture
  r = bounding box of the port's visRgn (content coordinates)
  top = Zoom2Act(r.top);   left = Zoom2Act(r.left) & $FFF0
  bottom = Zoom2ActR(r.bottom);   right = (Zoom2ActR(r.right) + 15) & $FFF0
  draw (top, left, bottom, right) of the shown type     ; 4.2-4.4
  if hasSel: SetPenSize(2, 1); SetPenMode(2 = XOR); SetPenPat(ANTS[phase]); FrameRect(selWin)
```

BACK is the pattern at OSAYCANYOU $312E (file $55E59): diagonal stripes, two columns white and
two black, shifted one column per row (# = pixel value 0, black; . = value 3, white):

```
##..##..
#..##..#
..##..##
.##..##.
(rows 4-7 repeat rows 0-3)
```

All patterns used by the window are 32 bytes long but only their first 16 bytes carry the
picture: 8 rows of 2 bytes (8 columns). BACK is 0F0F 3C3C F0F0 C3C3 0F0F 3C3C F0F0 C3C3 followed
by 16 zero bytes. The marching ants data (4.5) only works out with this reading.

All three image types end in CopyPixels (QuickDraw Auxiliary $0912) with a source rectangle in
image units and the destination rectangle (Act2Zoom(top), Act2Zoom(left), Act2ZoomR(bottom),
Act2ZoomR(right)), transfer mode 0 (copy), no mask region. Zooming in and shrinking are done
only by CopyPixels scaling 640-mode pixels; the program never averages pixels.

### 4.2 Screen image (MAINE $EAF2)

```
if lines < top: nothing to draw
bottom = min(bottom, lines)
if bytes*4 < left: nothing to draw
right = min(right, bytes*4)
CopyPixels(LocInfo MAINE $00E2, port, (top, left, bottom, right), zoomed rect, 0, nil)
```

The buffer is copied as it is, as 640-mode pixels, in the desktop's colours. Nothing is
converted: a 320-mode pixel value v (4 bits) shows as two columns, v >> 2 on the left and v & 3
on the right. With the standard 640 desktop palette the left column of each pair is black,
red, green or white and the right one black, blue, yellow or white:

| v | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | A | B | C | D | E | F |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| left column | K | K | K | K | R | R | R | R | G | G | G | G | W | W | W | W |
| right column | K | B | Y | W | K | B | Y | W | K | B | Y | W | K | B | Y | W |

(K black, R red, G green, B blue, Y yellow, W white.) A 640-mode line shows its own 2-bit
values. The image's palettes and SCBs are not used, except with "Use image's palette" (4.6).

### 4.3 True color image (MAINE $EBE5)

The visible part is converted to 640-mode pixels in strips of up to 32 rows, and each strip is
copied with CopyPixels.

```
bottom = min(bottom, height)
if bottom == top or top >= height: nothing to draw
Wu = 320-sized ? width*2 : width
if left >= Wu: nothing to draw
right = min(right, Wu)
first = 320-sized ? left : left*2          ; byte offset in a row, 2 bytes per pixel
last  = 320-sized ? right : right*2
rowBytes = ((right - left + 31) & ~31) / 4   ; strip bytes per row, a multiple of 8
rowsPerStrip = min(32, 16384 / rowBytes)
parity = (top & 1) << 12
line = top
repeat
    n = min(bottom - line, rowsPerStrip)
    for each of the n rows (true color rows line, line+1, ...):
        y = first               ; next() reads the pixel word at byte offset y, then y = y + 2
        do
            320-sized: b = (T(next()) & $F0) | (T(next()) & $0F)                                  ; 2 pixels
            640-sized: b = (T(next()) & $C0) | (T(next()) & $30) | (T(next()) & $0C) | (T(next()) & $03)  ; 4 pixels
            store b in the strip
        while y < last            ; tested after each byte
        parity ^= $1000
    CopyPixels({SCB $80, strip buffer LONGCODE $4F88, rowBytes, (line, left, line+n, right)},
               port, (line, left, line+n, right), zoomed rect, 0, nil)
    line = line + n
until line >= bottom

T(w):                                          ; MAINE $EDD5
    if w & $8000: g = (w >> 4) & 15; i = (g << 8) | (g << 4) | g    ; gray: top 4 bits as $0ggg
    else:         i = w & $0FFF
    return DITHER[parity | i]                  ; one byte
```

DITHER is a fixed table in the program: OSAYCANYOU $4F0F, 8192 bytes, file $57C3A-$59C39 (it
is not built at run time). Index = (image row & 1) × 4096 + $0RGB. Each entry is one 640-mode
byte, four 2-bit pixels, so every 12-bit colour has a pattern 4 columns wide and 2 rows high
in the standard 640 palette (columns 0 and 2 black/red/green/white, columns 1 and 3
black/blue/yellow/white). A pixel takes the part of its colour's pattern that falls on its own
columns: a 320-sized pixel in the left half of a byte takes bits 7-4, one in the right half
bits 3-0; a 640-sized pixel at position k (0-3) of the byte takes bits 7-2k and 6-2k. The row
parity is that of the image row, not of the screen line.

Copy the table as it is. Some entries (even row / odd row, columns 0-3; K R G W Y B as in 4.2):

| Colour | Pattern | Colour | Pattern |
|---|---|---|---|
| $000 | KKKK / KKKK | $F00 | RWRK / RKRK |
| $444 | WKKK / KKKK | $0F0 | GWGW / GKGW |
| $888 | WKKK / KKWK | $00F | WBKB / KBKB |
| $CCC | WWWK / WKWK | $FF0 | WYWY / WYWY |
| $FFF | WWWW / WWWW | $0FF | WWGB / GBWB |

On the gray ramp $000-$FFF the eight cells turn white in this order: row 0 column 0 at level
4, row 1 column 2 at 7, row 0 column 2 at 9, row 1 column 0 at $B, row 0 column 1 at $C, row 1
column 3 at $D, row 0 column 3 at $E, row 1 column 1 at $F (the order of the ordered-dither
matrix 0 4 2 6 / 3 7 1 5).

### 4.4 Monochrome image (MAINE $EE00)

The same strip scheme, with QuickDraw II's bit-to-pixel tables:

```
bottom = min(bottom, height); same tests as for true color
320-sized: Wu = width*2; conv = GetAddress(2); first = left / 16; last = (right + 15) / 16
640-sized: Wu = width;   conv = GetAddress(3); first = left / 8;  last = (right + 7) / 8
rowBytes, rowsPerStrip, strips as in 4.3
row address: GetMonoLine(first row of the strip), then + bytes per row for each further row
for y = first to last - 1:
    320-sized: copy the 4 bytes at conv + src[y] * 4    ; each bit gives a 4-bit pixel = 2 columns
    640-sized: copy the 2 bytes at conv + src[y] * 2    ; each bit gives a 2-bit pixel = 1 column
CopyPixels as in 4.3
```

A set bit becomes pixel value 3 (white in the desktop palette) and a clear bit 0 (black). There
is no dithering.

### 4.5 Selection frame and marching ants

The frame is FrameRect(selWin) with pen size 2 × 1, XOR mode and pen pattern ANTS[phase];
drawing it again with the same pattern removes it. On every null event (MAINE $0DB5 calls
MAINE $EFE3) and during a drag, once at least 6 ticks have passed since the last step, the
program does FrameRect(selWin) with pattern STEP[phase] (XOR) and then phase = (phase + 1) &
3. STEP[i] = ANTS[i] XOR ANTS[i + 1], so the frame turns into the next pattern in place.

ANTS[i] = OSAYCANYOU $4E8F + 32 × i, STEP[i] = OSAYCANYOU $4E9F + 32 × i (128 bytes from file
$57BBA; pointer tables MAINE $213E and MAINE $214E). In the pictures "." (value 3) inverts the
screen pixel and "#" leaves it:

```
ANTS[0]    ANTS[1]    ANTS[2]    ANTS[3]
####..##   ######..   ..######   ##..####
##..####   ####..##   ######..   ..######
..######   ##..####   ####..##   ######..
######..   ..######   ##..####   ####..##
(rows 4-7 repeat rows 0-3)
```

Each step moves the dashes two columns to the right.

### 4.6 Use image's palette

This only works for the screen image, only while "Use image's palette" is on, and only while
the pointer is over the image window's content.

MAINE $E1D6 runs before every TaskMaster call. It finds the window and part under the pointer:
wInContent of the image window calls EnterPals, anything else calls ExitPals. This happens
even when another window is in front, as long as the picture is the topmost thing under the
pointer. Choosing a menu (MAINE $0FC7) and NewImgType also call ExitPals.

```
EnterPals [FRED $9F92]:
  if loaded or shownType != 1 or not usePal: return
  loaded = usePal
  for p = 0 to highest palette number used ($048E): SetColorTable(15 - p, image palette p)
  ; continues into EnterScbs
EnterScbs [FRED $9FE0]:
  if not loaded or shownType != 1: return
  r = bounding box of the window's visRgn, also converted to global coordinates
  for each screen line y from the global top to the global bottom - 1:
      i = Zoom2Act(content line)                     ; image line shown there
      if i < lines: SetSCB(y, imageSCB[i] XOR $0F)
ExitPals [FRED $A0A6]:
  if not loaded: return
  loaded = 0
  InitColorTable(buffer); SetColorTable(0, buffer)    ; standard 640 colours back in table 0
  SetAllSCBs($80)
  InitPalette                                         ; Menu Manager
```

Image palette p goes to colour table 15 - p, and each image line's SCB gets 15 - p as its
palette number (the mode bits stay). So table 0 of the desktop survives unless the image uses
all 16 palettes. The screen lines of the window then show the raw bytes in the image's own
modes and colours, so at actual size the picture looks right. Everything else on those lines
(other windows, the desktop) is shown in the image's modes and palettes too. EnterScbs runs
again after keyboard positioning (8) and auto-scrolling (6.4). Lines of the window below the
picture keep SCB $80.

Because the window shows raw bytes as 640-mode columns, a zoom other than actual size repeats
or drops half-pixels of 320-mode lines, so their colours are wrong in that case (this follows
from the code).

## 5. Title and info bar text

### 5.1 Title (MAINE $4991)

Rebuilt by ImgChanged and when the window is shown. Format:

`" " + name + " (" + mode + "," + count + ") "`

- name: the loaded file's name (after the last colon), at most 31 characters; a longer name is
  cut to 31 characters and the last one becomes "…" ($C9).
- mode: "320" if every line is 320 mode, "640" if every line is 640 mode, "Mix" otherwise.
- count: the highest palette number used by any line, plus 1, as two characters right-aligned
  (" 1" to "16"). It is not the number of different palettes: an image using only palette 5
  shows "6".
- without a screen image: `" NAME (???) "` (three question marks).

Examples: `" PICTURE (320, 1) "`, `" PICTURE (Mix,16) "`.

The title depends only on the screen image, not on the shown type. While building it the routine
also clears bits 15-12 of every palette entry, clears SCB bit 6 on all lines and bit 5 (fill
mode) on 640-mode lines; if a 320-mode line uses fill mode it converts the image once (LONGCODE
$E400 [UnFillIt]).

### 5.2 How the text is built

The info bar text (MAINE $F29F, buffer MAINE $4017) is put together from pieces that carry a
level. The text is built for level 0; if it does not fit it is built again for level 1, and so
on. A piece marked "≤ n" is used at levels 0 to n, one marked "= n" only at level n. The test
after each build (MAINE $F47F): level = level + 1; if level ≥ the last level, draw; else if
CStringWidth(text) + info left + 142 < info right, draw; else build again. So the last variant
is drawn even when it does not fit (the info bar clips it). The text is drawn with DrawCString
at (info left + 142, info top + 8), black on white, copy mode. When only the text is redrawn
(MAINE $F1D2: after a peek or a selection change), the area from the pen position after the
text to the right edge is erased.

Numbers are decimal without leading spaces or zeros.

### 5.3 Image text (selection mode, no selection)

| Level | Text |
|---|---|
| 0 and 1 | `Screen image: 320 x 200`, `True color image: 640 x 480`, `Monochrome image: 576 x 720` |
| 2 | `Image: 320 x 200` |
| 3 | `320 x 200` |

W and H are in the image's own pixels (W converted as in section 2, H = lines).

### 5.4 Selection text (selection mode, the shown type has a selection)

| Level | Text |
|---|---|
| 0 | `Selection: W x H   (T, L, B, R)` (three spaces before the parenthesis) |
| 1 and 2 | `Selection: W x H` |
| 3 | `W x H` |

W = right - left and H = bottom - top of the shown type's selection; T, L, B, R are its top,
left, bottom and right, in that order. L, R and W are converted to pixels as in section 2; T, B
and H are lines.

### 5.5 Pixel peek text (pixel peek mode)

No point yet (ImgChanged clears the point): while no value has been shown since the program
started, level 0 `Click in image to view pixel values`, level 1 `Click in image`. After the
first value has been shown ($F1D0 = 1), a single space instead.

With a point (x converted as in section 2, y = line):

| Level | Screen image | True color, colour pixel | True color, gray pixel | Monochrome |
|---|---|---|---|---|
| 0 | `x,y    Palette p  Index i  Color $RGB` | `x,y    Red r  Green g  Blue b` | `x,y    Gray n` | `x,y    White` |
| 1 | `x,y    Pp  Ii  $RGB` | `x,y    Rr  Gg  Bb` | `x,y    Gray n` | `x,y    White` |
| 2 | `Pp  Ii  $RGB` | `Rr  Gg  Bb` | `Gray n` | `White` |

There are four spaces after "x,y" and two between the parts.

- Screen image (MAINE $F4F2): SCB = image SCB of line y, p = SCB & 15. Byte = row[x / 4] (x in
  columns). 320-mode line: i = high nibble if (x & 2) = 0, otherwise low nibble. 640-mode line:
  v = 2-bit value at position x & 3 (position 0 = bits 7-6); i is shown as v followed by "e" for
  positions 0 and 2 or "o" for positions 1 and 3 (for example `Index 2o`); the colour is
  entry 4 × (x & 3) + v of palette p. Colour: the palette entry as three hex digits.
- True color (MAINE $F6AE): gray pixel: n = w & $FF. Colour pixel: r = ((w >> 8) & 15) × 2 +
  bit 14, g = ((w >> 4) & 15) × 2 + bit 13, b = (w & 15) × 2 + bit 12 (0-31 each).
- Monochrome (MAINE $F66D): bit of byte x / 8 in the row, mask from MAINE $F665 ($80, $40 ...
  $01 for x & 7): 1 = "White", 0 = "Black".

If "Clicking sets VOC key color" is on, every screen image peek also calls Video Overlay Card
tool $0F21 with three words: the colour's red, green and blue nibbles, each in bits 15-12 (red
pushed first).

## 6. Mouse in the content

### 6.1 Cursors (MAINE $E1D6)

On every main loop pass, before TaskMaster:

```
GetNextEvent(0, ev)                       ; only for the pointer position
part, w = FindWindow(ev.where)
palettes: EnterPals or ExitPals (4.6)
if part != wInContent or w != image window or w != FrontWindow: code = 0
elif tool == pixel peek: code = 10
elif no selection:       code = 11
else:                    code = CODES[vzone + hzone]
if code != current code: set it; code 0: InitCursor, else SetCursor(rCursor CURSOR[code])
```

Zones, with the pointer (v, h) and selWin, in content coordinates:

- hzone: 1 if -6 ≤ h - left < 6; otherwise 3 if -6 ≤ h - right < 6; otherwise 2 if between left
  and right, 0 outside.
- vzone: 4 if -3 ≤ v - top < 3; otherwise 12 if -3 ≤ v - bottom < 3; otherwise 8 if between, 0
  outside.
- Option key down: hzone = 1 if h ≤ the centre column of selWin, else 3; vzone = 4 if v ≤ the
  centre row, else 12. So the pointer always picks the nearest corner.

CODES (MAINE $E346, file $1EB83), by vzone and hzone:

| | hzone 0 | 1 (left) | 2 (between) | 3 (right) |
|---|---|---|---|---|
| vzone 0 | 11 | 11 | 11 | 11 |
| 4 (top) | 11 | 7 | 8 | 9 |
| 8 (between) | 11 | 4 | 5 | 6 |
| 12 (bottom) | 11 | 1 | 2 | 3 |

Codes 1-9 follow the numeric keypad: 7 top-left corner ... 3 bottom-right corner, 5 = inside
(move). CURSOR (MAINE $E3A2, file $1EBDF) gives the rCursor ($8027) resource ID:

| Code | Meaning | rCursor |
|---|---|---|
| 0 | arrow | none (InitCursor) |
| 1, 9 | bottom-left or top-right corner | 4 |
| 3, 7 | bottom-right or top-left corner | 1 |
| 2, 8 | bottom or top edge | 2 |
| 4, 6 | left or right edge | 3 |
| 5 | inside the selection: move | 8 |
| 10 | pixel peek | 6 |
| 11 | new selection | 5 |

The cursors (640-mode pixels; # black, . white, x inverts the screen pixel, blank
transparent):

```
rCursor 1, NW-SE double arrow (codes 3, 7), hot spot v 5 h 9
##########
#......#
#....#
#..# xx
##     xx
         xx     ##
           xx #..#
            #....#
          #......#
        ##########

rCursor 4, NE-SW double arrow (codes 1, 9), hot spot v 5 h 9
        ##########
          #......#
            #....#
           xx #..#
         xx     ##
##     xx
#..# xx
#....#
#......#
##########

rCursor 2, vertical double arrow (codes 2, 8), hot spot v 6 h 8
       ##
     ##..##
   ##......##
 ##..........##
# # # #xx# # # #
       xx
       xx
       xx
# # # #xx# # # #
 ##..........##
   ##......##
     ##..##
       ##

rCursor 3, horizontal double arrow (codes 4, 6), hot spot v 3 h 14
      ###          ###
    ##..#          #..##
  ##....#          #....##
##......xxxxxxxxxxxx......##
  ##....#          #....##
    ##..#          #..##
      ###          ###

rCursor 8, move (code 5), hot spot v 1 h 6
      ##
     #.#
    #..#
   #...#
  #....#
 #.....#
#......#
########

rCursor 6, pixel peek (code 10), hot spot v 4 h 8
xx              xx
  xx          xx
    xx      xx

        xx

    xx      xx
  xx          xx
xx              xx

rCursor 5, new selection (code 11), hot spot v 4 h 8
        xx
        xx
        xx

xxxxxx  xx  xxxxxx

        xx
        xx
        xx
```

### 6.2 Clicks and selection (MAINE $E3C6)

TaskMaster's wInContent goes to MAINE $E3C6. It does nothing unless the cursor code is 1-11 (so
only in the front image window). It first processes pending updates (FRED $97DF), then starts
drawing in the window with pen 2 × 1 in XOR mode.

```
if clickCount == 2 and code == 11:           ; double click outside the selection or with none
    store(); new selWin = (0, 0, H, W); hasSel = 1; draw frame; update info text; return
anchor = snap(click point); constraint = none
if no selection: clear left and right of selWin and of the stored rectangle
switch code:
    1  bottom-left corner:  anchor = (top, right)
    3  bottom-right corner: anchor = (top, left)
    7  top-left corner:     anchor = (bottom, right)
    9  top-right corner:    anchor = (bottom, left)
    2  bottom edge: anchor v = top,    only top and bottom change
    8  top edge:    anchor v = bottom, only top and bottom change
    4  left edge:   anchor h = right,  only left and right change
    6  right edge:  anchor h = left,   only left and right change
    5  move:        last = mouse position
    10, 11:         anchor = snapped click point
loop:
    SystemTask; p = GetMouse()                                      ; content coordinates
    if code == 10: pixel peek (6.3), no change to the selection
    else:
        p.v = (p.v + halfY) & maskY; below 0 -> 0; if >= Hz: Hz & maskY
        p.h = (p.h + halfX) & maskX; below 0 -> 0; if >= Wz: Wz & maskX
        move:           new = selWin moved by p - last; last = p; then shifted back inside
                        0..Wz and 0..Hz keeping its size (left first, then right, top, bottom)
        corner or new:  new = rectangle spanned by anchor and p
        edge:           the free pair from anchor and p (sorted), the other pair unchanged
    if new != selWin:
        draw frame (erases the old one), selWin = new,
        if at least 6 ticks since the last ant step: next phase,
        draw frame, store(), update the info text (MAINE $F1D2)
    elif at least 6 ticks since the last ant step: ant step (4.5)
    auto-scroll (6.4)
until the button is up
if no selection: selWin = (0, 0, Hz, Wz)
store()
```

"Draw frame" (MAINE $E98B) sets hasSel = 0 and draws nothing when the rectangle has no height or
no width; otherwise hasSel = 1 and it draws the frame. So a click without dragging removes the
selection, and a selection always has at least one step in each direction.

store() (MAINE $E9C4): the type's selection flag = hasSel; its stored rectangle = (Zoom2Act(top),
Zoom2Act(left), min(Zoom2ActR(bottom), H), min(Zoom2ActR(right), W)); for true color also
LONGCODE $0F77 = 0.

Snapping (values from ImgChanged): points are rounded to the nearest pixel boundary of the
shown image: 4 columns (one byte) for a screen image, 2 for 320-sized and 1 for 640-sized true
color or monochrome, 1 line vertically, multiplied by the zoom. When shrunk, the mask becomes
$FFFF and nothing is rounded.

The double click: the first click of the pair already left no selection, so the stored
rectangle is the whole image. The second click stores that again with the flag set and sets
selWin to (0, 0, H, W) in image units. At actual size that is the whole picture; at other zoom
levels the frame is drawn at the wrong size until the next ImgChanged, while the stored
selection is right.

### 6.3 Pixel peek

While the button is held (code 10): x = Zoom2Act(h) limited to 0 .. W - 1, y = Zoom2Act(v)
limited to 0 .. H - 1; the peek point becomes (x, y) and the info text is redrawn. The value
follows the pointer while the button is down and the last one stays. The selection is kept and
keeps marching.

### 6.4 Auto-scroll (MAINE $E7F1)

During every drag step, selection or peek:

- up 8 rows if the pointer is at global v = 0 or at or above the top of the visible content;
  down 8 rows if global v ≥ 200 or v + 1 ≥ the bottom of the visible content;
- left 16 columns if global h = 0 or h ≤ the visible left edge; right 16 columns if h + 1 ≥ the
  visible right edge;
- limits: origin ≥ 0; horizontal ≤ (data width - view width + 1) & ~1; vertical ≤ Hz - view
  height;
- if the origin changed: SetContentOrigin, SetDataSize(Wz + 7, Hz), EnterScbs.

## 7. Info bar pop-up menus

### 7.1 Dispatch (MAINE $F796)

TaskMaster's wInInfo goes to MAINE $2F5E, which calls the front window's wInfoRefCon routine,
MAINE $F796. It updates the cursor and palettes (MAINE $E1D6), gets the info bar rectangle in
global coordinates, installs the pop-up menu bar (handle MAINE $2004) to set item states, puts
the system menu bar back, and shows the menu with PopUpMenuSelect(current item, left, top,
flag $0040, menu). The click zones are in `superconvert-ui-data.md` 5.3. While "Menu item help"
mode is on ($053E not 0) the choice is ignored.

| Pop-up | Menu position (left, top) | Current item passed |
|---|---|---|
| 1 image type | (info left, info top - 1) | $0100 + shown type |
| 3 zoom | (info left + 40, info top - 1) | $0300 + (zoom & $FF) |
| 2 tool | (info left + 80, info top - 1) | $0200 + tool |
| 4 or 5 | (info left + 120, min(info bottom + 1, 188)) | 0 |

For pop-ups 4 and 5 the 18-column strip at info left + 120 is inverted before and after the
menu (MAINE $FA57), and the menu opens below the info bar.

### 7.2 Pop-up 1: image type (MAINE $F80F)

| Item | Enabled when | Checked when |
|---|---|---|
| 257 Screen image | a screen image exists | (not set by the program) |
| 258 True color image | a true color image exists | (not set by the program) |
| 259 Monochrome image | a monochrome image exists | (not set by the program) |
| 262 Use image's palette | the shown type is screen | $00D0 is on |
| 260 320-sized pixels | the shown type is true color or monochrome | the shown type's pixel size is 0 |
| 261 640-sized pixels | the shown type is true color or monochrome | the shown type's pixel size is 1 |

The menu order is 257, 258, 259, a line, 262, 260, 261. The choice a = item & $FF: if a ≤ 3
and a is the shown type, nothing happens; otherwise NewImgType(a) (section 3):

- Screen image, True color image, Monochrome image: show that image (ExitPals, ImgChanged).
- 320-sized pixels, 640-sized pixels: set the shown type's pixel size; the selection's left and
  right follow so the same pixels stay selected; ImgChanged redraws at the new width. The value
  is kept per type. Loading does not change it, except that the Works of Art loader sets
  320-sized for monochrome; Screen > Convert to true color and Monochrome > Convert to true
  color set the true color value (section 9).
- Use image's palette: ExitPals, then toggle. Nothing is redrawn; the palettes change the next
  time the pointer is over the picture (4.6).

### 7.3 Pop-up 3: zoom (MAINE $F8DC)

- 1/8 shrink, 1/4 shrink, 1/2 shrink and Actual size are always enabled.
- m = max(W, H) in image units: 2X zoom is enabled if m < 5000, 4X zoom if m < 2500, 8X zoom if
  m < 1250 (the zoomed size stays below 10000).

The choice z = item & $FF as a signed byte (1021-1023 give -3 to -1, 768-771 give 0 to 3). If z
differs from the zoom, the zoom becomes z and NewImgType(shown type) runs: ExitPals, new data
size, selection frame position, info bar icon, full redraw. The origin stays.

Magnifier icon in the info bar (x = info left + 42): OSAYCANYOU $4A1D at actual size, $4A65
(small) when shrunk, $4AAD (large) when zoomed.

How each level draws: always CopyPixels (4.1), applied to the 640-mode pixels after the true
color dithering or monochrome expansion. At 2X, 4X and 8X every column and row is repeated 2,
4 or 8 times. At 1/2, 1/4 and 1/8 one column and one row out of every 2, 4 or 8 is shown
(sampling, no averaging). For a screen image the columns are half-pixels of 320-mode bytes, so
shrinking and zooming change 320-mode values (4.6).

### 7.4 Pop-up 2: tool (MAINE $F972)

tool = item & $FF (513 Selection mode = 1, 514 Pixel peek mode = 2), then DrawInfoBar. The
selection stays (and keeps marching) in pixel peek mode; the cursor changes on the next main
loop pass.

### 7.5 Pop-ups 4 and 5 (MAINE $F9C4)

Pop-up 4 (menu MAINE $2014) is used in selection mode, pop-up 5 (MAINE $2018) in pixel peek mode
(table MAINE $E1CC). Choices go through the table at MAINE $FAAA.

| Item | Enabled when | Action |
|---|---|---|
| 1025 Crop to selection | the shown type has a selection | screen: LONGCODE $DB37 [DoShrink]; true color: FRED $9B50 [DoCropTrue]; monochrome: FRED $89BB [DoCropMono] |
| 1026 Discard this image type | always | screen: exists = 0, then ImgChanged; true color: LONGCODE $AF4F [PurgeRemap]; monochrome: FRED $8767 [PurgeMono]. If no image is left: close the window (MAINE $4217) |
| 1027 Discard other image types | always | screen shown: PurgeRemap and PurgeMono; true color shown: screen exists = 0 and PurgeMono; monochrome shown: screen exists = 0 and PurgeRemap |
| 1281 Clicking sets VOC key color | the shown type is screen and the VOC tool set is running ($00AE) | toggles $00D4; checked when on |

PurgeRemap and PurgeMono free the image (the handle is unlocked and made purgeable), clear its
flag and then call ImgChanged, or close the window when nothing is left. So after "Discard this
image type" the window shows the first remaining of screen, true color, monochrome. "Discard
other image types" keeps the shown type; when it only drops the screen image (only a flag is
cleared) nothing calls ImgChanged, so the title and menus are not brought up to date until the
next change.

Crop to selection:

- Screen: the selection is in whole bytes. The selected bytes of the selected lines are moved to
  the start of the buffer, the SCBs move up with them, the size becomes (right - left) / 4 bytes
  by (bottom - top) lines (this clears the screen selection), and duplicate palettes are merged
  (LONGCODE $FDEE, probably). Then the image is shown as after a load (MAINE $4271): title,
  View full screen unless "Don't automatically view screen images after loading" is checked,
  zoom back to Actual size, origin (0, 0), screen shown.
- True color: the selected pixels (left and right halved when 320-sized) are copied into a
  smaller image and the handle is shrunk; LONGCODE $0F47 and $0F49 are scaled by the size change;
  the true color selection is cleared; origin (0, 0); NewImgType(shown type). The zoom stays.
- Monochrome: the same with bit shifting; the monochrome selection is cleared; origin (0, 0);
  NewImgType(shown type). The zoom stays.

## 8. Keys

FRED $A171 [SHRVector], the image window's wRefCon, gets key-down events (TaskMaster result 3)
when the image window is in front (MAINE $2F1E). Auto-key events (result 5) are ignored by it.

| Key | Action |
|---|---|
| 1 to 9 | scroll so that a point of selWin is centred; keypad layout: 7, 8, 9 = top left, top centre, top right; 4, 5, 6 = middle; 1, 2, 3 = bottom. Without a selection selWin is the whole picture |
| Space | as 5 |
| Apple-w | close the window (MAINE $4217). Only lowercase w is tested |
| Tab | only for Works of Art pictures (below) |

Positioning (FRED $A1DA): the point (ph, pv) is the average of two edges of selWin (tables
FRED $A2EC-$A333, file $2CBD0). With the visible width vw and height vh of the content:

```
h = ph - vw/2, below 0 -> 0, rounded down to even;  if h + vw >= Wz: h = Wz - vw (0 if negative), rounded down to even
v = pv - vh/2, below 0 -> 0;                        if v + vh >= Hz: v = Hz - vh (0 if negative)
SetContentOrigin(h, v); SetDataSize(Wz + 7, Hz); EnterScbs
```

Tab (FRED $B410): only when a monochrome image of exactly 270 × 360 image units is shown and the
Works of Art loader (FRED $AEBA) left its list of sub-picture rectangles in the shared buffer at
LONGCODE $4F88.
Each Tab makes the next rectangle of the list the selection and centres it as key 5.

## 9. Which image type is shown after each command

| Command | Code | Window shows afterwards | Other effects |
|---|---|---|---|
| Load, the file gives no true color image (screen image, possibly with a monochrome one) | MAINE $45D4, $4271 | screen | first View full screen unless "Don't automatically view screen images after loading"; zoom Actual size, origin (0, 0); then the Remap dialog if "Automatically show Remap dialog after loading screen images" |
| Load, the file gives a true color image, Remap dialog on (default) | MAINE $428C, then $1141 | while the Remap dialog is up: the type shown before the load if the new file has it, otherwise the first that exists of screen, true color, monochrome (normally true color); after a successful Remap the new screen image (with View full screen as above); after Cancel unchanged | zoom Actual size, origin (0, 0) |
| Load, the file gives a true color image, "Don't automatically show Remap dialog for true color images" | MAINE $4271 | screen (with View full screen as above) if the file also gave a screen image; otherwise as in the row above, normally true color | |
| Convert to screen (Remap)... | MAINE $1141 | after a successful Remap: screen, with View full screen unless the preference is set | zoom Actual size, origin (0, 0); Remap makes a true color image from the screen image first if there is none |
| True color filters: Median, Sigma, Emboss, Blur, Sharpen, Solarize, Find edges, Increase contrast, Decrease contrast | SUPERFX $0000 and $035D-$1708 | true color (or the shown type if it still exists, e.g. monochrome) | the window is hidden while the filter runs and the screen image is dropped (MAINE $421F); then the Remap dialog unless "Don't automatically show Remap dialog for true color images"; after a successful Remap: screen and View full screen |
| Histogram equalization | LONGCODE $E796 | true color | screen image kept (out of date); then the Remap dialog unless the preference is set |
| Rotate/flip image... | LONGCODE $B8AC | true color | the stored true color selection is flipped or turned with the picture; screen image kept; then the Remap dialog unless the preference is set |
| Screen > Convert to true color... | FRED $C0C0 | true color | no Remap |
| Screen > or True color > Convert to monochrome... | FRED $CB73, $CB8C | monochrome (after its dialog) | no Remap |
| Monochrome > Convert to screen... | FRED $C568 | screen | no full screen view, no Remap |
| Monochrome > Convert to true color... | FRED $C556 | true color | no Remap |
| Negative image | FRED $928E | monochrome | makes a monochrome image from true color or screen first if there is none; inverts only the monochrome selection (the whole image without one) |

So the program does run Remap by itself after every True color filter, Histogram equalization
and Rotate/flip: it opens the normal Remap dialog (the user can Cancel), unless "Don't
automatically show Remap dialog for true color images" is checked. The conversions between
image types do not.

Notes:

- The filters and Histogram equalization first make a true color image from the screen or
  monochrome image if there is none (FRED $B830 [MakeAMap]).
- Conversions use the source type's stored selection (the whole image without a selection).
- Pixel size of a new true color image: Screen > Convert to true color sets 320-sized when the
  screen image has no 640-mode line, 640-sized otherwise; Monochrome > Convert to true color
  takes the choice made in the monochrome options dialog. Monochrome images start 640-sized;
  only the Works of Art loader sets 320-sized.
- Every load first closes the window (MAINE $4217: all images discarded).

## 10. Full-screen views

### 10.1 Common part

- View full screen, View half size and View X4 magnified first call FRED $C1FB [MakeScreen] and
  afterwards FRED $C505 [UnMakeScrn]. View approximation calls FRED $B830 [MakeAMap] instead.
- LONGCODE $ED1D [DoWithFull](routine): HideMenuBar, opens the full-screen window (rWindParam1 7),
  HideCursor, saves the screen pixels, the 200 SCBs and the 16 colour tables in a new handle,
  calls the routine, then restores all of it (if the save failed: standard colour table 0,
  master SCB, RefreshDesktop).
- The View full screen and View half size routines call LONGCODE $E3AF [VOCAttach] at the
  start and LONGCODE $E388 [VOCDetach] at the end (the Video Overlay Card's second monitor);
  View X4 magnified and View approximation do not.
- Ending: the routine loops on GetNextEvent(mouseDown, keyDown, deskAcc). A click or a key ends
  the view. A key typed with Apple is posted again (PostEvent) so its menu command runs after the
  view; other keys are dropped. View half size posts every key again.

MakeScreen:

```
if a screen image exists: done
if a true color image exists:
    sel = true color selection (the whole image without one)
    lines = min(sel height, 400); bytes = sel width in image units / 4
    SetScreenSize(640 mode, bytes, lines), retried with one byte less while too large
    temporary = (lines were cut or the width was reduced)
    standard 640 palette in palette 0, all SCBs $80 (MAINE $4CDD)
    each line: FRED $C151 [T2SLine], the same dithering as the window (4.3, same pixel size, row parity)
    NewImgType(1)                                ; the window now shows this screen image
else (monochrome): FRED $C32D [ScrFroMono]        ; shows the monochrome options dialog unless its "SKIP ME" is set
UnMakeScrn: if temporary: screen exists = 0, and if the screen was shown, NewImgType(2)
```

So when it did not have to be cut, the screen image made for viewing stays afterwards and the
window keeps showing it.

### 10.2 View full screen (MAINE $120C, routine MAINE $1254)

```
all 16 palettes copied to the hardware; all 200 SCBs = SCB of image line 0
if bytes < 160 or lines < 200: fill the screen with $F0F0 on even lines and $0F0F on odd lines
position from a point (h, v):
    wider than the screen (bytes > 160): ox = bytes/2 - h/4, limited to 0 .. bytes - 160; 160 bytes per line
    otherwise: ox = 0; each line is copied at the left, the rest of the line keeps the fill
    taller (lines > 200): oy = lines/2 - v, limited to 0 .. lines - 200
    SCBs of screen lines 0.. = image SCBs from line oy (while image lines remain)
    pixels copied again only when the offset changed
```

The point: until the mouse moves, an automatic tour that steps every 32 ticks through
(h, v) = (0, 0), (320, 0), (640, 0), (640, 100), (640, 200), (320, 200), (0, 200), (0, 100)
(MAINE $1230 and $1240, files $11A6D and $11A7D). Once the pointer is no longer where it was when
the view started, the pointer position is used. With the pointer in the middle of the screen
the middle of the picture is shown; moving the pointer right shows more of the left part, as if
the picture were dragged. Pictures of one screen or less do not move.

### 10.3 View half size (MAINE $2D57, routine MAINE $2D6C)

```
port = Menu Manager port (the whole screen)
FillRect(screen, pattern MAINE $2E9A)          ; rows alternate ..##..## / ##..##..
PenNormal
for y = 100 to 199: MoveTo(640, y); LineTo(65535 div y, y)   ; a curved black area in the lower right corner
SCBs: all lines = image SCB[0]; line i = image SCB[2i] for i = 0 .. (lines - 1) / 2
all 16 palettes copied to the hardware
CopyPixels(LocInfo MAINE $00E2, port, (0, 0, lines & ~1, columns & ~3),
           (0, 0, (lines & ~1) / 2, (columns & ~3) / 2), copy, nil)
wait for mouseDown, keyDown, autoKey or deskAcc; a key is posted again
```

The picture is reduced to half by CopyPixels and placed at the top left; a picture of 320 bytes
by 400 lines (two screens each way) fills the screen. No scrolling. The pattern and the black curve are shown in the
palette and mode of image line 0's SCB on the lines below the picture. Because the bytes are
treated as 640-mode pixels, a 320-mode line keeps only the top two bits of each pair of
neighbouring pixels (follows from the code).

### 10.4 View X4 magnified (MAINE $1483, routine MAINE $14A7)

```
all 16 palettes copied to the hardware; all SCBs 0
if bytes < 40 or lines < 50: fill with $F0F0 / $0F0F lines as in 10.2
visible part: 40 bytes by 50 lines, following the pointer (h, v):
    left = bytes/2 + 160 - h/2 - 20, limited to 0 .. bytes - 40 (all bytes if fewer than 40)
    top  = lines/2 + 200 - 2v - 25, limited to 0 .. lines - 50
for each visible image line: 4 screen lines with SCB = image SCB & $0F (320 mode, same palette)
    320-mode line: each byte (2 pixels) becomes 4 bytes, each pixel 4 times (OSAYCANYOU $3B3B, $3D3B)
    640-mode line: each byte (4 pixels) becomes 4 bytes of 320-mode pixels; the pixel at position k
        (k = 0 for bits 7-6) with value v becomes two 320-mode pixels of value 4k + v (OSAYCANYOU $3F3B, $413B)
    the line is written to the 4 screen lines
redrawn only when (left, top) changes
```

The picture follows the pointer in the same dragging sense as in 10.2: the pointer in the
middle of the screen shows the middle of the picture.

### 10.5 View approximation (MAINE $16BD, routine MAINE $173E)

The true color image is shown with three primary-colour lines per pixel; there is no
remapping and the image is not changed.

```
320 mode. Palettes (MAINE $16DE, file $11F1B):
    0 = red ramp   $000 $100 ... $F00
    1 = green ramp $000 $010 ... $0F0
    2 = blue ramp  $000 $001 ... $00F
SCBs: line 4k -> 0, 4k+1 -> 1, 4k+2 -> 2, 4k+3 -> 0
screen cleared to 0
up to 80 × 50 true color pixels, each drawn as a block 4 pixels wide and 4 lines high:
    line 0: red level, line 1: green level, line 2: blue level, line 3: 0 (black)
    each level is one word = four 320-mode pixels:
        colour pixel: 5-bit component c -> OSAYCANYOU $43BB[c] (patterns a b a b, for example
            1 -> 1 0 1 0, 2 -> 1 1 1 1, 3 -> 2 1 2 1, 31 -> F F F F)
        gray pixel: n = level >> 2 (0-63) -> OSAYCANYOU $433B[n], the same word on all three lines
            (for example 1 -> 0 0 1 0, 2 -> 1 0 1 0, 3 -> 1 1 1 0, 63 -> F F F F)
visible part, following the pointer (h, v):
    sx: start at -2; w = width/2 - 39; while w >= 80: sx += 1, w = (w + 1) / 2
    d = (320 - h) scaled by 2^sx (shift left when sx > 0, arithmetic shift right when sx < 0)
    left = max(0, min(d + width/2 + 40, width) - 80); columns = min(80, width - left)
    sy: start at -1; t = height/2 - 24; while t >= 50: sy += 1, t = (t + 1) / 2
    d = (100 - v) scaled by 2^sy
    top = max(0, min(d + height/2 + 25, height) - 50); rows = min(50, height - top)
redrawn only when (left, top) changes
```

The scale factors make the whole pointer range cover the whole picture, again in the dragging
sense. Ending as in 10.1.

## 11. Other window behaviour

- Close box: TaskMaster's wInGoAway goes to MAINE $0D9C; for the image window it calls MAINE
  $4217: PurgeRemap, PurgeMono, HideWindow, ExitPals, hide the "Save..." button, disable Save
  conversion, Current image and the print items ($0102, $0108, $010F, $0119, $011A, $011E),
  disable the Screen, True color and Monochrome menus, screen image exists = 0, screen selection
  flag = 0. So closing the window discards all images. Edit > Close and Apple-w do the same.
- Zoom box, grow box, dragging and the scroll bars are handled by TaskMaster alone; the content
  is redrawn through MAINE $EA30.
- Showing the window (MAINE $428F): ShowControl("Save..."), enable menus 5, 9 and 6, zoom back to
  Actual size, NewImgType(shown type), SetContentOrigin(0, 0), ShowWindow, SelectWindow, enable
  $0102, $0108, $010F, $0119, $011A, $011E.
- Windows > Current image: SelectWindow(image window).
- Windows > Normal positions (MAINE $2210): if the image window is zoomed it is unzoomed
  (ZoomWindow), then ResizeWindow to content 122,328,183,608 (OSAYCANYOU $311E).
- Key-down, auto-key, activate and wInControl results go to the front window's wRefCon (MAINE
  $2F1E); for the image window only key-down does anything (section 8).
- The marching ants run on null events (MAINE $0DB5 calls MAINE $EFE3).
- Choosing a menu command calls ExitPals first (MAINE $0FC7), so commands always start with the
  desktop colours.

## 12. Data tables

| Table | Address | File offset | Size |
|---|---|---|---|
| True color dither table | OSAYCANYOU $4F0F | $57C3A | 8192 bytes |
| Marching ants patterns ANTS / STEP | OSAYCANYOU $4E8F | $57BBA | 4 × 32 bytes |
| Window background pattern | OSAYCANYOU $312E | $55E59 | 32 bytes |
| View X4 tables (320 first word, 320 second word, 640 first word, 640 second word) | OSAYCANYOU $3B3B, $3D3B, $3F3B, $413B | $56866 | 4 × 256 words |
| View approximation gray levels | OSAYCANYOU $433B | $57066 | 64 words |
| View approximation colour levels | OSAYCANYOU $43BB | $570E6 | 32 words |
| View approximation palettes | MAINE $16DE | $11F1B | 3 × 16 words |
| Fixed palettes with SCB mode (MAINE $4CB1-$4CED) | MAINE $4D16 | $15553 | 8 × 16 words |
| View half size background pattern | MAINE $2E9A | $136D7 | 32 bytes |
| View full screen tour points h / v | MAINE $1230 / $1240 | $11A6D / $11A7D | 8 words each |
| Cursor codes | MAINE $E346 | $1EB83 | 16 bytes |
| Cursor resource IDs by code | MAINE $E3A2 | $1EBDF | 12 words |
| Key positioning tables | FRED $A2EC | $2CBD0 | 4 × 9 words |
| Monochrome bit masks | MAINE $F665 | $1FEA2 | 8 bytes |
| Monochrome to true color gray levels | FRED $C09E | $2E982 | 17 words |

Fixed palettes at MAINE $4D16 (the routine at each entry also sets all 400 SCBs to the mode
shown and installs the palette as palette 0):

| Entry | Mode | Colours |
|---|---|---|
| MAINE $4CB1 (used by the Apple II HiRes, DoubleHiRes and text loaders) | 320 | $000 $D03 $852 $F60 $070 $555 $0D0 $FF0 $009 $D0D $AAA $F98 $22F $6AF $0F9 $FFF |
| MAINE $4CC3 | 640 | $000 $777 $CCC $FFF repeated 4 times |
| MAINE $4CCC | 320 | $000 $FFF $D00 $0DD $D0D $0D0 $00D $FE0 $F70 $B50 $F88 $666 $999 $BFB $BBF $CCC |
| MAINE $4CD5 | 320 | $000 $777 $841 $72C $00F $080 $F70 $D00 $FA9 $FF0 $0E0 $4DF $DAF $78F $CCC $FFF |
| MAINE $4CDD | 640 | $000 $F00 $0F0 $FFF $000 $00F $FF0 $FFF repeated twice (standard 640 palette) |
| MAINE $4CE5 | 640 | $000 $F00 $0F0 $FFF repeated 4 times |
| MAINE $4CED | 320 | $000 $111 ... $FFF (16 grays) |
| MAINE $4CBA (offset $E0, used by LONGCODE $B77E) | 320 | $000 $00F $0F0 $0FF $F00 $F0F $FF0 $FFF $000 $222 $444 $666 $999 $BBB $DDD $FFF |

The monochrome to screen conversion uses $4CD5 (320) or $4CDD (640) for pure black and white and
$4CED (320) or $4CC3 (640) when it produced gray levels.

## 13. Corrections to superconvert-ui-data.md

- 5.2 Title: the number after the comma is the highest palette number used plus 1, not the
  number of different palettes. Without a screen image the title is `" NAME (???) "` (three
  question marks). The name is cut to 31 characters.
- 5.3 Text: there are four variants, levels 0 to 3; the last one, `W x H`, is always drawn when
  nothing longer fits (there is no empty variant). Levels 0 and 1 are the same.
- 5.3 Selection text: the numbers in parentheses are top, left, bottom, right (in that order),
  in the image's pixels: `Selection: W x H   (T, L, B, R)`.
- 5.3 Pixel peek: "Click in image to view pixel values" / "Click in image" only appear until the
  first value has been shown; afterwards the text is blank until the next click. The value
  texts are in 5.5 of this document.
- 5.1 Keys: Apple-w is tested in lowercase only; Tab only works for Works of Art pictures.

## 14. Uncertain points

- Scaling: zoom and shrink rely on QuickDraw Auxiliary CopyPixels scaling. Which rows and
  columns it keeps when shrinking (and so the exact look of 1/2, 1/4, 1/8 and of View half size)
  was not checked on a machine. The program itself never averages.
- QuickDraw's bit-to-pixel tables (GetAddress 2 and 3) are taken to give all ones for a set bit,
  leftmost pixel first. The pixel peek text ("White" for a set bit) agrees.
- Patterns: the reading of 640-mode patterns as 8 rows of 2 bytes (first 16 bytes) comes from
  the data: with it ANTS[i] XOR STEP[i] = ANTS[i + 1] for all four steps and the background is a
  regular diagonal hatch.
- 640-mode colour order: the pixel peek (5.5) and View X4 magnified (10.4) use palette entry
  4k + v for the pixel at position k (k = 0 for bits 7-6). The Apple IIgs hardware documentation
  gives entries 8-11 for bits 7-6, 12-15 for bits 5-4, 0-3 for bits 3-2 and 4-7 for bits 1-0.
  The two agree only when entries 0-7 equal entries 8-15, as in the standard 640 palette; for
  other palettes the program's peek colour and X4 colours would differ from the normal screen.
  Not checked on a machine.
- Whether PopUpMenuSelect puts a check mark on the current item it is given: the program sets
  check marks only on items 260, 261, 262 and 1281.
- Whether SetDataSize or SetContentOrigin change an origin that is outside the new data size,
  and whether SetContentOrigin applies the origin mask $FFF8 (the key positioning only rounds h
  to even).
- LONGCODE $0F77 (cleared on every change and on every true color selection change) and $0F47 /
  $0F49 (scaled by Crop to selection) belong to the Remap code; their exact meaning was not
  traced.
- Video Overlay Card tool $0F21 is taken to set the key colour; its name was not checked.
- The Works of Art Tab feature was read only from FRED $B410; the loader side was not traced.
- The colours shown by View half size outside the picture and in the X4 fill depend on the
  image's palettes (the pattern is drawn in pixel values, then the image's palettes are loaded).
