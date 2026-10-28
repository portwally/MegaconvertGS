*-------------------------------------------------------------
* Print.s - printing, as SuperConvert's (a segment of its own;
* docs/superconvert-file.md 6): the Print Manager, started the first time
* it is needed (its printer and port drivers from the System folder), one
* print record kept for the session.
*-------------------------------------------------------------
            rel
            mx    %00
            use   macros/Macs.s
            put   Equates.s

pp          =     $D0                   ; (a long pointer)

* PrintAlign: File > Print alignment page...: page setup and the print
* job's dialogs, then one page with a cross at each corner of the area
* the printer can print.
*   out: carry set (A = the error, or errCancel) if it wasn't printed
PrintAlign  ent
            phb
            phk
            plb
            jsr   PrStart
            bcc   :jx1
            jmp   :out
:jx1
            jsr   Dialogs
            bcc   :jx2
            jmp   :out
:jx2
            pha                         ; the document
            pha
            PushLongAt PrRecH
            PushLong 0
            Tool  _PrOpenDoc
            pla
            sta   PrPort
            pla
            sta   PrPort+2
            jsr   PrOK
            bcc   :jx3
            jmp   :close
:jx3
            PushLongAt PrPort           ; its one page
            PushLong 0
            Tool  _PrOpenPage
            jsr   PrOK
            bcs   :page
            lda   PrRecH                ; the page's rect (the print record's
            sta   pp                    ; rPage), less its last row and column
            lda   PrRecH+2
            sta   pp+2
            ldy   #2
            lda   [pp],y
            tax
            lda   [pp]
            sta   pp
            stx   pp+2
            ldy   #8
            ldx   #0
:r          lda   [pp],y
            sta   PRect,x
            iny
            iny
            inx
            inx
            cpx   #8
            bcc   :r
            dec   PRect+4
            dec   PRect+6
            Tool  _PenNormal
            lda   PRect+2               ; the crosses: top left, top right,
            ldx   PRect                 ; bottom left, bottom right
            jsr   Cross
            lda   PRect+6
            ldx   PRect
            jsr   Cross
            lda   PRect+2
            ldx   PRect+4
            jsr   Cross
            lda   PRect+6
            ldx   PRect+4
            jsr   Cross
:page       PushLongAt PrPort
            Tool  _PrClosePage
:close      PushLongAt PrPort
            Tool  _PrCloseDoc
            jsr   PrEnd
:out        plb
            rtl

* Cross: a cross of two 21-pixel strokes centred at h A, v X.
Cross       pha
            phx
            pha                         ; MoveTo(h, v - 10)
            txa
            sec
            sbc   #10
            pha
            Tool  _MoveTo
            pea   0                     ; down 20
            pea   20
            Tool  _Line
            pea   -10                   ; to the left end
            pea   -10
            Tool  _Move
            pea   20                    ; across 20
            pea   0
            Tool  _Line
            plx
            pla
            rts

* PrStart: the Print Manager started (once), the print record made with
* its defaults (once) and checked.
*   out: carry set (A = the error; the alert shown) if it can't be
PrStart     lda   PrOn
            bne   :rec
            pea   $13                   ; the tool set, from the System folder
            pea   $0300
            Tool  _LoadOneTool
            bcc   :jx4
            jmp   :err
:jx4
            pha                         ; its direct page: 2 pages in bank 0
            pha
            PushLong 512
            lda   uid
            pha
            pea   $C005
            PushLong 0
            Tool  _NewHandle
            pla
            sta   PrDPH
            pla
            sta   PrDPH+2
            bcs   :err
            lda   PrDPH
            sta   pp
            lda   PrDPH+2
            sta   pp+2
            lda   uid
            pha
            lda   [pp]
            pha
            Tool  _PMStartUp
            bcs   :err
            inc   PrOn
:rec        lda   PrRecH
            ora   PrRecH+2
            bne   :valid
            pha                         ; the print record: its defaults
            pha
            PushLong 140
            lda   uid
            pha
            pea   $8000
            PushLong 0
            Tool  _NewHandle
            pla
            sta   PrRecH
            pla
            sta   PrRecH+2
            bcs   :err
            PushLongAt PrRecH
            Tool  _PrDefault
:valid      pha                         ; (checked against the printer chosen)
            PushLongAt PrRecH
            Tool  _PrValidate
            pla
            clc
            rts
:err        jsr   Alert
            sec
            rts

* Dialogs: page setup, then the print job (Cancel in either: errCancel).
Dialogs     pha
            PushLongAt PrRecH
            Tool  _PrStlDialog
            pla
            beq   :cancel
            pha
            PushLongAt PrRecH
            Tool  _PrJobDialog
            pla
            beq   :cancel
            clc
            rts
:cancel     lda   #errCancel
            sec
            rts

* PrOK: carry set if the Print Manager has an error (it is then told to
* stop: PrSetError($80)).
PrOK        pha
            Tool  _PrError
            pla
            beq   :ok
            sta   PrErr
            pea   $80
            Tool  _PrSetError
            sec
            rts
:ok         clc
            rts

* PrEnd: after the document: its spooled pages printed, or the error.
PrEnd       pha
            Tool  _PrError
            pla
            bne   :err
            PushLongAt PrRecH
            PushLong 0
            PushLong PrStatus
            Tool  _PrPicFile
            pha
            Tool  _PrError
            pla
            bne   :err
            clc
            rts
:err        cmp   #$80                  ; (stopped: an error said already)
            bne   :say
            lda   PrErr
:say        jsr   Alert
            sec
            rts

