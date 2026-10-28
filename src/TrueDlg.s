*-------------------------------------------------------------
* TrueDlg.s - the True color menu's Dialog Manager dialogs, as
* SuperConvert's (part of the Filter segment; see
* docs/superconvert-truecolor.md): Rotate/flip image, True color
* image info, and the progress dialog the filters show.
*-------------------------------------------------------------

*-------------------------------------------------------------
* Rotate/flip image
*-------------------------------------------------------------

* FilterTurnAsk: the Rotate/flip dialog; A = 1 if the picture is too big
* to turn (only flips then).   out: A = the bits (1 mirror, 2 flip, 4 turn;
* 0: Cancel or no change)
FilterTurnAsk ent
            phb
            phk
            plb
            sta   TooBig
            tdc
            sta   FxDP
            pha
            pha
            PushLong RotTmpl
            Tool  _GetNewModalDialog
            pla
            sta   Dlg
            pla
            sta   Dlg+2
            lda   TooBig
            beq   :all
            PushLongAt Dlg              ; too big: the note, and no turns
            pea   16
            Tool  _ShowDItem
            ldx   #0
:rem        phx
            PushLongAt Dlg
            lda   NoTurn,x
            pha
            Tool  _RemoveDItem
            plx
            inx
            inx
            cpx   #8
            bcc   :rem
:all        PushLongAt Dlg
            Tool  _SetPort
            lda   #1                    ; M = [1 0; 0 1]
            sta   Ma
            sta   Md
            stz   Mb
            stz   Mc
            stz   Erase
            jsr   MAsABCD
            jsr   Preview
:loop       pha
            PushLong 0
            Tool  _ModalDialog
            pla
            cmp   #1
            beq   :make
            cmp   #2
            beq   :cancel
            cmp   #9
            bcs   :loop
            sec
            sbc   #3
            asl
            tax
            jsr   (Moves,x)
            bra   :loop
:cancel     stz   TurnBits
            bra   :close
:make       stz   TurnBits              ; M as the bits
            lda   TooBig
            bne   :rows
            lda   Mb
            beq   :rows
            lda   #4
            tsb   TurnBits
            lda   Ma                    ; rows swapped: (c, d, a, b)
            ldx   Mc
            stx   Ma
            sta   Mc
            lda   Mb
            ldx   Md
            stx   Mb
            sta   Md
:rows       lda   Md
            bpl   :d
            lda   #2
            tsb   TurnBits
:d          lda   Ma
            bpl   :close
            lda   #1
            tsb   TurnBits
:close      PushLongAt Dlg
            Tool  _CloseDialog
            lda   TurnBits
            plb
            rtl
NoTurn      dw    3,4,7,8
Moves       da    RotL,RotR,FlipV,FlipH,TwistA,TwistB

* The buttons: each animates the preview to the new M (COS[k], SIN[k]:
* 10 degree steps), then sets M.
RotL        ldx   #2                    ; << Rotate: anticlockwise
:k          stx   Step
            lda   Ma                    ; A = a COS + c SIN
            jsr   TimesCos
            sta   PA
            lda   Mc
            jsr   TimesSin
            clc
            adc   PA
            sta   PA
            lda   Mb                    ; B = b COS + d SIN
            jsr   TimesCos
            sta   PB
            lda   Md
            jsr   TimesSin
            clc
            adc   PB
            sta   PB
            lda   Mc                    ; C = c COS - a SIN
            jsr   TimesCos
            sta   PC
            lda   Ma
            jsr   TimesSin
            jsr   Neg
            clc
            adc   PC
            sta   PC
            lda   Md                    ; D = d COS - b SIN
            jsr   TimesCos
            sta   PD
            lda   Mb
            jsr   TimesSin
            jsr   Neg
            clc
            adc   PD
            sta   PD
            jsr   Animate
            ldx   Step
            inx
            inx
            cpx   #20
            bcc   :k
            lda   Ma                    ; (a, b, c, d) = (c, d, -a, -b)
            ldx   Mc
            stx   Ma
            jsr   Neg
            sta   Mc
            lda   Mb
            ldx   Md
            stx   Mb
            jsr   Neg
            sta   Md
            rts
