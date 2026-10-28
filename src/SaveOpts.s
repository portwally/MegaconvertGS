*-------------------------------------------------------------
* SaveOpts.s - the save formats' own windows, as SuperConvert's (part of
* the Save segment; docs/superconvert-file.md 4.9): the GIF upload note
* that stays up as its progress window, the Finder icon's criteria. Only
* for saves whose dialogs were shown (DlgOn), not for the test commands'
* saves.
*-------------------------------------------------------------

* GifNote: before a GIF's pixels are coded: what to give in its
* description when uploading it, "^0 x ^1 x ^2 / ^3" (its size, its
* colours rounded up to a power of two, the palette range they need),
* left up with a progress bar (GifBar) until SaveDone.
GifNote     lda   DlgOn
            bne   :show
            rts
:show       lda   OW
            ldx   #GnW
            jsr   NumStr
            lda   OH
            ldx   #GnH
            jsr   NumStr
            lda   GEntries
            ldx   #GnC
            jsr   NumStr
            jsr   GifRange
            ldx   #GnR
            jsr   NumStr
            PushLong GnW
            PushLong GnH
            PushLong GnC
            PushLong GnR
            Tool  _ParamText
            pha
            pha
            PushLong GnTmpl
            Tool  _GetNewModalDialog
            pla
            sta   GnDlg
            pla
            sta   GnDlg+2
            PushLongAt GnDlg
            Tool  _SetPort
            PushLongAt GnDlg
            Tool  _DrawDialog
            pea   2                     ; the bar's frame, the text in it
            pea   1
            Tool  _SetPenSize
            pea   0
            Tool  _SetSolidPenPat
            PushLong GnFrame
            Tool  _FrameRect
            pea   0
            Tool  _SetForeColor
            pea   3
            Tool  _SetBackColor
            pea   50
            pea   142
            Tool  _MoveTo
            PushLong TxGnProg
            Tool  _DrawCString
            Tool  _PenNormal            ; the bar darkens what it covers
            PushLong GnPat
            Tool  _SetPenPat
            pea   $8003
            Tool  _SetPenMode
            stz   GnAcc
            stz   GnBar
            stz   GnShown
            rts

