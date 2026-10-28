# SuperConvert 4: File menu

How the original SuperConvert 4.0 handles every command of the File menu, read from the program's
data fork (OMF load file) and checked against its data. It completes `superconvert-ui-data.md`
(menus, load and save records, data fork dialog templates), `superconvert-image-window.md` and
`superconvert-truecolor.md`; things already given there are referenced, not repeated.

Conventions are those of `superconvert-ui-data.md`: $ = hexadecimal, rectangles are
[top, left, bottom, right] (bottom/right exclusive), coordinates are 640-mode pixels, addresses are
segment name/number plus segment offset (MAINE = 5, FRED = 6, LONGCODE = 8, OSAYCANYOU = 9,
DYNAMDESK = 25, DYNAMTIFF = 26, segment 11 is "png", segment 2 is the unnamed first code
segment). "Item" means a Dialog Manager item, "control" a Control Manager control. Bracketed names
such as [DoLoadNext] are routine names embedded in the program. Things that could not be
confirmed are marked **(unconfirmed)** and listed in section 11.

## Contents

- 1. Entry points
- 2. Shared machinery (paths, busy state, error alert)
- 3. Load & convert..., Load next, Cancel remaining files, Re-convert last file
- 4. Save conversion...
- 5. Exchange load/save paths
- 6. Printing
- 7. Examine file...
- 8. Quit
- 9. Automatic save / print / load next
- 10. Corrections to the other documents
- 11. Uncertain points

## 1. Entry points

Menu dispatch is MAINE $0FC7, table MAINE $101A (4 bytes per item from item $00FA; a 2-byte
pointer is a JSR into MAINE, a 3-byte one a JSL). After the routine returns, HiliteMenu(0).

| Item | Text | Key | Code |
|---|---|---|---|
| $0101 | Load & convert... | Apple-L | MAINE $4302 |
| $0114 | Re-convert last file | Apple-R | MAINE $45F6 |
| $0117 | Load next | Apple-N | LONGCODE $E1F0 [DoLoadNext] |
| $010C | Cancel remaining files | Apple-D | LONGCODE $DE40 [CancelAll] (= BRL to [DisableNext] $DE4F) |
| $0102 | Save conversion... | Apple-S | MAINE $9527 |
| $0124 | Exchange load/save paths | | MAINE $4C98 |
| $010F | Print (normal)... | | MAINE $B7CC |
| $0119 | Print (enhanced)... | Apple-P | MAINE $B807 |
| $0125 | Print alignment page... | | MAINE $C4E4 |
| $011E | Print (?????)... | | MAINE $C383 (ImageWriter LQ driver, see 6.7) |
| $0110 | Examine file... | | segment 2 $59E0 |
| $0103 | Quit | Apple-Q | MAINE $1152 |

Item enabling: $0114 is enabled by the first load (MAINE $4564 / $433E) and never disabled again.
$0117 and $010C are enabled and disabled together by the load queue (3.6). $0102, $010F, $0119,
$011A, $011E (list MAINE $4244) are disabled by MAINE $4217 when the image is discarded at the start
of a load and enabled by MAINE $42F0 when an image is shown. $0125, $0124, $0110, $0101, $0103 are
always enabled.

## 2. Shared machinery

### 2.1 Load path and save path

