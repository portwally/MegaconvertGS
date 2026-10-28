# MegaconvertGS

An image converter for the Apple IIgs, written in 65816 assembly for GS/OS.

## Build

Needs [Merlin 32](https://www.brutaldeluxe.fr/products/crossdevtools/merlin/).

```bash
./build.sh
```

Writes the application to `build/MegaconvertGS` (GS/OS type S16). Set `MERLIN32` if the
assembler isn't in `~/Downloads/Merlin32_v1.2_b2 2/MacOs/`.

## Test

```bash
./test/run.sh
```

Copies the boot disk (`System604.img` by default, or `BOOT_DISK=...`), puts MegaconvertGS
in place of the Finder on the copy, boots it in MAME from Ample in a window, and saves the
Super Hi-Res screen every 30 emulated seconds to `build/test/screens/`. Needs cadius, and
the GS Remap command-line tool (`SC4=...`) to turn the screen dumps into PNG files.

Checks against GS Remap (run `./test/fixtures.sh` once first to make the test pictures):

```bash
COMMANDS=test/basic.test RUN_SECONDS=90 ./test/run.sh && python3 test/check_basic.py
```

```bash
COMMANDS=test/remap.test ./test/run.sh && python3 test/check_remap.py
```

```bash
./test/ui.sh
```

```bash
./test/true.sh
```

```bash
./test/apple.sh
```

```bash
./test/other.sh
```

```bash
./test/save.sh
```

```bash
./test/remap2.sh
```

```bash
./test/dialog.sh
```

```bash
./test/desk.sh
```

```bash
./test/filters.sh
```

```bash
./test/mono.sh
```

```bash
./test/desktop.sh
```

```bash
./test/paths.sh
```

```bash
./test/edit.sh
```

```bash
./test/tools.sh
```

```bash
./test/loadconv.sh
```

```bash
./test/prefs.sh
```

```bash
./test/extras.sh
./test/smooth.sh
./test/savedlg.sh
./test/sysinfo.sh
./test/examine.sh
./test/oscope.sh
./test/woa.sh
./test/deskinit.sh
```

Or all of them, one after the other (each suite's report goes to `build/suite_*.txt`):

```bash
./test/all.sh
```

`basic` loads and saves every supported format, `remap` compares Remap with GS Remap
pixel for pixel, and `ui` opens and saves a picture through the menus and file dialogs.
`true` makes 46 PNG, GIF, BMP and JPEG test pictures covering each variant of each
format (`test/make_true.py`, JPEGs with `cjpeg`), loads them all, and checks the decoded
pixels against GS Remap (JPEG against libjpeg's `djpeg`, as JPEG decoders round
differently), the fitted size, and the remapped screen. It also logs each load time.
`apple` makes a test file for each Apple II and IIgs format (`test/make_apple.py`),
loads each by its format and, where Open can tell, by itself, and compares the screens
and pictures with GS Remap. `other` does the same for the other computers' formats
(`test/make_other.py`; TIFF files made with ImageMagick). The test runner also records
the text screen, a screenshot and the processor's registers with each screen dump, which
shows where a crash or a hang happened. `save` saves several pictures in every save
format and compares the files with GS Remap's, made by `test/sc4save` (a small tool on
GS Remap's engine, built with Swift). `remap2` remaps pictures with each graphic mode,
palette, rendering and some scale steps (`test/remap2_list.py`) and compares the screens
with GS Remap's (`sc4remap`, also in `test/sc4save`); it logs each remap's time.
`dialog` works the Remap dialog with clicks given by the test (the `CLICKS` test command:
modes, palettes, Get other..., the scroll bars, Fit, Quick remap and Cancel) and compares
each result with GS Remap's for the options the clicks chose. `desk` works the main
windows with the mouse (the `CLICK` test command moves the pointer and puts clicks in the
event queue, as the mouse would): it chooses a computer type, asks for Info on format,
double-clicks a format to load a picture through the file dialog, chooses a save format,
saves with Save..., and compares the file with GS Remap's. `filters` runs every True
color filter (several factors each) and every rotate/flip on test pictures (random noise,
a picture one pixel wide, one one pixel high, a smooth one; `test/make_filter.py`) with
the `FILTER` and `TURN` test commands, and compares each result with GS Remap's
(`sc4filter` in `test/sc4save`) byte for byte. `mono` makes monochrome images from a
grey and a colour picture with each rendering method and size, turns them back into
screen and true colour images with every aspect, scaling, mode and shrink choice, and
checks each against `test/mono_model.py` (SuperConvert's conversions as
`docs/superconvert-truecolor.md` describes them). `remap2` also covers Store palette and
Remap's Stored palette choice. `desktop` checks the desktop message Use as desktop
background leaves (`SAVE DESK`) against the original's layout, Revert to normal desktop,
and a view and a filter chosen from the menus. `paths` works the file dialogs with Return
and checks the folders they open in, before and after Exchange load/save paths. `edit`
copies and cuts screen images to the Clipboard, draws the Clipboard's picture back
(`SAVE SCRAP`) and compares it with the image, and checks which images Cut and Close
leave. `tools` works the image window's tools through the `DESK` test command (drags in
content coordinates): selections (new, moved, corners, edges, at 2X zoom, a double
click), the pointer's shapes, the keys that bring a part into view, pixel peek, Copy of a
selection, Crop to selection of each image type (against crops made by the checker),
Discard this and other image types, Use image's palette (the hardware's line modes and
colour tables) and Apple-w. `loadconv` opens Load & convert's dialog and loads with
Return, rates the test folders' files with many formats' filters (the `QUEUE` test
command adds a folder as "Load all pictures within selected folders" does) against
`test/loadconv_list.py`'s model of SuperConvert's filter, and loads the queue with Load
next. `prefs` saves and reads back the Preferences file and checks the dialog keeps the
options. `extras` makes the font list pages and the key chart. `smooth` converts a 640
mode screen to true colour both ways (Exact as GS Remap, Smoothed against
`test/smooth_model.py`) and checks the window's choice is kept. `savedlg` answers Save
conversion's dialogs (`SAVEDLG`: size, alignment, warning) and compares the files with
`test/savedlg_model.py`'s pictures; with `SAVEDLG 3` it also goes through the formats' own
windows (Hex data's options, the GIF upload note and progress, the Finder icon's criteria)
and checks what they write. `sysinfo` saves the System info report as text and
checks its sections and figures. `examine` opens Examine file's window on several files
(`EXAMINE`: mode buttons, scroll bar parts, the pointer over the histogram) and checks
each saved screen against the files' bytes: every dump cell's character and colours,
scrolled lines against lines drawn afresh, the histogram's bars, scales and info line.
`oscope` makes Oscilloscope Art of a 320 and a 640 mode screen and compares them with
`test/check_oscope.py`'s model byte for byte. `woa` loads the two pages of a Works of Art
test file (`test/make_woa.py`, the documentation's example) as monochrome images and refuses
three damaged copies. `deskinit` saves desktop background INITs and checks each as an OMF
load file holding MegaconvertGS's own INIT and the packed desktop message. The build stops on a local label defined twice
under one global label (`test/labels.py`), which Merlin 32 accepts silently.
A test run stops by itself once the test commands are done.

## Layout

- `src/MegaconvertGS.s` — the program: the menus, loading and saving
- `src/File.s`, `src/Stream.s` — reading and writing files
- `src/Formats.s` — Super Hi-Res formats
- `src/True.s` — true colour pictures and fitting them to the screen
- `src/BMP.s`, `src/GIF.s`, `src/PNG.s` with `src/Inflate.s`, `src/JPEG.s` — modern formats
- `src/Apple.s` — Apple II and IIgs formats (a segment of its own), with `src/WOA.s`
  (Works of Art pages, as monochrome images) and `src/Glyphs.s`,
  the Apple II character set drawn from the Print Char 21 font by Kreative Software
  (`test/glyphs.swift`)
- `src/Other.s` with `src/OtherPC.s` and `src/TIFF.s` — the other computers' formats (a
  segment of its own)
