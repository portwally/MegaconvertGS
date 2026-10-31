# Makes the MegaconvertGS manual: build/manual/manual.html from the screenshots in
# build/manual/shots (docs/manual/shots.sh) and the program's own format lists and Info
# on format texts (formats.py); docs/manual/shots.sh then prints it to PDF with Chrome.
#   python3 docs/manual/make_manual.py
import html, os, re, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from formats import load_lists, info_texts, ROOT

SHOTS = os.path.join(ROOT, "build", "manual", "shots")
OUT = os.path.join(ROOT, "build", "manual", "manual.html")
VERSION = re.search(r"MegaconvertGS (\d+\.\d+)", open(os.path.join(ROOT, "src", "MegaconvertGS.s"), encoding="latin-1").read()).group(1)

def esc(t): return html.escape(t)

WINDOWS = ("DESK", "WIN", "HELP", "EXAM", "BF", "REMAPDLG", "PREFS", "SAVEINFO", "TITLE")
TRIM = os.path.join(ROOT, "build", "manual", "trim")

def trimmed(path, name):
    """A picture fitted smaller than the screen: its black right and bottom margins
    cut off (windows stay whole)."""
    import subprocess
    if name.startswith(WINDOWS): return path
    os.makedirs(TRIM, exist_ok=True)
    out = os.path.join(TRIM, name + ".png")
    if re.fullmatch(r"R0FIT|R320[CPD]|R640[DX]|RMULTI|RGREY|RDEF|F(BLUR|EDGES|EMBOSS|EQUAL|MIRROR|MORE|SHARP|SOLAR)", name):
        # (the photo fitted: 256 x 192, all alike)
        subprocess.run(["magick", path, "-crop", "512x384+0+0", "+repage", out], check=True)
        return out
    box = subprocess.run(["magick", path, "-fuzz", "4%", "-format", "%@", "info:"], capture_output=True, text=True).stdout
    m = re.match(r"(\d+)x(\d+)\+(\d+)\+(\d+)", box)
    if not m: return path
    w, h, x, y = map(int, m.groups())
    W, H = x + w, y + h
    if W >= 620 and H >= 390: return path           # (fills the screen: as it is)
    subprocess.run(["magick", path, "-crop", f"{W}x{H}+0+0", "+repage", out], check=True)
    return out

def img(name, caption=None, cls="shot"):
    path = os.path.join(SHOTS, name + ".png")
    if os.path.exists(path): path = trimmed(path, name)
    if not os.path.exists(path):
        return f'<div class="missing">[{esc(name)}]</div>'
    cap = f"<figcaption>{caption}</figcaption>" if caption else ""
    return f'<figure class="{cls}"><img src="{path}" alt="">{cap}</figure>'

def grid(items, cols=3):
    cells = "".join(img(n, c, "cell") for n, c in items)
    return f'<div class="grid g{cols}">{cells}</div>'

def tip(text, kind="Tip"): return f'<aside class="tip"><b>{kind}</b> {text}</aside>'

KIND = {1: ("screen", "Screen image"), 2: ("true", "True color image"), 3: ("both", "Screen and true color"),
        4: ("mono", "Monochrome image")}

def format_reference():
    types, saves = load_lists()
    fmt, sav = info_texts()
    out = []
    for tname, fs in types:
        out.append(f'<section class="fmtgroup"><h3>{esc(tname)}</h3>')
        for name, n, icon in fs:
            text = fmt.get(n) or ""
            parts = [esc(p) for p in text.split("\n")]
            body = "".join(f"<p>{p}</p>" for p in parts if p)
            k, label = KIND.get(icon, ("", ""))
            out.append(f'<div class="fmt"><div class="fmthead"><span class="name">{esc(name)}</span>'
                       f'<span class="kind {k}">{label}</span></div>{body}</div>')
        out.append("</section>")
    saves_html = []
    for name, n, icon in saves:
        text = sav.get(n) or ""
        body = "".join(f"<p>{esc(p)}</p>" for p in text.split("\n") if p)
        saves_html.append(f'<div class="fmt"><div class="fmthead"><span class="name">{esc(name)}</span></div>{body}</div>')
    return "".join(out), "".join(saves_html), types, saves

LOADREF, SAVEREF, TYPES, SAVES = format_reference()
NLOAD = sum(len(f) for _, f in TYPES)

