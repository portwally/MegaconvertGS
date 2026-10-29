*-------------------------------------------------------------
* SaveDlg.s - Save conversion's dialogs, as SuperConvert's (part of the
* Save segment; docs/superconvert-file.md 4.3-4.6): the size of the saved
* picture, the size limit, where the picture goes in a larger or smaller
* area, and what the format can't hold. The picture to save is then made
* at that size (the canvas the savers read).
*-------------------------------------------------------------

* SaveAsk: the dialogs for save format A (MegaconvertGS's number), for
* the screen image (scrp, pw, ph, p640; dsel, dselr: its selection).
*   out: carry set if cancelled (A = $FFFF), or A = an error; else the
*   canvas: dctl (pointer), cstr, cscb, cpal, darg = bytes a line, dact =
*   lines (SaveFree disposes of it)
SaveAsk     ent
            phb
            phk
            plb
            sta   SvFmt
            ldx   #0                    ; (the formats' own windows too, unless
            lda   TstSize               ; a test answers, or says to show them)
            bne   :dl
            inx
:dl         lda   TstOpts
            beq   :dl2
            ldx   #1
:dl2        stx   DlgOn
            lda   SvFmt
            asl                         ; the format's record (SuperConvert's)
            tax
            lda   SvRecs,x
            sta   Rec
            ldx   Rec
            lda   |0,x                  ; warnings, sizes, default, maximum
            sta   RWarn
            lda   |2,x
            and   #$00FF
            sta   RSizes
            lda   |3,x
            and   #$00FF
            sta   RDefault
            lda   |4,x
            sta   RMaxW
            lda   |6,x
            sta   RMaxH
            stz   STop                  ; the original: the image, or its
            stz   SLeft                 ; selection (whole bytes)
            lda   pw
            ldx   p640
            beq   :b320
            clc
            adc   #3
            lsr
            lsr
            bra   :bytes
:b320       inc
            lsr
:bytes      sta   SBytes
            lda   ph
            sta   SLines
            lda   #TxSameOrig
            sta   SizeItem2+12
            lda   dsel
            beq   :size
            lda   dselr
            sta   STop
            lda   dselr+2
            lsr
            lsr
            sta   SLeft
            lda   dselr+6
            lsr
            lsr
            sec
            sbc   SLeft
            sta   SBytes
            lda   dselr+4
            sec
            sbc   dselr
            sta   SLines
            lda   #TxSameClip
            sta   SizeItem2+12
:size       jsr   SizeDlg               ; the size
            bcc   :limit
            jmp   SvCancel
:limit      lda   RWarn                 ; too large for the format?
            and   #$1000
            beq   :align
            lda   SBytes
            cmp   RMaxW
            beq   :w
            bcs   :big
:w          lda   SLines
            cmp   RMaxH
            beq   :align
            bcc   :align
:big        pha                         ; "Image is much too large ..."
            pea   0
            PushLong 0
            PushLong TxTooLarge
            Tool  _AlertWindow
            pla
            jmp   SvCancel
:align      stz   HOff                  ; where it goes
            stz   VOff
            lda   CBytes
            cmp   SBytes
            bne   :ask
            lda   CLines
            cmp   SLines
            beq   :make
:ask        jsr   AlignDlg
            bcc   :make
            jmp   SvCancel
:make       jsr   MakeCanvas            ; the picture at that size
            bcc   :warn
            plb
            rtl
:warn       jsr   Warnings              ; what the format can't hold
            bcc   :opts
:no         jsr   FreeCanvas
            jmp   SvCancel
:opts       lda   SvFmt                 ; the format's own options (Hex data)
            cmp   #9
            bne   :done
            jsr   HexOpts
            bcs   :no
:done       lda   CanvP
            sta   dctl
            lda   CanvP+2
            sta   dctl+2
            lda   CBytes
            sta   darg
            lda   CLines
            sta   dact
            clc
            plb
            rtl
SvCancel    lda   #$FFFF
            sec
            plb
            rtl

* SaveFree: the canvas disposed of.
SaveFree    ent
            phb
            phk
            plb
            jsr   FreeCanvas
            plb
            rtl
FreeCanvas  lda   CanvH
            ora   CanvH+2
            beq   :none
            PushLongAt CanvH
            Tool  _DisposeHandle
            stz   CanvH
            stz   CanvH+2
