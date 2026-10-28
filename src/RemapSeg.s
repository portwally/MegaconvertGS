*-------------------------------------------------------------
* RemapSeg.s - Remap (a segment of its own; called from the
* main program with JSL)
*
* Turns the true colour picture into a screen: 320 x 200 with 16
* colours, 640 x 200 with 4, 640 x 200 dither mode (8 colours, in
* pairs of columns), or multipalette (320 mode, a palette for each
* group of lines). Palettes: calculated from the picture, the
* default colours, greys, or one of the others. Rendering: closest
* match, pattern dither, or error diffusion (for grey palettes).
* The size is set in GS Remap's scale steps, across and down; the
* result is at most one screen (the rest of the picture is cut off).
*
* The steps follow SuperConvert's remap as GS Remap does it:
*  1. the picture scaled to the output size (box averages)
*  2. the colours' histogram, and from it the palette's calculated
*     colours (popularity, with neighbours suppressed)
*  3. every pattern (or single colour) the palette can make
*  4. every pixel takes the pattern that matches it best
*
* In:  tp, tstride, rw, rh, rtall (the picture), scrp (the screen to
*      fill), uid. Out: rout_w, rout_h, rout640 (the screen picture).
*-------------------------------------------------------------
            rel
            mx    %00
            use   macros/Macs.s
            put   Equates.s