CSS = r"""
@page { size: A4; margin: 18mm 17mm 20mm 17mm;
  @bottom-center { content: counter(page); font: 9pt "Avenir Next", "Helvetica Neue", sans-serif; color: #8a8f98; }
  @top-right { content: "MegaconvertGS __VERSION__ Manual"; font: 8pt "Avenir Next", "Helvetica Neue", sans-serif; color: #b0b4bb; } }
@page cover { margin: 0; @bottom-center { content: none; } @top-right { content: none; } }
:root { --ink: #1d2230; --muted: #5b6272; --line: #e3e6ec; --accent: #3a6df0; --soft: #f4f6fa;
  --r: #e2453c; --o: #f29c2b; --y: #f2c81f; --g: #57b65a; --b: #3a8ee6; --v: #8e5bd6; }
* { box-sizing: border-box; }
html { -webkit-print-color-adjust: exact; print-color-adjust: exact; }
body { margin: 0; color: var(--ink); font: 10.2pt/1.5 "Avenir Next", "Helvetica Neue", Helvetica, sans-serif; }
h1, h2, h3 { font-family: "Avenir Next", "Helvetica Neue", sans-serif; letter-spacing: -0.01em; }
h1 { font-size: 26pt; font-weight: 700; margin: 0 0 4mm; line-height: 1.15; }
h1 .num { display: block; font-size: 10pt; font-weight: 600; color: var(--accent); letter-spacing: 0.12em; text-transform: uppercase; margin-bottom: 2mm; }
h2 { font-size: 15pt; font-weight: 650; margin: 7mm 0 2mm; break-after: avoid; }
h3 { font-size: 12pt; font-weight: 650; margin: 5mm 0 1.5mm; break-after: avoid; }
p { margin: 0 0 2.6mm; }
.chapter { break-before: page; }
.chapter > .lead { font-size: 12pt; color: var(--muted); margin-bottom: 6mm; max-width: 150mm; }
.rainbow { height: 5px; border-radius: 3px; margin: 0 0 6mm;
  background: linear-gradient(90deg, var(--g) 0 16.6%, var(--y) 16.6% 33.3%, var(--o) 33.3% 50%, var(--r) 50% 66.6%, var(--v) 66.6% 83.3%, var(--b) 83.3%); width: 42mm; }
figure { margin: 3mm 0 5mm; break-inside: avoid; }
figure img { width: 100%; display: block; image-rendering: pixelated; border-radius: 6px; }
figure.shot { width: 132mm; margin-left: auto; margin-right: auto; }
figure.wide { width: 100%; }
figcaption { font-size: 8.8pt; color: var(--muted); margin-top: 2.2mm; text-align: center; }
.grid { display: grid; gap: 4mm 4mm; margin: 3mm 0 5mm; }
.g2 { grid-template-columns: 1fr 1fr; } .g3 { grid-template-columns: 1fr 1fr 1fr; } .g4 { grid-template-columns: repeat(4, 1fr); }
.grid figure { margin: 0; }
.grid figure img { border-radius: 4px; }
.tip { background: var(--soft); border-left: 3px solid var(--accent); border-radius: 0 6px 6px 0; padding: 2.6mm 4mm; margin: 3mm 0 4mm; font-size: 9.6pt; break-inside: avoid; }
.tip b { color: var(--accent); margin-right: 1.5mm; }
.tip.warn { border-left-color: var(--o); } .tip.warn b { color: #c47a12; }
table { border-collapse: collapse; width: 100%; font-size: 9.4pt; margin: 2mm 0 5mm; break-inside: auto; }
th { text-align: left; font-weight: 650; border-bottom: 1.5px solid var(--ink); padding: 1.6mm 2mm; }
td { border-bottom: 1px solid var(--line); padding: 1.6mm 2mm; vertical-align: top; }
tr { break-inside: avoid; }
kbd { font: 8.6pt "SF Mono", Menlo, monospace; background: #fff; border: 1px solid #cfd4dc; border-bottom-width: 2px; border-radius: 4px; padding: 0 1.3mm; }
code { font: 8.8pt "SF Mono", Menlo, monospace; background: var(--soft); border-radius: 3px; padding: 0 1mm; }
.steps { counter-reset: s; list-style: none; padding: 0; margin: 2mm 0 4mm; }
.steps li { counter-increment: s; position: relative; padding-left: 9mm; margin-bottom: 2.4mm; }
.steps li::before { content: counter(s); position: absolute; left: 0; top: 0.2mm; width: 5.6mm; height: 5.6mm; border-radius: 50%;
  background: var(--accent); color: #fff; font-size: 8.4pt; font-weight: 700; display: flex; align-items: center; justify-content: center; }
ul.plain { padding-left: 5mm; margin: 1mm 0 4mm; } ul.plain li { margin-bottom: 1.2mm; }
.two { display: grid; grid-template-columns: 1fr 1fr; gap: 6mm; }
/* cover */
.cover { page: cover; height: 297mm; position: relative; overflow: hidden; color: #fff;
  background: linear-gradient(180deg, #1e0395 0%, #1e0395 55%, #10045c 100%); }
.cover .art { position: absolute; left: 0; right: 0; top: 0; }
.cover .art img { width: 100%; display: block; image-rendering: auto; }
.cover .titles { position: absolute; left: 22mm; right: 22mm; bottom: 34mm; }
.cover h1 { font-size: 34pt; margin: 0; color: #fff; }
.cover .sub { font-size: 14pt; color: #d6d2ff; margin-top: 2mm; }
.cover .meta { margin-top: 8mm; font-size: 10pt; color: #aaa3f0; }
.cover .bar { position: absolute; left: 0; right: 0; bottom: 0; height: 10mm;
  background: linear-gradient(90deg, var(--g) 0 16.6%, var(--y) 16.6% 33.3%, var(--o) 33.3% 50%, var(--r) 50% 66.6%, var(--v) 66.6% 83.3%, var(--b) 83.3%); }
/* contents */
.toc { columns: 1; font-size: 11pt; }
.toc a { color: var(--ink); text-decoration: none; display: flex; padding: 1.6mm 0; border-bottom: 1px dotted #cfd4dc; }
.toc a .n { width: 10mm; color: var(--accent); font-weight: 650; }
.toc a .pg { margin-left: auto; color: var(--muted); }
.toc .sub a { font-size: 9.6pt; padding: 0.9mm 0 0.9mm 10mm; border-bottom: none; color: var(--muted); }
/* format reference */
.fmtgroup { break-inside: auto; }
.fmtgroup h3 { border-bottom: 2px solid var(--ink); padding-bottom: 1mm; margin-top: 7mm; }
.fmt { break-inside: avoid; padding: 2.2mm 0 1.6mm; border-bottom: 1px solid var(--line); font-size: 9.2pt; }
.fmt p { margin: 0 0 1.2mm; }
.fmthead { display: flex; align-items: baseline; gap: 2mm; margin-bottom: 1mm; }
.fmthead .name { font-weight: 650; font-size: 10pt; }
.kind { margin-left: auto; font-size: 7.6pt; font-weight: 600; letter-spacing: .04em; text-transform: uppercase; border-radius: 10px; padding: 0.3mm 2.2mm; white-space: nowrap; }
.kind.screen { background: #e6effd; color: #2556c4; } .kind.true { background: #fdeee2; color: #b45b10; }
.kind.both { background: #ece8fb; color: #5b3fb8; } .kind.mono { background: #ececec; color: #444; }
.new { font-size: 7.4pt; font-weight: 700; color: #fff; background: var(--g); border-radius: 10px; padding: 0.2mm 1.8mm; text-transform: uppercase; letter-spacing: .05em; }
.missing { border: 1px dashed #d55; color: #d55; padding: 6mm; text-align: center; margin: 3mm 0; font-size: 9pt; }
.small { font-size: 8.8pt; color: var(--muted); }
""".replace("__VERSION__", VERSION)

