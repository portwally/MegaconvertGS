*-------------------------------------------------------------
* MonoDlg.s - the monochrome dialogs, as SuperConvert's (part of the
* Mono segment; docs/superconvert-truecolor.md 7.1, 8.1, 9): Convert
* to monochrome (from the screen or true colour image), Monochrome >
* Convert to screen / true color, and Monochrome image info.
*-------------------------------------------------------------

* MonoToDlg: Convert to monochrome... from the screen (A = 0) or true
* colour image (A = 2): the dialog (unless SKIP ME), then MonoMake.
*   out: carry clear; or carry set and A = error ($FFFF: Cancel)
MonoToDlg   ent
            phb
            phk
            plb
            sta   Src
            tdc
            sta   MDP
            ldx   Src                   ; SKIP ME for this kind: no dialog
            lda   SkipTo,x
            beq   :jx1
            jmp   :go
:jx1
            jsr   SrcSize
            lda   AskH                  ; the pop-ups start as last time
            sta   PopHT+32
            lda   AskV
            sta   PopVT+32
            lda   AskM
            sta   PopMT+32
            lda   #ToCtls
            ldx   #ToParms
            jsr   OpenDlg
            jsr   ToText
:loop       jsr   Modal
            cmp   #1
            beq   :ok
            cmp   #3
            beq   :cancel
            cmp   #4
            bne   :pop
            Tool  _SysBeep              ; (Info on options: no help yet)
            bra   :loop
:pop        cmp   #32
            bcc   :loop
            jsr   ToValues
            jsr   ToText
            PushLongAt DlgWin           ; the size text again
            Tool  _SetPort
            PushLong ToTxRect
            Tool  _InvalRect
            bra   :loop
:cancel     jsr   CloseDlg
            lda   #$FFFF
            sec
            plb
            rtl
:ok         jsr   ToValues
            pha                         ; SKIP ME for this kind
            PushLongAt DlgWin
            PushLong 2
            Tool  _GetCtlValueByID
            pla
            ldx   Src
            sta   SkipTo,x
            jsr   CloseDlg
:go         lda   AskM
            sta   MkMethod
            lda   Src
            ldx   AskH
            ldy   AskV
            jsr   MakeCore
            plb
            rtl

* ToValues: AskH, AskV, AskM from the pop-ups.
ToValues    lda   #32
            jsr   CtlValue
            sta   AskH
            lda   #33
            jsr   CtlValue
            sta   AskV
            lda   #34
            jsr   CtlValue
            sta   AskM
            rts

* ToText: the size text's substitutions: the result's size, " (clipped)",
* "(not enough memory?)".
ToText      lda   SrcW
            ldx   AskH
            jsr   Times
            stz   Clipped
            jsr   Clip5000
            sta   OutW
            ldx   #Sub0
            jsr   DecStr
            lda   SrcH
            ldx   AskV
            jsr   Times
            jsr   Clip5000
            sta   OutH
            ldx   #Sub1
            jsr   DecStr
            stz   Sub2                  ; " (clipped)"
            lda   Clipped
            beq   :mem
            ldx   #TxClipped
            ldy   #Sub2
            jsr   CopyStr
:mem        stz   Sub3                  ; is there room for it?
            lda   OutW
            clc
            adc   #7
            lsr
            lsr
            lsr
            ldx   OutH
            jsr   Mul16
            pha
            pha
            lda   MHi
            pha
            lda   MLo
            pha
            lda   uid
            pha
            pea   attrFile
            PushLong 0
            Tool  _NewHandle
            bcs   :no
            Tool  _DisposeHandle
            rts
:no         pla
            pla
            ldx   #TxNoMem
            ldy   #Sub3
            jmp   CopyStr
Clip5000    cmp   #5001
            bcc   :ok
            inc   Clipped
            lda   #5000
:ok         rts

* MonoFromDlg: Monochrome > Convert to screen (A = 0) / true color (A = 2):
* the dialog (unless SKIP ME), then MonoOut.
*   out: carry clear; or carry set and A = error ($FFFF: Cancel)
* MonoFromSet: Convert to screen's choices set to Square, 1:1, 320 mode
* (as after loading a Works of Art page).
MonoFromSet ent
            phb
            phk
            plb
            lda   #1
            sta   FAspect
            sta   FScale
            stz   F640
            plb
            rtl

