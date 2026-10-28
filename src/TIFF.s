*-------------------------------------------------------------
* TIFF.s - part of the Other segment: TIFF pictures
*
* Intel or Motorola byte order; the first image of the file; strips
* uncompressed, PackBits or LZW (with the horizontal predictor for
* 8-bit samples); grey (white or black is zero) in 1, 2, 4, 8 or 16
* bits, RGB in 8 or 16 bits (extra samples ignored), and palette
* pictures of 1 to 8 bits.
*-------------------------------------------------------------

LoadTIFF    lda   #0
            jsr   SAtA
            jsr   SLE16
            stz   TLE
            cmp   #$4D4D                ; "MM": Motorola
            beq   :order
            cmp   #$4949                ; "II": Intel
            bne   :bad
            inc   TLE
:order      jsr   TU16
            cmp   #42
            bne   :bad
            jsr   TU32                  ; the first directory
            lda   n1
            sta   n0
            lda   n1+2
            sta   n0+2
            jsr   SAt
            bcc   :defaults
:bad        lda   #errNotPicture
            sec
            rts
:defaults   stz   TW
            stz   TH
            lda   #1
            sta   TBits
            sta   TComp
            sta   TPhoto
            sta   TSPP
            sta   TPlanar
            sta   TPred
            lda   #$FFFF
            sta   TRPS
            stz   TBitsOff
            stz   TBitsOff+2
            stz   TSOCnt
            stz   TSBCnt
            stz   TCmap
            stz   TCmap+2
            stz   TCmapHas
            jsr   TU16
            sta   u1                    ; entries
:entry      lda   u1
            bne   :more
            jmp   :read
:more       dec   u1
            jsr   TU16
            sta   TTag
            jsr   TU16
            sta   TType
            jsr   TU32
            lda   n1
            sta   TCnt
            lda   n1+2
            sta   TCnt+2
            lda   TType                 ; the value (or where the values are)
            cmp   #3
            bne   :long
            lda   TCnt+2
            bne   :long
            lda   TCnt
            cmp   #3
            bcs   :long
            jsr   TU16                  ; one or two shorts, in place
            sta   TVal
            stz   TVal+2
            jsr   TU16
            bra   :tag
:long       jsr   TU32
            lda   n1
            sta   TVal
            lda   n1+2
            sta   TVal+2
:tag        lda   TTag
            cmp   #256
            bne   :t257
            lda   TVal
            sta   TW
            bra   :entry
:t257       cmp   #257
            bne   :t258
            lda   TVal
            sta   TH
            bra   :entry
:t258       cmp   #258
            bne   :t259
            lda   TCnt                  ; one value each sample: the first
            cmp   #3
            bcs   :bitsAt
            lda   TVal
            sta   TBits
            jmp   :entry
:bitsAt     lda   TVal
            sta   TBitsOff
            lda   TVal+2
            sta   TBitsOff+2
            jmp   :entry
:t259       cmp   #259
            bne   :t262
            lda   TVal
            sta   TComp
            jmp   :entry
:t262       cmp   #262
            bne   :t273
            lda   TVal
            sta   TPhoto
            jmp   :entry
:t273       cmp   #273
            bne   :t277
            lda   TType
            sta   TSOType
            lda   TCnt
            sta   TSOCnt
            lda   TVal
            sta   TSOVal
            lda   TVal+2
            sta   TSOVal+2
            jmp   :entry
:t277       cmp   #277
            bne   :t278
            lda   TVal
            sta   TSPP
            jmp   :entry
:t278       cmp   #278
            bne   :t279
            lda   TVal+2
            bne   :rpsBig
            lda   TVal
            sta   TRPS
:rpsBig     jmp   :entry
:t279       cmp   #279
            bne   :t284
            lda   TType
            sta   TSBType
            lda   TCnt
            sta   TSBCnt
            lda   TVal
            sta   TSBVal
            lda   TVal+2
            sta   TSBVal+2
            jmp   :entry
:t284       cmp   #284
            bne   :t317
            lda   TVal
            sta   TPlanar
            jmp   :entry
:t317       cmp   #317
            bne   :t320
            lda   TVal
            sta   TPred
            jmp   :entry
:t320       cmp   #320
            bne   :skip
            lda   TVal
            sta   TCmap
            lda   TVal+2
            sta   TCmap+2
            inc   TCmapHas