CHAPTERS = [
    ("start", "1", "Welcome"),
    ("tour", "2", "A guided tour"),
    ("images", "3", "The image window"),
    ("remap", "4", "Remapping true color pictures"),
    ("truecolor", "5", "Filters and effects"),
    ("mono", "6", "Monochrome images"),
    ("batch", "7", "Loading many files"),
    ("saving", "8", "Saving"),
    ("apple2", "9", "Apple II pictures"),
    ("babelfish", "10", "Babelfish"),
    ("extras", "11", "Extras and preferences"),
    ("menus", "12", "Menus and keys"),
    ("loadref", "13", "Load formats reference"),
    ("saveref", "14", "Save formats reference"),
]

def chapter(cid, title, lead, body):
    num = dict((c, n) for c, n, _ in CHAPTERS)[cid]
    return (f'<section class="chapter" id="{cid}"><h1><span class="num">Chapter {num}</span>{title}</h1>'
            f'<div class="rainbow"></div><p class="lead">{lead}</p>{body}</section>')

PAGES = {}
if os.environ.get("PAGES") and os.path.exists(os.environ["PAGES"]):
    PAGES = dict(l.split() for l in open(os.environ["PAGES"]) if l.strip())
toc = "".join(f'<a href="#{c}"><span class="n">{n}</span>{esc(t)}<span class="pg">{PAGES.get(n, "")}</span></a>' for c, n, t in CHAPTERS)

cover = f"""
<section class="cover">
  <div class="art"><img src="{os.path.join(os.path.dirname(os.path.abspath(__file__)), 'cover.png')}" alt=""></div>
  <div class="titles">
    <h1>User manual</h1>
    <div class="sub">Pictures from many computers, converted on the Apple IIgs</div>
    <div class="meta">Version {VERSION} &middot; Walter Tengler &middot; github.com/portwally/MegaconvertGS</div>
  </div>
  <div class="bar"></div>
</section>
<section class="chapter" style="break-before: page"><h1>Contents</h1><div class="rainbow"></div><div class="toc">{toc}</div>
<p class="small" style="margin-top:10mm">MegaconvertGS is a successor to SuperConvert by Jason Harper and Ian Brumby, published with
the kind permission of Ian Brumby. Babelfish is a trademark of Seven Hills Software. The sample pictures in this manual come
from Apple IIgs and Apple II software and disks of their time; they belong to their authors.</p></section>
"""

body = []

