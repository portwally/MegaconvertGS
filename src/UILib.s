*-------------------------------------------------------------
* UILib.s - drawing in SuperConvert's style, for the dialogs and windows
* (put into each segment that draws them): text, buttons, radio buttons,
* check boxes, runs of pixels and shapes made of them, greying out.
* The texts drawn must be in the same bank as this code.
*-------------------------------------------------------------

* GreyBox: what is drawn in Box greyed out (every other pixel white).
GreyBox     pea   1                     ; OR
            Tool  _SetPenMode
            PushLong GreyPat
            Tool  _SetPenPat
            PushLong Box
            Tool  _PaintRect
            Tool  _PenNormal
            rts

* Radio: a radio button with its top left at X, Y; marked if A <> 0.
Radio       stx   ShX
            sty   ShY
            sta   t3
            ldx   #RadioRing
            jsr   Shape
            lda   t3
            beq   :done
            ldx   #RadioDot
            jsr   Shape
:done       rts

* Checkbox: a check box with its top left at X, Y; crossed if A <> 0.
Checkbox    stx   ShX
            sty   ShY
            sta   t3
            ldx   #BoxFrame
            jsr   Shape
            lda   t3
            beq   :done
            ldx   #BoxCross
            jsr   Shape
:done       rts

* Shape: runs at X (bytes: row, first and last pixel, from ShY and ShX;
* $FF ends them).
Shape       stx   t0
            ldy   #0
:run        lda   (t0),y
            and   #$00FF
            cmp   #$00FF
            beq   :done
            clc
            adc   ShY
            sta   RunY
            iny
            lda   (t0),y
            and   #$00FF
            clc
            adc   ShX
            sta   RunA
            iny
            lda   (t0),y
            and   #$00FF
            clc
            adc   ShX
            sta   RunB
            iny
            phy
            jsr   DrawRun
            ply
            bra   :run
:done       rts

* Runs: runs at X (words: row, first and last pixel; $FFFF ends them).
Runs        lda   |0,x
            cmp   #$FFFF
            beq   :done
            sta   RunY
            lda   |2,x
            sta   RunA
            lda   |4,x
            sta   RunB
            phx
            jsr   DrawRun
            plx
            txa
            clc
            adc   #6
            tax
            bra   Runs
:done       rts

* DrawRun: pixels RunA to RunB of row RunY, with the pen.
DrawRun     lda   RunA
            pha
            lda   RunY
            pha
            Tool  _MoveTo
            lda   RunB
            pha
            lda   RunY
            pha
            Tool  _LineTo
            rts

* Button: the button whose rect is at X (11 or 13 lines tall), with the
* text at A in the middle.
Button      sta   BTxt
            stx   BRect2
            lda   |4,x
            sec
            sbc   |0,x
            cmp   #12
            bcs   :tall
            lda   #End11
            ldy   #9                    ; (baseline: from the top)
            bra   :frame
:tall       lda   #End13
            ldy   #10
:frame      sty   BBase
            ldy   #6
            jsr   BtnFrame
            pha                         ; the text, in the middle
            pea   ^UIBank
            lda   BTxt
            pha
            Tool  _CStringWidth
            pla
            sta   t3
            ldx   BRect2
            lda   |2,x
            clc
            adc   |6,x
            sec
            sbc   t3
            lsr
            pha
            lda   |0,x
            clc
            adc   BBase
            pha
            Tool  _MoveTo
            pea   ^UIBank
            lda   BTxt
            pha
            Tool  _DrawCString
            rts

* BtnFrame: the outline of the button whose rect is at X: A = its ends
* (rows of runs from its corners in), Y = how far in the top and bottom
* lines start.
BtnFrame    sta   t0
            sty   t1
            lda   |0,x
            sta   BTop
            lda   |2,x
            sta   BLeft
            lda   |4,x
            dec
            sta   BBot
            lda   |6,x
            dec
            sta   BRight
            lda   BLeft                 ; top and bottom lines
            clc
            adc   t1
            sta   RunA
            lda   BRight
            sec
            sbc   t1
            sta   RunB
            lda   BTop
            sta   RunY
            jsr   DrawRun
            lda   BBot
            sta   RunY
            jsr   DrawRun
            ldy   #0                    ; the ends
:end        lda   (t0),y
            and   #$00FF
            cmp   #$00FF
            beq   :done
            clc
            adc   BTop
            sta   RunY
            iny
            lda   (t0),y
            and   #$00FF
            sta   t1
            iny
            lda   (t0),y
            and   #$00FF
            sta   t2
            iny
            phy
            lda   BLeft
            clc
            adc   t1
            sta   RunA
            lda   BLeft
            clc
            adc   t2
            sta   RunB
            jsr   DrawRun
            lda   BRight
            sec
            sbc   t2
            sta   RunA
            lda   BRight
            sec
            sbc   t1
            sta   RunB
            jsr   DrawRun
            ply
            bra   :end
