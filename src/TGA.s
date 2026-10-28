*-------------------------------------------------------------
* TGA.s - Truevision Targa pictures (part of the Other segment):
* colour-mapped, true colour and grey (types 1, 2 and 3), and the same
* run-length coded (9, 10 and 11); 8, 15, 16, 24 or 32 bits a pixel,
* colour maps of 15, 16, 24 or 32 bits an entry; the rows from the
* bottom or from the top, each from the left or from the right. The
* alpha channel is left out, as many files leave it 0.
*-------------------------------------------------------------

* LoadTGA: out: carry clear, or carry set and A = error
LoadTGA     lda   #0
            jsr   SAtA
            jsr   SByte                 ; the ID's length
            sta   TgIdLen
            jsr   SByte                 ; a colour map?
            sta   TgMap
            jsr   SByte                 ; the picture's type
            sta   TgType
            jsr   SLE16                 ; the colour map: first entry, how many,
            sta   TgFirst                ; bits an entry
            jsr   SLE16
            sta   TgCount
            jsr   SByte
            sta   TgCSize
            jsr   SLE16                 ; (the origin: not needed)
            jsr   SLE16
            jsr   SLE16                 ; width, height, bits a pixel, and
            sta   GW                    ; the order of the rows and columns
            jsr   SLE16
            sta   GH
            jsr   SByte
            sta   TgDepth
            jsr   SByte
            sta   TgDesc
            lda   GW
            beq   :bad
            lda   GH
            beq   :bad
            lda   TgMap
            cmp   #2
            bcs   :bad
            lda   TgType                 ; 1-3, or 9-11 (run-length coded)
            and   #$0008
            sta   TgRle
            lda   TgType
            and   #$FFF7
            sta   TgKind
            cmp   #1
            beq   :mapped
            cmp   #2
            beq   :true
            cmp   #3                    ; (another type: not a TGA)
            bne   :bad
            lda   TgDepth               ; gray: 8 bits
            cmp   #8
            bne   :unsup
            bra   :ok
:mapped     lda   TgMap                  ; colour-mapped: 8 bits, a map
            beq   :bad
            lda   TgDepth
            cmp   #8
            bne   :unsup
            bra   :ok
:true       lda   TgDepth                ; true colour: 15, 16, 24 or 32 bits
            cmp   #15
            beq   :ok
            cmp   #16
            beq   :ok
            cmp   #24
            beq   :ok
            cmp   #32
            beq   :ok
:unsup      lda   #errUnsupported
            sec
            rts
:bad        lda   #errNotPicture
            sec
            rts
:ok         ldx   TgIdLen                ; past the ID
            beq   :map
:id         jsr   SByte
            dex
            bne   :id
:map        lda   TgMap                  ; the colour map (read, or passed)
            beq   :make
            jsr   TgMapRead
            bcs   :unsup
:make       lda   GW
            ldx   GH
            stz   ttall
            jsr   MakeTrue
            bcc   :go
            rts
:go         stz   TgPLeft                 ; no run yet
            stz   RowY
:row        lda   TgDesc                 ; from the top, or from the bottom
            and   #$0020
            bne   :top
            lda   GH
            sec
            sbc   RowY
            dec
            bra   :at
:top        lda   RowY
:at         jsr   TrueRow
            lda   TgDesc                 ; each pixel left to right, or right to
            and   #$0010                ; left (from the last, Y back 6 after
            sta   TgBack                 ; each)
            ldy   #0
            lda   TgBack
            beq   :pixels
            lda   GW
            dec
            sta   t1
            asl
            clc
            adc   t1
            tay
:pixels     lda   GW
            sta   TgLeft
:pix        jsr   TgPix
            jsr   PutRGB
            lda   TgBack
            beq   :next
            dey
            dey
            dey
            dey
            dey
            dey
:next       dec   TgLeft
            bne   :pix
            inc   RowY
            lda   RowY
            cmp   GH
            bcc   :row
            clc
            rts