body.append(chapter("start", "Welcome",
  "MegaconvertGS turns pictures from many computers and file formats into Apple IIgs Super Hi-Res screens, "
  "and saves them in the formats the IIgs and other computers read. It runs under GS/OS on a real Apple IIgs "
  "or in an emulator.", f"""
<p>MegaconvertGS is a new program written from scratch in 65816 assembly. It follows SuperConvert 4, the classic IIgs
converter by Jason Harper and Ian Brumby: the same windows, lists, menus and conversions, so SuperConvert's users feel at
home. Where GS Remap, a modern reimplementation of SuperConvert's arithmetic, has a function, MegaconvertGS gives the
same result pixel for pixel.</p>
<h2>What it does</h2>
<div class="two"><ul class="plain">
<li><b>Opens {NLOAD} load formats</b> from {len(TYPES)} kinds of computer: the Apple II and IIgs, Atari ST and 8-bit, Amiga,
Commodore 64, Macintosh, PC, Unix workstations, Amstrad CPC, MSX, ZX Spectrum and today's PNG, JPEG, GIF, BMP and TIFF.</li>
<li><b>Remaps</b> true color pictures to 320 or 640 mode, 640 dither mode or a palette for every line, with SuperConvert's
palettes and dithering.</li>
<li><b>Filters</b> true color pictures, makes <b>monochrome</b> images and turns them back.</li></ul>
<ul class="plain"><li><b>Saves</b> in {len(SAVES)} formats: Apple Preferred, $C1, PackBytes, PaintWorks, Finder icons, icon
resources, a desktop picture, GIF, PNG, TIFF, BMP and Apple II screens.</li>
<li><b>Batch converts</b> many files or whole folders with Load &amp; convert.</li>
<li><b>Works with Babelfish</b>, Seven Hills' file translators, for even more formats.</li></ul></div>
<h2>What you need</h2>
<ul class="plain"><li>An Apple IIgs with GS/OS System 6 (tested with System 6.0.4), or an emulator: MegaconvertGS is
developed and tested in MAME (most easily run through Ample on the Mac).</li>
<li>Memory: the tests run with 4 MB. Large photographs need more than small screens; true color pictures up to 4096 x 4096
pixels are read when memory allows.</li></ul>
<h2>Installing</h2>
<p>MegaconvertGS comes on an 800K ProDOS disk image, <code>MegaconvertGS.po</code>, from the project's GitHub page.</p>
<ol class="steps">
<li>Boot GS/OS and insert (or mount) the MegaconvertGS disk.</li>
<li>Double-click <b>MegaconvertGS</b> to run it straight from the disk.</li>
<li>To keep it on a hard disk, copy <b>MegaconvertGS</b>, <b>MCGS.Help</b> and <b>MCGS.Title</b> into one folder, and
<b>MCGS.Icons</b> into the disk's <b>Icons</b> folder so the Finder shows its icon.</li></ol>
{tip("On a real IIgs, write the image to a 3.5&quot; disk, or use a FloppyEmu or BlueSCSI. In an emulator, boot your System 6 disk and mount the image as a second drive.")}
{img("DESK0", "MegaconvertGS just after it starts: the Load formats and Save formats windows.")}
"""))

body.append(chapter("tour", "A guided tour",
  "Ten minutes with MegaconvertGS: load a Super Hi-Res picture, look at it, load a photograph, remap it to the screen and save the result.", f"""
<h2>The desktop</h2>
<p>MegaconvertGS opens two windows side by side. <b>Load formats</b> lists the kinds of computer (Computer type) and, below,
the formats of the one chosen (Specific type). <b>Save formats</b> lists what MegaconvertGS can write. A small icon in front
of each format tells what kind of image it gives: a Super Hi-Res <b>screen image</b>, a <b>true color image</b>, both, or a
<b>monochrome image</b>.</p>
{img("DESK1", "Load formats with Apple IIgs specific chosen: SuperHiRes, $C1 screens, DreamGrafix, PaintWorks Gold, Print Shop IIgs, Finder icons and more.")}
<h2>Loading a picture</h2>
<ol class="steps">
<li>In Load formats, click the computer the picture comes from, then its format. Click <b>Info on format</b> to read about it.</li>
<li>Click <b>Load&hellip;</b> (or double-click the format, or choose <b>File &gt; Load &amp; convert&hellip;</b>, <kbd>&#8984;L</kbd>).</li>
<li>The file dialog lists only the files that format can read. Choose one and click Open.</li></ol>
<p>Not sure what a file is? <b>File &gt; Load any picture&hellip;</b> (<kbd>&#8984;O</kbd>) recognises most formats by their file
type, name, size and contents.</p>
{img("WIN1", "An Apple Preferred picture loaded: the image window beside the format windows, its info bar at the top.")}
<h2>Viewing</h2>
<p>The image window shows the picture in the desktop's own colors, as closely as the desktop's 640 mode allows. To see it in
its real colors, choose <b>Screen &gt; View full screen</b> (<kbd>&#8984;F</kbd>); a click or a key returns. <b>View half size</b>
(<kbd>&#8984;H</kbd>) shows a large picture whole, <b>View X4 magnified</b> (<kbd>&#8984;4</kbd>) its pixels.</p>
{grid([("MURDER", "View full screen: the picture as the IIgs shows it."), ("TIGER", "A 320 mode picture with 16 palettes."), ("BEAUTY", "A 640 mode picture.")])}
<h2>Pictures from the IIgs</h2>
<p>Super Hi-Res pictures load as they are, in every variety the IIgs knew: plain and packed screens, PaintWorks,
Apple Preferred, DreamGrafix, "3200 color" pictures with a palette for every line. An Apple Preferred picture larger
than the screen, or with 3200 colors, is read whole as a true color picture and fitted to the screen.</p>
{grid([("BLOOM", "PaintWorks."), ("NEKO", "Apple Preferred, 640 mode."), ("TURRICAN", "Apple Preferred, 352 x 256, fitted."),
       ("TREK", "Apple Preferred with 3200 colors, 800 x 600, fitted."), ("SUNSET", "Apple Preferred with 3200 colors."), ("FOOT", "A Brooks \"3200 color\" picture.")])}
<h2>Loading a photograph</h2>
<p>Pictures with more colors or pixels than the screen holds &mdash; PNG, JPEG, GIF, BMP, TIFF, "3200 color" pictures, Amiga
24-bit IFF and many more &mdash; become a <b>true color image</b>: red, green and blue for every pixel. MegaconvertGS then
fits it to the screen at once, so there is always something to see, and opens the Remap dialog.</p>
{img("WIN2", "A 3200 color photograph loaded as a true color image, fitted to the screen.")}
<h2>Remapping and saving</h2>
<p>In the <b>Remap</b> dialog (also <b>True color &gt; Convert to screen</b>, <kbd>&#8984;M</kbd>) choose the graphic mode, the palette,
how colors are rendered and the size, then click Remap. The next chapter but two explains every choice.</p>
{img("REMAPDLG", "The Remap dialog: graphic mode, palette, rendering, and the size with its scroll bars.")}
<p>To save, choose a format in <b>Save formats</b> and click <b>Save&hellip;</b> (or <b>File &gt; Save conversion&hellip;</b>,
<kbd>&#8984;S</kbd>). Apple Preferred is the IIgs's standard picture file and the best choice for most pictures.</p>
{grid([("R0FIT", "As loaded: fitted to the screen."), ("RMULTI", "Remapped to multipalette with error diffusion."), ("R640D", "Remapped to 640 mode.")])}
"""))

