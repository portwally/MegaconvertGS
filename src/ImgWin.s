*-------------------------------------------------------------
* ImgWin.s - the screen image window, as SuperConvert's (part of the
* Desk segment; docs/superconvert-image-window.md)
*
* The window shows one of the images: the screen image (its bytes as
* they are, as 640 mode pixels in the desktop's colours) or the true
* colour image (through SuperConvert's dither table, its pixels 320 or
* 640 sized). Sizes are in image units: 640 mode columns at actual size,
* and lines. The info bar has the image type, zoom, tool and actions
* pop-ups, and the image's size.
*-------------------------------------------------------------

ip0         =     $CC                   ; long pointers for drawing
ip1         =     $D0
iw0         =     $D4                   ; words
iw1         =     $D6
iw2         =     $D8
iw3         =     $DA
iw4         =     $DC
iw5         =     $DE

* DeskImages: the images changed (from the direct page: scrp, pw, ph, p640
* the screen image; tp, tstride, rw, rh, rtall the true colour one;
* dhave: 1 screen, 2 true colour; dname). The window, if shown, follows.
* DeskNoImages: every image discarded (Edit > Close, the close box): the
* image window goes.
DeskNoImages ent
            phb
            phk
            plb
            jsr   ExitPals
            jsr   SelClear
            jsr   TakeImages
            lda   ScrWin
            ora   ScrWin+2
            beq   :done
            PushLongAt ScrWin
            Tool  _HideWindow
:done       plb
            rtl

* DeskPixSize: image type A's pixels X sized (0 320, 1 640).
DeskPixSize ent
            phb
            phk
            plb
            asl
            tay
            txa
            sta   PixSize,y
            plb
            rtl

DeskImages  ent
            phb
            phk
            plb
            jsr   TakeImages
            lda   ScrWin
            ora   ScrWin+2
            beq   :done
            jsr   ImgChanged
:done       plb
            rtl

* DeskPicture: as DeskImages, then the window shows image type dshow
* (1 screen, 2 true colour; 0: as it was), at actual size, from its top
* left, in front.
DeskPicture ent
            phb
            phk
            plb
            jsr   TakeImages
            lda   ScrWin
            ora   ScrWin+2
            bne   :have
            PushLong ScrParms
            jsr   OpenWin
            sta   ScrWin
            stx   ScrWin+2
            pea   $FFF8                 ; (the origin moves 8 columns at a time)
            PushLongAt ScrWin
            Tool  _SetOriginMask
:have       lda   dshow
            beq   :keep
            sta   Shown
            cmp   #2                    ; a new true colour image: its pixels'
            bne   :keep                 ; size from its shape
            lda   rtall
            sta   PixSize+4
:keep       stz   Zoom
            jsr   ImgChanged
            pea   0
            pea   0
            PushLongAt ScrWin
            Tool  _SetContentOrigin
            PushLongAt ScrWin
            Tool  _ShowWindow
            PushLongAt ScrWin
            Tool  _SelectWindow
            plb
            rtl

* TakeImages: the images' details from the direct page.
TakeImages  lda   dhave
            sta   Have
            stz   GreyKnown
            lda   scrp
            sta   ScrLoc+2
            lda   scrp+2
            sta   ScrLoc+4
            lda   pw                    ; the screen image: bytes a line x 4
            ldx   p640
            bne   :w640
            asl
:w640       sta   ScrUnits
            lda   ph
            sta   ScrLines
            lda   pw
            sta   ScrPixW
            lda   tp
            sta   TrueP
            lda   tp+2
            sta   TrueP+2
            lda   tstride
            sta   TrueStr
            lda   rw
            sta   TrueW
            lda   rh
            sta   TrueH
            lda   dname
            sta   NameP
            lda   dname+2
            sta   NameP+2
            ldy   #6                    ; the monochrome image (MonoBlk)
            lda   [mblk],y
            sta   MonoP
            ldy   #8
            lda   [mblk],y
            sta   MonoP+2
            ldy   #10
            lda   [mblk],y
            sta   MonoW
            ldy   #12
            lda   [mblk],y
            sta   MonoH
            ldy   #14
            lda   [mblk],y
            sta   MonoStr
            rts

* ImgChanged: after any change of image, type, zoom or pixel size: the
* size, the title, the info bar, everything drawn again.
ImgChanged  lda   Shown                 ; a type that exists (else the first)
            asl
            tax
            lda   Have
            and   TypeBit,x
            bne   :ok
            ldx   #1
            lda   Have
            and   #1
            bne   :set
            ldx   #2
            lda   Have
            and   #2
            bne   :set
            ldx   #3
:set        stx   Shown
:ok         jsr   Units                 ; W, H in image units
            lda   UnitsW
            jsr   A2ZR
            sta   ZoomW
            lda   UnitsH
            jsr   A2ZR
            sta   ZoomH
            lda   ZoomH
            pha
            lda   ZoomW
            clc
            adc   #7
            pha
            PushLongAt ScrWin
            Tool  _SetDataSize
            jsr   SelInit               ; the selection, snapping, no peek
            jsr   MakeTitle
            PushLong ScrTitle
            PushLongAt ScrWin
            Tool  _SetWTitle
            PushLongAt ScrWin           ; all drawn again
            Tool  _SetPort
            PushLong BigRect
            Tool  _InvalRect
            PushLongAt ScrWin           ; (the info bar too)
            Tool  _DrawInfoBar
            rts

* Units: UnitsW, UnitsH: the shown image's size in image units.
Units       lda   Shown
            cmp   #2
            bcs   :other
            lda   ScrUnits
            sta   UnitsW
            lda   ScrLines
            sta   UnitsH
            rts
:other      jsr   Shape                 ; true colour, monochrome: by their pixels
            lda   ImgW
            ldx   ImgPix
            bne   :w
            asl
:w          sta   UnitsW
            lda   ImgH
            sta   UnitsH
            rts

* Shape: ImgW, ImgH, ImgPix: the shown true colour or monochrome image's
* size and pixel size (0 320, 1 640 sized).
Shape       lda   Shown
            asl
            tax
            lda   PixSize,x
            sta   ImgPix
            lda   Shown
            cmp   #3
            beq   :mono
            lda   TrueW
            sta   ImgW
            lda   TrueH
            sta   ImgH
            rts
:mono       lda   MonoW
            sta   ImgW
            lda   MonoH
            sta   ImgH
            rts

* The zoom (Zoom: -3 1/8 ... 0 actual size ... 3 8X): image units to
* window units (A2Z rounds down, A2ZR up) and back (Z2A down, Z2AR up).
A2Z         ldx   Zoom
            beq   :done
            bmi   :shrink
:grow       asl
            dex
            bne   :grow
:done       rts
:shrink     cmp   #$8000
            ror
            inx
            bne   :shrink
            rts
A2ZR        ldx   Zoom
            bpl   A2Z
:shrink     pha                         ; a = (a >> 1) + (a & 1)
            and   #1
            sta   iw5
            pla
            cmp   #$8000
            ror
            clc
            adc   iw5
            inx
            bne   :shrink
            rts
Z2A         ldx   Zoom
            beq   :done
            bmi   :grow
:shrink     cmp   #$8000
            ror
            dex
            bne   :shrink
:done       rts
:grow       asl
            inx
            bne   :grow
            rts
Z2AR        ldx   Zoom
            bmi   Z2A
            beq   Z2A
:shrink     pha
            and   #1
            sta   iw5
            pla
            cmp   #$8000
            ror
            clc
            adc   iw5
            dex
            bne   :shrink
            rts

*-------------------------------------------------------------
* The title and the info bar's text
*-------------------------------------------------------------

* MakeTitle: ScrTitle = " NAME (320, n) ": the screen image's modes (320,
* 640 or Mix) and its highest colour table + 1; " NAME (???) " without
* a screen image.
MakeTitle   lda   #ScrTitle+1
            sta   mp1
            stz   TLen
            lda   #TxSpace
            jsr   TAdd
            lda   NameP
            ldx   NameP+2
            jsr   TAddLong
            lda   Have
            and   #1
            bne   :screen
            lda   #TxNone
            jsr   TAdd
            bra   :end
