*-------------------------------------------------------------
* MSX.s - MSX screens saved with BSAVE (part of the Other segment): a
* 7-byte header ($FE, the first and last video memory address, the start
* address), then that part of the video memory.
*   Screen 2 (MSX1): 256 x 192, 8 x 8 cells from a name table, each line
*   of a cell with its own two colours: a screen image.
*   Screen 5 and 7 (MSX2): 256 x 212 and 512 x 212, 16 colours from a
*   palette (the file's, or the MSX2's own): true colour pictures.
*   Screen 8 (MSX2): 256 x 212, 256 colours (3 bits green, 3 red, 2 blue).
* What the file leaves out of the video memory reads as 0.
*-------------------------------------------------------------

* LoadMS2: Screen 2. out: carry clear, or carry set and A = error
LoadMS2     jsr   MsHead
            bcc   :ok
            rts
:ok         jsr   ScrBegin
            ldx   #MsPal4
            jsr   SetTable0
            stz   Is640
            lda   #256
            sta   PixW
            stz   RowY
:row        lda   RowY                  ; the third of the screen x 2048
            and   #$00C0
            asl
            asl
            asl
            asl
            asl
            sta   MsThird
            lda   RowY                  ; the name table's row: $1800 + (y >> 3) * 32
            and   #$00F8
            asl
            asl
            clc
            adc   #$1800
            sta   MsName
            stz   MsCol
            ldx   #0                    ; (X: the pixel)
:cell       lda   MsName                ; the cell's pattern (left out: the
            clc                         ; usual names, 0-255 down each third)
            adc   MsCol
            jsr   MsAt
            bcc   :name
            lda   RowY
            and   #$0038
            asl
            asl
            clc
            adc   MsCol
:name       asl                         ; its line: third + name * 8 + (y & 7)
            asl
            asl
            clc
            adc   MsThird
            sta   t2
            lda   RowY
            and   #$0007
            clc
            adc   t2
            sta   t2
            jsr   MsAt                  ; the pattern's bits
            sta   MsBits
            lda   t2                    ; and its colours, from $2000 on
            clc
            adc   #$2000
            jsr   MsAt
            sta   t3
            and   #$000F
            sta   MsBg
            lda   t3
            lsr
            lsr
            lsr
            lsr
            sta   MsFg
            lda   MsBits
            xba
            ldy   #8
:px         asl
            pha
            lda   MsBg
            bcc   :set
            lda   MsFg
:set        sep   #$20
            mx    %10
            sta   RowPix,x
            rep   #$20
            mx    %00
            pla
            inx
            dey
            bne   :px
            inc   MsCol
            lda   MsCol
            cmp   #32
            bcc   :cell
            jsr   PackRow
            inc   RowY
            lda   RowY
            cmp   #192
            bcs   :done
            jmp   :row
:done       clc
            rts

* LoadMS5, LoadMS7: Screen 5 (256 x 212, 128 bytes a line, the palette at
* $7680) and Screen 7 (512 x 212, 256 bytes a line, the palette at $FA80;
* its pixels half as wide as they are tall); two pixels a byte, the high
* nibble first.
LoadMS5     lda   #256
            ldx   #$7680
            ldy   #0
            bra   MsNibbles
LoadMS7     lda   #512
            ldx   #$FA80
            ldy   #1
MsNibbles   sta   MsW
            stx   MsPalAt
            sty   MsTall
            jsr   MsHead
            bcc   :ok
            rts
:ok         jsr   MsPalette
            jsr   MsMake
            bcc   :rows
            rts
:rows       stz   RowY
:row        lda   RowY
            jsr   TrueRow
            lda   MsW                   ; the line's first byte: y x (w / 2)
            lsr
            tax
            lda   RowY
            jsr   Mul16
            lda   MLo
            sta   MsAddr
            stz   MsCol
            ldy   #0
:byte       lda   MsAddr
            jsr   MsAt
            sta   MsBits
            lsr
            lsr
            lsr
            lsr
            jsr   MsPut
            lda   MsBits
            and   #$000F
            jsr   MsPut
            inc   MsAddr
            inc   MsCol
            inc   MsCol
            lda   MsCol
            cmp   MsW
            bcc   :byte
            inc   RowY
            lda   RowY
            cmp   #212
            bcc   :row
            clc
            rts

* LoadMS8: Screen 8: 256 x 212, a byte a pixel, GGGRRRBB.
LoadMS8     lda   #256
            sta   MsW
            stz   MsTall
            jsr   MsHead
            bcc   :ok
            rts
:ok         jsr   MsMake
            bcc   :rows
            rts
:rows       stz   RowY
:row        lda   RowY
            jsr   TrueRow
            lda   RowY                  ; the line's first byte: y x 256
            xba
            sta   MsAddr
            ldy   #0
