*-------------------------------------------------------------
* OtherPC.s - part of the Other segment: Amiga IFF, PC (GEM,
* PC Paintbrush, FliAway), Unix (Sun, SGI, PBM/PGM/PPM), IPI,
* QRT and TIFF. All of them become true colour pictures.
*-------------------------------------------------------------

*-------------------------------------------------------------
* Amiga IFF: FORM ILBM (bit planes) or PBM (DeluxePaint on the PC,
* a byte a pixel), with Extra HalfBrite, HAM and 24-bit pictures.
*-------------------------------------------------------------
LoadIFF     ldy   #0                    ; find the picture's FORM
:find       tya
            clc
            adc   #12
            bcs   :bad0
            jsr   Within
            bcs   :bad0
            lda   [fp],y
            cmp   #$4F46                ; "FO"
            bne   :next
            iny
            iny
            lda   [fp],y
            dey
            dey
            cmp   #$4D52                ; "RM"
            bne   :next
            tya
            clc
            adc   #8
            tay
            lda   [fp],y
            tax
            iny
            iny
            lda   [fp],y
            sta   t1
            tya
            sec
            sbc   #10
            tay
            stz   Chunky
            cpx   #$4C49                ; "ILBM"
            bne   :pbm
            lda   t1
            cmp   #$4D42
            beq   :found
:pbm        cpx   #$4250                ; "PBM "
            bne   :next
            lda   t1
            cmp   #$204D
            bne   :next
            inc   Chunky
            bra   :found
:next       iny
            bne   :find
:bad0       jmp   IFFBad
:found      sty   u0                    ; the form's end: 8 + its length, or the file's
            tya
            clc
            adc   #4
            jsr   SAtA
            jsr   SBE32
            lda   n1
            clc
            adc   #8
            sta   FormEnd
            lda   n1+2
            adc   #0
            sta   FormEnd+2
            lda   FormEnd
            clc
            adc   u0
            sta   FormEnd
            bcc   :fe
            inc   FormEnd+2
:fe         lda   FormEnd+2
            cmp   flen+2
            bcc   :feOK
            bne   :feFile
            lda   FormEnd
            cmp   flen
            bcc   :feOK
:feFile     lda   flen
            sta   FormEnd
            lda   flen+2
            sta   FormEnd+2
:feOK       stz   IW
            stz   IH
            stz   IPlanes
            stz   IMask
            stz   IComp
            stz   NCol
            stz   HasCamg
            stz   Camg
            stz   HasBody
            lda   u0                    ; chunks from form + 12
            clc
            adc   #12
            sta   CkPos
            stz   CkPos+2
:chunk      lda   CkPos                 ; room for a chunk header?
            clc
            adc   #8
            tax
            lda   CkPos+2
            adc   #0
            cmp   FormEnd+2
            bcc   :ckIn
            beq   :jx5
            jmp   :chunksDone
:jx5
            cpx   FormEnd
            beq   :ckIn
            bcc   :jx6
            jmp   :chunksDone
:jx6
:ckIn       lda   CkPos
            sta   n0
            lda   CkPos+2
            sta   n0+2
            jsr   SAt
            jsr   SLE16
            sta   Tag1
            jsr   SLE16
            sta   Tag2
            jsr   SBE32
            lda   n1
            sta   CkLen
            lda   n1+2
            sta   CkLen+2
            lda   Tag1
            ldx   Tag2
            cmp   #$4D42                ; BMHD
            bne   :notBM
            cpx   #$4448
            bne   :notBM
            jsr   SBE16
            sta   IW
            jsr   SBE16
            sta   IH
            jsr   SBE16
            jsr   SBE16
            jsr   SByte
            sta   IPlanes
            jsr   SByte
            sta   IMask
            jsr   SByte
            sta   IComp
            bra   :ckNext
:notBM      cmp   #$4D43                ; CMAP
            bne   :notCM
            cpx   #$5041
            bne   :notCM
            jsr   ReadCmap
            bra   :ckNext
:notCM      cmp   #$4143                ; CAMG
            bne   :notCA
            cpx   #$474D
            bne   :notCA
            jsr   SBE32
            lda   n1
            sta   Camg
            inc   HasCamg
            bra   :ckNext
:notCA      cmp   #$4F42                ; BODY
            bne   :ckNext
            cpx   #$5944
            bne   :ckNext
            jsr   SPos
            lda   n0
            sta   BodyAt
            lda   n0+2
            sta   BodyAt+2
            inc   HasBody
:ckNext     lda   CkLen                 ; next: 8 + length, rounded up to even
            clc
            adc   #1
            and   #$FFFE
            sta   t1
            lda   CkLen+2
            adc   #0
            sta   t2
            lda   CkPos
            clc
            adc   #8
            sta   CkPos
            bcc   :c1
            inc   CkPos+2
:c1         lda   CkPos
            clc
            adc   t1
            sta   CkPos
            lda   CkPos+2
            adc   t2
            sta   CkPos+2
            jmp   :chunk
:chunksDone lda   HasBody
            beq   IFFBad
            lda   IW
            beq   IFFBad
            lda   IH
            beq   IFFBad
            lda   IPlanes
            beq   IFFBad
            cmp   #33
            bcs   IFFBad
            jmp   IFFPixels
IFFBad      lda   #errNotPicture
            sec
            rts

* ReadCmap: the colour map (length CkLen / 3 entries, at most 256) into TabR/G/B.
ReadCmap    lda   CkLen+2
            bne   :many
            lda   CkLen
            ldx   #3
            jsr   Div16
            cmp   #257
            bcc   :n
:many       lda   #256
:n          sta   NCol
            ldx   #0
:e          cpx   NCol
            bcs   :done
            phx
            txa
            asl
            tax
            jsr   SByte
            sta   TabR,x
            jsr   SByte
            sta   TabG,x
            jsr   SByte
            sta   TabB,x
            plx
            inx
            bra   :e
:done       rts

IFFPixels   lda   NCol                  ; old pictures: only the high nibbles set
            beq   :flags
            asl
            sta   t3                    ; (bytes of entries)
            ldx   #0
            lda   #0
:or         ora   TabR,x
            ora   TabG,x
            ora   TabB,x
            inx
            inx
            cpx   t3
            bcc   :or
            and   #$000F
            bne   :flags
            ldx   #0
:fix        lda   TabR,x
            jsr   :dup
            sta   TabR,x
            lda   TabG,x
            jsr   :dup
            sta   TabG,x
            lda   TabB,x
            jsr   :dup
            sta   TabB,x
            inx
            inx
            cpx   #512
            bcc   :fix
            bra   :flags
:dup        sta   t1
            lsr
            lsr
            lsr
            lsr
            ora   t1
            rts
