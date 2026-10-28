* Toolbox call numbers (tool set in the low byte, call in the high byte).

* Tool Locator
_TLStartUp          =     $0201
_TLShutDown         =     $0301
_StartUpTools       =     $1801
_ShutDownTools      =     $1901
* Memory Manager
_MMStartUp          =     $0202
_MMShutDown         =     $0302
_NewHandle          =     $0902
_DisposeHandle      =     $1002
* Miscellaneous Tools
_SysBeep            =     $2C03
_MessageCenter      =     $1501
_HLock              =     $2002
_GetHandleSize      =     $1802
_Desktop            =     $0C0E
_PackBytes          =     $2603
_UnPackBytes        =     $2703
* QuickDraw II
_InitCursor         =     $CA04
_HideCursor         =     $9004
_ShowCursor         =     $9104
_MoveTo             =     $3A04
_DrawCString        =     $A604
_SetPort            =     $1B04
_EraseRect          =     $5504
_InvertRect         =     $5604
_GlobalToLocal      =     $8504
* Desk Manager
_FixAppleMenu       =     $1E05
* Event Manager
_GetNextEvent       =     $0A06
_FlushEvents        =     $1506
_TickCount          =     $1006
_PostEvent          =     $1406
_FakeMouse          =     $1906
_HandToHand         =     $2A02
* Window Manager
_NewWindow          =     $090E
_CloseWindow        =     $0B0E
_TaskMaster         =     $1D0E
_AlertWindow        =     $590E
* Menu Manager
_InsertMenu         =     $0D0F
_FixMenuBar         =     $130F
_DrawMenuBar        =     $2A0F
_MenuVersion        =     $040F
_SetMItemStruct     =     $490F
_HiliteMenu         =     $2C0F
_NewMenu            =     $2D0F
* Standard File
_SFGetFile2         =     $0E17
_SFPutFile2         =     $0F17

* GS/OS call numbers (class 1)
_CreateGS           =     $2001
_DestroyGS          =     $2002
_OpenGS             =     $2010
_ReadGS             =     $2012
_WriteGS            =     $2013
_CloseGS            =     $2014
_SetMarkGS          =     $2016
_GetEOFGS           =     $2019
_QuitGS             =     $2029
_SetPrefixGS        =     $2009
_GetPrefixGS        =     $200A
_ExpandPathGS       =     $200E
_GetDirEntryGS      =     $201C
_SFPMultiGet2       =     $1517
_SFReScan           =     $1317

* TaskMaster results
wInMenuBar          =     $0011
wInGoAway           =     $0016
wInInfo             =     $0018
wInSpecial          =     $0019

* Menu item numbers
iUndo               =     250
iCut                =     251
iCopy               =     252
iPaste              =     253
iClear              =     254
iClose              =     255
iQuit               =     256
iAbout              =     257
iOpen               =     259
iSaveAPF            =     260
iView               =     270
iLoadConv           =     280                ; SuperConvert's menus (MegaconvertGS numbers)
iReconvert          =     281
iLoadNext           =     282
iCancelQ            =     283
iScrInfo            =     290
iTurn               =     303                ; True color: Rotate/flip image
iHalf               =     293                ; Screen: View half size
iScrMono            =     292                ; Screen: Convert to monochrome
iTrueMono           =     301                ; True color: Convert to monochrome
iMonoInfo           =     320                ; Monochrome: info, to screen, to true colour,
iMonoScr            =     321                ; negative
iMonoTrue           =     322
iMonoNeg            =     323
iX4                 =     294                ; Screen: View X4 magnified
iApprox             =     302                ; True color: View approximation
iToTrue             =     291                ; Screen: Convert to true color
iStore              =     295                ; Screen: Store palette
iDesk               =     296                ; Screen: Use as desktop background
iRevert             =     344                ; Extras: Revert to normal desktop
iExchange           =     285                ; File: Exchange load/save paths
iPrefs              =     267                ; Apple: Preferences...
iFonts              =     340                ; Extras: Available font list
iMoreFonts          =     341                ; Extras: More available fonts
iKeyChart           =     342                ; Extras: Font key chart...
iSysInfo            =     345                ; Extras: System info report...
iExamine            =     289                ; File: Examine file...
iOscope             =     297                ; Screen: Oscilloscope Art
iTrueInfo           =     300
iFirstFx            =     304                ; True color: the filters, in fx order
iLastFx             =     313
iWinFirst           =     330                ; Windows: normal positions, then the windows
iWinLast            =     333
iRemap              =     271

