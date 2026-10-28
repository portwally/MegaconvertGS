# How MegaconvertGS works

MegaconvertGS is a GS/OS desktop application (type S16) written in 65816 assembly for
Merlin 32. Its code is new; what it follows is SuperConvert 4: its windows, lists, menus,
dialogs and conversions, as read from its program file and documentation (the
`superconvert-*.md` files in this folder). Where GS Remap, a modern reimplementation of
SuperConvert's conversions, has a function, MegaconvertGS matches it pixel for pixel, and
the test suites check that ([BUILDING.md](BUILDING.md)).

## Segments

The program is one OMF load file of several segments, each under 64K: the main program
and one segment each for the Apple II and IIgs loaders, the other computers' loaders, the
save formats, Remap, the main windows (Desk), the True color filters, the views, the
monochrome conversions, the Extras, the help window, printing and TIFF Save Options. A
loader segment is called with `JSL` and finds the file, its length and the picture's
buffers in direct page (`src/Equates.s`); `src/SegLib.s` holds the helpers each loader
segment includes.

## Source layout

- `src/MegaconvertGS.s`: the program: start-up, the menus, loading and saving
- `src/File.s`, `src/Stream.s`: reading and writing files
- `src/Formats.s`: Super Hi-Res formats, and recognising a file (by its type, signature,
  name and size, in that order across the loaders)
- `src/True.s`: true colour pictures and fitting them to the screen
- `src/BMP.s`, `src/GIF.s`, `src/PNG.s` with `src/Inflate.s`, `src/JPEG.s`: modern formats
  (JPEG baseline and progressive: a progressive picture's coefficients are kept block by
  block while its scans add to them, and turned into pixels at the end)
- `src/Apple.s`: Apple II and IIgs formats (a segment of its own), with `src/WOA.s`
  (Works of Art pages, as monochrome images) and `src/Glyphs.s`, the Apple II character
  set drawn from the Print Char 21 font by Kreative Software (`test/glyphs.swift`)
- `src/Other.s` with `src/OtherPC.s`, `src/TIFF.s`, `src/TGA.s` and `src/PICT.s`: the
  other computers' formats (a segment of its own)
- `src/SegLib.s`: helpers each loader segment includes
- `src/Save.s`: the save formats (a segment of its own)
- `src/Screen.s`: full-screen view, and the title picture at start-up
- `src/RemapSeg.s` with `src/RemapRender.s`, `src/RemapUI.s` and `src/UILib.s`: Remap:
  scaling, palettes, rendering, multipalette and the Remap dialog (a segment of its own)
- `src/Desk.s` with `src/DeskLists.s`, `src/FormatInfo.s`, `src/ImgWin.s` and
  `src/ImgData.s`: SuperConvert's main windows: Load formats, Save formats and the image
  window (screen or true colour image, zoom, info bar pop-ups), and the Info on format
  texts (a segment of its own); `test/make_lists.py` makes the lists from SuperConvert's,
  `test/make_imgdata.py` takes the dither table and info bar icons from its program file