:flags      stz   Ham                   ; HAM, Extra HalfBrite, pixel shape
            stz   Ehb
            lda   IPlanes
            cmp   #24
            beq   :notHam
            lda   HasCamg
            beq   :guessHam
            lda   Camg
            and   #$0800
            beq   :notHam
            inc   Ham
            bra   :notHam
:guessHam   lda   IPlanes
            cmp   #6
            bne   :notHam
            lda   NCol
            cmp   #16
            bne   :notHam
            inc   Ham
:notHam     lda   Ham
            bne   :shape
            lda   IPlanes
            cmp   #6
            bne   :shape
            lda   HasCamg
            beq   :ehb
            lda   Camg
            and   #$0080
            beq   :shape
:ehb        inc   Ehb
:shape      stz   ttall                 ; hires without interlace: tall pixels
            lda   Camg
            and   #$8000
            beq   :rowBytes
            lda   Camg
            and   #$0004
            bne   :rowBytes
            inc   ttall
:rowBytes   lda   Chunky
            beq   :planar
            lda   IW
            inc
            and   #$FFFE
            sta   IRow
            lda   #1
            sta   IRowPl
            bra   :sized
:planar     lda   IW
            clc
            adc   #15
            lsr
            lsr
            lsr
            lsr
            asl
            sta   IRow
            lda   IPlanes
            ldx   IMask
            cpx   #1
            bne   :rp
            inc
:rp         sta   IRowPl
:sized      lda   IRow                  ; the row buffer
            ldx   IRowPl
            jsr   Mul16
            lda   MHi
            bne   :tooBig
            lda   MLo
            sta   IRowAll
            jsr   NewOut
            bcc   :buf
            rts
:tooBig     lda   #errTooBig
            sec
            rts
:buf        lda   IW
            ldx   IH
            jsr   MakeTrue
            bcc   :go
            pha
            jsr   FreeOut
            pla
            rts
:go         lda   BodyAt
            sta   n0
            lda   BodyAt+2
            sta   n0+2
            jsr   SAt
            lda   IPlanes               ; grey for colours past the map: v * 255 / (2^planes - 1)
            cmp   #8
            bcs   :rows
            tax
            lda   #1
:pow        asl
            dex
            bne   :pow
            dec
            sta   ITop
:rows       stz   RowY
:row        jsr   IFFReadRow
            lda   RowY
            jsr   TrueRow
            stz   CR
            stz   CG
            stz   CB
            ldy   #0
            ldx   #0
:pix        stx   PixX
            phy                         ; (they use Y)
            jsr   IFFValue              ; VLo / VHi
            jsr   IFFColour
            ply
            jsr   PutRGB
            ldx   PixX
            inx
            cpx   IW
            bcc   :pix
            inc   RowY
            lda   RowY
            cmp   IH
            bcc   :row
            jsr   FreeOut
            clc
            rts

* IFFReadRow: the next row (each plane, then the mask plane) into the buffer.
IFFReadRow  lda   IComp
            cmp   #1
            beq   :packed
            ldy   #0
:raw        cpy   IRowAll
            bcs   :done
            jsr   SByte
            sep   #$20
            mx    %10
            sta   [OutDP],y
            rep   #$20
            mx    %00
            iny
            bra   :raw
:packed     ldy   #0
            ldx   IRowPl
:plane      phx
            jsr   PBStart
            ldx   IRow
:b          jsr   PBGet
            sep   #$20
            mx    %10
            sta   [OutDP],y
            rep   #$20
            mx    %00
            iny
            dex
            bne   :b
            jsr   PBEnd
            plx
            dex
            bne   :plane
:done       rts

* IFFValue: the value of pixel PixX (VLo, VHi: up to 24 planes).
IFFValue    lda   Chunky
            beq   :planar
            ldy   PixX
            lda   [OutDP],y
            and   #$00FF
            sta   VLo
            stz   VHi
            rts
:planar     stz   VLo
            stz   VHi
            lda   PixX
            and   #$0007
            tax
            lda   BitMasks,x
            and   #$00FF
            sta   t3                    ; the dot's bit
            lda   PixX
            lsr
            lsr
            lsr
            tay                         ; the byte in the first plane
            lda   #1
            sta   t2                    ; this plane's bit in the value
            stz   t1                    ; (in the high word after 16 planes)
            ldx   IPlanes
:plane      lda   [OutDP],y
            and   t3
            beq   :off
            lda   t2
            tsb   VLo
            lda   t1
            tsb   VHi
:off        asl   t2
            rol   t1
            tya
            clc
            adc   IRow
            tay
            dex
            bne   :plane
            rts

* IFFColour: CR, CG, CB for the value (keeping the last colour where HAM says so).
IFFColour   lda   IPlanes
            cmp   #24
            bne   :ham
            lda   VLo                   ; 24 bits: red low, then green, blue
            and   #$00FF
            sta   CR
            lda   VLo
            xba
            and   #$00FF
            sta   CG
            lda   VHi
            and   #$00FF
            sta   CB
            rts
:ham        lda   Ham
            beq   :ehb
            lda   IPlanes               ; control = the top 2 bits, value = the rest
            sec
            sbc   #2
            tax
            lda   VLo
            ldy   #0
:split      cpx   #0
            beq   :got
            lsr
            dex
            iny
            bra   :split
:got        sta   t1                    ; control
            lda   #1
:mask       cpy   #0
            beq   :masked
            asl
            dey
            bra   :mask
:masked     dec
            and   VLo
            sta   t2                    ; value
            lda   IPlanes
            cmp   #6
            bne   :six
            lda   t2                    ; 4 data bits: * 17
            jsr   Times17
            bra   :level
:six        lda   t2                    ; 6 data bits
            asl
            asl
            sta   t3
            lda   t2
            lsr
            lsr
            lsr
            lsr
            ora   t3
:level      sta   t3
            lda   t1
            and   #$0003
            beq   :hamMap
            cmp   #1
            bne   :notB
            lda   t3
            sta   CB
            rts
:notB       cmp   #2
            bne   :g
            lda   t3
            sta   CR
            rts
:g          lda   t3
            sta   CG
            rts
:hamMap     lda   t2
            cmp   NCol
            bcs   :keep
            jmp   MapColour
:keep       rts
:ehb        lda   Ehb                   ; Extra HalfBrite: the upper 32 at half brightness
            beq   :map
            lda   VLo
            cmp   #32
            bcc   :map
            sbc   #32
            cmp   NCol
            bcs   :keep
            jsr   MapColour
            lsr   CR
            lsr   CG
            lsr   CB
            rts
:map        lda   VHi
            bne   :grey
            lda   VLo
            cmp   NCol
            bcs   :grey
            jmp   MapColour
