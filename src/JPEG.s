*-------------------------------------------------------------
* JPEG.s - baseline and progressive JPEG (JFIF)
*
* Huffman coded, 8-bit samples, grey or YCbCr with each component
* sampled 1 or 2 times per MCU across and down, restart markers.
* A progressive picture's coefficients are kept, block by block, while
* its scans add to them, and turned into pixels at the end.
* The inverse DCT is the fast integer one with scaled quantisation
* tables (Arai, Agui and Nakajima), as in the IJG's jidctfst.
* Chroma is widened by repeating samples.
* Huffman codes up to 8 bits long come from a lookup table (the next 8
* bits of the data: length and symbol), longer ones bit by bit.
*-------------------------------------------------------------

hl          =     $A4                   ; the Huffman table's lookup (long)
jb          =     $A8                   ; data bits, highest first (left aligned)
jn          =     $AA                   ;   and how many
CHK         =     $AC                   ; (IDCT: a row's outputs, OR'd)
T0          =     $B0                   ; (IDCT: the butterfly's values)
T1          =     $B2
T2          =     $B4
T3          =     $B6
T4          =     $B8
T5          =     $BA
T6          =     $BC
T7          =     $BE
T10         =     $C0
T11         =     $C2
T12         =     $C4
T13         =     $C6
Z5          =     $C8
Z10         =     $CA
Z11         =     $CC
Z12         =     $CE
Z13         =     $D0
MKs         =     $D2                   ; (MulK: lo x K / 256; MulTables: lo x
MKv         =     $D4                   ; K, 24 bits, with MKv after MKs)
GT          =     $D6                   ; (OutRows: a green part, two luma
LP          =     $D8                   ;   samples, pixels left)
PCnt        =     $DA
Out0        =     $DC                   ; (IDCT: a row's samples, high bytes)
Out1        =     $DE
Out2        =     $E0
Out3        =     $E2
Out4        =     $E4
Out5        =     $E6
Out6        =     $E8
Out7        =     $EA
ha          =     $EC                   ; an AC table's fast lookup (long)

* BFLY: one 8-point inverse DCT of ]1-]8 (,x) into T0-T7. Keeps X.
* Products are floor(v x K / 256), from MTab (lo x K / 256 + hi x K, hi
* signed), as libjpeg's fast integer IDCT works them out.
BFLY        MAC
            lda   ]1,x                  ; even part
            clc
            adc   ]5,x
            sta   T10
            lda   ]1,x
            sec
            sbc   ]5,x
            sta   T11
            lda   ]3,x
            clc
            adc   ]7,x
            sta   T13
            lda   ]3,x
            sec
            sbc   ]7,x
            sta   MKv                   ; x 362
            and   #$00FF
            asl
            tay
            lda   MTab+1024,y
            sta   MKs
            lda   MKv
            xba
            and   #$00FF
            asl
            tay
            lda   MTab+1536,y
            clc
            adc   MKs
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
            lda   ]6,x                  ; odd part
            clc
            adc   ]4,x
            sta   Z13
            lda   ]6,x
            sec
            sbc   ]4,x
            sta   Z10
            lda   ]2,x
            clc
            adc   ]8,x
            sta   Z11
            lda   ]2,x
            sec
            sbc   ]8,x
            sta   Z12
            lda   Z11
            clc
            adc   Z13
            sta   T7
            lda   Z11
            sec
            sbc   Z13
            sta   MKv                   ; x 362
            and   #$00FF
            asl
            tay
            lda   MTab+1024,y
            sta   MKs
            lda   MKv
            xba
            and   #$00FF
            asl
            tay
            lda   MTab+1536,y
            clc
            adc   MKs
            sta   T11
            lda   Z10
            clc
            adc   Z12
            sta   MKv                   ; x 473
            and   #$00FF
            asl
            tay
            lda   MTab+2048,y
            sta   MKs
            lda   MKv
            xba
            and   #$00FF
            asl
            tay
            lda   MTab+2560,y
            clc
            adc   MKs
            sta   Z5
            lda   Z12
            sta   MKv                   ; x 277
            and   #$00FF
            asl
            tay
            lda   MTab,y
            sta   MKs
            lda   MKv
            xba
            and   #$00FF
            asl
            tay
            lda   MTab+512,y
            clc
            adc   MKs
            sec
            sbc   Z5
            sta   T10
            lda   Z10                   ; x -669
            eor   #$FFFF
            inc
            sta   MKv
            and   #$00FF
            asl
            tay
            lda   MTab+3072,y
            sta   MKs
            lda   MKv
            xba
            and   #$00FF
            asl
            tay
            lda   MTab+3584,y
            clc
            adc   MKs
            clc
            adc   Z5
            sec                         ; tmp6 = tmp12 - tmp7
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
            <<<

* HBFLY: BFLY when ]5-]8 are 0: only ]1-]4 (,x). Keeps X.
HBFLY       MAC
            lda   ]3,x                  ; even part: tmp10 = tmp11 = In0,
            sta   MKv                   ; tmp13 = In2; x 362
            and   #$00FF
            asl
            tay
            lda   MTab+1024,y
            sta   MKs
            lda   MKv
            xba
            and   #$00FF
            asl
            tay
            lda   MTab+1536,y
            clc
            adc   MKs
            sec
            sbc   ]3,x
            sta   T12
            lda   ]1,x
            clc
            adc   ]3,x
            sta   T0
            lda   ]1,x
            sec
            sbc   ]3,x
            sta   T3
            lda   ]1,x
            clc
            adc   T12
            sta   T1
            lda   ]1,x
            sec
            sbc   T12
            sta   T2
            lda   ]2,x                  ; odd part: z11 = z12 = In1, z13 = In3,
            clc                         ; z10 = -In3
            adc   ]4,x
            sta   T7
            lda   ]2,x
            sec
            sbc   ]4,x
            sta   Z10                   ; (z11 - z13 = z10 + z12 = In1 - In3)
            sta   MKv                   ; x 362
            and   #$00FF
            asl
            tay
            lda   MTab+1024,y
            sta   MKs
            lda   MKv
            xba
            and   #$00FF
            asl
            tay
            lda   MTab+1536,y
            clc
            adc   MKs
            sta   T11
            lda   Z10
            sta   MKv                   ; x 473
            and   #$00FF
            asl
            tay
            lda   MTab+2048,y
            sta   MKs
            lda   MKv
            xba
            and   #$00FF
            asl
            tay
            lda   MTab+2560,y
            clc
            adc   MKs
            sta   Z5
            lda   ]2,x
            sta   MKv                   ; x 277
            and   #$00FF
            asl
            tay
            lda   MTab,y
            sta   MKs
            lda   MKv
            xba
            and   #$00FF
            asl
            tay
            lda   MTab+512,y
            clc
            adc   MKs
            sec
            sbc   Z5
            sta   T10
            lda   ]4,x
            sta   MKv                   ; x -669 (of z10)
            and   #$00FF
            asl
            tay
            lda   MTab+3072,y
            sta   MKs
            lda   MKv
            xba
            and   #$00FF
            asl
            tay
            lda   MTab+3584,y
            clc
            adc   MKs
            clc
            adc   Z5
            sec                         ; tmp6 = tmp12 - tmp7
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
            <<<

