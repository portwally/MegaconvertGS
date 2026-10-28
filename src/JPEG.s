*-------------------------------------------------------------
* JPEG.s - baseline JPEG (JFIF)
*
* Huffman coded, 8-bit samples, grey or YCbCr with each component
* sampled 1 or 2 times per MCU across and down, restart markers.
* The inverse DCT is the fast integer one with scaled quantisation
* tables (Arai, Agui and Nakajima), as in the IJG's jidctfst.
* Chroma is widened by repeating samples.
*-------------------------------------------------------------

JHCnt       =     Work                  ; 8 Huffman tables: counts by length (17 words)
JHSym       =     Work+512              ;   and symbols (256 words each)
QTab        =     Work+4608             ; 4 quantisation tables, natural order, scaled
CrR         =     Work+5120             ; colour conversion, by sample value
CbB         =     Work+5632
CrG         =     Work+6144
CbG         =     Work+6656
Coef        =     Work+7168             ; one block's coefficients (64 words)
WS          =     Work+7296             ; IDCT work space (64 words)
Blk         =     Work+7424             ; the block's samples (64 bytes)
JLim        =     Work+14336            ; per table and length (as JHCnt): the
JOff        =     Work+14608            ;   code limit, and symbol index - first
MTab        =     Work+8192             ; MulK's tables, 1024 bytes for each
                                        ; constant: lo x K / 256, then hi x K

DecodeJPEG  jsr   MulTables
            stz   JNComp
            stz   RestartInt
            stz   CHnd
            stz   CHnd+2
            stz   CHnd+4
            stz   CHnd+6
            stz   CHnd+8
            stz   CHnd+10
            lda   #2
            sta   n0
            stz   n0+2
            jsr   StreamAt
:marker     jsr   GetByte
            bcs   :corrupt
            cmp   #$FF
            bne   :marker
:ff         jsr   GetByte
            bcs   :corrupt
            cmp   #$FF
            beq   :ff
            cmp   #0
            beq   :marker
            cmp   #$D8                  ; SOI, RSTn: no segment
            beq   :marker
            cmp   #$D9
            beq   :corrupt              ; EOI before any scan
            cmp   #$D0
            bcc   :seg
            cmp   #$D8
            bcc   :marker
:seg        cmp   #$C0
            beq   :sof
            cmp   #$C1
            beq   :sof
            cmp   #$C4
            beq   :dht
            cmp   #$DB
            beq   :dqt
            cmp   #$DD
            beq   :dri
            cmp   #$DA
            beq   :sos
            cmp   #$C8                  ; other frame types: progressive,
            beq   :skip                 ; lossless, arithmetic coding
            cmp   #$CC
            beq   :skip
            cmp   #$C0
            bcc   :skip
            cmp   #$D0
            bcs   :skip
            lda   #errUnsupported
            sec
            rts
:skip       jsr   GetBE16
            sec
            sbc   #2
            bcc   :corrupt
            jsr   SkipA
            bra   :marker
:corrupt    lda   #errCorrupt
            sec
            rts
:sof        jsr   ReadSOF
            bcc   :marker
            rts
:dht        jsr   ReadDHT
            bcs   :jx13
            jmp   :marker
:jx13
            rts
:dqt        jsr   ReadDQT
            jmp   :marker
:dri        jsr   GetBE16
            jsr   GetBE16
            sta   RestartInt
            jmp   :marker
:sos        lda   JNComp
            beq   :corrupt
            jsr   ReadSOS
            bcc   :scan
            rts
:scan       jsr   DecodeScan
            php
            pha
            ldx   #CHnd
            jsr   FreeHandleAt
            ldx   #CHnd+4
            jsr   FreeHandleAt
            ldx   #CHnd+8
            jsr   FreeHandleAt
            pla
            plp
            rts

* ReadDQT: quantisation tables, scaled for the fast IDCT.
ReadDQT     jsr   GetBE16
            sec
            sbc   #2
            sta   SegLeft
:table      lda   SegLeft
            cmp   #65
            bcc   :done
            jsr   GetByte
            sta   u1
            and   #$0003                ; table number * 128
            xba
            lsr
            clc
            adc   #QTab
            sta   u2
            ldx   #0
:entry      phx
            lda   u1
            and   #$00F0
            beq   :byte
            jsr   GetBE16
            dec   SegLeft
            bra   :got
:byte       jsr   GetByte
:got        dec   SegLeft
            plx
            phx
            pha
            lda   ZigZag,x              ; natural position (times 2)
            sta   u3
            tay
            lda   AanScale,y
            plx                         ; v * scale / 4096, rounded
            jsr   Mul16
            lda   ProdLo
            clc
            adc   #2048
            sta   t1
            lda   ProdHi
            adc   #0
            cmp   #2048
            bcc   :fits
            lda   #32767
            bra   :store
:fits       asl
            asl
            asl
            asl
            sta   t2
            lda   t1
            xba
            lsr
            lsr
            lsr
            lsr
            and   #$000F
            ora   t2
