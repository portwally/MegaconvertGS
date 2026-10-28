*-------------------------------------------------------------
* Filter.s - the True color menu's filters and Rotate/flip (a
* segment of its own; called from the main program with JSL)
*
* They change the true colour picture as GS Remap's filters do:
* 8-bit channels; the neighbourhood filters see each byte's 3 x 3
* neighbours in the same channel, with the picture's edges
* repeated, numbered
*       0 1 2
*       3 4 5
*       6 7 8
* In: tp, tstride, rw, rh (the picture), uid. Rotate/flip with a
* turn makes a new picture: fhnd is then its handle, tp its pointer.
*-------------------------------------------------------------
            rel
            mx    %00
            use   macros/Macs.s
            put   Equates.s

N0          =     $D0                   ; the neighbours: N0-N2 the row above,
N1          =     $D4                   ; N3-N5 this row, N6-N8 the row below,
N2          =     $D8                   ; each pointing at the pixel to the
N3          =     $DC                   ; left, this one and the one to the
N4          =     $E0                   ; right (longs; Y = the byte)
N5          =     $E4
N6          =     $E8
N7          =     $EC
N8          =     $F0
OutR        =     $F4                   ; the picture row being written
fs          =     $F8                   ; work words (fs, ft also a pointer)
ft          =     $FA
fu          =     $FC
fk          =     $FE
V0          =     $5A                   ; the median's nine values (bytes)
RowP        =     q0                    ; a picture row (long)
MapP        =     q1                    ; the 64K table (long)
DstP        =     q2                    ; where a copy goes (long)
SrcP        =     p0                    ; where it comes from (long)
fn          =     n0                    ; 32-bit work numbers
fd          =     n1

* FilterRun: filter A (fxEqualize ... fxLess, Equates.s) on the true
* colour picture; X = the factor (0-99) for Blur, Sharpen, Find edges.
*   out: carry clear, or carry set and A = error
FilterRun   ent
            phb
            phk
            plb
            stx   Factor
            asl
            tax
            jsr   (Kinds,x)
            plb
            rtl
Kinds       da    Equalize,Median,Sigma,Emboss,Blur,Sharpen,Solarize,Edges
            da    MoreCon,LessCon

*-------------------------------------------------------------
* The neighbourhood filters
*-------------------------------------------------------------

Median      ldx   #0
            jmp   Around
Emboss      ldx   #2
            jmp   Around

Sigma       stz   fs                    ; (s + 4) / 9 for every sum s of nine
            lda   #4                    ; bytes, 0-2295
            sta   ft
            ldx   #0
            sep   #$20
            mx    %10
:one        lda   fs
            sta   Div9,x
            rep   #$20
            mx    %00
            inc   ft
            lda   ft
            cmp   #9
            bcc   :same
            stz   ft
            inc   fs
:same       sep   #$20
            mx    %10
            inx
            cpx   #2296
            bcc   :one
            rep   #$20
            mx    %00
            ldx   #4
            jmp   Around

* Blur: the centre counts (100 - factor) / 2 - 13, the sides 2, the
* corners 1; divided by the weights' sum (at least 1), rounded.
Blur        lda   #100
            sec
            sbc   Factor
            lsr
            sec
            sbc   #13
            sta   Weight
            clc
            adc   #12
            jsr   Weights
            ldx   #6
            jmp   Around

* Sharpen: the centre counts (100 - factor) / 2 + 13, the others take
* away (sides 2, corners 1); divided by what is left (at least 1).
Sharpen     lda   #100
            sec
            sbc   Factor
            lsr
            clc
            adc   #13
            sta   Weight
            sec
            sbc   #12
            jsr   Weights
            ldx   #8
            jmp   Around

* Weights: WTab = Weight times each byte value; A = the divisor (made
* at least 1): Half = its half, DivTab = each sum divided by it (at
* most 255).
Weights     cmp   #1
            bpl   :pos
            lda   #1
:pos        sta   Divisor
            lsr
            sta   Half
            lda   #0                    ; WTab: 0, w, 2w ...
            ldx   #0
