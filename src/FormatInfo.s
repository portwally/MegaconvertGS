*-------------------------------------------------------------
* FormatInfo.s - the Info on format texts: an AlertWindow
* string for each load format and each save format (size and
* icon, the text, one OK button), and two tables of their
* addresses. Data only.
*
* FmtInfo: by load format number (fmtC1 = 1 ... fmtTIFF = 50, then
* the formats listed but not implemented yet, 51-54);
* entry 0 is the SuperHiRes entry, which reads any $C0 or $C1
* picture. SaveInfo: by save number (1 $C1 screen ... 12 TIFF,
* then 13-15, not implemented yet);
* entry 0 is unused.
*
* Each text fits a size 9 alert (600 x 80 in 640 mode): at most
* 5 lines of 516 pixels in Shaston 8, so a line stays free above
* the OK button. No / ^ # in the texts (AlertWindow's codes).
*-------------------------------------------------------------

FmtInfo     da    FiSHR,FiC1,FiAPF,FiPacked,FiPW,FiBMP,FiGIF,FiPNG,FiJPEG,FiHGR,FiHGRBW
            da    FiDHR,FiDHRBW,FiPSBW,FiPSGS,FiCGT,FiIcon,FiTScan,FiTDM40,FiTDM80,FiDG
            da    FiDG3200,FiAST,FiCEyes,Fi3200,Fi3200C,FiPWGold,FiDegas,FiDegasE,FiNeo
            da    FiTiny,FiSPU,FiSPC,FiIFF,FiDoodle,FiKoala,FiC64PS,FiMac640,FiMac320
            da    FiMacMono,FiMacSM,FiGEM,FiPCX,FiFli,FiSun,FiSGI,FiPNM,FiRLE,FiIPI,FiQRT
            da    FiTIFF,0,FiWOA,FiBabelTC,FiBabelPM,FiTGA,FiPICT
            da    FiZX,FiMS2,FiMS5,FiMS7,FiMS8,FiArtSt,FiAAS,FiCPC0,FiCPC1,FiCPC2
            da    FiFLI,FiAmica,FiMIC,FiGR8,FiGR9

FiFLI       asc   '93/FLI Graph (.FLI): Commodore 64 multicolor pictures with new screen colors '
            asc   'on every line, 17409 bytes.',0D,'It becomes a screen image in the C64',27,'s 16 '
            asc   'colors; the first three columns, which the C64 can',27,'t show, are black./^#0',00

FiAmica     asc   '93/Amica Paint (.AMI): packed Commodore 64 multicolor pictures, as Koala '
            asc   'pictures.',0D,'It becomes a screen image in the C64',27,'s 16 colors./^#0',00

FiMIC       asc   '93/MicroPainter (.MIC): Atari 8-bit pictures, 160 x 192 in 4 colors (7680 '
            asc   'bytes, and the 4 color registers if the file has them; else grays).',0D,'It '
            asc   'becomes a screen image in close to the Atari',27,'s colors./^#0',00

FiGR8       asc   '93/Atari Graphics 8 screen (.GR8): 320 x 192 in 2 colors, 7680 bytes.',0D,'It '
            asc   'becomes a black and white screen image./^#0',00

FiGR9       asc   '93/Atari Graphics 9 screen (.GR9): 80 x 192 in 16 grays, 7680 bytes.',0D,'It '
            asc   'becomes a screen image in 16 grays, its dots four times as wide./^#0',00

FiArtSt     asc   '93/Art Studio (OCP): hires pictures from the Commodore 64',27,'s Art Studio, '
            asc   '9009 bytes: 320 x 200 dots, a color pair for each 8 x 8 cell; and the same '
            asc   'pictures of 9002 bytes (Interpaint, Gigapaint and others).',0D,'It becomes '
            asc   'a screen image in the C64',27,'s 16 colors./^#0',00

FiAAS       asc   '93/Advanced Art Studio (OCP): multicolor pictures from the Commodore 64',27,'s '
            asc   'Advanced Art Studio, 10018 bytes: 160 x 200 wide dots in four colors for each '
            asc   'cell.',0D,'It becomes a screen image in the C64',27,'s 16 colors./^#0',00

FiCPC0      asc   '93/Amstrad CPC mode 0 screen (.SCR): the CPC',27,'s 16K of screen memory, with '
            asc   'or without its AMSDOS header or packed by OCP Art Studio, as mode 0: 160 x 200 '
            asc   'in 16 colors.',0D,'It becomes a screen image in the colors of the .PAL file '
            asc   'beside it, or the CPC',27,'s start-up colors./^#0',00

