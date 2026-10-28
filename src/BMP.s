*-------------------------------------------------------------
* BMP.s - Windows and OS/2 bitmaps (.BMP)
*
* 1, 4, 8, 16, 24 and 32 bits per pixel, uncompressed (or with
* bit fields for 16 and 32 bits), bottom-up or top-down rows.
*-------------------------------------------------------------

DecodeBMP   lda   #10
            sta   n0
            stz   n0+2
            jsr   StreamAt
            jsr   GetLE32               ; where the pixels start
            lda   n1
            sta   DataOff
            lda   n1+2
            sta   DataOff+2
            jsr   GetLE32               ; header size
            lda   n1
            sta   HdrSize
            stz   TopDown
            stz   Comp
            stz   ClrUsed
            stz   RMask
            lda   HdrSize
            cmp   #12
            bne   :info
            jsr   GetLE16               ; OS/2 1.x header
            sta   TrueW
            jsr   GetLE16
            sta   TrueH
            jsr   GetLE16
            jsr   GetLE16
            sta   Bpp
            lda   #3
            sta   PalStep
            bra   :palette
:info       cmp   #40
            bcs   :infoOK
            jmp   :bad
:infoOK     jsr   GetLE32
            lda   n1+2
            beq   :wOK
            jmp   :big
:wOK        lda   n1
            sta   TrueW
            jsr   GetLE32
            lda   n1+2
            beq   :up
            cmp   #$FFFF
            beq   :down
            jmp   :big
:down       inc   TopDown               ; negative height: rows go top down
            lda   #0
            sec
            sbc   n1
            sta   n1
:up         lda   n1
            sta   TrueH
            jsr   GetLE16               ; planes
            jsr   GetLE16
            sta   Bpp
            jsr   GetLE32
            lda   n1
            sta   Comp
            lda   #12                   ; image size, resolution
            jsr   SkipA
            jsr   GetLE32
            lda   n1
            sta   ClrUsed
            lda   #4
            sta   PalStep
            lda   Comp
            cmp   #3
            bne   :palette
            lda   #54                   ; bit fields: the red mask
            sta   n0
            stz   n0+2
            jsr   StreamAt
            jsr   GetLE32
            lda   n1
            sta   RMask

:palette    jsr   ClearPal
            lda   ClrUsed
            bne   :count
            lda   Bpp
            cmp   #9
            bcs   :noPal
            tax
            lda   #1
:pow        asl
            dex
            bne   :pow
:count      cmp   #257
            bcc   :countOK
            lda   #256
:countOK    sta   u1
            lda   HdrSize
            clc
            adc   #14
            sta   n0
            stz   n0+2
            jsr   StreamAt
            ldx   #0
:entry      phx
            jsr   GetByte               ; blue, green, red
            sta   CB
            jsr   GetByte
            sta   CG
            jsr   GetByte
            plx
            sep   #$20
            mx    %10
            sta   Pal,x
            lda   CG
            sta   Pal+1,x
            lda   CB
            sta   Pal+2,x
            rep   #$20
            mx    %00
            lda   PalStep
            cmp   #4
            bne   :three
            phx
            jsr   GetByte
            plx
:three      inx
            inx
            inx
            dec   u1
            bne   :entry

:noPal      lda   Comp                  ; what can be read
            beq   :compOK
            cmp   #3
            bne   :unsup
            lda   Bpp
            cmp   #16
            beq   :compOK
            cmp   #32
            bne   :unsup
:compOK     lda   Bpp
            ldx   #10
:findBpp    cmp   BppList,x
            beq   :bppOK
            dex
            dex
            bpl   :findBpp
:unsup      lda   #errUnsupported
            sec
            rts
:bppOK      lda   BppRows,x
            sta   RowConv
            lda   TrueW                 ; row size: bits rounded up to 4 bytes
            ldx   Bpp
            jsr   Mul16
            lda   ProdLo
            clc
            adc   #31
            sta   RowSize
            lda   ProdHi
            adc   #0
            ldx   #5
:sh         lsr
            ror   RowSize
            dex
            bne   :sh
            asl   RowSize
            asl   RowSize
            jsr   NewTrue
            bcc   :rows
            rts