:w          sta   WTab,x
            clc
            adc   Weight
            inx
            inx
            cpx   #512
            bcc   :w
            stz   fs                    ; DivTab: the quotient, stepping
            stz   ft
            ldx   #0
:d          lda   fs
            cmp   #256
            bcc   :byte
            lda   #255
:byte       sep   #$20
            mx    %10
            sta   DivTab,x
            rep   #$20
            mx    %00
            inc   ft
            lda   ft
            cmp   Divisor
            bcc   :next
            stz   ft
            inc   fs
:next       inx
            cpx   #DivMax
            bcc   :d
            rts

* Find edges: 4 x the centre less the four corners, times
* (130 - factor) / 80 and rounded (GS Remap's gain, (100 - factor) / 20
* + 1.5), with GS Remap's few roundings down (EdgeEx); 0 if not more
* than 0.
Edges       lda   #130
            sec
            sbc   Factor
            sta   Weight
            stz   fs                    ; quotient
            stz   ft                    ; remainder (of 80)
            ldx   #1
:d          lda   ft
            clc
            adc   Weight
:sub        cmp   #80
            bcc   :rem
            sbc   #80
            inc   fs
            bra   :sub
:rem        sta   ft
            lda   fs
            ldy   ft
            cpy   #40                   ; a half or more: up
            bcc   :down
            inc
:down       cmp   #256
            bcc   :byte
            lda   #255
:byte       sep   #$20
            mx    %10
            sta   EdgeTab,x
            rep   #$20
            mx    %00
            inx
            cpx   #1021
            bcc   :d
            ldx   #0                    ; GS Remap's exceptions for this factor
:ex         lda   EdgeEx,x
            and   #$00FF
            cmp   #$FF
            beq   :done
            cmp   Factor
            bne   :skip
            lda   EdgeEx+1,x
            tay
            sep   #$20
            mx    %10
            lda   EdgeTab,y
            dec
            sta   EdgeTab,y
            rep   #$20
            mx    %00
:skip       inx
            inx
            inx
            bra   :ex
:done       ldx   #10
            jmp   Around

* Around: runs body X (Bodies) for every byte of the picture with its
* neighbours set (N0-N8, Y = the byte), and puts its result (A, 0-255)
* in the byte's place. Each row is first copied to a buffer with its
* first and last pixels repeated at the ends, so the bodies see the
* picture as it was.
*   out: carry clear, or carry set and A = error
Around      stx   BodyX
            lda   tstride
            sta   RowLen
            jsr   NewBufs
            bcc   :ok
            rts
:ok         lda   tp
            sta   RowP
            lda   tp+2
            sta   RowP+2
            ldx   #0                    ; row 0 above and here
            jsr   CopyRow
            ldx   #4
            jsr   CopyRow
            stz   RowY
:row        lda   RowY                  ; the row below, or this one again
            inc
            cmp   rh
            bcs   :last
            lda   RowP
            clc
            adc   RowLen
            sta   SrcP
            lda   RowP+2
            adc   #0
            sta   SrcP+2
            ldx   #8
            jsr   CopyFrom
            bra   :set
:last       lda   Bufs+4                ; (the last row: below is this row)
            sta   Bufs+8
            lda   Bufs+6
            sta   Bufs+10
:set        ldy   #0                    ; N0-N2: the row above
            ldx   #N0
            jsr   SetN
            ldy   #4
            ldx   #N3
            jsr   SetN
            ldy   #8
            ldx   #N6
            jsr   SetN
            lda   RowP
            sta   OutR
            lda   RowP+2
            sta   OutR+2
            ldy   #0
:byte       ldx   BodyX
            jsr   (Bodies,x)
            sep   #$20
            mx    %10
            sta   [OutR],y
            rep   #$20
            mx    %00
            iny
            cpy   RowLen
            bcc   :byte
            lda   Bufs                  ; rotate: above <- here <- below
            ldx   Bufs+4
            stx   Bufs
            ldx   Bufs+8
            stx   Bufs+4
            sta   Bufs+8
            lda   Bufs+2
            ldx   Bufs+6
            stx   Bufs+2
            ldx   Bufs+10
            stx   Bufs+6
            sta   Bufs+10
            lda   RowP
            clc
            adc   RowLen
            sta   RowP
            lda   RowP+2
            adc   #0
            sta   RowP+2
            lda   RowY                  ; (the progress; Command-period stops)
            jsr   ProgRow
            bcs   :stop
            inc   RowY
            lda   RowY
            cmp   rh
            bcs   :stop
            jmp   :row
