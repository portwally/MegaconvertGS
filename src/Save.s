*-------------------------------------------------------------
* Save.s - save formats (a segment of its own; called from
* MegaconvertGS.s with JSL)
*
* PaintWorks, Finder icons (a new file, or one more icon in a
* file), icon resources (rIcon, in a new resource file or added
* to one), hex data for programmers, and GIF, PNG and TIFF.
* The layouts follow GS Remap's save formats. GIF, PNG and TIFF
* hold the picture as GS Remap shows it: 320 mode pixels twice
* as wide, and every line twice, so the pixels come out square.
*
* In: the picture (scrp: cstr bytes a line, its SCBs at cscb, colour
* tables at cpal), its size (pw, ph, p640), the file to
* write (pathp), an existing file to add to (fp, flen).
* Out: what to write (outp, outl, otype, oaux, ohnd); resource
* files are written here, and outl is then 0.
*-------------------------------------------------------------
            rel
            mx    %00
            use   macros/Macs.s
            put   Equates.s

TiffSave    ext
svPW        =     4
svIcon      =     5
svIconAdd   =     6
svRIcon     =     7
svRIconAdd  =     8
svHex       =     9
svGIF       =     10
svPNG       =     11
svTIFF      =     12
svDesk      =     13
svBMP       =     16                    ; (14, 15: the Babelfish exports, not here)
svDHRBW     =     20                    ; (17-20: Apple II HiRes and Double HiRes)

* SaveFormat: A = format. Out: carry clear, or carry set and A = error.
SaveFormat  ent
            phb
            phk
            plb
            stz   outl
            stz   outl+2
            stz   ohnd
            stz   ohnd+2
            sec
            sbc   #svPW
            cmp   #svDHRBW-svPW+1
            bcs   :bad
            asl
            tax
            jsr   (:kinds,x)
            stz   DlgOn                 ; (the next save: SaveAsk says)
            plb
            rtl
:bad        lda   #errUnsupported
            sec
            plb
            rtl
:kinds      da    SavePW,SaveIcon,SaveIconAdd,SaveRIcon,SaveRIconAdd,SaveHex
            da    SaveGIF,SavePNG,SaveTIFF,SaveDesk,SaveNone,SaveNone,SaveBMP
            da    SaveHGR,SaveHGRBW,SaveDHR,SaveDHRBW
SaveNone    lda   #errNotImpl
            sec
            rts

*-------------------------------------------------------------
* The picture
*-------------------------------------------------------------

* Pix: the pixel value at (PX, PY) of the picture.
Pix         lda   PY
            jsr   TimesStr
            sta   t1
            lda   p640
            bne   :wide
            lda   PX
            lsr
            clc
            adc   t1
            tay
            lda   [scrp],y
            and   #$00FF
            sta   t1
            lda   PX
            lsr
            lda   t1
            bcs   :low
            lsr
            lsr
            lsr
            lsr
:low        and   #$000F
            rts
:wide       lda   PX
            lsr
            lsr
            clc
            adc   t1
            tay
            lda   [scrp],y
            and   #$00FF
            sta   t1
            lda   PX                    ; bits 7-6 for x & 3 = 0
            and   #$0003
            eor   #$0003
            asl
            tax
            lda   t1
:sh         cpx   #0
            beq   :got
            lsr
            dex
            bra   :sh
:got        and   #$0003
            rts

* Colour: the 12-bit colour shown for value A at (PX, PY): the line's
* colour table, and in 640 mode the column's part of it (8, 12, 0, 4).
Colour      sta   t2
            lda   PY
            clc
            adc   cscb
            tay
            lda   [scrp],y
            and   #$00FF
            sta   t1
            and   #$000F                ; the table
            asl
            asl
            asl
            asl
            asl
            clc
            adc   cpal
            sta   t3
            lda   t1
            and   #$0080
            beq   :narrow
            lda   PX
            and   #$0003
            tax
            lda   Off640,x
            and   #$00FF
            sta   t1
            lda   t2
            and   #$0003
            clc
            adc   t1
            bra   :entry
:narrow     lda   t2
            and   #$000F
:entry      asl
            clc
            adc   t3
            tay
            lda   [scrp],y
            and   #$0FFF
            rts

Off640      db    8,12,0,4
PalEnd      dw    0

