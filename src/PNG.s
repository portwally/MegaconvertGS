*-------------------------------------------------------------
* PNG.s - Portable Network Graphics
*
* Every colour type and bit depth, interlaced or not. Pixels that
* are transparent (alpha or tRNS) are mixed with white.
*-------------------------------------------------------------

DecodePNG   jsr   ClearPal
            stz   HaveHdr
            stz   HasKey
            stz   ZTotal
            stz   ZTotal+2
            stz   ZHnd
            stz   ZHnd+2
            stz   RawHnd
            stz   RawHnd+2
            lda   #1                    ; first pass: header, palette, IDAT sizes
            sta   PngPass
            jsr   Chunks
            bcc   :read
            rts
:read       lda   HaveHdr
            bne   :jx4
            jmp   :bad
:jx4
            lda   TrueW
            bne   :jx5
            jmp   :bad
:jx5
            cmp   #4097
            bcc   :jx6
            jmp   :big
:jx6
            lda   TrueH
            bne   :jx7
            jmp   :bad
:jx7
            cmp   #4097
            bcc   :jx8
            jmp   :big
:jx8
            lda   ZTotal
            ora   ZTotal+2
            bne   :jx9
            jmp   :bad
:jx9
            jsr   CheckType
            bcc   :typeOK
            rts
:typeOK     jsr   RawSize               ; space for the inflated rows
            lda   ZTotal                ; the compressed data, in one piece
            sta   n0
            lda   ZTotal+2
            sta   n0+2
            jsr   NewBig
            bcc   :jx10
            jmp   :err
:jx10
            lda   n1
            sta   ZHnd
            lda   n1+2
            sta   ZHnd+2
            lda   p0
            sta   ZP
            sta   q2
            lda   p0+2
            sta   ZP+2
            sta   q2+2
            lda   #2                    ; second pass: gather the IDAT data
            sta   PngPass
            jsr   Chunks
            lda   RawLen
            sta   n0
            lda   RawLen+2
            sta   n0+2
            jsr   NewBig
            bcs   :err
            lda   n1
            sta   RawHnd
            lda   n1+2
            sta   RawHnd+2
            lda   p0
            sta   RawP
            sta   q0
            lda   p0+2
            sta   RawP+2
            sta   q0+2
            lda   #0
            jsr   FillBig
            lda   ZP                    ; inflate, past the 2-byte zlib header
            clc
            adc   #2
            sta   s0
            lda   ZP+2
            adc   #0
            sta   s0+2
            lda   ZTotal
            sec
            sbc   #2
            sta   InLeft
            lda   ZTotal+2
            sbc   #0
            sta   InLeft+2
            lda   RawLen
            sta   OutLeft
            lda   RawLen+2
            sta   OutLeft+2
            jsr   Inflate
            bcs   :err
            ldx   #ZHnd
            jsr   FreeHandleAt
            jsr   NewTrue
            bcs   :err
            jsr   Rows
            ldx   #RawHnd
            jsr   FreeHandleAt
            clc
            rts
:big        lda   #errTooBig
            bra   :err
:bad        lda   #errCorrupt
:err        pha
            ldx   #ZHnd
            jsr   FreeHandleAt
            ldx   #RawHnd
            jsr   FreeHandleAt
            pla
            sec
            rts

* Chunks: walks the chunks (pass 1: reads them, pass 2: copies IDAT to q2).
Chunks      lda   #8
            sta   n0
            stz   n0+2
            jsr   StreamAt
:chunk      lda   InLeft+2              ; at least a length and a type left?
            bne   :more
            lda   InLeft
            cmp   #8
            bcs   :more
            clc                         ; no IEND: use what there is
            rts
:more       jsr   GetBE32
            lda   n1
            sta   ChunkLen
            lda   n1+2
            sta   ChunkLen+2
            jsr   GetBE16
            sta   Type1
            jsr   GetBE16
            sta   Type2
            lda   FileLen               ; where the next chunk starts
            sec
            sbc   InLeft
            tax
            lda   FileLen+2
            sbc   InLeft+2
            sta   NextPos+2
            txa
            clc
            adc   ChunkLen
            sta   NextPos
            lda   NextPos+2
            adc   ChunkLen+2
            sta   NextPos+2
            lda   NextPos
            clc
            adc   #4                    ; and its CRC
            sta   NextPos
            bcc   :pos
            inc   NextPos+2
:pos        lda   Type1
            ldx   Type2
            cmp   #$4945                ; IEND
            bne   :notEnd
            cpx   #$4E44
            bne   :notEnd
            clc
            rts
