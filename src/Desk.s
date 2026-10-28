*-------------------------------------------------------------
* Desk.s - the Desk segment: SuperConvert's main windows, made as the
* original makes them, with the same window, button and list settings:
* Load formats (List Manager lists of the computer types and the chosen
* type's formats, Info on format and Load...), Save formats (Info on
* format, Save... and the list of formats) and Screen image (the picture
* drawn in the desktop's colours, with scroll bars).
*-------------------------------------------------------------
            rel
            mx    %00
            use   macros/Macs.s
            put   Equates.s

NewTrueL    ext                         ; (SegLib's MakeTrue: not used here)

* DeskStart: the Load formats and Save formats windows.
DeskStart   ent
            phb
            phk
            plb
            tdc                         ; (for the routines the toolbox calls)
            sta   AppDP
            PushLong LoadParms
            jsr   OpenWin
            sta   LoadWin
            stx   LoadWin+2
            ldx   #InfoLTmpl            ; its buttons
            jsr   NewButton
            sta   CtlInfoL
            stx   CtlInfoL+2
            ldx   #LoadTmpl
            jsr   NewButton
            sta   CtlLoad
            stx   CtlLoad+2
            ldx   #NextTmpl             ; (Load next: in its place, while
            jsr   NewButton             ; files wait in the queue)
            sta   CtlNext
            stx   CtlNext+2
            lda   LoadWin               ; its lists
            sta   ListWin
            lda   LoadWin+2
            sta   ListWin+2
            ldx   #TypeRec
            jsr   NewList
            sta   TypeCtl
            stx   TypeCtl+2
            jsr   MakeFmtList
            PushLong SaveParms
            jsr   OpenWin
            sta   SaveWin
            stx   SaveWin+2
            ldx   #InfoSTmpl
            jsr   NewButton
            sta   CtlInfoS
            stx   CtlInfoS+2
            ldx   #SaveTmpl             ; (shown once there is a picture)
            jsr   NewButton
            sta   CtlSave
            stx   CtlSave+2
            lda   SaveWin
            sta   ListWin
            lda   SaveWin+2
            sta   ListWin+2
            ldx   #SaveRec
            jsr   NewList
            sta   SaveCtl
            stx   SaveCtl+2
            PushLongAt LoadWin          ; Load formats in front, as in SuperConvert
            Tool  _SelectWindow
            jsr   MenuIcons
            jsr   NewStrip              ; (the image window's drawing buffer)
            plb
            rtl

* NewStrip: the 16K buffer the image window draws through (StripP; also
* in StripLoc). Without it, the window shows nothing but its background.
NewStrip    pha
            pha
            pea   0
            pea   16384
            lda   uid
            pha
            pea   attrBuffer
            PushLong 0
            Tool  _NewHandle
            pla
            sta   StripH
            pla
            sta   StripH+2
            bcs   :none
            lda   StripH
            sta   mp0
            lda   StripH+2
            sta   mp0+2
            lda   [mp0]
            sta   StripP
            sta   StripLoc+2
            ldy   #2
            lda   [mp0],y
            sta   StripP+2
            sta   StripLoc+4
:none       rts

* MenuIcons: the small icons SuperConvert shows by its image info items
* (screen, true color, monochrome), with Menu Manager 3.3 and later.
MenuIcons   pha
            Tool  _MenuVersion
            pla
            cmp   #$0303
            bcc   :old
            pea   0                     ; (a pointer to the structure)
            PushLong ScrItem
            pea   290
            Tool  _SetMItemStruct
            pea   0
            PushLong TrueItem
            pea   300
            Tool  _SetMItemStruct
            pea   0
            PushLong MonoItem
            pea   320
            Tool  _SetMItemStruct
            pha
            Tool  _FixMenuBar
            pla
            Tool  _DrawMenuBar
:old        rts

* The items' structures: an icon, the title (the Menu Manager fills it in)
* and the icon (the list's).
ScrItem     dw    $8000
            adrl  0
            adrl  ListIcon1
TrueItem    dw    $8000
            adrl  0
            adrl  ListIcon2
MonoItem    dw    $8000
            adrl  0
            adrl  ListIcon4

* OpenWin: a window from the parameters on the stack (pushed as a long
* before the JSR).   out: A, X = the window
OpenWin     pla                         ; (return address)
            sta   OwRet
            pha                         ; result
            pha
            lda   7,s                   ; the parameters' address, above it
            pha
            lda   7,s
            pha
            Tool  _NewWindow
            pla
            plx
            sta   OwWin
            pla                         ; (the caller's parameters)
            pla
            lda   OwRet
            pha
            lda   OwWin
            rts

* NewButton: a button from the template at X in window LoadWin or SaveWin
* (the template says which: its ID 1-2 load, 3-4 save).   out: A, X = it
NewButton   stx   t0
            pha                         ; result
            pha
            lda   |2,x                  ; (ID: 1, 2 and 5 Load formats',
            cmp   #5                    ; 3 and 4 Save formats')
            beq   :load
            cmp   #3
            bcs   :save
:load       PushLongAt LoadWin
            bra   :make
:save       PushLongAt SaveWin
:make       pea   0                     ; one template, by pointer
            pea   ^InfoLTmpl
            lda   t0
            pha
            Tool  _NewControl2
            pla
            plx
            rts

* NewList: the List Manager list whose record is at X, in window ListWin.
*   out: A, X = its control
NewList     stx   t0
            pha                         ; result
            pha
            PushLongAt ListWin
            pea   ^TypeRec
            lda   t0
            pha
            Tool  _CreateList
            pla
            plx
            rts

* MakeFmtList: the list of the chosen computer type's formats.
MakeFmtList lda   CurType
            asl
            tax
            lda   TypeFmts,x
            sta   FmtRec+28             ; listPointer
            lda   #^FmMems0
            sta   FmtRec+30
            lda   TypeCount,x
            sta   FmtRec+8              ; listSize
            lda   #1
            sta   FmtRec+14             ; listStart: the top
            lda   LoadWin
            sta   ListWin
            lda   LoadWin+2
            sta   ListWin+2
            ldx   #FmtRec
            jsr   NewList
            sta   FmtCtl
            stx   FmtCtl+2
            rts

*-------------------------------------------------------------
* Clicks
*-------------------------------------------------------------

* DeskControl: a control in one of the windows was clicked (dctl = it,
* dclk = the clicks counted: a double click on a format is Load... or
* Save...).
*   out: dact = 0 nothing more, 1 load (darg = the load format), 2 save
*   (darg = the save format)
DeskControl ent
            phb
            phk
            plb
            stz   dact
            ldx   #TypeCtl
            jsr   IsCtl
            bne   :notType
            jsr   TypeChosen
            bra   :done
:notType    ldx   #CtlInfoL
            jsr   IsCtl
            bne   :notInfoL
            jsr   ChosenFmt
            jsr   InfoLoad
            bra   :done
:notInfoL   ldx   #CtlNext
            jsr   IsCtl
            bne   :notNext
            lda   #3                    ; Load next
            sta   dact
            bra   :done
:notNext    ldx   #CtlLoad
            jsr   IsCtl
            beq   :load
            ldx   #FmtCtl
            jsr   IsCtl
            bne   :notLoad
            lda   dclk
            cmp   #2
            bcc   :done
:load       jsr   ChosenFmt
            sta   darg
            lda   #1
            sta   dact
            bra   :done
:notLoad    ldx   #CtlInfoS
            jsr   IsCtl
            bne   :notInfoS
            jsr   ChosenSave
            jsr   InfoSave
            bra   :done
:notInfoS   ldx   #CtlSave
            jsr   IsCtl
            beq   :save
            ldx   #SaveCtl
            jsr   IsCtl
            bne   :done
            lda   dclk
            cmp   #2
            bcc   :done
            lda   HaveSave              ; (only with a picture to save)
            beq   :done
:save       jsr   ChosenSave
            sta   darg
            lda   #2
            sta   dact
:done       plb
            rtl

* IsCtl: Z set if dctl is the control whose handle is at X.
IsCtl       lda   dctl
            cmp   |0,x
            bne   :no
            lda   dctl+2
            cmp   |2,x
:no         rts

* TypeChosen: a click in the computer types: if another type is chosen,
* the formats list shows its formats.
TypeChosen  ldx   #TypeMems
            ldy   #NTypes
            jsr   Chosen
            cmp   CurType
            beq   :same
            sta   CurType
            PushLongAt FmtCtl
            Tool  _DisposeControl
            jsr   MakeFmtList
            PushLongAt FmtCtl
            Tool  _DrawOneCtl
:same       rts

* Chosen: A = the number of the chosen member of the Y members at X (12
* bytes each; 0 if none is).
Chosen      stz   t1
            sty   t2
:m          lda   |4,x
            and   #$0080
            bne   :found
            txa
            clc
            adc   #12
            tax
            inc   t1
            lda   t1
            cmp   t2
            bcc   :m
            stz   t1
:found      lda   t1
            rts

* ChosenFmt: A = the load format chosen in the formats list (its member
* address in t3).
ChosenFmt   lda   CurType
            asl
            tax
            lda   TypeCount,x
            tay
            lda   TypeFmts,x
            tax
            phx
            jsr   Chosen
            asl                         ; * 12
            asl
            sta   t1
            asl
            clc
            adc   t1
            plx
            stx   t1
            clc
            adc   t1
            sta   t3
            tax
            lda   |6,x
            rts

* ChosenSave: A = the save format chosen (its member address in t3).
ChosenSave  ldx   #SaveMems
            ldy   #NSaves
            jsr   Chosen
            asl
            asl
            sta   t1
            asl
            clc
            adc   t1
            clc
            adc   #SaveMems
            sta   t3
            tax
            lda   |6,x
            rts

* DeskPick: for tests: Y = 0: computer type A and its format X chosen in
* Load formats; Y = 1: save format A chosen in Save formats.
DeskPick    ent
            phb
            phk
            plb
            sta   PkA
            stx   PkX
            cpy   #0
            bne   :save
            ldx   #TypeMems             ; the type
            ldy   #NTypes
            lda   PkA
            jsr   Pick
            lda   PkA
            cmp   CurType
            beq   :fmt
            sta   CurType
            PushLongAt FmtCtl
            Tool  _DisposeControl
            jsr   MakeFmtList
:fmt        lda   CurType               ; and its format
            asl
            tax
            lda   TypeCount,x
            tay
            lda   TypeFmts,x
            tax
            lda   PkX
            jsr   Pick
            PushLongAt TypeCtl
            Tool  _DrawOneCtl
            PushLongAt FmtCtl
            Tool  _DrawOneCtl
            plb
            rtl
:save       ldx   #SaveMems
            ldy   #NSaves
            lda   PkA
            jsr   Pick
            PushLongAt SaveCtl
            Tool  _DrawOneCtl
            plb
            rtl

* Pick: member A (of the Y members at X) is the one chosen.
Pick        sta   t1
            sty   t2
            stz   t3
:m          sep   #$20
            mx    %10
            lda   |4,x
            and   #$7F
            sta   |4,x
            lda   t3
            cmp   t1
            bne   :next
            lda   |4,x
            ora   #$80
            sta   |4,x
:next       rep   #$20
            mx    %00
            txa
            clc
            adc   #12
            tax
            inc   t3
            lda   t3
            cmp   t2
            bcc   :m
            rts

PkA         dw    0
PkX         dw    0

* DeskLoadFmt, DeskSaveFmt: A = the load or save format chosen.
DeskLoadFmt ent
            phb
            phk
            plb
            jsr   ChosenFmt
            plb
            rtl

DeskSaveFmt ent
            phb
            phk
            plb
            jsr   ChosenSave
            plb
            rtl

* InfoLoad, InfoSave: what the chosen format is (t3: its member), from
* FormatInfo.s.
InfoLoad    ldx   t3
            lda   |6,x                  ; the load format
            asl
            tax
            lda   FmtInfo,x
            bra   Info
InfoSave    ldx   t3
            lda   |6,x                  ; the save format
            asl
            tax
            lda   SaveInfo,x
Info        sta   t0
            pha                         ; result: the button
            pea   0                     ; a C string
            PushLong 0                  ; no substitution strings
            pea   ^FmtInfo              ; the text (in this segment)
            lda   t0
            pha
            Tool  _AlertWindow
            pla
            rts

*-------------------------------------------------------------
* The windows' other entries
*-------------------------------------------------------------

* DeskShowSave: the Save... button (A <> 0: there is a picture to save).
DeskShowSave ent
            phb
            phk
            plb
            sta   HaveSave
            tax
            PushLongAt CtlSave
            txa
            bne   :show
            Tool  _HideControl
            plb
            rtl
:show       Tool  _ShowControl
            plb
            rtl

* DeskWindow: the Windows menu: A = 0 normal positions, 1 Load formats,
* 2 Save formats, 3 the screen image.
DeskWindow  ent
            phb
            phk
            plb
            cmp   #0
            bne   :one
            jsr   Normal
            bra   :done
:one        asl
            asl
            tax
            lda   WinTab+2,x
            ora   WinTab,x
            beq   :done                 ; (no screen image window yet)
            lda   WinTab+2,x
            pha
            lda   WinTab,x
            pha
            lda   WinTab+2,x
            pha
            lda   WinTab,x
            pha
            Tool  _ShowWindow
            Tool  _SelectWindow
:done       plb
            rtl

WinTab      adrl  0
LoadWin     adrl  0
SaveWin     adrl  0
ScrWin      adrl  0

* Normal: each window back where it starts.
Normal      ldx   #4
:w          lda   WinTab+2,x
            ora   WinTab,x
            beq   :next
            phx
            lda   WinPos,x              ; MoveWindow(h, v, window)
            pha
            lda   WinPos+2,x
            pha
            lda   WinTab+2,x
            pha
            lda   WinTab,x
            pha
            Tool  _MoveWindow
            plx
:next       inx
            inx
            inx
            inx
            cpx   #16
            bcc   :w
            rts

WinPos      dw    0,0,8,30,328,30,328,122   ; (h, v of each content)

* DeskClose: the close box (or Edit > Close) of window dctl: hidden.
DeskClose   ent
            phb
            phk
            plb
            PushLongAt dctl
            Tool  _HideWindow
            plb
            rtl

*-------------------------------------------------------------
* The screen image window
*-------------------------------------------------------------

* TAdd: the C string at A (this bank) onto the text at mp1; TAddLong:
* the C string at X:A.
TAdd        ldx   #^TxSpace
TAddLong    sta   mp0
            stx   mp0+2
            ldy   #0
            ldx   TLen
:c          lda   [mp0],y
            and   #$00FF
            beq   :end
            phy
            txy
            sep   #$20
            mx    %10
            sta   (mp1),y
            rep   #$20
            mx    %00
            ply
            iny
            inx
            cpx   #60
            bcc   :c
:end        stx   TLen
            rts

* TDec: A in decimal onto the text.
TDec        ldx   #0
:digit      sta   n0
            stz   n0+2
            phx
            lda   #10
            jsr   Div32
            plx
            lda   DvR
            clc
            adc   #'0'
            pha
            inx
            lda   DvQ
            bne   :digit
            ldy   TLen
:out        pla
            sep   #$20
            mx    %10
            sta   (mp1),y
            rep   #$20
            mx    %00
            iny
            dex
            bne   :out
            sty   TLen
            rts

*-------------------------------------------------------------
* Drawing (called by the toolbox: own data bank and direct page)
*-------------------------------------------------------------

* DrawLoadWin: the Load formats window's contents.
DrawLoadWin phb
            phk
            plb
            phd
            lda   AppDP
            tcd
            PushLongAt LoadWin
            Tool  _DrawControls
            pea   15                    ; the labels: white on black
            Tool  _SetForeColor
            pea   0
            Tool  _SetBackColor
            pea   0
            Tool  _SetSolidPenPat
            lda   #TxComp
            ldx   #LabelX1
            ldy   #LabelY1
            jsr   Label
            lda   #TxSpec
            ldx   #LabelX2
            ldy   #LabelY2
            jsr   Label
            Tool  _PenNormal
            pea   0
            Tool  _SetForeColor
            pea   15
            Tool  _SetBackColor
            pld
            plb
            rtl

* Label: the string at A (a Pascal string in this bank), its left at X and
* its baseline at Y, on a black box a row taller than the text above and
* below, as SuperConvert paints it.
Label       sta   mw0
            stx   LRect+2
            sty   mw1
            tya
            sec
            sbc   #8
            sta   LRect                 ; top
            tya
            clc
            adc   #2
            sta   LRect+4               ; bottom
            pha                         ; result: the string's width
            pea   ^TxComp
            lda   mw0
            pha
            Tool  _StringWidth
            pla
            clc
            adc   LRect+2
            sta   LRect+6               ; right
            PushLong LRect
            Tool  _PaintRect
            lda   LRect+2
            pha
            lda   mw1
            pha
            Tool  _MoveTo
            pea   ^TxComp
            lda   mw0
            pha
            Tool  _DrawString
            rts

* DrawSaveWin: the Save formats window's contents.
DrawSaveWin phb
            phk
            plb
            phd
            lda   AppDP
            tcd
            PushLongAt SaveWin
            Tool  _DrawControls
            pld
            plb
            rtl

* DrawMem: one member of a list (the List Manager calls it, with the
* member's rect, the member and the list on the stack): its icon and
* name, on green if it is the one chosen.
DrawMem     phb
            phk
            plb
            phd
            lda   AppDP
            tcd
            lda   11,s                  ; the member
            sta   mp0
            lda   13,s
            sta   mp0+2
            lda   15,s                  ; its rect
            sta   mp1
            lda   17,s
            sta   mp1+2
            ldy   #6
:r          lda   [mp1],y
            sta   MRect,y
            dey
            dey
            bpl   :r
            ldy   #4                    ; chosen?
            lda   [mp0],y
            and   #$0080
            sta   mw1
            beq   :plain
            PushLong YelGreen
            Tool  _SetPenPat
            PushLong MRect
            Tool  _PaintRect
            Tool  _PenNormal
            bra   :icon
:plain      PushLong MRect
            Tool  _EraseRect
:icon       ldy   #8                    ; the icon, as SuperConvert draws it
            lda   [mp0],y               ; (the chosen type: an open folder)
            bne   :kind
            ldx   mw1
            beq   :kind
            lda   #8
:kind       asl
            sta   mw0
            tax
            pea   ^ListIcons
            lda   ListIcons,x
            pha
            pea   0                     ; drawn as it is, through its mask
            lda   MRect+2               ; at the row's left + 4 (even), top
            clc
            adc   #4
            and   #$FFFE
            pha
            lda   MRect
            pha
            Tool  _DrawIcon
            lda   mw1                   ; the name, on the row's colour
            beq   :white
            pea   10
            bra   :back
:white      pea   15
:back       Tool  _SetBackColor
            ldx   mw0                   ; after the icon
            lda   MRect+2
            clc
            adc   IconTextX,x
            pha
            lda   MRect
            clc
            adc   #8
            pha
            Tool  _MoveTo
            lda   [mp0]
            tax
            ldy   #2
            lda   [mp0],y
            pha
            phx
            Tool  _DrawString
            pea   15
            Tool  _SetBackColor
            pld
            plb
            lda   2,s                   ; drop the parameters (12 bytes)
            sta   14,s
            lda   1,s
            sta   13,s
            tsc
            clc
            adc   #12
            tcs
            rtl

*-------------------------------------------------------------
* Data
*-------------------------------------------------------------
AppDP       dw    0
OwRet       dw    0
OwWin       adrl  0
ListWin     adrl  0
CurType     dw    1                     ; Apple IIgs specific
CtlInfoL    adrl  0
CtlLoad     adrl  0
CtlNext     adrl  0
CtlInfoS    adrl  0
CtlSave     adrl  0
TypeCtl     adrl  0
FmtCtl      adrl  0
HaveSave    dw    0                     ; there is a picture to save
SaveCtl     adrl  0
MRect       dw    0,0,0,0

TLen        dw    0
ScrTitle    ds    64                    ; (Pascal strings)
TxSpace     asc   ' ',00
TxOpenP     asc   ' (',00
TxComma     asc   ', ',00
TxCloseP    asc   ') ',00
Tx320       asc   '320',00
Tx640       asc   '640',00
TxImage     asc   'Image: ',00
TxTimes     asc   ' x ',00

* Where things are in the windows (as SuperConvert has them).
LabelX1     =     10                    ; "Computer type"
LabelY1     =     78
LabelX2     =     184                   ; "Specific type"
LabelY2     =     93
LRect       dw    0,0,0,0

TxComp      str   '  Computer type  '
TxSpec      str   '  Specific type  '

* Windows (NewWindow parameters, as SuperConvert's).
LoadParms   dw    78
            dw    $80E8                 ; title, moves, clicks when inactive, visible
            adrl  LoadTitle
            adrl  0
            dw    0,0,0,0
            adrl  0                     ; (the usual colours)
            dw    0,0,0,0,0,0,0,0,0,0
            adrl  0
            dw    0
            adrl  0
            adrl  0
            adrl  DrawLoadWin
            dw    30,8,195,314          ; content: top, left, bottom, right
            adrl  $FFFFFFFF
            adrl  0
LoadTitle   str   ' Load formats '

SaveParms   dw    78
            dw    $80E8
            adrl  SaveTitle
            adrl  0
            dw    0,0,0,0
            adrl  0
            dw    0,0,0,0,0,0,0,0,0,0
            adrl  0
            dw    0
            adrl  0
            adrl  0
            adrl  DrawSaveWin
            dw    30,328,94,634
            adrl  $FFFFFFFF
            adrl  0
SaveTitle   str   ' Save formats '

ScrParms    dw    78
            dw    $DDD0                 ; title, close box, scroll bars, grow,
            adrl  ScrTitle              ; zoom, moves, info bar (hidden at first)
            adrl  0
            dw    0,0,0,0
            adrl  0
            dw    0,0                   ; origin
            dw    200,640               ; data: height, width (set for the picture)
            dw    400,1280              ; at most
            dw    4,8                   ; scroll steps: down, across
            dw    0,0
            adrl  0
            dw    12                    ; info bar height
            adrl  0
            adrl  DrawScrInfo
            adrl  DrawScr
            dw    122,328,183,608
            adrl  $FFFFFFFF
            adrl  0

* Buttons (control templates: ID, rect, simple button, flags, title).
InfoLTmpl   dw    7
            adrl  1
            dw    81,10,92,145
            adrl  $80000000
            dw    0,$1000
            adrl  0
            adrl  TxInfoBtn
LoadTmpl    dw    7
            adrl  2
            dw    73,160,84,295
            adrl  $80000000
            dw    0,$1000
            adrl  0
            adrl  TxLoadBtn
NextTmpl    dw    8
            adrl  5
            dw    73,160,84,295
            adrl  $80000000
            dw    $0080,$1000           ; (invisible until files wait)
            adrl  0
            adrl  TxNextBtn
            adrl  NextColors
NextColors  dw    $0000,$00E0,$0000,$00E1,$000F
InfoSTmpl   dw    7
            adrl  3
            dw    1,10,12,145
            adrl  $80000000
            dw    0,$1000
            adrl  0
            adrl  TxInfoBtn
SaveTmpl    dw    7
            adrl  4
            dw    1,160,12,296
            adrl  $80000000
            dw    $0080,$1000           ; (invisible until there is a picture)
            adrl  0
            adrl  TxSaveBtn
TxInfoBtn   str   'Info on format'
TxLoadBtn   str   'Load...'
TxNextBtn   str   'Load next'
TxSaveBtn   str   'Save...'

* Lists (List Manager records, as SuperConvert's): rect, size, rows shown,
* type (2: one at a time), first shown, control, draw routine, row height,
* member size, members, refCon, scroll bar colours.
TypeRec     dw    -1,-3,71,284
            dw    NTypes,7,2,1
            adrl  0
            adrl  DrawMem
            dw    10,12
            adrl  TypeMems
            adrl  0
            adrl  0
FmtRec      dw    94,-3,166,284
            dw    0,7,2,1
            adrl  0
            adrl  DrawMem
            dw    10,12
            adrl  0
            adrl  0
            adrl  0
SaveRec     dw    13,-2,65,284
            dw    NSaves,5,2,1
            adrl  0
            adrl  DrawMem
            dw    10,12
            adrl  SaveMems
            adrl  0
            adrl  0

* The lists' icons (640 mode pixels, 16 x 8, from SuperConvert's): by
* kind (folder, screen, true colour, save), plain and chosen.
YelGreen    hex   AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA


            put   ImgWin.s
            put   ImgTools.s
            put   LoadMulti.s
            put   ImgData.s
            put   DeskLists.s
            put   FormatInfo.s
            put   SegLib.s