:screen     stz   HiPal                 ; the lines' modes and highest table
            stz   Modes                 ; (bit 0: a 320 line, bit 1: a 640 line)
            lda   ScrLoc+2
            sta   ip0
            lda   ScrLoc+4
            sta   ip0+2
            ldy   #scbOffset
            ldx   ScrLines
:scb        lda   [ip0],y
            and   #$000F
            cmp   HiPal
            bcc   :lower
            sta   HiPal
:lower      lda   [ip0],y
            and   #$0080
            beq   :m320
            lda   #2
            bra   :mode
:m320       lda   #1
:mode       tsb   Modes
            iny
            dex
            bne   :scb
            lda   #TxOpenP
            jsr   TAdd
            lda   Modes
            asl
            tax
            lda   ModeTx,x
            jsr   TAdd
            lda   #TxComma1
            jsr   TAdd
            lda   HiPal                 ; two characters
            inc
            cmp   #10
            bcs   :two
            pha
            lda   #TxSpace
            jsr   TAdd
            pla
:two        jsr   TDec
            lda   #TxCloseP
            jsr   TAdd
:end        sep   #$20
            mx    %10
            lda   TLen
            sta   ScrTitle
            rep   #$20
            mx    %00
            rts

* InfoText: the info bar's text for level A (0 the longest, 2, 3 the
* shortest) into InfoTx (a C string).
InfoText    sta   iw4
            lda   #InfoTx
            sta   mp1
            stz   TLen
            lda   ToolNo
            cmp   #2
            bne   :notPeek
            jmp   PeekText