:notEnd     cmp   #$4944                ; IDAT
            bne   :notData
            cpx   #$4154
            bne   :notData
            jsr   ChunkIDAT
            bra   :next
:notData    ldy   PngPass
            cpy   #1
            bne   :next
            cmp   #$4948                ; IHDR
            bne   :notHdr
            cpx   #$4452
            bne   :notHdr
            jsr   ChunkIHDR
            bcc   :next
            rts
:notHdr     cmp   #$504C                ; PLTE
            bne   :notPal
            cpx   #$5445
            bne   :notPal
            jsr   ChunkPLTE
            bra   :next
:notPal     cmp   #$7452                ; tRNS
            bne   :next
            cpx   #$4E53
            bne   :next
            jsr   ChunkTRNS
:next       lda   NextPos
            sta   n0
            lda   NextPos+2
            sta   n0+2
            jsr   StreamAt
            bcs   :jx11
            jmp   :chunk
:jx11
            clc
            rts

ChunkIHDR   jsr   GetBE32
            lda   n1+2
            bne   :big
            lda   n1
            sta   TrueW
            jsr   GetBE32
            lda   n1+2
            bne   :big
            lda   n1
            sta   TrueH
            jsr   GetByte
            sta   Depth
            jsr   GetByte
            sta   CType
            jsr   GetByte
            jsr   GetByte
            jsr   GetByte
            sta   Interlaced
            inc   HaveHdr
            clc
            rts
:big        lda   #errTooBig
            sec
            rts

ChunkPLTE   ldx   #0
:entry      lda   ChunkLen+2
            bne   :more
            cpx   ChunkLen
            bcs   :done
:more       cpx   #768
            bcs   :done
            phx
            jsr   GetByte
            plx
            sep   #$20
            mx    %10
            sta   Pal,x
            rep   #$20
            mx    %00
            inx
            bra   :entry
:done       rts

ChunkTRNS   lda   CType
            cmp   #3
            bne   :key
            ldx   #0                    ; alpha for palette entries
:entry      txa
            lsr
            ldy   ChunkLen+2
            bne   :more
            cmp   ChunkLen
            bcs   :done
:more       cpx   #512
            bcs   :done
            phx
            jsr   GetByte
            plx
            sta   PalA,x
            inx
            inx
            bra   :entry
:done       rts
:key        jsr   GetBE16               ; the transparent grey or colour
            sta   KeyR
            sta   KeyG
            sta   KeyB
            lda   CType
            cmp   #2
            bne   :one
            jsr   GetBE16
            sta   KeyG
            jsr   GetBE16
            sta   KeyB
:one        inc   HasKey
            rts

ChunkIDAT   lda   PngPass
            cmp   #2
            beq   :copy
            lda   ZTotal
            clc
            adc   ChunkLen
            sta   ZTotal
            lda   ZTotal+2
            adc   ChunkLen+2
            sta   ZTotal+2
            rts
:copy       lda   ChunkLen
            sta   u1
            lda   ChunkLen+2
            sta   u2
:byte       lda   u1
            ora   u2
            beq   :done
            jsr   GetByte
            sep   #$20
            mx    %10
            sta   [q2]
            rep   #$20
            mx    %00
            inc   q2
            bne   :count
            inc   q2+2
:count      lda   u1
            bne   :low
            dec   u2
:low        dec   u1
            bra   :byte
:done       rts

* CheckType: the colour type and depth make sense; sets Channels, BitsPP, Bpp.
CheckType   lda   CType
            cmp   #7
            bcs   :bad
            asl
            tax
            lda   TypeChans,x
            beq   :bad
            sta   Channels
            lda   Depth                 ; 1, 2, 4, 8 or 16 bits
            cmp   #8
            bcc   :low
            beq   :ok
            cmp   #16
            bne   :bad
            lda   CType
            cmp   #3                    ; no 16-bit palettes
            beq   :bad
            bra   :ok
:low        cmp   #1
            beq   :lowOK
            cmp   #2
            beq   :lowOK
            cmp   #4
            bne   :bad
:lowOK      lda   CType                 ; below 8 bits: grey or palette only
            beq   :ok
            cmp   #3
            bne   :bad
:ok         lda   Channels
            ldx   Depth
            jsr   Mul16
            lda   ProdLo
            sta   BitsPP
            lsr
            lsr
            lsr
            bne   :bytes
            lda   #1
:bytes      sta   PBpp
            clc
            rts
:bad        lda   #errUnsupported
            sec
            rts

TypeChans   dw    1,0,3,1,2,0,4

* RawSize: RawLen = bytes of all the filtered rows.
RawSize     stz   RawLen
            stz   RawLen+2
            jsr   FirstPass
