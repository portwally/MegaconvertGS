*-------------------------------------------------------------
* FilterUI.s - the True color menu's dialogs (part of the Filter
* segment): SuperConvert's Factor dialog for Blur, Sharpen and Find
* edges (its window and controls), and the message shown while a
* filter works (its texts).
*-------------------------------------------------------------

* FilterAsk: the Factor dialog, showing factor A at first.
*   out: carry clear and A = the factor (0-99), or carry set: cancelled
FilterAsk   ent
            phb
            phk
            plb
            sta   AskVal
            jsr   ValText               ; (the edit line starts with it)
            pha
            pha
            PushLong FacParms
            Tool  _NewWindow
            pla
            sta   AskWin
            pla
            sta   AskWin+2
            ldx   #0                    ; its controls
:ctl        phx
            pha
            pha
            PushLongAt AskWin
            pea   0                     ; one template, by pointer
            pea   ^FacOK
            lda   FacTmpls,x
            pha
            Tool  _NewControl2
            pla
            pla
            plx
            inx
            inx
            cpx   #10
            bcc   :ctl
:loop       pha                         ; result: the control hit
            pha
            PushLong AskEvent
            PushLong 0                  ; no update, hook or beep routines
            PushLong 0
            PushLong 0
            pea   $0008
            Tool  _DoModalWindow
            pla
            plx
            cmp   #1
            beq   :ok
            cmp   #2
            bne   :loop
            jsr   :close                ; Cancel
            sec
            plb
            rtl
:ok         PushLongAt AskWin           ; OK: the edit line's number
            PushLong 3
            PushLong AskBuf
            Tool  _GetLETextByID
            jsr   ParseVal
            bcc   :good
            pha                         ; not 0-99: say so, and again
            pea   0
            PushLong 0
            PushLong MsgFactor
            Tool  _AlertWindow
            pla
            bra   :loop
:good       jsr   :close
            lda   AskVal
            clc
            plb
            rtl
:close      PushLongAt AskWin
            Tool  _CloseWindow
            rts

* FacDraw: the dialog's contents (its controls).
FacDraw     phb
            phk
            plb
            PushLongAt AskWin
            Tool  _DrawControls
            plb
            rtl

* ValText: AskText = AskVal (0-99) as a Pascal string.
ValText     lda   AskVal
            ldx   #0
:tens       cmp   #10
            bcc   :units
            sbc   #10
            inx
            bra   :tens
:units      sep   #$20
            mx    %10
            ora   #'0'
            sta   AskText+2
            txa
            beq   :one
            ora   #'0'
            sta   AskText+1
            lda   #2
            sta   AskText
            rep   #$20
            mx    %00
            rts
            mx    %10
:one        lda   AskText+2
            sta   AskText+1
            lda   #1
            sta   AskText
            rep   #$20
            mx    %00
            rts

* ParseVal: AskVal = the number in AskBuf (a Pascal string), as the ROM's
* Dec2Int reads it: spaces first skipped, nothing (or only spaces) is 0,
* then digits only.   out: carry set if it isn't one
ParseVal    stz   AskVal
            lda   AskBuf
            and   #$00FF
            beq   :ok
            tay
            ldx   #1
:space      lda   AskBuf,x
            and   #$00FF
            cmp   #' '
            bne   :digit
            inx
            dey
            bne   :space
:ok         clc
            rts
:digit      lda   AskBuf,x
            and   #$00FF
            sec
            sbc   #'0'
            bcc   :bad
            cmp   #10
            bcs   :bad
            sta   fs
            lda   AskVal                ; x 10 + the digit
            asl
            sta   ft
            asl
            asl
            clc
            adc   ft
            adc   fs
            sta   AskVal
            inx
            dey
            bne   :digit
            clc
            rts
:bad        sec
            rts

* FilterBusy: while filter A works: SuperConvert's progress dialog with its
* message (histogram equalization: only the watch). FilterIdle: gone.
FilterBusy  ent
            phb
            phk
            plb
            tax
            tdc
            sta   FxDP
            txa
            beq   :watch
            asl
            tax
            lda   BusyTexts,x
            jsr   ProgOpen
            plb
            rtl
:watch      Tool  _WaitCursor
            plb
            rtl
FilterIdle  ent
            phb
            phk
            plb
            jsr   ProgClose
            Tool  _InitCursor
            plb
            rtl

*-------------------------------------------------------------
* Data
*-------------------------------------------------------------
AskVal      dw    50
AskWin      adrl  0
AskText     ds    3
AskBuf      ds    256
AskEvent    dw    0                     ; (an extended event record)
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
MsgFactor   asc   '33/Factor must be a number in the range 0-99./^#4',00

* The Factor dialog: its window (SuperConvert's: an alert frame at
* 83,206,130,432) and controls.
FacParms    dw    78
            dw    $2068                 ; alert frame, clicks, visible, controls
            adrl  0
            adrl  0
            dw    0,0,0,0
            adrl  0
            dw    0,0,0,0,0,0,0,0,0,0
            adrl  0
            dw    0
            adrl  0
            adrl  0
            adrl  FacDraw
            dw    83,206,130,432
            adrl  $FFFFFFFF
            adrl  0
FacTmpls    da    FacOK,FacCancel,FacEdit,FacPct,FacLabel
FacOK       dw    9                     ; OK: the default button (Return)
            adrl  1
            dw    29,124,42,198
            adrl  $80000000
            dw    $0001,$3000
            adrl  0
            adrl  TxOK
            adrl  0
            db    $0D,$0D
            dw    0,0
FacCancel   dw    7                     ; Cancel
            adrl  2
            dw    29,29,42,108
            adrl  $80000000
            dw    0,$3000
            adrl  0
            adrl  TxCancel
FacEdit     dw    8                     ; the factor: two characters
            adrl  3
            dw    8,116,21,146
            adrl  $83000000
            dw    0,$7000
            adrl  0
            dw    2
            adrl  AskText
FacPct      dw    9
            adrl  4
            dw    10,149,26,169
            adrl  $81000000
            dw    0,$1000
            adrl  0
            adrl  TxPct
            dw    1,0
FacLabel    dw    9
            adrl  5
            dw    10,56,20,109
            adrl  $81000000
            dw    0,$1000
            adrl  0
            adrl  TxFactor
            dw    7,0
TxOK        str   'OK'
TxCancel    str   'Cancel'
TxPct       asc   '%'
TxFactor    asc   'Factor:'

* SuperConvert's messages, by filter.
BusyTexts   da    TxEq,TxMed,TxSig,TxEmb,TxBlur,TxSharp,TxSol,TxEdge,TxMore,TxLess
TxEq        str   'Equalizing image histogram'
TxMed       str   'Performing median filter'
TxSig       str   'Performing sigma filter'
TxEmb       str   'Embossing image'
TxBlur      str   'Blurring image'
TxSharp     str   'Sharpening image'
TxSol       str   'Solarizing image'
TxEdge      str   'Finding image edges'
TxMore      str   'Increasing image contrast'
TxLess      str   'Decreasing image contrast'