:grey       lda   IPlanes               ; no colour for it: a grey
            cmp   #8
            bcc   :scale
            lda   VLo
            and   #$00FF
            bra   :g3
:scale      lda   VLo
            ldx   #255
            jsr   Mul16
            lda   MLo
            ldx   ITop
            jsr   Div16
:g3         sta   CR
            sta   CG
            sta   CB
            rts

* MapColour: CR, CG, CB = colour map entry A.
MapColour   asl
            tax
            lda   TabR,x
            sta   CR
            lda   TabG,x
            sta   CG
            lda   TabB,x
            sta   CB
            rts

*-------------------------------------------------------------
* GEM / Ventura Publisher .IMG: bit planes, run coded, shown as greys
*-------------------------------------------------------------
LoadGEM     lda   #0
            jsr   SAtA
            jsr   SBE16                 ; version
            cmp   #4
            bcs   :bad
            jsr   SBE16                 ; header length in words
            asl
            sta   GHead
            cmp   #16
            bcc   :bad
            jsr   Within
            bcs   :bad
            jsr   SBE16
            sta   GPlanes
            beq   :bad
            cmp   #9
            bcs   :bad
            jsr   SBE16
            sta   GPat
            beq   :bad
            cmp   #256
            bcs   :bad
            jsr   SBE16                 ; pixel size
            jsr   SBE16
            jsr   SBE16
            sta   GW
            beq   :bad
            jsr   SBE16
            sta   GH
            bne   :ok
:bad        lda   #errNotPicture
            sec
            rts
:ok         lda   GW                    ; bytes a line
            clc
            adc   #7
            lsr
            lsr
            lsr
            sta   GLine
            ldx   GPlanes
            jsr   Mul16
            lda   MLo
            jsr   NewOut
            bcc   :buf
            rts
:buf        ldx   GPlanes               ; grey for each value: 255 - v * 255 / (2^planes - 1)
            lda   #1
:pow        asl
            dex
            bne   :pow
            dec
            sta   ITop
            ldx   #0
:greys      phx
            txa
            lsr                         ; v
            ldx   #255
            jsr   Mul16
            lda   MLo
            ldx   ITop
            jsr   Div16
            eor   #$00FF                ; 255 - v * 255 / top
            plx
            sta   TabR,x
            inx
            inx
            cpx   #512
            bcc   :greys
            lda   GW
            ldx   GH
            stz   ttall
            jsr   MakeTrue
            bcc   :start
            pha
            jsr   FreeOut
            pla
            rts
:start      lda   GHead
            jsr   SAtA
            stz   RowY
:line       lda   RowY
            cmp   GH
            bcc   :more
            jmp   :done
:more       lda   SLeft
            ora   SLeft+2
            bne   :data
            jmp   :done
:data       lda   #1                    ; vertical replication: 0 0 $FF n
            sta   GRep
            lda   SLeft+2
            bne   :peek
            lda   SLeft
            cmp   #4
            bcc   :planes
:peek       lda   [s0]
            bne   :planes
            ldy   #2
            lda   [s0],y
            and   #$00FF
            cmp   #$00FF
            bne   :planes
            jsr   SByte
            jsr   SByte
            jsr   SByte
            jsr   SByte
            cmp   #0
            beq   :planes
            sta   GRep
:planes     ldx   #0                    ; each plane's line
            stz   u2
:plane      lda   u2
            ldx   GLine
            jsr   Mul16
            lda   MLo
            sta   GAt                   ; where this plane's line goes
            clc
            adc   GLine
            sta   GEnd
            ldy   GAt                   ; clear it
            lda   #0
:clr        cpy   GEnd
            bcs   :fill
            sep   #$20
            mx    %10
            sta   [OutDP],y
            rep   #$20
            mx    %00
            iny
            bra   :clr
:fill       ldy   GAt
:item       cpy   GEnd
            bcs   :planeDone
            lda   SLeft
            ora   SLeft+2
            beq   :planeDone
            jsr   SByte
            cmp   #$80
            beq   :literal
            cmp   #0
            beq   :pattern
            tax                         ; a solid run
            and   #$0080
            beq   :zeros
            lda   #$FF
:zeros      sta   t1
            txa
            and   #$007F
            tax
            beq   :item
:solid      lda   t1
            jsr   GPut
            dex
            bne   :solid
            bra   :item
:literal    jsr   SByte
            tax
            beq   :item
:lit        jsr   SByte
            jsr   GPut
            dex
            bne   :lit
            bra   :item
:pattern    jsr   SByte                 ; repeat count, then the pattern
            sta   t2
            ldx   #0
:patByte    cpx   GPat
            bcs   :patGot
            jsr   SByte
            sep   #$20
            mx    %10
            sta   GPatBuf,x
            rep   #$20
            mx    %00
            inx
            bra   :patByte
:patGot     lda   t2
            beq   :item
:patRep     ldx   #0
:patOut     lda   GPatBuf,x
            jsr   GPut
            inx
            cpx   GPat
            bcc   :patOut
            dec   t2
            bne   :patRep
            bra   :item
:planeDone  inc   u2
            lda   u2
            cmp   GPlanes
            bcs   :rep
            jmp   :plane
:rep        jsr   GOutLine              ; the line, as often as it repeats
            inc   RowY
            dec   GRep
            beq   :nextLine
            lda   RowY
            cmp   GH
            bcc   :rep
:nextLine   jmp   :line
:done       jsr   FreeOut
            clc
            rts

* GPut: a byte to the plane line (Y), dropped past its end. Keeps X.
GPut        cpy   GEnd
            bcs   :full
            sep   #$20
            mx    %10
            sta   [OutDP],y
            rep   #$20
            mx    %00
            iny
            rts
:full       iny
            rts

* GOutLine: picture line RowY from the plane lines (a set bit is ink).
GOutLine    lda   RowY
            jsr   TrueRow
            ldy   #0
            ldx   #0
:pix        stx   PixX
            phy
            txa
            and   #$0007
            tax
            lda   BitMasks,x
            and   #$00FF
            sta   t3
            lda   PixX
            lsr
            lsr
            lsr
            tay
            stz   t1                    ; value
            lda   #1
            sta   t2
            ldx   GPlanes
:pl         lda   [OutDP],y
            and   t3
            beq   :off
            lda   t2
            tsb   t1
:off        asl   t2
            tya
            clc
            adc   GLine
            tay
            dex
            bne   :pl
            lda   t1
            asl
            tax
            lda   TabR,x
            ply
            jsr   PutGrey
            ldx   PixX
            inx
            cpx   GW
            bcc   :pix
            rts

*-------------------------------------------------------------
* PC Paintbrush .PCX and .PCC
*-------------------------------------------------------------
LoadPCX     lda   #129
            jsr   NeedLen
            bcc   :ok
            rts
