*-------------------------------------------------------------
* MonoSeg.s - monochrome images, as SuperConvert's (a segment of its
* own; docs/superconvert-truecolor.md sections 7-9)
*
* A monochrome image has one bit a pixel, bit 7 leftmost, 1 white,
* rows of (width + 7) / 8 bytes. Main keeps it (MonoBlk; mblk on the
* direct page points there): its handle, pointer, size, row length.
*
* In: scrp, pw, ph, p640 (the screen image), tp, tstride, rw, rh (the
* true colour image), uid, mblk.
*-------------------------------------------------------------
            rel
            mx    %00
            use   macros/Macs.s
            put   Equates.s

NewTrueL    ext

mo0         =     $D0                   ; work pointers (long)
mo1         =     $D4
mo2         =     $D8
mq0         =     $DC                   ; work words
mq1         =     $DE
mq2         =     $E0
mq3         =     $E2
mq4         =     $E4
mq5         =     $E6
mq6         =     $E8
mq7         =     $EA

* The block Main keeps (mblk points at it)
mbHave      =     0                     ; a monochrome image is there
mbHnd       =     2                     ; its handle (long)
mbPtr       =     6                     ; its pointer (long)
mbW         =     10
mbH         =     12
mbStr       =     14                    ; bytes a row

*-------------------------------------------------------------
* To monochrome
*-------------------------------------------------------------

* MonoMake: a new monochrome image from the screen image (A = 0) or the
* true colour image (A = 2), X times wider and Y times taller (1, 2 or
* 4), rendered with method MkMethod (1 error diffusion, 2 pattern dither,
* 3 50% threshold, 4 halftone; set by MonoMethod).
*   out: carry clear, or carry set and A = error
MonoMake    ent
            phb
            phk
            plb
            jsr   MakeCore
            plb
            rtl
MakeCore    sta   Src
            stx   ScaleH
            sty   ScaleV
            jsr   SrcSize               ; SrcW, SrcH: the source's pixels
            lda   SrcW
            asl
            sta   SrcW2
            lda   SrcW                  ; the result's size (at most 5000)
            ldx   ScaleH
            jsr   Times
            jsr   Cap5000
            sta   OutW
            lda   SrcH
            ldx   ScaleV
            jsr   Times
            jsr   Cap5000
            sta   OutH
            jsr   NewMono               ; mo1: the new image
            bcc   :ok
            rts
:ok         lda   Src
            beq   :grey
            jsr   IsGrey                ; a true colour image all of greys?
:grey       lda   #$FFFF
            sta   LumY                  ; (no source row ready yet)
            ldx   #0                    ; the error buffers cleared
:clr        stz   ErrA,x
            stz   ErrB,x
            inx
            inx
            cpx   #ErrLen
            bcc   :clr
            lda   #ErrA
            sta   ErrCur
            lda   #ErrB
            sta   ErrNext
            stz   OutY
:row        lda   OutY                  ; the source row: y / V
            ldx   ScaleV
            jsr   Over
            cmp   LumY
            beq   :have
            sta   LumY
            jsr   LumRow                ; Lum: its pixels' intensities
:have       jsr   OutRow
            lda   mo1                   ; the next output row
            clc
            adc   OutStr
            sta   mo1
            bcc   :same
            inc   mo1+2
:same       inc   OutY
            lda   OutY
            cmp   OutH
            bcc   :row
            jsr   Keep                  ; the image becomes Main's
            clc
            rts

* MonoMethod: the rendering method for MonoMake (A).
MonoMethod  ent
            phb
            phk
            plb
            sta   MkMethod
            plb
            rtl

* SrcSize: SrcW, SrcH: the source's size in pixels.
SrcSize     lda   Src
            bne   :true
            lda   pw
            sta   SrcW
            lda   ph
            sta   SrcH
            rts
:true       lda   rw
            sta   SrcW
            lda   rh
            sta   SrcH
            rts

* OutRow: output row OutY into mo1: each pixel's intensity Lum[x / H],
* rendered.
OutRow      stz   OutX
            stz   Byte
            lda   #$80
            sta   Mask
            stz   OSrcX                 ; (x / H stepped: the source column,
            stz   OPh                   ; and x mod H)
            ldy   #0                    ; the output byte
:pix        lda   OSrcX
            asl
            tax
            inc   OPh
            lda   OPh
            cmp   ScaleH
            bcc   :step
            stz   OPh
            inc   OSrcX