:done       rts

* Heading: the text at A at h = X, v = Y, in bold.
Heading     sta   BTxt
            stx   t2
            sty   RBase
            pea   1
            Tool  _SetTextFace
            lda   BTxt
            ldx   t2
            ldy   RBase
            jsr   TextAt
            pea   0
            Tool  _SetTextFace
            rts

* TextAt: the text at A at h = X, v = Y.
TextAt      sta   t0
            phx
            phy
            Tool  _MoveTo
            pea   ^UIBank
            lda   t0
            pha
            Tool  _DrawCString
            rts

* DrawSize: SizeTxt at h = X, v = Y.
DrawSize    lda   #SizeTxt
            jmp   TextAt

* SizeWidth: A = how wide SizeTxt is drawn.
SizeWidth   pha
            PushLong SizeTxt
            Tool  _CStringWidth
            pla
            rts

* AddTx: the C string at A onto SizeTxt.
AddTx       sta   t0
            ldy   #0
            ldx   SizeLen
            sep   #$20
            mx    %10
:c          lda   (t0),y
            sta   SizeTxt,x
            beq   :end
            iny
            inx
            bra   :c
:end        rep   #$20
            mx    %00
            stx   SizeLen
            rts

* AddDec: A in decimal onto SizeTxt.
AddDec      ldx   #0
:digit      sta   n0
            stz   n0+2
            phx
            lda   #10
            jsr   Div32
            plx
            lda   DvR
            clc
            adc   #'0'
            pha
            inx
            lda   DvQ
            bne   :digit
            ldy   SizeLen
:out        pla
            sep   #$20
            mx    %10
            sta   SizeTxt,y
            rep   #$20
            mx    %00
            iny
            dex
            bne   :out
            lda   #0
            sta   SizeTxt,y
            sty   SizeLen
            rts

* HLine: a line across at v = A, from h = X to h = Y.
HLine       sta   RunY
            stx   RunA
            sty   RunB
            jmp   DrawRun

* ThumbBox: Box as a scroll box: white, framed.
ThumbBox    PushLong Box
            Tool  _EraseRect
            pea   2
            pea   1
            Tool  _SetPenSize
            PushLong Box
            Tool  _FrameRect
            Tool  _PenNormal
            rts

* Shapes: rows of runs (row, first, last) from the top left.
RadioRing   db    0,6,14,1,3,5,1,15,17,2,1,2,2,18,19,3,0,1,3,19,20
            db    4,0,1,4,19,20,5,0,1,5,19,20,6,1,2,6,18,19,7,3,5,7,15,17
            db    8,6,14,$FF
RadioDot    db    2,7,13,3,5,15,4,4,16,5,5,15,6,7,13,$FF
BoxFrame    db    0,0,22,1,0,1,1,21,22,2,0,1,2,21,22,3,0,1,3,21,22,4,0,1,4,21,22
            db    5,0,1,5,21,22,6,0,1,6,21,22,7,0,1,7,21,22,8,0,22,$FF
BoxCross    db    1,0,3,1,19,22,2,4,6,2,16,18,3,7,9,3,13,15,4,10,12
            db    5,7,9,5,13,15,6,4,6,6,16,18,7,0,3,7,19,22,$FF
* A button's ends (row, first, last from its side), for 11 and 13 lines;
* and the ring around the button Return presses.
End11       db    1,3,6,2,1,3,3,0,2,4,0,2,5,0,2,6,0,2,7,0,2,8,1,3,9,3,6,$FF
End13       db    1,3,6,2,1,3,3,0,2,4,0,2,5,0,2,6,0,2,7,0,2,8,0,2,9,0,2
            db    10,1,3,11,3,6,$FF
EndRing     db    1,6,10,2,3,6,3,2,4,4,1,3,5,0,2,6,0,2,7,0,2,8,0,2,9,0,2
            db    10,0,2,11,0,2,12,1,3,13,2,4,14,3,6,15,6,10,$FF

* Pen patterns (640 mode: 4 pixels a byte, 2 bytes a line): every other
* column dark (scroll bars' tracks), every other pixel white (with OR:
* greyed out), and pixel values 1 and 2 (purple, and yellow and green).
Stripes     hex   CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC
GreyPat     hex   3333CCCC3333CCCC3333CCCC3333CCCC3333CCCC3333CCCC3333CCCC3333CCCC
Purple      hex   5555555555555555555555555555555555555555555555555555555555555555
YelGreen    hex   AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA

UIBank      =     *                     ; (this segment's bank, for the texts)
Box         dw    0,0,0,0
BTxt        dw    0
BRect2      dw    0
BBase       dw    0
BTop        dw    0
BLeft       dw    0
BBot        dw    0
BRight      dw    0
ShX         dw    0
ShY         dw    0
RunY        dw    0
RunA        dw    0
RunB        dw    0
SizeLen     dw    0
SizeTxt     ds    80
RBase       dw    0
