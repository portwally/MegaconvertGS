*-------------------------------------------------------------
* RemapRender.s - part of the Remap segment: patterns, rendering,
* error diffusion and multipalette.
*-------------------------------------------------------------

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
:done       rts

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

* Best: the candidate closest to the target BR, BG, BB.
*   score = 3|R-r| + 4|G-g| + 2|B-b| + penalty/16; the highest index
*   wins ties.   out: A = candidate number
Best        lda   #$7D00
            sta   BestScore
            stz   BestIndex
            lda   NCand
            dec
            asl
            tax
:try        lda   Penalty,x
            bmi   :next
            lsr
            lsr
            lsr
            lsr
            sta   t2
            lda   AvgR,x
            sec
            sbc   BR
            jsr   Abs
            sta   t1
            asl
            clc
            adc   t1
            clc
            adc   t2
            sta   t2
            lda   AvgG,x
            sec
            sbc   BG
            jsr   Abs
            asl
            asl
            clc
            adc   t2
            sta   t2
            lda   AvgB,x
            sec
            sbc   BB
            jsr   Abs
            asl
            clc
            adc   t2
            cmp   BestScore
            bcs   :next
            sta   BestScore
            txa
            lsr
            sta   BestIndex
:next       dex
            dex
            bpl   :try
            lda   BestIndex
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
RenderLines stz   GreyMode
            jsr   PalGrey
            bcs   :colour
            inc   GreyMode
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
            ldx   #510                  ; nothing worked out yet
            lda   #0
:clear      sta   CacheOK,x
            sta   GreyOK,x
            dex
            dex
            bpl   :clear
            lda   GreyMode
            beq   :lines
            lda   OAlg
            cmp   #2
            bne   :lines
            jmp   Diffuse
:lines      lda   LineA
            sta   RowY
:row        lda   RowY
            cmp   LineB
            bcc   :more
            rts
:more       jsr   GetLine
            jsr   ClearRowOut
            ldx   #0
:pix        stx   PixX
            lda   GreyMode
            beq   :colourPix
            lda   LineY,x               ; greys: by grey level
            sta   BR
            sta   BG
            sta   BB
            asl
            tay
            lda   GreyOK,y
            bne   :greyHave
            phy
            jsr   Lookup
            ply
            sta   GreyVal,y
            lda   #1
            sta   GreyOK,y
:greyHave   lda   GreyVal,y
            bra   :bytes
:colourPix  lda   LineC,x               ; colours: by 12-bit colour
            lsr                         ; CacheOK is a bit per colour:
            lsr                         ; word = colour / 16
            lsr
            lsr
            asl
            tay
            lda   LineC,x
            and   #$000F
            asl
            tax
            lda   BitMask,x
            sta   t3
            and   CacheOK,y
            bne   :colHave
            lda   t3
            ora   CacheOK,y
            sta   CacheOK,y
            ldx   PixX
            lda   LineC,x
            jsr   SetTarget
            jsr   Lookup
            pha
            ldx   PixX
            lda   LineC,x
            asl
            tay
            pla
            sta   CacheVal,y
            bra   :colGot
:colHave    ldx   PixX
            lda   LineC,x
            asl
            tay
:colGot     lda   CacheVal,y
:bytes      tay                         ; even line: high byte, odd: low byte
            lda   RowY
            lsr
            tya
            bcs   :odd
            xba
:odd        and   #$00FF
            jsr   PutPixel
            ldx   PixX
            inx
            inx
            cpx   ROutW2
            bcs   :rowDone
            jmp   :pix
:rowDone    jsr   StoreRow
            inc   RowY
            jmp   :row

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
            ldx   #0                    ; no error to pass on yet
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
:more       jsr   GetLine
            jsr   ClearRowOut
            lda   RowY                  ; direction
            sec
            sbc   LineA
            and   #$0001
            bne   :rtl
            stz   PixX                  ; left to right: x from 0, step +1
            lda   #2
            sta   DStep
            bra   :go
:rtl        lda   ROutW2                 ; right to left
            dec
            dec
            sta   PixX
            lda   #-2
            sta   DStep
:go         lda   ROutW
            sta   DCount
:pix        ldx   PixX                  ; wanted = level + (error + 8) / 16
            lda   Cur+2,x
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
            clc
            adc   LineY,x
            sta   Wanted
            bpl   :pos
            lda   #0
            bra   :idx