NewTrueL    ext                         ; (SegLib's MakeTrue: not used here)

* RemapRun: remaps with the options as they are (A = 1: the default
* options, fitted to the screen, as Open uses them; 2: a quick remap).
*   out: carry clear, or carry set and A = error
RemapRun    ent
            phb
            phk
            plb
            cmp   #2
            bne   :notQuick
            jsr   Quick
            plb
            rtl
:notQuick   cmp   #0
            beq   :go
            lda   OMode                 ; the defaults, without losing the
            pha                         ; options chosen in the dialog
            lda   OPal
            pha
            lda   OAlg
            pha
            stz   OMode                 ; 320 mode, calculated, pattern dither
            stz   OPal
            lda   #1
            sta   OAlg
            jsr   Fit
            jsr   Remap
            sta   RunErr                ; (the result: carry and A)
            lda   #0
            rol
            sta   RunCarry
            pla
            sta   OAlg
            pla
            sta   OPal
            pla
            sta   OMode
            lda   RunCarry
            lsr                         ; (back into the carry)
            lda   RunErr
            plb
            rtl
:go         jsr   Remap
            plb
            rtl
RunErr      dw    0
RunCarry    dw    0

* RemapSet: options from the direct page (rmode, rpal, ralg, rhs, rvs,
* rother); a step of $FF means: fit to the screen.
RemapSet    ent
            phb
            phk
            plb
            lda   rmode
            sta   OMode
            lda   rpal
            sta   OPal
            lda   ralg
            sta   OAlg
            lda   OMode                 ; (OOther: a word for each mode)
            asl
            tax
            lda   rother
            sta   OOther,x
            lda   rhs
            sta   OHStep
            lda   rvs
            sta   OVStep
            lda   rhs
            cmp   #$FF
            bne   :steps
            jsr   Fit
:steps      jsr   Normalise
            plb
            rtl

*-------------------------------------------------------------
* Options
*-------------------------------------------------------------

* GetProto: Proto (with flags) and ProtoN for the mode and palette choice.
* MPTech: the multipalette technique (0 standard, 1 max 8, 2 optimized,
* 3 zones, 4 zones max 8).
GetProto    stz   MPTech
            lda   OMode
            cmp   #3
            bne   :single
            lda   OPal                  ; multipalette: always calculated; "other"
            cmp   #3                    ; picks a technique
            bne   :mp
            lda   OOther+6
            cmp   #4
            bcc   :tech
            lda   #3
:tech       inc
            sta   MPTech
:mp         lda   #CalcProtos
            bra   :set
:single     lda   OPal
            cmp   #4
            bne   :notCur
            jmp   CurProto
:notCur     cmp   #5
            bne   :notStored
            jmp   StoredProto
:notStored  cmp   #3
            beq   :other
            asl                         ; calculated, default, greys: the set,
            tax                         ; then the mode's palette in it
            lda   ProtoSets,x
            sta   t0
            lda   OMode
            xba
            lsr
            lsr
            lsr                         ; * 32
            clc
            adc   t0
            bra   :set
:other      lda   OMode                 ; the mode's list of other palettes
            asl
            tax
            lda   OOther,x              ; which one (kept within the list)
            cmp   OtherCount,x
            bcc   :in
            lda   OtherCount,x
            dec
:in         xba
            lsr
            lsr
            lsr                         ; * 32
            clc
            adc   OtherSets,x
:set        sta   t0
            ldx   OMode
            lda   ModeN,x
            and   #$00FF
            sta   ProtoN
            ldy   #0
:c          lda   (t0),y
            sta   Proto,y
            iny
            iny
            cpy   #32
            bcc   :c
            rts

ModeN       db    16,4,8,16

* CurProto: GetProto for the picture's current palette: colour table 0 of
* the screen picture as it is (640 modes: entries 8 to 11, or 8 to 15).
CurProto    ldx   OMode
            lda   ModeN,x
            and   #$00FF
            sta   ProtoN
            ldy   #palOffset
            cpx   #0
            beq   :copy
            ldy   #palOffset+16
:copy       ldx   #0
:c          lda   [scrp],y
            and   #$0FFF
            sta   Proto,x
            iny
            iny
            inx
            inx
            cpx   #32
            bcc   :c
            rts

* StoredProto: the stored palette (Store palette), as CurProto takes the
* picture's: its first 16 colours in 320 mode, colours 8-15 otherwise.
StoredProto ldx   OMode
            lda   ModeN,x
            and   #$00FF
            sta   ProtoN
            ldy   #0
            cpx   #0
            beq   :copy
            ldy   #16
:copy       ldx   #0
:c          lda   StoredPal,y
            and   #$0FFF
            sta   Proto,x
            iny
            iny
            inx
            inx
            cpx   #32
            bcc   :c
            rts

* RemapStore: Screen > Store palette: the screen picture's colour table 0
* kept, for the mode it suits (320 mode; 640 with colours 0-3 the same as
* 4-7: four colours; else 640 dither).
RemapStore  ent
            phb
            phk
            plb
            ldy   #palOffset            ; the 16 colours
            ldx   #0
:c          lda   [scrp],y
            and   #$0FFF
            sta   StoredPal,x
            iny
            iny
            inx
            inx
            cpx   #32
            bcc   :c
            stz   StoredMode
            ldy   #scbOffset            ; line 0 in 640 mode?
            lda   [scrp],y
            and   #$0080
            beq   :done
            lda   #1
            sta   StoredMode
            ldx   #0                    ; colours 0-3 as 4-7: four colours
:same       lda   StoredPal,x
            cmp   StoredPal+8,x
            bne   :dither
            inx
            inx
            cpx   #8
            bcc   :same
            bra   :done
:dither     lda   #2
            sta   StoredMode
:done       lda   #1
            sta   HaveStored
            plb
            rtl

* PalOK: carry clear if palette A (0 calculated, 1 default, 2 greys, 3 other,
* 4 the picture's current, 5 stored) can be used in mode OMode. A is kept.
PalOK       pha
            ldx   OMode
            cmp   #5                    ; stored: only in the mode it came from
            bne   :notStored
            lda   HaveStored
            beq   :no
            cpx   StoredMode
            bne   :no
            bra   :yes
:notStored  pla
            pha
            cmp   #1                    ; default and greys: not in multipalette
            beq   :notMulti
            cmp   #2
            beq   :notMulti
            cmp   #4
            bne   :yes
            cpx   #3                    ; the picture's current: a screen of the
            beq   :no                   ; same kind
            lda   ModeIs640,x
            and   #$00FF
            sta   t1
            jsr   Screen640
            cmp   t1
            bne   :no
            bra   :yes
:notMulti   cpx   #3
            beq   :no
:yes        pla
            clc
            rts
:no         pla
            sec
            rts

HaveStored  dw    0                     ; Store palette: there is one,
StoredMode  dw    0                     ; for this mode,
StoredPal   ds    32                    ; its 16 colours
ModeIs640   db    0,1,1,0

* Screen640: A = 1 if the screen picture's first line is in 640 mode.
Screen640   ldy   #scbOffset
            lda   [scrp],y
            and   #$0080
            beq   :no
            lda   #1
:no         rts

* Normalise: a palette the mode can't use becomes calculated; error
* diffusion only for a grey palette (not in multipalette).
Normalise   lda   OPal
            jsr   PalOK
            bcc   :palOK
            stz   OPal
:palOK      lda   OAlg
            cmp   #2
            bne   :ok
            jsr   DiffusionOK
            bcc   :ok
            lda   #1
            sta   OAlg
:ok         rts

* DiffusionOK: carry clear if error diffusion can be used.
DiffusionOK lda   OMode
            cmp   #3
            beq   :no
            jsr   GetProto
            ldx   #0
:e          lda   Proto,x
            bit   #$8000                ; reserved: fine
            bne   :next
            bit   #$4000                ; to be calculated: not grey
            bne   :no
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

* IsGrey: carry clear if colour A has red = green = blue.
IsGrey      sta   t1
            and   #$000F
            sta   t2
            lda   t1
            lsr
            lsr
            lsr
            lsr
            and   #$000F
            cmp   t2
            bne   :no
            lda   t1
            xba
            and   #$000F
            cmp   t2
            bne   :no
            clc
            rts
:no         sec
            rts

*-------------------------------------------------------------
* Sizes
*-------------------------------------------------------------

* Natural: NatW, NatH, the size at 1:1 for the mode (pixel shapes).
Natural     lda   rh
            sta   NatH
            lda   rw
            ldx   OMode
            cpx   #1
            beq   :wide
            cpx   #2
            beq   :wide
            ldx   rtall                 ; 320 mode, tall pixels: half as many
            beq   :w
            lsr
            bne   :w
            lda   #1
            bra   :w
:wide       ldx   rtall                 ; 640 modes, square pixels: twice as many
            bne   :w
            asl
:w          sta   NatW
            rts

* ScreenW: 640 for the 640 modes, else 320.
ScreenW     lda   #320
            ldx   OMode
            cpx   #1
            beq   :wide
            cpx   #2
            bne   :done
:wide       asl
:done       rts

* Fit: the largest step up to 1:1 that fits the screen, across and down.
Fit         jsr   Natural
            lda   #14
            sta   OHStep
:try        lda   NatW
            ldx   OHStep
            jsr   Scale
            sta   t3
            jsr   ScreenW
            cmp   t3
            bcc   :less
            lda   NatH
            ldx   OHStep
            jsr   Scale
            cmp   #201
            bcc   :fit
:less       lda   OHStep
            beq   :fit
            dec   OHStep
            bra   :try
:fit        lda   OHStep
            sta   OVStep
            rts

* Scale: A * n / d for scale step X (0-22).
Scale       pha
            txa
            asl
            tax
            lda   StepD,x
            sta   t2
            lda   StepN,x
            tax
            pla
            jsr   Mul16
            lda   MLo
            sta   n0
            lda   MHi
            sta   n0+2
            lda   t2
            jmp   Div32

* Sizes: the wanted size (WantW, WantH), the size on the screen (ROutW, ROutH),
* and the part of the picture that makes it (CropW, CropH).
Sizes       jsr   Natural
            lda   NatW
            ldx   OHStep
            jsr   Scale
            bne   :w
            inc
:w          sta   WantW
            lda   NatH
            ldx   OVStep
            jsr   Scale
            bne   :h
            inc
:h          sta   WantH
            jsr   ScreenW
            cmp   WantW
            bcc   :cw
            lda   WantW
:cw         sta   ROutW
            asl
            sta   ROutW2
            lda   #200
            cmp   WantH
            bcc   :ch
            lda   WantH
:ch         sta   ROutH
            lda   rw                    ; crop = picture * clipped / wanted
            ldx   ROutW
            jsr   Mul16
            lda   MLo
            sta   n0
            lda   MHi
            sta   n0+2
            lda   WantW
            jsr   Div32
            bne   :cwOK
            inc
:cwOK       sta   CropW
            lda   rh
            ldx   ROutH
            jsr   Mul16
            lda   MLo
            sta   n0
            lda   MHi
            sta   n0+2
            lda   WantH
            jsr   Div32
            bne   :chOK
            inc
:chOK       sta   CropH
            lda   CropW                 ; the spans: the cropped picture
            sta   SrcW                  ; scaled to the output size
            lda   ROutW
            sta   SpanW
            lda   CropH
            sta   SrcH
            lda   ROutH
            sta   SpanH
            rts

* GS Remap's scale steps, 1:16 up to 4:1 (1:1 is step 14).
StepN       dw    1,1,1,1,1,1,1,1,2,1,3,2,3,4,1,5,4,3,5,2,5,3,4
StepD       dw    16,12,10,8,6,5,4,3,5,2,5,3,4,5,1,4,3,2,3,1,2,1,1

*-------------------------------------------------------------
* Quick remap (GS Remap's): the picture at its 320 mode size, the
* screenful at its top left, in a fixed palette with an ordered dither
*-------------------------------------------------------------
Quick       lda   OMode                 ; the size in 320 mode
            pha
            stz   OMode
            jsr   Natural
            pla
            sta   OMode
            lda   NatW
            cmp   #320
            bcc   :w
            lda   #320
:w          sta   ROutW
            asl
            sta   ROutW2
            lda   NatH
            cmp   #200
            bcc   :h
            lda   #200
:h          sta   ROutH
            lda   rw                    ; the spans: the whole picture scaled to
            sta   SrcW                  ; its 320 mode size (of which the top
            lda   NatW                  ; left screenful is made)
            sta   SpanW
            lda   rh
            sta   SrcH
            lda   NatH
            sta   SpanH
            lda   #16                   ; (320 mode pixels)
            sta   ProtoN
            jsr   MakePlanes
            bcc   :planes
            rts
:planes     jsr   ClearScreen
            jsr   QTables
            stz   RowY
:row        lda   RowY                  ; (the planes read in place)
            jsr   PlaneRow
            jsr   ClearRowOut
            lda   RowY                  ; thresholds k: 2 x line parity +
            and   #$0001                ; column parity
            asl
            sta   t1
            xba
            sta   KE                    ; (k x 256: QGB, k x 16: QR)
            clc
            adc   #$0100
            sta   KO
            lda   t1
            asl
            asl
            asl
            asl
            sta   KRE
            clc
            adc   #16
            sta   KRO
            ldy   #0
            sty   OutI
:pair       lda   [p1],y                ; even column: the left nibble
            and   #$00FF
            ora   KE
            tax
            lda   QGB,x
            sta   t2
            lda   [p1],y
            xba
            and   #$000F
            ora   KRE
            tax
            lda   QR,x
            ora   t2
            and   #$0007
            tax
            lda   QMapL,x
            and   #$00FF
            sta   Acc
            iny
            iny
            cpy   ROutW2
            bcs   :put
            lda   [p1],y                ; odd column: the right one
            and   #$00FF
            ora   KO
            tax
            lda   QGB,x
            sta   t2
            lda   [p1],y
            xba
            and   #$000F
            ora   KRO
            tax
            lda   QR,x
            ora   t2
            and   #$0007
            tax
            lda   QMapR,x
            and   #$00FF
            ora   Acc
            sta   Acc
            iny
            iny
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
            bcc   :pair
            jsr   StoreRow
            inc   RowY
            lda   RowY
            cmp   ROutH
            bcs   :jx1
            jmp   :row
:jx1
            ldx   #30                   ; the palette
:pal        lda   QuickPal,x
            and   #$0FFF
            sta   PalOut,x
            dex
            dex
            bpl   :pal
            ldx   #0
            jsr   PutTable
            jsr   FreePlanes
            lda   ROutW
            sta   rout_w
            lda   ROutH
            sta   rout_h
            stz   rout640
            clc
            rts

QThresh     dw    5,12,14,9

* QTables: Quick's tables for each threshold k (QThresh): QGB (k x 256 +
* green x 16 + blue: green 2, blue 1, if at least the threshold), QR (k x
* 16 + red: 4), and QMapL/QMapR: the 3 bits as the pixel (7: white, 15).
QTables     ldx   #0
:gb         txa                         ; (x: k x 256 + green x 16 + blue)
            xba
            and   #$0003
            asl
            tay
            lda   QThresh,y
            sta   t1
            stz   t2
            txa
            lsr
            lsr
            lsr
            lsr
            and   #$000F
            cmp   t1
            bcc   :b
            lda   #2
            sta   t2
:b          txa
            and   #$000F
            cmp   t1
            bcc   :gbs
            inc   t2
:gbs        lda   t2
            sep   #$20
            mx    %10
            sta   QGB,x
            rep   #$20
            mx    %00
            inx
            cpx   #1024
            bcc   :gb
            ldx   #0
:r          txa                         ; (x: k x 16 + red)
            lsr
            lsr
            lsr
            and   #$0006
            tay
            txa
            and   #$000F
            cmp   QThresh,y
            lda   #0
            bcc   :rs
            lda   #4
:rs         sep   #$20
            mx    %10
            sta   QR,x
            rep   #$20
            mx    %00
            inx
            cpx   #64
            bcc   :r
            ldx   #0
:m          txa
            cmp   #7
            bne   :ms
            lda   #15
:ms         sep   #$20
            mx    %10
            sta   QMapR,x
            asl
            asl
            asl
            asl
            sta   QMapL,x
            rep   #$20
            mx    %00
            inx
            cpx   #8
            bcc   :m
            rts
QuickPal    dw    $0000,$000F,$00F0,$00FF,$0F00,$0F0F,$0FF0,$8FFF
            dw    $8000,$0222,$0444,$0666,$0999,$0BBB,$0DDD,$0FFF

*-------------------------------------------------------------
* Stats: the true colour picture's distinct colours (as 12-bit colours,
* as GS Remap counts them), and whether they are all greys or only black
* and white. Counted once for each picture (tgen).
*-------------------------------------------------------------
Stats       lda   StDone
            beq   :count
            lda   tgen
            cmp   StGen
            bne   :count
            rts
:count      ldx   #4094                 ; a byte for each colour seen
            lda   #0
:z          sta   Hist,x
            dex
            dex
            bpl   :z
            stz   StDistinct
            lda   #1
            sta   StGrey
            sta   StBW
            stz   RowY
:row        lda   RowY
            ldx   tstride
            jsr   Mul16
            lda   tp
            clc
            adc   MLo
            sta   q0
            lda   tp+2
            adc   MHi
            sta   q0+2
            lda   rw
            sta   u1
            ldy   #0
:pix        lda   [q0],y                ; green and red
            and   #$F0F0
            lsr
            lsr
            lsr
            lsr
            sta   t1                    ; colour index: g << 8 | b << 4 | r
            iny
            iny
            lda   [q0],y                ; blue
            iny
            and   #$00F0
            ora   t1
            tax
            lda   Hist,x
            and   #$00FF
            bne   :next
            inc   Hist,x                ; (16 bits, but 0 to 1: the next byte stays)
            inc   StDistinct
            txa
            beq   :bw                   ; black and white: $000 and $FFF
            cmp   #$0FFF
            beq   :bw
            stz   StBW
:bw         lda   StGrey
            beq   :next
            txa                         ; grey: red = green = blue
            and   #$000F
            sta   t2
            txa
            lsr
            lsr
            lsr
            lsr
            and   #$000F
            cmp   t2
            bne   :notGrey
            txa
            xba
            and   #$000F
            cmp   t2
            beq   :next
:notGrey    stz   StGrey
:next       dec   u1
            bne   :pix
            inc   RowY
            lda   RowY
            cmp   rh
            bcc   :row
            lda   tgen
            sta   StGen
            lda   #1
            sta   StDone
            rts

StDone      dw    0
StGen       dw    0
StDistinct  dw    0
StGrey      dw    0
StBW        dw    0

*-------------------------------------------------------------
* The remap
*-------------------------------------------------------------
Remap       jsr   Normalise
            jsr   GetProto
            jsr   Sizes
            lda   OMode                 ; the picture at the output size (one
            cmp   #3                    ; palette: its colours counted too)
            beq   :mp
            lda   #1
            sta   PlHist
:mp         jsr   MakePlanes
            stz   PlHist
            bcc   :planes
            rts
:planes     jsr   ClearScreen
            lda   OMode
            cmp   #3
            bne   :single
            jsr   Multi
            bra   :done
:single     stz   LineA                 ; every line, one palette
            lda   ROutH
            sta   LineB
            jsr   CalcPalette           ; (Hist: MakePlanes')
            jsr   FreshCache
            jsr   RenderLines
            ldx   #0                    ; the palette as colour table 0
            jsr   PutTable
            lda   OMode                 ; 640 modes: SCB $80 on each line
            beq   :done
            ldx   ROutH
            ldy   #scbOffset
            sep   #$20
            mx    %10
            lda   #$80
:scb        sta   [scrp],y
            iny
            dex
            bne   :scb
            rep   #$20
            mx    %00
:done       jsr   FreePlanes
            lda   ROutW                  ; the result
            sta   rout_w
            lda   ROutH
            sta   rout_h
            stz   rout640
            lda   OMode
            cmp   #1
            beq   :w
            cmp   #2
            bne   :ok
:w          inc   rout640
:ok         clc
            rts

* ClearScreen: the whole screen picture to 0.
ClearScreen lda   #0
            ldy   #$7FFE
:z          sta   [scrp],y
            dey
            dey
            bpl   :z
            rts

* PutTable: PalOut (ProtoN entries) as colour table X/32, repeated to fill
* its 16 entries.
PutTable    txa
            asl
            asl
            asl
            asl
            asl
            clc
            adc   #palOffset
            tay
            ldx   #0
:e          phx
            txa                         ; entry (x / 2) mod ProtoN
            lsr
:mod        cmp   ProtoN
            bcc   :in
            sbc   ProtoN
            bra   :mod
:in         asl
            tax
            lda   PalOut,x
            and   #$0FFF
            sta   [scrp],y
            plx
            iny
            iny
            inx
            inx
            cpx   #32
            bcc   :e
            rts

*-------------------------------------------------------------
* 1. The picture at the output size: for each pixel its 12-bit colour
* (top nibbles of the averages) and its grey level, in a buffer:
* each line ROutW colour words, then ROutW grey bytes.
*-------------------------------------------------------------
MakePlanes  lda   PlHist                ; (counting: from nothing)
            beq   :nh
            ldx   #8190
            lda   #0
:hz         sta   Hist,x
            dex
            dex
            bpl   :hz
:nh
            lda   ROutW                  ; bytes a line
            asl
            clc
            adc   ROutW
            sta   PlRow
            ldx   ROutH
            jsr   Mul16
            lda   MLo                   ; (and a spare word)
            clc
            adc   #2
            sta   n0
            lda   MHi
            adc   #0
            sta   n0+2
            jsr   NewBig
            bcc   :fill
            rts
:fill       stz   GreyMade              ; the greys now only if the palette
            lda   #1                    ; is sure to be grey (else RenderLines
            sta   NoGrey                ; asks for them: MakeGrey)
            jsr   ProtoGrey
            bcs   PlaneFill
            stz   NoGrey
            inc   GreyMade

* PlaneFill: the planes' lines from the true colour picture (colours,
* counted into Hist if PlHist; greys unless NoGrey).
PlaneFill   stz   P50OK                 ; (XA3, XN: Reduce's tables go)
            lda   SrcW                  ; which source columns make each output one
            ldx   SpanW
            jsr   SpanStart
            ldx   #0
:col        phx
            jsr   SpanNext
            plx
            lda   SpanA
            asl
            clc
            adc   SpanA
            sta   XA3,x
            lda   SpanB
            sec
            sbc   SpanA
            sta   XN,x
            inx
            inx
            cpx   ROutW2
            bcc   :col
            stz   AllOne                ; every span across one pixel?
            ldx   #0
:a1         lda   XN,x
            cmp   #1
            bne   :unit
            inx
            inx
            cpx   ROutW2
            bcc   :a1
            inc   AllOne
:unit       stz   Unit                  ; 1:1?
            lda   SpanW
            cmp   SrcW
            bne   :rows
            lda   SpanH
            cmp   SrcH
            bne   :rows
            inc   Unit
:rows       lda   SrcH                  ; (the rows' spans, stepped too)
            ldx   SpanH
            jsr   SpanStart
            ldx   #SpCur-SpQ            ; (kept apart from the columns')
:sv         lda   SpQ,x
            sta   RowSp,x
            dex
            dex
            bpl   :sv
            lda   #$FFFF
            sta   PrevA
            stz   RowY
:row        jsr   ScaleRow               ; LineC, LineY
            lda   RowY                  ; store them
            jsr   PlaneRow
            ldy   #0
            lda   PlHist
            bne   :ch
:c          lda   LineC,y
            sta   [p1],y
            iny
            iny
            cpy   ROutW2
            bcc   :c
            bra   :grey
:ch         lda   LineC,y               ; (and counted, as HistLines does)
            sta   [p1],y
            asl
            tax
            lda   Hist,x
            inc
            beq   :full
            sta   Hist,x
:full       iny
            iny
            cpy   ROutW2
            bcc   :ch
:grey       lda   NoGrey
            bne   :nextRow
            ldx   #0                    ; (the greys two at a time: an odd
:g          lda   LineY+2,x             ; width writes a byte into the next
            xba                         ; line, stored after it, or into the
            ora   LineY,x               ; buffer's spare word)
            sta   [p1],y
            inx
            inx
            inx
            inx
            iny
            iny
            cpx   ROutW2
            bcc   :g
:nextRow    inc   RowY
            lda   RowY
            cmp   ROutH
            bcs   :rowsDone
            jmp   :row
:rowsDone   clc
            rts

* MakeGrey: the planes' greys, if they weren't made (the lines scaled
* again; the colours come out the same).
MakeGrey    lda   GreyMade
            bne   :done
            stz   NoGrey
            lda   PlHist
            pha
            stz   PlHist
            jsr   PlaneFill
            pla
            sta   PlHist
            inc   GreyMade
:done       rts

* ProtoGrey: carry clear if every prototype entry is reserved, or fixed
* and grey (the palette will be all grey).
ProtoGrey   ldx   #0
:e          lda   Proto,x
            bit   #$8000
            bne   :next
            bit   #$4000
            bne   :no
            phx
            jsr   IsGrey
            plx
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

* PlaneRow: p1 = line A of the planes buffer.
PlaneRow    ldx   PlRow
            jsr   Mul16
            lda   PlP
            clc
            adc   MLo
            sta   p1
            lda   PlP+2
            adc   MHi
            sta   p1+2
            rts

* GetLine: LineC = line A's colours times 2, from the planes (for the
* multipalette line costs).
GetLine     jsr   PlaneRow
            ldy   #0
:c          lda   [p1],y
            asl
            sta   LineC,y
            iny
            iny
            cpy   ROutW2
            bcc   :c
            rts

* NewBig: the planes buffer of n0 (long) bytes (it may cross banks).
NewBig      pha
            pha
            PushLongAt n0
            lda   uid
            pha
            pea   $C008
            PushLong 0
            Tool  _NewHandle
            tax
            pla
            sta   PlH
            pla
            sta   PlH+2
            txa
            bcs   :err
            lda   PlH
            sta   n1
            lda   PlH+2
            sta   n1+2
            lda   [n1]
            sta   PlP
            ldy   #2
            lda   [n1],y
            sta   PlP+2
            clc
:err        rts

FreePlanes  lda   PlH
            ora   PlH+2
            beq   :none
            PushLongAt PlH
            Tool  _DisposeHandle
            stz   PlH
            stz   PlH+2
:none       rts

* SpanStart: spans of A source pixels scaled to X: the first is output
* pixel 0's. SpanNext: SpanA up to SpanB of the next output pixel, as
* floor(i x src / out) and floor((i + 1) x src / out) (at least one
* pixel, at most to src), stepped: the quotient each time, and one more
* when the remainders add up to out.
SpanStart   sta   SpanSrc
            stx   SpanOut
            stz   SpQ                   ; src / out, src mod out
:q          cmp   SpanOut
            bcc   :r
            sbc   SpanOut
            inc   SpQ
            bra   :q
:r          sta   SpR
            stz   SpAcc
            stz   SpCur
            rts
SpanNext    lda   SpCur
            sta   SpanA
            clc
            adc   SpQ
            sta   SpCur
            lda   SpAcc
            clc
            adc   SpR
            cmp   SpanOut
            bcc   :acc
            sbc   SpanOut
            inc   SpCur
:acc        sta   SpAcc
            lda   SpCur
            cmp   SpanA
            bne   :ok
            inc
:ok         cmp   SpanSrc
            bcc   :in
            lda   SpanSrc
:in         sta   SpanB
            rts

* ScaleRow: LineC and LineY for output line RowY (box averages).
ScaleRow     ldx   #SpCur-SpQ            ; the row's span (its stepping state)
:ld         lda   RowSp,x
            sta   SpQ,x
            dex
            dex
            bpl   :ld
            lda   SrcH
            sta   SpanSrc
            lda   SpanH
            sta   SpanOut
            jsr   SpanNext
            ldx   #SpCur-SpQ
:st         lda   SpQ,x
            sta   RowSp,x
            dex
            dex
            bpl   :st
            lda   SpanB
            sec
            sbc   SpanA
            sta   RowN
            lda   SpanA                 ; the same source lines as the line
            cmp   PrevA                 ; before (enlarging): the same line
            bne   :new
            lda   RowN
            cmp   PrevN
            bne   :new
            rts
:new        lda   SpanA
            sta   PrevA
            lda   RowN
            sta   PrevN
            lda   SpanA                 ; q0 = its first source line
            ldx   tstride
            jsr   Mul16
            lda   tp
            clc
            adc   MLo
            sta   q0
            lda   tp+2
            adc   MHi
            sta   q0+2
            lda   Unit
            bne   :jx7
            jmp   :general
:jx7
            ldx   #0                    ; 1:1 (SetLine's sums, inline: t1 a
            ldy   #0                    ; channel, t2 the grey's sum, t3 the
            lda   NoGrey                ; colour so far; each ASL leaves the
            beq   :unit                 ; carry clear)
:unitC      lda   [q0],y                ; (colours only)
            and   #$00F0
            asl
            asl
            asl
            asl
            sta   t3
            iny
            lda   [q0],y
            and   #$00F0
            ora   t3
            sta   t3
            iny
            lda   [q0],y
            and   #$00F0
            lsr
            lsr
            lsr
            lsr
            ora   t3
            sta   LineC,x
            iny
            inx
            inx
            cpx   ROutW2
            bcc   :unitC
            rts
:unit       lda   [q0],y
            and   #$00FF
            sta   t1                    ; red
            asl
            asl
            adc   t1
            sta   t2
            lda   t1
            and   #$00F0
            asl
            asl
            asl
            asl
            sta   t3
            iny
            lda   [q0],y                ; green
            and   #$00FF
            sta   t1
            and   #$00F0
            ora   t3
            sta   t3
            lda   t1
            asl
            asl
            asl
            adc   t2
            sta   t2
            iny
            lda   [q0],y                ; blue
            and   #$00FF
            sta   t1
            lsr
            lsr
            lsr
            lsr
            ora   t3
            sta   LineC,x
            lda   t1
            asl
            adc   t1
            adc   t2
            lsr
            lsr
            lsr
            lsr
            sta   LineY,x
            iny
            inx
            inx
            cpx   ROutW2
            bcc   :unit
            rts
:general    stz   LastXN                ; (no box size known for this row)
            lda   RowN                  ; one source line and one pixel for
            cmp   #1                    ; each: the quicker loop
            bne   :gen
            lda   AllOne
            beq   :gen
            jmp   :wide
:gen        ldx   #0
:pix        stx   PixX
            lda   RowN                  ; one source pixel: read, or the same as
            cmp   #1                    ; the column before's
            beq   :jx4
            jmp   :box
:jx4
            lda   XN,x
            cmp   #1
            beq   :jx8
            jmp   :box
:jx8
            cpx   #0
            beq   :one
            lda   XN-2,x
            cmp   #1
            bne   :one
            lda   XA3,x
            cmp   XA3-2,x
            bne   :one
            lda   LineC-2,x
            sta   LineC,x
            lda   LineY-2,x
            sta   LineY,x
            jmp   :nextPix
:one        ldy   XA3,x                 ; (SetLine inline, as at 1:1)
            lda   NoGrey
            bne   :oC
            lda   [q0],y
            and   #$00FF
            sta   t1                    ; red
            asl
            asl
            adc   t1
            sta   t2
            lda   t1
            and   #$00F0
            asl
            asl
            asl
            asl
            sta   t3
            iny
            lda   [q0],y                ; green
            and   #$00FF
            sta   t1
            and   #$00F0
            ora   t3
            sta   t3
            lda   t1
            asl
            asl
            asl
            adc   t2
            sta   t2
            iny
            lda   [q0],y                ; blue
            and   #$00FF
            sta   t1
            lsr
            lsr
            lsr
            lsr
            ora   t3
            sta   LineC,x
            lda   t1
            asl
            adc   t1
            adc   t2
            lsr
            lsr
            lsr
            lsr
            sta   LineY,x
            jmp   :nextPix
:oC         lda   [q0],y                ; (colours only)
            and   #$00F0
            asl
            asl
            asl
            asl
            sta   t3
            iny
            lda   [q0],y
            and   #$00F0
            ora   t3
            sta   t3
            iny
            lda   [q0],y
            and   #$00F0
            lsr
            lsr
            lsr
            lsr
            ora   t3
            sta   LineC,x
            jmp   :nextPix
:box        lda   RowN                  ; one source line, at most 257
            cmp   #1                    ; pixels: the sums fit 16 bits
            beq   :jx2
            jmp   :box32
:jx2
            lda   XN,x
            cmp   #258
            bcc   :jx3
            jmp   :box32
:jx3
            sta   u2
            cmp   LastXN
            beq   :k1
            sta   LastXN
            sta   Divisor
            jsr   DivWay
:k1         ldy   XA3,x
            stz   SumR
            stz   SumG
            stz   SumB
:sp         lda   [q0],y
            and   #$00FF
            clc
            adc   SumR
            sta   SumR
            iny
            lda   [q0],y
            and   #$00FF
            clc
            adc   SumG
            sta   SumG
            iny
            lda   [q0],y
            and   #$00FF
            clc
            adc   SumB
            sta   SumB
            iny
            dec   u2
            bne   :sp
            lda   DMeth                 ; a power of two: the shifts here
            cmp   #1
            beq   :sh1
            jmp   :known                ; (Avg: X unused below 258)
:sh1        lda   SumR
            ldx   DShift
:shr        lsr
            dex
            bne   :shr
            sta   CR
            lda   SumG
            ldx   DShift
:shg        lsr
            dex
            bne   :shg
            sta   CG
            lda   SumB
            ldx   DShift
:shb        lsr
            dex
            bne   :shb
            sta   CB
            ldx   PixX
            jsr   SetLine
            jmp   :nextPix
:box32
            stz   SumR
            stz   SumR+2
            stz   SumG
            stz   SumG+2
            stz   SumB
            stz   SumB+2
            lda   q0
            sta   q1
            lda   q0+2
            sta   q1+2
            lda   RowN
            sta   u1
:srcRow     ldx   PixX
            lda   XN,x
            sta   u2
            ldy   XA3,x
:srcPix     lda   [q1],y
            and   #$00FF
            clc
            adc   SumR
            sta   SumR
            bcc   :r
            inc   SumR+2
:r          iny
            lda   [q1],y
            and   #$00FF
            clc
            adc   SumG
            sta   SumG
            bcc   :g
            inc   SumG+2
:g          iny
            lda   [q1],y
            and   #$00FF
            clc
            adc   SumB
            sta   SumB
            bcc   :b
            inc   SumB+2
:b          iny
            dec   u2
            bne   :srcPix
            lda   q1
            clc
            adc   tstride
            sta   q1
            lda   q1+2
            adc   #0
            sta   q1+2
            dec   u1
            bne   :srcRow
            ldx   PixX                  ; divide by the pixel count (its
            lda   XN,x                  ; quickest exact way, worked out
            cmp   LastXN                ; again only when the count changes)
            beq   :known
            sta   LastXN
            ldx   RowN
            jsr   Mul16
            lda   MLo
            sta   Divisor
            jsr   DivWay
:known      lda   SumR
            ldx   SumR+2
            jsr   Avg
            sta   CR
            lda   SumG
            ldx   SumG+2
            jsr   Avg
            sta   CG
            lda   SumB
            ldx   SumB+2
            jsr   Avg
            sta   CB
            ldx   PixX
            jsr   SetLine
:nextPix    inx
            inx
            cpx   ROutW2
            bcs   :done
            jmp   :pix
:done       rts

:wide       ldx   #0                    ; (each pixel the column before's if
            bra   :wNew                 ; its source is the same)