* GifBar: before each line is coded: the bar 256 x the lines done /
* the height long (the original's steps: it never quite reaches the end).
GifBar      lda   GnDlg
            ora   GnDlg+2
            beq   :out
            lda   GnBar
            cmp   GnShown
            beq   :next
            sta   GnShown
            clc
            adc   #22
            sta   GnBarR+6
            PushLong GnBarR
            Tool  _PaintRect
:next       lda   GnAcc                 ; (the next line's)
            clc
            adc   #256
:d          cmp   OH
            bcc   :st
            sbc   OH
            inc   GnBar
            bra   :d
:st         sta   GnAcc
:out        rts

* GifRange: A = the palette range the colours need (the original's
* test): each colour's class is the first of 1 bit (every channel 0 or
* 15), 2 bits (0, 5, 10, 15) and 3 bits (0, 2, 4, 6, 9, 11, 13, 15) its
* three channels all pass, else 4 bits; the worst class gives 8, 64, 512
* or 4096.
GifRange    stz   GnOr                  ; (the worst: 0-3 for 1-4 bits)
            ldx   #0
:c          txa
            lsr
            cmp   NCol
            bcs   :range
            phx
            lda   PalR,x                ; the tests all three channels pass
            jsr   :mask
            sta   GnT
            lda   PalG,x
            jsr   :mask
            and   GnT
            sta   GnT
            lda   PalB,x
            jsr   :mask
            and   GnT
            ldx   #3                    ; its class: the first test passed
            lsr
            bcs   :c1
            lsr
            bcs   :c2
            lsr
            bcs   :c3
            bra   :cls
:c1         dex
:c2         dex
:c3         dex
:cls        cpx   GnOr
            bcc   :keep
            stx   GnOr
:keep       plx
            inx
            inx
            bra   :c
:range      lda   GnOr
            asl
            tax
            lda   GnRanges,x
            rts
:mask       lsr                         ; (the 4-bit channel: the high nibble)
            lsr
            lsr
            lsr
            and   #$000F
            tax
            lda   GnMasks,x
            and   #$00FF
            pha
            lda   5,s                   ; (the colour's index again)
            tax
            pla
            rts

* SaveDone: the save written (A = 0) or failed (A = 1): a GIF's progress
* window says "GIF save completed" and waits for that button, then goes.
SaveDone    ent
            phb
            phk
            plb
            tax
            lda   GnDlg
            ora   GnDlg+2
            beq   :out
            txa
            bne   :close
            Tool  _PenNormal
            PushLongAt GnDlg
            pea   1
            PushLong GnDoneR
            pea   10                    ; (a button)
            PushLong TxGnDone
            pea   0
            pea   0
            PushLong 0
            Tool  _NewDItem
:wait       pha
            PushLong 0
            Tool  _ModalDialog
            pla
            cmp   #1
            bne   :wait
:close      PushLongAt GnDlg
            Tool  _CloseDialog
            stz   GnDlg
            stz   GnDlg+2
:out        plb
            rtl

* NumStr: A in decimal as a Pascal string at X (this bank).
NumStr      stx   NsP
            ldy   #0
:d          sta   NsV
            lda   #0
            ldx   #16
:b          asl   NsV
            rol
            cmp   #10
            bcc   :n
            sbc   #10
            inc   NsV
:n          dex
            bne   :b
            clc
            adc   #'0'
            pha
            iny
            lda   NsV
            bne   :d
            tya
            ldx   NsP
            sep   #$20
            mx    %10
            sta   |0,x
            rep   #$20
            mx    %00
:o          inx
            pla
            sep   #$20
            mx    %10
            sta   |0,x
            rep   #$20
            mx    %00
            dey
            bne   :o
            rts

* IconDlg: a Finder icon's criteria (SuperConvert's dialog 9:2649): the
* icon and its small icon shown; the files it is for (their file type,
* aux type and name, each checked or any) and the program the Finder runs
* for them; the record at q1 (PutRecord's) changed to match. Only when the
* save's dialogs were shown. ftype, faux: the loaded file's type and aux
* type; dname: its name.
*   out: carry set, A = errCancel if cancelled
IconDlg     lda   DlgOn
            bne   :show
            clc
            rts
:show       lda   q1                    ; the icons in the record
            clc
            adc   #86
            sta   IdBig
            sta   cp0
            lda   q1+2
            adc   #0
            sta   IdBig+2
            sta   cp0+2
            ldy   #2                    ; (the small one after the big one's
            lda   [cp0],y               ; image and mask)
            asl
            clc
            adc   #8
            adc   IdBig
            sta   IdSmall
            lda   IdBig+2
            adc   #0
            sta   IdSmall+2
            lda   #3                    ; "$tt", "$aaaa" (the lengths first:
            sta   IdType                ; these are word stores)
            lda   #5
            sta   IdAux
            lda   #'$'
            sta   IdType+1
            sta   IdAux+1
            lda   ftype
            ldx   #IdType+2
            jsr   Hex2At
            lda   faux
            xba
            ldx   #IdAux+2
            jsr   Hex2At
            lda   faux
            ldx   #IdAux+4
            jsr   Hex2At
            ldy   #0                    ; the name: 15 characters at most, the
:nm         lda   [dname],y             ; 15th a '*' when there are more
            and   #$00FF
            beq   :nmEnd
            cpy   #15
            bcc   :nmPut
            lda   #'*'
            ldx   #15
            sep   #$20
            mx    %10
            sta   IdName,x
            rep   #$20
            mx    %00
            bra   :nmEnd
:nmPut      sep   #$20
            mx    %10
            sta   IdName+1,y
            rep   #$20
            mx    %00
            iny
            bra   :nm
:nmEnd      cpy   #15
            bcc   :nmLen
            ldy   #15
:nmLen      tya
            sep   #$20
            mx    %10
            sta   IdName
            rep   #$20
            mx    %00
            pha                         ; the program: this one's path
            pha
            lda   uid
            pha
            pea   1
            Tool  _GetPathname2
            pla
            sta   cp0
            pla
            sta   cp0+2
            stz   IdPath
            bcs   :dlg
            lda   [cp0]
            cmp   #63
            bcc   :pLen
            lda   #63
:pLen       sta   IdLen
            ldy   #0
:pc         cpy   IdLen
            bcs   :pEnd
            iny
            iny
            lda   [cp0],y
            dey
            sep   #$20
            mx    %10
            sta   IdPath,y
            rep   #$20
            mx    %00
            bra   :pc
:pEnd       lda   IdLen
            sep   #$20
            mx    %10
            sta   IdPath
            rep   #$20
            mx    %00
:dlg        pha
            pha
            PushLong IdTmpl
            Tool  _GetNewModalDialog
            pla
            sta   IdDlg
            pla
            sta   IdDlg+2
            lda   #32
            ldx   #IdType
            jsr   IdSet
            lda   #33
            ldx   #IdAux
            jsr   IdSet
            lda   #34
            ldx   #IdName
            jsr   IdSet
            lda   #35
            ldx   #IdPath
            jsr   IdSet
