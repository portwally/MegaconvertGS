*-------------------------------------------------------------
* SegLib.s - helpers every loader segment includes (put) for itself:
* building screens and true colour pictures, reading the file,
* arithmetic, and a work buffer.
*-------------------------------------------------------------

OutDP       =     $5C                   ; (direct page) the work buffer from NewOut

* ScrBegin: an empty picture.
ScrBegin    lda   #0
            ldy   #$7FFE
:zero       sta   [scrp],y
            dey
            dey
            bpl   :zero
            rts

* SetTable0: colour table 0 = the 16 words at X.
SetTable0   ldy   #palOffset
:copy       lda   |0,x
            sta   [scrp],y
            inx
            inx
            iny
            iny
            cpy   #palOffset+32
            bcc   :copy
            rts

* SetScbs: the first X lines get SCB A.
SetScbs     sta   t0
            ldy   #scbOffset
:scb        cpx   #0
            beq   :done
            sep   #$20
            mx    %10
            lda   t0
            sta   [scrp],y
            rep   #$20
            mx    %00
            iny
            dex
            bra   :scb
:done       rts

* ClearRow: all of RowPix to A.
ClearRow    and   #$00FF                ; the value in both bytes
            sta   t0
            xba
            ora   t0
            ldx   #638
:clr        sta   RowPix,x
            dex
            dex
            bpl   :clr
            rts

* PackRow: RowPix (one pixel value a byte, PixW of them) into picture
* line RowY, 2 pixels a byte, or 4 in 640 mode (Is640). At most one
* screen wide; lines beyond 200 are left out.
PackRow     ldx   PixW                  ; nothing past the last pixel
            stz   RowPix,x
            stz   RowPix+2,x
            lda   Is640                 ; the picture's size, at most a screen
            sta   p640
            lda   #320
            ldx   Is640
            beq   :maxW
            asl
:maxW       cmp   PixW
            bcc   :w
            lda   PixW
:w          sta   pw
            lda   RowY
            inc
            cmp   #201
            bcc   :h
            lda   #200
:h          cmp   ph
            bcc   :rows
            sta   ph
:rows       lda   RowY
            cmp   #200
            bcc   :in
            rts
:in         asl
            asl
            asl
            asl
            asl
            sta   t0
            asl
            asl
            clc
            adc   t0
            tay
            sta   t3
            clc
            adc   #160
            sta   t2                    ; end of the line
            ldx   #0
            lda   Is640
            bne   :wide
:narrow     cpx   PixW
            bcs   :done
            cpy   t2
            bcs   :done
            lda   RowPix,x
            and   #$000F
            asl
            asl
            asl
            asl
            sta   t1
            lda   RowPix+1,x
            and   #$000F
            ora   t1
            jsr   :store
            inx
            inx
            bra   :narrow
:wide       cpx   PixW
            bcs   :done
            cpy   t2
            bcs   :done
            lda   RowPix,x
            and   #$0003
            asl
            asl
            sta   t1
            lda   RowPix+1,x
            and   #$0003
            ora   t1
            asl
            asl
            sta   t1
            lda   RowPix+2,x
            and   #$0003
            ora   t1
            asl
            asl
            sta   t1
            lda   RowPix+3,x
            and   #$0003
            ora   t1
            jsr   :store
            inx
            inx
            inx
            inx
            bra   :wide
:done       rts
:store      sep   #$20
            mx    %10
            sta   [scrp],y
            rep   #$20
            mx    %00
            iny
            rts


* PutGrey17: a grey pixel of 4-bit level A at [q0],y; y += 3.
PutGrey17   sta   t1
            asl
            asl
            asl
            asl
            ora   t1
PutGrey     sep   #$20
            mx    %10
            sta   [q0],y
            iny
            sta   [q0],y
            iny
            sta   [q0],y
            iny
            rep   #$20
            mx    %00
            rts


Times17     sta   t2
            asl
            asl
            asl
            asl
            ora   t2
            rts


* NeedLen: carry set (A = errNotPicture) if the file is shorter than A bytes.
NeedLen     ldx   flen+2
            bne   :ok
            cmp   flen
            beq   :ok
            bcc   :ok
            lda   #errNotPicture
            sec
            rts