:step       lda   Lum,x
            jsr   Render                ; carry set: white
            bcc   :black
            lda   Mask
            tsb   Byte
:black      lsr   Mask
            bne   :next
            jsr   PutByte
:next       inc   OutX
            lda   OutX
            cmp   OutW
            bcc   :pix
            lda   Mask                  ; a part byte at the end
            cmp   #$80
            beq   :end
            jsr   PutByte
:end        lda   MkMethod              ; error diffusion: the next row's errors
            cmp   #1
            bne   :done
            lda   ErrCur
            ldx   ErrNext
            stx   ErrCur
            sta   ErrNext
            tax                         ; (cleared for the row after, as far
            lda   OutW                  ; as Diffuse reaches: 2 x width + 10
            asl                         ; bytes)
            clc
            adc   #10
            sta   ErrUse
            ldy   #0
:clr        stz   |0,x
            inx
            inx
            iny
            iny
            cpy   ErrUse
            bcc   :clr
:done       rts
PutByte     lda   Byte
            sep   #$20
            mx    %10
            sta   [mo1],y
            rep   #$20
            mx    %00
            iny
            stz   Byte
            lda   #$80
            sta   Mask
            rts

* Render: intensity A (0-255) at OutX, OutY.   out: carry set for white
Render      sta   mq0
            lda   MkMethod
            cmp   #3
            beq   :thresh
            cmp   #2
            beq   :pattern
            cmp   #4
            beq   :half
            jmp   Diffuse
:thresh     lda   mq0
            cmp   #128
            rts
:pattern    jsr   Cell
            lda   PD,x
            bra   :cmp
:half       jsr   Cell
            lda   HT,x
:cmp        and   #$00FF
            sta   mq1
            lda   mq0
            cmp   mq1
            rts
Cell        lda   OutY                  ; X = (y & 7) x 8 + (x & 7)
            and   #7
            asl
            asl
            asl
            sta   mq1
            lda   OutX
            and   #7
            ora   mq1
            tax
            rts

* Diffuse: SuperConvert's error diffusion (errors kept to whole pixels
* within 0-255; a quarter, an eighth and a sixteenth passed on).
Diffuse     lda   OutX
            asl
            clc
            adc   ErrCur
            tax
            lda   |4,x                  ; (the buffers start two pixels early)
            clc
            adc   mq0
            bmi   :black0
            cmp   #256
            bcs   :white0
            cmp   #128
            bcs   :white
            sta   mq1                   ; black: the error is v
            clc
            bra   :pass
:white      sbc   #255                  ; (carry set) white: v - 255
            sta   mq1
            sec
            bra   :pass
:black0     stz   mq1
            clc
            bra   :pass
:white0     stz   mq1
            sec
:pass       php
            lda   mq1                   ; e4, e8, e16 (shifts that keep the sign)
            cmp   #$8000
            ror
            cmp   #$8000
            ror
            sta   mq2                   ; e4
            cmp   #$8000
            ror
            sta   mq3                   ; e8
            cmp   #$8000
            ror
            sta   mq4                   ; e16
            lda   OutX
            asl
            sta   mq5
            clc
            adc   ErrCur
            tax
            lda   |6,x                  ; this row: x+1 a quarter, x+2 an eighth
            clc
            adc   mq2
            sta   |6,x
            lda   |8,x
            clc
            adc   mq3
            sta   |8,x
            lda   mq5                   ; the next row: x-2 .. x+2
            clc
            adc   ErrNext
            tax
            lda   |0,x
            clc
            adc   mq4
            sta   |0,x
            lda   |2,x
            clc
            adc   mq3
            sta   |2,x
            lda   |4,x
            clc
            adc   mq2
            sta   |4,x
            lda   |6,x
            clc
            adc   mq3
            sta   |6,x
            lda   |8,x
            clc
            adc   mq4
            sta   |8,x
            plp
            rts

* LumRow: Lum = the intensities of source row LumY.
LumRow      lda   Src
            bne   :true
            jmp   ScrLum
:true       lda   LumY                  ; mo0: the row
            ldx   tstride
            jsr   Mul16
            lda   tp
            clc
            adc   MLo
            sta   mo0
            lda   tp+2
            adc   MHi
            sta   mo0+2
            ldx   #0
            ldy   #0
