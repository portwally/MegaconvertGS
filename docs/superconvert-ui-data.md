# SuperConvert 4 user interface data

Reference data for rebuilding the SuperConvert main screen in MegaconvertGS, read from the
original program files: the data fork (an OMF load file, ProDOS type $B3, aux type $DB07,
758944 bytes) and the resource fork (36795 bytes). The resource fork names the program "SuperConvert™", version
4.0 (rVersion bytes 00A00004), "Copyright © 1992-1997 Seven Hills Software Corporation".

`superconvert-ui-data.json` holds the same data in machine-readable form, including the raw bytes
of every record, window block, control template and icon.

Conventions:

- Numbers starting with $ are hexadecimal.
- Rectangles are [top, left, bottom, right] as in QuickDraw II; bottom and right are exclusive.
- Coordinates are 640-mode pixels. "Screen" coordinates are global: content coordinates plus the window content origin (wPosition top-left), all windows having origin 0,0 at start-up.
- Data locations are given as segment number/name, segment offset, and data fork file offset.
- In the JSON, "fileOffset" is always a data fork offset.

## Contents

- 1. Data fork layout
- 2. Start-up screen
- 3. Load formats window
- 4. Save formats window
- 5. Screen image window and info bar
- 6. List drawing and icons
- 7. Computer types
- 8. Load formats
- 9. Save formats
- 10. Menus
- 11. Dialogs
- 12. Compared with GS Remap
- 13. Uncertain points

## 1. Data fork layout

The data fork is an ExpressLoad OMF file with 26 segments. Every segment except the first has a
$45-byte header (DISPNAME $30, DISPDATA $45), one LCONST record holding the whole segment image,
then SUPER/cRELOC/cINTERSEG relocation records and an END record. No segment uses DS records.

| Seg | Name | Header at | Data at | Length | Kind |
|---|---|---|---|---|---|
| 1 | ~ExpressLoad | $00000 | $00048 | $7BD | $8001 |
| 2 | (unnamed) | $00806 | $00850 | $DB1B | $0000 |
| 3 | ~GLOBALS | $0F51C | $0F566 | $29 | $4000 |
| 4 | INITIALIZE | $0F590 | $0F5DA | $119B | $0010 |
| 5 | MAINE | $107F3 | $1083D | $FD24 | $0000 |
| 6 | FRED | $2289A | $228E4 | $EE9F | $0000 |
| 7 | SPAM | $32AB8 | $32B02 | $F5E5 | $0000 |
| 8 | LONGCODE | $4210C | $42156 | $FEDB | $0000 |
| 9 | OSAYCANYOU | $52CE1 | $52D2B | $B065 | $0000 |
| 10 | SUPERFX | $5E377 | $5E3C1 | $179A | $0000 |
| 11 | png | $5FFED | $60037 | $7309 | $0000 |
| 12 | ~ARRAYS | $67E1F | $67E69 | $1CAC | $4000 |
| 13 | djpeg | $69F12 | $69F5C | $8831 | $0000 |
| 14 | djpeg2 | $72EAA | $72EF4 | $2644 | $0000 |
| 15 | djpeg4 | $75821 | $7586B | $BFBA | $0000 |
| 16 | INFLATE | $82215 | $8225F | $99B4 | $0000 |
| 17 | jmisc | $8C249 | $8C293 | $7F55 | $0000 |
| 18 | pngutil | $9474D | $94797 | $498E | $0000 |
| 19 | pngread | $994BB | $99505 | $37CA | $0000 |
| 20 | pngtrans | $9D227 | $9D271 | $C9A2 | $0000 |
| 21 | pngwrite | $AA11E | $AA168 | $1721 | $0000 |
| 22 | ~JumpTable | $AB92A | $AB974 | $60 | $0002 |
| 23 | DYNAMIFF | $AB9D5 | $ABA1F | $195A | $8000 |
| 24 | DYNAMINFO | $AD61B | $AD665 | $DBC | $8000 |
| 25 | DYNAMDESK | $AE5AC | $AE5F6 | $80BF | $8000 |
| 26 | DYNAMTIFF | $B66F0 | $B673A | $2AD6 | $8000 |

File offset of a segment address: For segments 2-26: file offset = segment header offset + $4A + segment offset (the single LCONST record starts at header + $45, data 5 bytes later). Segment 1 (~ExpressLoad): header + $48.

Resolving pointers (they are stored as segment offsets and patched at load time):

- SUPER RELOC3 / SUPER RELOC2 / cRELOC: value is an offset in the same segment (3 or 2 bytes are patched).
- SUPER INTERSEG1: 3-byte patch; low 16 bits = offset, third byte = target segment number (file 1). Example: $0008EFA1 = LONGCODE (8) offset $EFA1.
- SUPER INTERSEG13..24: 2-byte offset into segment (n - 12), used for the low word of PEA pairs.
- SUPER INTERSEG25..36: bank byte (shift -16) of segment (n - 24), used for the high word of PEA pairs.
- INTERSEG / cINTERSEG: explicit segment number in the record.

Worked examples:

| Pointer as stored | Means | File offset |
|---|---|---|
| listPointer $00002FB2 (SUPER RELOC3) | MAINE $2FB2, computer type members | $137EF |
| listDraw $0008EFA1 (SUPER INTERSEG1) | LONGCODE $EFA1, list member draw routine | $510F7 |
| wTitle $0000319C (SUPER RELOC3) | OSAYCANYOU $319C, " Load formats " | $55EC7 |
| wTitle $000031F9 (SUPER RELOC3) | OSAYCANYOU $31F9, " Save formats " | $55F24 |
| wRefCon $000525DC (SUPER INTERSEG1) | MAINE $25DC, window handler for both format windows | $12E19 |
| wContDefProc $000699B5 (SUPER INTERSEG1) | FRED $99B5, Load formats content drawing | $2C299 |

## 2. Start-up screen

- 640 mode, master SCB $80. Desktop colour table 0 is the standard 640-mode table:
  $000 $F00 $0F0 $FFF $000 $00F $FF0 $FFF $000 $F00 $0F0 $FFF $000 $00F $FF0 $FFF.
  In the screen dump notation (pixel value 0 "#", 1 "a", 2 "b", 3 "."), the desktop is the
  standard ".a.a" pattern and selected list rows are filled with value 2 ($AAAA).
- Menu bar: Apple, File, Edit, Screen, True color, Monochrome, Windows, Extras. Screen, True
  color and Monochrome start disabled (menu flag $0080) and are enabled once there is an image.
- Two windows are open: Load formats (left) and Save formats (right). The Screen image window
  exists but is hidden until a picture is loaded. Load formats is the active (front) window at
  start-up: it is created last and its title bar is drawn black.

| Window | Content rect (screen) | Frame bits | Title | NewWindow block |
|---|---|---|---|---|
| Load formats | 30,8,195,314 | $80E8 fTitle, fMove, fQContent, fVis, fCtlTie | " Load formats " | OSAYCANYOU $314E (file $55E79) |
| Save formats | 30,328,94,634 | $80E8 fTitle, fMove, fQContent, fVis, fCtlTie | " Save formats " | OSAYCANYOU $31AB (file $55ED6) |
| Screen image | 122,328,183,608 | $DDD0 fTitle, fClose, fRScroll, fBScroll, fGrow, fZoom, fMove, fQContent, fInfo | (set at run time) | OSAYCANYOU $30E0 (file $55E0B) |

Screen map of the start-up state (rectangles top,left,bottom,right, bottom/right exclusive):

| Element | Screen rect | Notes |
|---|---|---|
| Menu bar | 0,0,13,640 | black lines on rows 0 and 12 |
| Load formats window, frame and title bar | 17,6,196,316 | title bar rows 17-29 (black, title in white); frame columns 6-7 and 314-315 |
| Load formats content | 30,8,195,314 |  |
| Computer type list | 29,5,101,292 | scroll bar 29,290,101,316 |
| "  Computer type  " label box | 101,18,110,134 | measured |
| Button "Load..." (and "Load next") | 103,168,114,303 |  |
| Button "Info on format" (load) | 111,18,122,153 |  |
| "  Specific type  " label box | 115,192,125,303 | measured; last row shared with the list frame |
| Specific type list | 124,5,196,292 | scroll bar 124,290,196,316 |
| Save formats window, frame and title bar | 17,326,95,636 | title bar rows 17-29 (white: inactive) |
| Save formats content | 30,328,94,634 |  |
| Button "Info on format" (save) | 31,338,42,473 |  |
| Button "Save..." (hidden at start) | 31,488,42,624 |  |
| Save format list | 43,326,95,612 | scroll bar 43,610,95,636 |
| Screen image content (hidden at start) | 122,328,183,608 | info bar 12 rows directly above |

All three use the plain NewWindow call (not NewWindow2), wColor 0 (default colours), wPlane
$FFFFFFFF (in front), origin 0,0 and zoom rectangle 0,0,0,0. The window frames seen in the screen
dump: Load formats title bar rows 17-29 and frame columns 6-7 / 314-315, bottom frame row 195;
Save formats title bar rows 17-29, frame columns 326-327 / 634-635, bottom frame row 94.

## 3. Load formats window

### 3.1 Window parameters

| Field | Value |
|---|---|
| paramLength | 78 |
| wFrameBits | $80E8 (fTitle, fMove, fQContent, fVis, fCtlTie) |
| wTitle | OSAYCANYOU $319C (file $55EC7) " Load formats " |
| wRefCon | MAINE $25DC (file $12E19) |
| wZoom | 0,0,0,0 |
| wColor | 0 |
| wYOrigin | 0 |
| wXOrigin | 0 |
| wDataH | 0 |
| wDataW | 0 |
| wMaxH | 0 |
| wMaxW | 0 |
| wScrollVer | 0 |
| wScrollHor | 0 |
| wPageVer | 0 |
| wPageHor | 0 |
| wInfoRefCon | 0 |
| wInfoHeight | 0 |
| wFrameDefProc | 0 |
| wInfoDefProc | 0 |
| wContDefProc | FRED $99B5 (file $2C299) |
| wPosition | 30,8,195,314 |
| wPlane | $FFFFFFFF |
| wStorage | 0 |

Created at MAINE $1EEA: NewWindow(OSAYCANYOU $314E); CreateList(window, MAINE $2093); CreateList(window, MAINE $20BB); then three NewControl calls; then JSR $2695 (fills the specific type list for the selected computer type).

### 3.2 Controls

Window content origin = screen (8, 30) (left, top).

| Element | Content rect | Screen rect | Notes |
|---|---|---|---|
| Computer type list | -1,-3,71,284 | 29,5,101,292 | List control (CreateList). Scroll bar outside the rect on the right, screen 29,290,101,316. |
| Specific type list | 94,-3,166,284 | 124,5,196,292 | List control (CreateList). Scroll bar outside the rect on the right, screen 124,290,196,316. |
| Button "Info on format" | 81,10,92,145 | 111,18,122,153 | flag $0000. Opens the help window at the topic named by the selected format record (+28). |
| Button "Load..." | 73,160,84,295 | 103,168,114,303 | flag $0000. Posts an Apple-L key-down event (same as File > Load & convert...). |
| Button "Load next" | 73,160,84,295 | 103,168,114,303 | flag $0080, invisible at start. Same rectangle as "Load...". LONGCODE $DDFD hides "Load..." and shows this button when several files were chosen (and enables menu items $117 and $10C); LONGCODE $DE60 reverses it. Posts an Apple-N key-down event (File > Load next). |

"Load next" colour table (MAINE $2065 (file $128A2)): outline $0000, norBack $00E0, selBack $0000, norText $00E1, selText $000F
(simple button colour table; in a text colour word bits 7-4 are the background and bits 3-0 the
text colour). These are the bytes `E0 00 00 00 E1 00 0F 00` that sit just before the label strings;
they belong to the "Load next" button, not to the labels. The other buttons use the default colours.

All buttons are simple buttons made with the old NewControl call (defProc 0, value 0, refCon 0).
Button title strings and rectangles are in MAINE: Info on format rect $2028 / title $2030, Load...
rect $2043 / title $204B, Load next rect $2043 / title $2057. Control handles are stored at MAINE
$203F, $2053, $2061; the window pointer at MAINE $2024.

### 3.3 List records