:wLoop      lda   XA3,x
            cmp   XA3-2,x
            bne   :wNew
            lda   LineC-2,x
            sta   LineC,x
            lda   LineY-2,x
            sta   LineY,x
            bra   :wNext
:wNew       ldy   XA3,x
            lda   NoGrey
            bne   :wC
            lda   [q0],y
            and   #$00FF
            sta   t1                    ; red
            asl
            asl
            adc   t1
            sta   t2
            lda   t1
            and   #$00F0
            asl
            asl
            asl
            asl
            sta   t3
            iny
            lda   [q0],y                ; green
            and   #$00FF
            sta   t1
            and   #$00F0
            ora   t3
            sta   t3
            lda   t1
            asl
            asl
            asl
            adc   t2
            sta   t2
            iny
            lda   [q0],y                ; blue
            and   #$00FF
            sta   t1
            lsr
            lsr
            lsr
            lsr
            ora   t3
            sta   LineC,x
            lda   t1
            asl
            adc   t1
            adc   t2
            lsr
            lsr
            lsr
            lsr
            sta   LineY,x
            bra   :wNext
:wC         lda   [q0],y                ; (colours only)
            and   #$00F0
            asl
            asl
            asl
            asl
            sta   t3
            iny
            lda   [q0],y
            and   #$00F0
            ora   t3
            sta   t3
            iny
            lda   [q0],y
            and   #$00F0
            lsr
            lsr
            lsr
            lsr
            ora   t3
            sta   LineC,x