:stop       jsr   FreeBufs
            clc
            rts
Bodies      da    BMedian,BEmboss,BSigma,BBlur,BSharpen,BEdges

* SetN: the three neighbour pointers at X (on the direct page) for the
* buffer whose pointer is at Bufs+Y: the buffer + 0, + 3 and + 6.
SetN        lda   Bufs,y
            sta   0,x
            clc
            adc   #3
            sta   4,x
            clc
            adc   #3
            sta   8,x
            lda   Bufs+2,y
            sta   2,x
            sta   6,x
            sta   10,x
            rts

* CopyRow: the row at RowP into buffer X (Bufs+X). CopyFrom: the row
* at SrcP. The row goes from the buffer's 4th byte, with its first
* pixel again before it and its last after it.
CopyRow     lda   RowP
            sta   SrcP
            lda   RowP+2
            sta   SrcP+2
CopyFrom    lda   Bufs,x
            sta   DstP
            clc
            adc   #3
            sta   fs
            lda   Bufs+2,x
            sta   DstP+2
            sta   ft
            ldy   #0
            lda   RowLen
            lsr
            bcc   :even
            sep   #$20                  ; an odd length: the first byte alone
            mx    %10
            lda   [SrcP]
            sta   [fs]
            rep   #$20
            mx    %00
            iny
:even       cpy   RowLen
            bcs   :ends
            lda   [SrcP],y
            sta   [fs],y
            iny
            iny
            bra   :even
:ends       sep   #$20
            mx    %10
            ldx   #3                    ; the first pixel before it
            ldy   #3
:first      lda   [DstP],y
            dey
            dey
            dey
            sta   [DstP],y
            iny
            iny
            iny
            iny
            dex
            bne   :first
            ldx   #3                    ; the last after it
            ldy   RowLen
:last       lda   [DstP],y
            iny
            iny
            iny
            sta   [DstP],y
            dey
            dey
            dex
            bne   :last
            rep   #$20
            mx    %00
            rts

* NewBufs: three buffers of RowLen + 6 bytes (Bufs: their pointers,
* BufHs: their handles).   out: carry set and A = error if no memory
NewBufs     ldx   #0
:one        stx   fk
            pha                         ; result: handle
            pha
            pea   0
            lda   RowLen
            clc
            adc   #6
            pha
            lda   uid
            pha
            pea   attrBuffer
            PushLong 0
            Tool  _NewHandle
            ply
            sty   fs
            ply
            sty   ft
            bcs   :err
            ldx   fk
            lda   fs
            sta   BufHs,x
            lda   ft
            sta   BufHs+2,x
            lda   [fs]
            sta   Bufs,x
            ldy   #2
            lda   [fs],y
            sta   Bufs+2,x
            inx
            inx
            inx
            inx
            cpx   #12
            bcc   :one
            clc
            rts
:err        pha
            jsr   FreeBufs
            pla
            sec
            rts

* FreeBufs: disposes of the buffers made.
FreeBufs    ldx   #8
:one        lda   BufHs,x
            ora   BufHs+2,x
            beq   :none
            phx
            lda   BufHs+2,x
            pha
            lda   BufHs,x
            pha
            Tool  _DisposeHandle
            plx
            stz   BufHs,x
            stz   BufHs+2,x
:none       dex
            dex
            dex
            dex
            bpl   :one
            rts

*-------------------------------------------------------------
* The bodies: Y = the byte; out: A = its new value (0-255). X may
* change; Y must not.
*-------------------------------------------------------------