* TgMapRead: the colour map: TgCount entries of TgCSize bits, the first
* TgFirst, into TgPalR, TgPalG, TgPalB (those past 256 passed over).
*   out: carry set if its entries are of a size not read
TgMapRead   lda   TgCSize
            cmp   #15
            beq   :sz
            cmp   #16
            beq   :sz
            cmp   #24
            beq   :sz
            cmp   #32
            beq   :sz
            sec
            rts
:sz         ldx   #510                  ; entries not in the map: black
:z          stz   TgPalR,x
            stz   TgPalG,x
            stz   TgPalB,x
            dex
            dex
            bpl   :z
            lda   TgFirst
            sta   t2                    ; this entry's number
            lda   TgCount
            sta   t3
            beq   :done
:e          lda   TgCSize
            jsr   TgColour               ; CR, CG, CB
            lda   t2
            cmp   #256
            bcs   :skip
            asl
            tax
            lda   CR
            sta   TgPalR,x
            lda   CG
            sta   TgPalG,x
            lda   CB
            sta   TgPalB,x
:skip       inc   t2
            dec   t3
            bne   :e
:done       clc
            rts

* TgPix: the next pixel's colour (CR, CG, CB), through the runs if the
* picture is run-length coded (a run or a packet may go on to the next
* row). Keeps Y.
TgPix       lda   TgRle
            beq   TgRead
            lda   TgPLeft
            bne   :more
            jsr   SByte                 ; a packet: how many, and a run of
            pha                         ; one colour or that many colours
            and   #$007F
            inc
            sta   TgPLeft
            pla
            and   #$0080
            sta   TgPRun
            beq   :more
            jsr   TgRead                 ; (the run's colour)
            lda   CR
            sta   TgRunR
            lda   CG
            sta   TgRunG
            lda   CB
            sta   TgRunB
:more       dec   TgPLeft
            lda   TgPRun
            beq   TgRead
            lda   TgRunR
            sta   CR
            lda   TgRunG
            sta   CG
            lda   TgRunB
            sta   CB
            rts

* TgRead: one pixel from the file: an index into the colour map, a grey,
* or a colour of TgDepth bits. Keeps Y.
TgRead      lda   TgKind
            cmp   #2
            bne   :byte
            lda   TgDepth
            bra   TgColour
:byte       jsr   SByte
            sta   CR
            ldx   TgKind
            cpx   #1
            bne   :grey
            asl                         ; a colour map entry (by its number;
            tax
            lda   TgPalR,x
            sta   CR
            lda   TgPalG,x
            sta   CG
            lda   TgPalB,x              ; those not in the map are black)
            sta   CB
            rts
:grey       sta   CG
            sta   CB
            rts

* TgColour: a colour of A bits (15, 16, 24 or 32) from the file into CR,
* CG, CB: 5 bits a channel widened to 8, or blue, green, red (and alpha,
* left out). Keeps Y.
TgColour    cmp   #24
            bcc   :five
            pha
            jsr   SByte
            sta   CB
            jsr   SByte
            sta   CG
            jsr   SByte
            sta   CR
            pla
            cmp   #32
            bne   :done
            jsr   SByte                 ; (alpha)
:done       rts
:five       jsr   SLE16                 ; x rrrrr ggggg bbbbb
            sta   t1
            and   #$001F
            jsr   :wide
            sta   CB
            lda   t1
            lsr
            lsr
            lsr
            lsr
            lsr
            and   #$001F
            jsr   :wide
            sta   CG
            lda   t1
            xba
            lsr
            lsr
            and   #$001F
            jsr   :wide
            sta   CR
            rts
:wide       sta   t0                    ; v << 3 | v >> 2
            asl
            asl
            asl
            sta   Tgt2w
            lda   t0
            lsr
            lsr
            ora   Tgt2w
            rts

TgIdLen     dw    0
TgMap       dw    0
TgType      dw    0
TgKind      dw    0
TgRle       dw    0
TgFirst     dw    0
TgCount     dw    0
TgCSize     dw    0
TgDepth     dw    0
TgDesc      dw    0
TgBack      dw    0
TgLeft      dw    0
TgPLeft     dw    0
TgPRun      dw    0
TgRunR      dw    0
TgRunG      dw    0
TgRunB      dw    0
Tgt2w       dw    0
TgPalR      ds    512
TgPalG      ds    512
TgPalB      ds    512