- `src/SegLib.s` — helpers each loader segment includes
- `src/Save.s` — the save formats (a segment of its own)
- `src/Screen.s` — full-screen view
- `src/RemapSeg.s` with `src/RemapRender.s`, `src/RemapUI.s` and `src/UILib.s` — Remap:
  scaling, palettes, rendering, multipalette and the Remap dialog (a segment of its own)
- `src/Desk.s` with `src/DeskLists.s`, `src/FormatInfo.s`, `src/ImgWin.s` and
  `src/ImgData.s` — SuperConvert's main windows: Load formats, Save formats and the image
  window (screen or true colour image, zoom, info bar pop-ups), and the Info on format
  texts (a segment of its own); `test/make_lists.py` makes the lists from SuperConvert's,
  `test/make_imgdata.py` takes the dither table and info bar icons from its program file
- `src/Filter.s` with `src/FilterUI.s`, `src/TrueDlg.s`, `src/FilterTabs.s`,
  `src/FilterMed.s` and `src/FilterData.s` — the True color menu: filters, rotate/flip,
  the Factor, Rotate/flip, image info and progress dialogs (a segment of its own;
  `test/make_filter_tables.py` makes the tables that match GS Remap's arithmetic)
- `src/View.s` with `src/ViewData.s` — View full screen, half size, X4 magnified and
  approximation (a segment of its own)
- `src/ImgTools.s` (in the Desk segment) — the image window's tools: selection and its
  marching ants, pixel peek, the pointer's shapes, the tool and action pop-ups, keys, Use
  image's palette; `src/Actions.s` (main program) — Crop to selection and Discard
- `src/LoadMulti.s` (in the Desk segment) and `src/LoadConv.s` — Load & convert's file
  dialog (SuperConvert's template, check boxes and file filter) and the load queue
- `src/Extras.s` with `src/SysInfo.s`, `src/Examine.s` and `src/Oscope.s` — Preferences,
  Available font list, More available fonts, Font key chart, the System info report, File >
  Examine file and Screen > Oscilloscope Art (a segment of its own); `src/Prefs.s` — what
  the options change
- `src/SaveDlg.s` and `src/SaveOpts.s` (in the Save segment) — Save conversion's size,
  alignment and warning dialogs, Hex data's options, the GIF upload note and progress, the
  Finder icon's criteria; `src/True640.s` (in the Mono segment) — Convert to true color's 640 mode
  window (Exact or Smoothed)
- `src/MonoSeg.s` with `src/MonoDlg.s` and `src/MonoData.s` — monochrome images: the
  conversions to and from them and their dialogs (a segment of its own;
  `test/make_monodata.py` takes the dialogs' menus and icons from SuperConvert)
- `src/Test.s` — test commands read from `MC.TEST`
- `src/Equates.s` — toolbox and GS/OS call numbers
- `src/macros/Macs.s` — call and push macros
- `src/link.s` — Merlin 32 link file
- `test/` — emulator test scripts; `test/speed/` — models and exactness checks for the
  speed plan
- `docs/` — SuperConvert as read from its program file: windows, lists, menus and
  dialogs (`superconvert-ui-data.md`, and `.json` for scripts), the image window and its
  views (`superconvert-image-window.md`), the True color and Monochrome menus
  (`superconvert-truecolor.md`), the File menu (`superconvert-file.md`); and the speed
  plan (`speed-plan.md`)

## Status

- Milestone 1, the desktop shell: starts the tools, shows the menu bar and a window,
  About and Quit.
- Milestone 2: opens $C1 screens, Apple Preferred, PackBytes and PaintWorks pictures
  (320 and 640 mode); saves as Apple Preferred, $C1 and PackBytes; full-screen view;
  Remap to 320 mode with a calculated palette and pattern dither, matching GS Remap
  exactly.
- Milestone 3: true colour pictures. Opens PNG (every colour type and bit depth,
  interlaced, transparency), GIF (87a/89a, interlaced, transparency), BMP (1-32 bits,
  OS/2 and Windows headers) and baseline JPEG (grey or colour, any 1x/2x sampling,
  restart markers). A picture larger than the screen is fitted to it with GS Remap's
  scale steps and box averaging, then remapped.
- Milestone 4: Apple II and IIgs formats. HiRes and Double HiRes (colour or black &
  white), Print Shop graphics (and the IIgs colour ones and library), ThunderScan
  scans, TDM text screens, DreamGrafix (256 and 3200 colours), Paintworks Gold, Finder
  icons, AST and ComputerEyes digitizer files, and "3200 color" pictures (plain, ".3201"
  and compressed). Open recognises most of them by type, size or contents; File >
  Open As reads a file as any format chosen from a list.

- Milestone 5: the other computers' formats. Atari ST (Degas, Degas Elite, Neochrome,
  Tiny, Spectrum 512 plain and compressed), Amiga IFF (ILBM with HAM, Extra HalfBrite and
  24-bit, and DeluxePaint PBM), Commodore 64 (Doodle, Koala, Print Shop), Macintosh
  (MacPaint three ways, ScreenMaker), PC (GEM IMG, PC Paintbrush, FliAway frames), Unix
  (Sun Rasterfile, SGI, PBM/PGM/PPM), CompuServe RLE, IPI, QRT and TIFF. Black & white
  pictures taller than a screen become true colour pictures, fitted to the screen.

- Milestone 6: save formats. File > Save As offers Apple Preferred, $C1, PackBytes,
  PaintWorks, Finder icons (a new file, or added to one), icon resources (a new resource
  file, or added to one), hex data, GIF, PNG and TIFF. GIF, PNG and TIFF show the picture
  as GS Remap does, with square pixels. Icons use GS Remap's default settings.

- Milestone 7: Remap modes and options. Screen > Remap... opens SuperConvert's Remap
  dialog, drawn pixel for pixel as the original: the graphic mode (320 x 200 in 16
  colours, 640 x 200 in 4, 640 dither mode, multipalette with a palette for each line),
  the palette (default, greys, calculated, the picture's current one, or one of each
  mode's other palettes, or multipalette's techniques, from Get other...), the rendering
  (closest match, pattern dither, error diffusion for grey palettes), the picture's
  distinct colours, and the size in scale steps across and down with two scroll bars and
  a diagram of the size against a grid of screens. Quick remap makes a one-screen
  preview. The other options are shown greyed out, as MegaconvertGS has them (it always
  clips to one screen), and there is no stored palette yet. Every combination matches GS
  Remap pixel for pixel.

- Milestone 8: SuperConvert's main screen, which matches the original's start screen
  pixel for pixel. The Load formats window lists SuperConvert's ten computer types and
  each one's formats, with its icons (what kind of picture each makes), Info on format (a
  description of each format) and Load...; a double click on a format loads too. The
  Save formats window lists the save formats, with Info on format and Save... (once there
  is a picture). The formats SuperConvert lists that MegaconvertGS doesn't have yet (New
  Print Shop graphics, Works of Art, the desktop background INIT and the Babelfish
  imports and exports) say so, as SuperConvert itself did for New Print Shop graphics.
  The screen image window shows the picture in the desktop's colours, with its name and
  number of colour tables in the title, its size in the info bar, and scroll bars. The
  menu bar is SuperConvert's, with the items MegaconvertGS doesn't have yet dimmed: Load
  & convert loads with the chosen format, Re-convert last file loads the same file
  again, the Windows menu brings back or arranges the windows, and a true colour picture
  opens the Remap dialog once loaded, as in SuperConvert. Load formats takes the place of
  File > Open As, and Save formats of File > Save As.

