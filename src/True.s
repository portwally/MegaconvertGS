*-------------------------------------------------------------
* True.s - true colour pictures
*
* Pictures with more colours or pixels than the screen can show
* (PNG, GIF, JPEG, BMP...) are kept as 24-bit RGB, row by row,
* in one block that may cross banks. Remap then scales them to
* fit the screen, as GS Remap's "fit to screen" does: the largest
* of its scale steps up to 1:1 that fits, with box averaging.
*-------------------------------------------------------------

* DecodeTrue: recognises and decodes a true colour format.
*   out: carry clear, A = format; or carry set, A = error
*        (A = 0: not one of these formats)
DecodeTrue  stz   n0
            stz   n0+2
            jsr   StreamAt
            jsr   GetBE16
            cmp   #$424D                ; "BM"
            beq   :bmp
            cmp   #$FFD8
            beq   :jpeg
            cmp   #$4749                ; "GI" "F8"
            beq   :gif
            cmp   #$8950                ; $89 "PNG"
            beq   :png
            lda   #0
            sec
            rts
:bmp        jsr   DecodeBMP
            ldx   #fmtBMP
            bra   :result
:jpeg       jsr   DecodeJPEG
            ldx   #fmtJPEG
            bra   :result
:gif        jsr   GetBE16
            cmp   #$4638
            bne   :not
            jsr   DecodeGIF
            ldx   #fmtGIF
            bra   :result
:png        jsr   GetBE16
            cmp   #$4E47
            bne   :not
            jsr   DecodePNG
            ldx   #fmtPNG
:result     bcc   :ok
            pha
            jsr   FreeTrue
            pla
            bne   :err
            lda   #errCorrupt
:err        sec
            rts
:ok         txa
            clc
            rts
:not        lda   #0
            sec
            rts

* NewTrue: a white picture of TrueW x TrueH pixels.
*   out: carry clear, or carry set and A = error
NewTrue     jsr   FreeTrue
            lda   TrueW
            beq   :bad
            cmp   #4097
            bcs   :big
            lda   TrueH
            beq   :bad
            cmp   #4097
            bcs   :big
            lda   TrueW
            asl
            clc
            adc   TrueW
            sta   TrueStride
            ldx   TrueH
            jsr   Mul16
            lda   ProdLo
            sta   n0
            sta   TrueSize
            lda   ProdHi
            sta   n0+2
            sta   TrueSize+2
            jsr   NewBig
            bcs   :err
            lda   n1
            sta   TrueHnd
            lda   n1+2
            sta   TrueHnd+2
            lda   p0
            sta   TrueP
            lda   p0+2
            sta   TrueP+2
            lda   NoFill                ; (a screen picture writes every byte)
            bne   :filled
            lda   TrueFill              ; white, or black for the loader segments
            jsr   FillBig
:filled
            lda   #1
            sta   IsTrue
            inc   TrueGen               ; (the Remap dialog counts its colours once)
            clc
            rts
:bad        lda   #errCorrupt
            sec
:err        rts
:big        lda   #errTooBig
            sec
            rts

TrueGen     dw    0

* NewTrueL: NewTrue for the loader segments (JSL). A = width, X = height,
* ttall = 1 for pixels twice as tall as wide (half as many across on screen).
*   out: carry clear, tp and tstride set; or carry set and A = error
NewTrueL    ent
            phb
            phk
            plb
            sta   TrueW
            stx   TrueH
            stz   TrueFill              ; GS Remap's pictures start black
            jsr   NewTrue
            ldx   #$FF
            stx   TrueFill
            bcs   :out
            lda   ttall
            sta   TrueTall
            lda   TrueP
            sta   tp
            lda   TrueP+2
            sta   tp+2
            lda   TrueStride
            sta   tstride
            clc
:out        plb
            rtl

* FreeTrue: forgets the true colour picture.
FreeTrue    stz   TrueTall
            stz   IsTrue
            lda   TrueHnd
            ora   TrueHnd+2
            beq   :none
            PushLongAt TrueHnd
            Tool  _DisposeHandle
            stz   TrueHnd
            stz   TrueHnd+2
:none       rts

* NewBig: like NewBuffer, but the block may cross banks.
*   in:  n0 = size;  out: carry clear, n1 = handle, p0 = pointer
NewBig      pha
            pha
            PushLongAt n0
            lda   UserID
            pha
            pea   attrFile
            PushLong 0
            Tool  _NewHandle
            tax
            pla
            sta   n1
            pla
            sta   n1+2
            txa
            bcs   :err
            lda   n1
            sta   p0
            lda   n1+2
            sta   p0+2
            lda   [p0]
            tax
            ldy   #2
            lda   [p0],y
            sta   p0+2
            stx   p0
            clc
:err        rts

