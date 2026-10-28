*-------------------------------------------------------------
* Actions.s - the image window's actions on the images (part of the main
* program; docs/superconvert-image-window.md 7.5 and 8): Crop to
* selection, Discard this image type, Discard other image types, and
* Apple-w. The Desk segment (ImgTools.s) asks for them through dact, with
* the shown type in darg.
*-------------------------------------------------------------

* ImgAction: dact 3 crop, 4 discard this type, 5 discard the others, 6
* close (every image goes).
ImgAction   lda   dact
            cmp   #6
            bne   :n6
            jmp   CloseImages
:n6         cmp   #3
            bne   :n3
            jmp   CropSel
:n3         cmp   #4
            bne   :n4
            jmp   DiscardThis
:n4         cmp   #5
            bne   :out
            jmp   DiscardOthers
:out        rts

* DiscardThis: the shown type's image goes; the window shows the first
* left (none left: as Close).
DiscardThis lda   darg
            jsr   DropType
            jmp   AfterDrop

* DiscardOthers: every other type's image goes.
DiscardOthers ldx #1
:t          cpx   darg
            beq   :next
            phx
            txa
            jsr   DropType
            plx
:next       inx
            cpx   #4
            bcc   :t
            jmp   AfterDrop

* DropType: image type A (1 screen, 2 true colour, 3 monochrome) goes.
DropType    pha
            jsl   DeskSelClear
            pla
            cmp   #2
            beq   :true
            bcs   :mono
            stz   HaveScreen
            rts
:true       jmp   FreeTrue
:mono       lda   MonoBlk
            beq   :none
            PushLongAt MonoHnd
            Tool  _DisposeHandle
            stz   MonoBlk
:none       rts

* AfterDrop: the window follows; with no image left, as Close.
AfterDrop   lda   HaveScreen
            ora   IsTrue
            ora   MonoBlk
            bne   :some
            jmp   CloseImages
:some       jmp   TellDesk

* CropSel: the shown type's image cut down to its selection.
CropSel     lda   darg
            jsl   DeskSel               ; (dsel, dselr, dselu)
            lda   dsel
            bne   :have
            rts
:have       lda   darg
            cmp   #2
            beq   :true
            bcs   :mono
            jmp   CropScr
:true       jmp   CropTrue
:mono       jmp   CropMono

* CropScr: the screen image: the selected bytes of the selected lines to
* the start of each line, the lines (and their modes) to the top, the rest
* cleared; then shown as after a load.
CropScr     lda   dselr+2               ; whole bytes (4 columns each)
            lsr
            lsr
            sta   CLeft
            lda   dselr+6
            lsr
            lsr
            sec
            sbc   CLeft
            sta   CBytes
            lda   dselr+4
            sec
            sbc   dselr
            sta   CLines
            lda   ScreenP               ; (offsets within the buffer)
            sta   p0
            lda   ScreenP+2
            sta   p0+2
            stz   t3                    ; the new line
:line       lda   t3
            cmp   #200
            bcs   :scbs
            jsr   Times160
            sta   t2                    ; where it goes
            ldx   #0
            lda   t3
            cmp   CLines
            bcs   :clr                  ; (below the picture: cleared)
            clc
            adc   dselr
            jsr   Times160
            clc
            adc   CLeft
            sta   t1                    ; where it comes from
:b          cpx   CBytes
            bcs   :clr
            txa
            clc
            adc   t1
            tay
            lda   [p0],y
            sta   CByte
            txa
            clc
            adc   t2
            tay
            sep   #$20
            mx    %10
            lda   CByte
            sta   [p0],y
            rep   #$20
            mx    %00
            inx
            bra   :b
:clr        cpx   #160
            bcs   :nextL
            txa
            clc
            adc   t2
            tay
            sep   #$20
            mx    %10
            lda   #0
            sta   [p0],y
            rep   #$20
            mx    %00
            inx
            bra   :clr
:nextL      inc   t3
            bra   :line
:scbs       stz   t3                    ; the lines' modes and colour tables
:s          lda   t3                    ; move up with them; below, the first
            cmp   CLines                ; line's
            bcc   :from
            lda   #0
            bra   :src
:from       clc
            adc   dselr