:ok         lda   [fp]
            and   #$00FF
            cmp   #10
            beq   :hdr
:bad        lda   #errNotPicture
            sec
            rts
:hdr        ldy   #3
            lda   [fp],y
            and   #$00FF
            sta   PBits
            ldy   #65
            lda   [fp],y
            and   #$00FF
            sta   PPlanes
            beq   :bad
            ldy   #66
            lda   [fp],y
            sta   PLine
            beq   :bad
            ldy   #8                    ; width = xmax - xmin + 1
            lda   [fp],y
            ldy   #4
            sec
            sbc   [fp],y
            inc
            sta   PW
            beq   :bad
            bmi   :bad
            ldy   #10
            lda   [fp],y
            ldy   #6
            sec
            sbc   [fp],y
            inc
            sta   PH
            beq   :bad
            bmi   :bad
            lda   PBits
            cmp   #1
            beq   :bits
            cmp   #2
            beq   :bits
            cmp   #4
            beq   :bits
            cmp   #8
            bne   :bad
:bits       jsr   PCXPalette
            lda   PLine                 ; a row: bytes a line * planes
            ldx   PPlanes
            jsr   Mul16
            lda   MHi
            bne   :bad
            lda   MLo
            sta   PRowAll
            jsr   NewOut
            bcc   :buf
            rts
:buf        lda   PW
            ldx   PH
            stz   ttall
            jsr   MakeTrue
            bcc   :start
            pha
            jsr   FreeOut
            pla
            rts
:start      lda   #128
            jsr   SAtA
            stz   PRun
            ldy   #2                    ; run coded?
            lda   [fp],y
            and   #$00FF
            sta   PRle
            stz   RowY
:row        ldy   #0
:byte       cpy   PRowAll
            bcs   :conv
            jsr   PCXByte
            sep   #$20
            mx    %10
            sta   [OutDP],y
            rep   #$20
            mx    %00
            iny
            bra   :byte
:conv       lda   RowY
            jsr   TrueRow
            ldy   #0
            ldx   #0
:pix        stx   PixX
            phy
            jsr   PCXPixel
            ply
            jsr   PutRGB
            ldx   PixX
            inx
            cpx   PW
            bcc   :pix
            inc   RowY
            lda   RowY
            cmp   PH
            bcc   :row
            jsr   FreeOut
            clc
            rts

* PCXByte: the next data byte (a byte with the top two bits set is a count).
PCXByte     lda   PRle
            bne   :rle
            jmp   SByte
:rle        lda   PRun
            beq   :next
            dec   PRun
            lda   PVal
            rts
:next       jsr   SByte
            bcs   :zero
            cmp   #$C0
            bcc   :plain
            and   #$003F
            sta   PRun
            jsr   SByte
            sta   PVal
            bra   :rle
:plain      rts
:zero       lda   #0
            rts

* PCXPalette: TabR/G/B and NCol, as GS Remap chooses them.
PCXPalette  ldx   #0                    ; the header's 16 colours
            ldy   #16
:hdr        lda   [fp],y
            and   #$00FF
            sta   TabR,x
            iny
            lda   [fp],y
            and   #$00FF
            sta   TabG,x
            iny
            lda   [fp],y
            and   #$00FF
            sta   TabB,x
            iny
            inx
            inx
            cpx   #32
            bcc   :hdr
            lda   #16
            sta   NCol
            lda   PBits
            cmp   #8
            bne   :notByte
            lda   PPlanes
            cmp   #1
            bne   :notByte
            lda   flen+2                ; 256 colours at the end, after a 12
            bne   :end256
            lda   flen
            cmp   #769
            bcc   :greys
:end256     lda   flen
            sec
            sbc   #769
            sta   n0
            lda   flen+2
            sbc   #0
            sta   n0+2
            jsr   SAt
            jsr   SByte
            cmp   #12
            bne   :greys
            ldx   #0
:e          jsr   SByte
            sta   TabR,x
            jsr   SByte
            sta   TabG,x
            jsr   SByte
            sta   TabB,x
            inx
            inx
            cpx   #512
            bcc   :e
            bra   :n256
:greys      ldx   #0
:g          txa
            lsr
            sta   TabR,x
            sta   TabG,x
            sta   TabB,x
            inx
            inx
            cpx   #512
            bcc   :g
:n256       lda   #256
            sta   NCol
            rts
:notByte    lda   PBits                 ; colours = 2 ^ (bits * planes)
            ldx   PPlanes
            jsr   Mul16
            lda   MLo
            cmp   #1
            bne   :more
            lda   TabR                  ; two colours: the header's, or black and white
            cmp   TabR+2
            bne   :done
            lda   TabG
            cmp   TabG+2
            bne   :done
            lda   TabB
            cmp   TabB+2
            bne   :done
            stz   TabR
            stz   TabG
            stz   TabB
            lda   #255
            sta   TabR+2
            sta   TabG+2
            sta   TabB+2
            lda   #2
            sta   NCol
:done       rts
:more       tax                         ; EGA colours: version 3, or a header of one colour
            ldy   #1
            lda   [fp],y
            and   #$00FF
            cmp   #3
            beq   :ega
            cpx   #4                    ; how many header colours to compare (at most 16)
            bcs   :all16
            lda   #1
:pw         asl
            dex
            bne   :pw
            asl
            bra   :cnt
:all16      lda   #32
:cnt        sta   t1
            ldx   #2
:same       cpx   t1
            bcs   :ega
            lda   TabR,x
            cmp   TabR
            bne   :done
            lda   TabG,x
            cmp   TabG
            bne   :done
            lda   TabB,x
            cmp   TabB
            bne   :done
            inx
            inx
            bra   :same
:ega        ldx   #0
            ldy   #0
:egaC       lda   EGA,y
            and   #$00FF
            sta   TabR,x
            lda   EGA+1,y
            and   #$00FF
            sta   TabG,x
            lda   EGA+2,y
            and   #$00FF
            sta   TabB,x
            iny
            iny
            iny
            inx
            inx
            cpx   #32
            bcc   :egaC
            rts

* PCXPixel: CR, CG, CB of pixel PixX from the row buffer.
PCXPixel    lda   PBits
            cmp   #8
            bne   :planes
            lda   PPlanes
            cmp   #3
            bcc   :planes
            ldy   PixX                  ; 8 bits, 3 planes or more: red, green, blue
            lda   [OutDP],y
            and   #$00FF
            sta   CR
            tya
            clc
            adc   PLine
            tay
            lda   [OutDP],y
            and   #$00FF
            sta   CG
            tya
            clc
            adc   PLine
            tay
            lda   [OutDP],y
            and   #$00FF
            sta   CB
            rts