:px         lda   MsAddr
            jsr   MsAt
            sta   MsBits
            lsr                         ; green: the top 3 bits
            lsr
            lsr
            lsr
            lsr
            asl
            tax
            lda   Ms3to8,x
            sta   CG
            lda   MsBits                ; red: the next 3
            lsr
            lsr
            and   #$0007
            asl
            tax
            lda   Ms3to8,x
            sta   CR
            lda   MsBits                ; blue: the last 2
            and   #$0003
            asl
            tax
            lda   Ms2to8,x
            sta   CB
            jsr   PutRGB
            inc   MsAddr
            lda   MsAddr
            and   #$00FF
            bne   :px
            inc   RowY
            lda   RowY
            cmp   #212
            bcc   :row
            clc
            rts

* MsHead: the BSAVE header: carry clear and MsStart, MsLen (the bytes of
* video memory the file holds), or carry set and A = error.
MsHead      lda   flen+2
            bne   :long
            lda   flen
            cmp   #8
            bcc   :bad
:long       lda   [fp]
            and   #$00FF
            cmp   #$00FE
            bne   :bad
            ldy   #1
            lda   [fp],y
            sta   MsStart
            ldy   #3                    ; end - start + 1
            lda   [fp],y
            sec
            sbc   MsStart
            bcc   :bad
            inc
            bne   :len
            dec                         ; (all 64K: as much as a word holds)
:len        sta   MsLen
            lda   flen+2                ; no more than the file has
            bne   :ok
            lda   flen
            sec
            sbc   #7
            cmp   MsLen
            bcs   :ok
            sta   MsLen
:ok         clc
            rts
:bad        lda   #errNotPicture
            sec
            rts

* MsAt: the byte at video memory address A, from the file; 0 and carry set
* if the file doesn't hold it. Keeps X and Y.
MsAt        phy
            sec
            sbc   MsStart
            bcc   :no
            cmp   MsLen
            bcs   :no
            clc
            adc   #7
            tay
            lda   [fp],y
            and   #$00FF
            ply
            clc
            rts
:no         ply
            lda   #0
            sec
            rts

* MsPalette: the 16 colours (MsR, MsG, MsB, 8 bits): the file's palette
* at MsPalAt (each colour two bytes: 0RRR0BBB, 00000GGG), if it holds all
* of it, or the MSX2's own.
MsPalette   lda   MsPalAt
            clc
            adc   #31
            jsr   MsAt
            bcs   :own
            ldx   #0
:entry      phx
            txa                         ; (X: entry x 2)
            clc
            adc   MsPalAt
            jsr   MsAt
            plx
            sta   t2
            lsr
            lsr
            lsr
            lsr
            and   #$0007
            jsr   :wide
            sta   MsR,x
            lda   t2
            and   #$0007
            jsr   :wide
            sta   MsB,x
            phx
            txa
            inc
            clc
            adc   MsPalAt
            jsr   MsAt
            plx
            and   #$0007
            jsr   :wide
            sta   MsG,x
            inx
            inx
            cpx   #32
            bcc   :entry
            rts
:own        ldx   #30
:copy       lda   MsOwnR,x
            sta   MsR,x
            lda   MsOwnG,x
            sta   MsG,x
            lda   MsOwnB,x
            sta   MsB,x
            dex
            dex
            bpl   :copy
            rts
:wide       phx                         ; 3 bits to 8
            asl
            tax
            lda   Ms3to8,x
            plx
            rts

* MsMake: the true colour picture, MsW x 212 (pixels twice as tall as wide
* if MsTall).
MsMake      lda   MsTall
            sta   ttall
            lda   MsW
            sta   GW
            lda   #212
            sta   GH
            ldx   #212
            lda   MsW
            jmp   MakeTrue

* MsPut: colour A of the palette at Y (keeps Y on).
MsPut       asl
            tax
            lda   MsR,x
            sta   CR
            lda   MsG,x
            sta   CG
            lda   MsB,x
            sta   CB
            jmp   PutRGB

* The MSX2's own palette (3 bits each, as 8), and as Super Hi-Res colours
* for Screen 2.
MsOwnR      dw    0,0,36,109,36,73,182,73,255,255,219,219,36,219,182,255
MsOwnG      dw    0,0,219,255,36,109,36,219,36,109,219,219,146,73,182,255
MsOwnB      dw    0,0,36,109,255,255,36,255,36,109,36,146,36,182,182,255
MsPal4      dw    $000,$000,$2D2,$6F6,$22F,$46F,$B22,$4DF
            dw    $F22,$F66,$DD2,$DD9,$292,$D4B,$BBB,$FFF
Ms3to8      dw    0,36,73,109,146,182,219,255
Ms2to8      dw    0,85,170,255

MsStart     dw    0
MsLen       dw    0
MsThird     dw    0
MsName      dw    0
MsCol       dw    0
MsBits      dw    0
MsFg        dw    0
MsBg        dw    0
MsW         dw    0
MsTall      dw    0
MsPalAt     dw    0
MsAddr      dw    0
MsR         ds    32
MsG         ds    32
MsB         ds    32