JHCnt       =     Work                  ; 8 Huffman tables: counts by length (17 words)
JHSym       =     Work+512              ;   and symbols (256 words each)
QTab        =     Work+4608             ; 4 quantisation tables, natural order, scaled
CrR         =     Work+5120             ; colour conversion, by sample value
CbB         =     Work+5632
CrG         =     Work+6144
CbG         =     Work+6656
Coef        =     Work+7168             ; one block's coefficients (64 words)
WS          =     Work+7296             ; IDCT work space (64 words)
JLim        =     Work+14336            ; per table and length (as JHCnt): the
JOff        =     Work+14608            ;   code limit, and symbol index - first
JClamp      =     Work+14880            ; 0-255 for -384 to 639 (1024 bytes)
MTab        =     Work+8192             ; MulK's tables, 1024 bytes for each
                                        ; constant: lo x K / 256, then hi x K

DecodeJPEG  stz   JProg                 ; (a progressive picture's
            stz   JScans                ; coefficients: freed however it ends)
            ldx   #10
:none       stz   CfHnd,x
            dex
            dex
            bpl   :none
            lda   #6144                 ; the Huffman lookups: 8 x 512 bytes,
            sta   n0                    ; and 4 fast AC ones (in one bank)
            stz   n0+2
            jsr   NewBuffer
            bcs   :nomem
            lda   n1
            sta   LkHnd
            lda   n1+2
            sta   LkHnd+2
            lda   p0
            sta   LkP
            lda   p0+2
            sta   hl+2
            sta   ha+2
            jsr   JMain
            php
            pha
            ldx   #LkHnd
            jsr   FreeHandleAt
            ldx   #CfHnd
            jsr   FreeHandleAt
            ldx   #CfHnd+4
            jsr   FreeHandleAt
            ldx   #CfHnd+8
            jsr   FreeHandleAt
            pla
            plp
:nomem      rts

JMain       jsr   MulTables
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
            bcc   :jx1
            jmp   :eod
:jx1
            cmp   #$FF
            bne   :marker
:ff         jsr   GetByte
            bcc   :jx2
            jmp   :eod
:jx2
:code       cmp   #$FF
            beq   :ff
            cmp   #0
            beq   :marker
            cmp   #$D8                  ; SOI, RSTn: no segment
            beq   :marker
            cmp   #$D9                  ; EOI (before any scan: damaged)
            bne   :jx3
            jmp   :eod
:jx3
            cmp   #$D0
            bcc   :seg
            cmp   #$D8
            bcc   :marker
:seg        cmp   #$C0
            beq   :sof
            cmp   #$C1
            beq   :sof
            cmp   #$C2
            beq   :sof2
            cmp   #$C4
            bne   :jx10
            jmp   :dht
:jx10
            cmp   #$DB
            bne   :jx11
            jmp   :dqt
:jx11
            cmp   #$DD
            bne   :jx12
            jmp   :dri
:jx12
            cmp   #$DA
            bne   :jx5
            jmp   :sos
:jx5
            cmp   #$C8                  ; other frame types: lossless,
            beq   :skip                 ; arithmetic coding
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
            jmp   :marker
:corrupt    lda   #errCorrupt
            sec
            rts
:sof        lda   JProg                 ; (a second frame: damaged)
            bne   :sof2x
            jsr   ReadSOF
            bcs   :jx4
            jmp   :marker
:jx4
            rts
:sof2       lda   JProg                 ; progressive: room for the
            beq   :sof2a                ; coefficients
:sof2x      jmp   :corrupt
:sof2a      jsr   ReadSOF
            bcs   :perr
            inc   JProg
            jsr   JpInit
            bcs   :perr
            jmp   :marker
:perr       rts
:pscan      jsr   JpScan                ; a progressive scan, then the marker
            bcs   :perr                 ; that ended it
            lda   MarkerHit
            beq   :pnext
            lda   JMark
            jmp   :code
:pnext      jmp   :marker
:eod        lda   JScans                ; the end: a progressive picture's
            bne   :pout                 ; scans so far, or damaged
            jmp   :corrupt
:pout       stz   RestartInt
            bra   :scan
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
            lda   JProg
            bne   :pscan
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
            lda   hl
            sta   DCLk,x
            lda   t1
            and   #$0003
            ora   #$0004
            jsr   TableAddr
            lda   hc
            sta   ACCnt,x
            lda   hs
            sta   ACSym,x
            lda   hl
            sta   ACLk,x
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

* TableAddr: hc, hs and hl for Huffman table A. Keeps X.
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
            pha
            clc
            adc   #JHSym
            sta   hs
            pla
            clc
            adc   LkP
            sta   hl
            rts

*-------------------------------------------------------------
* The scan
*-------------------------------------------------------------
DecodeScan  jsr   McuDims
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
            lda   #1                    ; (every row is written, or filled
            sta   NoFill                ; at the end when the data is damaged)
            jsr   NewTrue
            stz   NoFill
            bcc   :start
            rts
:start      ldx   #126                  ; (the IDCT leaves them clear)
:clr        stz   Coef,x
            dex
            dex
            bpl   :clr
            jsr   MakeLims
            stz   jn
            stz   jb
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
:hb         jsr   JBlock
            bcc   :ok
            inc   JErr                  ; damaged: keep what was decoded
            bra   :rows
:ok         jsr   BlockAt
            lda   ACAny                 ; (only DC: the same all over)
            bne   :idct
            jsr   DCOnly
            bra   :stored
:idct       jsr   IDCT
:stored
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
            bne   :fill
            inc   MY
            lda   MY
            cmp   McusY
            bcs   :done
            jmp   :mcuRow
:done       clc
            rts
:fill       lda   MY                    ; damaged: the rows below the last
            inc                         ; strip white
            ldx   McuH
            jsr   Mul16
            lda   ProdLo
            cmp   TrueH
            bcs   :done
            pha
            jsr   TrueRowAt
            lda   q0
            sta   p0
            lda   q0+2
            sta   p0+2
            pla
            eor   #$FFFF
            sec
            adc   TrueH
            ldx   TrueStride
            jsr   Mul16
            lda   ProdLo
            sta   n0
            lda   ProdHi
            sta   n0+2
            lda   TrueFill
            jsr   FillBig
            clc
            rts

* McuDims: MCUs across and down.
McuDims     lda   HMax
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
            rts

*-------------------------------------------------------------
* Progressive pictures
*-------------------------------------------------------------

* JpInit: room for a progressive picture's coefficients, all 0: for each
* component, blocks of 64 words (in zig-zag order), McusX x H across and
* McusY x V down; and how many blocks a scan of it alone holds.
JpInit      jsr   McuDims
            ldx   #0
