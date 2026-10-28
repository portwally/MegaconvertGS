*-------------------------------------------------------------
* View.s - the full-screen views, as SuperConvert's (a segment of
* its own; docs/superconvert-image-window.md section 10): View full
* screen, View half size, View X4 magnified (Screen menu) and View
* approximation (True color menu). Each draws straight into the
* Super Hi-Res screen, waits for a click or a key (X4 and the
* approximation follow the mouse meanwhile), and puts the desktop
* back as it was.
*
* In: scrp, pw, ph, p640 (the screen image), tp, tstride, rw, rh (the
* true colour image), uid.
*-------------------------------------------------------------
            rel
            mx    %00
            use   macros/Macs.s
            put   Equates.s

vs          =     $D0                   ; the screen ($E1/2000, long)
vp          =     $D4                   ; the picture (long)
vw0         =     $D8                   ; work words
vw1         =     $DA
vw2         =     $DC
vw3         =     $DE
vw4         =     $E0
vw5         =     $E2
vw6         =     $E4
vw7         =     $E6

* ViewRun: view A: 0 full screen, 1 half size, 2 X4 magnified, 3 the
* true colour approximation.   out: carry set and A = error (no memory)
ViewRun     ent
            phb
            phk
            plb
            sta   Kind
            jsr   Begin
            bcs   :out
            lda   Kind
            asl
            tax
            jsr   (Views,x)
            jsr   End
            clc
:out        plb
            rtl
Views       da    Full,Half,X4,Approx

* Begin: the desktop's pixels, SCBs and colours kept; the pointer hidden.
Begin       pha
            pha
            pea   0
            pea   $8000
            lda   uid
            pha
            pea   attrBuffer
            PushLong 0
            Tool  _NewHandle
            pla
            sta   KeepH
            pla
            sta   KeepH+2
            bcc   :ok
            rts
:ok         lda   KeepH
            sta   vp
            lda   KeepH+2
            sta   vp+2
            lda   [vp]
            tax
            ldy   #2
            lda   [vp],y
            sta   KeepP+2
            stx   KeepP
            jsr   ScreenP
            lda   KeepP
            sta   vp
            lda   KeepP+2
            sta   vp+2
            ldy   #$7FFE
:keep       lda   [vs],y
            sta   [vp],y
            dey
            dey
            bpl   :keep
            Tool  _HideCursor
            pha                         ; earlier clicks and keys forgotten
            pea   $FFFF
            pea   0
            Tool  _FlushEvents
            pla
            jsr   Picture               ; vp: the screen image
            clc
            rts

* End: the desktop back.
End         jsr   ScreenP
            lda   KeepP
            sta   vp
            lda   KeepP+2
            sta   vp+2
            ldy   #$7FFE
:back       lda   [vp],y
            sta   [vs],y
            dey
            dey
            bpl   :back
            PushLongAt KeepH
            Tool  _DisposeHandle
            Tool  _ShowCursor
            rts

ScreenP     lda   #$2000
            sta   vs
            lda   #$00E1
            sta   vs+2
            rts
Picture     lda   scrp
            sta   vp
            lda   scrp+2
            sta   vp+2
            lda   pw                    ; the screen image's bytes a line
            lsr
            ldx   p640
            beq   :b
            lsr
:b          sta   Bytes
            lda   ph
            sta   Lines
            rts

* Wait: until a click or a key. Out: carry clear. WaitMove: also, while
* waiting, the routine at Mover runs whenever the mouse moves.
Wait        stz   Mover
WaitMove    lda   #$FFFF
            sta   LastH
:loop       lda   Mover
            beq   :ev
            jsr   Mouse
            lda   MouseH
            cmp   LastH
            bne   :moved
            lda   MouseV
            cmp   LastV
            beq   :ev
:moved      lda   MouseH
            sta   LastH
            lda   MouseV
            sta   LastV
            jsr   CallMover
:ev         pha
            pea   $002A                 ; mouse down, key down, auto-key
            PushLong Event
            Tool  _GetNextEvent
            pla
            beq   :loop
            lda   Event                 ; a key typed with Apple: its menu
            cmp   #3                    ; command runs afterwards
            bcc   :done
            lda   Event+14
            and   #$0100
            beq   :done
            pha
            pea   3
            lda   Event+4
            pha
            lda   Event+2
            pha
            Tool  _PostEvent
            pla
:done       rts
CallMover   ldx   #0                    ; (indexed: the pointer is in this bank)
            jmp   (Mover,x)

* Mouse: MouseH, MouseV: the pointer on the screen (0-639, 0-199).
Mouse       pha
            pha
            Tool  _GetMenuMgrPort
            Tool  _SetPort
            PushLong MouseV
            Tool  _GetMouse
            rts