RotR        ldx   #2                    ; Rotate >>: clockwise
:k          stx   Step
            lda   Ma                    ; A = a COS - c SIN
            jsr   TimesCos
            sta   PA
            lda   Mc
            jsr   TimesSin
            jsr   Neg
            clc
            adc   PA
            sta   PA
            lda   Mb                    ; B = b COS - d SIN
            jsr   TimesCos
            sta   PB
            lda   Md
            jsr   TimesSin
            jsr   Neg
            clc
            adc   PB
            sta   PB
            lda   Mc                    ; C = c COS + a SIN
            jsr   TimesCos
            sta   PC
            lda   Ma
            jsr   TimesSin
            clc
            adc   PC
            sta   PC
            lda   Md                    ; D = d COS + b SIN
            jsr   TimesCos
            sta   PD
            lda   Mb
            jsr   TimesSin
            clc
            adc   PD
            sta   PD
            jsr   Animate
            ldx   Step
            inx
            inx
            cpx   #20
            bcc   :k
            lda   Mc                    ; (a, b, c, d) = (-c, -d, a, b)
            jsr   Neg
            ldx   Ma
            sta   Ma
            stx   Mc
            lda   Md
            jsr   Neg
            ldx   Mb
            sta   Mb
            stx   Md
            rts
FlipV       ldx   #2                    ; \/ Flip \/: upside down
:k          stx   Step
            lda   Ma
            jsr   Times100
            sta   PA
            lda   Mb
            jsr   Times100
            sta   PB
            lda   Mc
            jsr   TimesCos
            sta   PC
            lda   Md
            jsr   TimesCos
            sta   PD
            jsr   Animate
            ldx   Step
            inx
            inx
            cpx   #38
            bcc   :k
            lda   Mc
            jsr   Neg
            sta   Mc
            lda   Md
            jsr   Neg
            sta   Md
            rts
FlipH       ldx   #2                    ; > Flip >: left and right
:k          stx   Step
            lda   Ma
            jsr   TimesCos
            sta   PA
            lda   Mb
            jsr   TimesCos
            sta   PB
            lda   Mc
            jsr   Times100
            sta   PC
            lda   Md
            jsr   Times100
            sta   PD
            jsr   Animate
            ldx   Step
            inx
            inx
            cpx   #38
            bcc   :k
            lda   Ma
            jsr   Neg
            sta   Ma
            lda   Mb
            jsr   Neg
            sta   Mb
            rts
TwistA      ldx   #2                    ; // Twist: (x, y) to (y, x)
:k          stx   Step
            lda   Ma                    ; A = (COS (a - c) + 100 (a + c)) / 2
            sec
            sbc   Mc
            ldx   Ma
            ldy   Mc
            jsr   TwistOne
            sta   PA
            lda   Mb                    ; B = (COS (b - d) + 100 (b + d)) / 2
            sec
            sbc   Md
            ldx   Mb
            ldy   Md
            jsr   TwistOne
            sta   PB
            lda   Mc                    ; C = (COS (c - a) + 100 (a + c)) / 2
            sec
            sbc   Ma
            ldx   Ma
            ldy   Mc
            jsr   TwistOne
            sta   PC
            lda   Md                    ; D = (COS (d - b) + 100 (b + d)) / 2
            sec
            sbc   Mb
            ldx   Mb
            ldy   Md
            jsr   TwistOne
            sta   PD
            jsr   Animate
            ldx   Step
            inx
            inx
            cpx   #38
            bcc   :k
            lda   Ma                    ; (a, b, c, d) = (c, d, a, b)
            ldx   Mc
            stx   Ma
            sta   Mc
            lda   Mb
            ldx   Md
            stx   Mb
            sta   Md
            rts