body.append(chapter("images", "The image window",
  "One picture, three ways at once: as a screen image, as a true color image and as a monochrome image. The image window shows any of them.", f"""
<h2>The three kinds of image</h2>
<table><tr><th>Kind</th><th>What it holds</th><th>Made by</th></tr>
<tr><td><b>Screen image</b></td><td>Super Hi-Res pixels, a mode and palette for each line (320 or 640 mode), up to 16 color tables of 16 colors.</td><td>Loading a screen format; Remap; Monochrome &gt; Convert to screen.</td></tr>
<tr><td><b>True color image</b></td><td>Red, green and blue for every pixel, up to 4096 x 4096 pixels.</td><td>Loading a photograph or another true color format; Screen &gt; Convert to true color.</td></tr>
<tr><td><b>Monochrome image</b></td><td>One bit a pixel, black or white.</td><td>Convert to monochrome (Screen or True color menu); Works of Art pages.</td></tr></table>
<p>Choose which kind the window shows with the pop-up at the left of its info bar. The other pop-ups choose the tool, the zoom
and actions.</p>
{grid([("WIN1Z", "Zoomed in: every Super Hi-Res pixel shows."), ("WIN2T", "The true color image shown in the window.")], 2)}
<h2>Tools and actions</h2>
<ul class="plain"><li><b>Selection:</b> drag a rectangle; its marching ants show it. <b>Crop to selection</b> keeps only it; Save's
size choice can save just the selection; Edit &gt; Copy copies it.</li>
<li><b>Pixel peek:</b> point at a pixel to read its color (and its palette entry) in the info bar.</li>
<li><b>Zoom:</b> four steps, from the whole picture to every pixel large.</li>
<li><b>Actions:</b> crop to the selection, discard this kind of image or the others, and <b>Use image's palette</b>, which puts the
picture's own colors on the screen while you look at it.</li></ul>
{img("WIN1S", "A selection in the image window.")}
{tip("The number keys 1-9 and the space bar move around a picture larger than the window.")}
"""))

body.append(chapter("remap", "Remapping true color pictures",
  "Remap turns a true color picture into a Super Hi-Res screen: it picks the colors, chooses how to show the ones the screen can't, and sizes the picture.", f"""
<h2>The graphic mode</h2>
<table><tr><th>Mode</th><th>Resolution</th><th>Colors</th></tr>
<tr><td>320 mode</td><td>320 x 200</td><td>16 colors from 4096, one palette for the whole picture.</td></tr>
<tr><td>640 mode</td><td>640 x 200</td><td>4 colors (pure), the desktop's mode.</td></tr>
<tr><td>640 dither mode</td><td>640 x 200</td><td>4 colors in each column of four, which the eye mixes into more.</td></tr>
<tr><td>Multipalette</td><td>320 x 200</td><td>A palette of 16 for every line: the most colors the IIgs shows without special tricks.</td></tr></table>
{grid([("R320D", "320 mode, error diffusion."), ("R640D", "640 mode, error diffusion."), ("R640X", "640 dither mode, pattern dither."), ("RMULTI", "Multipalette, error diffusion.")], 2)}
<h2>The palette</h2>
<p><b>Calculated</b> finds the best colors for this picture. <b>Default</b> uses the IIgs's standard colors, <b>Greys</b> sixteen
greys. <b>Stored</b> uses the colors kept with Screen &gt; Store palette, and <b>Other&hellip;</b> takes them from another picture
file &mdash; useful when several pictures must share one palette. <b>Current</b> keeps the screen image's own.</p>
{grid([("R320D", "Calculated palette."), ("RDEF", "The default palette."), ("RGREY", "Greys.")])}
<h2>Rendering</h2>
<p><b>Closest color</b> gives each pixel the nearest color; <b>pattern dither</b> mixes neighbors in a regular pattern;
<b>error diffusion</b> spreads each pixel's error to its neighbors for the smoothest look.</p>
{grid([("R320C", "Closest color."), ("R320P", "Pattern dither."), ("R320D", "Error diffusion.")])}
<h2>Size</h2>
<p>The scroll bars in the dialog choose how large the picture comes out, in SuperConvert's scale steps; the diagram shows its size
against the screen. A picture larger than the screen is fitted to it when it loads. <b>Quick remap</b> makes a fast preview.</p>
{tip("Remapping never changes the true color image: try as many modes and palettes as you like, then save the one you prefer.")}
"""))