:pass       jsr   PassSize
            bcs   :skip
            lda   PassH                 ; PassH * (1 + row bytes)
            ldx   PassStride
            jsr   Mul16
            lda   RawLen
            clc
            adc   ProdLo
            sta   RawLen
            lda   RawLen+2
            adc   ProdHi
            sta   RawLen+2
:skip       jsr   NextPass
            bcc   :pass
            rts

* FirstPass / NextPass: step through the passes (seven if interlaced).
FirstPass   stz   PassNo
            lda   Interlaced
            beq   :one
            rts
:one        lda   #14                   ; the last table entry: every pixel
            sta   PassNo
            rts

NextPass    lda   PassNo
            cmp   #12                   ; after pass 7, or the single pass
            bcs   :end
            inc
            inc
            sta   PassNo
            clc
            rts
:end        sec
            rts

* PassSize: PassW, PassH, RowBytes, PassStride of pass PassNo; carry set if empty.
PassSize    ldx   PassNo
            lda   TrueW
            sec
            sbc   PassX,x
            beq   :empty
            bcc   :empty
            clc
            adc   PassDX,x
            dec
            ldy   PassSX,x
            jsr   ShiftR
            sta   PassW
            ldx   PassNo
            lda   TrueH
            sec
            sbc   PassY,x
            beq   :empty
            bcc   :empty
            clc
            adc   PassDY,x
            dec
            ldy   PassSY,x
            jsr   ShiftR
            sta   PassH
            lda   PassW                 ; row bytes = (PassW * BitsPP + 7) / 8
            ldx   BitsPP
            jsr   Mul16
            lda   ProdLo
            clc
            adc   #7
            sta   RowBytes
            lda   ProdHi
            adc   #0
            ldy   #3
:sh         lsr
            ror   RowBytes
            dey
            bne   :sh
            lda   RowBytes
            inc
            sta   PassStride
            clc
            rts
:empty      sec
            rts

* ShiftR: A >> Y.
ShiftR      cpy   #0
            beq   :done
:sh         lsr
            dey
            bne   :sh
:done       rts

* Adam7 passes (word tables); entry 7 is the whole picture at once.
PassX       dw    0,4,0,2,0,1,0,0
PassY       dw    0,0,4,0,2,0,1,0
PassDX      dw    8,8,4,4,2,2,1,1
PassDY      dw    8,8,8,4,4,2,2,1
PassSX      dw    3,3,2,2,1,1,0,0
PassSY      dw    3,3,3,2,2,1,1,0

*-------------------------------------------------------------
* Rows: unfilter each row and turn it into RGB.
*-------------------------------------------------------------
Rows        lda   RawP
            sta   q1
            lda   RawP+2
            sta   q1+2
            jsr   FirstPass
:pass       jsr   PassSize
            bcs   :skip
            stz   PassRow
:row        jsr   Unfilter
            ldx   PassNo                ; picture row = PassY + row * PassDY
            lda   PassRow
            ldy   PassSY,x
            beq   :y
:shl        asl
            dey
            bne   :shl
:y          clc
            adc   PassY,x
            jsr   TrueRowAt
            jsr   ConvRow
            lda   q1
            clc
            adc   PassStride
            sta   q1
            bcc   :nx
            inc   q1+2
:nx         inc   PassRow
            lda   PassRow
            cmp   PassH
            bcc   :row
:skip       jsr   NextPass
            bcc   :pass
            rts

