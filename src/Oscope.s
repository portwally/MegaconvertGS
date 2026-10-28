*-------------------------------------------------------------
* Oscope.s - Screen > Oscilloscope Art, as SuperConvert's (part of the
* Extras segment; docs/superconvert-extras.md 4.3): the screen image made
* into a 320 mode picture to watch on an oscilloscope on the composite
* video output. Each pair of lines gets a grey level of its own (so the
* video voltage says which line it is), the even line lit where the
* source is bright, the odd one where it is medium; the lines are then
* put in the original's scrambled order, with their palettes.
*-------------------------------------------------------------

* OscArt: scrp: the screen image ($C1 layout); darg: its bytes a line,
* dact: its lines.
*   out: carry set if there was no memory (A = the error)
OscArt      ent
            phb
            phk
            plb
            lda   darg
            sta   OsBytes
            lda   dact
            sta   OsLines
            pha                         ; the lines made, before their order
            pha
            PushLong 32000
            lda   uid
            pha
            pea   $C018
            PushLong 0
            Tool  _NewHandle
            tax
            pla
            sta   OsH
            pla
            sta   OsH+2
            txa
            bcc   :got
            plb
            rtl
:got        lda   OsH
            sta   xp0
            lda   OsH+2
            sta   xp0+2
            ldy   #2
            lda   [xp0],y
            tax
            lda   [xp0]
            sta   xp0
            stx   xp0+2
            stz   OsL                   ; each source line
:line       jsr   OsLine
            inc   OsL
            lda   OsL
            cmp   #200
            bcc   :line
            ldy   #palOffset            ; colour tables 0-7: the scope's greys
            ldx   #0
:pal        lda   OsPals,x
            sta   [scrp],y
            iny
            iny
            inx
            inx
            cpx   #256
            bcc   :pal
            lda   #$17                  ; the order: a shift register's
            sta   OsA                   ; sequence through 1-199
            stz   OsX
:next       lda   OsA
:step       asl
            cmp   #256
            bcc   :lt
            and   #$00FF
            eor   #$001D
:lt         cmp   #200
            bcs   :step
            sta   OsA
            jsr   OsPut
            inc   OsX
            lda   OsA
            cmp   #$17
            bne   :next
            stz   OsA                   ; the last row: line 0
            jsr   OsPut
            PushLongAt OsH
            Tool  _DisposeHandle
            clc
            plb
            rtl

* OsPut: image row OsX = made line OsA, with its colour table (7 for the
* top 28 lines, 6 for the next 28, ...; 320 mode).
OsPut       lda   OsA
            jsr   Os160
            sta   OsFrom
            lda   OsX
            jsr   Os160
            sta   OsTo
            ldx   #0
:b          txa
            clc
            adc   OsFrom
            tay
            lda   [xp0],y
            pha
            txa
            clc
            adc   OsTo
            tay
            pla
            sta   [scrp],y
            inx
            inx
            cpx   #160
            bcc   :b
            lda   OsA                   ; 7 - line / 28
            ldx   #0
:d          cmp   #28
            bcc   :scb
            sbc   #28
            inx
            bra   :d
:scb        stx   OsT
            lda   #7
            sec
            sbc   OsT
            pha
            lda   OsX
            clc
            adc   #scbOffset
            tay
            pla
            sep   #$20
            mx    %10
            sta   [scrp],y
            rep   #$20
            mx    %00
            rts