:pos        cmp   #256
            bcc   :idx
            lda   #255
:idx        asl
            tax
            lda   GreyVal,x
            and   #$00FF
            sta   PByte
            jsr   PutPixel
            jsr   GreyOf                ; error = wanted - the grey shown
            eor   #$FFFF
            sec
            adc   Wanted
            sta   Err
            lda   PixX                  ; spread it: 7 ahead, 3 behind below,
            clc                         ; 5 below, 1 ahead below
            adc   #2
            clc
            adc   DStep
            tax
            lda   Err
            asl
            asl
            asl
            sec
            sbc   Err                   ; 7
            clc
            adc   Cur,x
            sta   Cur,x
            lda   Err
            clc
            adc   Nxt,x                 ; 1
            sta   Nxt,x
            lda   PixX
            clc
            adc   #2
            tax
            lda   Err
            asl
            asl
            clc
            adc   Err                   ; 5
            clc
            adc   Nxt,x
            sta   Nxt,x
            txa
            sec
            sbc   DStep
            tax
            lda   Err
            asl
            clc
            adc   Err                   ; 3
            clc
            adc   Nxt,x
            sta   Nxt,x
            lda   PixX
            clc
            adc   DStep
            sta   PixX
            dec   DCount
            beq   :rowDone
            jmp   :pix
:rowDone    jsr   StoreRow
            ldx   #0                    ; the line below becomes current
:sw         lda   Nxt,x
            sta   Cur,x
            stz   Nxt,x
            inx
            inx
            cpx   #1290
            bcc   :sw
            inc   RowY
            jmp   :row

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
:line       lda   RowY                  ; the best palette for the line
            jsr   GetLine
            lda   #$FFFF
            sta   BestCost
            lda   RowY
            asl
            tax
            lda   Owner,x
            sta   BestP
            stz   MPOwn
:try        jsr   MinAt                 ; cost = the distances of its pixels
            stz   Cost
            ldx   #0
:px         lda   LineC,x
            asl
            tay
            lda   [q1],y
            clc
            adc   Cost
            bcs   :worse
            sta   Cost
            cmp   BestCost
            bcs   :worse
            inx
            inx
            cpx   ROutW2
            bcc   :px
            lda   Cost                  ; better
            sta   BestCost
            lda   MPOwn
            sta   BestP
            bra   :nextP
:worse
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
:render     stz   RowY                  ; each run of lines with its palette
:run        lda   RowY
            cmp   ROutH
            bcs   :tables
            sta   LineA
            asl
            tax
            lda   Owner,x
            sta   MPOwn
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
            jsr   UseTable              ; PalOut = its palette
            lda   LineB
            pha
            jsr   RenderLines
            pla
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
:tables     stz   MPOwn                 ; the colour tables
:tab        jsr   UseTable
            ldx   MPOwn
            jsr   PutTable
            inc   MPOwn
            lda   MPOwn
            cmp   MPCount
            bcc   :tab
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
            stz   u1                    ; colour number in PList
:c          lda   u1
            cmp   NPresent
            bcs   :nextP
            asl
            tax
            lda   PList,x
            sta   DC1
            lda   #$FFFF
            sta   Nearest
            ldx   #0
:e          txa
            clc
            adc   u0
            tay
            lda   Tables,y
            bmi   :skip                 ; reserved
            and   #$0FFF
            sta   DC2
            phx
            jsr   Dist
            plx
            cmp   Nearest
            bcs   :skip
            sta   Nearest
:skip       inx
            inx
            cpx   #32
            bcc   :e
            lda   DC1
            asl
            tay
            lda   Nearest
            sta   [q1],y
            inc   u1
            bra   :c
:nextP      inc   MPOwn
            lda   MPOwn
            cmp   MPCount
            bcc   :p
            rts

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
Byt         ds    512
LineC       ds    1284
LineY       ds    1284
XA3         ds    1284
XN          ds    1284
RowOut      ds    162
Cur         ds    1292
Nxt         ds    1292
Owner       ds    404
Tables      ds    512
GreyOK      ds    512
GreyVal     ds    512
CacheOK     ds    512                   ; a bit per colour
Hist        ds    8192
CacheVal    ds    8192
PList       ds    8192