:loop       pha
            PushLong 0
            Tool  _ModalDialog
            pla
            cmp   #1
            beq   :save
            cmp   #2
            beq   :cancel
            cmp   #16                   ; a check box: turned over
            bcc   :loop
            cmp   #20
            bcs   :loop
            sta   IdHit
            pha
            PushLongAt IdDlg
            lda   IdHit
            pha
            Tool  _GetDItemValue
            pla
            eor   #1
            pha
            PushLongAt IdDlg
            lda   IdHit
            pha
            Tool  _SetDItemValue
            bra   :loop
:cancel     jsr   :close
            lda   #errCancel
            sec
            rts
:save       lda   #16                   ; the type and aux type: a number,
            ldx   #32                   ; "$" and hex digits, or any (0)
            jsr   IdNum
            bcs   :loop
            sta   IdTypeV
            lda   #17
            ldx   #33
            jsr   IdNum
            bcs   :loop
            sta   IdAuxV
            lda   q1                    ; into the record
            sta   cp0
            lda   q1+2
            sta   cp0+2
            ldy   #82
            lda   IdTypeV
            sta   [cp0],y
            ldy   #84
            lda   IdAuxV
            sta   [cp0],y
            lda   #18                   ; the name, or "*"
            jsr   IdOn
            bne   :name
            lda   #$2A01
            sta   IdText
            bra   :putName
:name       lda   #34
            jsr   IdGet
:putName    ldy   #66
            ldx   #15
            jsr   IdPut
            lda   #19                   ; the program, or none
            jsr   IdOn
            bne   :prog
            stz   IdText
            bra   :putProg
:prog       lda   #35
            jsr   IdGet
:putProg    ldy   #2
            ldx   #63
            jsr   IdPut
            jsr   :close
            clc
            rts
:close      PushLongAt IdDlg
            Tool  _CloseDialog
            rts

* IdSet: the dialog's edit line A gets the Pascal string at X.
IdSet       pha
            PushLongAt IdDlg
            lda   5,s
            pha
            pea   ^IdType
            phx
            Tool  _SetIText
            pla
            rts

* IdOn: A = item A's value (a check box: 1 on).
IdOn        tax
            pha
            PushLongAt IdDlg
            phx
            Tool  _GetDItemValue
            pla
            rts

* IdGet: IdText = edit line A's text.
IdGet       tax
            PushLongAt IdDlg
            phx
            PushLong IdText
            Tool  _GetIText
            rts

* IdPut: IdText (at most X characters) into the record at q1 + Y, a
* Pascal string in X + 1 bytes (the rest zero).
IdPut       stx   IdLen
            lda   q1
            sta   cp0
            lda   q1+2
            sta   cp0+2
            lda   IdText
            and   #$00FF
            cmp   IdLen
            bcc   :len
            lda   IdLen
:len        sta   IdN
            ldx   #0
:c          cpx   IdN
            beq   :lenB
            bcs   :zero
:lenB       txa                         ; (byte 0: the length)
            beq   :first
            lda   IdText,x
            bra   :put
:first      lda   IdN
:put        sep   #$20
            mx    %10
            sta   [cp0],y
            rep   #$20
            mx    %00
            iny
            inx
            bra   :c
:zero       cpx   IdLen
            beq   :z
            bcs   :done
:z          lda   #0
            sep   #$20
            mx    %10
            sta   [cp0],y
            rep   #$20
            mx    %00
            iny
            inx
            bra   :zero
:done       rts

* IdNum: check box A on: edit line X's number ("$" hex, or decimal); off:
* 0. A bad one: a beep, its text flashed and left selected.
*   out: A = the number, or carry set
IdNum       stx   IdItem
            jsr   IdOn
            bne   :on
            lda   #0
            clc
            rts
:on         lda   IdItem
            jsr   IdGet
            jsr   IdParse
            bcs   :bad
            rts
:bad        Tool  _SysBeep
            lda   #31
            sta   IdN
:flash      PushLongAt IdDlg
            lda   IdItem
            pha
            pea   0
            lda   IdN
            and   #1
            beq   :sel
            lda   #255
:sel        pha
            Tool  _SelectIText
            dec   IdN
            bne   :flash
            PushLongAt IdDlg
            lda   IdItem
            pha
            pea   0
            pea   255
            Tool  _SelectIText
            sec
            rts