* OsLine: source line OsL made into line OsL of the buffer at xp0.
OsLine      lda   OsL                   ; its mode and colour table (none
            ldx   #0                    ; below the picture)
            cmp   OsLines
            bcs   :scb
            clc
            adc   #scbOffset
            tay
            lda   [scrp],y
            and   #$00FF
            tax
:scb        stx   OsScb
            txa                         ; each colour's brightness: R + G + B
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
:br         lda   [scrp],y
            pha
            and   #$000F
            sta   OsT
            lda   1,s
            lsr
            lsr
            lsr
            lsr
            and   #$000F
            clc
            adc   OsT
            sta   OsT
            pla
            xba
            and   #$000F
            clc
            adc   OsT
            sta   OsBr,x
            iny
            iny
            inx
            inx
            cpx   #32
            bcc   :br
            lda   OsL                   ; its level: 14, 14, 13, 13, ... 1, 1
            ldx   #0                    ; every 28 lines
:m28        cmp   #28
            bcc   :lev
            sbc   #28
            bra   :m28
:lev        lsr
            sta   OsT
            lda   #14
            sec
            sbc   OsT
            sta   OsLev
            asl                         ; (and as a high nibble)
            asl
            asl
            asl
            sta   OsLevH
            lda   #30                   ; lit from 30 (even lines) or 15 (odd)
            ldx   OsL
            txa
            lsr
            bcc   :thr
            lda   #15
            bra   :thr2
:thr        lda   #30
:thr2       sta   OsThr
            lda   OsL
            jsr   Os160
            sta   OsTo
            lda   OsL                   ; (the source line, when there is one)
            jsr   Os160
            sta   OsFrom
            stz   OsI
:byte       lda   #0                    ; the source byte: 0 past the picture
            ldx   OsL
            cpx   OsLines
            bcs   :have
            ldx   OsI
            cpx   OsBytes
            bcs   :have
            lda   OsI
            clc
            adc   OsFrom
            tay
            lda   [scrp],y
            and   #$00FF
:have       sta   OsByte
            lda   OsScb
            and   #$0080
            bne   :p640
            lda   OsByte                ; 320 mode: each nibble a colour
            lsr
            lsr
            lsr
            lsr
            asl
            tax
            lda   OsBr,x
            sta   OsB1
            lda   OsByte
            and   #$000F
            asl
            tax
            lda   OsBr,x
            sta   OsB2
            bra   :lit
:p640       lda   OsByte                ; 640 mode: each nibble two pixels,
            lsr                         ; their brightnesses averaged (high
            lsr                         ; nibble: colours 0-3 and 4-7, low:
            lsr                         ; 8-11 and 12-15)
            lsr
            lsr
            lsr
            jsr   :br2
            pha
            lda   OsByte
            lsr
            lsr
            lsr
            lsr
            and   #$0003
            clc
            adc   #4
            jsr   :br2
            clc
            adc   1,s
            lsr
            sta   OsB1
            pla
            lda   OsByte
            lsr
            lsr
            and   #$0003
            clc
            adc   #8
            jsr   :br2
            pha
            lda   OsByte
            and   #$0003
            clc
            adc   #12
            jsr   :br2
            clc
            adc   1,s
            lsr
            sta   OsB2
            pla
:lit        lda   #0                    ; lit: the line's level; else 0
            ldx   OsB1
            cpx   OsThr
            bcc   :lo
            lda   OsLevH
:lo         ldx   OsB2
            cpx   OsThr
            bcc   :put
            ora   OsLev
:put        pha
            lda   OsI
            clc
            adc   OsTo
            tay
            pla
            sep   #$20
            mx    %10
            sta   [xp0],y
            rep   #$20
            mx    %00
            inc   OsI
            lda   OsI
            cmp   #160
            bcs   :done
            jmp   :byte
:done       rts
:br2        asl                         ; colour A's brightness
            tax
            lda   OsBr,x
            rts

* Os160: A x 160.
Os160       asl
            asl
            asl
            asl
            asl
            sta   OsT
            asl
            asl
            clc
            adc   OsT
            rts

OsH         adrl  0
OsBytes     dw    0
OsLines     dw    0
OsL         dw    0
OsI         dw    0
OsA         dw    0
OsX         dw    0
OsT         dw    0
OsScb       dw    0
OsLev       dw    0
OsLevH      dw    0
OsThr       dw    0
OsFrom      dw    0
OsTo        dw    0
OsByte      dw    0
OsB1        dw    0
OsB2        dw    0
OsBr        ds    32                    ; the 16 colours' brightnesses
* The colour tables 0-7: table p has 0 black; 1-7 R = G = 2p, B 0-6;
* 8-14 R = G = 2p + 1, B 0-6; 15 white
OsPals      dw    $000,$000,$001,$002,$003,$004,$005,$006
            dw    $110,$111,$112,$113,$114,$115,$116,$FFF
            dw    $000,$220,$221,$222,$223,$224,$225,$226
            dw    $330,$331,$332,$333,$334,$335,$336,$FFF
            dw    $000,$440,$441,$442,$443,$444,$445,$446
            dw    $550,$551,$552,$553,$554,$555,$556,$FFF
            dw    $000,$660,$661,$662,$663,$664,$665,$666
            dw    $770,$771,$772,$773,$774,$775,$776,$FFF
            dw    $000,$880,$881,$882,$883,$884,$885,$886
            dw    $990,$991,$992,$993,$994,$995,$996,$FFF
            dw    $000,$AA0,$AA1,$AA2,$AA3,$AA4,$AA5,$AA6
            dw    $BB0,$BB1,$BB2,$BB3,$BB4,$BB5,$BB6,$FFF
            dw    $000,$CC0,$CC1,$CC2,$CC3,$CC4,$CC5,$CC6
            dw    $DD0,$DD1,$DD2,$DD3,$DD4,$DD5,$DD6,$FFF
            dw    $000,$EE0,$EE1,$EE2,$EE3,$EE4,$EE5,$EE6
            dw    $FF0,$FF1,$FF2,$FF3,$FF4,$FF5,$FF6,$FFF