:notPeek    lda   HasSel
            beq   :image
            jmp   SelText
:image      lda   #4
            sta   LastLevel
            lda   iw4
            cmp   #2
            bcs   :short
            lda   Shown
            asl
            tax
            lda   TypeTx,x              ; "Screen image: ", "True color image: "
            jsr   TAdd
            bra   :size
:short      cmp   #3
            bcs   :size
            lda   #TxImage
            jsr   TAdd
:size       lda   Shown                 ; the size in the image's own pixels
            cmp   #2
            bcs   :true
            lda   ScrPixW
            ldx   ScrLines
            bra   :put
:true       jsr   Shape
            lda   ImgW
            ldx   ImgH
:put        phx
            jsr   TDec
            lda   #TxTimes
            jsr   TAdd
            pla
            jsr   TDec
            ldy   TLen
            lda   #0
            sep   #$20
            mx    %10
            sta   (mp1),y
            rep   #$20
            mx    %00
            rts

*-------------------------------------------------------------
* Drawing (called by the toolbox: own data bank and direct page)
*-------------------------------------------------------------

* DrawScr: the window's contents: the background right of and below the
* picture, then the part of the picture the update needs.
DrawScr     phb
            phk
            plb
            phd
            lda   AppDP
            tcd
            lda   ZoomW                 ; the background
            sta   ScrBack+2
            stz   ScrBack
            lda   #10000
            sta   ScrBack+4
            sta   ScrBack+6
            PushLong ScrBack
            PushLong BackPat
            Tool  _FillRect
            lda   ZoomH
            sta   ScrBack
            stz   ScrBack+2
            PushLong ScrBack
            PushLong BackPat
            Tool  _FillRect
            pha                         ; the part to draw: the visible
            pha                         ; region's box, in image units
            Tool  _GetPort
            pla
            sta   ip0
            pla
            sta   ip0+2
            ldy   #28                   ; (visRgn)
            lda   [ip0],y
            tax
            iny
            iny
            lda   [ip0],y
            sta   ip0+2
            stx   ip0
            lda   [ip0]
            tax
            ldy   #2
            lda   [ip0],y
            sta   ip0+2
            stx   ip0
            ldy   #2                    ; rgnBBox
            lda   [ip0],y
            jsr   Z2A
            sta   Part
            ldy   #4
            lda   [ip0],y
            jsr   Z2A
            and   #$FFF0
            sta   Part+2
            ldy   #6
            lda   [ip0],y
            jsr   Z2AR
            sta   Part+4
            ldy   #8
            lda   [ip0],y
            jsr   Z2AR
            clc
            adc   #15
            and   #$FFF0
            sta   Part+6
            lda   Shown
            cmp   #2
            bcs   :true
            jsr   DrawScreen
            bra   :done
:true       jsr   DrawTrue              ; (or the monochrome image)
:done       lda   HasSel                ; the selection's frame
            beq   :out
            jsr   DrawAnts
:out        pld
            plb
            rtl

* DrawScreen: the screen image's bytes, as they are, in Part.
DrawScreen  lda   Part
            cmp   ScrLines
            bcs   :none
            lda   Part+4
            cmp   ScrLines
            bcc   :b
            lda   ScrLines
            sta   Part+4
:b          lda   Part+2
            cmp   ScrUnits
            bcs   :none
            lda   Part+6
            cmp   ScrUnits
            bcc   :r
            lda   ScrUnits
            sta   Part+6