:planes     lda   PixX                  ; bit position: x * bits
            ldx   PBits
            jsr   Mul16
            lda   MLo
            sta   t2
            lsr
            lsr
            lsr
            sta   u3                    ; byte in the plane
            lda   t2                    ; shift = 8 - bits - (x * bits) % 8
            and   #$0007
            clc
            adc   PBits
            eor   #$FFFF
            sec
            adc   #8
            sta   t3
            ldx   PBits                 ; mask = 2^bits - 1
            lda   #1
:m          asl
            dex
            bne   :m
            dec
            sta   u2
            stz   VLo
            stz   t2                    ; plane shift
            ldx   #0
:plane      phx
            ldy   u3
            lda   [OutDP],y
            and   #$00FF
            ldx   t3
:sh         cpx   #0
            beq   :shifted
            lsr
            dex
            bra   :sh
:shifted    and   u2
            ldx   t2
:up         cpx   #0
            beq   :or
            asl
            dex
            bra   :up
:or         tsb   VLo
            lda   t2
            clc
            adc   PBits
            sta   t2
            lda   u3
            clc
            adc   PLine
            sta   u3
            plx
            inx
            cpx   PPlanes
            bcc   :plane
            lda   VLo
            cmp   NCol
            bcs   :black
            jmp   MapColour
:black      stz   CR
            stz   CG
            stz   CB
            rts

EGA         db    0,0,0,0,0,170,0,170,0,0,170,170,170,0,0,170,0,170,170,85,0,170,170,170
            db    85,85,85,85,85,255,85,255,85,85,255,255,255,85,85,255,85,255,255,255,85,255,255,255

*-------------------------------------------------------------
* FliAway frame: 256 colour words, a packed size (0: not packed), then
* 320 x 200 bytes (PackBytes)
*-------------------------------------------------------------
LoadFli     lda   #515
            jsr   NeedLen
            bcc   :ok
            rts
:ok         lda   #0                    ; the colours: $0RGB, extra low bits in 14, 13, 12
            jsr   SAtA
            ldx   #0
:col        jsr   SLE16
            sta   t1
            xba                         ; red: bits 8-11 and 14
            and   #$000F
            sta   t2
            lda   t1
            xba
            lsr
            lsr
            lsr
            lsr
            lsr
            lsr
            jsr   :five
            sta   TabR,x
            lda   t1
            lsr
            lsr
            lsr
            lsr
            and   #$000F
            sta   t2
            lda   t1
            xba
            lsr
            lsr
            lsr
            lsr
            lsr
            jsr   :five
            sta   TabG,x
            lda   t1
            and   #$000F
            sta   t2
            lda   t1
            xba
            lsr
            lsr
            lsr
            lsr
            jsr   :five
            sta   TabB,x
            inx
            inx
            cpx   #512
            bcc   :col
            lda   #64000
            jsr   NewOut
            bcc   :buf
            rts
:buf        ldy   #512
            lda   [fp],y
            beq   :raw
            jsr   FliUnpack
            bcc   :pic
:bad        jsr   FreeOut
            lda   #errNotPicture
            sec
            rts
:raw        lda   #514+64000            ; 64000 bytes as they are
            jsr   Within
            bcs   :bad
            lda   #514
            jsr   SAtA
            ldy   #0
:copy       jsr   SByte
            sep   #$20
            mx    %10
            sta   [OutDP],y
            rep   #$20
            mx    %00
            iny
            cpy   #64000
            bcc   :copy
:pic        lda   #320
            ldx   #200
            stz   ttall
            jsr   MakeTrue
            bcc   :rows
            pha
            jsr   FreeOut
            pla
            rts
:rows       stz   RowY
            stz   u0                    ; source
:row        lda   RowY
            jsr   TrueRow
            ldy   #0
            ldx   #320
:pix        phx
            phy
            ldy   u0
            lda   [OutDP],y
            and   #$00FF
            jsr   MapColour
            inc   u0
            ply
            jsr   PutRGB
            plx
            dex
            bne   :pix
            inc   RowY
            lda   RowY
            cmp   #200
            bcc   :row
            jsr   FreeOut
            clc
            rts
:five       and   #$0001                ; (t2 << 1 | low bit) as 5 bits, then to 8
            sta   t3
            lda   t2
            asl
            ora   t3
            sta   t3
            asl
            asl
            asl
            sta   t2
            lda   t3
            lsr
            lsr
            ora   t2
            rts

* FliUnpack: PackBytes data from 514 on into the 64000-byte buffer.
FliUnpack   lda   fp
            clc
            adc   #514
            sta   FliSrc
            lda   fp+2
            adc   #0
            sta   FliSrc+2
            lda   flen
            sec
            sbc   #514
            sta   FliLeft
            lda   flen+2
            sbc   #0
            sta   FliLeft+2
            lda   OutP
            sta   FliDst
            lda   OutP+2
            sta   FliDst+2
            lda   #64000
            sta   FliSize
:piece      lda   FliSize
            beq   :done
            lda   FliLeft+2
            bne   :most
            lda   FliLeft
            beq   :short
            cmp   #32767
            bcc   :len
:most       lda   #32767
:len        sta   t1
            pha                         ; result: bytes used
            PushLongAt FliSrc
            lda   t1
            pha
            PushLong FliDst
            PushLong FliSize
            Tool  _UnPackBytes
            pla
            beq   :short                ; nothing used
            sta   t1
            lda   FliSrc
            clc
            adc   t1
            sta   FliSrc
            bcc   :s
            inc   FliSrc+2
:s          lda   FliLeft
            sec
            sbc   t1
            sta   FliLeft
            bcs   :piece
            dec   FliLeft+2
            bra   :piece
:done       clc
            rts
:short      sec
            rts

*-------------------------------------------------------------
* Sun Rasterfile: 1, 8, 24 or 32 bits, maybe run coded
*-------------------------------------------------------------
LoadSun     lda   #4
            jsr   SAtA
            jsr   SBE32                 ; width
            lda   n1+2
            bne   :bad
            lda   n1
            sta   SW
            beq   :bad
            jsr   SBE32
            lda   n1+2
            bne   :bad
            lda   n1
            sta   SH
            beq   :bad
            jsr   SBE32
            lda   n1
            sta   SDepth
            cmp   #1
            beq   :d
            cmp   #8
            beq   :d
            cmp   #24
            beq   :d
            cmp   #32
            beq   :d
:bad        lda   #errNotPicture
            sec
            rts