FiCPC1      asc   '93/Amstrad CPC mode 1 screen (.SCR): the CPC',27,'s 16K of screen memory, with '
            asc   'or without its AMSDOS header or packed by OCP Art Studio, as mode 1: 320 x 200 '
            asc   'in 4 colors (Open reads a CPC screen this way, unless a .PAL file beside it '
            asc   'says another mode).',0D,'It becomes a screen image in the colors of the .PAL '
            asc   'file, or the CPC',27,'s start-up colors./^#0',00

FiCPC2      asc   '93/Amstrad CPC mode 2 screen (.SCR): the CPC',27,'s 16K of screen memory, with '
            asc   'or without its AMSDOS header or packed by OCP Art Studio, as mode 2: 640 x 200 '
            asc   'in 2 colors.',0D,'It becomes a 640 mode screen image./^#0',00

FiZX        asc   '93/ZX Spectrum screen (.SCR): the Sinclair ZX Spectrum',27,'s screen, 6912 '
            asc   'bytes: 256 x 192 dots and a color pair for each 8 x 8 cell (a 6144-byte file: '
            asc   'the dots alone, black on white).',0D,'It becomes a screen image in the '
            asc   'Spectrum',27,'s 15 colors./^#0',00

FiMS2       asc   '93/MSX Screen 2 (.SC2): the MSX',27,'s 256 x 192 graphics screen saved with '
            asc   'BSAVE, a color pair for each line of each 8 x 8 cell.',0D,'It becomes a '
            asc   'screen image in the MSX',27,'s 16 colors./^#0',00

FiMS5       asc   '93/MSX2 Screen 5 (.SC5, .GE5): 256 x 212 in 16 colors from a palette of 512, '
            asc   'saved with BSAVE (the palette from the file if it holds it, else the '
            asc   'MSX2',27,'s own).',0D,'It becomes a true color picture, remapped to fit a 320 '
            asc   'mode screen./^#0',00

FiMS7       asc   '93/MSX2 Screen 7 (.SC7): 512 x 212 in 16 colors from a palette of 512, saved '
            asc   'with BSAVE; its dots are half as wide as tall.',0D,'It becomes a true color '
            asc   'picture, remapped to fit a 320 mode screen./^#0',00

FiMS8       asc   '93/MSX2 Screen 8 (.SC8): 256 x 212 in 256 colors (3 bits of green, 3 of red, '
            asc   '2 of blue), saved with BSAVE.',0D,'It becomes a true color picture, '
            asc   'remapped to fit a 320 mode screen./^#0',00

FiTGA       asc   '93/Truevision Targa (.TGA): pictures from paint and video programs, usually '
            asc   'ProDOS type $06 (BIN).',0D,'Reads color-mapped, true color and '
            asc   'gray pictures, run-length coded or not, of 8, 15, 16, 24 or 32 bits a pixel; '
            asc   'an alpha channel is left out./^#0',00

FiPICT      asc   '93/QuickDraw picture (PICT): the Macintosh',27,'s picture format, version 1 '
            asc   'or 2, with or without the 512 bytes a Mac file starts with.',0D,'Reads the '
            asc   'pictures in it: bitmaps and pixel maps, packed or not, of 1 to 32 bits a '
            asc   'pixel; the lines, shapes and text it may also draw are left out./^#0',00

SaveInfo    da    0,FiSvC1,FiSvAPF,FiSvPack,FiSvPW,FiSvIcon,FiSvIconAdd,FiSvRIcon
            da    FiSvRIcAdd,FiSvHex,FiSvGIF,FiSvPNG,FiSvTIFF,FiSvDesk,FiSvBabelTC
            da    FiSvBabelPM,FiSvBMP,FiSvHGR,FiSvHGRBW,FiSvDHR,FiSvDHRBW

* Load formats

FiSHR       asc   '93/SuperHiRes ($C0 PNT, $C1 PIC): reads the common Super Hi-Res files and '
            asc   'works out by itself which kind each one is: ProDOS type $C0 with aux type '
            asc   '$0000 (PaintWorks), $0001 (PackBytes) or $0002 (Apple Preferred), or type $C1 '
            asc   'with aux type $0000 (a plain screen).',0D,'Loaded as it is, up to one '
            asc   'screen./^#0',00

FiC1        asc   '93/$C1 screen: the Super Hi-Res screen saved byte for byte, 32768 bytes: the '
            asc   'pixels, the 200 SCBs (each line',27,'s mode and color table) and 16 color '
            asc   'tables. ProDOS type $C1 (PIC), aux type $0000, though early pictures were '
            asc   'often BIN files.',0D,'Loaded unchanged. Any file of at least 32000 bytes can '
            asc   'be read this way./^#0',00