MonoFromDlg ent
            phb
            phk
            plb
            sta   Dest
            tdc
            sta   MDP
            ldx   Dest
            lda   SkipFrom,x
            beq   :ask
            jmp   :go
:ask        lda   FAspect               ; the pop-ups start as last time
            sta   PopAT+32
            lda   FScale
            sta   PopST+32
            lda   FShrink
            sta   PopRT+32
            lda   #FromCtls
            ldx   #FromParms
            jsr   OpenDlg
            lda   Dest                  ; the radio buttons: by kind
            bne   :pix
            lda   #FromRad0
            bra   :rad
:pix        lda   #FromRad2
:rad        sta   mq0
            pha                         ; (NewControl2: a list of templates)
            pha
            PushLongAt DlgWin
            pea   3
            pea   ^FromRad0
            lda   mq0
            pha
            Tool  _NewControl2
            pla
            pla
            lda   F640                  ; the mode chosen
            clc
            adc   #16
            tax
            pea   1
            PushLongAt DlgWin
            pea   0
            phx
            Tool  _SetCtlValueByID
            jsr   FromText
:loop       jsr   Modal
            cmp   #1
            beq   :ok
            cmp   #3
            beq   :cancel
            cmp   #4
            bne   :other
            Tool  _SysBeep              ; (Info on options: no help yet)
            bra   :loop
:other      cmp   #16                   ; (only the radio buttons and pop-ups
            bcc   :loop                 ; change the sizes)
            jsr   FromValues
            jsr   FromText
            PushLongAt DlgWin           ; the text and the drawing again
            Tool  _SetPort
            PushLong FromTxRect
            Tool  _InvalRect
            PushLong GridRect
            Tool  _InvalRect
            bra   :loop
:cancel     jsr   CloseDlg
            lda   #$FFFF
            sec
            plb
            rtl
:ok         jsr   FromValues
            pha
            PushLongAt DlgWin
            PushLong 2
            Tool  _GetCtlValueByID
            pla
            ldx   Dest
            sta   SkipFrom,x
            jsr   CloseDlg
:go         lda   FAspect
            sta   OutAspect
            lda   FScale
            sta   OutScale
            lda   F640
            sta   Out640
            lda   FShrink
            sta   OutShrink
            lda   Dest
            jsr   OutCore
            plb
            rtl

* FromValues: the choices from the controls.
FromValues  lda   #32
            jsr   CtlValue
            sta   FAspect
            lda   #33
            jsr   CtlValue
            sta   FScale
            lda   #34
            jsr   CtlValue
            sta   FShrink
            lda   #17                   ; 640 mode (or 640-sized pixels)?
            jsr   CtlValue
            sta   F640
            rts

* FromText: the sizes text: the monochrome pixels, the resulting pixels,
* " (will be clipped)" or " (not enough memory?)"; "Shrink as" only when
* the result is smaller.
FromText    ldy   #mbW
            lda   [mblk],y
            sta   SrcW
            ldx   #Sub0
            jsr   DecStr
            ldy   #mbH
            lda   [mblk],y
            sta   SrcH
            ldx   #Sub1
            jsr   DecStr
            lda   SrcW                  ; w, h as the dialog works them out
            sta   OutW
            lda   SrcH
            sta   OutH
            lda   F640
            beq   :t
            asl   OutW
:t          lda   FAspect
            cmp   #2
            bne   :w
            asl   OutH
:w          cmp   #3
            bne   :s
            asl   OutW
:s          lda   FScale
            cmp   #2
            bcc   :sized
            jsr   Halve
            lda   FScale
            cmp   #4
            bcc   :sized
            jsr   Halve
:sized      lda   OutW
            ldx   #Sub2
            jsr   DecStr
            lda   OutH
            ldx   #Sub3
            jsr   DecStr
            stz   Sub4
            stz   Sub5
            stz   Sub6
            stz   Sub7
            lda   Dest
            bne   :true
            lda   OutW                  ; a screen: bytes a line, lines
            lsr
            ldx   F640
            beq   :b
            lsr
:b          cmp   #321
            bcs   :clip
            ldx   OutH
            cpx   #401
            bcs   :clip
            jsr   Mul16
            lda   MHi
            bne   :clip
            bra   :shrink