:skip       jmp   :entry

:read       lda   TBitsOff              ; bits per sample from a list
            ora   TBitsOff+2
            beq   :check
            lda   TBitsOff
            sta   n0
            lda   TBitsOff+2
            sta   n0+2
            jsr   SAt
            jsr   TU16
            sta   TBits
:check      lda   TW                    ; what can be read
            beq   :unsup
            lda   TH
            beq   :unsup
            lda   TSOCnt
            beq   :unsup
            lda   TSPP
            beq   :unsup
            cmp   #1
            beq   :planar
            lda   TPlanar
            cmp   #1
            bne   :unsup
:planar     lda   TComp
            cmp   #1
            beq   :comp
            cmp   #5
            beq   :comp
            cmp   #32773
            bne   :unsup
:comp       lda   TPhoto
            cmp   #4
            bcs   :unsup
            cmp   #2
            bne   :notRGB
            lda   TSPP
            cmp   #3
            bcc   :unsup
            lda   TBits
            cmp   #8
            beq   :ok
            cmp   #16
            beq   :ok
:unsup      lda   #errUnsupported
            sec
            rts
:notRGB     cmp   #3
            bne   :grey
            lda   TCmapHas
            beq   :unsup
            lda   TBits
            beq   :unsup
            cmp   #9
            bcs   :unsup
            bra   :ok
:grey       lda   TBits
            cmp   #1
            beq   :ok
            cmp   #2
            beq   :ok
            cmp   #4
            beq   :ok
            cmp   #8
            beq   :ok
            cmp   #16
            bne   :unsup
:ok         lda   TRPS                  ; rows a strip, at most the height
            cmp   TH
            bcc   :rps
            lda   TH
            sta   TRPS
:rps        lda   TW                    ; bytes a row = (width * samples * bits + 7) / 8
            ldx   TSPP
            jsr   Mul16
            lda   MLo
            ldx   TBits
            jsr   Mul16
            lda   MLo
            clc
            adc   #7
            sta   TRowBytes
            lda   MHi
            adc   #0
            ldx   #3
:sh         lsr
            ror   TRowBytes
            dex
            bne   :sh
            cmp   #0
            beq   :rowOK
            lda   #errTooBig
            sec
            rts
:rowOK      lda   TPhoto
            cmp   #3
            bne   :alloc
            jsr   TReadMap
:alloc      lda   TRPS                  ; a strip's buffer
            ldx   TRowBytes
            jsr   Mul16
            lda   MLo
            sta   TSize
            lda   MHi
            sta   TSize+2
            jsr   TNewBuf
            bcc   :pic
            rts
:pic        lda   TW
            ldx   TH
            stz   ttall
            jsr   MakeTrue
            bcc   :strips
            pha
            jsr   TFreeBuf
            pla
            rts
:strips     stz   TStrip
            stz   TY
:strip      lda   TY
            cmp   TH
            bcs   :done
            jsr   TDecode               ; this strip into the buffer
            lda   TH                    ; its rows: at most RPS, at most what is left
            sec
            sbc   TY
            cmp   TRPS
            bcc   :rows
            lda   TRPS
:rows       sta   u2
            lda   TBuf
            sta   p3
            lda   TBuf+2
            sta   p3+2
:row        jsr   TPredict
            lda   TY
            jsr   TrueRow
            jsr   TPixels
            lda   p3
            clc
            adc   TRowBytes
            sta   p3
            bcc   :nx
            inc   p3+2
:nx         inc   TY
            dec   u2
            bne   :row
            inc   TStrip
            bra   :strip
:done       jsr   TFreeBuf
            clc
            rts

* TU16, TU32: a number in the file's byte order (TU32: in n1).
TU16        lda   TLE
            beq   :be
            jmp   SLE16
:be         jmp   SBE16

TU32        lda   TLE
            beq   :be
            jsr   SLE16
            sta   n1
            jsr   SLE16
            sta   n1+2
            rts
:be         jmp   SBE32

* TReadMap: the colour map (3 x 2^bits 16-bit values) into TabR, TabG, TabB.
TReadMap    ldx   TBits
            lda   #1
:pow        asl
            dex
            bne   :pow
            sta   u3                    ; entries
            lda   TCmap
            sta   n0
            lda   TCmap+2
            sta   n0+2
            jsr   SAt
            ldx   #0
