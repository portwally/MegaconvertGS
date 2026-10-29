*-------------------------------------------------------------
* Babel.s - Babelfish, Seven Hills Software's file translators (a segment
* of its own; docs/superconvert-formats-extra.md 4 and Babelfish's
* programming manual): SuperConvert's True Color and PixelMap imports and
* exports. With the user: Babelfish's own Open and Export dialogs. Without
* (tests, Re-convert last file): the translator that ranks the file best
* (import), or the one BabelName named (export).
*
* An imported PixelMap that fits the screen (160 bytes x 200 lines at most)
* becomes the screen image, with its SCBs and colour tables; a larger one,
* and every True Color image, a true colour image (NewTrueL).
*
* All requests go to "Seven Hills~Babelfish~" through SendRequest; each
* reply starts with the Tool Locator's count and Babelfish's result.
*-------------------------------------------------------------
            rel
            mx    %00
            use   macros/Macs.s
            put   Equates.s

NewTrueL    ext

_SendRequest =    $1C01
_BlockMove  =     $2B02
_HUnlock    =     $2202

bfStartUp   =     $9001                 ; Babelfish's requests
bfShutDown  =     $9002
bfGetFile   =     $9012
bfImportThis =    $9013
bfRead      =     $9014
bfPutFile   =     $9015
bfExportThis =    $9016
bfWrite     =     $9017
bfMatchKinds =    $9021
bfMatchFile =     $9022
bfName2Num  =     $9024
bfNum2Name  =     $9023

xStatus     =     $02                   ; the transfer record: status,
xFlags      =     $04                   ; flags, kinds of data (8 bytes),
xKinds      =     $06                   ; translator, thermometer, the
xTrans      =     $0E                   ; data record, the file's path
xAction     =     $12                   ; (GS/OS string) and name (Pascal
xFull       =     $14                   ; string)
xNow        =     $16
xData       =     $1C
xPath       =     $20
xName       =     $24

stDone      =     $8000                 ; statuses
stCancel    =     $8001
stAbort     =     $80FF

xp          =     q2                    ; the transfer record (long)

*-------------------------------------------------------------
* Entries
*-------------------------------------------------------------

* BabelAsk: Babelfish's Open dialog for kind A (2 PixelMap, 4 True Color):
* the file and its translator chosen, nothing read yet.
*   out: carry clear and pathp = the file's path (a GS/OS string); or carry
*        set and A = error (errCancel: cancelled)
BabelAsk    ent
            phb
            phk
            plb
            sta   Kind
            stz   Quiet
            jsr   FreeReply
            stz   Asked
            jsr   StartBF
            bcs   :out
            jsr   NewXfer
            lda   #$0007                ; progress, errors, standard matching
            ldy   #xFlags
            sta   [xp],y
            jsr   BlkXfer               ; the record, the default prompt and
            jsr   BlkReply              ; button, the reply
            ldx   #bfGetFile
            jsr   SendBlk
            bcs   :out
            jsr   Status                ; (cancelled: errCancel)
            bcs   :out
            jsr   ReplyPath
            inc   Asked
            clc
:out        plb
            rtl

* BabelLoad: the import of kind A: the file BabelAsk chose, or else the one
* at pathp; X bit 0 (tests): no error dialogs from Babelfish, and the
* translator BabelName named (if any); bit 1 (Re-convert last file): the
* translator the last import used. Else the one ranking the file highest
* (two equal: the first by name; a person chooses in the dialog). The
* screen image is cleared and the true colour image gone already.
*   out: carry clear and A = 0: the screen image (pw, ph, p640 set), 1: the
*        true colour image; or carry set and A = error
BabelLoad   ent
            phb
            phk
            plb
            sta   Kind
            txa
            and   #1
            sta   Quiet
            txa
            and   #2
            sta   Again
            jsr   Import
            php
            pha
            jsr   FreeReply
            stz   Asked
            pla
            plp
            plb
            rtl

* BabelSave: the export of kind A (2: the screen image at scrp, pw x ph
* pixels, p640; 4: the true colour image at tp, tstride, rw x rh): X = 0:
* Babelfish's Export dialog, fp = the name it offers (GS/OS string); X = 1
* (tests): to pathp with the translator BabelName named, no error dialogs.
*   out: carry clear, or carry set and A = error (errCancel: cancelled)
BabelSave   ent
            phb
            phk
            plb
            sta   Kind
            stx   Quiet
            jsr   Export
            php
            pha
            jsr   FreeReply
            pla
            plp
            plb
            rtl

* BabelName: the translator tests export with (fp: a C string; empty: the
* first that exports the kind).
BabelName   ent
            phb
            phk
            plb
            sep   #$20
            mx    %10
            ldy   #0
:c          lda   [fp],y
            beq   :end
            sta   TName+1,y
            iny
            cpy   #63
            bcc   :c
:end        tya
            sta   TName
            rep   #$20
            mx    %00
            plb
            rtl

