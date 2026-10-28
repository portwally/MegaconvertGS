*-------------------------------------------------------------
* True640.s - Screen > Convert to true color for a 640 mode screen
* image, as SuperConvert's (part of the Mono segment, which has the option
* windows; docs/superconvert-truecolor.md 10): the window choosing Exact or
* Smoothed, and the smoothed conversion of a line.
*-------------------------------------------------------------

* Dlg640: the window (unless SKIP ME was checked last time).
*   out: carry clear and A = 0 Exact, 1 Smoothed; carry set: cancelled
Dlg640      ent
            phb
            phk
            plb
            tdc
            sta   MDP
            lda   Skip640               ; SKIP ME: the last choice
            beq   :ask
            lda   Smooth640
            clc
            plb
            rtl
:ask        pha                         ; the window (invisible at first)
            pha
            PushLong 0
            PushLong 0
            PushLong TcRedraw
            PushLong 0
            pea   0
            PushLong TcParms
            pea   $800E
            Tool  _NewWindow2
            pla
            sta   DlgWin
            pla
            sta   DlgWin+2
            lda   Smooth640             ; the last choice on
            beq   :show
            lda   #6
            jsr   RadioOn
:show       PushLongAt DlgWin
            Tool  _ShowWindow
:loop       jsr   Modal
            cmp   #1
            beq   :ok
            cmp   #2
            beq   :cancel
            cmp   #3
            bne   :loop
            Tool  _SysBeep              ; (Info on options: no help yet)
            bra   :loop
:cancel     jsr   CloseDlg
            sec
            plb
            rtl
:ok         lda   #6                    ; Smoothed?
            jsr   CtlValue
            sta   Smooth640
            lda   #4                    ; SKIP ME
            jsr   CtlValue
            sta   Skip640
            jsr   CloseDlg
            lda   Smooth640
            clc
            plb
            rtl

* RadioOn: radio button A on (the other of its family goes off).
RadioOn     sta   mq0
            pea   1
            PushLongAt DlgWin
            pea   0
            lda   mq0
            pha
            Tool  _SetCtlValueByID
            rts

* TcRedraw: the window's contents: its controls, and the screen image's
* icon, an arrow, the true colour image's icon.
TcRedraw    phb
            phk
            plb
            phd
            lda   MDP
            tcd
            PushLongAt DlgWin
            Tool  _DrawControls
            lda   #MIcScr
            ldx   #150
            ldy   #4
            jsr   Icon
            lda   #IcArrowR
            ldx   #174
            ldy   #6
            jsr   Icon
            lda   #MIcTrue
            ldx   #214
            ldy   #4
            jsr   Icon
            pld
            plb
            rtl

*-------------------------------------------------------------
* Smoothed: dither patterns become a solid colour
*-------------------------------------------------------------

* SmoothLine: one line of a 640 mode screen image to true colour,
* smoothed. In: dctl = the line's bytes (long), darg = its SCB, dact =
* its width in pixels (at most 640), scrp = the screen image (its colour
* tables), q0 = the true colour row (RGB, long).
SmoothLine  ent
            phb
            phk
            plb
            jsr   V5Make                ; (the blend table, made once)
            lda   darg                  ; the line's colours
            and   #$000F
            asl
            asl
            asl
            asl
            asl
            clc
            adc   #palOffset
            tay
            ldx   #0
:p          lda   [scrp],y
            and   #$0FFF
            sta   SmP,x
            iny
            iny
            inx
            inx
            cpx   #32
            bcc   :p
            ldx   #0                    ; equal colours share one index
:canon      stx   mq0
            ldy   #0
:find       lda   SmP,y
            cmp   SmP,x
            beq   :got
            iny
            iny
            bra   :find
:got        tya
            lsr
            sta   mq1                   ; (the first index with this colour)
            asl
            asl
            asl
            asl
            ora   mq1                   ; x 17
            sta   SmCanon,x
            inx
            inx
            cpx   #32
            bcc   :canon
            ldx   #0                    ; each pixel's code (byte (c << 4) | c)
            ldy   #0
:pix        cpx   dact
            bcs   :sent
            txa
            lsr
            lsr
            tay
            lda   [dctl],y              ; its byte; the pixel's 2 bits
            and   #$00FF
            sta   mq0
            txa
            and   #3
            sta   mq1
            tay
            lda   mq0
:sh         cpy   #3
            beq   :v
            lsr
            lsr
            iny
            bra   :sh
:v          and   #3
            sta   mq2
            lda   mq1                   ; the entry: 8, 12, 0 or 4 + the value
            asl
            tay
            lda   Off640s,y
            clc
            adc   mq2
            asl
            tay
            lda   SmCanon,y
            sep   #$20
            mx    %10
            sta   SmCode,x
            rep   #$20
            mx    %00
            inx
            bra   :pix