* Memory attributes: locked, fixed, no bank crossing, no special memory
attrBuffer          =     $C018
* Locked, fixed, no special memory, may cross banks (for whole files)
attrFile            =     $C008

* Layout of a one-screen picture ($C1 file layout)
scbOffset           =     $7D00
palOffset           =     $7E00
screenSize          =     $8000

* Picture formats, as reported by DecodeFile
fmtC1               =     1
fmtAPF              =     2
fmtPacked           =     3
fmtPaintWorks       =     4
fmtBMP              =     5
fmtGIF              =     6
fmtPNG              =     7
fmtJPEG             =     8
fmtHGR              =     9                  ; Apple.s, the Apple II and IIgs segment
fmtHGRBW            =     10
fmtDHR              =     11
fmtDHRBW            =     12
fmtPSBW             =     13
fmtPSGS             =     14
fmtCGT              =     15
fmtIcon             =     16
fmtTScan            =     17
fmtTDM40            =     18
fmtTDM80            =     19
fmtDG               =     20
fmtDG3200           =     21
fmtAST              =     22
fmtCEyes            =     23
fmt3200             =     24
fmt3200C            =     25
fmtPWGold           =     26                 ; (in Formats.s)
fmtDegas            =     27                 ; Other.s: the other platforms
fmtDegasE           =     28
fmtNeo              =     29
fmtTiny             =     30
fmtSPU              =     31
fmtSPC              =     32
fmtIFF              =     33
fmtDoodle           =     34
fmtKoala            =     35
fmtC64PS            =     36
fmtMac640           =     37
fmtMac320           =     38
fmtMacMono          =     39
fmtMacSM            =     40
fmtGEM              =     41
fmtPCX              =     42
fmtFli              =     43
fmtSun              =     44
fmtSGI              =     45
fmtPNM              =     46
fmtRLE              =     47
fmtIPI              =     48
fmtQRT              =     49
fmtTIFF             =     50
fmtCount            =     51                 ; (Load formats lists some past these)
fmtNPS              =     51                 ; New Print Shop graphics (not here)
fmtWOA              =     52                 ; Works of Art (Apple.s WOA.s)
saveCount           =     14                 ; save numbers 1-13 (Save formats lists more)

* The True color menu's filters (Filter.s), in menu order
fxEqualize          =     0
fxMedian            =     1
fxSigma             =     2
fxEmboss            =     3
fxBlur              =     4
fxSharpen           =     5
fxSolarize          =     6
fxEdges             =     7
fxMore              =     8                  ; increase contrast
fxLess              =     9                  ; decrease contrast

* Errors of our own (GS/OS and Memory Manager errors are passed on as they are)
errNotPicture       =     $FFFF              ; no format recognised
errUnsupported      =     $FFFE              ; a kind of picture not handled yet
errTooBig           =     $FFFD              ; wider or taller than 4096 (JPEG: 2048)
errCorrupt          =     $FFFC              ; the data is damaged
errPW640            =     $FFFB              ; PaintWorks holds 320 mode pictures only
errIcon640          =     $FFFA              ; Finder icons are 640 mode
errIconBig          =     $FFF9              ; ... and at most 160 x 50
errIconRes          =     $FFF8              ; icon resources: at most a quarter screen
errNotImpl          =     $FFF7              ; a format listed but not implemented yet
errCopy             =     $FFF6              ; Copy or Cut: no picture made
errCancel           =     $FFF5              ; cancelled in a window: no message
errFont             =     $FF03              ; Font key chart: a damaged font