:ok         clc
            rts

* NeedLong: like NeedLen, for X:A bytes.
NeedLong    cpx   flen+2
            bcc   :ok
            bne   :short
            cmp   flen
            beq   :ok
            bcc   :ok
:short      lda   #errNotPicture
            sec
            rts
:ok         clc
            rts

* Within: carry clear if offset A is no further than the end of the file.
Within      ldx   flen+2
            bne   :ok
            cmp   flen
            beq   :ok
            bcc   :ok
            sec
            rts
:ok         clc
            rts

* TrueRow: q0 = row A of the true colour picture.
TrueRow     ldx   tstride
            jsr   Mul16
            lda   tp
            clc
            adc   MLo
            sta   q0
            lda   tp+2
            adc   MHi
            sta   q0+2
            rts

* Mul16: MLo/MHi = A * X.
Mul16       sta   MA
            stz   MAHi
            stx   MB
            stz   MLo
            stz   MHi
:loop       lda   MB
            beq   :done
            lsr   MB
            bcc   :shift
            clc
            lda   MLo
            adc   MA
            sta   MLo
            lda   MHi
            adc   MAHi
            sta   MHi
:shift      asl   MA
            rol   MAHi
            bra   :loop
:done       rts

* Div16: A / X (X not 0), the quotient in A.
Div16       sta   DvN
            stx   DvD
            stz   DvQ
            stz   DvR
            ldx   #16
:bit        asl   DvN
            rol   DvR
            lda   DvR
            sec
            sbc   DvD
            bcc   :no
            sta   DvR
:no         rol   DvQ
            dex
            bne   :bit
            lda   DvQ
            rts

* NewOut: a buffer of A bytes (OutP; OutDP is its pointer on the direct page).
NewOut      inc                         ; an even size (it is cleared a word at a time)
            and   #$FFFE
            sta   n0
            stz   n0+2
            pha                         ; result: handle
            pha
            PushLongAt n0
            lda   uid
            pha
            pea   attrBuffer
            PushLong 0
            Tool  _NewHandle
            tax
            pla
            sta   OutH
            pla
            sta   OutH+2
            txa
            bcs   :err
            lda   OutH
            sta   n1
            lda   OutH+2
            sta   n1+2
            lda   [n1]
            sta   OutP
            sta   OutDP
            ldy   #2
            lda   [n1],y
            sta   OutP+2
            sta   OutDP+2
            ldy   n0                    ; start empty
            lda   #0
:zero       dey
            dey
            sta   [OutDP],y
            bne   :zero
            clc
:err        rts

FreeOut     lda   OutH
            ora   OutH+2
            beq   :none
            PushLongAt OutH
            Tool  _DisposeHandle
            stz   OutH
            stz   OutH+2
:none       rts


Std320      dw    $000,$777,$841,$72C,$00F,$080,$F70,$D00
            dw    $FA9,$FF0,$0E0,$4DF,$DAF,$78F,$CCC,$FFF
Std640      dw    $000,$F00,$0F0,$FFF,$000,$00F,$FF0,$FFF
            dw    $000,$F00,$0F0,$FFF,$000,$00F,$FF0,$FFF
BWPal       dw    $000,$FFF,$000,$FFF,$000,$FFF,$000,$FFF
            dw    $000,$FFF,$000,$FFF,$000,$FFF,$000,$FFF
Is640       dw    0
PixW        dw    0
RowY        dw    0
CR          dw    0
CG          dw    0
CB          dw    0
MA          dw    0
MAHi        dw    0
MB          dw    0
MLo         dw    0
MHi         dw    0
DvN         dw    0
DvD         dw    0
DvQ         dw    0,0
DvR         dw    0
OutH        adrl  0
OutP        adrl  0
RowPix      ds    644

*-------------------------------------------------------------
* Reading the file as a stream: s0 (direct page) is the read
* position, SLeft the bytes left. Past the end: zeros, carry set.
*-------------------------------------------------------------

* SAt: reads from offset n0 (long) on. Carry set if that is past the end.
SAt         lda   flen
            sec
            sbc   n0
            sta   SLeft
            lda   flen+2
            sbc   n0+2
            sta   SLeft+2
            bcc   :past
            lda   fp
            clc
            adc   n0
            sta   s0
            lda   fp+2
            adc   n0+2
            sta   s0+2
            clc
            rts