:r          ldx   #Part
            jsr   Zoomed
            pha
            pha
            Tool  _GetPort
            PushLong ScrLoc             ; (the port's own LocInfo is first)
            lda   7,s                   ; the port, as the destination
            pha
            lda   7,s
            pha
            PushLong Part
            PushLong ZRect
            pea   0
            PushLong 0
            Tool  _CopyPixels
            pla
            pla
:none       rts

* Zoomed: ZRect = the rect at X (image units) in window units.
Zoomed      stx   iw4
            lda   |0,x
            jsr   A2Z
            sta   ZRect
            ldx   iw4
            lda   |2,x
            jsr   A2Z
            sta   ZRect+2
            ldx   iw4
            lda   |4,x
            jsr   A2ZR
            sta   ZRect+4
            ldx   iw4
            lda   |6,x
            jsr   A2ZR
            sta   ZRect+6
            rts

* DrawTrue: the true colour image in Part, through the dither table, in
* strips of at most 32 rows of 640 mode bytes.
DrawTrue    lda   StripP+2              ; (no buffer: nothing drawn)
            bne   :buf
            rts
:buf        jsr   Shape
            lda   Part+4
            cmp   ImgH
            bcc   :b
            lda   ImgH
            sta   Part+4
:b          lda   Part
            cmp   Part+4
            bcc   :rows
            rts
:rows       lda   ImgW                  ; the image's width in image units
            ldx   ImgPix
            bne   :wu
            asl
:wu         sta   iw0
            lda   Part+2
            cmp   iw0
            bcc   :in
            rts
:in         lda   Part+6
            cmp   iw0
            bcc   :r
            lda   iw0
            sta   Part+6
:r          lda   Part+6                ; bytes a strip row: a multiple of 8
            sec
            sbc   Part+2
            clc
            adc   #31
            and   #$FFE0
            lsr
            lsr
            sta   StripLoc+6
            lda   #16384                ; rows a strip: at most 32
            ldx   StripLoc+6
            jsr   Div16
            cmp   #32
            bcc   :per
            lda   #32
:per        sta   iw1
            lda   Part
            sta   iw2                   ; the strip's first row
:strip      lda   Part+4
            sec
            sbc   iw2
            cmp   iw1
            bcc   :n
            lda   iw1
:n          sta   iw3                   ; its rows
            lda   Shown
            cmp   #3
            beq   :mono
            jsr   MakeStrip
            bra   :made
:mono       jsr   MonoStrip
:made
            lda   iw2                   ; (line, left, line + n, right)
            sta   SRect
            sta   StripLoc+8
            clc
            adc   iw3
            sta   SRect+4
            sta   StripLoc+12
            lda   Part+2
            sta   SRect+2
            sta   StripLoc+10
            lda   StripLoc+6
            asl
            asl
            clc
            adc   Part+2
            sta   StripLoc+14
            lda   Part+6
            sta   SRect+6
            ldx   #SRect
            jsr   Zoomed
            pha
            pha
            Tool  _GetPort
            PushLong StripLoc
            lda   7,s
            pha
            lda   7,s
            pha
            PushLong SRect
            PushLong ZRect
            pea   0
            PushLong 0
            Tool  _CopyPixels
            pla
            pla
            lda   iw2
            clc
            adc   iw3
            sta   iw2
            cmp   Part+4
            bcs   :jx1
            jmp   :strip
:jx1
            rts

* MakeStrip: iw3 rows of the true colour image from row iw2, columns
* Part+2 to Part+6 (image units), as 640 mode bytes in the strip.
MakeStrip   lda   StripP
            sta   ip1
            lda   StripP+2
            sta   ip1+2
            lda   iw2
            sta   iw4                   ; this row
            lda   iw3
            sta   iw5                   ; rows left
:row        lda   iw4                   ; ip0: the row's first pixel
            ldx   TrueStr
            jsr   Mul16                 ; (MLo, MHi)
            lda   Part+2                ; the first pixel
            ldx   ImgPix
            bne   :p640
            lsr
:p640       sta   PixX
            asl
            clc
            adc   PixX                  ; x 3
            clc
            adc   MLo
            sta   ip0
            lda   MHi
            adc   #0
            sta   ip0+2
            lda   TrueP
            clc
            adc   ip0
            sta   ip0
            lda   TrueP+2
            adc   ip0+2
            sta   ip0+2
            lda   iw4                   ; the dither table's half for the row
            and   #1
            xba
            asl
            asl
            asl
            asl
            sta   Parity                ; ($1000 on odd rows)
            ldy   #0                    ; the strip byte
            lda   Part+6
            sec
            sbc   Part+2
            clc
            adc   #3
            lsr
            lsr
            sta   NBytes                ; bytes to make
:byte       lda   ImgPix
            bne   :four
            jsr   Pixel                 ; 320 sized: two pixels, a nibble each
            and   #$00F0
            sta   PixB
            jsr   Pixel
            and   #$000F
            ora   PixB
            bra   :put
:four       jsr   Pixel                 ; 640 sized: four, two bits each
            and   #$00C0
            sta   PixB
            jsr   Pixel
            and   #$0030
            tsb   PixB
            jsr   Pixel
            and   #$000C
            tsb   PixB
            jsr   Pixel
            and   #$0003
            ora   PixB
:put        sep   #$20
            mx    %10
            sta   [ip1],y
            rep   #$20
            mx    %00
            iny
            dec   NBytes
            bne   :byte
            lda   ip1                   ; the next strip row
            clc
            adc   StripLoc+6
            sta   ip1
            inc   iw4
            dec   iw5
            beq   :jx2
            jmp   :row
:jx2
            rts

* MonoStrip: iw3 rows of the monochrome image from row iw2, columns
* Part+2 to Part+6 (image units): each bit white (3) or black (0), one
* column (640 sized) or two (320 sized).
MonoStrip   jsr   MakeExp
            lda   StripP
            sta   ip1
            lda   StripP+2
            sta   ip1+2
            lda   iw2
            sta   iw4
            lda   iw3
            sta   iw5
:row        lda   iw4                   ; ip0: the row's first byte used
            ldx   MonoStr
            jsr   Mul16
            lda   Part+2                ; (8 or 16 image units a byte)
            lsr
            lsr
            lsr
            ldx   ImgPix
            bne   :b
            lsr
:b          clc
            adc   MLo
            sta   ip0
            lda   MHi
            adc   #0
            sta   ip0+2
            lda   MonoP
            clc
            adc   ip0
            sta   ip0
            lda   MonoP+2
            adc   ip0+2
            sta   ip0+2
            ldy   #0                    ; the strip byte
            stz   PixX                  ; the source byte
:byte       phy
            ldy   PixX
            lda   [ip0],y
            and   #$00FF
            ply
            asl
            ldx   ImgPix
            bne   :two
            asl                         ; 320 sized: four bytes
            tax
            lda   Exp320,x
            sta   [ip1],y
            iny
            iny
            lda   Exp320+2,x
            sta   [ip1],y
            iny
            iny
            bra   :next
:two        tax                         ; 640 sized: two bytes
            lda   Exp640,x
            sta   [ip1],y
            iny
            iny
:next       inc   PixX
            cpy   StripLoc+6
            bcc   :byte
            lda   ip1                   ; the next strip row
            clc
            adc   StripLoc+6
            sta   ip1
            inc   iw4
            dec   iw5
            bne   :row
            rts

* MakeExp: the bit expansion tables, once: each byte's 8 pixels white (a
* set bit) or black, as 2 bytes (640 sized) or 4 (320 sized).
MakeExp     lda   ExpMade
            beq   :make
            rts