- Milestone 9 (in progress): the True color menu and the image window, as SuperConvert's.
  The filters (histogram equalization, median, sigma, emboss, blur, sharpen, solarize,
  find edges, increase and decrease contrast) give exactly GS Remap's results, with the
  original's Factor dialog and progress dialog (its apple fills; Command-period stops);
  Rotate/flip has the original's dialog with its turning "UP" preview; True color image
  info shows the original's statistics and colour histograms; afterwards the Remap
  dialog opens, as in SuperConvert. Screen > Convert to true color. The image window shows
  the screen image as SuperConvert does (its bytes as 640 mode pixels) or the true colour
  image (through SuperConvert's dither table), with the info bar's image type and zoom
  pop-ups. View full screen, half size, X4 magnified and approximation work as the
  original's. Monochrome images: Convert to monochrome (from the screen or the true colour
  image: size, error diffusion, pattern dither, 50% threshold or halftone) with the
  original's dialog, the Monochrome menu's info, Convert to screen image and to true color
  (aspect, scaling, mode, shrink) and Negative, as the original's documented algorithms.
  Screen > Store palette and Remap's Stored palette choice; Use as desktop background and
  Extras > Revert to normal desktop (a Window Manager desktop message, as the original
  made it); File > Exchange load/save paths (each file dialog opens in the folder of the
  last load or save); Edit > Copy and Cut (a QuickDraw II picture and the colour table on
  the Clipboard, with the original's warning for mixed modes or several colour tables)
  and Close (every image goes, as with the image window's close box). The image window's
  tools: selections with marching ants (dragged, moved, resized by their corners and
  edges, snapped to whole bytes or pixels, kept for each image type), pixel peek with the
  original's texts, the pointer's shapes (SuperConvert's cursors), the keys 1-9 and space,
  Crop to selection and Discard this or other image types, Use image's palette, and
  Copy of a selection. Load & convert with SuperConvert's file dialog: its file filter for
  the chosen format, several files at once and folders' pictures ("Load all pictures
  within selected folders"), Load next and Cancel remaining files, and the Load next
  button. Preferences (saved in MCGS.Prefs): viewing screen images full screen after
  loading, the Remap dialog's rules, automatic save after loading and load next after
  saving. Extras: Available font list, More available fonts and Font key chart.
  Convert to true color's 640 mode window (Exact, or Smoothed as the original blends).
  Save conversion's dialogs: the picture's size (one screen, two screens high or wide, a
  page, the selection) and alignment, and the warnings (640 mode, several colour tables,
  dithering) before saving. Extras > System info report (memory, load files, tool sets,
  versions, battery RAM; Save as text file). File > Examine file: any files, one after
  another, as hex and text (data or resource fork, scrolled with the scroll bar or the
  arrow keys) or as a histogram of the byte values with the original's info line. The
  formats' own save windows: Hex data's options (what goes before, between and after the
  bytes, with a live sample line), the GIF upload note that stays up as the progress bar,
  and the Finder icon's criteria (file type, aux type, name, the program to run). Screen >
  Oscilloscope Art. Works of Art pages (Springboard Publisher), chosen in the original's page
  window, become monochrome images; with only a monochrome or true colour image, Save
  conversion and the Screen menu make a screen image first (Convert to screen or Remap), as
  the original does. Save as Desktop background image INIT: MegaconvertGS's own INIT, which
  puts the picture on the desktop at start-up from SYSTEM.SETUP.

Help! and Menu item help, with MegaconvertGS's own help text (`help/MCGS.Help.txt`, built
into `build/MCGS.Help`, which goes beside the program). File > Print alignment page.

Next: Print (normal) and (enhanced) (copying the picture to the printer port fails with
error $1212 under MAME's System 6.0.4 driver, except for small areas), Print banner, the
PNG and TIFF save options and the "more than one way" window, then speed (`docs/speed-plan.md`: box averaging without division, faster rendering and
palette search) and progressive JPEG.