* BabelLast: (tests) the last translator used: fp = its name (a Pascal
* string), A = the kind of data it sent when importing.
BabelLast   ent
            phb
            phk
            plb
            lda   #TrName
            sta   fp
            lda   #^TrName
            sta   fp+2
            lda   #List                 ; dctl: the last Match list (number,
            sta   dctl                  ; ranking; ListN bytes), darg its
            lda   #^List                ; length, dact: the last request
            sta   dctl+2
            lda   ListN
            sta   darg
            lda   LastReq
            sta   dact
            lda   LastKind
            plb
            rtl

* BabelQuit: Babelfish shut down, if this program started it.
BabelQuit   ent
            phb
            phk
            plb
            lda   Started
            beq   :out
            jsr   BlkUid
            ldx   #bfShutDown
            jsr   SendBlk
            ldx   #XferH
            jsr   FreeAt
            stz   Started
:out        plb
            rtl

*-------------------------------------------------------------
* Importing
*-------------------------------------------------------------

Import      jsr   StartBF
            bcc   :up
            rts
:up         lda   Asked
            beq   :path
            jmp   :chosen
:path       jsr   NewXfer               ; the file at pathp
            jsr   PathName
            lda   Again                 ; Re-convert: the translator as before
            beq   :byName
            lda   KeptTrans
            ldy   #xTrans
            sta   [xp],y
            bra   :chosen
:byName     lda   Quiet                 ; tests: by name
            beq   :match
            lda   TName
            and   #$00FF
            beq   :match
            lda   #0                    ; (importing)
            ldy   #xFlags
            sta   [xp],y
            lda   #$FFFF
            ldy   #xTrans
            sta   [xp],y
            jsr   BlkXfer
            lda   #TName
            sta   Blk+4
            lda   #^TName
            sta   Blk+6
            ldx   #bfName2Num
            jsr   SendBlk
            bcc   :named
            rts
:named      ldy   #xTrans
            lda   [xp],y
            cmp   #$FFFF
            bne   :chosen
            lda   BOut+4
            sta   [xp],y
            bra   :chosen
:match      lda   #$0004                ; the one ranking it highest
            ldy   #xFlags
            sta   [xp],y
            jsr   BlkXfer
            ldx   #bfMatchFile
            jsr   SendBlk
            bcc   :list
            rts
:list       ldx   #4
            jsr   FirstTrans
            bcc   :chosen
            lda   #errNotPicture
            rts
:chosen     jsr   TransName
            lda   #0                    ; Import: the translator opens the
            ldy   #xStatus              ; file (with its progress window, and
            sta   [xp],y                ; its error messages but in tests)
            jsr   ShowFlags
            ldy   #xFlags
            sta   [xp],y
            ldy   #xKinds
            lda   Kind
            sta   [xp],y
            jsr   BlkXfer
            ldx   #bfImportThis
            jsr   SendBlk
            bcs   :err
            jsr   Status
            bcs   :err
            ldy   #xKinds               ; the one kind it sends
            lda   [xp],y
            and   #$00FF
            sta   Kind
            sta   LastKind
            stz   Got
            stz   GotTrue
            stz   Row
:read       lda   #0                    ; Read, until it is done
            ldy   #xStatus
            sta   [xp],y
            jsr   BlkXfer
            ldx   #bfRead
            jsr   SendBlk
            bcs   :err
            ldy   #xStatus
            lda   [xp],y
            beq   :take
            cmp   #stDone
            beq   :take
            jsr   Status                ; (failed: the translator is shut down)
:err        rts
:take       sta   Done
            jsr   Take
            bcc   :next
            pha                         ; this side failed: stop the translator
            jsr   Abort
            pla
            sec
            rts
:next       lda   Done
            beq   :read
            lda   Got                   ; nothing came: not a picture
            bne   :got
            lda   #errNotPicture
            sec
            rts
:got        ldy   #xTrans               ; (kept for Re-convert)
            lda   [xp],y
            sta   KeptTrans
            lda   GotTrue
            clc
            rts

* Abort: the import stopped from this side (the translator closes the file).
Abort       lda   Done
            bne   :out
            lda   #stAbort
            ldy   #xStatus
            sta   [xp],y
            jsr   BlkXfer
            ldx   #bfRead
            jsr   SendBlk
:out        rts

* Take: the data the last Read sent, if any (p1: its data record).
*   out: carry set and A = error if it can't be kept
Take        ldy   #xData
            lda   [xp],y
            sta   p1
            iny
            iny
            lda   [xp],y
            sta   p1+2
            ora   p1
            bne   :rec
            clc
            rts
:rec        lda   Kind
            cmp   #4
            bne   :pm
            jmp   TakeTC
:pm         cmp   #2
            beq   TakePM
            lda   #errUnsupported
            sec
            rts

* TakePM: a PixelMap (handed over with its image, SCB and colour table
* handles, which are disposed of here).
TakePM      ldy   #$0E                  ; (no image yet: nothing to take)
            lda   [p1],y
            iny
            iny
            ora   [p1],y
            bne   :have
            clc
            rts
