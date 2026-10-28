# SuperConvert 4: True color and Monochrome menus

Reference for rebuilding the dialogs and image operations of the "True color" and "Monochrome"
menus of SuperConvert 4.0 (and the related "Screen" items) in MegaconvertGS. Everything was read
from the original program files (data fork, OMF load file; resource fork) and, for the Integer
Math routines the filters call, from the Apple IIgs ROM 3.

Conventions are those of `superconvert-ui-data.md`: numbers starting with $ are hexadecimal,
rectangles are top,left,bottom,right with bottom/right exclusive, coordinates are 640-mode pixels,
addresses are given as segment name and offset (file offsets are data fork offsets). Segments: 2
(unnamed), 5 MAINE, 6 FRED, 8 LONGCODE, 9 OSAYCANYOU, 10 SUPERFX, 23 DYNAMIFF. Routine names in
brackets (DoNegative, ToMonoDlg ...) are the names stored in the program itself.

640-mode bitmaps are drawn as in the other document: "#" = 0, "a" = 1, "b" = 2, "." = 3. With
the desktop's standard 640 colour table, 1 is red on even columns and blue on odd columns, 2 is
green / yellow, 3 white, 0 black.

There are two ways to get the same pixels as the original:

- Most windows are Toolbox templates (Dialog Manager item lists, NewWindow2 templates with control
  templates, AlertWindow strings). On the IIgs, building the same templates and making the same
  calls in the same order draws the same pixels. All template fields are listed below.
- The custom drawing (progress icon, rotate preview, histogram graph, monochrome preview grid) is
  given as exact coordinates and calls.

## Contents

- 1. Menu items and entry points
- 2. Shared machinery
- 3. Factor dialog (Blur, Sharpen, Find edges)
- 4. Rotate/flip image
- 5. True color image info
- 6. Histogram equalization
- 7. Convert to monochrome (Screen and True color menus)
- 8. Monochrome > Convert to screen / Convert to true color
- 9. Monochrome image info, Negative image
- 10. Screen > Convert to true color (exact or smoothed)
- 11. The SUPERFX filters compared with GS Remap
- 12. Integer Math rounding and the contrast tables
- 13. Uncertain points

## 1. Menu items and entry points

Menu dispatch: MAINE $0FC7, table MAINE $101A, 4 bytes per item starting at item $00FA. A 2-byte
pointer is a JSR into MAINE, a 3-byte one a JSL.

| Item | Menu | Text | Code | Window |
|---|---|---|---|---|
| $0123 | True color | True color image info... | LONGCODE $C5D7 | section 5 |
| $011F | True color | Convert to monochrome... | FRED $CB8C [True2Mono] | section 7 (kind 2) |
| $0121 | True color | Rotate/flip image... | LONGCODE $B8AC | section 4 |
| $012A | True color | Histogram equalization... | LONGCODE $E796 [DoEqualize] | none (section 6) |
| $012B | True color | Median filter | SUPERFX $035D | progress only |
| $012C | True color | Sigma filter | SUPERFX $043E | progress only |
| $0135 | True color | Emboss image | SUPERFX $054A | progress only |
| $0136 | True color | Blur image... | SUPERFX $082E | Factor dialog |
| $0137 | True color | Sharpen image... | SUPERFX $0A76 | Factor dialog |
| $0138 | True color | Solarize image | SUPERFX $0D24 | progress only |
| $0139 | True color | Find edges... | SUPERFX $0DC1 | Factor dialog |
| $013A | True color | Increase contrast | SUPERFX $1676 | progress only |
| $013B | True color | Decrease contrast | SUPERFX $1708 | progress only |
| $0113 | Screen | Convert to true color... | FRED $C0C0 [Scrn2True] | section 10 (640 mode only) |
| $0131 | Screen | Convert to monochrome... | FRED $CB73 [Scrn2Mono] | section 7 (kind 0) |
| $0132 | Monochrome | Monochrome image info... | FRED $92F4 [MonoInfo] | alert, section 9 |
| $010A | Monochrome | Convert to screen... | FRED $C568 [Mono2Scrn] -> $C32D [ScrFroMono] | section 8 (kind 0) |
| $0133 | Monochrome | Convert to true color... | FRED $C556 [Mono2True] -> $BFE2 [GenFroMono] | section 8 (kind 2) |
| $0134 | Monochrome | Negative image | FRED $928E [DoNegative] | none |

The same monochrome windows also appear when saving in a format that needs another image type
(FRED $A4EA-$A51C, [DoSaveType]).

## 2. Shared machinery

### 2.1 True colour pixel words

The true colour image is one 16-bit word per pixel (handle LONGCODE $0F21, width $0F3F, height
$0F41, size in bytes $0F29/$0F2B):

- bit 15 set: grey pixel, 8-bit grey in bits 7-0;
- bit 15 clear: 15-bit colour, bits 11-8 / 7-4 / 3-0 = high four bits of R / G / B, bits 14 / 13 /
  12 = the fifth (lowest) bit of R / G / B. The 5-bit channel is R5 = R4*2 + bit 14.

Pixels whose three channels are equal are always stored as grey pixels: every encoder below turns
equal channels into a grey word. A 24-bit RGB model can therefore tell the two kinds apart: r = g
= b is a grey pixel, anything else a colour pixel whose 8-bit channels are the 5-bit channels
expanded as rrrrr rrr.

Codecs used by the operations in this document:

| Codec | Address | Grey pixel | Colour pixel |
|---|---|---|---|
| decode to 5 bits | SUPERFX $029A | R5 = G5 = B5 = g >> 3 | R5 = R4*2 + bit 14, same for G (bit 13), B (bit 12) |
| encode from 5 bits | SUPERFX $02FE | see below | see below |
| decode to 8 bits | DYNAMIFF $15A1 (called through ~JumpTable 22:$0058) | R = G = B = g | R = R4*17, G = G4*17, B = B4*17 (fifth bits ignored) |
| encode from 8 bits | DYNAMIFF $152C (called through ~JumpTable 22:$002E) | if R = G = B (low bytes): $8000 + R | 5-bit channel = c >> 3 |
| palette colour to pixel | LONGCODE $B120 [Scrn2Map] | $0RGB with R = G = B: $8000 OR $0RGB (grey R*17 in the low byte) | nibbles kept, fifth bit = copy of the nibble's bit 3 (5-bit = 2n + (n >= 8)) |

The SUPERFX encoder does not clamp; its exact 16-bit behaviour matters for out-of-range results
(Blur, section 11):

```
encode5(R, G, B):                         ; 16-bit unsigned inputs
  if R == B and R == G: return ((R << 3) | $8000) & $FFFF
  t = R >> 1
  w = ((t & $FF) << 8) | (t >> 8)          ; XBA of R >> 1
  if R & 1: w |= $4000
  w |= (G << 3) & $00F0;  if G & 1: w |= $2000
  w |= B >> 1;            if B & 1: w |= $1000
  return w & $FFFF
```

Consequence: after any SUPERFX filter a grey pixel holds v5*8, so white (255) comes back as 248,
and any pixel whose three results are equal becomes a grey pixel with value v5*8.

### 2.2 Getting a true colour or monochrome image first

Every True color command first calls MakeAMap (FRED $B830): if a true colour image exists (MAINE
$052E <> 0) it returns at once; otherwise MakeAMapAnyway (FRED $B845) converts the screen image
(320 mode silently, 640 mode after the Exact / Smoothed window of section 10), or, with no screen
image, the monochrome image ([GenFroMono], with the window of section 8). Cancel there cancels the
command.

The Monochrome commands start with MakeAMono (FRED $C52B): with no monochrome image they run
True2Mono or Scrn2Mono first, which shows the Convert to monochrome window of section 7.

### 2.3 Before and after an operation

- SUPERFX filters call MAINE $421F before changing the image: the image window is hidden, the
  Save button hidden, items $0102, $0108, $010F, $0119, $011A, $011E and menus 5, 9, 6 disabled,
  and the screen image flag (MAINE $052C) cleared. Rotate/flip does the same only when it
  transposes. Histogram equalization does not.
- Filters, Rotate/flip and Histogram equalization reset the colour count cache (LONGCODE $0F77 =
  rows counted) so the next True color image info recounts.
- Afterwards: MAINE $428C (new window title, Save button shown, menus 5, 9, 6 enabled, zoom back
  to actual size, image type icon updated). Then, unless the preference "Don't automatically show
  Remap dialog for true color images" (MAINE $00C0) is set, the Remap dialog opens (LONGCODE
  $9F28 [ReMap]); if it completes, MAINE $4271 shows the result (full-screen view unless MAINE
  $00BE is set).
- Rotate/flip ends with MaybeBeep(5) (OSAYCANYOU $0A1A): on System 6 (Misc Tools 3.2 or later)
  SysBeep2($8005), otherwise nothing.

### 2.4 Progress dialog