TwistB      ldx   #2                    ; Twist \\: (x, y) to (-y, -x)
:k          stx   Step
            lda   Mc                    ; A = (COS (c + a) + 100 (a - c)) / 2
            clc
            adc   Ma
            ldx   Ma
            ldy   Mc
            jsr   TwistTwo
            sta   PA
            lda   Md                    ; B = (COS (d + b) + 100 (b - d)) / 2
            clc
            adc   Mb
            ldx   Mb
            ldy   Md
            jsr   TwistTwo
            sta   PB
            lda   Mc                    ; C = (COS (c + a) + 100 (c - a)) / 2
            clc
            adc   Ma
            ldx   Mc
            ldy   Ma
            jsr   TwistTwo
            sta   PC
            lda   Md                    ; D = (COS (d + b) + 100 (d - b)) / 2
            clc
            adc   Mb
            ldx   Md
            ldy   Mb
            jsr   TwistTwo
            sta   PD
            jsr   Animate
            ldx   Step
            inx
            inx
            cpx   #38
            bcc   :k
            lda   Mc                    ; (a, b, c, d) = (-c, -d, -a, -b)
            jsr   Neg
            pha
            lda   Md
            jsr   Neg
            pha
            lda   Ma
            jsr   Neg
            sta   Mc
            lda   Mb
            jsr   Neg
            sta   Md
            pla
            sta   Mb
            pla
            sta   Ma
            rts

* TwistOne: (COS x A + 100 (X + Y)) / 2; TwistTwo: (COS x A + 100 (X - Y)) / 2.
TwistOne    sty   fu
            stx   fk
            jsr   TimesCos
            sta   fs
            lda   fk
            clc
            adc   fu
            bra   Twist2
TwistTwo    sty   fu
            stx   fk
            jsr   TimesCos
            sta   fs
            lda   fk
            sec
            sbc   fu
Twist2      jsr   Times100
            clc
            adc   fs
            ldx   #2
            jmp   SDiv

* Animate: the preview at PA-PD, the old one erased.
Animate     lda   #1
            sta   Erase
            jmp   Preview

* MAsABCD: PA-PD = 100 M.
MAsABCD     lda   Ma
            jsr   Times100
            sta   PA
            lda   Mb
            jsr   Times100
            sta   PB
            lda   Mc
            jsr   Times100
            sta   PC
            lda   Md
            jsr   Times100
            sta   PD
            rts

* TimesCos, TimesSin: A (-2 to 2) x COS[Step] or SIN[Step]; Times100: A x 100.
TimesCos    ldx   Step
            ldy   Cos,x
            bra   Times
TimesSin    ldx   Step
            ldy   Sin,x
            bra   Times
Times100    ldy   #100
Times       sty   ft                    ; A x Y, A small (repeated adding)
            tax
            lda   #0
            cpx   #0
            beq   :done
            bmi   :neg
:pos        clc
            adc   ft
            dex
            bne   :pos
            rts
:neg        sec
            sbc   ft
            inx
            bne   :neg
:done       rts

* Neg: A = -A.
Neg         eor   #$FFFF
            inc
            rts

* SDiv: A / X, rounded towards 0 (A signed, X more than 0), as C divides.
SDiv        stx   ft
            cmp   #$8000
            bcc   SDivPos
            jsr   Neg
            jsr   SDivPos
            jmp   Neg
SDivPos     ldx   #0
:sub        cmp   ft
            bcc   :done
            sec
            sbc   ft
            inx
            bra   :sub
:done       txa
            rts

* Preview: the framed "UP" for PA-PD: each point (x, y) at
* ((x PA + y PB) / 5 + 160, (x PC + y PD) / 13 + 60); with Erase, the
* previous one first in white.
Preview     ldx   #0
:pt         lda   UpCurH,x              ; the previous place
            sta   UpOldH,x
            lda   UpCurV,x
            sta   UpOldV,x
            phx
            lda   UpX,x
            ldy   PA
            jsr   MulS
            sta   fk
            plx
            phx
            lda   UpY,x
            ldy   PB
            jsr   MulS
            clc
            adc   fk
            ldx   #5
            jsr   SDiv
            clc
            adc   #160
            plx
            sta   UpCurH,x
            phx
            lda   UpX,x
            ldy   PC
            jsr   MulS
            sta   fk
            plx
            phx
            lda   UpY,x
            ldy   PD
            jsr   MulS
            clc
            adc   fk
            ldx   #13
            jsr   SDiv
            clc
            adc   #60
            plx
            sta   UpCurV,x
            inx
            inx
            cpx   #28
            bcc   :pt
            pea   2
            pea   1
            Tool  _SetPenSize
            pea   0
            Tool  _SetPenMode
            lda   Erase
            beq   :draw
            pea   $FFFF
            Tool  _SetSolidPenPat
            ldx   #UpOldH-UpCurH
            jsr   Walk
