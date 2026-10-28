*-------------------------------------------------------------
* ZX.s - ZX Spectrum screens (part of the Other segment): 6912 bytes,
* the 256 x 192 bitmap in the Spectrum's order (by thirds of the screen,
* then the line within the cell, then the row of cells) and a colour
* attribute for each 8 x 8 cell (ink, paper, bright; flash left out); or
* 6144 bytes, the bitmap alone, black on white. It becomes a screen image
* of that size in the Spectrum's 15 colours.
*-------------------------------------------------------------

* LoadZX: out: carry clear, or carry set and A = error
LoadZX      lda   flen+2
            bne   :bad
            lda   flen
            cmp   #6912
            beq   :ok
            cmp   #6144
            beq   :ok
:bad        lda   #errNotPicture
            sec
            rts
:ok         jsr   ScrBegin
            ldx   #ZxPal
            jsr   SetTable0
            stz   Is640
            lda   #256
            sta   PixW
            stz   RowY
:row        lda   RowY                  ; the line's bitmap: (y & $C0) << 5,
            and   #$00C0                ; (y & 7) << 8, (y & $38) << 2
            asl
            asl
            asl
            asl
            asl
            sta   t1
            lda   RowY
            and   #$0007
            xba
            ora   t1
            sta   t1
            lda   RowY
            and   #$0038
            asl
            asl
            ora   t1
            sta   ZxLine
            lda   RowY                  ; its attributes: 6144 + (y >> 3) * 32
            and   #$00F8
            asl
            asl
            clc
            adc   #6144
            sta   ZxAttr
            stz   ZxCol
            ldx   #0                    ; (X: the pixel)
:cell       lda   #$0038                ; no attributes: ink 0 on paper 7
            ldy   flen
            cpy   #6912
            bne   :attr
            lda   ZxAttr
            clc
            adc   ZxCol
            tay
            lda   [fp],y
:attr       sta   t2
            and   #$0007                ; ink and paper (8 more if bright)
            sta   ZxInk
            lda   t2
            lsr
            lsr
            lsr
            and   #$0007
            sta   ZxPaper
            lda   t2
            and   #$0040
            beq   :norm
            lda   #8
            tsb   ZxInk
            tsb   ZxPaper
:norm       lda   ZxLine                ; its 8 pixels, highest bit first
            clc
            adc   ZxCol
            tay
            lda   [fp],y
            xba
            ldy   #8
:px         asl
            pha
            lda   ZxPaper
            bcc   :set
            lda   ZxInk
:set        sep   #$20
            mx    %10
            sta   RowPix,x
            rep   #$20
            mx    %00
            pla
            inx
            dey
            bne   :px
            inc   ZxCol
            lda   ZxCol
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

* The Spectrum's colours: black, blue, red, magenta, green, cyan, yellow,
* white, and the same bright.
ZxPal       dw    $000,$00D,$D00,$D0D,$0D0,$0DD,$DD0,$DDD
            dw    $000,$00F,$F00,$F0F,$0F0,$0FF,$FF0,$FFF

ZxLine      dw    0
ZxAttr      dw    0
ZxCol       dw    0
ZxInk       dw    0
ZxPaper     dw    0
