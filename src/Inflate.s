*-------------------------------------------------------------
* Inflate.s - Deflate decompression (RFC 1951), as used by PNG
*
* Reads from the stream (s0, InLeft), writes to q0 until OutLeft
* bytes are written or the last block ends. The output so far is
* the history that back-references copy from, so no window is
* kept: the whole result stays in memory.
* Bits are read from the stream in place: s0 is the byte they come
* from, BitOff how many of its bits are used, InLeft the bytes left from
* it on; past the end every bit is 0 (as GetByte gives 0 there): the
* data is followed by two 0 bytes, where s0 stays once it gets there.
* Huffman codes up to 9 bits long come from a table of the next 9 bits;
* longer ones are decoded a bit at a time from per-length code counts,
* the canonical way (which also decides any code a table entry doesn't).
*-------------------------------------------------------------

Lens        =     Work                  ; code lengths, 320 words
LenCnt      =     Work+640              ; literal/length code: counts by length
LenSym      =     Work+704              ;   symbols in code order (288 words)
DstCnt      =     Work+1280             ; distance code
DstSym      =     Work+1344
Offs        =     Work+1408             ; 17 words
LitTab      =     Work+2048             ; the next 9 bits: length x 4096 +
DstTab      =     Work+3072             ;   symbol, or 0 (512 words each)
FirstC      =     Work+4096             ; Build: first code, first symbol
SIdx        =     Work+4128             ;   by length (16 words each)

* Inflate: out: carry clear, or carry set and A = errCorrupt
Inflate     stz   BitOff
            stz   BitOff2
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
GetBit      phx
            phy
            ldx   #1
            jsr   GetBits
            ply
            plx
            lsr
            rts

* GetBits: X bits (up to 16), first bit lowest, in A.
GetBits     cpx   #10
            bcs   :two
            phx
            jsr   Peek16
            plx
            pha
            txa
            jsr   Drop
            txa
            asl
            tax
            pla
            and   BitMask,x
            rts
:two        phx                         ; (8, then the rest above them)
            ldx   #8
            jsr   GetBits
            sta   GbLo
            pla
            sec
            sbc   #8
            tax
            jsr   GetBits
            xba
            ora   GbLo
            rts

* Peek16: the next 16 bits (at least 9 of them from the data, or the 0s
* after it), first bit lowest, in A. Uses X.
Peek16      lda   [s0]
            ldx   BitOff2
            jmp   (:sh,x)
:sh         da    :c0,:c1,:c2,:c3,:c4,:c5,:c6,:c7
:c7         lsr
:c6         lsr
:c5         lsr
:c4         lsr
:c3         lsr
:c2         lsr
:c1         lsr
:c0         rts

* Drop: A (up to 9) bits used.
Drop        clc
            adc   BitOff
            cmp   #8
            bcs   :adv
            sta   BitOff
            asl
            sta   BitOff2
            rts
:adv        pha
            and   #7
            sta   BitOff
            asl
            sta   BitOff2
            pla
            lsr
            lsr
            lsr
            sta   DropK                 ; (whole bytes: 1 or 2)
            lda   InLeft+2
            bne   :ok
            lda   InLeft
            cmp   DropK
            bcs   :ok
            sta   DropK                 ; (to the end: the 0s from now on)
:ok         lda   InLeft
            sec
            sbc   DropK
            sta   InLeft
            lda   InLeft+2
            sbc   #0
            sta   InLeft+2
            lda   s0
            clc
            adc   DropK
            sta   s0
            bcc   :d
            inc   s0+2
:d          rts

BitMask     dw    0,1,3,7,15,31,63,127,255,511

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
Stored      lda   BitOff                ; to the next byte boundary
            beq   :al
            lda   #8
            sec
            sbc   BitOff
            jsr   Drop
:al
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
            lda   #LitTab
            sta   u3
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
            lda   #DstTab
            sta   u3
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
            lda   #LitTab
            sta   u3
            jsr   Build
            lda   HLit
            clc
            adc   HDist
            sta   HTot
            stz   LIdx
:lens       lda   LIdx
            cmp   HTot
            bcs   :built
            jsr   DecLit
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
            lda   #LitTab
            sta   u3
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
            lda   #DstTab
            sta   u3
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
            jmp   Table

* Table: the 9-bit table at (u3) for the code just built: each code of up
* to 9 bits at every index whose low bits are the code (first bit lowest).
* Longest first, so where codes overlap (an over-full code) the shorter
* one is left, as DecodeH finds it first; codes past a length's room, and
* every longer code, are left to DecodeH.
Table       ldy   #1022
            lda   #0
:z          sta   (u3),y
            dey
            dey
            bpl   :z
            stz   u1                    ; first codes and symbols by length
            stz   u2
            ldy   #2
:fc         lda   u1
            sta   FirstC,y
            lda   u2
            sta   SIdx,y
            lda   (hc),y
            clc
            adc   u2
            sta   u2
            lda   (hc),y
            clc
            adc   u1
            asl
            sta   u1
            iny
            iny
            cpy   #20
            bcc   :fc
            lda   #9                    ; each length, longest first
            sta   TLen
:len        lda   TLen
            asl
            tay
            lda   (hc),y
            beq   :nextLen
            sta   TCnt
            lda   FirstC,y
            sta   TCode
            lda   SIdx,y
            asl
            sta   TSym
            ldx   TLen                  ; (the room: 2^len codes)
            lda   #1
:p          asl
            dex
            bne   :p
            sta   TStep
:code       lda   TCode
            cmp   TStep
            bcs   :nextLen
            ldx   TLen                  ; its bits reversed
            stz   TRev
:rv         lsr
            rol   TRev
            dex
            bne   :rv
            ldy   TSym                  ; the entry: length x 4096 + symbol
            lda   (hs),y
            sta   TEnt
            lda   TLen
            xba
            asl
            asl
            asl
            asl
            ora   TEnt
            sta   TEnt
            lda   TRev
:fill       asl
            tay
            lda   TEnt
            sta   (u3),y
            tya
            lsr
            clc
            adc   TStep
            cmp   #512
            bcc   :fill
            inc   TCode
            inc   TSym
            inc   TSym
            dec   TCnt
            bne   :code
:nextLen    dec   TLen
            bne   :len
            rts

* DecLit, DecDst: one symbol of the literal/length (or code length) code,
* or of the distance code: from the table, else DecodeH. Carry set if no
* code matches.
DecLit      lda   [s0]                  ; (Peek16 inline)
            ldx   BitOff2
            jmp   (:sh,x)
:sh         da    :c0,:c1,:c2,:c3,:c4,:c5,:c6,:c7
:c7         lsr
:c6         lsr
:c5         lsr
:c4         lsr
:c3         lsr
:c2         lsr
:c1         lsr
:c0         and   #$01FF
            asl
            tax
            lda   LitTab,x
            beq   :slow
            sta   TEnt
            xba
            lsr
            lsr
            lsr
            lsr
            and   #$000F
            clc                         ; (Drop inline, but for whole bytes)
            adc   BitOff
            cmp   #8
            bcs   :adv
            sta   BitOff
            asl
            sta   BitOff2
            lda   TEnt
            and   #$01FF
            clc
            rts
:adv        sbc   BitOff                ; (back to the length: carry set)
            jsr   Drop
            lda   TEnt
            and   #$01FF
            clc
            rts
:slow       lda   #LenCnt
            sta   hc
            lda   #LenSym
            sta   hs
            jmp   DecodeH
DecDst      lda   [s0]                  ; (Peek16 inline)
            ldx   BitOff2
            jmp   (:sh,x)
:sh         da    :c0,:c1,:c2,:c3,:c4,:c5,:c6,:c7
:c7         lsr
:c6         lsr
:c5         lsr
:c4         lsr
:c3         lsr
:c2         lsr
:c1         lsr
:c0         and   #$01FF
            asl
            tax
            lda   DstTab,x
            beq   :slow
            sta   TEnt
            xba
            lsr
            lsr
            lsr
            lsr
            and   #$000F
            clc                         ; (Drop inline, but for whole bytes)
            adc   BitOff
            cmp   #8
            bcs   :adv
            sta   BitOff
            asl
            sta   BitOff2
            lda   TEnt
            and   #$01FF
            clc
            rts
:adv        sbc   BitOff                ; (back to the length: carry set)
            jsr   Drop
            lda   TEnt
            and   #$01FF
            clc
            rts
:slow       lda   #DstCnt
            sta   hc
            lda   #DstSym
            sta   hs
            jmp   DecodeH

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
Codes       jsr   DecLit
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
            bcc   :jx4
            jmp   :bad
:jx4        asl
            tax
            lda   LBase,x
            sta   CopyLen
            lda   LExt,x
            beq   :noExt
            tax
            jsr   GetBits
            clc
            adc   CopyLen
            sta   CopyLen
:noExt      jsr   DecDst
            bcc   :jx5
            jmp   :bad
:jx5        cmp   #30
            bcc   :jx6
            jmp   :bad
:jx6        asl
            tax
            lda   DBase,x
            sta   BackDist
            lda   DExt,x
            beq   :noDExt
            tax
            jsr   GetBits
            clc
            adc   BackDist
            sta   BackDist
:noDExt     lda   OutDone+2             ; not further back than the start
            bne   :far
            lda   OutDone
            cmp   BackDist
            bcs   :far
            jmp   :bad
:far        lda   q0
            sec
            sbc   BackDist
            sta   q1
            lda   q0+2
            sbc   #0
            sta   q1+2
            stz   CopyEnd               ; as many as there is room for (the
            lda   OutLeft+2             ; block ends when the output is full)
            bne   :room
            lda   OutLeft
            cmp   CopyLen
            bcs   :room
            sta   CopyLen
            inc   CopyEnd
            lda   CopyLen
            beq   :end
:room       ldy   #0                    ; forwards (a copy may overlap what it
            lda   BackDist              ; writes): two bytes at a time when
            cmp   #2                    ; they are 2 or more back, the last
            bcc   :bytes                ; one alone
            lda   CopyLen
            lsr
            beq   :last
            tax