:wNext      inx
            inx
            cpx   ROutW2
            bcs   :jx9
            jmp   :wLoop
:jx9
            rts

* DivWay: how to divide by Divisor: DMeth 0 not at all (1), 1 a shift
* right by DShift (a power of two up to 256), 2 a 16-bit division (up to
* 257: the sums fit 16 bits), 3 DivAvg.
DivWay      lda   Divisor
            cmp   #1
            bne   :n1
            stz   DMeth
            rts
:n1         cmp   #258
            bcs   :big
            stz   DShift                ; a power of two?
:p          inc   DShift
            lsr
            bcc   :p
            bne   :d16                  ; (other bits: no)
            dec   DShift                ; (the shifts before the bit)
            lda   #1
            sta   DMeth
            rts
:d16        lda   Divisor               ; (x 128: eight rounds)
            asl
            asl
            asl
            asl
            asl
            asl
            asl
            sta   DD16
            lda   #2
            sta   DMeth
            rts
:big        lda   #3
            sta   DMeth
            rts

* Avg: (X:A) / Divisor (the answer below 256), DivWay's way.
Avg         ldy   DMeth
            bne   :n0
            rts
:n0         cpy   #1
            bne   :n2
            ldy   DShift
:s          lsr
            dey
            bne   :s
            rts