:sent       sep   #$20                  ; three that never match
            mx    %10
            lda   #$63
            sta   SmCode,x
            lda   #$64
            sta   SmCode+1,x
            lda   #$65
            sta   SmCode+2,x
            rep   #$20
            mx    %00
            ldx   #0                    ; dither patterns
:run        cpx   dact
            bcc   :jx1
            jmp   :blend
:jx1
            jsr   Code                  ; runs of one code stay
            sta   mq0
            inx
            jsr   Code
            dex
            cmp   mq0
            bne   :pattern
:same       inx                         ; (past the whole run)
            cpx   dact
            bcc   :jx2
            jmp   :blend
:jx2
            jsr   Code
            cmp   mq0
            beq   :same
            bra   :run
:pattern    sta   mq1                   ; a, b, a, b, a: one colour
            inx
            inx
            jsr   Code                  ; code[x+2] = a?
            dex
            dex
            cmp   mq0
            bne   :next
            txa
            clc
            adc   #4
            tax
            jsr   Code                  ; code[x+4] = a?
            sta   mq4
            txa
            sec
            sbc   #4
            tax
            lda   mq4
            cmp   mq0
            bne   :next
            inx
            inx
            inx
            jsr   Code                  ; code[x+3] = b?
            dex
            dex
            dex
            cmp   mq1
            bne   :next
            lda   mq1                   ; the pair: b's high, a's low nibble
            and   #$00F0
            sta   mq2
            lda   mq0
            and   #$000F
            ora   mq2
            sta   mq2
            stz   mq3                   ; (0: a expected, 1: b)
:repl       cpx   dact
            bcs   :run
            jsr   Code                  ; while a, b, a ... goes on
            ldy   mq3
            beq   :wantA
            cmp   mq1
            bne   :run
            bra   :neighbour
:wantA      cmp   mq0
            bne   :run
:neighbour  sta   mq4                   ; and the pixel differs from the next
            inx
            jsr   Code
            dex
            cmp   mq4
            bne   :jx3
            jmp   :run
:jx3
            lda   mq2
            sep   #$20
            mx    %10
            sta   SmCode,x
            rep   #$20
            mx    %00
            lda   mq3
            eor   #1
            sta   mq3
            inx
            bra   :repl
:next       inx
            jmp   :run
:blend      ldx   #0                    ; each pixel: its code's blend
            ldy   #0
:b          cpx   dact
            bcs   :done
            phx
            phy
            jsr   Code
            jsr   Blend                 ; mq5, mq6, mq7: 8-bit R, G, B
            ply
            sep   #$20
            mx    %10
            lda   mq5
            sta   [q0],y
            iny
            lda   mq6
            sta   [q0],y
            iny
            lda   mq7
            sta   [q0],y
            iny
            rep   #$20
            mx    %00
            plx
            inx
            bra   :b
:done       plb
            rtl

* Code: A = SmCode[X].
Code        lda   SmCode,x
            and   #$00FF
            rts

* Blend: code A = (i << 4) | j: colours P[j] and P[i] blended, each
* channel v5 = the largest k with TH[k] <= SQ[c1] + SQ[c2]; equal
* channels give a grey (v5 x 8), else each channel's 5 bits expanded.
Blend       pha
            and   #$000F
            asl
            tax
            lda   SmP,x
            sta   mq0                   ; P[j]
            pla
            lsr
            lsr
            lsr
            and   #$001E
            tax
            lda   SmP,x
            sta   mq1                   ; P[i]
            lda   mq0                   ; red
            xba
            and   #$000F
            tax
            lda   SQ,x
            and   #$00FF
            sta   mq2
            lda   mq1
            xba
            and   #$000F
            tax
            lda   SQ,x
            and   #$00FF
            clc
            adc   mq2
            tax
            lda   V5,x
            and   #$00FF
            sta   mq5
            lda   mq0                   ; green
            lsr
            lsr
            lsr
            lsr
            and   #$000F
            tax
            lda   SQ,x
            and   #$00FF
            sta   mq2
            lda   mq1
            lsr
            lsr
            lsr
            lsr
            and   #$000F
            tax
            lda   SQ,x
            and   #$00FF
            clc
            adc   mq2
            tax
            lda   V5,x
            and   #$00FF
            sta   mq6
            lda   mq0                   ; blue
            and   #$000F
            tax
            lda   SQ,x
            and   #$00FF
            sta   mq2
            lda   mq1
            and   #$000F
            tax
            lda   SQ,x
            and   #$00FF
            clc
            adc   mq2
            tax
            lda   V5,x
            and   #$00FF
            sta   mq7
            lda   mq5                   ; a grey?
            cmp   mq6
            bne   :colour
            cmp   mq7
            bne   :colour
            asl
            asl
            asl
            sta   mq5
            sta   mq6
            sta   mq7
            rts