FiAPF       asc   '93/Apple Preferred: the standard IIgs picture format, ProDOS type $C0 (PNT), '
            asc   'aux type $0002, used by most IIgs paint programs. Its MAIN block holds the '
            asc   'color tables and the lines, each packed with PackBytes and with its own mode.'
            asc   0D,'MegaconvertGS loads up to one screen of it and cuts off the rest./^#0',00

FiPacked    asc   '93/PackBytes screen: a whole $C1 screen (32768 bytes) packed with the IIgs '
            asc   'toolbox routine PackBytes, ProDOS type $C0 (PNT), aux type $0001. Rarely used, '
            asc   'but it keeps everything a screen can hold.',0D,'Unpacked and loaded unchanged. '
            asc   'Files of other types can be read this way too./^#0',00

FiPW        asc   '93/PaintWorks: the picture file of the first PaintWorks Plus (Activision), '
            asc   'ProDOS type $C0 (PNT), aux type $0000: one color table, the painting patterns, '
            asc   'then the picture packed with PackBytes, in 320 mode and up to a full page (396 '
            asc   'lines) tall.',0D,'Its top 200 lines are loaded./^#0',00

FiBMP       asc   '93/Windows bitmap (.BMP): the plain picture file of Windows PCs, also with the '
            asc   'older OS-2 header: 1, 4, 8, 16, 24 or 32 bits a pixel, uncompressed (run coded '
            asc   'files can',27,'t be read).',0D,'It becomes a true color picture, remapped to '
            asc   'fit a 320 mode screen with a calculated palette. Convert to screen (Remap) '
            asc   'offers other settings./^#0',00

FiGIF       asc   '93/GIF: CompuServe',27,'s Graphics Interchange Format (87a and 89a), up to 256 '
            asc   'colors out of 16 million. The first picture in the file is read, interlaced or '
            asc   'not, on a white background where transparent pixels stay white.',0D
            asc   'It becomes a true color picture, remapped to fit a 320 mode screen./^#0',00

FiPNG       asc   '93/PNG (Portable Network Graphics): the lossless picture format of today',27
            asc   's computers. Every kind is read: gray, palette or RGB, with or without alpha, '
            asc   '1 to 16 bits, interlaced or not. Transparent parts are mixed with white.',0D
            asc   'It becomes a true color picture, remapped to fit a 320 mode screen./^#0',00

FiJPEG      asc   '93/JPEG (JFIF): the usual format for photographs (.JPG), compressed with some '
            asc   'loss. Baseline and progressive JPEG files are read, gray or color, up to 2048 '
            asc   'pixels wide and 4096 tall (progressive ones as far as memory allows).',0D,'It becomes a true '
            asc   'color picture, remapped to fit a 320 mode screen./^#0',00

FiHGR       asc   '93/HiRes color: the Apple II high resolution screen, 8192 bytes (usually a BIN '
            asc   'or FOT file): 280 x 192 dots in black, white, violet, green, blue and orange, '
            asc   'the colors worked out from the dots and their neighbors as on a color monitor.'
            asc   0D,'Loaded as 280 x 192 in 320 mode./^#0',00

FiHGRBW     asc   '93/HiRes black & white: the Apple II high resolution screen (8192 bytes, '
            asc   'usually a BIN or FOT file) as a monochrome monitor shows it, each of its 280 x '
            asc   '192 dots white or black.',0D,'Loaded as 280 x 192 in 320 mode./^#0',00

FiDHR       asc   '93/Double HiRes color: the double high resolution screen of the Apple IIe, IIc '
            asc   'and IIgs, 16384 bytes, the auxiliary memory half first: 140 x 192 pixels in 16 '
            asc   'colors, each pixel made of 4 dots.',0D,'Loaded in 320 mode with the Apple II '
            asc   'colors, each pixel doubled across: 280 x 192./^#0',00

FiDHRBW     asc   '93/Double HiRes black & white: the Apple II double high resolution screen '
            asc   '(16384 bytes, the auxiliary half first) as a monochrome monitor shows it, each '
            asc   'of its 560 x 192 dots white or black.',0D,'Loaded as 560 x 192 in 640 mode./^#0'
            asc   00