* IdParse: A = the number in IdText: "$" and 1-4 hex digits, or decimal
* digits up to 65535.
*   out: carry set if there is none
IdParse     lda   IdText
            and   #$00FF
            bne   :jx1
            jmp   :bad
:jx1
            sta   IdLen
            stz   IdV
            ldx   #1
            lda   IdText+1
            and   #$00FF
            cmp   #'$'
            beq   :hex
:dec        lda   IdText,x
            and   #$00FF
            sec
            sbc   #'0'
            cmp   #10
            bcs   :bad
            sta   IdN
            lda   IdV                   ; x 10, + the digit
            cmp   #6554
            bcs   :bad
            asl
            sta   IdV
            asl
            asl
            clc
            adc   IdV
            adc   IdN
            bcs   :bad
            sta   IdV
            inx
            cpx   IdLen
            bcc   :dec
            beq   :dec
            bra   :ok
:hex        inx
            cpx   IdLen
            beq   :hd
            bcs   :bad                  ; ("$" alone)
:hd         lda   IdText,x
            and   #$00FF
            cmp   #'a'
            bcc   :up
            sbc   #$20
:up         sec
            sbc   #'0'
            cmp   #10
            bcc   :digit
            sbc   #7
            cmp   #10
            bcc   :bad
            cmp   #16
            bcs   :bad
:digit      sta   IdN
            lda   IdV
            cmp   #$1000
            bcs   :bad
            asl
            asl
            asl
            asl
            ora   IdN
            sta   IdV
            inx
            cpx   IdLen
            bcc   :hd
            beq   :hd
:ok         lda   IdV
            clc
            rts
:bad        sec
            rts

* Hex2At: A's low byte as 2 hex digits at X (this bank).
Hex2At      pha
            lsr
            lsr
            lsr
            lsr
            and   #$000F
            tay
            lda   IdHexD,y
            sep   #$20
            mx    %10
            sta   |0,x
            rep   #$20
            mx    %00
            pla
            and   #$000F
            tay
            lda   IdHexD,y
            sep   #$20
            mx    %10
            sta   |1,x
            rep   #$20
            mx    %00
            rts

* IdDrawBig, IdDrawSmall: the dialog's icons (user items: the Dialog
* Manager calls them with the dialog and the item's number).
IdDrawBig   phb
            phk
            plb
            PushLongAt IdBig
            pea   0
            pea   100
            pea   5
            Tool  _DrawIcon
            bra   IdDrawn
IdDrawSmall phb
            phk
            plb
            PushLongAt IdSmall
            pea   0
            pea   280
            pea   16
            Tool  _DrawIcon
IdDrawn     plb
            lda   2,s                   ; the parameters off the stack
            sta   8,s
            lda   1,s
            sta   7,s
            pla
            pla
            pla
            rtl

*-------------------------------------------------------------
* PNG save options
*-------------------------------------------------------------