body.append(chapter("truecolor", "Filters and effects",
  "The True color menu changes the true color picture itself. Remap afterwards to see and save the result.", f"""
<table><tr><th>Command</th><th>What it does</th></tr>
<tr><td>Histogram equalization</td><td>Spreads the picture's brightness over the whole range: dull pictures gain contrast.</td></tr>
<tr><td>Median filter, Sigma filter</td><td>Remove noise; Sigma keeps edges sharper.</td></tr>
<tr><td>Emboss image</td><td>Makes the picture look raised, in grey.</td></tr>
<tr><td>Blur image, Sharpen image</td><td>Soften or sharpen by a factor you choose.</td></tr>
<tr><td>Solarize image</td><td>Inverts the brighter half, as an overexposed photograph.</td></tr>
<tr><td>Find edges</td><td>Outlines the shapes.</td></tr>
<tr><td>Increase / Decrease contrast</td><td>Stretch or flatten the colors.</td></tr>
<tr><td>Rotate/flip image&hellip;</td><td>Quarter turns and mirror images.</td></tr></table>
{grid([("RMULTI", "The original, remapped to multipalette."), ("FEQUAL", "Histogram equalization."), ("FEMBOSS", "Emboss."),
       ("FSOLAR", "Solarize."), ("FEDGES", "Find edges."), ("FBLUR", "Blur (factor 80)."),
       ("FSHARP", "Sharpen (factor 80)."), ("FMORE", "Increase contrast."), ("FMIRROR", "Mirrored.")])}
<p><b>True color image info&hellip;</b> (<kbd>&#8984;T</kbd>) shows the picture's size and its red, green, blue and brightness histograms;
<b>View approximation</b> (<kbd>&#8984;A</kbd>) shows the true color picture as closely as the screen can, without remapping.</p>
"""))

body.append(chapter("mono", "Monochrome images",
  "Black and white, one bit a pixel: for printing, for 640 mode, for MacPaint-style art and for a look of its own.", f"""
<p><b>Convert to monochrome&hellip;</b> (in the Screen and True color menus) makes the monochrome image, enlarged two or four
times if you like, by one of four methods. The <b>Monochrome</b> menu turns it back into a screen or true color image &mdash;
choosing the pixels' aspect, the scaling, 320 or 640 mode and how much grey to keep &mdash; and makes its negative.</p>
{grid([("MDIFF", "Error diffusion."), ("MPAT", "Pattern dither."), ("MTHRESH", "50% threshold."), ("MHALF", "Halftone.")], 2)}
{tip("Macintosh MacPaint pictures and Springboard Works of Art pages load straight into a monochrome image.")}
"""))

body.append(chapter("batch", "Loading many files",
  "Load & convert works through many pictures one after another: choose them all at once, or whole folders.", f"""
<ol class="steps"><li>Choose the format in Load formats and click <b>Load&hellip;</b>.</li>
<li>In the file dialog, select several files (shift-click), or folders with <b>Load all pictures within selected folders</b> checked.</li>
<li>The first picture loads; <b>Load next</b> (<kbd>&#8984;N</kbd>, or the button that takes Load&hellip;'s place) loads the next.
<b>File &gt; Cancel remaining files</b> forgets the rest.</li></ol>
<p>With the preferences <b>Automatically save picture after loading</b> and <b>Automatically load next picture after saving</b>,
a whole folder converts while you watch: each picture loads, is remapped as you set, saved in the chosen Save format, and the
next one follows.</p>
{tip("File > Re-convert last file (&#8984;R) loads the last picture again in the chosen format &mdash; handy after changing the Remap settings or the preferences.")}
"""))