:d          jsr   SBE32                 ; length
            jsr   SBE32
            lda   n1
            sta   SType
            jsr   SBE32
            lda   n1
            sta   SMapType
            jsr   SBE32
            lda   n1+2
            bne   :bad
            lda   n1
            sta   SMapLen
            clc
            adc   #32
            bcs   :bad
            jsr   Within
            bcs   :bad
            stz   NCol                  ; the colour map: all reds, all greens, all blues
            lda   SMapType
            cmp   #1
            bne   :noMap
            lda   SMapLen
            ldx   #3
            jsr   Div16
            cmp   #257
            bcc   :n
            lda   #256
:n          sta   NCol
            ldx   #0                    ; entry * 2
            ldy   #32                   ; its red
:mr         txa
            lsr
            cmp   NCol
            bcs   :mapDone
            lda   [fp],y
            and   #$00FF
            sta   TabR,x
            tya
            clc
            adc   NCol
            tay
            lda   [fp],y
            and   #$00FF
            sta   TabG,x
            tya
            clc
            adc   NCol
            tay
            lda   [fp],y
            and   #$00FF
            sta   TabB,x
            tya
            sec
            sbc   NCol
            sec
            sbc   NCol
            tay
            iny
            inx
            inx
            bra   :mr
:mapDone
:noMap      lda   SW                    ; bytes a line: (width * depth + 15) / 16 * 2
            ldx   SDepth
            jsr   Mul16
            lda   MLo
            clc
            adc   #15
            sta   t1
            lda   MHi
            adc   #0
            ldx   #4
:sh         lsr
            ror   t1
            dex
            bne   :sh
            lda   t1
            asl
            sta   SLine
            jsr   NewOut
            bcc   :buf
            rts
:buf        lda   SW
            ldx   SH
            stz   ttall
            jsr   MakeTrue
            bcc   :start
            pha
            jsr   FreeOut
            pla
            rts
:start      lda   SMapLen
            clc
            adc   #32
            jsr   SAtA
            stz   PRun
            stz   RowY
:row        ldy   #0
:byte       cpy   SLine
            bcs   :conv
            jsr   SunByte
            sep   #$20
            mx    %10
            sta   [OutDP],y
            rep   #$20
            mx    %00
            iny
            bra   :byte
:conv       lda   RowY
            jsr   TrueRow
            ldy   #0
            ldx   #0
:pix        stx   PixX
            phy
            jsr   SunPixel
            ply
            jsr   PutRGB
            ldx   PixX
            inx
            cpx   SW
            bcc   :pix
            inc   RowY
            lda   RowY
            cmp   SH
            bcc   :row
            jsr   FreeOut
            clc
            rts

* SunByte: the next data byte ($80 n v: v n+1 times; $80 0: $80).
SunByte     lda   SType
            cmp   #2
            beq   :rle
            jmp   SByte
:rle        lda   PRun
            beq   :next
            dec   PRun
            lda   PVal
            rts
:next       jsr   SByte
            cmp   #$80
            bne   :done
            jsr   SByte
            cmp   #0
            bne   :run
            lda   #$80
:done       rts
:run        sta   PRun
            jsr   SByte
            sta   PVal
            rts

* SunPixel: CR, CG, CB of pixel PixX.
SunPixel    lda   SDepth
            cmp   #1
            bne   :d8
            lda   PixX
            lsr
            lsr
            lsr
            tay
            lda   [OutDP],y
            sta   t1
            lda   PixX
            and   #$0007
            tax
            lda   BitMasks,x
            and   t1
            and   #$00FF
            beq   :clear
            lda   NCol                  ; set: map entry 1, or black
            cmp   #2
            bcc   :black
            lda   #1
            jmp   MapColour
:black      stz   CR
            stz   CG
            stz   CB
            rts
:clear      lda   NCol
            cmp   #2
            bcc   :white
            lda   #0
            jmp   MapColour
:white      lda   #255
            sta   CR
            sta   CG
            sta   CB
            rts
:d8         cmp   #8
            bne   :wide
            ldy   PixX
            lda   [OutDP],y
            and   #$00FF
            cmp   NCol
            bcs   :grey
            jmp   MapColour
:grey       sta   CR
            sta   CG
            sta   CB
            rts
:wide       lda   PixX                  ; 24 or 32 bits (32: a pad byte first)
            asl
            clc
            adc   PixX
            ldx   SDepth
            cpx   #32
            bne   :at
            lda   PixX
            asl
            asl
            inc
:at         tay
            lda   SType
            cmp   #3                    ; RGB order, or BGR
            beq   :rgb
            lda   [OutDP],y
            and   #$00FF
            sta   CB
            iny
            lda   [OutDP],y
            and   #$00FF
            sta   CG
            iny
            lda   [OutDP],y
            and   #$00FF
            sta   CR
            rts
:rgb        lda   [OutDP],y
            and   #$00FF
            sta   CR
            iny
            lda   [OutDP],y
            and   #$00FF
            sta   CG
            iny
            lda   [OutDP],y
            and   #$00FF
            sta   CB
            rts

*-------------------------------------------------------------
* SGI Iris: grey or RGB, 1 or 2 bytes a sample, bottom line first,
* plain or run coded (with a table of where each line starts)
*-------------------------------------------------------------
LoadSGI     lda   #513
            jsr   NeedLen
            bcc   :ok
            rts
:ok         lda   #0
            jsr   SAtA
            jsr   SBE16
            cmp   #474
            bne   :bad
            jsr   SByte
            sta   GRle
            jsr   SByte
            sta   GBytes
            beq   :bad
            cmp   #3
            bcs   :bad
            jsr   SBE16                 ; dimensions
            sta   t1
            jsr   SBE16
            sta   GW
            beq   :bad
            cmp   #4097
            bcs   :bad
            jsr   SBE16
            sta   GH
            beq   :bad
            jsr   SBE16
            sta   GChan
            lda   t1
            cmp   #3
            bcs   :ch
            lda   #1
            sta   GChan
:ch         lda   GChan
            bne   :good
:bad        lda   #errNotPicture
            sec
            rts
:good       lda   GW
            ldx   GH
            stz   ttall
            jsr   MakeTrue
            bcc   :rows
            rts
:rows       stz   RowY                  ; file line
:row        stz   u2                    ; channel
            ldx   #RowR
            jsr   SGIRow
            lda   GChan
            cmp   #3
            bcc   :grey
            inc   u2
            ldx   #RowG
            jsr   SGIRow
            inc   u2
            ldx   #RowB
            jsr   SGIRow
            bra   :out
:grey       ldx   #0                    ; one channel: grey
:copy       lda   RowR,x
            sta   RowG,x
            sta   RowB,x
            inx
            inx
            cpx   #4096
            bcc   :copy
:out        lda   GH                    ; picture line = height - 1 - file line
            sec
            sbc   RowY
            dec
            jsr   TrueRow
            jsr   OutRGBRows
            inc   RowY
            lda   RowY
            cmp   GH
            bcc   :row
            clc
            rts