:draw       pea   1
            Tool  _SetSolidPenPat
            ldx   #0
            jsr   Walk
            Tool  _PenNormal
            rts

* Walk: the shape through the points (UpCurH + X: the current or old ones).
Walk        stx   fu
            ldx   #0
:pt         phx
            txa
            clc
            adc   fu
            tay
            lda   UpCurH,y
            pha
            lda   UpCurV,y
            pha
            lda   UpFlag,x
            beq   :line
            Tool  _MoveTo
            bra   :next
:line       Tool  _LineTo
:next       plx
            inx
            inx
            cpx   #28
            bcc   :pt
            rts

* MulS: A x Y, A small (-4 to 4).
MulS        sty   ft
            tax
            lda   #0
            cpx   #0
            beq   :done
            bmi   :neg
:pos        clc
            adc   ft
            dex
            bne   :pos
            rts
:neg        sec
            sbc   ft
            inx
            bne   :neg
:done       rts

*-------------------------------------------------------------
* True color image info
*-------------------------------------------------------------

* FilterInfo: the True color image info dialog (the image: tp, tstride,
* rw, rh).
FilterInfo  ent
            phb
            phk
            plb
            tdc
            sta   FxDP
            jsr   CountColors
            lda   rw                    ; ^0, ^1: the size
            ldx   #ParW
            jsr   ParNum
            lda   rh
            ldx   #ParH
            jsr   ParNum
            lda   Distinct              ; ^2: the distinct colours, 4 wide
            pha
            pea   ^ParD
            pea   ParD+1
            pea   4
            pea   0
            Tool  _Int2Dec
            lda   #4
            sep   #$20
            mx    %10
            sta   ParD
            rep   #$20
            mx    %00
            PushLong ParW
            PushLong ParH
            PushLong ParD
            ldx   DistKind
            lda   DistTx,x
            pea   ^TxFull
            pha
            Tool  _ParamText
            pha
            pha
            PushLong InfoTmpl
            Tool  _GetNewModalDialog
            pla
            sta   Dlg
            pla
            sta   Dlg+2
:loop       pha
            PushLong 0
            Tool  _ModalDialog
            pla
            cmp   #1
            beq   :done
            cmp   #2
            bne   :loop
            Tool  _SysBeep              ; (Print: not in this version)
            bra   :loop
:done       PushLongAt Dlg
            Tool  _CloseDialog
            plb
            rtl

* ParNum: the number A as a Pascal string at X (as many digits as it needs).
ParNum      stx   fu
            pha                         ; (five wide, then the spaces dropped)
            pea   ^ParW
            txa
            inc
            pha
            pea   5
            pea   0
            Tool  _Int2Dec
            ldx   fu
            ldy   #0
:sp         lda   |1,x
            and   #$00FF
            cmp   #' '
            bne   :got
            inx
            iny
            cpy   #4
            bcc   :sp
:got        sty   fs
            lda   #5
            sec
            sbc   fs
            sta   fs                    ; the digits
            ldy   fu
            sep   #$20
            mx    %10
            sta   |0,y
:mv         lda   |1,x
            sta   |1,y
            inx
            iny
            dec   fs
            bne   :mv
            rep   #$20
            mx    %00
            rts

* CountColors: Counts = how many pixels have each 12-bit colour (the top
* four bits of each channel; at most $FFFF), Distinct, DistKind (0 full
* color, 2 grayscale, 4 B & W only). With 20 rows or more, the progress
* dialog says so.
CountColors ldx   #0
:clr        stz   Counts,x
            inx
            inx
            cpx   #8192
            bcc   :clr
            lda   rh
            cmp   #20
            bcc   :quiet
            lda   #TxCount
            jsr   ProgOpen
:quiet      lda   tp
            sta   RowP
            lda   tp+2
            sta   RowP+2
            stz   RowY
