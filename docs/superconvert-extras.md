# SuperConvert 4: Apple, Edit and Extras menus, and the extra Screen menu commands

How the original SuperConvert 4.0 (Seven Hills Software, data fork 758944 bytes, resource fork
36795 bytes) carries out the Apple menu (About, Help!, Menu item help, Preferences...), the Edit
menu, the Screen menu commands Store palette, Use as desktop background, Oscilloscope Art and View
interlaced on VOC, and the whole Extras menu. Everything here was read from the program code and
from its help file SuperConv.Help (on System604.img in /Live.Install, ProDOS type $04 TXT, aux
$0000, 130188 bytes data fork, 736 bytes resource fork).

Already documented elsewhere and not repeated: menu item IDs, flags and keys
(superconvert-ui-data.md section 10), the resource windows for About (rWindParam1 4) and
Preferences (rWindParam1 6) with every control rectangle (superconvert-ui-data.md 11.1), the Print
banner dialog template 9:1DFA (superconvert-ui-data.md 11.2, its items are repeated in 6.4 below
because the code depends on them), the error alert "I am having a hard time ..." and the common
print set-up (superconvert-file.md 2.3 and 6.1), image variables and the full-screen machinery
(superconvert-image-window.md 1 and 10).

Conventions as in the other documents: $ = hexadecimal, rectangles are (top, left, bottom, right)
with bottom and right exclusive, coordinates are 640-mode pixels, addresses are segment name and
offset (MAINE = 5, FRED = 6, LONGCODE = 8, OSAYCANYOU = 9, DYNAMINFO = 24). Names in square
brackets are the routine names stored in the program. "Toolbox" calls are given by name and number.

## Contents

- 1. Entry points
- 2. Apple menu
  - 2.1 About SuperConvert
  - 2.2 Help! and the help window
  - 2.3 The help file format
  - 2.4 Menu item help
  - 2.5 Preferences...
- 3. Edit menu
- 4. Screen menu extras
  - 4.1 Store palette and the Remap "Stored palette" option
  - 4.2 Use as desktop background (and Revert to normal desktop)
  - 4.3 Oscilloscope Art
  - 4.4 View interlaced on VOC
- 5. Extras menu
  - 5.1 Available font list / More available fonts
  - 5.2 Font key chart...
  - 5.3 Print banner...
  - 5.4 Revert to normal desktop
  - 5.5 System info report...
- 6. Shared helpers used above
- 7. Compared with GS Remap
- 8. Uncertain points

## 1. Entry points

Menu dispatch MAINE $0FC7, table MAINE $101A (4 bytes per item from item $00FA; a 2-byte entry is
a JSR into MAINE, a 3-byte entry a JSL). The help topic label used by Menu item help (2.4) is
listed too.

| Item | ID | Routine | Help label |
|---|---|---|---|
| About SuperConvert... | $0100 | MAINE $215E | M1ABOUT |
| Help! | $0105 | FRED $0036 [Lmhelp] | M1HELP |
| Menu item help | $0115 | FRED $07C1 [Lmmenuhelp] | M1MHELP |
| Preferences... | $0111 | OSAYCANYOU $7032 [DoPrefs] | M1PREFS |
| Undo | $00FA | MAINE $0FFD (RTS) | M3 |
| Cut | $00FB | OSAYCANYOU $07C5 [CutImage] | M3 |
| Copy | $00FC | OSAYCANYOU $07B1 [CopyImage] | M3 |
| Paste | $00FD | MAINE $0FFD (RTS) | M3 |
| Clear | $00FE | MAINE $0FFD (RTS) | M3 |
| Close | $00FF | MAINE $4217 | M3 |
| View interlaced on VOC | $0129 | MAINE $19B0 | M5INTERLACE |
| Store palette | $012D | OSAYCANYOU $069A [SaveAPal] | M5STORE |
| Use as desktop background | $0118 | LONGCODE $EA3D [UseAsDesk] | M5USEDESK |
| Oscilloscope Art | $011D | MAINE $D553 | M5OSCOPE |
| Available font list | $011B | MAINE $CA0C | M8FONTLIST |
| More available fonts | $0120 | MAINE $CA17 | M8MOREFONTS |
| Font key chart... | $011C | MAINE $CD88 | M8KEYCHART |
| Print banner... | $010E | MAINE $D739 | M8BANNER |
| Revert to normal desktop | $0127 | LONGCODE $E997 [RevertDesk] | M8DEFDESK |
| System info report... | $0112 | MAINE $112A: JSL ~JumpTable $0012, which loads dynamic segment 24 DYNAMINFO and enters it at $0191 | M8SYSINFO |

At start-up: MAINE $006C loads the preferences (OSAYCANYOU $7298), MAINE $0641 starts the Video
Overlay Card tool set (LONGCODE $E2D4 [InitVOC]), MAINE $07F1 allocates the help buffer handle
(FRED $0000 [InitHelp]: NewHandle of size 0, user ID MAINE $00A0, kept at MAINE $2284), MAINE
$0801 sets the Revert item (LONGCODE $E920 [CheckDesk]) and MAINE $0808 removes the VOC menu item
when there is no usable card (LONGCODE $E33B [VOCMItems]).

## 2. Apple menu

### 2.1 About SuperConvert (MAINE $215E)

```
w = NewWindow2(title nil, refCon 0, contentDraw MAINE $21CE, defProc nil,
               paramTableDesc 2 (resource), rWindParam1 4, $800E)
repeat
    r = DoModalWindow(event record MAINE $21E2, nil, nil, nil, flags $0008)
until r == 1                       ; control 1 = "OK" (default button, Return)
CloseWindow(w)
```

The content draw routine MAINE $21CE only calls DrawControls. The window, its pictures and texts
are listed in superconvert-ui-data.md 11.1 (rWindParam1 4: position 28,48,185,592, alert frame;
rPicture 1 at 5,1,62,542 is the 541 x 57 "SuperConvert" logo, rPicture 2 (13 x 11) next to the
copyright line, rPicture 3 (181 x 43) above the address, rPicture 4 (17 x 9) between "Copyright"
and "1992-1997 Seven Hills Software Corporation"). The help text M1ABOUT still speaks of a
"Continue" button; the button is "OK".

### 2.2 Help! and the help window

#### Commands

- Help! (FRED $0036 [Lmhelp]): if the help window is not open, HelpGoTo("HOME"); if it is open,
  only bring it to the front (SelectWindow); the page shown does not change.
- Info on format buttons, "Help!" buttons in option dialogs and Menu item help call FRED $02B1
  [HelpGoTo](Pascal label). Dialogs that are themselves modal use FRED $0972 [ModalHelp] (2.2,
  end).
- Closing: the close box (TaskMaster wInGoAway, MAINE $0D9C: the image window closes the image,
  any other window is the help window) or Apple-W in the help window, FRED $0277 [LCloseHelp]:
  CloseWindow, then SetPurge(1) on the help buffer. The text stays in memory until the Memory
  Manager purges it; the next HelpOpen reuses it when the handle has not been purged.

#### Loading (FRED $0086 [HelpOpen])

