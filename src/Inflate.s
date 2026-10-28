*-------------------------------------------------------------
* Inflate.s - Deflate decompression (RFC 1951), as used by PNG
*
* Reads from the stream (s0, InLeft), writes to q0 until OutLeft
* bytes are written or the last block ends. The output so far is
* the history that back-references copy from, so no window is
* kept: the whole result stays in memory.
* Huffman codes are decoded a bit at a time from per-length code
* counts, the canonical way.
*-------------------------------------------------------------

Lens        =     Work                  ; code lengths, 320 words
LenCnt      =     Work+640              ; literal/length code: counts by length
LenSym      =     Work+704              ;   symbols in code order (288 words)
DstCnt      =     Work+1280             ; distance code
DstSym      =     Work+1344
Offs        =     Work+1408             ; 17 words

* Inflate: out: carry clear, or carry set and A = errCorrupt
Inflate     stz   IBitCnt
            stz   OutDone
            stz   OutDone+2
:block      lda   OutLeft
            ora   OutLeft+2
            beq   :done
            jsr   GetBit
            lda   #0
            rol
            sta   Last
            ldx   #2
            jsr   GetBits
            cmp   #0
            beq   :stored
            cmp   #1
            beq   :fixed
            cmp   #2
            bne   :bad
            jsr   Dynamic
            bcs   :bad
            bra   :codes
:fixed      jsr   Fixed
:codes      jsr   Codes
            bcs   :bad
            bra   :next
:stored     jsr   Stored
            bcs   :bad
:next       lda   Last
            beq   :block
:done       clc
            rts
:bad        lda   #errCorrupt
            sec
            rts

* GetBit: the next bit (lowest first) in the carry. Keeps X and Y.
GetBit      dec   IBitCnt
            bpl   :have
            jsr   GetByte
            sta   IBitBuf
            lda   #7
            sta   IBitCnt
:have       lsr   IBitBuf
            rts

* GetBits: X bits, first bit lowest, in A.
GetBits     stz   IBits
            lda   #1
            sta   IMask
            cpx   #0
            beq   :done
:loop       jsr   GetBit
            bcc   :zero
            lda   IBits
            ora   IMask
            sta   IBits
:zero       asl   IMask
            dex
            bne   :loop
:done       lda   IBits
            rts

* PutOut: writes the byte in A. Carry set when the output is full.
PutOut      ldx   OutLeft
            bne   :room
            ldx   OutLeft+2
            beq   :full
            dec   OutLeft+2
:room       dec   OutLeft
            sep   #$20
            mx    %10
            sta   [q0]
            rep   #$20
            mx    %00
            inc   q0
            bne   :b
            inc   q0+2
:b          inc   OutDone
            bne   :c
            inc   OutDone+2
:c          clc
            rts
:full       sec
            rts

* Stored: a block stored as it is.
Stored      stz   IBitCnt               ; to the next byte boundary
            jsr   GetLE16
            sta   CopyLen
            jsr   GetLE16
            eor   #$FFFF
            cmp   CopyLen
            bne   :bad
:copy       lda   CopyLen
            beq   :ok
            jsr   GetByte
            jsr   PutOut
            bcs   :ok
            dec   CopyLen
            bra   :copy
:ok         clc
            rts
:bad        sec
            rts

* Fixed: the fixed Huffman codes.
Fixed       ldx   #0
            lda   #8
:a          sta   Lens,x
            inx
            inx
            cpx   #576
            bcc   :a
            ldx   #288
            lda   #9
:b          sta   Lens,x
            inx
            inx
            cpx   #512
            bcc   :b
            lda   #7
:c          sta   Lens,x
            inx
            inx
            cpx   #560
            bcc   :c
            lda   #Lens
            sta   u0
            lda   #288
            sta   BN
            lda   #LenCnt
            sta   hc
            lda   #LenSym
            sta   hs
            jsr   Build
            ldx   #0
            lda   #5
:d          sta   Lens,x
            inx
            inx
            cpx   #60
            bcc   :d
            lda   #Lens
            sta   u0
            lda   #30
            sta   BN
            lda   #DstCnt
            sta   hc
            lda   #DstSym
            sta   hs
            jmp   Build

* Dynamic: reads the code lengths of a dynamic block and builds its codes.
Dynamic     ldx   #5
            jsr   GetBits
            clc
            adc   #257
            sta   HLit
            ldx   #5
            jsr   GetBits
            inc
            sta   HDist
            ldx   #4
            jsr   GetBits
            clc
            adc   #4
            sta   HCLen
            ldx   #36
:zero       stz   Lens,x
            dex
            dex
            bpl   :zero
            ldy   #0
:cl         ldx   #3
            jsr   GetBits
            pha
            lda   Order,y
            asl
            tax
            pla
            sta   Lens,x
            iny
            iny
            tya
            lsr
            cmp   HCLen
            bcc   :cl
            lda   #Lens
            sta   u0
            lda   #19
            sta   BN
            lda   #LenCnt
            sta   hc
            lda   #LenSym
            sta   hs
            jsr   Build
            lda   HLit
            clc
            adc   HDist
            sta   HTot
            stz   LIdx
:lens       lda   LIdx
            cmp   HTot
            bcs   :built
            jsr   DecodeH
            bcs   :bad
            cmp   #16
            bcs   :repeat
            pha
            lda   LIdx
            asl
            tax
            pla
            sta   Lens,x
            inc   LIdx
            bra   :lens
:repeat     sta   u2
            cmp   #16
            bne   :zeros
            lda   LIdx                  ; 16: the previous length, 3-6 times
            beq   :bad
            asl
            tax
            lda   Lens-2,x
            sta   u1
            ldx   #2
            jsr   GetBits
            clc
            adc   #3
            bra   :fill