:have       inc   Got
            ldy   #2                    ; LocInfo (p2): mode, row bytes, size
            lda   [p1],y
            sta   p2
            iny
            iny
            lda   [p1],y
            sta   p2+2
            lda   [p2]
            and   #$00FF
            sta   PortSCB
            ldy   #6
            lda   [p2],y
            sta   RowB
            ldy   #12
            lda   [p2],y
            ldy   #8
            sec
            sbc   [p2],y
            sta   Lines
            ldy   #14
            lda   [p2],y
            ldy   #10
            sec
            sbc   [p2],y
            sta   Pix
            ldy   #$0E                  ; the image (p3)
            jsr   LockAt
            sta   p3
            stx   p3+2
            stz   ScbOK                 ; the SCBs (q0): their handle, else
            ldy   #$12                  ; their pointer, else the mode for all
            jsr   LockAt
            sta   q0
            stx   q0+2
            ora   q0+2
            bne   :scb
            ldy   #6
            lda   [p1],y
            sta   q0
            iny
            iny
            lda   [p1],y
            sta   q0+2
            ora   q0
            beq   :pal
:scb        inc   ScbOK
:pal        stz   PalLen                ; the colour tables (q1) and how many
            ldy   #$16                  ; bytes of them
            jsr   LockAt
            sta   q1
            stx   q1+2
            ora   q1+2
            beq   :palPtr
            ldy   #$16
            jsr   SizeAt
            bra   :palLen
:palPtr     ldy   #$0A
            lda   [p1],y
            sta   q1
            iny
            iny
            lda   [p1],y
            sta   q1+2
            ora   q1
            beq   :sized
            lda   #512
:palLen     cmp   #513
            bcc   :pl
            lda   #512
:pl         sta   PalLen
:sized      lda   ScbOK                 ; the mode: line 0's (when the SCBs
            beq   :port                 ; came), else the LocInfo's
            lda   [q0]
            and   #$00FF
            sta   PortSCB
:port       stz   M640                  ; its bytes a row: 2 or 4 pixels each
            lda   PortSCB
            and   #$0080
            beq   :m320
            inc   M640
            lda   Pix
            clc
            adc   #3
            lsr
            lsr
            bra   :bytes
:m320       lda   Pix
            inc
            lsr
:bytes      sta   Bytes
            lda   Pix                   ; nothing in it?
            beq   :empty
            bmi   :empty
            lda   Lines
            beq   :empty
            bmi   :empty
            lda   Bytes                 ; fits the screen: the screen image
            cmp   #161
            bcs   :true
            lda   Lines
            cmp   #201
            bcs   :true
            jsr   PMScreen
            bra   :free
:true       jsr   PMTrue
            bra   :free
:empty      lda   #errCorrupt
            sec
:free       php                         ; the three handles are ours: gone
            pha
            ldy   #$0E
            jsr   DropAt
            ldy   #$12
            jsr   DropAt
            ldy   #$16
            jsr   DropAt
            pla
            plp
            rts

