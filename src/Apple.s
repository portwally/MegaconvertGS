*-------------------------------------------------------------
* Apple.s - Apple II and Apple IIgs picture formats
* (a segment of its own; called from Formats.s with JSL)
*
* Apple II: HiRes and Double HiRes (colour or black & white),
* Print Shop graphics, ThunderScan scans, TDM text screens.
* Apple IIgs: DreamGrafix, Print Shop IIgs graphics and library,
* Finder icons, AST and ComputerEyes digitizer files, and
* "3200 color" pictures, plain and compressed.
*
* Screen formats are written to the picture (scrp) in $C1 layout;
* the others become true colour pictures through NewTrueL.
* The layouts follow SuperConvert's loaders as GS Remap reads them.
*-------------------------------------------------------------
            rel
            mx    %00
            use   macros/Macs.s
            put   Equates.s

NewTrueL    ext

* DecodeApple: A = format to read (0: recognise it).
*   out: carry clear and A = format, or carry set and A = error (0: not one of these)
DecodeApple ent
            phb
            phk
            plb
            stz   pw                    ; (PackRow notes the picture's size)
            stz   ph
            stz   p640
            sta   Want
            jsr   Detect
            bcs   :out
            cmp   #fmtWOA               ; (Works of Art: WOA.s)
            bne   :table
            jsr   LoadWOA
            bra   :out
:table      sec
            sbc   #fmtHGR
            asl
            tax
            jsr   (Loaders,x)
:out        plb
            rtl

Loaders     da    LoadHGR,LoadHGRBW,LoadDHR,LoadDHRBW,LoadPSBW,LoadPSGS,LoadCGT
            da    LoadIcon,LoadTScan,LoadTDM40,LoadTDM80,LoadDG,LoadDG3200
            da    LoadAST,LoadCEyes,Load3200,Load3200C

* Detect: the format asked for, or one recognised by type, aux type and size.
Detect      stz   DGAuto
            lda   Want
            beq   :auto
            clc
            rts
:auto
            lda   ftype
            cmp   #$00CA
            bne   :notIcon
            lda   #fmtIcon
            clc
            rts
:notIcon    cmp   #$00F7                ; Works of Art: type $F7, "SS" at 5
            bne   :notWOA
            lda   flen+2
            bne   :ssWOA
            lda   flen
            cmp   #16
            bcc   :notWOA
:ssWOA      ldy   #5
            lda   [fp],y
            cmp   #$5353
            bne   :notWOA
            lda   #fmtWOA
            clc
            rts
:notWOA     lda   faux
            cmp   #$8005                ; DreamGrafix
            bne   :notDG
            lda   ftype
            cmp   #$00C0
            beq   :dg
            cmp   #$00C1
            bne   :notDG
:dg         inc   DGAuto
            lda   #fmtDG
            clc
            rts
:notDG      lda   ftype
            cmp   #$00C1
            bne   :notC1
            lda   faux
            cmp   #2
            bne   :notC1
            lda   #fmt3200
            clc
            rts
:notC1      cmp   #$00C0
            bne   :notC0
            lda   faux
            cmp   #4
            bne   :notC0
            lda   #fmt3200C
            clc
            rts
:notC0      jsr   IsAPP
            bcs   :sizes
            lda   #fmt3200C
            clc
            rts
:sizes      lda   flen+2                ; by size
            bne   :big
            lda   flen
            ldx   #0
:range      cmp   SizeLo,x
            bcc   :nextSize
            cmp   SizeHi,x
            beq   :found
            bcc   :found
:nextSize   inx
            inx
            cpx   #SizeHi-SizeLo
            bcc   :range
            bra   :none
:found      lda   SizeFmt,x
            clc
            rts
:big        cmp   #1                    ; 96000 = $1:7700
            bne   :big2
            lda   flen
            cmp   #$7700
            bne   :none
            lda   #fmtAST
            clc
            rts
:big2       cmp   #2                    ; 192000-196608 = $2:EE00-$3:0000
            bne   :big3
            lda   flen
            cmp   #$EE00
            bcc   :none
            lda   #fmtCEyes
            clc
            rts
:big3       cmp   #3
            bne   :none
            lda   flen
            bne   :none
            lda   #fmtCEyes
            clc
            rts
:none       lda   #0
            sec
            rts

SizeLo      dw    8184,16376,572,1716,38400
SizeHi      dw    8192,16384,572,1716,38400
SizeFmt     dw    fmtHGR,fmtDHR,fmtPSBW,fmtPSGS,fmt3200

* IsAPP: carry clear if the file is a ".3201" picture ("APP", 0, tables, packed pixels).
IsAPP       lda   flen+2
            bne   :long
            lda   flen
            cmp   #6405
            bcc   :no
:long       lda   [fp]
            and   #$7F7F
            cmp   #$5041                ; "AP"
            bne   :no
            ldy   #2
            lda   [fp],y
            and   #$FF7F
            cmp   #$0050                ; "P", 0
            bne   :no
            clc
            rts
:no         sec
            rts

*-------------------------------------------------------------
* Screen helpers
*-------------------------------------------------------------

* HiResRow: A = screen line -> A = its offset in a HiRes page.
HiResRow    sta   t0
            and   #$0007                ; (y & 7) * $400
            xba
            asl
            asl
            sta   t1
            lda   t0                    ; ((y >> 3) & 7) * $80
            lsr
            lsr
            lsr
            and   #$0007
            xba
            lsr
            clc
            adc   t1
            sta   t1
            lda   t0                    ; (y >> 6) * $28
            lsr
            lsr
            lsr
            lsr
            lsr
            lsr
            sta   t0
            asl
            asl
            clc
            adc   t0                    ; * 5
            asl
            asl
            asl                         ; * 40
            clc
            adc   t1
            rts

*-------------------------------------------------------------
* Apple II HiRes
*-------------------------------------------------------------

LoadHGR     lda   #8184
            jsr   NeedLen
            bcc   :ok
            rts
:ok         jsr   ScrBegin
            ldx   #A2Pal
            jsr   SetTable0
            stz   Is640
            lda   #280
            sta   PixW
            stz   RowY
:row        lda   RowY
            jsr   HiResRow
            tay
            ldx   #0                    ; dots and their colour shift
:col        lda   [fp],y
            sta   t1
            and   #$0080                ; the byte's colour shift
            sta   t2
            phy
            ldy   #7
:bit        lda   t1
            and   #$0001
            sta   OnBuf+1,x
            lda   t2
            sta   Shf,x
            lsr   t1
            inx
            dey
            bne   :bit
            ply
            iny
            cpx   #280
            bcc   :col
            sep   #$20                  ; nothing left of the first dot
            mx    %10
            stz   OnBuf
            stz   OnBuf+281
            rep   #$20
            mx    %00
            ldx   #0
:pix        lda   OnBuf+1,x             ; this dot on?
            and   #$00FF
            beq   :off
            lda   OnBuf,x               ; with a neighbour: white
            ora   OnBuf+2,x
            and   #$00FF
            beq   :tint
            lda   #15
            bra   :set
:tint       txa
            jsr   Tint
            bra   :set
:off        lda   OnBuf,x               ; between two dots: their colour
            and   #$00FF
            beq   :black
            lda   OnBuf+2,x
            and   #$00FF
            beq   :black
            txa
            dec
            jsr   Tint
            bra   :set
:black      lda   #0
:set        sep   #$20
            mx    %10
            sta   RowPix,x
            rep   #$20
            mx    %00
            inx
            cpx   #280
            bcc   :pix
            jsr   PackRow
            inc   RowY
            lda   RowY
            cmp   #192
            bcs   :done
            jmp   :row
:done       lda   #fmtHGR
            clc
            rts

* Tint: the colour of dot A when on by itself: violet or green, or
* blue or orange when its byte's top bit is set.
Tint        tay
            lda   Shf,y
            and   #$00FF
            bne   :shifted
            tya
            lsr
            bcs   :green
            lda   #9                    ; violet
            rts
:green      lda   #6
            rts
:shifted    tya
            lsr
            bcs   :orange
            lda   #12                   ; blue
            rts
:orange     lda   #3
            rts

LoadHGRBW   lda   #8184
            jsr   NeedLen
            bcc   :ok
            rts
:ok         jsr   ScrBegin
            ldx   #Std320
            jsr   SetTable0
            stz   Is640
            lda   #280
            sta   PixW
            stz   RowY
:row        lda   RowY
            jsr   HiResRow
            tay
            ldx   #0
:col        lda   [fp],y
            sta   t1
            phy
            ldy   #7
:bit        lda   t1
            lsr   t1
            and   #$0001
            beq   :dot
            lda   #15
:dot        sep   #$20
            mx    %10
            sta   RowPix,x
            rep   #$20
            mx    %00
            inx
            dey
            bne   :bit
            ply
            iny
            cpx   #280
            bcc   :col
            jsr   PackRow
            inc   RowY
            lda   RowY
            cmp   #192
            bcc   :row
            lda   #fmtHGRBW
            clc
            rts

*-------------------------------------------------------------
* Apple II Double HiRes: auxiliary page, then main page
*-------------------------------------------------------------
LoadDHR     lda   #0
            bra   DoubleHiRes
LoadDHRBW   lda   #1
DoubleHiRes sta   Is640                 ; black & white: 560 dots in 640 mode
            lda   #16376
            jsr   NeedLen
            bcc   :ok
            rts
:ok         jsr   ScrBegin
            lda   Is640
            beq   :colPal
            ldx   #BWPal
            jsr   SetTable0
            lda   #$80
            ldx   #192
            jsr   SetScbs
            lda   #560
            bra   :w
:colPal     ldx   #A2Pal
            jsr   SetTable0
            lda   #280
:w          sta   PixW
            stz   RowY
:row        lda   RowY
            jsr   HiResRow
            sta   u0
            ldx   #0                    ; the 560 dots
:col        ldy   u0
            lda   [fp],y                ; auxiliary byte: 7 dots
            jsr   :seven
            lda   u0
            clc
            adc   #8192
            tay
            lda   [fp],y                ; main byte: 7 dots
            jsr   :seven
            inc   u0
            cpx   #560
            bcc   :col
            lda   Is640
            bne   :mono
            ldx   #0                    ; 4 dots make one colour, shown twice
            ldy   #0
:four       lda   Bits,x
            and   #$0001
            asl
            ora   Bits+1,x
            and   #$0003
            asl
            ora   Bits+2,x
            and   #$0007
            asl
            ora   Bits+3,x
            and   #$000F
            sta   t1
            xba
            ora   t1
            sta   RowPix,y
            iny
            iny
            inx
            inx
            inx
            inx
            cpx   #560
            bcc   :four
            bra   :pack
:mono       ldx   #558
:copy       lda   Bits,x
            sta   RowPix,x
            dex
            dex
            bpl   :copy
:pack       jsr   PackRow
            inc   RowY
            lda   RowY
            cmp   #192
            bcs   :done
            jmp   :row
:done       lda   Is640
            bne   :bw
            lda   #fmtDHR
            clc
            rts
:bw         lda   #fmtDHRBW
            clc
            rts
:seven      sta   t1
            ldy   #7
:bit        lda   t1
            and   #$0001
            sep   #$20
            mx    %10
            sta   Bits,x
            rep   #$20
            mx    %00
            lsr   t1
            inx
            dey
            bne   :bit
            rts

*-------------------------------------------------------------
* Print Shop: 88 x 52, one plane, or yellow, magenta, cyan planes
*-------------------------------------------------------------
LoadPSBW    lda   #572
            jsr   NeedLen
            bcc   :ok
            rts
:ok         stz   PSColour
            jsr   PrintShop
            lda   #fmtPSBW
            clc
            rts

LoadPSGS    lda   #1716
            jsr   NeedLen
            bcc   :ok
            rts
:ok         lda   #1
            sta   PSColour
            jsr   PrintShop
            lda   #fmtPSGS
            clc
            rts

* The Print Shop IIgs library (GRAPHIC.CGT0-7): its first graphic.
LoadCGT     lda   #1716
            jsr   NeedLen
            bcc   :ok
            rts
:ok         lda   #1
            sta   PSColour
            jsr   PrintShop
            lda   #fmtCGT
            clc
            rts

PrintShop   jsr   ScrBegin
            ldx   #Std320
            jsr   SetTable0
            stz   Is640
            lda   #88
            sta   PixW
            stz   RowY
:row        lda   RowY                  ; row start = y * 11
            asl
            asl
            sta   t0
            asl
            clc
            adc   t0
            sec
            sbc   RowY
            sta   u0
            ldx   #0
:pix        txa
            lsr
            lsr
            lsr
            clc
            adc   u0
            tay
            txa
            and   #$0007
            phx
            tax
            lda   PSMask,x
            and   #$00FF
            sta   t2
            plx
            lda   [fp],y                ; plane 0
            and   t2
            beq   :p0
            lda   #4
:p0         sta   t1
            lda   PSColour
            bne   :colour
            lda   t1                    ; one plane does for all three
            beq   :index
            lda   #7
            bra   :index
:colour     tya
            clc
            adc   #572
            tay
            lda   [fp],y
            and   t2
            beq   :p1
            lda   #2
            tsb   t1
:p1         tya
            clc
            adc   #572
            tay
            lda   [fp],y
            and   t2
            beq   :p2
            lda   #1
            tsb   t1
:p2         lda   t1
:index      tay
            lda   PSCols,y
            sep   #$20
            mx    %10
            sta   RowPix,x
            rep   #$20
            mx    %00
            inx
            cpx   #88
            bcc   :pix
            jsr   PackRow
            inc   RowY
            lda   RowY
            cmp   #52
            bcs   :jx3
            jmp   :row
:jx3
            rts

PSMask      db    $80,$40,$20,$10,$08,$04,$02,$01
PSCols      db    15,4,7,3,9,10,6,0

*-------------------------------------------------------------
* Finder icon file ($CA): its first icon, large, in 640 mode
*-------------------------------------------------------------
LoadIcon    lda   flen+2
            bne   :lenOK
            lda   flen
            cmp   #29
            bcs   :lenOK
:bad        lda   #errNotPicture
            sec
            rts
:lenOK      ldy   #4
            lda   [fp],y
            cmp   #1
            bne   :bad
            ldy   #26                   ; the first icon record
            lda   [fp],y
            cmp   #95
            bcc   :bad
            clc
            adc   #26
            jsr   Within
            bcs   :bad
            lda   #26+86                ; its large icon
            sta   u0
            tay                         ; size, height, width
            iny
            iny
            lda   [fp],y
            sta   IcSize
            iny
            iny
            lda   [fp],y
            sta   IcH
            iny
            iny
            lda   [fp],y
            sta   IcW
            lda   IcH
            beq   :bad
            lda   IcW
            beq   :bad
            lda   IcSize
            cmp   IcH
            bcc   :bad
            asl                         ; image and mask must be in the file
            clc
            adc   #8
            clc
            adc   u0
            jsr   Within
            bcs   :bad
            lda   IcSize                ; bytes a row = size / height
            ldx   IcH
            jsr   Div16
            sta   IcRow
            jsr   ScrBegin
            ldx   #Std640
            jsr   SetTable0
            lda   #1
            sta   Is640
            lda   IcW                   ; width with 8 white pixels each side
            asl
            clc
            adc   #16
            cmp   #641
            bcc   :w
            lda   #640
:w          sta   PixW
            lda   IcH
            clc
            adc   #8
            sta   IcLines
            tax
            cpx   #201
            bcc   :scb
            ldx   #200
:scb        lda   #$80
            jsr   SetScbs
            stz   RowY
:row        lda   #3                    ; white
            jsr   ClearRow
            lda   RowY                  ; an icon line?
            sec
            sbc   #4
            bcs   :jx4
            jmp   :pack
:jx4
            cmp   IcH
            bcs   :pack
            ldx   IcRow                 ; image line = data + line * bytes a row
            jsr   Mul16
            lda   MLo
            clc
            adc   u0
            clc
            adc   #8
            sta   u1                    ; image line
            clc
            adc   IcSize
            sta   u2                    ; mask line
            stz   u3                    ; x
:pix        lda   u3
            lsr
            cmp   IcRow
            bcs   :pack
            pha
            clc
            adc   u2
            tay
            lda   [fp],y
            sta   t1                    ; mask byte
            pla
            clc
            adc   u1
            tay
            lda   [fp],y
            sta   t2                    ; image byte
            lda   u3
            lsr
            bcs   :low
            lda   t1                    ; even x: high nibbles
            lsr
            lsr
            lsr
            lsr
            sta   t1
            lda   t2
            lsr
            lsr
            lsr
            lsr
            sta   t2
:low        lda   t1
            and   #$000F
            beq   :next                 ; masked out
            lda   u3                    ; two 640 mode pixels at 8 + 2x
            asl
            clc
            adc   #8
            tax
            cpx   #639
            bcs   :next
            lda   t2
            and   #$000F
            lsr
            lsr
            sep   #$20
            mx    %10
            sta   RowPix,x
            lda   t2
            and   #$03
            sta   RowPix+1,x
            rep   #$20
            mx    %00
:next       inc   u3
            lda   u3
            cmp   IcW
            bcc   :pix
:pack       jsr   PackRow
            inc   RowY
            lda   RowY
            cmp   IcLines
            bcs   :done
            cmp   #200
            bcs   :done
            jmp   :row
:done       lda   #fmtIcon
            clc
            rts

*-------------------------------------------------------------
* ThunderScan raw scan: 256-byte header, rows of 4-bit grey
*-------------------------------------------------------------
LoadTScan   lda   #257
            jsr   NeedLen
            bcc   :ok
            rts
:ok         ldy   #$0F
            lda   [fp],y
            lsr
            sta   TsRow                 ; bytes a row
            beq   :bad
            ldy   #$1E
            lda   [fp],y
            inc
            sta   TsH
            lda   TsRow                 ; 256 + rows * height must fit
            ldx   TsH
            jsr   Mul16
            lda   MLo
            clc
            adc   #256
            sta   n0
            lda   MHi
            adc   #0
            sta   n0+2
            lda   flen+2
            cmp   n0+2
            bne   :cmp
            lda   flen
            cmp   n0
:cmp        bcc   :bad
            ldy   #$0A
            lda   [fp],y
            and   #$0001
            sta   ttall
            lda   TsRow
            asl
            ldx   TsH
            jsl   NewTrueL
            bcc   :rows
            rts
:bad        lda   #errNotPicture
            sec
            rts
:rows       lda   fp
            clc
            adc   #256
            sta   q1
            lda   fp+2
            adc   #0
            sta   q1+2
            stz   RowY
:row        lda   RowY
            jsr   TrueRow
            ldy   #0
            stz   u0                    ; source byte
:byte       phy
            ldy   u0
            lda   [q1],y
            ply
            pha
            lsr
            lsr
            lsr
            lsr
            and   #$000F
            jsr   PutGrey17
            pla
            and   #$000F
            jsr   PutGrey17
            inc   u0
            lda   u0
            cmp   TsRow
            bcc   :byte
            lda   q1
            clc
            adc   TsRow
            sta   q1
            bcc   :nx
            inc   q1+2
:nx         inc   RowY
            lda   RowY
            cmp   TsH
            bcc   :row
            lda   #fmtTScan
            clc
            rts

*-------------------------------------------------------------
* TDM text screen captures: 40 columns, or 80 (auxiliary half first)
*-------------------------------------------------------------
LoadTDM40   lda   #888
            jsr   NeedLen
            bcc   :ok
            rts
:ok         stz   Is640
            lda   #40
            sta   Cols
            lda   #280
            sta   PixW
            lda   #15
            sta   White
            jsr   ScrBegin
            ldx   #Std320
            jsr   SetTable0
            jsr   TextScreen
            lda   #fmtTDM40
            clc
            rts

LoadTDM80   lda   #1912
            jsr   NeedLen
            bcc   :ok
            rts
:ok         lda   #1
            sta   Is640
            lda   #80
            sta   Cols
            lda   #560
            sta   PixW
            lda   #3
            sta   White
            jsr   ScrBegin
            ldx   #Std640
            jsr   SetTable0
            lda   #$80
            ldx   #192
            jsr   SetScbs
            jsr   TextScreen
            lda   #fmtTDM80
            clc
            rts

TextScreen  stz   TRowN
:textRow    lda   TRowN                 ; base = (row & 7) * $80 + (row >> 3) * $28
            and   #$0007
            xba
            lsr
            sta   t1
            lda   TRowN
            lsr
            lsr
            lsr
            sta   t0
            asl
            asl
            clc
            adc   t0
            asl
            asl
            asl
            clc
            adc   t1
            sta   u0
            ldx   #0                    ; each column's character code ($FFFF: none)
:code       txa
            lsr                         ; the column
            ldy   Cols
            cpy   #80
            bne   :c40
            lsr                         ; 80 columns: column / 2, odd ones from $400 on
            bcc   :c40
            adc   #1023                 ; (+ the carry)
:c40        clc
            adc   u0
            jsr   ByteAt
            sta   Codes,x
            inx
            inx
            txa
            lsr
            cmp   Cols
            bcc   :code
            stz   GY
:line       lda   #0
            jsr   ClearRow
            stz   u1                    ; column
:column     lda   u1
            asl
            tax
            lda   Codes,x
            bmi   :nextCol              ; beyond the file
            sta   t1
            and   #$007F
            cmp   #$20
            bcs   :printable
            adc   #$40
:printable  sta   t2
            lda   #0                    ; inverse below $80
            ldy   t1
            cpy   #$80
            bcs   :normal
            lda   #$7F
:normal     sta   t3
            lda   t2                    ; the glyph row
            cmp   #$7F
            bcs   :blank
            sec
            sbc   #$20
            asl
            asl
            asl
            clc
            adc   GY
            tay
            lda   Glyphs,y
            and   #$00FF
            bra   :bits
:blank      lda   #0
:bits       eor   t3                    ; dots that are lit
            and   #$007F
            sta   t2
            lda   u1                    ; x = column * 7
            asl
            asl
            asl
            sec
            sbc   u1
            tax
            ldy   #7
:dot        lda   t2
            and   #$0040
            beq   :dark
            lda   White
            sep   #$20
            mx    %10
            sta   RowPix,x
            rep   #$20
            mx    %00
:dark       asl   t2
            inx
            dey
            bne   :dot
:nextCol    inc   u1
            lda   u1
            cmp   Cols
            bcc   :column
            lda   TRowN                 ; picture line = row * 8 + glyph line
            asl
            asl
            asl
            clc
            adc   GY
            sta   RowY
            jsr   PackRow
            inc   GY
            lda   GY
            cmp   #8
            bcs   :nextRow
            jmp   :line
:nextRow    inc   TRowN
            lda   TRowN
            cmp   #24
            bcs   :done
            jmp   :textRow
:done       rts

* ByteAt: the file's byte at offset A ($FFFF if past the end).
ByteAt      ldy   flen+2
            bne   :in
            cmp   flen
            bcc   :in
            lda   #$FFFF
            rts
:in         tay
            lda   [fp],y
            and   #$00FF
            rts

*-------------------------------------------------------------
* DreamGrafix ($C0/$8005): LZW, 9 to 12 bit codes, low bit first,
* clear $100, end $101. 256 colours (a $C1 screen) or "3200 color".
*-------------------------------------------------------------
LoadDG      lda   DGAuto
            bne   :auto
            lda   #32768
            sta   DGLimit
            jsr   Unlzw
            bcc   :got
            rts
:got        jsr   DGScreen
            bra   DGDone
:auto       lda   #38400                ; recognised: either kind
            sta   DGLimit
            jsr   Unlzw
            bcc   :got2
            rts
:got2       lda   DGCount
            cmp   #38400
            bcc   :screen
            jsr   DG3200
            bra   DGDone
:screen     jsr   DGScreen
DGDone      php
            pha
            jsr   FreeOut
            pla
            plp
            rts

LoadDG3200  lda   #38400
            sta   DGLimit
            jsr   Unlzw
            bcc   :got
            rts
:got        jsr   DG3200
            bra   DGDone

DG3200      lda   DGCount
            cmp   #38400
            bcc   :bad
            lda   OutP                  ; pixels, then the colour tables
            sta   q1
            lda   OutP+2
            sta   q1+2
            lda   OutP
            clc
            adc   #32000
            sta   q2
            lda   OutP+2
            adc   #0
            sta   q2+2
            jsr   To3200
            bcs   :err
            lda   #fmtDG3200
            clc
:err        rts
:bad        lda   #errNotPicture
            sec
            rts

* DGScreen: the decoded bytes as a $C1 screen, read the way a $C1 file is.
DGScreen    lda   DGCount
            cmp   #32200
            bcs   :ok
            lda   #errNotPicture
            sec
            rts
:ok         stz   t1                    ; 640 mode if most SCBs say so
            ldy   #32000
:count      lda   [OutDP],y
            and   #$0080
            beq   :c
            inc   t1
:c          iny
            cpy   #32200
            bcc   :count
            ldx   #0
            lda   t1
            cmp   #101
            bcc   :mode
            ldx   #$80
:mode       stx   t2
            lda   #320                  ; a whole screen
            sta   pw
            lda   #200
            sta   ph
            stz   p640
            cpx   #0
            beq   :size
            inc   p640
            asl   pw
:size       ldy   #0                    ; pixels
:pix        lda   [OutDP],y
            sta   [scrp],y
            iny
            iny
            cpy   #32000
            bcc   :pix
:scb        lda   [OutDP],y             ; SCBs, mode bit as the whole picture
            and   #$007F
            ora   t2
            sep   #$20
            mx    %10
            sta   [scrp],y
            rep   #$20
            mx    %00
            iny
            cpy   #32200
            bcc   :scb
            lda   #0
:spare      sta   [scrp],y
            iny
            iny
            cpy   #palOffset
            bcc   :spare
:pal        lda   [OutDP],y             ; colour tables, 12 bits
            and   #$0FFF
            sta   [scrp],y
            iny
            iny
            cpy   #$8000
            bcc   :pal
            lda   #fmtDG
            clc
            rts

* Unlzw: decodes the file into a new buffer (OutP), at most DGLimit bytes.
Unlzw       lda   #38400
            jsr   NewOut
            bcc   :start
            rts
:start      stz   DGCount
            stz   BitPos
            stz   BitPos+2
:clear      lda   #9
            sta   Width
            lda   #$0200
            sta   Top
            lda   #$0102
            sta   Next
            lda   #$FFFF
            sta   Prev
:loop       lda   DGCount
            cmp   DGLimit
            bcc   :code
            jmp   :end
:code       jsr   ReadLzw
            bcc   :have
            jmp   :end
:have       cmp   #$0101
            bne   :notEnd
            jmp   :end
:notEnd     cmp   #$0100
            beq   :clear
            sta   Code
            ldx   Prev
            cpx   #$FFFF
            bne   :normal
            sta   Prev                  ; the first code after a clear
            sta   First
            jsr   Emit
            bra   :loop
:normal     ldy   #0                    ; walk the string back to its first byte
            cmp   Next
            bcc   :walk
            lda   First
            sep   #$20
            mx    %10
            sta   LStack
            rep   #$20
            mx    %00
            ldy   #1
            lda   Prev
:walk       cmp   #$0100
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
            bcs   :end
            txa
            asl
            tax
            lda   LPrefix,x
            bra   :walk
:root       sta   First
            phy
            jsr   Emit
            ply
:pop        dey
            bmi   :popped
            lda   LStack,y
            and   #$00FF
            phy
            jsr   Emit
            ply
            bra   :pop
:popped     ldx   Next                  ; new string: previous + first
            cpx   #4096
            bcs   :noAdd
            sep   #$20
            mx    %10
            lda   First
            sta   LSuffix,x
            rep   #$20
            mx    %00
            txa
            asl
            tax
            lda   Prev
            sta   LPrefix,x
            inc   Next
            lda   Next
            cmp   Top
            bcc   :noAdd
            lda   Width
            cmp   #12
            bcs   :noAdd
            inc   Width
            asl   Top
:noAdd      lda   Code
            sta   Prev
            jmp   :loop
:end        clc
            rts

* Emit: one decoded byte (dropped past the limit).
Emit        ldy   DGCount
            cpy   DGLimit
            bcs   :full
            sep   #$20
            mx    %10
            sta   [OutDP],y
            rep   #$20
            mx    %00
            inc   DGCount
:full       rts

* ReadLzw: the next Width-bit code. Carry set past the end of the file.
ReadLzw     lda   BitPos                ; byte = position / 8
            sta   n0
            lda   BitPos+2
            sta   n0+2
            ldx   #3
:sh         lsr   n0+2
            ror   n0
            dex
            bne   :sh
            lda   n0+2                  ; inside the file?
            cmp   flen+2
            bne   :cmp
            lda   n0
            cmp   flen
:cmp        bcc   :in
            rts
:in         lda   fp                    ; q1 = that byte
            clc
            adc   n0
            sta   q1
            lda   fp+2
            adc   n0+2
            sta   q1+2
            stz   V2                    ; up to three bytes, low first
            lda   [q1]
            and   #$00FF
            sta   V0
            jsr   :more                 ; the next byte, if there is one
            bcs   :got
            ldy   #1
            lda   [q1],y
            xba
            and   #$FF00
            tsb   V0
            jsr   :more2
            bcs   :got
            ldy   #2
            lda   [q1],y
            and   #$00FF
            sta   V2
:got        lda   BitPos                ; shift right by position & 7
            and   #$0007
            beq   :mask
            tax
:shr        lsr   V2
            ror   V0
            dex
            bne   :shr
:mask       lda   Width
            asl
            tax
            lda   Masks,x
            and   V0
            pha
            lda   BitPos
            clc
            adc   Width
            sta   BitPos
            bcc   :pos
            inc   BitPos+2
:pos        pla
            clc
            rts
:more       lda   #1                    ; byte + 1 inside the file?
            bra   :inside
:more2      lda   #2
:inside     clc
            adc   n0
            sta   n1
            lda   n0+2
            adc   #0
            cmp   flen+2
            bne   :c2
            lda   n1
            cmp   flen
:c2         bcs   :out
            clc
            rts
:out        sec
            rts

Masks       dw    0,1,3,7,15,31,63,127,255,511,1023,2047,4095

*-------------------------------------------------------------
* "3200 color": 200 lines, each with its own colour table
*-------------------------------------------------------------
Load3200    lda   flen+2
            bne   :ok
            lda   flen
            cmp   #38400
            bcs   :ok
            lda   #errNotPicture
            sec
            rts
:ok         lda   fp
            sta   q1
            lda   fp+2
            sta   q1+2
            lda   fp
            clc
            adc   #32000
            sta   q2
            lda   fp+2
            adc   #0
            sta   q2+2
            jsr   To3200
            bcs   :err
            lda   #fmt3200
            clc
:err        rts

* To3200: pixels at q1 (32000 bytes) and tables at q2 (200 x 16 colours,
* each stored last colour first) become a true colour picture.
To3200      pei   q1+2                  ; (making the picture uses q1)
            pei   q1
            pei   q2+2
            pei   q2
            lda   #320
            ldx   #200
            stz   ttall
            jsl   NewTrueL
            ply
            sty   q2
            ply
            sty   q2+2
            ply
            sty   q1
            ply
            sty   q1+2
            bcc   :rows
            rts
:rows       stz   RowY
:row        ldy   #30                   ; this line's colours as R, G, B
            ldx   #0
:entry      lda   [q2],y
            sta   t1
            xba
            and   #$000F
            jsr   Times17
            sta   LineR,x
            lda   t1
            lsr
            lsr
            lsr
            lsr
            and   #$000F
            jsr   Times17
            sta   LineG,x
            lda   t1
            and   #$000F
            jsr   Times17
            sta   LineB,x
            inx
            inx
            dey
            dey
            bpl   :entry
            lda   RowY
            jsr   TrueRow
            ldy   #0
            stz   u0
:byte       phy
            ldy   u0
            lda   [q1],y
            ply
            pha
            lsr
            lsr
            lsr
            lsr
            and   #$000F
            jsr   :put
            pla
            and   #$000F
            jsr   :put
            inc   u0
            lda   u0
            cmp   #160
            bcc   :byte
            lda   q1
            clc
            adc   #160
            sta   q1
            bcc   :q2
            inc   q1+2
:q2         lda   q2
            clc
            adc   #32
            sta   q2
            bcc   :next
            inc   q2+2
:next       inc   RowY
            lda   RowY
            cmp   #200
            bcs   :jx5
            jmp   :row
:jx5
            clc
            rts
:put        asl
            tax
            lda   LineR,x
            sep   #$20
            mx    %10
            sta   [q0],y
            iny
            lda   LineG,x
            sta   [q0],y
            iny
            lda   LineB,x
            sta   [q0],y
            iny
            rep   #$20
            mx    %00
            rts

* Compressed: ".3201" (APP, tables, PackBytes pixels), or SuperConvert's
* own: 7 header bytes (the last two: packed size of the tables), the
* packed tables, then the packed pixels.
Load3200C   lda   flen+2
            bne   :big
            lda   flen
            cmp   #8
            bcs   :big
:bad        lda   #errNotPicture
            sec
            rts
:big        lda   #38400
            jsr   NewOut
            bcc   :buf
            rts
:buf        jsr   IsAPP
            bcc   :jx6
            jmp   :runs
:jx6
            lda   fp                    ; .3201: pixels unpacked from 6404 on
            clc
            adc   #6404
            sta   UPPtr
            lda   fp+2
            adc   #0
            sta   UPPtr+2
            lda   flen
            sec
            sbc   #6404
            tax
            lda   flen+2
            sbc   #0
            bne   :most
            cpx   #32768
            bcc   :size
:most       ldx   #32767
:size       stx   UPLen
            lda   OutP
            sta   UPDst
            lda   OutP+2
            sta   UPDst+2
            lda   #32000
            sta   UPOut
            pha                         ; result: bytes used
            PushLongAt UPPtr            ; the packed pixels
            lda   UPLen
            pha
            PushLong UPDst              ; where they go
            PushLong UPOut              ; how many (counts down)
            Tool  _UnPackBytes
            pla
            lda   UPOut                 ; all 32000 bytes there?
            beq   :jx7
            jmp   :fail
:jx7
            lda   OutP
            sta   q1
            lda   OutP+2
            sta   q1+2
            lda   fp
            clc
            adc   #4
            sta   q2
            lda   fp+2
            adc   #0
            sta   q2+2
            jsr   To3200
            jmp   :done
:runs       ldy   #5                    ; packed table size
            lda   [fp],y
            clc
            adc   #7
            sta   u1                    ; where the pixels start
            jsr   Within
            bcs   :fail
            lda   fp                    ; tables into the buffer at 32000
            clc
            adc   #7
            sta   RunSrcDP
            lda   fp+2
            adc   #0
            sta   RunSrcDP+2
            lda   u1
            sec
            sbc   #7
            sta   RunLeft
            stz   RunLeft+2
            lda   #32000
            sta   RunOut
            lda   #6400
            jsr   UnpackRuns
            bcs   :fail
            lda   fp                    ; pixels: the rest of the file
            clc
            adc   u1
            sta   RunSrcDP
            lda   fp+2
            adc   #0
            sta   RunSrcDP+2
            lda   flen
            sec
            sbc   u1
            sta   RunLeft
            lda   flen+2
            sbc   #0
            sta   RunLeft+2
            stz   RunOut
            lda   #32000
            jsr   UnpackRuns
            bcs   :fail
            lda   OutP
            sta   q1
            lda   OutP+2
            sta   q1+2
            lda   OutP
            clc
            adc   #32000
            sta   q2
            lda   OutP+2
            adc   #0
            sta   q2+2
            jsr   To3200
:done       php
            pha
            jsr   FreeOut
            pla
            plp
            bcs   :err
            lda   #fmt3200C
            clc
:err        rts
:fail       jsr   FreeOut
            lda   #errNotPicture
            sec
            rts

* UnpackRuns: A bytes into the buffer from offset RunOut, from RunSrc
* (RunLeft bytes). Each control byte: the top 3 bits say what to do,
* the low 5 how many (ops 1 and 7 take 13 bits, the next byte too):
* 0, 1: repeat the next byte n+1 times; 6, 7: copy n bytes as they are;
* 2-5: repeat the next op bytes n+1 times. Carry set if the data runs out.
UnpackRuns  clc
            adc   RunOut
            sta   RunEnd
:control    lda   RunOut
            cmp   RunEnd
            bcc   :more
            clc
            rts
:more       jsr   RunByte
            bcc   :jx9
            jmp   :out
:jx9
            sta   t1
            and   #$001F
            sta   RunN
            lda   t1
            lsr
            lsr
            lsr
            lsr
            lsr
            sta   RunOp
            cmp   #1
            beq   :long
            cmp   #7
            bne   :ops
:long       jsr   RunByte
            bcs   :out
            sta   t1
            lda   RunN
            xba
            ora   t1
            sta   RunN
:ops        lda   RunOp
            cmp   #2
            bcc   :repeat
            cmp   #6
            bcs   :copy
            ldx   #0                    ; 2-5: a unit of op bytes
:unit       phx
            jsr   RunByte
            plx
            bcs   :out
            sep   #$20
            mx    %10
            sta   RunUnit,x
            rep   #$20
            mx    %00
            inx
            cpx   RunOp
            bcc   :unit
            inc   RunN                  ; n+1 times
:again      ldx   #0
:put        lda   RunUnit,x
            jsr   RunPut
            inx
            cpx   RunOp
            bcc   :put
            dec   RunN
            bne   :again
            bra   :control
:repeat     jsr   RunByte
            bcs   :out
            sta   t1
            inc   RunN
:rep        lda   t1
            jsr   RunPut
            dec   RunN
            bne   :rep
            jmp   :control
:copy       lda   RunN
            bne   :jx11
            jmp   :control
:jx11
:lit        jsr   RunByte
            bcs   :out
            jsr   RunPut
            dec   RunN
            bne   :lit
            jmp   :control
:out        sec
            rts

* RunByte: the next source byte; carry set at the end.
RunByte     lda   RunLeft
            ora   RunLeft+2
            bne   :have
            sec
            rts
:have       lda   RunLeft
            bne   :low
            dec   RunLeft+2
:low        dec   RunLeft
            lda   [RunSrcDP]
            and   #$00FF
            inc   RunSrcDP
            bne   :ok
            inc   RunSrcDP+2
:ok         clc
            rts

* RunPut: a byte to the buffer, while before RunEnd. Keeps X.
RunPut      ldy   RunOut
            cpy   RunEnd
            bcs   :full
            sep   #$20
            mx    %10
            sta   [OutDP],y
            rep   #$20
            mx    %00
            inc   RunOut
:full       rts

*-------------------------------------------------------------
* Video digitizers
*-------------------------------------------------------------

* AST VisionPlus: red, green and blue planes of 200 lines of 160 bytes,
* two 4-bit samples a byte.
LoadAST     lda   #$7700                ; 96000 bytes
            ldx   #1
            jsr   NeedLong
            bcc   :ok
            rts
:ok         lda   #320
            ldx   #200
            stz   ttall
            jsl   NewTrueL
            bcc   :rows
            rts
:rows       stz   RowY
            lda   fp
            sta   q1
            lda   fp+2
            sta   q1+2
:row        lda   RowY
            jsr   TrueRow
            ldy   #0
            stz   u0                    ; x
:pix        lda   u0
            lsr
            sta   u1                    ; byte in the line
            jsr   :plane                ; red
            lda   u1
            clc
            adc   #32000
            sta   u1
            jsr   :plane
            lda   u1
            clc
            adc   #32000
            sta   u1
            jsr   :plane
            inc   u0
            lda   u0
            cmp   #320
            bcc   :pix
            lda   q1
            clc
            adc   #160
            sta   q1
            bcc   :nx
            inc   q1+2
:nx         inc   RowY
            lda   RowY
            cmp   #200
            bcc   :row
            lda   #fmtAST
            clc
            rts
:plane      phy
            ldy   u1
            lda   [q1],y
            ply
            sta   t1
            lda   u0
            lsr
            lda   t1
            bcs   :lo
            lsr
            lsr
            lsr
            lsr
:lo         and   #$000F
            jsr   Times17
            sep   #$20
            mx    %10
            sta   [q0],y
            rep   #$20
            mx    %00
            iny
            rts

* ComputerEyes GS: red, green and blue planes of 6-bit samples,
* column by column (200 a column), planes 64000 or 65535 bytes apart.
LoadCEyes   lda   #$EE00                ; 192000 bytes
            ldx   #2
            jsr   NeedLong
            bcc   :ok
            rts
:ok         lda   #64000
            sta   CeStride
            lda   flen+2
            cmp   #3
            bcs   :wide
            cmp   #2
            bne   :narrow
            lda   flen
            cmp   #$FFFD                ; 196605 = $2:FFFD
            bcc   :narrow
:wide       lda   #65535
            sta   CeStride
:narrow     lda   #320
            ldx   #200
            stz   ttall
            jsl   NewTrueL
            bcc   :rows
            rts
:rows       stz   RowY
:row        lda   RowY                  ; the planes' samples for this line
            clc
            adc   fp
            sta   q1
            lda   fp+2
            adc   #0
            sta   q1+2
            lda   q1
            clc
            adc   CeStride
            sta   q2
            lda   q1+2
            adc   #0
            sta   q2+2
            lda   q2
            clc
            adc   CeStride
            sta   p3
            lda   q2+2
            adc   #0
            sta   p3+2
            lda   RowY
            jsr   TrueRow
            ldy   #0
            stz   u0                    ; x * 200
:pix        phy
            ldy   u0
            lda   [q1],y
            jsr   Six
            sta   CR
            lda   [q2],y
            jsr   Six
            sta   CG
            lda   [p3],y
            jsr   Six
            sta   CB
            ply
            sep   #$20
            mx    %10
            lda   CR
            sta   [q0],y
            iny
            lda   CG
            sta   [q0],y
            iny
            lda   CB
            sta   [q0],y
            iny
            rep   #$20
            mx    %00
            lda   u0
            clc
            adc   #200
            sta   u0
            cmp   #64000
            bcc   :pix
            inc   RowY
            lda   RowY
            cmp   #200
            bcs   :jx12
            jmp   :row
:jx12
            lda   #fmtCEyes
            clc
            rts

* Six: a 6-bit sample (low bits of A) as 8 bits.
Six         and   #$003F
            sta   t1
            asl
            asl
            sta   t2
            lda   t1
            lsr
            lsr
            lsr
            lsr
            ora   t2
            rts

*-------------------------------------------------------------
* Helpers
*-------------------------------------------------------------

*-------------------------------------------------------------
* Data
*-------------------------------------------------------------
RunSrcDP    =     $60                   ; (direct page) UnpackRuns' source

* Apple II colours in Double HiRes bit order.
A2Pal       dw    $000,$D03,$852,$F60,$070,$555,$0D0,$FF0
            dw    $009,$D0D,$AAA,$F98,$22F,$6AF,$0F9,$FFF

Want        dw    0
DGAuto      dw    0
PSColour    dw    0
IcSize      dw    0
IcH         dw    0
IcW         dw    0
IcRow       dw    0
IcLines     dw    0
TsRow       dw    0
TsH         dw    0
Cols        dw    0
White       dw    0
TRowN       dw    0
GY          dw    0
DGLimit     dw    0
DGCount     dw    0
BitPos      adrl  0
Width       dw    0
Top         dw    0
Next        dw    0
Prev        dw    0
Code        dw    0
First       dw    0
V0          dw    0
V2          dw    0
UPPtr       adrl  0
UPLen       dw    0
UPOut       dw    0
UPDst       adrl  0
RunLeft     adrl  0
RunOut      dw    0
RunEnd      dw    0
RunN        dw    0
RunOp       dw    0
RunUnit     ds    8
CeStride    dw    0
LineR       ds    32
LineG       ds    32
LineB       ds    32
Codes       ds    160
OnBuf       ds    284
Shf         ds    282
Bits        ds    562
LPrefix     ds    8192
LSuffix     ds    4096
LStack      ds    4096

            put   WOA.s
            put   SegLib.s
            put   Glyphs.s