:pix        lda   GreyImg
            beq   :colour
            lda   [mo0],y               ; a grey image: GREY[g]
            and   #$00FF
            asl
            phx
            tax
            lda   GreyTab,x
            plx
            bra   :put
:colour     lda   [mo0],y               ; R, by its top 5 bits
            and   #$00F8
            lsr
            lsr
            phx
            tax
            lda   RT5,x
            plx
            sta   mq0
            iny
            lda   [mo0],y               ; G
            and   #$00F8
            lsr
            lsr
            phx
            tax
            lda   GT5,x
            plx
            clc
            adc   mq0
            sta   mq0
            iny
            lda   [mo0],y               ; B
            and   #$00F8
            lsr
            lsr
            phx
            tax
            lda   BT5,x
            plx
            clc
            adc   mq0
            dey
            dey
:put        sta   Lum,x
            iny
            iny
            iny
            inx
            inx
            cpx   SrcW2
            bcc   :pix
            rts

* ScrLum: Lum = the intensities of screen row LumY: its colour table's
* colours (by its SCB); 640 mode pixel k of a byte (0: bits 7-6) uses
* entry 4k + its value.
ScrLum      lda   LumY
            clc
            adc   #scbOffset
            tay
            lda   [scrp],y
            and   #$000F
            xba
            lsr
            lsr
            lsr                         ; x 32
            clc
            adc   #palOffset
            sta   mq6                   ; the table's offset
            ldx   #0                    ; the table's 16 intensities
:pal        txa
            clc
            adc   mq6
            tay
            lda   [scrp],y
            jsr   Lum4
            sta   PalLum,x
            inx
            inx
            cpx   #32
            bcc   :pal
            lda   LumY                  ; mo0: the row
            jsr   Times160
            sta   mq6
            ldx   #0                    ; the pixel (x 2)
:pix        txa
            lsr
            ldy   p640
            bne   :p640
            lsr                         ; 320: two pixels a byte
            clc
            adc   mq6
            tay
            lda   [scrp],y
            and   #$00FF
            sta   mq0
            txa
            and   #2                    ; the second pixel: the low nibble
            bne   :low
            lda   mq0
            lsr
            lsr
            lsr
            lsr
            bra   :v
:low        lda   mq0
            and   #$000F
:v          asl
            tay
            lda   PalLum,y
            bra   :put
:p640       lsr                         ; 640: four pixels a byte
            lsr
            clc
            adc   mq6
            tay
            lda   [scrp],y
            and   #$00FF
            sta   mq0
            txa
            lsr
            and   #3                    ; k
            sta   mq1
            asl                         ; shift the byte left 2k
            tay
            lda   mq0
:sh         cpy   #0
            beq   :top
            asl
            dey
            bra   :sh
:top        and   #$00C0                ; value, then entry 4k + value
            lsr
            lsr
            lsr
            lsr
            lsr
            lsr
            sta   mq0
            lda   mq1
            asl
            asl
            clc
            adc   mq0
            asl
            tay
            lda   PalLum,y
:put        sta   Lum,x
            inx
            inx
            cpx   SrcW2
            bcc   :pix
            rts

* Lum4: A = the intensity of colour A ($0RGB): RT4[r] + GT4[g] + BT4[b].
Lum4        sta   mq0
            xba
            and   #$000F
            tay
            lda   RT4,y
            and   #$00FF
            sta   mq1
            lda   mq0
            lsr
            lsr
            lsr
            lsr
            and   #$000F
            tay
            lda   GT4,y
            and   #$00FF
            clc
            adc   mq1
            sta   mq1
            lda   mq0
            and   #$000F
            tay
            lda   BT4,y
            and   #$00FF
            clc
            adc   mq1
            rts

* IsGrey: GreyImg = 1 if every pixel of the true colour image is grey.
IsGrey      stz   GreyImg
            stz   mq6                   ; the row
:row        lda   mq6
            ldx   tstride
            jsr   Mul16
            lda   tp
            clc
            adc   MLo
            sta   mo0
            lda   tp+2
            adc   MHi
            sta   mo0+2
            ldy   #0
:pix        lda   [mo0],y               ; R = G?
            sta   mq0
            xba
            eor   mq0
            and   #$00FF
            bne   :no
            iny                         ; G = B?
            lda   [mo0],y
            sta   mq0
            xba
            eor   mq0
            and   #$00FF
            bne   :no
            iny
            iny
            cpy   tstride
            bcc   :pix
            inc   mq6
            lda   mq6
            cmp   rh
            bcc   :row
            inc   GreyImg