* Fill: the screen's pixels $F0F0 on even lines, $0F0F on odd ones.
Fill        ldx   #0
            ldy   #0
:line       txa
            and   #1
            beq   :even
            lda   #$0F0F
            bra   :put
:even       lda   #$F0F0
:put        sta   vw0
            phx
            ldx   #80
:word       lda   vw0
            sta   [vs],y
            iny
            iny
            dex
            bne   :word
            plx
            inx
            cpx   #200
            bcc   :line
            rts

* Colours: the picture's 16 colour tables into the screen's.
Colours     ldy   #palOffset
:c          lda   [vp],y
            sta   [vs],y
            iny
            iny
            cpy   #$8000
            bcc   :c
            rts

*-------------------------------------------------------------
* View full screen
*-------------------------------------------------------------
Full        jsr   Colours
            ldy   #scbOffset            ; every line the first line's mode
            lda   [vp],y
            and   #$00FF
            sta   vw0
            xba
            ora   vw0
            ldy   #scbOffset
:scb        sta   [vs],y
            iny
            iny
            cpy   #scbOffset+200
            bcc   :scb
            lda   Bytes                 ; a smaller picture: the rest filled
            cmp   #160
            bcc   :fill
            lda   Lines
            cmp   #200
            bcs   :copy
:fill       jsr   Fill
:copy       ldx   #0                    ; its lines, with their own modes
            stz   vw1                   ; (line offset)
:line       ldy   vw1
            phx
            ldx   Bytes
            sep   #$20
            mx    %10
:b          lda   [vp],y
            sta   [vs],y
            iny
            dex
            bne   :b
            rep   #$20
            mx    %00
            plx
            txy
            jsr   SetScb                ; (its mode and table too)
            lda   vw1
            clc
            adc   #160
            sta   vw1
            inx
            cpx   Lines
            bcc   :line
            jmp   Wait

* SetScb: the screen's SCB of line X = the picture's of line X (Y = X).
SetScb      phy
            tya
            clc
            adc   #scbOffset
            tay
            sep   #$20
            mx    %10
            lda   [vp],y
            sta   [vs],y
            rep   #$20
            mx    %00
            ply
            rts

*-------------------------------------------------------------
* View half size
*-------------------------------------------------------------
Half        jsr   Fill                  ; the background: ..##..## / ##..##..
            jsr   Curve
            ldy   #scbOffset            ; every line the first line's SCB,
            lda   [vp],y                ; then line i the picture's line 2i
            and   #$00FF
            sta   vw0
            xba
            ora   vw0
:all        sta   [vs],y
            iny
            iny
            cpy   #scbOffset+200
            bcc   :all
            lda   Lines
            dec
            lsr
            inc
            sta   vw2                   ; (lines - 1) / 2 + 1 lines
            ldx   #0
:scb        txa
            asl
            clc
            adc   #scbOffset
            tay
            sep   #$20
            mx    %10
            lda   [vp],y
            pha
            txa
            rep   #$20
            mx    %00
            and   #$00FF
            clc
            adc   #scbOffset
            tay
            sep   #$20
            mx    %10
            pla
            sta   [vs],y
            rep   #$20
            mx    %00
            inx
            cpx   vw2
            bcc   :scb
            jsr   Colours
            lda   Lines                 ; the picture at half size: every
            lsr                         ; other line and column (as 640 mode
            sta   vw2                   ; pixels), at the top left
            lda   Bytes
            and   #$FFFE
            lsr
            sta   vw3                   ; bytes a half line
            stz   vw4                   ; the line
:line       lda   vw4                   ; source: line 2y, dest: line y
            asl
            jsr   Times160
            sta   vw5
            lda   vw4
            jsr   Times160
            sta   vw6
            stz   vw7                   ; the dest byte
:byte       lda   vw7                   ; two source bytes: of each its
            asl                         ; pixels 0 and 2
            clc
            adc   vw5
            tay
            lda   [vp],y
            and   #$00FF
            tax
            lda   HalfHi,x
            and   #$00FF
            sta   vw0
            iny
            lda   [vp],y
            and   #$00FF
            tax
            lda   HalfHi,x
            and   #$00FF
            lsr
            lsr
            lsr
            lsr
            ora   vw0
            pha
            lda   vw6
            clc
            adc   vw7
            tay
            pla
            sep   #$20
            mx    %10
            sta   [vs],y
            rep   #$20
            mx    %00
            inc   vw7
            lda   vw7
            cmp   vw3
            bcc   :byte
            inc   vw4
            lda   vw4
            cmp   vw2
            bcc   :line
            jmp   Wait