:row        ldy   #0
:pix        lda   [RowP],y              ; R
            and   #$00F0
            asl
            asl
            asl
            asl
            sta   fs
            iny
            lda   [RowP],y              ; G
            and   #$00F0
            tsb   fs
            iny
            lda   [RowP],y              ; B
            and   #$00F0
            lsr
            lsr
            lsr
            lsr
            ora   fs
            asl
            tax
            lda   Counts,x
            inc
            beq   :full
            sta   Counts,x
:full       iny
            cpy   tstride
            bcc   :pix
            lda   RowY
            jsr   ProgRow
            jsr   NextRow
            bcc   :row
            jsr   ProgClose
            stz   Distinct              ; the distinct colours
            ldx   #0
:d          lda   Counts,x
            beq   :none
            inc   Distinct
:none       inx
            inx
            cpx   #8192
            bcc   :d
            stz   DistKind              ; the distribution
            lda   Distinct
            cmp   #17
            bcs   :kind
            ldx   #0                    ; colours other than black and white
            ldy   #0
:bw         lda   Counts,x
            beq   :nbw
            cpx   #0
            beq   :nbw
            cpx   #$FFF*2
            beq   :nbw
            iny
:nbw        inx
            inx
            cpx   #8192
            bcc   :bw
            cpy   #0
            bne   :greys
            lda   #4
            sta   DistKind
            bra   :kind
:greys      ldx   #$111*2               ; and other than greys
:g          lda   Counts,x
            beq   :ng
            dey
:ng         txa
            clc
            adc   #$111*2
            tax
            cpx   #$FFF*2
            bcc   :g
            cpy   #0
            bne   :kind
            lda   #2
            sta   DistKind
:kind       rts

* DrawGraph: the dialog's graph item (the Dialog Manager calls it with the
* dialog and the item's ID, which it leaves to us to remove).
DrawGraph   phb
            phk
            plb
            phd
            lda   FxDP
            tcd
            Tool  _WaitCursor
            PushLong GraphRect
            Tool  _EraseRect
            pea   2                     ; the axes
            pea   1
            Tool  _SetPenSize
            pea   0
            Tool  _SetSolidPenPat
            pea   230
            pea   5
            Tool  _MoveTo
            pea   230
            pea   140
            Tool  _LineTo
            pea   588
            pea   140
            Tool  _LineTo
            pea   220
            pea   135
            Tool  _MoveTo
            pea   230
            pea   135
            Tool  _LineTo
            ldx   #0                    ; "^FREQUENCY", down the side
:f          phx
            pea   210
            txa
            asl
            asl
            asl
            clc
            adc   #30
            pha
            Tool  _MoveTo
            plx
            phx
            lda   TxFreq,x
            and   #$00FF
            pha
            Tool  _DrawChar
            plx
            inx
            cpx   #10
            bcc   :f
            pea   210
            pea   139
            Tool  _MoveTo
            pea   '0'
            Tool  _DrawChar
            ldx   #0                    ; the intensities 0-F
:x          phx
            txa
            asl
            sta   fs
            asl
            asl
            asl
            sec
            sbc   fs                    ; 22 k = 16 k + 8 k - 2 k
            sta   fs
            txa
            asl
            asl
            asl
            asl
            clc
            adc   fs
            clc
            adc   #245
            sta   fk
            pha
            pea   140
            Tool  _MoveTo
            lda   fk
            pha
            pea   144
            Tool  _LineTo
            lda   fk
            sec
            sbc   #3
            pha
            pea   153
            Tool  _MoveTo
            plx
            phx
            lda   HexDig,x
            and   #$00FF
            pha
            Tool  _DrawChar
            plx
            inx
            cpx   #16
            bcc   :x
            pea   370
            pea   164
            Tool  _MoveTo
            PushLong TxIntens
            Tool  _DrawString
            jsr   Bins
            lda   #0                    ; red, green, blue
            jsr   Line
            lda   #1
            jsr   Line
            lda   #2
            jsr   Line
            Tool  _PenNormal
            Tool  _InitCursor
            pld
            plb
            lda   2,s                   ; drop the parameters (6 bytes)
            sta   8,s
            lda   1,s
            sta   7,s
            tsc
            clc
            adc   #6
            tcs
            rtl