:no         rts

*-------------------------------------------------------------
* From monochrome
*-------------------------------------------------------------

* MonoOut: the monochrome image as a screen image (A = 0, into scrp:
* out pw, ph, p640) or a true colour image (A = 2, a new one: NewTrueL),
* with OutAspect (1 square, 2 tall, 3 wide), OutScale (1, 2, 4), Out640
* and OutShrink (1 grayscale, 2 B&W 50%, 3 line art on white, 4 on
* black), set with MonoOpts.   out: carry set and A = error
MonoOut     ent
            phb
            phk
            plb
            jsr   OutCore
            plb
            rtl
OutCore     sta   Dest
            jsr   Blocks                ; BW, BH, RX, RY, Weight; OutW, OutH
            lda   Dest
            bne   :true
            jmp   ToScreen
:true       jmp   ToTrue

* MonoOpts: aspect A, scaling X, 640 mode Y (bits 8-15: shrink).
MonoOpts    ent
            phb
            phk
            plb
            sta   OutAspect
            stx   OutScale
            tya
            and   #$00FF
            sta   Out640
            tya
            xba
            and   #$00FF
            sta   OutShrink
            plb
            rtl

* Blocks: the source block each output pixel comes from (BW across, BH
* rows), how often it repeats (RX across, RY down), a black pixel's
* weight (16 / (BW x BH)); OutW, OutH the result's size.
Blocks      lda   OutAspect             ; table row: (aspect - 1) x 3 + scale
            dec
            sta   mq0
            asl
            clc
            adc   mq0
            sta   mq0
            lda   OutScale
            lsr                         ; 1, 2, 4 -> 0, 1, 2
            cmp   #2
            bcc   :s
            lda   #2
:s          clc
            adc   mq0
            ldx   Out640
            beq   :m
            clc
            adc   #9
:m          asl
            asl
            asl                         ; 8 bytes a row
            tax
            lda   BlockTab,x
            sta   BW
            lda   BlockTab+2,x
            sta   BH
            lda   BlockTab+4,x
            sta   RX
            lda   BlockTab+6,x
            sta   RY
            lda   BW
            ldx   BH
            jsr   Times
            tax
            lda   #16
            jsr   Over
            sta   Weight
            ldy   #mbW                  ; out: ((w + bw - 1) / bw) x rx
            lda   [mblk],y
            clc
            adc   BW
            dec
            ldx   BW
            jsr   Over
            ldx   RX
            jsr   Times
            sta   OutW
            ldy   #mbH
            lda   [mblk],y
            clc
            adc   BH
            dec
            ldx   BH
            jsr   Over
            ldx   RY
            jsr   Times
            sta   OutH
            stz   Greys                 ; grey levels come out?
            lda   OutShrink
            cmp   #1
            bne   :g
            lda   Weight
            cmp   #16
            bcs   :g
            inc   Greys
:g          rts

* Value: A = 0 (white) .. 16 (black) for output pixel (OutX, OutY).
* The block's rows are worked out once for each OutY, and its first column
* stepped along when OutX goes up by one (VY = $FFFF: nothing kept).
Value       lda   OutY
            cmp   VY
            beq   :rowsOK
            sta   VY
            ldx   RY                    ; the block's first source row
            jsr   Over
            ldx   BH
            jsr   Times
            sta   mq4
            stz   VNR                   ; its rows' places (those inside)
            ldx   BH
            stx   mq3
:r          lda   mq4
            ldy   #mbH
            cmp   [mblk],y
            bcs   :rows
            jsr   MonoRow
            lda   VNR
            asl
            asl
            tax
            lda   mo0
            sta   VRP,x
            lda   mo0+2
            sta   VRP+2,x
            inc   VNR
            inc   mq4
            dec   mq3
            bne   :r
:rows       lda   #$FFFE                ; (no column kept for this row: not
            sta   VX                    ; OutX - 1 for any OutX)
:rowsOK     lda   OutX                  ; the block's first source column
            dec
            cmp   VX
            bne   :colNew
            inc   VX                    ; (the next pixel: stepped)
            inc   VPh
            lda   VPh
            cmp   RX
            bcc   :colOK
            stz   VPh
            lda   VC0
            clc
            adc   BW
            sta   VC0
            bra   :colOK