:r          jsr   TU16
            xba
            and   #$00FF
            sta   TabR,x
            inx
            inx
            txa
            lsr
            cmp   u3
            bcc   :r
            ldx   #0
:g          jsr   TU16
            xba
            and   #$00FF
            sta   TabG,x
            inx
            inx
            txa
            lsr
            cmp   u3
            bcc   :g
            ldx   #0
:b          jsr   TU16
            xba
            and   #$00FF
            sta   TabB,x
            inx
            inx
            txa
            lsr
            cmp   u3
            bcc   :b
            rts

* TListAt: entry TStrip of a list (count A, type X, value/offset TLVal) in n0.
TListAt     cmp   #1
            bne   :list
            lda   TLVal
            sta   n0
            lda   TLVal+2
            sta   n0+2
            rts
:list       stx   t1
            lda   TStrip
            asl
            ldx   t1
            cpx   #3
            beq   :short
            asl
:short      clc
            adc   TLVal
            sta   n0
            lda   TLVal+2
            adc   #0
            sta   n0+2
            jsr   SAt
            lda   t1
            cmp   #3
            bne   :long
            jsr   TU16
            sta   n0
            stz   n0+2
            rts
:long       jsr   TU32
            lda   n1
            sta   n0
            lda   n1+2
            sta   n0+2
            rts

* TDecode: strip TStrip, uncompressed, into the buffer (TSize bytes).
TDecode     lda   TSBVal                ; its byte count
            sta   TLVal
            lda   TSBVal+2
            sta   TLVal+2
            lda   TSBCnt
            bne   :counts
            lda   #$FFFF                ; no counts: as much as there is
            sta   TLeft
            sta   TLeft+2
            bra   :offset
:counts     ldx   TSBType
            jsr   TListAt
            lda   n0
            sta   TLeft
            lda   n0+2
            sta   TLeft+2
:offset     lda   TSOVal                ; where it is
            sta   TLVal
            lda   TSOVal+2
            sta   TLVal+2
            lda   TSOCnt
            ldx   TSOType
            jsr   TListAt
            jsr   SAt
            lda   TBuf                  ; output
            sta   p1
            lda   TBuf+2
            sta   p1+2
            lda   TSize
            sta   TOutLeft
            lda   TSize+2
            sta   TOutLeft+2
            lda   TComp
            cmp   #5
            beq   :lzw
            cmp   #1
            beq   :plain
            jsr   PBStart               ; PackBits
:pb         lda   TOutLeft
            ora   TOutLeft+2
            beq   :done
            jsr   PBGet
            jsr   TPut
            bra   :pb
:plain      jsr   TByte
            bcs   :fill
            jsr   TPut
            bcc   :plain
            bra   :done
:lzw        jsr   TLzw
:fill       lda   TOutLeft              ; whatever is missing: 0
            ora   TOutLeft+2
            beq   :done
            lda   #0
            jsr   TPut
            bra   :fill
:done       rts

* TByte: the next byte of the strip; carry set at its end.
TByte       lda   TLeft
            ora   TLeft+2
            beq   :end
            lda   TLeft
            bne   :lo
            dec   TLeft+2
:lo         dec   TLeft
            jmp   SByte
:end        sec
            rts

* TPut: a byte into the buffer; carry set when it is full.
TPut        ldx   TOutLeft
            bne   :room
            ldx   TOutLeft+2
            beq   :full
            dec   TOutLeft+2
:room       dec   TOutLeft
            sep   #$20
            mx    %10
            sta   [p1]
            rep   #$20
            mx    %00
            inc   p1
            bne   :ok
            inc   p1+2
:ok         clc
            rts
:full       sec
            rts

* TLzw: TIFF LZW: codes high bit first, 9 to 12 bits, clear 256, end 257,
* the code width growing one code early.
TLzw        stz   TBitCnt
            stz   TAcc
            stz   TAcc+2
:clear      lda   #9
            sta   TWidth
            lda   #258
            sta   TNext
            lda   #$FFFF
            sta   TPrev
:loop       lda   TOutLeft
            ora   TOutLeft+2
            bne   :code
            rts
:code       jsr   TCode
            cmp   #257
            bne   :notEnd
            rts
