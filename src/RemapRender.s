*-------------------------------------------------------------
* RemapRender.s - part of the Remap segment: patterns, rendering,
* error diffusion and multipalette.
*-------------------------------------------------------------

pR          =     $D0                   ; (Best: score table pointers on the
pG          =     $D2                   ; direct page)
pB          =     $D4
rAcc        =     $D8                   ; (ColRow: the byte so far)
dErr        =     $DA                   ; (Diffuse: the error, the 7 for the
dC7         =     $D6                   ; next pixel, the next line's cells
dP          =     $DC                   ; behind and after it so far)
dQ          =     $DE

*-------------------------------------------------------------
* 3. Candidates: every pattern (or single colour) the palette can
* make, with its average colour (in display intensities) and its
* spread penalty. Pattern dither: 256 two-pixel (320 mode) or
* four-pixel (640 modes) patterns; closest match: the single
* colours (pairs of them in 640 dither mode).
*-------------------------------------------------------------

* PalGrey: carry clear if every palette entry is reserved or grey.
PalGrey     ldx   #0
:e          lda   PalOut,x
            bit   #$8000
            bne   :next
            jsr   IsGrey
            bcs   :no
:next       inx
            inx
            txa
            lsr
            cmp   ProtoN
            bcc   :e
            clc
            rts
:no         sec
            rts

* BuildCands: the candidates for PalOut, as patterns if Pattern <> 0.
BuildCands  ldx   #0                    ; each entry's intensities
:inten      lda   PalOut,x
            xba
            and   #$000F
            asl
            tay
            lda   Intensity,y
            sta   PalR,x
            lda   PalOut,x
            lsr
            lsr
            lsr
            lsr
            and   #$000F
            asl
            tay
            lda   Intensity,y
            sta   PalG,x
            lda   PalOut,x
            and   #$000F
            asl
            tay
            lda   Intensity,y
            sta   PalB,x
            inx
            inx
            cpx   #32
            bcc   :inten
            lda   #256                  ; how many
            ldx   Pattern
            bne   :n
            lda   ProtoN
            cmp   #8
            bne   :n
            lda   #16
:n          sta   NCand
            stz   CandI
:cand       jsr   CandIdx               ; its entries (Idx, IdxN) and byte
            stz   SumR
            stz   SumG
            stz   SumB
            stz   Dis
            ldy   #0
:sum        ldx   Idx,y
            lda   PalOut,x
            bpl   :usable
            inc   Dis                   ; a reserved entry: never used
:usable     lda   PalR,x
            clc
            adc   SumR
            sta   SumR
            lda   PalG,x
            clc
            adc   SumG
            sta   SumG
            lda   PalB,x
            clc
            adc   SumB
            sta   SumB
            iny
            iny
            tya
            lsr
            cmp   IdxN
            bcc   :sum
            lda   SumR
            jsr   Divide
            sta   AvR
            lda   SumG
            jsr   Divide
            sta   AvG
            lda   SumB
            jsr   Divide
            sta   AvB
            stz   SumR                  ; spread
            ldy   #0
:spread     ldx   Idx,y
            lda   PalR,x
            sec
            sbc   AvR
            jsr   Abs
            sta   t1
            asl
            clc
            adc   t1
            clc
            adc   SumR
            sta   SumR
            lda   PalG,x
            sec
            sbc   AvG
            jsr   Abs
            asl
            asl
            clc
            adc   SumR
            sta   SumR
            lda   PalB,x
            sec
            sbc   AvB
            jsr   Abs
            asl
            clc
            adc   SumR
            sta   SumR
            iny
            iny
            tya
            lsr
            cmp   IdxN
            bcc   :spread
            lda   #$FFFF                ; penalty (a reserved entry: never)
            ldy   Dis
            bne   :pen
            lda   SumR
            jsr   Divide
:pen        sta   t3
            lda   CandI
            asl
            tax
            lda   AvR
            sta   AvgR,x
            lda   AvG
            sta   AvgG,x
            lda   AvB
            sta   AvgB,x
            lda   CandB
            sta   Byt,x
            lda   t3
            sta   Penalty,x
            inc   CandI
            lda   CandI
            cmp   NCand
            bcs   :done
            jmp   :cand
:done       jmp   SortCands

* Divide: A / IdxN (1, 2 or 4), but never 0 unless A is 0.
Divide      ldx   IdxN
            cpx   #1
            beq   :done
            sta   t1
            cpx   #2
            beq   :two
            lsr
:two        lsr
            bne   :done
            ldx   t1
            beq   :done
            lda   #1
:done       rts

* CandIdx: candidate CandI's palette entries (Idx, times 2; IdxN of them)
* and the byte it stands for (CandB).
CandIdx     lda   CandI
            sta   CandB
            ldx   ProtoN
            lda   Pattern
            beq   :closest
            cpx   #16
            bne   :four
            lda   CandI                 ; 320: left pixel, right pixel
            lsr
            lsr
            lsr
            lsr
            asl
            sta   Idx
            lda   CandI
            and   #$000F
            asl
            sta   Idx+2
            lda   #2
            sta   IdxN
            rts
:four       lda   #4                    ; 640: four pixels; 640 dither: odd columns
            sta   IdxN                  ; from entries 4-7
            stz   t2
            cpx   #8
            bne   :f
            lda   #8
            sta   t2
:f          lda   CandI                 ; i >> 6
            lsr
            lsr
            lsr
            lsr
            lsr
            lsr
            and   #$0003
            asl
            sta   Idx
            lda   CandI
            lsr
            lsr
            lsr
            lsr
            and   #$0003
            asl
            clc
            adc   t2
            sta   Idx+2
            lda   CandI
            lsr
            lsr
            and   #$0003
            asl
            sta   Idx+4
            lda   CandI
            and   #$0003
            asl
            clc
            adc   t2
            sta   Idx+6
            rts
:closest    lda   #1
            sta   IdxN
            cpx   #8
            beq   :pair
            lda   CandI                 ; one colour
            asl
            sta   Idx
            cpx   #4
            beq   :c4
            lda   CandI                 ; 320: both nibbles
            asl
            asl
            asl
            asl
            ora   CandI
            sta   CandB
            rts
:c4         lda   CandI                 ; 640: all four pixels
            ldx   #$55
            jsr   Mul16
            lda   MLo
            sta   CandB
            rts
:pair       lda   #2                    ; 640 dither: an even and an odd colour
            sta   IdxN
            lda   CandI
            lsr
            lsr
            asl
            sta   Idx
            lda   CandI
            and   #$0003
            asl
            clc
            adc   #8
            sta   Idx+2
            lda   CandI
            asl
            asl
            asl
            asl
            ora   CandI
            sta   CandB
            rts