:colour     lda   mq5
            jsr   Expand
            sta   mq5
            lda   mq6
            jsr   Expand
            sta   mq6
            lda   mq7
            jsr   Expand
            sta   mq7
            rts

* Expand: 5 bits to 8 (rrrrr rrr).
Expand      asl
            asl
            asl
            sta   mq4
            lsr
            lsr
            lsr
            lsr
            lsr
            ora   mq4
            rts

* V5Make: V5[s] (s = 0-510) = the largest k with TH[k] <= s.
V5Make      lda   V5Made
            bne   :out
            inc   V5Made
            ldx   #0                    ; s
            ldy   #0                    ; k
:s          cpy   #31*2
            bcs   :put
            lda   TH+2,y                ; the next threshold reached?
            sta   mq0
            txa
            cmp   mq0
            bcc   :put
            iny
            iny
            bra   :s
:put        tya
            lsr
            sep   #$20
            mx    %10
            sta   V5,x
            rep   #$20
            mx    %00
            inx
            cpx   #511
            bcc   :s
:out        rts

*-------------------------------------------------------------
* Data
*-------------------------------------------------------------
Skip640     dw    0                     ; SKIP ME
Smooth640   dw    0                     ; the last choice: 1 Smoothed
V5Made      dw    0
Off640s     dw    8,12,0,4              ; (the entries: 2 bits at x & 3)
SmP         ds    32                    ; the line's colours
SmCanon     ds    32                    ; their codes
SmCode      ds    640+4
SQ          db    0,1,4,9,17,27,39,54,70,90,111,135,161,190,221,255
TH          dw    0,1,1,2,5,8,13,19,26,34,43,54,65,78,92,107,123,141,159,179,200
            dw    222,247,270,296,323,351,380,411,443,476,509
V5          ds    512

* The window (SuperConvert's FRED $BC74).
TcParms     dw    $50,$2000
            adrl  0,0
            dw    0,0,0,0
            adrl  0
            dw    0,0,0,0,0,0,0,0,0,0
            adrl  0
            dw    0
            adrl  0,0,0
            dw    40,132,150,512
            adrl  $FFFFFFFF
            adrl  TcCtls
            dw    $0003
TcCtls      adrl  TcOK,TcCancel,TcInfo,TcSkip,TcExact,TcSmooth,TcText,0
TcOK        dw    9
            adrl  1
            dw    75,290,88,360
            adrl  $80000000
            dw    $0001,$3000
            adrl  0
            adrl  TxOKm
            adrl  0
            db    $0D,$0D
            dw    0,0
TcCancel    dw    9
            adrl  2
            dw    75,180,88,270
            adrl  $80000000
            dw    0,$3000
            adrl  0
            adrl  TxCancelm
            adrl  0
            db    $1B,$1B
            dw    0,0
TcInfo      dw    7
            adrl  3
            dw    75,10,88,160
            adrl  $80000000
            dw    0,$1000
            adrl  0
            adrl  TxInfoOpt
TcSkip      dw    10
            adrl  4
            dw    95,10,104,280
            adrl  $82000000
            dw    0,$3000
            adrl  0
            adrl  TxSkip1
            dw    0
            adrl  0
            db    $13,$13
            dw    0,0
TcExact     dw    10
            adrl  5
            dw    50,10,59,380
            adrl  $84000000
            dw    0,$3000
            adrl  0
            adrl  TxExact
            dw    1
            adrl  0
            db    'E','e'
            dw    0,0
TcSmooth    dw    10
            adrl  6
            dw    60,10,69,380
            adrl  $84000000
            dw    0,$3000
            adrl  0
            adrl  TxSmooth
            dw    0
            adrl  0
            db    'S','s'
            dw    0,0
TcText      dw    8
            adrl  7
            dw    18,10,45,371
            adrl  $81000000
            dw    0,$1000
            adrl  0
            adrl  TxTc
            dw    TxTcEnd-TxTc
TxSkip1     str   'SKIP ME: always use this option'
TxExact     str   'Exact: each pixel retains its individual color'
TxSmooth    str   'Smoothed: dither patterns become a solid color'
TxTc        asc   'A 640 mode screen image is being converted to true color, which can be '
            asc   'done in either of two ways depending on the eventual use of the image:'
TxTcEnd