:past       stz   SLeft
            stz   SLeft+2
            sec
            rts

* SAtA: reads from offset A on.
SAtA        sta   n0
            stz   n0+2
            bra   SAt

* SByte: the next byte (keeps X and Y).
SByte       lda   SLeft
            bne   :have
            lda   SLeft+2
            beq   :end
            dec   SLeft+2
:have       dec   SLeft
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

* SBE16 / SLE16: a 16-bit number, high or low byte first (keep X and Y).
SBE16       jsr   SByte
            xba
            pha
            jsr   SByte
            ora   1,s
            sta   1,s
            pla
            rts

SLE16       jsr   SByte
            pha
            jsr   SByte
            xba
            ora   1,s
            sta   1,s
            pla
            rts

* SBE32: a 32-bit number, high byte first, in n1.
SBE32       jsr   SBE16
            sta   n1+2
            jsr   SBE16
            sta   n1
            rts

* SSkip: skips n0 (long) bytes.
SSkip       lda   SLeft
            sec
            sbc   n0
            tax
            lda   SLeft+2
            sbc   n0+2
            bcc   :all
            sta   SLeft+2
            stx   SLeft
            lda   s0
            clc
            adc   n0
            sta   s0
            lda   s0+2
            adc   n0+2
            sta   s0+2
            rts
:all        stz   SLeft
            stz   SLeft+2
            rts

* SPos: the read position as an offset into the file, in n0.
SPos        lda   flen
            sec
            sbc   SLeft
            sta   n0
            lda   flen+2
            sbc   SLeft+2
            sta   n0+2
            rts

* MakeTrue: a black true colour picture of A x X pixels (ttall as set),
* keeping q1, q2 and u0-u3 (making it uses them).
MakeTrue    pei   q1+2
            pei   q1
            pei   q2+2
            pei   q2
            pei   u0
            pei   u1
            pei   u2
            pei   u3
            jsl   NewTrueL
            ply
            sty   u3
            ply
            sty   u2
            ply
            sty   u1
            ply
            sty   u0
            ply
            sty   q2
            ply
            sty   q2+2
            ply
            sty   q1
            ply
            sty   q1+2
            rts

* PutRGB: CR, CG, CB at [q0],y; y += 3.
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

* Div32: n0 (long) / A, the quotient (16 bits) in A, the remainder in DvR.
Div32       sta   DvD
            stz   DvR
            stz   DvQ
            stz   DvQ+2
            ldx   #32
:bit        asl   n0
            rol   n0+2
            rol   DvR
            lda   DvR
            sec
            sbc   DvD
            bcc   :no
            sta   DvR
:no         rol   DvQ
            rol   DvQ+2
            dex
            bne   :bit
            lda   DvQ
            rts

* PackBits (ByteRun1) from the stream, a byte at a time. PBStart starts a run
* afresh; PBGet gives the next byte (0 once the data runs out).
PBStart     stz   PBLeft
            rts

PBGet       lda   PBLeft
            bne   :have
            jsr   SByte                 ; a control byte
            bcs   :zero
            cmp   #$80
            beq   PBGet                 ; -128: nothing
            bcs   :run
            inc                         ; n + 1 bytes as they are
            sta   PBLeft
            stz   PBRun
            bra   :have
:run        eor   #$00FF                ; 1 - n repeats of the next byte
            clc
            adc   #2
            sta   PBLeft
            jsr   SByte
            bcs   :zero
            sta   PBVal
            lda   #1
            sta   PBRun
:have       dec   PBLeft
            lda   PBRun
            beq   :literal
            lda   PBVal
            rts
:literal    jmp   SByte
:zero       stz   PBLeft
            lda   #0
            rts

* PBEnd: the end of a row: bytes of a literal run that weren't needed are skipped
* (a repeat run's byte has already been read).
PBEnd       lda   PBRun
            bne   :done
:skip       lda   PBLeft
            beq   :done
            jsr   SByte
            dec   PBLeft
            bra   :skip
:done       stz   PBLeft
            rts

PBLeft      dw    0
PBRun       dw    0
PBVal       dw    0

SLeft       adrl  0