- `src/Filter.s` with `src/FilterUI.s`, `src/TrueDlg.s`, `src/FilterTabs.s`,
  `src/FilterMed.s` and `src/FilterData.s`: the True color menu: filters, rotate/flip,
  the Factor, Rotate/flip, image info and progress dialogs (a segment of its own;
  `test/make_filter_tables.py` makes the tables that match GS Remap's arithmetic)
- `src/View.s` with `src/ViewData.s`: View full screen, half size, X4 magnified and
  approximation (a segment of its own)
- `src/ImgTools.s` (in the Desk segment): the image window's tools: selection and its
  marching ants, pixel peek, the pointer's shapes, the tool and action pop-ups, keys, Use
  image's palette; `src/Actions.s` (main program): Crop to selection and Discard
- `src/LoadMulti.s` (in the Desk segment) and `src/LoadConv.s`: Load & convert's file
  dialog (SuperConvert's template, check boxes and file filter) and the load queue
- `src/Extras.s` with `src/SysInfo.s`, `src/Examine.s` and `src/Oscope.s`: Preferences,
  Available font list, More available fonts, Font key chart, the System info report, File >
  Examine file and Screen > Oscilloscope Art (a segment of its own); `src/Prefs.s`: what
  the options change
- `src/SaveDlg.s` and `src/SaveOpts.s` (in the Save segment): Save conversion's size,
  alignment and warning dialogs, Hex data's options, the GIF upload note and progress, the
  Finder icon's criteria; `src/True640.s` (in the Mono segment): Convert to true color's
  640 mode window (Exact or Smoothed)
- `src/MonoSeg.s` with `src/MonoDlg.s` and `src/MonoData.s`: monochrome images: the
  conversions to and from them and their dialogs (a segment of its own;
  `test/make_monodata.py` takes the dialogs' menus and icons from SuperConvert)
- `src/TiffOpt.s`: TIFF Save Options (a segment of its own)
- `src/Test.s`: test commands read from `MC.TEST`
- `src/Equates.s`: toolbox and GS/OS call numbers, direct page, format numbers
- `src/macros/Macs.s`: call and push macros
- `src/link.s`: Merlin 32 link file
- `help/MCGS.Help.txt`: the help text; `art/`: the title picture and the script that adds
  its credits
- `test/`: emulator test scripts and the scripts that make the test pictures;
  `test/speed/`: models and exactness checks for the speed plan

## Reference documents

- `superconvert-ui-data.md` (and `.json` for scripts): SuperConvert's windows, lists,
  menus and dialogs as read from its program file
- `superconvert-image-window.md`: the image window and its views
- `superconvert-truecolor.md`: the True color and Monochrome menus
- `superconvert-file.md`: the File menu
- `superconvert-screens.md`: notes from screenshots of the original, for matching its look
- `superconvert-extras.md`: the Apple, Edit and Extras menus and the extra Screen menu
  commands
- `superconvert-formats-extra.md`: Works of Art, the desktop INIT, New Print Shop and
  Babelfish
- `speed-plan.md`: where the time went, what was changed and the measured gains

## History

- **Milestone 1, the desktop shell:** starts the tools, shows the menu bar and a window,
  About and Quit.
- **Milestone 2:** opens $C1 screens, Apple Preferred, PackBytes and PaintWorks pictures
  (320 and 640 mode); saves as Apple Preferred, $C1 and PackBytes; full-screen view;
  Remap to 320 mode with a calculated palette and pattern dither, matching GS Remap
  exactly.
- **Milestone 3, true colour pictures:** PNG (every colour type and bit depth,
  interlaced, transparency), GIF (87a/89a, interlaced, transparency), BMP (1-32 bits,
  OS/2 and Windows headers) and baseline JPEG (grey or colour, any 1x/2x sampling, restart
  markers). A picture larger than the screen is fitted to it with GS Remap's scale steps
  and box averaging, then remapped.
- **Milestone 4, Apple II and IIgs formats:** HiRes and Double HiRes (colour or black &
  white), Print Shop graphics (and the IIgs colour ones and library), ThunderScan scans,
  TDM text screens, DreamGrafix (256 and 3200 colours), Paintworks Gold, Finder icons, AST
  and ComputerEyes digitizer files, and "3200 color" pictures (plain, ".3201" and
  compressed). Open recognises most of them by type, size or contents.
- **Milestone 5, the other computers' formats:** Atari ST (Degas, Degas Elite,
  Neochrome, Tiny, Spectrum 512 plain and compressed), Amiga IFF (ILBM with HAM, Extra
  HalfBrite and 24-bit, and DeluxePaint PBM), Commodore 64 (Doodle, Koala, Print Shop),
  Macintosh (MacPaint three ways, ScreenMaker), PC (GEM IMG, PC Paintbrush, FliAway
  frames), Unix (Sun Rasterfile, SGI, PBM/PGM/PPM), CompuServe RLE, IPI, QRT and TIFF.
  Black & white pictures taller than a screen become true colour pictures.
- **Milestone 6, save formats:** Apple Preferred, $C1, PackBytes, PaintWorks, Finder
  icons (a new file, or added to one), icon resources (a new resource file, or added to
  one), hex data, GIF, PNG and TIFF. GIF, PNG and TIFF show the picture as GS Remap does,
  with square pixels. Icons use GS Remap's default settings.
- **Milestone 7, Remap modes and options:** SuperConvert's Remap dialog, drawn pixel for
  pixel as the original: the graphic mode (320 x 200 in 16 colours, 640 x 200 in 4, 640
  dither mode, multipalette with a palette for each line), the palette (default, greys,
  calculated, the picture's current one, or another from Get other...), the rendering
  (closest match, pattern dither, error diffusion for grey palettes), the picture's
  distinct colours, and the size in scale steps with two scroll bars and a diagram of the
  size against a grid of screens. Quick remap makes a one-screen preview. Every
  combination matches GS Remap pixel for pixel.
- **Milestone 8, SuperConvert's main screen,** matching the original's start screen pixel
  for pixel: the Load formats window with SuperConvert's ten computer types and their
  formats, icons, Info on format and Load...; the Save formats window; the screen image
  window with its title, info bar and scroll bars; SuperConvert's menu bar. Load & convert
  loads with the chosen format, Re-convert last file loads the same file again, and a
  true colour picture opens the Remap dialog once loaded.
- **Milestone 9, the True color menu and the image window, as SuperConvert's:** the
  filters with exactly GS Remap's results and the original's Factor and progress dialogs;
  Rotate/flip with its turning "UP" preview; True color image info; Convert to true color
  (640 mode screens Exact or Smoothed); the image window's views of the screen, true
  colour and monochrome images; View full screen, half size, X4 magnified and
  approximation; monochrome images (Convert to monochrome, the Monochrome menu, Negative)
  as the original's documented algorithms; Store palette; Use as desktop background and
  Revert to normal desktop; Exchange load/save paths; Copy, Cut and Close; the image
  window's tools (selections with marching ants, pixel peek, SuperConvert's cursors, keys,
  Crop to selection, Discard, Use image's palette); Load & convert with SuperConvert's
  file dialog and filter, folders and the load queue; Preferences (saved in MCGS.Prefs);
  the Extras (font lists, key chart, System info report); Examine file; Save conversion's
  dialogs and the formats' own save windows; Oscilloscope Art; Works of Art pages; the
  desktop background INIT (MegaconvertGS's own INIT, which puts the picture on the
  desktop at start-up from SYSTEM.SETUP); TIFF Save Options; PNG save options; Help! and
  Menu item help with MegaconvertGS's own help text; File > Print alignment page.
- **Speed:** remapping, opening PNG and JPEG files, saving, the monochrome conversions,
  two filters and the image window made faster with the same results
  ([speed-plan.md](speed-plan.md)).
- **Formats SuperConvert didn't have:** Truevision Targa (TGA: colour-mapped, true colour
  and grey, 8 to 32 bits, run-length coded or not) and Macintosh PICT (version 1 and 2,
  with or without the 512-byte header: the bit maps and pixel maps in it, 1 to 32 bits)
  in Load formats and Open, progressive JPEG, and Save as BMP (8 bits with the screen
  image's colours, square pixels as GS Remap's PNG). Open tries TGA and PICT by name (and
  PICT's signature) before the Apple formats' size guesses; a file so named that isn't
  one goes on to the other formats.
- **A title picture at start-up** (`MCGS.Title`, a $C1 screen beside the program: until
  a click, a key or 3 seconds; none if the file isn't there).

## Not done yet

- The Babelfish imports and exports, which the lists show as SuperConvert did.
- SuperConvert's New Print Shop graphics entry is left out of Load formats: SuperConvert
  never loaded it either, and no description of its Apple II files was found.
- Print (normal), Print (enhanced) and Print banner: copying the picture to the printer
  port fails with error $1212 under MAME's System 6.0.4 driver once a page holds more than
  a small area, in strips or tiles alike.
- SuperConvert's "more than one way" window has nothing to ask here: MegaconvertGS's PNG
  saves the screen image, and TIFF Save Options asks for the image itself.
