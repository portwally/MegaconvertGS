# Building and testing MegaconvertGS

## What you need

- [Merlin 32](https://www.brutaldeluxe.fr/products/crossdevtools/merlin/), the 65816
  cross-assembler.
- Python 3 (the build checks labels and makes the title picture).
- For the tests: [MAME](https://www.mamedev.org) from
  [Ample](https://github.com/ksherlock/ample) with its Apple IIgs ROMs, Cadius (to put
  files on the disk image), a System 6.0.4 hard disk image (`System604.img` in the
  project folder, not in the repository), and GS Remap's command-line tool `sc4`
  (`~/Documents/GS Remap/.build/release/sc4`, or `SC4=...`) as the reference.
- For some test pictures: libjpeg's `cjpeg`, `jpegtran` and `djpeg`, and ImageMagick.

## Build

```bash
./build.sh
```

Writes into `build/`:

- `MegaconvertGS`: the application (GS/OS type S16)
- `MCGS.Help`: the help text, from `help/MCGS.Help.txt`
- `MCGS.Title`: the title picture, from `art/MegaconvertGS_Title.shr` with the credits
  drawn in by `art/make_title.py`

All three go in one folder on the IIgs. Set `MERLIN32` if the assembler isn't in
`~/Downloads/Merlin32_v1.2_b2/MacOs/`. The build stops on a local label defined twice
under one global label (`test/labels.py`), which Merlin 32 accepts silently.

## Make the release disk

```bash
./make_disk.sh
```

Makes `build/MegaconvertGS.po`, an 800K ProDOS disk with the three files and their file
types, and the Finder icon in an Icons folder (`art/make_icon.py` draws it and writes
`build/icon-preview.png`; needs Cadius). Run `./build.sh` first.

## Run it in MAME

```bash
./test/run.sh
```

Copies the boot disk (`System604.img`, or `BOOT_DISK=...`), puts MegaconvertGS in place
of the Finder on the copy, boots it in MAME in a window (never full screen: that blanks
the Mac's display), and saves the Super Hi-Res screen every 30 emulated seconds to
`build/test/screens/` (`DUMP_EVERY=...`), as PNG files too. With each screen it records
the text screen, a screenshot and the processor's registers, which shows where a crash
or a hang happened.

- `RUN_SECONDS`: how long to run (emulated seconds, default 240)
- `COMMANDS`: a test command file (see `src/Test.s`), copied to the disk as `MC.TEST`;
  its pictures come from `build/fixtures` and results go to the folder `MCOUT`, copied
  back to `build/test/results`. A run stops by itself once the commands are done.
- `KEYS`: keys to press at given times, e.g. `60:SU,62:return` (see `test/dump.lua`)
- `UI_PICTURE`, `UI_TYPE`: a picture put at the top of the disk as `SUNSET`
- `TITLE=1`: the title picture beside the program (the test suites start without it)

## Tests

Make the test pictures once:

```bash
./test/fixtures.sh
```

Then run every suite, one after the other (each suite's report goes to
`build/suite_*.txt`):

```bash
./test/all.sh
```

or one of them, e.g.:

```bash
./test/true.sh
```

Each suite checks what MegaconvertGS does against GS Remap (pixel for pixel or byte for
byte) or against a model written from SuperConvert's documented behaviour:

- `basic` loads and saves every supported format; `remap` compares Remap with GS Remap;
  `ui` opens and saves a picture through the menus and file dialogs.
- `true` makes 50 PNG, GIF, BMP and JPEG (baseline and progressive) test pictures
  covering each variant of each format (`test/make_true.py`, JPEGs with `cjpeg`), loads
  them all, and checks the decoded pixels against GS Remap (JPEG against libjpeg's
  `djpeg`, as JPEG decoders round differently), the fitted size, and the remapped
  screen. It logs each load time.
- `apple` makes a test file for each Apple II and IIgs format (`test/make_apple.py`),
  loads each by its format and, where Open can tell, by itself, and compares the screens
  and pictures with GS Remap. `other` does the same for the other computers' formats
  (`test/make_other.py`; TIFF files made with ImageMagick).
- `newfmt` loads MegaconvertGS's own formats from test files written from known pixels
  (`test/make_newfmt.py`): every TGA kind and depth, run-length coded or not, either row
  order; PICT version 1 and 2, bit maps and pixel maps of 1 to 32 bits with each kind of
  packing, bands, scaling and the drawing commands passed over; ZX Spectrum screens with
  every ink, paper and bright, and without colours; MSX Screen 2 with its own name
  table, Screen 5 with the file's palette and without it, Screen 7 and Screen 8; Amstrad
  CPC screens in each mode, with and without the AMSDOS header; C64 Art Studio and
  Advanced Art Studio pictures. Plus a
  TGA from `sips` and two PICTs from ImageMagick. Each is loaded by its format and by
  itself, and checked pixel for pixel (the screen images in the saved screen's colours).
- `save` saves several pictures in every save format and compares the files with GS
  Remap's, made by `test/sc4save` (a small tool on GS Remap's engine, built with Swift).
- `remap2` remaps pictures with each graphic mode, palette, rendering and some scale
  steps (`test/remap2_list.py`) and compares the screens with GS Remap's (`sc4remap`, also
  in `test/sc4save`); it logs each remap's time. It also covers Store palette and Remap's
  Stored palette choice.
- `dialog` works the Remap dialog with clicks given by the test (the `CLICKS` command:
  modes, palettes, Get other..., the scroll bars, Fit, Quick remap and Cancel) and
  compares each result with GS Remap's for the options the clicks chose.
- `desk` works the main windows with the mouse (the `CLICK` command puts clicks in the
  event queue, as the mouse would): it chooses a computer type, asks for Info on format,
  double-clicks a format to load a picture through the file dialog, chooses a save
  format, saves with Save..., and compares the file with GS Remap's.
- `filters` runs every True color filter (several factors each) and every rotate/flip on
  test pictures (`test/make_filter.py`) with the `FILTER` and `TURN` commands, and
  compares each result with GS Remap's (`sc4filter` in `test/sc4save`) byte for byte.
- `mono` makes monochrome images with each rendering method and size, turns them back
  into screen and true colour images with every aspect, scaling, mode and shrink choice,
  and checks each against `test/mono_model.py` (SuperConvert's conversions as
  `docs/superconvert-truecolor.md` describes them).
- `desktop` checks the desktop message Use as desktop background leaves (`SAVE DESK`)
  against the original's layout, Revert to normal desktop, and a view and a filter chosen
  from the menus.
- `paths` works the file dialogs with Return and checks the folders they open in, before
  and after Exchange load/save paths.
- `edit` copies and cuts screen images to the Clipboard, draws the Clipboard's picture
  back (`SAVE SCRAP`) and compares it with the image, and checks which images Cut and
  Close leave.
- `tools` works the image window's tools through the `DESK` command: selections, the
  pointer's shapes, keys, pixel peek, Copy of a selection, Crop to selection of each image
  type, Discard, Use image's palette and Apple-w.
- `loadconv` opens Load & convert's dialog, rates the test folders' files with many
  formats' filters (the `QUEUE` command) against `test/loadconv_list.py`'s model of
  SuperConvert's filter, and loads the queue with Load next.
- `prefs` saves and reads back the Preferences file and checks the dialog keeps the
  options. `extras` makes the font list pages and the key chart.
- `smooth` converts a 640 mode screen to true colour both ways (Exact as GS Remap,
  Smoothed against `test/smooth_model.py`) and checks the window's choice is kept.
- `savedlg` answers Save conversion's dialogs (`SAVEDLG`: size, alignment, warning) and
  compares the files with `test/savedlg_model.py`'s pictures; with `SAVEDLG 3` it also
  goes through the formats' own windows (Hex data's options, the GIF upload note and
  progress, the Finder icon's criteria).
- `sysinfo` saves the System info report as text and checks its sections and figures.
- `examine` opens Examine file's window on several files (`EXAMINE`) and checks each
  saved screen against the files' bytes: every dump cell, scrolled lines, the
  histogram's bars, scales and info line.
- `oscope` makes Oscilloscope Art of a 320 and a 640 mode screen and compares them with
  `test/check_oscope.py`'s model byte for byte.
- `woa` loads the two pages of a Works of Art test file (`test/make_woa.py`) as
  monochrome images and refuses three damaged copies.
- `deskinit` saves desktop background INITs and checks each as an OMF load file holding
  MegaconvertGS's own INIT and the packed desktop message.
- `help` works the help window; `tiffopt` the TIFF Save Options.

`test/timing.sh` times saves, filters and the monochrome conversions (the `TIMING 1` test
command logs each command's ticks); `test/speed/` holds the models and exactness checks
for the speed plan.