:store      ldy   u3
            sta   (u2),y
            plx
            inx
            inx
            cpx   #128
            bcc   :entry
            dec   SegLeft
            bra   :table
:done       lda   SegLeft
            jmp   SkipA

* ReadDHT: Huffman tables.
ReadDHT     jsr   GetBE16
            sec
            sbc   #2
            sta   SegLeft
:table      lda   SegLeft
            cmp   #17
            bcs   :one
            jsr   SkipA
            clc
            rts
:one        jsr   GetByte
            sta   u1
            and   #$0010                ; AC tables are 4-7
            lsr
            lsr
            sta   t1
            lda   u1
            and   #$0003
            ora   t1
            sta   u1
            asl                         ; counts: table * 34
            sta   t1
            asl
            asl
            asl
            asl
            clc
            adc   t1
            clc
            adc   #JHCnt
            sta   hc
            lda   u1                    ; symbols: table * 512
            xba
            asl
            clc
            adc   #JHSym
            sta   hs
            stz   u2                    ; total
            lda   #0
            sta   (hc)
            ldy   #2
:count      jsr   GetByte
            sta   (hc),y
            clc
            adc   u2
            sta   u2
            iny
            iny
            cpy   #34
            bcc   :count
            lda   SegLeft
            sec
            sbc   #17
            sec
            sbc   u2
            bcc   :bad
            sta   SegLeft
            lda   u2
            cmp   #257
            bcs   :bad
            ldy   #0
:sym        cpy   u2
            beq   :table
            phy
            jsr   GetByte
            sta   t1
            ply
            tya
            asl
            phy
            tay
            lda   t1
            sta   (hs),y
            ply
            iny
            bra   :sym
:bad        lda   #errCorrupt
            sec
            rts

* ReadSOF: the frame: size and components.
ReadSOF     jsr   GetBE16
            jsr   GetByte
            cmp   #8
            beq   :jx16
            jmp   :unsup
:jx16
            jsr   GetBE16
            sta   TrueH
            jsr   GetBE16
            sta   TrueW
            lda   TrueH
            bne   :jx17
            jmp   :unsup
:jx17
            cmp   #4097
            bcc   :jx18
            jmp   :big
:jx18
            lda   TrueW
            bne   :jx19
            jmp   :bad
:jx19
            cmp   #2049
            bcc   :jx20
            jmp   :big
:jx20
            jsr   GetByte
            sta   JNComp
            cmp   #1
            beq   :n
            cmp   #3
            bne   :unsup
:n          lda   #1
            sta   HMax
            sta   VMax
            ldx   #0
:comp       phx
            jsr   GetByte
            plx
            sta   CompId,x
            phx
            jsr   GetByte
            plx
            pha
            lsr
            lsr
            lsr
            lsr
            sta   CH,x
            pla
            and   #$000F
            sta   CV,x
            phx
            jsr   GetByte
            plx
            and   #$0003
            xba                         ; table * 128
            lsr
            clc
            adc   #QTab
            sta   CQ,x
            lda   JNComp                ; one component: one block per MCU
            cmp   #1
            bne   :factors
            lda   #1
            sta   CH,x
            sta   CV,x
:factors    lda   CH,x
            beq   :unsup
            cmp   #3
            bcs   :unsup
            cmp   HMax
            bcc   :h
            sta   HMax
:h          lda   CV,x
            beq   :unsup
            cmp   #3
            bcs   :unsup
            cmp   VMax
            bcc   :v
            sta   VMax
:v          inx
            inx
            txa
            lsr
            cmp   JNComp
            bcc   :comp
            clc
            rts
:unsup      lda   #errUnsupported
            sec
            rts
:big        lda   #errTooBig
            sec
            rts
:bad        lda   #errCorrupt
            sec
            rts

* ReadSOS: which tables each component of the scan uses.
ReadSOS     jsr   GetBE16
            jsr   GetByte
            cmp   JNComp                ; only scans with every component
            bne   :unsup
            stz   u1
:comp       jsr   GetByte
            ldx   #0
:find       cmp   CompId,x
            beq   :found
            inx
            inx
            cpx   #6
            bcc   :find
            lda   #errCorrupt
            sec
            rts
:found      phx
            jsr   GetByte
            plx
            sta   t1
            lsr                         ; DC table: counts and symbols
            lsr
            lsr
            lsr
            and   #$0003
            jsr   TableAddr
            lda   hc
            sta   DCCnt,x
            lda   hs
            sta   DCSym,x
            lda   t1
            and   #$0003
            ora   #$0004
            jsr   TableAddr
            lda   hc
            sta   ACCnt,x
            lda   hs
            sta   ACSym,x
            inc   u1
            lda   u1
            cmp   JNComp
            bcc   :comp
            jsr   GetByte               ; spectral selection, approximation
            jsr   GetByte
            jsr   GetByte
            clc
            rts
:unsup      lda   #errUnsupported
            sec
            rts

* TableAddr: hc, hs for Huffman table A. Keeps X.
TableAddr   sta   t2
            asl
            sta   t3
            asl
            asl
            asl
            asl
            clc
            adc   t3
            clc
            adc   #JHCnt
            sta   hc
            lda   t2
            xba
            asl
            clc
            adc   #JHSym
            sta   hs
            rts