1. If the window is open ($22AC <> 0): SelectWindow, done.
2. If the help buffer handle (MAINE $2284) has been purged (master pointer 0):
   - GS/OS Open (parameter block MAINE $2530, pCount 12, read access) of "1:SuperConv.Help"
     (class 1 string at MAINE $251A; prefix 1 = the program's folder). The file's EOF comes back in
     the Open block.
   - ReAllocHandle(EOF + $7D00, user ID, attributes $4000) on the same handle.
   - LoadResource(type $0001, ID 1) from the program's own resource fork (8961 bytes) and
     UnPackBytes into the first $7D00 bytes of the buffer (destination size given as $8000; the
     resource unpacks to 32768 bytes). ReleaseResource.
   - GS/OS Read of EOF bytes to buffer + $7D00, Close.
   - Any error: close the file if it was opened, error alert X = $30 ("I am having a hard time
     attempting to load & display the help file."), return $FFFF.
3. SetPurge(0) on the buffer.
4. NewWindow2(title nil, refCon = FRED $0EB1 [HelpVector], contentDraw FRED $0E39 [HelpRedraw],
   defProc nil, template OSAYCANYOU $34C5 from memory). History depth $2383 = 0, $22AC = 1.

So the buffer is: 32000 bytes of help pictures, then the whole text file.

#### The help picture (resource type $0001, ID 1)

PackBytes data that unpacks to one 640-mode screen, 160 bytes x 200 lines, no SCBs and no palette.
It is drawn with the help window's (desktop) colours through the LocInfo at MAINE $2294: portSCB
$0080, pointer = buffer, width 160, bounds 0,0,200,640. Regions used by the help text and the
info bar (rectangles in the picture):

| Rectangle | Contents |
|---|---|
| 0,0,60,300 | reduced "SuperConvert" title (HOME page) |
| 0,310,9,342 / 10,310,19,342 / 20,310,29,342 / 30,310,39,342 | Home, Previous, Next, Back icons (32 x 9) |
| 40,310,49,350 / 50,310,59,350 / 60,310,67,350 | tree pieces "bend", "straight", "arrow" |
| 61,16,71,32 / 61,32,71,48 / 61,48,71,68 | screen, true color, screen + true color list icons |
| 62,168,70,184 / 62,184,70,200 | selection mode and pixel peek mode icons |
| 72,0,84,350 | picture of the image window info bar |
| 0,354,88,640 | picture of the small-icon editor |
| 93,0,151,224 | Second Sight logo |

#### Window (template OSAYCANYOU $34C5, NewWindow2 from memory)

| Field | Value |
|---|---|
| paramLength | $0050 |
| wFrameBits | $D0B8: title bar, close box, right scroll bar, movable, visible, info bar, control tie |
| wTitle | OSAYCANYOU $351D, "SuperConvert Help" |
| wScrollVer | 10 (one arrow click scrolls 10 lines of pixels); other scroll and page values 0 (defaults) |
| wInfoRefCon | FRED $0C0E [InHelpInfo] (called for clicks in the info bar) |
| wInfoHeight | 13 |
| wInfoDefProc | FRED $0A7E [HlpInfoBar] |
| wPosition | 45,4,197,612 (content 608 x 152) |
| wPlane | $FFFFFFFF (front) |

Data height is set per page (SetDataSize(0, last bottom + 3)); the data width is not set.
The font is the window's default (system font).

#### Info bar (FRED $0A7E [HlpInfoBar])

PenNormal, text mode copy, foreground 0, background $FFFF. For n = 1..4 (Home, Previous, Next,
Back), with the info bar rectangle (top, left, bottom, right) given by the Window Manager:

| n | Label | Item area (left - right, added to info left) | Icon x | Label x (baseline info top + 9) | Icon source rows |
|---|---|---|---|---|---|
| 1 | "Home" | 20 - 110 | 30 | 70 | 0-9 |
| 2 | "Previous" | 190 - 310 | 268 | 200 | 10-19 |
| 3 | "Next" | 320 - 410 | 330 | 370 | 20-29 |
| 4 | "Back" | 470 - 560 | 480 | 520 | 30-39 |

(Tables FRED $0B8F, $0BAD, $0B99, $0BA3, $0BB7; labels are the Pascal strings after the window
title at OSAYCANYOU $352F, pointers at OSAYCANYOU $3547.) The icon is PPToPort(help picture, source
rows r..r+9, columns 310-342, to (info left + icon x, info top + 1), copy). If the item is not
available ($22B2 + 2n = 0) its area (info top to info bottom) is painted with pen pattern colour
$FFFF through the pen mask $55,$AA,$55,$AA,... (a 50 % white screen over icon and label). Home is
always available ($22B4 = 1); Previous, Next and Back come from the page's last line (2.3).

Clicks (FRED $0C0E [InHelpInfo]): StartInfoDrawing; the point is made local; find the item area
that contains it; nothing if the item is not available; otherwise track like a button (InvertRect
while the mouse is inside and StillDown), EndInfoDrawing, and act on release inside:

- Back (4): if the history depth $2383 > 0: pop it, restore the stored scroll position ($2385
  = v, $2387 = h) and HelpGoTo(stored label). With an empty history: HelpGoTo(the page's Back
  label).
- Home, Previous, Next: HelpGoTo(label n). The Home label is "HOME" (MAINE $22D2).

#### Keys (FRED $0D48 [KeyInHelp])

| Key | Action |
|---|---|
| h or H | Home |
| left arrow ($08) | Previous |
| right arrow ($15) | Next |
| down arrow ($0A) or up arrow ($0B) | Back |
| Apple-W or Apple-w | close the help window |

An arrow or H for an unavailable item does nothing; otherwise the item's area is inverted once and
the same action as a click follows (the new page redraws the info bar).

#### Buttons in a page (FRED $0DD1 [HelpCtrl])

Topic buttons are simple buttons whose control ID is the pointer to their target label. On a hit:
GetContentOrigin is stored; if the history holds fewer than 20 entries, push (current label
$22DF, scroll v, scroll h) at $22E3/$2333; the scroll origin is reset to 0 and HelpGoTo(target).
Static text controls have ID 0 and are ignored.

#### Drawing (FRED $0E39 [HelpRedraw])

SetCtlParamPtr(MAINE $23AB) (the substitution strings, 2.3), DrawControls, then for every picture
of the page PPToPort(help picture, source rectangle, to its destination, copy); finally the
previous control parameter pointer is restored.

#### ModalHelp (FRED $0972)

Used by "Help!" buttons of modal dialogs: remember the front window and the event mask, close and
reopen the help window at the label, then run TaskMaster until the help window closes
(wInGoAway): control hits and key events go to HelpVector, info bar clicks to InHelpInfo,
wInMenuBar / wInContent of other windows give SysBeep. Afterwards the old front window is
selected again.

### 2.3 The help file format

Plain text, lines end in CR ($0D), Mac OS Roman characters. The file's first line starts with "."
so it is never shown; then comes the error page (below). A page (topic) begins after one or more
label lines and ends at its navigation line. 188 labels, 167 pages.

#### Finding a topic (FRED $02B1 [HelpGoTo], label = Pascal string)

1. HelpOpen; remember the label (MAINE $22DF and $23AB); StartDrawing; EraseRect and InvalRect of
   0,0,9999,608 (OSAYCANYOU $3515); SetOrigin(0, 0).
2. Scan the text from its first byte for CR "." pairs. After each, compare the label with the
   characters that follow, ignoring case (each byte pair is XORed and masked with $5F); the
   character after the label must be CR. So a label line is "." + name + CR, matched exactly
   apart from case.
3. Not found: display from the start of the file instead (the error page).
4. KillControls; SetContentOrigin2(0, h, v) with the stored history position (normally 0, 0),
   which is then cleared; picture count 0; v = 3; picture zone bottom = 0.
5. Lay out lines until the navigation line (below), SetDataSize(0, last bottom + 3),
   DrawInfoBar.

#### Line types (first character)

| First character | Meaning |
|---|---|
| CR (empty line) | v += 5 |
| "." | label line; skipped. Several label lines in a row name the same page (".M4", ".M4NORMAL", ...) |
| "\\" | row of buttons: "\\N~text~LABEL~text~LABEL..." |
| ">" | picture: ">L top,left,bottom,right" or ">R top,left,bottom,right"; anything after the fourth number is a comment |
| "=" | "=0": clear the Back history; "=1": move down past the picture zone (v = zone bottom, or v + 1 if v is already below it); "=2": v -= 9; "=3" to "=7": nothing |
| "^" followed by a non-digit | navigation line, ends the page: "^~previous~next~back" |
| anything else (also "^" + digit) | text |

Text: each line is a static text control (template MAINE $24FA: procRef $81000000, flag $0003,
moreFlags $1000, text pointer into the buffer, text size). Rectangle: v to v + 9, left 6 / right
602, or the text margins of the current picture zone (below). Following lines are joined into the
same control (the CRs are kept, each adds 9 to the height) while the next line starts with a
character $20-$2D, a digit or a letter, the joined text stays under 320 characters, and, inside a
picture zone, the control does not reach the zone bottom. Afterwards v = control bottom.

Substitution codes in the text (the control's parameter array MAINE $23AB): *0 = the requested
label, *1 = normal (LETextBox2 codes: style 0, foreground 0, background 3), *2 = bold (style 1),
*3 = background colour 2, *4 to *9 = "?". The help file uses them only on the error page.

Buttons: "\\N" with N = 1..9 (one digit) buttons, then N pairs of fields separated by "~": the
title and the target label (the routine at FRED $0621 turns each field into a Pascal string in
place). Button width by N (MAINE $2391): 596, 288, 185, 134, 103, 82, 68, 57, 48, 41 for N =
1..10; buttons start at left 6 with 20 pixels between them; top = v + 1, bottom = v + 14. Simple
button template MAINE $23EC (procRef $80000000, round, moreFlags $1000, ID = label pointer). A
pair with an empty title leaves its slot empty. After the row v = bottom + 1 (rows are 15 high).
The file uses N = 1 (156 times), 2, 3 and 4.

Pictures: source rectangle in the help picture; v is not advanced. Destination top = v.

```
w = right - left;  h = bottom - top;  newZoneBottom = v + h
if v >= zoneBottom:                       ; start a new picture zone
    textLeft = 6; textRight = 602
    L: left = 6;                right side text: textLeft = left + w + 10
    R: left = (602 - w) & ~1;   textRight = left - 10
else:                                     ; next to the previous picture of this zone
    L: left = (textLeft - 10) & ~1;  textLeft = left + w + 10
    R: left = ((textRight + 10) - w) & ~1;  textRight = left - 10
zoneBottom = newZoneBottom
store (top, left_src, bottom, right_src, destLeft = left, destTop = v)   ; 12 bytes at MAINE $240A
```

Text and buttons inside the zone (v < zone bottom) use textLeft..textRight (buttons always start
at 6). With several ">L" lines in a row the pictures sit side by side (used for the tree drawing on
the image window page).

Navigation line: "^~previous~next~back" (empty fields allowed, e.g. "^~~~HOME"). The three labels
become Previous, Next and Back; an empty field makes that item unavailable.

Error page (shown when a label is missing): the first page of the file. In this file it is two bold
lines of "ERROR", the text `Invalid data in the SuperConv.Help file:` and `Label "*3.*0*1" not
found.` (the missing label, highlighted), with the navigation line "^~~~back from error".

Resource fork of SuperConv.Help: one resource of type $0001, ID 1, 278 bytes. The program never
opens this fork; it looks like an editor's settings record.

### 2.4 Menu item help (FRED $07C1 [Lmmenuhelp])

```
SetCursor(rCursor 7 from the resource fork)              ; the "pick a menu item" cursor
HiliteMenu(0, the menu of the command)                   ; unhighlight Apple
MenuGlobal($0001)                                        ; dimmed items can be chosen
repeat GetNextEvent(mouseDown | keyDown | deskAcc) until an event
keyDown:   MenuKey(event)                                ; an Apple-key shortcut picks its item
mouseDown: FindWindow
    wInMenuBar: MenuSelect
    wInInfo in the image window: MAINE $053E = 1; SelectWindow(image window);
             MAINE $F796 (info bar pop-up menus); $053E = 0
             a result code c <> 0: HelpGoTo("PU" + 4 hex digits of c)   ; e.g. "PU0101"
    anything else: no help
MenuGlobal($FFFE); InitCursor
item >= $00FA: HelpGoTo(label number item - $00FA of the list OSAYCANYOU $3208)
item 1..$F9 (a desk accessory): HelpGoTo("M1")
no item but a menu: label number 0 ("M3")
HiliteMenu(0, menu)
```

Labels per item (OSAYCANYOU $3208, consecutive Pascal strings): $00FA-$00FF "M3"; $0100 M1ABOUT;
$0101 M2LOAD; $0102 M2SAVE; $0103 M2QUIT; $0104 M5FULL; $0105 M1HELP; $0106 M4LOAD; $0107
M4SAVE; $0108 M4CONV; $0109 M5SCRNINFO; $010A M6TOSCRN; $010B M5SHOW; $010C M2CANCEL; $010D
M8DIGITIZE; $010E M8BANNER; $010F M2PRINT; $0110 M2FILEUTIL; $0111 M1PREFS; $0112 M8SYSINFO;
$0113 M5TOTRUE; $0114 M2RELOAD; $0115 M1MHELP; $0116 M9TOSCRN; $0117 M2LOADNEXT; $0118
M5USEDESK; $0119 M2PRINTE; $011A "?"; $011B M8FONTLIST; $011C M8KEYCHART; $011D M5OSCOPE; $011E
M2xxPRINT; $011F M9TOMONO; $0120 M8MOREFONTS; $0121 M9ROTFLIP; $0122 "?"; $0123 M9TRUEINFO;
$0124 M2EXCHANGE; $0125 M2ALIGN; $0126 M4NORMAL; $0127 M8DEFDESK; $0128 M5MAGNIFY; $0129
M5INTERLACE; $012A M9EQUALIZE; $012B M9MEDIANFILT; $012C M9SIGMAFILT; $012D M5STORE; $012E "?";
$012F "?"; $0130 M9VIEWTRUE; $0131 M5TOMONO; $0132 M6MONOINFO; $0133 M6TOTRUE; $0134
M6NEGATIVE; $0135 M9EMBOSS; $0136 M9BLUR; $0137 M9SHARPEN; $0138 M9SOLARIZE; $0139 M9FINDEDGES;
$013A M9INCCONTRAST; $013B M9DECCONTRAST. "M8DIGITIZE" and "M2xxPRINT" have no page in the help
file (they show the error page); "?" too.

Pop-up help labels in the file: PU0101-PU0106 (image type), PU0201/PU0202 (tool), PU0300-PU0303
and PU03FD-PU03FF (zoom), PU0401-PU0403, PU0501.

### 2.5 Preferences... (OSAYCANYOU $7032 [DoPrefs])

Window rWindParam1 6 (superconvert-ui-data.md 11.1: 34,24,178,616, starts hidden, picture rPicture
5 at the top, eight check boxes, buttons OK / Cancel / Save (Apple-S) / "Clear all "SKIP ME"
preferences").

```
w = NewWindow2(nil, 0, contentDraw OSAYCANYOU $7350 [GenericRedraw], nil, 2, rWindParam1 6, $800E)
for id = 6 .. 13:
    if id == 10 and no usable Video Overlay Card (MAINE $00B0 = 0): HiliteControl(255)   ; dimmed
    else SetCtlValue(variable(id) <> 0)
if all six "SKIP ME" words MAINE $00D6-$00E0 are 0: HiliteControl(255, control 4)
ShowWindow(w)
loop r = DoModalWindow(event record OSAYCANYOU $6F49, nil, nil, nil, 0):
    1 OK:     variable(id) = GetCtlValue(id) for id 6..13; done
    3 Save:   as OK, then write the preferences file
    2 Cancel: done
    4 Clear all "SKIP ME" preferences: the six words = 0 at once (Cancel does not undo it);
              dim control 4; continue
done: FRED $97A3 [FlushNsert], CloseWindow
```

| ID | Check box | Variable |
|---|---|---|
| 6 | Automatically save picture after loading | MAINE $00B6 |
| 7 | Automatically print picture after loading | MAINE $00B8 |
| 8 | Automatically load next picture after saving | MAINE $00BC |
| 9 | Don't automatically view screen images after loading | MAINE $00BE |
| 10 | Use second monitor (attached to Video Overlay Card) for continuous viewing | MAINE $00B2 |
| 11 | Don't automatically show Remap dialog for true color images | MAINE $00C0 |
| 12 | Automatically show Remap dialog after loading screen images | MAINE $00C2 |
| 13 | Disk insertion starts load (save, if disk was blank; Requires System 6+) | MAINE $00C4 |

Preferences file "9:SuperConv.Prefs" (class 1 string OSAYCANYOU $701F; prefix 9 = the program's
folder): type $5A, aux $0000, access $C3, exactly 16 bytes = the eight words above in the order
$00B6, $00B8, $00BC, $00BE, $00B2, $00C0, $00C2, $00C4 (each 0 or 1).

- Saving (OSAYCANYOU $72DE then GS/OS): Destroy, Create (type $5A), Open with write access, Write
  16 bytes, Close. Errors are ignored silently.
- Loading at start-up (OSAYCANYOU $7298): clear the 16-byte buffer, Open (read), Read 16 bytes,
  Close; a missing file leaves all options off. Then the words are copied to the variables
  (OSAYCANYOU $7317).
- The "SKIP ME" flags are not saved in this file.

The help page M1PREFS names "Apple-minus or Apple-_" as shortcuts; in this version the item has no
key equivalent and no code tests for these keys.

## 3. Edit menu

#### Enabling (MAINE $2572, run before every TaskMaster call)

- Front window is a system window (desk accessory): enable Undo, Cut, Copy, Paste, Clear, Close.
  TaskMaster then hands the commands to the desk accessory.
- Otherwise: disable Undo, Paste, Clear; Cut and Copy enabled only when a screen image exists
  (MAINE $052C); Close enabled when any image exists ($052C, $052E or $0530).

So for SuperConvert's own windows Undo, Paste and Clear are always dimmed (their table entries are
an RTS), and Cut/Copy work on the screen image only. The help page M3 describes only the desk
accessory case.

#### Copy (OSAYCANYOU $07B1) and Cut (OSAYCANYOU $07C5)

```
cut = (Cut ? 1 : 0)
loc = copy of the image LocInfo MAINE $00E2 (16 bytes); loc.portSCB = MAINE $00F2 (SCB of line 0);
      loc.bounds.right = MAINE $00F4 (width in the image's own pixels)
frame = loc.bounds                                   ; whole image
if the screen image has a selection (MAINE $E180):
    frame = (top $E196, left $E198, bottom $E19A, right $E19C)
    in 320 mode (SCB bit 7 clear) left and right are halved
MAINE $C95F(SCB, 40)                                 ; open a port over the image buffer (section 6)
ClipRect(loc.bounds)
pic = OpenPicture(frame)
PPToPort(loc, frame, frame.left, frame.top, mode copy)
ClosePicture
MAINE $C9EE                                          ; close the port
error: alert X = $3C ("cutting/copying to the Clipboard."), KillPicture, return
ZeroScrap
PutScrap(size of pic, type 1 (picture), pic); KillPicture
PutScrap(34, type $8002, MAINE $4017): word $0001, then the 16 colours of palette 0 (MAINE $00FA)
if more than one palette is used (MAINE $048E <> 0) or both 320 and 640 lines exist
   (MAINE $048A <> 0 and $048C <> 0):
    AlertWindow(C string OSAYCANYOU $0983)
if cut and there is no selection:
    screen image exists = 0
    if no true color and no monochrome image: MAINE $4217 (as Close)
    else FRED $9D4D [ImgChanged]
```

AlertWindow string (size 6, icon 4, one button "Continue" (^#6)): "The Clipboard does not
currently support mixed graphics modes or multiple color palettes.  This image will probably not
look right when pasted."

So the clipboard gets a QuickDraw II picture of the screen image (or its selection) in the mode
of its first line, plus a private scrap of type $8002 = count word 1 and palette 0. Cut with a
selection behaves exactly like Copy (nothing is erased). The SCB written into the picture is the
one of line 0 only.

#### Paste, Clear, Undo

Nothing (MAINE $0FFD is an RTS); dimmed for SuperConvert's windows.

#### Close (MAINE $4217)

Discards all images (also the action of the image window's close box): LONGCODE $AF4F
[PurgeRemap], FRED $8767 [PurgeMono], HideWindow(image window), FRED $A0A6 [ExitPals],
HideControl("Save..." button MAINE $2112), disable items $0102, $0108, $010F, $0119, $011A,
$011E, disable menus 5, 9, 6 (Screen, True color, Monochrome), screen image flag $052C = 0,
selection flag $E180 = 0.

## 4. Screen menu extras

The Screen menu is enabled whenever any image exists. The commands below first make a screen
image when there is none (FRED $C1FB [MakeScreen], superconvert-image-window.md 10.1) except
Store palette, which needs a screen image and is reached only then.

### 4.1 Store palette (OSAYCANYOU $069A [SaveAPal]) and the Remap "Stored palette" option

The Remap dialog's palette radio buttons (item IDs $20-$25: Default color, Grayscale, Calculated,
Stored palette, Picture's current, Get other) take their palettes from one list per graphics mode
(LONGCODE $97F6, four pointers):

| Mode | List | Default color | Grayscale | Calculated (template) | Stored | Picture's current |
|---|---|---|---|---|---|---|
| 0: 320 x 200, 16 colors | LONGCODE $9806 | $981E | $9840 | $9862 | pointer $9812 | pointer $9816 |
| 1: 640 x 200, 4 colors | LONGCODE $9884 | $989C | $98A6 | $98B0 | pointer $9890 | pointer $9894 |
| 2: 640 x 200 dither | LONGCODE $98BA | $98D2 | $98E4 | $98F6 | pointer $98C6 | pointer $98CA |
| 3: Multipalette | LONGCODE $9908 | (own options, no stored palette) | | | | |

Each palette is a count word followed by that many $0RGB words. The stored palette lives in
LONGCODE $97D4 (count + up to 16 colours), the "picture's current" palette in LONGCODE $97B2.

Store palette:

```
clear all three "Stored" pointers ($9812, $9890, $98C6)
if the screen image's line 0 is 320 mode (MAINE $00F2 bit 7 clear):
    n = 16; $9812 -> $97D4                       ; available in 320 mode only
else if colours 0-3 of palette 0 equal colours 4-7:
    n = 4;  $9890 -> $97D4                       ; available in 640 4-colour mode only
else:
    n = 8;  $98C6 -> $97D4                       ; available in 640 dither mode only
$97D4 = n; $97D6.. = the first n colours of palette 0 (MAINE $00FA)
```

Only palette 0 is used, also for multipalette images. Nothing is written to disk; the palette
lasts until the program quits or the next Store palette. There is no message.

In the Remap dialog LONGCODE $AE62 [AllowPals] runs whenever the graphics mode changes: for each
of the six choices the radio button is enabled if the mode's pointer is set and dimmed
(HiliteControl 255) if it is nil; if the current choice ($0F33) becomes dimmed, the choice moves
to Calculated (item $22). So "Stored palette" can be chosen only in the graphics mode the palette
was stored from, and Remap then uses exactly those n colours.

"Picture's current" is filled the same way by OSAYCANYOU $0723 [PicAPal] (from the current screen
image, only if one exists) when Remap starts (LONGCODE $9F71) and from FRED $B861.

The 640 4-colour default palette ($989C) is $000 $F00 $0F0 $FFF, grey $000 $777 $CCC $FFF; the
640 dither default ($98D2) is $000 $F00 $0F0 $FFF $000 $00F $FF0 $FFF.

### 4.2 Use as desktop background (LONGCODE $EA3D [UseAsDesk])

```
MakeScreen; carry set: return
h = LONGCODE $EA8D [CreateDesk]
    failed (no memory): SysBeep; UnMakeScrn; return
MessageCenter(addMessage 1, type 2, h); DisposeHandle(h)
LONGCODE $EB9E [NewDeskMsg]
LONGCODE $E920 [CheckDesk]
FRED $C505 [UnMakeScrn]
```

CreateDesk builds a Window Manager desktop message (message type 2) holding a picture:

```
h = NewHandle($7D08 = 8 + 32000, locked + fixed)
fill all $7D08 bytes with $DD                      ; the light blue desktop dither
word at +6 = 1                                     ; 1 = picture follows (0 would be a pattern)
pixels start at +8, 160 bytes per line, 200 lines (lines 0-12 lie under the menu bar)
bytes = min(image bytes per line MAINE $00E8, 160)
x0    = (160 - $00E8) / 2 when $00E8 < 160, else 0       ; centred, or cut on the right
lines = image lines MAINE $00EE
if lines >= 200: copy the first 200 lines to rows 0-199     ; bottom cut off
else if lines >= 187: first row = 200 - lines                ; bottom aligned
else: first row = (187 - lines) / 2 + 13                     ; centred below the menu bar
copy each line's first "bytes" bytes to row r at byte x0
```

The image's SCBs and palettes are not used: the bytes are shown with the desktop's own 640-mode
colours (help text: remap to 640 dither mode with the default palette, or 320 mode with a black and
white palette, to make it look right).

NewDeskMsg: Desktop(8 = CheckForNewDeskMsg, 0), then Desktop(5 = SetDeskPat, Desktop(4 =
GetDeskPat, 0)) to make the Window Manager redraw the desktop.

CheckDesk (also at start-up and at the end of every full-screen view): MessageCenter(getMessage 2,
type 2, an empty handle); if a type 2 message exists (no error, or error $0201 only) enable item
$0127 Revert to normal desktop, else disable it.

### 4.3 Oscilloscope Art (MAINE $D553)

Turns the screen image into a 320-mode picture meant to be watched on an oscilloscope connected to
the composite video output: each pair of screen lines is given its own grey level, so the video
voltage of a lit pixel encodes the source line, and the scope (TV-line triggered) draws the picture
as 320 x 100 points with 3 brightness levels.

```
MakeScreen; carry set: return
busy on (WaitCursor + heartbeat, MAINE $278F)
for L = 199 down to 0:                                       ; source line L
    if L >= image lines: line = 160 zero bytes, s = 0
    else: line = image line L padded with zeros to 160 bytes; s = SCB of line L
    out = image buffer + $8300 + L * 160                     ; temporary area (buffer is 64K)
    for byte i = 0..159, for each nibble (high first):
        if s is 640 mode: b = (brightness of colour ((nib >> 2) + k) + brightness of colour
                              ((nib & 3) + k + 4)) / 2, with k = 0 for the high nibble, 8 for the low
        else:             b = brightness of colour nib
          (brightness = R + G + B of that colour in palette s & 15, 0..45)
        lit = (L odd ? b >= 15 : b >= 30)
        output nibble = lit ? (LEVEL[L] & 15) : 0
copy 256 bytes from MAINE $D2AB to palettes 0-7 (MAINE $00FA); palettes 8-15 are kept
reorder: a = $17; X = 0
    repeat: repeat a = a * 2; if a >= 256: a = (a & $FF) xor $1D  until a < 200
            image row X = temporary line a; SCB(row X) = SCBTAB[a]; X++
    until a == $17
    image row 199 = temporary line 0, SCB = SCBTAB[0]
busy off; set size 160 bytes x 200 lines (MAINE $4E16); show (MAINE $4271)
```

The reordering visits every line 0-199 exactly once (rows 0, 1, 2 ... get lines 46, 92, 184, 109,
169, 79, 158, 33 ...; row 199 gets line 0).

Tables:

- SCBTAB (MAINE $D3AB, 200 bytes): 7 for lines 0-27, 6 for 28-55, 5 for 56-83, 4 for 84-111, 3 for
  112-139, 2 for 140-167, 1 for 168-195, 0 for 196-199.
- LEVEL (MAINE $D473, 200 bytes): repeating every 28 lines: 14, 14, 13, 13, 12, 12, ..., 1, 1.
- Palettes (MAINE $D2AB), palette p = 0..7: colour 0 = $000; colours 1-7 = R = G = 2p, B = 0..6;
  colours 8-14 = R = G = 2p + 1, B = 0..6; colour 15 = $FFF. For example palette 7: $000 $EE0 $EE1
  $EE2 $EE3 $EE4 $EE5 $EE6 $FF0 $FF1 $FF2 $FF3 $FF4 $FF5 $FF6 $FFF.

So line pair 2k/2k+1 has one luminance (decreasing from the top line to the bottom), the even
line lights for bright pixels (sum >= 30) and the odd line for medium ones (>= 15). In the 640-mode
case the code takes the nibble halves in the order colours 0-3 / 4-7 for the high nibble and
8-11 / 12-15 for the low nibble (the hardware order is 8-11, 12-15, 0-3, 4-7). The routine at
MAINE $D6F8 advances the destination pointer's low word only (bank byte written to the wrong
direct page cell); harmless while the image buffer does not cross a bank.

The help page M5OSCOPE gives the required set-up: Control Panel monochrome display, black border;
scope DC coupled, TV line sync, about 0.5 V/div and 20 ms/div.

### 4.4 View interlaced on VOC (MAINE $19B0)

Needs an Apple Video Overlay Card with the Video Overlay tool set (tool set $21, TOOL033).

Start-up (LONGCODE $E2D4 [InitVOC]): $00AE = $00B0 = $00B2 = $00B4 = 0; LoadOneTool($21, $0100)
and the tool set's StartUp ($0221) (on error UnloadOneTool); $00AE = 1; if function $1B21 (query
feature) answers 1 for features $12 and $13, $00B0 = 1 (usable card). LONGCODE $E33B
[VOCMItems]: without a usable card the item $0129 is deleted from the Screen menu (DeleteMItem,
CalcMenuSize). Quit: LONGCODE $E36A [ShutVOC] (attach, tool set ShutDown $0321).

The command: MakeScreen; FlushEvents; LONGCODE $ED1D [DoWithFull](MAINE $19D4); UnMakeScrn.
Below, VDGG(c, v) is tool call $1D21 (graphics generator control) with control c and value v.

```
LONGCODE $E3AF [VOCAttach]                     ; VDGG($12, 0); undo a held interlace view
interrupts off
VDGG($C8, 1); VDGG($CB, 1); VDGG($C9, $30)     ; interlace on (value meanings: see 8)
palettes: all 16 (MAINE $00FA) to bank $E1 $9E00; and to bank $E0 $9E00 after saving its
          contents; VDGG($12, 1); restore bank $E0; VDGG($12, 0)
SCBs: for k = 0..199: $E1:9D00+k = SCB of image line 2k; $E0:9D00+k = SCB of line 2k+1
          (same save / VDGG($12,1) / restore / VDGG($12,0) dance for bank $E0)
pixels: for k = 0..199:
    $E1:2000 + 160k = image line 2k (first min(bytes, 160) bytes, rest $F0;
                      lines beyond the image all $F0)
    $E0:2000 + 160k = image line 2k+1 (rest $0F; beyond the image all $0F), old bytes saved,
                      VDGG($12, 1), old bytes restored, VDGG($12, 0)
VDGG($12, 1); VDGG($C8, 0)
LONGCODE $E388 [VOCDetach]                     ; with "Use second monitor": VDGG($12, 1)
interrupts restored
if "Use second monitor" (MAINE $00B2): $00B4 = 1; return     ; the picture stays on the VOC monitor
wait for mouseDown or keyDown (GetNextEvent mask $000A); an Apple-key key is posted again
VDGG($12, 0); VDGG($CB, 0); VDGG($C9, 0)
```

So the even lines go to the normal Super Hi-Res buffer (bank $E1), the odd lines are written to
bank $E0 while the card captures them, and bank $E0's own contents are put back with capture off.
The result is 400 interlaced lines on the VOC output; the built-in video output shows the even
field (the help text warns it shows garbage). The image should be 400 lines high for the right
proportions. With "Use second monitor" the picture is held on the card until the next full-screen
view (VOCAttach clears $00B4 and switches $C8, $CB, $C9 off).

## 5. Extras menu

### 5.1 Available font list (MAINE $CA0C) / More available fonts (MAINE $CA17)

Makes a 640-mode screen image that lists every installed font in itself.

```
Available font list: start index $CC91 = 0; name suffix "00"
More available fonts: keep $CC91; name suffix + 1 ("01", "02", ...; two digits)
busy on; MAINE $4217 (discard the current image)
MAINE $C95F(SCB $80, 160 bytes)          ; port over the image buffer: 640 x 400 (section 6)
SetSolidBackPat($FFFF); EraseRect(port rect); SetForeColor(0); SetBackColor($FFFF); SetTextMode(copy)
collect: for n = 1, 2, ...: FindFontStats(fontID $00FF0000, flags $001E, n, result)
         stop at the first result with bit 15 of its stats word set; errors skip n
         store result font IDs (4 bytes each) at LONGCODE $4F88
sort them (segment 2 $9F2C, a qsort): by size (byte 3) first, then by family name
         (GetFamInfo, byte-wise, case sensitive, shorter first); style is not compared
x = 640 (forces a new row); y = 0; rowH = 0; $CC91 = 0
for i = start index .. end:
    InstallFont(id, 1)                        ; 1 = no scaling
    if failed, or GetFontID <> id, or ascent = descent = 0,
       or ascent|descent|widMax|leading >= 256: SetPurgeStat(id, purgeable); SysBeep; next
    text = family name + style words + " " + size + " "        (LONGCODE $EBE3 [MakeFName])
    w = StringWidth(text without the last space)
    if x + w >= 640: x = 0; y += rowH; rowH = 0
                     if y >= 400: SetPurgeStat; stop
    rowH = max(rowH, ascent + descent + 1)
    MoveTo(x, y + ascent); DrawString(text); SetPurgeStat(id, purgeable)
    x += StringWidth(text)                    ; including the trailing space
    if y + ascent + descent >= 396 and $CC91 = 0: $CC91 = i   ; next page starts with this font
close port; lines = min(y + rowH + 1, 400)
screen size 160 bytes x lines, 640 mode (MAINE $4E16); palette and SCBs (MAINE $4CE5):
    all 400 SCBs $80, palette 0 = $000 $F00 $0F0 $FFF repeated four times
file name (MAINE $3F61) = "FontList00" (suffix as above)
busy off; show (MAINE $4271); disable $0114 Re-convert last file
enable $0120 More available fonts if $CC91 <> 0, else disable it
```

Style words appended by MakeFName, by style bit 0-7: " Bold", " Italic", " Underline", " Outline",
" Shadow", " Unknown", " Unknown", " Unknown". The size is decimal (1 to 3 digits). Example:
"Shaston Bold 16 ". Entries in one row share the row top (they are top aligned, not baseline
aligned). Text is black on white, drawn with text mode copy, so each entry's background is white.
Note that the list is rebuilt and resorted for every page, and the page break font (the first whose
bottom reaches line 396) appears again at the top of the next page.

### 5.2 Font key chart... (MAINE $CD88)

```
MAINE $4217; MAINE $C95F($80, 160)                     ; as 5.1
id = ChooseFont(last id (initially $10000000: family $0000, plain, size 16), 0); 0 = cancelled: close port, return
FRED $97DF [UpdateAll]; busy on
erase white; SetForeColor(0); SetBackColor($FFFF); SetTextMode(4 = foreground copy)
header: MoveTo(0, 11); LoadSysFont; DrawString(MakeFName(id)); x = width + 8; y = 0
InstallFont(id, 0)                                     ; scaling allowed
checks as in 5.1; on failure: alert X = $2C ("trying to display a font.") with the error
    code ($FF03 "Font appears to be damaged" when the font info is unusable)
rowH = max(ascent + descent + leading, 18)
for c = 0 .. 255:
    MoveTo(0, 0); CharBounds(c) -> glyph right edge cr
    skip c if c < firstChar or c > lastChar of the font, or its offset/width entry is $FFFF
    LoadSysFont; SetForeColor(c < $80 ? 2 : 1)
    hex = 2 hex digits of c; key = key equivalent (below)
    W = max(CStringWidth(hex), CStringWidth(key))
    if x + cr + W + 4 >= 640: y += rowH; x = 0
    MoveTo(x + (W - width(hex)) / 2, y + 7);  DrawCString(hex)
    MoveTo(x + (W - width(key)) / 2, y + 16); DrawCString(key)
    InstallFont(id, 0); SetForeColor(0)
    MoveTo(x + W + 4, y + ascent); DrawChar(c)
    x += W + 16 + cr
SetPurgeStat(id, purgeable); close port
lines = min(y + rowH, 400); size 160 x lines, 640 mode; palette and SCBs as in 5.1
file name "KeyChart"; busy off; show; disable $0114
```

So the two labels are drawn in the system font in colour 2 (green in palette 0, characters
$00-$7F) or colour 1 (red, $80-$FF), centred in a column of width W; the character itself follows
4 pixels to the right in black.

Key equivalent text (built in MAINE $D151 by MAINE $D276):

- $00-$1F: "^" followed by the character + $40 (e.g. "^A").
- $20-$7F: the character; space is written "Spc", $7F "Del".
- $80-$FB: character $14 of the system font (the solid Apple, standing for Option), then from the
  table MAINE $D16C (two bytes per character): if the first byte is not a space, that dead key
  character and a space; then the second byte (space written "Spc"). Examples: $80 "Ä" = Option
  u + "A"; $81 "Å" = Option + "A"; $CA = Option + "Spc".
- $FC-$FF: empty.

Table MAINE $D16C for $80-$FB, as shown (Option is always pressed first; "x+y" = Option-x as a
dead key, then y):

- Dead key entries: 80 u+A, 83 e+E, 84 n+N, 85 u+O, 86 u+U, 87 e+a, 88 `+a, 89 i+a, 8A u+a,
  8B n+a, 8E e+e, 8F `+e, 90 i+e, 91 u+e, 92 e+i, 93 `+i, 94 i+i, 95 u+i, 96 n+n, 97 e+o, 98 `+o,
  99 i+o, 9A u+o, 9B n+o, 9C e+u, 9D `+u, 9E i+u, 9F u+u, AB e+Spc, AC u+Spc, CB `+A, CC n+A,
  CD n+O, D8 u+y.
- Single keys (Option + key): 81 A, 82 C, 8C a, 8D c, A0 t, A1 *, A2 4, A3 3, A4 6, A5 8, A6 7,
  A7 s, A8 r, A9 g, AA 2, AD =, AE ", AF O, B0 5, B1 +, B2 ",", B3 ., B4 y, B5 m, B6 d, B7 w,
  B8 P, B9 p, BA b, BB 9, BC 0, BD z, BE ', BF o, C0 ?, C1 1, C2 l, C3 v, C4 f, C5 x, C6 j,
  C7 `\`, C8 |, C9 ;, CA Spc, CE Q, CF q, D0 -, D1 _, D2 [, D3 {, D4 ], D5 }, D6 /, D7 V, D9 ~,
  DA !, DB @, DC #, DD $, DE %, DF ^, E0 &, E1 (, E2 ), E3 W, E4 E, E5 R, E6 T, E7 Y, E8 U, E9 I,
  EA S, EB D, EC F, ED G, EE H, EF J, F0 K, F1 L, F2 :, F3 Z, F4 X, F5 B, F6 N, F7 M, F8 <,
  F9 >, FA h, FB k.

In the table a byte pair "space, key" marks a single key; the shown text is $14, [dead key,
space,] key.

### 5.3 Print banner... (MAINE $D739)

#### Flow

```
MAINE $4217 (discard image); MAINE $00F2 = $80
MAINE $B5FF (print record set-up, superconvert-file.md 6.1)
PrStlDialog(print record); cancelled: MAINE $B69B (print clean-up), return
copy prInfo.rPage (print record +8..+15) to MAINE $DDD2 (top, left, bottom, right)
d = GetNewModalDialog(OSAYCANYOU $1DFA); SetPort(d)
loop:
    InvalRect(item 65 rect), InvalRect(item 66 rect); EraseRect(preview area 115,0,160,630)
    ParamText(nil, MakeFName(font 1), MakeFName(font 2), nil)
    r = ModalDialog2(nil): item = low word, part code = high word
    part 3 (check box): toggle its value; part 4 (radio): set its value 1
    part 2 (button) or item 1:
        1 OK:        render (below); CloseDialog; print (below)
        2 Cancel:    CloseDialog; return
        3 Choose font (line 1): id = ChooseFont(font 1, 0); if not 0: font 1 = id
        4 Choose font (line 2): "Second line" check box = 1; id = ChooseFont(font 2, 0); ...
        5 Preview:   render; preview (below)
```

Initial fonts (kept between uses): font 1 = $2002FFFE (family $FFFE Shaston, style $02, size 32),
font 2 = $200AFFFE (Shaston, style $0A, size 32), shown by MakeFName as "Shaston Italic 32 " and
"Shaston Italic Outline 32 ".

#### Dialog (OSAYCANYOU $1DFA, rect 30,5,190,635, visible, 14 items)

| ID | Type | Rect | Text / value |
|---|---|---|---|
| 1 | button | 85,510,100,610 | "OK" |
| 2 | button | 85,390,100,490 | "Cancel" |
| 3 | button | 5,200,16,330 | "Choose font:" |
| 4 | button | 45,200,56,330 | "Choose font:" |
| 5 | button | 95,265,106,365 | "Preview" |
| 16 ($10) | radio, family 1 | 87,65 | nine spaces; value 1; colour table OSAYCANYOU $1EF3 ($0000 $00F0 $00F0 $000F) |
| 17 ($11) | radio, family 1 | 87,145 | nine spaces; value 0; colour table OSAYCANYOU $1F13 ($0000 $00F0 $00F0 $003F) |
| 32 ($20) | check box | 46,10 | "Second line"; value 0 |
| 48 ($30) | edit line (max 255) | 20,5,35,625 | first line text |
| 49 ($31) | edit line (max 255) | 60,5,75,625 | second line text |
| 64 | static text | 7,10,17,190 | "First or only line" |
| 65 | static text | 6,340,16,630 | "^1" + spaces (font 1 name) |
| 66 | static text | 46,340,56,630 | "^2" + spaces (font 2 name) |
| 67 | static text | 87,10,97,85 | "Print:" |

The two radio buttons have blank titles; their colour tables differ only in the title colour word
($000F against $003F), which makes the first title a solid black bar and the second a black and
white dither (grey): Print: [black] [grey]. Item 17 on = grey printing. The preview area is
115,10,155,620 (rectangle MAINE $D997), erased as 115,0,160,630 (MAINE $D99F).

#### Render (MAINE $DA8A)

```
WaitCursor
second = value of item $20; grey = value of item $11
InstallFont(font 1, 0); GetFontInfo -> asc1, desc1, widMax1, lead1
t1 = GetIText(item $30); if empty: t1 = " "
StringBounds(t1) -> b1;  H = b1.bottom - b1.top;  W = b1.right - b1.left;  x1 = -b1.left
if second:
    InstallFont(font 2, 0); GetFontInfo -> lead2; t2 = GetIText(item $31); StringBounds -> b2
    H += (lead1 + lead2) / 2 + (b2.bottom - b2.top)
    x2 = -b2.left; W2 = b2.right - b2.left
    if W2 > W: x1 += (W2 - W) / 2; W = W2
    if W2 < W: x2 += (W - W2) / 2
restore the dialog's font, text face 0
pageLen = ceil(3 * H * rPage.bottom / rPage.right)          ; FixRatio, FixMul, rounded up
pages   = ceil(W / pageLen)
pad = (pages * pageLen - W) / 2;  x1 += pad;  x2 += pad;  W = pages * pageLen
MAINE $C95F($80, ceil(W / 4) bytes)                          ; port over the image buffer
erase white; foreground 0; background $FFFF; text mode copy
if H < port lines: port lines = H                            ; else the banner is cut at the bottom
InstallFont(font 1, 0); MoveTo(x1, -b1.top); DrawString(t1)
if second: InstallFont(font 2, 0); MoveTo(x2, H - b2.bottom); DrawString(t2)
close port; SetPort(dialog); InitCursor
```

The banner image is a 640-mode bitmap W pixels wide and H lines high (black text on white) in the
screen image buffer, at most 65536 bytes.

#### Preview (MAINE $D88E)

```
EraseRect(115,0,160,630)
CopyPixels(banner LocInfo, dialog port, banner rect, 115,10,155,620, mode copy)  ; scaled to 610 x 40
SetPenSize(2, 1); SetSolidPenPat(1); SetForeColor(1); SetTextMode(4)
for i = 0 .. pages:
    x = i * 610 / pages + 10 - 1
    MoveTo(x, 115); Line(0, 39); Move(3, -30)                 ; page boundary, 2 pixels wide
    if i < pages: DrawString(Int2Dec(i + 1, 2 characters))   ; page number at (x + 3, 124)
SetForeColor(0)
```

#### Print (MAINE $DDFC)

```
UpdateAll; PrJobDialog(print record); cancelled: MAINE $B69B, return
UpdateAll; PrSetDocName("SuperConvert banner")
rowBytes = H / 2 + 1 (+ 1 more when H is odd)              ; strip row: one nibble per banner line
size = pageLen * rowBytes; more than 65535: error $FF02 ("Picture too large")
strip = NewHandle(size, locked, fixed, no bank cross); error: alert
SetColorEntry(table 0, entries 2, 6, 10, 14, $0888)         ; colour 2 becomes grey
strip LocInfo (MAINE $DDE6): portSCB $80, width rowBytes, bounds 0,0,pageLen,2H
port = PrOpenDoc(print record, nil)
grey: fill = $AA (colour 2) else fill = $00 (black)
col = 0
for page = 0 .. pages - 1:
    for r = 0 .. pageLen - 1 (banner column col, col++):
        for j = 0 .. H - 1:                                    ; banner row H-1-j
            pixel = banner pixel (col, H - 1 - j)
            nibble j of strip row r = (pixel <> 0 ? $F : fill nibble)   ; white or ink
    PrOpenPage(port, frame 0,0,pageLen,2H); SetPort(port)
    PPToPort(strip LocInfo, 0,0,pageLen,2H, 0, 0, copy)
    PrClosePage
PrCloseDoc; PrError; no error: PrPicFile(print record, nil, nil, status MAINE $B4C4)
MAINE $B69B (clean-up: master SCB $80, standard colour table)
error: alert X = $20 ("printing this document.")
```

The banner is turned a quarter turn: each strip row is one banner column, with the banner's bottom
line at the left edge of the paper, and each banner pixel becomes one nibble (two 640-mode pixels).
Each page prints pageLen rows of 2H pixels at the top left of the page. The help page M8BANNER asks
for "No gaps between pages" in the page set-up dialog and no landscape or draft printing.

### 5.4 Revert to normal desktop (LONGCODE $E997 [RevertDesk])

```
h = NewHandle(40, locked + fixed); fill with $DD; word at +6 = 0   ; a pattern message: 32 bytes $DD
MessageCenter(addMessage 1, type 2, h); DisposeHandle(h)
Desktop(8 = CheckForNewDeskMsg, 0)
MessageCenter(deleteMessage 3, type 2, nil)          ; remove the message, freeing its memory
NewDeskMsg (4.2); DisableMItem($0127)
```

The item starts disabled and is enabled by CheckDesk (4.2) whenever some desktop message exists
(from Use as desktop background, a desktop INIT or another program).

### 5.5 System info report... (DYNAMINFO $0191)

#### Window (DYNAMINFO $0008, NewWindow2 from memory)

Alert frame ($2020: alert, visible), no title, position 25,10,185,630, content draw OSAYCANYOU
$7350 [GenericRedraw], control list DYNAMINFO $0153:

| ID | Control | Rect | Title / key |
|---|---|---|---|
| 1 | simple button, round | 142,50,155,150 | "Cancel"; Escape |
| 2 | simple button, round | 142,230,155,390 | "Save as text file"; Apple-S / Apple-s |
| 3 | simple button, round | 142,470,155,570 | "Print"; Apple-P / Apple-p |
| - | TextEdit control (template DYNAMINFO $0058, created with NewControl2) | 5,10,136,610 | ID 0; text flags $40800000 (single format, draw bounds); default vertical scroll bar; max 65000 characters |

TextEdit starting text (DYNAMINFO $009C, LETextBox2 format, 39 bytes): font code Shaston ($FFFE)
style $02 size 16, "SuperConvert  System Info:" CR, then font code Shaston plain size 8.

#### Building the report

```
WaitCursor; MAINE $4217 (discard image; the image buffer is used as text buffer, DP $14)
open window; create the TextEdit control
TESetSelection(13, 13); TEInsert(C string MAINE $0094 = "4.0")   ; "SuperConvert 4.0 System Info:"
TESetSelection(end); TEStyleChange($22, Shaston plain 8, black on white)
append each section to the buffer, TEInsert it (text block), then the next section
TEScroll to the top; InitCursor
TaskMaster loop until a control is hit: 1 Cancel, 2 Save, 3 Print; any of them then closes the window
```

Sections (each one paragraph; "nK" = value / 1024 truncated + "K"; numbers decimal without
leading spaces):

1. `MEMORY USAGE:  TotalMem=nK, FreeMem=nK, RealFreeMem=nK, MaxBlock=nK, ` + handle count +
   ` handles.  By ID range (ID=norm/purgeable): ` + for each user ID type t ($0-$F, top 4 bits of
   the ID) with a non-zero total: `$txxx=nK/nK`, items separated by ", ". The handles are walked
   from the Memory Manager's list ($E1:1600, next at +$10); the size at +8 is added to "purgeable"
   when the attribute bits $0300 are set, else to "norm"; every handle is counted. The distinct
   owner IDs are collected (at buffer + $8000) and sorted.
2. `LOAD FILES IN MEMORY:  ` + for each owner ID and file number 1, 2, ... while the Loader's
   GetPathname2 ($2211) succeeds: `$iiii name` (4 hex digits, a space, the last pathname component,
   or "(unnamed)"), separated by ", ".
3. `STARTED TOOLSETS:  ` + for tool sets $01-$7E whose Status function ($06tt) answers non-zero:
   `$tt vM.m` (version from $04tt: "v", major (bits 8-14), ".", minor (bits 0-7), and character
   $A7 when bit 15 = prerelease), separated by ", ".
4. `MISCELLANEOUS:  GS/OS vM.m, ROM ID $xxxx & features $xxxx,  key translation n` (GS/OS
   GetVersion; FWEntry($FE1F) first and third result words; Event Manager GetKeyTranslation). With
   a TransWarp GS (the bytes "TWGS" at $BC:FF00) it continues `.  TWGS: vM.m, features $xxxx,
   speed n KHz, config $xxxx` (calls into $BC:FF08 (version in X, features in A), $BC:FF20,
   $BC:FF3C).
5. `BATTERY RAM (non-255 values):  ` + for parameters $00-$FB whose ReadBParam value is not 255:
   `$pp=n`, separated by ", ". (No CR after this section.)

Sections 1-4 end with CR.

#### Save as text file (DYNAMINFO $0BD3)

TEGetText into the buffer; re-wrap: going through the text, a space more than 76 characters after
the last line start becomes a line break (CR) at the last earlier single space of that line (or at
itself); double spaces are not break points; every $A7 becomes "B". SFPutFile2 at (160, 50),
prompt "Name to save as:", default name "SysInfoReport". Destroy the old file (error $46 ignored),
Create type $04 (TXT), aux $0000, open, write (MAINE $4C57), close; errors: alert X = 4 ("creating
the file:") or X = 8 ("writing to the file:").

#### Print (DYNAMINFO $0A44)

PrStlDialog, PrJobDialog, UpdateAll, PrSetDocName("SuperConvert SysInfo Report"), PrOpenDoc,
PrOpenPage; the page rectangle (print record rPage) inset by 40 horizontally and 18 vertically;
TEPaintText(printer port, line 0, that rectangle, 0, the TextEdit record); PrClosePage,
PrCloseDoc, PrPicFile; errors: alert X = $20. Only one page is printed (the result of TEPaintText,
the next line, is not used).

## 6. Shared helpers used above

- MAINE $C95F(A = SCB, X = bytes per line): OpenPort on the GrafPort MAINE $C851 whose pixel image
  is the screen image buffer (MAINE $00E4): portSCB = A, width = X, port rect 0,0, min(65535 / X,
  400), X x 2 (320 mode) or X x 4 (640 mode); ClipRect and visRgn to it. SetBufDims(X, 20, 40) when
  X >= 320. MAINE $C9EE: SetPort(menu bar port), ClosePort. These ports draw straight into the
  image buffer, which is why the commands discard the current image first (MAINE $4217).
- MAINE $4E16(A = SCB, X = bytes, Y = lines): set the screen image size; MAINE $4CE5: all 400 SCBs
  $80 and palette 0 = $000 $F00 $0F0 $FFF repeated; MAINE $4CDD: the same with $000 $F00 $0F0 $FFF
  $000 $00F $FF0 $FFF (standard 640) ; MAINE $4CED: SCBs $00 and a 16-step grey palette.
- MAINE $4271: show a new screen image (title, full-screen view unless the preference says no).
- MAINE $278F / $27AA: busy on (WaitCursor, heartbeat task) / off (InitPalette, InitCursor).
- LONGCODE $EBE3 [MakeFName](font ID, buffer): family name (GetFamInfo) + style words + " " +
  size + " ".
- Error alert MAINE $47F4 with X = message number: superconvert-file.md 2.3.

## 7. Compared with GS Remap

- Edit: GS Remap's Paste loads the clipboard as a true color image; in the original Paste is always
  dimmed for its own windows, and Copy/Cut need a screen image. The original also adds a palette
  scrap (type $8002) and warns about mixed modes or several palettes.
- Store palette: GS Remap uses the same 320 / 640 4-colour / 640 dither rule (first 4 colours equal
  to the next 4).
- System info report: GS Remap shows a short Mac-specific summary; the original builds the five
  sections above in a TextEdit window with Save and Print.
- Available font list: GS Remap pages 28 font families per page with names "Fonts n"; the
  original lists every family/style/size, sorted by size, page height 400 lines, names
  "FontList00", "FontList01", ...
- Print banner, Oscilloscope Art and View interlaced on VOC are not available in GS Remap.

## 8. Uncertain points

- Video Overlay tool set control numbers: $12 is taken to switch the card between following the
  computer's graphics bus (0) and keeping its own picture (1), from how the code saves and restores
  bank $E0 around it; $C8, $CB and $C9 ($30) together switch interlace on, but their individual
  names and meanings were not confirmed. Feature numbers $12 and $13 tested at start-up are
  probably the graphics-bus and dual-output features.
- DoModalWindow flag $0008 (About) and ReAllocHandle attributes $4000 (help) are given as stored;
  their bit meanings were not checked.
- Static text flag $0003 in the help text controls is taken to switch on the *n text substitution
  (the code sets a parameter array with SetCtlParamPtr before drawing); the exact flag bits were not
  checked. The colour words in the substitution strings (*1 background $0003, *3 background
  $0002) are as stored.
- FindFontStats is called with font ID $00FF0000 and flags $001E; that this enumerates all
  installed fonts follows from the loop, the flag meanings were not checked.
- The sort routine at segment 2 $9F2C is taken to be an ascending qsort from its parameters; the
  resulting order (size first, then family name) follows from the compare routine MAINE $CCB6.
- In the oscilloscope conversion the half-nibble colour order for 640-mode lines differs from the
  hardware order (4.3); whether that was intended is unknown.
- FWEntry($FE1F) result words printed as "ROM ID" and "features" are the first and third words
  pulled from the stack; which registers they are was not checked.
- Help window: whether the right scroll bar lies inside or outside wPosition was not checked; the
  layout above uses content coordinates (text from 6 to 602).
- The Font key chart default font ID $10000000 (family $0000) is as stored; what family $0000
  resolves to on a real system was not checked.
- None of the windows in this document were checked against a screen dump of the running program;
  all positions come from the templates and the drawing code.