:true       lda   OutW
            cmp   #2001
            bcs   :clip
            lda   OutH
            cmp   #2001
            bcs   :clip
            lda   OutW                  ; room for it? (w x 2 x h)
            asl
            ldx   OutH
            jsr   Mul16
            pha
            pha
            lda   MHi
            pha
            lda   MLo
            pha
            lda   uid
            pha
            pea   attrFile
            PushLong 0
            Tool  _NewHandle
            bcs   :nomem
            Tool  _DisposeHandle
            bra   :shrink
:nomem      pla
            pla
            ldx   #TxNoMem2
            ldy   #Sub4
            jsr   CopyStr
            bra   :shrink
:clip       ldx   #TxWillClip
            ldy   #Sub4
            jsr   CopyStr
:shrink     lda   #255                  ; "Shrink as" dimmed unless smaller
            ldx   OutW
            cpx   SrcW
            bcc   :on
            ldx   OutH
            cpx   SrcH
            bcs   :hl
:on         lda   #0
:hl         pha
            PushLongAt DlgWin
            PushLong 34
            Tool  _HiliteCtlByID
            rts
Halve       lda   OutW                  ; (w + 1) / 2, (h + 1) / 2
            inc
            lsr
            sta   OutW
            lda   OutH
            inc
            lsr
            sta   OutH
            rts

*-------------------------------------------------------------
* Monochrome image info, Negative image
*-------------------------------------------------------------

* MonoInfoAlert: "The monochrome image is W by H. P% of the pixels (N out
* of T) are white." (SuperConvert's alert).
MonoInfoAlert ent
            phb
            phk
            plb
            jsr   WhiteCore             ; (A, X: the white count)
            sta   NumLo
            stx   NumHi
            stz   CSub0                 ; no selection: nothing before it
            ldy   #mbW
            lda   [mblk],y
            sta   SrcW
            jsr   CDec
            ldy   #CSub1
            jsr   CStore
            ldy   #mbH
            lda   [mblk],y
            sta   SrcH
            jsr   CDec
            ldy   #CSub2
            jsr   CStore
            lda   NumLo                 ; the white count
            sta   n0
            lda   NumHi
            sta   n0+2
            jsr   CDec32
            ldy   #CSub4
            jsr   CStore
            lda   SrcW                  ; all the pixels
            ldx   SrcH
            jsr   Mul16
            lda   MLo
            sta   n0
            sta   AllLo
            lda   MHi
            sta   n0+2
            sta   AllHi
            jsr   CDec32
            ldy   #CSub6
            jsr   CStore
            lda   NumLo                 ; white x 100 / all
            sta   n0
            lda   NumHi
            sta   n0+2
            jsr   Times100
            lda   AllLo
            sta   n1
            lda   AllHi
            sta   n1+2
            jsr   Div32n
            jsr   CDec32
            ldy   #CSub3
            jsr   CStore
            pha
            pea   0                     ; (C strings)
            PushLong CSubs
            PushLong TxMonoInfo
            Tool  _AlertWindow
            pla
            plb
            rtl

*-------------------------------------------------------------
* The dialogs' machinery
*-------------------------------------------------------------

* MonoSkips: A = 1 if "SKIP ME" is set in one of the monochrome options
* windows (for Preferences).
MonoSkips   ent
            phb
            phk
            plb
            lda   SkipTo
            ora   SkipTo+2
            ora   SkipTo+4
            ora   SkipFrom
            ora   SkipFrom+2
            ora   SkipFrom+4
            ora   Skip640
            beq   :none
            lda   #1
:none       plb
            rtl

* MonoNoSkip: Preferences' Clear all "SKIP ME" preferences: those windows
* show again.
MonoNoSkip  ent
            phb
            phk
            plb
            stz   SkipTo
            stz   SkipTo+2
            stz   SkipTo+4
            stz   SkipFrom
            stz   SkipFrom+2
            stz   SkipFrom+4
            stz   Skip640
            plb
            rtl

* OpenDlg: the dialog window from parameters X (NewWindow2; its controls
* in the list the parameters give), and the substitutions for its texts.
OpenDlg     stx   mq0
            pha
            pha
            PushLong 0                  ; no title
            PushLong 0
            lda   mq0
            cmp   #ToParms
            bne   :from
            PushLong ToRedraw
            bra   :draw
:from       PushLong FromRedraw
:draw       PushLong 0                  ; the usual frame
            pea   0                     ; the parameters: a pointer
            pea   ^ToParms
            lda   mq0
            pha
            pea   $800E
            Tool  _NewWindow2
            pla
            sta   DlgWin
            pla
            sta   DlgWin+2
            PushLong SubPtrs            ; the static texts' *0 ... *7
            Tool  _SetCtlParamPtr
            PushLongAt DlgWin           ; (made invisible: shown now)
            Tool  _ShowWindow
            rts