* Direct page (the application's own)
p0                  =     $00                ; long pointers
p1                  =     $04
p2                  =     $08
p3                  =     $0C
n0                  =     $10                ; long numbers
n1                  =     $14
t0                  =     $18                ; words
t1                  =     $1A
t2                  =     $1C
t3                  =     $1E
q0                  =     $20                ; more long pointers
q1                  =     $24
q2                  =     $28
s0                  =     $2C                ; read position in the file (Stream.s)
hc                  =     $30                ; Huffman decoding: counts, symbols (words)
hs                  =     $32
u0                  =     $34                ; more words
u1                  =     $36
u2                  =     $38
u3                  =     $3A

* Shared with the loader segments (set by Formats.s before calling one)
fp                  =     $40                ; the file's data (long)
flen                =     $44                ; its length (long)
scrp                =     $48                ; the picture, $C1 layout (long)
tp                  =     $4C                ; a true colour picture made by NewTrueL (long)
ftype               =     $50                ; file type
faux                =     $52                ; aux type (low word)
tstride             =     $54                ; bytes per true colour row
uid                 =     $56                ; the program's memory ID
ttall               =     $58                ; NewTrueL: pixels twice as tall as wide
pathp               =     $64                ; the file's path (GS/OS string, long)
ipg                 =     $68                ; IPI: the green and blue files (long)
ipb                 =     $6C
pw                  =     $70                ; a screen picture's own size (0: the whole screen)
ph                  =     $72
p640                =     $74                ; and 1 for 640 mode
outp                =     $76                ; Save.s: what to write (long), its length (long),
outl                =     $7A                ;   file type and aux type (long), and its handle
otype               =     $7E
oaux                =     $80                ;   ($80-$83)
ohnd                =     $A0                ;   (long; not after oaux, which is a long too)

* Resource Manager and others (Save.s)
_CreateResourceFile =     $091E
_OpenResourceFile   =     $0A1E
_CloseResourceFile  =     $0B1E
_AddResource        =     $0C1E
_GetResourceSize    =     $1D1E
_SetResourceFileDepth =   $251E
_FrameRect          =     $5304
_PaintRect          =     $5404

* Shared with the Remap segment (besides tp, tstride, scrp, uid)
rw                  =     $86                ; the true colour picture's size
rh                  =     $88
rtall               =     $8A                ; 1: its pixels are twice as tall as wide
rout_w              =     $8C                ; the screen picture made
rout_h              =     $8E
rout640             =     $90
rmode               =     $92                ; RemapSet's options
rpal                =     $94
ralg                =     $96
rhs                 =     $98
rvs                 =     $9A
rother              =     $9C
tgen                =     $9E                ; the true colour picture's number (+1 for a new one)

* QuickDraw and Event Manager calls for the Remap dialog
_SetPenSize         =     $2C04
_SetPenMode         =     $2E04
_SetPenPat          =     $3004
_PenNormal          =     $3604
_LineTo             =     $3C04
_FrameOval          =     $5804
_PaintOval          =     $5904
_FrameRRect         =     $5D04
_CStringWidth       =     $AA04
_GetMouse           =     $0C06
_StillDown          =     $0E06
_FreeMem            =     $1B02
_MaxBlock           =     $1C02
_SetTextFace        =     $9A04
_SetForeColor       =     $A004
_PPToPort           =     $D604

* The main windows (Desk.s): windows, controls, lists, menus
_ShowWindow         =     $130E
_HideWindow         =     $120E
_SelectWindow       =     $110E
_FrontWindow        =     $150E
_GetSysWFlag        =     $4C0E
_SetWTitle          =     $0D0E
_InvalRect          =     $3A0E
_StartDrawing       =     $4D0E
_SetDataSize        =     $410E
_SetContentOrigin   =     $3F0E
_MoveWindow         =     $190E
_LocalToGlobal      =     $8404
_DrawString         =     $A504
_StringWidth        =     $A904
_SetBackColor       =     $A204
_NewControl2        =     $3110
_DrawControls       =     $1010
_DisposeControl     =     $0A10
_ShowControl        =     $0F10
_HideControl        =     $0E10
_CreateList         =     $091C
_NextMember         =     $0B1C
_SelectMember       =     $0D1C
_EnableMItem        =     $300F
_DisableMItem       =     $310F
_SetMenuFlag        =     $1F0F
_DrawOneCtl         =     $2510
_DrawIcon           =     $0B12
_FillRect           =     $5704
_CopyPixels         =     $0912
_GetPort            =     $1C04
_OpenPort           =     $1804
_ClosePort          =     $1A04
_SetPortLoc         =     $1D04
_SetPortRect        =     $1F04
_ClipRect           =     $2604
_OpenPicture        =     $B704
_ClosePicture       =     $B904
_DrawPicture        =     $BA04
_KillPicture        =     $BB04
_ZeroScrap          =     $0B16
_PutScrap           =     $0C16
_GetScrapHandle     =     $0E16
_SetOriginMask      =     $340E
_DrawInfoBar        =     $550E
_PopUpMenuSelect    =     $3C0F
_NewMenuBar         =     $150F
_GetMenuBar         =     $0A0F
_SetMenuBar         =     $390F
_CheckMItem         =     $320F
_GetNewModalDialog  =     $3215
_NewDItem           =     $0D15
_GetIText           =     $1F15
_SetIText           =     $2015
_SelectIText        =     $2115
_ModalDialog        =     $0F15
_CloseDialog        =     $0C15
_ShowDItem          =     $2315
_RemoveDItem        =     $0E15
_ParamText          =     $1B15
_SetDItemValue      =     $2F15
_GetDItemValue      =     $2E15
_DrawDialog         =     $1615
_DrawChar           =     $A404
_Int2Dec            =     $260B
_SysBeep2           =     $3803
_GetMenuMgrPort     =     $1B0F
_HiliteCtlByID      =     $3F10
_SetCtlValueByID    =     $3C10
_GetCtlValueByID    =     $3D10
_SetCtlParamPtr     =     $3410
_NewWindow2         =     $610E
_SetSolidPenPat     =     $3704
_GetLETextByID      =     $3B10
_DoModalWindow      =     $640E
_WaitCursor         =     $0A12

* The image window's tools (ImgTools.s)
_FindWindow         =     $170E
_SetCursor          =     $8E04
_GetTick            =     $2503
_SetOrigin          =     $2304
_GetPen             =     $2904
_StartInfoDrawing   =     $500E
_EndInfoDrawing     =     $510E
_BeginUpdate        =     $1E0E
_EndUpdate          =     $1F0E
_GetContentOrigin   =     $3E0E
_GetPortRect        =     $2004
_SetHandleSize      =     $1902
_SetSCB             =     $1204
_SetColorTable      =     $0E04
_GetColorTable      =     $0F04
_InitColorTable     =     $0D04
_SetAllSCBs         =     $1404
_InitPalette        =     $2F0F
_GetNewDItem        =     $3315
_GetControlDItem    =     $1E15
_SetDefButton       =     $3815
_NoteAlert          =     $1915
_HiliteControl      =     $1110

* Fonts (Extras.s)
_GetFamInfo         =     $0B1B
_InstallFont        =     $0E1B
_SetPurgeStat       =     $0F1B
_FindFontStats      =     $111B
_LoadSysFont        =     $131B
_ChooseFont         =     $161B
_GetFontInfo        =     $9604
_SetTextMode        =     $9C04
_SetSolidBackPat    =     $3804
_CharBounds         =     $AC04
_GetFontID          =     $D104
_GetFont            =     $9504

* System info report (SysInfo.s)
_TotalMem           =     $1D02
_RealFreeMem        =     $2F02
_GetPathname2       =     $2211
_ReadBParam         =     $0C03
_WriteBParam        =     $0B03
_FWEntry            =     $2403
_GetKeyTranslation  =     $1B06
_GetVersionGS       =     $202A
_TEInsert           =     $1A22
_TESetSelection     =     $1D22
_TEGetText          =     $0C22
_TEScroll           =     $2522
_TEPaintText        =     $1322
_TEStyleChange      =     $1F22

* Examine file (Examine.s)
_GetFileInfoGS      =     $2006
_SFShowInvisible    =     $1217
_SetCtlAction       =     $2010
_GetCtlValue        =     $1A10
_FindControl        =     $1310
_SetCtlValue        =     $1910
_GetCtlID           =     $2A10
_GetCtlHandleFromID =     $3010
_ScrollRect         =     $7E04
_NewRgn             =     $6704
_DisposeRgn         =     $6804
_SetFontFlags       =     $9804
_DrawText           =     $A704
_Line               =     $3D04
_LongMul            =     $0C0B
_LongDivide         =     $0D0B

* Help! and the help window (Help.s)
_KillControls       =     $0B10
_SetContentOrigin2  =     $570E
_MenuGlobal         =     $230F
_MenuSelect         =     $2B0F
_MenuKey            =     $090F
_SetPenMask         =     $3204
_PtInRect           =     $4F04
iHelp               =     265                ; Apple: Help!
iMenuHelp           =     266                ; Apple: Menu item help

* Printing (Print.s)
_PMStartUp          =     $0213
_PMShutDown         =     $0313
_PrDefault          =     $0913
_PrValidate         =     $0A13
_PrStlDialog        =     $0B13
_PrJobDialog        =     $0C13
_PrOpenDoc          =     $0E13
_PrCloseDoc         =     $0F13
_PrOpenPage         =     $1013
_PrClosePage        =     $1113
_PrPicFile          =     $1213
_PrError            =     $1413
_PrSetError         =     $1513
_Move               =     $3B04
iPrint              =     286                ; File: Print (normal)
iPrintE             =     287                ; File: Print (enhanced)
iAlign              =     288                ; File: Print alignment page
_LoadOneTool        =     $0F01
cstr                =     $5A                ; the picture saved: bytes a line
cscb                =     $60                ;   (160, 320), where its SCBs and
cpal                =     $62                ;   colour tables are (SaveAs)
dsel                =     $EC                ; DeskSel: the type's selection flag,
dselr               =     $EE                ;   and its rectangle (top, left, bottom,
                                             ;   right; image units; $EE-$F5),
dselu               =     $F6                ;   image units a pixel across (true
                                             ;   colour, monochrome: 1 or 2)

* Shared with the Desk segment (besides scrp, pw, ph, p640)
dctl                =     $A4                ; a control (handle)
dact                =     $A8                ; what to do next (Desk's answer)
darg                =     $AA                ; and with what
dname               =     $AC                ; the picture's name (C string, long)
dpals               =     $B0                ; how many colour tables it uses
dclk                =     $B2                ; the clicks counted (2: a double click)
fhnd                =     $B4                ; Filter: a new true colour picture's handle (long)
dhave               =     $B8                ; Desk: the images there are (1 screen, 2 true colour)
dshow               =     $BA                ; Desk: the image type to show (0: as it was)
mblk                =     $BC                ; the monochrome image's block (MonoBlk, long)
* Desk's own, for routines the toolbox calls back ($C0-$CF: nothing else uses them)
mp0                 =     $C0
mp1                 =     $C4
mw0                 =     $C8
mw1                 =     $CA

wInContent          =     $0013
wInControl          =     $0021