* SortCands: the usable candidates (no reserved entry) sorted by AvgG for
* Best: SR2, SG2, SB2 (each average times 2), BSP (penalty / 16) and BSI (the
* candidate) from 0 to NSort - 2 (bytes); GStart: where each green value
* starts (GStart+512: NSort). Also the score tables, the first time.
SortCands   lda   WReady
            bne   :count
            ldx   #0                    ; BW3, BW4, BW2: 3, 4 and 2 times |j - 255|
:w          txa
            lsr
            sec
            sbc   #255
            bpl   :pos
            eor   #$FFFF
            inc
:pos        sta   t1
            asl
            sta   BW2,x
            clc
            adc   t1
            sta   BW3,x
            lda   BW2,x
            asl
            sta   BW4,x
            inx
            inx
            cpx   #1022
            bcc   :w
            inc   WReady
:count      ldx   #512                  ; how many of each green
:z          stz   GStart,x
            dex
            dex
            bpl   :z
            lda   NCand
            dec
            asl
            tax
:c          lda   Penalty,x
            bmi   :cn
            lda   AvgG,x
            asl
            tay
            lda   GStart,y
            inc
            inc
            sta   GStart,y
:cn         dex
            dex
            bpl   :c
            ldx   #0                    ; where each ends
            lda   #0
:e          clc
            adc   GStart,x
            sta   GStart,x
            inx
            inx
            cpx   #512
            bcc   :e
            sta   GStart+512
            sta   NSort
            lda   NCand                 ; each candidate at the end of its green,
            dec                         ; which leaves GStart where each starts
            asl
            sta   t2
:put        ldx   t2
            lda   Penalty,x
            bmi   :pn
            lda   AvgG,x
            asl
            tay
            lda   GStart,y
            dec
            dec
            sta   GStart,y
            tay
            lda   Penalty,x
            lsr
            lsr
            lsr
            lsr
            sta   BSP,y
            lda   AvgR,x
            asl
            sta   SR2,y
            lda   AvgG,x
            asl
            sta   SG2,y
            lda   AvgB,x
            asl
            sta   SB2,y
            txa
            lsr
            sta   BSI,y
:pn         dec   t2
            dec   t2
            bpl   :put
            rts

* Best: the candidate closest to the target BR, BG, BB.
*   score = 3|R-r| + 4|G-g| + 2|B-b| + penalty/16; the highest index
*   wins ties; 0 if every candidate has a reserved entry.
*   Searched outwards from the target's green in SortCands' order: no
*   candidate further away can do better once 4|G-g| alone is more than
*   the best score.   out: A = candidate number
Best        lda   #255                  ; pR, pG, pB: the score tables at the
            sec                         ; target (y = 2 x the average)
            sbc   BR
            asl
            clc
            adc   #BW3
            sta   pR
            lda   #255
            sec
            sbc   BG
            asl
            clc
            adc   #BW4
            sta   pG
            lda   #255
            sec
            sbc   BB
            asl
            clc
            adc   #BW2
            sta   pB
            lda   #$7D00
            sta   BestScore
            stz   BestIndex
            lda   BG
            asl
            tax
            lda   GStart,x
            sta   t2                    ; (the first one below)
            tax
:up         cpx   NSort                 ; upwards
            bcs   :down
            ldy   SG2,x
            lda   (pG),y
            cmp   BestScore
            beq   :u1
            bcs   :down
:u1         ldy   SR2,x
            clc
            adc   (pR),y
            ldy   SB2,x
            adc   (pB),y
            adc   BSP,x
            cmp   BestScore
            bcc   :uBest
            bne   :uNext
            lda   BSI,x                 ; a tie: the higher candidate
            cmp   BestIndex
            bcc   :uNext
            sta   BestIndex
            bra   :uNext
:uBest      sta   BestScore
            lda   BSI,x
            sta   BestIndex
:uNext      inx
            inx
            bra   :up
:down       ldx   t2                    ; downwards
:dNext      dex
            dex
            bmi   :done
            ldy   SG2,x
            lda   (pG),y
            cmp   BestScore
            beq   :d1
            bcs   :done
:d1         ldy   SR2,x
            clc
            adc   (pR),y
            ldy   SB2,x
            adc   (pB),y
            adc   BSP,x
            cmp   BestScore
            bcc   :dBest
            bne   :dNext
            lda   BSI,x
            cmp   BestIndex
            bcc   :dNext
            sta   BestIndex
            bra   :dNext
:dBest      sta   BestScore
            lda   BSI,x
            sta   BestIndex
            bra   :dNext
:done       lda   BestIndex
            rts

* Lookup: the bytes for the target BR, BG, BB.
*   out: A = even line byte * 256 + odd line byte
Lookup      jsr   Best
            sta   First
            ldx   Pattern
            bne   :pattern
            asl                         ; one colour: the same on every line
            tax
            lda   Byt,x
            and   #$00FF
            sta   t1
            xba
            ora   t1
            rts
:pattern    asl
            tax
            lda   BR                    ; aim the second pattern at what
            asl                         ; the first one missed
            sec
            sbc   AvgR,x
            jsr   Clamp
            sta   BR
            lda   BG
            asl
            sec
            sbc   AvgG,x
            jsr   Clamp
            sta   BG
            lda   BB
            asl
            sec
            sbc   AvgB,x
            jsr   Clamp
            sta   BB
            jsr   Best
            cmp   First
            beq   :firstOn
            bcc   :firstOn
            xba                         ; second on even lines,
            sta   t1                    ; first (nibbles swapped) on odd
            lda   First
            jsr   SwapNibbles
            ora   t1
            rts
:firstOn    jsr   SwapNibbles           ; first on even lines,
            sta   t1                    ; second (swapped) on odd
            lda   First
            xba
            ora   t1
            rts

SwapNibbles and   #$00FF
            sta   t2
            asl
            asl
            asl
            asl
            and   #$00F0
            sta   t3
            lda   t2
            lsr
            lsr
            lsr
            lsr
            ora   t3
            rts

Clamp       bpl   :pos
            lda   #0
            rts
:pos        cmp   #256
            bcc   :ok
            lda   #255
:ok         rts

* SetTarget: BR, BG, BB = display intensities of the colour in A.
SetTarget   sta   t1
            xba
            and   #$000F
            asl
            tay
            lda   Intensity,y
            sta   BR
            lda   t1
            lsr
            lsr
            lsr
            lsr
            and   #$000F
            asl
            tay
            lda   Intensity,y
            sta   BG
            lda   t1
            and   #$000F
            asl
            tay
            lda   Intensity,y
            sta   BB
            rts