:notEnd     cmp   #256
            beq   :clear
            sta   TCodeV
            ldx   TPrev
            cpx   #$FFFF
            bne   :normal
            sta   TPrev                 ; the first code after a clear
            sta   TFirst
            jsr   TPut
            bra   :loop
:normal     ldy   #0
            cmp   TNext
            bcc   :walk
            lda   TFirst                ; the code being made: previous + its first byte
            sep   #$20
            mx    %10
            sta   LStack
            rep   #$20
            mx    %00
            ldy   #1
            lda   TPrev
:walk       cmp   #256
            bcc   :root
            tax
            sep   #$20
            mx    %10
            lda   LSuffix,x
            sta   LStack,y
            rep   #$20
            mx    %00
            iny
            cpy   #4096
            bcs   :out
            txa
            asl
            tax
            lda   LPrefix,x
            bra   :walk
:out        rts
:root       sta   TFirst
            jsr   TPut
:pop        dey
            bmi   :add
            lda   LStack,y
            and   #$00FF
            phy
            jsr   TPut
            ply
            bra   :pop
:add        ldx   TNext                 ; new code: previous + first byte
            cpx   #4096
            bcs   :keep
            sep   #$20
            mx    %10
            lda   TFirst
            sta   LSuffix,x
            rep   #$20
            mx    %00
            txa
            asl
            tax
            lda   TPrev
            sta   LPrefix,x
            inc   TNext
            lda   TNext                 ; wider codes from 511, 1023, 2047 on
            cmp   #511
            beq   :wider
            cmp   #1023
            beq   :wider
            cmp   #2047
            bne   :keep
:wider      inc   TWidth
:keep       lda   TCodeV
            sta   TPrev
            jmp   :loop

* TCode: the next TWidth-bit code, high bit first (257 at the end of the strip).
TCode       lda   TBitCnt
            cmp   TWidth
            bcs   :have
            jsr   TByte
            bcc   :byte
            lda   #257
            rts
:byte       sta   t1                    ; TAcc = TAcc << 8 | byte
            lda   TAcc+1
            sta   TAcc+2
            lda   TAcc
            xba
            and   #$FF00
            ora   t1
            sta   TAcc
            lda   TBitCnt
            clc
            adc   #8
            sta   TBitCnt
            bra   TCode
:have       lda   TAcc                  ; code = TAcc >> (count - width)
            sta   t1
            lda   TAcc+2
            sta   t2
            lda   TBitCnt
            sec
            sbc   TWidth
            sta   TBitCnt
            tax
            beq   :mask
:sh         lsr   t2
            ror   t1
            dex
            bne   :sh
:mask       lda   TWidth
            asl
            tax
            lda   TMasks,x
            and   t1
            rts

* TPredict: undoes the horizontal predictor on the row at p3 (8-bit samples).
TPredict    lda   TPred
            cmp   #2
            bne   :done
            lda   TBits
            cmp   #8
            bne   :done
            lda   TW
            ldx   TSPP
            jsr   Mul16
            lda   MLo
            sta   t2                    ; samples in the row
            ldy   TSPP
:s          cpy   t2
            bcs   :done
            tya
            sec
            sbc   TSPP
            tax
            phy
            txy
            lda   [p3],y
            ply
            clc
            adc   [p3],y
            sep   #$20
            mx    %10
            sta   [p3],y
            rep   #$20
            mx    %00
            iny
            bra   :s
:done       rts

* TPixels: the row at p3 into picture line q0.
TPixels     ldy   #0
            ldx   #0
:pix        stx   PixX
            phy
            lda   TPhoto
            cmp   #2
            beq   :rgb
            jsr   TSample0              ; grey or palette: sample 0
            ldx   TPhoto
            cpx   #3
            beq   :map
            jsr   TGrey                 ; to 8 bits
            ldx   TPhoto
            bne   :g
            eor   #$00FF                ; white is zero
:g          sta   CR
            sta   CG
            sta   CB
            bra   :put
:map        jsr   MapColour
            bra   :put
:rgb        lda   #0
            jsr   TSampleC
            sta   CR
            lda   #1
            jsr   TSampleC
            sta   CG
            lda   #2
            jsr   TSampleC
            sta   CB
:put        ply
            jsr   PutRGB
            ldx   PixX
            inx
            cpx   TW
            bcc   :pix
            rts