:n2         cpy   #2
            bne   :n3
            sta   DvLo                  ; eight rounds in 16 bits
            lda   DD16
            sta   DdLo
            stz   DvQ2
            ldx   #8
:b          asl   DvQ2
            lda   DvLo
            sec
            sbc   DdLo
            bcc   :no
            sta   DvLo
            inc   DvQ2
:no         lsr   DdLo
            dex
            bne   :b
            lda   DvQ2
            rts
:n3         jmp   DivAvg

* DivAvg: (X:A) / Divisor, when the answer is below 256.
DivAvg      sta   DvLo
            stx   DvHi
            lda   Divisor
            cmp   #1
            bne   :div
            lda   DvLo
            rts
:div        sta   DdLo                  ; divisor * 128
            stz   DdHi
            ldx   #7
:sh         asl   DdLo
            rol   DdHi
            dex
            bne   :sh
            stz   DvQ2
            ldx   #8
:bit        asl   DvQ2
            lda   DvLo
            sec
            sbc   DdLo
            tay
            lda   DvHi
            sbc   DdHi
            bcc   :no
            sta   DvHi
            sty   DvLo
            inc   DvQ2
:no         lsr   DdHi
            ror   DdLo
            dex
            bne   :bit
            lda   DvQ2
            rts

* SetLine: LineC and LineY at X from CR, CG, CB (0-255). Keeps X.
SetLine     lda   CR
            and   #$00F0
            asl
            asl
            asl
            asl
            sta   t1
            lda   CG
            and   #$00F0
            ora   t1
            sta   t1
            lda   CB
            lsr
            lsr
            lsr
            lsr
            ora   t1
            sta   LineC,x
            lda   CR                    ; (5R + 8G + 3B) / 16
            asl
            asl
            clc
            adc   CR
            sta   t1
            lda   CG
            asl
            asl
            asl
            clc
            adc   t1
            sta   t1
            lda   CB
            asl
            clc
            adc   CB
            clc
            adc   t1
            lsr
            lsr
            lsr
            lsr
            sta   LineY,x
            rts