| Field | computerType | specificType |
|---|---|---|
| listRec | MAINE $2093 (file $128D0) | MAINE $20BB (file $128F8) |
| listRect | -1,-3,71,284 | 94,-3,166,284 |
| listRectScreen | 29,5,101,292 | 124,5,196,292 |
| listSize | 10 | 0 |
| listView | 7 | 7 |
| listType | 2 | 2 |
| listStart | 1 | 1 |
| listCtl | 0 | 0 |
| listDraw | LONGCODE $EFA1 (file $510F7) | LONGCODE $EFA1 (file $510F7) |
| listMemHeight | 10 | 10 |
| listMemSize | 12 | 32 |
| listPointer | MAINE $2FB2 (file $137EF) | 0 |
| listRefCon | 0 | 0 |
| listScrollClr | 0 | 0 |

listType 2 = Pascal strings, one selection at a time. The specific list gets its listSize and
listPointer at run time from the selected computer type (MAINE $2695: NextMember on the computer
list, then NewList with the member's count (+6) and array pointer (+8)). Member rectangles: member i: top = listRect.top + 1 + 10*i, bottom = top + 10, left = listRect.left + 2, right = listRect.right - 2.
With the frame lines this gives rows 10 pixels high starting one pixel below the top frame; for
the computer list, member 0 is screen rows 30-39 and member 1 (selected at start) rows 40-49.

### 3.4 Labels "Computer type" and "Specific type"

| String | Data | MoveTo (content h,v) | Screen h,v | Black box in dump (inclusive) |
|---|---|---|---|---|
| "  Computer type  " | MAINE $206F (file $128AC) | 10,78 | 18,108 | x 18-133, y 101-109 |
| "  Specific type  " | MAINE $2081 (file $128BE) | 184,93 | 192,123 | x 192-302, y 115-123 |

Drawing sequence (FRED $99B5, after DrawControls):

- SetBackColor($0000) - black
- SetForeColor($FFFF) - white
- SetSolidPenPat($0000) - black
- MoveTo(h, v)
- StringBounds(string) at the pen position; rect.top -= 1; rect.bottom += 1; PaintRect(rect)
- DrawString(string) - white text on black

So the label colours are: box and text background black ($0000), text white ($FFFF), drawn with
the system font. The box is the string's StringBounds rectangle grown by one row at the top and
one at the bottom; the two leading and two trailing spaces widen it. "Specific type" sits
directly on top of the specific list frame (its last box row coincides with the list's top line,
screen row 124).

### 3.5 Behaviour

- MAINE $25DC: called with the TaskMaster result; for wInControl ($21) it compares the control handle with the five buttons above and acts.
- Info on format opens the help window ("SuperConvert Help", help file "1:SuperConv.Help") at the
  topic named by the selected format's help tag (record +28, e.g. "LFC0").
- Load... posts an Apple-L key-down event; Load next posts Apple-N.
- Selecting a computer type refills the specific list (MAINE $2695).

## 4. Save formats window

### 4.1 Window parameters

| Field | Value |
|---|---|
| paramLength | 78 |
| wFrameBits | $80E8 (fTitle, fMove, fQContent, fVis, fCtlTie) |
| wTitle | OSAYCANYOU $31F9 (file $55F24) " Save formats " |
| wRefCon | MAINE $25DC (file $12E19) |
| wZoom | 0,0,0,0 |
| wColor | 0 |
| wYOrigin | 0 |
| wXOrigin | 0 |
| wDataH | 0 |
| wDataW | 0 |
| wMaxH | 0 |
| wMaxW | 0 |
| wScrollVer | 0 |
| wScrollHor | 0 |
| wPageVer | 0 |
| wPageHor | 0 |
| wInfoRefCon | 0 |
| wInfoHeight | 0 |
| wFrameDefProc | 0 |
| wInfoDefProc | 0 |
| wContDefProc | FRED $9A65 (file $2C349) |
| wPosition | 30,328,94,634 |
| wPlane | $FFFFFFFF |
| wStorage | 0 |

Created at MAINE $1E34: NewWindow(OSAYCANYOU $31AB); CreateList(window, MAINE $2116); two NewControl calls. The Save formats window is created before the Load formats window.

### 4.2 Controls

Window content origin = screen (328, 30).

| Element | Content rect | Screen rect | Notes |
|---|---|---|---|
| Save format list | 13,-2,65,284 | 43,326,95,612 | List control (CreateList). Scroll bar outside the rect on the right, screen 43,610,95,636. |
| Button "Info on format" | 1,10,12,145 | 31,338,42,473 | flag $0000. Help topic from the selected save record (+28). |
| Button "Save..." | 1,160,12,296 | 31,488,42,624 | flag $0080, invisible at start. MAINE $428F shows it once there is an image (and enables menus 5, 9, 6); MAINE $4232 hides it again. Posts an Apple-S key-down event (File > Save conversion...). |

Rectangles and titles: Info on format rect MAINE $20E7 / title $20EF, Save... rect $2102 / title
$210A; handles at MAINE $20FE and $2112; window pointer at MAINE $20E3. FRED $9A65: DrawControls(GetPort()) only.

### 4.3 List record

| Field | saveFormat |
|---|---|
| listRec | MAINE $2116 (file $12953) |
| listRect | 13,-2,65,284 |
| listRectScreen | 43,326,95,612 |
| listSize | 14 |
| listView | 5 |
| listType | 2 |
| listStart | 1 |
| listCtl | 0 |
| listDraw | LONGCODE $EFA1 (file $510F7) |
| listMemHeight | 10 |
| listMemSize | 38 |
| listPointer | MAINE $8E5C (file $19699) |
| listRefCon | 0 |
| listScrollClr | 0 |

Five rows are visible; member 2 ("$C0,2 Apple Preferred") is selected at start (screen rows 64-73).

## 5. Screen image window and info bar

### 5.1 Window parameters

| Field | Value |
|---|---|
| paramLength | 78 |
| wFrameBits | $DDD0 (fTitle, fClose, fRScroll, fBScroll, fGrow, fZoom, fMove, fQContent, fInfo) |
| wTitle | 0 |
| wRefCon | FRED $A171 (file $2CA55) |
| wZoom | 0,0,0,0 |
| wColor | 0 |
| wYOrigin | 0 |
| wXOrigin | 0 |
| wDataH | 400 |
| wDataW | 1280 |
| wMaxH | 400 |
| wMaxW | 1280 |
| wScrollVer | 4 |
| wScrollHor | 8 |
| wPageVer | 0 |
| wPageHor | 0 |
| wInfoRefCon | 4-byte INTERSEG to segment 5; value $8000F796 = offset $F796 with bit 31 set |
| wInfoHeight | 12 |
| wFrameDefProc | 0 |
| wInfoDefProc | MAINE $F083 (file $1F8C0) |
| wContDefProc | MAINE $EA30 (file $1F26D) |
| wPosition | 122,328,183,608 |
| wPlane | $FFFFFFFF |
| wStorage | 0 |

MAINE $1C13: NewWindow(OSAYCANYOU $30E0), stored at MAINE $2000; SetOriginMask($FFF8, window); SetPort(window). The window starts hidden (fVis clear).

- FRED $A171: key handler for the image window (keys 1-9 and Space move the view to one of nine positions, keypad layout, Space = 5; Tab and Apple-W are also handled).
- MAINE $EA30 fills the area right of and below the picture with the pattern at OSAYCANYOU $312E (32 bytes: 0F0F3C3C F0F0C3C3 0F0F3C3C F0F0C3C3 then 16 zero bytes), then draws the picture.
- The window is not open at start-up. With content rect 122,328,183,608 the info bar (12 pixels) and title bar
  sit above row 122, below the Save formats window.

### 5.2 Title

wTitle is 0 in the block. MAINE $4991-$4A89 builds the title at MAINE $4AB2 and calls SetWTitle. Format: " " + file name + " (" + mode + "," + palettes + ") ", where mode is "320" (all lines 320 mode), "640" (all lines 640 mode), "Mix" (both), "??" when there is no screen image and palettes is the number of distinct palettes used, right-aligned in 2 characters (" 1" .. "16"). Example: `" PICTURE (320, 1) "`.

### 5.3 Info bar

Height 12. Draw procedure MAINE $F083 (wInfoDefProc); click procedure MAINE $F796 (from wInfoRefCon). x and y are offsets from the info bar rectangle passed to the draw procedure (left, top). Icons are drawn with DrawIcon (QuickDraw Auxiliary $0B12), display mode 0. Colours: SetForeColor(0) black, SetBackColor($FFFF) white, SetTextMode(0) copy.

| x | y | Item | Source / icon data |
|---|---|---|---|
| left+2 | top+0 | image type icon | table MAINE $E1B0 indexed by MAINE $0528 (1 screen, 2 true color, 3 monochrome); OSAYCANYOU 1 = $4453, 2 = $44AB, 3 = $456F |
| left+20 | top+0 | pop-up arrow with divider | OSAYCANYOU $4839 |
| left+42 | top+1 | magnifier (zoom) icon | MAINE $E16E: 0 = actual size, negative = shrunk, positive = zoomed; OSAYCANYOU 0 = $4A1D, negative = $4A65, positive = $4AAD |
| left+60 | top+0 | pop-up arrow with divider | same as x=20 (OSAYCANYOU $4839) |
| left+82 | top+1 | tool icon | table MAINE $E1C0 indexed by MAINE $053C (1 selection, 2 pixel peek); OSAYCANYOU 1 = $498D, 2 = $49D5 |
| left+100 | top+0 | pop-up arrow with divider | same as x=20 |
| left+122 | top+0 | pop-up arrow on white (actions menu) | OSAYCANYOU $48A5 |
| left+142 | top+8 | text, DrawCString at (left+142, top+8) |  |

Text:

- Built in MAINE $4017 (C string). Variants, longest first:
  - level 0/1: "Screen image: W x H" / "True color image: W x H" / "Monochrome image: W x H"
  - level 2: "Image: W x H"
  - level 3: "W x H"
  - level 4: empty
- The longest variant whose width satisfies CStringWidth + left + 142 < right is used (MAINE $F47F). With the window at its initial width the first variant does not fit, which is why the original shows "Image: 320 x 200".
- When a selection exists (MAINE $E17E != 0) the text is "Selection: W x H   (left, top, right, bottom)" with shorter variants.
- In pixel peek mode the text reads "Click in image to view pixel values" (or "Click in image"), then the value of the clicked pixel.

Clicks (x measured from the info bar left edge):

| x | Pop-up menu | Menu position |
|---|---|---|
| < 40 | image type (pop-up menu 1) | left |
| 40-79 | zoom (pop-up menu 3) | left+40 |
| 80-119 | tool (pop-up menu 2) | left+80 |
| >= 120 | pop-up menu 4 in selection mode, 5 in pixel peek mode (table MAINE $E1CC) | left+120; the 18-pixel strip at left+120 is inverted while the menu is shown |

The pop-up menus are listed in section 10.4. Info bar icons (640-mode pixels; "#" 0 black, "a" 1,
"b" 2, "." 3 white, blank = transparent):

```
image type icon, 1 = OSAYCANYOU $4453 (file $5717E) (16x10)
|                |
| ###############|
| ##.a.........##|
| a.a.a.a.a.a.a.a|
| a.a.a.a.a.a.a.a|
| a.a.a.a.a.a.a.a|
| a.a.a.a.a.a.a.a|
| a.a.a.a.a.a.a.a|
| a.a.a.a.a.a.a.a|
|                |
```
```
image type icon, 2 = OSAYCANYOU $44AB (file $571D6) (16x10)
|                |
|    a.a.a.a     |
|    a#a#a#a     |
|    a#a#a#a     |
|    a.a.a.a     |
|b.b.b.b  a.a.a.a|
|b#b#b#b  a#a#a#a|
|b#b#b#b  a#a#a#a|
|b.b.b.b  a.a.a.a|
|                |
```
```
image type icon, 3 = OSAYCANYOU $456F (file $5729A) (16x10)
|                |
|....####....####|
|....####....####|
|####....####....|
|####....####....|
|....####....####|
|....####....####|
|####....####....|
|####....####....|
|                |
```
```
pop-up arrow with divider = OSAYCANYOU $4839 (file $57564) (20x10)
|                ##  |
|                ###.|
|                ###.|
|##############  ###.|
|  ##########    ###.|
|    ######      ###.|
|      ##        ###.|
|                ###.|
|                ###.|
|                ###.|
```
```
magnifier (zoom) icon, 0 = OSAYCANYOU $4A1D (file $57748) (16x8)
|..######........|
|##.b...b##......|
|#b...b...#......|
|##.b...b##......|
|..######.###....|
|........######..|
|..........######|
|............###.|
```
```
magnifier (zoom) icon, negative = OSAYCANYOU $4A65 (file $57790) (16x8)
|................|
|....####........|
|..##.b..##......|
|..##...b##......|
|....#######.....|
|.........####...|
|...........#....|
|................|
```
```
magnifier (zoom) icon, positive = OSAYCANYOU $4AAD (file $577D8) (20x9)
|...########.........|
|.###...b..###.......|
|##...b...b..##......|
|##.b...b...b##......|
|##...b...b..##......|
|.###...b..###.#.....|
|...########.#####...|
|...........########.|
|.............#######|
```
```
tool icon, 1 = OSAYCANYOU $498D (file $576B8) (16x8)
|####..####..####|
|##............##|
|................|
|##............##|
|##............##|
|................|
|##............##|
|####..####..####|
```
```
tool icon, 2 = OSAYCANYOU $49D5 (file $57700) (16x8)
|......####......|
|......####......|
|......########..|
|....######..###.|
|............###.|
|..b#b#b#b#b#b##.|
|...........####.|
|#a#a#a#a#a#a#a#a|
```
```
pop-up arrow on white (actions menu) = OSAYCANYOU $48A5 (file $575D0) (16x10)
|................|
|................|
|................|
|##############..|
|..##########....|
|....######......|
|......##........|
|................|
|................|
|................|
```

## 6. List drawing and icons

### 6.1 Member drawing

All three lists use the same listDraw routine, LONGCODE $EFA1 (listDraw for all three lists):

1. icon = member byte +5 AND $0F
1. if member memFlag bit 7 is clear: SetSolidPenPat($FFFF) and SetBackColor($FFFF) (white)
1. else: SetSolidPenPat($AAAA) and SetBackColor($AAAA) (colour 2); if icon = 0 then icon = 8 (open folder)
1. SetPenMode(0); SetTextMode(0); SetForeColor(0) (black text)
1. PaintRect(member rect)
1. DrawIcon(icon table OSAYCANYOU $478B [icon], mode 0, x = (rect.left + 4) AND $FFFE, y = rect.top)
1. MoveTo(rect.left + width table OSAYCANYOU $47AF [icon] + 10, rect.top + 8)
1. DrawString(member name)

Icon x = (member left + 4) rounded down to even; text x = member left + icon width + 10;
baseline = member top + 8. Example from the dump: computer list members start at screen x 7
(hidden under the window frame), so folder icons are at x 10-25 and names start at x 33.

### 6.2 List icons

Icon index = member byte +5 AND $0F. For formats this byte is a bit mask: $01 screen (palette)
image, $02 true color image, $04 monochrome image; the icon shows which kinds of image the format
produces (load list) or can store (save list). This is the true colour marker of this version.
Icon pointer table OSAYCANYOU $478B (file $574B6), width table OSAYCANYOU $47AF (file $574DA). Icon headers: iconType $0000, iconSize, iconHeight,
iconWidth (the stored width counts 2-pixel units; the drawn width in 640-mode pixels is bytes per
row x 4). Image then mask.

| Index | Meaning | Data | Size (640 px) | Width used for text |
|---|---|---|---|---|
| 0 | closed folder (computer type) | OSAYCANYOU $43FB (file $57126) | 16x10 | 16 |
| 1 | screen image (palette) | OSAYCANYOU $4453 (file $5717E) | 16x10 | 16 |
| 2 | true color image | OSAYCANYOU $44AB (file $571D6) | 16x10 | 16 |
| 3 | screen + true color | OSAYCANYOU $4503 (file $5722E) | 20x10 | 20 |
| 4 | monochrome (checkerboard) | OSAYCANYOU $456F (file $5729A) | 16x10 | 16 |
| 5 | screen + monochrome | OSAYCANYOU $45C7 (file $572F2) | 20x10 | 20 |
| 6 | true color + monochrome | OSAYCANYOU $4633 (file $5735E) | 20x10 | 20 |
| 7 | screen + true color + monochrome | OSAYCANYOU $469F (file $573CA) | 24x10 | 24 |
| 8 | open folder (selected computer type) | OSAYCANYOU $471F (file $5744A) | 20x10 | 16 |

```
icon 0: closed folder (computer type)
|                |
|   ######       |
| ###....####### |
|##............##|
|##............##|
|##............##|
|##............##|
|################|
|                |
|                |
```
```
icon 1: screen image (palette)
|                |
| ###############|
| ##.a.........##|
| a.a.a.a.a.a.a.a|
| a.a.a.a.a.a.a.a|
| a.a.a.a.a.a.a.a|
| a.a.a.a.a.a.a.a|
| a.a.a.a.a.a.a.a|
| a.a.a.a.a.a.a.a|
|                |
```
```
icon 2: true color image
|                |
|    a.a.a.a     |
|    a#a#a#a     |
|    a#a#a#a     |
|    a.a.a.a     |
|b.b.b.b  a.a.a.a|
|b#b#b#b  a#a#a#a|
|b#b#b#b  a#a#a#a|
|b.b.b.b  a.a.a.a|
|                |
```
```
icon 3: screen + true color
|             ###    |
|    a.a.a.a ########|
|    a#a#a#a###....##|
|    a#a#a####a.a.a.a|
|    a.a.a###.a.a.a.a|
|b.b.b.b.###a.a.a.a.a|
|b#b#b#b###.a.a.a.a.a|
|b#b#b####a.a.a.a.a.a|
|b.b.b###.a.a.a.a.a.a|
|    ###             |
```
```
icon 4: monochrome (checkerboard)
|                |
|....####....####|
|....####....####|
|####....####....|
|####....####....|
|....####....####|
|....####....####|
|####....####....|
|####....####....|
|                |
```
```
icon 5: screen + monochrome
|             ###    |
| ##############.####|
| ##.a......###..####|
| a.a.a.a.a######....|
| a.a.a.a.##.####....|
| a.a.a.a####....####|
| a.a.a.#####....####|
| a.a.a###...####....|
| a.a.###....####....|
|    ###             |
```
```
icon 6: true color + monochrome
|             ###    |
|    a.a.a.a ###.####|
|    a#a#a#a###..####|
|    a#a#a#######....|
|    a.a.a##.####....|
|b.b.b.b.####....####|
|b#b#b#b#####....####|
|b#b#b####...####....|
|b.b.b###....####....|
|    ###             |
```
```
icon 7: screen + true color + monochrome
|            ##     ##   |
|    a.a.a.a#############|
|    a#a#a###.....##.####|
|    a#a#a##a.a.a####....|
|    a.a.##.a.a.#####....|
|b.b.b.b##a.a.a##....####|
|b#b#b###.a.a.###....####|
|b#b#b##a.a.a##..####....|
|b.b.##.a.a.##...####....|
|   ##     ##            |
```
```
icon 8: open folder (selected computer type)
|                    |
|   ######           |
| ###....#######     |
|##............##    |
|##.....############ |
|##..###..........###|
|#.###..........###  |
|################    |
|                    |
|                    |
```

## 7. Computer types

List record MAINE $2093, members at MAINE $2FB2 (file $137EF), 10 members of 12 bytes:

| Offset | Size | Meaning |
|---|---|---|
| +0 | 4 | pointer to name (Pascal string) |
| +4 | 1 | memFlag: $80 = selected |
| +5 | 1 | icon index: 0 (closed folder; drawn as 8, open folder, when selected) |
| +6 | 2 | number of specific formats |
| +8 | 4 | pointer to the array of 32-byte format records |

| # | Name | memFlag | Icon | Formats | Format array | Record |
|---|---|---|---|---|---|---|
| 0 | Apple II family | $00 | 0 | 10 | MAINE $30C6 (file $13903) | MAINE $2FB2 (file $137EF) |
| 1 | Apple IIgs specific | $80 (selected at start) | 0 | 12 | MAINE $3332 (file $13B6F) | MAINE $2FBE (file $137FB) |
| 2 | Atari ST | $00 | 0 | 6 | MAINE $366F (file $13EAC) | MAINE $2FCA (file $13807) |
| 3 | Amiga | $00 | 0 | 1 | MAINE $37EB (file $14028) | MAINE $2FD6 (file $13813) |
| 4 | Commodore 64/128 | $00 | 0 | 3 | MAINE $3826 (file $14063) | MAINE $2FE2 (file $1381F) |
| 5 | Macintosh | $00 | 0 | 4 | MAINE $38D5 (file $14112) | MAINE $2FEE (file $1382B) |
| 6 | IBM PC & compatibles | $00 | 0 | 5 | MAINE $39E5 (file $14222) | MAINE $2FFA (file $13837) |
| 7 | Unix machines | $00 | 0 | 3 | MAINE $3B49 (file $14386) | MAINE $3006 (file $13843) |
| 8 | Computer-independent | $00 | 0 | 7 | MAINE $3C22 (file $1445F) | MAINE $3012 (file $1384F) |
| 9 | External (Babelfish™) | $00 | 0 | 2 | MAINE $3EB2 (file $146EF) | MAINE $301E (file $1385B) |

Raw member records (name | flag | icon | count | array; pointers as stored, before relocation):

```
$2FB2 Apple II family    2A300000 00 00 0A00 C6300000
$2FBE Apple IIgs specifi 3A300000 80 00 0C00 32330000
$2FCA Atari ST           4E300000 00 00 0600 6F360000
$2FD6 Amiga              57300000 00 00 0100 EB370000
$2FE2 Commodore 64/128   5D300000 00 00 0300 26380000
$2FEE Macintosh          6E300000 00 00 0400 D5380000
$2FFA IBM PC & compatibl 78300000 00 00 0500 E5390000
$3006 Unix machines      8D300000 00 00 0300 493B0000
$3012 Computer-independe 9B300000 00 00 0700 223C0000
$301E External (Babelfis B0300000 00 00 0200 B23E0000
```

## 8. Load formats

### 8.1 Format record (32 bytes)

| Offset | Size | Meaning |
|---|---|---|
| +0 | 4 | pointer to name (Pascal string) |
| +4 | 1 | memFlag: $80 = selected (only "SuperHiRes ($C0/PNT, $C1/PIC)" at start) |
| +5 | 1 | kind / icon: $01 screen image, $02 true color image, $04 monochrome image (combinations 3, 5, 6, 7 have their own icons) |
| +6 | 1 | file type A |
| +7 | 1 | file type B. A file matches if its type is A or B. $FF $FF = use the file type list at +20. $FE $FF = Babelfish true color import, $FD $FF = Babelfish pixel map import (no file dialog filter). If the pair is $04/$06, typeless ($00) files are accepted too. Folders always show. |
| +8 | 4 | Macintosh file type (four characters, e.g. "PNTG"), 0 if none |
| +12 | 4 | minimum EOF (inclusive) |
| +16 | 4 | maximum EOF (inclusive) |
| +20 | 2 | minimum aux type (inclusive); when +6 = $FFFF, +20 is a 4-byte pointer to the file type list |
| +22 | 2 | maximum aux type (inclusive) |
| +24 | 4 | loader routine. 2-byte relocation = 16-bit MAINE address called with JSR; 3-byte relocation = long address called with JSL. 0 = not implemented ("This format has not been implemented yet") |
| +28 | 4 | pointer to help topic tag (Pascal string, "LF...") used by Info on format |

The filter that applies these fields to the file list is the Standard File filter procedure at
MAINE $4610 (used by SFPMultiGet2 in File > Load & convert). Files that match are selectable;
others are shown dimmed or hidden depending on a setting.

### 8.2 Formats by computer type

#### 0. Apple II family (10 formats, array MAINE $30C6 (file $13903))

| # | Name | Kind/icon | File types | Aux types | EOF | Mac type | Loader | Help tag |
|---|---|---|---|---|---|---|---|---|
| 0 | HiRes black & white | 1 screen | $06 or $08 | $0000-$FFFF | $1FF8-$2100 |  | JSR MAINE $74DB | LFHGR |
| 1 | HiRes color | 1 screen | $06 or $08 | $0000-$FFFF | $1FF8-$2100 |  | JSR MAINE $74E0 | LFHGR |
| 2 | DoubleHiRes black & white | 1 screen | $06 or $08 | $0000-$FFFF | $3FF8-$4100 |  | JSR MAINE $75EB | LFDHR |
| 3 | DoubleHiRes color | 1 screen | $06 or $08 | $0000-$FFFF | $3FF8-$4100 |  | JSR MAINE $75F0 | LFDHR |
| 4 | Print Shop B & W graphic | 1 screen | $06 | $0000-$FFFF | $23C-$300 |  | JSR MAINE $8767 | LFPSGRB1 |
| 5 | New Print Shop graphics | 1 screen | $F5 | $3000-$5FFF | $1-$FFFFFF |  | none (not implemented) | LFNPS |
| 6 | ThunderScan raw scan file | 2 true color | $06 | $5453-$5453 | $1-$FFFFFF |  | JSR MAINE $6154 | LFTSCAN |
| 7 | Works of Art (Springboard Publ.) | 4 monochrome | $F7 | $0000-$0000 | $1-$FFFFFF |  | JSL FRED $AEBA | LFWOA |
| 8 | TDM 40-column text screen capture | 1 screen | $06 | $0000-$FFFF | $378-$400 |  | JSR MAINE $771B | LFTEXT |
| 9 | TDM 80-column text screen capture | 1 screen | $06 | $0000-$FFFF | $778-$800 |  | JSR MAINE $7734 | LFTEXT |

Raw records (name | flag | kind | typeA typeB | mac | eofMin | eofMax | auxMin | auxMax | loader | tag):

```
$30C6 06320000 00 01 06 08 00000000 F81F0000 00210000 0000 FFFF DB740000 26320000
$30E6 1A320000 00 01 06 08 00000000 F81F0000 00210000 0000 FFFF E0740000 26320000
$3106 2C320000 00 01 06 08 00000000 F83F0000 00410000 0000 FFFF EB750000 58320000
$3126 46320000 00 01 06 08 00000000 F83F0000 00410000 0000 FFFF F0750000 58320000
$3146 5E320000 00 01 06 06 00000000 3C020000 00030000 0000 FFFF 67870000 77320000
$3166 80320000 00 01 F5 F5 00000000 01000000 FFFFFF00 0030 FF5F 00000000 98320000
$3186 9E320000 00 02 06 06 00000000 01000000 FFFFFF00 5354 5354 54610000 B8320000
$31A6 C0320000 00 04 F7 F7 00000000 01000000 FFFFFF00 0000 0000 BAAE0600 E1320000
$31C6 E7320000 00 01 06 06 00000000 78030000 00040000 0000 FFFF 1B770000 2B330000
$31E6 09330000 00 01 06 06 00000000 78070000 00080000 0000 FFFF 34770000 2B330000
```

#### 1. Apple IIgs specific (12 formats, array MAINE $3332 (file $13B6F))

| # | Name | Kind/icon | File types | Aux types | EOF | Mac type | Loader | Help tag |
|---|---|---|---|---|---|---|---|---|
| 0 | SuperHiRes ($C0/PNT, $C1/PIC) (selected) | 1 screen | list (8.3) |  |  |  | JSR MAINE $6315 | LFC0 |
| 1 | Uncompressed SHR screen ($C1, BIN) | 1 screen | $06 or $C1 | $0000-$FFFF | $7E20-$8200 |  | JSR MAINE $62D0 | LFC1 |
| 2 | DreamGrafix SHR screen | 1 screen | $C0 | $8005-$8005 | $1-$9FFF |  | JSR MAINE $6EF6 | LFDRM |
| 3 | DreamGrafix "3200 color" screen | 2 true color | $C0 | $8005-$8005 | $1-$AFFF |  | JSR MAINE $6DB9 | LFDRM3200 |
| 4 | Paintworks Gold 640 mode files | 1 screen | $C0 or $C1 | $0000-$FFFF | $1-$FFFFFF |  | JSR MAINE $6C04 | LFSCREWED |
| 5 | Print Shop IIgs color graphic | 1 screen | $F8 | $C323-$C323 | $6B4-$700 |  | JSR MAINE $87B4 | LFPSGRC1 |
| 6 | PS IIgs built-in (GRAPHIC.CGT0-7) | 1 screen | $06 | $0000-$FFFF | $35A0-$3640 |  | JSR MAINE $8AC8 | LFPSGRC8 |
| 7 | Finder icon file | 1 screen | $CA | $0000-$FFFF | $10-$FFFFF |  | JSR MAINE $7394 | LFICON |
| 8 | AST picture data file (color only) | 2 true color | $06 or $C1 | $4180-$8001 | $17700-$17FFF |  | JSR MAINE $5974 | LFAST |
| 9 | ComputerEyes GS raw data file | 2 true color | $06 | $0000-$FFFF | $2EE00-$30100 |  | JSL MAINE $6206 | LFCEYES |
| 10 | "3200 color" uncompressed picture | 2 true color | $06 or $C1 | $0000-$FFFF | $9600-$9700 |  | JSR MAINE $5D97 | LF3200 |
| 11 | "3200 color" compressed picture | 2 true color | $C0 | $3200-$3200 | $100-$99999 |  | JSR MAINE $5DD0 | LF3200 |

Raw records (name | flag | kind | typeA typeB | mac | eofMin | eofMax | auxMin | auxMax | loader | tag):

```
$3332 B2340000 80 01 FF FF 00000000 00000000 00000000 023D 0000 15630000 D0340000
$3352 D5340000 00 01 C1 06 00000000 207E0000 00820000 0000 FFFF D0620000 F8340000
$3372 FD340000 00 01 C0 C0 00000000 01000000 FF9F0000 0580 0580 F66E0000 14350000
$3392 1A350000 00 02 C0 C0 00000000 01000000 FFAF0000 0580 0580 B96D0000 3A350000
$33B2 44350000 00 01 C0 C1 00000000 01000000 FFFFFF00 0000 FFFF 046C0000 63350000
$33D2 6D350000 00 01 F8 F8 00000000 B4060000 00070000 23C3 23C3 B4870000 8B350000
$33F2 94350000 00 01 06 06 00000000 A0350000 40360000 0000 FFFF C88A0000 B6350000
$3412 BF350000 00 01 CA CA 00000000 10000000 FFFF0F00 0000 FFFF 94730000 D0350000
$3432 D7350000 00 02 06 C1 00000000 00770100 FF7F0100 8041 0180 74590000 FA350000
$3452 00360000 00 02 06 06 00000000 00EE0200 00010300 0000 FFFF 06620000 1E360000
$3472 26360000 00 02 06 C1 00000000 00960000 00970000 0000 FFFF 975D0000 68360000
$3492 48360000 00 02 C0 C0 00000000 00010000 99990900 0032 0032 D05D0000 68360000
```

#### 2. Atari ST (6 formats, array MAINE $366F (file $13EAC))

| # | Name | Kind/icon | File types | Aux types | EOF | Mac type | Loader | Help tag |
|---|---|---|---|---|---|---|---|---|
| 0 | Degas (.PI1, .PI2, .PI3) | 5 screen+monochrome | $04 or $06 | $0000-$FFFF | $7D22-$8000 |  | JSR MAINE $4E90 | LFATARI |
| 1 | Degas Elite (.PC1, .PC2, .PC3) | 5 screen+monochrome | $04 or $06 | $0000-$FFFF | $1-$8000 |  | JSR MAINE $4EC4 | LFDEGELITE |
| 2 | Neochrome (.NEO) | 5 screen+monochrome | $04 or $06 | $0000-$FFFF | $7D80-$8000 |  | JSR MAINE $4F78 | LFNEO |
| 3 | Tiny (.TNY) | 5 screen+monochrome | $04 or $06 | $0000-$FFFF | $1-$8000 |  | JSR MAINE $4FB7 | LFTINY |
| 4 | Spectrum 512 uncompressed (.SPU) | 2 true color | $04 or $06 | $0000-$FFFF | $C7A0-$C900 |  | JSR MAINE $5329 | LFSPEC |
| 5 | Spectrum 512 compressed (.SPC) | 2 true color | $04 or $06 | $0000-$FFFF | $6A0-$C400 |  | JSR MAINE $5456 | LFSPEC |

Raw records (name | flag | kind | typeA typeB | mac | eofMin | eofMax | auxMin | auxMax | loader | tag):

```
$366F 2F370000 00 05 06 04 00000000 227D0000 00800000 0000 FFFF 904E0000 48370000
$368F 50370000 00 05 06 04 00000000 01000000 00800000 0000 FFFF C44E0000 6F370000
$36AF 7A370000 00 05 06 04 00000000 807D0000 00800000 0000 FFFF 784F0000 8B370000
$36CF 91370000 00 05 06 04 00000000 01000000 00800000 0000 FFFF B74F0000 9D370000
$36EF A4370000 00 02 06 04 00000000 A0C70000 00C90000 0000 FFFF 29530000 E4370000
$370F C5370000 00 02 06 04 00000000 A0060000 00C40000 0000 FFFF 56540000 E4370000
```

#### 3. Amiga (1 format, array MAINE $37EB (file $14028))

| # | Name | Kind/icon | File types | Aux types | EOF | Mac type | Loader | Help tag |
|---|---|---|---|---|---|---|---|---|
| 0 | IFF (FORM ILBM only) | 2 true color | $04 or $06 | $0000-$FFFF | $0-$FFFFFFFF |  | JSL ~JumpTable $0020 (jump table to DYNAMIFF $085A) | LFIFF |

Raw records (name | flag | kind | typeA typeB | mac | eofMin | eofMax | auxMin | auxMax | loader | tag):

```
$37EB 0B380000 00 02 06 04 00000000 00000000 FFFFFFFF 0000 FFFF 20001600 20380000
```

#### 4. Commodore 64/128 (3 formats, array MAINE $3826 (file $14063))

| # | Name | Kind/icon | File types | Aux types | EOF | Mac type | Loader | Help tag |
|---|---|---|---|---|---|---|---|---|
| 0 | Doodle (DDxxx) | 1 screen | $04 or $06 | $0000-$FFFF | $2340-$2710 |  | JSR MAINE $8BD7 | LF64doodle |
| 1 | Koala Illustrator | 1 screen | $04 or $06 | $0000-$FFFF | $290F-$2EE0 |  | JSR MAINE $8D2A | LF64KOALA |
| 2 | Print Shop screen | 1 screen | $04 or $06 | $0000-$FFFF | $1F40-$2AF8 |  | JSR MAINE $8E14 | LF64PS |

Raw records (name | flag | kind | typeA typeB | mac | eofMin | eofMax | auxMin | auxMax | loader | tag):

```
$3826 86380000 00 01 06 04 00000000 40230000 10270000 0000 FFFF D78B0000 95380000
$3846 A0380000 00 01 06 04 00000000 0F290000 E02E0000 0000 FFFF 2A8D0000 B2380000
$3866 BC380000 00 01 06 04 00000000 401F0000 F82A0000 0000 FFFF 148E0000 CE380000
```

#### 5. Macintosh (4 formats, array MAINE $38D5 (file $14112))

| # | Name | Kind/icon | File types | Aux types | EOF | Mac type | Loader | Help tag |
|---|---|---|---|---|---|---|---|---|
| 0 | MacPaint => 640 mode grayscale | 1 screen | $04 or $06 | $0000-$FFFF | $3E8-$FFFF | PNTG | JSL FRED $B510 | LFMPNT |
| 1 | MacPaint => 320 mode black & white | 1 screen | $04 or $06 | $0000-$FFFF | $3E8-$FFFF | PNTG | JSL FRED $B4FB | LFMPNT |
| 2 | MacPaint, as monochrome image | 4 monochrome | $04 or $06 | $0000-$FFFF | $3E8-$FFFF | PNTG | JSL FRED $B72B | LFMPNT |
| 3 | ScreenMaker (old startup screen) | 4 monochrome | $04 or $06 | $0000-$FFFF | $5580-$5600 |  | JSL FRED $B48C | LFMACSM |

Raw records (name | flag | kind | typeA typeB | mac | eofMin | eofMax | auxMin | auxMax | loader | tag):

```
$38D5 55390000 00 01 06 04 504E5447 E8030000 FFFF0000 0000 FFFF 10B50600 B5390000
$38F5 74390000 00 01 06 04 504E5447 E8030000 FFFF0000 0000 FFFF FBB40600 B5390000
$3915 97390000 00 04 06 04 504E5447 E8030000 FFFF0000 0000 FFFF 2BB70600 B5390000
$3935 BC390000 00 04 06 04 00000000 80550000 00560000 0000 FFFF 8CB40600 DD390000
```

#### 6. IBM PC & compatibles (5 formats, array MAINE $39E5 (file $14222))

| # | Name | Kind/icon | File types | Aux types | EOF | Mac type | Loader | Help tag |
|---|---|---|---|---|---|---|---|---|
| 0 | Windows or OS/2 bitmap (.BMP) | 2 true color | $04 or $06 | $0000-$FFFF | $50-$FFFFFF |  | JSL FRED $239E | LFWINBMP |
| 1 | Ventura Publisher (.IMG, .GEM) | 2 true color | $04 or $06 | $0000-$FFFF | $10-$FFFFFF |  | JSL OSAYCANYOU $8850 | LFVENTURA |
| 2 | PC Paintbrush (.PCX, .PCC) ??? | 6 true color+monochrome | $04 or $06 | $0000-$FFFF | $80-$FFFFFF |  | JSR MAINE $55AC | LFZSOFT |
| 3 | DeluxePaint, not Enhanced (.LBM) | 2 true color | $04 or $06 | $0000-$FFFF | $10-$FFFFFF |  | JSL ~JumpTable $0020 (jump table to DYNAMIFF $085A) | LFIBMDP |
| 4 | AA frame file from FliAway | 2 true color | $00 | $0000-$FFFF | $300-$FD00 |  | JSR MAINE $6060 | LFAATEMP |

Raw records (name | flag | kind | typeA typeB | mac | eofMin | eofMax | auxMin | auxMax | loader | tag):

```
$39E5 853A0000 00 02 06 04 00000000 50000000 FFFFFF00 0000 FFFF 9E230600 A33A0000
$3A05 AC3A0000 00 02 06 04 00000000 10000000 FFFFFF00 0000 FFFF 50880900 CB3A0000
$3A25 D53A0000 00 06 06 04 00000000 80000000 FFFFFF00 0000 FFFF AC550000 F43A0000
$3A45 FC3A0000 00 02 06 04 00000000 10000000 FFFFFF00 0000 FFFF 20001600 413B0000
$3A65 1D3B0000 00 02 00 00 00000000 00030000 00FD0000 0000 FFFF 60600000 383B0000
```

#### 7. Unix machines (3 formats, array MAINE $3B49 (file $14386))

| # | Name | Kind/icon | File types | Aux types | EOF | Mac type | Loader | Help tag |
|---|---|---|---|---|---|---|---|---|
| 0 | Sun Rasterfile | 2 true color | $04 or $06 | $0000-$FFFF | $20-$FFFFFF |  | JSL FRED $152D | LFSUNRASTER |
| 1 | SGI Iris (.SGI, .BW, .RGB, .RGBA) | 2 true color | $04 or $06 | $0000-$FFFF | $200-$FFFFFF |  | JSL OSAYCANYOU $7BE6 | LFSGIIRIS |
| 2 | Portable Pixelmap (.PBM, .PGM, .PPM) | 2 true color | $04 or $06 | $0000-$FFFF | $10-$FFFFFF |  | JSL FRED $0ED2 | LFPORTPIXMAP |

Raw records (name | flag | kind | typeA typeB | mac | eofMin | eofMax | auxMin | auxMax | loader | tag):

```
$3B49 A93B0000 00 02 06 04 00000000 20000000 FFFFFF00 0000 FFFF 2D150600 B83B0000
$3B69 C43B0000 00 02 06 04 00000000 00020000 FFFFFF00 0000 FFFF E67B0900 E63B0000
$3B89 F03B0000 00 02 06 04 00000000 10000000 FFFFFF00 0000 FFFF D20E0600 153C0000
```

#### 8. Computer-independent (7 formats, array MAINE $3C22 (file $1445F))

| # | Name | Kind/icon | File types | Aux types | EOF | Mac type | Loader | Help tag |
|---|---|---|---|---|---|---|---|---|
| 0 | JPEG (JFIF) | 2 true color | list (8.3) |  |  |  | JSL FRED $DBA7 | LFJPEG |
| 1 | GIF (Graphics Interchange Format) | 2 true color | list (8.3) |  |  | GIFf | JSR MAINE $824C | LFGIF |
| 2 | PNG (Portable Network Graphics) | 2 true color | list (8.3) |  |  | PNGf | JSL FRED $D9E4 | LFPNG |
| 3 | RLE (Run Length Encoding) | 1 screen | $04 or $06 | $0000-$FFFF | $2-$61A8 |  | JSL FRED $ADD4 | LFRLE |
| 4 | IPI 256x256 image (.R + .G + .B) | 2 true color | $04 or $06 | $0000-$FFFF | $10000-$10200 |  | JSR MAINE $5A5A | LFIPI |
| 5 | IPI 512x512 image (.R + .G + .B) | 2 true color | $04 or $06 | $0000-$FFFF | $40000-$40200 |  | JSR MAINE $5A5F | LFIPI |
| 6 | QRT raw image file | 2 true color | $00 | $0000-$FFFF | $6-$FFFFFF |  | JSR MAINE $5C9B | LFQRT |

Raw records (name | flag | kind | typeA typeB | mac | eofMin | eofMax | auxMin | auxMax | loader | tag):

```
$3C22 D03D0000 00 02 FF FF 00000000 00000000 00000000 AA3D 0000 A7DB0600 DC3D0000
$3C42 E33D0000 00 02 FF FF 47494666 00000000 00000000 4C3D 0000 4C820000 053E0000
$3C62 0B3E0000 00 02 FF FF 504E4766 00000000 00000000 843D 0000 E4D90600 2B3E0000
$3C82 313E0000 00 01 06 04 00000000 02000000 A8610000 0000 FFFF D4AD0600 4B3E0000
$3CA2 513E0000 00 02 06 04 00000000 00000100 00020100 0000 FFFF 5A5A0000 933E0000
$3CC2 723E0000 00 02 06 04 00000000 00000400 00020400 0000 FFFF 5F5A0000 933E0000
$3CE2 993E0000 00 02 00 00 00000000 06000000 FFFFFF00 0000 FFFF 9B5C0000 AC3E0000
```

#### 9. External (Babelfish™) (2 formats, array MAINE $3EB2 (file $146EF))

| # | Name | Kind/icon | File types | Aux types | EOF | Mac type | Loader | Help tag |
|---|---|---|---|---|---|---|---|---|
| 0 | Babelfish™ True Color Import | 2 true color | Babelfish true color import (no file filter) |  |  |  | JSR MAINE $824C | LFBABELTRUE |
| 1 | Babelfish™ PixelMap Import | 1 screen | Babelfish pixel map import (no file filter) |  |  |  | JSR MAINE $824C | LFBABELPIXEL |

Raw records (name | flag | kind | typeA typeB | mac | eofMin | eofMax | auxMin | auxMax | loader | tag):

```
$3EB2 F23E0000 00 02 FE FF 00000000 00000000 00000000 0000 0000 4C820000 0F3F0000
$3ED2 1B3F0000 00 01 FD FF 00000000 00000000 00000000 0000 0000 4C820000 363F0000
```

### 8.3 File type lists

Used when the record's file type bytes are $FF $FF. Entries of 18 bytes: file type (2), aux min (4),
aux max (4), EOF min (4), EOF max (4); the list ends with $FFFF.

"SuperHiRes ($C0/PNT, $C1/PIC)", list at MAINE $3D02 (file $1453F):

| File type | Aux types | EOF |
|---|---|---|
| $C0 | $0000-$0002 | $1-$FFFFFF |
| $C0 | $8000-$8000 | $1-$FFFFFF |
| $C1 | $0000-$0000 | $1-$FFFFFF |
| $C1 | $0002-$FFFF | $1-$FFFFFF |

"JPEG (JFIF)", list at MAINE $3DAA (file $145E7):

| File type | Aux types | EOF |
|---|---|---|
| $04 | $0000-$FFFF | $8-$FFFFFF |
| $06 | $0000-$FFFF | $8-$FFFFFF |

"GIF (Graphics Interchange Format)", list at MAINE $3D4C (file $14589):

| File type | Aux types | EOF |
|---|---|---|
| $04 | $0000-$FFFF | $D-$FFFFFF |
| $06 | $0000-$FFFF | $D-$FFFFFF |
| $C0 | $8006-$8006 | $D-$FFFFFF |

"PNG (Portable Network Graphics)", list at MAINE $3D84 (file $145C1):

| File type | Aux types | EOF |
|---|---|---|
| $04 | $0000-$FFFF | $8-$FFFFFF |
| $06 | $0000-$FFFF | $8-$FFFFFF |

## 9. Save formats

### 9.1 Save record (38 bytes)

| Offset | Size | Meaning |
|---|---|---|
| +0 | 4 | pointer to name (Pascal string) |
| +4 | 1 | memFlag: $80 = selected (only "$C0,2 Apple Preferred" at start) |
| +5 | 1 | kind / icon: $01 can store a screen image, $02 can store a true color image (3 = both). If bit 1 is clear (or there is no true color image) and there is no screen image yet, one is made first: Remap for a true color image, conversion for a monochrome image. |
| +6 | 2 | ProDOS file type of the new file; $FFFE = Babelfish true color export, $FFFD = Babelfish pixel map export |
| +8 | 4 | default name suffix (replaces an existing suffix of up to 4 characters); "????" = none |
| +12 | 2 | aux type of the new file |
| +14 | 4 | Macintosh file type written to the Finder info (SetFileInfo option list), 0 if none |
| +18 | 2 | warning mask: bit n set = warn if the image has feature n (see 9.3); bit 12 ($1000) = check the size limit at +32/+34 |
| +20 | 1 | size choices enabled in the "Select size of saved picture" dialog (bit 0 = button 2 ... bit 4 = button 6) |
| +21 | 1 | default button in that dialog (same bit layout) |
| +22 | 3 | options routine (long address) called before the file dialog; carry set = cancel. MAINE $9982 is an empty routine (CLC, RTL) |
| +25 | 1 | zero |
| +26 | 2 | save routine, 16-bit MAINE address (JSR) |
| +28 | 4 | pointer to help topic tag ("SF...") |
| +32 | 2 | maximum width in bytes (when +18 bit 12 is set) |
| +34 | 2 | maximum height in lines (when +18 bit 12 is set); too big gives "Image is much too large to save in this format" |
| +36 | 2 | 1 = adds to an existing file (no Save As dialog), 0 = makes a new file |

### 9.2 The 14 save formats

List record MAINE $2116, members at MAINE $8E5C (file $19699), listMemSize 38.

| # | Name | Kind/icon | File type | Aux | Suffix | Mac type | Warn | Sizes/default | Options | Save (MAINE) | Help tag | Max (bytes x lines) | Adds to file |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 0 | $C0,0 PaintWorks+ 1.0 (obsolete) | 1 screen | $00C0 | $0000 | .PNT |  | $0005 | $04/$04 | MAINE $9982 none (CLC, RTL) | $A40E | SFC0x0 |  |  |
| 1 | $C0,1 PackBytes (obsolete) | 1 screen | $00C0 | $0001 | .PAK |  | $0000 | $02/$02 | MAINE $9982 none (CLC, RTL) | $A449 | SFC0x1 |  |  |
| 2 | $C0,2 Apple Preferred (selected) | 1 screen | $00C0 | $0002 | .SHR |  | $0000 | $1F/$01 | MAINE $9982 none (CLC, RTL) | $A4DB | SFC0x2 |  |  |
| 3 | $C1 uncompressed screen | 1 screen | $00C1 | $0000 | .SCR |  | $0000 | $02/$02 | MAINE $9982 none (CLC, RTL) | $A36E | SFC1 |  |  |
| 4 | Finder icon (new file) | 1 screen | $00CA | $0000 | .ICN |  | $1010 | $01/$01 | MAINE $9982 none (CLC, RTL) | $9EB5 | SFICON | 40x50 |  |
| 5 | Finder icon (add to existing file) | 1 screen | $00CA | $0000 | ???? |  | $1010 | $01/$01 | MAINE $9982 none (CLC, RTL) | $9EBA | SFICON | 40x50 | yes |
| 6 | Icon resource (HyperCard, etc.) | 1 screen | $0000 | $0000 | ???? |  | $1000 | $01/$01 | MAINE $9982 none (CLC, RTL) | $A2CF | SFRICON | 80x100 | yes |
| 7 | Desktop background image INIT | 1 screen | $00B7 | $0000 | .INI |  | $0004 | $01/$01 | MAINE $9982 none (CLC, RTL) | $B46D | SFDESK |  |  |
| 8 | Hex data (for programmers only) | 1 screen | $0004 | $0000 | .SRC |  | $0000 | $01/$01 | MAINE $A64A Hex data options window | $A751 | SFHEX |  |  |
| 9 | GIF (Graphics Interchange Format) | 1 screen | $0006 | $0000 | .GIF | GIFf | $0002 | $1F/$02 | MAINE $9982 none (CLC, RTL) | $A88D | SFGIF |  |  |
| 10 | PNG (Portable Network Graphics) | 2 true color | $0006 | $0000 | .PNG | PNGf | $0002 | $1F/$02 | MAINE $9982 none (CLC, RTL) | $FB3E | SFPNG |  |  |
| 11 | TIFF (Tagged Image File Format) | 3 screen+true color | $0006 | $0000 | .TIF | TIFF | $0002 | $1F/$01 | MAINE $9982 none (CLC, RTL) | $B473 | SFTIFF |  |  |
| 12 | Babelfish™ True Color Export | 2 true color | $FFFE (Babelfish true color export) | $0000 |  |  | $0000 | $00/$00 |  |  | SFBABELTRUE |  |  |
| 13 | Babelfish™ PixelMap Export | 1 screen | $FFFD (Babelfish pixel map export) | $0000 |  |  | $0000 | $00/$00 |  |  | SFBABELPIXEL |  |  |

Raw records (name | flag | kind | ftype | suffix | aux | mac | warn | sizes | default | options | 0 | save | tag | maxW | maxH | adds):

```
$8E5C 70900000 00 01 C000 2E504E54 0000 00000000 0500 04 04 829900 00 0EA4 91900000 0000 0000 0000
$8E82 98900000 00 01 C000 2E50414B 0100 00000000 0000 02 02 829900 00 49A4 B3900000 0000 0000 0000
$8EA8 BA900000 80 01 C000 2E534852 0200 00000000 0000 1F 01 829900 00 DBA4 D0900000 0000 0000 0000
$8ECE D7900000 00 01 C100 2E534352 0000 00000000 0000 02 02 829900 00 6EA3 EF900000 0000 0000 0000
$8EF4 F4900000 00 01 CA00 2E49434E 0000 00000000 1010 01 01 829900 00 B59E 2E910000 2800 3200 0000
$8F1A 0B910000 00 01 CA00 3F3F3F3F 0000 00000000 1010 01 01 829900 00 BA9E 2E910000 2800 3200 0100
$8F40 35910000 00 01 0000 3F3F3F3F 0000 00000000 0010 01 01 829900 00 CFA2 55910000 5000 6400 0100
$8F66 5D910000 00 01 B700 2E494E49 0000 00000000 0400 01 01 829900 00 6DB4 7B910000 0000 0000 0000
$8F8C 82910000 00 01 0400 2E535243 0000 00000000 0000 01 01 4AA600 00 51A7 A2910000 0000 0000 0000
$8FB2 A8910000 00 01 0600 2E474946 0000 47494666 0200 1F 02 829900 00 8DA8 CA910000 0000 0000 0000
$8FD8 D0910000 00 02 0600 2E504E47 0000 504E4766 0200 1F 02 829900 00 3EFB F0910000 0000 0000 0000
$8FFE F6910000 00 03 0600 2E544946 0000 54494646 0200 1F 01 829900 00 73B4 16920000 0000 0000 0000
$9024 1D920000 00 02 FEFF 00000000 0000 00000000 0000 00 00 000000 00 0000 3A920000 0000 0000 0000
$904A 46920000 00 01 FDFF 00000000 0000 00000000 0000 00 00 000000 00 0000 61920000 0000 0000 0000
```

### 9.3 Size choices and warnings

"Select size of saved picture" (data fork dialog OSAYCANYOU $1725) has buttons 2-6: Same as original;
One screen wide, one screen (200) high; One screen wide, one page (396) high; One screen wide, two
screens (400) high; Two screens wide, one screen (200) high. Sizes in bytes x lines are in MAINE $9284
(widths) and $9292 (heights): original, 160x200, 160x396, 160x400, 320x200.

Warning bits (+18), checked over all scan lines before saving; the alert (OSAYCANYOU $18E3) reads
"Can't save, the specified format cannot handle:" followed by up to four of these lines, with the
buttons "Cancel save" and "Save anyway, AT YOUR OWN RISK":

| Bit | Condition | Message |
|---|---|---|
| 0 | some line is in 640 mode | => 640-mode graphics. |
| 1 | both 320 and 640 mode lines | => Mixed 320- and 640-mode graphics. |
| 2 | a line uses a palette other than 0 | => Multiple color palettes. |
| 3 | a 640-mode palette is not four pure colours (entries 0-3 differ from 4-7, 8-11 or 12-15) | => 640-mode dithering. |
| 4 | not "all 640 mode, palette 0 only, standard 640 colours" | => Anything but 640 dither mode, default colors. |

## 10. Menus

### 10.1 Menu bar

rMenuBar 1 (flag $8000: menus are resource IDs) lists rMenu 1, 2, 3, 4, 5, 6, 7, 8. It is installed with NewMenuBar2
(resource) and SetSysBar (MAINE $1C90). Menu flag $A008: menu title and item references are
resource IDs ($A000), $0008 = allow caching; $A088 adds $0080 = menu disabled. Item flags: $8000 =
title is a resource ID, $0080 = disabled, $0040 = dividing line below the item, $0020 = XOR
highlighting; $2000 is set on all menu bar items (see section 13).
Titles are rPString resources and keep their spaces.

| rMenu | Menu ID | Title | Title resource | Flag | Items |
|---|---|---|---|---|---|
| 1 | 1 | "@" | rPString $2711 | $A008 | 4 |
| 2 | 2 | "  File  " | rPString $2712 | $A008 | 12 |
| 3 | 3 | "  Edit  " | rPString $2713 | $A008 | 6 |
| 4 | 5 | "  Screen  " | rPString $2714 | $A088 (disabled) | 10 |
| 5 | 9 | "  True color  " | rPString $2715 | $A088 (disabled) | 15 |
| 6 | 6 | "  Monochrome  " | rPString $2716 | $A088 (disabled) | 4 |
| 7 | 4 | "  Windows  " | rPString $2717 | $A008 | 4 |
| 8 | 8 | "  Extras  " | rPString $2718 | $A008 | 6 |

### 10.2 Menu items

Key = itemChar or altItemChar (typed with the Apple key). Item IDs are in hex and decimal.

#### "Apple" (menu ID 1)

| Item | Item ID | Key | Flag | Meaning | Resource |
|---|---|---|---|---|---|
| "About SuperConvert™...   " | $0100 (256) | ! or 1 | $A000 |  | rMenuItem $12C |
| "Help!" | $0105 (261) | ? or / | $A000 |  | rMenuItem $12D |
| "Menu item help" | $0115 (277) |  | $A000 |  | rMenuItem $12E |
| "Preferences..." | $0111 (273) |  | $A040 | line below | rMenuItem $12F |

#### "File" (menu ID 2)

| Item | Item ID | Key | Flag | Meaning | Resource |
|---|---|---|---|---|---|
| "Load & convert..." | $0101 (257) | L or l | $A000 |  | rMenuItem $130 |
| "Re-convert last file" | $0114 (276) | R or r | $A080 | disabled | rMenuItem $131 |
| "Load next" | $0117 (279) | N or n | $A080 | disabled | rMenuItem $132 |
| "Cancel remaining files" | $010C (268) | D or d | $A080 | disabled | rMenuItem $133 |
| "Save conversion..." | $0102 (258) | S or s | $A080 | disabled | rMenuItem $134 |
| "Exchange load/save paths" | $0124 (292) |  | $A040 | line below | rMenuItem $135 |
| "Print (normal)..." | $010F (271) |  | $A080 | disabled | rMenuItem $136 |
| "Print (enhanced)..." | $0119 (281) | P or p | $A080 | disabled | rMenuItem $137 |
| "Print alignment page..." | $0125 (293) |  | $A040 | line below | rMenuItem $138 |
| "Print (?????)..." | $011E (286) |  | $A040 | line below | rMenuItem $139 |
| "Examine file..." | $0110 (272) |  | $A040 | line below | rMenuItem $13A |
| "Quit" | $0103 (259) | Q or q | $A000 |  | rMenuItem $13B |

#### "Edit" (menu ID 3)

| Item | Item ID | Key | Flag | Meaning | Resource |
|---|---|---|---|---|---|
| "Undo" | $00FA (250) | Z or z | $A0C0 | disabled, line below | rMenuItem $FA |
| "Cut" | $00FB (251) | X or x | $A000 |  | rMenuItem $FB |
| "Copy" | $00FC (252) | C or c | $A000 |  | rMenuItem $FC |
| "Paste   " | $00FD (253) | V or v | $A000 |  | rMenuItem $FD |
| "Clear" | $00FE (254) |  | $A0C0 | disabled, line below | rMenuItem $FE |
| "Close" | $00FF (255) |  | $A000 |  | rMenuItem $FF |

#### "Screen" (menu ID 5)

| Item | Item ID | Key | Flag | Meaning | Resource |
|---|---|---|---|---|---|
| "Screen image info..." | $0109 (265) | I or i | $A000 |  | rMenuItem $13C |
| "Convert to true color..." | $0113 (275) |  | $A000 |  | rMenuItem $13D |
| "Convert to monochrome..." | $0131 (305) |  | $A040 | line below | rMenuItem $13E |
| "View full screen" | $0104 (260) | F or f | $A000 |  | rMenuItem $13F |
| "View half size" | $010B (267) | H or h | $A000 |  | rMenuItem $140 |
| "View X4 magnified" | $0128 (296) | 4 | $A000 |  | rMenuItem $141 |
| "View interlaced on VOC" | $0129 (297) |  | $A000 |  | rMenuItem $142 |
| "Store palette" | $012D (301) |  | $A000 |  | rMenuItem $143 |
| "Use as desktop background" | $0118 (280) |  | $A000 |  | rMenuItem $144 |
| "Oscilloscope Art" | $011D (285) |  | $A000 |  | rMenuItem $145 |

#### "True color" (menu ID 9)

| Item | Item ID | Key | Flag | Meaning | Resource |
|---|---|---|---|---|---|
| "True color image info..." | $0123 (291) | T or t | $A000 |  | rMenuItem $146 |
| "Convert to screen (Remap)..." | $0116 (278) | M or m | $A000 |  | rMenuItem $147 |
| "Convert to monochrome..." | $011F (287) |  | $A040 | line below | rMenuItem $148 |
| "View approximation" | $0130 (304) | A or a | $A000 |  | rMenuItem $149 |
| "Rotate/flip image..." | $0121 (289) |  | $A000 |  | rMenuItem $14A |
| "Histogram equalization..." | $012A (298) |  | $A000 |  | rMenuItem $14B |
| "Median filter" | $012B (299) |  | $A000 |  | rMenuItem $14C |
| "Sigma filter" | $012C (300) |  | $A000 |  | rMenuItem $14D |
| "Emboss image" | $0135 (309) |  | $A000 |  | rMenuItem $15C |
| "Blur image..." | $0136 (310) |  | $A000 |  | rMenuItem $15D |
| "Sharpen image..." | $0137 (311) |  | $A000 |  | rMenuItem $15E |
| "Solarize image" | $0138 (312) |  | $A000 |  | rMenuItem $15F |
| "Find edges..." | $0139 (313) |  | $A000 |  | rMenuItem $160 |
| "Increase contrast" | $013A (314) |  | $A000 |  | rMenuItem $161 |
| "Decrease contrast" | $013B (315) |  | $A000 |  | rMenuItem $162 |

#### "Monochrome" (menu ID 6)

| Item | Item ID | Key | Flag | Meaning | Resource |
|---|---|---|---|---|---|
| "Monochrome image info..." | $0132 (306) |  | $A000 |  | rMenuItem $14E |
| "Convert to screen..." | $010A (266) |  | $A000 |  | rMenuItem $14F |
| "Convert to true color..." | $0133 (307) |  | $A040 | line below | rMenuItem $150 |
| "Negative image" | $0134 (308) |  | $A000 |  | rMenuItem $151 |

#### "Windows" (menu ID 4)

| Item | Item ID | Key | Flag | Meaning | Resource |
|---|---|---|---|---|---|
| "Normal positions" | $0126 (294) |  | $A040 | line below | rMenuItem $152 |
| "Load formats" | $0106 (262) |  | $A000 |  | rMenuItem $153 |
| "Save formats" | $0107 (263) |  | $A000 |  | rMenuItem $154 |
| "Current image" | $0108 (264) |  | $A080 | disabled | rMenuItem $155 |

#### "Extras" (menu ID 8)

| Item | Item ID | Key | Flag | Meaning | Resource |
|---|---|---|---|---|---|
| "Available font list" | $011B (283) |  | $A000 |  | rMenuItem $156 |
| "More available fonts" | $0120 (288) |  | $A080 | disabled | rMenuItem $157 |
| "Font key chart..." | $011C (284) |  | $A000 |  | rMenuItem $158 |
| "Print banner..." | $010E (270) |  | $A000 |  | rMenuItem $159 |
| "Revert to normal desktop" | $0127 (295) |  | $A080 | disabled | rMenuItem $15A |
| "System info report..." | $0112 (274) |  | $A000 |  | rMenuItem $15B |

Items $0109 "Screen image info...", $0123 "True color image info..." and $0132 "Monochrome image
info..." get small icons through SetMItemStruct (MAINE $1DBF, Menu Manager 3.3 or later): the screen,
true colour and monochrome list icons (OSAYCANYOU $4453, $44AB, $456F). The Apple menu title "@"
is the colour Apple.

### 10.3 Menus not in the menu bar (used by dialog pop-ups)

- rMenu 9, menu ID 5, title "Filter: ": "None" ($012C), "Auto    " ($012D). Item flag $8020 = title resource, XOR highlighting.
- rMenu 10, menu ID 1000, title "Keyword: ": (no items; filled at run time). Item flag $8020 = title resource, XOR highlighting.
- rMenu 11, menu ID 2000, title "DCT method: ": "Fast integer" ($012C), "Integer" ($012D), "Floating point" ($012E). Item flag $8020 = title resource, XOR highlighting.

### 10.4 Info bar pop-up menus

Built with NewMenu from text in OSAYCANYOU (MAINE $1CBE-$1D69) into a separate, never-shown menu bar
(handle MAINE $2004) and shown with PopUpMenuSelect. Title lines are "##Blah\Nn"; item lines start
with ">>"; "V" = line below, "D" = disabled.

- Menu 1 (text OSAYCANYOU $2E9A (file $55BC5), handle MAINE $2008): Screen image (257); True color image (258); Monochrome image (259, line below); Use image's palette (262, disabled); 320-sized pixels (260, disabled); 640-sized pixels (261, disabled)
- Menu 2 (text OSAYCANYOU $2F38 (file $55C63), handle MAINE $2010): Selection mode (513); Pixel peek mode (514)
- Menu 3 (text OSAYCANYOU $2F70 (file $55C9B), handle MAINE $200C): 1/8 shrink (1021); 1/4 shrink (1022); 1/2 shrink (1023); Actual size (768); 2X zoom (769); 4X zoom (770); 8X zoom (771)
- Menu 4 (text OSAYCANYOU $2FF4 (file $55D1F), handle MAINE $2014): Crop to selection (1025); Discard this image type (1026); Discard other image types (1027)
- Menu 5 (text OSAYCANYOU $305B (file $55D86), handle MAINE $2018): Clicking sets VOC key color (1281)

Item icons (SetMItemStruct with itemFlag2 $8000 and an icon pointer; table OSAYCANYOU $308A):

| Item ID | Menu | Icon |
|---|---|---|
| $0101 | info bar pop-up | OSAYCANYOU $4453 (file $5717E) |
| $0102 | info bar pop-up | OSAYCANYOU $44AB (file $571D6) |
| $0103 | info bar pop-up | OSAYCANYOU $456F (file $5729A) |
| $0104 | info bar pop-up | OSAYCANYOU $48FD (file $57628) |
| $0105 | info bar pop-up | OSAYCANYOU $4945 (file $57670) |
| $0201 | info bar pop-up | OSAYCANYOU $498D (file $576B8) |
| $0202 | info bar pop-up | OSAYCANYOU $49D5 (file $57700) |
| $0109 | menu bar | OSAYCANYOU $4453 (file $5717E) |
| $0123 | menu bar | OSAYCANYOU $44AB (file $571D6) |
| $0132 | menu bar | OSAYCANYOU $456F (file $5729A) |

Icons $48FD (320-sized pixels) and $4945 (640-sized pixels):

```
320-sized pixels, item $0104 = OSAYCANYOU $48FD (16x8)
|#######.#######.|
|#######.#######.|
|#######.#######.|
|................|
|#######.#######.|
|#######.#######.|
|#######.#######.|
|................|
```
```
640-sized pixels, item $0105 = OSAYCANYOU $4945 (16x8)
|###.###.###.###.|
|###.###.###.###.|
|###.###.###.###.|
|................|
|###.###.###.###.|
|###.###.###.###.|
|###.###.###.###.|
|................|
```

## 11. Dialogs

### 11.1 Resource fork windows (rWindParam1 with rControlList)

All eight are NewWindow2 templates of $50 bytes, frame $206D (alert frame, visible) except 6 ($204D,
starts hidden) and 7 ($006D), plane $FFFFFFFF, inDesc $0209 (title resource; control list is an
rControlList resource). No titles, no colour tables. Control types: simple button $80000000,
static text $81000000, check box $82000000, LineEdit $83000000, radio button $84000000, TextEdit
$85000000, scroll bar $86000000, pop-up $87000000, rectangle $87FF0003, picture $8D000000.
Simple button flag bits 0-1: 0 round, 1 bold (default), 2 square. Key equivalent $0D/$0D = Return.

#### rWindParam1 1: "Loading Babelfish..." message (opened from FRED $ED70)

Position (screen) 97,220,112,417, frame $206D, control list rControlList 1.

| Template | ID | Type | Rect | Flag | More flags | Details |
|---|---|---|---|---|---|---|
| $1 | 1 | statText | 3,2,13,194 | $0000 | $1002 | "Loading Babelfish..."; textSize 20; just 1 |

#### rWindParam1 2: PNG save options (opened from FRED $E196)

Position (screen) 29,166,184,472, frame $206D, control list rControlList 2.

| Template | ID | Type | Rect | Flag | More flags | Details |
|---|---|---|---|---|---|---|
| $2 | 1 | simpleButton | 137,219,150,290 | $0001 | $3002 | "OK"; buttonStyle bold outline (default button); key $0D/$0D mods $0000 |
| $3 | 2 | simpleButton | 137,130,150,207 | $0000 | $3002 | "Cancel"; buttonStyle round single outline |
| $4 | 3 | statText | 4,12,14,284 | $0004 | $1002 | "PNG save options"; textSize 16; just 0 |
| $5 | 4 | popUp | 44,81,0,0 | $0002 | $1002 | initialValue 300; menuRef rMenu $9 |
| $6 | 6 | scrollBar | 31,13,42,295 | $001C | $1002 | initialValue 5; maxSize 9; viewSize 1; scrollBarStyle horizontal, arrows: left,right |
| $7 | 7 | statText | 21,12,31,91 | $0004 | $1002 | "More speed"; textSize 10; just 0 |
| $8 | 8 | statText | 21,172,31,297 | $0004 | $1002 | "More compression"; textSize 16; just 0 |
| $9 | 9 | editText (TextEdit) | 68,11,126,294 | $0000 | $7400 | textFlags $03800000 |
| $A | 10 | statText | 59,12,69,88 | $0004 | $1002 | "Comments:"; textSize 9; just 0 |
| $B | 11 | simpleButton | 137,12,150,86 | $0000 | $3002 | "Help!"; buttonStyle round single outline |
| $C | 12 | rectangle | 14,12,15,292 | $0002 | $1000 |  |

#### rWindParam1 3: PNG comments shown while loading a PNG (opened from FRED $DDCE)

Position (screen) 45,166,167,472, frame $206D, control list rControlList 3.

| Template | ID | Type | Rect | Flag | More flags | Details |
|---|---|---|---|---|---|---|
| $D | 1 | simpleButton | 103,219,116,290 | $0001 | $3002 | "OK"; buttonStyle bold outline (default button); key $0D/$0D mods $0000 |
| $E | 2 | simpleButton | 104,131,117,208 | $0000 | $3002 | "Cancel"; buttonStyle round single outline |
| $F | 3 | statText | 4,12,14,284 | $0004 | $1002 | "PNG comments"; textSize 12; just 0 |
| $10 | 4 | popUp | 22,10,35,256 | $0002 | $1002 | initialValue 300; menuRef rMenu $A |
| $11 | 6 | editText (TextEdit) | 37,10,95,293 | $0000 | $7400 | textFlags $07800000 |
| $12 | 7 | rectangle | 14,12,15,292 | $0002 | $1000 |  |

#### rWindParam1 4: About SuperConvert (opened from MAINE $2187)

Position (screen) 28,48,185,592, frame $206D, control list rControlList 4.

| Template | ID | Type | Rect | Flag | More flags | Details |
|---|---|---|---|---|---|---|
| $13 | 1 | simpleButton | 137,19,150,124 | $0001 | $3002 | "OK"; buttonStyle bold outline (default button); key $0D/$0D mods $0000 |
| $14 | 2 | picture | 5,1,62,542 | $FF00 | $1002 | pictureRef rPicture $1 |
| $15 | 3 | picture | 62,100,73,113 | $FF00 | $1002 | pictureRef rPicture $2 |
| $16 | 4 | picture | 78,353,121,534 | $FF00 | $1002 | pictureRef rPicture $3 |
| $17 | 5 | statText | 125,371,151,530 | $0000 | $1002 | "2310 Oxford Road / Tallahassee, FL 32304 / USA"; textSize 42; just -1 |
| $18 | 6 | statText | 76,15,131,327 | $0000 | $1002 | "Original program by Jason Harper / Updates by Ian Brumby /  / The LZW compression technology used is / licensed for use under U.S. Patent 4,558,320 / and foreign counterparts."; textSize 165; just 0 |
| $19 | 7 | statText | 63,123,73,194 | $0004 | $1002 | "Copyright"; textSize 54; just 0 |
| $1A | 8 | statText | 63,216,73,534 | $0004 | $1002 | "1992-1997 Seven Hills Software Corporation"; textSize 42; just 0 |
| $1B | 9 | picture | 63,196,72,213 | $FF00 | $1002 | pictureRef rPicture $4 |

#### rWindParam1 5: JPEG load options, including the "DCT method" pop-up (opened from FRED $E477)

Position (screen) 35,154,178,486, frame $206D, control list rControlList 5.

| Template | ID | Type | Rect | Flag | More flags | Details |
|---|---|---|---|---|---|---|
| $1C | 1 | simpleButton | 124,228,137,314 | $0001 | $3002 | "OK"; buttonStyle bold outline (default button); key $0D/$0D mods $0000 |
| $1D | 2 | simpleButton | 125,131,138,212 | $0000 | $3002 | "Cancel"; buttonStyle round single outline |
| $1E | 3 | statText | 4,12,14,148 | $0004 | $1002 | "JPEG load options"; textSize 17; just 0 |
| $1F | 4 | radioButton | 27,66,36,160 | $0001 | $1002 | "Fast mode"; initialValue 1; radioFamily 1 |
| $20 | 5 | radioButton | 37,66,46,258 | $0001 | $1002 | "Grayscale preview mode"; initialValue 0; radioFamily 1 |
| $21 | 6 | radioButton | 47,66,56,178 | $0001 | $1002 | "Custom mode"; initialValue 0; radioFamily 1 |
| $22 | 7 | popUp | 67,51,0,0 | $FF02 | $1002 | initialValue 300; menuRef rMenu $B |
| $23 | 8 | checkBox | 88,64,97,262 | $FF01 | $1002 | "High quality upsampling"; initialValue 1 |
| $24 | 9 | checkBox | 98,64,107,204 | $FF01 | $1002 | "Force grayscale"; initialValue 0 |
| $25 | 10 | rectangle | 14,12,15,318 | $0002 | $1000 |  |
| $26 | 11 | rectangle | 62,24,113,302 | $0001 | $1000 |  |
| $27 | 12 | simpleButton | 125,12,138,86 | $0000 | $3002 | "Help!"; buttonStyle round single outline |

#### rWindParam1 6: Preferences (opened from OSAYCANYOU $7068)

Position (screen) 34,24,178,616, frame $204D, control list rControlList 6.

| Template | ID | Type | Rect | Flag | More flags | Details |
|---|---|---|---|---|---|---|
| $28 | 1 | simpleButton | 125,494,138,578 | $0001 | $3002 | "OK"; buttonStyle bold outline (default button); key $0D/$0D mods $0000 |
| $29 | 2 | simpleButton | 126,399,139,481 | $0000 | $3002 | "Cancel"; buttonStyle round single outline |
| $2A | 3 | simpleButton | 126,311,139,389 | $0000 | $3002 | "Save"; buttonStyle round single outline; key $53/$73 mods $0100 |
| $2B | 4 | simpleButton | 126,9,139,269 | $0002 | $3002 | "Clear all “SKIP ME” preferences"; buttonStyle square |
| $2C | 5 | picture | 3,182,32,383 | $FF00 | $1002 | pictureRef rPicture $5 |
| $2D | 6 | checkBox | 38,12,48,338 | $0001 | $1002 | "Automatically save picture after loading"; initialValue 0 |
| $2E | 7 | checkBox | 48,12,57,340 | $0001 | $1002 | "Automatically print picture after loading"; initialValue 0 |
| $2F | 8 | checkBox | 58,12,67,364 | $0001 | $1002 | "Automatically load next picture after saving"; initialValue 0 |
| $30 | 9 | checkBox | 68,12,77,380 | $0001 | $1002 | "Don't automatically view screen images after loading"; initialValue 0 |
| $31 | 10 | checkBox | 78,12,87,579 | $0001 | $1002 | "Use second monitor (attached to Video Overlay Card) for continuous viewing"; initialValue 0 |
| $32 | 11 | checkBox | 88,12,97,429 | $0001 | $1002 | "Don't automatically show Remap dialog for true color images"; initialValue 0 |
| $33 | 12 | checkBox | 98,12,107,476 | $0001 | $1002 | "Automatically show Remap dialog after loading screen images"; initialValue 0 |
| $34 | 13 | checkBox | 108,12,117,550 | $0001 | $1002 | "Disk insertion starts load (save, if disk was blank; Requires System 6+)"; initialValue 0 |

#### rWindParam1 7: full-screen window without controls, used when viewing full screen (opened from LONGCODE $ED66)

Position (screen) 0,0,199,639, frame $006D, control list none.

#### rWindParam1 8: "Factor" dialog for the SUPERFX filters (Blur, Sharpen, Find edges), opened from SUPERFX $06E5

Position (screen) 83,206,130,432, frame $206D, control list rControlList 8.

| Template | ID | Type | Rect | Flag | More flags | Details |
|---|---|---|---|---|---|---|
| $35 | 1 | simpleButton | 29,124,42,198 | $0001 | $3002 | "OK"; buttonStyle bold outline (default button); key $0D/$0D mods $0000 |
| $36 | 2 | simpleButton | 29,29,42,108 | $0000 | $3002 | "Cancel"; buttonStyle round single outline |
| $37 | 3 | editLine | 8,116,21,146 | $0000 | $7002 | maxSize 2; defaultText 50 |
| $38 | 4 | statText | 10,149,26,169 | $0000 | $1002 | "%"; textSize 1; just 0 |
| $39 | 5 | statText | 10,56,20,109 | $0000 | $1002 | "Factor:"; textSize 7; just 0 |

### 11.2 Data fork dialog templates (Dialog Manager, GetNewModalDialog)

These are not in the resource fork but are part of the same user interface. Item types: 10 button,
11 check box, 12 radio button, 13 scroll bar, 15 static text, 16/22 long static text, 17 edit line,
20 user item, 21 user control; $8000 = disabled item.

| Template | File | Rect | Items | Purpose | Buttons / boxes |
|---|---|---|---|---|---|
| 9:1725 | $54450 | 30,50,170,400 | 7 | Save: "Select size of saved picture" (buttons 2-6 enabled by save record +20, default by +21) | "Cancel save", "Same as original", "One screen wide, one screen (200) high", "One screen wide, one page (396) high", "One screen wide, two screens (400) high", "Two screens wide, one screen (200) high" |
| 9:19AF | $546DA | 28,135,173,505 | 3 | Save: alignment of the saved area | "centered", "Cancel save" |
| 9:1C18 | $54943 | 30,170,180,470 | 1 | Save: upload description note |  |
| 9:1DFA | $54B25 | 30,5,190,635 | 14 | Extras > Print banner... | "OK", "Cancel", "Choose font:", "Choose font:", "Preview", "         ", "         ", "Second line" |
| 9:201B | $54D46 | 30,10,155,630 | 12 | Finder icon save options (colours, background, icon states) | "OK", "Cancel", "Small icon", "Open", "Offline", "Selected" |
| 9:21D8 | $54F03 | 33,80,183,560 | 15 | Print (enhanced) layout and caption | "OK", "Cancel", "Set caption font", "Info...", "Top", "Center", "Bottom", "Left" |
| 9:23D7 | $55102 | 40,35,178,285 | 12 | ImageWriter LQ print options | "Print", "Cancel", "Color", "Unidirectional printing", "Darker printing", "Landscape mode (sideways)", "Wide paper", "Condensed vertical printing" |
| 9:25FF | $5532A | 90,175,165,465 | 2 | small dialog with a vertical scroll bar and OK, opened by the PS IIgs built-in (GRAPHIC.CGT) loader (MAINE $8B5B) | "OK" |
| 9:2649 | $55374 | 25,70,190,570 | 17 | Finder icon: file-matching rule ("This icon: ... Will be used for files matching ...") | "Save", "Cancel", "Filetype is:", "Auxilliary type is:", "Filename is:", "Run the program:" |
| 9:2A0F | $5573A | 50,100,115,400 | 5 | Name for icon resource | "OK", "Cancel" |
| 9:2AF2 | $5581D | 25,300,190,550 | 3 | Segment chooser note ("Click on the MAIN segment to load") |  |
| 9:2C1B | $55946 | 41,305,159,505 | 8 | Loader progress / palette choice ("Processing ... file", "Use 320 mode" / "Use 640 mode") | "Use 320 mode: 16 colors", "Use 640 mode: 4 colors", "Calculated palette", "Default color palette", "Grayscale palette" |
| 5:280F | $1304C | 20,60,193,400 | 6 | Remap progress (per-colour and per-palette percentages) | "OK" |
| 8:9926 | $4BA7C | 20,10,192,630 | 35 | Convert to screen (Remap) - graphic mode, palette, rendering, scaling; contains the "Get other..." button | "Get other...", "Info on these options", "Cancel", "320 x 200, 16 colors", "640 x 200, 4 colors", "640 x 200 dither mode", "Multipalette modes", "Default color" |
| 8:C477 | $4E5CD | 20,20,190,620 | 4 | image statistics with colour histograms (probably True color image info...) | "Done", "Print" |
| 8:D2DA | $4F430 | 20,170,179,470 | 8 | four icon user items, each with a text line (^0..^3); opened from LONGCODE $D1FA |  |
| 2:13F4 | $01C44 | 40,100,160,560 | 9 | Rotate/flip image | "Make it so", "Cancel", "<< Rotate", "Rotate >>", "\/ Flip \/", "> Flip >", "// Twist", "Twist \\" |
| 23:07E8 | $AC207 | 35,220,190,620 | 2 | Reading IFF file | "Continue" |
| 26:195C | $B8096 | 20,50,185,590 | 13 | TIFF save options | "Save", "Cancel", "Screen image only, as TIFF Class P (palette color) image", "True color image only, as TIFF Class R (RGB color) image", "Both screen and true color images", "Intel byte ordering, suitable for use on IBM & compatible systems", "Motorola byte ordering, suitable for use on Macintosh systems", "Increase compatibility (may increase file size considerably)" |

The "Get other..." button is item 2 of the Remap dialog (LONGCODE $9926), rect 115,35,126,150. Full
item lists, with rectangles and texts, are in the JSON (dataForkDialogs).

### 11.3 Data fork window templates (NewWindow2 from memory)

| Template | File | Position | Frame | Title | Purpose | Controls |
|---|---|---|---|---|---|---|
| 9:3769 | $56494 | 40,110,120,530 | $20A0 |  | Hex data save options ("Start of line", "Item separator", "End of line") | "OK", "Cancel", "Sample line of generated output: / *001*", "Start of line:", "Item separator:" |
| 9:7560 | $5A28B | 40,30,140,610 | $2000 |  | Not enough memory to load the whole image | "There is not currently enough memory ava", "Cancel" |
| 9:34C5 | $561F0 | 45,4,197,612 | $D0B8 | "SuperConvert Help" | Help window ("SuperConvert Help") |  |
| 6:830B | $2ABEF | 30,120,170,520 | $2000 |  | Monochrome image options (aspect ratio, scaling, shrink) | "Resulting image:", "Monochrome pixels / *0 x *1 / CUUResult", "SKIP ME: always use these options", "OK", "Cancel" |
| 6:A877 | $2D15B | 20,106,170,534 | $2000 |  | Choice between ways to save in the selected format | "Continue...", "Cancel", "SKIP ME: save using selected type whenev", "There is more than one way to save an im", "*6*0*7*1*8" |
| 6:B2C5 | $2DBA9 | 40,110,150,510 | $2000 |  | Select page to be loaded (list) | "Select page / to be loaded:", "Cancel", "OK" |
| 6:BC74 | $2E558 | 40,132,150,512 | $2000 |  | 640 mode screen image to true color: exact or smoothed | "OK", "Cancel", "Info on options...", "SKIP ME: always use this option", "Exact: each pixel retains its individual" |
| 6:C591 | $2EE75 | 50,120,145,520 | $2000 |  | Image size / rendering method options | "Image will be *0 by *1*2. *3", "SKIP ME: always use these options", "OK", "Cancel", "Info on options..." |
| 8:0420 | $42576 | 30,2,197,638 | $C000 |  | Examine file window (radio buttons Data fork / Histogram / Resource fork) | "Data fork", "Histogram", "Resource fork" |
| 24:0008 | $AD66D | 25,10,185,630 | $2020 |  | System info report (Cancel / Save as text file / Print) | "Cancel", "Save as text file", "Print" |

LONGCODE $0420 (title bar with close box, 30,2,197,638, radio buttons Data fork / Histogram /
Resource fork) is taken to be the File > Examine file... window; that command's file dialog prompt
"Select file(s) to examine:" is in segment 2.

## 12. Compared with GS Remap's FormatRegistry

- Computer types: the original has 10; GS Remap has 9 and lacks "External (Babelfish™)" with its two formats.
- Apple II family: GS Remap lacks "New Print Shop graphics" (listed in the original but with no loader, so it only shows "This format has not been implemented yet") and "Works of Art (Springboard Publ.)" (monochrome, loader FRED $AEBA).
- Apple IIgs specific, Atari ST, Amiga, Commodore 64/128 and Macintosh: same names in the same order.
- IBM PC & compatibles: the original names are "PC Paintbrush (.PCX, .PCC) ???" (with the question marks) and "AA frame file from FliAway".
- Unix machines: the original names include the extensions: "SGI Iris (.SGI, .BW, .RGB, .RGBA)", "Portable Pixelmap (.PBM, .PGM, .PPM)".
- Computer-independent: the original has 7 entries with two separate IPI entries ("IPI 256x256 image (.R + .G + .B)", "IPI 512x512 image (.R + .G + .B)") and no TIFF or "Anything macOS can open" entry.
- Marking: this version shows the kind of image with an icon per row (section 6.2), not with a leading asterisk; the asterisk belongs to the 3.x manual. Kinds that GS Remap does not model: screen + monochrome (Degas, Degas Elite, Neochrome, Tiny), true color + monochrome (PC Paintbrush), monochrome only (Works of Art, MacPaint as monochrome, ScreenMaker).
- Save formats: the original has 14; GS Remap has 12. GS Remap lacks "Desktop background image INIT" and the two Babelfish™ exports, calls the second icon entry "Finder icon (add to file)" (original: "Finder icon (add to existing file)"), and splits "Icon resource (HyperCard, etc.)" into a new-file and an add-to-file entry (the original has one entry, which adds to an existing file).
- Default name suffixes in the original are ".PNT", ".PAK", ".SHR", ".SCR", ".ICN", ".INI", ".SRC", ".GIF", ".PNG", ".TIF" (or none).

## 13. Uncertain points

- Menu item flag bit 13 ($2000) is set on every menu bar item and clear on the dialog pop-up items; its meaning was not determined. Bits 15-14 = 10 mean the item title is a resource ID.
- Load record +8 (Macintosh file type) is not used by the file filter at MAINE $4610; its use is inferred from the save side, where the same kind of field is written to the Finder info.
- Save record +32/+34 are taken to be bytes per line and lines, by comparison with the size table at MAINE $9284 (160 bytes = one screen width).
- The info bar was not seen in a screen dump (the image window is closed at start-up); its layout comes from the drawing code at MAINE $F083. The same applies to the window title format.
- The "Load next" colours ($E0/$E1 values) are 640-mode dithered colour numbers; their look depends on the palette in use.
- The label boxes were measured in the start-up screen dump; their size follows from the system font glyph bounds.
- rWindParam1 1, 2, 3 and 5 were matched to their callers by the window ID pushed next to $800E in FRED; those call sites were not traced further. Purposes given for data fork dialogs are read from their texts; the ones marked "probably" are guesses.
- Item $011A appears in a list of items enabled and disabled together with the save and print items (MAINE $4244) but is in no menu.