:comp       stx   CI
            lda   TrueW                 ; alone: its own width and height
            ldy   CH,x                  ; in blocks
            cpy   HMax
            beq   :w
            inc
            lsr
:w          clc
            adc   #7
            lsr
            lsr
            lsr
            sta   NBX,x
            lda   TrueH
            ldy   CV,x
            cpy   VMax
            beq   :h
            inc
            lsr
:h          clc
            adc   #7
            lsr
            lsr
            lsr
            sta   NBY,x
            lda   McusX                 ; kept: whole MCUs
            ldy   CH,x
            cpy   #2
            bne   :bx
            asl
:bx         sta   CfBX,x
            lda   McusY
            ldy   CV,x
            cpy   #2
            bne   :by
            asl
:by         ldy   CfBX,x
            tyx
            jsr   Mul16                 ; blocks x 128 bytes
            lda   ProdLo
            sta   n0
            lda   ProdHi
            sta   n0+2
            ldx   #7
:x128       asl   n0
            rol   n0+2
            dex
            bne   :x128
            jsr   NewBig                ; (often more than a bank)
            bcs   :out
            lda   CI
            asl
            tay
            lda   n1
            sta   CfHnd,y
            lda   n1+2
            sta   CfHnd+2,y
            lda   p0
            sta   CfP,y
            lda   p0+2
            sta   CfP+2,y
            lda   #0
            jsr   FillBig
            ldx   CI
            inx
            inx
            txa
            lsr
            cmp   JNComp
            bcs   :jx6
            jmp   :comp
:jx6
            clc
:out        rts

* JpScan: one scan of a progressive picture: its components, the
* coefficients it holds (Ss to Se) and which of their bits (Ah, Al),
* added to each block's coefficients. Damaged data ends the scan.
JpScan      jsr   GetBE16               ; (its length)
            jsr   GetByte
            sta   JpNs
            beq   :bad
            cmp   JNComp
            beq   :ns
            bcs   :bad
:ns         stz   u1
:comp       jsr   GetByte               ; each component: which, and its
            ldx   #0                    ; tables
:find       cmp   CompId,x
            beq   :found
            inx
            inx
            cpx   #6
            bcc   :find
:bad        lda   #errCorrupt
            sec
            rts
:found      txa
            ldy   u1
            sta   JpComp,y
            phx
            jsr   GetByte
            plx
            sta   t1
            lsr
            lsr
            lsr
            lsr
            and   #$0003
            jsr   TableAddr
            lda   hc
            sta   DCCnt,x
            lda   hs
            sta   DCSym,x
            lda   hl
            sta   DCLk,x
            lda   t1
            and   #$0003
            ora   #$0004
            jsr   TableAddr
            lda   hc
            sta   ACCnt,x
            lda   hs
            sta   ACSym,x
            lda   hl
            sta   ACLk,x
            inc   u1
            inc   u1
            lda   u1
            lsr
            cmp   JpNs
            bcc   :comp
            jsr   GetByte               ; coefficients Ss to Se, bits Ah, Al
            sta   JpSs
            jsr   GetByte
            sta   JpSe
            jsr   GetByte
            pha
            and   #$000F
            sta   JpAl
            pla
            lsr
            lsr
            lsr
            lsr
            sta   JpAh
            lda   JpSe                  ; DC alone (any components), or AC
            cmp   #64                   ; of one component
            bcs   :bad
            cmp   JpSs
            bcc   :bad
            ldx   #0
            lda   JpSs
            bne   :ac
            lda   JpSe
            beq   :kind
            jmp   :bad
:ac         lda   JpNs
            cmp   #1
            beq   :jx7
            jmp   :bad
:jx7
            ldx   #4
:kind       lda   JpAh                  ; first, or refined
            beq   :first
            inx
            inx
:first      stx   JpKind
            ldx   JpAl
            lda   #1
:p1         cpx   #0
            beq   :p1d
            asl
            dex
            bra   :p1
:p1d        sta   JpP1
            jsr   MakeLims
            stz   jn
            stz   jb
            stz   MarkerHit
            stz   Pred
            stz   Pred+2
            stz   Pred+4
            stz   JpEOB
            lda   RestartInt
            sta   RstLeft
            lda   JpNs
            cmp   #1
            bne   :mcus
            lda   JpComp                ; one component: its blocks in order
            sta   CI
            stz   JpBY
:brow       ldx   CI
            lda   JpBY
            cmp   NBY,x
            bcc   :jx8
            jmp   :done
:jx8
            stz   JpBX
            jsr   JpBlkAt
:blk        jsr   JpRst
            jsr   JpOne
            bcs   :done
            lda   q1
            clc
            adc   #128
            sta   q1
            bcc   :nc
            inc   q1+2
:nc         inc   JpBX
            ldx   CI
            lda   JpBX
            cmp   NBX,x
            bcc   :blk
            inc   JpBY
            bra   :brow
:mcus       stz   MY                    ; more: by MCU, as in a baseline scan
:mrow       stz   MX
:mcu        jsr   JpRst
            stz   JpI
:sc         ldy   JpI
            ldx   JpComp,y
            stx   CI
            stz   VB
:vb         stz   HB
:hb         jsr   JpAt
            jsr   JpOne
            bcs   :done
            ldx   CI
            inc   HB
            lda   HB
            cmp   CH,x
            bcc   :hb
            inc   VB
            lda   VB
            cmp   CV,x
            bcc   :vb
            inc   JpI
            inc   JpI
            lda   JpI
            lsr
            cmp   JpNs
            bcc   :sc
            inc   MX
            lda   MX
            cmp   McusX
            bcc   :mcu
            inc   MY
            lda   MY
            cmp   McusY
            bcc   :mrow
:done       inc   JScans
            clc
            rts

* JpRst: at the start of an MCU, a restart marker if one is due.
JpRst       lda   RestartInt
            beq   :done
            lda   RstLeft
            bne   :count
            jsr   Restart
            stz   JpEOB
            lda   RestartInt
            sta   RstLeft
:count      dec   RstLeft
:done       rts

* JpOne: the scan's part of the block at q1 (component CI).
*   out: carry set if the data is damaged
JpOne       ldx   JpKind
            jmp   (JpKinds,x)

JpKinds     da    JpDC0,JpDC1,JpAC0,JpAC1

* JpAt: q1 = the kept block of component CI at MCU MX, MY, block HB, VB.
JpAt        ldx   CI
            lda   MX
            ldy   CH,x
            cpy   #2
            bne   :h
            asl
:h          clc
            adc   HB
            sta   JpBX
            lda   MY
            ldy   CV,x
            cpy   #2
            bne   :v
            asl
:v          clc
            adc   VB
* JpBlkAt: q1 = the kept block of component CI at JpBX across, A down.
JpBlkAt     ldx   CI
            pha
            lda   CfBX,x
            tax
            pla
            jsr   Mul16
            lda   ProdLo
            clc
            adc   JpBX
            sta   q1
            lda   ProdHi
            adc   #0
            sta   q1+2
            ldx   #7