FiPSBW      asc   '93/Print Shop graphic: a graphic from Broderbund',27,'s original Print Shop '
            asc   'for the Apple II, 88 x 52 dots in black and white, 572 bytes. Print Shop keeps '
            asc   'them on DOS 3.3 disks, so copy them to ProDOS first.',0D,'Loaded as 88 x 52 in '
            asc   '320 mode./^#0',00

FiPSGS      asc   '93/Print Shop IIgs color graphic: a graphic from Broderbund',27,'s Print Shop '
            asc   'IIgs, 88 x 52 dots in 8 colors (black, white, red, orange, yellow, green, blue '
            asc   'and purple) made of yellow, magenta and cyan planes, 1716 bytes.',0D
            asc   'Loaded as 88 x 52 in 320 mode with the standard colors./^#0',00

FiCGT       asc   '93/Print Shop IIgs built-in graphics: the libraries GRAPHIC.CGT0 to '
            asc   'GRAPHIC.CGT7 that come with Print Shop IIgs, each a series of 88 x 52 color '
            asc   'graphics followed by their names.',0D,'The first graphic in the file is '
            asc   'loaded, as 88 x 52 in 320 mode./^#0',00

FiIcon      asc   '93/Finder icon file: the IIgs Finder',27,'s icons, ProDOS type $CA (ICN). Each '
            asc   'entry says which files it is for and holds a large and a small icon, each with '
            asc   'a mask, in up to 16 colors.',0D,'The first entry',27,'s large icon is shown in '
            asc   '640 mode with the standard colors, on white./^#0',00

FiTScan     asc   '93/ThunderScan raw scan: a scan from Thunderware',27,'s ThunderScan, the '
            asc   'scanner that takes the place of the ribbon in an ImageWriter printer: a '
            asc   '256-byte header, then rows of 4-bit gray samples.',0D,'It becomes a gray true '
            asc   'color picture, remapped to fit a 320 mode screen./^#0',00

FiTDM40     asc   '93/TDM 40-column text screen: the Apple II text screen memory saved as a BIN '
            asc   'file, as On Three',27,'s The Desktop Manager (TDM) captures it: 1024 bytes, 40 '
            asc   'columns by 24 lines.',0D,'Drawn with the Apple II characters, normal and '
            asc   'inverse, as 280 x 192 in 320 mode./^#0',00

FiTDM80     asc   '93/TDM 80-column text screen: the Apple II 80-column text screen memory saved '
            asc   'as a BIN file, as TDM (The Desktop Manager) captures it: 2048 bytes, the '
            asc   'auxiliary memory half first.',0D,'Drawn with the Apple II characters, normal '
            asc   'and inverse, as 560 x 192 in 640 mode./^#0',00

FiDG        asc   '93/DreamGrafix: pictures from the DreamGrafix paint program, ProDOS type $C0 '
            asc   '(PNT), aux type $8005, LZW compressed. This is the 256 color kind, a screen '
            asc   'using all 16 color tables.',0D,'Unpacked and loaded unchanged, in 320 or 640 '
            asc   'mode, whichever most of its lines use./^#0',00

FiDG3200    asc   '93/DreamGrafix "3200 color": the DreamGrafix kind with its own palette on each '
            asc   'of the 200 lines, ProDOS type $C0 (PNT), aux type $8005, LZW compressed.',0D
            asc   'It becomes a 320 x 200 true color picture, remapped to 320 mode. Remap',27
            asc   's multipalette mode keeps more of its colors./^#0',00

FiAST       asc   '93/AST picture data: a full color picture from VisionEffects, the software of '
            asc   'AST',27,'s VisionPlus video digitizer, saved as picture data from 320 mode: '
            asc   'red, green and blue planes of 4-bit samples, 96000 bytes.',0D,'It becomes a '
            asc   '320 x 200 true color picture, remapped to 320 mode./^#0',00

FiCEyes     asc   '93/ComputerEyes GS raw data: a full color capture from the ComputerEyes GS '
            asc   'video digitizer: red, green and blue planes of 6-bit samples, stored column by '
            asc   'column, about 192000 bytes.',0D,'It becomes a 320 x 200 true color picture, '
            asc   'remapped to 320 mode./^#0',00

Fi3200      asc   '93/"3200 color" picture: 320 mode pixels followed by a color table for each of '
            asc   'the 200 lines, 38400 bytes, ProDOS type $C1 (PIC), aux type $0002, called '
            asc   'Brooks format after John Brooks. Special viewers show them, changing the '
            asc   'palette on every line.',0D,'It becomes a 320 x 200 true color picture, '
            asc   'remapped to 320 mode./^#0',00