* OutRGBRows: picture line q0 from RowR, RowG, RowB (GW pixels).
OutRGBRows  ldy   #0
            ldx   #0
:pix        lda   RowR,x
            and   #$00FF
            sta   CR
            lda   RowG,x
            and   #$00FF
            sta   CG
            lda   RowB,x
            and   #$00FF
            sta   CB
            jsr   PutRGB
            inx
            cpx   GW
            bcc   :pix
            rts

* SGIRow: file line RowY of channel u2 into the 4096-byte row at X.
SGIRow      stx   t3
            ldy   #0                    ; clear it
            lda   #0
:clr        sta   (t3),y
            iny
            iny
            cpy   #4096
            bcc   :clr
            lda   u2                    ; line number in the file: channel * height + y
            ldx   GH
            jsr   Mul16
            lda   MLo
            clc
            adc   RowY
            sta   u3
            lda   GRle
            bne   :rle
            lda   u3                    ; plain: 512 + line * width * bytes
            ldx   GW
            jsr   Mul16
            lda   MLo
            sta   n0
            lda   MHi
            sta   n0+2
            lda   GBytes
            cmp   #2
            bne   :one
            asl   n0
            rol   n0+2
:one        lda   n0
            clc
            adc   #512
            sta   n0
            bcc   :at
            inc   n0+2
:at         jsr   SAt
            ldy   #0
:plain      jsr   SByte
            sep   #$20
            mx    %10
            sta   (t3),y
            rep   #$20
            mx    %00
            lda   GBytes
            cmp   #2
            bne   :p1
            jsr   SByte
:p1         iny
            cpy   GW
            bcc   :plain
            rts
:rle        lda   u3                    ; where the line starts: the table at 512
            asl
            asl
            clc
            adc   #512
            sta   n0
            stz   n0+2
            bcc   :tab
            inc   n0+2
:tab        jsr   SAt
            jsr   SBE32
            lda   n1
            sta   n0
            lda   n1+2
            sta   n0+2
            jsr   SAt
            ldy   #0                    ; x
:ctl        cpy   GW
            bcs   :done
            lda   SLeft
            ora   SLeft+2
            beq   :done
            lda   GBytes                ; the control (low byte of a 2-byte one)
            cmp   #2
            bne   :c1
            jsr   SByte
:c1         jsr   SByte
            sta   t1
            and   #$007F
            beq   :done
            tax
            lda   t1
            and   #$0080
            beq   :repeat
:lit        jsr   SGISample
            jsr   :put
            dex
            bne   :lit
            bra   :ctl
:repeat     jsr   SGISample
            sta   t1
:rep        lda   t1
            jsr   :put
            dex
            bne   :rep
            bra   :ctl
:done       rts
:put        cpy   GW
            bcs   :past
            sep   #$20
            mx    %10
            sta   (t3),y
            rep   #$20
            mx    %00
:past       iny
            rts

* SGISample: a sample (its high byte for 2-byte samples). Keeps X and Y.
SGISample   jsr   SByte
            pha
            lda   GBytes
            cmp   #2
            bne   :one
            jsr   SByte
:one        pla
            rts

*-------------------------------------------------------------
* Portable bitmap, greymap and pixmap: P1-P3 as text, P4-P6 binary
*-------------------------------------------------------------
LoadPNM     ldy   #1
            lda   [fp],y
            and   #$00FF
            sec
            sbc   #'0'
            sta   NKind
            lda   #2
            jsr   SAtA
            jsr   PNMNumber
            bcs   :bad
            sta   GW
            beq   :bad
            jsr   PNMNumber
            bcs   :bad
            sta   GH
            beq   :bad
            lda   #1                    ; the largest value
            ldx   NKind
            cpx   #1
            beq   :top
            cpx   #4
            beq   :top
            jsr   PNMNumber
            bcc   :got
            lda   #255
:got        cmp   #0
            bne   :top
            lda   #1
:top        sta   NTop
            lda   GW
            ldx   GH
            stz   ttall
            jsr   MakeTrue
            bcc   :scale
            rts
:bad        lda   #errNotPicture
            sec
            rts
:scale      lda   NTop                  ; samples up to 255: a table
            cmp   #256
            bcs   :rows
            ldx   #0
:tab        phx
            txa
            lsr
            jsr   PNMScale
            plx
            sta   TabR,x
            inx
            inx
            cpx   #512
            bcc   :tab
:rows       lda   NKind
            cmp   #4
            bcc   :text
            jsr   SByte                 ; the one space after the header
:text       stz   RowY
:row        lda   RowY
            jsr   TrueRow
            lda   NKind
            cmp   #4
            bne   :pixels
            jsr   PNMBits               ; P4: a row of bits
            bra   :next
:pixels     ldy   #0
            ldx   #0
:pix        stx   PixX
            phy
            jsr   PNMPixel
            ply
            jsr   PutRGB
            ldx   PixX
            inx
            cpx   GW
            bcc   :pix
:next       inc   RowY
            lda   RowY
            cmp   GH
            bcc   :row
            clc
            rts