*-------------------------------------------------------------
* The scan
*-------------------------------------------------------------
DecodeScan  lda   HMax                  ; MCUs across and down
            asl
            asl
            asl
            sta   McuW
            dec
            clc
            adc   TrueW
            ldy   #3
            ldx   HMax
            cpx   #2
            bne   :sx
            iny
:sx         jsr   ShiftR
            sta   McusX
            lda   VMax
            asl
            asl
            asl
            sta   McuH
            dec
            clc
            adc   TrueH
            ldy   #3
            ldx   VMax
            cpx   #2
            bne   :sy
            iny
:sy         jsr   ShiftR
            sta   McusY
            ldx   #0                    ; a strip of samples per component
:buf        stx   CI
            lda   McusX                 ; BW = McusX * H * 8
            asl
            asl
            asl
            ldy   CH,x
            cpy   #2
            bne   :bw
            asl
:bw         sta   BW,x
            ldy   CV,x                  ; size = BW * V * 8
            cpy   #2
            bne   :one
            asl
:one        asl
            asl
            asl
            sta   n0
            stz   n0+2
            jsr   NewBuffer
            bcc   :got
            rts
:got        ldx   CI
            txa
            asl
            tay
            lda   n1
            sta   CHnd,y
            lda   n1+2
            sta   CHnd+2,y
            lda   p0
            sta   CP,y
            lda   p0+2
            sta   CP+2,y
            lda   CH,x                  ; widened across or down?
            cmp   HMax
            lda   #0
            bcs   :wx
            inc
:wx         sta   ShX,x
            lda   CV,x
            cmp   VMax
            lda   #0
            bcs   :wy
            inc
:wy         sta   ShY,x
            inx
            inx
            txa
            lsr
            cmp   JNComp
            bcc   :buf
            jsr   ColourTables
            jsr   NewTrue
            bcc   :start
            rts
:start      jsr   MakeLims
            stz   JCnt
            stz   MarkerHit
            stz   Pred
            stz   Pred+2
            stz   Pred+4
            lda   RestartInt
            sta   RstLeft
            stz   JErr
            stz   MY
:mcuRow     stz   MX
:mcu        lda   RestartInt
            beq   :blocks
            lda   RstLeft
            bne   :count
            jsr   Restart
            lda   RestartInt
            sta   RstLeft
:count      dec   RstLeft
:blocks     ldx   #0
:comp       stx   CI
            stz   VB
:vb         stz   HB
:hb         jsr   DecodeBlock
            bcc   :ok
            inc   JErr                  ; damaged: keep what was decoded
            bra   :rows
:ok         jsr   IDCT
            jsr   StoreBlock
            ldx   CI
            inc   HB
            lda   HB
            cmp   CH,x
            bcc   :hb
            inc   VB
            lda   VB
            cmp   CV,x
            bcc   :vb
            inx
            inx
            txa
            lsr
            cmp   JNComp
            bcc   :comp
            inc   MX
            lda   MX
            cmp   McusX
            bcc   :mcu
:rows       jsr   OutRows
            lda   JErr
            bne   :done
            inc   MY
            lda   MY
            cmp   McusY
            bcs   :done
            jmp   :mcuRow
:done       clc
            rts

* Restart: at a restart marker: realign and reset the DC predictions.
Restart     stz   JCnt
            lda   MarkerHit
            beq   :search
            stz   MarkerHit
            bra   :reset
:search     jsr   GetByte
            bcs   :reset
            cmp   #$FF
            bne   :search
:ff         jsr   GetByte
            bcs   :reset
            cmp   #$FF
            beq   :ff
:reset      stz   Pred
            stz   Pred+2
            stz   Pred+4
            rts

* GetBitJ: the next bit (highest first) in the carry; past a marker, zeros.
* Keeps X and Y.
GetBitJ     dec   JCnt
            bpl   :have
            lda   MarkerHit
            bne   :zero
            jsr   GetByte
            bcs   :zero
            cmp   #$FF
            bne   :byte
            jsr   GetByte               ; $FF $00 is a data byte $FF
            cmp   #0
            beq   :isFF
            inc   MarkerHit             ; a marker: the data has ended
            bra   :zero
:isFF       lda   #$FF
:byte       xba
            sta   JBuf
            lda   #7
            sta   JCnt
:have       asl   JBuf
            rts
:zero       stz   JCnt
            clc
            rts

* GetBitsJ: X bits, highest first, in A.
GetBitsJ    stz   JVal
            cpx   #0
            beq   :done
:loop       jsr   GetBitJ
            rol   JVal
            dex
            bne   :loop
:done       lda   JVal
            rts

* MakeLims: for each Huffman table and code length, DecodeJ's limit
* (first code + count) and the symbol index less the first code.
MakeLims    ldx   #0                    ; (X: table x 34 + length x 2, the
:t          stz   t2                    ; same place in all three)
            stz   t3
            inx
            inx
            lda   #16
            sta   MLCnt