:make       inc   ExpMade
            ldx   #0                    ; the byte value x 2
:v          stz   iw0                   ; 640 sized
            stz   iw1                   ; 320 sized (iw1, then PixT)
            stz   PixT
            txa
            lsr
            sta   PixB
            ldy   #0                    ; the bit (x 2), leftmost first
:bit        lda   PixB
            and   #$0080
            beq   :black
            lda   ExpBit640,y
            tsb   iw0
            phy
            tya
            asl
            tay
            lda   ExpBit320,y
            tsb   iw1
            lda   ExpBit320+2,y
            tsb   PixT
            ply
:black      asl   PixB
            iny
            iny
            cpy   #16
            bcc   :bit
            lda   iw0
            sta   Exp640,x
            phx
            txa
            asl
            tax
            lda   iw1
            sta   Exp320,x
            lda   PixT
            sta   Exp320+2,x
            plx
            inx
            inx
            cpx   #512
            bcc   :v
            rts
* For bit i (0: leftmost): its white pixels in the strip bytes, as words
* (the first byte low); 320 sized: two words a bit.
ExpBit640   dw    $00C0,$0030,$000C,$0003,$C000,$3000,$0C00,$0300
ExpBit320   dw    $00F0,0,$000F,0,$F000,0,$0F00,0,0,$00F0,0,$000F,0,$F000,0,$0F00

* Pixel: A = the dither table's byte for the pixel at ip0 (black past the
* row's end); ip0 to the next pixel.
Pixel       lda   PixX
            cmp   TrueW
            bcs   :past
            phy
            lda   [ip0]                 ; R: bits 11-8
            and   #$00F0
            asl
            asl
            asl
            asl
            ora   Parity
            sta   PixI
            ldy   #1                    ; G: bits 7-4
            lda   [ip0],y
            and   #$00F0
            tsb   PixI
            iny                         ; B: bits 3-0
            lda   [ip0],y
            and   #$00F0
            lsr
            lsr
            lsr
            lsr
            ora   PixI
            tax
            lda   DitherTab,x
            ply
            inc   PixX
            pha
            lda   ip0
            clc
            adc   #3
            sta   ip0
            bcc   :same
            inc   ip0+2
:same       pla
            rts
:past       inc   PixX
            lda   #0
            rts

* DrawScrInfo: the info bar (the Window Manager calls it with the bar's
* rect, its refCon and the window): the pop-ups' icons and the text.
DrawScrInfo phb
            phk
            plb
            phd
            lda   AppDP
            tcd
            lda   15,s                  ; the bar's rect
            sta   mp1
            lda   17,s
            sta   mp1+2
            ldy   #6