* PngOpts: the PNG options window (SuperConvert's rWindParam1 2): the
* compression level (a slider, "More speed" to "More compression"), the
* filter (None or Auto) and comments. PngUse then says to follow them;
* without the window (a test's save), the usual PNG (as GS Remap's),
* unless PngSet gave them.
*   out: carry set, A = errCancel, if cancelled
PngOpts     lda   PngSetOn              ; (a test gave them)
            beq   :dlg
            stz   PngSetOn
            lda   #1
            sta   PngUse
            clc
            rts
:dlg        stz   PngUse
            lda   DlgOn
            bne   :show
            clc
            rts
:show       lda   #5                    ; level 6, filter None, no comments
            sta   PgSVal                ; (nothing kept from the last time)
            pha
            pha
            PushLong 0
            PushLong 0
            PushLong PgDraw
            PushLong 0
            pea   0
            PushLong PgParms
            pea   $800E
            Tool  _NewWindow2
            pla
            sta   PgWin
            pla
            sta   PgWin+2
            lda   PgSVal
            sta   PgLast
:loop       pha
            pha
            PushLong PgEvent
            PushLong 0
            PushLong 0
            PushLong 0
            pea   $0008
            Tool  _DoModalWindow
            pla
            plx
            cmp   #1
            beq   :ok
            cmp   #2
            beq   :cancel
            cmp   #6
            bne   :loop
            jsr   PgSlider
            bra   :loop
:cancel     jsr   :close
            lda   #errCancel
            sec
            rts
:ok         pha                         ; the level: the slider + 1
            PushLongAt PgWin
            PushLong 6
            Tool  _GetCtlValueByID
            pla
            inc
            sta   PngLevel
            pha                         ; the filter: Auto on?
            PushLongAt PgWin
            PushLong 21
            Tool  _GetCtlValueByID
            pla
            sta   PngFilter
            pha                         ; the comments
            pha
            pea   $0005                 ; (a text block, by pointer)
            PushLong PngTBuf
            PushLong 2000
            pea   0
            PushLong 0
            pha
            pha
            PushLongAt PgWin
            PushLong 9
            Tool  _GetCtlHandleFromID
            Tool  _TEGetText
            pla
            plx
            cmp   #2000
            bcc   :len
            lda   #2000
:len        sta   PngTLen
            jsr   :close
            lda   #1
            sta   PngUse
            clc
            rts
:close      PushLongAt PgWin
            Tool  _CloseWindow
            rts

* PgSlider: the slider clicked: dragged (a new value), or one step for
* an arrow and two for its page parts (the part under the click),
* within 0-8.
PgSlider    pha
            PushLongAt PgWin
            PushLong 6
            Tool  _GetCtlValueByID
            pla
            cmp   PgLast
            bne   :set
            pha                         ; the part clicked
            PushLong PgWhich
            lda   PgEvent+$0C
            pha
            lda   PgEvent+$0A
            pha
            PushLongAt PgWin
            Tool  _FindControl
            pla
            ldx   #-1
            cmp   #5
            beq   :step
            ldx   #1
            cmp   #6
            beq   :step
            ldx   #-2
            cmp   #7
            beq   :step
            ldx   #2
            cmp   #8
            beq   :step
            rts
:step       txa
            clc
            adc   PgLast
            bpl   :lo
            lda   #0
:lo         cmp   #9
            bcc   :set
            lda   #8
:set        sta   PgLast
            pha
            PushLongAt PgWin
            PushLong 6
            Tool  _SetCtlValueByID
            rts

* PgDraw: the window's contents: its controls, a line under the title.
PgDraw      phb
            phk
            plb
            pha
            pha
            Tool  _GetPort
            Tool  _DrawControls
            Tool  _PenNormal
            pea   12
            pea   14
            Tool  _MoveTo
            pea   292
            pea   14
            Tool  _LineTo
            plb
            rtl

* PngSet: for tests: the next PNG saved with level A, filter X (0 None,
* 1 Auto) and the C string at dctl as comments, without the window.
PngSet      ent
            phb
            phk
            plb
            sta   PngLevel
            stx   PngFilter
            ldy   #0
:c          lda   [dctl],y
            and   #$00FF
            beq   :e
            sep   #$20
            mx    %10
            sta   PngTBuf,y
            rep   #$20
            mx    %00
            iny
            cpy   #2000
            bcc   :c
:e          sty   PngTLen
            lda   #1
            sta   PngSetOn
            plb
            rtl

*-------------------------------------------------------------
* Desktop background image INIT ($B7)
*-------------------------------------------------------------

* SaveDesk: a one-segment OMF load file: MegaconvertGS's own INIT
* (InitCode) and, packed after it, the desktop message (from Main, at fp:
* 32008 bytes). At start-up, from the SYSTEM.SETUP folder, the INIT
* unpacks the message and gives it to the Message Center as the desktop
* (type 2), as SuperConvert's does (docs/superconvert-formats-extra.md 2).
SaveDesk    lda   #34000                ; room: the header, the INIT, the
            sta   n0                    ; packed message (at most $7F00)
            stz   n0+2
            jsr   OutNew
            bcc   :head
            rts
:head       lda   q0                    ; (the header: its lengths later)
            sta   q1
            lda   q0+2
            sta   q1+2
            ldx   #0
:h          lda   OmfHead,x
            jsr   Put
            inx
            cpx   #OmfHeadEnd-OmfHead
            bcc   :h
            lda   #$F2                  ; LCONST: the segment's bytes
            jsr   Put
            lda   q0
            sta   DkCount
            lda   q0+2
            sta   DkCount+2
            ldx   #4
            jsr   PutZeros
            lda   q0                    ; (where the INIT's variables go)
            clc
            adc   #IVars-InitCode
            sta   DkVars
            lda   q0+2
            adc   #0
            sta   DkVars+2
            ldx   #0                    ; the INIT
:c          lda   InitCode,x
            jsr   Put
            inx
            cpx   #IPacked-InitCode
            bcc   :c
            lda   fp                    ; the message, packed
            sta   DkSrc
            lda   fp+2
            sta   DkSrc+2
            lda   #$7D08
            sta   DkSize
            pha
            PushLong DkSrc
            PushLong DkSize
            lda   q0+2
            pha
            lda   q0
            pha
            pea   $7F00
            Tool  _PackBytes
            pla
            sta   DkN
            clc
            adc   q0
            sta   q0
            bcc   :q
            inc   q0+2
:q          lda   DkN
            clc
            adc   outl
            sta   outl
            bcc   :o
            inc   outl+2
:o          lda   #0                    ; END
            jsr   Put
            lda   DkVars                ; the packed length, for the INIT
            sta   q2
            lda   DkVars+2
            sta   q2+2
            ldy   #IPkLen-IVars
            lda   DkN
            sta   [q2],y
            lda   DkCount               ; the segment's length: the LCONST's
            sta   q2                    ; count and the header's LENGTH
            lda   DkCount+2
            sta   q2+2
            lda   DkN
            clc
            adc   #IPacked-InitCode
            sta   [q2]
            ldy   #8
            sta   [q1],y
            lda   #0
            ldy   #2
            sta   [q2],y
            ldy   #10
            sta   [q1],y
            lda   outl                  ; and the file's: BYTECNT
            sta   [q1]
            ldy   #2
            lda   outl+2
            sta   [q1],y
            lda   #$00B7
            sta   otype
            stz   oaux
            stz   oaux+2
            clc
            rts

* The INIT (copied into the file, never run here). At start-up it gets a
* 32008-byte handle (with the memory ID the Loader gives in A), unpacks
* the message after it there, adds it to the Message Center as type 2 and
* lets go of the handle (the Message Center keeps a copy). It finds its
* variables with PER, so it runs wherever it is loaded.
InitCode    phb
            phd
            phk
            plb
            tay                         ; NewHandle(32008, ID, locked fixed)
            pha
            pha
            pea   0
            pea   $7D08
            phy
            pea   $C000
            pea   0
            pea   0
            ldx   #$0902
            jsl   $E10000
            tay
            per   IVars
            plx
            pla
            sta   |0,x                  ; (the handle)
            pla
            sta   |2,x
            tya
            bcs   :out
            pha                         ; (4 bytes of direct page on the stack)
            pha
            tsc
            tcd
            lda   |0,x
            sta   1
            lda   |2,x
            sta   3
            lda   [1]                   ; its data: where to unpack
            sta   |4,x
            ldy   #2
            lda   [1],y
            sta   |6,x
            pla
            pla
            pha                         ; UnPackBytes(the packed message, its
            phb                         ; length, the place, its size)
            phb
            pla
            and   #$00FF
            pha
            per   IPacked
            lda   |10,x
            pha
            phb
            phb
            pla
            and   #$00FF
            pha
            per   IDest
            phb
            phb
            pla
            and   #$00FF
            pha
            per   ISize
            ldx   #$2703
            jsl   $E10000
            pla
            per   IVars                 ; MessageCenter(add, type 2, handle)
            plx
            pea   1
            pea   2
            lda   |2,x
            pha
            lda   |0,x
            pha
            ldx   #$1501
            jsl   $E10000
            per   IVars                 ; DisposeHandle(handle)
            plx
            lda   |2,x
            pha
            lda   |0,x
            pha
            ldx   #$1002
            jsl   $E10000
            lda   #0
            clc
:out        pld
            plb
            rtl
IVars       adrl  0                     ; the handle
IDest       adrl  0                     ; where the message is unpacked
ISize       dw    $7D08                 ; its size
IPkLen      dw    0                     ; the packed message's length
IPacked                                 ; (the packed message follows)

DkCount     adrl  0
DkVars      adrl  0
DkSrc       adrl  0
DkSize      dw    0
DkN         dw    0
* The segment header (version 2): byte count and length filled in; one
* static code segment, no name
OmfHead     adrl  0                     ; BYTECNT
            adrl  0                     ; RESSPC
            adrl  0                     ; LENGTH
            db    0,0,4,2               ; (unused), LABLEN, NUMLEN, VERSION
            adrl  $10000                ; BANKSIZE
            dw    0,0                   ; KIND (static code), (unused)
            adrl  0                     ; ORG
            adrl  0                     ; ALIGN
            db    0,0                   ; NUMSEX, (unused)
            dw    1                     ; SEGNUM
            adrl  0                     ; ENTRY
            dw    $2C,$37               ; DISPNAME, DISPDATA
            ds    10                    ; LOADNAME
            db    0                     ; SEGNAME (empty)
OmfHeadEnd

*-------------------------------------------------------------
* Data
*-------------------------------------------------------------
DlgOn       dw    0                     ; this save's dialogs were shown
GnDlg       adrl  0                     ; the GIF note (0: none up)
GnAcc       dw    0
GnBar       dw    0
GnShown     dw    0
GnOr        dw    0
GnT         dw    0
GnMasks     db    7,0,4,0,4,2,4,0,0,4,2,4,0,4,0,7   ; bit 0: 1 bit, 1: 2, 2: 3
GnRanges    dw    8,64,512,4096
NsP         dw    0
NsV         dw    0
GnW         ds    8                     ; ^0-^3 (Pascal strings)
GnH         ds    8
GnC         ds    8
GnR         ds    8
GnFrame     dw    132,22,145,278
GnBarR      dw    132,22,145,22
GnDoneR     dw    132,16,145,284
GnPat       hex   66666666666666666666666666666666
            hex   66666666666666666666666666666666
TxGnProg    asc   'GIF87a save in progress...',00
TxGnDone    str   'GIF save completed'
* The note (SuperConvert's 9:1C18)
GnTmpl      dw    30,170,180,470
            dw    $FFFF
            adrl  0
            adrl  GnItem,0
GnItem      dw    4
            dw    5,10,125,290
            dw    $8016                 ; (long static text, disabled)
            adrl  TxGnNote
            dw    TxGnNoteEnd-TxGnNote
            dw    0
            adrl  0
TxGnNote    asc   'If this file is to be uploaded to a computer service or BBS, please '
            asc   'include the following data in its description:',0D,0D
            db    $01,'S',$01,$00,$01,'J',$01,$00
            asc   '^0 x ^1 x ^2 / ^3 ',0D,0D
            db    $01,'J',$00,$00,$01,'S',$00,$00
            asc   'This information (the picture'
            db    $27
            asc   's horizontal & vertical size, number of colors, and palette range) '
            asc   'will help downloaders to estimate how well the file will turn out on '
            asc   'their particular graphics hardware.'
TxGnNoteEnd
IdDlg       adrl  0
IdBig       adrl  0
IdSmall     adrl  0
IdHit       dw    0
IdItem      dw    0
IdLen       dw    0
IdN         dw    0
IdV         dw    0
IdTypeV     dw    0
IdAuxV      dw    0
IdType      ds    8                     ; the edit lines' first texts
IdAux       ds    8
IdName      ds    18
IdPath      ds    66
IdText      ds    258                   ; an edit line's text
IdHexD      asc   '0123456789ABCDEF'
* The dialog (SuperConvert's 9:2649)
IdTmpl      dw    25,70,190,570
            dw    $FFFF
            adrl  0
            adrl  IdI1,IdI2,IdI3,IdI4,IdI5,IdI6,IdI7,IdI8,IdI9
            adrl  IdI16,IdI17,IdI18,IdI19,IdI32,IdI35,IdI34,IdI33,0
IdI1        dw    1,147,380,160,480,$000A
            adrl  TxIdSave
            dw    0,0
            adrl  0
IdI2        dw    2,147,240,160,340,$000A
            adrl  TxIdCancel
            dw    0,0
            adrl  0
IdI3        dw    3,16,280,81,490,$8014
            adrl  IdDrawSmall
            dw    0,0
            adrl  0
IdI4        dw    4,5,100,55,260,$8014
            adrl  IdDrawBig
            dw    0,0
            adrl  0
IdI5        dw    5,5,10,15,95,$800F
            adrl  TxId5
            dw    0,0
            adrl  0
IdI6        dw    6,5,280,15,490,$800F
            adrl  TxId6
            dw    0,0
            adrl  0
IdI7        dw    7,60,10,70,270,$800F
            adrl  TxId7
            dw    0,0
            adrl  0
IdI8        dw    8,70,10,80,270,$800F
            adrl  TxId8
            dw    0,0
            adrl  0
IdI9        dw    9,115,10,125,490,$800F
            adrl  TxId9
            dw    0,0
            adrl  0
IdI16       dw    16,85,10,0,0,$000B
            adrl  TxId16
            dw    1,0
            adrl  0
IdI17       dw    17,85,224,0,0,$000B
            adrl  TxId17
            dw    1,0
            adrl  0
IdI18       dw    18,100,100,0,0,$000B
            adrl  TxId18
            dw    1,0
            adrl  0
IdI19       dw    19,130,10,0,0,$000B
            adrl  TxId19
            dw    1,0
            adrl  0
IdI32       dw    32,83,132,96,180,$8011
            adrl  TxIdNone
            dw    5,0
            adrl  0
IdI35       dw    35,128,160,141,490,$8011
            adrl  TxIdNone
            dw    63,0
            adrl  0
IdI34       dw    34,98,224,111,400,$8011
            adrl  TxIdNone
            dw    15,0
            adrl  0
IdI33       dw    33,83,400,96,460,$8011
            adrl  TxIdNone
            dw    5,0
            adrl  0
TxIdSave    str   'Save'
TxIdCancel  str   'Cancel'
TxId5       str   'This icon:'
TxId6       str   'Along with this small icon:'
TxId7       str   'Will be used for files matching'
TxId8       str   'the following selected criteria:'
TxId9       str   'When the icon is double-clicked or opened, the Finder will:'
TxId16      str   'Filetype is:'
TxId17      str   'Auxilliary type is:'
TxId18      str   'Filename is:'
TxId19      str   'Run the program:'
TxIdNone    db    0
PngUse      dw    0                     ; the window's choices (or PngSet's)
PngSetOn    dw    0
PngLevel    dw    6
PngFilter   dw    0
PngTLen     dw    0
PngTBuf     ds    2002
PgWin       adrl  0
PgLast      dw    0
PgWhich     adrl  0
PgEvent     dw    0
            adrl  0,0
            dw    0,0,0
            adrl  0
            adrl  $001FFFFF
            adrl  0
            dw    0
            adrl  0,0,0
            ds    16
* The window (SuperConvert's rWindParam1 2): content 29,166,184,472
PgParms     dw    $50,$2020
            adrl  0,0
            dw    0,0,0,0
            adrl  0
            dw    0,0,0,0,0,0,0,0,0,0
            adrl  0
            dw    0
            adrl  0,0,0
            dw    29,166,184,472
            adrl  $FFFFFFFF
            adrl  PgCtls
            dw    $0003
PgCtls      adrl  PgTitle,PgSpeed,PgComp,PgBar,PgNone,PgAuto,PgComLab,PgTE
            adrl  PgCancel,PgOK,0
PgTitle     dw    9
            adrl  3
            dw    4,12,14,284
            adrl  $81000000
            dw    0,$1000
            adrl  0
            adrl  TxPgTitle
            dw    16,0
PgSpeed     dw    9
            adrl  7
            dw    21,12,31,91
            adrl  $81000000
            dw    0,$1000
            adrl  0
            adrl  TxPgSpeed
            dw    10,0
PgComp      dw    9
            adrl  8
            dw    21,172,31,297
            adrl  $81000000
            dw    0,$1000
            adrl  0
            adrl  TxPgComp
            dw    16,0
PgBar       dw    9                     ; the level: 0-8 (+ 1)
            adrl  6
            dw    31,13,42,295
            adrl  $86000000
            dw    $001C,$1000
            adrl  0
            dw    9,1
PgSVal      dw    5
PgNone      dw    8                     ; the filter: None or Auto (as two
            adrl  20                    ; buttons, where SuperConvert has a
            dw    44,12,0,0             ; pop-up menu)
            adrl  $84000000
            dw    1,$1000
            adrl  0
            adrl  TxPgNone
            dw    1
PgAuto      dw    8
            adrl  21
            dw    44,150,0,0
            adrl  $84000000
            dw    1,$1000
            adrl  0
            adrl  TxPgAuto
            dw    0
PgComLab    dw    9
            adrl  10
            dw    59,12,69,88
            adrl  $81000000
            dw    0,$1000
            adrl  0
            adrl  TxPgCom
            dw    9,0
PgTE        dw    17                    ; the comments (TextEdit)
            adrl  9
            dw    68,11,126,294
            adrl  $85000000
            dw    0,$7400
            adrl  0
            adrl  $03800000
            dw    $FFFF,$FFFF,$FFFF,$FFFF
            adrl  $FFFFFFFF
            dw    0
            adrl  0
            dw    0
            adrl  0
            dw    $0004
            adrl  PgTEText
            adrl  0
            adrl  2000
PgTEText    db    0
PgCancel    dw    9
            adrl  2
            dw    137,130,150,207
            adrl  $80000000
            dw    0,$3000
            adrl  0
            adrl  TxPgCancel
            adrl  0
            db    $1B,$1B
            dw    0,0
PgOK        dw    9
            adrl  1
            dw    137,219,150,290
            adrl  $80000000
            dw    $0001,$3000
            adrl  0
            adrl  TxPgOK
            adrl  0
            db    $0D,$0D
            dw    0,0
TxPgTitle   asc   'PNG save options'
TxPgSpeed   asc   'More speed'
TxPgComp    asc   'More compression'
TxPgCom     asc   'Comments:'
TxPgNone    str   'Filter: None'
TxPgAuto    str   'Auto'
TxPgCancel  str   'Cancel'
TxPgOK      str   'OK'