*-------------------------------------------------------------
* 2. Histogram and palette
*-------------------------------------------------------------

* HistLines: Hist = the colours of lines LineA to LineB - 1 (with owner
* MPOwn, in multipalette; LineA = 0 and LineB = ROutH otherwise).
HistLines   ldx   #8190
            lda   #0
:clear      sta   Hist,x
            dex
            dex
            bpl   :clear
            lda   LineA
            sta   RowY
:row        lda   RowY
            cmp   LineB
            bcs   :done
            lda   OMode                 ; multipalette: only the palette's own lines
            cmp   #3
            bne   :take
            lda   RowY
            asl
            tax
            lda   Owner,x
            cmp   MPOwn
            bne   :next
:take       lda   RowY                  ; (the planes read in place)
            jsr   PlaneRow
            ldy   #0
:pix        lda   [p1],y
            asl
            tax
            lda   Hist,x
            inc
            beq   :full                 ; stays at $FFFF
            sta   Hist,x
:full       iny
            iny
            cpy   ROutW2
            bcc   :pix
:next       inc   RowY
            bra   :row
:done       rts

* CalcPalette: the calculated slots of Proto (ProtoN entries) filled in
* from Hist (which it changes), into PalOut.
CalcPalette ldx   #30                   ; working copy of the prototype
:copy       lda   Proto,x
            sta   PW,x
            dex
            dex
            bpl   :copy
            lda   ProtoN                ; 640 dither: black and white are shared
            cmp   #8                    ; by the two halves
            bne   :count0
            ldx   #0
            ldy   #8
            jsr   Merge
            ldx   #6
            ldy   #14
            jsr   Merge