* Bins: Bin = 16 sums for each channel (red, green, blue) of the colours'
* counts by that channel's four bits; Scale = pixels / 200 (at least 1).
Bins        ldx   #0
:clr        stz   Bin,x
            inx
            inx
            cpx   #192
            bcc   :clr
            ldx   #0                    ; colour $RGB
:c          lda   Counts,x
            beq   :next
            sta   fs
            txa
            lsr
            sta   fu                    ; the colour
            xba                         ; red: bits 11-8
            and   #$000F
            ldy   #0
            jsr   AddBin
            lda   fu                    ; green
            lsr
            lsr
            lsr
            lsr
            and   #$000F
            ldy   #64
            jsr   AddBin
            lda   fu                    ; blue
            and   #$000F
            ldy   #128
            jsr   AddBin
:next       inx
            inx
            cpx   #8192
            bcc   :c
            lda   rw                    ; pixels / 200
            ldx   rh
            jsr   Mul32
            lda   #200
            sta   fd
            stz   fd+2
            jsr   Div32
            lda   fn
            ora   fn+2
            bne   :s
            inc   fn
:s          lda   fn
            sta   Scale
            lda   fn+2
            sta   Scale+2
            rts
AddBin      phx                         ; Bin[Y/4 + A] += fs (32 bits)
            asl
            asl
            sta   ft
            tya
            clc
            adc   ft
            tax
            lda   Bin,x
            clc
            adc   fs
            sta   Bin,x
            bcc   :ok
            inc   Bin+2,x
:ok         plx
            rts

* Line: channel A's line: pen pattern, size and offset as SuperConvert's.
Line        sta   fk
            asl
            tax
            lda   LinePat,x
            pea   ^PatRed
            pha
            Tool  _SetPenPat
            ldx   fk
            lda   LineW,x
            and   #$00FF
            pha
            lda   LineH,x
            and   #$00FF
            pha
            Tool  _SetPenSize
            stz   fu                    ; the bin
:k          lda   fk                    ; y = 133 - bin / Scale + dy
            asl
            asl
            asl
            asl
            asl
            asl
            sta   ft
            lda   fu
            asl
            asl
            clc
            adc   ft
            tax
            lda   Bin,x
            sta   fn
            lda   Bin+2,x
            sta   fn+2
            lda   Scale
            sta   fd
            lda   Scale+2
            sta   fd+2
            jsr   Div32
            ldx   fk
            lda   LineD,x
            and   #$00FF
            clc
            adc   #133
            sec
            sbc   fn
            sta   ft                    ; y
            lda   fu                    ; x = 240 + 22 k + dx
            asl
            sta   fs
            asl
            asl
            asl
            sec
            sbc   fs
            sta   fs
            lda   fu
            asl
            asl
            asl
            asl
            clc
            adc   fs
            clc
            adc   #240
            sta   fs
            ldx   fk
            lda   LineDx,x
            and   #$00FF
            clc
            adc   fs
            pha
            lda   ft
            pha
            lda   fu
            bne   :to
            Tool  _MoveTo
            bra   :more
:to         Tool  _LineTo
:more       inc   fu
            lda   fu
            cmp   #16
            bcs   :jx1
            jmp   :k
:jx1
            rts

*-------------------------------------------------------------
* The progress dialog (the filters, and counting colours)
*-------------------------------------------------------------

* ProgOpen: the progress dialog with the message at A (a Pascal string
* in this bank), in the middle of the screen, an apple to fill.
ProgOpen    sta   ProgText
            pha                         ; the width: the message's + 90
            pea   ^TxCount
            lda   ProgText
            pha
            Tool  _StringWidth
            pla
            clc
            adc   #90
            sta   fs
            lda   #640
            sec
            sbc   fs
            lsr
            and   #$FFFE
            sta   ProgTmpl+2            ; left, right
            clc
            adc   fs
            sta   ProgTmpl+6
            pea   ^TxCount              ; ^0: the message
            lda   ProgText
            pha
            PushLong 0
            PushLong 0
            PushLong 0
            Tool  _ParamText
            pha
            pha
            PushLong ProgTmpl
            Tool  _GetNewModalDialog
            pla
            sta   ProgDlg
            pla
            sta   ProgDlg+2
            PushLongAt ProgDlg
            Tool  _DrawDialog
            Tool  _WaitCursor
            lda   #1
            sta   ProgOn
            stz   ProgLast
            rts