Fi3200C     asc   '93/"3200 color" picture, compressed: two packed kinds are read: .3201 files '
            asc   '(an APP header, the 200 color tables, then the pixels packed with PackBytes) '
            asc   'and a run coded kind with a 7-byte header.',0D,'It becomes a 320 x 200 true '
            asc   'color picture, remapped to 320 mode./^#0',00

FiPWGold    asc   '93/PaintWorks Gold 640 mode: PaintWorks Gold saves 640 mode pictures with 320 '
            asc   'mode headers, in all of its formats, so other programs show them at half width '
            asc   'in the wrong colors.',0D,'This reads them as the 640 x 200 pictures they are. '
            asc   'Save them again, as Apple Preferred for example./^#0',00

FiDegas     asc   '93/Degas (.PI1, .PI2, .PI3): Atari ST pictures from Degas and Degas Elite, '
            asc   '32034 bytes. Low resolution (320 x 200, 16 colors) loads in 320 mode, medium '
            asc   '(640 x 200, 4 colors) in 640 mode, with their own colors.',0D,'High resolution '
            asc   '(640 x 400, black & white) becomes a true color picture, remapped to fit a 320 '
            asc   'mode screen./^#0',00

FiDegasE    asc   '93/Degas Elite (.PC1, .PC2, .PC3): the compressed Atari ST pictures of Degas '
            asc   'Elite. Low resolution (320 x 200, 16 colors) loads in 320 mode, medium (640 x '
            asc   '200, 4 colors) in 640 mode, with their own colors.',0D,'High resolution (640 x '
            asc   '400, black & white) becomes a true color picture, remapped to fit a 320 mode '
            asc   'screen./^#0',00

FiNeo       asc   '93/Neochrome (.NEO): Atari ST pictures from the Neochrome paint program, 32128 '
            asc   'bytes, nearly always low resolution: 320 x 200 in 16 colors, loaded in 320 '
            asc   'mode with their own colors.',0D,'Medium and high resolution ones are read as '
            asc   'Degas pictures are./^#0',00

FiTiny      asc   '93/Tiny (.TNY, .TN1 to .TN3): compressed Atari ST pictures. Low resolution '
            asc   '(320 x 200, 16 colors) loads in 320 mode, medium (640 x 200, 4 colors) in 640 '
            asc   'mode, with their own colors.',0D,'High resolution (640 x 400, black & white) '
            asc   'becomes a true color picture, remapped to fit a 320 mode screen./^#0',00

FiSPU       asc   '93/Spectrum 512 (.SPU): Atari ST pictures from Spectrum 512, which changes '
            asc   'palettes three times along each line to show up to 512 colors: 51104 bytes, '
            asc   'the top line always black.',0D,'It becomes a 320 x 200 true color picture, '
            asc   'remapped to 320 mode./^#0',00

FiSPC       asc   '93/Spectrum 512 compressed (.SPC): Spectrum 512 pictures with the bit planes '
            asc   'and each line',27,'s palettes packed: 320 x 200 with up to 512 colors, the top '
            asc   'line black.',0D,'It becomes a 320 x 200 true color picture, remapped to 320 '
            asc   'mode./^#0',00

FiIFF       asc   '93/IFF: the Amiga',27,'s standard picture file (FORM ILBM), also used by '
            asc   'DeluxePaint on the PC (FORM PBM, .LBM): 1 to 8 bit planes, Extra HalfBrite, '
            asc   'HAM and 24-bit, packed or not, found anywhere in the file.',0D,'It becomes a '
            asc   'true color picture, remapped to fit a 320 mode screen./^#0',00

FiDoodle    asc   '93/Doodle: Commodore 64 pictures from the Doodle paint program, whose file '
            asc   'names usually start with DD: 320 x 200 dots, with two colors in each 8 x 8 '
            asc   'cell.',0D,'Loaded as 320 x 200 in 320 mode with the Commodore 64 colors./^#0',00

FiKoala     asc   '93/Koala: Commodore 64 multicolor pictures from the KoalaPad',27
            asc   's paint program (.KOA, .KLA), 10003 bytes: 160 x 200 double-wide pixels, with '
            asc   'four colors in each 4 x 8 cell.',0D,'Loaded as 320 x 200 in 320 mode with the '
            asc   'Commodore 64 colors./^#0',00

FiC64PS     asc   '93/C64 Print Shop screen: a Commodore 64 Print Shop screen, a load address and '
            asc   'then a 320 x 200 bitmap (8000 bytes) in black and white.',0D,'Loaded as 320 x '
            asc   '200 in 320 mode, white on black. Other C64 bitmaps can be viewed this way too, '
            asc   'without their colors; Open takes any 8002-byte file this way./^#0',00