:count0     stz   NChosen
            ldx   #0                    ; the colours in use, listed (CList:
            ldy   #0                    ; colour x 2, in order; their counts
:count      lda   Hist,x                ; only fall to 0 from here on, never
            beq   :zero                 ; rise from it): Distinct of them
            txa
            sta   CList,y
            iny
            iny
:zero       inx
            inx
            cpx   #8192
            bcc   :count
            sty   NList
            tya
            lsr
            sta   Distinct
            stz   FreeSlots             ; calculated slots; fixed colours leave
            ldx   #0                    ; the histogram
:slots      lda   PW,x
            bit   #$8000
            bne   :nextSlot
            bit   #$4000
            beq   :fixed
            inc   FreeSlots
            bra   :nextSlot
:fixed      and   #$0FFF
            asl
            tay
            lda   Hist,y
            beq   :nextSlot
            dec   Distinct
            lda   #0
            sta   Hist,y
:nextSlot   inx
            inx
            txa
            lsr
            cmp   ProtoN
            bcc   :slots
            lda   FreeSlots
            bne   :pick
            jmp   :assign
:pick       cmp   Distinct
            bcc   :popular
            stz   ListI                 ; room for every colour: take them all
:all        ldy   ListI
            cpy   NList
            bcs   :allDone
            ldx   CList,y
            lda   Hist,x
            beq   :allNext
            lda   NChosen
            cmp   #16
            bcs   :allNext
            asl
            tay
            txa
            lsr
            sta   Chosen,y
            inc   NChosen
:allNext    inc   ListI
            inc   ListI
            bra   :all
:allDone    jmp   :assign
:popular    jsr   ArgMax                ; Peak = largest count
            lda   Peak
            lsr
            lsr
            lsr
            sta   PeakEighth
            jsr   BiasTab               ; (dist x peak / 9 for each distance)
            jsr   P50Tabs               ; (and Reduce's tables)
            lda   #$0777                ; (distances from mid grey)
            jsr   DistSet
            stz   ListI                 ; favour colours far from mid grey:
:bias       ldy   ListI                 ; count += peak/8 + dist(c,$777)*peak/9
            cpy   NList
            bcs   :biasDone
            ldx   CList,y
            lda   Hist,x
            beq   :biasNext
            stx   BiasX
            txa
            lsr
            jsr   DistTo
            asl
            tay
            ldx   BiasX
            lda   Hist,x
            clc
            adc   PeakEighth
            bcs   :sat
            clc
            adc   BiasT,y               ; ($FFFF above 16 bits: saturates too,
            bcc   :store                ; as the count is at least 1)
:sat        lda   #$FFFF
:store      sta   Hist,x
:biasNext   inc   ListI
            inc   ListI
            bra   :bias
:biasDone
            ldx   #0                    ; fixed colours push their neighbours down
:fixRed     lda   PW,x
            bit   #$C000
            bne   :fixRedNext
            stx   SlotX
            jsr   Reduce
            ldx   SlotX
:fixRedNext inx
            inx
            txa
            lsr
            cmp   ProtoN
            bcc   :fixRed
            lda   FreeSlots
            sta   Remaining
:choose     lda   Remaining
            beq   :assign
            dec   Remaining
            lda   NChosen
            cmp   #16
            bcs   :assign
            jsr   ArgMax
            lda   Peak
            beq   :assign
            lda   PeakIndex
            jsr   Reduce
            lda   PeakIndex
            asl
            tax
            stz   Hist,x
            lda   NChosen
            asl
            tay
            lda   PeakIndex
            sta   Chosen,y
            inc   NChosen
            bra   :choose

* A chosen colour that equals a calculated slot's default keeps that slot.
:assign     stz   ChosenK
:match      lda   ChosenK
            cmp   NChosen
            bcs   :fill
            asl
            tay
            lda   Chosen,y
            ora   #$4000
            sta   t0
            ldx   #0
:mSlot      lda   PW,x
            cmp   t0
            beq   :matched
            inx
            inx
            txa
            lsr
            cmp   ProtoN
            bcc   :mSlot
            inc   ChosenK
            bra   :match
:matched    lda   Chosen,y
            sta   PW,x
            jsr   RemoveChosen          ; Y = index * 2 of the one to drop
            bra   :match

* Remaining calculated slots take the remaining colours, darkest first.
:fill       ldx   #0
:fSlot      lda   PW,x
            and   #$C000
            cmp   #$4000
            bne   :fOut
            lda   PW,x
            and   #$0FFF
            sta   PW,x
            lda   NChosen
            beq   :fOut
            stx   SlotX
            lda   #1000                 ; find the darkest
            sta   BestBright
            ldy   #0
:dark       lda   Chosen,y
            cmp   PW,x
            bne   :bright
            lda   #0
            bra   :cmp
:bright     jsr   Brightness
:cmp        cmp   BestBright
            bcs   :darkNext
            sta   BestBright
            sty   BestY
:darkNext   iny
            iny
            tya
            lsr
            cmp   NChosen
            bcc   :dark
            ldy   BestY
            lda   Chosen,y
            ldx   SlotX
            sta   PW,x
            jsr   RemoveChosen
            ldx   SlotX
:fOut       lda   PW,x
            sta   PalOut,x
            inx
            inx
            txa
            lsr
            cmp   ProtoN
            bcc   :fSlot
            lda   ProtoN                ; 640 dither: the shared ones
            cmp   #8
            bne   :done
            lda   PalOut+8
            cmp   #$FFFF
            bne   :w4
            lda   PalOut
            sta   PalOut+8
:w4         lda   PalOut+14
            cmp   #$FFFF
            bne   :done
            lda   PalOut+6
            sta   PalOut+14
:done       rts

* Merge: slots X and Y (times 2) of Work: a fixed colour is shared; two
* calculated ones become one ($FFFF: filled in from the first afterwards).
Merge       lda   PW,x
            and   #$C000
            sta   t1
            lda   PW,y
            and   #$C000
            sta   t2
            lda   t1
            bne   :aCalc
            lda   t2                    ; fixed and calculated: both fixed
            cmp   #$4000
            bne   :done
            lda   PW,x
            sta   PW,y
            rts
:aCalc      cmp   #$4000
            bne   :done
            lda   t2
            bne   :both
            lda   PW,y                ; calculated and fixed: the fixed one first
            sta   PW,x
            lda   #$FFFF
            sta   PW,y
            rts
:both       cmp   #$4000
            bne   :done
            lda   #$FFFF
            sta   PW,y
:done       rts

* RemoveChosen: drops Chosen[Y/2] by moving the last one into its place.
RemoveChosen dec  NChosen
            lda   NChosen
            asl
            tax
            lda   Chosen,x
            sta   Chosen,y
            rts

* ArgMax: Peak = largest count, PeakIndex = its colour (first one wins;
* the colours CalcPalette listed).
ArgMax      stz   Peak
            stz   PeakIndex
            ldy   #0
:scan       cpy   NList
            bcs   :done
            ldx   CList,y
            lda   Hist,x
            cmp   Peak
            beq   :next
            bcc   :next
            sta   Peak
            txa
            lsr
            sta   PeakIndex
:next       iny
            iny
            bra   :scan
:done       rts

* Reduce: colours within distance 50 of colour A have their count
* scaled by distance/50 (but never below 1).
Reduce      and   #$0FFF
            jsr   DistSet               ; (distances from it)
            stz   ListR
:scan       ldy   ListR                 ; (the colours CalcPalette listed)
            cpy   NList
            bcc   :jx5
            jmp   :done
:jx5
            ldx   CList,y
            lda   Hist,x
            bne   :jx6
            jmp   :next
:jx6
            stx   RedX
            txa
            lsr
            jsr   DistTo
            cmp   #50
            bcs   :restore
            sta   RedD                  ; count * d / 50, with count = 50a + b:
            ldx   RedX                  ; a x d + b x d / 50 (T50); count =
            lda   Hist,x                ; 256h + l = 50 x 5h + v, v = 6h + l:
            xba                         ; a = 5h + v / 50 (TQ), b = v mod 50
            and   #$00FF
            sta   t1                    ; h
            asl
            adc   t1
            asl
            sta   t2                    ; 6h
            lda   Hist,x
            and   #$00FF
            clc
            adc   t2
            sta   RedV                  ; v
            tay
            lda   TQ,y
            and   #$00FF
            sta   t2                    ; v / 50
            asl                         ; b = v - 50 (v / 50)
            sta   t0
            asl
            asl
            asl
            clc
            adc   t0
            sta   t0                    ; 18 q
            lda   t2
            asl
            asl
            asl
            asl
            asl
            clc
            adc   t0                    ; 50 q
            eor   #$FFFF
            sec
            adc   RedV
            asl                         ; T50: b x 64 + d
            asl
            asl
            asl
            asl
            asl
            ora   RedD
            sta   RedV
            lda   t1                    ; a = 5h + v / 50
            asl
            asl
            adc   t1
            clc
            adc   t2
            ldx   RedD
            jsr   Mul16
            ldy   RedV
            lda   T50,y
            and   #$00FF
            clc
            adc   MLo
            bne   :put
            lda   #1
:put        ldx   RedX
            sta   Hist,x
:restore
:next       inc   ListR
            inc   ListR
            jmp   :scan
:done       rts

* BiasTab: BiasT = d x Peak / 9 for each distance d (0-90; the largest
* from $777), $FFFF where it needs more than 16 bits.
BiasTab     lda   Peak
            sta   n0
            stz   n0+2
            lda   #9
            jsr   Div32                 ; Peak / 9, remainder in DvR
            stz   BqLo
            stz   BqHi
            stz   BqR
            ldx   #0
:d          lda   BqLo
            ldy   BqHi
            beq   :put
            lda   #$FFFF
:put        sta   BiasT,x
            lda   BqLo                  ; + Peak / 9
            clc
            adc   DvQ
            sta   BqLo
            bcc   :r
            inc   BqHi
:r          lda   BqR                   ; + its remainder (one more at 9)
            clc
            adc   DvR
            cmp   #9
            bcc   :rs
            sbc   #9
            inc   BqLo
            bne   :rs
            inc   BqHi
:rs         sta   BqR
            inx
            inx
            cpx   #182
            bcc   :d
            rts

* P50Tabs: Reduce's tables, made once after the planes (they share
* XA3 to Nxt, idle while palettes are calculated): TQ (v / 50 for v up
* to 1785) and T50 (b x d / 50 at b x 64 + d, both below 50).
P50Tabs     lda   P50OK
            beq   :make
            rts