:l          lda   JHCnt,x
            sta   t1
            clc
            adc   t2
            sta   JLim,x
            lda   t3
            sec
            sbc   t2
            sta   JOff,x
            lda   t3
            clc
            adc   t1
            sta   t3
            lda   JLim,x
            asl
            sta   t2
            inx
            inx
            dec   MLCnt
            bne   :l
            cpx   #272
            bcc   :t
            rts

* DecodeJ: one Huffman symbol (code at hc, hs). Carry set if none matches.
* Bit by bit against each length's limit (MakeLims).
DecodeJ     lda   hc
            sec
            sbc   #JHCnt
            clc
            adc   #JLim
            sta   u0
            clc
            adc   #JOff-JLim
            sta   u3
            stz   HCode
            ldy   #2
:loop       dec   JCnt                  ; (GetBitJ inline but for a new byte)
            bmi   :refill
            asl   JBuf
:bit        rol   HCode
            lda   HCode
            cmp   (u0),y
            bcc   :found
            iny
            iny
            cpy   #34
            bcc   :loop
            sec
            rts
:refill     inc   JCnt
            jsr   GetBitJ
            bra   :bit
:found      clc
            adc   (u3),y
            asl
            tay
            lda   (hs),y
            clc
            rts

* Extend: the signed value of the A bits read for size X.
Extend      sta   JVal
            txa
            asl
            tax
            lda   JVal
            cmp   PowTab-2,x
            bcs   :pos
            sec
            sbc   PowTab,x
            inc
:pos        rts

* DecodeBlock: the coefficients of one block of component CI, dequantised.
DecodeBlock ldx   #126
:clear      stz   Coef,x
            dex
            dex
            bpl   :clear
            ldx   CI
            lda   CQ,x
            sta   u2
            lda   DCCnt,x
            sta   hc
            lda   DCSym,x
            sta   hs
            jsr   DecodeJ
            bcc   :jx21
            jmp   :bad
:jx21
            cmp   #12
            bcc   :jx22
            jmp   :bad
:jx22
            tax
            beq   :noDiff
            phx
            jsr   GetBitsJ
            plx
            jsr   Extend
            bra   :diff
:noDiff     lda   #0
:diff       ldx   CI
            clc
            adc   Pred,x
            sta   Pred,x
            ldy   #0                    ; times quantisation entry 0
            jsr   DeQuant
            sta   Coef
            ldx   CI
            lda   ACCnt,x
            sta   hc
            lda   ACSym,x
            sta   hs
            lda   #1
            sta   K
:ac         jsr   DecodeJ
            bcs   :bad
            sta   u1
            and   #$000F
            bne   :value
            lda   u1                    ; run of 16 zeros, or the end of the block
            cmp   #$F0
            bne   :end
            lda   K
            clc
            adc   #16
            sta   K
            cmp   #64
            bcc   :ac
:end        clc
            rts
:value      sta   u3                    ; size
            lda   u1                    ; skip the zero run
            lsr
            lsr
            lsr
            lsr
            clc
            adc   K
            cmp   #64
            bcs   :end
            sta   K
            ldx   u3
            jsr   GetBitsJ
            ldx   u3
            jsr   Extend
            pha
            lda   K
            asl
            tax
            ldy   ZigZag,x
            pla
            jsr   DeQuant
            ldx   K
            pha
            txa
            asl
            tax
            ldy   ZigZag,x
            pla
            sta   Coef,y
            inc   K
            lda   K
            cmp   #64
            bcc   :ac
            clc
            rts
:bad        sec
            rts

* DeQuant: A (signed) times quantisation entry Y of the table at u2 (low 16 bits).
DeQuant     cmp   #0                    ; (the value is the multiplier: Mul16
            bpl   :pos                  ; goes round once per bit of it, and
            eor   #$FFFF                ; it is mostly small)
            inc
            tax
            lda   (u2),y
            jsr   Mul16
            lda   ProdLo
            eor   #$FFFF
            inc
            rts
:pos        tax
            lda   (u2),y
            jsr   Mul16
            lda   ProdLo
            rts

*-------------------------------------------------------------
* Inverse DCT: Coef -> Blk
*-------------------------------------------------------------
IDCT        ldx   #0                    ; columns
:col        lda   Coef+16,x
            ora   Coef+32,x
            ora   Coef+48,x
            ora   Coef+64,x
            ora   Coef+80,x
            ora   Coef+96,x
            ora   Coef+112,x
            bne   :full
            lda   Coef,x                ; only DC: the same all down
            sta   WS,x
            sta   WS+16,x
            sta   WS+32,x
            sta   WS+48,x
            sta   WS+64,x
            sta   WS+80,x
            sta   WS+96,x
            sta   WS+112,x
            jmp   :nextCol