:colNew     lda   OutX
            sta   VX
            ldx   RX
            jsr   Over
            pha
            ldx   RX
            jsr   Times
            eor   #$FFFF
            sec
            adc   OutX
            sta   VPh                   ; (OutX mod RX)
            pla
            ldx   BW
            jsr   Times
            sta   VC0
:colOK      stz   mq6                   ; the value
            stz   VI
:sy         lda   VI
            cmp   VNR
            bcs   :done
            asl
            asl
            tax
            lda   VRP,x
            sta   mo0
            lda   VRP+2,x
            sta   mo0+2
            lda   VC0
            sta   mq2
            ldx   BW
            stx   mq7
:sx         lda   mq2
            ldy   #mbW
            cmp   [mblk],y
            bcs   :nextRow
            lsr
            lsr
            lsr
            tay
            lda   [mo0],y
            and   #$00FF
            sta   mq0
            lda   mq2
            and   #7
            tax
            lda   BitMask,x
            and   #$00FF
            and   mq0
            bne   :white
            lda   mq6
            clc
            adc   Weight
            sta   mq6
:white      inc   mq2
            dec   mq7
            bne   :sx
:nextRow    inc   VI
            bra   :sy
:done       lda   Weight                ; shrunk to black and white?
            cmp   #16
            bcs   :v
            lda   OutShrink
            cmp   #1
            beq   :v
            sec
            sbc   #2
            asl
            tax
            lda   mq6
            cmp   Thresh,x
            lda   #0
            bcc   :v2
            lda   #16
:v2         sta   mq6
:v          lda   mq6
            rts

* MonoRow: mo0 = the monochrome image's row A.
MonoRow     ldy   #mbStr
            pha
            lda   [mblk],y
            tax
            pla
            jsr   Mul16
            ldy   #mbPtr
            lda   [mblk],y
            clc
            adc   MLo
            sta   mo0
            ldy   #mbPtr+2
            lda   [mblk],y
            adc   MHi
            sta   mo0+2
            rts

* ToScreen: the values as screen pixels in scrp (one screen at most), its
* SCBs and colour table 0 as SuperConvert sets them.
ToScreen    ldy   #0                    ; cleared
            lda   #0
:clr        sta   [scrp],y
            iny
            iny
            cpy   #$8000
            bcc   :clr
            lda   OutW                  ; kept to one screen
            ldx   Out640
            bne   :w640
            cmp   #321
            bcc   :w
            lda   #320
            bra   :w
:w640       cmp   #641
            bcc   :w
            lda   #640
:w          sta   OutW
            lda   OutH
            cmp   #201
            bcc   :h
            lda   #200
:h          sta   OutH
            lda   #$FFFF                ; (Value: nothing kept)
            sta   VY
            stz   OutY
:row        lda   OutY
            jsr   Times160
            sta   RowOff                ; the row's offset
            stz   OutX
:pix        jsr   Value
            asl
            tax
            lda   Out640
            bne   :p640
            lda   Scr320,x              ; 320: a nibble
            sta   mq0
            lda   OutX
            lsr
            clc
            adc   RowOff
            tay
            lda   OutX
            and   #1
            bne   :lo
            lda   mq0
            asl
            asl
            asl
            asl
            bra   :or
:lo         lda   mq0
            bra   :or
:p640       lda   Scr640,x              ; 640: two bits
            sta   mq0
            lda   OutX
            lsr
            lsr
            clc
            adc   RowOff
            tay
            lda   OutX
            and   #3
            eor   #3                    ; shift left 2 x (3 - k)
            asl
            tax
            lda   mq0
:sh         cpx   #0
            beq   :or
            asl
            dex
            bra   :sh
:or         sep   #$20
            mx    %10
            ora   [scrp],y
            sta   [scrp],y
            rep   #$20
            mx    %00
            inc   OutX
            lda   OutX
            cmp   OutW
            bcc   :pix
            lda   OutY                  ; the line's SCB
            clc
            adc   #scbOffset
            tay
            lda   Out640
            beq   :s
            lda   #$80
:s          sep   #$20
            mx    %10
            sta   [scrp],y
            rep   #$20
            mx    %00
            inc   OutY
            lda   OutY
            cmp   OutH
            bcs   :jx1
            jmp   :row