FiMac640    asc   '93/MacPaint as 640 mode grays: MacPaint documents (Mac file type PNTG) are 576 '
            asc   'x 720 dots, black and white, packed with PackBits. A MacBinary header is '
            asc   'skipped.',0D,'Each pair of lines becomes a line of four grays: the top 400 '
            asc   'lines as 576 x 200 in 640 mode./^#0',00

FiMac320    asc   '93/MacPaint as 320 mode black & white: MacPaint documents (Mac file type PNTG) '
            asc   'are 576 x 720 dots, black and white, packed with PackBits. A MacBinary header '
            asc   'is skipped.',0D,'The top left 320 x 200 dots are loaded in 320 mode, black on '
            asc   'white./^#0',00

FiMacMono   asc   '93/MacPaint as monochrome image: MacPaint documents (Mac file type PNTG) are '
            asc   '576 x 720 dots, black and white, packed with PackBits. A MacBinary header is '
            asc   'skipped.',0D,'The whole page becomes a true color picture, remapped to fit a '
            asc   '320 mode screen./^#0',00

FiMacSM     asc   '93/ScreenMaker: the startup screen of early Macintoshes, made with '
            asc   'ScreenMaker: a plain 512 x 342 bitmap in black and white, 21888 bytes. A '
            asc   'MacBinary header is skipped.',0D,'It becomes a true color picture, remapped to '
            asc   'fit a 320 mode screen./^#0',00

FiGEM       asc   '93/GEM IMG: the bitmap pictures (.IMG) of Digital Research',27,'s GEM and of '
            asc   'Ventura Publisher, with 1 to 8 bit planes, run coded.',0D,'Shown in grays, 0 '
            asc   'as white and the highest value as black: a true color picture, remapped to fit '
            asc   'a 320 mode screen./^#0',00

FiPCX       asc   '93/PC Paintbrush (.PCX, .PCC): ZSoft',27,'s PC paint program format, run '
            asc   'coded: 2 to 16 colors in bit planes, 256 colors with a palette at the end, or '
            asc   '24-bit color. PCC files are clippings.',0D,'It becomes a true color picture, '
            asc   'remapped to fit a 320 mode screen./^#0',00

FiFli       asc   '93/FliAway frame: one frame of an Autodesk Animator animation (.FLI, PC), '
            asc   'saved by the FliAway utility: 256 colors and the 320 x 200 frame, packed with '
            asc   'PackBytes or not.',0D,'It becomes a 320 x 200 true color picture, remapped to '
            asc   '320 mode./^#0',00

FiSun       asc   '93/Sun Rasterfile: the bitmap format of Sun workstations (.RAS): 1, 8, 24 or '
            asc   '32 bits a pixel, with or without a color map, plain or run coded.',0D
            asc   'It becomes a true color picture of its own size (up to 4096 x 4096), remapped '
            asc   'to fit a 320 mode screen./^#0',00

FiSGI       asc   '93/SGI image: the picture format of Silicon Graphics workstations (.SGI, .RGB, '
            asc   '.BW): gray or RGB (alpha is ignored), 8 or 16 bits a sample, plain or run '
            asc   'coded.',0D,'It becomes a true color picture, remapped to fit a 320 mode '
            asc   'screen./^#0',00

FiPNM       asc   '93/PBM, PGM, PPM: the portable bitmap, graymap and pixmap files of the Unix '
            asc   'PBMPLUS (Netpbm) tools: black & white, gray or color, as text (P1 to P3) or '
            asc   'binary (P4 to P6).',0D,'It becomes a true color picture, remapped to fit a 320 '
            asc   'mode screen./^#0',00

FiRLE       asc   '93/RLE: CompuServe',27,'s run-length coded pictures (.RLE), 256 x 192 or 128 x '
            asc   '96 dots in black and white, kept as plain text that may start anywhere in the '
            asc   'file, so a terminal',27,'s capture buffer will do.',0D,'Loaded in 320 mode./^#0'
            asc   00

FiIPI       asc   '93/IPI image: a format of the Image Processing Institute (University of '
            asc   'Southern California): three files named alike but ending .R, .G and .B, '
            asc   'squares of 8-bit samples, 256 or 512 a side. Pick any one, the other two are '
            asc   'read with it.',0D,'It becomes a true color picture, remapped to fit a 320 mode '
            asc   'screen./^#0',00