:full       lda   Coef,x
            sta   In0
            lda   Coef+16,x
            sta   In1
            lda   Coef+32,x
            sta   In2
            lda   Coef+48,x
            sta   In3
            lda   Coef+64,x
            sta   In4
            lda   Coef+80,x
            sta   In5
            lda   Coef+96,x
            sta   In6
            lda   Coef+112,x
            sta   In7
            jsr   Butterfly
            lda   T0
            clc
            adc   T7
            sta   WS,x
            lda   T0
            sec
            sbc   T7
            sta   WS+112,x
            lda   T1
            clc
            adc   T6
            sta   WS+16,x
            lda   T1
            sec
            sbc   T6
            sta   WS+96,x
            lda   T2
            clc
            adc   T5
            sta   WS+32,x
            lda   T2
            sec
            sbc   T5
            sta   WS+80,x
            lda   T3
            clc
            adc   T4
            sta   WS+64,x
            lda   T3
            sec
            sbc   T4
            sta   WS+48,x
:nextCol    inx
            inx
            cpx   #16
            bcs   :rows
            jmp   :col

:rows       ldx   #0                    ; rows: X = row * 16, Y = row * 8
            ldy   #0
:row        lda   WS+2,x
            ora   WS+4,x
            ora   WS+6,x
            ora   WS+8,x
            ora   WS+10,x
            ora   WS+12,x
            ora   WS+14,x
            bne   :rfull
            lda   WS,x
            jsr   Range
            sep   #$20
            mx    %10
            sta   Blk,y
            sta   Blk+1,y
            sta   Blk+2,y
            sta   Blk+3,y
            sta   Blk+4,y
            sta   Blk+5,y
            sta   Blk+6,y
            sta   Blk+7,y
            rep   #$20
            mx    %00
            jmp   :nextRow
:rfull      lda   WS,x
            sta   In0
            lda   WS+2,x
            sta   In1
            lda   WS+4,x
            sta   In2
            lda   WS+6,x
            sta   In3
            lda   WS+8,x
            sta   In4
            lda   WS+10,x
            sta   In5
            lda   WS+12,x
            sta   In6
            lda   WS+14,x
            sta   In7
            jsr   Butterfly
            lda   T0
            clc
            adc   T7
            jsr   Range
            sta   Out0
            lda   T0
            sec
            sbc   T7
            jsr   Range
            sta   Out7
            lda   T1
            clc
            adc   T6
            jsr   Range
            sta   Out1
            lda   T1
            sec
            sbc   T6
            jsr   Range
            sta   Out6
            lda   T2
            clc
            adc   T5
            jsr   Range
            sta   Out2
            lda   T2
            sec
            sbc   T5
            jsr   Range
            sta   Out5
            lda   T3
            clc
            adc   T4
            jsr   Range
            sta   Out4
            lda   T3
            sec
            sbc   T4
            jsr   Range
            sta   Out3
            sep   #$20
            mx    %10
            lda   Out0
            sta   Blk,y
            lda   Out1
            sta   Blk+1,y
            lda   Out2
            sta   Blk+2,y
            lda   Out3
            sta   Blk+3,y
            lda   Out4
            sta   Blk+4,y
            lda   Out5
            sta   Blk+5,y
            lda   Out6
            sta   Blk+6,y
            lda   Out7
            sta   Blk+7,y
            rep   #$20
            mx    %00
:nextRow    tya
            clc
            adc   #8
            tay
            txa
            clc
            adc   #16
            tax
            cpx   #128
            bcs   :done
            jmp   :row
:done       rts

* Butterfly: one 8-point inverse DCT, In0-In7 -> T0-T7 (outputs paired).
* Keeps X and Y.
Butterfly   phx                         ; (X back at the end: MulT uses it)
            lda   In0                   ; even part
            clc
            adc   In4
            sta   T10
            lda   In0
            sec
            sbc   In4
            sta   T11
            lda   In2
            clc
            adc   In6
            sta   T13
            lda   In2
            sec
            sbc   In6
            ldx   #1024
            jsr   MulT
            sec
            sbc   T13
            sta   T12
            lda   T10
            clc
            adc   T13
            sta   T0
            lda   T10
            sec
            sbc   T13
            sta   T3
            lda   T11
            clc
            adc   T12
            sta   T1
            lda   T11
            sec
            sbc   T12
            sta   T2
            lda   In5                   ; odd part
            clc
            adc   In3
            sta   Z13
            lda   In5
            sec
            sbc   In3
            sta   Z10
            lda   In1
            clc
            adc   In7
            sta   Z11
            lda   In1
            sec
            sbc   In7
            sta   Z12
            lda   Z11
            clc
            adc   Z13
            sta   T7
            lda   Z11
            sec
            sbc   Z13
            ldx   #1024
            jsr   MulT
            sta   T11
            lda   Z10
            clc
            adc   Z12
            ldx   #2048
            jsr   MulT
            sta   Z5
            lda   Z12
            ldx   #0
            jsr   MulT
            sec
            sbc   Z5
            sta   T10
            lda   Z10
            ldx   #3072
            jsr   MulT
            eor   #$FFFF
            inc
            clc
            adc   Z5
            sta   T12
            lda   T12                   ; tmp6 = tmp12 - tmp7
            sec
            sbc   T7
            sta   T6
            lda   T11                   ; tmp5 = tmp11 - tmp6
            sec
            sbc   T6
            sta   T5
            lda   T10                   ; tmp4 = tmp10 + tmp5
            clc
            adc   T5
            sta   T4
            plx
            rts

