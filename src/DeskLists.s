* DeskLists.s - the Load formats and Save formats lists, as SuperConvert's (made by
* test/make_lists.py). Members: name (Pascal string), flags (bit 7: chosen), a spare
* byte, the format or save number, the icon (0 folder; else what kind of picture: 1
* screen, 2 true color, 3 both, 4 monochrome), and for a load format its file filter
* (Load & convert's file dialog: docs/superconvert-file.md 3.4): 12 bytes each.

NTypes      =     14
TypeMems    =     *
            adrl  TyName0
            db    0,0
            dw    0,0,0
            adrl  TyName1
            db    $80,0
            dw    1,0,0
            adrl  TyName2
            db    0,0
            dw    2,0,0
            adrl  TyName3
            db    0,0
            dw    3,0,0
            adrl  TyName4
            db    0,0
            dw    4,0,0
            adrl  TyName5
            db    0,0
            dw    5,0,0
            adrl  TyName6
            db    0,0
            dw    6,0,0
            adrl  TyName7
            db    0,0
            dw    7,0,0
            adrl  TyName8
            db    0,0
            dw    8,0,0
            adrl  TyName9
            db    0,0
            dw    9,0,0
            adrl  TyName10
            db    0,0
            dw    10,0,0
            adrl  TyName11
            db    0,0
            dw    11,0,0
            adrl  TyName12
            db    0,0
            dw    12,0,0
            adrl  TyName13
            db    0,0
            dw    13,0,0
* Each type's formats: where its members are, how many.
TypeFmts    da    FmMems0,FmMems1,FmMems2,FmMems3,FmMems4,FmMems5,FmMems6,FmMems7,FmMems8,FmMems9,FmMems10,FmMems11,FmMems12,FmMems13
TypeCount   dw    9,12,6,1,7,5,5,3,3,3,4,1,9,2
FmMems0     =     *
            adrl  FmName0x0
            db    $80,0
            dw    fmtHGRBW,1,Filt0x0
            adrl  FmName0x1
            db    0,0
            dw    fmtHGR,1,Filt0x1
            adrl  FmName0x2
            db    0,0
            dw    fmtDHRBW,1,Filt0x2
            adrl  FmName0x3
            db    0,0
            dw    fmtDHR,1,Filt0x3
            adrl  FmName0x4
            db    0,0
            dw    fmtPSBW,1,Filt0x4
            adrl  FmName0x5
            db    0,0
            dw    fmtTScan,2,Filt0x5
            adrl  FmName0x6
            db    0,0
            dw    52,4,Filt0x6
            adrl  FmName0x7
            db    0,0
            dw    fmtTDM40,1,Filt0x7
            adrl  FmName0x8
            db    0,0
            dw    fmtTDM80,1,Filt0x8
FmMems1     =     *
            adrl  FmName1x0
            db    $80,0
            dw    0,1,Filt1x0
            adrl  FmName1x1
            db    0,0
            dw    fmtC1,1,Filt1x1
            adrl  FmName1x2
            db    0,0
            dw    fmtDG,1,Filt1x2
            adrl  FmName1x3
            db    0,0
            dw    fmtDG3200,2,Filt1x3
            adrl  FmName1x4
            db    0,0
            dw    fmtPWGold,1,Filt1x4
            adrl  FmName1x5
            db    0,0
            dw    fmtPSGS,1,Filt1x5
            adrl  FmName1x6
            db    0,0
            dw    fmtCGT,1,Filt1x6
            adrl  FmName1x7
            db    0,0
            dw    fmtIcon,1,Filt1x7
            adrl  FmName1x8
            db    0,0
            dw    fmtAST,2,Filt1x8
            adrl  FmName1x9
            db    0,0
            dw    fmtCEyes,2,Filt1x9
            adrl  FmName1x10
            db    0,0
            dw    fmt3200,2,Filt1x10
            adrl  FmName1x11
            db    0,0
            dw    fmt3200C,2,Filt1x11
FmMems2     =     *
            adrl  FmName2x0
            db    $80,0
            dw    fmtDegas,3,Filt2x0
            adrl  FmName2x1
            db    0,0
            dw    fmtDegasE,3,Filt2x1
            adrl  FmName2x2
            db    0,0
            dw    fmtNeo,3,Filt2x2
            adrl  FmName2x3
            db    0,0
            dw    fmtTiny,3,Filt2x3
            adrl  FmName2x4
            db    0,0
            dw    fmtSPU,2,Filt2x4
            adrl  FmName2x5
            db    0,0
            dw    fmtSPC,2,Filt2x5
FmMems3     =     *
            adrl  FmName3x0
            db    $80,0
            dw    fmtIFF,2,Filt3x0
FmMems4     =     *
            adrl  FmName4x0
            db    $80,0
            dw    fmtDoodle,1,Filt4x0
            adrl  FmName4x1
            db    0,0
            dw    fmtKoala,1,Filt4x1
            adrl  FmName4x2
            db    0,0
            dw    fmtC64PS,1,Filt4x2
            adrl  FmName4x3
            db    0,0
            dw    fmtArtSt,1,Filt4x3
            adrl  FmName4x4
            db    0,0
            dw    fmtAAS,1,Filt4x4
            adrl  FmName4x5
            db    0,0
            dw    fmtFLI,1,Filt4x5
            adrl  FmName4x6
            db    0,0
            dw    fmtAmica,1,Filt4x6
FmMems5     =     *
            adrl  FmName5x0
            db    $80,0
            dw    fmtMac640,1,Filt5x0
            adrl  FmName5x1
            db    0,0
            dw    fmtMac320,1,Filt5x1
            adrl  FmName5x2
            db    0,0
            dw    fmtMacMono,2,Filt5x2
            adrl  FmName5x3
            db    0,0
            dw    fmtMacSM,2,Filt5x3
            adrl  FmName5x4
            db    0,0
            dw    fmtPICT,2,Filt5x4
FmMems6     =     *
            adrl  FmName6x0
            db    $80,0
            dw    fmtBMP,2,Filt6x0
            adrl  FmName6x1
            db    0,0
            dw    fmtGEM,2,Filt6x1
            adrl  FmName6x2
            db    0,0
            dw    fmtPCX,2,Filt6x2
            adrl  FmName6x3
            db    0,0
            dw    fmtIFF,2,Filt6x3
            adrl  FmName6x4
            db    0,0
            dw    fmtFli,2,Filt6x4
FmMems7     =     *
            adrl  FmName7x0
            db    $80,0
            dw    fmtSun,2,Filt7x0
            adrl  FmName7x1
            db    0,0
            dw    fmtSGI,2,Filt7x1
            adrl  FmName7x2
            db    0,0
            dw    fmtPNM,2,Filt7x2
FmMems8     =     *
            adrl  FmName8x0
            db    $80,0
            dw    fmtCPC0,1,Filt8x0
            adrl  FmName8x1
            db    0,0
            dw    fmtCPC1,1,Filt8x1
            adrl  FmName8x2
            db    0,0
            dw    fmtCPC2,1,Filt8x2
FmMems9     =     *
            adrl  FmName9x0
            db    $80,0
            dw    fmtMIC,1,Filt9x0
            adrl  FmName9x1
            db    0,0
            dw    fmtGR8,1,Filt9x1
            adrl  FmName9x2
            db    0,0
            dw    fmtGR9,1,Filt9x2
FmMems10     =     *
            adrl  FmName10x0
            db    $80,0
            dw    fmtMS2,1,Filt10x0
            adrl  FmName10x1
            db    0,0
            dw    fmtMS5,2,Filt10x1
            adrl  FmName10x2
            db    0,0
            dw    fmtMS7,2,Filt10x2
            adrl  FmName10x3
            db    0,0
            dw    fmtMS8,2,Filt10x3
FmMems11     =     *
            adrl  FmName11x0
            db    $80,0
            dw    fmtZX,1,Filt11x0
FmMems12     =     *
            adrl  FmName12x0
            db    $80,0
            dw    fmtJPEG,2,Filt12x0
            adrl  FmName12x1
            db    0,0
            dw    fmtGIF,2,Filt12x1
            adrl  FmName12x2
            db    0,0
            dw    fmtPNG,2,Filt12x2
            adrl  FmName12x3
            db    0,0
            dw    fmtRLE,1,Filt12x3
            adrl  FmName12x4
            db    0,0
            dw    fmtIPI,2,Filt12x4
            adrl  FmName12x5
            db    0,0
            dw    fmtIPI,2,Filt12x5
            adrl  FmName12x6
            db    0,0
            dw    fmtQRT,2,Filt12x6
            adrl  FmName12x7
            db    0,0
            dw    fmtTIFF,2,Filt12x7
            adrl  FmName12x8
            db    0,0
            dw    fmtTGA,2,Filt12x8
FmMems13     =     *
            adrl  FmName13x0
            db    $80,0
            dw    53,2,Filt13x0
            adrl  FmName13x1
            db    0,0
            dw    54,1,Filt13x1
NSaves      =     20
SaveMems    =     *
            adrl  SvName0
            db    0,0
            dw    4,1,0
            adrl  SvName1
            db    0,0
            dw    3,1,0
            adrl  SvName2
            db    $80,0
            dw    2,1,0
            adrl  SvName3
            db    0,0
            dw    1,1,0
            adrl  SvName4
            db    0,0
            dw    5,1,0
            adrl  SvName5
            db    0,0
            dw    6,1,0
            adrl  SvName6
            db    0,0
            dw    8,1,0
            adrl  SvName7
            db    0,0
            dw    13,1,0
            adrl  SvName8
            db    0,0
            dw    9,1,0
            adrl  SvName9
            db    0,0
            dw    10,1,0
            adrl  SvName10
            db    0,0
            dw    11,1,0
            adrl  SvName11
            db    0,0
            dw    12,1,0
            adrl  SvName12
            db    0,0
            dw    14,1,0
            adrl  SvName13
            db    0,0
            dw    15,1,0
            adrl  SvName14
            db    0,0
            dw    7,1,0
            adrl  SvName15
            db    0,0
            dw    16,1,0
            adrl  SvName16
            db    0,0
            dw    17,1,0
            adrl  SvName17
            db    0,0
            dw    18,1,0
            adrl  SvName18
            db    0,0
            dw    19,1,0
            adrl  SvName19
            db    0,0
            dw    20,1,0
TyName0     dfb   15
            asc   'Apple II family'
FmName0x0   dfb   19
            asc   'HiRes black & white'
FmName0x1   dfb   11
            asc   'HiRes color'
FmName0x2   dfb   25
            asc   'DoubleHiRes black & white'
FmName0x3   dfb   17
            asc   'DoubleHiRes color'
FmName0x4   dfb   24
            asc   'Print Shop B & W graphic'
FmName0x5   dfb   25
            asc   'ThunderScan raw scan file'
FmName0x6   dfb   32
            asc   'Works of Art (Springboard Publ.)'
FmName0x7   dfb   33
            asc   'TDM 40-column text screen capture'
FmName0x8   dfb   33
            asc   'TDM 80-column text screen capture'
TyName1     dfb   19
            asc   'Apple IIgs specific'
FmName1x0   dfb   29
            asc   'SuperHiRes ($C0/PNT, $C1/PIC)'
FmName1x1   dfb   34
            asc   'Uncompressed SHR screen ($C1, BIN)'
FmName1x2   dfb   22
            asc   'DreamGrafix SHR screen'
FmName1x3   dfb   31
            asc   'DreamGrafix "3200 color" screen'
FmName1x4   dfb   30
            asc   'Paintworks Gold 640 mode files'
FmName1x5   dfb   29
            asc   'Print Shop IIgs color graphic'
FmName1x6   dfb   33
            asc   'PS IIgs built-in (GRAPHIC.CGT0-7)'
FmName1x7   dfb   16
            asc   'Finder icon file'
FmName1x8   dfb   34
            asc   'AST picture data file (color only)'
FmName1x9   dfb   29
            asc   'ComputerEyes GS raw data file'
FmName1x10  dfb   33
            asc   '"3200 color" uncompressed picture'
FmName1x11  dfb   31
            asc   '"3200 color" compressed picture'
TyName2     dfb   8
            asc   'Atari ST'
FmName2x0   dfb   24
            asc   'Degas (.PI1, .PI2, .PI3)'
FmName2x1   dfb   30
            asc   'Degas Elite (.PC1, .PC2, .PC3)'
FmName2x2   dfb   16
            asc   'Neochrome (.NEO)'
FmName2x3   dfb   11
            asc   'Tiny (.TNY)'
FmName2x4   dfb   32
            asc   'Spectrum 512 uncompressed (.SPU)'
FmName2x5   dfb   30
            asc   'Spectrum 512 compressed (.SPC)'
TyName3     dfb   5
            asc   'Amiga'
FmName3x0   dfb   20
            asc   'IFF (FORM ILBM only)'
TyName4     dfb   16
            asc   'Commodore 64/128'
FmName4x0   dfb   14
            asc   'Doodle (DDxxx)'
FmName4x1   dfb   17
            asc   'Koala Illustrator'
FmName4x2   dfb   17
            asc   'Print Shop screen'
FmName4x3   dfb   28
            asc   'Art Studio, Interpaint hires'
FmName4x4   dfb   25
            asc   'Advanced Art Studio (OCP)'
FmName4x5   dfb   16
            asc   'FLI Graph (.FLI)'
FmName4x6   dfb   18
            asc   'Amica Paint (.AMI)'
TyName5     dfb   9
            asc   'Macintosh'
FmName5x0   dfb   30
            asc   'MacPaint => 640 mode grayscale'
FmName5x1   dfb   34
            asc   'MacPaint => 320 mode black & white'
FmName5x2   dfb   29
            asc   'MacPaint, as monochrome image'
FmName5x3   dfb   32
            asc   'ScreenMaker (old startup screen)'
FmName5x4   dfb   24
            asc   'QuickDraw picture (PICT)'
TyName6     dfb   20
            asc   'IBM PC & compatibles'
FmName6x0   dfb   29
            asc   'Windows or OS/2 bitmap (.BMP)'
FmName6x1   dfb   30
            asc   'Ventura Publisher (.IMG, .GEM)'
FmName6x2   dfb   26
            asc   'PC Paintbrush (.PCX, .PCC)'
FmName6x3   dfb   32
            asc   'DeluxePaint, not Enhanced (.LBM)'
FmName6x4   dfb   26
            asc   'AA frame file from FliAway'
TyName7     dfb   13
            asc   'Unix machines'
FmName7x0   dfb   14
            asc   'Sun Rasterfile'
FmName7x1   dfb   33
            asc   'SGI Iris (.SGI, .BW, .RGB, .RGBA)'
FmName7x2   dfb   36
            asc   'Portable Pixelmap (.PBM, .PGM, .PPM)'
TyName8     dfb   11
            asc   'Amstrad CPC'
FmName8x0   dfb   20
            asc   'Mode 0 screen (.SCR)'
FmName8x1   dfb   20
            asc   'Mode 1 screen (.SCR)'
FmName8x2   dfb   20
            asc   'Mode 2 screen (.SCR)'
TyName9     dfb   11
            asc   'Atari 8-bit'
FmName9x0   dfb   19
            asc   'MicroPainter (.MIC)'
FmName9x1   dfb   24
            asc   'Graphics 8 screen (.GR8)'
FmName9x2   dfb   24
            asc   'Graphics 9 screen (.GR9)'
TyName10    dfb   3
            asc   'MSX'
FmName10x0  dfb   15
            asc   'Screen 2 (.SC2)'
FmName10x1  dfb   21
            asc   'Screen 5 (.SC5, .GE5)'
FmName10x2  dfb   15
            asc   'Screen 7 (.SC7)'
FmName10x3  dfb   15
            asc   'Screen 8 (.SC8)'
TyName11    dfb   11
            asc   'ZX Spectrum'
FmName11x0  dfb   13
            asc   'Screen (.SCR)'
TyName12    dfb   20
            asc   'Computer-independent'
FmName12x0  dfb   11
            asc   'JPEG (JFIF)'
FmName12x1  dfb   33
            asc   'GIF (Graphics Interchange Format)'
FmName12x2  dfb   31
            asc   'PNG (Portable Network Graphics)'
FmName12x3  dfb   25
            asc   'RLE (Run Length Encoding)'
FmName12x4  dfb   32
            asc   'IPI 256x256 image (.R + .G + .B)'
FmName12x5  dfb   32
            asc   'IPI 512x512 image (.R + .G + .B)'
FmName12x6  dfb   18
            asc   'QRT raw image file'
FmName12x7  dfb   31
            asc   'TIFF (Tagged Image File Format)'
FmName12x8  dfb   23
            asc   'Truevision Targa (.TGA)'
TyName13    dfb   21
            asc   'External (Babelfish',AA,')'
FmName13x0  dfb   28
            asc   'Babelfish',AA,' True Color Import'
FmName13x1  dfb   26
            asc   'Babelfish',AA,' PixelMap Import'
SvName0     dfb   32
            asc   '$C0,0 PaintWorks+ 1.0 (obsolete)'
SvName1     dfb   26
            asc   '$C0,1 PackBytes (obsolete)'
SvName2     dfb   21
            asc   '$C0,2 Apple Preferred'
SvName3     dfb   23
            asc   '$C1 uncompressed screen'
SvName4     dfb   22
            asc   'Finder icon (new file)'
SvName5     dfb   34
            asc   'Finder icon (add to existing file)'
SvName6     dfb   31
            asc   'Icon resource (HyperCard, etc.)'
SvName7     dfb   29
            asc   'Desktop background image INIT'
SvName8     dfb   31
            asc   'Hex data (for programmers only)'
SvName9     dfb   33
            asc   'GIF (Graphics Interchange Format)'
SvName10    dfb   31
            asc   'PNG (Portable Network Graphics)'
SvName11    dfb   31
            asc   'TIFF (Tagged Image File Format)'
SvName12    dfb   28
            asc   'Babelfish',AA,' True Color Export'
SvName13    dfb   26
            asc   'Babelfish',AA,' PixelMap Export'
SvName14    dfb   24
            asc   'Icon resource (new file)'
SvName15    dfb   20
            asc   'BMP (Windows bitmap)'
SvName16    dfb   20
            asc   'Apple II HiRes color'
SvName17    dfb   28
            asc   'Apple II HiRes black & white'
SvName18    dfb   27
            asc   'Apple II Double HiRes color'
SvName19    dfb   27
            asc   'Apple II Double HiRes b & w'
* File filters: types (A, B; $FFFF: a list), aux min, max, EOF min, max.
Filt0x0     dw    $0806,$0000,$FFFF
            adrl  $1FF8,$2100
Filt0x1     dw    $0806,$0000,$FFFF
            adrl  $1FF8,$2100
Filt0x2     dw    $0806,$0000,$FFFF
            adrl  $3FF8,$4100
Filt0x3     dw    $0806,$0000,$FFFF
            adrl  $3FF8,$4100
Filt0x4     dw    $0606,$0000,$FFFF
            adrl  $23C,$300
Filt0x5     dw    $0606,$5453,$5453
            adrl  $1,$FFFFFF
Filt0x6     dw    $F7F7,$0000,$0000
            adrl  $1,$FFFFFF
Filt0x7     dw    $0606,$0000,$FFFF
            adrl  $378,$400
Filt0x8     dw    $0606,$0000,$FFFF
            adrl  $778,$800
Filt1x0     dw    $FFFF
            da    FList1x0
FList1x0   =     *
            dw    $C0
            adrl  $0,$2,$1,$FFFFFF
            dw    $C0
            adrl  $8000,$8000,$1,$FFFFFF
            dw    $C1
            adrl  $0,$0,$1,$FFFFFF
            dw    $C1
            adrl  $2,$FFFF,$1,$FFFFFF
            dw    $FFFF
Filt1x1     dw    $06C1,$0000,$FFFF
            adrl  $7E20,$8200
Filt1x2     dw    $C0C0,$8005,$8005
            adrl  $1,$9FFF
Filt1x3     dw    $C0C0,$8005,$8005
            adrl  $1,$AFFF
Filt1x4     dw    $C1C0,$0000,$FFFF
            adrl  $1,$FFFFFF
Filt1x5     dw    $F8F8,$C323,$C323
            adrl  $6B4,$700
Filt1x6     dw    $0606,$0000,$FFFF
            adrl  $35A0,$3640
Filt1x7     dw    $CACA,$0000,$FFFF
            adrl  $10,$FFFFF
Filt1x8     dw    $C106,$4180,$8001
            adrl  $17700,$17FFF
Filt1x9     dw    $0606,$0000,$FFFF
            adrl  $2EE00,$30100
Filt1x10    dw    $C106,$0000,$FFFF
            adrl  $9600,$9700
Filt1x11    dw    $C0C0,$3200,$3200
            adrl  $100,$99999
Filt2x0     dw    $0406,$0000,$FFFF
            adrl  $7D22,$8000
Filt2x1     dw    $0406,$0000,$FFFF
            adrl  $1,$8000
Filt2x2     dw    $0406,$0000,$FFFF
            adrl  $7D80,$8000
Filt2x3     dw    $0406,$0000,$FFFF
            adrl  $1,$8000
Filt2x4     dw    $0406,$0000,$FFFF
            adrl  $C7A0,$C900
Filt2x5     dw    $0406,$0000,$FFFF
            adrl  $6A0,$C400
Filt3x0     dw    $0406,$0000,$FFFF
            adrl  $0,$FFFFFFFF
Filt4x0     dw    $0406,$0000,$FFFF
            adrl  $2340,$2710
Filt4x1     dw    $0406,$0000,$FFFF
            adrl  $290F,$2EE0
Filt4x2     dw    $0406,$0000,$FFFF
            adrl  $1F40,$2AF8
Filt4x3     dw    $0406,$0000,$FFFF
            adrl  $232A,$2331
Filt4x4     dw    $0406,$0000,$FFFF
            adrl  $2722,$2722
Filt4x5     dw    $0406,$0000,$FFFF
            adrl  $4401,$4401
Filt4x6     dw    $0406,$0000,$FFFF
            adrl  $4,$2713
Filt5x0     dw    $0406,$0000,$FFFF
            adrl  $3E8,$FFFF
Filt5x1     dw    $0406,$0000,$FFFF
            adrl  $3E8,$FFFF
Filt5x2     dw    $0406,$0000,$FFFF
            adrl  $3E8,$FFFF
Filt5x3     dw    $0406,$0000,$FFFF
            adrl  $5580,$5600
Filt5x4     dw    $0406,$0000,$FFFF
            adrl  $A,$FF0000
Filt6x0     dw    $0406,$0000,$FFFF
            adrl  $50,$FFFFFF
Filt6x1     dw    $0406,$0000,$FFFF
            adrl  $10,$FFFFFF
Filt6x2     dw    $0406,$0000,$FFFF
            adrl  $80,$FFFFFF
Filt6x3     dw    $0406,$0000,$FFFF
            adrl  $10,$FFFFFF
Filt6x4     dw    $0000,$0000,$FFFF
            adrl  $300,$FD00
Filt7x0     dw    $0406,$0000,$FFFF
            adrl  $20,$FFFFFF
Filt7x1     dw    $0406,$0000,$FFFF
            adrl  $200,$FFFFFF
Filt7x2     dw    $0406,$0000,$FFFF
            adrl  $10,$FFFFFF
Filt8x0     dw    $0406,$0000,$FFFF
            adrl  $3FD0,$10000
Filt8x1     dw    $0406,$0000,$FFFF
            adrl  $3FD0,$10000
Filt8x2     dw    $0406,$0000,$FFFF
            adrl  $3FD0,$10000
Filt9x0     dw    $0406,$0000,$FFFF
            adrl  $28,$2565
Filt9x1     dw    $0406,$0000,$FFFF
            adrl  $28,$2565
Filt9x2     dw    $0406,$0000,$FFFF
            adrl  $28,$2565
Filt10x0     dw    $0406,$0000,$FFFF
            adrl  $8,$10006
Filt10x1     dw    $0406,$0000,$FFFF
            adrl  $8,$10006
Filt10x2     dw    $0406,$0000,$FFFF
            adrl  $8,$10006
Filt10x3     dw    $0406,$0000,$FFFF
            adrl  $8,$10006
Filt11x0     dw    $0406,$0000,$FFFF
            adrl  $1800,$1B00
Filt12x0     dw    $FFFF
            da    FList12x0
FList12x0   =     *
            dw    $04
            adrl  $0,$FFFF,$8,$FFFFFF
            dw    $06
            adrl  $0,$FFFF,$8,$FFFFFF
            dw    $FFFF
Filt12x1     dw    $FFFF
            da    FList12x1
FList12x1   =     *
            dw    $04
            adrl  $0,$FFFF,$D,$FFFFFF
            dw    $06
            adrl  $0,$FFFF,$D,$FFFFFF
            dw    $C0
            adrl  $8006,$8006,$D,$FFFFFF
            dw    $FFFF
Filt12x2     dw    $FFFF
            da    FList12x2
FList12x2   =     *
            dw    $04
            adrl  $0,$FFFF,$8,$FFFFFF
            dw    $06
            adrl  $0,$FFFF,$8,$FFFFFF
            dw    $FFFF
Filt12x3     dw    $0406,$0000,$FFFF
            adrl  $2,$61A8
Filt12x4     dw    $0406,$0000,$FFFF
            adrl  $10000,$10200
Filt12x5     dw    $0406,$0000,$FFFF
            adrl  $40000,$40200
Filt12x6     dw    $0000,$0000,$FFFF
            adrl  $6,$FFFFFF
Filt12x7     dw    $0406,$0000,$FFFF
            adrl  $8,$FF0000
Filt12x8     dw    $0406,$0000,$FFFF
            adrl  $12,$FF0000
Filt13x0     dw    $FFFE,$0000,$0000
            adrl  $0,$0
Filt13x1     dw    $FFFD,$0000,$0000
            adrl  $0,$0
* The icons (SuperConvert's), by number; 8: the chosen type's open folder.
ListIcons   da    ListIcon0,ListIcon1,ListIcon2,ListIcon3,ListIcon4,ListIcon5,ListIcon6,ListIcon7,ListIcon8
IconTextX   dw    26,26,26,30,26,30,30,34,26
ListIcon0   =     *                     ; closed folder (computer type)
            hex   000028000A000800FFFFFFFFFC003FFFC0FF0003
            hex   0FFFFFF00FFFFFF00FFFFFF00FFFFFF000000000
            hex   FFFFFFFFFFFFFFFF0000000003FFC0003FFFFFFC
            hex   FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
            hex   0000000000000000
ListIcon1   =     *                     ; screen image (palette)
            hex   000028000A000800FFFFFFFFC0000000C37FFFF0
            hex   DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD
            hex   DDDDDDDDFFFFFFFF000000003FFFFFFF3FFFFFFF
            hex   3FFFFFFF3FFFFFFF3FFFFFFF3FFFFFFF3FFFFFFF
            hex   3FFFFFFF00000000
ListIcon2   =     *                     ; true color image
            hex   000028000A000800FFFFFFFFFF7777FFFF4447FF
            hex   FF4447FFFF7777FFBBBBDDDD888BD111888BD111
            hex   BBBBDDDDFFFFFFFF0000000000FFFC0000FFFC00
            hex   00FFFC0000FFFC00FFFC3FFFFFFC3FFFFFFC3FFF
            hex   FFFC3FFF00000000
ListIcon3   =     *                     ; screen + true color
            hex   000032000A000A00FFFFFFC0FFFF77770000FF44
            hex   440FF0FF44401DDDFF7740DDDDBBBB01DDDD8888
            hex   0DDDDD88801DDDDDBB80DDDDDDFF03FFFFFF0000
            hex   003F0000FFFCFFFF00FFFFFFFF00FFFFFFFF00FF
            hex   FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
            hex   FFFFFF00FC000000
ListIcon4   =     *                     ; monochrome (checkerboard)
            hex   000028000A000800FFFFFFFFFF00FF00FF00FF00
            hex   00FF00FF00FF00FFFF00FF00FF00FF0000FF00FF
            hex   00FF00FFFFFFFFFF00000000FFFFFFFFFFFFFFFF
            hex   FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
            hex   FFFFFFFF00000000
ListIcon5   =     *                     ; screen + monochrome
            hex   000032000A000A00FFFFFFC0FFC000000300C37F
            hex   FC0F00DDDDD000FFDDDDC300FFDDDD00FF00DDDC
            hex   00FF00DDD03F00FFDDC0FF00FFFF03FFFFFF0000
            hex   003F003FFFFFFFFF3FFFFFFFFF3FFFFFFFFF3FFF
            hex   FFFFFF3FFFFFFFFF3FFFFFFFFF3FFFFFFFFF3FFF
            hex   FFFFFF00FC000000
ListIcon6   =     *                     ; true color + monochrome
            hex   000032000A000A00FFFFFFC0FFFF77770300FF44
            hex   440F00FF444000FFFF774300FFBBBB00FF008888
            hex   00FF0088803F00FFBB80FF00FFFF03FFFFFF0000
            hex   003F0000FFFCFFFF00FFFFFFFF00FFFFFFFF00FF
            hex   FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
            hex   FFFFFF00FC000000
ListIcon7   =     *                     ; screen + true color + monochrome
            hex   00003C000A000C00FFFFFF0FFC3FFF7774000000
            hex   FF4440FFC300FF4441DD00FFFF770DDC00FFBBB8
            hex   1DD0FF008880DDC0FF008881DD0F00FFBB0DDC3F
            hex   00FFFC3FF0FFFFFF000000F003C000FFFFFFFFFF
            hex   00FFFFFFFFFF00FFFFFFFFFF00FFFFFFFFFFFFFF
            hex   FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
            hex   FFFF03C00F000000
ListIcon8   =     *                     ; open folder (selected computer type)
            hex   000032000A000A00FFFFFFFFFFFC003FFFFFC0FF
            hex   0003FF0FFFFFF0FF0FFC0000030F03FFFFC0303F
            hex   FFFC0F00000000FFFFFFFFFFFFFFFFFFFFFF0000
            hex   00000003FFC000003FFFFFFC00FFFFFFFF00FFFF
            hex   FFFFFCFFFFFFFFFFFFFFFFFFF0FFFFFFFF000000
            hex   0000000000000000