:src        cmp   t3                    ; (line 0's is already in place)
            bcc   :read
            beq   :sNext
:read       clc
            adc   #scbOffset
            tay
            lda   [p0],y
            sta   CByte
            lda   t3
            clc
            adc   #scbOffset
            tay
            sep   #$20
            mx    %10
            lda   CByte
            sta   [p0],y
            rep   #$20
            mx    %00
:sNext      inc   t3
            lda   t3
            cmp   #200
            bcc   :s
            lda   CBytes                ; the new size, in pixels
            asl
            ldx   Pic640
            beq   :w
            asl
:w          sta   PicW
            lda   CLines
            sta   PicH
            lda   #1                    ; shown as after a load
            jsl   DeskSelClear
            lda   #1
            sta   ShowType
            jmp   PictureMenus

* Times160: A x 160.
Times160    asl
            asl
            asl
            asl
            asl                         ; x 32
            sta   t0
            asl
            asl                         ; x 128
            clc
            adc   t0
            rts

* CropTrue: the true colour image: the selected pixels of the selected
* rows packed at the start of its block (left and right in pixels: image
* units / dselu).
CropTrue    lda   dselr+2
            ldx   dselu
            cpx   #2
            bne   :l
            lsr
:l          sta   CLeft
            lda   dselr+6
            cpx   #2
            bne   :r
            lsr
:r          sec
            sbc   CLeft
            sta   CBytes                ; (pixels across)
            asl
            clc
            adc   CBytes
            sta   CStride               ; x 3: bytes a new row
            lda   dselr+4
            sec
            sbc   dselr
            sta   CLines
            lda   TrueP                 ; p1: where the rows go
            sta   p1
            lda   TrueP+2
            sta   p1+2
            lda   dselr                 ; p0: the first selected pixel
            ldx   TrueStride
            jsr   Mul16
            lda   CLeft
            asl
            clc
            adc   CLeft
            clc
            adc   ProdLo
            sta   n0
            lda   ProdHi
            adc   #0
            sta   n0+2
            lda   TrueP
            clc
            adc   n0
            sta   p0
            lda   TrueP+2
            adc   n0+2
            sta   p0+2
            lda   CLines
            sta   t3
:row        ldy   #0
            sep   #$20
            mx    %10
:b          cpy   CStride
            bcs   :next
            lda   [p0],y
            sta   [p1],y
            iny
            bra   :b
:next       rep   #$20
            mx    %00
            lda   p0
            clc
            adc   TrueStride
            sta   p0
            lda   p0+2
            adc   #0
            sta   p0+2
            lda   p1
            clc
            adc   CStride
            sta   p1
            lda   p1+2
            adc   #0
            sta   p1+2
            dec   t3
            bne   :row
            lda   CBytes
            sta   TrueW
            lda   CLines
            sta   TrueH
            lda   CStride
            sta   TrueStride
            ldx   CLines                ; its size, and the block shrunk to it
            jsr   Mul16
            lda   ProdLo
            sta   TrueSize
            lda   ProdHi
            sta   TrueSize+2
            PushLongAt TrueSize
            PushLongAt TrueHnd
            Tool  _SetHandleSize
            lda   TrueHnd               ; (where it is now)
            sta   p0
            lda   TrueHnd+2
            sta   p0+2
            ldy   #2
            lda   [p0],y
            sta   TrueP+2
            lda   [p0]
            sta   TrueP
            inc   TrueGen
            lda   #2
            jsl   DeskSelClear
            jsr   TellDesk
            jsl   DeskTop               ; (the picture's top left in view)
            rts

* CropMono: the monochrome image: the same with its bits.
CropMono    lda   dselr+2
            ldx   dselu
            cpx   #2
            bne   :l
            lsr
:l          sta   CLeft                 ; (pixels)
            lda   dselr+6
            cpx   #2
            bne   :r
            lsr
:r          sec
            sbc   CLeft
            sta   CBytes                ; (pixels across)
            clc
            adc   #7
            lsr
            lsr
            lsr
            sta   CStride               ; bytes a new row
            lda   dselr+4
            sec
            sbc   dselr
            sta   CLines
            lda   MonoP
            sta   p1
            lda   MonoP+2
            sta   p1+2
            lda   dselr
            ldx   MonoStr
            jsr   Mul16
            lda   MonoP
            clc
            adc   ProdLo
            sta   p0
            lda   MonoP+2
            adc   ProdHi
            sta   p0+2
            lda   CLeft                 ; the bit shift
            and   #7
            sta   t2
            lda   CLeft
            lsr
            lsr
            lsr
            sta   t1                    ; the first byte
            lda   CLines
            sta   t3
:row        ldy   t1                    ; each new byte: 8 bits from the
            ldx   #0                    ; old ones at bit (left & 7)
:byte       cpx   CStride
            bcs   :next
            lda   [p0],y                ; (two old bytes, high first)
            xba
            and   #$FFFF
            ldy   t2
            beq   :put
:sh         asl
            dey
            bne   :sh
:put        xba
            phx
            ply                         ; (the new byte's index)
            sep   #$20
            mx    %10
            sta   [p1],y
            rep   #$20
            mx    %00
            txa
            inc
            tax
            clc
            adc   t1
            tay
            bra   :byte
:next       lda   CBytes                ; the bits past the width cleared
            and   #7
            beq   :whole
            tax
            lda   EndMask-1,x
            and   #$00FF
            sta   t0
            ldy   CStride
            dey
            sep   #$20
            mx    %10
            lda   [p1],y
            and   t0
            sta   [p1],y
            rep   #$20
            mx    %00
:whole      lda   p0
            clc
            adc   MonoStr
            sta   p0
            lda   p0+2
            adc   #0
            sta   p0+2
            lda   p1
            clc
            adc   CStride
            sta   p1
            lda   p1+2
            adc   #0
            sta   p1+2
            dec   t3
            bne   :row
            lda   CBytes
            sta   MonoW
            lda   CLines
            sta   MonoH
            lda   CStride
            sta   MonoStr
            lda   #3
            jsl   DeskSelClear
            jsr   TellDesk
            jsl   DeskTop
            rts

CLeft       dw    0
CBytes      dw    0
CStride     dw    0
CLines      dw    0
CByte       dw    0
EndMask     db    $80,$C0,$E0,$F0,$F8,$FC,$FE