FiQRT       asc   '93/QRT raw image: the output of QRT, the Quick Ray Tracer: width and height, '
            asc   'then each line',27,'s number and its rows of red, green and blue samples, 8 '
            asc   'bits each.',0D,'It becomes a true color picture, remapped to fit a 320 mode '
            asc   'screen./^#0',00

FiTIFF      asc   '93/TIFF (.TIF): the Tagged Image File Format of desktop publishing on Macs and '
            asc   'PCs. The first image of a file is read, in either byte order, uncompressed, '
            asc   'PackBits or LZW: gray (1 to 16 bits), palette (1 to 8 bits) or RGB (8 or 16 '
            asc   'bits).',0D,'It becomes a true color picture, remapped to fit a 320 mode '
            asc   'screen./^#0',00

FiWOA       asc   '93/Works of Art: black and white clip art from Springboard Publishing',27
            asc   's Works of Art collections.',0D,'Each page chosen becomes a monochrome '
            asc   'image./^#0',00

FiBabelTC   asc   '93/Babelfish True Color Import: a picture read through Babelfish, Seven Hills '
            asc   'Software',27,'s file translator system, as a true color image.',0D
            asc   'MegaconvertGS doesn',27,'t work with Babelfish yet./^#0',00

FiBabelPM   asc   '93/Babelfish PixelMap Import: a picture read through Babelfish, Seven Hills '
            asc   'Software',27,'s file translator system, as a screen image.',0D,'MegaconvertGS '
            asc   'doesn',27,'t work with Babelfish yet./^#0',00

* Save formats

FiSvC1      asc   '93/$C1 screen: the whole Super Hi-Res screen as it is in memory, 32768 bytes '
            asc   '(pixels, SCBs and 16 color tables), ProDOS type $C1 (PIC), aux type $0000.',0D
            asc   'Every IIgs graphics program reads it, though it is not packed. Always a whole '
            asc   'screen./^#0',00

FiSvAPF     asc   '93/Apple Preferred: the standard IIgs picture format, ProDOS type $C0 (PNT), '
            asc   'aux type $0002, read by nearly all IIgs graphics programs: the best choice in '
            asc   'most cases.',0D,'A MAIN block with the 16 color tables and all 200 lines, 320 '
            asc   'or 640 pixels wide, each packed with PackBytes and keeping its SCB./^#0',00

FiSvPack    asc   '93/PackBytes screen: the whole 32768-byte screen, SCBs and color tables '
            asc   'included, packed with the toolbox routine PackBytes, ProDOS type $C0 (PNT), '
            asc   'aux type $0001.',0D,'Smaller than a $C1 screen with nothing lost, but few '
            asc   'programs read it./^#0',00

FiSvPW      asc   '93/PaintWorks: the format of the first PaintWorks Plus, ProDOS type $C0 (PNT), '
            asc   'aux type $0000: color table 0, empty painting patterns, then the lines packed '
            asc   'with PackBytes.',0D,'For 320 mode pictures only. Lines using other color '
            asc   'tables change color./^#0',00

FiSvIcon    asc   '93/Finder icon, new file: an icon file, ProDOS type $CA (ICN), with one icon '
            asc   'for any file: the picture as the large icon and a reduced copy as the small '
            asc   'one.',0D,'The picture must be 640 mode, at most 160 x 50 (80 x 25 is usual), '
            asc   'and should use the standard colors, as the Finder does./^#0',00

FiSvIconAdd asc   '93/Finder icon, add to a file: the same icon, added after the last one in an '
            asc   'icon file you choose, so several icons can share one file. Same limits: 640 '
            asc   'mode, at most 160 x 50.',0D,'Leave the system disk',27,'s own icon files '
            asc   'alone: new system software replaces them./^#0',00

FiSvRIcon   asc   '93/Icon resource, new file: a new file (ProDOS type $06, BIN) whose resource '
            asc   'fork holds the picture as an rIcon ($8001) resource, ID 1, for use in programs.'
            asc   0D,'320 or 640 mode, at most a quarter of the screen (8000 bytes of pixels)./^#0'
            asc   00

FiSvRIcAdd  asc   '93/Icon resource, add to a file: the picture as one more rIcon ($8001) '
            asc   'resource, with the lowest free ID, added to a resource file you choose, such '
            asc   'as a program of your own.',0D,'320 or 640 mode, at most a quarter of the '
            asc   'screen (8000 bytes of pixels)./^#0',00

FiSvHex     asc   '93/Hex data, for programmers: a text file (ProDOS type $04, TXT) with an '
            asc   'assembler line for each picture line, its pixel bytes in hexadecimal, as in dc '
            asc   'h',27,'00 11 22',27,'.',0D,'Only the picture',27,'s own size, two pixels a '
            asc   'byte in 320 mode and four in 640 mode, without SCBs or colors./^#0',00