:x128       asl   q1
            rol   q1+2
            dex
            bne   :x128
            lda   CI
            asl
            tax
            lda   q1
            clc
            adc   CfP,x
            sta   q1
            lda   q1+2
            adc   CfP+2,x
            sta   q1+2
            rts

* JpDC0: the DC coefficient's first bits: a difference, as in a baseline
* scan, shifted up by Al.
JpDC0       ldx   CI
            lda   DCLk,x
            sta   hl
            lda   DCCnt,x
            sta   hc
            lda   DCSym,x
            sta   hs
            jsr   DecodeJ
            bcs   :bad
            cmp   #12
            bcs   :bad
            tax
            beq   :d
            phx
            jsr   GetBitsJ
            plx
            jsr   Extend
:d          ldx   CI
            clc
            adc   Pred,x
            sta   Pred,x
            ldx   JpAl
            beq   :st
:sh         asl
            dex
            bne   :sh
:st         sta   [q1]
            clc
:bad        rts

* JpDC1: one more bit of the DC coefficient.
JpDC1       jsr   GetBitJ
            bcc   :done
            lda   [q1]
            ora   JpP1
            sta   [q1]
:done       clc
            rts

* JpAC0: the first bits of coefficients Ss to Se, or nothing in an
* end-of-band run.
JpAC0       lda   JpEOB
            beq   :go
            dec   JpEOB
            clc
            rts
:go         ldx   CI
            lda   ACLk,x
            sta   hl
            lda   ACCnt,x
            sta   hc
            lda   ACSym,x
            sta   hs
            lda   JpSs
            sta   K
:sym        jsr   DecodeJ
            bcs   :bad
            sta   u1
            and   #$000F
            bne   :val
            lda   u1                    ; no value: 16 zeros, or the end of
            lsr                         ; the band here and in more blocks
            lsr
            lsr
            lsr
            cmp   #15
            bne   :eob
            lda   K
            clc
            adc   #16
            sta   K
            bra   :next
:eob        jsr   JpRun
            dec   JpEOB
            clc
            rts
:val        sta   u3                    ; a run of zeros, then a value
            lda   u1
            lsr
            lsr
            lsr
            lsr
            clc
            adc   K
            cmp   #64
            bcs   :bad
            sta   K
            ldx   u3
            jsr   GetBitsJ
            ldx   u3
            jsr   Extend
            ldx   JpAl
            beq   :st
:sh         asl
            dex
            bne   :sh
:st         pha
            lda   K
            asl
            tay
            pla
            sta   [q1],y
            inc   K
:next       lda   JpSe
            cmp   K
            bcs   :sym
            clc
            rts
:bad        sec
            rts

* JpRun: an end-of-band run (r in A): 2^r blocks, plus the next r bits.
JpRun       sta   u0
            tax
            lda   #1
:sh         cpx   #0
            beq   :p
            asl
            dex
            bra   :sh
:p          sta   JpEOB
            ldx   u0
            beq   :done
            jsr   GetBitsJ
            clc
            adc   JpEOB
            sta   JpEOB
:done       rts

* JpAC1: one more bit of coefficients Ss to Se: those already not zero
* get a bit each; a new one (1 or -1 at bit Al) goes after so many zeros.
JpAC1       lda   JpP1
            eor   #$FFFF
            inc
            sta   JpM1
            lda   JpSs
            sta   K
            lda   JpEOB
            beq   :go
            jmp   :eob
:go         ldx   CI
            lda   ACLk,x
            sta   hl
            lda   ACCnt,x
            sta   hc
            lda   ACSym,x
            sta   hs
:sym        jsr   DecodeJ
            bcc   :jx9
            jmp   :bad
:jx9
            sta   u1
            lsr
            lsr
            lsr
            lsr
            sta   u0                    ; zeros to pass
            lda   u1
            and   #$000F
            beq   :nos
            jsr   GetBitJ               ; a new coefficient: its sign
            lda   JpP1
            bcs   :sp
            lda   JpM1
:sp         sta   u3
            bra   :adv
:nos        stz   u3                    ; none: 16 zeros, or the end of the
            lda   u0                    ; band
            cmp   #15
            beq   :adv
            jsr   JpRun
            bra   :eob
:adv        lda   K
            asl
            tay
            lda   [q1],y
            beq   :zero
            jsr   JpCorr
            bra   :inc
:zero       dec   u0
            bmi   :place
:inc        inc   K
            lda   JpSe
            cmp   K
            bcs   :adv
:place      lda   u3
            beq   :nxt
            lda   K
            cmp   #64
            bcs   :nxt
            asl
            tay
            lda   u3
            sta   [q1],y
:nxt        inc   K
            lda   JpSe
            cmp   K
            bcs   :sym
            clc
            rts
:eob        lda   JpSe                  ; the rest of the band: a bit each
            cmp   K                     ; for those not zero
            bcc   :end
            lda   K
            asl
            tay
            lda   [q1],y
            beq   :e
            jsr   JpCorr
:e          inc   K
            bra   :eob
:end        dec   JpEOB
            clc
            rts
:bad        sec
            rts

* JpCorr: a correction bit for the coefficient at [q1],y (not zero): if
* it is set and that bit of the coefficient isn't, the coefficient grows
* by it (away from 0).
JpCorr      jsr   GetBitJ
            bcc   :no
            lda   [q1],y
            and   JpP1
            bne   :no
            lda   [q1],y
            bmi   :neg
            clc
            adc   JpP1
            sta   [q1],y
:no         rts
:neg        sec
            sbc   JpP1
            sta   [q1],y
            rts

* JBlock: the next block's coefficients, dequantised: decoded, or from
* those kept for a progressive picture.
*   out: carry set if the data is damaged
JBlock      lda   JProg
            bne   :kept
            jmp   DecodeBlock
:kept       lda   #1                    ; (no shortcut for only DC)
            sta   ACAny
            jsr   JpAt
            ldx   CI                    ; (Coef is clear: the IDCT leaves it
            lda   CQ,x                  ; so)
            sta   u2
            ldy   #0
:k          lda   [q1],y
            bne   :nz