:make       ldx   #0
            ldy   #0                    ; (the quotient)
            stz   t1                    ; (the remainder)
:q          tya
            sep   #$20
            mx    %10
            sta   TQ,x
            rep   #$20
            mx    %00
            inc   t1
            lda   t1
            cmp   #50
            bcc   :qn
            stz   t1
            iny
:qn         inx
            cpx   #1786
            bcc   :q
            stz   t2                    ; b
:b          lda   t2
            asl
            asl
            asl
            asl
            asl
            asl
            tax
            stz   t0                    ; b x d / 50 and its remainder
            stz   t1
            ldy   #50
:d          lda   t0
            sep   #$20
            mx    %10
            sta   T50,x
            rep   #$20
            mx    %00
            inx
            lda   t1
            clc
            adc   t2
            cmp   #50
            bcc   :ds
            sbc   #50
            inc   t0
:ds         sta   t1
            dey
            bne   :d
            inc   t2
            lda   t2
            cmp   #50
            bcc   :b
            inc   P50OK
            rts

* Distances between colours: a = 3 dR, b = 4 dG, c = 2 dB;
*   |a| + |b| + |c| + |a+b+c| / 4
* DistSet: the colour in A as the one Dist is measured from (its 3 R,
* 4 G, 2 B). DistTo: Dist between it and the colour in A, the same
* (|-x| = |x|). Keeps Y.
DistSet     sta   DT
            xba
            and   #$000F
            asl
            tax
            lda   W3R,x
            sta   FA
            lda   DT
            lsr
            lsr
            lsr
            lsr
            and   #$000F
            asl
            tax
            lda   W4G,x
            sta   FB
            lda   DT
            and   #$000F
            asl
            sta   FC
            rts
DistTo      sta   DT
            xba
            and   #$000F
            asl
            tax
            lda   W3R,x                 ; a
            sec
            sbc   FA
            sta   DA
            bpl   :a
            eor   #$FFFF
            inc
:a          sta   DS
            lda   DT                    ; b
            lsr
            lsr
            lsr
            lsr
            and   #$000F
            asl
            tax
            lda   W4G,x
            sec
            sbc   FB
            sta   DB
            bpl   :b
            eor   #$FFFF
            inc
:b          clc
            adc   DS
            sta   DS
            lda   DT                    ; c
            and   #$000F
            asl
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

W3R         dw    0,3,6,9,12,15,18,21,24,27,30,33,36,39,42,45
W4G         dw    0,4,8,12,16,20,24,28,32,36,40,44,48,52,56,60

* Abs: |A| (A just loaded or computed, so N is A's sign).
Abs         bpl   :pos
            eor   #$FFFF
            inc
:pos        rts

* Brightness: 5 R + 8 G + 3 B of the colour in A.
Brightness  sta   t1
            xba
            and   #$000F
            sta   t2
            asl
            asl
            clc
            adc   t2
            sta   t3
            lda   t1
            lsr
            lsr
            lsr
            lsr
            and   #$000F
            asl
            asl
            asl
            clc
            adc   t3
            sta   t3
            lda   t1
            and   #$000F
            sta   t2
            asl
            clc
            adc   t2
            clc
            adc   t3
            rts

    put   RemapRender.s
    put   RemapUI.s
    put   UILib.s
    put   SegLib.s