:r          lda   [mp1],y
            sta   IRect,y
            sta   IGlobal,y
            dey
            dey
            bpl   :r
            PushLong IGlobal            ; (where it is, for clicks)
            Tool  _LocalToGlobal
            PushLong IRect
            Tool  _EraseRect
            pea   0
            Tool  _SetForeColor
            pea   15
            Tool  _SetBackColor
            lda   Shown                 ; the image type
            asl
            tax
            lda   TypeIcon,x
            ldx   #2
            ldy   #0
            jsr   InfoIcon
            lda   #IcArrow
            ldx   #20
            ldy   #0
            jsr   InfoIcon
            lda   #IcZoom0              ; the zoom
            ldx   Zoom
            beq   :z
            lda   #IcZoomS
            cpx   #$8000
            bcs   :z
            lda   #IcZoomL
:z          ldx   #42
            ldy   #1
            jsr   InfoIcon
            lda   #IcArrow
            ldx   #60
            ldy   #0
            jsr   InfoIcon
            lda   #IcSelect             ; the tool
            ldx   ToolNo
            cpx   #2
            bne   :t
            lda   #IcPeek
:t          ldx   #82
            ldy   #1
            jsr   InfoIcon
            lda   #IcArrow
            ldx   #100
            ldy   #0
            jsr   InfoIcon
            lda   #IcActArr             ; the actions
            ldx   #122
            ldy   #0
            jsr   InfoIcon
            jsr   FitText               ; the longest text that fits
            lda   IRect+2
            clc
            adc   #142
            pha
            lda   IRect
            clc
            adc   #8
            pha
            Tool  _MoveTo
            PushLong InfoTx
            Tool  _DrawCString
            pld
            plb
            lda   2,s                   ; drop the parameters (12 bytes)
            sta   14,s
            lda   1,s
            sta   13,s
            tsc
            clc
            adc   #12
            tcs
            rtl

* InfoIcon: the icon at A (this bank) at the bar's left + X, top + Y.
InfoIcon    sty   iw1
            pea   ^IcArrow
            pha
            pea   0
            txa
            clc
            adc   IRect+2
            pha
            lda   IRect
            clc
            adc   iw1
            pha
            Tool  _DrawIcon
            rts

*-------------------------------------------------------------
* The info bar's pop-ups
*-------------------------------------------------------------

* DeskInfoClick: a click in the window's info bar (dctl: where, global
* v and h). Image type and zoom pop-ups.
DeskInfoClick ent
            phb
            phk
            plb
            stz   dact
            jsr   ExitPals
            jsr   PopMenus
            lda   dctl+2                ; which: by the distance from its left
            sec
            sbc   IGlobal+2
            cmp   #40
            bcc   :type
            cmp   #80
            bcc   :zoom
            cmp   #120
            bcc   :tool
            cmp   #140
            bcs   :done
            jsr   ActPop                ; (dact: what the main program does)
            bra   :done
:tool       jsr   ToolPop
            bra   :done
:zoom       jsr   ZoomPop
            bra   :done
:type       jsr   TypePop
:done       plb
            rtl

* PopMenus: the pop-up menus, made once (in a menu bar of their own,
* never shown, where their states are set).
PopMenus    lda   PopBar
            ora   PopBar+2
            beq   :make
            rts
:make       pha                         ; the menu bar in use
            pha
            Tool  _GetMenuBar
            pla
            sta   SysBar
            pla
            sta   SysBar+2
            pha
            pha
            PushLong 0
            Tool  _NewMenuBar
            pla
            sta   PopBar
            pla
            sta   PopBar+2
            PushLongAt PopBar
            Tool  _SetMenuBar
            ldx   #0
:menu       phx
            pha
            pha
            pea   ^PopText1
            lda   PopTexts,x
            pha
            Tool  _NewMenu
            pla
            sta   iw0
            pla
            sta   iw1
            plx
            lda   iw0
            sta   PopH,x
            lda   iw1
            sta   PopH+2,x
            phx
            PushLongAt iw0
            pea   0
            Tool  _InsertMenu
            plx
            inx
            inx
            inx
            inx
            cpx   #20
            bcc   :menu
            ldx   #0                    ; the image type items' icons
:icon       phx
            pea   0
            pea   ^PopS1
            lda   PopStructs,x
            pha
            lda   PopItems,x
            pha
            Tool  _SetMItemStruct
            plx
            inx
            inx
            cpx   #14
            bcc   :icon
            PushLongAt SysBar
            Tool  _SetMenuBar
            rts

* TypePop: the image type pop-up.
TypePop     PushLongAt PopBar           ; the items' states
            Tool  _SetMenuBar
            ldx   #1