* Times160: A x 160.
Times160    asl
            asl
            asl
            asl
            asl
            sta   vw0                   ; x 32
            asl
            asl                         ; x 128
            clc
            adc   vw0
            rts

* Curve: a black area in the lower right corner: on each line y from 100
* to 199, from x = 65535 / y to the right edge.
Curve       lda   #100
            sta   vw2
:line       lda   #$FFFF                ; 65535 / y
            ldx   vw2
            jsr   Div16
            cmp   #640
            bcs   :next
            sta   vw3                   ; the first black pixel
            lda   vw2
            jsr   Times160
            sta   vw4
            lda   vw3                   ; its byte
            lsr
            lsr
            clc
            adc   vw4
            tay
            lda   vw3                   ; the part of the byte from it on
            and   #3
            tax
            sep   #$20
            mx    %10
            lda   [vs],y
            and   KeepBits,x
            sta   [vs],y
            rep   #$20
            mx    %00
            iny
            lda   vw4
            clc
            adc   #160
            sta   vw5
:rest       cpy   vw5
            bcs   :next
            sep   #$20
            mx    %10
            lda   #0
            sta   [vs],y
            rep   #$20
            mx    %00
            iny
            bra   :rest
:next       inc   vw2
            lda   vw2
            cmp   #200
            bcc   :line
            rts
KeepBits    db    $00,$C0,$F0,$FC

* Div16: A / X (X not 0), the quotient in A.
Div16       sta   vw0
            stx   vw1
            stz   vw6
            stz   vw7
            ldx   #16
:bit        asl   vw0
            rol   vw7
            lda   vw7
            sec
            sbc   vw1
            bcc   :no
            sta   vw7
:no         rol   vw6
            dex
            bne   :bit
            lda   vw6
            rts

*-------------------------------------------------------------
* View X4 magnified
*-------------------------------------------------------------
X4          jsr   Colours
            ldy   #scbOffset            ; all lines 320 mode, table 0
            lda   #0
:scb        sta   [vs],y
            iny
            iny
            cpy   #scbOffset+200
            bcc   :scb
            lda   Bytes
            cmp   #40
            bcc   :fill
            lda   Lines
            cmp   #50
            bcs   :go
:fill       jsr   Fill
:go         lda   #$FFFF
            sta   Left
            lda   #X4Draw
            sta   Mover
            jsr   Mouse                 ; drawn once for where the pointer is
            jsr   X4Draw
            jmp   WaitMove

* X4Draw: 40 bytes x 50 lines of the picture, four times larger, the part
* the pointer says (dragging: the pointer in the middle shows the middle).
X4Draw      lda   Bytes                 ; left = bytes/2 + 160 - h/2 - 20
            lsr
            clc
            adc   #140
            sta   vw0
            lda   MouseH
            lsr
            sta   vw1
            lda   vw0
            sec
            sbc   vw1
            ldx   Bytes
            ldy   #40
            jsr   Limit
            sta   vw2
            lda   Lines                 ; top = lines/2 + 200 - 2v - 25
            lsr
            clc
            adc   #175
            sta   vw0
            lda   MouseV
            asl
            sta   vw1
            lda   vw0
            sec
            sbc   vw1
            ldx   Lines
            ldy   #50
            jsr   Limit
            sta   vw3
            cmp   Top                   ; only when it changed
            bne   :draw
            lda   vw2
            cmp   Left
            bne   :draw
            rts
:draw       lda   vw2
            sta   Left
            lda   vw3
            sta   Top
            stz   vw4                   ; the screen line group (0-49)
:line       lda   vw4
            clc
            adc   Top
            cmp   Lines
            bcc   :in
            rts
:in         sta   vw5                   ; the picture line
            jsr   Times160
            clc
            adc   Left
            sta   vw6                   ; its first byte
            lda   vw5                   ; its SCB: 320 mode, its table
            clc
            adc   #scbOffset
            tay
            lda   [vp],y
            and   #$008F
            sta   vw7                   ; (bit 7: 640 mode, for the bytes)
            lda   vw4                   ; the screen line: 4 x group
            asl
            asl
            jsr   Times160
            sta   vw0
            lda   vw4
            asl
            asl
            clc
            adc   #scbOffset
            tay
            lda   vw7
            and   #$000F
            sep   #$20
            mx    %10
            sta   [vs],y
            iny
            sta   [vs],y
            iny
            sta   [vs],y
            iny
            sta   [vs],y
            rep   #$20
            mx    %00
            ldx   #0                    ; 40 bytes, each 4