* ProgRow: row A of rh done: the apple filled to (A x 32) / rh.
*   out: carry set if Command-period was typed (a filter stops)
ProgRow     ldx   ProgOn
            bne   :on
            clc
            rts
:on         sta   fn                    ; row x 32 (32 bits)
            stz   fn+2
            ldy   #5
:x32        asl   fn
            rol   fn+2
            dey
            bne   :x32
            lda   rh
            sta   fd
            stz   fd+2
            jsr   Div32
            lda   fn
            cmp   ProgLast
            beq   :same
            sta   ProgLast
            pha
            PushLongAt ProgDlg
            pea   1
            Tool  _SetDItemValue
:same       pha                         ; Command-period?
            pea   $0408                 ; (as SuperConvert asks)
            PushLong ProgEvent
            Tool  _GetNextEvent
            pla
            beq   :no
            lda   ProgEvent+2
            and   #$007F
            cmp   #'.'
            bne   :no
            lda   ProgEvent+14
            and   #$0100
            beq   :no
            sec
            rts
:no         clc
            rts

* ProgClose: the progress dialog gone.
ProgClose   lda   ProgOn
            beq   :off
            stz   ProgOn
            PushLongAt ProgDlg
            Tool  _CloseDialog
            Tool  _InitCursor
:off        rts

* DrawApple: the progress item (as DrawGraph: the dialog and the item).
DrawApple   phb
            phk
            plb
            phd
            lda   FxDP
            tcd
            pha                         ; its value: 0 the empty apple
            PushLongAt ProgDlg
            pea   1
            Tool  _GetDItemValue
            pla
            ldx   #AppleFull
            cmp   #0
            bne   :v
            ldx   #AppleEmpty
            lda   #32
:v          stx   AppleLoc+2
            sta   fs
            lda   #32                   ; from row 32 - v down
            sec
            sbc   fs
            bpl   :t
            lda   #0