:zeros      stz   u1
            cmp   #17
            bne   :long
            ldx   #3                    ; 17: zero, 3-10 times
            jsr   GetBits
            clc
            adc   #3
            bra   :fill
:long       ldx   #7                    ; 18: zero, 11-138 times
            jsr   GetBits
            clc
            adc   #11
:fill       sta   u2
            clc
            adc   LIdx
            beq   :bad
            dec
            cmp   HTot
            bcs   :bad
:put        lda   LIdx
            asl
            tax
            lda   u1
            sta   Lens,x
            inc   LIdx
            dec   u2
            bne   :put
            bra   :lens
:bad        sec
            rts
:built      lda   #Lens
            sta   u0
            lda   HLit
            sta   BN
            lda   #LenCnt
            sta   hc
            lda   #LenSym
            sta   hs
            jsr   Build
            lda   HLit
            asl
            clc
            adc   #Lens
            sta   u0
            lda   HDist
            sta   BN
            lda   #DstCnt
            sta   hc
            lda   #DstSym
            sta   hs
            jsr   Build
            clc
            rts

* Build: canonical code from BN lengths at (u0) into counts (hc), symbols (hs).
Build       ldy   #32
            lda   #0
:clear      sta   (hc),y
            dey
            dey
            bpl   :clear
            ldy   #0
            ldx   BN
:count      lda   (u0),y
            asl
            phy
            tay
            lda   (hc),y
            inc
            sta   (hc),y
            ply
            iny
            iny
            dex
            bne   :count
            stz   Offs+2
            ldy   #2
:offs       lda   Offs,y
            clc
            adc   (hc),y
            sta   Offs+2,y
            iny
            iny
            cpy   #32
            bcc   :offs
            ldy   #0
            stz   u1
:sym        lda   (u0),y
            beq   :skip
            asl
            tax
            phy
            lda   Offs,x
            asl
            tay
            lda   u1
            sta   (hs),y
            inc   Offs,x
            ply
:skip       iny
            iny
            inc   u1
            lda   u1
            cmp   BN
            bcc   :sym
            rts

* DecodeH: one symbol of the code at hc/hs. Carry set if no code matches.
DecodeH     stz   HCode
            stz   HFirst
            stz   HIndex
            ldy   #2
:loop       jsr   GetBit
            rol   HCode
            lda   (hc),y
            sta   HCount
            clc
            adc   HFirst
            sta   HLimit
            lda   HCode
            cmp   HLimit
            bcc   :found
            lda   HIndex
            clc
            adc   HCount
            sta   HIndex
            lda   HLimit
            asl
            sta   HFirst
            iny
            iny
            cpy   #32
            bcc   :loop
            sec
            rts
:found      sec
            sbc   HFirst
            clc
            adc   HIndex
            asl
            tay
            lda   (hs),y
            clc
            rts

* Codes: the literals and copies of a block, up to its end code.
Codes       lda   #LenCnt
            sta   hc
            lda   #LenSym
            sta   hs
            jsr   DecodeH
            bcc   :jx1
            jmp   :bad
:jx1
            cmp   #256
            bcs   :jx3
            jmp   :literal
:jx3
            bne   :jx2
            jmp   :end
:jx2
            sec
            sbc   #257
            cmp   #29
            bcs   :bad
            asl
            tax
            lda   LBase,x
            sta   CopyLen
            lda   LExt,x
            tax
            jsr   GetBits
            clc
            adc   CopyLen
            sta   CopyLen
            lda   #DstCnt
            sta   hc
            lda   #DstSym
            sta   hs
            jsr   DecodeH
            bcs   :bad
            cmp   #30
            bcs   :bad
            asl
            tax
            lda   DBase,x
            sta   BackDist
            lda   DExt,x
            tax
            jsr   GetBits
            clc
            adc   BackDist
            sta   BackDist
            lda   OutDone+2             ; not further back than the start
            bne   :far
            lda   OutDone
            cmp   BackDist
            bcc   :bad
:far        lda   q0
            sec
            sbc   BackDist
            sta   q1
            lda   q0+2
            sbc   #0
            sta   q1+2
:copy       lda   [q1]
            and   #$00FF
            jsr   PutOut
            bcs   :end
            inc   q1
            bne   :c
            inc   q1+2
:c          dec   CopyLen
            bne   :copy
            jmp   Codes
:literal    jsr   PutOut
            bcs   :end
            jmp   Codes
:end        clc
            rts
:bad        sec
            rts

Order       dw    16,17,18,0,8,7,9,6,10,5,11,4,12,3,13,2,14,1,15
LBase       dw    3,4,5,6,7,8,9,10,11,13,15,17,19,23,27,31
            dw    35,43,51,59,67,83,99,115,131,163,195,227,258
LExt        dw    0,0,0,0,0,0,0,0,1,1,1,1,2,2,2,2
            dw    3,3,3,3,4,4,4,4,5,5,5,5,0
DBase       dw    1,2,3,4,5,7,9,13,17,25,33,49,65,97,129,193
            dw    257,385,513,769,1025,1537,2049,3073,4097,6145
            dw    8193,12289,16385,24577
DExt        dw    0,0,0,0,1,1,2,2,3,3,4,4,5,5,6,6
            dw    7,7,8,8,9,9,10,10,11,11,12,12,13,13

IBitBuf     dw    0
IBitCnt     dw    0
IBits       dw    0
IMask       dw    0
Last        dw    0
OutLeft     adrl  0
OutDone     adrl  0
CopyLen     dw    0
BackDist        dw    0
HLit        dw    0
HDist       dw    0
HCLen       dw    0
HTot        dw    0
LIdx        dw    0
BN          dw    0
HCode       dw    0
HFirst      dw    0
HIndex      dw    0
HCount      dw    0
HLimit      dw    0