:byte       phx
            txa
            clc
            adc   vw6
            tay
            lda   [vp],y
            and   #$00FF
            asl
            asl
            sta   vw1
            lda   vw7
            and   #$0080
            beq   :b320
            ldx   vw1
            lda   X640A,x
            sta   vw1
            lda   X640A+2,x
            bra   :put
:b320       ldx   vw1
            lda   X320A,x
            sta   vw1
            lda   X320A+2,x
:put        sta   vw2
            plx
            phx
            txa
            asl
            asl
            clc
            adc   vw0                   ; the screen byte
            tay
            lda   vw1
            sta   [vs],y
            iny
            iny
            lda   vw2
            sta   [vs],y
            plx
            inx
            cpx   #40
            bcc   :byte
            ldy   vw0                   ; the line again three times
            lda   vw0
            clc
            adc   #160
            sta   vw1
            ldx   #80
:copy       lda   [vs],y
            phy
            pha
            tya
            clc
            adc   #160
            tay
            pla
            sta   [vs],y
            pha
            tya
            clc
            adc   #160
            tay
            pla
            sta   [vs],y
            pha
            tya
            clc
            adc   #160
            tay
            pla
            sta   [vs],y
            ply
            iny
            iny
            dex
            bne   :copy
            inc   vw4
            lda   vw4
            cmp   #50
            bcs   :done
            jmp   :line
:done       rts

* Limit: A (signed) kept to 0 .. X - Y (0 if X <= Y).
Limit       sta   vw0
            stx   vw1
            sty   vw6
            lda   vw1
            sec
            sbc   vw6
            bcc   :zero
            beq   :zero
            sta   vw1                   ; the largest
            lda   vw0
            bmi   :zero
            cmp   vw1
            bcc   :ok
            lda   vw1
:ok         rts
:zero       lda   #0
            rts

*-------------------------------------------------------------
* View approximation
*-------------------------------------------------------------
Approx      ldy   #palOffset            ; red, green and blue ramps
            ldx   #0
:pal        lda   RampR,x
            sta   [vs],y
            iny
            iny
            inx
            inx
            cpx   #96
            bcc   :pal
            ldx   #0                    ; lines: red, green, blue, black
:scb        txa
            and   #3
            asl
            tay
            lda   ScbOf4,y
            pha
            txa
            clc
            adc   #scbOffset
            tay
            pla
            sep   #$20
            mx    %10
            sta   [vs],y
            rep   #$20
            mx    %00
            inx
            cpx   #200
            bcc   :scb
            ldy   #0                    ; cleared
            lda   #0
:clr        sta   [vs],y
            iny
            iny
            cpy   #32000
            bcc   :clr
            lda   #-2                   ; the scales the pointer moves by
            sta   SX
            lda   rw
            lsr
            sec
            sbc   #39
:sx         cmp   #80
            bcc   :sxd
            bmi   :sxd
            inc   SX
            inc
            lsr
            bra   :sx
:sxd        lda   #-1
            sta   SY
            lda   rh
            lsr
            sec
            sbc   #24
:sy         cmp   #50
            bcc   :syd
            bmi   :syd
            inc   SY
            inc
            lsr
            bra   :sy
:syd        lda   #$FFFF
            sta   Left
            lda   #ApproxDraw
            sta   Mover
            jsr   Mouse
            jsr   ApproxDraw
            jmp   WaitMove

* ApproxDraw: up to 80 x 50 pixels as 4 x 4 blocks: a red, a green and a
* blue level line and a black one, the part the pointer says.
ApproxDraw  lda   #320                  ; left
            sec
            sbc   MouseH
            ldx   SX
            jsr   Scale2
            sta   vw0
            lda   rw
            lsr
            clc
            adc   #40
            clc
            adc   vw0
            jsr   MinMax
            ldx   rw
            jsr   UpTo
            sec
            sbc   #80
            bpl   :l
            lda   #0
:l          sta   vw2
            lda   #100                  ; top
            sec
            sbc   MouseV
            ldx   SY
            jsr   Scale2
            sta   vw0
            lda   rh
            lsr
            clc
            adc   #25
            clc
            adc   vw0
            jsr   MinMax
            ldx   rh
            jsr   UpTo
            sec
            sbc   #50
            bpl   :t
            lda   #0
:t          sta   vw3
            cmp   Top
            bne   :draw
            lda   vw2
            cmp   Left
            bne   :draw
            rts
:draw       lda   vw2
            sta   Left
            lda   vw3
            sta   Top
            stz   vw4                   ; the block row
:row        lda   vw4
            clc
            adc   Top
            cmp   rh
            bcc   :in
            rts