:none       rts

*-------------------------------------------------------------
* "Select size of saved picture:"
*-------------------------------------------------------------

* SizeDlg: CBytes, CLines: the size chosen (items 2-6: the original, one
* screen, a page, two screens high, two screens wide). The format's record
* says which can be chosen and which is the default.
*   out: carry set: Cancel save
SizeDlg     lda   TstSize               ; (a test's answer: no dialog)
            beq   :show
            sta   Item
            jmp   :chosen
:show       pha                         ; the dialog
            pha
            PushLong SizeTmpl
            Tool  _GetNewModalDialog
            pla
            sta   DlgP
            pla
            sta   DlgP+2
            lda   #2                    ; the sizes the format can't take,
            sta   Item                  ; dimmed
:dim        lda   Item
            sec
            sbc   #2
            tax
            lda   SzBits,x
            and   #$00FF
            and   RSizes
            bne   :next
            pea   255
            pha
            pha
            PushLongAt DlgP
            lda   Item
            pha
            Tool  _GetControlDItem
            Tool  _HiliteControl
:next       inc   Item
            lda   Item
            cmp   #7
            bcc   :dim
            lda   #2                    ; the default
            sta   Item
:def        lda   Item
            sec
            sbc   #2
            tax
            lda   SzBits,x
            and   #$00FF
            and   RDefault
            beq   :nd
            lda   Item
            pha
            PushLongAt DlgP
            Tool  _SetDefButton
            bra   :run
:nd         inc   Item
            lda   Item
            cmp   #7
            bcc   :def
:run        pha                         ; the choice
            PushLong 0
            Tool  _ModalDialog
            pla
            sta   Item
            PushLongAt DlgP
            Tool  _CloseDialog
:chosen     lda   Item
            cmp   #2
            bcc   :cancel
            cmp   #7
            bcs   :cancel
            asl
            tax
            lda   Widths-4,x
            sta   CBytes
            lda   Heights-4,x
            sta   CLines
            cpx   #4                    ; (item 2: the original)
            bne   :ok
:orig       lda   SBytes
            sta   CBytes
            lda   SLines
            sta   CLines
:ok         clc
            rts
:cancel     sec
            rts

*-------------------------------------------------------------
* "Select alignment of saved area within picture:"
*-------------------------------------------------------------

* AlignDlg: HOff, VOff: where the new area starts in the picture (bytes,
* lines; negative: before it). Its buttons are the ones the size change
* needs: left, centre, right across; top, centre, bottom down.
*   out: carry set: Cancel save
AlignDlg    lda   TstAlign              ; (a test's answer: no dialog)
            beq   :show
            sta   Item
            jmp   :chosen
:show       pha
            pha
            PushLong AlignTmpl
            Tool  _GetNewModalDialog
            pla
            sta   DlgP
            pla
            sta   DlgP+2
            lda   CBytes                ; across differs?
            cmp   SBytes
            beq   :down
            lda   #ItCL
            jsr   AddItem
            lda   #ItCR
            jsr   AddItem
            lda   CLines
            cmp   SLines
            beq   :run
            lda   #ItTL                 ; both: the corners and edges too
            jsr   AddItem
            lda   #ItTR
            jsr   AddItem
            lda   #ItBL
            jsr   AddItem
            lda   #ItBR
            jsr   AddItem
            lda   #ItTC
            jsr   AddItem
            lda   #ItBC
            jsr   AddItem
            bra   :run
:down       lda   #ItTC                 ; down only
            jsr   AddItem
            lda   #ItBC
            jsr   AddItem
:run        pha
            PushLong 0
            Tool  _ModalDialog
            pla
            sta   Item
            PushLongAt DlgP
            Tool  _CloseDialog
:chosen     lda   Item
            cmp   #2
            beq   :cancel
            lda   SBytes                ; across: 0 left, all right, half
            sec                         ; centred
            sbc   CBytes
            sta   HOff
            lda   Item
            cmp   #48
            beq   :h0
            cmp   #16
            beq   :h0
            cmp   #50
            beq   :h0
            cmp   #49
            beq   :v
            cmp   #17
            beq   :v
            cmp   #51
            beq   :v
            lda   HOff
            cmp   #$8000                ; (halved keeping the sign)
            ror
            sta   HOff
            bra   :v
:h0         stz   HOff
:v          lda   SLines                ; down: 0 top, all bottom, half
            sec
            sbc   CLines
            sta   VOff
            lda   Item
            cmp   #48
            beq   :v0
            cmp   #32
            beq   :v0
            cmp   #49
            beq   :v0
            cmp   #50
            beq   :done
            cmp   #33
            beq   :done
            cmp   #51
            beq   :done
            lda   VOff
            cmp   #$8000
            ror
            sta   VOff
            bra   :done
:v0         stz   VOff
:done       clc
            rts
:cancel     sec
            rts

* AddItem: the item whose template is at A added to the dialog.
AddItem     tax
            PushLongAt DlgP
            pea   ^ItCL
            phx
            Tool  _GetNewDItem
            rts

*-------------------------------------------------------------
* The picture at the size chosen
*-------------------------------------------------------------

* MakeCanvas: CanvP: the new picture, CBytes x CLines: its line r is the
* original's line r + VOff (from its byte HOff), outside it colour 0 and
* the first or last line's mode; its colour tables the screen image's.
* Lines of 160 bytes (320 if wider), the SCBs after them, then (from a
* 256-byte boundary past the SCBs) the colour tables: one screen has a
* $C1 file's layout.
*   out: carry set and A = error (no memory)
MakeCanvas  lda   #160
            ldx   CBytes
            cpx   #161
            bcc   :str
            lda   #320
:str        sta   cstr
            ldx   CLines                ; SCBs at cstr x lines
            jsr   Mul16S
            sta   cscb
            clc
            adc   #256
            ldx   CLines
            cpx   #257
            bcc   :pal
            clc
            adc   #256
:pal        sta   cpal
            clc
            adc   #512
            sta   CvSize
            pha                         ; the block
            pha
            pea   0
            lda   CvSize
            pha
            lda   uid
            pha
            pea   $C018                 ; (locked, fixed, within a bank)
            PushLong 0
            Tool  _NewHandle
            pla
            sta   CanvH
            pla
            sta   CanvH+2
            bcc   :got
            stz   CanvH
            stz   CanvH+2
            sec
            rts
:got        lda   CanvH
            sta   cp0
            lda   CanvH+2
            sta   cp0+2
            ldy   #2
            lda   [cp0],y
            sta   CanvP+2
            lda   [cp0]
            sta   CanvP
            sta   cp0
            lda   CanvP+2
            sta   cp0+2
            stz   CR                    ; each line
:line       lda   CR
            cmp   CLines
            bcc   :one
            jmp   :tables
:one        clc                         ; its source line
            adc   VOff
            sta   SR
            bmi   :before
            cmp   SLines
            bcs   :after
            clc
            adc   STop
            sta   SRow                  ; (the screen image's line)
            jsr   Bytes                 ; its bytes
            lda   SRow
            bra   :scb
:before     jsr   Zeros                 ; above the picture: its first line's
            lda   STop                  ; mode
            bra   :scb
:after      jsr   Zeros                 ; below: its last line's
            lda   STop
            clc
            adc   SLines
            dec
:scb        clc
            adc   #scbOffset
            tay
            lda   [scrp],y
            and   #$00FF
            sta   CW
            lda   CR
            clc
            adc   cscb
            tay
            sep   #$20
            mx    %10
            lda   CW
            sta   [cp0],y
            rep   #$20
            mx    %00
            inc   CR
            jmp   :line
:tables     ldy   #palOffset            ; the colour tables
            ldx   cpal
:t          lda   [scrp],y
            phy
            txy
            sta   [cp0],y
            ply
            iny
            iny
            inx
            inx
            cpy   #palOffset+512
            bcc   :t
            clc
            rts

* Bytes: canvas line CR from screen line SRow: byte j is the screen's
* byte SLeft + HOff + j while that is within the original, else 0.
Bytes       lda   CR
            ldx   cstr
            jsr   Mul16S
            sta   CDst
            lda   SRow
            ldx   #160
            jsr   Mul16S
            clc
            adc   SLeft
            sta   CSrc
            ldx   #0                    ; j
:b          cpx   CBytes
            bcs   :done
            txa                         ; within the original?
            clc
            adc   HOff
            bmi   :zero
            cmp   SBytes
            bcs   :zero
            clc
            adc   CSrc
            tay
            lda   [scrp],y
            bra   :put
:zero       lda   #0
:put        sta   CW
            txa
            clc
            adc   CDst
            tay
            sep   #$20
            mx    %10
            lda   CW
            sta   [cp0],y
            rep   #$20
            mx    %00
            inx
            bra   :b
:done       rts

* Zeros: canvas line CR all colour 0.
Zeros       lda   CR
            ldx   cstr
            jsr   Mul16S
            tay
            ldx   CBytes
            sep   #$20
            mx    %10
            lda   #0
:z          sta   [cp0],y
            iny
            dex
            bne   :z
            rep   #$20
            mx    %00
            rts

* Mul16S: A = A x X (16 bits).
Mul16S      sta   CMa
            stx   CMb
            lda   #0
            ldx   #16
:bit        asl
            asl   CMb
            bcc   :next
            clc
            adc   CMa
:next       dex
            bne   :bit
            rts

*-------------------------------------------------------------
* "Can't save, the specified format cannot handle:"
*-------------------------------------------------------------

* Warnings: the canvas's lines checked against the format's warning bits
* (640 mode, both modes, colour tables past 0, 640 mode dithering, other
* than 640 dither mode with the default colours); for each that applies
* a line in the alert. Save anyway goes on.
*   out: carry set: Cancel save
Warnings    stz   Found                 ; bit 0: a 640 line, 1: a 320 line,
            stz   CR                    ; 2: a table past 0, 3: dithering
:line       lda   CR
            cmp   CLines
            bcs   :lines
            clc
            adc   cscb
            tay
            lda   [cp0],y
            and   #$00FF
            sta   CW
            and   #$0080
            beq   :n320
            lda   #1
            tsb   Found
            jsr   Dither                ; its table: four pure colours?
            bra   :pal
:n320       lda   #2
            tsb   Found
:pal        lda   CW
            and   #$000F
            beq   :next
            lda   #4
            tsb   Found
:next       inc   CR
            bra   :line
:lines      stz   Cond                  ; each warning's condition
            lda   Found
            and   #1
            beq   :c1
            lda   #1                    ; => 640-mode graphics.
            tsb   Cond
:c1         lda   Found
            and   #3
            cmp   #3
            bne   :c2
            lda   #2                    ; => Mixed 320- and 640-mode graphics.
            tsb   Cond
:c2         lda   Found
            and   #4
            beq   :c3
            lda   #4                    ; => Multiple color palettes.
            tsb   Cond
:c3         lda   Found
            and   #8
            beq   :c4
            lda   #8                    ; => 640-mode dithering.
            tsb   Cond
:c4         lda   Found                 ; => Anything but 640 dither mode,
            and   #6                    ; default colors: unless all lines
            bne   :c4yes                ; 640 mode, table 0, the standard
            jsr   StdColors             ; colours
            bcc   :c5
:c4yes      lda   #16
            tsb   Cond
:c5         lda   Cond                  ; the lines the format warns of
            and   RWarn
            and   #$001F
            sta   Cond
            sta   LastCond
            bne   :alert
            clc
            rts
:alert      lda   TstWarn               ; (a test's answer: no alert)
            beq   :texts
            cmp   #3
            bne   :jx1
            jmp   :go
:jx1
            sec
            rts
:texts      ldx   #0                    ; ^0 ... ^3
            ldy   #0
:w          cpx   #5*2
            bcs   :params
            lsr   Cond
            bcc   :nw
            cpy   #4*4
            bcs   :nw
            lda   WarnTx,x
            sta   Params,y
            lda   #^WarnTx0
            sta   Params+2,y
            iny
            iny
            iny
            iny
:nw         inx
            inx
            bra   :w
:params     cpy   #4*4                  ; the rest: a space
            bcs   :show
            lda   #TxBlank
            sta   Params,y
            lda   #^TxBlank
            sta   Params+2,y
            iny
            iny
            iny
            iny
            bra   :params
:show       PushLongAt Params
            PushLongAt Params+4
            PushLongAt Params+8
            PushLongAt Params+12
            Tool  _ParamText
            pha
            PushLong WarnTmpl
            PushLong 0
            Tool  _NoteAlert
            pla
            cmp   #3                    ; Save anyway, AT YOUR OWN RISK
            beq   :go
            sec
            rts
:go         clc
            rts

* Dither: line CW's colour table: entries 0-3 the same as 4-7, 8-11 and
* 12-15, or bit 3 of Found.
Dither      lda   CW
            and   #$000F
            asl
            asl
            asl
            asl
            asl
            clc
            adc   cpal
            sta   CT
            ldx   #8                    ; 4-7, 8-11, 12-15 against 0-3
:e          txa
            and   #7
            clc
            adc   CT
            tay
            lda   [cp0],y
            sta   CW2
            txa
            clc
            adc   CT
            tay
            lda   [cp0],y
            cmp   CW2
            bne   :yes
            inx
            inx
            cpx   #32
            bcc   :e
            rts
:yes        lda   #8
            tsb   Found
            rts

* StdColors: carry clear if colour table 0's entries 0-7 are the standard
* 640 colours.
StdColors   ldy   cpal
            ldx   #0
:c          lda   [cp0],y
            cmp   Std640C,x
            bne   :no
            iny
            iny
            inx
            inx
            cpx   #16
            bcc   :c
            clc
            rts
:no         sec
            rts

* HexOpts: Hex data's options (SuperConvert's window, OSAYCANYOU $3769):
* what goes before each line, between its bytes and after it, with a
* sample line that follows the typing. OK keeps them (for the next save
* too); Cancel stops the save.
*   out: carry set if cancelled
HexOpts     lda   DlgOn                 ; (a test's answers: no window)
            bne   :show
            clc
            rts
:show       ldx   #62                   ; (the fields as they were, for Cancel)
:keep       lda   HexStart,x
            sta   HxKept,x
            sta   HxShown,x
            dex
            dex
            bpl   :keep
            PushLong HxSubs             ; the sample shows the three fields
            Tool  _SetCtlParamPtr
            pha
            pha
            PushLong 0
            PushLong 0
            PushLong HxDraw
            PushLong 0
            pea   0
            PushLong HxParms
            pea   $800E
            Tool  _NewWindow2
            pla
            sta   HxWin
            pla
            sta   HxWin+2
:loop       pha                         ; the control hit
            pha
            PushLong HxEvent
            PushLong 0
            PushLong 0
            PushLong 0
            pea   $0008
            Tool  _DoModalWindow
            pla
            plx
            sta   Item
            jsr   HxRead                ; the fields as typed
            lda   Item
            cmp   #1
            beq   :ok
            cmp   #2
            bne   :loop
            ldx   #62                   ; Cancel: the fields as they were
:back       lda   HxKept,x
            sta   HexStart,x
            dex
            dex
            bpl   :back
            jsr   :close
            sec
            rts
:ok         jsr   :close
            clc
            rts
:close      PushLongAt HxWin
            Tool  _CloseWindow
            rts

* HxRead: the edit lines' texts into the fields; the sample drawn again
* when they changed.
HxRead      PushLongAt HxWin
            PushLong 6
            PushLong HexStart
            Tool  _GetLETextByID
            PushLongAt HxWin
            PushLong 5
            PushLong HexSep
            Tool  _GetLETextByID
            PushLongAt HxWin
            PushLong 4
            PushLong HexEnd
            Tool  _GetLETextByID
            ldx   #62
:cmp        lda   HexStart,x
            cmp   HxShown,x
            bne   :new
            dex
            dex
            bpl   :cmp
            rts
:new        ldx   #62
:copy       lda   HexStart,x
            sta   HxShown,x
            dex
            dex
            bpl   :copy
            pha                         ; the sample
            pha
            PushLongAt HxWin
            PushLong 3
            Tool  _GetCtlHandleFromID
            Tool  _DrawOneCtl
            rts

* HxDraw: the window's contents: its controls.
HxDraw      phb
            phk
            plb
            pha
            pha
            Tool  _GetPort
            Tool  _DrawControls
            plb
            rtl

* HexSet: for tests: the hex fields from the C string at dctl,
* "start|separator|end".
HexSet      ent
            phb
            phk
            plb
            lda   dctl
            sta   cp0
            lda   dctl+2
            sta   cp0+2
            ldy   #0
            ldx   #HexStart
            jsr   :field
            ldx   #HexSep
            jsr   :field
            ldx   #HexEnd
            jsr   :field
            plb
            rtl
:field      stx   HxF
            stz   HxN
:c          lda   [cp0],y
            and   #$00FF
            beq   :end
            iny
            cmp   #'|'
            beq   :end
            ldx   HxN
            cpx   #20
            bcs   :c
            inx
            stx   HxN
            pha
            txa
            clc
            adc   HxF
            tax
            pla
            sep   #$20
            mx    %10
            sta   |0,x
            rep   #$20
            mx    %00
            bra   :c
:end        lda   HxN
            ldx   HxF
            sep   #$20
            mx    %10
            sta   |0,x
            rep   #$20
            mx    %00
            rts

* SaveTest: for tests: the dialogs' answers given (A: the size item 2-6,
* X: the alignment item, Y: the warning alert's 1 Cancel save or 3 Save
* anyway; 0: show that one).
SaveTest    ent
            phb
            phk
            plb
            pha
            and   #$7FFF
            sta   TstSize
            pla
            and   #$8000
            sta   TstOpts
            stx   TstAlign
            sty   TstWarn
            plb
            rtl

* SaveWarned: for tests: A = the warnings the last save gave (bits 0-4).
SaveWarned  ent
            phb
            phk
            plb
            lda   LastCond
            plb
            rtl

*-------------------------------------------------------------
* Data
*-------------------------------------------------------------
cp0         =     $DC                   ; (the canvas: a long pointer)
SvFmt       dw    0                     ; the format (MegaconvertGS's number)
HxWin       adrl  0
HxF         dw    0
HxN         dw    0
HxKept      ds    64                    ; the hex fields before the window
HxShown     ds    64                    ; and as the sample shows them
HxSubs      adrl  HexStart,HexSep,HexEnd
HxEvent     dw    0
            adrl  0,0
            dw    0,0,0
            adrl  0
            adrl  $001FFFFF
            adrl  0
            dw    0
            adrl  0,0,0
            ds    16
* The window (OSAYCANYOU $3769): alert frame, movable
HxParms     dw    $50,$20A0
            adrl  0,0
            dw    0,0,0,0
            adrl  0
            dw    0,0,0,0,0,0,0,0,0,0
            adrl  0
            dw    0
            adrl  0,0,0
            dw    40,110,120,530
            adrl  $FFFFFFFF
            adrl  HxCtls
            dw    $0003
HxCtls      adrl  HxOK,HxCancel,HxSample,HxEdEnd,HxEdSep,HxEdStart,HxL1,HxL2,HxL3,0
HxOK        dw    9                     ; OK: the default button (Return)
            adrl  1
            dw    60,310,73,400
            adrl  $80000000
            dw    $0001,$3000
            adrl  0
            adrl  TxHxOK
            adrl  0
            db    $0D,$0D
            dw    0,0
HxCancel    dw    9                     ; Cancel (Escape)
            adrl  2
            dw    60,200,73,290
            adrl  $80000000
            dw    0,$3000
            adrl  0
            adrl  TxHxCancel
            adrl  0
            db    $1B,$1B
            dw    0,0
HxSample    dw    9                     ; the sample: *0 *1 *2 the fields
            adrl  3
            dw    35,12,53,1000
            adrl  $81000000
            dw    $0003,$1000
            adrl  0
            adrl  TxHxSample
            dw    TxHxSampleEnd-TxHxSample,0
HxEdEnd     dw    8                     ; the edit lines (20 characters)
            adrl  4
            dw    15,290,28,410
            adrl  $83000000
            dw    0,$7000
            adrl  0
            dw    20
            adrl  HexEnd
HxEdSep     dw    8
            adrl  5
            dw    15,150,28,270
            adrl  $83000000
            dw    0,$7000
            adrl  0
            dw    20
            adrl  HexSep
HxEdStart   dw    8
            adrl  6
            dw    15,10,28,130
            adrl  $83000000
            dw    0,$7000
            adrl  0
            dw    20
            adrl  HexStart
HxL1        dw    9
            adrl  7
            dw    5,10,13,129
            adrl  $81000000
            dw    0,$1000
            adrl  0
            adrl  TxHxL1
            dw    14,0
HxL2        dw    9
            adrl  8
            dw    5,150,14,269
            adrl  $81000000
            dw    0,$1000
            adrl  0
            adrl  TxHxL2
            dw    15,0
HxL3        dw    9
            adrl  9
            dw    5,290,14,409
            adrl  $81000000
            dw    0,$1000
            adrl  0
            adrl  TxHxL3
            dw    12,0
TxHxOK      str   'OK'
TxHxCancel  str   'Cancel'
TxHxSample  asc   'Sample line of generated output:',0D
            asc   '*001*123*145*167*189*1AB*1CD*1EF*2'
TxHxSampleEnd
TxHxL1      asc   'Start of line:'
TxHxL2      asc   'Item separator:'
TxHxL3      asc   'End of line:'
* Each save format's record (MegaconvertGS's numbers 1-13): warnings,
* sizes that can be chosen, the default (bits: original, one screen, a
* page, two screens high, two wide), the largest original (bytes, lines).
SvRecs      da    RecC1,RecC1,RecAPF,RecPack,RecPW,RecIcon,RecIcon,RecRIcon,RecRIcon
            da    RecHex,RecGIF,RecPNG,RecTIFF,RecDesk,RecPNG,RecPNG,RecPNG
            da    RecHex,RecHex,RecHex,RecHex  ; (Apple II: stretched to its screen)
RecPW       dw    $0005
            db    $04,$04
            dw    0,0
RecPack     dw    $0000
            db    $02,$02
            dw    0,0
RecAPF      dw    $0000
            db    $1F,$01
            dw    0,0
RecC1       dw    $0000
            db    $02,$02
            dw    0,0
RecIcon     dw    $1010
            db    $01,$01
            dw    40,50
RecRIcon    dw    $1000
            db    $01,$01
            dw    80,100
RecDesk     dw    $0004
            db    $01,$01
            dw    0,0
RecHex      dw    $0000
            db    $01,$01
            dw    0,0
RecGIF      dw    $0002
            db    $1F,$02
            dw    0,0
RecPNG      dw    $0002
            db    $1F,$02
            dw    0,0
RecTIFF     dw    $0002
            db    $1F,$01
            dw    0,0
Rec         dw    0
TstSize     dw    0                     ; (tests: the dialogs' answers)
TstAlign    dw    0
TstWarn     dw    0
TstOpts     dw    0                     ; (and the formats' own windows shown)
LastCond    dw    0
RWarn       dw    0
RSizes      dw    0
RDefault    dw    0
RMaxW       dw    0
RMaxH       dw    0
STop        dw    0                     ; the original: first line, first byte,
SLeft       dw    0                     ; bytes a line, lines
SBytes      dw    0
SLines      dw    0
CBytes      dw    0                     ; the size chosen
CLines      dw    0
HOff        dw    0                     ; where it starts in the original
VOff        dw    0
CanvH       adrl  0
CanvP       adrl  0
CvSize       dw    0
CR          dw    0
SR          dw    0
SRow        dw    0
CW          dw    0
CW2         dw    0
CT          dw    0
CDst        dw    0
CSrc        dw    0
CMa         dw    0
CMb         dw    0
Item        dw    0
DlgP        adrl  0
Found       dw    0
Cond        dw    0
Params      adrl  0,0,0,0
SzBits        db    1,2,4,8,16
Widths      dw    0,160,160,160,320     ; (items 2-6; 2: the original)
Heights     dw    0,200,396,400,200
Std640C     dw    $0000,$0F00,$00F0,$0FFF,$0000,$000F,$0FF0,$0FFF
WarnTx      da    WarnTx0,WarnTx1,WarnTx2,WarnTx3,WarnTx4
WarnTx0     str   '=> 640-mode graphics.'
WarnTx1     str   '=> Mixed 320- and 640-mode graphics.'
WarnTx2     str   '=> Multiple color palettes.'
WarnTx3     str   '=> 640-mode dithering.'
WarnTx4     str   '=> Anything but 640 dither mode, default colors.'
TxBlank     str   ' '
TxTooLarge  asc   '52/I am having a hard time attempting to save this image. Image is '
            asc   'much too large to save in this format./^#0',00

* The dialogs (SuperConvert's templates).
SizeTmpl    dw    30,50,170,400
            dw    $FFFF
            adrl  0
            adrl  SizeItem1,SizeItem2,SizeItem3,SizeItem4,SizeItem5,SizeItem6
            adrl  SizeItem7,0
SizeItem1   dw    1,120,100,135,250,$000A
            adrl  TxCancelSave
            dw    0,0
            adrl  0
SizeItem2   dw    2,20,10,35,340,$000A
            adrl  TxSameOrig
            dw    0,0
            adrl  0
SizeItem3   dw    3,40,10,55,340,$000A
            adrl  TxOneScreen
            dw    0,0
            adrl  0
SizeItem4   dw    4,60,10,75,340,$000A
            adrl  TxOnePage
            dw    0,0
            adrl  0
SizeItem5   dw    5,80,10,95,340,$000A
            adrl  TxTwoHigh
            dw    0,0
            adrl  0
SizeItem6   dw    6,100,10,115,340,$000A
            adrl  TxTwoWide
            dw    0,0
            adrl  0
SizeItem7   dw    7,5,10,15,340,$800F
            adrl  TxSelSize
            dw    0,0
            adrl  0
AlignTmpl   dw    28,135,173,505
            dw    $FFFF
            adrl  0
            adrl  AlItem1,AlItem2,AlItem4,0
AlItem1     dw    1,55,130,85,240,$000A
            adrl  TxCentered
            dw    0,0
            adrl  0
AlItem2     dw    2,125,20,140,170,$000A
            adrl  TxCancelSave
            dw    0,0
            adrl  0
AlItem4     dw    4,5,10,15,360,$800F
            adrl  TxSelAlign
            dw    0,0
            adrl  0
ItCL        dw    16,55,10,85,120,$000A
            adrl  TxCL
            dw    0,0
            adrl  0
ItCR        dw    17,55,250,85,360,$000A
            adrl  TxCR
            dw    0,0
            adrl  0
ItTL        dw    48,20,10,50,120,$000A
            adrl  TxTL
            dw    0,0
            adrl  0
ItTR        dw    49,20,250,50,360,$000A
            adrl  TxTR
            dw    0,0
            adrl  0
ItBL        dw    50,90,10,120,120,$000A
            adrl  TxBL
            dw    0,0
            adrl  0
ItBR        dw    51,90,250,120,360,$000A
            adrl  TxBR
            dw    0,0
            adrl  0
ItTC        dw    32,20,130,50,240,$000A
            adrl  TxTC
            dw    0,0
            adrl  0
ItBC        dw    33,90,130,120,240,$000A
            adrl  TxBC
            dw    0,0
            adrl  0
WarnTmpl    dw    40,100,120,540
            dw    $0BAD
            db    $81,$81,$81,$81
            adrl  WItem1,WItem3,WItem4,0
WItem1      dw    1,60,300,75,420,$000A
            adrl  TxCancelSave
            dw    0,0
            adrl  0
WItem3      dw    3,60,20,75,260,$000A
            adrl  TxAnyway
            dw    0,0
            adrl  0
WItem4      dw    4,5,75,50,430,$8010
            adrl  TxCantSave
            dw    TxCantEnd-TxCantSave,0
            adrl  0
TxCancelSave str  'Cancel save'
TxSameOrig  str   'Same as original'
TxSameClip  str   'Same as clipping'
TxOneScreen str   'One screen wide, one screen (200) high'
TxOnePage   str   'One screen wide, one page (396) high'
TxTwoHigh   str   'One screen wide, two screens (400) high'
TxTwoWide   str   'Two screens wide, one screen (200) high'
TxSelSize   str   'Select size of saved picture:'
TxCentered  str   'centered'
TxSelAlign  str   'Select alignment of saved area within picture:'
TxCL        str   'center left'
TxCR        str   'center right'
TxTL        str   'top left'
TxTR        str   'top right'
TxBL        str   'bottom left'
TxBR        str   'bottom right'
TxTC        str   'top center'
TxBC        str   'bottom center'
TxAnyway    str   'Save anyway, AT YOUR OWN RISK'
TxCantSave  asc   'Can',27,'t save, the specified format cannot handle:',0D
            asc   '^0',0D,'^1',0D,'^2',0D,'^3',0D
TxCantEnd