* TSample0: sample 0 of pixel PixX as stored (1-16 bits; 16: its high byte).
TSample0    lda   PixX
            ldx   TSPP
            jsr   Mul16
            lda   MLo                   ; sample number
            ldx   TBits
            cpx   #8
            bcs   :bytes
            jsr   Mul16                 ; under 8 bits: bit position
            lda   MLo
            sta   t2
            lsr
            lsr
            lsr
            tay
            lda   [p3],y
            and   #$00FF
            sta   t1
            lda   t2                    ; shift = 8 - bits - position % 8
            and   #$0007
            clc
            adc   TBits
            eor   #$FFFF
            sec
            adc   #8
            tax
            lda   t1
:sh         cpx   #0
            beq   :m
            lsr
            dex
            bra   :sh
:m          sta   t1
            ldx   TBits
            lda   #1
:pw         asl
            dex
            bne   :pw
            dec
            and   t1
            rts
:bytes      cpx   #16
            beq   :wide
            tay
            lda   [p3],y
            and   #$00FF
            rts
:wide       asl
            tay
            lda   TLE                   ; the high byte: second in Intel order
            beq   :hi
            iny
:hi         lda   [p3],y
            and   #$00FF
            rts

* TSampleC: RGB sample A of pixel PixX (8 bits, or the high byte of 16).
TSampleC    sta   t1
            lda   PixX
            ldx   TSPP
            jsr   Mul16
            lda   MLo
            clc
            adc   t1
            ldx   TBits
            cpx   #16
            beq   :wide
            tay
            lda   [p3],y
            and   #$00FF
            rts
:wide       asl
            tay
            lda   TLE
            beq   :hi
            iny
:hi         lda   [p3],y
            and   #$00FF
            rts

* TGrey: a grey sample of TBits bits as 8 bits.
TGrey       ldx   TBits
            cpx   #8
            bcs   :done                 ; 8, or the high byte of 16
            cpx   #1
            bne   :two
            cmp   #0
            beq   :done
            lda   #255
            rts
:two        cpx   #2
            bne   :four
            sta   t1                    ; * 85
            asl
            asl
            clc
            adc   t1
            sta   t1
            asl
            asl
            asl
            asl
            clc
            adc   t1
            rts
:four       jmp   Times17
:done       rts

* TNewBuf: a buffer of TSize bytes (may cross banks) in TBuf.
TNewBuf     pha
            pha
            PushLongAt TSize
            lda   uid
            pha
            pea   $C008
            PushLong 0
            Tool  _NewHandle
            tax
            pla
            sta   THnd
            pla
            sta   THnd+2
            txa
            bcs   :err
            lda   THnd
            sta   n1
            lda   THnd+2
            sta   n1+2
            lda   [n1]
            sta   TBuf
            ldy   #2
            lda   [n1],y
            sta   TBuf+2
            clc
:err        rts

TFreeBuf    lda   THnd
            ora   THnd+2
            beq   :none
            PushLongAt THnd
            Tool  _DisposeHandle
            stz   THnd
            stz   THnd+2
:none       rts

TMasks      dw    0,1,3,7,15,31,63,127,255,511,1023,2047,4095

TLE         dw    0
TW          dw    0
TH          dw    0
TBits       dw    0
TBitsOff    adrl  0
TComp       dw    0
TPhoto      dw    0
TSPP        dw    0
TRPS        dw    0
TPlanar     dw    0
TPred       dw    0
TSOType     dw    0
TSOCnt      dw    0
TSOVal      adrl  0
TSBType     dw    0
TSBCnt      dw    0
TSBVal      adrl  0
TCmap       adrl  0
TCmapHas    dw    0
TTag        dw    0
TType       dw    0
TCnt        adrl  0
TVal        adrl  0
TRowBytes        dw    0
TSize       adrl  0
THnd        adrl  0
TBuf        adrl  0
TStrip      dw    0
TY          dw    0
TLVal       adrl  0
TLeft       adrl  0
TOutLeft    adrl  0
TBitCnt     dw    0
TAcc        adrl  0
TWidth      dw    0
TNext       dw    0
TPrev       dw    0
TFirst      dw    0
TCodeV      dw    0
LPrefix     ds    8192
LSuffix     ds    4096
LStack      ds    4096