* BMedian: the middle of the nine values (19 compare-and-swaps).
BMedian     sep   #$20
            mx    %10
            lda   [N0],y
            sta   V0
            lda   [N1],y
            sta   V0+1
            lda   [N2],y
            sta   V0+2
            lda   [N3],y
            sta   V0+3
            lda   [N4],y
            sta   V0+4
            lda   [N5],y
            sta   V0+5
            lda   [N6],y
            sta   V0+6
            lda   [N7],y
            sta   V0+7
            lda   [N8],y
            sta   V0+8
            put   FilterMed.s
            lda   V0+4
            rep   #$20
            mx    %00
            and   #$00FF
            rts

* BEmboss: 128 + 2 (n5 + n7 - n1 - n3) + n8 - n0.
BEmboss     clc
            lda   [N5],y
            and   #$00FF
            sta   fs
            lda   [N7],y
            and   #$00FF
            adc   fs
            sta   fs
            lda   [N1],y
            and   #$00FF
            sta   ft
            lda   [N3],y
            and   #$00FF
            adc   ft
            sta   ft
            lda   fs
            sec
            sbc   ft
            asl
            clc
            adc   #128
            sta   fs
            lda   [N8],y
            and   #$00FF
            clc
            adc   fs
            sta   fs
            lda   [N0],y
            and   #$00FF
            sta   ft
            lda   fs
            sec
            sbc   ft
            bmi   :zero
            cmp   #256
            bcc   :ok
            lda   #255
:ok         rts
:zero       lda   #0
            rts

* BSigma: the nine values' average, rounded.
BSigma      clc
            lda   [N0],y
            and   #$00FF
            sta   fs
            lda   [N1],y
            and   #$00FF
            adc   fs
            sta   fs
            lda   [N2],y
            and   #$00FF
            adc   fs
            sta   fs
            lda   [N3],y
            and   #$00FF
            adc   fs
            sta   fs
            lda   [N4],y
            and   #$00FF
            adc   fs
            sta   fs
            lda   [N5],y
            and   #$00FF
            adc   fs
            sta   fs
            lda   [N6],y
            and   #$00FF
            adc   fs
            sta   fs
            lda   [N7],y
            and   #$00FF
            adc   fs
            sta   fs
            lda   [N8],y
            and   #$00FF
            adc   fs
            tax
            lda   Div9,x
            and   #$00FF
            rts

* Ring: A = the corners (n0, n2, n6, n8) + 2 x the sides (n1, n3, n5, n7).
Ring        jsr   Corners
            sta   fs
            clc
            lda   [N1],y
            and   #$00FF
            sta   ft
            lda   [N3],y
            and   #$00FF
            adc   ft
            sta   ft
            lda   [N5],y
            and   #$00FF
            adc   ft
            sta   ft
            lda   [N7],y
            and   #$00FF
            adc   ft
            asl
            adc   fs
            rts

* Corners: A = n0 + n2 + n6 + n8.
Corners     clc
            lda   [N0],y
            and   #$00FF
            sta   fu
            lda   [N2],y
            and   #$00FF
            adc   fu
            sta   fu
            lda   [N6],y
            and   #$00FF
            adc   fu
            sta   fu
            lda   [N8],y
            and   #$00FF
            adc   fu
            rts

* BBlur: (the ring + Weight x n4 + Half) / Divisor.
BBlur       jsr   Ring
            sta   fs
            lda   [N4],y
            and   #$00FF
            asl
            tax
            lda   WTab,x
            clc
            adc   fs
Divide      clc
            adc   Half
            bmi   :zero
            tax
            lda   DivTab,x
            and   #$00FF
            rts
:zero       lda   #0
            rts

* BSharpen: (Weight x n4 - the ring + Half) / Divisor.
BSharpen    jsr   Ring
            sta   fs
            lda   [N4],y
            and   #$00FF
            asl
            tax
            lda   WTab,x
            sec
            sbc   fs
            bra   Divide

* BEdges: 4 x n4 - the corners, through EdgeTab (0 if not more than 0).
BEdges      jsr   Corners
            sta   fs
            lda   [N4],y
            and   #$00FF
            asl
            asl
            sec
            sbc   fs
            bmi   :zero
            beq   :zero
            tax
            lda   EdgeTab,x
            and   #$00FF
            rts
:zero       lda   #0
            rts

*-------------------------------------------------------------
* Filters on each byte or pixel by itself
*-------------------------------------------------------------