Used by the nine SUPERFX filters (one line, the name below) and by True color image info ("Counting
colors used, please wait", only when 20 or more rows still have to be counted).

Open: LONGCODE $D163. Parameters: line count and four string pointers (Pascal strings).

```
UpdateAll                                         ; FRED $97DF
h = [42, 81, 120, 159][lines-1]                   ; table LONGCODE $D2CE
top = (200 - h) / 2;  bottom = top + h            ; one line: 79, 121
SetPort(GetMenuMgrPort)
width = max over the lines of StringWidth(line) + 90
left = ((640 - width) / 2) AND $FFFE;  right = left + width
ParamText(line1, line2, line3, line4)             ; unused lines are 0
write top,left,bottom,right into the template's first 8 bytes
GetNewModalDialog(LONGCODE $D2DA); DrawDialog; WaitCursor
```

Template LONGCODE $D2DA (file $4F430): visible $FFFF, refCon 0, eight items. With one line only
items 1 and 16 fall inside the window.

| ID | Type | Rect | Content |
|---|---|---|---|
| 1 | user item, disabled ($8014) | 5,10,37,74 | progress icon, draw procedure LONGCODE $CCA8 |
| 2 | user item, disabled | 44,10,76,74 | same procedure |
| 3 | user item, disabled | 83,10,115,74 | same procedure |
| 4 | user item, disabled | 122,10,154,74 | same procedure |
| 16 | static text, disabled ($800F) | 17,80,27,500 | "^0 " |
| 17 | static text, disabled | 56,80,66,500 | "^1 " |
| 18 | static text, disabled | 95,80,105,500 | "^2 " |
| 19 | static text, disabled | 134,80,144,500 | "^3 " |

Window content rectangles (system font widths):

| Message | StringWidth | Content rect (global) |
|---|---|---|
| "Performing median filter" | 175 | 79,186,121,451 |
| "Performing sigma filter" | 167 | 79,190,121,447 |
| "Embossing image" | 113 | 79,218,121,421 |
| "Blurring image" | 103 | 79,222,121,415 |
| "Sharpening image" | 120 | 79,214,121,424 |
| "Solarizing image" | 118 | 79,216,121,424 |
| "Finding image edges" | 138 | 79,206,121,434 |
| "Increasing image contrast" | 187 | 79,180,121,457 |
| "Decreasing image contrast" | 187 | 79,180,121,457 |
| "Counting colors used, please wait" | 241 | 79,154,121,485 |

Update: LONGCODE $D252 (item 1; entries $D257/$D25C/$D261 for items 2-4), called after each row
with X = index of the row just finished (0-based) and Y = number of rows:
value = (X*32) / Y (LongDivide, truncated); SetDItemValue(value, dialog, 1).

Icon drawing, LONGCODE $CCA8:

```
box = GetDItemBox(dialog, item)
v = GetDItemValue(dialog, item)
if v == 0: picture = EMPTY (LONGCODE $CF4B); v = 32
else:      picture = FULL  (LONGCODE $CD4B)
srcTop = max(0, 32 - v)
PPToPort(LocInfo LONGCODE $D14B, srcRect srcTop,0,32,64, x = box.left, y = box.top + 32 - v, mode 0)
```

LocInfo: SCB $0080, 16 bytes per row, bounds 0,0,32,64. Nothing is erased, so the empty apple
outline drawn at value 0 stays and the rainbow fills it from the bottom up. With 32 or more rows
the last value is 31, so the top row of the filled picture is never drawn.

```
FULL, LONGCODE $CD4B (file $4EEA1), 64x32
|...........................................#####................|
|........................................###bbb##................|
|.....................................###bbbbbb##................|
|...................................###bbbbbbb##.................|
|..................................##bbbbbbb###..................|
|.................................##bbbbbb###....................|
|.................................##bbb###.......................|
|...............##############....#####....############..........|
|..........#####bbbbbbbbbbbbbb###.......###bbbbbbbbbbbb#####.....|
|.......####bbbbbbbbbbbbbbbbbbbb#########bbbbbbbbbbbbbbbbbbb###..|
|.....###bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb####|
|...##b.b.b.b.b.b.b.b.b.b.b.b.b.b.b.b.b.b.b.b.b.b.b.b.b.b.###....|
|..##.b.b.b.b.b.b.b.b.b.b.b.b.b.b.b.b.b.b.b.b.b.b.b.b.b.##.......|
|.##b.b.b.b.b.b.b.b.b.b.b.b.b.b.b.b.b.b.b.b.b.b.b.b.b.##.........|
|.##b.b.b.b.b.b.b.b.b.b.b.b.b.b.b.b.b.b.b.b.b.b.b.b.b##..........|
|##ababababababababababababababababababababababababa##...........|
|##ababababababababababababababababababababababababa##...........|
|##ababababababababababababababababababababababababa##...........|
|##ababababababababababababababababababababababababab##..........|
|##a#a#a#a#a#a#a#a#a#a#a#a#a#a#a#a#a#a#a#a#a#a#a#a#a#a##.........|
|.###a#a#a#a#a#a#a#a#a#a#a#a#a#a#a#a#a#a#a#a#a#a#a#a#a#a##.......|
|.###a#a#a#a#a#a#a#a#a#a#a#a#a#a#a#a#a#a#a#a#a#a#a#a#a#a#a###....|
|..##a#a#a#a#a#a#a#a#a#a#a#a#a#a#a#a#a#a#a#a#a#a#a#a#a#a#a#a#####|
|..##aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa##|
|...##aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa##.|
|....##aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa##.|
|.....##aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa##..|
|.......##a#a#a#a#a#a#a#a#a#a#a#a#a#a#a#a#a#a#a#a#a#a#a#a#a###...|
|........###a#a#a#a#a#a#a#a#a#a#a#a#a#a#a#a#a#a#a#a#a#a#a####....|
|..........###a#a#a#a#a#a#a###############a#a#a#a#a#a#a####......|
|............#####a#a#a#a####...........####a#a#a#a######........|
|...............##########.................##########............|
```

```
EMPTY, LONGCODE $CF4B (file $4F0A1), 64x32
|...........................................#####................|
|........................................###...##................|
|.....................................###......##................|
|...................................###.......##.................|
|..................................##.......###..................|
|.................................##......###....................|
|.................................##...###.......................|
|...............##############....#####....############..........|
|..........#####..............###.......###............#####.....|
|.......####....................#########...................###..|
|.....###....................................................####|
|...##....................................................###....|
|..##...................................................##.......|
|.##..................................................##.........|
|.##.................................................##..........|
|##.................................................##...........|
|##.................................................##...........|
|##.................................................##...........|
|##..................................................##..........|
|##...................................................##.........|
|.##....................................................##.......|
|.##......................................................###....|
|..##........................................................####|
|..##..........................................................##|
|...##........................................................##.|
|....##.......................................................##.|
|.....##.....................................................##..|
|.......##..................................................##...|
|........###..............................................###....|
|..........###..............#############...............###......|
|............####........####...........####........#####........|
|...............##########.................##########............|
```

Close: LONGCODE $D235: CloseDialog, UpdateAll, InitCursor.

Cancel (filters only): after every row MAINE $277F calls GetNextEvent(mask $0408) and cancels on a
key-down whose character (high bit ignored) is "." with the Apple key down (modifiers bit
$0100). The filter stops, the rows already done stay filtered and the rest is unchanged, the
progress dialog closes and the program carries on exactly as after a normal finish (section 2.3,
including the Remap dialog). Escape does not cancel. The colour count cannot be cancelled.

### 2.5 Busy indicator

Operations without a progress dialog show no text. MAINE $278F turns on WaitCursor and a heartbeat
task (MAINE $27C8, every 6 ticks) that rotates the SCBs of scan lines 2-9 (line n takes line n+1's
SCB, line 9 takes line 2's), so the colour Apple in the menu bar cycles its stripes. MAINE $27AA
turns it off (DelHeartBeat, InitPalette, InitCursor). Used by Rotate/flip, Histogram equalization,
Convert to monochrome, monochrome to screen / true colour, screen to true colour, Negative image,
Monochrome image info and colour counts of fewer than 20 rows. None of these can be cancelled.

### 2.6 FRED option windows

The windows of sections 7, 8 and 10 are NewWindow2 templates in FRED: no title, frame $2000
(fAlert only: alert frame, not movable, created invisible), plane in front, control list given as
a pointer list, wInVerb $0003. The code passes a content draw procedure, creates the window, sets
control values and substitution strings, then ShowWindow.

- Run loop, FRED $ABFC [ModalMaster]: TaskMaster(mask $0FFF, task record FRED $ABCE). It returns
  the control ID for wInControl ($21) and 0 for anything else; clicks on the desktop, the menu bar,
  drag, grow, close or zoom areas and in other windows beep (AlwaysBeep(4), OSAYCANYOU $0A49:
  SysBeep2(4) on System 6, SysBeep before). MAINE $EFE3 runs before every TaskMaster call (it keeps
  the image window's selection outline moving).
- Keys are control key equivalents: OK = Return, Cancel = Escape, the "SKIP ME" check box =
  Control-S ($13); radio buttons and others as listed.
- When OK is clicked with "SKIP ME" checked the window is not shown next time and the last options
  are reused. Flags: MAINE $00D6 + kind (section 8), $00DA + kind (section 7), $00DE (section 10).
  The Preferences button "Clear all “SKIP ME” preferences" clears them.
- "Info on options..." opens the help window at a topic (ModalHelp, FRED $0972); the window stays.
- On OK or Cancel: CloseWindow, SetMenuBar(0), UpdateAll (OK only).

Icons drawn by these windows' content procedures (DrawIcon, mode 0): screen image OSAYCANYOU
$4453, true colour $44AB, monochrome $456F (icons 1, 2 and 4 of `superconvert-ui-data.md` section
6.2), and the arrow OSAYCANYOU $47C1 (file $574EC, 32x7, mask all set):

```
|.................###............|
|..................######........|
|...................#########....|
|################################|
|...................#########....|
|..................######........|
|.................###............|
```

## 3. Factor dialog (Blur, Sharpen, Find edges)

Code: SUPERFX $06E5, called by all three filters with the long value 8 (the window resource ID) on
the stack. Returns the factor, or $FFFF for Cancel.

Window: rWindParam1 8 (resource fork), content rect 83,206,130,432 (226 x 47), frame $206D
(fAlert, fQContent, fVis, fCtlTie and bits $0005), no title, wPlane $FFFFFFFF, control list
rControlList 8, wInVerb $0209. Raw template (80 bytes):

```
50 00 6D 20 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 53 00
CE 00 82 00 B0 01 FF FF FF FF 08 00 00 00 09 02
```

Controls (rControlList 8 = templates $35, $36, $37, $38, $39), local coordinates:

| Template | ID | Kind | Rect | Flag | More flags | Content |
|---|---|---|---|---|---|---|
| $35 | 1 | simple button | 29,124,42,198 | $0001 bold outline (default) | $3002 | "OK" (rPString 1), key Return ($0D/$0D, modifiers 0, care 0) |
| $36 | 2 | simple button | 29,29,42,108 | $0000 round | $3002 | "Cancel" (rPString 2), no key equivalent |
| $37 | 3 | edit line | 8,116,21,146 | $0000 | $7002 | maxSize 2, default text "50" (rPString $1E) |
| $38 | 4 | static text | 10,149,26,169 | $0000 | $1002 | "%" (rTextForLETextBox2 $C), textSize 1, just 0 |
| $39 | 5 | static text | 10,56,20,109 | $0000 | $1002 | "Factor:" (rTextForLETextBox2 $D), textSize 7, just 0 |

Raw control templates:

```
$35  09 00 01 00 00 00 1D 00 7C 00 2A 00 C6 00 00 00 00 80 01 00 02 30 00 00 00 00 01 00 00 00 00 00 00 00 0D 0D 00 00 00 00
$36  09 00 02 00 00 00 1D 00 1D 00 2A 00 6C 00 00 00 00 80 00 00 02 30 00 00 00 00 02 00 00 00 00 00 00 00 00 00 00 00 00 00
$37  08 00 03 00 00 00 08 00 74 00 15 00 92 00 00 00 00 83 00 00 02 70 00 00 00 00 02 00 1E 00 00 00
$38  09 00 04 00 00 00 0A 00 95 00 1A 00 A9 00 00 00 00 81 00 00 02 10 00 00 00 00 0C 00 00 00 01 00 00 00
$39  09 00 05 00 00 00 0A 00 38 00 14 00 6D 00 00 00 00 81 00 00 02 10 00 00 00 00 0D 00 00 00 07 00 00 00
```

Behaviour:

```
w = NewWindow2(title 0, refCon 0, contentDraw SUPERFX $07E6 (DrawControls), defProc 0,
               paramTableDesc 2 (resource), paramTableRef 8, resourceType $800E)
loop:
  hit = DoModalWindow(event record SUPERFX $0800, updateProc 0, eventHook 0, beepProc 0, flags $0008)
  if hit == 2: CloseWindow(w); UpdateAll; return $FFFF     ; the filter does nothing
  if hit != 1: continue
  GetLETextByID(w, 3, buffer SUPERFX $07FC)               ; Pascal string
  value = Dec2Int(buffer+1, length, unsigned)
  if error: AlertWindow($0024, 0, 5); continue           ; window stays open, text unchanged
  CloseWindow(w); return value
```

- Default: "50" for all three filters, every time. The window is rebuilt from the resource on each
  use and the value is not remembered.
- Check: only Dec2Int's error (ROM 3 Dec2Int at $FE/FA75): leading spaces are skipped; an empty
  or all-space field gives 0 without error; after that only digits are allowed, so "+", "-",
  letters or trailing spaces give an error. With maxSize 2 the accepted values are exactly 0-99.
  There is no other range check.
- Error message: rAlertString 5, the C string
  `33/Factor must be a number in the range 0-99./^#4` (size code 3, icon code 3, one button:
  standard button 4, "Try Again", default). AlertWindow flags $0024: bits 2-1 = 10 (string is a
  resource ID), bit 5 also set.
- What the factor does: section 11 (Blur, Sharpen, Find edges).

## 4. Rotate/flip image

### 4.1 Flow (LONGCODE $B8AC)

```
MakeAMap                                          ; may show section 10's window
tooBig = (width >= 801) or (height >= 655)        ; transpose needs a 100-byte x 655-row bitmap
bits = RotateDialog(tooBig) AND 7                 ; segment 2 $0AB9
if bits == 0: return                              ; Cancel, or no net change
UpdateAll; busy indicator on (2.5)
if bits & 1: mirror  (LONGCODE $B937)             ; swap x and width-1-x in every row
if bits & 2: flip    (LONGCODE $B9B8)             ; swap row y and height-1-y
if bits & 4: transpose (LONGCODE $BA57)           ; pixel (x,y) -> (y,x); width and height swap
busy off; MaybeBeep(5); image type = true colour; ImgChanged; MAINE $428C; Remap dialog (2.3)
```

The selection rectangle is mirrored, flipped and swapped along with the image. The order (mirror,
then flip, then transpose) is the same as GS Remap's `TrueColorImage.transformed`.

### 4.2 Dialog

Dialog Manager template, segment 2 $13F4 (file $01C44), opened with GetNewModalDialog: content rect
40,100,160,560, visible, refCon 0. Items (in template order):

| ID | Type | Rect | Text |
|---|---|---|---|
| 1 | button | 95,340,110,450 | "Make it so" (default item) |
| 2 | button | 75,340,90,450 | "Cancel" |
| 3 | button | 5,60,18,150 | "<< Rotate" |
| 4 | button | 5,170,18,260 | "Rotate >>" |
| 5 | button | 102,115,115,205 | "\/ Flip \/" (bytes 5C 2F 20 46 6C 69 70 20 5C 2F) |
| 6 | button | 54,265,67,355 | "> Flip >" |
| 7 | button | 92,10,105,100 | "// Twist" |
| 8 | button | 92,220,105,310 | "Twist \\" (two backslashes) |
| 16 | static text, disabled ($800F), itemFlag $0080 (hidden) | 5,280,55,450 | "The image is too big to\rbe rotated or twisted.\rOnly flips are allowed." |

```
d = GetNewModalDialog(2:$13F4)
if tooBig: ShowDItem(d, 16); RemoveDItem(d, 3); RemoveDItem(d, 4); RemoveDItem(d, 7); RemoveDItem(d, 8)
SetPort(d)
(a, b, c, d) = (1, 0, 0, 1)                       ; pending transform
Preview(100a, 100b, 100c, 100d, erase = 0)        ; segment 2 $0908
loop: hit = ModalDialog(filter 0) ... (below)
CloseDialog(d); return bits
```

Return is the Dialog Manager's default item (1). No other keys are handled.

### 4.3 The pending transform

The dialog keeps a 2x2 matrix M = [a b; c d] (entries -1, 0, 1). M maps image coordinates (x to
the right, y down, centred) to displayed coordinates: the pixel at (x, y) ends up at
(a*x + b*y, c*x + d*y). Each button multiplies M on the left, after an animation:

| Button | New M | Effect on the image |
|---|---|---|
| << Rotate | (a,b,c,d) <- (c, d, -a, -b) | 90 degrees anticlockwise |
| Rotate >> | (a,b,c,d) <- (-c, -d, a, b) | 90 degrees clockwise |
| \/ Flip \/ | (c, d) <- (-c, -d) | upside down |
| > Flip > | (a, b) <- (-a, -b) | mirror left/right |
| // Twist | (a,b,c,d) <- (c, d, a, b) | transpose: (x, y) -> (y, x), mirror about the top-left to bottom-right diagonal |
| Twist \\ | (a,b,c,d) <- (-c, -d, -a, -b) | (x, y) -> (-y, -x), mirror about the bottom-left to top-right diagonal |

"Make it so" (item 1) turns M into the bits:

```
bits = 0
if not tooBig and b != 0: bits |= 4; swap rows: (a,b,c,d) = (c,d,a,b)
if d < 0: bits |= 2; d = -d
if a < 0: bits |= 1; a = -a
; now M is the identity (the code stops at BRK $BC otherwise)
```

| Net M | Bits | Result |
|---|---|---|
| [1 0; 0 1] | 0 | nothing |
| [-1 0; 0 1] | 1 | mirror |
| [1 0; 0 -1] | 2 | flip |
| [-1 0; 0 -1] | 3 | rotate 180 |
| [0 1; 1 0] | 4 | transpose |
| [0 1; -1 0] | 5 | rotate 90 anticlockwise |
| [0 -1; 1 0] | 6 | rotate 90 clockwise |
| [0 -1; -1 0] | 7 | transpose + rotate 180 |

Cancel (item 2) returns 0.

### 4.4 Preview and animation

The preview is a framed "UP" drawn in the dialog's port. Shape table segment 2 $12F2 (file $01B42),
14-byte records: flag (1 = MoveTo, 0 = LineTo, -1 = end), x, y, current screen x, y, previous
screen x, y.

| # | Flag | x | y | Identity position (h, v) |
|---|---|---|---|---|
| 1 | Move | -4 | -3 | 80, 37 |
| 2 | Line | 4 | -3 | 240, 37 |
| 3 | Line | 4 | 3 | 240, 83 |
| 4 | Line | -4 | 3 | 80, 83 |
| 5 | Line | -4 | -3 | 80, 37 |
| 6 | Move | -3 | -2 | 100, 45 |
| 7 | Line | -3 | 2 | 100, 75 |
| 8 | Line | -1 | 2 | 140, 75 |
| 9 | Line | -1 | -2 | 140, 45 |
| 10 | Move | 1 | 2 | 180, 75 |
| 11 | Line | 1 | -2 | 180, 45 |
| 12 | Line | 3 | -2 | 220, 45 |
| 13 | Line | 3 | 0 | 220, 60 |
| 14 | Line | 1 | 0 | 180, 60 |

Preview(A, B, C, D, erase), segment 2 $0908 (C integer arithmetic, division truncates):

```
for each point: prev = cur
                cur.h = (x*A + y*B) / 5 + 160
                cur.v = (x*C + y*D) / 13 + 60
SetPenSize(2, 1)
if erase: SetPenMode(0); SetSolidPenPat($FFFF); walk the points using prev (white)
SetPenMode(0); SetSolidPenPat(1); walk the points using cur
```

Animation tables: COS = segment 2 $109C = 100, 98, 94, 87, 77, 64, 50, 34, 17, 0, -17, -34, -50,
-64, -77, -87, -94, -98, -100 (index 0-18, cos of 10-degree steps); SIN = $1058 = 0, 17, 34, 50,
64, 77, 87, 94, 98, 100 (index 0-9). Each step calls Preview(A, B, C, D, erase = 1); there is no
delay between steps.

| Button | Steps k | A, B, C, D |
|---|---|---|
| << Rotate | 1-9 | a*COS+c*SIN, b*COS+d*SIN, c*COS-a*SIN, d*COS-b*SIN |
| Rotate >> | 1-9 | a*COS-c*SIN, b*COS-d*SIN, c*COS+a*SIN, d*COS+b*SIN |
| \/ Flip \/ | 1-18 | 100a, 100b, c*COS, d*COS |
| > Flip > | 1-18 | a*COS, b*COS, 100c, 100d |
| // Twist | 1-18 | (COS(a-c)+100(a+c))/2, (COS(b-d)+100(b+d))/2, (COS(c-a)+100(a+c))/2, (COS(d-b)+100(b+d))/2 |
| Twist \\ | 1-18 | (COS(c+a)+100(a-c))/2, (COS(d+b)+100(b-d))/2, (COS(c+a)+100(c-a))/2, (COS(d+b)+100(d-b))/2 |

(COS and SIN stand for COS[k] and SIN[k].) The last step equals the new M times 100, so no final
redraw is needed.

## 5. True color image info

### 5.1 Flow (LONGCODE $C5D7)

```
MakeAMap
CountColors                                    ; LONGCODE $D83E, see 5.3
FormatDistinct                                 ; LONGCODE $D8D1: ParamText(0, 0, distinct, distribution)
SetParam(0, width); SetParam(1, height)        ; LONGCODE $D9C0: ParamText with only that slot set
d = GetNewModalDialog(LONGCODE $C477)
loop:
  hit = ModalDialog(filter $8000F471)          ; LONGCODE $F471 [prszFilter], high bit set
  if hit == 1: CloseDialog(d); return          ; "Done"
  if hit == 2: BRK at LONGCODE $C664            ; "Print" (see below)
  if hit >= 16: SetDItemValue(1, d, hit); SetDItemValue(hit, d, 15)   ; no such items exist
```

The filter [prszFilter] turns null events into "handled, item 0" and swallows update events for
other windows.

Print: item 2 branches straight to a BRK instruction (LONGCODE $C664, bytes 00 00), so in this
version clicking "Print" stops in the debugger or system monitor. The code after the BRK would
print the graph from the screen: HideCursor; PrPixelMap(LocInfo LONGCODE $C69F (SCB $80, pointer
$E12000, 160 bytes per row, bounds 0,0,200,640), source rect 20,230,185,610 (the graph item on
screen), colour 1); ShowCursor.

### 5.2 Dialog

Template LONGCODE $C477 (file $4E5CD): content rect 20,20,190,620, visible $FFFF, refCon 0. Items
in template order:

| ID | Type | Rect | Content |
|---|---|---|---|
| 15 | user item, disabled ($8014) | 0,210,165,590 | value 16, draw procedure LONGCODE $C6B7 (the graph) |
| 1 | button | 152,30,165,150 | "Done" (default item) |
| 2 | button | 130,40,143,140 | "Print" |
| 8 | long static text 2, disabled ($8016) | 5,10,50,190 | 83 characters, below |

Item 8 text (CR = \r):

```
Image size: ^0 by ^1 \rDistinct colors: ^2 \rDistribution: ^3 \r\r\r\r\r\rColor histograms:
```

Substitutions (each ParamText call passes 0 for the slots it does not set; the program relies on
those slots keeping their earlier strings):

| Param | Value | Format |
|---|---|---|
| ^0 | image width ($0F3F) | Int2Dec with exactly the number of digits needed (1-5) |
| ^1 | image height ($0F41) | same |
| ^2 | number of distinct 12-bit colours | Int2Dec into 4 characters, right-justified with leading spaces (e.g. "  56") |
| ^3 | distribution | "full color", "grayscale" or "B & W only" |

Example: "Image size: 320 by 200 ", "Distinct colors:   56 ", "Distribution: full color ".

The item rectangle is only 45 pixels high; see section 13 about the last line.

### 5.3 Statistics

Colour count, LONGCODE $D3DC, one row per call; LONGCODE $0F77 counts the rows done (0 clears the
table first). LONGCODE $D83E calls it for all remaining rows: with fewer than 20 rows left under
the busy indicator, otherwise inside the progress dialog "Counting colors used, please wait"
(no cancel).

```
for every pixel p of the whole image (not the selection):
  if p is grey: c = $111 * (g >> 4)               ; table LONGCODE $D81E
  else:         c = p AND $0FFF                    ; high nibbles R4 G4 B4
  if count[c] == 0: (also records the colour in a 256-entry list, not used here)
  if count[c] != $FFFF: count[c] += 1              ; 16-bit counts, saturating
distinct = number of c with count[c] > 0           ; LONGCODE $D49D
```

Distribution, LONGCODE $D8D1:

```
if distinct >= 17: "full color"
else:
  n = distinct - (count[$000] > 0) - (count[$FFF] > 0)
  if n == 0: "B & W only"
  else:
    n -= number of present colours among $111, $222, ... $EEE
    "grayscale" if n == 0 else "full color"
```

### 5.4 Histogram graph (LONGCODE $C7C5, called by $C6B7)

The item procedure: WaitCursor; EraseRect(0,210,165,590); draw (values 16 and >= 20 draw this
graph; 17-19 would call LONGCODE $CAB2, which is unreachable); InitCursor. Coordinates are local
to the dialog; system font; DrawChar/DrawString with the port's default colours.

Axes and labels (pen 2 wide x 1 high, solid pattern 0 = black):

| Element | Calls |
|---|---|
| Y axis | MoveTo(230,5); LineTo(230,140) |
| X axis | LineTo(588,140) |
| zero tick | MoveTo(220,135); LineTo(230,135) |
| "^FREQUENCY" | one character per line: MoveTo(210, v); DrawChar for v = 30, 38, 46 ... 102 ("^", "F", "R", "E", "Q", "U", "E", "N", "C", "Y") |
| "0" | MoveTo(210,139); DrawChar("0") |
| X ticks | for k = 0..15: x = 245 + 22k; MoveTo(x,140); LineTo(x,144) |
| X labels | MoveTo(x - 3, 153); DrawChar of hex digit k ("0" ... "9", "A" ... "F") |
| "INTENSITY >" | MoveTo(370,164); DrawString |

Bins: three histograms of 16 bins (32-bit) over the 4096 colour counts of 5.3: red bin = R4 of
the 12-bit colour, green = G4, blue = B4; each bin adds the counts of all colours with that
nibble (LONGCODE $C9AF, $C9D9, $CA04). Grey pixels count in all three at the same nibble.

Scale and polyline (LONGCODE $CA47):

```
scale = (width * height) / 200                   ; LongDivide, truncated
y(k)  = 133 - LOWORD(bin[k] / scale) + dy        ; LongDivide
MoveTo(240 + dx, y(0))
for k = 1..15: LineTo(240 + 22k + dx, y(k))
```

| Line | Pen pattern (32 bytes) | Pen size (w x h) | dx, dy | Look with the desktop palette |
|---|---|---|---|---|
| red, drawn first | LONGCODE $C557: $44 x 32 (pixels 1,0,1,0) | 12 x 6 | 0, 0 | red / black columns (dark red) |
| green | LONGCODE $C577: $AA x 32 (2,2,2,2) | 8 x 4 | 2, 1 | green / yellow |
| blue, drawn last | LONGCODE $C597: $DD x 32 (3,1,3,1) | 4 x 2 | 4, 2 | white / blue columns (dotted blue) |

The three pens are centred on each other (centres x = 245.5 + 22k, y = y(k) + 2.5), so where the
channels agree the line shows red edges, green inside and a blue core. A bin holding all pixels
lies 200 pixels above the baseline, i.e. far above the item (clipped). An empty bin is drawn at y
133-138, just above the X axis at 140. A fourth pattern at LONGCODE $C5B7 ($66 x 32) is unused.

## 6. Histogram equalization

LONGCODE $E796 [DoEqualize]. Despite the "..." there is no dialog: MakeAMap, then the busy
indicator, no progress message, no cancel. It works on the whole image.

```
hist[0..255] = 0                                 ; 32-bit, LONGCODE $4F8C
for each pixel: (R, G, B) = decode8(pixel)       ; DYNAMIFF, section 2.1
                hist[R]++; hist[G]++; hist[B]++  ; one histogram for all three channels
T = bytes * 3 / 2                                ; = 3 * number of pixels
v0 = lowest level with hist[v0] > 0
map[v] = 0 for v <= v0
cum = hist[v0]
for v = v0+1 .. 255: cum += hist[v]; map[v] = (cum * 255) / T     ; LongMul, LongDivide, truncated
for each pixel: (R, G, B) = decode8(pixel)
                pixel = encode8(map[R], map[G], map[B])
```

The map is stored as bytes at MAINE $4017. Then: colour count cache reset, image type true colour,
ImgChanged, busy off, MAINE $428C, Remap dialog (2.3).

## 7. Convert to monochrome (Screen and True color menus)

### 7.1 Window

FRED $C81C [ToMonoDlg], kind 0 = from the screen image (Screen menu), kind 2 = from the true colour
image (True color menu). Template FRED $C591 (file $2EE75): content 50,120,145,520 (95 x 400),
frame $2000, content procedure FRED $CB02 [ToBWRedraw].

| ID | Kind | Rect | Flag | More | Content |
|---|---|---|---|---|---|
| 32 | pop-up | 17,10,0,0 (sized by the control) | $0042 | $3004 | titleWidth 0; menu text FRED $C6EA |
| 33 | pop-up | 17,210,0,0 | $0042 | $3004 | titleWidth 0; menu text FRED $C73F |
| 34 | pop-up | 33,10,0,0 | $0042 | $3004 | titleWidth 0; menu text FRED $C792 |
| 0 | static text | 50,15,60,500 | $0002 (substitution) | $1000 | "Image will be *0 by *1*2. *3" |
| 1 | simple button | 65,300,78,380 | $0001 default | $3000 | "OK" (OSAYCANYOU $0EF7), key Return |
| 3 | simple button | 65,200,78,280 | $0000 | $3000 | "Cancel" (OSAYCANYOU $0EE8), key Escape |
| 4 | simple button | 65,15,78,170 | $0000 | $3000 | "Info on options..." |
| 2 | check box | 82,10,0,0 | $0000 | $3000 | "SKIP ME: always use these options" (OSAYCANYOU $0F16), value 0, key Control-S |

Pop-up menus (Menu Manager text; the number after \N is the item ID = the pop-up value):

```
FRED $C6EA  ##  Horizontal size:  \N1\r--1X\N1\r--2X\N2\r--4X\N4\r.
FRED $C73F  ##  Vertical size:  \N1\r--1X\N1\r--2X\N2\r--4X\N4\r.
FRED $C792  ##  Rendering method:  \N1\r--Error diffusion\N1\r--Pattern dither\N2\r--Halftone\N4\r--50% threshold\N3\r.
```

ToBWRedraw: DrawControls; DrawIcon(source icon: screen $4453 for kind 0, true colour $44AB for
kind 2, at h 160, v 4); DrawIcon(arrow $47C1, h 184, v 6); DrawIcon(monochrome $456F, h 224, v 4).

Values: horizontal size FRED $C57F, vertical $C581, method $C583, all 1 at start (1X, 1X, Error
diffusion). The last values are kept for the session (shared by both kinds) and copied into the
pop-ups' initialValue fields before NewWindow2; "SKIP ME" saves a copy per kind at $C585/$C589/$C58D
+ kind.

Substitutions (OSAYCANYOU $78FE..$7A0B, strings set with SetCtlParamPtr):

| | Value |
|---|---|
| *0 | result width = selection width x horizontal size (capped at 5000) |
| *1 | result height = selection height x vertical size (capped at 5000) |
| *2 | " (clipped)" if either was capped, else empty |
| *3 | "(not enough memory?)" if NewHandle(((width + 7) / 8) * height) fails, else empty |

The selection is the info bar selection (the whole image when nothing is selected). The window
recomputes and invalidates the text rectangle after every click. Buttons: OK converts, Cancel
returns, "Info on options..." shows help topic "OTHER2MONO" (kind 0) or "OTHER2MONO2" (kind 2).

### 7.2 Conversion (FRED $CC07, busy indicator, no cancel)

1. Intensity of each source pixel, 0-255 (linear light):
   - screen pixel with 4-bit palette colour (r, g, b): RT4[r] + GT4[g] + BT4[b];
   - true colour grey pixel g: GREY[g] (LONGCODE $B563) = round(g*g/255);
   - true colour colour pixel (5-bit r, g, b): RT5[r] + GT5[g] + BT5[b], with
     XT5[v] = round(k * 255 * (v/31)^2), k = 0.30, 0.59, 0.11.

   | Table | Values |
   |---|---|
   | RT4 (FRED $CBA5) | 0 0 1 2 4 7 10 14 19 25 31 39 47 56 66 77 |
   | GT4 (FRED $CBC5) | 0 1 2 4 8 13 20 28 38 49 62 76 92 110 129 150 |
   | BT4 (FRED $CBE5) | 0 0 0 1 2 3 4 5 7 9 11 14 17 20 24 28 |
   | RT5 (FRED $CE6A) | 0 0 0 1 1 2 3 4 5 6 8 10 11 13 16 18 20 23 26 29 32 35 39 42 46 50 54 58 62 67 72 77 |
   | GT5 (FRED $CEAA) | 0 0 1 1 3 4 6 8 10 13 16 19 23 26 31 35 40 45 51 57 63 69 76 83 90 98 106 114 123 132 141 150 |
   | BT5 (FRED $CEEA) | 0 0 0 0 0 1 1 1 2 2 3 4 4 5 6 7 7 8 9 11 12 13 14 15 17 18 20 21 23 25 26 28 |

   Screen pixels: in 320 mode each nibble is a pixel; in a 640-mode screen, lines with a 640 SCB
   give four pixels per byte where pixel k of the byte (k = 0 leftmost) uses palette entry 4k +
   value, and 320 lines give each pixel twice. The palette is the line's SCB palette.
2. Scaling: output pixel (x, y) takes source pixel (x / H, y / V) (H, V = 1, 2 or 4).
3. Rendering, output bit 1 = white (FRED $CF2A), x and y being output coordinates:

   | Method (value) | Rule |
   |---|---|
   | 50% threshold (3) | white if L >= 128 |
   | Pattern dither (2) | white if L >= PD[y AND 7][x AND 7] |
   | Halftone (4) | white if L >= HT[y AND 7][x AND 7] |
   | Error diffusion (1) | Burkes, left to right on every row, see below |

   PD (FRED $D09D) = 4 x (8x8 Bayer) + 2; HT (FRED $D11D) is a clustered screen:

   ```
   PD                                   HT
     2 130  34 162  10 138  42 170       250 234 170  58   6  70 182 246
   226  66 194  98 234  74 202 106       218 186 122  10  50  30 142 202
    50 178  18 146  58 186  26 154       154  90  82 114 162  98  74 102
   210 114 242  82 218 122 250  90        42  34 146 210 226 194 134  22
    14 142  46 174   6 134  38 166         2  66 178 242 254 238 174  62
   238  78 206 110 230  70 198 102        54  26 138 206 222 190 126  14
    62 190  30 158  54 182  22 150       166 106  78 110 158  94  86 118
   222 126 254  94 214 118 246  86       230 198 130  18  46  38 150 214
   ```

   Error diffusion (FRED $D012), errors in signed 16-bit, shifts are arithmetic (floor):

   ```
   v = L + err_cur[x]
   if v < 0:          bit = 0 (black), e = 0
   elif v >= 256:     bit = 1 (white), e = 0
   elif v >= 128:     bit = 1, e = v - 255
   else:              bit = 0, e = v
   e4 = e >> 2;  e8 = e4 >> 1;  e16 = e8 >> 1
   err_cur[x+1] += e4;   err_cur[x+2] += e8
   err_next[x-2] += e16; err_next[x-1] += e8; err_next[x] += e4; err_next[x+1] += e8; err_next[x+2] += e16
   ```

   The error buffer (LONGCODE $5F34, 2503 words) starts at zero for the whole image.
4. The result becomes the monochrome image (SetMonoSize FRED $87B9), image type monochrome.

## 8. Monochrome > Convert to screen / Convert to true color

### 8.1 Window

FRED $8BF4 [FroMonoDlg], kind 0 = to screen ([ScrFroMono]), kind 2 = to true colour
([GenFroMono]). Template FRED $830B (file $2ABEF): content 30,120,170,520 (140 x 400), frame
$2000, content procedure FRED $8FED [FrBWRedraw].

| ID | Kind | Rect | Flag | More | Content |
|---|---|---|---|---|---|
| 0 | static text | 15,10,25,170 | $0000 | $1000 | "Resulting image:" |
| 0 | static text | 69,160,105,500 | $0002 (substitution) | $1000 | "Monochrome pixels\r*0 x *1\r" + $01 "CUU" + "Resulting pixels\r*2 x *3*4*5*6*7" |
| 2 | check box | 127,10,0,0 | $0000 | $3000 | "SKIP ME: always use these options", key Control-S |
| 32 | pop-up | 17,210,29,390 | $0042 | $3004 | titleWidth 105; menu FRED $8592 |
| 33 | pop-up | 33,210,45,370 | $0042 | $3004 | titleWidth 105; menu FRED $85F5 |
| 34 | pop-up | 49,10,0,0 | $0042 | $3004 | titleWidth 0; menu FRED $864E |
| 1 | simple button | 110,300,123,380 | $0001 default | $3000 | "OK", key Return |
| 3 | simple button | 110,200,123,280 | $0000 | $3000 | "Cancel", key Escape |
| 4 | simple button | 110,15,123,170 | $0000 | $3000 | "Info on options..." |

Added after NewWindow2 with NewControl2 (input descriptor 3, list FRED $8715 for kind 0, $8721
for kind 2):

| ID | Kind | Rect | Title kind 0 | Title kind 2 | Key |
|---|---|---|---|---|---|
| 16 | radio, family 0 | 25,10,0,0 | "320 mode" | "320-sized pixels" | "3" (Apple key up) |
| 17 | radio, family 0 | 35,10,0,0 | "640 mode" | "640-sized pixels" | "6" (Apple key up) |

The $01 "C" "UU" in the long text is a LETextBox2 colour command: "Resulting pixels" and the
following line are drawn in colour $5555 (pixel value 1).

```
FRED $8592  ##  Aspect ratio:  \N1\r--Square\N1*Ss\r--Tall\N2*Tt\r--Wide\N3*Ww\r.
FRED $85F5  ##  Scaling:  \N1\r--1:1\N1*11\r--1:2\N2*22\r--1:4\N4*44\r.
FRED $864E  ##  Shrink as:  \N1\r--Grayscale\N1\r--Black & white (50% threshold)\N2\r--B&W (line art on white background)\N3\r--B&W (line art on black background)\N4\r.
```

Values (FRED $80E9 aspect, $80EB scaling, $80ED 640 flag, $80EF shrink): 1 (Square), 1 (1:1), 0
(320), 1 (Grayscale) at start; kept for the session and shared by both kinds; "SKIP ME" copies
per kind at $8E35/$8E39/$8E3D/$8E41 + kind. Radio 16 + flag is set on before showing.

Sizes and texts (FRED $8E60), recomputed after every click:

```
w = selection width, h = selection height (monochrome pixels)
*0 = w, *1 = h
if 640: w *= 2
Tall: h *= 2;  Wide: w *= 2
1:2: w = (w+1)/2, h = (h+1)/2;   1:4: the same twice
*2 = w, *3 = h; *4..*7 empty
"Shrink as" is dimmed (hilite 255) unless the result is smaller than the source in width or height
kind 0: if bytes per line ((w/2, then /2 again for 640) > 320) or h > 400 or bytes*h >= 65536:
        *4 = " (will be clipped)"
kind 2: if w > 2000 or h > 2000: *4 = " (will be clipped)"
        elif NewHandle(w*2*h) fails: *4 = " (not enough memory?)"
```

Help topics: "MONO2OTHER" (kind 0), "MONO2OTHER2" (kind 2).

FrBWRedraw draws, besides DrawControls:

- DrawIcon(monochrome $456F, h 160, v 4); arrow $47C1 at (184, 6); screen $4453 (kind 0) or true
  colour $44AB (kind 2) at (224, 4);
- if rect 70,10,105,140 meets the visible region: EraseRect(70,10,105,140); PenNormal;
  SetPenSize(2,1); SetPenPat(32 x $CC); MoveTo(137,73) LineTo(156,77); SetSolidPenPat(1);
  MoveTo(138,87) LineTo(156,95) (two pointer lines from the text to the drawing);
- grid of screen pixels with the same pen: horizontal lines MoveTo(10,v) LineTo(138,v) for v = 70,
  87, 104; vertical lines MoveTo(h,70) LineTo(h,104) for h = 10, 42, 74, 106, 138 (step 16 in 640
  mode: 10, 26 ... 138);
- monochrome pixels as inverted cells: height H and width W from scaling: 1:1 -> 14, 28; 1:2 -> 6,
  12; 1:4 -> 2, 4; Tall: H = 2H + 2 (30 becomes 31); Wide: W = 2W + 4. Cells InvertRect(top,
  left, top + H, left + W) for left = 13, then left = right + 4 while right + 4 < 140; top = 72,
  then top = bottom + 2 (88 becomes 89) while top < 105.

### 8.2 Conversion values (FRED $94DB [MExpand])

For each output pixel the routine adds a weight for every black monochrome pixel it covers, giving
0 (all white) .. 16 (all black). Mode = aspect, scaling and 640 flag:

| Aspect | Scale | Mode | Source rows per output row | Output pixels per source pixel / source pixels per output pixel | Weight |
|---|---|---|---|---|---|
| Square | 1:1 | 320 | 1 | 1 / 1 | 16 |
| Square | 1:2 | 320 | 2 | 1 / 2 | 4 |
| Square | 1:4 | 320 | 4 | 1 / 4 | 1 |
| Tall | 1:1 | 320 | 1/2 (each row twice) | 1 / 1 | 16 |
| Tall | 1:2 | 320 | 1 | 1 / 2 | 8 |
| Tall | 1:4 | 320 | 2 | 1 / 4 | 2 |
| Wide | 1:1 | 320 | 1 | 2 / 1 | 16 |
| Wide | 1:2 | 320 | 2 | 1 / 1 | 8 |
| Wide | 1:4 | 320 | 4 | 1 / 2 | 2 |
| Square | 1:1 | 640 | 1 | 2 / 1 | 16 |
| Square | 1:2 | 640 | 2 | 1 / 1 | 8 |
| Square | 1:4 | 640 | 4 | 1 / 2 | 2 |
| Tall | 1:1 | 640 | 1/2 | 2 / 1 | 16 |
| Tall | 1:2 | 640 | 1 | 1 / 1 | 16 |
| Tall | 1:4 | 640 | 2 | 1 / 2 | 4 |
| Wide | 1:1 | 640 | 1 | 4 / 1 | 16 |
| Wide | 1:2 | 640 | 2 | 2 / 1 | 8 |
| Wide | 1:4 | 640 | 4 | 1 / 1 | 4 |

(Tables FRED $9673, $96A3, $96D3, $9703.) If the weight is not 16 and Shrink is not Grayscale,
each value becomes 16 if value >= threshold else 0, thresholds (FRED $966D): Black & white (50%)
8, line art on white 1, line art on black 16. MExpand reports "grey levels present" only for
Grayscale with a weight below 16.

### 8.3 To screen ([ScrFroMono], FRED $C32D)

Busy indicator; height capped at 400; bytes per line = w/2 (320) or w/4 (640), rounded up; the
screen buffer is allocated by MAINE $4E16 and, if that fails, the line length is reduced one byte
at a time until it fits. Pixel value from the 0..16 value v:

| Mode | Pixel value for v = 0 .. 16 |
|---|---|
| 320 | 15 15 14 14 13 12 12 11 11 10 9 8 7 6 5 3 0 (FRED $C49F/$C4B0) |
| 640 | 3 3 3 3 2 2 2 2 2 1 1 1 1 1 0 0 0 (FRED $C4C1 ...) |

All SCBs are set to $00 or $80 and palette 0 is loaded:

| Case | Routine | Palette |
|---|---|---|
| 320, no grey levels | MAINE $4CD5 | 000 777 841 72C 00F 080 F70 D00 FA9 FF0 0E0 4DF DAF 78F CCC FFF (standard) |
| 320, grey levels | MAINE $4CED | 000 111 222 333 444 555 666 777 888 999 AAA BBB CCC DDD EEE FFF |
| 640, no grey levels | MAINE $4CDD | 000 F00 0F0 FFF 000 00F FF0 FFF (x2, standard) |
| 640, grey levels | MAINE $4CC3 | 000 777 CCC FFF (x4) |

Image type becomes screen.

### 8.4 To true colour ([GenFroMono], FRED $BFE2)

Width and height capped at 2000; busy indicator; each output pixel becomes a grey pixel word from
FRED $C09E indexed by v: 255 247 239 230 221 211 202 191 180 169 156 143 128 110 90 64 0
(= round(255 * sqrt((16 - v)/16))). The image is marked as having 640-shaped pixels (MAINE $0538)
when "640-sized pixels" was chosen; the remap mode (LONGCODE $0F31) becomes 0 for 320, or 2 (640
dither) unless it already was 1 or 2. Image type becomes true colour.

## 9. Monochrome image info, Negative image

Monochrome image info, FRED $92F4 [MonoInfo] (after MakeAMono): busy indicator, count of white
pixels (1 bits, popcount table FRED $80FB) inside the selection, then

```
AlertWindow($0000, substitution array OSAYCANYOU $7886, C string FRED $9483)
"60~The *0monochrome image is *1 by *2.\r\r*3% of the pixels (*4 out of *6) are white.~^#0"
```

Size code 6, icon code 0 (none), "~" separates the parts, one default button: standard button 0
("OK"). Substitutions: *0 = "selected area of the " when a selection exists (MAINE $E184 <> 0),
else empty; *1 = width, *2 = height (exact digits); *3 = white*100 / (width*height) truncated;
*4 = white count, *6 = width*height (Long2Dec, leading spaces removed; *5 is skipped because *4
may run into its slot).

Negative image, FRED $928E [DoNegative]: MakeAMono, busy indicator, every bit inside the selection
rectangle inverted (EOR), image type monochrome. No dialog.

## 10. Screen > Convert to true color (exact or smoothed)

### 10.1 When it appears

Scrn2True (FRED $C0C0) calls MakeAMapAnyway, which converts the screen selection. For a 320-mode
screen there is no window (exact conversion). For a 640-mode screen FRED $BF10 shows the window
unless its "SKIP ME" flag (MAINE $00DE) is set. The same window therefore also appears before any
True color command when only a 640-mode screen image exists.

### 10.2 Window

Template FRED $BC74 (file $2E558): content 40,132,150,512 (110 x 380), frame $2000, content
procedure FRED $C0EE [ScTcRedraw].

| ID | Kind | Rect | Flag | More | Content |
|---|---|---|---|---|---|
| 1 | simple button | 75,290,88,360 | $0001 default | $3000 | "OK", key Return |
| 2 | simple button | 75,180,88,270 | $0000 | $3000 | "Cancel", key Escape |
| 3 | simple button | 75,10,88,160 | $0000 | $3000 | "Info on options..." (help topic "SCRN2TRUE") |
| 4 | check box | 95,10,104,280 | $0000 | $3000 | "SKIP ME: always use this option", value 0, key Control-S |
| 5 | radio, family 0 | 50,10,59,380 | $0000 | $3000 | "Exact: each pixel retains its individual color", value 1, key E/e |
| 6 | radio, family 0 | 60,10,69,380 | $0000 | $3000 | "Smoothed: dither patterns become a solid color", value 0, key S/s |
| 7 | static text | 18,10,45,371 | $0000 | $1000 | "A 640 mode screen image is being converted to true color, which can be done in either of two ways depending on the eventual use of the image:" (141 characters) |

ScTcRedraw: DrawControls; DrawIcon(screen $4453, h 150, v 4); arrow $47C1 at (174, 6); true
colour $44AB at (214, 4).

If the last choice was Smoothed (FRED $BB44 <> 0) radio 6 is turned on before showing, so the
choice is remembered for the session. OK stores radio 6's value in $BB44 and the check box in
$00DE; Cancel returns $FFFF and the command is cancelled.

### 10.3 Conversion (FRED $B845 onward, busy indicator)

The true colour image gets the selection size (640 pixels wide per 640 screen pixel, image marked
640-shaped, MAINE $0538 = 1) and remap mode 1 (four pure colours) when palette 0's entries 0-11
equal entries 4-15, else 2 (640 dither). For each line, with the line's SCB palette P:

- Exact: every pixel becomes Scrn2Map(P[entry]) (section 2.1); pixel k of a byte uses entry 4k +
  value; a 320-mode line inside a 640 screen gives each pixel twice.
- Smoothed:

```
canon[e] = first index i with P[i] == P[e]          ; equal colours share one index
code[x]  = canon[e] * 17                              ; byte (c << 4) | c
append three sentinel values $63, $64, $65
x = 0
while x < n:
  if code[x] == code[x+1]: skip the whole run of equal codes
  elif code[x] == code[x+2] == code[x+4] and code[x+1] == code[x+3]:
     a = code[x]; b = code[x+1]; pair = (b AND $F0) | (a AND $0F)
     replace code[x] and every following pixel while the pattern a, b, a, b ... continues
       (it also stops at the first pixel that equals its right neighbour) by pair
  else x += 1
pixel = BLEND[code]                                    ; 256 entries
BLEND[(i << 4) | j] = blend of P[j] and P[i]:  per channel
   s = SQ[c1] + SQ[c2];  v5 = largest k with TH[k] <= s;  stored as a 15-bit word (or grey if equal)
SQ (FRED $BB4E) = 0 1 4 9 17 27 39 54 70 90 111 135 161 190 221 255
TH (FRED $BB6E) = 0 1 1 2 5 8 13 19 26 34 43 54 65 78 92 107 123 141 159 179 200 222 247 270 296 323 351 380 411 443 476 509
```

In Smoothed mode even single pixels go through BLEND (colour c with itself), so their 5-bit
channels come from the SQ/TH tables instead of Scrn2Map.

## 11. The SUPERFX filters compared with GS Remap

### 11.1 Driver (SUPERFX $0000)

Called with a name (Pascal string, shown in the progress dialog) and three channel procedures;
the first (red) is called first and, for most filters, computes all three channels.

```
MakeAMap; MAINE $421F; OpenProgress(name)
colour count cache = 0
three rolling row buffers per channel (rows y-1, y, y+1), 5-bit values, edges repeated:
   buffer word 0 = copy of pixel 0, words 1..w = pixels 0..w-1, beyond the right edge = last pixel,
   row -1 = row 0, row h = row h-1
for y = 0 .. h-1:
   load row y+1, then for x = w-1 down to 0:
     n0..n8 = 3x3 neighbourhood (n0 = (x-1,y-1), n1 = (x,y-1), n2 = (x+1,y-1),
              n3 = (x-1,y), n4 = (x,y), n5 = (x+1,y), n6 = (x-1,y+1), n7 = (x,y+1), n8 = (x+1,y+1))
     R = procR(R-neighbourhood); G = procG(...); B = procB(...)
     pixel(x, y) = encode5(R, G, B)            ; section 2.1, no clamping in the driver
   UpdateProgress(y, h); if Apple-period: stop
CloseProgress; then 2.3
```

The rows are read before they are overwritten, so every result uses original pixels. The whole
image is processed (no selection).

### 11.2 Arithmetic, all on 5-bit channels (0-31)

| Filter | Code | Original (5-bit) | GS Remap Filters.swift (8-bit) | Difference |
|---|---|---|---|---|
| Median | $03BE | 5th smallest of n0..n8 | `sorted()[4]` | none apart from precision |
| Sigma | $0494 | average of the neighbours within -32..+32 of n4 (always all nine on 5-bit values), truncated: floor(sum / 9) via a shift-subtract divide | `(sum + 4) / 9`, rounded | original truncates |
| Emboss | $059C | -n0 - 2n1 - 2n3 + 2n5 + 2n7 + n8 + 16, clamped 0..31 | same with +128, clamped 0..255 | precision |
| Blur | $08B4 | w = ((100 - f) >> 1) - 13; d = w + 12, or 1 if d <= 0; sum = n0 + 2n1 + n2 + 2n3 + w*n4 + 2n5 + n6 + 2n7 + n8 (16-bit); result = UDivide(sum + (d >> 1), d), not clamped | same formula, result clamped 0..255 | for f >= 75 (w < 0) the original's sum can be negative or exceed 31d; the unsigned 16-bit division and the unclamped encoder then give garbage pixels (factor 99 corrupts every non-black pixel). For f <= 74 the result is always 0..31 and the formula matches |
| Sharpen | $0B11 | w = ((100 - f) >> 1) + 13; d = w - 12 (>= 1); sum = -n0 - 2n1 - n2 - 2n3 + w*n4 - 2n5 - n6 - 2n7 - n8; sum < 0 -> 0; sum > 31d -> 31; else (sum + (d >> 1)) / d | same, clamp via min(255) | precision only |
| Solarize | $0D7E | n4 > 16 -> 31 - n4, else n4 | v > 132 -> 255 - v | threshold 16 of 31 (8-bit grey 136 and up in the original) |
| Find edges | $0E79 | G = FixDiv((100 - f) << 16, 20 << 16) + $18000; Q = G >> 2 (16.16 fixed); result = floor(n4*G / 65536) - sum over n0, n2, n6, n8 of floor(n*Q / 65536), clamped 0..31 | `round(gain * (n4 - (n0+n2+n6+n8)/4))` in floating point, gain = (100-f)/20 + 1.5 | each term truncated separately in the original; FixDiv rounding of G (section 12) |
| Increase / Decrease contrast | $16D2 / $1764 | HSV in 16.16 fixed point, V' = V +- (curve(V) - V)/2 with curve = (sin(pi(V - 1/2)) + 1)/2 from FracSin, output rounded to 5 bits (section 12) | 8-bit table, channels scaled by table[max]/max | same idea; exact values differ (FracSin error, fixed-point rounding, 5-bit output) |

Further differences that apply to every filter:

- Input is 5-bit: colour channels as stored, grey pixels g >> 3. With MegaconvertGS's 24-bit
  pixels: v5 = v8 >> 3.
- Output: if the three results are equal the pixel becomes grey v5*8 (so 31 -> 248, never 255);
  otherwise a 15-bit colour (shown as rrrrr rrr). GS Remap keeps 8-bit values.
- Apple-period cancels after any row and keeps the partial result.
- Histogram equalization (LONGCODE, section 6) differs completely from GS Remap's
  `Filters.equalize`: GS Remap equalizes luminance, keeps hue, and uses
  (running - lowest)*255/(total - lowest); the original builds one histogram of all R, G and B
  samples, maps each channel separately and uses cum*255/(3N) with the lowest level forced to 0.

### 11.3 Contrast in detail (SUPERFX $1527, $12BC, $103E)

All values are 16.16 fixed point (1.0 = $10000); FixDiv, FixMul as in section 12.

```
RGB to HSV (SUPERFX $12BC), R, G, B = 0..31:
  r, g, b = FixDiv(R<<16, 31<<16), ...
  V = r; if G >= R: V = g; if B >= max(R, G): V = b
  m = r; if G < R: m = g; if B < min(R, G): m = b
  H = $FFFF0000 (undefined); S = 0
  if V != 0: S = FixDiv(V - m, V)
  if S == 0: done
  if r == V:   H = FixDiv(g - b, V - m)
  elif g == V: H = FixDiv(b - r, V - m) + 2.0
  else:        H = FixDiv(r - g, V - m) + 4.0
  H = FixMul(H, 60.0); if H < 0: H += 360.0

Contrast (SUPERFX $1527), dir = increase or decrease:
  x = FixMul(V - $8000, $0003243F)              ; pi in 16.16
  s = Frac2Fix(FracSin(x))
  curve = (s + $10000) >> 1                     ; unsigned shift
  dV = curve - V;  if decrease: dV = -dV
  V2 = V + FixMul(dV, $8000)
  if V2 >= $10000: V2 = $10000;  if V2 < 0: V2 = 0

HSV to RGB (SUPERFX $103E):
  out = (V2, V2, V2)
  if H != $FFFF0000 and S != 0:
     if H == 360.0: H = 0
     H = FixDiv(H, 60.0); i = H >> 16 (0 if negative); f = H - (i << 16)
     p = FixMul(V2, 1.0 - S)
     q = FixMul(V2, 1.0 - FixMul(S, f))
     t = FixMul(V2, 1.0 - FixMul(S, 1.0 - f))
     out = [(V2,t,p), (q,V2,p), (p,V2,t), (p,q,V2), (t,p,V2), (V2,p,q)][i]   (i < 6)
  channel = (FixMul(c, 31.0) + $8000) >> 16
```

V only takes the 32 values k/31, so the whole sine part reduces to the table in section 12.

## 12. Integer Math rounding and the contrast tables

The filters use the Integer Math tool set. ROM 3 behaviour (function table $FE/F043; FixMul
$FE/F28D, FixDiv $FE/F283, FracSin $FE/F4DB, Frac2Fix $FE/F7A8, Dec2Int $FE/FA75):

| Call | Result |
|---|---|
| FixMul(a, b) | sign * floor((abs(a)*abs(b) + $8000) / $10000): rounded to nearest, halves away from zero |
| FixDiv(a, b) | sign * round(abs(a) * $10000 / abs(b)), halves away from zero (one extra quotient bit decides) |
| Frac2Fix(x) | (x >> 14) rounded the same way |
| FracSin(x) | polynomial with range reduction; error about 3e-6, not the correctly rounded sine |
| overflow | $7FFFFFFF or $80000000 |

Examples: FixDiv(98<<16, 20<<16) = $0004E666 (4.9 rounded down), so for factor 2 the Find edges
gain is $00066666 and Q = $00019999; 5*Q = $7FFFD gives 7, not 8.

Contrast table (k = max(R, G, B) as 5-bit level; V = FixDiv(k<<16, 31<<16); s = Frac2Fix(FracSin(x));
grey result = output for R = G = B = k):

| k | V | s | V' increase | V' decrease | grey out (inc / dec) |
|---|---|---|---|---|---|
| 0 | $00000 | $FFFF0000 | $00000 | $00000 | 0 / 0 |
| 1 | $00842 | $FFFF0150 | $00475 | $00C0F | 1 / 1 |
| 2 | $01084 | $FFFF053E | $00991 | $01777 | 1 / 3 |
| 3 | $018C6 | $FFFF0BBD | $00F52 | $0223A | 2 / 4 |
| 4 | $02108 | $FFFF14BF | $015B3 | $02C5D | 3 / 5 |
| 5 | $0294A | $FFFF202B | $01CAF | $035E5 | 3 / 7 |
| 6 | $0318C | $FFFF2DE2 | $0243E | $03EDA | 4 / 8 |
| 7 | $039CE | $FFFF3DC2 | $02C57 | $04745 | 5 / 9 |
| 8 | $04211 | $FFFF4FA1 | $034F0 | $04F32 | 6 / 10 |
| 9 | $04A53 | $FFFF634E | $03DFD | $056A9 | 8 / 10 |
| 10 | $05295 | $FFFF7897 | $04770 | $05DBA | 9 / 11 |
| 11 | $05AD7 | $FFFF8F43 | $0513C | $06472 | 10 / 12 |
| 12 | $06319 | $FFFFA717 | $05B52 | $06AE0 | 11 / 13 |
| 13 | $06B5B | $FFFFBFD6 | $065A3 | $07113 | 12 / 14 |
| 14 | $0739D | $FFFFD93C | $0701D | $0771D | 14 / 14 |
| 15 | $07BDF | $FFFFF308 | $07AB1 | $07D0D | 15 / 15 |
| 16 | $08421 | $00000CF8 | $0854F | $082F3 | 16 / 16 |
| 17 | $08C63 | $000026C4 | $08FE3 | $088E3 | 17 / 17 |
| 18 | $094A5 | $0000402A | $09A5D | $08EED | 19 / 17 |
| 19 | $09CE7 | $000058E9 | $0A4AE | $09520 | 20 / 18 |
| 20 | $0A529 | $000070BD | $0AEC4 | $09B8E | 21 / 19 |
| 21 | $0AD6B | $00008769 | $0B890 | $0A246 | 22 / 20 |
| 22 | $0B5AD | $00009CB2 | $0C203 | $0A957 | 23 / 21 |
| 23 | $0BDEF | $0000B05F | $0CB0F | $0B0CF | 25 / 21 |
| 24 | $0C632 | $0000C23E | $0D3A9 | $0B8BB | 26 / 22 |
| 25 | $0CE74 | $0000D21E | $0DBC2 | $0C126 | 27 / 23 |
| 26 | $0D6B6 | $0000DFD5 | $0E350 | $0CA1C | 28 / 24 |
| 27 | $0DEF8 | $0000EB41 | $0EA4C | $0D3A4 | 28 / 26 |
| 28 | $0E73A | $0000F443 | $0F0AE | $0DDC6 | 29 / 27 |
| 29 | $0EF7C | $0000FAC2 | $0F66F | $0E889 | 30 / 28 |
| 30 | $0F7BE | $0000FEB0 | $0FB8B | $0F3F1 | 30 / 30 |
| 31 | $10000 | $00010000 | $10000 | $10000 | 31 / 31 |

Six of the s values (k = 2, 5, 7, 24, 26, 29) differ by one unit from a correctly rounded sine, so
a reimplementation must either call FracSin and Frac2Fix or use this table. With the table and
the FixMul/FixDiv rounding above, the rest of the contrast filter is exact integer arithmetic.

## 13. Uncertain points

- Only ROM 3 was examined for FixMul, FixDiv, FracSin, Frac2Fix and Dec2Int; ROM 01 is assumed to
  behave the same.
- True color image info: item 8's rectangle (5,10,50,190) holds only the first four or five text
  lines. If the Dialog Manager clips long static text to the item rectangle (assumed), "Color
  histograms:" is never visible. The display also assumes that ParamText keeps a slot unchanged
  when it is passed 0, which the program depends on.
- True color image info, Print: the BRK at LONGCODE $C664 was read from the file; what happens on
  a machine without a debugger (monitor or system error) was not checked.
- Rotate/flip: the preview is drawn right after GetNewModalDialog and before the first
  ModalDialog call. Whether the dialog's first update erases it was not checked.
- AlertWindow: the meaning of flag bit 5 ($0020), of the size and icon codes ("3"/"3", "6"/"0")
  and the button names for #0 ("OK") and #4 ("Try Again") are taken from the Window Manager's
  documented conventions, not re-derived. DoModalWindow flag $0008 is believed to be the I-beam
  cursor option.
- Factor dialog: whether the edit line starts with its text selected, and whether DoModalWindow
  maps Escape to Cancel (the Cancel template has no key equivalent), were not checked.
- Pop-up controls in FRED take a pointer to Menu Manager menu text with menu reference type bits
  01 in moreFlags; this works in the original but the Control Manager rule behind it was not
  checked.
- Screen pixels in 640 mode: both the monochrome conversion and the exact/smoothed conversion use
  palette entries 4k + value for pixel k of a byte (k = 0 leftmost). The display hardware uses 8-11,
  12-15, 0-3, 4-7. Results are the same for palettes whose groups repeat (all standard ones).
- Error diffusion buffer: 2503 words; results wider than about 2490 pixels would run past it.
- Histogram graph: images with fewer than 200 pixels give scale 0 (LongDivide by zero); not
  checked.
- 4-bit luminance tables RT4/GT4/BT4 are close to round(k*255*(n/15)^2.2) (GT4 differs at one
  entry); use the listed values.