body.append(chapter("saving", "Saving",
  "Choose a format in Save formats and click Save&hellip;. MegaconvertGS asks only what the format needs.", f"""
<p>Before the file dialog, MegaconvertGS may ask:</p>
<ul class="plain"><li><b>The size</b> of the saved picture: the original, one screen, a page, two screens high or wide, or the selection.</li>
<li><b>Where</b> a smaller picture goes in a larger area.</li>
<li>Whether to <b>go on</b> when the format can't hold everything the picture has: 640 mode, several color tables, mixed modes, dithering.</li>
<li>The format's <b>own options</b>: PNG compression and comments, TIFF Save Options, Hex data's layout, a Finder icon's criteria,
the Apple II saves' dithering and size.</li></ul>
<p>With only a true color or monochrome image, a screen image is made first. GIF, PNG, TIFF and BMP are written with square
pixels, as the picture looks, for today's computers.</p>
<h2>Which format?</h2>
<table><tr><th>For</th><th>Use</th></tr>
<tr><td>Keeping a IIgs picture</td><td>$C0,2 Apple Preferred: compressed, holds any size and every mode.</td></tr>
<tr><td>Programs that load a raw screen</td><td>$C1 uncompressed screen (32768 bytes).</td></tr>
<tr><td>Today's computers</td><td>PNG (lossless), or GIF, TIFF, BMP.</td></tr>
<tr><td>The Finder</td><td>Finder icon (new file, or added to an icon file).</td></tr>
<tr><td>HyperCard IIgs, HyperStudio</td><td>Icon resource.</td></tr>
<tr><td>The desktop's background</td><td>Desktop background image INIT (copy it to System.Setup).</td></tr>
<tr><td>Apple IIe, IIc programs</td><td>Apple II HiRes, Double HiRes, LoRes, Double LoRes (plain or packed).</td></tr>
<tr><td>Programmers</td><td>Hex data: the picture as assembler or BASIC data.</td></tr></table>
{img("SAVEINFO", "Info on format explains each save format before you choose it.")}
"""))

body.append(chapter("apple2", "Apple II pictures",
  "HiRes, Double HiRes, LoRes and Double LoRes: the Apple IIe and IIc screens, loaded with their colors worked out as a color monitor shows them, and saved back.", f"""
<h2>HiRes and Double HiRes</h2>
<p>A HiRes screen is 8192 bytes, 280 x 192 dots in six colors; Double HiRes is 16384 bytes (the auxiliary memory half first),
140 x 192 pixels in 16 colors. MegaconvertGS reads them in color or black and white, and also:</p>
<ul class="plain"><li>packed with PackBytes (ProDOS type $08, aux type $4000 or $4001);</li>
<li>packed with fadden's <b>LZ4FH</b> (type $08, aux type $8066);</li>
<li>Double HiRes as <b>two files</b>, <code>NAME.BIN</code> (main memory) and <code>NAME.AUX</code> (auxiliary), as Beagle Graphics and
bmp2dhr write them &mdash; open either one;</li>
<li><b>Dazzle Draw</b> and bmp2dhr's <code>.A2FC</code> files (and <code>.A2FM</code>, black and white), and bmp2dhr's <code>.DHR</code>
picture pieces.</li></ul>
{grid([("KNIGHT", "HiRes."), ("BBROS", "HiRes."), ("FALST", "Double HiRes (A2FC)."), ("SEVENTH", "Double HiRes (A2FC)."), ("APPLEHQ", "Double HiRes.")])}
<h2>Saving for the Apple II</h2>
<p>The Apple II save formats fit the picture to 280 x 192 (or 40 x 48 and 80 x 48 blocks) and dither it in the Apple II colors.
Their options choose error diffusion, a pattern or no dithering, and whether the picture fills the screen or keeps its
proportions. A picture already in Apple II colors keeps them exactly.</p>
"""))

body.append(chapter("babelfish", "Babelfish",
  "Babelfish, Seven Hills Software's freeware file translators, adds the formats of its translators to every program that uses it &mdash; MegaconvertGS among them, as SuperConvert 4 did.", f"""
<h2>Installing Babelfish</h2>
<p>Babelfish is freeware; the archive and its manual are at <b>speccie.uk/software/babelfish</b>. Copy the files of its System
folder into your boot disk's System folder (System.Setup, Desk.Accs and SHS.Babelfish) and restart.</p>
<h2>Importing</h2>
<ol class="steps"><li>In Load formats, choose <b>External (Babelfish&trade;)</b>, then <b>True Color Import</b> or <b>PixelMap Import</b>.</li>
<li>Click Load&hellip;. MegaconvertGS shows "Loading Babelfish&hellip;" the first time, then Babelfish's own Open dialog.</li>
<li>Choose the file; the translator that knows it best is chosen for you, with its rating shown. Click Open.</li></ol>
{img("BFOPEN", "Babelfish's Open dialog: the file, and the translator that will read it.")}
<p>PixelMap Import gives a screen image (or a true color image when the picture is larger than the screen); True Color Import a
true color image. Babelfish's translators read Apple Preferred, Super Hi-Res, MacPaint, Print Shop and Print Shop GS, GEM/IMG,
PBM, PGM and PPM, ComputerEyes, Visionary, ThunderScan, Works of Art and Single and Double Hi-Res.</p>
<h2>Exporting</h2>
<p>In Save formats choose <b>Babelfish&trade; PixelMap Export</b> (the screen image: Apple Preferred, Super Hi-Res, MacPaint, Print
Shop) or <b>True Color Export</b> (the true color image, as a PPM file), then Save&hellip;: Babelfish's Export dialog asks for the
name and the translator.</p>
{tip("Without Babelfish installed, these entries say &quot;Unable to startup Babelfish.&quot;", "Note")}
"""))