:next       iny
            iny
            cpy   #128
            bcc   :k
            lda   Coef                  ; (the IDCT's 128 and rounding)
            clc
            adc   #4112
            sta   Coef
            clc
            rts
:nz         sty   u3                    ; dequantised, in natural order
            ldx   ZigZag,y
            txy
            jsr   DeQuant
            sta   Coef,y
            ldy   u3
            bra   :next

* Restart: at a restart marker: realign and reset the DC predictions.
Restart     stz   jn
            stz   jb
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

* JFill: bytes into jb while it has 8 bits or fewer (9 to 16 after).
* Keeps Y.
JFill       lda   jn
            asl
            tax
            lda   MarkerHit             ; (GetByte, inline; at a marker or
                                        ; the file's end: zeros)
            bne   :zero
            lda   InLeft
            bne   :have
            lda   InLeft+2
            beq   :zero
            dec   InLeft+2
:have       dec   InLeft
            lda   [s0]
            inc   s0
            bne   :s
            inc   s0+2
:s          and   #$00FF
            cmp   #$FF
            beq   :ff
:byte       xba                         ; under the bits there already
            jsr   (JShrT,x)
            ora   jb
            sta   jb
            lda   jn
            clc
            adc   #8
            sta   jn
            cmp   #9
            bcc   JFill
            rts
:ff         phx                         ; $FF $00 is $FF; else a marker:
            jsr   GetByte               ; the data has ended
            plx
            bcs   :zero
            cmp   #0
            beq   :isFF
            sta   JMark
            inc   MarkerHit
:zero       lda   #0
            bra   :byte
:isFF       lda   #$FF
            bra   :byte

* Shifts of A by 0 to 8 (X = 2 x the count), through JSR (JShlT,X) or
* JSR (JShrT,X).
JSl8        asl
JSl7        asl
JSl6        asl
JSl5        asl
JSl4        asl
JSl3        asl
JSl2        asl
JSl1        asl
JSl0        rts
JSr8        lsr
JSr7        lsr
JSr6        lsr
JSr5        lsr
JSr4        lsr
JSr3        lsr
JSr2        lsr
JSr1        lsr
JSr0        rts
JShlT       da    JSl0,JSl1,JSl2,JSl3,JSl4,JSl5,JSl6,JSl7,JSl8
JShrT       da    JSr0,JSr1,JSr2,JSr3,JSr4,JSr5,JSr6,JSr7,JSr8

* GetBitJ: the next bit (highest first) in the carry. Keeps X and Y.
GetBitJ     lda   jn
            bne   :have
            phx
            jsr   JFill
            plx
:have       dec   jn
            asl   jb
            rts

* GetBitsJ: X bits, highest first, in A.
GetBitsJ    cpx   #9
            bcs   :long
            txa
            beq   :done
            sta   VSz
            lda   jn
            cmp   #8
            bcs   :have
            jsr   JFill
:have       lda   VSz                   ; the top bits: jb's high byte
            asl                         ; >> (8 - n)
            sta   VSz2
            eor   #$FFFF
            sec
            adc   #16
            tax
            lda   jb
            xba
            and   #$00FF
            jsr   (JShrT,x)
            sta   JVal
            ldx   VSz2                  ; and gone from jb
            lda   jb
            jsr   (JShlT,x)
            sta   jb
            lda   jn
            sec
            sbc   VSz
            sta   jn
            lda   JVal
:done       rts
:long       stz   JVal
:loop       jsr   GetBitJ
            rol   JVal
            dex
            bne   :loop
            lda   JVal
            rts

* GetValJ: the signed value of the next X bits, as JPEG codes it.
GetValJ     stx   VSz3
            jsr   GetBitsJ
            ldx   VSz3
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

* MakeLims: for each Huffman table and code length, DecodeJ's limit
* (first code + count) and the symbol index less the first code; then
* the lookups (MakeLook).
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

* MakeLook: each table's lookup, by the next 8 bits: the code's length x
* 2 (high byte) and its symbol, or 0 where the code is longer.
MakeLook    stz   MLt
:t          lda   MLt
            xba
            asl
            sta   MLk                   ; (its symbols: table x 512)
            clc
            adc   LkP
            sta   hl
            ldy   #510
            lda   #0
:clr        sta   [hl],y
            dey
            dey
            bpl   :clr
            lda   MLt                   ; its counts: table x 34
            asl
            sta   t1
            asl
            asl
            asl
            asl
            clc
            adc   t1
            sta   MLc
            stz   MLP                   ; the next code's first place
            lda   #2
            sta   MLL                   ; length x 2
            lda   #128                  ; places for each code of the length
            sta   MLN
:len        lda   MLc
            clc
            adc   MLL
            tax
            lda   JHCnt,x
            sta   MLCnt
:code       lda   MLCnt
            beq   :nextL
            lda   MLP                   ; (an over-full table: the rest are
            cmp   #256                  ; left to DecodeJ)
            bcs   :nextT
            asl
            tay
            ldx   MLk
            lda   JHSym,x
            and   #$00FF
            sta   t1
            lda   MLL
            xba
            ora   t1
            ldx   MLN
:fill       sta   [hl],y
            iny
            iny
            dex
            bne   :fill
            lda   MLP
            clc
            adc   MLN
            sta   MLP
            inc   MLk
            inc   MLk
            dec   MLCnt
            bra   :code
:nextL      lsr   MLN
            inc   MLL
            inc   MLL
            lda   MLL
            cmp   #18
            bcc   :len
:nextT      inc   MLt
            lda   MLt
            cmp   #8
            bcs   MakeFast
            jmp   :t

* MakeFast: for each AC table (4-7), by the next 8 bits: when its code and
* the value's bits both fit, the value (high byte, signed), the zero run
* (bits 4-7) and the bits used (0-3); else 0. 2048 bytes after the lookup.
MakeFast    lda   #4
            sta   MLt
:t          lda   MLt
            xba
            asl
            clc
            adc   LkP
            sta   hl
            clc
            adc   #2048
            sta   ha
            ldy   #0                    ; (the 8 bits x 2)
:i          lda   [hl],y
            beq   :put
            sta   t1                    ; length x 2, symbol
            and   #$000F
            beq   :none                 ; (no value: the end, or 16 zeros)
            sta   t2                    ; the value's size
            lda   t1
            xba
            and   #$00FF
            lsr
            clc
            adc   t2
            cmp   #9
            bcs   :none
            sta   t3                    ; bits used
            eor   #$FFFF                ; the value's bits: the 8 >> (8 -
            sec                         ; used), its size's low ones
            adc   #8
            asl
            tax
            tya
            lsr
            jsr   (JShrT,x)
            pha
            lda   t2
            asl
            tax
            pla
            and   MaskT,x
            cmp   HalfT,x               ; below half: negative
            bcs   :pos
            sec
            sbc   MaskT,x
:pos        and   #$00FF
            xba
            sta   u0
            lda   t1                    ; the zero run, the bits used
            and   #$00F0
            ora   t3
            ora   u0
            bra   :put
:none       lda   #0
:put        sta   [ha],y
            iny
            iny
            cpy   #512
            bcc   :i
            inc   MLt
            lda   MLt
            cmp   #8
            bcc   :t
            rts

* DecodeJ: one Huffman symbol (lookup at hl; code at hc, hs). Carry set
* if none matches.
DecodeJ     lda   jn
            cmp   #8
            bcs   :peek
            jsr   JFill
:peek       lda   jb                    ; the next 8 bits
            xba
            and   #$00FF
            asl
            tay
            lda   [hl],y
            beq   :long
            tay                         ; length x 2, symbol
            xba
            and   #$00FF
            tax
            lsr
            eor   #$FFFF
            sec
            adc   jn
            sta   jn
            lda   jb
            jsr   (JShlT,x)
            sta   jb
            tya
            and   #$00FF
            clc
            rts
:long       lda   hc                    ; longer: bit by bit against each
            sec                         ; length's limit (MakeLims)
            sbc   #JHCnt
            clc
            adc   #JLim
            sta   u0
            clc
            adc   #JOff-JLim
            sta   u3
            stz   HCode
            ldy   #2
:loop       jsr   GetBitJ
            rol   HCode
            lda   HCode
            cmp   (u0),y
            bcc   :found
            iny
            iny
            cpy   #34
            bcc   :loop
            sec
            rts
:found      clc
            adc   (u3),y
            asl
            tay
            lda   (hs),y
            clc
            rts

* DecodeBlock: the coefficients of one block of component CI, dequantised
* (into Coef, which the IDCT leaves clear).
DecodeBlock ldx   CI
            lda   CQ,x
            sta   u2
            lda   DCLk,x
            sta   hl
            lda   DCCnt,x
            sta   hc
            lda   DCSym,x
            sta   hs
            jsr   DecodeJ
            bcs   :bad0
            cmp   #12
            bcc   :dc
:bad0       sec
            rts
:dc         tax
            jsr   GetValJ
            ldx   CI
            clc
            adc   Pred,x
            sta   Pred,x
            ldy   #0                    ; times quantisation entry 0
            jsr   DeQuant
            clc                         ; (with the IDCT's 128 and
            adc   #4112                 ; rounding: 4096 + 16)
            sta   Coef
            ldx   CI
            lda   ACLk,x
            sta   hl
            clc
            adc   #2048
            sta   ha
            lda   ACCnt,x
            sta   hc
            lda   ACSym,x
            sta   hs
            lda   #1
            sta   K
            stz   ACAny
:ac         lda   jn                    ; the next 8 bits
            cmp   #8
            bcs   :peek
            jsr   JFill
:peek       lda   jb
            xba
            and   #$00FF
            asl
            tay
            lda   [ha],y                ; the code and the value in them:
            beq   :sym8                 ; all from the fast table
            sta   u1
            and   #$000F
            sta   u3
            asl
            tax
            lda   jb
            jsr   (JShlT,x)
            sta   jb
            lda   jn
            sec
            sbc   u3
            sta   jn
            lda   u1                    ; the zero run
            lsr
            lsr
            lsr
            lsr
            and   #$000F
            sec                         ; (and the place of the value)
            adc   K
            cmp   #65
            bcs   :fend
            dec
            sta   K
            asl
            tax
            ldy   ZigZag,x
            lda   u1                    ; the value, signed
            xba
            and   #$00FF
            cmp   #$0080
            bcc   :fpos
            ora   #$FF00
:fpos       jsr   DeQuant
            sta   Coef,y
            inc   ACAny
            inc   K
            lda   K
            cmp   #64
            bcs   :fend
            jmp   :ac
:fend       clc
            rts
:sym8       lda   [hl],y                ; the symbol (DecodeJ, inline)
            bne   :hit
            jsr   DecodeJ               ; (longer than 8 bits)
            bcc   :sym
            rts
:hit        tay
            xba
            and   #$00FF
            tax
            lsr
            eor   #$FFFF
            sec
            adc   jn
            sta   jn
            lda   jb
            jsr   (JShlT,x)
            sta   jb
            tya
            and   #$00FF
:sym        sta   u1
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
            bcs   :end
            jmp   :ac
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
            lda   u3
            cmp   #9
            bcs   :long
            cmp   jn                    ; its bits: jb's top ones
            bcc   :bits
            beq   :bits
            jsr   JFill
:bits       lda   u3
            asl
            tax
            lda   jb
            xba
            and   #$00FF
            jsr   (JShrS,x)
            sta   u1
            lda   jb
            jsr   (JShlT,x)
            sta   jb
            lda   jn
            sec
            sbc   u3
            sta   jn
            lda   u1                    ; below half: negative, its size
            cmp   HalfT,x               ; (2^s - 1) - the bits
            bcs   :pos
            eor   MaskT,x
            sta   u1
            lda   K
            asl
            tax
            ldy   ZigZag,x
            lda   u1
            jsr   DQMag
            eor   #$FFFF
            inc
            bra   :put
:pos        lda   K
            asl
            tax
            ldy   ZigZag,x
            lda   u1
            jsr   DQMag
            bra   :put
:long       tax                         ; (a long value)
            jsr   GetValJ
            pha
            lda   K
            asl
            tax
            ldy   ZigZag,x
            pla
            jsr   DeQuant
:put        sta   Coef,y
            inc   ACAny
            inc   K
            lda   K
            cmp   #64
            bcs   :full
            jmp   :ac
:full       clc
            rts
:bad        sec
            rts

* For a value of s bits (X = 2s): the shift that leaves them (8 - s),
* half its range, and the bits that make a negative one's size.
JShrS       da    JSr8,JSr7,JSr6,JSr5,JSr4,JSr3,JSr2,JSr1,JSr0
HalfT       dw    0,1,2,4,8,16,32,64,128
MaskT       dw    0,1,3,7,15,31,63,127,255

* DeQuant: A (signed) times quantisation entry Y of the table at u2 (low
* 16 bits). Keeps Y.
DeQuant     cmp   #0
            bpl   DQMag
            eor   #$FFFF
            inc
            jsr   DQMag
            eor   #$FFFF
            inc
            rts
DQMag       cmp   #2                    ; (mostly 1, or small: shift and add
            bcs   :mul                  ; once for each bit)
            cmp   #0
            beq   :zero
            lda   (u2),y
:zero       rts
:mul        sta   MV
            lda   (u2),y
            sta   MQ
            lda   #0
:loop       lsr   MV
            bcc   :next
            clc
            adc   MQ
            ldx   MV
            beq   :done
:next       asl   MQ
            bra   :loop
:done       rts

*-------------------------------------------------------------
* Inverse DCT: Coef -> the strip (BlockAt)
*-------------------------------------------------------------
IDCT        ldx   #0                    ; columns (Coef cleared as they are read)
:col        lda   Coef+64,x
            ora   Coef+80,x
            ora   Coef+96,x
            ora   Coef+112,x
            beq   :c4
            jmp   :full
:c4         lda   Coef+16,x
            ora   Coef+32,x
            ora   Coef+48,x
            bne   :half
            lda   Coef,x                ; only DC: the same all down
            stz   Coef,x
            sta   WS,x
            sta   WS+16,x
            sta   WS+32,x
            sta   WS+48,x
            sta   WS+64,x
            sta   WS+80,x
            sta   WS+96,x
            sta   WS+112,x
            jmp   :nextCol
:half       HBFLY Coef;Coef+16;Coef+32;Coef+48
            stz   Coef,x
            stz   Coef+16,x
            stz   Coef+32,x
            stz   Coef+48,x
            jmp   :cout
:full       BFLY  Coef;Coef+16;Coef+32;Coef+48;Coef+64;Coef+80;Coef+96;Coef+112
            stz   Coef,x
            stz   Coef+16,x
            stz   Coef+32,x
            stz   Coef+48,x
            stz   Coef+64,x
            stz   Coef+80,x
            stz   Coef+96,x
            stz   Coef+112,x
:cout
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

:rows       ldx   #0                    ; rows: X = row x 16, BI its place in
            lda   t1                    ; the strip (BlockAt)
            sta   BI
:row        lda   WS+8,x
            ora   WS+10,x
            ora   WS+12,x
            ora   WS+14,x
            beq   :r4
            jmp   :rfull
:r4         lda   WS+2,x
            ora   WS+4,x
            ora   WS+6,x
            bne   :rhalf
            lda   WS,x                  ; only the first: one sample
            jsr   RangeB
            ldy   BI
            sep   #$20
            mx    %10
            sta   [q2],y
            iny
            sta   [q2],y
            iny
            sta   [q2],y
            iny
            sta   [q2],y
            iny
            sta   [q2],y
            iny
            sta   [q2],y
            iny
            sta   [q2],y
            iny
            sta   [q2],y
            rep   #$20
            mx    %00
            jmp   :nextRow
:rhalf      HBFLY WS;WS+2;WS+4;WS+6
            jmp   :rout
:rfull      BFLY  WS;WS+2;WS+4;WS+6;WS+8;WS+10;WS+12;WS+14
:rout       stz   CHK                   ; (with the DC's 4112) bits 5-12 are
                                        ; the sample when no output is out of
                                        ; 0-8191 (no top 3 bits in CHK)
            lda   T0
            clc
            adc   T7
            tsb   CHK
            asl
            asl
            asl
            sta   Out0
            lda   T0
            sec
            sbc   T7
            tsb   CHK
            asl
            asl
            asl
            sta   Out7
            lda   T1
            clc
            adc   T6
            tsb   CHK
            asl
            asl
            asl
            sta   Out1
            lda   T1
            sec
            sbc   T6
            tsb   CHK
            asl
            asl
            asl
            sta   Out6
            lda   T2
            clc
            adc   T5
            tsb   CHK
            asl
            asl
            asl
            sta   Out2
            lda   T2
            sec
            sbc   T5
            tsb   CHK
            asl
            asl
            asl
            sta   Out5
            lda   T3
            clc
            adc   T4
            tsb   CHK
            asl
            asl
            asl
            sta   Out4
            lda   T3
            sec
            sbc   T4
            tsb   CHK
            asl
            asl
            asl
            sta   Out3
            lda   CHK
            and   #$E000
            beq   :inrange
            jsr   RowRange
:inrange    ldy   BI
            sep   #$20
            mx    %10
            lda   Out0+1
            sta   [q2],y
            iny
            lda   Out1+1
            sta   [q2],y
            iny
            lda   Out2+1
            sta   [q2],y
            iny
            lda   Out3+1
            sta   [q2],y
            iny
            lda   Out4+1
            sta   [q2],y
            iny
            lda   Out5+1
            sta   [q2],y
            iny
            lda   Out6+1
            sta   [q2],y
            iny
            lda   Out7+1
            sta   [q2],y
            rep   #$20
            mx    %00
:nextRow    lda   BI
            clc
            adc   t2
            sta   BI
            txa
            clc
            adc   #16
            tax
            cpx   #128
            bcs   :done
            jmp   :row
:done       rts

* RowRange: the IDCT's row outputs again, through RangeB (some are out
* of 0-255), in Out0-Out7's high bytes.
RowRange
            lda   T0
            clc
            adc   T7
            jsr   RangeB
            xba
            sta   Out0
            lda   T0
            sec
            sbc   T7
            jsr   RangeB
            xba
            sta   Out7
            lda   T1
            clc
            adc   T6
            jsr   RangeB
            xba
            sta   Out1
            lda   T1
            sec
            sbc   T6
            jsr   RangeB
            xba
            sta   Out6
            lda   T2
            clc
            adc   T5
            jsr   RangeB
            xba
            sta   Out2
            lda   T2
            sec
            sbc   T5
            jsr   RangeB
            xba
            sta   Out5
            lda   T3
            clc
            adc   T4
            jsr   RangeB
            xba
            sta   Out4
            lda   T3
            sec
            sbc   T4
            jsr   RangeB
            xba
            sta   Out3
            rts

* DCOnly: a block with only its DC coefficient: one sample all over.
DCOnly      lda   Coef
            stz   Coef
            jsr   RangeB
            sta   MKs
            xba
            ora   MKs
            sta   MKs                   ; (twice)
            lda   t1
            sta   BI
            ldx   #8
:row        ldy   BI
            lda   MKs
            sta   [q2],y
            iny
            iny
            sta   [q2],y
            iny
            iny
            sta   [q2],y
            iny
            iny
            sta   [q2],y
            lda   BI
            clc
            adc   t2
            sta   BI
            dex
            bne   :row
            rts

* MulK: (A * constant) / 256, signed (by its size, then the sign), the
* low 16 bits, X = the constant's table (4096: 359, 5120: 454), pushed
* first; keeps Y.
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

* MulTables: MTab for 277, 362, 473, 669, 359 and 454; for the first
* four (the IDCT's) hi is signed: hi x K less 256 K for hi 128-255.
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
            ldx   #0                    ; (constant x 2)
:sg         lda   MulKs,x
            and   #$00FF
            xba
            sta   t1                    ; 256 K, the low 16 bits
            txa
            xba
            asl                         ; its table, hi 128 on
            clc
            adc   #768
            tay
            lda   #128
            sta   t2
:sge        lda   MTab,y
            sec
            sbc   t1
            sta   MTab,y
            iny
            iny
            dec   t2
            bne   :sge
            inx
            inx
            cpx   #8
            bcc   :sg
            rts

MulKs       dw    277,362,473,669,359,454

* RangeB: a sample from an IDCT output with the DC's 4112 (v / 32 + 128,
* rounded): its bits 5-12 when it is 0-8191, else 0 or 255.
RangeB      cmp   #8192
            bcc   :mid
            asl
            bcs   :zero
            lda   #255
            rts
:zero       lda   #0
            rts
:mid        asl
            asl
            asl
            xba
            and   #$00FF
            rts

* BlockAt: q2 = component CI's strip, t1 = the place in it of block
* (MX * H + HB, VB), t2 = the strip's width.
BlockAt     ldx   CI
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
            rts

*-------------------------------------------------------------
* Colour
*-------------------------------------------------------------

* ColourTables: YCbCr -> RGB contributions for each sample value.
ColourTables lda  JNComp
            cmp   #3
            bne   :done
            ldx   #0                    ; JClamp: -384 to 639 kept within 0-255
:cl         txa
            sec
            sbc   #384
            bpl   :c1
            lda   #0
:c1         cmp   #256
            bcc   :c2
            lda   #255
:c2         sep   #$20
            mx    %10
            sta   JClamp,x
            rep   #$20
            mx    %00
            inx
            cpx   #1024
            bcc   :cl
            ldy   #0
:entry      tya
            lsr
            sec
            sbc   #128                  ; x = value - 128
            sta   u1
            jsr   M359                  ; red and blue: where their lookups
            clc                         ; start (JClamp + 384 + the part)
            adc   #JClamp+384
            sta   CrR,y
            lda   u1
            jsr   M454
            clc
            adc   #JClamp+384
            sta   CbB,y
            lda   u1                    ; green parts, 7 fraction bits, the
            ldx   #91                   ; Cb one with 64 (rounding) and
            jsr   SMul                  ; 17280 (135 x 128: the sum not
            sta   CrG,y                 ; negative)
            lda   u1
            ldx   #44
            jsr   SMul
            clc
            adc   #17344
            sta   CbG,y
            iny
            iny
            cpy   #512
            bcc   :entry
:done       rts

* ChromaParts: where the pixel lookups start for chroma JCb, JCr (x 2):
* JClamp + 384 + the red part (PRAdd), + the blue part (PBAdd), less
* the green part (PGSub). Keeps Y.
ChromaParts ldx   JCr
            lda   CrR,x
            sta   PRAdd
            lda   CrG,x
            ldx   JCb
            clc
            adc   CbG,x
            jsr   GreenAt
            sta   PGSub
            lda   CbB,x
            sta   PBAdd
            rts

* GreenAt: where the green lookup starts for a green sum (Cb and Cr
* parts, as ColourTables keeps them): JClamp + 384 - (the sum / 128 - 135).
GreenAt     asl
            xba
            and   #$00FF
            bcc   :g
            ora   #$0100
:g          eor   #$FFFF
            sec
            adc   #JClamp+384+135
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
:three      lda   TrueW                 ; colour: Y the place in the row,
            sta   PCnt                  ; the lookups' addresses written into
            stz   PixX                  ; the code for each chroma sample
            ldy   #0
            lda   ShX+2                 ; chroma half as wide: once for each
            beq   :topix                ; pair of pixels, p1, p2, p3 stepping
            lda   ShX+4                 ; along
            bne   :pair
:topix      jmp   :pix
:pair       lda   [p3]                  ; Cr: red, and its green part
            and   #$00FF
            asl
            tax
            lda   CrR,x
            sta   :r1+1
            sta   :r2+1
            lda   CrG,x
            sta   GT
            lda   [p2]                  ; Cb: blue, and the green
            and   #$00FF
            asl
            tax
            lda   CbB,x
            sta   :b1+1
            sta   :b2+1
            lda   CbG,x
            clc
            adc   GT
            jsr   GreenAt
            sta   :g1+1
            sta   :g2+1
            inc   p2
            inc   p3
            lda   PCnt                  ; carry: two pixels left (INC, AND,
            cmp   #2                    ; SEP, LDA, STA, INY and TAX keep it)
            lda   [p1]                  ; two luma samples
            inc   p1
            inc   p1
            sta   LP
            and   #$00FF                ; (the high byte 0 for TAX below)
            tax
            sep   #$20
            mx    %10
:r1         lda   JClamp,x              ; red, green, blue
            sta   [q0],y
            iny
:g1         lda   JClamp,x
            sta   [q0],y
            iny
:b1         lda   JClamp,x
            sta   [q0],y
            iny
            bcc   :pd8
            lda   LP+1
            tax
:r2         lda   JClamp,x
            sta   [q0],y
            iny
:g2         lda   JClamp,x
            sta   [q0],y
            iny
:b2         lda   JClamp,x
            sta   [q0],y
            iny
            rep   #$20
            mx    %00
            lda   PCnt
            sbc   #2                    ; (carry still set)
            sta   PCnt
            beq   :pd
            jmp   :pair
:pd8        rep   #$20
:pd         jmp   :rowDone
:pix        sty   DestOff               ; any other: each pixel's own
            lda   PixX
            ldy   ShX+2
            beq   :cb
            lsr
:cb         tay
            lda   [p2],y
            and   #$00FF
            asl
            sta   JCb
            lda   PixX
            ldy   ShX+4
            beq   :cr
            lsr
:cr         tay
            lda   [p3],y
            and   #$00FF
            asl
            sta   JCr
            jsr   ChromaParts
            lda   PRAdd
            sta   :r3+1
            lda   PGSub
            sta   :g3+1
            lda   PBAdd
            sta   :b3+1
            ldy   PixX
            lda   [p1],y
            and   #$00FF
            tax
            ldy   DestOff
            sep   #$20
            mx    %10
:r3         lda   JClamp,x
            sta   [q0],y
            iny
:g3         lda   JClamp,x
            sta   [q0],y
            iny
:b3         lda   JClamp,x
            sta   [q0],y
            iny
            rep   #$20
            mx    %00
            inc   PixX
            dec   PCnt
            beq   :rowDone
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
JVal        dw    0
VSz         dw    0                     ; (GetBitsJ: bits, and x 2; GetValJ)
VSz2        dw    0
VSz3        dw    0
MV          dw    0                     ; (DeQuant: the value, the entry)
MQ          dw    0
BI          dw    0                     ; (IDCT: the row's place in the strip)
LkHnd       adrl  0                     ; the Huffman lookups: handle, address
LkP         dw    0                     ;   (low word; hl+2 the bank)
MLt         dw    0                     ; (MakeLook: table, symbol, counts,
MLk         dw    0                     ;   place, length x 2, places for
MLc         dw    0                     ;   each code)
MLP         dw    0
MLL         dw    0
MLN         dw    0
MarkerHit   dw    0
JMark       dw    0                     ; (the marker that was hit)
JProg       dw    0                     ; progressive: the scans so far,
JScans      dw    0
CfHnd       ds    12                    ; and for each component: its
CfP         ds    12                    ; coefficients (handle, pointer),
CfBX        ds    6                     ; blocks across them, and in a scan of
NBX         ds    6                     ; it alone
NBY         ds    6
JpNs        dw    0                     ; the scan: components, which,
JpComp      ds    8
JpSs        dw    0                     ; coefficients, bits
JpSe        dw    0
JpAh        dw    0
JpAl        dw    0
JpP1        dw    0                     ; (1, -1 at bit Al)
JpM1        dw    0
JpEOB       dw    0                     ; blocks left in an end-of-band run
JpKind      dw    0
JpI         dw    0
JpBX        dw    0
JpBY        dw    0
MKc         dw    0
MKt         dw    0
MLCnt       dw    0                     ; (MakeLims: lengths left)
PRAdd       dw    0                     ; (OutRows: a chroma pair's parts)
PBAdd       dw    0
PGSub       dw    0                     ; (MulK: the constant's table)
JY          dw    0
PixX        dw    0                     ; (OutRows: the pixel)
ACAny       dw    0                     ; (DecodeBlock: AC coefficients)
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
DCLk        dw    0,0,0
ACLk        dw    0,0,0
CHnd        adrl  0,0,0
CP          adrl  0,0,0
LineP       adrl  0,0,0