*-------------------------------------------------------------
* 4. Rendering lines LineA to LineB - 1 with PalOut
*-------------------------------------------------------------
RenderLines stz   P50OK                 ; (RowOut, Cur, Nxt: Reduce's tables go)
            stz   GreyMode
            jsr   PalGrey
            bcs   :colour
            inc   GreyMode
            jsr   MakeGrey              ; (the greys, if not made yet)
            lda   OAlg                  ; greys: patterns for pattern dither only
            cmp   #1
            bne   :closest
            bra   :pat
:colour     lda   OAlg                  ; colours: patterns but for closest match
            beq   :closest
:pat        lda   #1
            sta   Pattern
            bra   :cands
:closest    stz   Pattern
:cands      jsr   BuildCands
            inc   RGen                  ; nothing worked out yet in this call
            ldx   #510
            lda   #0
:clear      sta   GreyOK,x
            dex
            dex
            bpl   :clear
            lda   GreyMode
            beq   RenderRows
            lda   OAlg
            cmp   #2
            bne   RenderRows
            jmp   Diffuse

* RenderRows: lines LineA to LineB - 1 as RenderLines would, with what its
* last call worked out (the same palette; error diffusion starts afresh).
RenderRows  lda   GreyMode
            beq   :lines
            lda   OAlg
            cmp   #2
            bne   :lines
            jmp   RenderLines
:lines      ldy   #16                   ; the masks for the pixels in a byte
            lda   ProtoN                ; (320 mode: 2, 640 modes: 4)
            cmp   #16
            bne   :m0
            ldy   #0
:m0         ldx   #0
:m          lda   PixMasks,y
            sta   PMask,x
            iny
            iny
            inx
            inx
            cpx   #16
            bcc   :m
            lda   LineA
            sta   RowY
:row        lda   RowY
            cmp   LineB
            bcc   :more
            rts
:more       jsr   PlaneRow              ; (the planes read in place)
            jsr   ClearRowOut
            lda   RowY                  ; even line: the high byte of the
            and   #1                    ; looked up word, odd: the low one
            sta   Odd
            ldy   #0
            sty   OutI
            lda   GreyMode
            bne   :byte
            jsr   ColRow                ; (colours: the quicker loop)
            bra   :stored
:byte       ldx   #0                    ; the pixels of each output byte
            stx   Acc
:pb         stx   PixK
            jsr   PixVal
            ldx   Odd
            bne   :lo
            xba
:lo         ldx   PixK
            and   PMask,x
            ora   Acc
            sta   Acc
            iny
            iny
            cpy   ROutW2
            bcs   :put
            inx
            inx
            lda   PMask,x
            bne   :pb
:put        ldx   OutI
            lda   Acc
            sep   #$20
            mx    %10
            sta   RowOut,x
            rep   #$20
            mx    %00
            inx
            stx   OutI
            cpy   ROutW2
            bcc   :byte
:stored     jsr   StoreRow
            inc   RowY
            jmp   :row

* ColRow: RenderLines' line into RowOut, for colours: each pixel's word
* from CacheVal if Hist says it was looked up in this call (else Miss),
* its bits by the mode's and the line's masks.
ColRow      lda   ProtoN
            cmp   #16
            bne   :w
            lda   Odd
            bne   :o3
            jmp   ColE320
:o3         jmp   ColO320
:w          lda   Odd
            bne   :o6
            jmp   ColE640
:o6         jmp   ColO640

* ColRow's loops: the pixels of each output byte unrolled, their masks
* fixed (even lines: the looked-up word's high byte).
ColE320     ldy   #0
:byte       lda   [p1],y
            asl
            tax
            lda   Hist,x
            cmp   RGen
            beq   :h0
            jsr   Miss
:h0         lda   CacheVal,x
            and   #$F000
            sta   rAcc
            iny
            iny
            cpy   ROutW2
            bcs   :put
            lda   [p1],y
            asl
            tax
            lda   Hist,x
            cmp   RGen
            beq   :h1
            jsr   Miss
:h1         lda   CacheVal,x
            and   #$0F00
            ora   rAcc
            sta   rAcc
            iny
            iny
:put        lda   rAcc
            xba
            ldx   OutI
            sep   #$20
            mx    %10
            sta   RowOut,x
            rep   #$20
            mx    %00
            inx
            stx   OutI
            cpy   ROutW2
            bcs   :done
            jmp   :byte
:done       rts

ColO320     ldy   #0
:byte       lda   [p1],y
            asl
            tax
            lda   Hist,x
            cmp   RGen
            beq   :h0
            jsr   Miss
:h0         lda   CacheVal,x
            and   #$00F0
            sta   rAcc
            iny
            iny
            cpy   ROutW2
            bcs   :put
            lda   [p1],y
            asl
            tax
            lda   Hist,x
            cmp   RGen
            beq   :h1
            jsr   Miss
:h1         lda   CacheVal,x
            and   #$000F
            ora   rAcc
            sta   rAcc
            iny
            iny
:put        lda   rAcc
            ldx   OutI
            sep   #$20
            mx    %10
            sta   RowOut,x
            rep   #$20
            mx    %00
            inx
            stx   OutI
            cpy   ROutW2
            bcs   :done
            jmp   :byte
:done       rts

ColE640     ldy   #0
:byte       lda   [p1],y
            asl
            tax
            lda   Hist,x
            cmp   RGen
            beq   :h0
            jsr   Miss
:h0         lda   CacheVal,x
            and   #$C000
            sta   rAcc
            iny
            iny
            cpy   ROutW2
            bcs   :put
            lda   [p1],y
            asl
            tax
            lda   Hist,x
            cmp   RGen
            beq   :h1
            jsr   Miss
:h1         lda   CacheVal,x
            and   #$3000
            ora   rAcc
            sta   rAcc
            iny
            iny
            cpy   ROutW2
            bcs   :put
            lda   [p1],y
            asl
            tax
            lda   Hist,x
            cmp   RGen
            beq   :h2
            jsr   Miss
:h2         lda   CacheVal,x
            and   #$0C00
            ora   rAcc
            sta   rAcc
            iny
            iny
            cpy   ROutW2
            bcs   :put
            lda   [p1],y
            asl
            tax
            lda   Hist,x
            cmp   RGen
            beq   :h3
            jsr   Miss
:h3         lda   CacheVal,x
            and   #$0300
            ora   rAcc
            sta   rAcc
            iny
            iny
:put        lda   rAcc
            xba
            ldx   OutI
            sep   #$20
            mx    %10
            sta   RowOut,x
            rep   #$20
            mx    %00
            inx
            stx   OutI
            cpy   ROutW2
            bcs   :done
            jmp   :byte
:done       rts

ColO640     ldy   #0
:byte       lda   [p1],y
            asl
            tax
            lda   Hist,x
            cmp   RGen
            beq   :h0
            jsr   Miss
:h0         lda   CacheVal,x
            and   #$00C0
            sta   rAcc
            iny
            iny
            cpy   ROutW2
            bcs   :put
            lda   [p1],y
            asl
            tax
            lda   Hist,x
            cmp   RGen
            beq   :h1
            jsr   Miss
:h1         lda   CacheVal,x
            and   #$0030
            ora   rAcc
            sta   rAcc
            iny
            iny
            cpy   ROutW2
            bcs   :put
            lda   [p1],y
            asl
            tax
            lda   Hist,x
            cmp   RGen
            beq   :h2
            jsr   Miss
:h2         lda   CacheVal,x
            and   #$000C
            ora   rAcc
            sta   rAcc
            iny
            iny
            cpy   ROutW2
            bcs   :put
            lda   [p1],y
            asl
            tax
            lda   Hist,x
            cmp   RGen
            beq   :h3
            jsr   Miss
:h3         lda   CacheVal,x
            and   #$0003
            ora   rAcc
            sta   rAcc
            iny
            iny
:put        lda   rAcc
            ldx   OutI
            sep   #$20
            mx    %10
            sta   RowOut,x
            rep   #$20
            mx    %00
            inx
            stx   OutI
            cpy   ROutW2
            bcs   :done
            jmp   :byte
:done       rts


* Miss: colour X/2 looked up (CacheVal,x) and marked in Hist. Keeps X, Y.
Miss        lda   RGen
            sta   Hist,x
            phy
            phx
            txa
            lsr
            jsr   SetTarget
            jsr   Lookup
            plx
            sta   CacheVal,x
            ply
            rts

* PixVal: the looked-up word (even line byte * 256 + odd line byte) for
* the pixel at plane offset Y (2 bytes a pixel). Keeps Y.
PixVal      lda   GreyMode
            bne   :grey
            lda   [p1],y                ; colours: by 12-bit colour (Hist
            asl                         ; says which have been looked up in
            tax                         ; this call)
            lda   Hist,x
            cmp   RGen
            bne   :miss
            lda   CacheVal,x
            rts
:miss       lda   RGen
            sta   Hist,x
            phy
            phx
            txa
            lsr
            jsr   SetTarget
            jsr   Lookup
            plx
            sta   CacheVal,x
            ply
            rts
:grey       phy                         ; greys: by grey level
            tya
            lsr
            clc
            adc   ROutW2
            tay
            lda   [p1],y
            and   #$00FF
            asl
            tax
            lda   GreyOK,x
            bne   :gHave
            phx
            txa
            lsr
            sta   BR
            sta   BG
            sta   BB
            jsr   Lookup
            plx
            sta   GreyVal,x
            lda   #1
            sta   GreyOK,x
:gHave      lda   GreyVal,x
            ply
            rts

* FreshCache: Hist (once the palettes are made) cleared for RenderLines'
* marks: a colour has been looked up in this call if its word is RGen.
FreshCache  ldx   #8190
            lda   #0
:z          sta   Hist,x
            dex
            dex
            bpl   :z
            stz   RGen
            rts

PixMasks    dw    $F0,$0F,0,0,0,0,0,0
            dw    $C0,$30,$0C,$03,0,0,0,0
* PutPixel: pixel PixX/2 from pattern byte A into RowOut.
PutPixel    sta   t1
            lda   PixX
            lsr
            sta   t2                    ; x
            ldx   ProtoN
            cpx   #16
            bne   :wide
            lsr                         ; 320: a nibble
            tay
            lda   t2
            lsr
            lda   t1
            bcs   :right
            and   #$00F0
            bra   :or
:right      and   #$000F
:or         sep   #$20
            mx    %10
            ora   RowOut,y
            sta   RowOut,y
            rep   #$20
            mx    %00
            rts
:wide       lsr                         ; 640: the byte's two bits for this column
            lsr
            tay
            lda   t2
            and   #$0003
            asl
            tax
            lda   t1
            and   ColMask,x
            sep   #$20
            mx    %10
            ora   RowOut,y
            sta   RowOut,y
            rep   #$20
            mx    %00
            rts

ColMask     dw    $C0,$30,$0C,$03

* ClearRowOut, StoreRow: RowOut (160 bytes) and line RowY of the screen.
ClearRowOut ldx   #158
:z          stz   RowOut,x
            dex
            dex
            bpl   :z
            rts

StoreRow    lda   RowY
            asl
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
            ldx   #0
:c          lda   RowOut,x
            sta   [scrp],y
            iny
            iny
            inx
            inx
            cpx   #160
            bcc   :c
            rts

*-------------------------------------------------------------
* Error diffusion (grey palettes): Floyd-Steinberg, the lines
* scanned alternately left to right and right to left
*-------------------------------------------------------------
Diffuse     stz   CandI                 ; the byte for every grey level
:level      lda   CandI
            sta   BR
            sta   BG
            sta   BB
            jsr   Lookup                ; (closest match: even = odd)
            xba
            and   #$00FF
            pha
            lda   CandI
            asl
            tax
            pla
            sta   GreyVal,x
            inc   CandI
            lda   CandI
            cmp   #256
            bcc   :level
            stz   CandI                 ; DTab (column x 256 + level, words):
:gt         lda   CandI                 ; the level's bits for the column in
            and   #$00FF                ; the high byte, the grey they show
            asl                         ; (GreyOf) in the low byte; it
            tax                         ; depends on nothing else
            lda   GreyVal,x
            sta   PByte
            lda   CandI
            xba
            and   #$0003
            asl
            sta   PixX
            jsr   GreyOf
            sta   t2                    ; (shown)
            lda   CandI
            and   #$00FF
            asl
            tax
            lda   GreyVal,x
            sta   t1                    ; (the byte)
            ldx   PixX
            lda   ProtoN
            cmp   #16
            bne   :gw
            lda   t1
            and   Mask320,x
            bra   :gm
:gw         lda   t1
            and   ColMask,x
:gm         xba
            ora   t2
            pha
            lda   CandI
            asl
            tax
            pla
            sta   DTab,x
            inc   CandI
            lda   CandI
            cmp   #1024
            bcc   :gt
            stz   DW                    ; (640 modes: 4 pixels a byte)
            lda   ProtoN
            cmp   #16
            beq   :dw
            inc   DW
:dw         ldx   #0                    ; no error to pass on yet
:z          stz   Cur,x
            stz   Nxt,x
            inx
            inx
            cpx   #1290
            bcc   :z
            lda   LineA
            sta   RowY
:row        lda   RowY
            cmp   LineB
            bcc   :more
            rts
:more       jsr   PlaneRow              ; (the grey plane read in place)
            jsr   ClearRowOut
            stz   dC7                   ; (the errors to pass on: 7 to the
            stz   dP                    ; next pixel; the next line's cell
            stz   dQ                    ; behind it, and the one after, so far)
            lda   RowY                  ; direction
            sec
            sbc   LineA
            and   #$0001
            bne   :rtl
            stz   PixX                  ; left to right: x from 0, step +1
            lda   #2
            sta   DStep
            lda   ROutW2
            sta   GY
            bra   :go
:rtl        lda   ROutW2                 ; right to left
            dec
            dec
            sta   PixX
            lda   #-2
            sta   DStep
            lda   ROutW2
            clc
            adc   ROutW
            dec
            sta   GY
:go         lda   ROutW
            sta   DCount
:pix        ldx   PixX                  ; wanted = level + (error + 8) / 16
            lda   Cur+2,x
            clc
            adc   dC7
            clc
            adc   #8
            cmp   #$8000
            ror
            cmp   #$8000
            ror
            cmp   #$8000
            ror
            cmp   #$8000
            ror
            ldy   GY
            sta   t1
            lda   [p1],y
            and   #$00FF
            clc
            adc   t1
            sta   Wanted
            bpl   :pos
            lda   #0
            bra   :idx
:pos        cmp   #256
            bcc   :idx
            lda   #255
:idx        sta   t3
            txa                         ; its bits and grey (DTab)
            and   #$0006
            xba
            lsr
            ora   t3
            asl
            tay
            lda   DTab,y
            sta   t1
            txa                         ; the output byte
            lsr
            lsr
            ldy   DW
            beq   :n3
            lsr
:n3         tay
            lda   t1
            xba
            sep   #$20
            mx    %10
            ora   RowOut,y
            sta   RowOut,y
            rep   #$20
            mx    %00
            lda   t1                    ; error = wanted - the grey shown
            and   #$00FF
            eor   #$FFFF
            sec
            adc   Wanted
            sta   dErr
            asl                         ; spread it: 3 behind below (that
            clc                         ; cell then done), 5 below, 1 ahead
            adc   dErr                  ; below, 7 to the next pixel (the
            clc                         ; same sums, added in another order)
            adc   dP
            bit   DStep
            bmi   :back
            sta   Nxt,x                 ; left to right: behind is x - 2
            inc   GY
            bra   :five
:back       sta   Nxt+4,x               ; right to left: behind is x + 2
            dec   GY
:five       lda   dErr
            asl
            asl
            clc
            adc   dErr                  ; 5
            clc
            adc   dQ
            sta   dP
            lda   dErr                  ; 1
            sta   dQ
            asl
            asl
            asl
            sec
            sbc   dErr                  ; 7
            sta   dC7
            txa
            clc
            adc   DStep
            sta   PixX
            dec   DCount
            beq   :rowDone
            jmp   :pix
:rowDone    lda   PixX                  ; the last two cells below
            clc
            adc   #2
            tax
            lda   dQ
            sta   Nxt,x
            txa
            sec
            sbc   DStep
            tax
            lda   dP
            sta   Nxt,x
            jsr   StoreRow
            lda   ROutW2                ; the line below becomes current
            clc                         ; (every cell of it was stored)
            adc   #4
            sta   t1
            ldx   #0
:sw         lda   Nxt,x
            sta   Cur,x
            inx
            inx
            cpx   t1
            bcc   :sw
            inc   RowY
            jmp   :row

Mask320     dw    $F0,$0F,$F0,$0F

* GreyOf: the display intensity of the palette entry the pattern byte
* PByte puts at column PixX/2 (its green).
GreyOf      lda   PixX
            lsr
            sta   t2
            ldx   ProtoN
            cpx   #16
            bne   :wide
            lsr                         ; 320: the nibble
            lda   PByte
            bcs   :low
            lsr
            lsr
            lsr
            lsr
:low        and   #$000F
            bra   :entry
:wide       and   #$0003                ; 640: the column's two bits
            eor   #$0003
            asl
            tay
            lda   PByte
:sh         cpy   #0
            beq   :got
            lsr
            dey
            bra   :sh
:got        and   #$0003
            cpx   #8                    ; dither mode: odd columns use 4-7
            bne   :entry
            pha
            lda   t2
            lsr
            pla
            bcc   :entry
            adc   #3                    ; (+ carry = 4)
:entry      asl
            tax
            lda   PalOut,x
            lsr
            lsr
            lsr
            lsr
            and   #$000F
            asl
            tax
            lda   Intensity,x
            rts

*-------------------------------------------------------------
* Multipalette: a palette for each group of lines (up to 16, or 8)
*-------------------------------------------------------------
Multi       lda   #16                   ; how many palettes
            ldx   MPTech
            cpx   #1
            beq   :eight
            cpx   #4
            bne   :n
:eight      lda   #8
:n          cmp   ROutH
            bcc   :count
            lda   ROutH
:count      sta   MPCount
            ldy   #2                    ; passes: zones 0, optimized 8, else 2
            cpx   #3
            bcs   :none
            cpx   #2
            bne   :p
            ldy   #8
            bra   :p
:none       ldy   #0
:p          sty   MPPasses
            stz   RowY                  ; first: lines shared out evenly
:own        lda   RowY
            ldx   MPCount
            jsr   Mul16
            lda   MLo
            sta   n0
            lda   MHi
            sta   n0+2
            lda   ROutH
            jsr   Div32
            pha
            lda   RowY
            asl
            tax
            pla
            sta   Owner,x
            inc   RowY
            lda   RowY
            cmp   ROutH
            bcc   :own
            stz   HavePrev
            jsr   MPTables
            lda   MPPasses
            bne   :passes
            jmp   :render
:passes     jsr   Present               ; the colours in the picture
            jsr   NewMinD
            bcc   :pass
            jmp   :render               ; (no memory: the even shares)
:pass       jsr   MinDist               ; each palette's distance to each colour
            stz   Changed
            stz   RowY
:line       lda   RowY                  ; the best palette for the line: the
            jsr   GetLine               ; lowest cost below $FFFF, the lower
            lda   #$FFFF                ; palette of two equal ones, or the
            sta   BestCost              ; owner; the owner tried first, as a
            sta   Limit                 ; bound for the others
            lda   RowY
            asl
            tax
            lda   Owner,x
            sta   BestP
            sta   OwnP
            sta   MPOwn
            jsr   LineCost
            bcs   :others
            sta   BestCost
:others     stz   MPOwn
:try        lda   MPOwn
            cmp   OwnP
            beq   :nextP
            lda   BestCost              ; a lower palette may equal the best
            cmp   #$FFFF
            beq   :lim
            ldx   MPOwn
            cpx   BestP
            bcs   :lim
            inc
:lim        sta   Limit
            jsr   LineCost
            bcs   :nextP
            sta   BestCost
            lda   MPOwn
            sta   BestP
:nextP      inc   MPOwn
            lda   MPOwn
            cmp   MPCount
            bcc   :try
            lda   RowY
            asl
            tax
            lda   BestP
            cmp   Owner,x
            beq   :same
            sta   Owner,x
            inc   Changed
:same       inc   RowY
            lda   RowY
            cmp   ROutH
            bcs   :lines
            jmp   :line
:lines      lda   Changed
            beq   :settled
            inc   HavePrev
            jsr   MPTables
            dec   MPPasses
            beq   :settled
            jmp   :pass
:settled    jsr   FreeMinD
:render     jsr   FreshCache
            stz   MPOwn                 ; each palette's runs of lines in turn
:pal        jsr   UseTable              ; (PalOut = its palette; its lookups
            stz   PalSet                ; kept from one run to the next)
            stz   RowY
:run        lda   RowY
            cmp   ROutH
            bcc   :look
            jmp   :nextPal
:look       sta   LineA
            asl
            tax
            lda   Owner,x
            cmp   MPOwn
            beq   :end
            inc   RowY
            bra   :run
:end        inx
            inx
            txa
            lsr
            cmp   ROutH
            bcs   :runEnd
            lda   Owner,x
            cmp   MPOwn
            beq   :end
:runEnd     txa
            lsr
            sta   LineB
            pha
            lda   PalSet
            bne   :again
            inc   PalSet
            jsr   RenderLines
            bra   :rendered
:again      jsr   RenderRows
:rendered   pla
            sta   LineB
            ldy   LineA                 ; their SCBs: the palette number
:scb        tya
            clc
            adc   #scbOffset
            phy
            tay
            lda   MPOwn
            sep   #$20
            mx    %10
            sta   [scrp],y
            rep   #$20
            mx    %00
            ply
            iny
            cpy   LineB
            bcc   :scb
            lda   LineB
            sta   RowY
            bra   :run
:nextPal    inc   MPOwn
            lda   MPOwn
            cmp   MPCount
            bcs   :tables
            jmp   :pal
:tables     stz   MPOwn                 ; the colour tables
:tab        jsr   UseTable
            ldx   MPOwn
            jsr   PutTable
            inc   MPOwn
            lda   MPOwn
            cmp   MPCount
            bcc   :tab
            rts

* LineCost: palette MPOwn's cost for the line (LineC): its pixels'
* distances, given up once it reaches Limit (or 16 bits).
*   out: carry clear and A = the cost if it is below Limit
LineCost    jsr   MinAt
            lda   #0                    ; (the sum in A; the carry is clear
            ldx   #0                    ; whenever the loop goes on)
            clc
:px         ldy   LineC,x               ; (colour x 2: GetLine)
            adc   [q1],y
            bcs   :no
            cmp   Limit
            bcs   :no
            inx
            inx
            cpx   ROutW2
            bcc   :px
            clc
            rts
:no         sec
            rts

* MPTables: each palette from the colours of its lines; a palette with no
* lines keeps the one it had (after the first time).
MPTables    stz   MPOwn
:p          stz   LineA
            lda   ROutH
            sta   LineB
            jsr   OwnsLines
            bcs   :none
            jsr   HistLines
            bra   :calc
:none       lda   HavePrev
            bne   :keep
            ldx   #8190                 ; (an empty histogram)
            lda   #0
:clr        sta   Hist,x
            dex
            dex
            bpl   :clr
:calc       jsr   CalcPalette
            lda   MPOwn                 ; Tables[p] = PalOut
            asl
            asl
            asl
            asl
            asl
            tay
            ldx   #0
:copy       lda   PalOut,x
            sta   Tables,y
            iny
            iny
            inx
            inx
            cpx   #32
            bcc   :copy
:keep       inc   MPOwn
            lda   MPOwn
            cmp   MPCount
            bcc   :p
            rts

* OwnsLines: carry clear if palette MPOwn has a line.
OwnsLines   ldx   #0
:l          lda   Owner,x
            cmp   MPOwn
            beq   :yes
            inx
            inx
            txa
            lsr
            cmp   ROutH
            bcc   :l
            sec
            rts
:yes        clc
            rts

* UseTable: PalOut = Tables[MPOwn].
UseTable    lda   MPOwn
            asl
            asl
            asl
            asl
            asl
            tay
            ldx   #0
:copy       lda   Tables,y
            sta   PalOut,x
            iny
            iny
            inx
            inx
            cpx   #32
            bcc   :copy
            rts

* Present: PList = the colours in the picture (NPresent of them).
Present     stz   LineA
            lda   ROutH
            sta   LineB
            lda   OMode                 ; (every line, whatever its palette)
            pha
            stz   OMode
            jsr   HistLines
            pla
            sta   OMode
            stz   NPresent
            ldx   #0
:c          lda   Hist,x
            beq   :n
            ldy   NPresent
            txa
            lsr
            sta   PList,y
            iny
            iny
            sty   NPresent
:n          inx
            inx
            cpx   #8192
            bcc   :c
            lsr   NPresent              ; (a count, not bytes)
            rts

* MinDist: for each palette and each colour in the picture, the distance
* to its nearest usable palette colour (MinD: 4096 words a palette).
MinDist     stz   MPOwn
:p          jsr   MinAt                 ; q1 = its table
            lda   MPOwn
            asl
            asl
            asl
            asl
            asl
            sta   u0                    ; its palette in Tables
            stz   NE                    ; its usable entries' 3 R, 4 G, 2 B
            ldx   #0
:pe         phx
            txa
            clc
            adc   u0
            tay
            lda   Tables,y
            bmi   :peNext               ; reserved
            and   #$0FFF
            jsr   DistSet
            ldy   NE
            lda   FA
            sta   ER3,y
            lda   FB
            sta   EG4,y
            lda   FC
            sta   EB2,y
            iny
            iny
            sty   NE
:peNext     plx
            inx
            inx
            cpx   #32
            bcc   :pe
            jsr   SortE                 ; (by green)
            stz   u1                    ; colour number in PList
:c          lda   u1
            cmp   NPresent
            bcc   :col
            jmp   :nextP
:col        asl
            tax
            lda   PList,x
            sta   DC1
            jsr   DistSet               ; (distances from it)
            lda   #$FFFF                ; the nearest entry: outwards from
            sta   Nearest               ; the colour's green (no entry further
            ldx   #0                    ; on can come nearer once 4 |dG|
:st         cpx   NE                    ; alone reaches the nearest)
            bcs   :up
            lda   EG4,x
            cmp   FB
            bcs   :up
            inx
            inx
            bra   :st
:up         stx   EStart
:upE        cpx   NE
            bcs   :down
            lda   EG4,x
            sec
            sbc   FB
            cmp   Nearest
            bcs   :down
            jsr   EDist
            cmp   Nearest
            bcs   :upN
            sta   Nearest
:upN        inx
            inx
            bra   :upE
:down       ldx   EStart
:dnE        dex
            dex
            bmi   :store
            lda   FB
            sec
            sbc   EG4,x
            cmp   Nearest
            bcs   :store
            jsr   EDist
            cmp   Nearest
            bcs   :dnE
            sta   Nearest
            bra   :dnE
:store      lda   DC1
            asl
            tay
            lda   Nearest
            sta   [q1],y
            inc   u1
            jmp   :c
:nextP      inc   MPOwn
            lda   MPOwn
            cmp   MPCount
            bcs   :done
            jmp   :p
:done       rts

* EDist: the distance from DistSet's colour to entry X/2 of MinDist's
* (DistTo's sums, with the entry's parts ready). Keeps X.
EDist       lda   ER3,x                 ; a
            sec
            sbc   FA
            sta   DA
            bpl   :a
            eor   #$FFFF
            inc
:a          sta   DS
            lda   EG4,x                 ; b
            sec
            sbc   FB
            sta   DB
            bpl   :b
            eor   #$FFFF
            inc
:b          clc
            adc   DS
            sta   DS
            lda   EB2,x                 ; c
            sec
            sbc   FC
            sta   DCc
            bpl   :c
            eor   #$FFFF
            inc
:c          clc
            adc   DS
            sta   DS
            lda   DA                    ; |a + b + c| / 4
            clc
            adc   DB
            clc
            adc   DCc
            bpl   :s
            eor   #$FFFF
            inc
:s          lsr
            lsr
            clc
            adc   DS
            rts

* SortE: MinDist's entries in order of green (an insertion sort).
SortE       ldx   #2
:i          cpx   NE
            bcs   :done
            lda   ER3,x
            sta   t1
            lda   EG4,x
            sta   t2
            lda   EB2,x
            sta   t3
            txy
:j          cpy   #2
            bcc   :put
            lda   EG4-2,y
            cmp   t2
            bcc   :put
            beq   :put
            sta   EG4,y
            lda   ER3-2,y
            sta   ER3,y
            lda   EB2-2,y
            sta   EB2,y
            dey
            dey
            bra   :j
:put        lda   t1
            sta   ER3,y
            lda   t2
            sta   EG4,y
            lda   t3
            sta   EB2,y
            inx
            inx
            bra   :i
:done       rts

* MinAt: q1 = palette MPOwn's distance table (MinP + p * 8192).
MinAt       lda   MPOwn
            xba
            asl
            asl
            asl
            asl
            asl
            clc
            adc   MinP
            sta   q1
            php
            lda   MPOwn
            lsr
            lsr
            lsr
            plp
            adc   MinP+2
            sta   q1+2
            rts

* NewMinD / FreeMinD: the distance tables (16 x 8192 bytes).
NewMinD     pha
            pha
            PushLong $20000
            lda   uid
            pha
            pea   $C008
            PushLong 0
            Tool  _NewHandle
            tax
            pla
            sta   MinH
            pla
            sta   MinH+2
            txa
            bcs   :err
            lda   MinH
            sta   n1
            lda   MinH+2
            sta   n1+2
            lda   [n1]
            sta   MinP
            ldy   #2
            lda   [n1],y
            sta   MinP+2
            clc
:err        rts

FreeMinD    lda   MinH
            ora   MinH+2
            beq   :none
            PushLongAt MinH
            Tool  _DisposeHandle
            stz   MinH
            stz   MinH+2
:none       rts

*-------------------------------------------------------------
* Data
*-------------------------------------------------------------

* Display intensity of a 4-bit colour channel (from SuperConvert).
Intensity   dw    0,1,5,10,18,28,41,56,73,92,113,137,163,192,222,255

BitMask     dw    $0001,$0002,$0004,$0008,$0010,$0020,$0040,$0080
            dw    $0100,$0200,$0400,$0800,$1000,$2000,$4000,$8000

* Prototypes: calculated, default, greys; for 320, 640 and 640 dither mode
* (16 words each; $4000 = calculate, $8000 = reserved).
ProtoSets   da    CalcProtos,DefProtos,GreyProtos
CalcProtos  dw    $0000,$4777,$4841,$472C,$400F,$4080,$4F70,$4D00
            dw    $4FA9,$4FF0,$40E0,$44DF,$4DAF,$478F,$4CCC,$0FFF
            dw    $0000,$4F00,$40F0,$0FFF,0,0,0,0,0,0,0,0,0,0,0,0
            dw    $0000,$4F00,$40F0,$0FFF,$0000,$400F,$4FF0,$0FFF,0,0,0,0,0,0,0,0
DefProtos   dw    $000,$777,$841,$72C,$00F,$080,$F70,$D00
            dw    $FA9,$FF0,$0E0,$4DF,$DAF,$78F,$CCC,$FFF
            dw    $000,$F00,$0F0,$FFF,0,0,0,0,0,0,0,0,0,0,0,0
            dw    $000,$F00,$0F0,$FFF,$000,$00F,$FF0,$FFF,0,0,0,0,0,0,0,0
GreyProtos  dw    $000,$111,$222,$333,$444,$555,$666,$777
            dw    $888,$999,$AAA,$BBB,$CCC,$DDD,$EEE,$FFF
            dw    $000,$777,$CCC,$FFF,0,0,0,0,0,0,0,0,0,0,0,0
            dw    $000,$888,$DDD,$FFF,$000,$444,$BBB,$FFF,0,0,0,0,0,0,0,0

* The other palettes of each mode.
OtherSets   da    Other320,Other640,Other640D,0
OtherCount  dw    6,4,3,4
Other320    dw    $0000,$8777,$8841,$872C,$800F,$8080,$8F70,$8D00
            dw    $8FA9,$8FF0,$80E0,$84DF,$8DAF,$878F,$8CCC,$0FFF
            dw    $0000,$0D03,$0852,$0F60,$0070,$0555,$00D0,$0FF0
            dw    $0009,$0D0D,$0AAA,$0F98,$022F,$06AF,$00F9,$0FFF
            dw    $0000,$8D03,$8852,$0F60,$8070,$8555,$00D0,$8FF0
            dw    $8009,$0D0D,$8AAA,$8F98,$022F,$86AF,$80F9,$0FFF
            dw    $0000,$4777,$4841,$472C,$400F,$4080,$4F70,$4D00
            dw    $4FA9,$4FF0,$40E0,$44DF,$4DAF,$878F,$8CCC,$0FFF
            dw    $0000,$4777,$4841,$472C,$400F,$4080,$4F70,$4D00
            dw    $8FA9,$8FF0,$80E0,$84DF,$8DAF,$878F,$8CCC,$0FFF
            dw    $0000,$000F,$00F0,$00FF,$0F00,$0F0F,$0FF0,$8FFF
            dw    $8000,$0222,$0444,$0666,$0999,$0BBB,$0DDD,$0FFF
Other640    dw    $0000,$8F00,$80F0,$0FFF,0,0,0,0,0,0,0,0,0,0,0,0
            dw    $0000,$00FF,$0F0F,$0FF0,0,0,0,0,0,0,0,0,0,0,0,0
            dw    $0F00,$00F0,$000F,$0FFF,0,0,0,0,0,0,0,0,0,0,0,0
            dw    $0000,$8F00,$0AAA,$0FFF,0,0,0,0,0,0,0,0,0,0,0,0
Other640D   dw    $0000,$8F00,$80F0,$0FFF,$0000,$800F,$8FF0,$0FFF,0,0,0,0,0,0,0,0
            dw    $0000,$000F,$0FF0,$0FFF,$0000,$0F00,$00F0,$0FFF,0,0,0,0,0,0,0,0
            dw    $0000,$8F00,$0777,$0FFF,$0000,$800F,$0CCC,$0FFF,0,0,0,0,0,0,0,0

* Options (kept from one Remap to the next)
OMode       dw    0                     ; 0 320, 1 640, 2 640 dither, 3 multipalette
OPal        dw    0                     ; 0 calculated, 1 default, 2 greys, 3 other
OAlg        dw    1                     ; 0 closest match, 1 pattern dither, 2 error diffusion
OHStep      dw    14
OVStep      dw    14
OOther      dw    0,0,0,0               ; which other palette (or technique), by mode

ProtoN      dw    16
Proto       ds    32
PW          ds    32                    ; (CalcPalette's working copy)
PalOut      ds    32
Chosen      ds    32
PalR        ds    32
PalG        ds    32
PalB        ds    32
MPTech      dw    0
NatW        dw    0
NatH        dw    0
WantW       dw    0
WantH       dw    0
ROutW        dw    0
ROutW2       dw    0
RGen        dw    0                     ; (RenderLines' call number)
GY          dw    0
DW          dw    0                     ; (Diffuse: 640 modes)                     ; (Diffuse: the grey plane's byte)
Odd         dw    0                     ; (RenderLines: an odd line,
OutI        dw    0                     ; the output byte, the pixels in
Acc         dw    0                     ; it so far, which one, each one's
PixK        dw    0                     ; bits)
PMask       ds    16
NE          dw    0
EStart      dw    0                     ; (MinDist: the first entry up)                     ; (MinDist: the usable entries x 2,
ER3         ds    32                    ; their 3 R, 4 G, 2 B)
EG4         ds    32
EB2         ds    32
PalSet      dw    0                     ; (Multi: a palette's first run done,
OwnP        dw    0                     ; the line's owner, the cost to beat)
Limit       dw    0
P50OK       dw    0                     ; (TQ and T50 made)
RedD        dw    0                     ; (Reduce: the distance, v, its
RedV        dw    0                     ; place in T50)
BqLo        dw    0                     ; (BiasTab: d x Peak / 9 and its
BqHi        dw    0                     ; remainder)
BqR         dw    0
BiasT       ds    182
NList       dw    0                     ; (CalcPalette: CList's bytes, the
ListI       dw    0                     ; places in it)
ListR       dw    0
FA          dw    0                     ; (DistSet: the colour's 3 R, 4 G,
FB          dw    0                     ; 2 B; DistTo: the sum so far)
FC          dw    0
DS          dw    0
KE          dw    0                     ; (Quick: the thresholds' table
KO          dw    0                     ; offsets for even and odd columns)
KRE         dw    0
KRO         dw    0
ROutH        dw    0
CropW       dw    0
CropH       dw    0
SrcW        dw    0                     ; the box averages: SrcW x SrcH source
SpanW       dw    0                     ; pixels make SpanW x SpanH output ones
SrcH        dw    0
SpanH       dw    0
Unit        dw    0
SpanSrc     dw    0
SpanOut     dw    0
SpanA       dw    0
SpanB       dw    0
SpQ         dw    0                     ; a span's stepping: src / out,
SpR         dw    0                     ; src mod out, the remainders so far,
SpAcc       dw    0                     ; the next start
SpCur       dw    0
RowSp       ds    8                     ; (the rows' own)
PrevA       dw    0                     ; the line before's source lines
PrevN       dw    0
PlHist      dw    0
NoGrey      dw    0                     ; (MakePlanes: no greys this time;
GreyMade    dw    0                     ; the planes have them)                     ; (MakePlanes: count Hist too)
AllOne      dw    0                     ; (every span across one pixel)
LastXN      dw    0                     ; the box size worked out last
DMeth       dw    0
DShift      dw    0
DD16        dw    0
RowN        dw    0
PixX        dw    0
SumR        adrl  0
SumG        adrl  0
SumB        adrl  0
Divisor     dw    0
DvLo        dw    0
DvHi        dw    0
DdLo        dw    0
DdHi        dw    0
DvQ2        dw    0
PlRow       dw    0
PlH         adrl  0
PlP         adrl  0
LineA       dw    0
LineB       dw    0
MPOwn       dw    0
Distinct    dw    0
FreeSlots   dw    0
NChosen     dw    0
ChosenK     dw    0
Remaining   dw    0
Peak        dw    0
PeakIndex   dw    0
PeakEighth  dw    0
BiasX       dw    0
SlotX       dw    0
RedX        dw    0
BestBright  dw    0
BestY       dw    0
DC1         dw    0
DC2         dw    0
DT          dw    0
DA          dw    0
DB          dw    0
DCc         dw    0
NCand       dw    0
CandI       dw    0
CandB       dw    0
IdxN        dw    0
Idx         ds    8
Dis         dw    0
AvR         dw    0
AvG         dw    0
AvB         dw    0
BR          dw    0
BG          dw    0
BB          dw    0
BestScore   dw    0
BestIndex   dw    0
First       dw    0
Pattern     dw    0
GreyMode    dw    0
DStep       dw    0
DCount      dw    0
Wanted      dw    0
Err         dw    0
PByte       dw    0
MPCount     dw    0
MPPasses    dw    0
HavePrev    dw    0
Changed     dw    0
BestCost    dw    0
BestP       dw    0
Cost        dw    0
Nearest     dw    0
NPresent    dw    0
MinH        adrl  0
MinP        adrl  0
AvgR        ds    512
AvgG        ds    512
AvgB        ds    512
Penalty     ds    512
WReady      dw    0                     ; (Best's tables made)
NSort       dw    0
SR2         ds    512                   ; the candidates sorted (SortCands)
SG2         ds    512
SB2         ds    512
BSP         ds    512
BSI         ds    512
GStart      ds    514
BW3         ds    1022                  ; 3, 4 and 2 times |j - 255|
BW4         ds    1022
BW2         ds    1022
Byt         ds    512
LineC       ds    1284
LineY       ds    1284
XA3         ds    1284
XN          ds    1284
RowOut      ds    162
Cur         ds    1292
Nxt         ds    1292
TQ          =     XA3                   ; (CalcPalette's Reduce: XA3 to Nxt,
T50         =     XA3+1786              ; 4,986 of their 5,314 bytes)
Owner       ds    404
Tables      ds    512
GreyOK      ds    512
GreyVal     ds    512
Hist        ds    8192
CacheVal    ds    8192                  ; (also Diffuse's and Quick's tables:
DTab        =     CacheVal              ; neither looks colours up)
QGB         =     CacheVal              ; (Quick: green and blue bits, red bit,
QR          =     CacheVal+1026         ; 7 as 15, in each nibble)
QMapL       =     CacheVal+1092
QMapR       =     CacheVal+1102
CList       =     CacheVal              ; (CalcPalette: the colours in use)
PList       ds    8192