body.append(chapter("extras", "Extras and preferences",
  "A few tools beyond converting, and the options that decide what happens after a picture loads or saves.", f"""
<h2>Preferences</h2>
<p><b>Apple &gt; Preferences&hellip;</b> sets what happens after a picture is loaded or saved: save it at once, view it full
screen or not, open the Remap dialog for true color pictures (or also after screen images), load the next file waiting after
saving. <b>Save</b> keeps the options for next time (in MCGS.Prefs beside the program).</p>
{img("PREFS", "The Preferences dialog.")}
<h2>Examine file</h2>
<p><b>File &gt; Examine file&hellip;</b> shows any file's data or resource fork as hex and text, or a histogram of its byte
values &mdash; useful when a file won't load and you want to know what it is.</p>
{grid([("EXAMA", "Examine file: hex and text."), ("EXAMC", "Examine file: the bytes' histogram.")], 2)}
<h2>And more</h2>
<ul class="plain"><li><b>Screen &gt; Use as desktop background</b> puts the picture behind every desktop program's windows; save it
as a Desktop background image INIT to keep it.</li>
<li><b>Screen &gt; Oscilloscope Art</b> makes a picture to watch on an oscilloscope on the composite output.</li>
<li><b>Extras &gt; Available font list</b>, <b>More available fonts</b> and <b>Font key chart&hellip;</b> show the installed fonts.</li>
<li><b>Extras &gt; System info report&hellip;</b> describes the computer: memory, tools, versions.</li>
<li><b>Apple &gt; Help!</b> opens the help window; <b>Menu item help</b>, then any menu item, shows that command's page.</li></ul>
{img("HELP0", "The help window.")}
"""))

body.append(chapter("menus", "Menus and keys",
  "Every command at a glance.", """
<table><tr><th>Menu</th><th>Commands</th></tr>
<tr><td><b>Apple</b></td><td>About MegaconvertGS, Help!, Menu item help, Preferences&hellip;, desk accessories.</td></tr>
<tr><td><b>File</b></td><td>Load &amp; convert&hellip;, Load any picture&hellip;, Re-convert last file, Load next, Cancel remaining files,
Save conversion&hellip;, Exchange load/save paths, Examine file&hellip;, Quit.</td></tr>
<tr><td><b>Edit</b></td><td>Undo, Cut, Copy (the screen image or its selection, with its colors), Paste, Clear, Close (every image).</td></tr>
<tr><td><b>Screen</b></td><td>Screen image info&hellip;, Convert to true color&hellip;, Convert to monochrome&hellip;, View full screen,
View half size, View X4 magnified, Store palette, Use as desktop background, Oscilloscope Art.</td></tr>
<tr><td><b>True color</b></td><td>True color image info&hellip;, Convert to screen (Remap)&hellip;, Convert to monochrome&hellip;, View
approximation, Rotate/flip image&hellip;, and the filters.</td></tr>
<tr><td><b>Monochrome</b></td><td>Monochrome image info&hellip;, Convert to screen&hellip;, Convert to true color&hellip;, Negative image.</td></tr>
<tr><td><b>Windows</b></td><td>Normal positions, Load formats, Save formats, Current image.</td></tr>
<tr><td><b>Extras</b></td><td>Available font list, More available fonts, Font key chart&hellip;, Revert to normal desktop, System info report&hellip;.</td></tr></table>
<h2>Keys</h2>
<table><tr><th>Key</th><th>Command</th><th>Key</th><th>Command</th></tr>
<tr><td><kbd>&#8984;L</kbd></td><td>Load &amp; convert</td><td><kbd>&#8984;M</kbd></td><td>Remap</td></tr>
<tr><td><kbd>&#8984;O</kbd></td><td>Load any picture</td><td><kbd>&#8984;F</kbd></td><td>View full screen</td></tr>
<tr><td><kbd>&#8984;R</kbd></td><td>Re-convert last file</td><td><kbd>&#8984;H</kbd></td><td>View half size</td></tr>
<tr><td><kbd>&#8984;N</kbd></td><td>Load next</td><td><kbd>&#8984;4</kbd></td><td>View X4 magnified</td></tr>
<tr><td><kbd>&#8984;S</kbd></td><td>Save conversion</td><td><kbd>&#8984;A</kbd></td><td>View approximation</td></tr>
<tr><td><kbd>&#8984;I</kbd></td><td>Screen image info</td><td><kbd>&#8984;T</kbd></td><td>True color image info</td></tr>
<tr><td><kbd>&#8984;?</kbd> <kbd>&#8984;/</kbd></td><td>Help</td><td><kbd>&#8984;Q</kbd></td><td>Quit</td></tr></table>
<p>In the help window: <kbd>H</kbd> goes home, the left and right arrows page, the up and down arrows go back.</p>
"""))

body.append(chapter("loadref", "Load formats reference",
  f"Every entry of the Load formats window, by computer type, with what MegaconvertGS reads and makes of it &mdash; the same texts as its Info on format button.",
  LOADREF))

body.append(chapter("saveref", "Save formats reference",
  "Every entry of the Save formats window, in its order, with the file it writes.", SAVEREF))

doc = f"""<!doctype html><html><head><meta charset="utf-8"><title>MegaconvertGS {VERSION} Manual</title>
<style>{CSS}</style></head><body>{cover}{''.join(body)}</body></html>"""
os.makedirs(os.path.dirname(OUT), exist_ok=True)
open(OUT, "w").write(doc)
missing = sorted(set(re.findall(r'class="missing">\[(\w+)\]', doc)))
print("wrote", OUT, "missing shots:", " ".join(missing) or "none")
