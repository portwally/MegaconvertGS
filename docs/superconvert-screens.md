# SuperConvert 4 screens (reference)

Notes from screenshots of the original SuperConvert 4, for matching its look in
MegaconvertGS. The desktop is in 640 mode.

## Menu bar

File, Edit, Screen, True color, Monochrome, Windows, Extras. Screen, True color and
Monochrome are dimmed until there is such a picture.

### File

- Load & convert... (Command-L)
- Re-convert last file (Command-R)
- Load next (Command-N) — dimmed unless several files were chosen
- Cancel remaining files — dimmed likewise
- Save conversion... (Command-S)
- Exchange load/save paths
- (line)
- Print (normal)...
- Print (enhanced)... (Command-P)
- Print alignment page...
- (line)
- Examine file...
- (line)
- Quit (Command-Q)

### Screen

- Screen image info... (Command-I)
- Convert to true color...
- Convert to monochrome...
- (line)
- View full screen (Command-F)
- View half size (Command-H)
- View X4 magnified (Command-4)
- (line)
- Store palette
- Use as desktop background
- Oscilloscope Art

### True color

- True color image info... (Command-T), with a small true colour icon
- Convert to screen (Remap)... (Command-M)
- Convert to monochrome...
- (line)
- View approximation (Command-A)
- (line)
- Rotate/flip image...
- Histogram equalization...
- Median filter
- Sigma filter
- Emboss image
- Blur image...
- Sharpen image...
- Solarize image
- Find edges...
- Increase contrast
- Decrease contrast

## Windows

- Load formats (top left): a list of computer types with folder icons (Apple II
  family, Apple IIgs specific, Atari ST, Amiga, Commodore 64/128, Macintosh, IBM PC &
  compatibles, ...), then "Computer type" (white on black), the buttons "Info on
  format" and "Load...", "Specific type" (white on black), and the list of that
  computer's formats with small icons (a screen icon; a coloured one for 3200 colour
  formats), selected rows green.
- Save formats (top right): the buttons "Info on format" and "Save...", and the list of
  save formats ("$C0,0 PaintWorks+ 1.0 (obsolete)", "$C0,1 PackBytes (obsolete)", "$C0,2
  Apple Preferred", "$C1 uncompressed screen", "Finder icon (new file)", ...).
- Screen image (bottom right, after loading): title "NAME (320, 1)", an info bar with
  tool pop-ups (magnifier, selection) and "Image: 320 x 200", and the picture drawn in
  the 640 mode desktop's colours, with scroll bars.

## Dialogs

- Load & convert: "Select file(s) to load and convert:", the folder pop-up, the file
  list, buttons Volumes, Accept, Open, Close, Cancel, and two check boxes: "Load all
  pictures within selected folders", "Allow files to be selected regardless of type".
- True color image info: "Image size: 320 by 200", "Distinct colors: 89",
  "Distribution: full color", a graph of frequency against intensity (0 to F) with a
  red, a green and a dotted (blue) line, and the buttons Print and Done (default).
- Remap: see src/RemapUI.s (drawn from a screenshot, pixel for pixel).