* FreeHandleAt: disposes of the handle at address X (in this bank), if any.
FreeHandleAt lda  |2,x                  ; (| : absolute, not direct page)
            ora   |0,x
            beq   :none
            lda   |2,x
            pha
            lda   |0,x
            pha
            stz   |0,x
            stz   |2,x
            Tool  _DisposeHandle
:none       rts

* FillBig: fills n0 (long) bytes at p0 with the byte in A.
FillBig     sta   FillVal
            lda   p0
            sta   q1
            lda   p0+2
            sta   q1+2
:chunk      lda   n0+2
            bne   :full
            lda   n0
            beq   :done
            cmp   #$8000
            bcc   :part
:full       lda   #$8000
:part       sta   u0
            and   #$FFFE                ; two bytes at a time, then the odd
            sta   FillE                 ; one alone
            lda   FillVal
            and   #$00FF
            sta   FillW
            xba
            ora   FillW
            ldy   #0
            cpy   FillE
            bcs   :odd
:loop       sta   [q1],y
            iny
            iny
            cpy   FillE
            bcc   :loop
:odd        cpy   u0
            bcs   :filled
            sep   #$20
            mx    %10
            sta   [q1],y
            rep   #$20
            mx    %00
:filled
            lda   q1
            clc
            adc   u0
            sta   q1
            lda   q1+2
            adc   #0
            sta   q1+2
            lda   n0
            sec
            sbc   u0
            sta   n0
            lda   n0+2
            sbc   #0
            sta   n0+2
            bra   :chunk
:done       rts

* TrueRowAt: q0 = start of row A of the true colour picture.
TrueRowAt   ldx   TrueStride
            jsr   Mul16
            lda   TrueP
            clc
            adc   ProdLo
            sta   q0
            lda   TrueP+2
            adc   ProdHi
            sta   q0+2
            rts

* SmoothRow: line SY of the 640 mode screen image, smoothed, into the true
* colour row at q0 (MonoSeg.s SmoothLine).
SmoothRow   lda   SY
            jsr   Times160T
            clc
            adc   ScreenP
            sta   dctl
            lda   ScreenP+2
            adc   #0
            sta   dctl+2
            lda   SY
            clc
            adc   #scbOffset
            tay
            lda   [p2],y
            and   #$00FF
            sta   darg
            lda   PicW
            sta   dact
            lda   ScreenP
            sta   scrp
            lda   ScreenP+2
            sta   scrp+2
            jsl   SmoothLine
            rts

* Times160T: A x 160.
Times160T   asl
            asl
            asl
            asl
            asl
            sta   u3
            asl
            asl
            clc
            adc   u3
            rts

Smooth      dw    0                     ; this conversion is smoothed
TestSmooth  dw    0                     ; (tests: SMOOTH n)

* PutIdx: stores palette entry A (Pal) as the pixel at [q0],y; y += 3.
PutIdx      sta   u3
            asl
            clc
            adc   u3
            tax
            sep   #$20
            mx    %10
            lda   Pal,x
            sta   [q0],y
            iny
            lda   Pal+1,x
            sta   [q0],y
            iny
            lda   Pal+2,x
            sta   [q0],y
            iny
            rep   #$20
            mx    %00
            rts

* ClearPal: all 256 palette entries black, all opaque.
ClearPal    ldx   #766
:rgb        stz   Pal,x
            dex
            dex
            bpl   :rgb
            ldx   #510
            lda   #255
:alpha      sta   PalA,x
            dex
            dex
            bpl   :alpha
            rts

*-------------------------------------------------------------
* A screen picture as a true colour one (what Remap starts from)
*-------------------------------------------------------------

* ScreenToTrue: the true colour picture = the screen picture (PicW x PicH,
* its pixels twice as tall in 640 mode), each colour's channels times 17.
ScreenToTrue stz  Smooth                ; a 640 mode screen: Exact or
            lda   Pic640                ; Smoothed (the window; tests choose
            beq   :exact                ; with SMOOTH)
            lda   TestMode
            beq   :ask
            lda   TestSmooth            ; (SMOOTH 2: the window, in a test)
            cmp   #2
            bcc   :choice
:ask        jsl   Dlg640
            bcc   :choice
            lda   #$FFFF                ; (cancelled)
            rts
:choice     sta   Smooth
:exact      lda   #2                    ; (a new true colour image: no
            jsl   DeskSelClear          ; selection)
            lda   PicW
            sta   TrueW
            lda   PicH
            sta   TrueH
            lda   #1
            sta   NoFill
            jsr   NewTrue
            stz   NoFill
            bcc   :ok
            rts
:ok         lda   Pic640
            sta   TrueTall
            lda   ScreenP
            sta   p2
            lda   ScreenP+2
            sta   p2+2
            stz   SY