* PMScreen: the PixelMap into the screen image ($C1 layout): its rows, its
* SCBs (lines below it: the mode's), its colour tables.
PMScreen    lda   p3
            sta   n0
            lda   p3+2
            sta   n0+2
            lda   scrp
            sta   n1
            lda   scrp+2
            sta   n1+2
            stz   t0
:row        PushLongAt n0
            PushLongAt n1
            pea   0
            lda   Bytes
            pha
            Tool  _BlockMove
            lda   n0
            clc
            adc   RowB
            sta   n0
            bcc   :s
            inc   n0+2
:s          lda   n1
            clc
            adc   #160
            sta   n1
            bcc   :d
            inc   n1+2
:d          inc   t0
            lda   t0
            cmp   Lines
            bcc   :row
            ldy   #0                    ; SCBs
:scb        lda   PortSCB
            cpy   Lines
            bcs   :put
            ldx   ScbOK
            beq   :put
            lda   [q0],y
:put        phy
            pha
            tya
            clc
            adc   #scbOffset
            tay
            pla
            sep   #$20
            mx    %10
            sta   [scrp],y
            rep   #$20
            mx    %00
            ply
            iny
            cpy   #200
            bcc   :scb
            lda   PalLen                ; colour tables: as many as came (as
            beq   :size                 ; SuperConvert)
            PushLongAt q1
            lda   scrp+2
            pha
            lda   scrp
            clc
            adc   #palOffset
            pha
            pea   0
            lda   PalLen
            pha
            Tool  _BlockMove
:size       lda   Pix                   ; its size: the whole screen (the
            sta   pw                    ; lines' modes say) or smaller
            lda   Lines
            sta   ph
            lda   M640
            sta   p640
            lda   Lines
            cmp   #200
            bne   :out
            lda   Pix
            ldx   M640
            beq   :w320
            cmp   #640
            bra   :whole
:w320       cmp   #320
:whole      bne   :out
            stz   pw
            stz   ph
            stz   p640
:out        stz   GotTrue
            clc
            rts

* PMTrue: a PixelMap larger than the screen into a true colour image: each
* line in its own colour table (from its SCB), in the map's mode.
PMTrue      lda   M640                  ; (640 mode: pixels twice as tall)
            sta   ttall
            lda   Pix
            ldx   Lines
            jsr   NewTrue               ; tp, tstride
            bcc   :made
            rts
:made       lda   #1
            sta   GotTrue
            lda   p3                    ; n0: the map's row, n1: the image's
            sta   n0
            lda   p3+2
            sta   n0+2
            lda   tp
            sta   n1
            lda   tp+2
            sta   n1+2
            stz   t0
:row        lda   PortSCB               ; the line's colour table, as RGB
            ldx   ScbOK
            beq   :tab
            ldy   t0
            lda   [q0],y
:tab        and   #$000F
            xba
            lsr
            lsr
            lsr                         ; x 32
            sta   t1
            ldx   #0
:entry      lda   #0
            ldy   t1
            cpy   PalLen
            bcs   :rgb
            lda   [q1],y
:rgb        sta   t2                    ; $0RGB: each 4 bits x 17
            xba
            and   #$000F
            jsr   Times17
            sta   LUT,x
            lda   t2
            lsr
            lsr
            lsr
            lsr
            and   #$000F
            jsr   Times17
            sta   LUT+1,x
            lda   t2
            and   #$000F
            jsr   Times17
            sta   LUT+2,x
            inc   t1
            inc   t1
            inx
            inx
            inx
            cpx   #48
            bcc   :entry
            stz   t2                    ; t2: the pixel, Y: its RGB
            ldy   #0
:pix        lda   M640
            bne   :p640
            lda   t2                    ; 320 mode: a nibble, high one first
            lsr
            phy
            tay
            lda   [n0],y
            ply
            and   #$00FF
            sta   t3
            lda   t2
            and   #1
            bne   :low
            lda   t3
            lsr
            lsr
            lsr
            lsr
            bra   :index
:low        lda   t3
            and   #$000F
            bra   :index
:p640       lda   t2                    ; 640 mode: two bits, the colours
            lsr                         ; 8-11, 12-15, 0-3, 4-7 by place
            lsr
            phy
            tay
            lda   [n0],y
            ply
            and   #$00FF
            sta   t3
            lda   t2
            and   #3
            tax
            beq   :sh
:shift      asl   t3
            asl   t3
            dex
            bne   :shift
:sh         lda   t3
            and   #$00C0
            lsr
            lsr
            lsr
            lsr
            lsr
            lsr
            sta   t3
            lda   t2
            and   #3
            tax
            lda   Base640,x
            and   #$00FF
            clc
            adc   t3
:index      sta   t3                    ; x 3
            asl
            adc   t3
            tax
            sep   #$20
            mx    %10
            lda   LUT,x
            sta   [n1],y
            iny
            lda   LUT+1,x
            sta   [n1],y
            iny
            lda   LUT+2,x
            sta   [n1],y
            iny
            rep   #$20
            mx    %00
            inc   t2
            lda   t2
            cmp   Pix
            bcs   :rowDone
            jmp   :pix
:rowDone    lda   n0                    ; the next line
            clc
            adc   RowB
            sta   n0
            bcc   :s
            inc   n0+2
:s          lda   n1
            clc
            adc   tstride
            sta   n1
            bcc   :d
            inc   n1+2
:d          inc   t0
            lda   t0
            cmp   Lines
            bcs   :done
            jmp   :row
:done       clc
            rts

Base640     db    8,12,0,4

* NewTrue: NewTrueL (A x X pixels: tp, tstride), keeping the pointers
* here (it clears the image with scratch pointers of its own).
NewTrue     pei   p1+2
            pei   p1
            pei   p3+2
            pei   p3
            pei   q0+2
            pei   q0
            pei   q1+2
            pei   q1
            jsl   NewTrueL
            tax                         ; (A, carry kept)
            pla
            sta   q1
            pla
            sta   q1+2
            pla
            sta   q0
            pla
            sta   q0+2
            pla
            sta   p3
            pla
            sta   p3+2
            pla
            sta   p1
            pla
            sta   p1+2
            txa
            rts

* Times17: A (0-15) x 17.
Times17     sta   t3
            asl
            asl
            asl
            asl
            clc
            adc   t3
            rts

* TakeTC: a True Color block: rows of RGB, top first, into the true colour
* image (made with the first block's size); its handle, if any, disposed of.
TakeTC      ldy   #6                    ; rows in this block
            lda   [p1],y
            bne   :rows
            clc
            rts
:rows       sta   t0
            lda   GotTrue
            bne   :made
            ldy   #2                    ; the first: the image, its size
            lda   [p1],y
            tax
            ldy   #4
            lda   [p1],y
            sta   THigh
            stz   ttall
            txa
            ldx   THigh
            jsr   NewTrue
            bcc   :new
            rts
:new        inc   Got
            inc   GotTrue
            lda   tp
            sta   TDst
            lda   tp+2
            sta   TDst+2
:made       lda   TDst
            sta   n1
            lda   TDst+2
            sta   n1+2
            ldy   #$0C                  ; the rows: their handle, else pointer
            jsr   LockAt
            sta   n0
            stx   n0+2
            ora   n0+2
            bne   :data
            ldy   #8
            lda   [p1],y
            sta   n0
            iny
            iny
            lda   [p1],y
            sta   n0+2
            ora   n0
            beq   :drop
:data       lda   Row                   ; (rows past the image's end: not kept)
            cmp   THigh
            bcs   :drop
            PushLongAt n0
            PushLongAt n1
            pea   0
            pei   tstride
            Tool  _BlockMove
            lda   n0
            clc
            adc   tstride
            sta   n0
            bcc   :s
            inc   n0+2
:s          lda   n1
            clc
            adc   tstride
            sta   n1
            bcc   :d
            inc   n1+2
:d          inc   Row
            dec   t0
            bne   :data
            lda   n1
            sta   TDst
            lda   n1+2
            sta   TDst+2
:drop       ldy   #$0C
            jsr   DropAt
            clc
            rts

*-------------------------------------------------------------
* Exporting
*-------------------------------------------------------------

Export      jsr   StartBF
            bcc   :up
            rts
:up         jsr   NewXfer
            jsr   MakeData              ; the data record (and a buffer)
            bcc   :data
:fail       rts
:data       lda   #DataRec
            ldy   #xData
            sta   [xp],y
            lda   #^DataRec
            iny
            iny
            sta   [xp],y
            lda   Quiet
            bne   :named
            lda   #$000E                ; PutFile: errors, standard, exporting
            ldy   #xFlags
            sta   [xp],y
            lda   fp                    ; the prompt, the name offered
            sta   Custom+10
            lda   fp+2
            sta   Custom+12
            jsr   BlkXfer
            lda   #Custom
            sta   Blk+4
            lda   #^Custom
            sta   Blk+6
            jsr   BlkReply
            ldx   #bfPutFile
            jsr   SendBlk
            bcs   :fail
            jsr   Status
            bcs   :fail
            jsr   ReplyPath
            bra   :export
:named      jsr   PathName              ; tests: the file at pathp, the
            lda   #$0008                ; translator named
            ldy   #xFlags
            sta   [xp],y
            lda   TName
            and   #$00FF
            bne   :byName
            jsr   BlkXfer               ; (no name: the first for the kind)
            ldx   #bfMatchKinds
            jsr   SendBlk
            bcs   :fail
            ldx   #2
            jsr   FirstTrans
            bcc   :export
            lda   #errNotImpl
:fail2      rts
:byName     lda   #$FFFF                ; (the number: in the record, or
            ldy   #xTrans               ; else after the result)
            sta   [xp],y
            jsr   BlkXfer
            lda   #TName
            sta   Blk+4
            lda   #^TName
            sta   Blk+6
            ldx   #bfName2Num
            jsr   SendBlk
            bcs   :fail2
            ldy   #xTrans
            lda   [xp],y
            cmp   #$FFFF
            bne   :export
            lda   BOut+4
            sta   [xp],y
:export     jsr   TransName
            lda   #0                    ; ExportThis: the translator makes
            ldy   #xStatus              ; the file
            sta   [xp],y
            jsr   ShowFlags
            ora   #$0008
            ldy   #xFlags
            sta   [xp],y
            lda   #3                    ; the thermometer: rows sent
            ldy   #xAction
            sta   [xp],y
            lda   Kind
            cmp   #4
            beq   :full
            lda   #1
            bra   :scale
:full       lda   rh
:scale      ldy   #xFull
            sta   [xp],y
            lda   #0
            ldy   #xNow
            sta   [xp],y
            jsr   BlkXfer
            ldx   #bfExportThis
            jsr   SendBlk
            bcs   :err
            jsr   Status
            bcs   :err
            lda   Kind
            cmp   #4
            beq   :tc
            jsr   Write                 ; a PixelMap: all at once
            bcs   :err
            bra   :finish
:tc         lda   rh                    ; True Color: all the rows at once
            sta   DataRec+6             ; (the PPM translator, the only one,
            ldy   #xNow                 ; takes one Write; GS/OS writes a
            sta   [xp],y                ; block crossing banks)
            lda   #1
            ldy   #xAction
            sta   [xp],y
            jsr   Write
            bcc   :finish
:err        rts
:finish     lda   #stDone               ; Done: the translator closes the file
            ldy   #xStatus
            sta   [xp],y
            jsr   BlkXfer
            ldx   #bfWrite
            jsr   SendBlk
            bcs   :err
            ldy   #xStatus
            lda   [xp],y
            beq   :ok
            cmp   #stDone
            beq   :ok
            jmp   Status
:ok         clc
            rts

* Write: Write with status Continue.   out: carry set, A = error if failed
Write       lda   #0
            ldy   #xStatus
            sta   [xp],y
            jsr   BlkXfer
            ldx   #bfWrite
            jsr   SendBlk
            bcs   :out
            jsr   Status
:out        rts

* MakeData: the data record for the kind: a PixelMap of the screen image
* (its LocInfo, SCBs and colour tables, by pointer), or True Color (the
* image's rows, by pointer).
MakeData    lda   Kind
            cmp   #4
            beq   :tc
            lda   #8                    ; PixelMap: 8 parameters
            sta   DataRec
            lda   #Loc
            sta   DataRec+2
            lda   #^Loc
            sta   DataRec+4
            lda   scrp
            clc
            adc   #scbOffset
            sta   DataRec+6
            lda   scrp+2
            sta   DataRec+8
            lda   scrp
            clc
            adc   #palOffset
            sta   DataRec+10
            lda   scrp+2
            sta   DataRec+12
            ldx   #14                   ; no handles, resolution unknown
:z          stz   DataRec,x
            inx
            inx
            cpx   #30
            bcc   :z
            ldx   #0                    ; LocInfo: mode, the picture, 160
            lda   p640                  ; bytes a row, its size
            beq   :scb
            ldx   #$80
:scb        stx   Loc
            lda   scrp
            sta   Loc+2
            lda   scrp+2
            sta   Loc+4
            lda   #160
            sta   Loc+6
            stz   Loc+8
            stz   Loc+10
            lda   ph
            sta   Loc+12
            lda   pw
            sta   Loc+14
            clc
            rts
:tc         lda   #7                    ; True Color: 7 parameters
            sta   DataRec
            lda   rw
            sta   DataRec+2
            lda   rh
            sta   DataRec+4
            stz   DataRec+6
            ldx   #12
:z2         stz   DataRec,x
            inx
            inx
            cpx   #20
            bcc   :z2
            lda   tp                    ; the rows: the image itself
            sta   DataRec+8
            lda   tp+2
            sta   DataRec+10
            clc
            rts

*-------------------------------------------------------------
* Talking to Babelfish
*-------------------------------------------------------------

* StartBF: Babelfish started once (with SuperConvert's "Loading
* Babelfish..." note while it loads its translators), and the transfer
* record made the size it asks for.   out: carry set, A = error if not
StartBF     lda   Started
            beq   :start
            lda   XferP
            sta   xp
            lda   XferP+2
            sta   xp+2
            clc
            rts
:start      jsr   OpenNote
            jsr   BlkUid
            ldx   #bfStartUp
            jsr   SendBlk
            php
            pha
            jsr   CloseNote
            pla
            plp
            bcc   :up
            lda   #errNoBabel
            rts
:up         lda   BOut+4                ; (+2: cleared a word at a time)
            clc
            adc   #2
            sta   XSize
            sta   n0
            stz   n0+2
            jsr   NewBuf
            bcc   :rec
            pha                         ; no memory: Babelfish shut down again
            jsr   BlkUid
            ldx   #bfShutDown
            jsr   SendBlk
            pla
            sec
            rts
:rec        lda   n1
            sta   XferH
            lda   n1+2
            sta   XferH+2
            lda   p0
            sta   XferP
            sta   xp
            lda   p0+2
            sta   XferP+2
            sta   xp+2
            lda   #1
            sta   Started
            clc
            rts

* NewXfer: the transfer record cleared: 12 parameters, status Continue,
* the kind of data.
NewXfer     lda   #0
            ldy   #0
:z          sta   [xp],y
            iny
            iny
            cpy   XSize
            bcc   :z
            lda   #12
            sta   [xp]
            lda   Kind
            ldy   #xKinds
            sta   [xp],y
            rts

* ShowFlags: the flags for Import or Export: the progress window, and
* error messages except in tests.
ShowFlags   lda   Quiet
            bne   :quiet
            lda   #$0003
            rts
:quiet      lda   #$0001
            rts

* Status: carry set and A = error when the record's status says stop:
* errCancel when the user cancelled, or (Babelfish told them already) for
* any failure but in tests, where the status itself is the error.
Status      ldy   #xStatus
            lda   [xp],y
            bne   :stop
            clc
            rts
:stop       cmp   #stCancel
            beq   :cancel
            ldx   Quiet
            bne   :code
:cancel     lda   #errCancel
:code       sec
            rts

* TransName: the record's translator's name into TrName (tests log it).
TransName   stz   TrName
            stz   LastKind
            jsr   BlkXfer
            ldx   #bfNum2Name
            jsr   SendBlk
            bcs   :out
            lda   BOut+4
            sta   p0
            lda   BOut+6
            sta   p0+2
            ora   p0
            beq   :out
            ldy   #2
            lda   [p0],y
            tax
            lda   [p0]
            sta   p1
            stx   p1+2
            lda   [p1]
            and   #$00FF
            cmp   #63
            bcc   :len
            lda   #62
:len        sta   t1
            tay
            beq   :none
            sep   #$20
            mx    %10
:c          lda   [p1],y
            sta   TrName,y
            dey
            bne   :c
            rep   #$20
            mx    %00
:none       sep   #$20
            mx    %10
            lda   t1
            sta   TrName
            rep   #$20
            mx    %00
            PushLongAt p0
            Tool  _DisposeHandle
:out        rts

* FirstTrans: from the list a Match call sent (its handle at BOut+4; X = 4:
* MatchFile's, a number and a ranking each, X = 2: MatchKinds', numbers
* only) the translator ranking highest (bit 15, "could look closer", aside;
* the first of equals) into the record; the list disposed of (its first 8
* kept for tests).   out: carry set if the list was empty
FirstTrans  stx   ESize
            lda   BOut+4
            sta   p0
            lda   BOut+6
            sta   p0+2
            ora   p0
            bne   :have
            sec
            rts
:have       ldy   #2
            lda   [p0],y
            tax
            lda   [p0]
            sta   p1
            stx   p1+2
            lda   [p1]                  ; count, then the translators
            bne   :some
            jmp   :empty
:some       sta   t1
            stz   ListN
            lda   #$FFFF
            sta   BestRank
            ldy   #2
:e          lda   [p1],y                ; (a number)
            sta   t2
            stz   t3
            lda   ESize
            cmp   #4
            bcc   :rank
            iny
            iny
            lda   [p1],y
            sta   t3
            dey
            dey
:rank       ldx   ListN                 ; (kept: number, ranking)
            cpx   #32
            bcs   :kept
            lda   t2
            sta   List,x
            lda   t3
            sta   List+2,x
            inx
            inx
            inx
            inx
            stx   ListN
:kept       lda   t3
            and   #$7FFF
            cmp   BestRank
            beq   :next
            bcc   :next
            sta   BestRank              ; (better: higher, or the first)
            lda   t2
            sta   BestNum
            bra   :next
:next       lda   BestRank
            cmp   #$FFFF
            bne   :step
            lda   t3
            and   #$7FFF
            sta   BestRank
            lda   t2
            sta   BestNum
:step       tya
            clc
            adc   ESize
            tay
            dec   t1
            bne   :e
            lda   BestNum
            ldy   #xTrans
            sta   [xp],y
            PushLongAt p0
            Tool  _DisposeHandle
            clc
            rts
:empty      PushLongAt p0
            Tool  _DisposeHandle
            sec
            rts

* SendBlk: request X to Babelfish, with Blk in and BOut out.
*   out: carry clear; or carry set and A = Babelfish's result, or the
*        Tool Locator's error (nobody took the request: $0120)
SendBlk     stx   LastReq
            stz   BOut
            stz   BOut+2
            phx
            pea   $8001                 ; to the name, the first one only
            PushLong BFName
            PushLong Blk
            PushLong BOut
            Tool  _SendRequest
            bcs   :tool
            lda   BOut+2
            bne   :err
            clc
            rts
:tool       ldx   BOut+2
            beq   :err
            txa
:err        sec
            rts

* BlkUid, BlkXfer, BlkReply: what requests get: the program's ID (start
* up, shut down), or the transfer record, then no custom record and the
* reply record (the dialogs).
BlkUid      lda   uid
            sta   BFUid
            lda   #BFUid
            sta   Blk
            lda   #^BFUid
            sta   Blk+2
            rts
BlkXfer     lda   xp
            sta   Blk
            lda   xp+2
            sta   Blk+2
            stz   Blk+4
            stz   Blk+6
            rts
BlkReply    lda   #Reply
            sta   Blk+8
            lda   #^Reply
            sta   Blk+10
            stz   Reply                 ; new handles for the name and path
            lda   #3
            sta   Reply+8
            sta   Reply+14
            stz   Reply+10
            stz   Reply+12
            stz   Reply+16
            stz   Reply+18
            rts

* ReplyPath: the file the dialog chose, into the record: its path (the
* reply's GS/OS string, also pathp) and its name (a Pascal string: the
* length word's high byte becomes the length byte).
ReplyPath   PushLongAt Reply+16
            Tool  _HLock
            PushLongAt Reply+10
            Tool  _HLock
            lda   Reply+16
            sta   p0
            lda   Reply+18
            sta   p0+2
            ldy   #2
            lda   [p0],y
            tax
            lda   [p0]
            clc
            adc   #2
            sta   pathp
            bcc   :p
            inx
:p          stx   pathp+2
            ldy   #xPath
            sta   [xp],y
            iny
            iny
            txa
            sta   [xp],y
            lda   Reply+10
            sta   p0
            lda   Reply+12
            sta   p0+2
            ldy   #2
            lda   [p0],y
            tax
            lda   [p0]
            sta   p1
            stx   p1+2
            ldy   #2
            sep   #$20
            mx    %10
            lda   [p1],y
            iny
            sta   [p1],y
            rep   #$20
            mx    %00
            lda   p1
            clc
            adc   #3
            ldy   #xName
            sta   [xp],y
            lda   p1+2
            adc   #0
            iny
            iny
            sta   [xp],y
            rts

* PathName: the file at pathp (GS/OS string) into the record: its path,
* and its name (after the last ':') as a Pascal string.
PathName    lda   pathp
            ldy   #xPath
            sta   [xp],y
            lda   pathp+2
            iny
            iny
            sta   [xp],y
            lda   [pathp]
            inc                         ; (the last character's place)
            tay
            sta   t0
:back       cpy   #2
            bcc   :start
            lda   [pathp],y
            and   #$00FF
            cmp   #':'
            beq   :start
            dey
            bra   :back
:start      iny                         ; Y: the name's first character
            ldx   #0
            sep   #$20
            mx    %10
:c          cpy   t0
            beq   :last
            bcs   :end
:last       lda   [pathp],y
            sta   NameBuf+1,x
            iny
            inx
            cpx   #63
            bcc   :c
:end        txa
            sta   NameBuf
            rep   #$20
            mx    %00
            lda   #NameBuf
            ldy   #xName
            sta   [xp],y
            lda   #^NameBuf
            iny
            iny
            sta   [xp],y
            rts

* FreeReply: the dialog's name and path handles disposed of.
FreeReply   ldx   #Reply+10
            jsr   FreeAt
            ldx   #Reply+16
            jmp   FreeAt

* FreeAt: the handle at X (this bank), if any, disposed of and cleared.
FreeAt      lda   |2,x
            ora   |0,x
            beq   :none
            lda   |2,x
            pha
            lda   |0,x
            pha
            stz   |0,x
            stz   |2,x
            Tool  _DisposeHandle
:none       rts

* LockAt: the handle at offset Y of the data record (p1) locked; its
* pointer in A (low) and X (high), or 0 for none.
LockAt      lda   [p1],y
            sta   u0
            iny
            iny
            lda   [p1],y
            sta   u1
            ora   u0
            bne   :lock
            tax
            rts
:lock       pei   u1
            pei   u0
            Tool  _HLock
            lda   u0
            sta   p0
            lda   u1
            sta   p0+2
            ldy   #2
            lda   [p0],y
            tax
            lda   [p0]
            rts

* SizeAt: the size of the handle at offset Y of the data record (p1), at
* most 65535.
SizeAt      pha
            pha
            iny
            iny
            lda   [p1],y
            pha
            dey
            dey
            lda   [p1],y
            pha
            Tool  _GetHandleSize
            pla
            plx
            beq   :out
            lda   #$FFFF
:out        rts

* DropAt: the handle at offset Y of the data record (p1) disposed of, and
* the field cleared.
DropAt      lda   [p1],y
            sta   u0
            iny
            iny
            lda   [p1],y
            sta   u1
            lda   #0
            sta   [p1],y
            dey
            dey
            sta   [p1],y
            lda   u0
            ora   u1
            beq   :none
            pei   u1
            pei   u0
            Tool  _DisposeHandle
:none       rts

* NewBuf: a locked block of n0 bytes not crossing a bank.
*   out: carry clear, n1 = handle, p0 = pointer; or carry set, A = error
NewBuf      pha
            pha
            PushLongAt n0
            lda   uid
            pha
            pea   attrBuffer
            PushLong 0
            Tool  _NewHandle
            tax
            pla
            sta   n1
            pla
            sta   n1+2
            txa
            bcs   :err
            ldy   #2
            lda   [n1],y
            tax
            lda   [n1]
            sta   p0
            stx   p0+2
            clc
:err        rts

* OpenNote, CloseNote: the "Loading Babelfish..." note (SuperConvert's
* rWindParam1 1), up while Babelfish starts.
OpenNote    pha
            pha
            PushLong 0                  ; title, refCon, content, frame
            PushLong 0
            PushLong 0
            PushLong 0
            pea   0                     ; the template by pointer
            PushLong NoteParms
            pea   $800E
            Tool  _NewWindow2
            pla
            sta   NoteWin
            pla
            sta   NoteWin+2
            pha
            pha
            Tool  _GetPort
            PushLongAt NoteWin
            Tool  _SetPort
            PushLongAt NoteWin
            Tool  _DrawControls
            Tool  _SetPort              ; (the port before)
            rts
CloseNote   PushLongAt NoteWin
            Tool  _CloseWindow
            rts

*-------------------------------------------------------------
* Data
*-------------------------------------------------------------
BFName      str   'Seven Hills~Babelfish~'
Started     dw    0
Asked       dw    0                     ; BabelAsk chose a file
Quiet       dw    0
Again       dw    0
KeptTrans   dw    0                     ; (the last import's translator)
Kind        dw    0
Got         dw    0                     ; (import: data came, a true
GotTrue     dw    0                     ;   colour image, its rows so far,
Row         dw    0                     ;   its height, Read's status)
THigh       dw    0
TDst        adrl  0
Done        dw    0
XferH       adrl  0
XferP       adrl  0
XSize       dw    0
BFUid       dw    0
NoteWin     adrl  0
Blk         ds    12                    ; a request's data in, and out
BOut        ds    8
Reply       ds    20                    ; SFReplyRec2
Custom      dw    3                     ; Export's custom record: prompt,
            adrl  TxPrompt              ; default button, the name offered
            adrl  0
            adrl  0
TxPrompt    str   'Export the graphic as:'
TrName      ds    64                    ; (the last translator's name)
LastKind    dw    0
LastReq     dw    0
ESize       dw    0
BestRank    dw    0
BestNum     dw    0
ListN       dw    0
List        ds    32
TName       ds    64                    ; (tests: the export's translator)
NameBuf     ds    64
PortSCB     dw    0                     ; (TakePM: the map's mode, row
RowB        dw    0                     ;   bytes, lines, pixels, bytes a
Lines       dw    0                     ;   row used, SCBs given, colour
Pix         dw    0                     ;   table bytes, 640 mode)
Bytes       dw    0
ScbOK       dw    0
PalLen      dw    0
M640        dw    0
LUT         ds    50                    ; (a line's 16 colours as RGB)
Loc         ds    16                    ; (export: LocInfo, data record)
DataRec     ds    30

NoteParms   dw    $50,$2028             ; alert frame, visible
            adrl  0,0
            dw    0,0,0,0
            adrl  0
            dw    0,0,0,0,0,0,0,0,0,0
            adrl  0
            dw    0
            adrl  0,0,0
            dw    97,220,112,417
            adrl  $FFFFFFFF
            adrl  NoteCtls
            dw    $0003
NoteCtls    adrl  NoteText,0
NoteText    dw    8
            adrl  1
            dw    3,2,13,194
            adrl  $81000000
            dw    0,$1000
            adrl  0
            adrl  TxNote
            dw    TxNoteEnd-TxNote
TxNote      asc   'Loading Babelfish...'
TxNoteEnd