* M277...M669: (A * constant) / 256, signed, the low 16 bits. Keep X and
* Y. With |A| = 256 hi + lo: hi x K + lo x K / 256, from MTab.
M277        phx
            ldx   #0
            bra   MulK
M362        phx
            ldx   #1024
            bra   MulK
M473        phx
            ldx   #2048
            bra   MulK
M669        phx
            ldx   #3072
* MulT: as MulK, X = the constant's table (0, 1024, 2048 or 3072), and
* X not kept.
MulT        stx   MKt
            cmp   #0
            bpl   MKmag
            eor   #$FFFF
            inc
            jsr   MKmag
            eor   #$FFFF
            inc
            rts
MulK        stx   MKt
            cmp   #0
            bpl   :pos
            eor   #$FFFF
            inc
            jsr   MKmag
            eor   #$FFFF
            inc
            plx
            rts
:pos        jsr   MKmag
            plx
            rts
MKmag       sta   MKv
            and   #$00FF
            asl
            adc   MKt                   ; (carry clear: lo x 2 < 512)
            tax
            lda   MTab,x
            sta   MKs
            lda   MKv
            xba
            and   #$00FF
            asl
            adc   MKt
            tax
            lda   MTab+512,x
            clc
            adc   MKs
            rts

* MulTables: MTab for 277, 362, 473, 669, 359 and 454.
MulTables   ldx   #0
            ldy   #0
:k          lda   MulKs,y
            sta   MKc
            stz   MKs                   ; lo x K (24 bits: MKs, MKv)
            stz   MKv
            stz   t1                    ; hi x K (16 bits)
            phy
            ldy   #256
:e          lda   MKs+1                 ; (/ 256)
            sta   MTab,x
            lda   t1
            sta   MTab+512,x
            lda   MKs
            clc
            adc   MKc
            sta   MKs
            bcc   :nc
            inc   MKv