:row        lda   SY
            jsr   TrueRowAt
            lda   Smooth                ; smoothed: the whole line at once
            beq   :exactRow
            jsr   SmoothRow
            jmp   :jx1
:exactRow
            lda   SY                    ; the line's SCB: colour table, mode
            clc
            adc   #scbOffset
            tay
            lda   [p2],y
            and   #$00FF
            sta   SScb
            and   #$000F
            asl
            asl
            asl
            asl
            asl
            clc
            adc   #palOffset
            sta   STab
            lda   SY                    ; the line's bytes
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
            sta   SRow
            stz   SX
            ldy   #0
            lda   SScb                  ; the line's mode the picture's: its
            and   #$0080                ; whole bytes through FastLine
            beq   :c320
            lda   Pic640
            beq   :pix
            bra   :fast
:c320       lda   Pic640
            bne   :pix
:fast       jsr   FastLine
            lda   SX
            cmp   PicW
            bcc   :pix
            jmp   :jx1
:pix        phy
            lda   Pic640
            bne   :wide
            lda   SX                    ; 320: a nibble
            lsr
            clc
            adc   SRow
            tay
            lda   [p2],y
            sta   t1
            lda   SX
            lsr
            lda   t1
            bcs   :low
            lsr
            lsr
            lsr
            lsr
:low        and   #$000F
            bra   :value
:wide       lda   SX                    ; 640: two bits
            lsr
            lsr
            clc
            adc   SRow
            tay
            lda   [p2],y
            sta   t1
            lda   SX
            and   #$0003
            eor   #$0003
            asl
            tax
            lda   t1
:sh         cpx   #0
            beq   :two
            lsr
            dex
            bra   :sh
:two        and   #$0003
:value      sta   t1                    ; its colour: 640 mode lines use the
            lda   SScb                  ; column's part of the table and the
            and   #$0080                ; pixel's low two bits (as GS Remap,
            beq   :entry                ; also in a 320 mode picture)
            lda   SX
            and   #$0003
            tax
            lda   Off640T,x
            and   #$00FF
            sta   t2
            lda   t1
            and   #$0003
            clc
            adc   t2
            sta   t1
            bra   :e2
:entry      lda   t1
            and   #$000F
            sta   t1
:e2         lda   t1
            asl
            clc
            adc   STab
            tay
            lda   [p2],y
            sta   t1
            ply
            xba                         ; red, green, blue (* 17)
            and   #$000F
            jsr   :x17
            lda   t1
            lsr
            lsr
            lsr
            lsr
            and   #$000F
            jsr   :x17
            lda   t1
            and   #$000F
            jsr   :x17
            inc   SX
            lda   SX
            cmp   PicW
            bcs   :jx1
            jmp   :pix
:jx1
            inc   SY
            lda   SY
            cmp   PicH
            bcs   :done
            jmp   :row
:done       clc
            rts
:x17        sta   t2
            asl
            asl
            asl
            asl
            ora   t2
            sep   #$20
            mx    %10
            sta   [q0],y
            rep   #$20
            mx    %00
            iny
            rts

Off640T     db    8,12,0,4

* FastLine: the whole bytes of screen line SY (SRow, colour table STab),
* whose mode is the picture's, into the true colour row at q0: the line's
* 16 colours' channels times 17 in R17/G17/B17, then 8 bits at a time.
*   out: SX = the pixels done, Y = SX * 3
FastLine    ldx   #0                    ; the line's colours
            ldy   STab
:tab        lda   [p2],y                ; $0RGB
            pha
            xba
            jsr   :x17
            sta   R17,x
            rep   #$20
            lda   1,s
            lsr
            lsr
            lsr
            lsr
            jsr   :x17
            sta   G17,x
            rep   #$20
            pla
            jsr   :x17
            sta   B17,x
            rep   #$20
            iny
            iny
            inx
            cpx   #16
            bcc   :tab
            lda   PicW                  ; the whole bytes
            lsr
            ldx   Pic640
            beq   :n
            lsr
:n          sta   t2
            cmp   #0                    ; (LDX set the flags)
            bne   :copy
            stz   SX
            ldy   #0
            rts
:copy       ldy   SRow                  ; the line, copied (a word at a time)
            ldx   #0
:cp         lda   [p2],y
            sta   SLine,x
            iny
            iny
            inx
            inx
            cpx   t2
            bcc   :cp
            stz   t0                    ; t0: the byte, t1: its value, t2: the
            ldy   #0                    ; count; B zero (TAX uses it)
            lda   #0
            sep   #$20
            mx    %10
            lda   Pic640
            bne   :b640