* Solarize: bytes over 132 become 255 less themselves.
Solarize    lda   tp
            sta   RowP
            lda   tp+2
            sta   RowP+2
            stz   RowY
:row        ldy   #0
            sep   #$20
            mx    %10
:byte       lda   [RowP],y
            cmp   #133
            bcc   :keep
            eor   #$FF
            sta   [RowP],y
:keep       iny
            cpy   tstride
            bcc   :byte
            rep   #$20
            mx    %00
            lda   RowY
            jsr   ProgRow
            bcs   :stop
            jsr   NextRow
            bcc   :row
:stop       clc
            rts

* NextRow: RowP to the next row.   out: carry set after the last
NextRow     lda   RowP
            clc
            adc   tstride
            sta   RowP
            lda   RowP+2
            adc   #0
            sta   RowP+2
            inc   RowY
            lda   RowY
            cmp   rh
            rts

* MoreCon, LessCon: each pixel's channels scaled by the contrast
* curve's value for its largest channel (KMore, KLess: FilterTabs.s).
MoreCon     ldx   #KMore
            bra   Contrast
LessCon     ldx   #KLess
Contrast    stx   KTab
            jsr   NewMap
            bcc   :ok
            rts
:ok         stz   fk                    ; the largest channel (row of the map)
:top        lda   fk                    ; its multiplier
            asl
            asl
            clc
            adc   KTab
            tay
            lda   |0,y
            sta   fn
            lda   |2,y
            sta   fn+2
            lda   #$8000                ; (c x K + $8000) >> 16, at most 255
            sta   fd
            stz   fd+2
            lda   fk
            xba
            tax                         ; the map row
            phb
            lda   MapP+1
            pha
            plb
            plb
:c          lda   fd+2
            cmp   #256
            bcc   :byte
            lda   #255
:byte       sep   #$20
            mx    %10
            sta   |0,x
            rep   #$20
            mx    %00
            lda   fd
            clc
            adc   fn
            sta   fd
            lda   fd+2
            adc   fn+2
            sta   fd+2
            inx
            txa
            and   #$00FF
            bne   :c
            plb
            inc   fk
            lda   fk
            cmp   #256
            bcc   :top
            ldx   #2                    ; the key: the largest channel
            jsr   ByPixel
            jmp   FreeMap