* RowCols: RowC = the 12-bit colours shown along line PY (pw of them), as
* Pix and Colour give them: the line's table read once, then its bytes
* (a line in the picture's own mode; any other through Pix and Colour).
RowCols     lda   PY
            clc
            adc   cscb
            tay
            lda   [scrp],y
            and   #$00FF
            sta   RScb
            and   #$000F                ; the line's table
            asl
            asl
            asl
            asl
            asl
            clc
            adc   cpal
            tay
            ldx   #0
:c          lda   [scrp],y
            and   #$0FFF
            sta   LCol,x
            iny
            iny
            inx
            inx
            cpx   #32
            bcc   :c
            lda   pw
            asl
            sta   RPW2
            lda   PY
            jsr   TimesStr
            tay                         ; (Y: the line's bytes)
            ldx   #0                    ; (X: RowC)
            lda   RScb
            and   #$0080
            beq   :l320
            lda   p640
            bne   :f640
            bra   :slow
:l320       lda   p640
            beq   :f320
:slow       stz   PX                    ; (the line in the other mode)
:sl         phx
            jsr   Pix
            jsr   Colour
            plx
            sta   RowC,x
            inx
            inx
            inc   PX
            lda   PX
            cmp   pw
            bcc   :sl
            rts
:f320       lda   [scrp],y              ; two pixels a byte
            and   #$00FF
            sta   t1
            lsr
            lsr
            lsr
            and   #$001E
            phx
            tax
            lda   LCol,x
            plx
            sta   RowC,x
            inx
            inx
            cpx   RPW2
            bcs   :done
            lda   t1
            asl
            and   #$001E
            phx
            tax
            lda   LCol,x
            plx
            sta   RowC,x
            inx
            inx
            iny
            cpx   RPW2
            bcc   :f320
:done       rts
:f640       lda   [scrp],y              ; four a byte: entries 8, 12, 0, 4 on
            and   #$00FF
            sta   t1
            lsr
            lsr
            lsr
            lsr
            lsr
            lsr
            ora   #8
            asl
            phx
            tax
            lda   LCol,x
            plx
            sta   RowC,x
            inx
            inx
            cpx   RPW2
            bcs   :done
            lda   t1
            lsr
            lsr
            lsr
            lsr
            and   #3
            ora   #12
            asl
            phx
            tax
            lda   LCol,x
            plx
            sta   RowC,x
            inx
            inx
            cpx   RPW2
            bcs   :done
            lda   t1
            lsr
            lsr
            and   #3
            asl
            phx
            tax
            lda   LCol,x
            plx
            sta   RowC,x
            inx
            inx
            cpx   RPW2
            bcs   :done
            lda   t1
            and   #3
            ora   #4
            asl
            phx
            tax
            lda   LCol,x
            plx
            sta   RowC,x
            inx
            inx
            iny
            cpx   RPW2
            bcc   :f640
            rts

* TimesStr: A x the picture's bytes a line (cstr: 160 or 320).
TimesStr    asl
            asl
            asl
            asl
            asl
            sta   t0
            asl
            asl
            clc
            adc   t0
            phx
            ldx   cstr
            cpx   #320
            bne   :done
            asl
:done       plx
            rts

* RowBytes: bytes of one packed line of the picture.
RowBytes    lda   pw
            ldx   p640
            bne   :wide
            inc
            lsr
            rts
:wide       clc
            adc   #3
            lsr
            lsr
            rts

*-------------------------------------------------------------
* Output buffer
*-------------------------------------------------------------

* OutNew: a buffer of n0 (long) bytes for the file (it may cross banks).
OutNew      pha
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
            sta   n1
            lda   ohnd+2
            sta   n1+2
            lda   [n1]
            sta   outp
            sta   q0
            ldy   #2
            lda   [n1],y
            sta   outp+2
            sta   q0+2
            stz   outl
            stz   outl+2
            clc
:err        rts

* Put: one byte to the output (q0 is where the next goes). Keeps X and Y.
Put         sep   #$20
            mx    %10
            sta   [q0]
            rep   #$20
            mx    %00
            inc   q0
            bne   :n
            inc   q0+2
:n          inc   outl
            bne   :done
            inc   outl+2
:done       rts

* PutW: a 16-bit number, low byte first. PutL: n1 (long). PutWB: high byte first.
PutW        pha
            jsr   Put
            pla
            xba
            jmp   Put

PutWB       pha
            xba
            jsr   Put
            pla
            jmp   Put

* PutZeros: X zero bytes.
PutZeros    cpx   #0
            beq   :done
:z          lda   #0
            jsr   Put
            dex
            bne   :z
:done       rts

*-------------------------------------------------------------
* BMP: a Windows bitmap (BITMAPINFOHEADER, 8 bits a pixel, the colours
* in use as its palette, the rows bottom up, each padded to 4 bytes): the
* screen image as PNG and GIF save it (OW x OH)
*-------------------------------------------------------------
SaveBMP     jsr   Shown
            lda   OW                    ; bytes a row
            clc
            adc   #3
            and   #$FFFC
            sta   BRow
            ldx   OH                    ; the pixels' bytes
            jsr   Mul16
            lda   MLo
            sta   BImg
            lda   MHi
            sta   BImg+2
            lda   NCol                  ; where they start: 14 + 40 + 4 a colour
            asl
            asl
            clc
            adc   #54
            sta   BOff
            clc                         ; the file's size
            adc   BImg
            sta   n0
            sta   BSize
            lda   BImg+2
            adc   #0
            sta   n0+2
            sta   BSize+2
            jsr   OutNew
            bcc   :head
            rts
:head       lda   #$4D42                ; "BM", the size, 0, the offset
            jsr   PutW
            lda   BSize
            jsr   PutW
            lda   BSize+2
            jsr   PutW
            ldx   #4
            jsr   PutZeros
            lda   BOff
            jsr   PutW0
            lda   #40                   ; the info header: its size, width,
            jsr   PutW0                 ; height (positive: bottom up), 1
            lda   OW                    ; plane, 8 bits, no compression, the
            jsr   PutW0                 ; pixels' bytes, 72 dots an inch
            lda   OH                    ; (2835 a metre), the colours used
            jsr   PutW0
            lda   #1
            jsr   PutW
            lda   #8
            jsr   PutW
            ldx   #4
            jsr   PutZeros
            lda   BImg
            jsr   PutW
            lda   BImg+2
            jsr   PutW
            lda   #2835
            jsr   PutW0
            lda   #2835
            jsr   PutW0
            lda   NCol
            jsr   PutW0
            ldx   #4
            jsr   PutZeros
            ldx   #0                    ; the palette: blue, green, red, 0
:pal        cpx   NCol
            bcs   :rows
            phx
            txa
            asl
            tax
            lda   PalB,x
            jsr   Put
            lda   PalG,x
            jsr   Put
            lda   PalR,x
            jsr   Put
            lda   #0
            jsr   Put
            plx
            inx
            bra   :pal
:rows       lda   OH                    ; the lines, the last first
            sta   LineNo
:line       dec   LineNo
            lda   LineNo
            jsr   ShownRow
            ldy   #0
:px         cpy   OW
            bcs   :pad
            lda   ShowLine,y
            jsr   Put
            iny
            bra   :px
:pad        lda   BRow
            sec
            sbc   OW
            tax
            jsr   PutZeros
            lda   LineNo
            bne   :line
            lda   #$0006
            sta   otype
            stz   oaux
            stz   oaux+2
            clc
            rts

*-------------------------------------------------------------
* Apple II HiRes and Double HiRes ($06 BIN, A$2000; Double HiRes: the
* auxiliary half first): the picture stretched to the Apple II screen,
* each place taking the colour shown there, as the closest Apple II
* colour, or as a dot that is on where that colour is bright. They load
* back as Apple.s reads them.
*   HiRes colour: 280 dots; a byte's top bit set where more of its 7 dots
*   want blue or orange than violet or green; white on, black off, a colour
*   on where its dot shows it (violet, blue: even dots; green, orange: odd).
*   Double HiRes colour: 140 pixels of 4 dots, the colour's bits from the
*   top one first.
*-------------------------------------------------------------
SaveHGR     lda   #0
            bra   SaveA2
SaveHGRBW   lda   #1
            bra   SaveA2
SaveDHR     lda   #2
            bra   SaveA2
SaveDHRBW   lda   #3
SaveA2      sta   A2Kind
            asl
            tax
            lda   A2Ws,x                ; places on a line
            sta   A2W
            lda   A2Dots,x              ; dots on a line
            sta   A2DotN
            lda   A2Sizes,x
            sta   n0
            stz   n0+2
            jsr   OutNew
            bcc   :buf
            rts
:buf        ldx   n0                    ; (all dots off)
            jsr   PutZeros
            ldx   #3598                 ; no errors yet
:clr        stz   E0,x
            dex
            dex
            bpl   :clr
            stz   t1                    ; the columns of each place: from
            stz   t2                    ; i pw / W up to (i + 1) pw / W (one
            ldx   #0                    ; at least)
:cx         lda   t1
            asl
            sta   SrcX,x                ; (as an index into RowC)
            lda   t2
            clc
            adc   pw
:cn         cmp   A2W
            bcc   :cs
            sbc   A2W
            inc   t1
            bra   :cn
:cs         sta   t2
            lda   t1
            asl
            sec
            sbc   SrcX,x
            lsr
            bne   :cnt
            inc
:cnt        sta   SrcN,x
            inx
            inx
            txa
            lsr
            cmp   A2W
            bcc   :cx
            stz   A2SY                  ; the lines: from y ph / 192 up to
            stz   A2AccY                ; (y + 1) ph / 192 (one at least)
            stz   A2Y
:row        lda   A2SY
            sta   PY
            lda   A2AccY
            clc
            adc   ph
:rn         cmp   #192
            bcc   :rs
            sbc   #192
            inc   A2SY
            bra   :rn
:rs         sta   A2AccY
            lda   A2SY
            sec
            sbc   PY
            bne   :nr
            inc
:nr         sta   A2NR
            ldx   A2W                   ; no sums yet
            dex
            txa
            asl
            tax
:zs         stz   SumR,x
            stz   SumG,x
            stz   SumB,x
            dex
            dex
            bpl   :zs
            lda   A2NR
            sta   A2RL
:add        jsr   RowCols               ; (each of the picture's lines)
            jsr   AddRow
            inc   PY
            dec   A2RL
            bne   :add
            jsr   Average
            jsr   A2Line
            lda   A2Y
            jsr   HRowOff
            sta   A2Off
            jsr   PackDots
            inc   A2Y
            lda   A2Y
            cmp   #192
            bcs   :done
            jmp   :row
:done       lda   #$0006
            sta   otype
            lda   #$2000
            sta   oaux
            stz   oaux+2
            clc
            rts

* AddRow: each place's colours on line PY (RowC) added to its sums (SumR,
* SumG, SumB: channels 0-255).
AddRow      ldx   #0
:p          stx   A2I2
            lda   SrcN,x
            sta   A2N
            lda   SrcX,x
            tay
:px         lda   RowC,y
            sta   A2C
            xba
            and   #$000F
            asl
            tax
            lda   T17,x
            ldx   A2I2
            clc
            adc   SumR,x
            sta   SumR,x
            lda   A2C
            lsr
            lsr
            lsr
            and   #$001E
            tax
            lda   T17,x
            ldx   A2I2
            clc
            adc   SumG,x
            sta   SumG,x
            lda   A2C
            asl
            and   #$001E
            tax
            lda   T17,x
            ldx   A2I2
            clc
            adc   SumB,x
            sta   SumB,x
            iny
            iny
            dec   A2N
            bne   :px
            inx
            inx
            txa
            lsr
            cmp   A2W
            bcc   :p
            rts

* Average: each place's sums / its pixels (columns x lines), rounded down.
Average     ldx   #0
:p          lda   SrcN,x
            ldy   A2NR
:m          dey
            beq   :n
            clc
            adc   SrcN,x
            bra   :m
:n          sta   A2Cnt
            cmp   #1
            beq   :next
            lda   SumR,x
            jsr   A2Div
            sta   SumR,x
            lda   SumG,x
            jsr   A2Div
            sta   SumG,x
            lda   SumB,x
            jsr   A2Div
            sta   SumB,x
:next       inx
            inx
            txa
            lsr
            cmp   A2W
            bcc   :p
            rts

* A2Div: A / A2Cnt (2-15; A up to 3825), rounded down: halved while the
* count is even, then by 3 from a table, else bit by bit. Keeps X.
A2Div       ldy   A2Cnt
:even       pha
            tya
            lsr
            bcs   :odd
            tay
            pla
            lsr
            bra   :even
:odd        pla
            cpy   #1
            beq   :done
            cpy   #3
            bne   :slow
            cmp   #766
            bcs   :slow
            tay
            lda   Third,y
            and   #$00FF
:done       rts
:slow       sta   A2DS
            tya
            asl
            asl
            asl
            asl
            asl
            asl
            asl
            sta   A2DD                  ; (the divisor x 128: 8 bits of answer)
            stz   A2DQ
            ldy   #8
:l          asl   A2DQ
            lda   A2DS
            cmp   A2DD
            bcc   :no
            sbc   A2DD
            sta   A2DS
            inc   A2DQ
:no         lsr   A2DD
            dey
            bne   :l
            lda   A2DQ
            rts

* A2Line: Dots = the line's places (RowC through SrcX), each with the
* errors of the places before it spread on (Floyd-Steinberg: 7/16 to the
* right, 3/16, 5/16 and 1/16 to the line below), then the closest it can be:
* a colour number (Double HiRes), on (1) or off (black & white: 3R + 6G + B,
* 0-2550, at least half), or a HiRes dot pair (black, white, or the
* colour of the even or odd dot in its byte's colour pair). Errors at the
* edges are dropped. Double HiRes colour is then spread to 4 dots a pixel.
A2Line      lda   A2Kind
            bne   :nh
            jsr   HgrPlan               ; HiRes colour: each byte's colours
            sep   #$20
            mx    %10
            stz   CandL                 ; (a pair: black, white, the two colours)
            lda   #15
            sta   CandL+1
            rep   #$20
            mx    %00
            lda   #4
            sta   NC
            bra   :go
:nh         ldx   #0                    ; Double HiRes: all 16
:all        txa
            sep   #$20
            mx    %10
            sta   CandL,x
            rep   #$20
            mx    %00
            inx
            cpx   #16
            bcc   :all
            stx   NC
:go         ldx   #4
:z          stz   Car,x
            stz   E1v,x
            dex
            dex
            bpl   :z
            stz   A2I
:place      lda   A2I
            asl
            sta   A2I2
            lda   A2Kind
            lsr
            bcc   :rgb
            jmp   :bw
:rgb        ldy   A2I2                  ; colour: each channel, 0-255, with
            lda   SumR,y
            clc
            adc   E0+2,y
            clc
            adc   Car
            bpl   :Rp
            lda   #0
:Rp         cmp   #256
            bcc   :Ro
            lda   #255
:Ro         sta   VR
            lda   SumG,y
            clc
            adc   E0+1202,y
            clc
            adc   Car+2
            bpl   :Gp
            lda   #0
:Gp         cmp   #256
            bcc   :Go
            lda   #255
:Go         sta   VG
            lda   SumB,y
            clc
            adc   E0+2402,y
            clc
            adc   Car+4
            bpl   :Bp
            lda   #0
:Bp         cmp   #256
            bcc   :Bo
            lda   #255
:Bo         sta   VB
            lda   A2Kind
            bne   :near
            lda   A2I2                  ; HiRes: this pair's two colours
            tax
            lda   Dots,x
            sta   CandL+2
:near       jsr   Near
            lda   BestI
            sta   A2Out
            lda   VR
            sec
            sbc   PR
            ldx   #0
            jsr   Spread
            lda   VG
            sec
            sbc   PG
            ldx   #2
            jsr   Spread
            lda   VB
            sec
            sbc   PB
            ldx   #4
            jsr   Spread
            lda   A2Kind
            bne   :one
            lda   A2K                   ; HiRes: the pair's dots
            asl
            tay
            ldx   A2I2
            lda   PairBits,y
            sta   Dots,x
            bra   :nextp
:bw         ldy   A2I2                  ; black & white: 3R + 6G + B, 0-2550,
            lda   SumR,y                ; with the errors brought here
            asl
            adc   SumR,y
            sta   VR
            lda   SumG,y
            asl
            adc   SumG,y
            asl
            adc   VR
            adc   SumB,y
            clc
            adc   E0+2,y
            clc
            adc   Car
            bpl   :bp
            lda   #0
:bp         cmp   #2550
            bcc   :bo
            lda   #2550
:bo         stz   A2Out
            cmp   #1275
            bcc   :dark
            sbc   #2550
            inc   A2Out
:dark       ldx   #0
            jsr   Spread
:one        ldx   A2I
            sep   #$20
            mx    %10
            lda   A2Out
            sta   Dots,x
            rep   #$20
            mx    %00
:nextp      inc   A2I
            lda   A2I
            cmp   A2W
            bcs   :end
            jmp   :place
:end        lda   A2Kind
            cmp   #2
            bne   :done
            ldy   #139                  ; (from the end: the pixels' places
            ldx   #556                  ; are not overwritten before read)
:e          lda   Dots,y
            and   #$000F
            sta   A2V
            lda   #8
            sta   A2Mask
            phx
:eb         lda   A2V
            and   A2Mask
            beq   :z0
            lda   #1
:z0         sep   #$20
            mx    %10
            sta   Dots,x
            rep   #$20
            mx    %00
            inx
            lsr   A2Mask
            bne   :eb
            plx
            dex
            dex
            dex
            dex
            dey
            bpl   :e
:done       rts

* HgrPlan: each HiRes byte's colour pair, by its pairs' closest colours (of
* the six, before any errors): blue and orange where more want them than
* violet and green (Vote > 0); then Dots = each dot's colour when on.
HgrPlan     ldx   #78
:z          stz   Vote,x
            dex
            dex
            bpl   :z
            ldx   #0
:h          lda   HCand,x
            sep   #$20
            mx    %10
            sta   CandL,x
            rep   #$20
            mx    %00
            inx
            cpx   #6
            bcc   :h
            stx   NC
            stz   A2I
            stz   A2B
            stz   A2Rem
:p          lda   A2I
            asl
            tax
            lda   SumR,x
            sta   VR
            lda   SumG,x
            sta   VG
            lda   SumB,x
            sta   VB
            jsr   Near
            lda   A2B
            asl
            tax
            lda   BestI
            cmp   #12
            beq   :plus
            cmp   #3
            beq   :plus
            cmp   #9
            beq   :minus
            cmp   #6
            bne   :nv
:minus      dec   Vote,x
            bra   :nv
:plus       inc   Vote,x
:nv         lda   A2Rem                 ; the next pair's even dot: its byte
            clc
            adc   #2
            cmp   #7
            bcc   :r
            sbc   #7
            inc   A2B
:r          sta   A2Rem
            inc   A2I
            lda   A2I
            cmp   #140
            bcc   :p
            ldx   #0                    ; each dot's colour
            stz   A2B
            stz   A2Rem
:d          lda   A2B
            asl
            tay
            lda   Vote,y
            beq   :vg
            bmi   :vg
            txa
            lsr
            lda   #3                    ; orange (odd), blue (even)
            bcs   :set
            lda   #12
            bra   :set
:vg         txa
            lsr
            lda   #6                    ; green (odd), violet (even)
            bcs   :set
            lda   #9
:set        sep   #$20
            mx    %10
            sta   Dots,x
            rep   #$20
            mx    %00
            inc   A2Rem
            lda   A2Rem
            cmp   #7
            bcc   :dn
            stz   A2Rem
            inc   A2B
:dn         inx
            cpx   #280
            bcc   :d
            rts

* Near: the closest to VR, VG, VB of the NC colours in CandL (by the sum
* of the squared channel differences / 4; the first of equals; a colour
* left as soon as its sum so far is no better): BestI, its place A2K, its
* channels PR, PG, PB.
Near        lda   #$FFFF
            sta   A2Best
            stz   A2Kc
:c          ldx   A2Kc
            cpx   NC
            bcs   :done
            lda   CandL,x
            and   #$00FF
            asl
            tay
            lda   PalR8,y
            sec
            sbc   VR
            bpl   :1
            eor   #$FFFF
            inc
:1          lsr
            lsr
            asl
            tax
            lda   Squares,x
            cmp   A2Best
            bcs   :nx
            sta   A2D
            lda   PalG8,y
            sec
            sbc   VG
            bpl   :2
            eor   #$FFFF
            inc
:2          lsr
            lsr
            asl
            tax
            lda   Squares,x
            clc
            adc   A2D
            cmp   A2Best
            bcs   :nx
            sta   A2D
            lda   PalB8,y
            sec
            sbc   VB
            bpl   :3
            eor   #$FFFF
            inc
:3          lsr
            lsr
            asl
            tax
            lda   Squares,x
            clc
            adc   A2D
            cmp   A2Best
            bcs   :nx
            sta   A2Best
            sty   A2BY
            lda   A2Kc
            sta   A2K
:nx         inc   A2Kc
            bra   :c
:done       ldy   A2BY
            lda   PalR8,y
            sta   PR
            lda   PalG8,y
            sta   PG
            lda   PalB8,y
            sta   PB
            tya
            lsr
            sta   BestI
            rts

* Spread: error A of channel X (0, 2, 4) at place A2I2/2: 7/16 to the next
* place, 3/16 below left, 5/16 below, the rest below right (each rounded
* down).
Spread      sta   A2E
            asl
            asl
            asl
            sec
            sbc   A2E
            cmp   #$8000
            ror
            cmp   #$8000
            ror
            cmp   #$8000
            ror
            cmp   #$8000
            ror
            sta   A2E7
            sta   Car,x
            lda   A2E
            asl
            clc
            adc   A2E
            cmp   #$8000
            ror
            cmp   #$8000
            ror
            cmp   #$8000
            ror
            cmp   #$8000
            ror
            sta   A2E3
            lda   A2E
            asl
            asl
            clc
            adc   A2E
            cmp   #$8000
            ror
            cmp   #$8000
            ror
            cmp   #$8000
            ror
            cmp   #$8000
            ror
            sta   A2E5
            lda   A2I2
            clc
            adc   ChOff,x
            tay
            lda   E0,y                  ; below left
            clc
            adc   A2E3
            sta   E0,y
            lda   A2E5                  ; below (and the place before's 1/16)
            clc
            adc   E1v,x
            sta   E0+2,y
            lda   A2E                   ; the rest, below right
            sec
            sbc   A2E7
            sec
            sbc   A2E3
            sec
            sbc   A2E5
            sta   E1v,x
            rts

* PackDots: the line's dots (Dots: 1 on), 7 a byte from bit 0, into its
* bytes at A2Off; Double HiRes: the auxiliary half, then the main one.
PackDots    ldx   #0
            stz   A2Grp
:g          stz   A2Bits
            lda   #1
            sta   A2Mask
            lda   #7
            sta   A2N
:b          lda   Dots,x
            and   #$00FF
            beq   :z
            lda   A2Bits
            ora   A2Mask
            sta   A2Bits
:z          asl   A2Mask
            inx
            dec   A2N
            bne   :b
            lda   A2Kind                ; HiRes colour: the byte's colour pair
            bne   :pair
            lda   A2Grp
            asl
            tay
            lda   Vote,y
            beq   :pair
            bmi   :pair
            lda   A2Bits
            ora   #$80
            sta   A2Bits
:pair       lda   A2Grp
            ldy   A2Kind
            cpy   #2
            bcc   :put
            lsr                         ; Double HiRes: byte groups by turns
            bcc   :put                  ; in auxiliary and main memory
            adc   #8192-1
:put        clc
            adc   A2Off
            tay
            sep   #$20
            mx    %10
            lda   A2Bits
            sta   [outp],y
            rep   #$20
            mx    %00
            inc   A2Grp
            cpx   A2DotN
            bcc   :g
            rts

* HRowOff: A = screen line -> A = its offset in a HiRes page.
HRowOff     sta   t0
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
            lda   t0                    ; (y >> 6) * 40
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
            adc   t0
            asl
            asl
            asl
            clc
            adc   t1
            rts

* The Apple II colours, numbered as Apple.s loads them (Double HiRes
* bit order), and HiRes's six: black, white, violet, green, blue, orange.
A2Pal       dw    $000,$D03,$852,$F60,$070,$555,$0D0,$FF0
            dw    $009,$D0D,$AAA,$F98,$22F,$6AF,$0F9,$FFF
HCand       db    0,15,9,6,12,3
Squares     dw    0,1,4,9,16,25,36,49,64,81,100,121,144,169,196,225
            dw    256,289,324,361,400,441,484,529,576,625,676,729,784,841,900,961
            dw    1024,1089,1156,1225,1296,1369,1444,1521,1600,1681,1764,1849,1936,2025,2116,2209
            dw    2304,2401,2500,2601,2704,2809,2916,3025,3136,3249,3364,3481,3600,3721,3844,3969
* The Apple II colours' channels, 0-255.
PalR8       dw    0,221,136,255,0,85,0,255
            dw    0,221,170,255,34,102,0,255
PalG8       dw    0,0,85,102,119,85,221,255
            dw    0,0,170,153,34,170,255,255
PalB8       dw    0,51,34,0,0,85,0,0
            dw    153,221,170,136,255,255,153,255
T17         dw    0,17,34,51,68,85,102,119,136,153,170,187,204,221,238,255
* Third: n / 3 for n = 0-765.
Third       db    0,0,0,1,1,1,2,2,2,3,3,3,4,4,4,5,5,5,6,6,6,7,7,7
            db    8,8,8,9,9,9,10,10,10,11,11,11,12,12,12,13,13,13,14,14,14,15,15,15
            db    16,16,16,17,17,17,18,18,18,19,19,19,20,20,20,21,21,21,22,22,22,23,23,23
            db    24,24,24,25,25,25,26,26,26,27,27,27,28,28,28,29,29,29,30,30,30,31,31,31
            db    32,32,32,33,33,33,34,34,34,35,35,35,36,36,36,37,37,37,38,38,38,39,39,39
            db    40,40,40,41,41,41,42,42,42,43,43,43,44,44,44,45,45,45,46,46,46,47,47,47
            db    48,48,48,49,49,49,50,50,50,51,51,51,52,52,52,53,53,53,54,54,54,55,55,55
            db    56,56,56,57,57,57,58,58,58,59,59,59,60,60,60,61,61,61,62,62,62,63,63,63
            db    64,64,64,65,65,65,66,66,66,67,67,67,68,68,68,69,69,69,70,70,70,71,71,71
            db    72,72,72,73,73,73,74,74,74,75,75,75,76,76,76,77,77,77,78,78,78,79,79,79
            db    80,80,80,81,81,81,82,82,82,83,83,83,84,84,84,85,85,85,86,86,86,87,87,87
            db    88,88,88,89,89,89,90,90,90,91,91,91,92,92,92,93,93,93,94,94,94,95,95,95
            db    96,96,96,97,97,97,98,98,98,99,99,99,100,100,100,101,101,101,102,102,102,103,103,103
            db    104,104,104,105,105,105,106,106,106,107,107,107,108,108,108,109,109,109,110,110,110,111,111,111
            db    112,112,112,113,113,113,114,114,114,115,115,115,116,116,116,117,117,117,118,118,118,119,119,119
            db    120,120,120,121,121,121,122,122,122,123,123,123,124,124,124,125,125,125,126,126,126,127,127,127
            db    128,128,128,129,129,129,130,130,130,131,131,131,132,132,132,133,133,133,134,134,134,135,135,135
            db    136,136,136,137,137,137,138,138,138,139,139,139,140,140,140,141,141,141,142,142,142,143,143,143
            db    144,144,144,145,145,145,146,146,146,147,147,147,148,148,148,149,149,149,150,150,150,151,151,151
            db    152,152,152,153,153,153,154,154,154,155,155,155,156,156,156,157,157,157,158,158,158,159,159,159
            db    160,160,160,161,161,161,162,162,162,163,163,163,164,164,164,165,165,165,166,166,166,167,167,167
            db    168,168,168,169,169,169,170,170,170,171,171,171,172,172,172,173,173,173,174,174,174,175,175,175
            db    176,176,176,177,177,177,178,178,178,179,179,179,180,180,180,181,181,181,182,182,182,183,183,183
            db    184,184,184,185,185,185,186,186,186,187,187,187,188,188,188,189,189,189,190,190,190,191,191,191
            db    192,192,192,193,193,193,194,194,194,195,195,195,196,196,196,197,197,197,198,198,198,199,199,199
            db    200,200,200,201,201,201,202,202,202,203,203,203,204,204,204,205,205,205,206,206,206,207,207,207
            db    208,208,208,209,209,209,210,210,210,211,211,211,212,212,212,213,213,213,214,214,214,215,215,215
            db    216,216,216,217,217,217,218,218,218,219,219,219,220,220,220,221,221,221,222,222,222,223,223,223
            db    224,224,224,225,225,225,226,226,226,227,227,227,228,228,228,229,229,229,230,230,230,231,231,231
            db    232,232,232,233,233,233,234,234,234,235,235,235,236,236,236,237,237,237,238,238,238,239,239,239
            db    240,240,240,241,241,241,242,242,242,243,243,243,244,244,244,245,245,245,246,246,246,247,247,247
            db    248,248,248,249,249,249,250,250,250,251,251,251,252,252,252,253,253,253,254,254,254,255
A2Kc        dw    0
A2NR        dw    0
A2RL        dw    0
A2Cnt       dw    0
A2DS        dw    0
A2DD        dw    0
A2DQ        dw    0
A2I2        dw    0
A2BY        dw    0
PairBits    dw    $0000,$0101,$0001,$0100 ; (HiRes pair: black, white, even, odd)
ChOff       dw    0,1200,2400
CandL       ds    16
Vote        ds    80
VR          dw    0
VG          dw    0
VB          dw    0
PR          dw    0
PG          dw    0
PB          dw    0
Car         dw    0,0,0
E1v         dw    0,0,0
A2I         dw    0
A2K         dw    0
A2Out       dw    0
NC          dw    0
BestI       dw    0
A2Rem       dw    0
A2E         dw    0
A2E1        dw    0
A2E3        dw    0
A2E5        dw    0
A2E7        dw    0
A2Ws        dw    140,280,140,560
A2Dots      dw    280,280,560,560
A2Sizes     dw    8192,8192,16384,16384
A2Kind      dw    0
A2W         dw    0
A2DotN      dw    0
A2AccY      dw    0
A2SY        dw    0
A2Y         dw    0
A2Off       dw    0
A2C         dw    0
A2V         dw    0
A2D         dw    0
A2P         dw    0
A2B         dw    0
A2Best      dw    0
A2Mask      dw    0
A2Bits      dw    0
A2N         dw    0
A2Grp       dw    0

* PutW0: A as a 32-bit number (high word 0), low byte first.
PutW0       jsr   PutW
            lda   #0
            jmp   PutW

*-------------------------------------------------------------
* PaintWorks ($C0/0000): colour table 0, a word, 512 bytes of
* patterns (left empty), then the lines packed with PackBytes
*-------------------------------------------------------------
SavePW      lda   p640
            beq   :ok
            lda   #errPW640
            sec
            rts
:ok         lda   #40000                ; plenty for 200 packed lines
            sta   n0
            stz   n0+2
            jsr   OutNew
            bcc   :buf
            rts
:buf        lda   cpal
            clc
            adc   #32
            sta   PalEnd
            ldy   cpal
:pal        lda   [scrp],y
            and   #$0FFF
            jsr   PutW
            iny
            iny
            cpy   PalEnd
            bcc   :pal
            lda   #0
            jsr   PutW
            ldx   #512
            jsr   PutZeros
            stz   PY                    ; each line: its 160 bytes, packed
:line       lda   PY
            jsr   TimesStr
            clc
            adc   scrp
            sta   PkSrc
            lda   scrp+2
            adc   #0
            sta   PkSrc+2
            lda   q0
            sta   PkDst
            lda   q0+2
            sta   PkDst+2
            lda   #160
            sta   PkLen
            pha                         ; result: bytes made
            PushLong PkSrc              ; (where the line is: moved on by the call)
            PushLong PkLen              ; (its length: counted down)
            PushLongAt PkDst
            pea   400                   ; room
            Tool  _PackBytes
            pla
            sta   t1                    ; move on past them
            clc
            adc   q0
            sta   q0
            bcc   :q
            inc   q0+2
:q          lda   outl
            clc
            adc   t1
            sta   outl
            bcc   :o
            inc   outl+2
:o          inc   PY
            lda   PY
            cmp   ph
            bcc   :line
            lda   #$00C0
            sta   otype
            stz   oaux
            stz   oaux+2
            clc
            rts

*-------------------------------------------------------------
* Icons
*-------------------------------------------------------------

* IconAt: the icon pixel source: the picture (Reduced = 0), or GS Remap's
* reduced copy for the Finder's small icons. Sets SrcW, SrcH.
IconSize    lda   pw
            sta   SrcW
            lda   ph
            sta   SrcH
            lda   Reduced
            bne   :small
            rts
:small      lda   #8                    ; target: 16 x 8 (640 mode) or 8 x 8
            ldx   p640
            beq   :tw
            asl
:tw         sta   t1
            lda   pw                    ; step = max(1, ceil(w / tw), ceil(h / 8))
            clc
            adc   t1
            dec
            ldx   t1
            jsr   Div16
            sta   Step
            lda   ph
            clc
            adc   #7
            lsr
            lsr
            lsr
            cmp   Step
            bcc   :s
            sta   Step
:s          lda   Step
            bne   :s1
            inc   Step
:s1         lda   #1                    ; 640 mode keeps pixel pairs together
            ldx   p640
            beq   :unit
            inc
:unit       sta   Unit
            lda   pw                    ; w = max(unit, (pw / step) / unit * unit)
            ldx   Step
            jsr   Div16
            ldx   Unit
            cpx   #2
            bne   :w
            and   #$FFFE
:w          cmp   Unit
            bcs   :wOK
            lda   Unit
:wOK        sta   SrcW
            lda   ph                    ; h = max(1, ph / step)
            ldx   Step
            jsr   Div16
            bne   :h
            inc
:h          sta   SrcH
            rts

* SrcPix: value of icon source pixel (SX, SY).
SrcPix      lda   Reduced
            bne   :small
            lda   SX
            sta   PX
            lda   SY
            sta   PY
            jmp   Pix
:small      lda   SY                    ; y: min(h - 1, y * step)
            ldx   Step
            jsr   Mul16
            lda   MLo
            cmp   ph
            bcc   :y
            lda   ph
            dec
:y          sta   PY
            lda   SX                    ; x: min(w - 1, (x / unit) * step * unit + x % unit)
            ldx   Unit
            cpx   #2
            bne   :one
            lsr
:one        ldx   Step
            jsr   Mul16
            lda   MLo
            ldx   Unit
            cpx   #2
            bne   :x1
            asl
            sta   t1
            lda   SX
            and   #$0001
            ora   t1
:x1         cmp   pw
            bcc   :x
            lda   pw
            dec
:x          sta   PX
            jmp   Pix

* PutIcon: an icon record: type, size, height, width, image, mask.
* 4 bits a pixel; in 640 mode one icon pixel is a pair of screen pixels.
PutIcon     jsr   IconSize
            lda   SrcW                  ; icon width and bytes a row
            ldx   p640
            beq   :w
            inc
            lsr
:w          sta   IconW
            inc
            lsr
            sta   IconRow
            ldx   SrcH
            jsr   Mul16
            lda   MLo
            sta   IconBytes
            lda   #$8000                ; colour icon
            jsr   PutW
            lda   IconBytes
            jsr   PutW
            lda   SrcH
            jsr   PutW
            lda   IconW
            jsr   PutW
            lda   #0                    ; the image, then the mask (all opaque)
            sta   Mask
            jsr   :pixels
            lda   #1
            sta   Mask
            jsr   :pixels
            rts
:pixels     stz   SY
:row        stz   IX
:byte       stz   t3                    ; two icon pixels a byte
            lda   IX
            jsr   IconPixel
            asl
            asl
            asl
            asl
            sta   t3
            lda   IX
            inc
            cmp   IconW
            bcs   :one
            jsr   IconPixel
            ora   t3
            sta   t3
:one        lda   t3
            jsr   Put
            lda   IX
            inc
            inc
            sta   IX
            cmp   IconW
            bcc   :byte
            inc   SY
            lda   SY
            cmp   SrcH
            bcc   :row
            rts

* IconPixel: icon pixel A of row SY (the mask: 15).
IconPixel   ldx   Mask
            beq   :image
            lda   #15
            rts
:image      ldx   p640
            bne   :pair
            sta   SX
            jmp   SrcPix
:pair       asl                         ; left << 2 | right (3 past the edge)
            sta   SX
            jsr   SrcPix
            asl
            asl
            sta   t2
            lda   SX
            inc
            cmp   SrcW
            bcs   :edge
            sta   SX
            jsr   SrcPix
            ora   t2
            rts
:edge       lda   #3
            ora   t2
            rts

* CheckIcon: Finder icons are 640 mode and at most 160 x 50.
CheckIcon   lda   p640
            bne   :mode
            lda   #errIcon640
            sec
            rts
:mode       lda   pw
            cmp   #161
            bcs   :big
            lda   ph
            cmp   #51
            bcs   :big
            clc
            rts
:big        lda   #errIconBig
            sec
            rts

* PutRecord: one Finder icon record: length, application (Pascal, 64),
* name pattern "*" (Pascal, 16), file type, aux type, large and small icons.
PutRecord   lda   q0                    ; where the length goes
            sta   q1
            lda   q0+2
            sta   q1+2
            lda   outl
            sta   RecStart
            lda   outl+2
            sta   RecStart+2
            lda   #0
            jsr   PutW
            ldx   #64                   ; no application
            jsr   PutZeros
            lda   #1                    ; "*"
            jsr   Put
            lda   #'*'
            jsr   Put
            ldx   #14
            jsr   PutZeros
            lda   #0                    ; any file type, aux type
            jsr   PutW
            lda   #0
            jsr   PutW
            stz   Reduced
            jsr   PutIcon
            lda   #1
            sta   Reduced
            jsr   PutIcon
            lda   outl                  ; the record's length
            sec
            sbc   RecStart
            sep   #$20
            mx    %10
            sta   [q1]
            xba
            ldy   #1
            sta   [q1],y
            rep   #$20
            mx    %00
            rts

* A new Finder icon file ($CA): a 26-byte header (version 1), the record, 0.
SaveIcon    jsr   CheckIcon
            bcc   :ok
            rts
:ok         jsr   IconOut
            bcc   :buf
            rts
:buf        ldx   #4
            jsr   PutZeros
            lda   #1
            jsr   PutW
            ldx   #20
            jsr   PutZeros
            bra   IconEnd

* Adding an icon to the file read into fp/flen.
SaveIconAdd jsr   CheckIcon
            bcc   :check
            rts
:check      lda   flen+2                ; a Finder icon file?
            bne   :len
            lda   flen
            cmp   #28
            bcc   :bad
:len        ldy   #4
            lda   [fp],y
            cmp   #1
            bne   :bad
            lda   #26                   ; after its last record
            sta   u0
:walk       lda   u0
            inc
            inc
            jsr   InFile
            bcs   :end
            ldy   u0
            lda   [fp],y
            beq   :end
            clc
            adc   u0
            bcs   :bad
            sta   t1
            jsr   InFile
            bcs   :bad
            lda   t1
            sta   u0
            bra   :walk
:bad        lda   #errNotPicture
            sec
            rts
:end        lda   flen                  ; room: the file and a record
            clc
            adc   #4000
            sta   n0
            lda   flen+2
            adc   #0
            sta   n0+2
            jsr   OutNew
            bcc   :copy
            rts
:copy       ldy   #0                    ; the file up to there
:c          cpy   u0
            bcs   IconEnd2
            lda   [fp],y
            jsr   Put
            iny
            bra   :c
IconEnd2
IconEnd     jsr   PutRecord
            jsr   IconDlg               ; (its criteria, if the dialogs show)
            bcc   :end
            rts
:end        lda   #0
            jsr   PutW
            lda   #$00CA
            sta   otype
            stz   oaux
            stz   oaux+2
            clc
            rts

* IconOut: an output buffer big enough for a Finder icon file.
IconOut     lda   #9000
            sta   n0
            stz   n0+2
            jmp   OutNew

* InFile: carry clear if offset A <= the file's length.
InFile      ldx   flen+2
            bne   :ok
            cmp   flen
            beq   :ok
            bcc   :ok
            sec
            rts
:ok         clc
            rts

*-------------------------------------------------------------
* Icon resources (rIcon, $8001), with the Resource Manager
*-------------------------------------------------------------
SaveRIcon   lda   #1                    ; a new resource file
            sta   RNew
            bra   RIcon
SaveRIconAdd stz  RNew
RIcon       lda   pw                    ; at most a quarter of the screen: 8000 image bytes
            sta   SrcW
            ldx   p640
            beq   :w
            inc
            lsr
:w          inc
            lsr
            ldx   ph
            jsr   Mul16
            lda   MHi
            bne   :big
            lda   MLo
            cmp   #8001
            bcc   :ok
:big        lda   #errIconRes
            sec
            rts
:ok         asl                         ; the resource: 8 + image + mask
            clc
            adc   #8
            sta   n0
            stz   n0+2
            jsr   OutNew
            bcc   :icon
            rts
:icon       stz   Reduced
            jsr   PutIcon
            lda   RNew
            beq   :open
            lda   pathp                 ; a new file: replace whatever is there
            sta   DestroyP+2
            lda   pathp+2
            sta   DestroyP+4
            jsl   $E100A8
            da    $2002
            adrl  DestroyP
            pea   0                     ; aux type
            pea   0
            pea   $0006                 ; file type: binary
            pea   $00C3                 ; access
            PushLongAt pathp
            Tool  _CreateResourceFile
            bcc   :open
            jmp   :fail
:open       pha                         ; result: file ID
            pea   3                     ; read and write
            PushLong 0
            PushLongAt pathp
            Tool  _OpenResourceFile
            pla
            sta   RFile
            bcc   :opened
            jmp   :fail
:opened     pha                         ; (result: the old depth)
            pea   1                     ; look in this file only
            Tool  _SetResourceFileDepth
            pla
            lda   #1                    ; the lowest free ID
            sta   RId
            stz   RId+2
:id         pha
            pha
            pea   $8001
            PushLongAt RId
            Tool  _GetResourceSize
            pla
            pla
            bcs   :free
            inc   RId
            bne   :id
:free       PushLongAt ohnd             ; the Resource Manager takes the handle
            pea   0
            pea   $8001
            PushLongAt RId
            Tool  _AddResource
            php
            pha
            stz   ohnd                  ; (no longer ours)
            stz   ohnd+2
            pha
            pea   $FFFF                 ; every file again
            Tool  _SetResourceFileDepth
            pla
            lda   RFile
            pha
            Tool  _CloseResourceFile
            pla
            plp
            bcs   :fail2
            stz   outl                  ; written already
            stz   outl+2
            clc
            rts
:fail2      sec
            rts
:fail       pha
            pha                         ; (free the icon)
            PushLongAt ohnd
            Tool  _DisposeHandle
            pla
            stz   ohnd
            stz   ohnd+2
            pla
            sec
            rts

DestroyP    dw    1
            adrl  0

*-------------------------------------------------------------
* Hex data: a line of text for each picture line, its packed bytes
* in hexadecimal: HexStart before, HexSep between, HexEnd after (" dc h'",
* " ", "'" unless the options window changed them)
*-------------------------------------------------------------
SaveHex     jsr   RowBytes
            sta   HRow
            lda   HexSep                ; room: a line has 2 + the separator a
            and   #$00FF                ; byte (less one separator), the start,
            sta   HLSep                 ; the end and a return
            clc
            adc   #2
            ldx   HRow
            jsr   Mul16
            lda   MLo
            sec
            sbc   HLSep
            sta   n0
            lda   HexStart
            and   #$00FF
            clc
            adc   n0
            sta   n0
            lda   HexEnd
            and   #$00FF
            sec                         ; (+ 1)
            adc   n0
            ldx   ph
            jsr   Mul16
            lda   MLo
            sta   n0
            lda   MHi
            sta   n0+2
            jsr   OutNew
            bcc   :lines
            rts
:lines      stz   PY
:line       ldx   #HexStart
            jsr   PutPS
            lda   PY
            jsr   TimesStr
            tay
            lda   HRow
            sta   HCnt
:b          lda   [scrp],y
            and   #$00FF
            pha
            lsr
            lsr
            lsr
            lsr
            jsr   :digit
            pla
            and   #$000F
            jsr   :digit
            dec   HCnt
            beq   :after
            ldx   #HexSep
            jsr   PutPS
            iny
            bra   :b
:after      ldx   #HexEnd
            jsr   PutPS
            lda   #$0D
            jsr   Put
            inc   PY
            lda   PY
            cmp   ph
            bcc   :line
            lda   #$0004                ; text
            sta   otype
            stz   oaux
            stz   oaux+2
            clc
            rts
:digit      tax
            lda   HexDigits,x
            and   #$00FF
            jmp   Put

* PutPS: the Pascal string at X (this bank) put out (Y kept).
PutPS       lda   |0,x
            and   #$00FF
            beq   :out
            sta   HLeft
:c          inx
            lda   |0,x
            and   #$00FF
            phx
            jsr   Put
            plx
            dec   HLeft
            bne   :c
:out        rts

HCnt        dw    0
HLeft       dw    0
HLSep       dw    0
* The three fields (Pascal strings, up to 20 characters; the options
* window's edit lines read and write them)
HexStart    db    6                     ; " dc h'"
            asc   ' dc h'
            db    $27
            ds    14
HexSep      db    1                     ; " "
            asc   ' '
            ds    19
HexEnd      db    1                     ; "'"
            db    $27
            ds    19
HexDigits   asc   '0123456789ABCDEF'

*-------------------------------------------------------------
* The picture as GS Remap shows it, for GIF, PNG and TIFF: OW x OH
* palette indexes (320 mode pixels twice, every line twice)
*-------------------------------------------------------------

* Shown: OW, OH; the colours in use as a palette (NCol, PalR/G/B, and
* CIdx: the palette index of each 12-bit colour).
Shown       lda   pw
            ldx   p640
            bne   :w
            asl
:w          sta   OW
            lda   ph
            asl
            sta   OH
            lda   #$FFFF                ; (no line in ShowLine yet)
            sta   ShowPY
            ldx   #8190                 ; no colours yet
            lda   #$FFFF
:clr        sta   CIdx,x
            dex
            dex
            bpl   :clr
            stz   NCol
            stz   PY
:row        jsr   RowCols               ; (the line's colours)
            stz   PX
:pix        lda   PX
            asl
            tax
            lda   RowC,x
            asl
            tax
            lda   CIdx,x
            bpl   :known
            lda   NCol
            sta   CIdx,x
            asl
            tay
            txa                         ; its 8-bit channels
            lsr
            sta   t1
            xba
            and   #$000F
            jsr   Times17
            sta   PalR,y
            lda   t1
            lsr
            lsr
            lsr
            lsr
            and   #$000F
            jsr   Times17
            sta   PalG,y
            lda   t1
            and   #$000F
            jsr   Times17
            sta   PalB,y
            inc   NCol
:known      inc   PX
            lda   PX
            cmp   pw
            bcc   :pix
            inc   PY
            lda   PY
            cmp   ph
            bcc   :row
            rts

* ShownRow: ShowLine = output line A (OW indexes).
ShownRow    lsr
            cmp   ShowPY                ; (the picture's line is already
            bne   :new                  ; there: lines are shown twice)
            rts
:new        sta   ShowPY
            sta   PY
            jsr   RowCols               ; (the line's colours)
            stz   PX
            ldy   #0
:pix        lda   PX
            asl
            tax
            lda   RowC,x
            asl
            tax
            lda   CIdx,x
            sep   #$20
            mx    %10
            sta   ShowLine,y
            iny
            ldx   p640
            bne   :one
            sta   ShowLine,y
            iny
:one        rep   #$20
            mx    %00
            inc   PX
            lda   PX
            cmp   pw
            bcc   :pix
            rts

Times17     sta   t0
            asl
            asl
            asl
            asl
            ora   t0
            rts

*-------------------------------------------------------------
* PNG: 8-bit palette picture; zlib data in one fixed-code block,
* each line filtered None (the doubled ones Up), runs as copies
*-------------------------------------------------------------
SavePNG     jsr   PngOpts               ; (the options window: its choices)
            bcc   :go
            rts
:go         jsr   Shown
            jsr   CrcTable
            lda   OW                    ; room: (OW + 1) * OH * 9 / 8 + 2048
            inc
            ldx   OH
            jsr   Mul16
            lda   MLo
            sta   n0
            lda   MHi
            sta   n0+2
            lsr   MHi
            ror   MLo
            lsr   MHi
            ror   MLo
            lsr   MHi
            ror   MLo
            lda   n0
            clc
            adc   MLo
            sta   n0
            lda   n0+2
            adc   MHi
            sta   n0+2
            lda   n0
            clc
            adc   #2048
            sta   n0
            bcc   :n
            inc   n0+2
:n          jsr   OutNew
            bcc   :sig
            rts
:sig        ldx   #0
:s          lda   PngSig,x
            jsr   Put
            inx
            cpx   #8
            bcc   :s
            lda   #13                   ; IHDR
            ldx   #IhdrTag
            jsr   ChunkStart
            lda   #0                    ; width, height (in the CRC too)
            jsr   PutWBC
            lda   OW
            jsr   PutWBC
            lda   #0
            jsr   PutWBC
            lda   OH
            jsr   PutWBC
            lda   #8                    ; 8 bits, palette, deflate, no filter set, no interlace
            jsr   CPut
            lda   #3
            jsr   CPut
            ldx   #3
:hz         lda   #0
            jsr   CPut
            dex
            bne   :hz
            jsr   ChunkEnd
            lda   NCol                  ; PLTE
            asl
            clc
            adc   NCol
            ldx   #PlteTag
            jsr   ChunkStart
            ldx   #0
:p          lda   PalR,x
            jsr   CPut
            lda   PalG,x
            jsr   CPut
            lda   PalB,x
            jsr   CPut
            inx
            inx
            txa
            lsr
            cmp   NCol
            bcc   :p
            jsr   ChunkEnd
            jsr   PngText               ; the comments (tEXt)
            lda   #0                    ; IDAT: its length filled in afterwards
            jsr   ChunkStartIDAT
            lda   PngUse
            beq   :std
            jsr   DeflateM              ; (the options window's choices)
            bra   :idat
:std        jsr   Deflate
:idat
            lda   outl                  ; its length, now known
            sec
            sbc   DataAt
            sta   t1
            lda   outl+2
            sbc   DataAt+2
            sta   t2
            lda   LenAt
            sta   q1
            lda   LenAt+2
            sta   q1+2
            lda   t2
            xba
            ldy   #0
            sta   [q1],y
            lda   t1
            xba
            ldy   #2
            sta   [q1],y
            jsr   ChunkEnd
            lda   #0                    ; IEND
            ldx   #0
:e          lda   IendTag,x
            jsr   Put
            inx
            cpx   #12
            bcc   :e
            lda   #$0006                ; binary, aux type: none
            sta   otype
            stz   oaux
            stz   oaux+2
            clc
            rts

PngSig      hex   89504E470D0A1A0A
IendTag     hex   0000000049454E44AE426082
IhdrTag     asc   'IHDR'
PlteTag     asc   'PLTE'
IdatTag     asc   'IDAT'

* ChunkStart: a chunk of A bytes with the 4-byte tag at X (in this bank).
ChunkStart  pha
            lda   #0
            jsr   PutWB
            pla
            jsr   PutWB
            jsr   CrcInit
            ldy   #4
:t          lda   |0,x
            and   #$00FF
            jsr   CPut
            inx
            dey
            bne   :t
            rts

* CPut: a byte of chunk data (counted in its CRC). Keeps X and Y.
CPut        pha
            jsr   CrcByte
            pla
            jmp   Put

* ChunkEnd: the CRC.
ChunkEnd    lda   Crc
            eor   #$FFFF
            sta   t1
            lda   Crc+2
            eor   #$FFFF
            jsr   PutWB
            lda   t1
            jmp   PutWB

* ChunkStartIDAT: the IDAT header, noting where its length goes.
ChunkStartIDAT lda q0
            sta   LenAt
            lda   q0+2
            sta   LenAt+2
            lda   #0
            jsr   PutWB
            lda   #0
            jsr   PutWB
            jsr   CrcInit
            ldx   #0
:t          lda   IdatTag,x
            and   #$00FF
            jsr   CPut
            inx
            cpx   #4
            bcc   :t
            lda   outl
            sta   DataAt
            lda   outl+2
            sta   DataAt+2
            rts

* Deflate: the zlib stream of the lines.
Deflate     lda   #$78                  ; zlib: deflate, 32K window; no dictionary
            jsr   CPut
            lda   #$01
            jsr   CPut
            lda   #1                    ; Adler-32
            sta   AdA
            stz   AdB
            stz   BitBuf
            stz   BitCnt
            lda   #1                    ; last block, fixed codes
            ldx   #1
            jsr   Bits
            lda   #1
            ldx   #2
            jsr   Bits
            stz   LineNo
:line       lda   LineNo
            and   #$0001
            bne   :dup
            lda   LineNo
            jsr   ShownRow
            lda   #0                    ; filter: None
            jsr   Raw
            ldy   #0
:byte       cpy   OW
            bcs   :next
            lda   ShowLine,y
            and   #$00FF
            jsr   Raw
            iny
            bra   :byte
:dup        lda   #2                    ; the same line again: Up, all zeros
            jsr   Raw
            lda   OW
            jsr   RawZeros
:next       inc   LineNo
            lda   LineNo
            cmp   OH
            bcc   :line
            jsr   Flush                 ; any run, then the end code
            lda   #256
            jsr   Sym
            lda   BitCnt                ; to a byte boundary
            beq   :adler
            lda   BitBuf
            jsr   CPut
:adler      lda   AdB                   ; Adler-32, high byte first
            jsr   PutWBC
            lda   AdA
            jsr   PutWBC
            rts

* DeflateM: as Deflate, with the PNG options window's choices: filter
* None on every line (PngFilter 0) or Up for the repeated ones (1, Auto);
* from level 6, matches against the line above too (copies from a line
* back).
DeflateM    lda   #$78                  ; zlib header, block header (as Deflate)
            jsr   CPut
            lda   #$01
            jsr   CPut
            lda   #1
            sta   AdA
            stz   AdB
            stz   BitBuf
            stz   BitCnt
            stz   RunLen
            lda   #1
            ldx   #1
            jsr   Bits
            lda   #1
            ldx   #2
            jsr   Bits
            stz   LineNo
            stz   HavePrev
            lda   OW                    ; a line: its filter byte and pixels
            inc
            sta   RowLen
:line       lda   LineNo
            and   #$0001
            beq   :new
            lda   PngFilter             ; a repeated line: as it is (None),
            beq   :code                 ; or Up and zeros (Auto)
            ldx   #0
            lda   #2
:z          sep   #$20
            mx    %10
            sta   CurRaw,x
            rep   #$20
            mx    %00
            lda   #0
            inx
            cpx   RowLen
            bcc   :z
            bra   :code
:new        lda   LineNo
            jsr   ShownRow
            sep   #$20
            mx    %10
            stz   CurRaw
            ldx   #0
:c          lda   ShowLine,x
            sta   CurRaw+1,x
            inx
            cpx   OW
            bcc   :c
            rep   #$20
            mx    %00
:code       jsr   RowOut
            ldx   #0                    ; (the line above, for the next)
:p          lda   CurRaw,x
            sta   PrevRaw,x
            inx
            inx
            cpx   RowLen
            bcc   :p
            lda   #1
            sta   HavePrev
            inc   LineNo
            lda   LineNo
            cmp   OH
            bcc   :line
            jsr   Flush                 ; the end (as Deflate)
            lda   #256
            jsr   Sym
            lda   BitCnt
            beq   :adler
            lda   BitBuf
            jsr   CPut
:adler      lda   AdB
            jsr   PutWBC
            lda   AdA
            jmp   PutWBC

* RowOut: line CurRaw coded: from level 6 a copy where 3 or more bytes
* are as in the line above, else bytes (and runs) as Deflate codes them.
RowOut      stz   RI
:b          lda   RI
            cmp   RowLen
            bcc   :more
            rts
:more       lda   HavePrev
            beq   :lit
            lda   PngLevel
            cmp   #6
            bcc   :lit
            ldx   RI                    ; how many as above
            ldy   #0
:m          cpx   RowLen
            bcs   :mend
            cpy   #258
            bcs   :mend
            lda   CurRaw,x
            eor   PrevRaw,x
            and   #$00FF
            bne   :mend
            inx
            iny
            bra   :m
:mend       cpy   #3
            bcc   :lit
            sty   MatchN
            jsr   Flush                 ; (the run waiting first; it uses CopyN)
            lda   MatchN
            sta   CopyN
            ldx   RI                    ; (the bytes in the checksum)
            ldy   CopyN
:ad         lda   CurRaw,x
            and   #$00FF
            sta   t2
            jsr   Adler
            inx
            dey
            bne   :ad
            lda   RowLen
            sta   CopyDist
            jsr   CopyD
            lda   RI
            clc
            adc   CopyN
            sta   RI
            bra   :b
:lit        ldx   RI
            lda   CurRaw,x
            and   #$00FF
            jsr   Raw
            inc   RI
            jmp   :b

* CopyD: a copy of CopyN bytes (3-258) from CopyDist back.
CopyD       ldx   #0                    ; its length code and extra bits
:find       lda   LenBase+2,x
            cmp   CopyN
            beq   :next
            bcs   :got
:next       inx
            inx
            cpx   #56
            bcc   :find
:got        lda   CopyN
            sec
            sbc   LenBase,x
            sta   CopyX
            txa
            lsr
            clc
            adc   #257
            phx
            jsr   Sym
            plx
            lda   LenExt,x
            tax
            lda   CopyX
            jsr   Bits
            ldx   #0                    ; its distance code and extra bits
:df         lda   DistBase+2,x
            cmp   CopyDist
            beq   :dn
            bcs   :dg
:dn         inx
            inx
            cpx   #58
            bcc   :df
:dg         lda   CopyDist
            sec
            sbc   DistBase,x
            sta   CopyX
            phx
            txa
            lsr
            ldx   #5
            jsr   BitsRev
            plx
            lda   DistExt,x
            tax
            lda   CopyX
            jmp   Bits

DistBase    dw    1,2,3,4,5,7,9,13,17,25,33,49,65,97,129,193,257,385,513,769
            dw    1025,1537,2049,3073,4097,6145,8193,12289,16385,24577,32769
DistExt     dw    0,0,0,0,1,1,2,2,3,3,4,4,5,5,6,6,7,7,8,8,9,9,10,10,11,11,12,12,13,13

* PngText: the comments as a tEXt chunk ("Comment", a zero, the text),
* if there are any.
PngText     lda   PngUse
            beq   :out
            lda   PngTLen
            beq   :out
            clc
            adc   #8
            ldx   #TextTag
            jsr   ChunkStart
            ldx   #0
:k          lda   TxComment,x
            and   #$00FF
            jsr   CPut
            inx
            cpx   #8
            bcc   :k
            ldx   #0
:t          lda   PngTBuf,x
            and   #$00FF
            jsr   CPut
            inx
            cpx   PngTLen
            bcc   :t
            jsr   ChunkEnd
:out        rts
TextTag     asc   'tEXt'
TxComment   asc   'Comment',00

PutWBC      pha
            xba
            and   #$00FF
            jsr   CPut
            pla
            and   #$00FF
            jmp   CPut

* Raw: the next byte of the uncompressed data: counts it, and codes it
* as a literal or as part of a run of the byte before.
Raw         and   #$00FF
            sta   RawB
            sta   t2
            jsr   Adler
            lda   RunLen
            beq   :lit
            lda   RawB
            cmp   RunByte
            bne   :flushLit
            inc   RunLen
            lda   RunLen
            cmp   #258
            bcc   :done
            jmp   Flush
:flushLit   jsr   Flush
:lit        lda   RawB                  ; a literal starts the next run
            sta   RunByte
            jsr   Sym
            lda   #1                    ; (the literal itself; repeats follow)
            sta   RunLen
:done       rts

* RawZeros: A bytes of 0, as Raw would take them one by one: their Adler
* sums, then the run they continue or start (a copy each time it reaches
* 258, a new literal after that).
RawZeros    sta   ZLeft
            beq   :done
            tax                         ; Adler: A stays, B gains A each time
            lda   AdB
:ad         clc
            adc   AdA
            bcs   :wrap
            cmp   #65521
            bcc   :ok
:wrap       sbc   #65521
:ok         dex
            bne   :ad
            sta   AdB
            stz   RawB
:z          lda   ZLeft
            beq   :done
            lda   RunLen                ; a run of 0s going on?
            beq   :lit
            lda   RunByte
            beq   :more
            jsr   Flush
:lit        stz   RunByte               ; a literal 0 starts the next run
            lda   #0
            jsr   Sym
            lda   #1
            sta   RunLen
            dec   ZLeft
            bra   :z
:more       lda   #258                  ; as many as fit in the run
            sec
            sbc   RunLen
            cmp   ZLeft
            bcc   :part
            lda   ZLeft
:part       sta   t2
            clc
            adc   RunLen
            sta   RunLen
            lda   ZLeft
            sec
            sbc   t2
            sta   ZLeft
            lda   RunLen
            cmp   #258
            bcc   :z
            jsr   Flush
            bra   :z
:done       rts

* Flush: the repeats of the last literal: copies at distance 1 (3-258 at a time).
Flush       lda   RunLen
            beq   :done
            dec                         ; repeats after the literal
            sta   FLeft
:copy       lda   FLeft
            beq   :end
            cmp   #3
            bcc   :lits
            cmp   #259
            bcc   :len
            lda   #258
:len        sta   CopyN
            jsr   Copy
            lda   FLeft
            sec
            sbc   CopyN
            sta   FLeft
            bra   :copy
:lits       lda   RunByte               ; 1 or 2: as literals
            jsr   Sym
            dec   FLeft
            bne   :lits
:end        stz   RunLen
:done       rts

* Copy: a copy of CopyN bytes (3-258) from distance 1.
Copy        ldx   #0                    ; its length code and extra bits
:find       lda   LenBase+2,x
            cmp   CopyN
            beq   :next
            bcs   :got
:next       inx
            inx
            cpx   #56
            bcc   :find
:got        lda   CopyN
            sec
            sbc   LenBase,x
            sta   CopyX
            txa
            lsr
            clc
            adc   #257
            phx
            jsr   Sym
            plx
            lda   LenExt,x
            tax
            lda   CopyX
            jsr   Bits
            lda   #0                    ; distance code 0 (distance 1): 5 bits of 0
            ldx   #5
            jmp   BitsRev

LenBase     dw    3,4,5,6,7,8,9,10,11,13,15,17,19,23,27,31
            dw    35,43,51,59,67,83,99,115,131,163,195,227,258,259
LenExt      dw    0,0,0,0,0,0,0,0,1,1,1,1,2,2,2,2
            dw    3,3,3,3,4,4,4,4,5,5,5,5,0,0

* Sym: a symbol of the fixed literal/length code, its code reversed from
* RevCode (made the first time).
Sym         pha                         ; (keeps Y, as Bits does)
            lda   RevDone
            bne   :have
            jsr   RevMake
:have       pla
            asl
            tax
            lda   RevCode,x
            sta   SymR
            txa
            lsr
            cmp   #144
            ldx   #8
            bcc   :len
            cmp   #256
            ldx   #9
            bcc   :len
            cmp   #280
            ldx   #7
            bcc   :len
            ldx   #8
:len        lda   SymR
            jmp   Bits

* RevMake: RevCode = each symbol's fixed code, its bits reversed.
RevMake     stz   RevSym
:s          lda   RevSym
            jsr   SymCode               ; A = the code, X = its bits
            sta   t0
            stz   t1
:r          lsr   t0
            rol   t1
            dex
            bne   :r
            lda   RevSym
            asl
            tax
            lda   t1
            sta   RevCode,x
            inc   RevSym
            lda   RevSym
            cmp   #288
            bcc   :s
            inc   RevDone
            rts

* SymCode: symbol A's fixed code (A) and its length (X).
SymCode     cmp   #144
            bcs   :s9
            clc
            adc   #$30                  ; 0-143: 8 bits from $30
            ldx   #8
            rts
:s9         cmp   #256
            bcs   :s7
            clc
            adc   #$190-144             ; 144-255: 9 bits from $190
            ldx   #9
            rts
:s7         cmp   #280
            bcs   :s8
            sec
            sbc   #256                  ; 256-279: 7 bits from 0
            ldx   #7
            rts
:s8         sec
            sbc   #280-$C0              ; 280-287: 8 bits from $C0
            ldx   #8
            rts

* BitsRev: a Huffman code of X bits (1-16), highest bit first: reversed,
* then as Bits.
BitsRev     sta   t0
            stx   t1
            stz   BRev
:r          lsr   t0
            rol   BRev
            dex
            bne   :r
            lda   BRev
            ldx   t1

* Bits: the low X bits of A (up to 16), lowest first: into the BitCnt
* (0-7) bits waiting in BitBuf, and out a byte at a time. Keeps Y.
Bits        cpx   #0
            beq   :none
            stx   BN
            pha
            txa
            asl
            tax
            pla
            and   BitsMask,x
            stz   BVH
            ldx   BitCnt                ; shifted past the bits waiting
            beq   :or
:sh         asl
            rol   BVH
            dex
            bne   :sh
:or         ora   BitBuf
            sta   BitBuf
            lda   BVH
            sta   BitHi
            lda   BitCnt
            clc
            adc   BN
            sta   BitCnt
            cmp   #8
            bcc   :none
            phy
:emit       lda   BitBuf                ; a whole byte: out, and the rest
            and   #$00FF                ; down 8 (BitHi follows BitBuf)
            jsr   CPut
            lda   BitBuf+1
            sta   BitBuf
            lda   BitHi+1
            and   #$00FF
            sta   BitHi
            lda   BitCnt
            sec
            sbc   #8
            sta   BitCnt
            cmp   #8
            bcs   :emit
            ply
:none       rts

BitsMask    dw    0,1,3,7,15,31,63,127,255,511,1023,2047,4095,8191,16383,32767,65535

* Adler: the Adler-32 sums with byte t2.
Adler       lda   AdA
            clc
            adc   t2
            cmp   #65521
            bcc   :a
            sbc   #65521
:a          sta   AdA
            clc
            adc   AdB
            bcs   :wrap
            cmp   #65521
            bcc   :b
:wrap       sbc   #65521
:b          sta   AdB
            rts

* CrcTable: the CRC-32 table (once).
CrcTable    lda   CrcDone
            bne   :done
            inc   CrcDone
            ldx   #0
:entry      txa
            lsr
            lsr
            sta   t1                    ; c = n
            stz   t2
            ldy   #8
:bit        lsr   t2
            ror   t1
            bcc   :even
            lda   t1
            eor   #$8320
            sta   t1
            lda   t2
            eor   #$EDB8
            sta   t2
:even       dey
            bne   :bit
            lda   t1
            sta   CrcLo,x
            lda   t2
            sta   CrcHi,x
            inx
            inx
            inx
            inx
            cpx   #1024
            bcc   :entry
:done       rts

CrcInit     lda   #$FFFF
            sta   Crc
            sta   Crc+2
            rts

* CrcByte: the CRC with byte A. Keeps X and Y.
CrcByte     phx
            and   #$00FF
            eor   Crc
            and   #$00FF
            asl
            asl
            tax
            lda   Crc                   ; crc >> 8
            xba
            and   #$00FF
            sta   CrcT
            lda   Crc+2
            xba
            pha
            and   #$FF00
            ora   CrcT
            eor   CrcLo,x
            sta   Crc
            pla
            and   #$00FF
            eor   CrcHi,x
            sta   Crc+2
            plx
            rts

*-------------------------------------------------------------
* GIF 87a: the shown picture, LZW (codes up to 12 bits, a clear
* code when the table is full), in blocks of up to 255 bytes
*-------------------------------------------------------------
SaveGIF     jsr   Shown
            lda   OW                    ; room: OW * OH * 3 / 2 + 2048
            ldx   OH
            jsr   Mul16
            lda   MLo
            sta   n0
            lda   MHi
            sta   n0+2
            lsr   MHi
            ror   MLo
            lda   n0
            clc
            adc   MLo
            sta   n0
            lda   n0+2
            adc   MHi
            sta   n0+2
            lda   n0
            clc
            adc   #2048
            sta   n0
            bcc   :n
            inc   n0+2
:n          jsr   OutNew
            bcc   :head
            rts
:head       ldx   #0
:h          lda   GifSig,x
            jsr   Put
            inx
            cpx   #6
            bcc   :h
            lda   OW
            jsr   PutW
            lda   OH
            jsr   PutW
            ldx   #0                    ; table bits: 2 << bits >= colours
:bits       inx
            lda   #2
            phx
:pw         cpx   #1
            beq   :pwd
            asl
            dex
            bra   :pw
:pwd        plx
            cmp   NCol
            bcc   :bits
            stx   GBits                 ; colours 2^GBits
            sta   GEntries
            txa
            dec
            ora   #$00F0                ; global table, 8-bit colour resolution
            jsr   Put
            lda   #0                    ; background, aspect
            jsr   Put
            lda   #0
            jsr   Put
            ldx   #0                    ; the table
:col        txa
            lsr
            cmp   NCol
            bcs   :pad
            lda   PalR,x
            jsr   Put
            lda   PalG,x
            jsr   Put
            lda   PalB,x
            jsr   Put
            bra   :colN
:pad        lda   #0
            jsr   Put
            lda   #0
            jsr   Put
            lda   #0
            jsr   Put
:colN       inx
            inx
            txa
            lsr
            cmp   GEntries
            bcc   :col
            jsr   GifNote               ; (the upload note, the progress)
            lda   #$2C                  ; the image: all of it, not interlaced
            jsr   Put
            lda   #0
            jsr   PutW
            lda   #0
            jsr   PutW
            lda   OW
            jsr   PutW
            lda   OH
            jsr   PutW
            lda   #0
            jsr   Put
            lda   GBits                 ; minimum code size (at least 2)
            cmp   #2
            bcs   :min
            lda   #2
:min        sta   MinCode
            jsr   Put
            jsr   Lzw
            lda   #0                    ; no more blocks, the end
            jsr   Put
            lda   #$3B
            jsr   Put
            lda   #$0006
            sta   otype
            stz   oaux
            stz   oaux+2
            clc
            rts

GifSig      asc   'GIF87a'

* Lzw: the picture's indexes, coded.
Lzw         ldx   MinCode               ; clear = 2^min, end = clear + 1
            lda   #1
:p          asl
            dex
            bne   :p
            sta   ClearC
            inc
            sta   EndC
            stz   GAcc
            stz   GAcc+2
            stz   GCnt
            stz   BlkLen
            jsr   LzwReset
            lda   ClearC
            jsr   Code
            lda   #$FFFF
            sta   Cur                   ; no string yet
            stz   LineNo
:line       jsr   GifBar                ; (the progress bar, before each line)
            lda   LineNo
            jsr   ShownRow
            ldy   #0
:pix        cpy   OW                    ; (a string that goes on, found at
            bcs   :nextLine             ; the first place it hashes to: here;
            lda   ShowLine,y            ; anything else through LzwChar,
            iny                         ; which looks it up again)
            sty   LzY
            and   #$00FF
            sta   Ch
            ldx   Cur
            bmi   :slow
            asl
            asl
            asl
            asl
            eor   Cur
            cmp   #5003
            bcc   :in
            sbc   #5003
:in         asl
            tax
            lda   HCode,x
            bmi   :slow
            lda   HPre,x
            cmp   Cur
            bne   :slow
            lda   HChr,x
            and   #$00FF
            cmp   Ch
            bne   :slow
            lda   HCode,x
            sta   Cur
            ldy   LzY
            bra   :pix
:slow       lda   Ch
            jsr   LzwChar
            ldy   LzY
            bra   :pix
:nextLine   inc   LineNo
            lda   LineNo
            cmp   OH
            bcc   :line
            lda   Cur
            bmi   :end
            jsr   Code
:end        lda   EndC
            jsr   Code
            lda   GCnt                  ; the last bits
            beq   :blk
            lda   GAcc
            jsr   BlkByte
:blk        jmp   BlkFlush

* LzwReset: an empty table.
LzwReset    lda   MinCode
            inc
            sta   CSize
            lda   ClearC
            clc
            adc   #2
            sta   NextC
            ldx   #10004                ; hash table empty
            lda   #$FFFF
:c          sta   HCode,x
            dex
            dex
            bpl   :c
            rts

* LzwChar: the next index A.
LzwChar     sta   Ch
            lda   Cur
            bpl   :have
            lda   Ch                    ; the first one: a string of one
            sta   Cur
            rts
:have       jsr   Hash                  ; is cur + ch in the table?
:probe      lda   HCode,x
            bmi   :absent
            lda   HPre,x
            cmp   Cur
            bne   :other
            lda   HChr,x
            and   #$00FF
            cmp   Ch
            bne   :other
            lda   HCode,x               ; yes: it becomes the string
            sta   Cur
            rts
:other      txa                         ; next place to look
            sec
            sbc   HStep
            bcs   :wrapped
            adc   #10006
:wrapped    tax
            bra   :probe
:absent     stx   HAt
            lda   Cur                   ; no: out goes cur
            jsr   Code
            lda   NextC
            cmp   #4096
            bcs   :full
            ldx   HAt                   ; cur + ch gets the next code
            sta   HCode,x
            lda   Cur
            sta   HPre,x
            lda   Ch
            sep   #$20
            mx    %10
            sta   HChr,x
            rep   #$20
            mx    %00
            inc   NextC
            ldx   CSize                 ; wider codes once 2^size is passed
            cpx   #12
            bcs   :same
            lda   NextC
            asl
            tax
            lda   CSize
            asl
            tay
            lda   Pow2,y
            cmp   NextC
            bcs   :same
            inc   CSize
            bra   :same
:full       lda   ClearC                ; table full: clear and start again
            jsr   Code
            jsr   LzwReset
:same       lda   Ch
            sta   Cur
            rts

Pow2        dw    1,2,4,8,16,32,64,128,256,512,1024,2048,4096

* Hash: X = where cur + ch is looked for (times 2), HStep the step (times 2).
Hash        lda   Ch                    ; (ch << 4) ^ cur, below 5003
            asl
            asl
            asl
            asl
            eor   Cur
:mod        cmp   #5003
            bcc   :in
            sbc   #5003
            bra   :mod
:in         sta   t1
            asl
            tax
            lda   #1                    ; step: 5003 - h, or 1 for h = 0
            ldy   t1
            beq   :step
            lda   #5003
            sec
            sbc   t1
:step       asl
            sta   HStep
            rts

* Code: code A, CSize bits, lowest first, into the data blocks.
Code        sta   t1
            stz   t2
            ldx   GCnt                  ; shifted to where the waiting bits end
:sh         cpx   #0
            beq   :or
            asl   t1
            rol   t2
            dex
            bra   :sh
:or         lda   GAcc
            ora   t1
            sta   GAcc
            lda   GAcc+2
            ora   t2
            sta   GAcc+2
            lda   GCnt
            clc
            adc   CSize
            sta   GCnt
:out        lda   GCnt                  ; whole bytes go out
            cmp   #8
            bcc   :done
            lda   GAcc
            and   #$00FF
            jsr   BlkByte
            ldx   #8
:dr         lsr   GAcc+2
            ror   GAcc
            dex
            bne   :dr
            lda   GCnt
            sec
            sbc   #8
            sta   GCnt
            bra   :out
:done       rts

* BlkByte: a data byte; 255 of them make a block.
BlkByte     ldx   BlkLen
            sep   #$20
            mx    %10
            sta   Blk,x
            rep   #$20
            mx    %00
            inx
            stx   BlkLen
            cpx   #255
            bcc   :done
            jmp   BlkFlush
:done       rts

BlkFlush    lda   BlkLen
            beq   :done
            jsr   Put
            ldx   #0
:b          lda   Blk,x
            jsr   Put
            inx
            cpx   BlkLen
            bcc   :b
            stz   BlkLen
:done       rts

*-------------------------------------------------------------
* TIFF: Intel order, 8-bit palette picture in one strip, PackBits
*-------------------------------------------------------------
SaveTIFF    lda   DlgOn                 ; (with the save's dialogs: SuperConvert's
            jsl   TiffSave              ; TIFF Save Options, TiffOpt.s)
            bcs   :done
            cmp   #$FFFF
            beq   :std
            clc
:done       rts
:std        jsr   Shown
            lda   OW                    ; room: OW * OH * 9 / 8 + 4096
            ldx   OH
            jsr   Mul16
            lda   MLo
            sta   n0
            lda   MHi
            sta   n0+2
            lsr   MHi
            ror   MLo
            lsr   MHi
            ror   MLo
            lsr   MHi
            ror   MLo
            lda   n0
            clc
            adc   MLo
            sta   n0
            lda   n0+2
            adc   MHi
            sta   n0+2
            lda   n0
            clc
            adc   #4096
            sta   n0
            bcc   :n
            inc   n0+2
:n          jsr   OutNew
            bcc   :head
            rts
:head       lda   #$4949                ; "II", 42, the directory at 8
            jsr   PutW
            lda   #42
            jsr   PutW
            lda   #8
            jsr   PutW
            lda   #0
            jsr   PutW
            lda   #10                   ; ten entries
            jsr   PutW
            ldx   #0
:entry      lda   TiffDir,x             ; tag, type
            jsr   PutW
            lda   TiffDir+2,x
            jsr   PutW
            lda   TiffDir+4,x           ; count (long)
            jsr   PutW
            lda   #0
            jsr   PutW
            lda   TiffDir+6,x           ; value: fixed, or filled in later
            cmp   #$FFFF
            bne   :value
            jsr   :later
:value      jsr   PutW
            lda   #0
            jsr   PutW
            txa
            clc
            adc   #8
            tax
            cpx   #80
            bcc   :entry
            lda   #0                    ; no next directory
            jsr   PutW
            lda   #0
            jsr   PutW
            ldx   #0                    ; colour map: reds, greens, blues (* 257)
:r          lda   PalR,x
            jsr   :map
            inx
            inx
            cpx   #512
            bcc   :r
            ldx   #0
:g          lda   PalG,x
            jsr   :map
            inx
            inx
            cpx   #512
            bcc   :g
            ldx   #0
:b          lda   PalB,x
            jsr   :map
            inx
            inx
            cpx   #512
            bcc   :b
            lda   outl                  ; the strip: each line PackBits packed
            sta   StripAt
            stz   LineNo
:line       lda   LineNo
            jsr   ShownRow
            jsr   PackLine
            inc   LineNo
            lda   LineNo
            cmp   OH
            bcc   :line
            lda   outl                  ; the strip's length
            sec
            sbc   StripAt
            sta   t1
            lda   outl+2
            sbc   #0
            sta   t2
            lda   outp                  ; fill in the values left for later
            sta   q1
            lda   outp+2
            sta   q1+2
            ldy   #78                   ; strip offset (entry 6: 10 + 5 * 12 + 8)
            lda   StripAt
            sta   [q1],y
            ldy   #114                  ; strip byte count (entry 9: 10 + 8 * 12 + 8)
            lda   t1
            sta   [q1],y
            iny
            iny
            lda   t2
            sta   [q1],y
            lda   #$0006
            sta   otype
            stz   oaux
            stz   oaux+2
            clc
            rts
:later      lda   TiffDir,x             ; width, height, rows a strip, colour map
            cmp   #256
            beq   :ow
            cmp   #257
            beq   :oh
            cmp   #278
            beq   :oh
            cmp   #320
            beq   :cmap
            lda   #0
            rts
:ow         lda   OW
            rts
:oh         lda   OH
            rts
:cmap       lda   #8+2+120+4            ; right after the directory
            rts
:map        and   #$00FF                ; 8 bits to 16
            sta   t1
            xba
            ora   t1
            jmp   PutW

* Directory entries: tag, type (3 short, 4 long), count, value ($FFFF: later).
TiffDir     dw    256,3,1,$FFFF
            dw    257,3,1,$FFFF
            dw    258,3,1,8
            dw    259,3,1,32773
            dw    262,3,1,3
            dw    273,4,1,0
            dw    277,3,1,1
            dw    278,3,1,$FFFF
            dw    279,4,1,0
            dw    320,3,768,$FFFF

* PackLine: ShowLine (OW bytes) in PackBits: runs of 2-128, literals of 1-128.
PackLine    stz   Pi
:next       lda   Pi
            cmp   OW
            bcc   :start
            rts
:start      ldy   Pi                    ; how long a run starts here
            lda   ShowLine,y
            and   #$00FF
            sta   t2
            iny
:run        tya
            sec
            sbc   Pi
            cmp   #128
            bcs   :runEnd
            cpy   OW
            bcs   :runEnd
            lda   ShowLine,y
            and   #$00FF
            cmp   t2
            bne   :runEnd
            iny
            bra   :run
:runEnd     tya
            sec
            sbc   Pi
            cmp   #2
            bcc   :literal
            eor   #$00FF                ; 257 - n, then the byte
            clc
            adc   #2
            jsr   Put
            lda   t2
            jsr   Put
            sty   Pi
            bra   :next
:literal    ldy   Pi                    ; up to the next pair of equal bytes
            iny
:lit        tya
            sec
            sbc   Pi
            cmp   #128
            bcs   :litEnd
            cpy   OW
            bcs   :litEnd
            tya
            inc
            cmp   OW
            bcs   :take
            lda   ShowLine,y
            and   #$00FF
            sta   t3
            lda   ShowLine+1,y
            and   #$00FF
            cmp   t3
            beq   :litEnd
:take       iny
            bra   :lit
:litEnd     sty   Pj
            tya
            sec
            sbc   Pi
            dec
            jsr   Put
            ldy   Pi
:copy       lda   ShowLine,y
            jsr   Put
            iny
            cpy   Pj
            bcc   :copy
            sty   Pi
            jmp   :next

*-------------------------------------------------------------
* Helpers
*-------------------------------------------------------------

* Mul16: MLo/MHi = A * X.
Mul16       sta   MA
            stz   MAHi
            stx   MB
            stz   MLo
            stz   MHi
:loop       lda   MB
            beq   :done
            lsr   MB
            bcc   :shift
            clc
            lda   MLo
            adc   MA
            sta   MLo
            lda   MHi
            adc   MAHi
            sta   MHi
:shift      asl   MA
            rol   MAHi
            bra   :loop
:done       rts

* Div16: A / X (X not 0), the quotient in A.
Div16       sta   DvN
            stx   DvD
            stz   DvQ
            stz   DvR
            ldx   #16
:bit        asl   DvN
            rol   DvR
            lda   DvR
            sec
            sbc   DvD
            bcc   :no
            sta   DvR
:no         rol   DvQ
            dex
            bne   :bit
            lda   DvQ
            rts

*-------------------------------------------------------------
* Data
*-------------------------------------------------------------
PX          dw    0
PY          dw    0
SX          dw    0
SY          dw    0
SrcW        dw    0
SrcH        dw    0
Step        dw    1
Unit        dw    1
Reduced     dw    0
Mask        dw    0
IX          dw    0
IconW       dw    0
IconRow     dw    0
IconBytes   dw    0
RecStart    adrl  0
RNew        dw    0
RFile       dw    0
RId         adrl  0
HRow        dw    0
OW          dw    0
OH          dw    0
NCol        dw    0
LineNo      dw    0
Crc         adrl  0
CrcDone     dw    0
CrcT        dw    0
LenAt       adrl  0
DataAt      adrl  0
AdA         dw    0
AdB         dw    0
LzY         dw    0                     ; (Lzw: the next pixel)
ShowPY      dw    0
BRow        dw    0                     ; (SaveBMP: bytes a row, the pixels'
BImg        adrl  0                     ; bytes, where they start, the
BOff        dw    0                     ; file's size)
BSize       adrl  0
RevDone     dw    0                     ; (RevCode made; RevMake's symbol;
RevSym      dw    0                     ; each fixed code reversed)
RevCode     ds    576
ZLeft       dw    0                     ; (RawZeros: the 0s left)
SymR        dw    0                     ; (Sym: the code reversed)                     ; (ShownRow: the line ShowLine holds)
RScb        dw    0                     ; (RowCols: the line's SCB, its colours,
RPW2        dw    0                     ; the line's pixels x 2, the colours
LCol        ds    32                    ; along it)
RowC        ds    1280
BitBuf      dw    0                     ; (the bits waiting, and above them
BitHi       dw    0                     ; up to 16 more: Bits)
BitCnt      dw    0
BRev        dw    0                     ; (BitsRev: the code reversed;
BN          dw    0                     ; Bits: how many, and the bits
BVH         dw    0                     ; shifted past 16)
RunLen      dw    0
RunByte     dw    0
RawB        dw    0
FLeft       dw    0
CopyN       dw    0
CopyX       dw    0
GBits       dw    0
GEntries    dw    0
MinCode     dw    0
ClearC      dw    0
EndC        dw    0
CSize       dw    0
NextC       dw    0
Cur         dw    0
Ch          dw    0
HAt         dw    0
HStep       dw    0
GAcc        adrl  0
GCnt        dw    0
BlkLen      dw    0
StripAt     dw    0
Pi          dw    0
Pj          dw    0
PkSrc       adrl  0
PkDst       adrl  0
PkLen       dw    0
MA          dw    0
MAHi        dw    0
MB          dw    0
MLo         dw    0
MHi         dw    0
DvN         dw    0
DvD         dw    0
DvQ         dw    0
DvR         dw    0
Blk         ds    256
PalR        ds    512
PalG        ds    512
PalB        ds    512
ShowLine    ds    1284
RowLen      dw    0
RI          dw    0
HavePrev    dw    0
CopyDist    dw    0
MatchN      dw    0
CrcLo       ds    1024                  ; (low and high words, 4 bytes apart)
CrcHi       =     CrcLo+2
CIdx        ds    8192
HCode       ds    10008
HPre        ds    10008
SrcX        =     HCode                 ; (Apple II: each place's column,
Dots        =     HPre                  ; and its line,
E0          =     HChr                  ; the errors for the next line,
SumR        =     HChr+3600             ; each place's colour)
SumG        =     HChr+4800
SumB        =     HChr+6000
SrcN        =     HCode+1200            ; (and its number of columns)
HChr        ds    10008
CurRaw      =     HChr                  ; PNG lines (DeflateM): this one, the one
PrevRaw     =     HChr+1286             ; above (in GIF's table: PNG doesn't use it)
            put   SaveDlg.s
            put   SaveOpts.s