Two handles hold GS/OS class-1 path strings: the load path (MAINE $3F55/$3F57) and the save path
(MAINE $3F59/$3F5B). Before a file dialog FRED $981E [RecallPfx8] sets prefix 8 to the stored
path (GS/OS SetPrefix); after the dialog FRED $9880 [StorePfx8] reads prefix 8 back into the
handle (GetPrefix, SetHandleSize). So the load dialog always opens in the folder of the last load,
the save dialogs in the folder of the last save. A failure of StorePfx8 after the load dialog gives
a SysBeep. After every file dialog FRED $97A3 [FlushNsert] runs (only with the "Disk insertion
starts load" preference and Window Manager 3.3+: HandleDiskInsert($C800) until it returns 0).

### 2.2 Busy state

MAINE $278F: WaitCursor (QDAux $0A12) and SetHeartBeat(MAINE $27C8) (a heartbeat task that
animates the wait cursor). MAINE $27AA: DelHeartBeat, InitPalette, InitCursor.
MAINE $2751/$277F: Apple-period check (GetNextEvent mask $0408; key '.' with the Apple bit $0100
returns A = $FFFF, carry set). Loaders and savers poll it; $FFFF means "cancelled, no alert".
FRED $97DF [UpdateAll]: up to five TaskMaster calls with mask $0040 (update events only) so
windows are redrawn between dialogs.

### 2.3 Error alert ("I am having a hard time ...")

StopAlert with template OSAYCANYOU $0F70 (file $53C9B): rect [70,20,135,620], ID $DEAD, stages
$83 $83 $83 $83. Items:

| Item | Type | Rect | Text |
|---|---|---|---|
| 3 | static text, disabled | 4,80,14,550 | "I am having a hard time ^0 " |
| 4 | static text (9:0FC6) or long static text (9:0FE2), disabled | 17,80,27,595 | "^1 " / the full pathname |
| 5 | static text, disabled | 30,80,40,595 | "Error code is $^2: ^3." |
| 1 | button | 45,250,57,350 | "Continue" |

Entry points (A = error code, X = 4 × message number):

- MAINE $47F4: ^1 = "" (a Pascal string of one space, MAINE $481B).
- MAINE $481D: ^1 = the loaded file name (MAINE $3F61).
- MAINE $484F: item 4 is the long static text variant; its text pointer and length (9:0FEE, 9:0FF2)
  were set by the caller to the full pathname.
- MAINE $4900 (load errors): if "Re-convert last file" is enabled, the full pathname
  ($3F5D handle) through the long variant, else $481D.

A = $FFFF shows nothing. ^2 is Int2Hex(A, 4 digits). ^3 is looked up in OSAYCANYOU $1227
(word code, word pointer; end $FFFF). ^0 is from OSAYCANYOU $104A:

| X | ^0 | X | ^0 |
|---|---|---|---|
| $00 | reading from the file: | $20 | printing this document. |
| $04 | creating the file: | $24 | pasting from the Clipboard. |
| $08 | writing to the file: | $28 | trying to process this image. |
| $0C | converting the file: | $2C | trying to display a font. |
| $10 | renaming the file: | $30 | attempting to load & display the help file. |
| $14 | trying to digitize. | $34 | attempting to save this image. |
| $18 | viewing this file. | $38 | appending to the file: |
| $1C | formatting the disk in device: | $3C | cutting/copying to the Clipboard. |

Messages (^3): $27 I/O error!; $2B Disk is write-protected; $2E Disk switched; $2F Disk is not
online; $40 Invalid pathname syntax; $44/$45/$46 File not found; $47 Duplicate pathname; $48 Disk is
full; $49 Volume directory full; $4C/$4D Unexpected end of file; $4E File is locked; $51/$5A Disk
directory has been damaged!; $57 Duplicate volume names; $5B Cannot rename onto a different disk;
$0201 Memory full; $1302 Selected printer port not active; $1304/$1305 Incompatible LaserPrep
version; $1306/$1307 AppleTalk communication failure; $1B0C Unable to scale font to requested size;
$1E02 File does not have a valid resource fork; $B0B0 This format has not been implemented yet;
$BA1A Missing GIF terminator; $FF00 File is damaged or not of the selected type; $FF01 Resolution
too high to convert; $FF02 Picture too large; $FF03 Font appears to be damaged; $FF04 Cannot handle
this variation on the selected type; $FF05 This format requires specific filename endings; $FF06
File did not contain any convertable picture; $FF07 Image is much too large to save in this format;
$FF08 Append would make file too long;start a new one; $FF09 Unable to locate the color palette;
$FF0A The Clipboard does not contain a picture; $FF0B Unknown resource name format; anything else
"(error description not available)". (Spellings as in the program.)

## 3. Load & convert...

### 3.1 Flow (MAINE $4302)

1. MAINE $2707: NextMember on the specific type list (MAINE $20BB); none selected = return.
   The format record pointer is kept in MAINE $3F51.
2. Loader field bytes +25/+26 zero (no loader): error alert A = $B0B0, X = $0C ("I am having a hard
   time converting the file: ... This format has not been implemented yet."). No file dialog.
3. RecallPfx8(load path).
4. Babelfish formats (+6 = $FFFE or $FFFD): enable $0114, busy, discard image (MAINE $4217),
   FRED $D79A / $D4E5 (Babelfish's own file handling), then as step 10.
5. Clear $3F4B ("load all in folders") and $3F43 ("any type"). Both check boxes therefore start
   unchecked every time.
6. SFPMultiGet2 (see 3.2). StorePfx8(load path) (SysBeep on failure), FlushNsert.
7. Count of chosen entries (reply MAINE $3F83) = 0: return.
8. One entry (MAINE $446D):
   - a folder ($0F) with "Load all pictures within selected folders" unchecked: SetPrefix 8 to it
     and open the dialog again inside it (back to step 5);
   - a folder with the box checked: treated as "several" (step 9);
   - a file: FRED $990C [ExpandFull] makes the full path in handle $3F5D (failure: alert X = $0C),
     then 3.5.
9. Several entries (MAINE $43F2): WaitCursor, every entry goes to LONGCODE $DFB9 [AddMulti]
   (3.6), the name list is disposed, then PostEvent(keyDown, 'N', Apple) so the first file loads as
   if Apple-N had been typed; InitCursor.
10. After a load see 3.7.

### 3.2 File dialog

SFPMultiGet2 (Standard File $1517), parameters as pushed (MAINE $4399):

| Parameter | Value |
|---|---|
| whereX, whereY | 120, 40 |
| long after whereY | 0 |
| prompt | Pascal string, OSAYCANYOU $0F4C: "Select file(s) to load and convert:" |
| filter procedure | MAINE $4610 (3.4) |
| type list | none |
| dialog template | segment 2 $144A (file $01C9A) |
| dialog hook | MAINE $4779 |
| reply | MAINE $3F83 (count word, names handle $3F85) |

Template 2:144A: rect [0,0,138,400], visible, refCon 0. Items:

| ID | Type | Rect | Text |
|---|---|---|---|
| 1 | button | 61,265,73,375 | Open |
| 2 | button | 79,265,91,375 | Close |
| 3 | button | 25,265,37,375 | Volumes |
| 4 | button | 97,265,109,375 | Cancel |
| 5 | button | 43,265,55,375 | Accept |
| 6 | user item (path) | 12,15,24,395 | |
| 7 | user item, disabled (file list) | 25,18,107,215 | |
| 8 | static text, disabled (prompt) | 3,15,12,395 | |
| 16 | check box | 113,15 (auto size) | Load all pictures within selected folders |
| 17 | check box | 125,15 (auto size) | Allow files to be selected regardless of type |

Items 1-8 are the standard SFMultiGet layout (drawn by Standard File in the system font);
16 and 17 are SuperConvert's. Both boxes have value 0 in the template.

### 3.3 Dialog hook (MAINE $4779)

Called with the item hit. For items 16 and 17: value := 1 - GetDItemValue, SetDItemValue, store
in $3F4B (item 16) or $3F43 (item 17); for item 17 also SFReScan (the list is filtered again at
once). The item hit is then set to 0 so Standard File ignores it. Other items pass through.

### 3.4 File filter (MAINE $4610)

Result 0 = not shown, 1 = shown dimmed, 2 = selectable. Uses the GetDirEntry record fields
fileType (+$10), eof (+$12, long) and auxType (+$2C; for single types only its low word).

```
result = 1                                 ; $3F4F would make it 0, but nothing ever sets $3F4F
if anyType ($3F43): return 2
rec = selected format record
if rec.types (+6 word) == $FFFF: list path below
if fileType == rec.typeA or fileType == rec.typeB: goto check
if fileType == $0F: return 2               ; folders always selectable
if fileType == $00 and rec.types is $0406 or $0604: goto check   ; typeless files for "$04 or $06" formats
return 1
check:
  if eof < rec.eofMin (+12) or eof > rec.eofMax (+16): return 1   ; full 32-bit compares
  if aux.lo < rec.auxMin (+20) or aux.lo > rec.auxMax (+22): return 1
  return 2
list path (rec +20 = pointer to 18-byte entries, end $FFFF):
  if fileType == $0F: return 2
  for each entry e with e.type == fileType:
     aux.hi >= e.auxMin.hi and aux.lo >= e.auxMin.lo and
     aux.hi <= e.auxMax.hi and aux.lo <= e.auxMax.lo and
     eof.hi >= e.eofMin.hi and eof.lo >= e.eofMin.lo and
     eof.hi <= e.eofMax.hi and eof.lo <= e.eofMax.lo   -> return 2
  return 1
```

Note the list path compares the high and low words separately (not as 32-bit numbers). For
example with eofMin $1 a file whose EOF is exactly $10000 or $20000 is rejected (low word 0), and
with eofMin $8 files of EOF $10000-$10007 are rejected. To behave the same this quirk must be
copied. The Babelfish formats ($FEFF/$FDFF) never reach the filter. The Macintosh type (+8) is
not used.

### 3.5 Loading one file (MAINE $44F3, also Re-convert and Load next)

1. Lock handle $3F5D; copy the last path component (after the last ':') to MAINE $3F61 as a
   Pascal string of at most 31 characters; a longer name is cut to 31 with the last character
   replaced by '…' ($C9).
2. Enable $0114 Re-convert last file.
3. Busy (2.2). Clear the SCB table MAINE $02FA (400 bytes).
4. MAINE $4217 discards the current image: purge Remap and monochrome data, HideWindow(image
   window), FRED $A0A6 [ExitPals], hide the "Save..." button, disable the items of 2 (list $4244),
   disable menus 5, 9, 6 (Screen, True color, Monochrome), $052C = 0, selection flag $E180 = 0.
5. UpdateAll; call the loader of the (still) selected format (2-byte = JSR, 3-byte = JSL).
6. Carry clear: success (3.7). Carry set with A = $FFFF: close the file (MAINE $4B3F), end busy,
   nothing shown. Other errors: close, end busy, purge Remap/mono, error alert X = 0
   ("reading from the file:").

So "Load next" and "Re-convert" use the format selected in the Load formats window at that moment,
not the one used originally.

### 3.6 The load queue (LONGCODE $DC69-$E2D4)

- Queue handle LONGCODE $DC03 (created by [InitMulti] at start-up). Each entry is a GS/OS result
  buffer: buffer size word, length word, full pathname.
- [AddMulti] $DFB9 (name, fileType):
  - folder and $3F4B clear: ignored;
  - folder and $3F4B set: GetPrefix(8) saved, prefix 8 := the folder, Open "8:" and GetDirEntry
    through all entries; each entry the filter (3.4) rates 2 is added recursively as "8:name"
    (so sub-folders are entered too, depth first); Close; prefix 8 restored;
  - file: ExpandPath to a full path and append it. If the queue was empty, [EnableNext] $DDFD:
    hide the "Load..." button (MAINE $2053), show "Load next" ($2061), EnableMItem $0117 and
    $010C.
- [DoLoadNext] $E1F0 (Apple-N, the "Load next" button):
  - if an automatic save or print is still pending ($00C6 or $00C8): set $00CA (load next later)
    and return;
  - otherwise copy the first entry into $3F5D, [RemoveName] it and load through MAINE $44F3
    (3.5). A memory error gives SysBeep.
- [RemoveName] $DF03: when fewer than 5 bytes would remain, [DisableNext] instead.
- [DisableNext] $DE4F (also "Cancel remaining files"): set the queue size to 0, hide "Load next",
  show "Load...", DisableMItem $0117 and $010C. No confirmation.
- Files passed by the Finder at start-up (MessageCenter message 1) are queued by [InitMulti] the
  same way (the computer type list member and the specific type are selected first), followed by
  an Apple-N event.

Between files nothing special is shown: each file is loaded and displayed as in 3.7, and the next
one waits for Apple-N / the "Load next" button, unless "Automatically load next picture after
saving" is on (9).

### 3.7 After a successful load (MAINE $45D4)

End busy. Then:

| Image made | Preferences | Result |
|---|---|---|
| no true color image ($052E = 0) | "Automatically show Remap dialog after loading screen images" ($00C2) on | MAINE $4271 (show), then Convert to screen (Remap) (MAINE $1141) |
| no true color image | that preference off | MAINE $4271 |
| true color image | "Don't automatically show Remap dialog for true color images" ($00C0) on | MAINE $4271 |
| true color image | that preference off | MAINE $428C (show without full screen), then Remap |

MAINE $4271 builds the title (MAINE $4991); if a screen image exists and "Don't automatically view
screen images after loading" ($00BE) is off, View full screen (MAINE $120C) runs first; then the
window is shown (MAINE $428F: show "Save...", enable menus 5, 9, 6, NewImgType, origin 0,0,
ShowWindow, SelectWindow, enable the items of section 1). Remap errors give alert X = $28.

### 3.8 Re-convert last file (MAINE $45F6)

Selected format with no loader: alert $B0B0 / $0C. Otherwise BRL MAINE $44F3 with the path still
in $3F5D (no dialog).

## 4. Save conversion...

### 4.1 Order of events (MAINE $9527)

1. Selected save record (MAINE $272C; list MAINE $2116) into $983B. None: return.
2. Image preparation: if the record can take true color (+5 bit 1) and a true color image exists,
   nothing. Otherwise, without a screen image: a monochrome-only image goes through FRED $C568
   [Mono2Scrn] (its window, `superconvert-truecolor.md` 8); a true color image through Remap
   (LONGCODE $9F28, its dialog; failure alert X = $28) and is then shown (MAINE $4271).
3. Default name (4.2). Babelfish exports branch off here (FRED $D19D / $D2EF, Babelfish's own
   dialog).
4. FRED $A3E1 [DoSaveType]: makes the image type the format needs, possibly through the choice
   window (4.10). Carry = cancel.
5. Size and clipping (4.3), size dialog (4.3), size limit (4.4), alignment dialog (4.5), format
   warnings (4.6).
6. Options routine of the record (+22, JSL; MAINE $9982 does nothing; Hex data: MAINE $A64A, 4.9).
   Carry = cancel.
7. RecallPfx8(save path). New file: 4.7. Adding to a file: 4.8.

### 4.2 Default name and suffix

The loaded file name ($3F61, at most 31 characters) is copied to MAINE $9498 (word length, text).
The routine looks for '.' among the last six characters (from the end backwards); if found, the
suffix starts there, otherwise at the end. That position is limited to 27 (1-based index of the
dot at most 27) and the record's 4-byte suffix (+8, e.g. ".PNT") is written there; the length
becomes position + 3. Examples: "PICTURE.PIC" with ".SHR" gives "PICTURE.SHR"; "SUNSET" gives
"SUNSET.SHR"; "A.LONGER" (dot 7 from the end) gives "A.LONGER.SHR". A save record whose suffix is
"PNG" (".PNG") sets $9482 = 0: the PNG saver opens the file itself; all others have the file
opened for them.

### 4.3 Size of the saved picture

Original size: with no selection ($E180 = 0) width = $00E8 bytes per line, height = $00EE lines,
offset 0,0, and item 2 of the size dialog reads "Same as original" (9:178F). With a selection
(MAINE $E196-$E19C, `superconvert-image-window.md`) width = (right-left)/4 bytes, height =
bottom-top, offsets left/4 and top, and item 2 reads "Same as clipping" (9:17A0).

"Select size" dialog, GetNewModalDialog(9:1725), rect [30,50,170,400]:

| Item | Rect | Text | Size (bytes x lines) |
|---|---|---|---|
| 7 static text, disabled | 5,10,15,340 | Select size of saved picture: | |
| 2 | 20,10,35,340 | Same as original / Same as clipping | original |
| 3 | 40,10,55,340 | One screen wide, one screen (200) high | 160 x 200 |
| 4 | 60,10,75,340 | One screen wide, one page (396) high | 160 x 396 |
| 5 | 80,10,95,340 | One screen wide, two screens (400) high | 160 x 400 |
| 6 | 100,10,115,340 | Two screens wide, one screen (200) high | 320 x 200 |
| 1 | 120,100,135,250 | Cancel save | |

All buttons are plain round Dialog Manager buttons. For items 2-6, a clear bit in record +20
(bit 0 = item 2) dims the item (HiliteControl 255); a set bit in +21 makes it the default button
(SetDefButton; without one, item 1 "Cancel save" stays the default). ModalDialog without filter.
Item 1 cancels. Sizes are in MAINE $9284 (widths) and $9292 (heights), indexed by item number.
Note the dialog is shown for every format, also when only one button is enabled.

### 4.4 Size limit

If record +18 bit 12 is set and the original width in bytes > +32 or original height > +34: error
alert A = $FF07, X = $34 ("I am having a hard time attempting to save this image." / "Image is
much too large to save in this format"). It tests the original (or clipping) size, not the chosen
size.

### 4.5 Alignment dialog (MAINE $9A5D)

Skipped when the chosen size equals the original. Otherwise GetNewModalDialog(9:19AF), rect
[28,135,173,505], with "centered" (item 1, [55,130,85,240], default), "Cancel save" (item 2,
[125,20,140,170]) and "Select alignment of saved area within picture:" (item 4, [5,10,15,360]).
Buttons are added with GetNewDItem:

| Width differs | Height differs | Added items |
|---|---|---|
| yes | no | 16 "center left" [55,10,85,120], 17 "center right" [55,250,85,360] |
| yes | yes | 16, 17, 48 "top left" [20,10,50,120], 49 "top right" [20,250,50,360], 50 "bottom left" [90,10,120,120], 51 "bottom right" [90,250,120,360], 32 "top center" [20,130,50,240], 33 "bottom center" [90,130,120,240] |
| no | yes | 32 "top center", 33 "bottom center" |

Result: horizontal offset 0 for items 48, 16, 50; original - new for 49, 17, 51; else
(original - new) / 2 (arithmetic). Vertical offset 0 for 48, 32, 49; original - new for 50, 33, 51;
else half. The new picture row r copies source row r + vOffset; rows outside the source repeat the
first or last source line's SCB (MAINE $9BF7), source bytes outside the width are left 0 (colour 0).

### 4.6 Format warnings (MAINE $9C9F)

Scans every output line's SCB (4.5 mapping); warning bits as in `superconvert-ui-data.md` 9.3.
Bit 3 compares palette words 0-3 with 4-7, 8-11, 12-15 of each 640-mode line's palette. Bit 4 is
clear only if there is no 320 line, palette 0 only, and palette 0 entries 0-7 equal $0000 $0F00
$00F0 $0FFF $0000 $000F $0FF0 $0FFF (MAINE $9E34). For each record +18 bit set whose condition
holds, the next ^n (^0-^3, default " ", OSAYCANYOU $1B77) gets its line. Any line: NoteAlert
9:18E3 (rect [40,100,120,540], ID $0BAD, stages $81):

| Item | Rect | Text |
|---|---|---|
| 4 long static text, disabled | 5,75,50,430 | "Can't save, the specified format cannot handle:" CR ^0 CR ^1 CR ^2 CR ^3 CR |
| 1 (default) | 60,300,75,420 | Cancel save |
| 3 | 60,20,75,260 | Save anyway, AT YOUR OWN RISK |

Item 3 continues, anything else cancels.

### 4.7 New file

SFPutFile2(whereX 160, whereY 50, prompt "Name to save as:" (9:16DA), default name 4.2, reply
MAINE $9484). StorePfx8(save path), FlushNsert; cancel = return. Then:

1. Destroy the path (errors other than $46 "file not found": alert X = 4 "creating the file:"
   with the full path). There is no own "replace?" question; SFPutFile2's own one applies.
2. Create (access $C3, file type record +6, aux type record +12, storage type 1); error X = 4.
3. Unless PNG: Open (read/write) (MAINE $9984).
4. Busy; JSR to the save routine (record +26).
5. Error: close, Destroy the new file, alert X = 8 ("writing to the file:") unless $FFFF.
6. Success: close; if the record has a Macintosh type (+14): GetFileInfo (pCount 7) then
   SetFileInfo (pCount 8) with an HFS option list (FST $0006) whose Finder info is type = the Mac
   type and creator 'GCon' (MAINE $94DD). End busy; if "Automatically load next picture after
   saving" ($00BC) is on, set $00CA (9).

### 4.8 Adding to an existing file (record +36 = 1)

SFGetFile2(whereX 120, whereY 50, prompt "Select file to add picture to:" (9:16EB), reply $9484):

- Finder icon (file type $CA): type list MAINE $983F: 2 entries, {flags $8000, type $CA, aux 0}
  and {flags $E000, type 0, aux 0}, i.e. icon files selectable, every other file shown dimmed
  **(flag meaning unconfirmed)**.
- Icon resource (file type 0): filter LONGCODE $F436 [RezFilter], no type list.

StorePfx8(save path), FlushNsert; cancel = return. Open, busy, save routine; on error close and
alert X = $38 ("appending to the file:"). On success close, end busy, the $00BC rule, and
SelectWindow(Load formats window).

### 4.9 Per-format dialogs and progress

**Finder icon (new file, MAINE $9EB5 / add, $9EBA).** GetNewModalDialog(9:2649), rect
[25,70,190,570], items:

| ID | Type | Rect | Text / default |
|---|---|---|---|
| 1 | button (default) | 147,380,160,480 | Save |
| 2 | button | 147,240,160,340 | Cancel |
| 3 | user control, disabled | 16,280,81,490 | small icon (template 9:26EC) |
| 4 | user item, disabled | 5,100,55,260 | the icon (MAINE $A27E: DrawIcon at the item box) |
| 5 | static text | 5,10,15,95 | This icon: |
| 6 | static text | 5,280,15,490 | Along with this small icon: |
| 7 | static text | 60,10,70,270 | Will be used for files matching |
| 8 | static text | 70,10,80,270 | the following selected criteria: |
| 9 | static text | 115,10,125,490 | When the icon is double-clicked or opened, the Finder will: |
| 16 | check box, value 1 | 85,10 | Filetype is: |
| 17 | check box, value 1 | 85,224 | Auxilliary type is: |
| 18 | check box, value 1 | 100,100 | Filename is: |
| 19 | check box, value 1 | 130,10 | Run the program: |
| 32 | edit line, max 5 | 83,132,96,180 | "$" + 2 hex digits of the loaded file's type ($3FBD) |
| 33 | edit line, max 5 | 83,400,96,460 | "$" + 4 hex digits of its aux type ($3FBF) |
| 34 | edit line, max 15 | 98,224,111,400 | loaded file name; 16+ characters: first 15 with the 15th replaced by '*' |
| 35 | edit line, max 63 | 128,160,141,490 | SuperConvert's own pathname (LGetPathname, file 1) |

Check boxes toggle. Save: for checked boxes the type and aux edit lines are parsed ("$" = hex
through Hex2Int, else Dec2Int); an empty or bad field gives SysBeep and its text selection is
flashed 31 times (SelectIText alternating), and the dialog continues. Unchecked "Filename is:"
writes "*", unchecked type/aux write 0, unchecked "Run the program:" writes an empty path. Cancel
returns $FFFF (no alert). The icon itself is the saved area (max 40 bytes x 50 lines, record
+32/+34). Appending checks the file: errors $FF04, $FF00, $FF08 (2.3).

**Icon resource (MAINE $A2CF).** ResourceStartUp, OpenResourceFile(read/write) on the chosen
file, SetResourceFileDepth(1), UniqueResourceID($FFFF, type $8001), LONGCODE $F095 [AskForName]
(dialog 9:2A0F, rect [50,100,115,400]: static text 32 "Name for resource (ID = ^0):"
[5,10,15,290], edit line 16 max 30 [17,10,30,290], OK [45,200,58,280], Cancel [45,100,58,180],
static text 33 "This name is already used, try another." [32,10,42,290]), then LONGCODE $F320
[MakeIcon]; ResourceShutDown. **(the duplicate-name logic of [AskForName] unconfirmed)**

**Hex data (options MAINE $A64A).** NewWindow2 from OSAYCANYOU $3769 (alert frame, movable,
position 40,110,120,530) with controls: OK [60,310,73,400] (default, Return), Cancel
[60,200,73,290] (Escape), edit lines "Start of line:" [15,10,28,130] default " dc h'", "Item
separator:" [15,150,28,270] default " ", "End of line:" [15,290,28,410] default "'" (max 20 each),
labels above at row 5 (x 10, 150, 290), and static text [35,12,53,1000] "Sample line of generated
output:" CR "*001*123*145*167*189*1AB*1CD*1EF*2" (*0, *1, *2 substitute the three fields).

**GIF (MAINE $A88D, file $1B0CA).** Runs after the Save dialog with the new file created and open
(4.7); there is no options routine. It allocates two locked, fixed handles, $2000 bytes (MAINE
$AE57, the colour table: one word per 12-bit colour) and $7542 bytes (MAINE $AE5B, the LZW table),
then counts the colours, writes the file up to the image data, shows the note and codes the image.

Colour count (MAINE $A924). Every word of the colour table is set to $7FFF. Each line of the saved
area ($92A8 bytes by $92AA lines as chosen in 4.3-4.5, made by MAINE $9BF7 with the alignment
applied, so bytes outside the picture are 0) is read pixel by pixel. Palette = the line's SCB AND
$F; entry = the pixel value in 320 mode (high nibble first), or 4k + value for pixel k of a byte in
640 mode (k = 0 leftmost), as for the TIFF palette image; 320 or 640 is decided once, for all
lines, by bit 7 of $00F2. The palette word (MAINE $00FA + 32 × palette + 2 × entry) indexes the
colour table, whose word is incremented unless it is $FFFF (MAINE $A9AE): a colour that occurs
holds $8000 + count - 1, saturating at 32768 pixels. Colours are counted by value, so palette
entries holding the same $0RGB are one colour. The palette word is used as it is here but ANDed
with $0FFF when coding; a word with any of bits 12-14 set would be counted outside the table.

Indices and classes (MAINE $A9C3). The largest word of the table is taken again and again (searched
from colour $000 up, a word ≥ the best so far replacing it, so among equal counts the higher $0RGB
comes first). While it has bit 15 set, its colour gets the next index, 0, 1, 2, ... (the index
replaces the count; index 0 is the most frequent colour), and is put in the first class whose test
holds, all three channels being tested at once:

| Class | Test (c = $0RGB) | Holds when every channel is | Counters incremented |
|---|---|---|---|
| 1 bit | t = c AND $0888; t = t OR t >> 1; t = t OR t >> 2; t = c | 0 or 15 | none |
| 2 bits | t = c AND $0CCC; t = t OR t >> 2; t = c | 0, 5, 10 or 15 | $AE6B |
| 3 bits | ((c AND $0888) >> 3 XOR c) AND $0111 = 0 | 0, 2, 4, 6, 9, 11, 13 or 15 (bit 0 = bit 3: a 3-bit value with its top bit repeated) | $AE6B, $AE6D |
| 4 bits | none of these | | $AE6B, $AE6D, $AE6F |

Results (MAINE $AA43), n being the number of colours (at most 256):

| Value | Rule |
|---|---|
| bits | the smallest of 1-8 with 2^bits >= n (table MAINE $AE75: 2, 4, 8, ..., 256) |
| ^0 | $92A8 × 2, or × 4 when $00F2 bit 7 is set: the saved area's width in pixels |
| ^1 | $92AA, its height in lines |
| ^2 | 2^bits, i.e. n rounded up to a power of two, at least 2 |
| ^3 and r | 4096 and 3 if $AE6F ≠ 0, else 512 and 2 if $AE6D ≠ 0, else 64 and 1 if $AE6B ≠ 0, else 8 and 0 |

r is the colour resolution of the screen descriptor (bits per channel - 1). The class of the widest
colour decides: black, red, green, blue, yellow and white (the 640-mode standard colours) give 8;
$000 $555 $AAA $FFF give 64; $000 $222 $DDD $FFF give 512, and so do $000 $555 $222 ($555 counts
as a 2-bit colour, $222 as a 3-bit one); a single colour such as $777, $123 or $F80 gives 4096. A
saved area of 160 x 200 bytes using $000 $0F0 $555 $AAA $FFF is announced as "320 x 200 x 8 / 64"
in 320 mode and "640 x 200 x 8 / 64" in 640 mode.

File, written before the note appears (MAINE $AA93-$AB6C; bytes go out through MAINE $4C16 and
$AD24):

| Bytes | Value |
|---|---|
| 6 | "GIF87a" |
| 2, 2 | screen width ^0, height ^1 |
| 1 | $80 (global colour table) + 16 × r + bits - 1 |
| 1 | background colour 0 (the most frequent colour) |
| 1 | 0 |
| 3 × 2^bits | global colour table: for each index the colour whose table word holds it, R, G, B, each 4-bit channel × $11; indices n to 2^bits - 1 are not found and give 0, 0, 0 |
| 10 | $2C, left 0, top 0, width ^0, height ^1, flags $40 (interlaced, no local table) + bits - 1 (the size field is filled in although there is no local table) |
| 1 | LZW minimum code size: bits, or 2 when bits = 1 |
| | data sub-blocks (below) and a zero byte |
| 1 | $3B |

No extension blocks are written.

Note (MAINE $AB6F). Each number is converted by MAINE $AE9F: Int2Dec(value, 6 characters,
unsigned) into a 6-byte buffer (MAINE $92D8, $92DE, $92E4, $92EA), then the leading spaces are
skipped and the length is stored over the last of them, making a Pascal string: plain decimal, no
padding, no separators. ParamText(^0, ^1, ^2, ^3); GetNewModalDialog(9:1C18), rect
[30,170,180,470], one item: ID 4, long static text, disabled, [5,10,125,290], 353 characters
(LETextBox2 codes as in TIFF):

| Part | Text |
|---|---|
| 1 | "If this file is to be uploaded to a computer service or BBS, please include the following data in its description:" CR CR |
| 2 | $01 "S" 1 (bold), $01 "J" 1 (centred), "^0 x ^1 x ^2 / ^3 " (with the final space) CR CR |
| 3 | $01 "J" 0 (left), $01 "S" 0 (plain), "This information (the picture's horizontal & vertical size, number of colors, and palette range) will help downloaders to estimate how well the file will turn out on their particular graphics hardware." |

DrawDialog, but no ModalDialog: the note stays up as the progress window. SetPort(dialog);
SetPenSize(2, 1); SetSolidPenPat(0); FrameRect [132,22,145,278] (OSAYCANYOU $1DD2, whose left and
right are reset to 22 and 278 first); SetForeColor(0); SetBackColor(3); MoveTo(50, 142) (point
MAINE $92D4); DrawString "GIF87a save in progress..." (OSAYCANYOU $170A); SetPenPat(32 bytes $66,
OSAYCANYOU $1DDA); SetPenMode($8003, notBIC: destination AND pattern).

Pixels (MAINE $AD38) are handed to the encoder row by row in interlaced order (MAINE $ADFD; steps
MAINE $AE8F 8, 8, 4, 2; next-pass starts $AE97 4, 2, 1): rows 0, 8, 16 and so on, then 4, 12, ...,
then 2, 6, 10, ..., then 1, 3, 5, ... Each pixel is found as in the count; its palette word AND
$0FFF looks up the colour table, and an index of 256 or more (a colour that was not counted)
executes BRK $BC. A pass starts at its first row without comparing it with the height, so areas
of 2, 3 or 4 lines go out as rows 0, 4 / 0, 4, 2 / 0, 4, 2, 1 instead of 0, 1 / 0, 2, 1 /
0, 2, 1, 3. A reader places them in the correct order's positions, so the rows are mixed up and
row 4 (which MAINE $9BF7 takes from below the saved area, or makes of zero bytes) appears in place
of a real one; if it holds a colour that was not counted, BRK $BC follows.

Before each row MAINE $ADFD advances the bar: with k = rows already handed over, FixRatio(k, $92AA),
right = 22 + the high byte of the fraction (256k / height, truncated), PaintRect [132, previous
right, 145, right]. In notBIC with the $66 pattern black stays black and white (3) becomes 1 and 2
in alternate pixels (red and yellow with the standard 640-mode colours: an orange bar), so frame
and text stay visible. The call after the last row has k = height, a fraction of 0 and an empty
rectangle, so the bar stops at 22 + 256 × (height - 1) / height (276 for 200 lines).

LZW (MAINE $B2C4, file $1BB01), in the style of Unix compress:

```
if bits = 1: bits = 2                       ; 0 or above 9: return $C0DE (cannot happen)
put byte(bits)                              ; minimum code size
clear = 2^bits; end = clear + 1             ; MAINE $B20E
width = bits + 1; limit = 2^width; next = clear + 2
empty the table; output(clear)
ent = pixel(); if none: output(end), finish
loop
    c = pixel(); if none: output(ent), output(end), finish
    if (ent, c) is in the table: ent = its code; continue
    output(ent)
    k = next
    if next <= 4095: enter (ent, c) as code next; next = next + 1
    if k = limit:
        if width < 12: width = width + 1; limit = 2 * limit
        else: output(clear)                 ; with 12 bits
              width = bits + 1; limit = 2^width; next = clear + 2; empty the table
    ent = c
finish: if the buffer holds bits, one sub-block of (bit count + 7) div 8 bytes; put byte(0)
```

The width therefore grows right after code 2^width has been entered, and the code output after
code 4095 has been entered is followed by a 12-bit Clear code: the usual GIF practice, without
deferred clearing. Only the end code differs: it is written with the current width, while a decoder
that enters code 2^w - 1 after the last data code reads it with w + 1 bits. The missing top bit is
a padding zero of the last byte, or lies after the data when the end code ends a byte; all pixels
are decoded before it, and decoders read such files correctly (checked with files made by a
transcription of the encoder).

output (MAINE $B259) packs codes least significant bit first into the buffer MAINE $AF0E. Before a
code is packed, when 253 or more whole bytes are waiting they go out as one sub-block (the length
byte through MAINE $AD24, the bytes through MAINE $4C57) and the partial byte moves to the front.
Sub-blocks therefore hold 253 or 254 bytes, the last one 1 to 255.

The table has 5003 ($138B) slots in three word arrays of the second handle: prefix (+$0000), code
(+$2716, 0 = free; only this array is cleared), pixel (+$4E2C). The first slot is ((c << 5) XOR
ent) mod 5003; collisions move on by 1, 3, 5 and so on. The reduction of this probe modulo 5003
(MAINE $B405-$B41D) is never applied: the reduced value is left in A and the loop reloads the
unreduced index (the reduction also compares with the word at absolute address $138B instead of
the constant). A probe passing slot 5002 therefore runs on beyond the arrays: code[i] then overlaps
the pixel array, prefix[i] the code array, and pixel[i] lies past the end of the handle. First
slots above 4095 need c ≥ 128, so in practice this concerns pictures with more than 128 colours;
with a transcription of the routine the codes stayed correct on test pictures, but memory after
the handle was written.

End (MAINE $ACA0): put byte($3B); close the file (MAINE $4B3F); busy off (MAINE $27AA);
GetNewDItem(OSAYCANYOU $1DA7): button item 1 "GIF save completed" [132,16,145,284], over the bar;
ModalDialog (no filter) until an item is hit; CloseDialog; both handles disposed of; carry clear.
4.7 then writes the Finder info (GIFf, GCon).

Cancelling and errors. There is no Apple-period check: from the first NewHandle to the final
ModalDialog nothing calls the Event Manager (the busy heartbeat task does not read the keyboard),
so the save cannot be interrupted. A write error ends the routine: MAINE $4C16 and $4C57 (and so
$AD24) close the file at once (MAINE $4B3F); the routine closes the dialog if it is up, disposes of
the handles and returns carry set; 4.7 destroys the file and shows the alert with X = 8 ("writing
to the file:"). A code with high byte $EE (a failure in MAINE $AD24, which ORs $EE00: minimum code
size, sub-block length bytes, trailer) is passed on as it is, so the alert reads e.g. "Error code
is $EE48: (error description not available)."; any other code is cut to its low byte (GS/OS codes
are unchanged). If the first NewHandle fails the routine returns carry set with A = 0 ("Error code
is $0000"); if the second fails, the first handle is disposed of and the routine returns carry
clear, so the save is taken as done and the empty file stays.

**PNG (MAINE $FB3E [setup_write_png], file $2037B).** Runs after the Save dialog; the new file
exists but is not open (4.2). Options window first: FRED $E14B [setup_write_png_options] (file
$30A2F) calls InitCursor (the busy heartbeat of 2.2 keeps running) and NewWindow2(no title,
refCon 0, content procedure FRED $E3C9 (DrawControls only), no frame procedure, parameters
rWindParam1 2 from the resource fork, `superconvert-ui-data.md` 11.1). The window is visible at
once (frame $206D), content rect 29,166,184,472:

| ID | Control | Rect | Default | Effect |
|---|---|---|---|---|
| 3 | static text | 4,12,14,284 | "PNG save options" | |
| 12 | rectangle | 14,12,15,292 | | line under the title |
| 7 | static text | 21,12,31,91 | "More speed" | |
| 8 | static text | 21,172,31,297 | "More compression" | |
| 6 | horizontal scroll bar with arrows | 31,13,42,295 | value 5 (range 0-8) | zlib compression level = value + 1 (1-9, default 6) |
| 4 | pop-up, menu rMenu 9 | 44,81 (auto size) | 300 | title "Filter: ", items 300 "None" and 301 "Auto    " (the trailing spaces are in the resource); filter = value - 300 |
| 10 | static text | 59,12,69,88 | "Comments:" | |
| 9 | TextEdit | 68,11,126,294 | empty | text of the tEXt chunk; no length limit; text flags $03800000 (smart cut and paste, Tab goes to the next control, frame drawn) |
| 11 | button | 137,12,150,86 | "Help!" | help topic "PNGSAVEOPT" (FRED $0972 [ModalHelp]); the window stays |
| 2 | button | 137,130,150,207 | "Cancel" | |
| 1 | button, default (Return) | 137,219,150,290 | "OK" | |

Nothing is remembered: every PNG save starts with level 6, "None" and no comments.

```
last = GetCtlValue(6)
loop id = DoModalWindow(event record FRED $E3FE, nil, nil, nil, flags $0008):
  1 OK:     filter = GetCtlValue(4) - 300                 ; 0 None, 1 Auto
            level  = GetCtlValue(6) + 1
            text   = TEGetText(control 9, descriptor $0019 = C string in a new handle); length = result
            CloseWindow; WaitCursor; return carry clear
  2 Cancel: CloseWindow; WaitCursor; return A = $FFFF, carry set   ; 4.7: file destroyed, no alert
  11 Help!: ModalHelp("PNGSAVEOPT")
  6 slider: v = GetCtlValue(6)
            if v <> last: last = v                          ; the thumb was dragged
            else, by the part under the click (FindControl at the event's point):
                 left arrow v - 1, right arrow v + 1, page left v - 2, page right v + 2, kept in 0-8;
                 SetCtlValue(v); last = v
```

The scroll bar has no action procedure, so an arrow or page click moves the value once, after the
button is released (no auto-repeat).

Then setup_write_png copies the pathname to a C string at MAINE $FC15, opens the progress dialog
with the single line "Deflating data" (MAINE $FD15; LONGCODE $D163, `superconvert-truecolor.md`
2.4), locks the comment handle and calls the PNG writer, segment 11 (png) $0712 (file $60749), a C
routine built on libpng (segments 11 and 18-21) and zlib, with (path, width LONGCODE $0F3F,
height $0F41, interlace 0, level, filter, text, length). Afterwards it closes the progress dialog
(LONGCODE $D235) and disposes of the comment handle; a non-zero result is returned as carry set
with A = $FFFF, so 4.7 destroys the file without a second alert.

```
f = fopen(path, "ab")                                    ; fails: "Unable to open file"
libpng write structures; error / warning procedures segment 2 $0015 / $0067
IHDR: width, height, bit depth 8, colour type 2 (RGB), interlace 0 (SuperConvert always passes 0)
tIME: ReadTimeHex now (year = byte + 1900, month + 1, day + 1, hour, minute, second; local time)
if length > 0: one tEXt chunk, keyword "Comment", the text as typed (lines end in CR, $0D)
png_set_filtering(filter)       ; 0: filter type 0 (None) on every row; 1: libpng picks one per row
png_set_compression_level(level)
png_write_info                                           ; signature, IHDR, tIME, tEXt
row = malloc(width * 3)                                  ; fails: "Unable to allocate memory"
for y = 0 to height - 1:
    if Apple-period was typed (segment 2 $0116): clean up, close, return -1   ; no message
    FRED $E852 [scpng_fetch_map](y, row); png_write_row(row)
    FRED $E6FF [scpng_update_thermo](y, height)         ; progress icon, LONGCODE $D252
png_write_end (IEND); clean up; fclose; free(row); return 0
```

Pixels (FRED $E852): a grey pixel word (bit 15 set) gives R = G = B = its low byte; a colour word
gives R = R4 << 4 | bit 14 << 3, G = G4 << 4 | bit 13 << 3, B = B4 << 4 | bit 12 << 3, that is the
5-bit channel times 8 (0-248, the low three bits always 0). A SuperConvert PNG is therefore always
8-bit RGB, not interlaced, with no palette, grey type, gAMA or pHYs chunk, and it holds the whole
true color image: the size choice, alignment and selection of 4.3-4.5 are not applied. Error
messages use AlertWindow with rAlertString 2, "PNG Error - *0" (*0 = "Unable to open file",
"Unable to allocate memory" or the libpng message, e.g. "zlib error", "Write Error"); libpng
warnings use rAlertString 3, "PNG Warning - *0".

**TIFF (MAINE $B473 → ~JumpTable $004A → DYNAMTIFF $28F6, file $B9030).** Runs after the Save
dialog with the new file created and open. GetNewModalDialog(26:195C, file $B8096), rect
[20,50,185,590]:

| ID | Type | Rect | Text / default |
|---|---|---|---|
| 128 | long static text, disabled | 5,10,15,530 | "TIFF Save Options", centred and bold (LETextBox2 codes $01 "J" 1, $01 "S" 1) |
| 129 | static text, disabled | 20,10,30,600 | Image to save: |
| 16 | radio button, family 1, value 1 | 30,10 | Screen image only, as TIFF Class P (palette color) image |
| 17 | radio button, family 1 | 40,10 | True color image only, as TIFF Class R (RGB color) image |
| 18 | radio button, family 1 | 50,10 | Both screen and true color images |
| 32 | radio button, family 2, value 1 | 65,10 | Intel byte ordering, suitable for use on IBM & compatible systems |
| 33 | radio button, family 2 | 75,10 | Motorola byte ordering, suitable for use on Macintosh systems |
| 64 | check box, value 1 | 90,10 | Increase compatibility (may increase file size considerably) |
| 65 | check box, value 0 | 105,10 | Leave image sizing decisions up to the receiving program |
| 130 | static text, disabled | 120,10,130,600 | Description of image: |
| 48 | edit line, disabled item, max 80 | 130,10,143,530 | empty |
| 2 | button | 147,300,160,400 | Cancel |
| 1 | button (default) | 147,420,160,520 | Save |

```
if no true color image ($052E = 0): dim items 17, 18              ; GetControlDItem, HiliteControl 255
elif no screen image ($052C = 0):  item 17 on; dim items 16, 18, 64
MAINE $27AA                                                     ; busy state off (2.2)
loop hit = ModalDialog(no filter):
  1 Save → go on;  2 Cancel → CloseDialog, return A = $FFFF, carry set   ; file destroyed, no alert
  64, 65 → value = 1 - value;  any other (16-18, 32, 33) → SetDItemValue(1, hit)
order   = value of item 33                ; 0 Intel, 1 Motorola
compat  = value of item 64
resUnit = 2 - value of item 65            ; 2 = inch, 1 = no absolute unit
which   = (first of items 16, 17, 18 that is on) - 16     ; 0 screen, 1 true color, 2 both
descr   = GetIText(item 48)
CloseDialog; busy (MAINE $278F); UpdateAll
header (DYNAMTIFF $1E3A); if which >= 1: RGB image ($21CE); if which <> 1: palette image ($24B3)
```

With both images "Screen image only" is preselected, whatever was answered in the window of 4.10.
DYNAMTIFF is a dynamic segment; FRED $A3B9 [UnloadAll] unloads it afterwards (A and the carry are
kept).

File layout. Header: "II", $2A $00 (Intel) or "MM", $00 $2A (Motorola), then the offset of the
first IFD (patched later). For each image in turn: the values that do not fit in 4 bytes, written
in the order the tags are made (tables below), the strips, the StripOffsets and StripByteCounts
arrays (when longer than 4 bytes), then the IFD (entry count, entries of 12 bytes, next-IFD
offset 0). The previous pointer (in the header, or the first IFD's next field when "Both" is
chosen) is then patched with SetMark and Write. Every block is rounded up to an even length (the
extra byte is whatever follows the data in memory), so all offsets are even. No compression.
Values of 4 bytes or less are stored in the entry, left-aligned (the rest of the field is not
cleared). With "Both" the RGB image is the first IFD and the palette image the second.

Common tags, made first for each image (DYNAMTIFF $202F):

| Tag | Type, count | Value |
|---|---|---|
| 270 ImageDescription | ASCII, n + 1 | the description; only when it is not empty |
| 306 DateTime | ASCII, 20 | "YYYY:MM:DD HH:MM:SS", ReadTimeHex (year = byte + 1900), local time |
| 305 Software | ASCII, 18 | "SuperConvert 4.0" and two zero bytes (template "SuperConvert X.XX" at DYNAMTIFF $21B1, with the version text at MAINE $0094, "4.0" and a zero, put over "X.XX") |
| 316 HostComputer | ASCII, 11 | "Apple IIgs" |
| 269 DocumentName | ASCII, n + 1 | the loaded file's name (MAINE $3F61, at most 31 characters, 3.5) |

RGB image (true color), then, in this order:

| Tag | Type, count | Value |
|---|---|---|
| 256 ImageWidth | SHORT | true color width (LONGCODE $0F3F) |
| 257 ImageLength | SHORT | height ($0F41) |
| 282 XResolution | RATIONAL | width × k / LONGCODE $0F47, reduced to lowest terms; k = 40 when the remap mode (LONGCODE $0F31) is 0 or 3, else 80 |
| 283 YResolution | RATIONAL | height × 36 / LONGCODE $0F49, reduced |
| 296 ResolutionUnit | SHORT | resUnit |
| 277 SamplesPerPixel | SHORT | 3 |
| 259 Compression | SHORT | 1 |
| 262 PhotometricInterpretation | SHORT | 2 (RGB) |
| 254 NewSubfileType | LONG | 0 |
| 284 PlanarConfiguration | SHORT | 1 |
| 258 BitsPerSample | SHORT × 3 | 8, 8, 8 |
| 278 RowsPerStrip | LONG | max(1, 8192 div (3 × width)) |
| 273 StripOffsets | LONG × strips | |
| 279 StripByteCounts | SHORT × strips | rows × width × 3 |

LONGCODE $0F47 / $0F49 are set to the width and height when a true color image is made (LONGCODE
$AFA9 [SetMapSize]); some loaders and Crop to selection change them. Normally the resolution is
therefore 40 (or 80) by 36 pixels per inch. Rows run top to bottom, 3 bytes per pixel (DYNAMTIFF
$2340):

```
grey word (bit 15 set): R = G = B = low byte
colour word: r5 = R4 * 2 + bit 14;  g5 = G4 * 2 + bit 13
  R = r5 << 3 | r5 >> 2
  G = g5 << 3 | g5 >> 2
  B = B4 << 4 | (B4 AND 8) | B4 >> 1      ; bit 12 is not used: the fifth blue bit is a copy of B4's bit 3
```

At most 1000 strips; more gives error $FF02 ("Picture too large"), which happens only for true
color images wider than 1365 pixels and taller than 1000 lines. The size choice, alignment and
selection of 4.3-4.5 are not applied to the RGB image.

Palette image (screen): the saved area as chosen in 4.3-4.5, $92A8 bytes by $92AA lines, each
line made by MAINE $9BF7 (alignment applied, returns the line's SCB). Every pixel's colour is the
12-bit entry of its line's palette (SCB AND $F): in 320 mode the high nibble is the left pixel; in
640 mode (the image's SCB $00F2, bit 7) pixel k of a byte (k = 0 leftmost) uses entry 4k + value,
the convention of `superconvert-truecolor.md` 7.2. All different colours used in the area are
collected and sorted by their $0RGB value; the colour in place i gets index i. Bits per pixel b =
the smallest with 2^b >= number of colours (at least 1); "Increase compatibility" raises b to 1,
4 or 8 (2, 3 → 4; 5, 6, 7 → 8). That is the box's only effect; it is dimmed when there is no
screen image. Tags after the common ones, in this order:

| Tag | Type, count | Value |
|---|---|---|
| 256 ImageWidth | SHORT | $92A8 × 2 (320 mode) or × 4 (640 mode) |
| 282 XResolution | RATIONAL | 40/1 (320 mode) or 80/1 (640 mode) |
| 283 YResolution | RATIONAL | 36/1 |
| 296 ResolutionUnit | SHORT | resUnit |
| 257 ImageLength | SHORT | $92AA |
| 277 SamplesPerPixel | SHORT | 1 |
| 259 Compression | SHORT | 1 |
| 262 PhotometricInterpretation | SHORT | 3 (palette) |
| 254 NewSubfileType | LONG | 1 with "Both" (the image after the RGB one), else 0 |
| 320 ColorMap | SHORT × 3 × 2^b | red of entries 0 to 2^b - 1, then green, then blue; a 4-bit channel c becomes c × $1111 (table DYNAMTIFF $2874); entries after the last colour are 0 |
| 278 RowsPerStrip | LONG | max(1, 8192 div bytesPerRow), bytesPerRow = (width × b + 7) div 8 |
| 258 BitsPerSample | SHORT | b |
| 273 StripOffsets | LONG × strips | |
| 279 StripByteCounts | SHORT × strips | |

Pixel data: the colour index of each pixel in b bits, packed from the most significant bit, each
row padded to a whole byte.

Byte order. Motorola writes every SHORT, LONG and RATIONAL value high byte first (in the entries
and out of line, including ColorMap and the strip arrays). The entries are sorted by tag before
the IFD is written, with the ORCA/C qsort (segment 2 $9F2C) and the comparison routine DYNAMTIFF
$1F79. With Motorola order that routine byte-swaps the tag words of both entries in place before
comparing and never swaps them back, so every comparison flips two tags. With Intel order nothing
is swapped and the entries come out sorted. With Motorola order they come out unsorted and some
tag numbers are stored low byte first (a reader sees tag $0001 instead of 256, $0301 instead of
259, and so on). Following the qsort's sequence of comparisons, the IFDs are always written in
this order (tag, and in brackets the number a reader gets when it is stored byte-swapped):

| Image | Description | Entries in file order |
|---|---|---|
| RGB | empty | 256 ($0001), 257, 259 ($0301), 262, 277 ($1501), 254, 273, 258 ($0201), 269 ($0D01), 278 ($1601), 282 ($1A01), 284, 279, 296 ($2801), 306, 316, 283 ($1B01), 305 |
| RGB | typed | 256, 257, 258, 259, 277 ($1501), 284, 262 ($0601), 254, 270, 278, 269 ($0D01), 273, 282, 306, 279, 296, 316, 283 ($1B01), 305 |
| palette | empty | 256, 257, 277 ($1501), 259, 262, 258, 254, 273 ($1101), 278, 269, 320, 279, 296, 282, 306, 283, 305, 316 ($3C01) |
| palette | typed | 256 ($0001), 257, 259, 262 ($0601), 277, 306 ($3201), 254, 270, 269 ($0D01), 258 ($0201), 273 ($1101), 278 ($1601), 320, 279, 282, 316, 283 ($1B01), 296, 305 ($3101) |

Most TIFF readers reject such files. MegaconvertGS should write a correct big-endian IFD (sorted,
every tag high byte first); the table is only needed to reproduce the original byte for byte.

**Desktop background image INIT (MAINE $B46D → ~JumpTable $003C → DYNAMDESK $0000, file
$AE5F6).** No dialog of its own; the procedure and the file are given byte for byte in
`superconvert-formats-extra.md` section 2. In short: LONGCODE $EA8D [CreateDesk] builds a
32008-byte Message Center block (6 filler bytes $DD, the word $0001, then 200 lines of 160 pixel
bytes from the top left of the whole screen image, centred or bottom-aligned as described there,
the rest $DD; the selection and the size choice are not used, and no palette or SCB is stored);
PackBytes packs it into the INIT template kept in DYNAMDESK, and the template, $805E bytes from
DYNAMDESK $0061, is written to the new file (type $B7, aux $0000). The file is a one-segment OMF
load file whose code, run from SYSTEM.SETUP at start-up, does NewHandle($7D08), UnPackBytes,
MessageCenter(1 add, type 2, handle) and DisposeHandle. FRED $A3B9 [UnloadAll] follows.

### 4.10 "More than one way" window (FRED $A3E1 [DoSaveType])

DoSaveType (file $2CCC5) is step 4 of 4.1. It decides which image type is saved, starts the
conversion and asks with this window when there is more than one possibility. Type bits: 1 =
screen, 2 = true color, 4 = monochrome. MAINE $8E58 / $8E5A hold the source and target types;
nothing else reads them.

```
cap  = save record +5 AND 7            ; 1 screen formats, 2 PNG, 3 TIFF (no record has 4)
have = (screen image $052C ? 1) + (true color image $052E ? 2) + (monochrome image $0530 ? 4)
skip = MAINE $00E0                     ; remembered "SKIP ME" answer: one type bit, or 0
                                       ; (cap = 0 or have = 0 ends in BRK $BB; cannot happen)
both = have AND cap
if both <> 0:
    if both is one bit:          src = dst = both
    elif both AND skip <> 0:     src = dst = both AND skip
    else:                        src = dst = Window(lines = both, no source, target 1/2/4)   ; kind A
elif have is one bit:
    src = have
    if cap is one bit:           dst = cap
    elif cap AND skip <> 0:      dst = cap AND skip
    else:                        dst = Window(lines = cap, source = have, target 1/2/4)       ; kind B2
else:
    dst = cap
    if have AND skip <> 0:       src = have AND skip
    else:                        src = Window(lines = have, source 1/2/4, target = cap)       ; kind B1
Window result $FFFF (Cancel): return carry set; the save stops before any file dialog
step for (src, dst) from the table FRED $A4C8, index (src - 1) * 4 + dst - 1; its carry is returned
```

| Source → target | Step |
|---|---|
| screen → screen, true color → true color, true color → screen, monochrome → monochrome | none |
| screen → true color | FRED $B845 [MakeAMapAnyway]: converts the screen image (640 mode: Exact / Smoothed window, `superconvert-truecolor.md` 10) |
| monochrome → screen | FRED $8BF4 [FroMonoDlg](kind 0, X = 1): only the options window of `superconvert-truecolor.md` 8.1 |
| monochrome → true color | FRED $8BF4 [FroMonoDlg](kind 2, X = 1): only the options window |
| screen → monochrome, true color → monochrome | FRED $CB73 [Scrn2Mono] / $CB8C [True2Mono]; never used (no record takes monochrome) |

X = 1 makes FroMonoDlg leave out its "(will be clipped)" / "(not enough memory?)" notes. Cancel in
the windows of these steps cancels the save. After FroMonoDlg no conversion is made here or later,
so no screen or true color image comes from the monochrome image (see 11).

Step 2 of 4.1 has already made a screen image when there was none, unless the record takes true
color and a true color image exists (cancelling its Convert-to-screen window is ignored there). So
the window appears only in these cases (lines are always shown in the order screen, true color,
monochrome):

| Record | Images at this point | Kind | Lines offered | Selected at first |
|---|---|---|---|---|
| TIFF | screen and true color (monochrome may exist too) | A | screen, true color | true color |
| PNG | screen and monochrome, no true color; this includes a monochrome-only picture after step 2 | B1 | screen, monochrome | screen |
| TIFF | monochrome only (the Convert-to-screen window of step 2 was cancelled) | B2 | screen, true color | true color |

For TIFF (kind A) the answer changes nothing: no conversion is needed and the TIFF dialog (4.9)
asks again. Without a window: PNG with only a screen image runs MakeAMapAnyway directly. When the
Convert-to-screen window of step 2 was cancelled and only a monochrome image exists, a screen-only
record runs FroMonoDlg(kind 0, X = 1) directly (the same options window a second time) and PNG
runs FroMonoDlg(kind 2, X = 1).

Window: NewWindow2 from FRED $A877 (file $2D15B): frame $2000 (alert frame, created invisible),
no title, content rect 20,106,170,534, content procedure FRED $AAA1, controls from the pointer list
FRED $A8C7 (wInVerb 3):

| ID | Type | Rect | Flag | More | Content |
|---|---|---|---|---|---|
| 7 | static text | 5,10,23,418 | $0000 | $1000 | "There is more than one way to save an image in the selected save format.  Please specify which to use:" (102 characters, two spaces after the full stop), centred (just 1) |
| 8 | static text | 40,20,50,408 | $FF02 (inactive, substitution) | $1000 | "*6*0*7*1*8", centred: line 1 |
| 9 | static text | 70,20,80,408 | $FF02 | $1000 | "*6*2*7*3*8", centred: line 2 |
| 10 | static text | 100,20,110,408 | $FF02 | $1000 | "*6*4*7*5*8", centred: line 3 |
| 4 | check box | 135,10 (auto size) | $0000 | $3000 | "SKIP ME: save using selected type whenever possible", value 0, key Control-S |
| 2 | simple button | 119,150,132,250 | $0000 | $3000 | "Cancel" (OSAYCANYOU $0EE8), key Escape |
| 1 | simple button | 119,280,132,410 | $0001 (default) | $3000 | "Continue..." (OSAYCANYOU $0F02), key Return |

Line 1 stands for screen, line 2 for true color, line 3 for monochrome: as the target in kinds A
and B2, as the source in kind B1. Substitution strings (OSAYCANYOU $794A / $78FE, set with
SetCtlParamPtr by OSAYCANYOU $7A0B before NewWindow2):

| | Value |
|---|---|
| *6 | "Save the " (FRED $A815) |
| *0, *2, *4 | source type of lines 1, 2, 3: "screen", "true color" or "monochrome" (FRED $A831, $A838, $A843); empty in kind A |
| *1, *3, *5 | target type of lines 1, 2, 3, same strings |
| *7 | " image as " when the lines have a source (kinds B1, B2), else empty |
| *8 | " image" when they have none (kind A), else empty |

Resulting lines: kind A "Save the screen image", "Save the true color image"; kind B1 "Save the
screen image as true color", "Save the monochrome image as true color"; kind B2 "Save the
monochrome image as screen", "Save the monochrome image as true color". The static text of each
line not offered gets EraseControl (FRED $AC65 [KillCtlByID]) before ShowWindow; in the ROM 3
Control Manager EraseControl shares HideControl's code and sets the invisible flag, so only the
offered lines are drawn.

Content procedure (FRED $AAA1):

```
DrawControls
for line = 3, 2, 1, if offered:
    top = 25 + 30 * (line - 1)
    if the line has a source:
        DrawIcon(source icon, mode 0, 142, top + 5); DrawIcon(arrow, 0, 166, top + 7); h = 142
    else h = 110
    DrawIcon(target icon, 0, h + 64, top + 5)
    DrawIcon(arrow, 0, h + 88, top + 7)
    DrawIcon(disk icon, 0, h + 128, top + 6)
Frame(selected line, $1111)

Frame(line, c): SetSolidPenPat(c); SetPenSize(7, 3); FrameRRect(rect of the line, 48, 20)
rects (FRED $A527): line 1 [25,10,55,418], line 2 [55,10,85,418], line 3 [85,10,115,418]
```

Icons: screen OSAYCANYOU $4453, true color $44AB, monochrome $456F, arrow $47C1
(`superconvert-truecolor.md` 2.6) and a 3.5-inch disk, OSAYCANYOU $4B0F (file $5783A, header
height 8, width 10). Each line thus shows source → target → disk, or target → disk in kind A.

Run loop: MAINE $EFE3, then FRED $ABFC [ModalMaster] (`superconvert-truecolor.md` 2.6).

- Continue (Return): result = 1, 2 or 4 for line 1, 2 or 3; if the check box is on, MAINE $00E0
  = result; CloseWindow; UpdateAll; the result goes on to the step table.
- Cancel (Escape): CloseWindow; A = $FFFF, carry set. Nothing has been saved; a screen image made
  in step 2 of 4.1 stays.
- Mouse-down in the content but not on a control: SetPort, GlobalToLocal; the first of the three
  line rects that contains the point gives the line.
- Key-down "S" or "s", "T" or "t", "M" or "m": line 1, 2 or 3. Other keys are ignored.
- A line not offered is ignored. Otherwise: SetPort(window); Frame(old line, $FFFF) (drawn over
  the old frame to remove it); selected line = new; Frame(new line, $1111). The window stays
  open; only Continue confirms.

"SKIP ME" memory: MAINE $00E0 keeps the answer for the rest of the session. It is not saved in
SuperConv.Prefs and is cleared by "Clear all “SKIP ME” preferences" (`superconvert-extras.md`
2.5). Showing the window clears $00E0 first; only Continue with the box on sets it again (Cancel
leaves it 0). The value is a type bit: the target in
kinds A and B2, the source in kind B1. "True color" remembered from a TIFF save therefore does
not suppress the PNG window (its lines are screen and monochrome), which then appears and clears
it.

## 5. Exchange load/save paths (MAINE $4C98)

Swaps the two path handles ($3F55/$3F57 with $3F59/$3F5B). No dialog, no redraw, no feedback.
The next Load dialog opens where the last save went and vice versa.

## 6. Printing

### 6.1 Common set-up

- Print record: handle MAINE $B47C (140 bytes, PrDefault at start-up, MAINE $B790).
- MAINE $B5FF before every print dialog: if the image is in 320 mode (SCB $00F2 bit 7 clear) the
  whole desktop is switched to 320 mode (CloseAllNDAs, WindowGlobal(1), SetMasterSCB(image SCB),
  HideCursor, CtlNewRes, WindNewRes, MenuNewRes, RefreshDesktop, SystemTask, InitCursor). If the
  mode differs from the last print, PrDefault; then PrValidate.
- MAINE $B69B afterwards: SetMasterSCB($80), InitColorTable/SetColorTable(0), back to 640 mode
  (SetAllSCBs($80), resolution changes, SizeWindow of the image window, RefreshDesktop,
  WindowGlobal($FFFE)).
- FRED $C1FB [MakeScreen] first makes a screen image if needed (Remap / mono conversion);
  FRED $C505 [UnMakeScrn] undoes it at the end.
- Before PrOpenDoc: PrSetDocName(loaded file name), and the screen shows the image palettes and
  SCBs (SetColorTable(0, image palettes), SetAllSCBs(image SCB), MAINE $B774).
- Errors after any Print Manager call (MAINE $C627) set PrSetError($80) to stop; at the end
  PrError ≠ 0 gives alert X = $20 ("printing this document.").
- After PrCloseDoc with no error: MAINE $BB8A frees memory until MaxBlock ≥ 10000 bytes
  (CompactMem, PurgeAll, closing help, CloseAllNDAs, purge levels 1-5) and beeps twice if it still
  is not enough; then PrPicFile(print record, 0, 0, status MAINE $B4C4).

### 6.2 Layout computation (MAINE $BAC3)

- Source: the screen image locInfo ($00F2 SCB, $00E4/$00E6 pointer, $00E8 width, bounds $00EE x
  $00F4 = height x width in pixels).
- Page rect = print record +8 (rPage).
- Page height in image lines = rPage.bottom / vScale (rounded up), width in pixels = rPage.right /
  hScale; a scale value of 0 means "÷2": page size = rPage x 2.
- Pages down = ceil(imageH / pageH), pages across = ceil(imageW / pageW).
- Offsets (enhanced only, computed while the preview is drawn, MAINE $C14A-$C1D7): vertical 0
  (Top), imageH - pagesDown·pageH (Bottom, zero or negative) or half of that (Center); horizontal
  likewise with Left / Right / Center. A negative offset becomes a positive destination position
  on the first page row/column.

### 6.3 Print (normal) (MAINE $B7CC)

MakeScreen; set-up; PrStlDialog (page setup); cancel = restore. Scales 1, offsets 0, no caption,
layout; then PrJobDialog; cancel = restore. Then the page loop (6.5).

### 6.4 Print (enhanced) (MAINE $B807)

MakeScreen; set-up; PrStlDialog; then the layout dialog (MAINE $BC1D) ; cancel = restore; then
the set-up again, PrJobDialog and the page loop.

Default caption (MAINE $BC1D): '"' + file name + '" printed at ' + ReadAsciiTime (20 characters,
high bits cleared), e.g. `"SUNSET.PIC" printed at 10/28/97  9:41:05 PM` (date format from the
Control Panel). Caption font: family $FFFE, style $02, size 16 (MAINE $B4EB) **(meaning of $FFFE
as "system font" unconfirmed)**.

Dialog: GetNewModalDialog(9:21D8), rect [33,80,183,560]; ModalDialog2 with filter LONGCODE $F471
[prszFilter].

| ID | Type | Rect | Text / function |
|---|---|---|---|
| 1 | button | 10,20,25,100 | OK |
| 2 | button | 35,20,50,100 | Cancel |
| 4 | button | 65,10,78,110 | Info... (help topic "M7PRINTE", FRED $0972 [ModalHelp]) |
| 32 | check box | 105,10 | Add caption |
| 3 | button | 117,10,129,150 | Set caption font |
| 48 | edit line, max 255 | 132,10,145,470 | caption text |
| 8 | scroll bar (vertical) | 20,140,110,170 | vertical scale |
| 9 | scroll bar (horizontal) | 5,175,18,385 | horizontal scale |
| 10 | user item, disabled | 20,175,110,385 | page preview (MAINE $BFCC) |
| 16, 17, 18 | radio buttons, family 1 | 35,395 / 60,395 / 85,395 | Top (on) / Center / Bottom |
| 24, 25, 26 | radio buttons, family 2 | 115,175 / 115,245 / 115,325 | Left (on) / Center / Right |

Scroll bar items use MAINE $BDFF as their Dialog Manager procedure: initial view 2, total 11,
value 1; line up / page up -1, line down / page down +1, thumb as dragged; clamped to 0-9. Value
0 is labelled "÷2" (MAINE $BFC9), 1-9 "x1"-"x9" (MAINE $BFC5); the label is drawn with
MoveTo(control record +$2A, +$28), Move(6, 9) **(probably the thumb position, unconfirmed)**. A
changed scale or radio button redraws the preview (InvalRect 9:22D1).

Buttons: Set caption font checks "Add caption", calls ChooseFont(current, 0); a non-zero result
becomes the caption font (SetPurgeStat $10, SetFont, SetTextFace(0)). OK reads the caption (GetIText
item 48) and clears the caption if "Add caption" is off.

Preview (MAINE $BFCC): EraseRect(item box); pen 2x1; scale = min((box width - 1) / (pagesAcross ·
pageW, doubled in 320 mode), (box height - 1) / (pagesDown · pageH)) (FixRatio); grid lines for
all page edges; each page numbered (decimal, 1-2 digits) at its top-left + (4, 9), numbering down
each column first; then the image rectangle (from the offsets) painted with solid pen pattern 2 in
mode $8003; fore colour 0, pen mode 0 restored.

### 6.5 Page loop (MAINE $B884)

PrOpenDoc. For each page column (left to right), for each page row (top to bottom): PrOpenPage
(frame = rPage); SetPort(print port); PicComment kind $FB (42 bytes: $A55A, palette number, its 16
colours) for every palette in use; PicComment kind $FC (14 bytes: $A55A, first line, last line,
palette, line numbers multiplied by the vertical scale or halved for ÷2) for each run of lines
with the same SCB on that page; PPToPort(image locInfo, source rect of the page, destX, destY,
mode 0) where a negative offset becomes a positive destination and source 0. Caption (enhanced,
when on, MAINE $B961-$BA2C): for Top and Center images on the last page row with baseline
v = pageH - size/2; for Bottom images on the first page row with baseline v = (3·size)/2 (size =
caption font size, computed as ((3·size) & $FF) / 2); h = 4 - column·pageW, so the text starts 4
pixels from the left of the whole printout and continues across the pages of that row;
SetBackColor($FFFF), SetForeColor(0), SetTextMode(0), InstallFont(caption font), DrawString.
PrClosePage. Then PrCloseDoc, PrError, PrPicFile (6.1).
**(How the x1-x9 / ÷2 factors enlarge the picture on paper is not visible here: PPToPort copies
1:1 and only the page partition and the PicComments use the factor.)**

### 6.6 Print alignment page (MAINE $C4E4)

No MakeScreen. PrStlDialog, PrJobDialog (cancel either: return). PrSetDocName("SuperConvert
alignment page", MAINE $C63D). PrOpenDoc, PrOpenPage, read rPage, PenNormal, rPage.bottom and
.right decremented, and a cross at each corner (top-left, top-right, bottom-left, bottom-right):
MoveTo(x, y-10), Line(0, 20), Move(-10, -10), Line(20, 0) - two 21-pixel strokes. No text on the
page. PrClosePage, PrCloseDoc, PrPicFile; errors alert X = $20.

### 6.7 Print (?????)... - ImageWriter LQ (MAINE $C383)

At start-up MAINE $C2FE tries InitialLoad of "LQ.DRIVER" (MAINE $C2E0). If that works, $C2DE = 1
and "Driver loaded" is drawn at (5, 197) on the start-up screen; if not, MAINE $C349 deletes menu
item $011E (DeleteMItem, CalcMenuSize), so normally the item is absent. At quit the driver is
unloaded (MAINE $C369).

The command: GetNewModalDialog(9:23D7), rect [40,35,178,285]; check box values are set from the
saved option bits ($C2B6, table MAINE $C2BA: item/bit pairs 16/$8000, 17/$4000, 18/$2000,
19/$0200, 20/$0040, 21/$0400, 33/$0800, 34/$1000); ParamText(^0 = PrGetNetworkName).

| ID | Type | Rect | Text |
|---|---|---|---|
| 3 | static text | 5,10,15,240 | IMAGEWRITER LQ/^0   v0.1 |
| 16-21 | check boxes | 20 / 30 / 40 / 50 / 60 / 70, x 10 | Color; Unidirectional printing; Darker printing; Landscape mode (sideways); Wide paper; Condensed vertical printing |
| 32-34 | radio buttons, family 1 | 85 / 95 / 105, x 10 | Full size (on); 2/3 size (reduced 33%); 1/3 size (reduced 67%) |
| 1 | button | 120,140,133,230 | Print |
| 2 | button | 120,20,133,110 | Cancel |

Print: bits collected, CloseDialog, UpdateAll, busy, JSL into the driver (MAINE $C2EC, patched
JML) with the bits, SCB table, palettes and image locInfo; end busy. **(the driver itself is a
separate file and was not examined)**

## 7. Examine file... (segment 2 $59E0, LONGCODE $0000)

### 7.1 File dialog and the chosen files

Segment 2 $59E0 is compiled code. SFShowInvisible(1) for the dialog (old state restored
afterwards), then SFPMultiGet2 at whereX 120, whereY 30, prompt "Select file(s) to examine:"
(Pascal string 2:5E94), filter 2:5180, no type list, template 2:60FB (file $694B, rect
[0,0,114,400]; the standard items 1-8 as in 3.2 but button 3 reads "Volume" and there are no extra
check boxes), hook 2:5089. Neither RecallPfx8/StorePfx8 nor FlushNsert is used: the dialog opens
in whatever folder prefix 8 holds (normally the folder of the last load or save dialog), and the
stored load and save paths are not changed.

Listed: every file and folder, invisible ones included, and every one can be selected (Standard
File itself dims only folders that cannot be read). The filter has no effect. It is compiled as a
function that returns its result in A and never writes the result word on the stack; Standard
File (Tool023 of System 6.0.4, code at $2E25) fills that word before the call with the upper 16
bits of the filter's address (bank byte, never 0) and treats every value other than 0 (not shown)
and 1 (dimmed) as selectable. To behave the same, pass no filter (or one that always returns 2).
For the record, the filter would give: folder 2; otherwise by the mode word 2:5EB7: 16 → 2 if
access bit $40, 17 → 2 if access bit $80, 18 → 2 if (access & $C3) ≠ $C3, 19 → 2 if access & $C2,
20 and 21 → 2, anything else 1. The mode is $0015 ("View file") and never changes here; the filter
also reads it after MAINE $1C06 has set the data bank to 0, i.e. from $00:5EB7.

Hook 2:5089: does nothing for items 1-15, which are all this dialog has. Items 16-21 belong to an
unused file utility dialog whose radio items are still in segment 2 (2:6179 "Rename
(unimplemented)", 2:5F27 "Delete (triple-click)", 2:5FC3 "Unlock", 2:6149 "Lock", 2:6065 "Change
(unimplemented)", 2:60C5 "View file"; no template uses them). For those the hook would set the item
hit to 0 and, if the item is off (item 17 only at its third click, counter 2:5EB1), turn it on,
store its number in 2:5EB7 and call SFReScan(0, 0).

Cancel or no file: return. Otherwise:

```
UpdateAll (FRED $97DF)
p = names handle data + 2                  ; entry: fileType word, auxType long, name (Pascal string)
repeat (number of names) times:
    turn the name into a GS/OS string (length word at p+5)
    ExpandPath into a 5-byte buffer (gives the length), NewHandle(length + 4), ExpandPath again
    (NewHandle or the second ExpandPath fails: this entry is skipped, no message)
    LONGCODE $0000(full path, fileType, auxType low word)   ; returns when its window is closed
    DisposeHandle(path)
    p = p + 7 + name length
DisposeHandle(names)
```

So several chosen files are examined one after another, in the order of the reply: the next
window opens only when the previous one has been closed with its close box. A chosen folder
(Accept with a folder selected) is skipped without a message; nothing inside it is examined. A
file whose two forks are both empty is skipped silently as well (7.2).

### 7.2 Window

LONGCODE $0000 is hand-written. Its direct page is its own stack frame; the address is kept in
$0526 for the content and scroll routines.

1. File type $0F: return.
2. GetFileInfo (pCount 11, block $0891); error: alert (below), no window. Data fork EOF ($08B5) and
   resource fork EOF ($08BD) both 0: return, no window, no message.
3. Title: the last path component (after the last ':') as a Pascal string at $02EE; up to 255
   characters are copied, the Window Manager centres the title and clips it to the title bar (a
   name of 31 characters fits easily).
4. NewWindow2 from the rWindParam1 at LONGCODE $0420 (file $42576), content routine $0552: frame
   $C000 (title bar and close box only: not movable, no zoom box, no grow box), content rect
   [30,2,197,638] global (636 × 167), in front of all windows, created invisible. Controls
   (template list $0492):

   | ID | Type | Rect (content) | Text |
   |---|---|---|---|
   | $10001 | radio button, family 0, value 1 | 1,10 (auto size) | Data fork |
   | $10002 | radio button, family 0 | 1,160 (auto size) | Histogram |
   | $10003 | radio button, family 0 | 1,320 (auto size) | Resource fork |
   | 1 | scroll bar, dump modes only (7.3) | 12,612,168,638 | |

5. Buffer: FreeMem / 2, or MaxBlock if that is smaller, rounded down to a multiple of 1 KB, at
   least 2 KB; NewHandle (locked, fixed). Its last 1 KB holds the 256 counts of 7.4, the rest is
   the read area. Failure: alert with the Memory Manager error ($0201 "Memory full"); the still
   invisible window is never closed.
6. Start mode: resource fork empty: "Resource fork" dimmed (HiliteControl 255), Data fork; data
   fork empty: "Resource fork" turned on, "Data fork" and "Histogram" dimmed, Resource fork;
   otherwise Data fork. Dimmed buttons stay dimmed for this file.
7. ShowWindow, then:

```
loop:
    if error ($0528) ≠ 0: goto close
    SetPort(window)
    r = TaskMaster($FFFF, task record $03F2)       ; wmTaskMask $00130106
    r = $21 (wInControl) and the control ID's high word ≠ 0: mode change to the ID's low word
    r = 0 and mode = 2: mouse tracking (7.4)
    r = $16 (wInGoAway): goto close
close:
    mode 0 (closes the open fork), CloseWindow, DisposeHandle(buffer)
    if error ≠ 0: alert
```

The task mask holds only tmUpdate, tmFindW, tmClose, tmContentControls, tmControlKey and
tmIdleEvents. Update events of all windows are handled; clicks work only on this window's
controls and close box. Keys do nothing (no menu keys, no Escape or Apple-period, no arrow keys:
TaskMaster hands the key events back and they are dropped); clicks in the menu bar, in other
windows (desk accessories included) and on the desktop are ignored. The window is therefore modal
until it is closed.

Errors: the alert of 2.3 through MAINE $47F4 (called via MAINE $1186) with X = $18 and ^1 = " ":
"I am having a hard time viewing this file." / "Error code is $xxxx: ...". After an Open, SetMark
or Read error the window is closed first; a GetFileInfo error comes before the window exists, and
after a NewHandle error the invisible window is left as it is (5). The next chosen file follows.

Mode change (LONGCODE $0615 with the new mode in A, from wInControl via $0609; the current mode
again: nothing):

```
if the old mode is 1 or 3: Close the fork
mode = new mode; SetPort(window)
InvalRect and EraseRect [12,0,200,640]
DisposeControl for the controls with ID 1, 2, ... (only the scroll bar exists)
mode 1 or 3: fork = mode >> 1 (0 data, 1 resource)
             scroll bar (7.3), top line = 0, Open(path, read access, fork), buffer marked empty
mode 2:      histogram counts (7.4), only the first time for this file; highlighted value = none
```

So every switch to a dump starts again at offset 0.

### 7.3 Data fork / resource fork dump

Content routine ($0552) in modes 1 and 3: DrawControls; MoveTo(0, 12), Line(640, 0) with the
port's pen as it is (black, but after the histogram it can still be colour 1 of a highlighted
bar); then lines r = 0-16 (LONGCODE $08F8). Nothing is erased here (the mode change erases).

Line r: offset = (top + r)·16; offset ≥ fork EOF: not drawn. Otherwise the C string at LONGCODE
$0B1E (file $42C74), 59 characters

```
OOOOOO | xx xx xx xx xx xx xx xx xx xx xx xx xx xx xx xx | 
```

is filled in and drawn with DrawCString at h 5, baseline v = 21 + 9·r, after SetFontFlags(2),
SetForeColor(0), SetBackColor(3); the text column follows from the pen position; SetFontFlags(0)
at the end.

Font and spacing: the port's font is the system font (Shaston 8). SetFontFlags(2) sets font flag
bit 1 ("zeroSize"): QuickDraw II then replaces the advance of every character, not only the
digits, by the advance of '0' (bit 0, "widMaxSize", would use widMax instead; QuickDraw II in
ROM 03, $FE882F). '0' is 8 pixels wide in Shaston 8, so every character takes an 8-pixel cell;
the glyph is drawn at its normal offset in the cell, only the advance changes (the normal Shaston 8
advances are 8 for digits and A-D, 7 for E and F, 4 for space, 6 for '|'). The text mode is copy
(port default), so each cell is painted in the back colour from row v-7 to row v (ascent 7,
descent 1); row v+1, the leading, is never painted.

| Cells | Content | x of the cells | Colours (fore / back) |
|---|---|---|---|
| 0-5 | offset, 6 hex digits (Long2Hex) | 5, 13, 21, 29, 37, 45 | 0 / 3 |
| 6-8 | " \| " | 53, 61, 69 | 0 / 3 |
| 9+3j and 10+3j, j = 0-15 | byte j, 2 hex digits (HexIt); 2 spaces past the end of the fork | 77+24j, 85+24j | 0 / 3 |
| 11+3j | space | 93+24j | 0 / 3 |
| 57-58 | "\| " | 461, 469 | 0 / 3 |
| 59+k, k = 0-15 | text column, byte k | 477+8k | below |

Hex digits are upper case. A line spans x 5-604; line r paints rows 14+9r to 21+9r (line 16: rows
158-165). The text column shows byte b as character c:

| b | c | Colours (fore / back) |
|---|---|---|
| $00-$1F | b + $40 ('@', 'A'-'Z', '[', backslash, ']', '^', '_') | 1 / 3 |
| $20-$7E | b | 0 / 3 |
| $7F | $C6 (a triangle in Shaston 8) | 0 / 3 |
| $80-$9F | b - $40 ('@' to '_') | 1 / 2 |
| $A0-$FE | b - $80 | 0 / 2 |
| $FF | $C6 | 0 / 2 |

(c = b & $7F, then $7F → $C6 and values below $20 + $40; the colours come from the tables $0B7D
(fore) and $0B8D (back) indexed by b >> 5.) The characters are drawn with DrawText in runs of
bytes with the same top three bits, each run after SetForeColor/SetBackColor. In a short last line
the cells after the fork's end are spaces, 0 / 3. The help text calls colour 1 purple and colour 2
green: with the standard 640-mode palette colour 1 is blue and red and colour 2 yellow and green
in alternating columns.

Reading: the fork is read on demand into the read area (size B, a multiple of 1 KB). For each line:

```
if offset < start or offset > start + length:          ; offset = start + length counts as inside
    start = max(0, offset - B/2) rounded down to a multiple of 256
    SetMark(start); WaitCursor; Read(B bytes); InitCursor; length = bytes read
n = start + length - offset, at most 16                   ; bytes shown on this line
```

Quirk (only for forks larger than B): the line whose offset is exactly start + length is drawn
with n = 0: offset shown, hex cells blank, and in the text column one character made from the
byte after the read data followed by 15 spaces. It stays so until that line is drawn again.

Scroll bar: template LONGCODE $0532 (file $42688), pCount 9: ID 1, rect [12,612,168,638] (its last
2 columns and last row lie outside the 636 × 167 content), procRef $86000000, flag $0003 (vertical,
both arrows), moreFlags $1000; made with NewControl2 at every switch to a dump; action procedure
LONGCODE $0B9D (SetCtlAction).

```
lines    = (EOF + 15) >> 4
s        = number of right shifts that bring lines below 32768 (0 up to an EOF of 524,272)
dataSize = lines >> s;  viewSize = max(1, 17 >> s);  value = 0
```

Action procedure (part code, control):

```
new = top - 1 (part 5, up arrow), top + 1 (6, down arrow), top - 16 (7, page up),
      top + 16 (8, page down), GetCtlValue << s (part $81, thumb); other parts: return
new = min(max(new, 0), max(0, lines - 17))
d = new - top
d = 0:           nothing
1 <= d <= 16:    ScrollRect([14,2,167,610], 0, -9·d); top = new; draw lines 17-d ... 16
-16 <= d <= -1:  ScrollRect([14,2,167,610], 0, 9·(-d)); top = new; draw lines -d-1 ... 0
otherwise:       top = new; draw lines 0 ... 16
SetCtlValue(top >> s)
```

So an arrow click scrolls one line and a page click 16 lines (of the 17 shown one stays), both
repeated while the button is held, since the Control Manager calls the procedure again and again.
The thumb ranges over the values 0 to dataSize - viewSize; the top line is value << s and the value
is top >> s. A fork of 17 lines or fewer does not scroll. The window cannot be resized or zoomed,
so 17 lines are always shown.

### 7.4 Histogram

Counting (LONGCODE $0751, on the first switch to Histogram for a file): WaitCursor; Open the data
fork; the 256 counts (32-bit, at the end of the buffer) cleared; the whole fork read in pieces of
the read area, counts[byte] + 1 for every byte; Close; InitCursor. No Apple-period. The maximum
is the largest count (unsigned 32-bit compare), kept in $052C; it is at least 1 (Histogram is
dimmed for an empty data fork). Errors: as in 7.2.

Drawing ($0552, mode 2), in this order:

1. DrawControls.
2. SetPenPat(LONGCODE $0488); PaintRect [153, 1+40k, 157, 34+40k] for k = 0-15 (the rect at
   $0601 moves 40 pixels right each time).
3. PenNormal.
4. For v = 0-255 with count ≠ 0: SetSolidPenPat(1 if v is the highlighted value, else 0),
   SetPenSize(1, 1), MoveTo(40·(v >> 4) + 2·(v & 15) + 2, 152), Line(0, -h) with
   h = count·140 / max (LongMul low 32 bits, LongDivide, low word of the quotient). The bar covers
   rows 152-h to 152 (h + 1 pixels, so every value that occurs shows at least one pixel); the
   largest reaches row 12.
5. The info line.

Nothing is erased by this routine.

Pattern at LONGCODE $0488 (file $425DE), 32 bytes as stored:

```
10 00 DD DD BF BF BF BF BF FF A2 04 00 00 CC 04 00 00 F6 04 00 00 00 00 00 00 08 00 01 00 01 00
```

Bytes 10-12, 14-16 and 18-20 are the relocated pointers of the window's control list ($0492), so in
memory they depend on the load address. In 640 mode QuickDraw II uses only bytes 0-15, 8 rows of 2
bytes (ROM 03 $FE1F4F repeats each 2-byte row), and patterns are aligned to the port's local
coordinates: the pixel (x, y) takes row y & 7, column x & 7 (2 bits per pixel, the leftmost pixel
in the top bits).

| Row | Bytes | Pixels (colour numbers) |
|---|---|---|
| 0 | 10 00 | 0 1 0 0 0 0 0 0 |
| 1 | DD DD | 3 1 3 1 3 1 3 1 |
| 2 | BF BF | 2 3 3 3 2 3 3 3 |
| 3 | BF BF | 2 3 3 3 2 3 3 3 |
| 4 | BF FF | 2 3 3 3 3 3 3 3 |
| 5-7 | relocated pointer bytes | depend on the load address |

The boxes cover rows 153-156, that is pattern rows 1-4 only, so they always look the same. One box,
x = 40k+1 to 40k+33 ('.' = colour 3); the 16 bars of the group stand on the even columns 40k+2 to
40k+32 directly above it:

```
row 153   1.1.1.1.1.1.1.1.1.1.1.1.1.1.1.1.1
row 154   ...2...2...2...2...2...2...2...2.
row 155   ...2...2...2...2...2...2...2...2.
row 156   .......2.......2.......2.......2.
```

A scale under each group of 16 values: a dotted line (colour 1 between the bars, 3 under them), a
2-pixel mark in colour 2 under every second bar (low nibble 1, 3, 5, ... 15) and a 3-pixel mark
under low nibbles 3, 7, 11 and 15.

Mouse (TaskMaster result 0 in mode 2, LONGCODE $0275): GlobalToLocal(event where); the value is
none unless 12 <= v < 157, h >= 2 and (h - 2) >> 1 = 20k + r with r < 16 and k < 16; then it is
16k + r (a bar's column and the column to its right). When it changes: the old bar is drawn again
in colour 0, the new one in colour 1, then the info line. No mouse button is needed.

Info line (LONGCODE $0DAA): SetForeColor(0), SetBackColor($FFFF, i.e. colour 3), EraseRect
[157,0,167,640]; no highlighted value: nothing more. Otherwise the Pascal string at LONGCODE $0EDA
(file $43030, 65 characters)

```
"x"  $12 hex  123 decimal     1234567 occurences, 123.45% of file
```

is filled in and drawn with DrawString at (10, 166) in the normal proportional system font (font
flags 0):

| Characters | Content |
|---|---|
| 1-3 | v >= $20: '"', the byte v itself, '"' (also for $7F-$FF, with the font's glyph); v < $20: '^', v + $40, space |
| 4-6 | 2 spaces, "$" |
| 7-8 | v, 2 hex digits (Int2Hex, upper case) |
| 9-14 | " hex  " |
| 15-17 | v in decimal, 3 places, right-aligned with spaces (Int2Dec) |
| 18-30 | " decimal" and 5 spaces |
| 31-37 | count, 7 places, right-aligned with spaces (Long2Dec) |
| 38-50 | " occurences, " (spelling of the program) |
| 51-56 | percentage, see below |
| 57-65 | "% of file" |

Percentage: p = ((count·10000) mod 2^32) / data fork EOF (LongMul, LongDivide, low word of the
quotient); Int2Dec(p, 5 places) gives d0 d1 d2 d3 d4 with leading spaces; a blank d2 or d3 becomes
'0'; shown as d0 d1 d2 '.' d3 d4 ("100.00", " 12.34", "  0.05"). The product overflows above
429,496 occurrences and the percentage is then wrong (1,048,576 bytes $00 in a file of that size
show " 18.08%"). Examples:

```
"A"  $41 hex   65 decimal          12 occurences,   0.52% of file
^@   $00 hex    0 decimal         300 occurences,  13.20% of file
```

## 8. Quit (MAINE $1152)

INC $00CC only. On the next null event (MAINE $0DB5) pending automatic save/print events are posted
first; then $00CE is decremented, the main loop (MAINE $0B8F, test at $0D23) returns, MAINE $08C5
shuts down (end busy, VOC off, LQ driver unloaded, Babelfish, all tools), and GS/OS Quit runs.
There is no confirmation of any kind, even with an unsaved image or a pending queue.

## 9. Automatic save / print / load next

Preferences (OSAYCANYOU $7032 [DoPrefs], window rWindParam1 6; check box → variable):
6 → $00B6 save after loading, 7 → $00B8 print after loading, 8 → $00BC load next after saving,
9 → $00BE don't view, 10 → $00B2 VOC, 11 → $00C0, 12 → $00C2, 13 → $00C4 disk insertion.
Pending flags $00C6 (save), $00C8 (print), $00CA (load next) are turned into key events by the null
event handler MAINE $0DB5 in that order, one per null event: PostEvent(keyDown, 'S' / 'P' / 'N',
Apple). A save or print therefore uses the normal dialogs. Load next is held back while a save or
print is pending ([DoLoadNext] sets $00CA again).

## 10. Corrections to the other documents

- `superconvert-ui-data.md` 11.2: template 9:201B ("OK", "Cancel", scroll bar, three colour user
  controls, "Background:", "Small icon", "Open", "Offline", "Selected") belongs to the Finder icon
  *loader* (MAINE $73DD, from MAINE $7394), not to saving.
- `superconvert-ui-data.md` 9.1: the suffix replaces an existing suffix if a '.' is among the last
  six characters (so up to five characters after the dot), and the dot position is limited to 27.
- `superconvert-ui-data.md` 9.3: the size limit compares the original (or clipping) size.
- `superconvert-ui-data.md` 8.1 / section 3: the "shown dimmed or hidden depending on a setting"
  never hides: the variable MAINE $3F4F is never written, so non-matching files are always dimmed.
- `superconvert-ui-data.md` 10.2: "Print (?????)..." is the ImageWriter LQ command and is removed
  from the menu when LQ.DRIVER cannot be loaded.
- `superconvert-ui-data.md` 11.1, rWindParam1 2: the pop-up (rMenu 9) is titled "Filter: " with
  the items "None" (300) and "Auto    " (301); the scroll bar value plus one is the zlib
  compression level (4.9).
- `superconvert-truecolor.md` 1 (last sentence): when saving, the monochrome windows of section 8
  are only option windows (FroMonoDlg with X = 1); no conversion follows them (4.10).

## 11. Uncertain points

- SFPMultiGet2 / SFPutFile2 / SFGetFile2 parameter names: the values and their order are as pushed;
  the meaning of the first long after whereY in SFPMultiGet2 (0) was assigned by position. Whether
  Standard File honours whereX/whereY or centres the dialog was not checked.
- Type list flags $8000 / $E000 for the Finder icon add dialog (4.8).
- [RezFilter] (icon resource add) and [AskForName] details were not traced.
- "More than one way" (4.10): after a monochrome → screen or monochrome → true color choice only
  the options window runs, and no code was found that converts the monochrome image afterwards.
  The savers then use the screen or true color data as it stands (for PNG: LONGCODE $0F21 /
  $0F3F / $0F41, stale or empty). This looks like a defect of the original and was not tried on a
  machine; MegaconvertGS should convert the monochrome image with the chosen options.
- The colours that SetSolidPenPat($1111) and SetSolidPenPat($FFFF) give the selection frame of
  the 4.10 window were not checked.
- TIFF with Motorola byte order: the scrambled entry order (4.9) was worked out from the code of
  the ORCA/C qsort and DYNAMTIFF $1F79, not checked against a file written by the program.
- PNG: whether TEGetText's length counts the terminating zero (which would then end the tEXt
  chunk) was not checked. The zlib settings other than the level (window, memory level,
  strategy) and libpng's per-row filter choice for "Auto" are the libraries' own and were not
  traced.
- GIF (4.9): the LZW hash probe that runs past its arrays (MAINE $B405, pictures with more than 128
  colours) was followed only with a transcription of the routine; what lies after the $7542-byte
  handle, and so what its stray writes hit on a machine, is not known. The orange of the progress
  bar assumes the standard 640-mode colours.
- Enhanced print: how the x1-x9 / ÷2 scale reaches the paper; the font family $FFFE; where the
  scale label is drawn.
- ImageWriter LQ driver internals.
- Examine file (7): "every file selectable" relies on Standard File's result word (checked in
  System 6.0.4's Tool023 only); zeroSize spacing and pattern alignment were read from ROM 03's
  QuickDraw II; whether a thumb drag calls the scroll action procedure live or once at the end,
  and the blank line at the read buffer's end, were not seen on a machine.
- Colour numbers 1-3 in the dump depend on the desktop palette in use (640 mode).
- GS Remap was not used for this document; nothing here was taken from it.