:jx1
            lda   Out640                ; colour table 0
            asl
            ora   Greys
            asl
            tax
            lda   Pals,x
            tax
            ldy   #palOffset
:pal        lda   |0,x
            sta   [scrp],y
            inx
            inx
            iny
            iny
            cpy   #palOffset+32
            bcc   :pal
            lda   OutW                  ; the screen image's size
            sta   pw
            lda   OutH
            sta   ph
            lda   Out640
            sta   p640
            clc
            rts

* ToTrue: a new true colour image of greys (at most 2000 x 2000).
ToTrue      lda   OutW
            jsr   Cap2000
            sta   OutW
            lda   OutH
            jsr   Cap2000
            sta   OutH
            lda   Out640
            sta   ttall
            lda   OutW
            ldx   OutH
            jsl   NewTrueL              ; tp, tstride
            bcc   :ok
            rts
:ok         lda   #$FFFF                ; (Value: nothing kept)
            sta   VY
            stz   OutY
:row        lda   OutY
            ldx   tstride
            jsr   Mul16
            lda   tp
            clc
            adc   MLo
            sta   mo1
            lda   tp+2
            adc   MHi
            sta   mo1+2
            stz   OutX
            stz   OutI
:pix        jsr   Value
            tax
            lda   TrueGrey,x
            and   #$00FF
            sta   mq0
            xba
            ora   mq0
            ldy   OutI
            sta   [mo1],y               ; (R and G, then B)
            iny
            iny
            sep   #$20
            mx    %10
            sta   [mo1],y
            rep   #$20
            mx    %00
            iny
            sty   OutI
            inc   OutX
            lda   OutX
            cmp   OutW
            bcc   :pix
            inc   OutY
            lda   OutY
            cmp   OutH
            bcc   :row
            clc
            rts

*-------------------------------------------------------------
* Negative image, the white count
*-------------------------------------------------------------

* MonoNeg: every pixel the other way.
MonoNeg     ent
            phb
            phk
            plb
            stz   mq4
:row        lda   mq4
            jsr   MonoRow
            ldy   #mbStr
            lda   [mblk],y
            sta   mq5
            ldy   #0
            sep   #$20
            mx    %10
:b          lda   [mo0],y
            eor   #$FF
            sta   [mo0],y
            iny
            cpy   mq5
            bcc   :b
            rep   #$20
            mx    %00
            inc   mq4
            lda   mq4
            ldy   #mbH
            cmp   [mblk],y
            bcc   :row
            plb
            rtl

* MonoWhite: the white pixels counted (MonoCount, 32 bits).
MonoWhite   ent
            phb
            phk
            plb
            jsr   WhiteCore
            plb
            rtl
WhiteCore   stz   MonoCount
            stz   MonoCount+2
            stz   mq4
:row        lda   mq4
            jsr   MonoRow
            stz   OutX
:pix        lda   OutX
            lsr
            lsr
            lsr
            tay
            lda   [mo0],y
            and   #$00FF
            sta   mq0
            lda   OutX
            and   #7
            tax
            lda   BitMask,x
            and   mq0
            and   #$00FF
            beq   :black
            inc   MonoCount
            bne   :black
            inc   MonoCount+2
:black      inc   OutX
            lda   OutX
            ldy   #mbW
            cmp   [mblk],y
            bcc   :pix
            inc   mq4
            lda   mq4
            ldy   #mbH
            cmp   [mblk],y
            bcc   :row
            lda   MonoCount
            ldx   MonoCount+2
            rts

*-------------------------------------------------------------
* Helpers
*-------------------------------------------------------------

* NewMono: a new image OutW x OutH (mo1: its pointer, OutStr bytes a row).
NewMono     lda   OutW
            clc
            adc   #7
            lsr
            lsr
            lsr
            sta   OutStr
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
            pla
            sta   NewH
            pla
            sta   NewH+2
            bcc   :ok
            rts
:ok         lda   NewH
            sta   mo0
            lda   NewH+2
            sta   mo0+2
            lda   [mo0]
            sta   mo1
            sta   NewP
            ldy   #2
            lda   [mo0],y
            sta   mo1+2
            sta   NewP+2
            clc
            rts

* Keep: the new image becomes Main's (the old one freed).
Keep        ldy   #mbHave
            lda   [mblk],y
            beq   :none
            ldy   #mbHnd+2
            lda   [mblk],y
            pha
            ldy   #mbHnd
            lda   [mblk],y
            pha
            Tool  _DisposeHandle
