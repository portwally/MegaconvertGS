*-------------------------------------------------------------
* TiffOpt.s - TIFF saved through SuperConvert's TIFF Save Options dialog
* (a segment of its own; docs/superconvert-file.md 4.9 "TIFF"): the screen
* image as a palette image (Class P), the true colour image as an RGB
* image (Class R), or both; Intel or Motorola byte order; the palette's
* bits raised to 1, 4 or 8 for compatibility; the resolution's unit; a
* description. Unlike the original, the directory is always sorted with
* its tags in the file's byte order, and each image is one strip.
* (Saves without the dialog use Save.s, as GS Remap's.)
*
* In: scrp, cstr, cscb, cpal, pw, ph, p640 (the picture to save, as the
* save dialogs made it); tp, tstride, rw, rh and dhave bit 1 (the true
* colour image); dname (the loaded file's name); uid.
* Out: outp, outl, otype, oaux, ohnd (as Save.s's formats).
*-------------------------------------------------------------
            rel
            mx    %00
            use   macros/Macs.s
            put   Equates.s

rp          =     $00                   ; (p0: a row's pointer)
wq          =     $08                   ; (p2: the output's patch pointer)

* TiffSave: A = 1: the dialog, then the file; A = 0 (a save without the
* dialogs): the file only if TiffSet gave its answers, else A = $FFFF
* (the usual TIFF, Save.s's).
*   out: carry set, A = errCancel or an error
TiffSave    ent
            phb
            phk
            plb
            stz   outl
            stz   outl+2
            stz   ohnd
            stz   ohnd+2
            cmp   #0
            bne   :dlg
            lda   TPreset
            bne   :pre
            lda   #$FFFF
            clc
            plb
            rtl
:pre        stz   TPreset
            bra   :go
:dlg        jsr   Dialog
            bcs   :out
:go
            jsr   Colours               ; the screen image's colours
            jsr   Room                  ; the output
            bcs   :out
            lda   TMoto                 ; the header: "II" or "MM", 42, the
            beq   :ii                   ; first directory at 8
            lda   #$4D4D
            bra   :order
:ii         lda   #$4949
:order      jsr   PutW0
            lda   #42
            jsr   TW
            lda   #8
            stz   VHi
            jsr   TL
            stz   NextAt                ; (no directory before)
            stz   NextAt+2
            lda   TWhich                ; the true colour image first (RGB)
            beq   :pal
            lda   #0
            jsr   ImgRGB
            lda   TWhich
            cmp   #1
            beq   :done
            lda   #1                    ; (then the screen's: "both")
            bra   :p2
:pal        lda   #0
:p2         jsr   ImgPal
:done       lda   #$0006
            sta   otype
            stz   oaux
            stz   oaux+2
            clc
:out        plb
            rtl

* TiffSet: for tests: the dialog's answers for the next TIFF: A the
* image (0 screen, 1 true colour, 2 both), X 1 Motorola, Y bit 0 more
* compatible, bit 1 sizing left to the receiver; the description the C
* string at dctl.
TiffSet     ent
            phb
            phk
            plb
            sta   TWhich
            stx   TMoto
            tya
            and   #1
            sta   TCompat
            tya
            and   #2
            lsr
            eor   #1
            inc
            sta   TResUnit
            ldy   #0
:c          lda   [dctl],y
            and   #$00FF
            beq   :e
            cpy   #80
            bcs   :e
            sep   #$20
            mx    %10
            sta   TDesc+1,y
            rep   #$20
            mx    %00
            iny
            bra   :c
:e          tya
            sep   #$20
            mx    %10
            sta   TDesc
            rep   #$20
            mx    %00
            lda   #1
            sta   TPreset
            plb
            rtl

*-------------------------------------------------------------
* The dialog
*-------------------------------------------------------------

* Dialog: the original's (26:195C): which image, the byte order, more
* compatible palettes, the resolution's unit, a description.
*   out: carry set, A = errCancel, for Cancel
Dialog      pha
            pha
            PushLong TDlgT
            Tool  _GetNewModalDialog
            pla
            sta   TDlg
            pla
            sta   TDlg+2
            lda   dhave                 ; no true colour image: only the
            and   #2                    ; screen's
            bne   :loop
            lda   #17
            jsr   Dim
            lda   #18
            jsr   Dim
:loop       pha
            PushLong 0
            Tool  _ModalDialog
            pla
            cmp   #1
            bne   :jx1
            jmp   :save
:jx1
            cmp   #2
            bne   :jx2
            jmp   :cancel
:jx2
            cmp   #64                   ; check boxes: turned over
            beq   :check
            cmp   #65
            beq   :check
            cmp   #16                   ; radio buttons: this one on, the others
            bcc   :loop                 ; of its family off
            cmp   #19
            bcc   :r1
            cmp   #32
            bcc   :loop
            cmp   #34
            bcs   :loop
            ldx   #32
            ldy   #34
            bra   :radio
:r1         ldx   #16
            ldy   #19
:radio      sta   THit
            stx   TFrom
            sty   TTo
:rr         lda   TFrom
            cmp   TTo
            bcs   :loop
            ldx   #0
            cmp   THit
            bne   :rv
            inx
:rv         phx
            PushLongAt TDlg
            lda   TFrom
            pha
            Tool  _SetDItemValue
            inc   TFrom
            bra   :rr
:check      sta   THit
            pha
            PushLongAt TDlg
            lda   THit
            pha
            Tool  _GetDItemValue
            pla
            eor   #1
            pha
            PushLongAt TDlg
            lda   THit
            pha
            Tool  _SetDItemValue
            jmp   :loop
:cancel     jsr   :close
            lda   #errCancel
            sec
            rts
:save       lda   #33                   ; Motorola?
            jsr   Value
            sta   TMoto
            lda   #64
            jsr   Value
            sta   TCompat
            lda   #65                   ; inches, or no absolute unit
            jsr   Value
            eor   #1
            inc
            sta   TResUnit
            stz   TWhich                ; the image: 0 screen, 1 true colour,
            lda   #17                   ; 2 both
            jsr   Value
            beq   :n17
            lda   #1
            sta   TWhich
:n17        lda   #18
            jsr   Value
            beq   :desc
            lda   #2
            sta   TWhich
:desc       PushLongAt TDlg             ; the description
            pea   48
            PushLong TDesc
            Tool  _GetIText
            jsr   :close
            clc
            rts
:close      PushLongAt TDlg
            Tool  _CloseDialog
            rts

* Value: A = item A's value.
Value       tax
            pha
            PushLongAt TDlg
            phx
            Tool  _GetDItemValue
            pla
            rts

* Dim: item A dimmed.
Dim         tax
            pea   255
            pha
            pha
            PushLongAt TDlg
            phx
            Tool  _GetControlDItem
            Tool  _HiliteControl
            rts

*-------------------------------------------------------------
* The screen image's colours
*-------------------------------------------------------------

* Colours: each 12-bit colour the picture uses, in order of value: CNum
* (their number), CList (them), CMap (by colour: its index + 1, 0 if not
* used); TBits: the bits a pixel (the smallest that holds them; 1, 4 or
* 8 for compatibility); over 256: no palette (an RGB image instead).
Colours     ldx   #4094
:z          stz   CMap,x
            dex
            dex
            bpl   :z
            stz   PY
:row        stz   PX
:pix        jsr   PixCol
            tax
            sep   #$20
            mx    %10
            lda   #1
            sta   CMap,x
            rep   #$20
            mx    %00
            inc   PX
            lda   PX
            cmp   pw
            bcc   :pix
            inc   PY
            lda   PY
            cmp   ph
            bcc   :row
            stz   CNum                  ; their indexes, in order of value
            ldx   #0
:c          lda   CMap,x
            and   #$00FF
            beq   :cn
            lda   CNum
            cmp   #256
            bcs   :over
            inc
            sep   #$20
            mx    %10
            sta   CMap,x
            rep   #$20
            mx    %00
            lda   CNum
            asl
            tay
            txa
            sta   CList,y
:over       inc   CNum
:cn         inx
            cpx   #4096
            bcc   :c
            ldx   #1                    ; the bits: 2^b >= the colours
            lda   #2
:b          cmp   CNum
            bcs   :bits
            asl
            inx
            cpx   #8
            bcc   :b
:bits       lda   TCompat               ; (compatibility: 1, 4 or 8)
            beq   :keep
            cpx   #2
            bcc   :keep
            ldy   #4
            cpx   #5
            bcc   :raise
            ldy   #8
:raise      tyx
:keep       stx   TBits
            rts

* PixCol: A = the 12-bit colour of pixel PX of line PY (the line's colour
* table; in 640 mode the column's part of it: 8, 12, 0, 4).
PixCol      lda   PY                    ; the line
            jsr   TimesStr
            sta   TRow
            lda   p640
            bne   :wide
            lda   PX
            lsr
            clc
            adc   TRow
            tay
            lda   [scrp],y
            and   #$00FF
            sta   TV
            lda   PX
            lsr
            lda   TV
            bcs   :low
            lsr
            lsr
            lsr
            lsr
:low        and   #$000F
            bra   :got
:wide       lda   PX
            lsr
            lsr
            clc
            adc   TRow
            tay
            lda   [scrp],y
            and   #$00FF
            sta   TV
            lda   PX                    ; (bits 7-6 for x & 3 = 0)
            and   #$0003
            eor   #$0003
            asl
            tax
            lda   TV
:sh         cpx   #0
            beq   :g2
            lsr
            dex
            bra   :sh
:g2         and   #$0003
:got        sta   TV
            lda   PY                    ; its colour table
            clc
            adc   cscb
            tay
            lda   [scrp],y
            and   #$00FF
            sta   TScb
            and   #$000F
            asl
            asl
            asl
            asl
            asl
            clc
            adc   cpal
            sta   TPal
            lda   TScb
            and   #$0080
            beq   :n
            lda   TV                    ; (the value's low two bits, also in
            and   #$0003                ; a 320 mode picture, as GS Remap)
            sta   TV
            lda   PX
            and   #$0003
            tax
            lda   Off640,x
            and   #$00FF
            clc
            adc   TV
            bra   :e
:n          lda   TV
            and   #$000F
:e          asl
            clc
            adc   TPal
            tay
            lda   [scrp],y
            and   #$0FFF
            rts

* TimesStr: A x cstr (the canvas's bytes a line).
TimesStr    sta   TM1
            lda   cstr
            sta   TM2
            lda   #0
:b          lsr   TM2
            bcc   :n
            clc
            adc   TM1
:n          asl   TM1
            ldx   TM2
            bne   :b
            rts

*-------------------------------------------------------------
* The output
*-------------------------------------------------------------

* Room: an output block for both images at most: their pixels and 6K.
Room        lda   pw                    ; the palette image: (pw x 8 + 7) / 8
            ldx   ph                    ; x ph, or 3 x pw x ph as RGB
            jsr   Mul
            jsr   Times3
            lda   MLo
            sta   n0
            lda   MHi
            sta   n0+2
            lda   dhave
            and   #2
            beq   :fixed
            lda   rw                    ; the true colour one: 3 x rw x rh
            ldx   rh
            jsr   Mul
            jsr   Times3
            lda   n0
            clc
            adc   MLo
            sta   n0
            lda   n0+2
            adc   MHi
            sta   n0+2
:fixed      lda   n0
            clc
            adc   #6144
            sta   n0
            bcc   :new
            inc   n0+2
:new        pha
            pha
            PushLongAt n0
            lda   uid
            pha
            pea   $C008
            PushLong 0
            Tool  _NewHandle
            tax
            pla
            sta   ohnd
            pla
            sta   ohnd+2
            txa
            bcs   :err
            lda   ohnd
            sta   wq
            lda   ohnd+2
            sta   wq+2
            ldy   #2
            lda   [wq],y
            sta   outp+2
            sta   q0+2
            lda   [wq]
            sta   outp
            sta   q0
            clc
:err        rts

* Mul: MHi:MLo = A x X; Times3: x 3.
Mul         sta   TM1
            stx   TM2
            stz   MLo
            stz   MHi
            stz   TM3
:b          lsr   TM2
            bcc   :n
            lda   MLo
            clc
            adc   TM1
            sta   MLo
            lda   MHi
            adc   TM3
            sta   MHi
:n          asl   TM1
            rol   TM3
            lda   TM2
            bne   :b
            rts
Times3      lda   MLo
            sta   TM1
            lda   MHi
            sta   TM2
            asl   MLo
            rol   MHi
            lda   MLo
            clc
            adc   TM1
            sta   MLo
            lda   MHi
            adc   TM2
            sta   MHi
            rts

* Put: a byte out; PutW0: a word, low byte first (whatever the order).
Put         sep   #$20
            mx    %10
            sta   [q0]
            rep   #$20
            mx    %00
            inc   q0
            bne   :n
            inc   q0+2
:n          inc   outl
            bne   :d
            inc   outl+2
:d          rts
PutW0       pha
            jsr   Put
            pla
            xba
            jmp   Put

* TW: a word in the file's order; TL: VHi:A, a long.
TW          ldx   TMoto
            beq   PutW0
            pha
            xba
            jsr   Put
            pla
            jmp   Put
TL          ldx   TMoto
            bne   :mm
            pha
            jsr   PutW0
            pla
            lda   VHi
            jmp   PutW0
:mm         pha
            lda   VHi
            jsr   TW
            pla
            jmp   TW

* Even: a pad byte to an even offset.
Even        lda   outl
            and   #1
            beq   :out
            lda   #0
            jsr   Put
:out        rts

* PatchL: the long VHi:A written in the file's order at offset TAt.
PatchL      pha
            lda   outp
            clc
            adc   TAt
            sta   wq
            lda   outp+2
            adc   TAt+2
            sta   wq+2
            pla
            ldx   TMoto
            bne   :mm
            sta   [wq]
            ldy   #2
            lda   VHi
            sta   [wq],y
            rts
:mm         xba
            ldy   #2
            sta   [wq],y
            lda   VHi
            xba
            sta   [wq]
            rts

*-------------------------------------------------------------
* The images
*-------------------------------------------------------------

* ImgPal: the screen image as a palette image (A: its NewSubfileType);
* over 256 colours, as an RGB image of its colours.
ImgPal      sta   TSub
            lda   CNum
            cmp   #257
            bcc   :pal
            lda   #2                    ; (its own colours as RGB)
            sta   TKind
            lda   pw
            sta   TW0
            lda   ph
            sta   TH0
            bra   ImgCommon
:pal        lda   #1
            sta   TKind
            lda   pw
            sta   TW0
            lda   ph
            sta   TH0
            bra   ImgCommon

* ImgRGB: the true colour image as an RGB image (A: NewSubfileType).
ImgRGB      sta   TSub
            stz   TKind
            lda   rw
            sta   TW0
            lda   rh
            sta   TH0

* ImgCommon: the directory (its tags in order), its values, the strip
* (TKind: 0 the true colour image, 1 palette indexes, 2 the screen's
* colours as RGB).
ImgCommon   stz   NE                    ; the entries
            lda   #254                  ; NewSubfileType
            ldx   #4
            ldy   TSub
            jsr   AddE
            lda   #256                  ; ImageWidth, ImageLength
            ldx   #3
            ldy   TW0
            jsr   AddE
            lda   #257
            ldx   #3
            ldy   TH0
            jsr   AddE
            lda   TKind                 ; BitsPerSample: b, or 8, 8, 8
            cmp   #1
            bne   :b3
            lda   #258
            ldx   #3
            ldy   TBits
            jsr   AddE
            bra   :comp
:b3         lda   #258
            ldx   #3
            ldy   #0
            jsr   AddE
            lda   #3
            jsr   SetCount
            lda   #4
            jsr   SetKind
:comp       lda   #259                  ; Compression: none
            ldx   #3
            ldy   #1
            jsr   AddE
            ldy   #2                    ; PhotometricInterpretation: RGB,
            lda   TKind                 ; palette
            cmp   #1
            bne   :ph
            ldy   #3
:ph         lda   #262
            ldx   #3
            jsr   AddE
            lda   [dname]               ; DocumentName: the loaded file's
            and   #$00FF
            beq   :desc
            lda   dname
            sta   TStr
            lda   dname+2
            sta   TStr+2
            lda   #269
            jsr   AddStr
:desc       lda   TDesc                 ; ImageDescription
            and   #$00FF
            beq   :strip
            lda   #TDesc+1
            sta   TStr
            lda   #^TDesc
            sta   TStr+2
            lda   TDesc                 ; (a C string: the end marked)
            and   #$00FF
            tax
            sep   #$20
            mx    %10
            stz   TDesc+1,x
            rep   #$20
            mx    %00
            lda   #270
            jsr   AddStr
:strip      lda   #273                  ; StripOffsets (one strip)
            ldx   #4
            ldy   #0
            jsr   AddE
            lda   #6
            jsr   SetKind
            ldy   #3                    ; SamplesPerPixel
            lda   TKind
            cmp   #1
            bne   :spp
            ldy   #1
:spp        lda   #277
            ldx   #3
            jsr   AddE
            lda   #278                  ; RowsPerStrip: all
            ldx   #4
            ldy   TH0
            jsr   AddE
            lda   #279                  ; StripByteCounts
            ldx   #4
            ldy   #0
            jsr   AddE
            lda   #7
            jsr   SetKind
            lda   #282                  ; XResolution, YResolution
            ldx   #5
            ldy   #0
            jsr   AddE
            lda   #2
            jsr   SetKind
            lda   #283
            ldx   #5
            ldy   #0
            jsr   AddE
            lda   #3
            jsr   SetKind
            lda   TKind                 ; PlanarConfiguration (RGB)
            cmp   #1
            beq   :unit
            lda   #284
            ldx   #3
            ldy   #1
            jsr   AddE
:unit       lda   #296                  ; ResolutionUnit
            ldx   #3
            ldy   TResUnit
            jsr   AddE
            lda   #TxSoftware           ; Software, DateTime, HostComputer
            sta   TStr
            lda   #^TxSoftware
            sta   TStr+2
            lda   #305
            jsr   AddStr
            jsr   DateText
            lda   #TxDate
            sta   TStr
            lda   #^TxDate
            sta   TStr+2
            lda   #306
            jsr   AddStr
            lda   #TxHost
            sta   TStr
            lda   #^TxHost
            sta   TStr+2
            lda   #316
            jsr   AddStr
            lda   TKind                 ; ColorMap (palette)
            cmp   #1
            bne   :write
            lda   TBits
            asl
            tax
            lda   Pow2,x
            sta   TM1
            asl
            adc   TM1
            tay
            lda   #320
            ldx   #3
            jsr   AddEc
            lda   #5
            jsr   SetKind
:write      jmp   WriteImg

* AddE: an entry: tag A, type X (2 ASCII, 3 SHORT, 4 LONG, 5 RATIONAL),
* count 1, value Y (kind 0: in its field). AddEc: count Y, value 0.
AddE        sta   TV
            stx   TV2
            sty   TV3
            lda   #1
            sta   TV4
            bra   Entry
AddEc       sta   TV
            stx   TV2
            sty   TV4
            stz   TV3
Entry       lda   NE
            jsr   EntAt
            lda   TV
            sta   TEnt,x
            lda   TV2
            sta   TEnt+2,x
            lda   TV4
            sta   TEnt+4,x
            stz   TEnt+6,x
            lda   TV3
            sta   TEnt+8,x
            stz   TEnt+10,x
            stz   TEnt+12,x
            inc   NE
            rts

* EntAt: X = entry A's offset (18 bytes each); LastAt: the last one's.
EntAt       asl
            sta   TM1
            asl
            asl
            asl
            clc
            adc   TM1
            tax
            rts
LastAt      lda   NE
            dec
            bra   EntAt

* SetKind, SetCount: the last entry's kind (1 a string, 2 and 3 the X
* and Y resolutions, 4 three 8s, 5 the colour map, 6 the strip's
* offset, 7 its length) or count.
SetKind     pha
            jsr   LastAt
            pla
            sta   TEnt+12,x
            rts
SetCount    pha
            jsr   LastAt
            pla
            sta   TEnt+4,x
            rts

* AddStr: an ASCII entry, tag A, the C string at TStr.
AddStr      sta   TV
            lda   TStr
            sta   rp
            lda   TStr+2
            sta   rp+2
            ldy   #0
:l          lda   [rp],y
            and   #$00FF
            beq   :e
            iny
            bra   :l
:e          iny                         ; (with its 0)
            sty   TV4
            lda   TV
            ldx   #2
            jsr   AddEc
            jsr   LastAt
            lda   TStr
            sta   TEnt+8,x
            lda   TStr+2
            sta   TEnt+10,x
            lda   #1
            sta   TEnt+12,x
            rts

* WriteImg: the directory (the previous one's "next" pointing at it),
* the values that don't fit in their fields, the strip.
WriteImg    jsr   Even
            lda   NextAt                ; (the previous directory: its next)
            ora   NextAt+2
            beq   :first
            lda   NextAt
            sta   TAt
            lda   NextAt+2
            sta   TAt+2
            lda   outl+2
            sta   VHi
            lda   outl
            jsr   PatchL
:first      lda   NE
            jsr   TW
            stz   EI
:e          lda   EI
            cmp   NE
            bcc   :jx3
            jmp   :next
:jx3
            jsr   EntAt
            lda   TEnt,x                ; tag, type, count
            jsr   TW
            lda   EI
            jsr   EntAt
            lda   TEnt+2,x
            jsr   TW
            lda   EI
            jsr   EntAt
            lda   TEnt+6,x
            sta   VHi
            lda   TEnt+4,x
            jsr   TL
            lda   EI                    ; the field
            jsr   EntAt
            lda   outl
            sta   TEnt+14,x
            lda   outl+2
            sta   TEnt+16,x
            lda   TEnt+12,x
            beq   :inPlace
            cmp   #1
            bne   :later
            lda   TEnt+4,x              ; a string of 4 or less: in place
            cmp   #5
            bcs   :later
            jsr   StrOut
            lda   EI
            jsr   EntAt
            lda   #4
            sec
            sbc   TEnt+4,x
            tay
            beq   :en
:pad        lda   #0
            phy
            jsr   Put
            ply
            dey
            bne   :pad
            bra   :en
:later      stz   VHi
            lda   #0
            jsr   TL
            bra   :en
:inPlace    lda   TEnt+2,x              ; a SHORT: left in the field
            cmp   #3
            bne   :long
            lda   TEnt+8,x
            jsr   TW
            lda   #0
            jsr   TW
            bra   :en
:long       stz   VHi
            lda   TEnt+8,x
            jsr   TL
:en         inc   EI
            jmp   :e
:next       lda   outl                  ; no next directory (yet)
            sta   NextAt
            lda   outl+2
            sta   NextAt+2
            stz   VHi
            lda   #0
            jsr   TL
            stz   EI                    ; the values after it
:v          lda   EI
            cmp   NE
            bcs   :strip
            jsr   EntAt
            lda   TEnt+12,x
            beq   :vn
            cmp   #6
            bcs   :vn
            cmp   #1
            bne   :val
            lda   TEnt+4,x
            cmp   #5
            bcc   :vn
:val        jsr   Even
            jsr   FieldHere             ; (its field: here)
            lda   EI
            jsr   EntAt
            lda   TEnt+12,x
            asl
            tax
            jsr   (:kinds,x)
:vn         inc   EI
            bra   :v
:kinds      da    0,StrOut,XRes,YRes,Eights,CMapOut
:strip      jsr   Even                  ; the strip
            lda   outl
            sta   SAt
            lda   outl+2
            sta   SAt+2
            jsr   Pixels
            stz   EI                    ; its offset and length in their fields
:s          lda   EI
            cmp   NE
            bcs   :out
            jsr   EntAt
            lda   TEnt+14,x
            sta   TAt
            lda   TEnt+16,x
            sta   TAt+2
            lda   TEnt+12,x
            cmp   #6
            bne   :s7
            lda   SAt+2
            sta   VHi
            lda   SAt
            jsr   PatchL
            bra   :sn
:s7         cmp   #7
            bne   :sn
            lda   outl
            sec
            sbc   SAt
            pha
            lda   outl+2
            sbc   SAt+2
            sta   VHi
            pla
            jsr   PatchL
:sn         inc   EI
            bra   :s
:out        rts

* FieldHere: entry EI's field = the offset here.
FieldHere   lda   EI
            jsr   EntAt
            lda   TEnt+14,x
            sta   TAt
            lda   TEnt+16,x
            sta   TAt+2
            lda   outl+2
            sta   VHi
            lda   outl
            jmp   PatchL

* StrOut: entry EI's string (its count of bytes, with its 0).
StrOut      lda   EI
            jsr   EntAt
            lda   TEnt+8,x
            sta   rp
            lda   TEnt+10,x
            sta   rp+2
            lda   TEnt+4,x
            sta   TM1
            ldy   #0
:c          cpy   TM1
            bcs   :e
            lda   [rp],y
            phy
            jsr   Put
            ply
            iny
            bra   :c
:e          rts

* XRes, YRes: 40 (or 80 in 640 mode) and 36 pixels a unit; Eights: 8,
* 8, 8.
XRes        lda   #40
            ldx   p640
            beq   :r
            lda   #80
:r          bra   Ratio
YRes        lda   #36
Ratio       stz   VHi
            jsr   TL
            stz   VHi
            lda   #1
            jmp   TL
Eights      lda   #8
            jsr   TW
            lda   #8
            jsr   TW
            lda   #8
            jmp   TW

* CMapOut: the colour map: 2^b reds, greens, blues (16 bits: the 4-bit
* channel x $1111; 0 past the colours used).
CMapOut     lda   TBits
            asl
            tax
            lda   Pow2,x
            sta   TN
            lda   #8                    ; red (bits 11-8), green, blue
            sta   TShift
:ch         stz   TI
:i          lda   TI
            cmp   TN
            bcs   :nch
            lda   #0
            ldx   TI
            cpx   CNum
            bcs   :put
            txa
            asl
            tax
            lda   CList,x
            ldx   TShift
:sh         cpx   #0
            beq   :nib
            lsr
            dex
            bra   :sh
:nib        and   #$000F
            sta   TM1                   ; x $1111
            asl
            asl
            asl
            asl
            ora   TM1
            sta   TM1
            xba
            and   #$FF00
            ora   TM1
:put        jsr   TW
            inc   TI
            bra   :i
:nch        lda   TShift
            sec
            sbc   #4
            sta   TShift
            bpl   :ch
            rts

* Pixels: the strip: by TKind.
Pixels      lda   TKind
            beq   PixTrue
            cmp   #1
            beq   PixPal
            jmp   PixScrRGB

* PixTrue: the true colour image's rows (3 bytes a pixel).
PixTrue     lda   tp
            sta   rp
            lda   tp+2
            sta   rp+2
            lda   rw
            jsr   Times3W
            sta   TN
            stz   PY
:row        ldy   #0
:b          cpy   TN
            bcs   :nrow
            lda   [rp],y
            phy
            jsr   Put
            ply
            iny
            bra   :b
:nrow       lda   rp
            clc
            adc   tstride
            sta   rp
            bcc   :nc
            inc   rp+2
:nc         inc   PY
            lda   PY
            cmp   rh
            bcc   :row
            rts
Times3W     sta   TM1
            asl
            clc
            adc   TM1
            rts

* PixPal: the screen image's colour indexes, b bits each, the leftmost
* in the top bits, each row to a whole byte.
PixPal      stz   PY
:row        stz   PX
            stz   TAcc
            stz   TCnt
:pix        jsr   PixCol
            tax
            lda   CMap,x
            and   #$00FF
            dec
            sta   TV
            ldx   TBits                 ; shifted in
:in         asl   TAcc
            dex
            bne   :in
            lda   TAcc
            ora   TV
            sta   TAcc
            lda   TCnt
            clc
            adc   TBits
            sta   TCnt
            cmp   #8
            bcc   :np
            sec                         ; a whole byte: out
            sbc   #8
            sta   TCnt
            tax
            lda   TAcc
:out        cpx   #0
            beq   :o
            lsr
            dex
            bra   :out
:o          and   #$00FF
            jsr   Put
:np         inc   PX
            lda   PX
            cmp   pw
            bcc   :pix
            lda   TCnt                  ; the row's last bits
            beq   :nrow
            lda   #8
            sec
            sbc   TCnt
            tax
            lda   TAcc
:pl         cpx   #0
            beq   :po
            asl
            dex
            bra   :pl
:po         and   #$00FF
            jsr   Put
:nrow       inc   PY
            lda   PY
            cmp   ph
            bcs   :jx4
            jmp   :row
:jx4
            rts

* PixScrRGB: the screen image's colours as RGB (over 256 colours).
PixScrRGB   stz   PY
:row        stz   PX
:pix        jsr   PixCol
            sta   TV
            xba
            jsr   :c8
            lda   TV
            lsr
            lsr
            lsr
            lsr
            jsr   :c8
            lda   TV
            jsr   :c8
            inc   PX
            lda   PX
            cmp   pw
            bcc   :pix
            inc   PY
            lda   PY
            cmp   ph
            bcc   :row
            rts
:c8         and   #$000F                ; 4 bits to 8
            sta   TM1
            asl
            asl
            asl
            asl
            ora   TM1
            jmp   Put

* DateText: TxDate = now, "YYYY:MM:DD HH:MM:SS".
DateText    pha
            pha
            pha
            pha
            Tool  _ReadTimeHex
            pla                         ; minute, second
            sta   TV
            pla                         ; year, hour
            sta   TV2
            pla                         ; month, day
            sta   TV3
            pla
            lda   TV2                   ; the year
            xba
            and   #$00FF
            clc
            adc   #1900
            ldx   #0
            ldy   #4
            jsr   Dec
            lda   TV3
            xba
            and   #$00FF
            inc
            ldx   #5
            ldy   #2
            jsr   Dec
            lda   TV3
            and   #$00FF
            inc
            ldx   #8
            ldy   #2
            jsr   Dec
            lda   TV2
            and   #$00FF
            ldx   #11
            ldy   #2
            jsr   Dec
            lda   TV
            xba
            and   #$00FF
            ldx   #14
            ldy   #2
            jsr   Dec
            lda   TV
            and   #$00FF
            ldx   #17
            ldy   #2
            jmp   Dec

* Dec: A in Y decimal digits (with leading zeros) at TxDate + X.
Dec         sta   TM1
            stx   TM2
            tya
            clc
            adc   TM2
            dec
            tax                         ; (the last digit's place)
:d          lda   TM1
            stz   TM3
:div        cmp   #10
            bcc   :rem
            sbc   #10
            inc   TM3
            bra   :div
:rem        clc
            adc   #'0'
            sep   #$20
            mx    %10
            sta   TxDate,x
            rep   #$20
            mx    %00
            lda   TM3
            sta   TM1
            dex
            dey
            bne   :d
            rts

*-------------------------------------------------------------
* Data
*-------------------------------------------------------------
TShow       dw    0
TPreset     dw    0                     ; (TiffSet's answers wait)
TDlg        adrl  0
THit        dw    0
TFrom       dw    0
TTo         dw    0
TWhich      dw    0                     ; 0 screen, 1 true colour, 2 both
TMoto       dw    0                     ; 1: Motorola byte order
TCompat     dw    1
TResUnit    dw    2
TBits       dw    8
TSub        dw    0
TKind       dw    0
TW0         dw    0
TH0         dw    0
NE          dw    0                     ; the directory's entries
EI          dw    0
NextAt      adrl  0                     ; the last directory's "next" field
SAt         adrl  0                     ; the strip
TAt         adrl  0
VHi         dw    0
TStr        adrl  0
TV          dw    0
TV2         dw    0
TV3         dw    0
TV4         dw    0
TM1         dw    0
TM2         dw    0
TM3         dw    0
MLo         dw    0
MHi         dw    0
TN          dw    0
TI          dw    0
TShift      dw    0
TAcc        dw    0
TCnt        dw    0
TRow        dw    0
TScb        dw    0
TPal        dw    0
PX          dw    0
PY          dw    0
CNum        dw    0                     ; the colours used
Pow2        dw    1,2,4,8,16,32,64,128,256
Off640      db    8,12,0,4
TEnt        ds    24*18                 ; tag, type, count, value, kind, field
CList       ds    512                   ; the colours, in order of value
CMap        ds    4096                  ; by colour: its index + 1
TDesc       ds    84                    ; the description (Pascal string)
TxSoftware  asc   'MegaconvertGS 0.7',00
TxHost      asc   'Apple IIgs',00
TxDate      asc   '0000:00:00 00:00:00',00
* The dialog (SuperConvert's 26:195C)
TDlgT       dw    20,50,185,590
            dw    $FFFF
            adrl  0
            adrl  TI128,TI129,TI16,TI17,TI18,TI32,TI33,TI64,TI65,TI130,TI48
            adrl  TI2,TI1,0
TI128       dw    128,5,10,15,530,$8016
            adrl  TxTiffTitle
            dw    TxTiffTitleEnd-TxTiffTitle,0
            adrl  0
TI129       dw    129,20,10,30,600,$800F
            adrl  TxTiff129
            dw    0,0
            adrl  0
TI16        dw    16,30,10,0,0,$000C
            adrl  TxTiff16
            dw    1,1
            adrl  0
TI17        dw    17,40,10,0,0,$000C
            adrl  TxTiff17
            dw    0,1
            adrl  0
TI18        dw    18,50,10,0,0,$000C
            adrl  TxTiff18
            dw    0,1
            adrl  0
TI32        dw    32,65,10,0,0,$000C
            adrl  TxTiff32
            dw    1,2
            adrl  0
TI33        dw    33,75,10,0,0,$000C
            adrl  TxTiff33
            dw    0,2
            adrl  0
TI64        dw    64,90,10,0,0,$000B
            adrl  TxTiff64
            dw    1,0
            adrl  0
TI65        dw    65,105,10,0,0,$000B
            adrl  TxTiff65
            dw    0,0
            adrl  0
TI130       dw    130,120,10,130,600,$800F
            adrl  TxTiff130
            dw    0,0
            adrl  0
TI48        dw    48,130,10,143,530,$8011
            adrl  TxTiffNone
            dw    80,0
            adrl  0
TI2         dw    2,147,300,160,400,$000A
            adrl  TxTiffCancel
            dw    0,0
            adrl  0
TI1         dw    1,147,420,160,520,$000A
            adrl  TxTiffSave
            dw    0,0
            adrl  0
TxTiffTitle db    $01,'J',$01,$00,$01,'S',$01,$00
            asc   'TIFF Save Options'
TxTiffTitleEnd
TxTiff129   str   'Image to save:'
TxTiff16    str   'Screen image only, as TIFF Class P (palette color) image'
TxTiff17    str   'True color image only, as TIFF Class R (RGB color) image'
TxTiff18    str   'Both screen and true color images'
TxTiff32    str   'Intel byte ordering, suitable for use on IBM & compatible systems'
TxTiff33    str   'Motorola byte ordering, suitable for use on Macintosh systems'
TxTiff64    str   'Increase compatibility (may increase file size considerably)'
TxTiff65    str   'Leave image sizing decisions up to the receiving program'
TxTiff130   str   'Description of image:'
TxTiffNone  db    0
TxTiffCancel str  'Cancel'
TxTiffSave  str   'Save'
