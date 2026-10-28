*-------------------------------------------------------------
* Stream.s - reading a loaded file (or any buffer) byte by byte
*
* s0 (direct page) points at the next byte, InLeft counts the
* bytes left. Reading past the end gives zeros with carry set.
*-------------------------------------------------------------

* StreamAt: starts reading the file at offset n0 (long).
*   out: carry set if that is past the end
StreamAt    lda   FileLen
            sec
            sbc   n0
            sta   InLeft
            lda   FileLen+2
            sbc   n0+2
            sta   InLeft+2
            bcc   :past
            lda   FileP
            clc
            adc   n0
            sta   s0
            lda   FileP+2
            adc   n0+2
            sta   s0+2
            clc
            rts
:past       stz   InLeft
            stz   InLeft+2
            sec
            rts

* GetByte: the next byte in A; carry set (and A = 0) at the end.
GetByte     lda   InLeft
            bne   :have
            lda   InLeft+2
            beq   :end
            dec   InLeft+2
:have       dec   InLeft
            lda   [s0]
            and   #$00FF
            inc   s0
            bne   :ok
            inc   s0+2
:ok         clc
            rts
:end        lda   #0
            sec
            rts

* GetLE16 / GetBE16: a 16-bit number, low byte first or high byte first.
GetLE16     jsr   GetByte
            pha
            jsr   GetByte
            xba
            ora   1,s
            sta   1,s
            pla
            rts

GetBE16     jsr   GetByte
            xba
            pha
            jsr   GetByte
            ora   1,s
            sta   1,s
            pla
            rts

* GetLE32 / GetBE32: a 32-bit number in n1.
GetLE32     jsr   GetLE16
            sta   n1
            jsr   GetLE16
            sta   n1+2
            rts

GetBE32     jsr   GetBE16
            sta   n1+2
            jsr   GetBE16
            sta   n1
            rts

* SkipBytes: skips n0 (long) bytes.
SkipBytes   lda   InLeft
            sec
            sbc   n0
            tax
            lda   InLeft+2
            sbc   n0+2
            bcc   :all
            sta   InLeft+2
            stx   InLeft
            lda   s0
            clc
            adc   n0
            sta   s0
            lda   s0+2
            adc   n0+2
            sta   s0+2
            rts
:all        stz   InLeft
            stz   InLeft+2
            rts

* SkipA: skips A bytes.
SkipA       sta   n0
            stz   n0+2
            bra   SkipBytes

InLeft      adrl  0