:none       ldy   #mbHave
            lda   #1
            sta   [mblk],y
            ldy   #mbHnd
            lda   NewH
            sta   [mblk],y
            iny
            iny
            lda   NewH+2
            sta   [mblk],y
            ldy   #mbPtr
            lda   NewP
            sta   [mblk],y
            iny
            iny
            lda   NewP+2
            sta   [mblk],y
            ldy   #mbW
            lda   OutW
            sta   [mblk],y
            ldy   #mbH
            lda   OutH
            sta   [mblk],y
            ldy   #mbStr
            lda   OutStr
            sta   [mblk],y
            rts

* Times: A x X (small, 16 bits). Over: A / X.
Times       sta   mq0
            lda   #0
            cpx   #0
            beq   :done
:add        clc
            adc   mq0
            dex
            bne   :add
:done       rts
Over        sta   mq0                   ; (16 steps: dividend shifted into
            stx   mq1                   ; the remainder, the quotient in mq0)
            lda   #0
            ldx   #16
:bit        asl   mq0
            rol
            cmp   mq1
            bcc   :no
            sbc   mq1
            inc   mq0
:no         dex
            bne   :bit
            lda   mq0
            rts
Cap5000     cmp   #5001
            bcc   :ok
            lda   #5000
:ok         rts
Cap2000     cmp   #2001
            bcc   :ok
            lda   #2000
:ok         rts

* Times160: A x 160.
Times160    asl
            asl
            asl
            asl
            asl
            sta   mq7
            asl
            asl
            clc
            adc   mq7
            rts

* Mul16: MLo/MHi = A x X.
Mul16       sta   mq0
            stx   mq1
            stz   MLo
            stz   MHi
            stz   mq2
:bit        lda   mq1
            beq   :done
            lsr   mq1
            bcc   :shift
            clc
            lda   MLo
            adc   mq0
            sta   MLo
            lda   MHi
            adc   mq2
            sta   MHi
:shift      asl   mq0
            rol   mq2
            bra   :bit
:done       rts

*-------------------------------------------------------------
* Data
*-------------------------------------------------------------
OSrcX       dw    0                     ; (OutRow: x / H and x mod H)
OPh         dw    0
VY          dw    0                     ; (Value: the OutY and OutX kept, the
VX          dw    0                     ; block's rows inside the image and
VNR         dw    0                     ; their places, OutX mod RX, the
VRP         ds    64                    ; block's first column, the row
VPh         dw    0                     ; being summed)
VC0         dw    0
VI          dw    0
Src         dw    0
Dest        dw    0
ScaleH      dw    1
ScaleV      dw    1
MkMethod    dw    1
SrcW        dw    0
SrcH        dw    0
SrcW2       dw    0
OutW        dw    0
OutH        dw    0
OutX        dw    0
OutY        dw    0
OutStr      dw    0
OutI        dw    0
RowOff      dw    0
LumY        dw    0
GreyImg     dw    0
Byte        dw    0
Mask        dw    0
ErrCur      dw    0
ErrNext     dw    0
NewH        adrl  0
NewP        adrl  0
MLo         dw    0
MHi         dw    0
OutAspect   dw    1
OutScale    dw    1
Out640      dw    0
OutShrink   dw    1
BW          dw    1
BH          dw    1
RX          dw    1
RY          dw    1
Weight      dw    16
Greys       dw    0
MonoCount   adrl  0
PalLum      ds    32
BitMask     db    $80,$40,$20,$10,$08,$04,$02,$01
Thresh      dw    8,1,16                ; shrink 2, 3, 4
Scr320      dw    15,15,14,14,13,12,12,11,11,10,9,8,7,6,5,3,0
Scr640      dw    3,3,3,3,2,2,2,2,2,1,1,1,1,1,0,0,0
TrueGrey    db    255,247,239,230,221,211,202,191,180,169,156,143,128,110,90,64,0
* (BW, BH, RX, RY) by aspect (square, tall, wide), scaling (1:1, 1:2, 1:4),
* 320 then 640 mode.
BlockTab    dw    1,1,1,1, 2,2,1,1, 4,4,1,1
            dw    1,1,1,2, 2,1,1,1, 4,2,1,1
            dw    1,1,2,1, 1,2,1,1, 2,4,1,1
            dw    1,1,2,1, 1,2,1,1, 2,4,1,1
            dw    1,1,2,2, 1,1,1,1, 2,2,1,1
            dw    1,1,4,1, 1,2,2,1, 1,4,1,1