:t          sta   AppleSrc
            sta   fk
            PushLong AppleLoc
            PushLong AppleSrc
            pea   10                    ; (the item's box: 5,10)
            lda   fk
            clc
            adc   #5
            pha
            pea   0
            Tool  _PPToPort
            pld
            plb
            lda   2,s
            sta   8,s
            lda   1,s
            sta   7,s
            tsc
            clc
            adc   #6
            tcs
            rtl

*-------------------------------------------------------------
* Data
*-------------------------------------------------------------
FxDP        dw    0                     ; our direct page (for the call-backs)
Dlg         adrl  0
TooBig      dw    0
TurnBits    dw    0
Ma          dw    1                     ; M = [a b; c d]
Mb          dw    0
Mc          dw    0
Md          dw    1
PA          dw    100                   ; the preview's
PB          dw    0
PC          dw    0
PD          dw    100
Erase       dw    0
Step        dw    0
Cos         dw    100,98,94,87,77,64,50,34,17,0,-17,-34,-50,-64,-77,-87,-94,-98,-100
Sin         dw    0,17,34,50,64,77,87,94,98,100
* The "UP" shape: move (1) or line (0) to (x, y); where it is now and before.
UpFlag      dw    1,0,0,0,0,1,0,0,0,1,0,0,0,0
UpX         dw    -4,4,4,-4,-4,-3,-3,-1,-1,1,1,3,3,1
UpY         dw    -3,-3,3,3,-3,-2,2,2,-2,2,-2,-2,0,0
UpCurH      ds    28
UpCurV      ds    28
UpOldH      ds    28
UpOldV      ds    28

* The Rotate/flip dialog (SuperConvert's template).
RotTmpl     dw    40,100,160,560
            dw    1
            adrl  0
            adrl  RotI1,RotI2,RotI3,RotI4,RotI5,RotI6,RotI7,RotI8,RotI16,0
RotI1       dw    1,95,340,110,450,10
            adrl  TxMake
            dw    0,0
            adrl  0
RotI2       dw    2,75,340,90,450,10
            adrl  TxCancel
            dw    0,0
            adrl  0
RotI3       dw    3,5,60,18,150,10
            adrl  TxRotL
            dw    0,0
            adrl  0
RotI4       dw    4,5,170,18,260,10
            adrl  TxRotR
            dw    0,0
            adrl  0
RotI5       dw    5,102,115,115,205,10
            adrl  TxFlipV
            dw    0,0
            adrl  0
RotI6       dw    6,54,265,67,355,10
            adrl  TxFlipH
            dw    0,0
            adrl  0
RotI7       dw    7,92,10,105,100,10
            adrl  TxTwistA
            dw    0,0
            adrl  0
RotI8       dw    8,92,220,105,310,10
            adrl  TxTwistB
            dw    0,0
            adrl  0
RotI16      dw    16,5,280,55,450,$800F
            adrl  TxTooBig
            dw    0,$0080
            adrl  0
TxMake      str   'Make it so'
TxRotL      str   '<< Rotate'
TxRotR      str   'Rotate >>'
TxFlipV     str   '\/ Flip \/'
TxFlipH     str   '> Flip >'
TxTwistA    str   '// Twist'
TxTwistB    str   'Twist \\'
TxTooBig    str   'The image is too big to',0D,'be rotated or twisted.',0D,'Only flips are allowed.'

* The True color image info dialog (SuperConvert's template).
InfoTmpl    dw    20,20,190,620
            dw    $FFFF
            adrl  0
            adrl  InfI15,InfI1,InfI2,InfI8,0
InfI15      dw    15,0,210,165,590,$8014
            adrl  DrawGraph
            dw    16,0
            adrl  0
InfI1       dw    1,152,30,165,150,10
            adrl  TxDone
            dw    0,0
            adrl  0
InfI2       dw    2,130,40,143,140,10
            adrl  TxPrint
            dw    0,0
            adrl  0
InfI8       dw    8,5,10,50,190,$8016
            adrl  TxInfo
            dw    TxInfoEnd-TxInfo,0
            adrl  0
TxDone      str   'Done'
TxPrint     str   'Print'
TxInfo      asc   'Image size: ^0 by ^1 ',0D,'Distinct colors: ^2 ',0D,'Distribution: ^3 '
            asc   0D,0D,0D,0D,0D,0D,'Color histograms:'
TxInfoEnd
DistTx      da    TxFull,TxGrey,TxBW
TxFull      str   'full color'
TxGrey      str   'grayscale'
TxBW        str   'B & W only'
ParW        ds    8
ParH        ds    8
ParD        ds    8
Distinct    dw    0
DistKind    dw    0
GraphRect   dw    0,210,165,590
TxFreq      asc   '^FREQUENCY'
HexDig      asc   '0123456789ABCDEF'
TxIntens    str   'INTENSITY >'
Scale       adrl  0
Bin         ds    192                   ; 16 x 3 sums (32 bits)
LinePat     da    PatRed,PatGreen,PatBlue
LineW       db    12,8,4
LineH       db    6,4,2
LineD       db    0,1,2                 ; dy
LineDx      db    0,2,4                 ; dx
PatRed      hex   4444444444444444444444444444444444444444444444444444444444444444
PatGreen    hex   AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
PatBlue     hex   DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD
Counts      ds    8192                  ; pixels of each 12-bit colour

* The progress dialog: one line (SuperConvert's template, its rect set
* for the message).
ProgTmpl    dw    79,0,121,0
            dw    $FFFF
            adrl  0
            adrl  ProgI1,ProgI16,0
ProgI1      dw    1,5,10,37,74,$8014
            adrl  DrawApple
            dw    0,0
            adrl  0
ProgI16     dw    16,17,80,27,500,$800F
            adrl  TxParam0
            dw    0,0
            adrl  0
TxParam0    str   '^0 '
ProgText    dw    0
ProgDlg     adrl  0
ProgOn      dw    0
ProgLast    dw    0
ProgEvent   dw    0                     ; (an event record)
            adrl  0
            adrl  0
            dw    0,0
            dw    0
AppleLoc    dw    $0080
            adrl  AppleFull
            dw    16
            dw    0,0,32,64
AppleSrc    dw    0,0,32,64
TxCount     str   'Counting colors used, please wait'