:copy2      lda   [q1],y
            sta   [q0],y
            iny
            iny
            dex
            bne   :copy2
:last       lda   CopyLen
            lsr
            bcc   :copied
:bytes      sep   #$20
            mx    %10
:copy       lda   [q1],y
            sta   [q0],y
            iny
            cpy   CopyLen
            bcc   :copy
            rep   #$20
            mx    %00
:copied
            lda   q0                    ; the output moves on
            clc
            adc   CopyLen
            sta   q0
            bcc   :q
            inc   q0+2
:q          lda   OutLeft
            sec
            sbc   CopyLen
            sta   OutLeft
            bcs   :ol
            dec   OutLeft+2
:ol         lda   OutDone
            clc
            adc   CopyLen
            sta   OutDone
            bcc   :od
            inc   OutDone+2
:od         lda   CopyEnd
            bne   :end
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

BitOff      dw    0                     ; bits used of the byte at s0
BitOff2     dw    0                     ; (the same times 2)
DropK       dw    0
GbLo        dw    0
CopyEnd     dw    0                     ; (the output full after this copy)
TLen        dw    0                     ; (Table: a length, its codes left,
TCnt        dw    0                     ; the next code, its symbol's place,
TCode       dw    0                     ; the length's room, a code reversed,
TSym        dw    0                     ; the entry)
TStep       dw    0
TRev        dw    0
TEnt        dw    0
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