* CloseDlg: the dialog gone.
CloseDlg    PushLongAt DlgWin
            Tool  _CloseWindow
            rts

* Modal: A = the control the user used.
Modal       pha
            pha
            PushLong MEvent
            PushLong 0
            PushLong 0
            PushLong 0
            pea   $0008
            Tool  _DoModalWindow
            pla
            plx
            rts

* CtlValue: A = the value of control A.
CtlValue    sta   mq0
            pha
            PushLongAt DlgWin
            pea   0
            lda   mq0
            pha
            Tool  _GetCtlValueByID
            pla
            rts

* ToRedraw, FromRedraw: the dialogs' contents (the Window Manager calls
* them): the controls, the icons; FromMono also its picture.
ToRedraw    phb
            phk
            plb
            phd
            lda   MDP
            tcd
            PushLongAt DlgWin
            Tool  _DrawControls
            ldx   #MIcScr            ; the source, an arrow, monochrome
            lda   Src
            beq   :s
            ldx   #MIcTrue
:s          txa
            ldx   #160
            ldy   #4
            jsr   Icon
            lda   #IcArrowR
            ldx   #184
            ldy   #6
            jsr   Icon
            lda   #MIcMono
            ldx   #224
            ldy   #4
            jsr   Icon
            pld
            plb
            rtl
FromRedraw  phb
            phk
            plb
            phd
            lda   MDP
            tcd
            PushLongAt DlgWin
            Tool  _DrawControls
            lda   #MIcMono            ; monochrome, an arrow, the result
            ldx   #160
            ldy   #4
            jsr   Icon
            lda   #IcArrowR
            ldx   #184
            ldy   #6
            jsr   Icon
            ldx   #MIcScr
            lda   Dest
            beq   :d
            ldx   #MIcTrue
:d          txa
            ldx   #224
            ldy   #4
            jsr   Icon
            jsr   Grid
            pld
            plb
            rtl

* Icon: DrawIcon(A, at X, Y).
Icon        sty   mq1
            pea   ^MIcScr
            pha
            pea   0
            phx
            lda   mq1
            pha
            Tool  _DrawIcon
            rts

* Grid: the picture of screen pixels (a grid) and the monochrome pixels
* over them (inverted cells), as the choices make them.
Grid        PushLong GridRect
            Tool  _EraseRect
            Tool  _PenNormal
            pea   2
            pea   1
            Tool  _SetPenSize
            PushLong PatCC
            Tool  _SetPenPat
            pea   137                   ; two pointers from the text
            pea   73
            Tool  _MoveTo
            pea   156
            pea   77
            Tool  _LineTo
            pea   1
            Tool  _SetSolidPenPat
            pea   138
            pea   87
            Tool  _MoveTo
            pea   156
            pea   95
            Tool  _LineTo
            ldx   #0                    ; the grid: lines across
:across     phx
            pea   10
            lda   GridV,x
            pha
            Tool  _MoveTo
            pea   138
            plx
            phx
            lda   GridV,x
            pha
            Tool  _LineTo
            plx
            inx
            inx
            cpx   #6
            bcc   :across
            lda   #32                   ; and down (16 apart for 640 mode)
            ldx   F640
            beq   :step
            lda   #16
:step       sta   mq2
            lda   #10
:down       sta   mq3
            pha
            pea   70
            Tool  _MoveTo
            lda   mq3
            pha
            pea   104
            Tool  _LineTo
            lda   mq3
            clc
            adc   mq2
            cmp   #139
            bcc   :down
            Tool  _PenNormal
            lda   FScale                ; the cells: by scaling
            ldx   #0
            cmp   #2
            bcc   :c
            ldx   #2
            cmp   #4
            bcc   :c
            ldx   #4
:c          lda   CellH,x
            sta   mq4
            lda   CellW,x
            sta   mq5
            lda   FAspect
            cmp   #2
            bne   :wide
            lda   mq4                   ; tall: 2H + 2 (30: 31)
            asl
            clc
            adc   #2
            cmp   #30
            bne   :th
            inc
:th         sta   mq4
            bra   :cells
:wide       cmp   #3
            bne   :cells
            lda   mq5                   ; wide: 2W + 4
            asl
            clc
            adc   #4
            sta   mq5
