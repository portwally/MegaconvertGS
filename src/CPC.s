*-------------------------------------------------------------
* CPC.s - Amstrad CPC screens (part of the Other segment): the 16K of
* screen memory, with or without the 128-byte AMSDOS header in front
* (known by its checksum). Line y starts at (y & 7) x 2048 + (y >> 3) x
* 80, 80 bytes a line. The file doesn't say the mode, so each has its own
* entry: mode 0, 160 x 200 in 16 colours (its pixels twice as wide);
* mode 1, 320 x 200 in 4; mode 2, 640 x 200 in 2. Screen images in the
* CPC's colours as it starts up (the inks' default colours).
*-------------------------------------------------------------

LoadCPC0    lda   #0
            bra   CpcGo
LoadCPC1    lda   #1
            bra   CpcGo
LoadCPC2    lda   #2
CpcGo       sta   CpMode
            jsr   CpcBase
            bcc   :ok
            rts
:ok         jsr   ScrBegin
            stz   Is640
            lda   #320
            sta   PixW
            ldx   #CpPal0
            lda   CpMode
            beq   :pal
            ldx   #CpPal1
            cmp   #1
            beq   :pal
            ldx   #CpPal2               ; mode 2: 640 mode lines
            phx
            lda   #$80
            ldx   #200
            jsr   SetScbs
            plx
            lda   #1
            sta   Is640
            lda   #640
            sta   PixW
:pal        jsr   SetTable0
            stz   RowY
:row        lda   RowY                  ; the line: (y & 7) x 2048 + (y >> 3) x 80
            and   #$0007
            xba
            asl
            asl
            asl
            sta   t1
            lda   RowY
            lsr
            lsr
            lsr
            sta   t2                    ; x 80 = x 64 + x 16
            asl
            asl
            asl
            asl
            sta   t0
            asl
            asl
            clc
            adc   t0
            clc
            adc   t1
            clc
            adc   CpBase
            sta   CpAddr
            ldx   #0                    ; (X: the pixel)
            stz   CpCol
:byte       lda   CpAddr
            clc
            adc   CpCol
            tay
            lda   [fp],y
            and   #$00FF
            sta   t3
            lda   CpMode
            beq   :m0
            cmp   #1
            beq   :m1
            lda   t3                    ; mode 2: a bit a pixel
            xba
            ldy   #8
:b2         asl
            pha
            lda   #0
            rol
            jsr   CpPut
            pla
            dey
            bne   :b2
            bra   :next
:m1         ldy   #4                    ; mode 1: bit 7 - k and bit 3 - k
:b1         stz   t2
            lda   t3
            and   #$0080
            beq   :lo1
            inc   t2
:lo1        lda   t3
            and   #$0008
            beq   :put1
            lda   #2
            tsb   t2
:put1       asl   t3
            lda   t2
            jsr   CpPut
            dey
            bne   :b1
            bra   :next
:m0         jsr   CpMode0               ; mode 0: the left pixel, then the
            pha                         ; right (the same bits one along)
            jsr   CpPut
            pla
            jsr   CpPut
            asl   t3
            jsr   CpMode0
            pha
            jsr   CpPut
            pla
            jsr   CpPut
:next       inc   CpCol
            lda   CpCol
            cmp   #80
            bcs   :line
            jmp   :byte
:line       jsr   PackRow
            inc   RowY
            lda   RowY
            cmp   #200
            bcs   :done
            jmp   :row
:done       clc
            rts

* CpMode0: the mode 0 pixel in t3's bits 7, 3, 5 and 1 (lowest first).
CpMode0     stz   t2
            lda   t3
            and   #$0080
            beq   :b1
            lda   #1
            tsb   t2
:b1         lda   t3
            and   #$0008
            beq   :b2
            lda   #2
            tsb   t2
:b2         lda   t3
            and   #$0020
            beq   :b3
            lda   #4
            tsb   t2
:b3         lda   t3
            and   #$0002
            beq   :done
            lda   #8
            tsb   t2
:done       lda   t2
            rts

* CpPut: pixel A into RowPix at X; X on. Keeps Y.
CpPut       sep   #$20
            mx    %10
            sta   RowPix,x
            rep   #$20
            mx    %00
            inx
            rts

* CpcBase: CpBase = 128 if the file starts with an AMSDOS header (the sum
* of its first 67 bytes in bytes 67-68), else 0; carry set and A = error
* if the file is too short for the screen's lines.
CpcBase     stz   CpBase
            lda   flen+2
            bne   :head
            lda   flen
            cmp   #16336+128
            bcc   :size
:head       stz   t1
            ldy   #0
:sum        lda   [fp],y
            and   #$00FF
            clc
            adc   t1
            sta   t1
            iny
            cpy   #67
            bcc   :sum
            ldy   #67
            lda   [fp],y
            cmp   t1
            bne   :size
            lda   #128
            sta   CpBase
:size       lda   flen+2                ; the last line ends at 16336
            bne   :ok
            lda   CpBase
            clc
            adc   #16336
            cmp   flen
            beq   :ok
            bcc   :ok
            lda   #errNotPicture
            sec
            rts
:ok         clc
            rts

* The inks' colours as the CPC starts up (its colour n: 9 x green + 3 x
* red + blue, each 0, half or full): mode 0's 16, mode 1's 4, mode 2's 2
* (in 640 mode, the same 4 for each pixel of a group).
CpPal0      dw    $008,$FF0,$0FF,$F00,$FFF,$000,$00F,$F0F
            dw    $088,$880,$88F,$F88,$0F0,$8F8,$008,$F88
CpPal1      dw    $008,$FF0,$0FF,$F00,$000,$000,$000,$000
            dw    $000,$000,$000,$000,$000,$000,$000,$000
CpPal2      dw    $008,$FF0,$008,$FF0,$008,$FF0,$008,$FF0
            dw    $008,$FF0,$008,$FF0,$008,$FF0,$008,$FF0

CpMode      dw    0
CpBase      dw    0
CpAddr      dw    0
CpCol       dw    0