:type       phx
            txa
            clc
            adc   #256
            pha
            txa
            asl
            tax
            lda   Have
            and   TypeBit,x
            beq   :off
            Tool  _EnableMItem
            bra   :next
:off        Tool  _DisableMItem
:next       plx
            inx
            cpx   #4
            bcc   :type
            ldx   #260                  ; pixel sizes: true colour, monochrome
:size       phx
            phx
            lda   Shown
            cmp   #2
            bcc   :soff
            Tool  _EnableMItem
            bra   :snext
:soff       Tool  _DisableMItem
:snext      plx
            inx
            cpx   #262
            bcc   :size
            lda   Shown                 ; the size in use checked
            asl
            tax
            lda   PixSize,x
            eor   #1
            pha
            pea   260
            Tool  _CheckMItem
            lda   Shown
            asl
            tax
            lda   PixSize,x
            pha
            pea   261
            Tool  _CheckMItem
            pea   262                   ; Use image's palette: the screen image
            lda   Shown
            cmp   #1
            bne   :poff
            Tool  _EnableMItem
            bra   :pchk
:poff       Tool  _DisableMItem
:pchk       lda   UsePal
            pha
            pea   262
            Tool  _CheckMItem
            PushLongAt SysBar
            Tool  _SetMenuBar
            lda   Shown
            clc
            adc   #256
            ldx   #0
            jsr   PopUp
            beq   :none
            and   #$00FF
            cmp   #4
            bcs   :pix
            cmp   Shown
            beq   :none
            sta   Shown
            jmp   ImgChanged
:pix        cmp   #6
            bcs   :jx3
            jmp   :psize
:jx3
            bne   :none
            lda   UsePal                ; Use image's palette: on or off
            eor   #1
            sta   UsePal
            rts
:psize      sec
            sbc   #4                    ; 0: 320 sized, 1: 640 sized
            pha
            lda   Shown
            asl
            tax
            pla
            cmp   PixSize,x
            beq   :none
            sta   PixSize,x
            pha                         ; the selection's left and right
            jsr   SelIndex              ; follow
            pla
            bne   :half
            lda   SelImg+2,y
            asl
            sta   SelImg+2,y
            lda   SelImg+6,y
            asl
            sta   SelImg+6,y
            jmp   ImgChanged
:half       lda   SelImg+2,y
            lsr
            sta   SelImg+2,y
            lda   SelImg+6,y
            lsr
            sta   SelImg+6,y
            jmp   ImgChanged
:none       rts

* ZoomPop: the zoom pop-up (2X, 4X, 8X only while the image stays below
* 10000 units).
ZoomPop     PushLongAt PopBar
            Tool  _SetMenuBar
            jsr   Units
            lda   UnitsW
            cmp   UnitsH
            bcs   :m
            lda   UnitsH
:m          sta   iw2
            ldx   #0
:z          phx
            lda   ZoomItems,x
            pha
            lda   iw2
            cmp   ZoomMax,x
            bcs   :off
            Tool  _EnableMItem
            bra   :next
:off        Tool  _DisableMItem
:next       plx
            inx
            inx
            cpx   #6
            bcc   :z
            PushLongAt SysBar
            Tool  _SetMenuBar
            lda   Zoom
            and   #$00FF
            ora   #$0300
            ldx   #4
            jsr   PopUp
            beq   :none
            and   #$00FF
            cmp   #$80                  ; (a signed byte)
            bcc   :pos
            ora   #$FF00
:pos        cmp   Zoom
            beq   :none
            sta   Zoom
            jmp   ImgChanged
:none       rts

* PopUp: pop-up menu X (PopH + X: 0 image type, 4 zoom) at the info
* bar's left + 10 X, with item A shown.
*   out: A = the item chosen (0: none), Z set if 0
PopUp       stx   iw0
            pha                         ; result
            pha                         ; the item shown
            txa
            asl
            asl
            clc
            adc   iw0
            asl
            clc
            adc   IGlobal+2             ; left
            pha
            lda   IGlobal
            dec
            pha                         ; top
            pea   $0040
            ldx   iw0
            lda   PopH+2,x
            pha
            lda   PopH,x
            pha
            Tool  _PopUpMenuSelect
            pla
            rts

