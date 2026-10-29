*-------------------------------------------------------------
* LoRes.s - Apple II LoRes and Double LoRes screens (part of the Other
* segment): the text page's 1024 bytes (Double LoRes: the auxiliary
* page's, then the main page's), each byte two blocks, the top one in
* its low 4 bits; 40 x 48 blocks (Double LoRes: 80 x 48, the columns by
* turns from auxiliary and main memory, the auxiliary ones' colour bits
* turned right by one: the video turns them left). Loaded as 280 x 192 in 320 mode, a block 7 x 4
* (Double LoRes: 3 or 4 across, column k from 7k / 2 on), in the LoRes
* colours.
*-------------------------------------------------------------

* LoadLoRes, LoadDLoRes: out: carry clear, or carry set and A = error
LoadLoRes   lda   #1016                 ; (the last 8 bytes are not shown)
            stz   LrDouble
            bra   LoRes
LoadDLoRes  lda   #1024+1016
            ldx   #1
            stx   LrDouble
LoRes       ldx   flen+2
            bne   :ok
            cmp   flen
            beq   :ok
            bcc   :ok
            lda   #errNotPicture
            sec
            rts
:ok         jsr   ScrBegin
            ldx   #LrPal
            jsr   SetTable0
            stz   Is640
            lda   #280
            sta   PixW
            stz   RowY
:row        lda   RowY                  ; the block row: y / 4; its text line
            lsr                         ; t = y / 8: (t & 7) * 128 + (t >> 3) * 40
            lsr
            lsr
            sta   t0
            and   #$0007
            xba
            lsr
            sta   t1
            lda   t0
            lsr
            lsr
            lsr
            sta   t0
            asl
            asl
            clc
            adc   t0
            asl
            asl
            asl
            clc
            adc   t1
            sta   LrOff
            stz   LrCol                 ; the blocks
            stz   LrEnd2
            ldx   #0                    ; (X: the pixel)
:block      lda   LrCol
            ldy   LrDouble
            beq   :single
            lsr                         ; Double LoRes: auxiliary or main
            bcc   :aux
            adc   #1024-1
:aux        clc
            adc   LrOff
            tay
            lda   [fp],y
            jsr   :half
            ldy   LrCol
            tya
            lsr
            bcs   :got
            lda   t2                    ; auxiliary: its bits turned left
            asl
            bit   #$0010
            beq   :r
            ora   #$0001
:r          and   #$000F
            sta   t2
            bra   :got
:single     clc
            adc   LrOff
            tay
            lda   [fp],y
            jsr   :half
:got        lda   LrEnd2                ; to pixel 7 (k + 1) / 2, or 7 (k + 1)
            clc
            adc   #7
            sta   LrEnd2
            ldy   LrDouble
            beq   :e1
            lsr
            bra   :e2
:e1         lda   LrEnd2
:e2         sta   t3
            sep   #$20
            mx    %10
            lda   t2
:put        sta   RowPix,x
            inx
            cpx   t3
            bcc   :put
            rep   #$20
            mx    %00
            inc   LrCol
            cpx   #280
            bcc   :block
            jsr   PackRow
            inc   RowY
            lda   RowY
            cmp   #192
            bcs   :done
            jmp   :row
:done       lda   #fmtLoRes
            ldy   LrDouble
            beq   :fmt
            lda   #fmtDLoRes
:fmt        clc
            rts
* :half: t2 = the block's colour in byte A: its low 4 bits in the top
* half of a text line (y & 4 = 0), else its high 4 bits.
:half       and   #$00FF
            sta   t2
            lda   RowY
            and   #$0004
            beq   :top
            lda   t2
            lsr
            lsr
            lsr
            lsr
            sta   t2
:top        lda   t2
            and   #$000F
            sta   t2
            rts

* The LoRes colours, by their numbers.
LrPal       dw    $000,$D03,$009,$D0D,$070,$555,$22F,$6AF
            dw    $852,$F60,$AAA,$F98,$0D0,$FF0,$0F9,$FFF
LrDouble    dw    0
LrOff       dw    0
LrCol       dw    0
LrEnd2      dw    0