Pals        da    Pal320,Pal320G,Pal640,Pal640G
Pal320      dw    $000,$777,$841,$72C,$00F,$080,$F70,$D00,$FA9,$FF0,$0E0,$4DF,$DAF,$78F,$CCC,$FFF
Pal320G     dw    $000,$111,$222,$333,$444,$555,$666,$777,$888,$999,$AAA,$BBB,$CCC,$DDD,$EEE,$FFF
Pal640      dw    $000,$F00,$0F0,$FFF,$000,$00F,$FF0,$FFF,$000,$F00,$0F0,$FFF,$000,$00F,$FF0,$FFF
Pal640G     dw    $000,$777,$CCC,$FFF,$000,$777,$CCC,$FFF,$000,$777,$CCC,$FFF,$000,$777,$CCC,$FFF
RT4         db    0,0,1,2,4,7,10,14,19,25,31,39,47,56,66,77
GT4         db    0,1,2,4,8,13,20,28,38,49,62,76,92,110,129,150
BT4         db    0,0,0,1,2,3,4,5,7,9,11,14,17,20,24,28
RT5         dw    0,0,0,1,1,2,3,4,5,6,8,10,11,13,16,18,20,23,26,29,32,35,39,42,46,50,54,58,62,67,72,77
GT5         dw    0,0,1,1,3,4,6,8,10,13,16,19,23,26,31,35,40,45,51,57,63,69,76,83,90,98,106,114,123,132,141,150
BT5         dw    0,0,0,0,0,1,1,1,2,2,3,4,4,5,6,7,7,8,9,11,12,13,14,15,17,18,20,21,23,25,26,28
PD          db    2,130,34,162,10,138,42,170,226,66,194,98,234,74,202,106
            db    50,178,18,146,58,186,26,154,210,114,242,82,218,122,250,90
            db    14,142,46,174,6,134,38,166,238,78,206,110,230,70,198,102
            db    62,190,30,158,54,182,22,150,222,126,254,94,214,118,246,86
HT          db    250,234,170,58,6,70,182,246,218,186,122,10,50,30,142,202
            db    154,90,82,114,162,98,74,102,42,34,146,210,226,194,134,22
            db    2,66,178,242,254,238,174,62,54,26,138,206,222,190,126,14
            db    166,106,78,110,158,94,86,118,230,198,130,18,46,38,150,214
GreyTab     =     *                     ; round(g x g / 255)
            dw    0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1
            dw    1,1,1,1,2,2,2,2,2,2,3,3,3,3,4,4
            dw    4,4,5,5,5,5,6,6,6,7,7,7,8,8,8,9
            dw    9,9,10,10,11,11,11,12,12,13,13,14,14,15,15,16
            dw    16,17,17,18,18,19,19,20,20,21,21,22,23,23,24,24
            dw    25,26,26,27,28,28,29,30,30,31,32,32,33,34,35,35
            dw    36,37,38,38,39,40,41,42,42,43,44,45,46,47,47,48
            dw    49,50,51,52,53,54,55,56,56,57,58,59,60,61,62,63
            dw    64,65,66,67,68,69,70,71,73,74,75,76,77,78,79,80
            dw    81,82,84,85,86,87,88,89,91,92,93,94,95,97,98,99
            dw    100,102,103,104,105,107,108,109,111,112,113,115,116,117,119,120
            dw    121,123,124,126,127,128,130,131,133,134,136,137,139,140,142,143
            dw    145,146,148,149,151,152,154,155,157,158,160,162,163,165,166,168
            dw    170,171,173,175,176,178,180,181,183,185,186,188,190,192,193,195
            dw    197,199,200,202,204,206,207,209,211,213,215,217,218,220,222,224
            dw    226,228,230,232,233,235,237,239,241,243,245,247,249,251,253,255
Lum         ds    8192                  ; a source row's intensities (a word each)
ErrLen      =     10016                 ; (5000 + 8 words)
ErrUse      dw    0                     ; (OutRow: the bytes a row uses)
ErrA        ds    ErrLen
ErrB        ds    ErrLen

            put   MonoDlg.s
            put   True640.s
            put   MonoData.s