FiSvGIF     asc   '93/GIF: a GIF 87a file for other computers, ProDOS type $06 (BIN), up to 256 '
            asc   'colors.',0D,'Written as it looks, with square pixels: lines twice and 320 mode '
            asc   'pixels twice across (a full screen gives 640 x 400). Each pixel keeps the '
            asc   'color it shows, whatever its palette./^#0',00

FiSvPNG     asc   '93/PNG: an 8-bit palette PNG file for today',27,'s computers, ProDOS type $06 '
            asc   '(BIN).',0D,'Written as it looks, with square pixels: lines twice and 320 mode '
            asc   'pixels twice across (a full screen gives 640 x 400). Each pixel keeps the '
            asc   'color it shows, whatever its palette./^#0',00

FiSvTIFF    asc   '93/TIFF: an 8-bit palette TIFF file in Intel byte order, packed with PackBits, '
            asc   'for desktop publishing and other programs on other computers, ProDOS type $06 '
            asc   '(BIN).',0D,'Written as it looks, with square pixels: lines twice and 320 mode '
            asc   'pixels twice across (a full screen gives 640 x 400)./^#0',00

FiSvDesk    asc   '93/Desktop background image INIT: the picture saved as a startup file, ProDOS '
            asc   'type $B7. In the SYSTEM.SETUP folder of a startup disk it puts the picture on '
            asc   'the desktop of every program at start-up.',0D,'Only its pixels are kept: it '
            asc   'shows in the mode and colours of the program. A larger picture is cut, a '
            asc   'smaller one centred on light blue./^#0',00

FiSvBabelTC asc   '93/Babelfish True Color Export: the true color picture written through '
            asc   'Babelfish, Seven Hills Software',27,'s file translator system, in a format its '
            asc   'translators offer.',0D,'MegaconvertGS doesn',27,'t work with Babelfish yet./^#0'
            asc   00

FiSvBMP     asc   '93/BMP: a Windows bitmap for today',27,'s computers, ProDOS type $06 (BIN), '
            asc   '8 bits a pixel, uncompressed.',0D,'Written as it looks, with square pixels: '
            asc   'lines twice and 320 mode pixels twice across (a full screen gives 640 x 400). '
            asc   'Each pixel keeps the color it shows, whatever its palette./^#0',00

FiSvHGR     asc   '93/HiRes color: the Apple II high resolution screen, ProDOS type $06 (BIN), '
            asc   'aux type $2000, 8192 bytes: 280 x 192 dots in black, white, violet, green, blue '
            asc   'and orange.',0D,'The picture is stretched to the Apple II screen and each '
            asc   'place takes the closest of the six colors; a byte of 7 dots shows blue and '
            asc   'orange or violet and green, whichever more of them want. Remap to those colors '
            asc   'first for the best result./^#0',00

FiSvHGRBW   asc   '93/HiRes black & white: the Apple II high resolution screen, ProDOS type $06 '
            asc   '(BIN), aux type $2000, 8192 bytes: 280 x 192 dots.',0D,'The picture is '
            asc   'stretched to the Apple II screen; a dot is on where the color there is bright '
            asc   '(half of white or more). Make a monochrome image and a screen from it first to '
            asc   'dither it./^#0',00

FiSvDHR     asc   '93/Double HiRes color: the double high resolution screen of the Apple IIe, IIc '
            asc   'and IIgs, ProDOS type $06 (BIN), aux type $2000, 16384 bytes, the auxiliary '
            asc   'memory half first: 140 x 192 pixels in 16 colors.',0D,'The picture is '
            asc   'stretched to the Apple II screen and each pixel takes the closest Apple II '
            asc   'color. Remap to those colors first for the best result./^#0',00

FiSvDHRBW   asc   '93/Double HiRes black & white: the Apple II double high resolution screen, '
            asc   'ProDOS type $06 (BIN), aux type $2000, 16384 bytes, the auxiliary half first: '
            asc   '560 x 192 dots.',0D,'The picture is stretched to the Apple II screen; a dot is '
            asc   'on where the color there is bright (half of white or more)./^#0',00

FiSvBabelPM asc   '93/Babelfish PixelMap Export: the screen picture written through Babelfish, '
            asc   'Seven Hills Software',27,'s file translator system, in a format its '
            asc   'translators offer.',0D,'MegaconvertGS doesn',27,'t work with Babelfish yet./^#0'
            asc   00