:b320       ldx   t0                    ; two pixels a byte
            lda   SLine,x
            inx
            stx   t0
            sta   t1
            lsr
            lsr
            lsr
            lsr
            tax
            lda   R17,x
            sta   [q0],y
            iny
            lda   G17,x
            sta   [q0],y
            iny
            lda   B17,x
            sta   [q0],y
            iny
            lda   t1
            and   #$0F
            tax
            lda   R17,x
            sta   [q0],y
            iny
            lda   G17,x
            sta   [q0],y
            iny
            lda   B17,x
            sta   [q0],y
            iny
            ldx   t0
            cpx   t2
            bcc   :b320
            rep   #$20
            mx    %00
            lda   t2
            asl
            sta   SX
            rts
            mx    %10
:b640       ldx   t0                    ; four a byte: entries 8, 12, 0, 4 on
            lda   SLine,x
            inx
            stx   t0
            sta   t1
            lsr
            lsr
            lsr
            lsr
            lsr
            lsr
            ora   #8
            tax
            lda   R17,x
            sta   [q0],y
            iny
            lda   G17,x
            sta   [q0],y
            iny
            lda   B17,x
            sta   [q0],y
            iny
            lda   t1
            lsr
            lsr
            lsr
            lsr
            and   #3
            ora   #12
            tax
            lda   R17,x
            sta   [q0],y
            iny
            lda   G17,x
            sta   [q0],y
            iny
            lda   B17,x
            sta   [q0],y
            iny
            lda   t1
            lsr
            lsr
            and   #3
            tax
            lda   R17,x
            sta   [q0],y
            iny
            lda   G17,x
            sta   [q0],y
            iny
            lda   B17,x
            sta   [q0],y
            iny
            lda   t1
            and   #3
            ora   #4
            tax
            lda   R17,x
            sta   [q0],y
            iny
            lda   G17,x
            sta   [q0],y
            iny
            lda   B17,x
            sta   [q0],y
            iny
            ldx   t0
            cpx   t2
            bcc   :b640
            rep   #$20
            mx    %00
            lda   t2
            asl
            asl
            sta   SX
            rts
* (:x17: A's low 4 bits times 17, stored as a byte by the caller)
:x17        and   #$000F
            pha
            asl
            asl
            asl
            asl
            ora   1,s
            sta   1,s
            pla
            sep   #$20
            mx    %10
            rts
            mx    %00

*-------------------------------------------------------------
* Arithmetic (also used by the decoders)
*-------------------------------------------------------------

* Mul16: Prod (32 bits) = A * X
Mul16       sta   M1
            stz   M1Hi
            stx   M2
            stz   ProdLo
            stz   ProdHi
:loop       lda   M2
            beq   :done
            lsr   M2
            bcc   :shift
            clc
            lda   ProdLo
            adc   M1
            sta   ProdLo
            lda   ProdHi
            adc   M1Hi
            sta   ProdHi
:shift      asl   M1
            rol   M1Hi
            bra   :loop
:done       rts

* Div32: Quot (32 bits) = Prod / A, for small divisors.
Div32       sta   Divisor
            lda   ProdLo
            sta   QuotLo
            lda   ProdHi
            sta   QuotHi
            stz   Rem
            ldx   #32
:loop       asl   QuotLo
            rol   QuotHi
            rol   Rem
            lda   Rem
            sec
            sbc   Divisor
            bcc   :no
            sta   Rem
            inc   QuotLo
:no         dex
            bne   :loop
            rts


*-------------------------------------------------------------
* Data
*-------------------------------------------------------------
IsTrue      dw    0
TrueFill    dw    $FF
TrueTall    dw    0
TrueW       dw    0
TrueH       dw    0
TrueStride  dw    0
TrueSize    adrl  0
TrueHnd     adrl  0
TrueP       adrl  0
FillVal     dw    0
FillW       dw    0                     ; (FillBig: the byte, the even count)
FillE       dw    0
CR          dw    0
CG          dw    0
CB          dw    0

SX          dw    0
SY          dw    0
SRow        dw    0
SScb        dw    0
STab        dw    0
NoFill      dw    0                     ; (NewTrue: no fill)
R17         ds    16                    ; (FastLine: a line's colours' channels
G17         ds    16                    ; times 17, and the line)
B17         ds    16
SLine       ds    162
M1          dw    0
M1Hi        dw    0
M2          dw    0
ProdLo      dw    0                     ; (ProdHi must follow: JPEG reads ProdLo+1)
ProdHi      dw    0
Divisor     dw    0
QuotLo      dw    0
QuotHi      dw    0
Rem         dw    0
DA          dw    0                     ; (PNG's Paeth filter)
DB          dw    0
DCc         dw    0

* The shared work area: a decoder's tables (BMP, GIF, PNG, JPEG).
Work        ds    24576

* A decoder's palette lives at the work area's end.
Pal         =     Work+16384            ; 256 x R, G, B
PalA        =     Work+17152            ; 256 alpha values (words: 512 bytes)