:nc         lda   t1
            clc
            adc   MKc
            sta   t1
            inx
            inx
            dey
            bne   :e
            ply
            txa                         ; (the next constant's 1024)
            clc
            adc   #512
            tax
            iny
            iny
            cpy   #12
            bcc   :k
            rts

MulKs       dw    277,362,473,669,359,454

* Range: a sample from an IDCT output: v / 32 + 128, kept within 0-255.
Range       clc                         ; (v + 16 from -4096 to 4095: the
            adc   #16                   ; answer is its bits 5-12, with the
            bmi   :neg                  ; top one flipped; further out it is
            cmp   #4096                 ; 0 or 255)
            bcc   :mid
            lda   #255
            rts
:neg        cmp   #$F000
            bcs   :mid
            lda   #0
            rts
:mid        asl
            asl
            asl
            xba
            and   #$00FF
            eor   #$0080
            rts
Clamp8      bmi   :zero
            cmp   #256
            bcc   :ok
            lda   #255
:ok         rts
:zero       lda   #0
            rts

* StoreBlock: Blk into component CI's strip at block (MX * H + HB, VB).
StoreBlock  ldx   CI
            lda   MX
            ldy   CH,x
            cpy   #2
            bne   :h1
            asl
:h1         clc
            adc   HB
            asl
            asl
            asl
            sta   t1
            lda   VB
            beq   :v0
            lda   BW,x
            asl
            asl
            asl
:v0         clc
            adc   t1
            sta   t1                    ; offset of the block's top left
            txa
            asl
            tax
            lda   CP,x
            sta   q2
            lda   CP+2,x
            sta   q2+2
            ldx   CI
            lda   BW,x
            sta   t2
            ldx   #0
            ldy   t1
:row        lda   Blk,x
            sta   [q2],y
            lda   Blk+2,x
            iny
            iny
            sta   [q2],y
            lda   Blk+4,x
            iny
            iny
            sta   [q2],y
            lda   Blk+6,x
            iny
            iny
            sta   [q2],y
            lda   t1
            clc
            adc   t2
            sta   t1
            tay
            txa
            clc
            adc   #8
            tax
            cpx   #64
            bcc   :row
            rts

*-------------------------------------------------------------
* Colour
*-------------------------------------------------------------

* ColourTables: YCbCr -> RGB contributions for each sample value.
ColourTables lda  JNComp
            cmp   #3
            bne   :done
            ldy   #0
:entry      tya
            lsr
            sec
            sbc   #128                  ; x = value - 128
            sta   u1
            jsr   M359
            sta   CrR,y
            lda   u1
            jsr   M454
            sta   CbB,y
            lda   u1                    ; green parts, 7 fraction bits
            ldx   #91
            jsr   SMul
            sta   CrG,y
            lda   u1
            ldx   #44
            jsr   SMul
            sta   CbG,y
            iny
            iny
            cpy   #512
            bcc   :entry
:done       rts

* PairPix: pixel X of OutRows' line from its luma and the pair's chroma
* parts (PRAdd, PBAdd, PGSub), as OutRows works it out for one pixel.
PairPix     txy
            lda   [p1],y
            and   #$00FF
            sta   JY
            clc
            adc   PRAdd
            bmi   :r0
            cmp   #256
            bcc   :r1
            lda   #255
            bra   :r1
:r0         lda   #0
:r1         sta   CR
            lda   JY
            clc
            adc   PBAdd
            bmi   :b0
            cmp   #256
            bcc   :b1
            lda   #255
            bra   :b1
:b0         lda   #0
:b1         sta   CB
            lda   JY
            sec
            sbc   PGSub
            bmi   :g0
            cmp   #256
            bcc   :g1
            lda   #255
            bra   :g1
:g0         lda   #0
:g1         ldy   DestOff               ; green at +1, red, blue
            sep   #$20
            mx    %10
            iny
            sta   [q0],y
            dey
            lda   CR
            sta   [q0],y
            iny
            iny
            lda   CB
            sta   [q0],y
            iny
            rep   #$20
            mx    %00
            sty   DestOff
            rts

M359        phx
            ldx   #4096
            jmp   MulK
M454        phx
            ldx   #5120
            jmp   MulK

* SMul: A (signed) * X, low 16 bits. Keeps Y.
SMul        cmp   #0
            bpl   :pos
            eor   #$FFFF
            inc
            jsr   Mul16
            lda   ProdLo
            eor   #$FFFF
            inc
            rts
:pos        jsr   Mul16
            lda   ProdLo
            rts

* OutRows: the finished strip of MCU row MY becomes RGB rows.
OutRows     stz   SR
:row        lda   MY                    ; picture row
            ldx   VMax
            cpx   #2
            bne   :y8
            asl
:y8         asl
            asl
            asl
            clc
            adc   SR
            cmp   TrueH
            bcc   :in
            rts
:in         jsr   TrueRowAt
            ldx   #0                    ; each component's line in its strip
:line       lda   SR
            ldy   ShY,x
            beq   :ly
            lsr
:ly         phx
            ldx   #0                    ; line * BW: shifts and adds
            stx   t1
            plx
            sta   t2
            ldy   BW,x
:mul        lda   t2
            beq   :mulDone
            lsr   t2
            bcc   :noAdd
            tya
            clc
            adc   t1
            sta   t1
:noAdd      tya
            asl
            tay
            bra   :mul
:mulDone    phx
            txa
            asl
            tax
            lda   CP,x
            clc
            adc   t1
            sta   LineP,x
            lda   CP+2,x
            sta   LineP+2,x
            plx
            inx
            inx
            txa
            lsr
            cmp   JNComp
            bcc   :line
            lda   LineP                 ; p1, p2, p3 = the lines of Y, Cb, Cr
            sta   p1
            lda   LineP+2
            sta   p1+2
            lda   LineP+4
            sta   p2
            lda   LineP+6
            sta   p2+2
            lda   LineP+8
            sta   p3
            lda   LineP+10
            sta   p3+2
            stz   DestOff
            ldx   #0
            lda   JNComp
            cmp   #3
            beq   :three
:grey       txy                         ; one component: grey (each byte
            lda   [p1],y                ; three times)
            ldy   DestOff
            sep   #$20
            mx    %10
            sta   [q0],y
            iny
            sta   [q0],y
            iny
            sta   [q0],y
            iny
            rep   #$20
            mx    %00
            sty   DestOff
            inx
            cpx   TrueW
            bcc   :grey
            jmp   :rowDone
:three      lda   ShX+2                 ; chroma half as wide: its parts
            beq   :pix                  ; once for each pair of pixels
            lda   ShX+4
            beq   :pix
:pair       txa
            lsr
            tay
            lda   [p2],y
            and   #$00FF
            asl
            sta   JCb
            lda   [p3],y
            and   #$00FF
            asl
            sta   JCr
            tay
            lda   CrR,y
            sta   PRAdd
            ldy   JCb
            lda   CbB,y
            sta   PBAdd
            lda   CbG,y
            ldy   JCr
            clc
            adc   CrG,y
            clc
            adc   #64
            asl                         ; (/ 128, keeping the sign)
            xba
            and   #$00FF
            bcc   :pg
            ora   #$FF00
:pg         sta   PGSub
            jsr   PairPix
            inx
            cpx   TrueW
            bcs   :pd
            jsr   PairPix
            inx
            cpx   TrueW
            bcc   :pair
:pd         jmp   :rowDone
:pix        txy
            lda   [p1],y
            and   #$00FF
            sta   JY
:colour     txa
            ldy   ShX+2
            beq   :cb
            lsr
:cb         tay
            lda   [p2],y
            and   #$00FF
            asl
            sta   JCb
            txa
            ldy   ShX+4
            beq   :cr
            lsr
:cr         tay
            lda   [p3],y
            and   #$00FF
            asl
            sta   JCr
            tay                         ; (Clamp8 inline)
            lda   CrR,y
            clc
            adc   JY
            bmi   :r0
            cmp   #256
            bcc   :r1
            lda   #255
            bra   :r1
:r0         lda   #0
:r1         sta   CR
            ldy   JCb
            lda   CbB,y
            clc
            adc   JY
            bmi   :b0
            cmp   #256
            bcc   :b1
            lda   #255
            bra   :b1
:b0         lda   #0
:b1         sta   CB
            lda   CbG,y
            ldy   JCr
            clc
            adc   CrG,y
            clc
            adc   #64
            asl                         ; / 128, keeping the sign: bits 7-14,
            xba                         ; and bit 15 above them
            and   #$00FF
            bcc   :gp
            ora   #$FF00
:gp         eor   #$FFFF
            sec
            adc   JY
            bmi   :g0
            cmp   #256
            bcc   :g1
            lda   #255
            bra   :g1
:g0         lda   #0
:g1         ldy   DestOff               ; (PutRGB inline: green at +1,
            sep   #$20                  ; red, blue)
            mx    %10
            iny
            sta   [q0],y
            dey
            lda   CR
            sta   [q0],y
            iny
            iny
            lda   CB
            sta   [q0],y
            iny
            rep   #$20
            mx    %00
            sty   DestOff
            inx
            cpx   TrueW
            bcs   :rowDone
            jmp   :pix
:rowDone    inc   SR
            lda   SR
            cmp   McuH
            bcs   :done
            jmp   :row
:done       rts

* Zig-zag order: natural position (times 2) of each coefficient.
ZigZag      dw    0*2,1*2,8*2,16*2,9*2,2*2,3*2,10*2
            dw    17*2,24*2,32*2,25*2,18*2,11*2,4*2,5*2
            dw    12*2,19*2,26*2,33*2,40*2,48*2,41*2,34*2
            dw    27*2,20*2,13*2,6*2,7*2,14*2,21*2,28*2
            dw    35*2,42*2,49*2,56*2,57*2,50*2,43*2,36*2
            dw    29*2,22*2,15*2,23*2,30*2,37*2,44*2,51*2
            dw    58*2,59*2,52*2,45*2,38*2,31*2,39*2,46*2
            dw    53*2,60*2,61*2,54*2,47*2,55*2,62*2,63*2

* Scale factors for the fast IDCT (14 fraction bits), natural order.
AanScale    dw    16384,22725,21407,19266,16384,12873,8867,4520
            dw    22725,31521,29692,26722,22725,17855,12299,6270
            dw    21407,29692,27969,25172,21407,16819,11585,5906
            dw    19266,26722,25172,22654,19266,15137,10426,5315
            dw    16384,22725,21407,19266,16384,12873,8867,4520
            dw    12873,17855,16819,15137,12873,10114,6967,3552
            dw    8867,12299,11585,10426,8867,6967,4799,2446
            dw    4520,6270,5906,5315,4520,3552,2446,1247

JNComp      dw    0
RestartInt  dw    0
RstLeft     dw    0
SegLeft     dw    0
HMax        dw    0
VMax        dw    0
McuW        dw    0
McuH        dw    0
McusX       dw    0
McusY       dw    0
MX          dw    0
MY          dw    0
CI          dw    0
VB          dw    0
HB          dw    0
K           dw    0
SR          dw    0
JErr        dw    0
JCnt        dw    0
JBuf        dw    0
JVal        dw    0
MarkerHit   dw    0
MKc         dw    0
MKs         dw    0                     ; (MulK: lo x K / 256; MulTables: lo x
MKv         dw    0                     ; K, 24 bits, with MKv after MKs)
MKt         dw    0
MLCnt       dw    0                     ; (MakeLims: lengths left)
PRAdd       dw    0                     ; (OutRows: a chroma pair's parts)
PBAdd       dw    0
PGSub       dw    0                     ; (MulK: the constant's table)
JY          dw    0
JCb         dw    0
JCr         dw    0
CompId      dw    0,0,0
CH          dw    0,0,0
CV          dw    0,0,0
CQ          dw    0,0,0
ShX         dw    0,0,0
ShY         dw    0,0,0
BW          dw    0,0,0
Pred        dw    0,0,0
DCCnt       dw    0,0,0
DCSym       dw    0,0,0
ACCnt       dw    0,0,0
ACSym       dw    0,0,0
CHnd        adrl  0,0,0
CP          adrl  0,0,0
LineP       adrl  0,0,0
In0         dw    0
In1         dw    0
In2         dw    0
In3         dw    0
In4         dw    0
In5         dw    0
In6         dw    0
In7         dw    0
T0          dw    0
T1          dw    0
T2          dw    0
T3          dw    0
T4          dw    0
T5          dw    0
T6          dw    0
T7          dw    0
T10         dw    0
T11         dw    0
T12         dw    0
T13         dw    0
Z5          dw    0
Z10         dw    0
Z11         dw    0
Z12         dw    0
Z13         dw    0
Out0        dw    0
Out1        dw    0
Out2        dw    0
Out3        dw    0
Out4        dw    0
Out5        dw    0
Out6        dw    0
Out7        dw    0
