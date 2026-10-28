*-------------------------------------------------------------
* CPC.s - Amstrad CPC screens (part of the Other segment): the 16K of
* screen memory, with or without the 128-byte AMSDOS header in front
* (known by its checksum), or packed by OCP Art Studio (blocks that start
* "MJH"). Line y starts at (y & 7) x 2048 + (y >> 3) x 80, 80 bytes a line.
* Mode 0 is 160 x 200 in 16 colours (its pixels twice as wide); mode 1, 320
* x 200 in 4; mode 2, 640 x 200 in 2. The mode and the inks' colours come
* from the .PAL file beside it (OCP Art Studio's; Formats.s reads it), if
* there is one; else each mode has its own entry, and the inks have the
* colours the CPC starts with. Screen images.
*-------------------------------------------------------------

LoadCPC0    lda   #0
            bra   CpcGo
LoadCPC1    lda   #1
            bra   CpcGo
LoadCPC2    lda   #2
CpcGo       sta   CpMode
            stz   CpUnpacked
            jsr   CpcBase
            bcc   :ok
            rts
:ok         jsr   CpcPal                ; (the .PAL file's mode and colours)
            jsr   ScrBegin
            stz   Is640
            lda   #320
            sta   PixW
            lda   CpMode
            cmp   #2
            bne   :pal
            lda   #$80                  ; mode 2: 640 mode lines
            ldx   #200
            jsr   SetScbs
            lda   #1
            sta   Is640
            lda   #640
            sta   PixW
:pal        ldx   #CpInks
            jsr   SetTable0
            stz   RowY
:row        lda   RowY                  ; the line: (y & 7) x 2048 + (y >> 3) x 80
            and   #$0007
            xba
            asl
            asl
            asl
            sta   t1
            lda   RowY
            lsr
            lsr
            lsr
            sta   t2                    ; x 80 = x 64 + x 16
            asl
            asl
            asl
            asl
            sta   t0
            asl
            asl
            clc
            adc   t0
            clc
            adc   t1
            clc
            adc   CpBase
            sta   CpAddr
            ldx   #0                    ; (X: the pixel)
            stz   CpCol
:byte       lda   CpAddr
            clc
            adc   CpCol
            tay
            lda   [fp],y
            and   #$00FF
            sta   t3
            lda   CpMode
            beq   :m0
            cmp   #1
            beq   :m1
            lda   t3                    ; mode 2: a bit a pixel
            xba
            ldy   #8
:b2         asl
            pha
            lda   #0
            rol
            jsr   CpPut
            pla
            dey
            bne   :b2
            bra   :next
:m1         ldy   #4                    ; mode 1: bit 7 - k and bit 3 - k
:b1         stz   t2
            lda   t3
            and   #$0080
            beq   :lo1
            inc   t2
:lo1        lda   t3
            and   #$0008
            beq   :put1
            lda   #2
            tsb   t2
:put1       asl   t3
            lda   t2
            jsr   CpPut
            dey
            bne   :b1
            bra   :next
:m0         jsr   CpMode0               ; mode 0: the left pixel, then the
            pha                         ; right (the same bits one along)
            jsr   CpPut
            pla
            jsr   CpPut
            asl   t3
            jsr   CpMode0
            pha
            jsr   CpPut
            pla
            jsr   CpPut
:next       inc   CpCol
            lda   CpCol
            cmp   #80
            bcs   :line
            jmp   :byte
:line       jsr   PackRow
            inc   RowY
            lda   RowY
            cmp   #200
            bcs   :done
            jmp   :row
:done       lda   CpUnpacked            ; (a packed screen: the file back)
            beq   :out
            jsr   CpcFile
:out        lda   CpMode                ; the format, as the mode it is
            clc
            adc   #fmtCPC0
            sta   Found
            clc
            rts

* CpMode0: the mode 0 pixel in t3's bits 7, 3, 5 and 1 (lowest first).
CpMode0     stz   t2
            lda   t3
            and   #$0080
            beq   :b1
            lda   #1
            tsb   t2
:b1         lda   t3
            and   #$0008
            beq   :b2
            lda   #2
            tsb   t2
:b2         lda   t3
            and   #$0020
            beq   :b3
            lda   #4
            tsb   t2
:b3         lda   t3
            and   #$0002
            beq   :done
            lda   #8
            tsb   t2
:done       lda   t2
            rts

* CpPut: pixel A into RowPix at X; X on. Keeps Y.
CpPut       sep   #$20
            mx    %10
            sta   RowPix,x
            rep   #$20
            mx    %00
            inx
            rts

* CpcBase: CpBase = 128 if the file starts with an AMSDOS header (the sum
* of its first 67 bytes in bytes 67-68), else 0. A packed screen is unpacked
* into a buffer, which stands for the file until CpcFile; otherwise the file
* must hold the screen's lines. Out: carry set and A = error if not a screen.
CpcBase     stz   CpBase
            lda   flen+2
            bne   :head
            lda   flen
            cmp   #128+5
            bcc   :packed
:head       stz   t1
            ldy   #0
:sum        lda   [fp],y
            and   #$00FF
            clc
            adc   t1
            sta   t1
            iny
            cpy   #67
            bcc   :sum
            ldy   #67
            lda   [fp],y
            cmp   t1
            bne   :packed
            lda   #128
            sta   CpBase
:packed     ldy   CpBase                ; "MJH": OCP Art Studio's packing
            lda   [fp],y
            cmp   #$4A4D                ; ("MJ")
            bne   :size
            iny
            iny
            lda   [fp],y
            and   #$00FF
            cmp   #'H'
            bne   :size
            jmp   CpcUnpack
:size       lda   flen+2                ; the last line ends at 16336
            bne   :ok
            lda   CpBase
            clc
            adc   #16336
            cmp   flen
            beq   :ok
            bcc   :ok
            lda   #errNotPicture
            sec
            rts
:ok         clc
            rts

* CpcUnpack: the blocks of a packed screen ("MJH", the bytes it makes, then
* bytes as they are, or 1, count (0: 256), byte for a run) into a 16K
* buffer, which then stands for the file (from CpBase 0).
CpcUnpack   lda   #16384
            jsr   NewOut
            bcc   :got
            rts
:got        lda   fp                    ; (the file, for CpcFile)
            sta   CpFile
            lda   fp+2
            sta   CpFile+2
            lda   flen
            sta   CpFileL
            lda   flen+2
            sta   CpFileL+2
            inc   CpUnpacked
            lda   CpBase
            jsr   SAtA
            ldy   #0                    ; (Y: where in the buffer)
:block      jsr   SByte                 ; a block: "MJH"
            bcs   :done
            cmp   #'M'
            bne   :done
            jsr   SByte
            jsr   SByte
            jsr   SLE16                 ; the bytes it makes
            sty   t2
            clc
            adc   t2
            bcs   :all
            cmp   #16384
            bcc   :end
:all        lda   #16384
:end        sta   CpEnd
:data       cpy   CpEnd
            bcs   :block
            jsr   SByte
            bcs   :done
            cmp   #1
            beq   :run
            jsr   :put
            bra   :data
:run        jsr   SByte                 ; a run: count (0: 256), byte
            cmp   #0
            bne   :n
            lda   #256
:n          sta   CpRun
            jsr   SByte
:rep        jsr   :put
            dec   CpRun
            bne   :rep
            bra   :data
:put        cpy   CpEnd                 ; (no further than the block says)
            bcs   :full
            sep   #$20
            mx    %10
            sta   [OutDP],y
            rep   #$20
            mx    %00
            iny
:full       rts
:done       lda   OutP                  ; the buffer stands for the file
            sta   fp
            lda   OutP+2
            sta   fp+2
            lda   #16384
            sta   flen
            stz   flen+2
            stz   CpBase
            clc
            rts

* CpcFile: the file back after a packed screen, and the buffer freed.
CpcFile     lda   CpFile
            sta   fp
            lda   CpFile+2
            sta   fp+2
            lda   CpFileL
            sta   flen
            lda   CpFileL+2
            sta   flen+2
            stz   CpUnpacked
            jmp   FreeOut

* CpcPal: CpInks, the 16 colour table entries: from the .PAL file if there
* is one (each ink's first colour, a Gate Array colour number; and the mode,
* when Open chose the format), else the inks' start-up colours. Mode 1
* uses 4 inks, mode 2 two (in 640 mode, the same for each pixel of a group).
CpcPal      ldx   #30                   ; start-up colours
:def        lda   CpPal0,x
            sta   CpSrc,x
            dex
            dex
            bpl   :def
            lda   opal
            cmp   #207
            bcc   :spread
            lda   Want                  ; Open: the mode the file says
            beq   :mode
            cmp   #$FFFF
            bne   :inks
:mode       lda   [ipg]
            and   #$00FF
            cmp   #3
            bcs   :inks
            sta   CpMode
:inks       ldx   #0                    ; each ink: byte 3 + 12 x ink
            ldy   #3
:ink        lda   [ipg],y
            and   #$001F
            asl
            phx
            tax
            lda   CpHw,x
            plx
            sta   CpSrc,x
            tya
            clc
            adc   #12
            tay
            inx
            inx
            cpx   #32
            bcc   :ink
:spread     ldx   #30                   ; the table for the mode
:copy       txa
            ldy   CpMode
            beq   :m0
            and   #$0006                ; mode 1: inks 0-3 repeated
            cpy   #1
            beq   :m0
            and   #$0002                ; mode 2: inks 0 and 1 repeated
:m0         tay
            lda   CpSrc,y
            sta   CpInks,x
            dex
            dex
            bpl   :copy
            rts

* The 16 inks' colours as the CPC starts up (its colour n: 9 x green + 3 x
* red + blue, each 0, half or full).
CpPal0      dw    $008,$FF0,$0FF,$F00,$FFF,$000,$00F,$F0F
            dw    $088,$880,$88F,$F88,$0F0,$8F8,$008,$F88

* The Gate Array's 32 colour numbers as Super Hi-Res colours.
CpHw        dw    $888,$888,$0F8,$FF8,$008,$F08,$088,$F88
            dw    $F08,$FF8,$FF0,$FFF,$F00,$F0F,$F80,$F8F
            dw    $008,$0F8,$0F0,$0FF,$000,$00F,$080,$08F
            dw    $808,$8F8,$8F0,$8FF,$800,$80F,$880,$88F

CpSrc       ds    32
CpInks      ds    32
CpFile      adrl  0
CpFileL     adrl  0
CpEnd       dw    0
CpRun       dw    0
CpUnpacked  dw    0
CpMode      dw    0
CpBase      dw    0
CpAddr      dw    0
CpCol       dw    0