:cells      lda   #72
            sta   CellR                 ; top
:row        lda   #13
            sta   CellR+2               ; left
:cell       lda   CellR
            clc
            adc   mq4
            sta   CellR+4
            lda   CellR+2
            clc
            adc   mq5
            sta   CellR+6
            PushLong CellR
            Tool  _InvertRect
            lda   CellR+6               ; the next: right + 4
            clc
            adc   #4
            sta   CellR+2
            clc
            adc   mq5
            cmp   #140
            bcc   :cell
            lda   CellR+4               ; the next row: bottom + 2 (88: 89)
            clc
            adc   #2
            cmp   #88
            bne   :r
            inc
:r          sta   CellR
            cmp   #105
            bcc   :row
            rts

*-------------------------------------------------------------
* Strings
*-------------------------------------------------------------

* DecStr: A in decimal as a C string at X (the static texts' *0 ...).
DecStr      stx   mq6
            jsr   Digits
            ldy   mq6
            jmp   CStore

* CDec: A in decimal into Digit; CDec32: n0 (32 bits). CStore: as a C
* string at Y.
CDec        sta   n0
            stz   n0+2
CDec32      jmp   Digits32
CStore      sty   mq6
            ldx   #0
            sep   #$20
            mx    %10
:c          lda   Digit,x
            sta   |0,y
            iny
            inx
            cpx   NDig
            bcc   :c
            lda   #0
            sta   |0,y
            rep   #$20
            mx    %00
            rts

* Digits: A's decimal digits into Digit (NDig of them); Digits32: n0's.
Digits      sta   n0
            stz   n0+2
Digits32    stz   NDig
            ldx   #10                   ; (digits come out last first)
:d          lda   #10
            sta   n1
            stz   n1+2
            phx
            jsr   Div32r                ; n0 = n0 / 10, remainder in mq7
            plx
            lda   mq7
            clc
            adc   #'0'
            dex
            sep   #$20
            mx    %10
            sta   DigBuf,x
            rep   #$20
            mx    %00
            lda   n0
            ora   n0+2
            bne   :d
            stx   mq0                   ; the digits to the front
            ldy   #0
:mv         lda   DigBuf,x
            sep   #$20
            mx    %10
            sta   Digit,y
            rep   #$20
            mx    %00
            iny
            inx
            cpx   #10
            bcc   :mv
            sty   NDig
            rts

* PutDigits: Digit as a Pascal string at Y.
PutDigits   lda   NDig
            sep   #$20
            mx    %10
            sta   |0,y
            rep   #$20
            mx    %00
            ldx   #0
:c          lda   Digit,x
            sep   #$20
            mx    %10
            sta   |1,y
            rep   #$20
            mx    %00
            iny
            inx
            cpx   NDig
            bcc   :c
            rts

* CopyStr: the Pascal string at X to Y as a C string.
CopyStr     lda   |0,x
            and   #$00FF
            sta   mq0
            inx
            sep   #$20
            mx    %10
:c          lda   |0,x
            sta   |0,y
            inx
            iny
            dec   mq0
            bne   :c
            lda   #0
            sta   |0,y
            rep   #$20
            mx    %00
            rts

* Div32r: n0 = n0 / n1, the remainder in mq7 (n1 at most 16 bits).
Div32r      stz   mq7
            ldx   #32
:bit        asl   n0
            rol   n0+2
            rol   mq7
            lda   mq7
            cmp   n1
            bcc   :no
            sbc   n1
            sta   mq7
            inc   n0
:no         dex
            bne   :bit
            rts

* Div32n: n0 = n0 / n1 (32 bits each).
Div32n      stz   mq6
            stz   mq7
            ldx   #32
:bit        asl   n0
            rol   n0+2
            rol   mq6
            rol   mq7
            lda   mq6
            sec
            sbc   n1
            tay
            lda   mq7
            sbc   n1+2
            bcc   :no
            sta   mq7
            sty   mq6
            inc   n0
:no         dex
            bne   :bit
            rts

* Times100: n0 = n0 x 100 (x 64 + x 32 + x 4).
Times100    lda   n0
            sta   mq4
            lda   n0+2
            sta   mq5
            asl   mq4                   ; x 4
            rol   mq5
            asl   mq4
            rol   mq5
            lda   mq4
            sta   mq0
            lda   mq5
            sta   mq1
            ldx   #3                    ; x 32
:a          asl   mq4
            rol   mq5
            dex
            bne   :a
            lda   mq4
            clc
            adc   mq0
            sta   mq0
            lda   mq5
            adc   mq1
            sta   mq1
            asl   mq4                   ; x 64
            rol   mq5
            lda   mq4
            clc
            adc   mq0
            sta   n0
            lda   mq5
            adc   mq1
            sta   n0+2
            rts

*-------------------------------------------------------------
* Data
*-------------------------------------------------------------
MDP         dw    0
DlgWin      adrl  0
Clipped     dw    0
AskH        dw    1                     ; ToMono's choices (kept)
AskV        dw    1
AskM        dw    1
SkipTo      dw    0,0,0                 ; SKIP ME, by kind (0, 2)
FAspect     dw    1                     ; FromMono's (kept)
FScale      dw    1
F640        dw    0
FShrink     dw    1
SkipFrom    dw    0,0,0
NumLo       dw    0
NumHi       dw    0
AllLo       dw    0
AllHi       dw    0
NDig        dw    0
Digit       ds    12
DigBuf      ds    12
MEvent      dw    0                     ; (an extended event record)
            adrl  0
            adrl  0
            dw    0,0
            dw    0
            adrl  0
            adrl  $001FFFFF
            adrl  0
            dw    0
            adrl  0,0,0
            dw    0,0
SubPtrs     adrl  Sub0,Sub1,Sub2,Sub3,Sub4,Sub5,Sub6,Sub7
Sub0        ds    12
Sub1        ds    12
Sub2        ds    24
Sub3        ds    24
Sub4        ds    24
Sub5        ds    2
Sub6        ds    2
Sub7        ds    2
TxClipped   str   ' (clipped)'
TxNoMem     str   '(not enough memory?)'
TxWillClip  str   ' (will be clipped)'
TxNoMem2    str   ' (not enough memory?)'
CSubs       adrl  CSub0,CSub1,CSub2,CSub3,CSub4,CSub5,CSub6
CSub0       ds    32
CSub1       ds    12
CSub2       ds    12
CSub3       ds    12
CSub4       ds    12
CSub5       ds    2
CSub6       ds    12
TxMonoInfo  asc   '60~The *0monochrome image is *1 by *2.',0D,0D
            asc   '*3% of the pixels (*4 out of *6) are white.~^#0',00
ToTxRect    dw    50,15,60,500
FromTxRect  dw    69,160,105,500
GridRect    dw    70,10,105,140
GridV       dw    70,87,104
CellH       dw    14,6,2
CellW       dw    28,12,4
CellR       dw    0,0,0,0
PatCC       hex   CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC

* The windows (NewWindow2 parameters, as SuperConvert's: no title, frame
* $2000; the control list's address is set before use).
ToParms     dw    $50,$2000
            adrl  0,0
            dw    0,0,0,0
            adrl  0
            dw    0,0,0,0,0,0,0,0,0,0
            adrl  0
            dw    0
            adrl  0,0,0                 ; (frame, info and content routines)
            dw    50,120,145,520
            adrl  $FFFFFFFF
            adrl  ToCtls
            dw    $0003
FromParms   dw    $50,$2000
            adrl  0,0
            dw    0,0,0,0
            adrl  0
            dw    0,0,0,0,0,0,0,0,0,0
            adrl  0
            dw    0
            adrl  0,0,0                 ; (frame, info and content routines)
            dw    30,120,170,520
            adrl  $FFFFFFFF
            adrl  FromCtls
            dw    $0003

* Their controls (SuperConvert's templates).
ToCtls      adrl  ToTxt,ToSkip,PopHT,PopVT,PopMT,ToOK,ToCancel,ToInfo,0
FromCtls    adrl  FrTxt1,FrTxt2,FrSkip,PopAT,PopST,PopRT,FrOK,FrCancel,FrInfo,0
ToTxt       dw    8
            adrl  0
            dw    50,15,60,500
            adrl  $81000000
            dw    $0002,$1000
            adrl  0
            adrl  TxWillBe
            dw    28
ToSkip      dw    10
            adrl  2
            dw    82,10,0,0
            adrl  $82000000
            dw    0,$3000
            adrl  0
            adrl  TxSkipMe
            dw    0
            adrl  0
            db    $13,$13
            dw    0,0
PopHT       dw    9
            adrl  32
            dw    17,10,0,0
            adrl  $87000000
            dw    $0042,$3004
            adrl  0
            dw    0
            adrl  PopHSize
            dw    1
PopVT       dw    9
            adrl  33
            dw    17,210,0,0
            adrl  $87000000
            dw    $0042,$3004
            adrl  0
            dw    0
            adrl  PopVSize
            dw    1
PopMT       dw    9
            adrl  34
            dw    33,10,0,0
            adrl  $87000000
            dw    $0042,$3004
            adrl  0
            dw    0
            adrl  PopMethod
            dw    1
ToOK        dw    9
            adrl  1
            dw    65,300,78,380
            adrl  $80000000
            dw    $0001,$3000
            adrl  0
            adrl  TxOKm
            adrl  0
            db    $0D,$0D
            dw    0,0
ToCancel    dw    9
            adrl  3
            dw    65,200,78,280
            adrl  $80000000
            dw    0,$3000
            adrl  0
            adrl  TxCancelm
            adrl  0
            db    $1B,$1B
            dw    0,0
ToInfo      dw    7
            adrl  4
            dw    65,15,78,170
            adrl  $80000000
            dw    0,$3000
            adrl  0
            adrl  TxInfoOpt
FrTxt1      dw    8
            adrl  0
            dw    15,10,25,170
            adrl  $81000000
            dw    0,$1000
            adrl  0
            adrl  TxResult
            dw    16
FrTxt2      dw    8
            adrl  0
            dw    69,160,105,500
            adrl  $81000000
            dw    $0002,$1000
            adrl  0
            adrl  TxPixels
            dw    62
FrSkip      dw    10
            adrl  2
            dw    127,10,0,0
            adrl  $82000000
            dw    0,$3000
            adrl  0
            adrl  TxSkipMe
            dw    0
            adrl  0
            db    $13,$13
            dw    0,0
PopAT       dw    9
            adrl  32
            dw    17,210,29,390
            adrl  $87000000
            dw    $0042,$3004
            adrl  0
            dw    105
            adrl  PopAspect
            dw    1
PopST       dw    9
            adrl  33
            dw    33,210,45,370
            adrl  $87000000
            dw    $0042,$3004
            adrl  0
            dw    105
            adrl  PopScale
            dw    1
PopRT       dw    9
            adrl  34
            dw    49,10,0,0
            adrl  $87000000
            dw    $0042,$3004
            adrl  0
            dw    0
            adrl  PopShrink
            dw    1
FrOK        dw    9
            adrl  1
            dw    110,300,123,380
            adrl  $80000000
            dw    $0001,$3000
            adrl  0
            adrl  TxOKm
            adrl  0
            db    $0D,$0D
            dw    0,0
FrCancel    dw    9
            adrl  3
            dw    110,200,123,280
            adrl  $80000000
            dw    0,$3000
            adrl  0
            adrl  TxCancelm
            adrl  0
            db    $1B,$1B
            dw    0,0
FrInfo      dw    7
            adrl  4
            dw    110,15,123,170
            adrl  $80000000
            dw    0,$3000
            adrl  0
            adrl  TxInfoOpt
* The radio buttons, added afterwards: 320/640 mode (to a screen) or
* 320/640-sized pixels (to true colour).
FromRad0    adrl  Rad16S,Rad17S,0
FromRad2    adrl  Rad16T,Rad17T,0
Rad16S      dw    10
            adrl  16
            dw    25,10,0,0
            adrl  $84000000
            dw    0,$3000
            adrl  0
            adrl  Tx320Mode
            dw    0
            adrl  0
            db    '3','3'
            dw    0,$0100
Rad17S      dw    10
            adrl  17
            dw    35,10,0,0
            adrl  $84000000
            dw    0,$3000
            adrl  0
            adrl  Tx640Mode
            dw    0
            adrl  0
            db    '6','6'
            dw    0,$0100
Rad16T      dw    10
            adrl  16
            dw    25,10,0,0
            adrl  $84000000
            dw    0,$3000
            adrl  0
            adrl  Tx320Pix
            dw    0
            adrl  0
            db    '3','3'
            dw    0,$0100
Rad17T      dw    10
            adrl  17
            dw    35,10,0,0
            adrl  $84000000
            dw    0,$3000
            adrl  0
            adrl  Tx640Pix
            dw    0
            adrl  0
            db    '6','6'
            dw    0,$0100