* PNMNumber: the next decimal number (skipping spaces and # comments).
*   out: carry clear, A = number; carry set if there is none
PNMNumber   jsr   SByte
            bcs   :none
            cmp   #'#'
            bne   :space
:comment    jsr   SByte
            bcs   :none
            cmp   #$0A
            bne   :comment
            bra   PNMNumber
:space      cmp   #$21
            bcc   PNMNumber
            stz   t1
            stz   t2                    ; any digits?
:digit      cmp   #'0'
            bcc   :end
            cmp   #'9'+1
            bcs   :end
            sbc   #'0'-1                ; (carry clear)
            pha
            lda   t1                    ; t1 = t1 * 10 + digit
            asl
            sta   t1
            asl
            asl
            clc
            adc   t1
            sta   t1
            pla
            clc
            adc   t1
            sta   t1
            inc   t2
            jsr   SByte
            bcc   :digit
:end        jsr   UnByte                ; that wasn't a digit
            lda   t2
            beq   :none
            lda   t1
            clc
            rts
:none       sec
            rts

* UnByte: steps back over the byte just read.
UnByte      lda   s0
            bne   :lo
            dec   s0+2
:lo         dec   s0
            inc   SLeft
            bne   :ok
            inc   SLeft+2
:ok         rts

* PNMScale: A * 255 / NTop, at most 255.
PNMScale    ldx   #255
            jsr   Mul16
            lda   MLo
            sta   n0
            lda   MHi
            sta   n0+2
            lda   NTop
            jsr   Div32
            cmp   #256
            bcc   :ok
            lda   #255
:ok         rts

* PNMSample: the next sample as 0-255.
PNMSample   lda   NKind
            cmp   #4
            bcs   :binary
            jsr   PNMNumber
            bcc   :scale
            lda   #0
            bra   :scale
:binary     lda   NTop
            cmp   #256
            bcc   :byte
            jsr   SBE16
            bra   :scale
:byte       jsr   SByte
            asl
            tax
            lda   TabR,x
            rts
:scale      ldx   NTop
            cpx   #256
            bcs   :calc
            cmp   #256
            bcs   :calc
            asl
            tax
            lda   TabR,x
            rts
:calc       jmp   PNMScale

* PNMPixel: CR, CG, CB for P1, P2, P3, P5, P6.
PNMPixel    lda   NKind
            cmp   #1
            bne   :notP1
:find       jsr   SByte                 ; P1: the next 0 or 1 (they may run together)
            bcs   :white
            cmp   #'0'
            beq   :white
            cmp   #'1'
            bne   :find
            lda   #0
            bra   :grey
:white      lda   #255
:grey       sta   CR
            sta   CG
            sta   CB
            rts
:notP1      cmp   #2
            beq   :g
            cmp   #5
            beq   :g
            jsr   PNMSample
            sta   CR
            jsr   PNMSample
            sta   CG
            jsr   PNMSample
            sta   CB
            rts
:g          jsr   PNMSample
            bra   :grey

* PNMBits: a P4 row of bits (set: black).
PNMBits     ldy   #0
            ldx   #0
:byte       phy
            jsr   SByte
            ply
            sta   t1
            lda   #8
            sta   t2
:bit        lda   t1
            and   #$0080
            beq   :w
            lda   #0
            bra   :put
:w          lda   #255
:put        cpx   GW
            bcs   :skip
            jsr   PutGrey
:skip       asl   t1
            inx
            dec   t2
            bne   :bit
            cpx   GW
            bcc   :byte
            rts

*-------------------------------------------------------------
* IPI: three square files of 8-bit samples (.R, .G, .B), 256 or 512
* a side. fp is the red file, ipg and ipb the others (Formats.s
* has read them and checked their sizes).
*-------------------------------------------------------------
LoadIPI     lda   #256
            ldx   flen+2
            cpx   #4                    ; 262144 bytes or more: 512
            bcc   :side
            lda   #512
:side       sta   GW
            tax
            stz   ttall
            jsr   MakeTrue
            bcc   :rows
            rts
:rows       lda   fp
            sta   q1
            lda   fp+2
            sta   q1+2
            lda   ipg
            sta   q2
            lda   ipg+2
            sta   q2+2
            lda   ipb
            sta   p3
            lda   ipb+2
            sta   p3+2
            stz   RowY
:row        lda   RowY
            jsr   TrueRow
            ldy   #0
            ldx   #0
:pix        phy
            txy
            lda   [q1],y
            and   #$00FF
            sta   CR
            lda   [q2],y
            and   #$00FF
            sta   CG
            lda   [p3],y
            and   #$00FF
            sta   CB
            ply
            jsr   PutRGB
            inx
            cpx   GW
            bcc   :pix
            lda   q1                    ; next lines
            clc
            adc   GW
            sta   q1
            bcc   :g
            inc   q1+2
:g          lda   q2
            clc
            adc   GW
            sta   q2
            bcc   :b
            inc   q2+2
:b          lda   p3
            clc
            adc   GW
            sta   p3
            bcc   :n
            inc   p3+2
:n          inc   RowY
            lda   RowY
            cmp   GW
            bcc   :row
            clc
            rts

*-------------------------------------------------------------
* QRT raw image: width, height, then for each line its number and
* a row of reds, a row of greens, a row of blues
*-------------------------------------------------------------
LoadQRT     lda   #6
            jsr   NeedLen
            bcc   :ok
            rts
:ok         lda   #0
            jsr   SAtA
            jsr   SLE16
            sta   GW
            beq   :bad
            cmp   #4097
            bcs   :big
            jsr   SLE16
            sta   GH
            beq   :bad
            cmp   #4097
            bcs   :big
            lda   GW
            ldx   GH
            stz   ttall
            jsr   MakeTrue
            bcc   :lines
            rts
:bad        lda   #errNotPicture
            sec
            rts
:big        lda   #errTooBig
            sec
            rts
:lines      lda   GW                    ; a record: 2 + 3 * width bytes
            asl
            clc
            adc   GW
            clc
            adc   #2
            sta   u1
:line       lda   SLeft+2
            bne   :read
            lda   SLeft
            cmp   u1
            bcc   :done
:read       jsr   SLE16
            sta   RowY
            ldx   #RowR
            jsr   :row
            ldx   #RowG
            jsr   :row
            ldx   #RowB
            jsr   :row
            lda   RowY
            cmp   GH
            bcs   :line
            jsr   TrueRow
            jsr   OutRGBRows
            bra   :line
:done       clc
            rts
:row        stx   t3
            ldy   #0
:b          jsr   SByte
            sep   #$20
            mx    %10
            sta   (t3),y
            rep   #$20
            mx    %00
            iny
            cpy   GW
            bcc   :b
            rts

*-------------------------------------------------------------
* Data
*-------------------------------------------------------------
Chunky      dw    0
FormEnd     adrl  0
CkPos       adrl  0
CkLen       adrl  0
Tag1        dw    0
Tag2        dw    0
IW          dw    0
IH          dw    0
IPlanes     dw    0
IMask       dw    0
IComp       dw    0
NCol        dw    0
HasCamg     dw    0
Camg        dw    0
HasBody     dw    0
BodyAt      adrl  0
Ham         dw    0
Ehb         dw    0
IRow        dw    0
IRowPl      dw    0
IRowAll     dw    0
ITop        dw    0
PixX        dw    0
VLo         dw    0
VHi         dw    0
GHead       dw    0
GPlanes     dw    0
GPat        dw    0
GW          dw    0
GH          dw    0
GLine       dw    0
GRep        dw    0
GAt         dw    0
GEnd        dw    0
GRle        dw    0
GBytes      dw    0
GChan       dw    0
PBits       dw    0
PPlanes     dw    0
PLine       dw    0
PW          dw    0
PH          dw    0
PRowAll     dw    0
PRle        dw    0
PRun        dw    0
PVal        dw    0
FliSrc      adrl  0
FliLeft     adrl  0
FliDst      adrl  0
FliSize     dw    0
SW          dw    0
SH          dw    0
SDepth      dw    0
SType       dw    0
SMapType    dw    0
SMapLen     dw    0
SLine       dw    0
NKind       dw    0
NTop        dw    0
GPatBuf     ds    256
RowR        ds    4098
RowG        ds    4098
RowB        ds    4098