* Unfilter: undoes the filter of the row at q1 (filter byte first).
* The row above is PassStride bytes before it (none on a pass's first row).
Unfilter    lda   q1                    ; p1 = q1 - Bpp: the pixel to the left
            sec
            sbc   PBpp
            sta   p1
            lda   q1+2
            sbc   #0
            sta   p1+2
            lda   q1                    ; q2 = the row above, p3 = up and left
            sec
            sbc   PassStride
            sta   q2
            lda   q1+2
            sbc   #0
            sta   q2+2
            lda   q2
            sec
            sbc   PBpp
            sta   p3
            lda   q2+2
            sbc   #0
            sta   p3+2
            lda   PassRow
            sta   NotFirst
            lda   [q1]
            and   #$00FF
            cmp   #5
            bcs   :none
            asl
            tax
            jmp   (:kinds,x)
:kinds      da    :none,FiltSub,FiltUp,FiltAvg,FiltPaeth
:none       rts

FiltSub     ldy   PBpp
            iny
:loop       cpy   RowBytes
            beq   :go
            bcs   :done
:go         lda   [q1],y
            clc
            adc   [p1],y
            sep   #$20
            mx    %10
            sta   [q1],y
            rep   #$20
            mx    %00
            iny
            bra   :loop
:done       rts

FiltUp      lda   NotFirst
            beq   :done
            ldy   #1
:loop       cpy   RowBytes
            beq   :go
            bcs   :done
:go         lda   [q1],y
            clc
            adc   [q2],y
            sep   #$20
            mx    %10
            sta   [q1],y
            rep   #$20
            mx    %00
            iny
            bra   :loop
:done       rts

FiltAvg     ldy   #1
:loop       cpy   RowBytes
            beq   :go
            bcs   :done
:go         jsr   Left
            sta   t1
            jsr   Above
            clc
            adc   t1
            lsr
            clc
            adc   [q1],y
            sep   #$20
            mx    %10
            sta   [q1],y
            rep   #$20
            mx    %00
            iny
            bra   :loop
:done       rts

FiltPaeth   ldy   #1
:loop       cpy   RowBytes
            beq   :go
            bcs   :done
:go         jsr   Left
            sta   Pa
            jsr   Above
            sta   Pb
            jsr   UpLeft
            sta   Pc
            lda   Pb                    ; pa = |b - c|
            sec
            sbc   Pc
            sta   t1
            jsr   AbsA
            sta   DA
            lda   Pa                    ; pb = |a - c|
            sec
            sbc   Pc
            sta   t2
            jsr   AbsA
            sta   DB
            lda   t1                    ; pc = |(b - c) + (a - c)|
            clc
            adc   t2
            jsr   AbsA
            sta   DCc
            lda   DA
            cmp   DB
            beq   :aOK
            bcs   :notA
:aOK        lda   DA
            cmp   DCc
            beq   :useA
            bcc   :useA
:notA       lda   DB
            cmp   DCc
            beq   :useB
            bcc   :useB
            lda   Pc
            bra   :add
:useA       lda   Pa
            bra   :add
:useB       lda   Pb
:add        clc
            adc   [q1],y
            sep   #$20
            mx    %10
            sta   [q1],y
            rep   #$20
            mx    %00
            iny
            bra   :loop
:done       rts

* Left, Above, UpLeft: neighbouring bytes of byte Y (0 outside the picture).
Left        cpy   PBpp
            beq   :none
            bcc   :none
            lda   [p1],y
            and   #$00FF
            rts
:none       lda   #0
            rts

Above       lda   NotFirst
            beq   :none
            lda   [q2],y
            and   #$00FF
            rts
:none       lda   #0
            rts

UpLeft      lda   NotFirst
            beq   :none
            cpy   PBpp
            beq   :none
            bcc   :none
            lda   [p3],y
            and   #$00FF
            rts
:none       lda   #0
            rts

AbsA        bpl   :pos
            eor   #$FFFF
            inc
:pos        rts

*-------------------------------------------------------------
* ConvRow: the unfiltered row at q1 into true colour row q0.
*-------------------------------------------------------------
ConvRow     ldx   PassNo                ; first pixel and step, in bytes
            lda   PassX,x
            asl
            clc
            adc   PassX,x
            sta   DestOff
            lda   PassDX,x
            asl
            clc
            adc   PassDX,x
            sta   DStep
            lda   PassW
            sta   u1
            ldy   #1
            lda   Depth
            cmp   #8
            bcc   :low
            jmp   ConvBytes

:low        stz   u0                    ; below 8 bits: grey or palette
:pix        lda   u0
            bne   :have
            lda   [q1],y
            and   #$00FF
            sta   u2
            iny
            lda   #8
            sta   u0
:have       lda   u2
            ldx   Depth
:shift      asl
            dex
            bne   :shift
            sta   t2
            xba
            and   #$00FF
            sta   Sample
            sta   Sample16
            lda   t2
            and   #$00FF
            sta   u2
            lda   u0
            sec
            sbc   Depth
            sta   u0
            phy
            lda   CType
            cmp   #3
            beq   :indexed
            lda   Sample                ; grey, scaled to 0-255
            beq   :grey
            lda   Depth
            asl
            tax
            lda   LowScale,x
            tax
            lda   Sample
            jsr   Mul16
            lda   ProdLo
:grey       sta   CR
            sta   CG
            sta   CB
            lda   #255
            sta   Alpha
            jsr   KeyGrey
            bra   :put
:indexed    jsr   FromPal
:put        jsr   PutPixel
            ply
            dec   u1
            bne   :pix
            rts

* 8 and 16 bits: one sample (or its high byte) per channel.
ConvBytes   lda   #255
            sta   Alpha
            jsr   NextSample
            sta   CR
            lda   Sample16
            sta   KeyTry
            lda   CType
            cmp   #3
            bne   :notIdx
            phy
            lda   CR
            sta   Sample
            jsr   FromPal
            bra   :put
:notIdx     cmp   #2                    ; types 2 and 6 are colour, 0 and 4 grey
            beq   :colour
            cmp   #6
            beq   :colour
            lda   CR                    ; grey (with alpha for type 4)
            sta   CG
            sta   CB
            lda   CType
            cmp   #4
            bne   :greyKey
            jsr   NextSample
            sta   Alpha
            phy
            bra   :put
:greyKey    phy
            lda   KeyTry
            sta   Sample16
            jsr   KeyGrey
            bra   :put
:colour     jsr   NextSample
            sta   CG
            lda   Sample16
            sta   KeyTryG
            jsr   NextSample
            sta   CB
            lda   Sample16
            sta   KeyTryB
            lda   CType
            cmp   #6
            bne   :rgbKey
            jsr   NextSample
            sta   Alpha
            phy
            bra   :put
:rgbKey     phy
            lda   HasKey
            beq   :put
            lda   KeyTry
            cmp   KeyR
            bne   :put
            lda   KeyTryG
            cmp   KeyG
            bne   :put
            lda   KeyTryB
            cmp   KeyB
            bne   :put
            stz   Alpha
:put        jsr   PutPixel
            ply
            dec   u1
            beq   :jx12
            jmp   ConvBytes
:jx12
            rts

* NextSample: the next 8 or 16-bit sample at [q1],y: high byte in A,
* the whole sample in Sample16.
NextSample  lda   [q1],y
            and   #$00FF
            sta   Sample16
            iny
            ldx   Depth
            cpx   #16
            bne   :done
            xba
            sta   Sample16
            lda   [q1],y
            and   #$00FF
            ora   Sample16
            sta   Sample16
            iny
            xba
            and   #$00FF
:done       rts

* KeyGrey: a grey sample (Sample16) equal to the tRNS grey is transparent.
KeyGrey     lda   HasKey
            beq   :done
            lda   Sample16
            cmp   KeyR
            bne   :done
            stz   Alpha
:done       rts

* FromPal: CR, CG, CB, Alpha from palette entry Sample.
FromPal     lda   Sample
            asl
            tax
            lda   PalA,x
            sta   Alpha
            lda   Sample
            asl
            clc
            adc   Sample
            tax
            lda   Pal,x
            and   #$00FF
            sta   CR
            lda   Pal+1,x
            and   #$00FF
            sta   CG
            lda   Pal+2,x
            and   #$00FF
            sta   CB
            rts

* PutPixel: CR, CG, CB mixed with white by Alpha, stored at DestOff.
PutPixel    lda   Alpha
            cmp   #255
            beq   :store
            lda   CR
            jsr   OverWhite
            sta   CR
            lda   CG
            jsr   OverWhite
            sta   CG
            lda   CB
            jsr   OverWhite
            sta   CB
:store      ldy   DestOff
            jsr   PutRGB
            lda   DestOff
            clc
            adc   DStep
            sta   DestOff
            rts

* OverWhite: (A * alpha + 255 * (255 - alpha) + 127) / 255
OverWhite   ldx   Alpha
            jsr   Mul16
            lda   #255
            sec
            sbc   Alpha
            sta   t1
            xba                         ; t1 * 255 = t1 * 256 - t1
            sec
            sbc   t1
            clc
            adc   ProdLo
            clc
            adc   #127
            sta   t1                    ; / 255 = (x + 1 + x / 256) / 256
            xba
            and   #$00FF
            sec
            adc   t1
            xba
            and   #$00FF
            rts

LowScale    dw    0,255,85,0,17

* PNG data
PngPass     dw    0
HaveHdr     dw    0
ChunkLen    adrl  0
NextPos     adrl  0
Type1       dw    0
Type2       dw    0
Depth       dw    0
CType       dw    0
Interlaced  dw    0
Channels    dw    0
BitsPP      dw    0
PBpp        dw    0
HasKey      dw    0
KeyR        dw    0
KeyG        dw    0
KeyB        dw    0
KeyTry      dw    0
KeyTryG     dw    0
KeyTryB     dw    0
ZTotal      adrl  0
ZHnd        adrl  0
ZP          adrl  0
RawLen      adrl  0
RawHnd      adrl  0
RawP        adrl  0
PassNo      dw    0
PassW       dw    0
PassH       dw    0
PassRow     dw    0
PassStride  dw    0
RowBytes    dw    0
NotFirst    dw    0
DStep       dw    0
Sample      dw    0
Sample16    dw    0
Alpha       dw    0
Pa          dw    0
Pb          dw    0
Pc          dw    0