*-------------------------------------------------------------
* Data
*-------------------------------------------------------------
Have        dw    0                     ; bit 0: a screen image, bit 1: true colour
Shown       dw    1                     ; 1 screen, 2 true colour
PixSize     dw    0,0,0,1               ; each type's pixels: 0 320, 1 640 sized
ImgW        dw    0
ImgH        dw    0
ImgPix      dw    0
MonoP       adrl  0                     ; the monochrome image
MonoW       dw    0
MonoH       dw    0
MonoStr     dw    0
ExpMade     dw    0
Exp640      ds    512                   ; a byte's 8 pixels as 2 bytes (640 sized)
Exp320      ds    1024                  ; ... as 4 bytes (320 sized)
Zoom        dw    0
ToolNo      dw    1                     ; 1 selection, 2 pixel peek
TypeBit     dw    0,1,2,4
ScrUnits    dw    0                     ; the screen image: width in image units,
ScrLines    dw    0                     ; lines, width in pixels
ScrPixW     dw    0
TrueP       adrl  0                     ; the true colour image
TrueStr     dw    0
TrueW       dw    0
TrueH       dw    0
NameP       adrl  0
UnitsW      dw    0
UnitsH      dw    0
ZoomW       dw    0
ZoomH       dw    0
HiPal       dw    0
Modes       dw    0
Part        dw    0,0,0,0               ; the part to draw (image units)
ZRect       dw    0,0,0,0               ; ... in the window
SRect       dw    0,0,0,0
ScrBack     dw    0,0,0,0
IRect       dw    0,0,0,0               ; the info bar (local, global)
IGlobal     dw    0,0,0,0
PixX        dw    0
PixB        dw    0
PixT        dw    0
PixI        dw    0
Parity      dw    0
NBytes      dw    0
StripP      adrl  0                     ; the strip buffer (16K, made by DeskStart)
StripH      adrl  0
StripLoc    dw    $0080                 ; 640 mode
            adrl  0
            dw    0                     ; bytes a row
            dw    0,0,0,0
ScrLoc      dw    $0080                 ; the screen image: 640 mode, 160 bytes a line
            adrl  0
            dw    160
            dw    0,0,400,640
BigRect     dw    0,0,10000,10000
BackPat     hex   0F0F3C3CF0F0C3C30F0F3C3CF0F0C3C3
            hex   00000000000000000000000000000000
InfoTx      ds    64
TypeIcon    da    0,ListIcon1,ListIcon2,ListIcon4
TypeTx      da    0,TxScrImg,TxTrueImg,TxMonoImg
ModeTx      da    0,Tx320,Tx640,TxMix
TxScrImg    asc   'Screen image: ',00
TxTrueImg   asc   'True color image: ',00
TxMonoImg   asc   'Monochrome image: ',00
TxNone      asc   ' (???) ',00
TxMix       asc   'Mix',00
PopBar      adrl  0
SysBar      adrl  0
PopH        adrl  0,0,0,0,0             ; image type, zoom, tool, actions (2)
PopTexts    da    PopText1,PopText3,PopText2,PopText4,PopText5
PopItems    dw    257,258,259,260,261,513,514
PopStructs  da    PopS1,PopS2,PopS3,PopS4,PopS5,PopS6,PopS7
PopS1       dw    $8000
            adrl  0
            adrl  ListIcon1
PopS2       dw    $8000
            adrl  0
            adrl  ListIcon2
PopS3       dw    $8000
            adrl  0
            adrl  ListIcon4
PopS4       dw    $8000
            adrl  0
            adrl  Ic320
PopS5       dw    $8000
            adrl  0
            adrl  Ic640
PopS6       dw    $8000
            adrl  0
            adrl  IcSelect
PopS7       dw    $8000
            adrl  0
            adrl  IcPeek
TxComma1    asc   ',',00
ZoomItems   dw    769,770,771
ZoomMax     dw    5000,2500,1250
* SuperConvert's pop-up menus (image type and zoom).
PopText1    asc   '##Blah\N1',00
            asc   '>>Screen image\N257',00
            asc   '>>True color image\N258',00
            asc   '>>Monochrome image\N259V',00
            asc   '>>Use image',27,'s palette\N262D',00
            asc   '>>320-sized pixels\N260D',00
            asc   '>>640-sized pixels\N261D',00
            asc   '.',00
PopText3    asc   '##Blah\N3',00
            asc   '>>1/8 shrink\N1021',00
            asc   '>>1/4 shrink\N1022',00
            asc   '>>1/2 shrink\N1023',00
            asc   '>>Actual size\N768',00
            asc   '>>2X zoom\N769',00
            asc   '>>4X zoom\N770',00
            asc   '>>8X zoom\N771',00
            asc   '.',00
PopText2    asc   '##Blah\N2',00
            asc   '>>Selection mode\N513',00
            asc   '>>Pixel peek mode\N514',00
            asc   '.',00
PopText4    asc   '##Blah\N4',00
            asc   '>>Crop to selection\N1025',00
            asc   '>>Discard this image type\N1026',00
            asc   '>>Discard other image types\N1027',00
            asc   '.',00
PopText5    asc   '##Blah\N5',00
            asc   '>>Clicking sets VOC key color\N1281D',00
            asc   '.',00