:in         ldx   tstride               ; the picture row
            jsr   Mul16
            lda   Left                  ; + left x 3
            asl
            clc
            adc   Left
            clc
            adc   MLo
            sta   vw5
            lda   MHi
            adc   #0
            sta   vw6
            lda   tp
            clc
            adc   vw5
            sta   vp
            lda   tp+2
            adc   vw6
            sta   vp+2
            lda   vw4                   ; the screen line: 4 x block row
            asl
            asl
            jsr   Times160
            sta   vw7
            stz   vw5                   ; the block (column)
:blk        lda   vw5
            clc
            adc   Left
            cmp   rw
            bcc   :jx1
            jmp   :next
:jx1
            lda   vw5
            asl
            sta   vw0
            asl
            clc
            adc   vw0
            tay                         ; the pixel's offset (x 3)
            lda   [vp],y                ; R, G
            sta   vw0
            iny
            iny
            lda   [vp],y                ; B
            and   #$00FF
            sta   vw1
            lda   vw0                   ; grey (R = G = B): the grey pattern
            and   #$00FF
            sta   vw6
            xba
            ora   vw6
            cmp   vw0
            bne   :colour
            lda   vw6
            cmp   vw1
            bne   :colour
            lsr
            lsr
            asl
            tax
            lda   GreyLevels,x
            sta   vw0
            sta   vw1
            sta   vw6
            bra   :put
:colour     lda   vw6                   ; 5-bit levels
            lsr
            lsr
            and   #$003E
            tax
            lda   ColLevels,x
            pha
            lda   vw0
            xba
            and   #$00FF
            lsr
            lsr
            and   #$003E
            tax
            lda   ColLevels,x
            pha
            lda   vw1
            lsr
            lsr
            and   #$003E
            tax
            lda   ColLevels,x
            sta   vw6                   ; blue
            pla
            sta   vw1                   ; green
            pla
            sta   vw0                   ; red
:put        lda   vw5                   ; screen byte: 2 x block + line
            asl
            clc
            adc   vw7
            tay
            lda   vw0
            sta   [vs],y
            tya
            clc
            adc   #160
            tay
            lda   vw1
            sta   [vs],y
            tya
            clc
            adc   #160
            tay
            lda   vw6
            sta   [vs],y
            inc   vw5
            lda   vw5
            cmp   #80
            bcs   :jx2
            jmp   :blk
:jx2
:next       inc   vw4
            lda   vw4
            cmp   #50
            bcs   :done
            jmp   :row
:done       rts

* Scale2: A (signed) x 2^X (X signed: left shifts, or arithmetic right).
Scale2      cpx   #0
            beq   :done
            bmi   :right
:left       asl
            dex
            bne   :left
:done       rts
:right      cmp   #$8000
            ror
            inx
            bne   :right
            rts
* MinMax: A kept to 0 or more (signed). UpTo: A kept to X at most.
MinMax      bpl   :ok
            lda   #0
:ok         rts
UpTo        stx   vw0
            cmp   vw0
            bcc   :ok
            lda   vw0
:ok         rts

* Mul16: MLo/MHi = A x X.
Mul16       sta   vw0
            stx   vw1
            stz   MLo
            stz   MHi
            stz   vw6
:bit        lda   vw1
            beq   :done
            lsr   vw1
            bcc   :shift
            clc
            lda   MLo
            adc   vw0
            sta   MLo
            lda   MHi
            adc   vw6
            sta   MHi
:shift      asl   vw0
            rol   vw6
            bra   :bit
:done       rts

*-------------------------------------------------------------
* Data
*-------------------------------------------------------------
Kind        dw    0
KeepH       adrl  0
KeepP       adrl  0
Bytes       dw    0
Lines       dw    0
Mover       dw    0
LastH       dw    0
LastV       dw    0
MouseV      dw    0                     ; (a point: v, h)
MouseH      dw    0
Left        dw    0
Top         dw    0
SX          dw    0
SY          dw    0
Out         dw    0
MLo         dw    0
MHi         dw    0
Event       ds    16
ScbOf4      dw    0,1,2,0
RampR       dw    $000,$100,$200,$300,$400,$500,$600,$700,$800,$900,$A00,$B00,$C00,$D00,$E00,$F00
RampG       dw    $000,$010,$020,$030,$040,$050,$060,$070,$080,$090,$0A0,$0B0,$0C0,$0D0,$0E0,$0F0
RampB       dw    $000,$001,$002,$003,$004,$005,$006,$007,$008,$009,$00A,$00B,$00C,$00D,$00E,$00F

            put   ViewData.s