* Alert: "I am having a hard time printing this document." with A.
Alert       sta   PrErr
            cmp   #$80                  ; (cancelled by the user: nothing)
            beq   :out
            xba
            pha
            and   #$00FF
            ldx   #0
            jsr   Hex2
            pla
            xba
            ldx   #2
            jsr   Hex2
            pha
            pea   0
            PushLong 0
            PushLong TxPrErr
            Tool  _AlertWindow
            pla
:out        lda   PrErr
            rts

* Hex2: A's low byte as 2 hex digits at TxPrHex + X.
Hex2        pha
            lsr
            lsr
            lsr
            lsr
            and   #$000F
            tay
            lda   HexD,y
            sep   #$20
            mx    %10
            sta   TxPrHex,x
            rep   #$20
            mx    %00
            pla
            and   #$000F
            tay
            lda   HexD,y
            sep   #$20
            mx    %10
            sta   TxPrHex+1,x
            rep   #$20
            mx    %00
            rts

* PrintPic: File > Print (normal)...: page setup, the print job, then the
* screen image (scrp; pw x ph pixels, darg bytes a line) on as many pages
* as it needs, down each column of pages, then across; at full size, its
* colours through the screen's colour table 0 (the image's own, while it
* prints).
*   out: carry set (A = the error, or errCancel) if it wasn't printed
PrintPic    ent
            phb
            phk
            plb
            jsr   PrStart
            bcc   :jx5
            jmp   :out
:jx5
            jsr   Dialogs
            bcc   :jx6
            jmp   :out
:jx6
            jsr   PageRect              ; the page: PRect
            lda   PRect+4               ; its size in pixels
            sec
            sbc   PRect
            sta   PageH
            lda   PRect+6
            sec
            sbc   PRect+2
            sta   PageW
            lda   scrp                  ; the image's LocInfo: the mode of
            sta   PLoc+2                ; its first line
            lda   scrp+2
            sta   PLoc+4
            ldy   #scbOffset
            lda   [scrp],y
            and   #$00F0
            sta   PLoc
            lda   ph
            sta   PLoc+10
            lda   pw
            sta   PLoc+12
            jsr   UsePal                ; (its colours on the screen)
            pha
            pha
            PushLongAt PrRecH
            PushLong 0
            Tool  _PrOpenDoc
            pla
            sta   PrPort
            pla
            sta   PrPort+2
            jsr   PrOK
            bcc   :jx7
            jmp   :close
:jx7
            stz   PX0                   ; each column of pages
:col        stz   PY0                   ; each page down it
:row        PushLongAt PrPort
            PushLong 0
            Tool  _PrOpenPage
            jsr   PrOK
            bcs   :pageEnd
            lda   PY0                   ; the part of the image on it
            sta   PSrc
            clc
            adc   PageH
            cmp   ph
            bcc   :b
            lda   ph
:b          sta   PSrc+4
            lda   PX0
            sta   PSrc+2
            clc
            adc   PageW
            cmp   pw
            bcc   :r
            lda   pw
:r          sta   PSrc+6
            PushLong PLoc
            PushLong PSrc
            lda   PRect+2
            pha
            lda   PRect
            pha
            pea   0
            Tool  _PPToPort
:pageEnd    PushLongAt PrPort
            Tool  _PrClosePage
            jsr   PrOK
            bcs   :close
            lda   PY0
            clc
            adc   PageH
            sta   PY0
            cmp   ph
            bcc   :row
            lda   PX0
            clc
            adc   PageW
            sta   PX0
            cmp   pw
            bcs   :jx8
            jmp   :col
:jx8
:close      PushLongAt PrPort
            Tool  _PrCloseDoc
            jsr   NoPal
            jsr   PrEnd
:out        plb
            rtl

* PageRect: PRect = the print record's page (rPage).
PageRect    lda   PrRecH
            sta   pp
            lda   PrRecH+2
            sta   pp+2
            ldy   #2
            lda   [pp],y
            tax
            lda   [pp]
            sta   pp
            stx   pp+2
            ldy   #8
            ldx   #0
:r          lda   [pp],y
            sta   PRect,x
            iny
            iny
            inx
            inx
            cpx   #8
            bcc   :r
            rts

* UsePal: the screen's colour table 0 = the image's first line's (kept
* to put back: NoPal).
UsePal      pea   0
            PushLong SavedPal
            Tool  _GetColorTable
            ldy   #scbOffset
            lda   [scrp],y
            and   #$000F
            asl
            asl
            asl
            asl
            asl
            clc
            adc   #palOffset
            adc   scrp
            tax
            lda   scrp+2
            adc   #0
            pea   0
            pha
            phx
            Tool  _SetColorTable
            rts
NoPal       pea   0
            PushLong SavedPal
            Tool  _SetColorTable
            rts

* PrintQuit: the Print Manager shut down, if it was started.
PrintQuit   ent
            phb
            phk
            plb
            lda   PrOn
            beq   :out
            Tool  _PMShutDown
            stz   PrOn
:out        plb
            rtl

*-------------------------------------------------------------
* Data
*-------------------------------------------------------------
PrOn        dw    0                     ; the Print Manager started
PrDPH       adrl  0                     ; its direct page
PrRecH      adrl  0                     ; the print record
PrPort      adrl  0                     ; the printing port
PrErr       dw    0
PRect       ds    8                     ; the page's rect
PageH       dw    0                     ; (its size in pixels)
PageW       dw    0
PX0         dw    0                     ; the page's place in the image
PY0         dw    0
PSrc        ds    8                     ; the part of the image on it
PLoc        dw    0                     ; the image's LocInfo
            adrl  0
            dw    160
            dw    0,0,200,320
SavedPal    ds    32                    ; the screen's colour table 0
PrStatus    ds    32                    ; PrPicFile's status record
HexD        asc   '0123456789ABCDEF'
TxPrErr     asc   '52/I am having a hard time printing this document (error $'
TxPrHex     asc   '0000)./^#0',00