* Equalize: GS Remap's histogram equalization. The greys' histogram
* (grey = (5 R + 8 G + 3 B) / 16), then grey v goes to
* (pixels up to v - the darkest grey's count) x 255 / (all pixels -
* the darkest grey's count), and each channel c of a pixel of grey g
* (not 0) to c x that / g (at most 255).
Equalize    ldx   #0
:clear      stz   Hist,x
            inx
            inx
            cpx   #1024
            bcc   :clear
            lda   tp
            sta   RowP
            lda   tp+2
            sta   RowP+2
            stz   RowY
:row        ldy   #0
:pix        jsr   GreyAt
            asl
            asl
            tax
            inc   Hist,x
            bne   :more
            inc   Hist+2,x
:more       iny
            iny
            iny
            cpy   tstride
            bcc   :pix
            jsr   NextRow
            bcc   :row
            lda   rw                    ; all pixels
            ldx   rh
            jsr   Mul32
            lda   fn
            sta   Total
            lda   fn+2
            sta   Total+2
            ldx   #0                    ; the darkest grey's count
:low        lda   Hist,x
            ora   Hist+2,x
            bne   :lowest
            inx
            inx
            inx
            inx
            bra   :low
:lowest     lda   Hist,x
            sta   Lowest
            lda   Hist+2,x
            sta   Lowest+2
            lda   Total                 ; every pixel the same grey: unchanged
            sec
            sbc   Lowest
            sta   Span
            lda   Total+2
            sbc   Lowest+2
            sta   Span+2
            ora   Span
            bne   :spread
            clc
            rts
:spread     stz   Run
            stz   Run+2
            ldx   #0
:map        phx
            lda   Run                   ; the pixels up to this grey
            clc
            adc   Hist,x
            sta   Run
            lda   Run+2
            adc   Hist+2,x
            sta   Run+2
            lda   Run                   ; less the darkest grey's
            sec
            sbc   Lowest
            sta   fn
            lda   Run+2
            sbc   Lowest+2
            sta   fn+2
            bcc   :neg
            jsr   Times255              ; x 255 / Span
            lda   Span
            sta   fd
            lda   Span+2
            sta   fd+2
            jsr   Div32
            lda   fn
            bra   :put
:neg        lda   #0
:put        plx
            pha
            txa
            lsr
            lsr
            tay
            pla
            sep   #$20
            mx    %10
            sta   EqMap,y
            rep   #$20
            mx    %00
            inx
            inx
            inx
            inx
            cpx   #1024
            bcc   :map
            jsr   NewMap
            bcc   :table
            rts
:table      stz   fk                    ; the grey (row of the map)
:grey       ldx   fk
            lda   EqMap,x
            and   #$00FF
            sta   fs                    ; t: what this grey becomes
            stz   ft                    ; c x t / g: quotient
            stz   fu                    ; and remainder
            lda   fk
            xba
            tax
            phb
            lda   MapP+1
            pha
            plb
            plb
:c          lda   fk
            bne   :div
            lda   fs                    ; grey 0: every channel t
            bra   :byte
:div        lda   ft
            cmp   #256
            bcc   :byte
            lda   #255
:byte       sep   #$20
            mx    %10
            sta   |0,x
            rep   #$20
            mx    %00
            lda   fk                    ; the next c: + t / g
            beq   :step
            lda   fu
            clc
            adc   fs
:sub        cmp   fk
            bcc   :rem
            sbc   fk
            inc   ft
            bra   :sub
:rem        sta   fu
:step       inx
            txa
            and   #$00FF
            bne   :c
            plb
            inc   fk
            lda   fk
            cmp   #256
            bcc   :grey
            ldx   #0                    ; the key: the grey
            jsr   ByPixel
            jmp   FreeMap

* GreyAt: A = the grey of the pixel at RowP + Y: (5 R + 8 G + 3 B) / 16.
GreyAt      lda   [RowP],y              ; R
            and   #$00FF
            sta   fs
            asl
            asl
            clc
            adc   fs
            sta   fs
            iny
            lda   [RowP],y              ; G
            and   #$00FF
            asl
            asl
            asl
            clc
            adc   fs
            sta   fs
            iny
            lda   [RowP],y              ; B
            and   #$00FF
            sta   ft
            asl
            clc
            adc   ft
            clc
            adc   fs
            dey
            dey
            lsr
            lsr
            lsr
            lsr
            rts

* TopAt: A = the pixel's largest channel.
TopAt       lda   [RowP],y
            and   #$00FF
            sta   fs
            iny
            lda   [RowP],y
            and   #$00FF
            cmp   fs
            bcc   :g
            sta   fs
:g          iny
            lda   [RowP],y
            and   #$00FF
            cmp   fs
            bcc   :b
            sta   fs
:b          dey
            dey
            lda   fs
            rts

* ByPixel: each channel c of each pixel becomes Map[key x 256 + c], the
* key from routine X (Keys: 0 the grey, 2 the largest channel).
ByPixel     stx   KeyX
            stx   fk                    ; (and on the direct page: the loop runs
            lda   tp
            sta   RowP
            lda   tp+2
            sta   RowP+2
            stz   RowY
:row        phb                         ; (the map's bank, for the row)
            lda   MapP+1
            pha
            plb
            plb
            ldy   #0
:pix        ldx   fk                    ; with the data bank the map's)
            jsr   (Keys,x)
            sep   #$20                  ; each channel c: Map[key x 256 + c]
            mx    %10                   ; (the key in B, c in A: TAX takes both)
            xba
            lda   [RowP],y
            tax
            lda   |0,x
            sta   [RowP],y
            iny
            lda   [RowP],y
            tax
            lda   |0,x
            sta   [RowP],y
            iny
            lda   [RowP],y
            tax
            lda   |0,x
            sta   [RowP],y
            iny
            rep   #$20
            mx    %00
            cpy   tstride
            bcc   :pix
            plb
            lda   RowY
            jsr   ProgRow
            bcs   :stop
            jsr   NextRow
            bcc   :row
:stop       clc
            rts
Keys        da    GreyAt,TopAt

* NewMap: a 64K table in a bank of its own (MapP; low word 0).
*   out: carry set and A = error if no memory
NewMap      pha
            pha
            pea   1                     ; ($10000 bytes)
            pea   0
            lda   uid
            pha
            pea   attrBuffer
            PushLong 0
            Tool  _NewHandle
            ply
            sty   MapH
            ply
            sty   MapH+2
            bcs   :err
            lda   MapH
            sta   fs
            lda   MapH+2
            sta   ft
            lda   [fs]
            sta   MapP
            ldy   #2
            lda   [fs],y
            sta   MapP+2
            clc
:err        rts

* FreeMap: disposes of the 64K table.   out: carry clear
FreeMap     PushLongAt MapH
            Tool  _DisposeHandle
            clc
            rts

* Mul32: fn = A x X.
Mul32       sta   fd
            stz   fd+2
            stx   fs
            stz   fn
            stz   fn+2
:bit        lda   fs
            beq   :done
            lsr   fs
            bcc   :shift
            clc
            lda   fn
            adc   fd
            sta   fn
            lda   fn+2
            adc   fd+2
            sta   fn+2
:shift      asl   fd
            rol   fd+2
            bra   :bit
:done       rts

* Times255: fn = fn x 255 (fn x 256 - fn; it fits in 32 bits here).
Times255    lda   fn+2
            sta   ft
            lda   fn
            sta   fs
            lda   fn+1                  ; x 256
            sta   fn+2
            lda   fn
            xba
            and   #$FF00
            sta   fn
            sec                         ; - the old value
            sbc   fs
            sta   fn
            lda   fn+2
            sbc   ft
            sta   fn+2
            rts

* Div32: fn = fn / fd (fd not 0).
Div32       stz   fs                    ; remainder (32 bits: fs, ft)
            stz   ft
            ldx   #32
:bit        asl   fn
            rol   fn+2
            rol   fs
            rol   ft
            lda   fs
            sec
            sbc   fd
            tay
            lda   ft
            sbc   fd+2
            bcc   :no
            sta   ft
            sty   fs
            inc   fn                    ; (the bit just shifted in was 0)
:no         dex
            bne   :bit
            rts

*-------------------------------------------------------------
* Rotate/flip
*-------------------------------------------------------------

* FilterTurn: rotate/flip with GS Remap's bits (the original's): 1 mirror
* (left and right swap), 2 flip (top and bottom swap), 4 turn (rows
* become columns), in that order. With 4 the picture is a new block:
* fhnd its handle, tp its pointer (the caller frees the old one).
*   out: carry clear, or carry set and A = error
FilterTurn  ent
            phb
            phk
            plb
            sta   Turn
            lda   Turn
            and   #1
            beq   :noMirror
            jsr   Mirror
:noMirror   lda   Turn
            and   #2
            beq   :noFlip
            jsr   Flip
:noFlip     lda   Turn
            and   #4
            beq   :done
            jsr   Transpose
            plb
            rtl
:done       clc
            plb
            rtl

* Mirror: each row's pixels in the other order.
Mirror      lda   tp
            sta   RowP
            lda   tp+2
            sta   RowP+2
            stz   RowY
:row        stz   fs                    ; the left pixel
            lda   tstride
            sec
            sbc   #3
            sta   ft                    ; the right one
:pair       lda   fs
            cmp   ft
            bcs   :next
            ldx   #3
            sep   #$20
            mx    %10
:swap       ldy   fs
            lda   [RowP],y
            xba
            ldy   ft
            lda   [RowP],y
            ldy   fs
            sta   [RowP],y
            xba
            ldy   ft
            sta   [RowP],y
            rep   #$20
            mx    %00
            inc   fs
            inc   ft
            sep   #$20
            mx    %10
            dex
            bne   :swap
            rep   #$20
            mx    %00
            lda   ft
            sec
            sbc   #6
            sta   ft
            bra   :pair
:next       jsr   NextRow
            bcc   :row
            rts

* Flip: the rows in the other order.
Flip        lda   rh
            dec
            ldx   tstride
            jsr   Mul32
            lda   tp                    ; DstP: the last row
            clc
            adc   fn
            sta   DstP
            lda   tp+2
            adc   fn+2
            sta   DstP+2
            lda   tp
            sta   RowP
            lda   tp+2
            sta   RowP+2
            lda   rh
            lsr
            sta   fk                    ; pairs of rows
            beq   :done
:pair       ldy   #0
            sep   #$20
            mx    %10
:swap       lda   [RowP],y
            xba
            lda   [DstP],y
            sta   [RowP],y
            xba
            sta   [DstP],y
            iny
            cpy   tstride
            bcc   :swap
            rep   #$20
            mx    %00
            lda   RowP
            clc
            adc   tstride
            sta   RowP
            lda   RowP+2
            adc   #0
            sta   RowP+2
            lda   DstP
            sec
            sbc   tstride
            sta   DstP
            lda   DstP+2
            sbc   #0
            sta   DstP+2
            dec   fk
            bne   :pair
:done       rts

* Transpose: a new picture rh wide and rw high: pixel (x, y) to (y, x).
*   out: fhnd, tp the new picture; carry set and A = error if no memory
Transpose   lda   rw
            ldx   rh
            jsr   Mul32
            lda   fn                    ; x 3
            sta   fd
            lda   fn+2
            sta   fd+2
            asl   fn
            rol   fn+2
            lda   fn
            clc
            adc   fd
            sta   fn
            lda   fn+2
            adc   fd+2
            sta   fn+2
            pha                         ; result: handle
            pha
            PushLongAt fn
            lda   uid
            pha
            pea   attrFile
            PushLong 0
            Tool  _NewHandle
            ply
            sty   fhnd
            ply
            sty   fhnd+2
            bcc   :got
            rts
:got        lda   fhnd
            sta   fs
            lda   fhnd+2
            sta   ft
            lda   [fs]
            sta   NewP
            ldy   #2
            lda   [fs],y
            sta   NewP+2
            lda   rh                    ; the new row length
            asl
            clc
            adc   rh
            sta   NewLen
            lda   tp
            sta   RowP
            lda   tp+2
            sta   RowP+2
            stz   RowY
:row        lda   RowY                  ; column RowY of the new picture
            asl
            clc
            adc   RowY
            clc
            adc   NewP
            sta   DstP
            lda   NewP+2
            adc   #0
            sta   DstP+2
            ldy   #0
:pix        sep   #$20
            mx    %10
            lda   [RowP],y
            sta   [DstP]
            iny
            lda   [RowP],y
            sta   fs
            iny
            lda   [RowP],y
            iny
            phy
            ldy   #2
            sta   [DstP],y
            dey
            lda   fs
            sta   [DstP],y
            ply
            rep   #$20
            mx    %00
            lda   DstP                  ; the next row of the new picture
            clc
            adc   NewLen
            sta   DstP
            lda   DstP+2
            adc   #0
            sta   DstP+2
            cpy   tstride
            bcc   :pix
            jsr   NextRow
            bcc   :row
            lda   NewP
            sta   tp
            lda   NewP+2
            sta   tp+2
            clc
            rts

*-------------------------------------------------------------
* Data
*-------------------------------------------------------------
Factor      dw    0
Weight      dw    0
Divisor     dw    1
Half        dw    0
BodyX       dw    0
KeyX        dw    0
KTab        dw    0
Turn        dw    0
RowLen      dw    0
RowY        dw    0
Bufs        adrl  0,0,0                 ; above, here, below
BufHs       adrl  0,0,0
MapH        adrl  0
NewP        adrl  0
NewLen      dw    0
Total       adrl  0
Lowest      adrl  0
Span        adrl  0
Run         adrl  0
Hist        ds    1024                  ; 256 counts (32 bits)
EqMap       ds    256
WTab        ds    512                   ; Weight x 0-255
DivMax      =     16100                 ; (sharpen's largest sum + half: 16090)
DivTab      ds    DivMax
Div9        ds    2296
EdgeTab     ds    1021

            put   FilterUI.s
            put   TrueDlg.s
            put   FilterData.s
            put   FilterTabs.s