:rows       lda   DataOff
            sta   RowOff
            lda   DataOff+2
            sta   RowOff+2
            stz   RowR
:row        lda   RowOff
            sta   n0
            lda   RowOff+2
            sta   n0+2
            jsr   StreamAt
            lda   RowR
            ldx   TopDown
            bne   :y
            lda   TrueH                 ; bottom up
            sec
            sbc   RowR
            dec
:y          jsr   TrueRowAt
            ldy   #0
            ldx   RowConv
            jsr   (BmpConv,x)
            lda   RowOff
            clc
            adc   RowSize
            sta   RowOff
            bcc   :next
            inc   RowOff+2
:next       inc   RowR
            lda   RowR
            cmp   TrueH
            bcc   :row
            clc
            rts
:bad        lda   #errCorrupt
            sec
            rts
:big        lda   #errTooBig
            sec
            rts

BmpConv     da    BmpIdx,BmpIdx,BmpIdx,Bmp16,Bmp24,Bmp32

* Indexed rows: 1, 4 or 8 bits per pixel, leftmost pixel in the high bits.
BmpIdx      lda   TrueW
            sta   u1                    ; pixels left in the row
:byte       jsr   GetByte
            sta   u2
            lda   #8                    ; bits left in the byte
            sta   u0
:pix        lda   u2                    ; shift the top Bpp bits up past bit 7
            ldx   Bpp
:shift      asl
            dex
            bne   :shift
            sta   t2
            xba                         ; they are the pixel
            and   #$00FF
            pha
            lda   t2
            and   #$00FF
            sta   u2
            pla
            jsr   PutIdx
            dec   u1
            beq   :done
            lda   u0
            sec
            sbc   Bpp
            sta   u0
            bne   :pix
            bra   :byte
:done       rts

Bmp24       ldx   TrueW
:pix        phx
            jsr   GetByte
            sta   CB
            jsr   GetByte
            sta   CG
            jsr   GetByte
            sta   CR
            jsr   PutRGB
            plx
            dex
            bne   :pix
            rts

Bmp32       ldx   TrueW
:pix        phx
            jsr   GetByte
            sta   CB
            jsr   GetByte
            sta   CG
            jsr   GetByte
            sta   CR
            jsr   GetByte
            jsr   PutRGB
            plx
            dex
            bne   :pix
            rts

Bmp16       ldx   TrueW
:pix        phx
            jsr   GetLE16
            sta   u2
            and   #$001F                ; blue: 5 bits
            jsr   Expand5
            sta   CB
            lda   RMask
            cmp   #$F800
            beq   :565
            lda   u2                    ; 5-5-5
            lsr
            lsr
            lsr
            lsr
            lsr
            and   #$001F
            jsr   Expand5
            sta   CG
            lda   u2
            xba
            lsr
            lsr
            and   #$001F
            jsr   Expand5
            sta   CR
            bra   :put
:565        lda   u2
            lsr
            lsr
            lsr
            lsr
            lsr
            and   #$003F
            sta   u3
            asl
            asl
            sta   CG
            lda   u3
            lsr
            lsr
            lsr
            lsr
            ora   CG
            sta   CG
            lda   u2
            xba
            lsr
            lsr
            lsr
            and   #$001F
            jsr   Expand5
            sta   CR
:put        jsr   PutRGB
            plx
            dex
            bne   :pix
            rts

* Expand5: a 5-bit value to 8 bits.
Expand5     sta   u3
            asl
            asl
            asl
            sta   t1
            lda   u3
            lsr
            lsr
            ora   t1
            rts

* PutRGB: stores CR, CG, CB at [q0],y; y += 3.
PutRGB      sep   #$20
            mx    %10
            lda   CR
            sta   [q0],y
            iny
            lda   CG
            sta   [q0],y
            iny
            lda   CB
            sta   [q0],y
            iny
            rep   #$20
            mx    %00
            rts

BppList     dw    1,4,8,16,24,32
BppRows     dw    0,2,4,6,8,10

DataOff     adrl  0
RowOff      adrl  0
HdrSize     dw    0
TopDown     dw    0
Comp        dw    0
ClrUsed     dw    0
RMask       dw    0
Bpp         dw    0
PalStep     dw    0
RowSize     dw    0
RowConv     dw    0
RowR        dw    0
