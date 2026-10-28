*-------------------------------------------------------------
* PICT.s - QuickDraw pictures from the Macintosh (part of the Other
* segment): version 1 and 2, with or without the 512 bytes a Mac file
* starts with. The bit maps and pixel maps in them are drawn (BitsRect,
* PackBitsRect, DirectBitsRect, and the same through a region): 1, 2, 4
* or 8 bits a pixel through a colour table, 16 or 32 bits a pixel. The
* other drawing commands are passed over. Each image goes where the
* picture puts it; when the first is drawn at another size (a picture of
* more than 72 dots an inch), the whole picture is made that much bigger,
* so the pixels stay as they are. What no image covers is white.
*-------------------------------------------------------------

PcPalR      =     TgPalR                ; (the colour table: TGA's colour map,
PcPalG      =     TgPalG                ; never in use at the same time)
PcPalB      =     TgPalB

* LoadPICT: out: carry clear, or carry set and A = error
LoadPICT    lda   #0                    ; the version at 10, or at 522 after
            jsr   PcFind                ; a Mac file's 512 bytes
            bcc   :found
            lda   #512
            jsr   PcFind
            bcc   :found
            lda   #errNotPicture
            sec
            rts
:found      stz   PcMade
:op         jsr   PcOpcode              ; the next command
            bcs   :end
            cmp   #$0100
            bcs   :long
            tax
            lda   PcOps,x
            and   #$00FF
            cmp   #$0080
            bcs   :special
            jsr   PcSkip                ; (a fixed length)
            bra   :op
:special    sec
            sbc   #$0080
            asl
            tax
            jsr   (PcSpec,x)
            bcc   :op
            cmp   #0                    ; 0: the end of the picture
            bne   :err
:end        lda   PcMade
            beq   :none
            clc
            rts
:none       lda   #errUnsupported       ; no image in it
:err        sec
            rts
:long       cmp   #$8000                ; version 2's own commands:
            bcs   :hi
            xba                         ; $0100-$7FFF: (high byte) x 2 bytes
            and   #$00FF
            asl
            jsr   PcSkip
            bra   :op
:hi         cmp   #$8100                ; $8000-$80FF: nothing; the rest: a
            bcc   :op                   ; long length, then that much
            jsr   PcSkipL
            bra   :op

* What follows each command up to $FF: a length (up to $7F), or one of these.
PcSpec      da    PcRgn,PcWord,PcLong,PcLText,PcDText,PcDHDV,PcLComm,PcEnd
            da    PcBitsOp,PcDirect,PcVerOp,PcPixPat
PcOps       db    $00,$80,$08,$02,$01,$02,$04,$04,$02,$08,$08,$04,$04,$02,$04,$04
            db    $08,$8A,$8B,$8B,$8B,$02,$02,$00,$00,$00,$06,$06,$00,$06,$00,$06
            db    $08,$04,$06,$02,$81,$81,$81,$81,$83,$84,$84,$85,$81,$81,$81,$81
            db    $08,$08,$08,$08,$08,$08,$08,$08,$00,$00,$00,$00,$00,$00,$00,$00
            db    $08,$08,$08,$08,$08,$08,$08,$08,$00,$00,$00,$00,$00,$00,$00,$00
            db    $08,$08,$08,$08,$08,$08,$08,$08,$00,$00,$00,$00,$00,$00,$00,$00
            db    $0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$04,$04,$04,$04,$04,$04,$04,$04
            db    $80,$80,$80,$80,$80,$80,$80,$80,$00,$00,$00,$00,$00,$00,$00,$00
            db    $80,$80,$80,$80,$80,$80,$80,$80,$00,$00,$00,$00,$00,$00,$00,$00
            db    $88,$88,$81,$81,$81,$81,$81,$81,$88,$88,$89,$89,$81,$81,$81,$81
            db    $02,$86,$81,$81,$81,$81,$81,$81,$81,$81,$81,$81,$81,$81,$81,$81
            db    $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
            db    $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
            db    $82,$82,$82,$82,$82,$82,$82,$82,$82,$82,$82,$82,$82,$82,$82,$82
            db    $82,$82,$82,$82,$82,$82,$82,$82,$82,$82,$82,$82,$82,$82,$82,$82
            db    $82,$82,$82,$82,$82,$82,$82,$82,$82,$82,$82,$82,$82,$82,$82,$87

* PcFind: carry clear if a picture's version is at A + 10; its frame
* noted, the version (1: one-byte commands) in PcVer, and the stream at
* the command after it.
PcFind      sta   PcBase
            clc
            adc   #10
            jsr   SAtA
            bcs   :no
            jsr   SBE16
            cmp   #$1101                ; version 1: $11, 1
            beq   :v1
            cmp   #$0011                ; version 2: $0011, $02FF
            bne   :no
            jsr   SBE16
            cmp   #$02FF
            bne   :no
            lda   #2
            bra   :ver
:v1         lda   #1
:ver        sta   PcVer
            jsr   SPos
            lda   n0
            pha
            lda   PcBase                ; the frame: top, left, bottom, right
            clc
            adc   #2
            jsr   SAtA
            jsr   SBE16
            sta   PcFT
            jsr   SBE16
            sta   PcFL
            jsr   SBE16
            sec
            sbc   PcFT
            sta   PcFH
            jsr   SBE16
            sec
            sbc   PcFL
            sta   PcFW
            pla
            jsr   SAtA
            lda   PcFW                  ; none, or upside down: not a picture
            beq   :no
            bmi   :no
            lda   PcFH
            beq   :no
            bmi   :no
            clc
            rts
:no         sec
            rts

* PcSig: carry clear if the file is a version 2 picture: $0011 $02FF at
* 10, or at 522 (after a Mac file's 512 bytes).
PcSig       ldy   #10
            jsr   PcSigAt
            bcc   :yes
            lda   flen+2
            bne   :far
            lda   flen
            cmp   #528
            bcc   :no
:far        ldy   #522
            jmp   PcSigAt
:no         sec
:yes        rts

PcSigAt     lda   [fp],y
            cmp   #$1100
            bne   :no
            iny
            iny
            lda   [fp],y
            cmp   #$FF02
            bne   :no
            clc
            rts
:no         sec
            rts

* PcOpcode: the next command in A (and PcOpNo); version 2's are words
* on even bytes. Carry set past the end.
PcOpcode    lda   PcVer
            cmp   #2
            bne   :v1
            jsr   SPos
            lda   n0
            lsr
            bcc   :even
            jsr   SByte
:even       jsr   SBE16
            bra   :got
:v1         jsr   SByte
:got        sta   PcOpNo
            rts

* PcSkip: passes over A bytes; PcSkipL: over as many as the long number
* that comes next says.
PcSkip      sta   n0
            stz   n0+2
            jmp   SSkip

PcSkipL     jsr   SBE32
            lda   n1
            sta   n0
            lda   n1+2
            sta   n0+2
            jmp   SSkip

* The commands' own lengths (each: carry clear to go on; carry set and
* A = 0 at the end, or A = error).
PcRgn       jsr   SBE16                 ; a region or polygon: its size,
            sec                         ; counting itself
            sbc   #2
            bcs   PcSkipC
            clc
            rts
PcWord      jsr   SBE16                 ; a word's length, then that much
PcSkipC     jsr   PcSkip
            clc
            rts
PcLong      jsr   PcSkipL               ; a long length
            clc
            rts
PcLText     lda   #4                    ; text after a point
            bra   PcText
PcDText     lda   #1                    ; text after a move across or down
            bra   PcText
PcDHDV      lda   #2                    ; text after a move across and down
PcText      jsr   PcSkip
            jsr   SByte                 ; (its length)
            bra   PcSkipC
PcLComm     lda   #2                    ; a comment: its kind, then a length
            jsr   PcSkip
            bra   PcWord
PcEnd       lda   #0
            sec
            rts
PcVerOp     lda   PcVer                 ; (another version command)
            bra   PcSkipC
PcPixPat    jsr   SBE16                 ; a pattern: its kind, then 8 bytes
            sta   PcT
            lda   #8
            jsr   PcSkip
            lda   PcT
            cmp   #2                    ; 2: an RGB colour
            bne   :map
            lda   #6
            bra   PcSkipC
:map        cmp   #1                    ; 1: a pixel map, a colour table and
            bne   :done                 ; the pixels
            jsr   SBE16
            and   #$3FFF
            sta   PcRB
            lda   #$8000
            sta   PcIsPix
            jsr   PcHead
            jsr   PcCTab
            stz   PcMode
            stz   PcPk                  ; (packed if 8 bytes a row or more)
            lda   PcRB
            cmp   #8
            bcc   :rows
            inc   PcPk
:rows       stz   PcJ
:row        lda   PcJ                   ; (each row: as it is, or packed)
            cmp   PcBH
            bcs   :done
            jsr   PcRowLen
            jsr   SSkip
            inc   PcJ
            bra   :row
:done       clc
            rts

* PcHead: after the row length (PcRB; PcIsPix $8000 for a pixel map):
* the bounds, and for a pixel map how it is packed, the bits a pixel
* and the colour components.
PcHead      jsr   SBE16
            sta   PcBT
            jsr   SBE16
            sta   PcBL
            jsr   SBE16
            sec
            sbc   PcBT
            sta   PcBH
            jsr   SBE16
            sec
            sbc   PcBL
            sta   PcBW
            lda   #1                    ; a bit map: 1 bit a pixel
            sta   PcBits
            sta   PcCmp
            stz   PcPack
            lda   PcIsPix
            beq   :done
            lda   #2                    ; (its version)
            jsr   PcSkip
            jsr   SBE16                 ; how it is packed
            sta   PcPack
            lda   #14                   ; (size, resolution, kind)
            jsr   PcSkip
            jsr   SBE16
            sta   PcBits                ; bits a pixel, components
            jsr   SBE16
            sta   PcCmp
            lda   #14                   ; (component size, the rest)
            jsr   PcSkip
:done       rts

* PcCTab: a colour table into PcPalR, PcPalG, PcPalB (by each entry's
* value, or by its place when its flags say so); the rest black.
PcCTab      ldx   #510
:z          stz   PcPalR,x
            stz   PcPalG,x
            stz   PcPalB,x
            dex
            dex
            bpl   :z
            lda   #4                    ; (its seed)
            jsr   PcSkip
            jsr   SBE16
            sta   PcCFlags
            jsr   SBE16                 ; entries - 1
            inc
            sta   PcK
            stz   PcI
:e          lda   PcK
            beq   :done
            jsr   SBE16                 ; value, red, green, blue
            bit   PcCFlags
            bpl   :val
            lda   PcI
:val        cmp   #256
            bcc   :in
            lda   #256                  ; (out of range: not kept)
:in         asl
            tax
            jsr   PcTo8
            sta   PcR
            jsr   PcTo8
            sta   PcG
            jsr   PcTo8
            cpx   #512
            bcs   :next
            sta   PcPalB,x
            lda   PcR
            sta   PcPalR,x
            lda   PcG
            sta   PcPalG,x
:next       inc   PcI
            dec   PcK
            bra   :e
:done       rts

* PcTo8: the next 16-bit colour component to 8 bits, rounded: v / 257,
* as (x - x >> 8) >> 8 with x = v + 128. Keeps X and Y.
PcTo8       jsr   SBE16
            cmp   #$FF7F
            bcs   :max
            clc
            adc   #128
            sta   PcT
            xba
            and   #$00FF
            eor   #$FFFF
            sec
            adc   PcT
            xba
            and   #$00FF
            rts
:max        lda   #255
            rts

* PcBitsOp: BitsRect, PackBitsRect (through a region if the command is
* odd): a bit map, or a pixel map of 1, 2, 4 or 8 bits a pixel.
PcBitsOp    jsr   SBE16
            tax
            and   #$3FFF
            sta   PcRB
            txa
            and   #$8000
            sta   PcIsPix
            jsr   PcHead
            lda   PcIsPix
            bne   :pix
            lda   #$00FF                ; a bit map: 0 white, 1 black
            sta   PcPalR
            sta   PcPalG
            sta   PcPalB
            stz   PcPalR+2
            stz   PcPalG+2
            stz   PcPalB+2
            bra   :go
:pix        jsr   PcCTab
            lda   PcBits
            cmp   #1
            beq   :go
            cmp   #2
            beq   :go
            cmp   #4
            beq   :go
            cmp   #8
            beq   :go
            lda   #errUnsupported
            sec
            rts
:go         stz   PcMode                ; packed if the command says so and
            lda   PcOpNo                ; the rows are 8 bytes or more
            and   #$0008
            beq   :raw
            lda   PcRB
            cmp   #8
            bcc   :raw
            lda   #1
            bra   :pk
:raw        lda   #0
:pk         sta   PcPk
            jmp   PcImage

* PcDirect: DirectBitsRect (and through a region): 16 or 32 bits a pixel.
PcDirect    lda   #4                    ; (an address)
            jsr   PcSkip
            jsr   SBE16
            and   #$3FFF
            sta   PcRB
            lda   #$8000
            sta   PcIsPix
            jsr   PcHead
            lda   #1                    ; packed, unless the rows are short
            sta   PcPk
            lda   PcRB
            cmp   #8
            bcs   :size
            stz   PcPk
:size       lda   PcBits
            cmp   #16
            beq   :16
            cmp   #32
            bne   :unsup
            lda   PcPk                  ; 32 bits: each row's red, green, blue
            beq   :x32                  ; apart (and alpha first if 4)
            lda   PcPack
            cmp   #1
            beq   :x32a
            cmp   #2
            beq   :rgb
            lda   PcCmp
            cmp   #3
            bcc   :unsup
            cmp   #5
            bcs   :unsup
            lda   #5
            bra   :mode
:x32a       stz   PcPk                  ; not packed: x, red, green, blue
:x32        lda   #3
            bra   :mode
:rgb        stz   PcPk                  ; red, green, blue, not packed
            lda   #4
            bra   :mode
:16         lda   PcPk                  ; 16 bits: packed a word at a time,
            beq   :w16                  ; or not
            lda   PcPack
            cmp   #1
            bne   :p16
            stz   PcPk
:w16        lda   #1
            bra   :mode
:p16        lda   #2
:mode       sta   PcMode
            jmp   PcImage
:unsup      lda   #errUnsupported
            sec
            rts

* PcImage: the source and destination rectangles, the mode (and a
* region), then the rows of pixels (as PcMode says), each drawn where it
* goes in the picture, made if this is the first image.
PcImage     jsr   SBE16
            sta   PcST
            jsr   SBE16
            sta   PcSL
            jsr   SBE16
            sta   PcSB
            jsr   SBE16
            sta   PcSR
            jsr   SBE16
            sta   PcDT
            jsr   SBE16
            sta   PcDL
            jsr   SBE16
            sta   PcDB
            jsr   SBE16
            sta   PcDR
            lda   #2                    ; (the transfer mode)
            jsr   PcSkip
            lda   PcOpNo                ; (a region)
            and   #$0001
            beq   :size
            jsr   PcRgn
:size       lda   PcBW                  ; an image of no size, or too big
            beq   :unsup
            cmp   #4097
            bcs   :unsup
            lda   PcBH
            beq   :unsup
            cmp   #4097
            bcs   :unsup
            lda   PcMade
            bne   :made
            jsr   PcMake
            bcc   :made
            rts
:unsup      lda   #errUnsupported
            sec
            rts
:made       jsr   PcPlace
            lda   PcFirst               ; the first image: the rest white
            beq   :rows                 ; if it doesn't cover all
            stz   PcFirst
            lda   PcHi
            sec
            sbc   PcLo
            cmp   GW
            bne   :white
            lda   PcHiY
            sec
            sbc   PcLoY
            cmp   GH
            beq   :rows
:white      jsr   PcWhite
:rows       stz   PcJ
:row        lda   PcJ
            cmp   PcBH
            bcc   :one
            clc
            rts
:one        stz   PcHiNow               ; this row in the picture?
            cmp   PcLoY
            bcc   :len
            cmp   PcHiY
            bcs   :len
            clc
            adc   PcOy
            jsr   TrueRow
            lda   PcHi
            sta   PcHiNow
:len        jsr   PcRowLen              ; where the next row starts
            jsr   SPos
            lda   n0
            clc
            adc   PcRowL
            sta   PcEnd0
            lda   n0+2
            adc   PcRowL+2
            sta   PcEnd0+2
            jsr   PBStart
            stz   PcWLeft
            stz   PcBLeft
            stz   PcI
            lda   PcOx                  ; Y: the first pixel's place in the row
            asl
            clc
            adc   PcOx
            tay
            lda   PcMode
            asl
            tax
            jsr   (PcModes,x)
            lda   PcEnd0                ; (whatever the row held)
            sta   n0
            lda   PcEnd0+2
            sta   n0+2
            jsr   SAt
            inc   PcJ
            bra   :row

PcModes     da    PcRowIdx,PcRow16,PcRow16,PcRow32,PcRow24,PcRowPl

* PcRowLen: n0 (and PcRowL) = the bytes of this row: the count before it
* if packed (a word if the rows are over 250 bytes), else as long as
* the row is (3 bytes a pixel for 24 bits).
PcRowLen    stz   n0+2
            lda   PcPk
            beq   :raw
            lda   PcRB
            cmp   #251
            bcs   :w
            jsr   SByte
            bra   :n
:w          jsr   SBE16
            bra   :n
:raw        lda   PcMode
            cmp   #4
            bne   :rb
            lda   PcBW
            asl
            clc
            adc   PcBW
            bra   :n
:rb         lda   PcRB
:n          sta   n0
            sta   PcRowL
            stz   PcRowL+2
            rts

* PcByte: the row's next byte (packed or not). Keeps X and Y.
PcByte      lda   PcPk
            beq   :raw
            jmp   PBGet
:raw        jmp   SByte

* PcPut: CR, CG, CB at Y if pixel PcI is in the picture; Y on 3 either way.
PcPut       lda   PcI
            cmp   PcLo
            bcc   :skip
            cmp   PcHiNow
            bcs   :skip
            jmp   PutRGB
:skip       iny
            iny
            iny
            rts

* PcRowIdx: a row of 1, 2, 4 or 8 bits a pixel, through the colour table.
PcRowIdx    lda   PcBits
            cmp   #8
            bne   :part
            jsr   PcByte
            bra   :idx
:part       lda   PcBLeft               ; the next bits from the left
            bne   :have
            jsr   PcByte
            sta   PcBuf
            lda   #8
            sta   PcBLeft
:have       lda   PcBits
            sta   PcK
            lda   PcBuf
            and   #$00FF
:sh         asl
            dec   PcK
            bne   :sh
            sta   PcBuf
            lda   PcBLeft
            sec
            sbc   PcBits
            sta   PcBLeft
            lda   PcBuf
            xba
            and   #$00FF
:idx        asl
            tax
            lda   PcPalR,x
            sta   CR
            lda   PcPalG,x
            sta   CG
            lda   PcPalB,x
            sta   CB
            jsr   PcPut
            inc   PcI
            lda   PcI
            cmp   PcBW
            bcc   PcRowIdx
            rts

* PcRow16: a row of 16-bit pixels (x rrrrr ggggg bbbbb), packed a word at
* a time (PcMode 2) or not.
PcRow16     lda   PcMode
            cmp   #2
            beq   :packed
            jsr   SBE16
            bra   :got
:packed     jsr   PcWGet
:got        sta   PcR
            and   #$001F
            jsr   PcWide
            sta   CB
            lda   PcR
            lsr
            lsr
            lsr
            lsr
            lsr
            and   #$001F
            jsr   PcWide
            sta   CG
            lda   PcR
            xba
            lsr
            lsr
            and   #$001F
            jsr   PcWide
            sta   CR
            jsr   PcPut
            inc   PcI
            lda   PcI
            cmp   PcBW
            bcc   PcRow16
            rts

* PcWide: 5 bits to 8 (v << 3 | v >> 2).
PcWide      sta   PcG
            asl
            asl
            asl
            sta   PcT
            lda   PcG
            lsr
            lsr
            ora   PcT
            rts

* PcWGet: the next word of a row packed a word at a time (as PackBits,
* but each count is of words). Keeps X and Y.
PcWGet      lda   PcWLeft
            bne   :have
            jsr   SByte
            cmp   #$80
            beq   PcWGet
            bcs   :run
            inc                         ; n + 1 words as they are
            sta   PcWLeft
            stz   PcWRun
            bra   :have
:run        eor   #$00FF                ; 1 - n of the next word
            clc
            adc   #2
            sta   PcWLeft
            jsr   SBE16
            sta   PcWVal
            lda   #1
            sta   PcWRun
:have       dec   PcWLeft
            lda   PcWRun
            beq   :lit
            lda   PcWVal
            rts
:lit        jmp   SBE16

* PcRow32: x, red, green, blue a pixel; PcRow24: red, green, blue.
PcRow32     jsr   SByte
PcRow24     jsr   SByte
            sta   CR
            jsr   SByte
            sta   CG
            jsr   SByte
            sta   CB
            jsr   PcPut
            inc   PcI
            lda   PcI
            cmp   PcBW
            bcs   :done
            lda   PcMode
            cmp   #4
            beq   PcRow24
            bra   PcRow32
:done       rts

* PcRowPl: a packed row of the components apart: (alpha,) red, green, blue.
PcRowPl     sty   PcY0
            lda   PcCmp                 ; the first plane: alpha if 4
            sec
            sbc   #3
            eor   #$FFFF
            inc
            sta   PcC                   ; -1 alpha, 0 red, 1 green, 2 blue
:plane      lda   PcC
            bmi   :skip
            clc
            adc   PcY0
            tay
            stz   PcI
:px         jsr   PBGet
            tax
            lda   PcI
            cmp   PcLo
            bcc   :next
            cmp   PcHiNow
            bcs   :next
            txa
            sep   #$20
            sta   [q0],y
            rep   #$20
:next       iny
            iny
            iny
            inc   PcI
            lda   PcI
            cmp   PcBW
            bcc   :px
            bra   :done
:skip       ldx   PcBW                  ; (alpha: passed over)
:a          jsr   PBGet
            dex
            bne   :a
:done       inc   PcC
            lda   PcC
            cmp   #3
            bcc   :plane
            rts

* PcMake: the picture, the frame's size (made bigger as much as the first
* image is drawn smaller).
PcMake      lda   PcSR
            sec
            sbc   PcSL
            sta   PcNX
            lda   PcDR
            sec
            sbc   PcDL
            sta   PcDX
            lda   PcSB
            sec
            sbc   PcST
            sta   PcNY
            lda   PcDB
            sec
            sbc   PcDT
            sta   PcDY
            lda   PcNX                  ; (sizes of nothing: as they are)
            dec
            bmi   :one
            lda   PcDX
            dec
            bmi   :one
            lda   PcNY
            dec
            bmi   :one
            lda   PcDY
            dec
            bpl   :size
:one        lda   #1
            sta   PcNX
            sta   PcDX
            sta   PcNY
            sta   PcDY
:size       lda   PcFW
            jsr   PcScaleX
            sta   GW
            lda   PcFH
            jsr   PcScaleY
            sta   GH
            lda   GW
            beq   :unsup
            cmp   #4097
            bcs   :big
            lda   GH
            beq   :unsup
            cmp   #4097
            bcs   :big
            ldx   GH
            lda   GW
            stz   ttall
            jsr   MakeTrue
            bcs   :out
            lda   #1
            sta   PcMade
            sta   PcFirst
            clc
:out        rts
:big        lda   #errTooBig
            sec
            rts
:unsup      lda   #errUnsupported
            sec
            rts

* PcScaleX, PcScaleY: A (not negative) * the first image's size / the
* size it is drawn at, across or down.
PcScaleX    ldx   PcNX
            ldy   PcDX
            bra   PcScale
PcScaleY    ldx   PcNY
            ldy   PcDY
PcScale     sty   PcT2
            cpx   PcT2
            beq   :same
            cmp   #$8000
            bcs   :same
            jsr   Mul16
            lda   MLo
            sta   n0
            lda   MHi
            sta   n0+2
            lda   PcT2
            jmp   Div32
:same       rts

* PcPlace: where this image goes: pixel x of the bounds at x + PcOx of
* the picture, those from PcLo up to PcHi drawn (the source rectangle's,
* inside the picture); rows likewise (PcOy, PcLoY, PcHiY).
PcPlace     lda   PcDL                  ; across
            sec
            sbc   PcFL
            jsr   PcScaleX
            clc
            adc   PcBL
            sec
            sbc   PcSL
            sta   PcOx
            lda   PcSL                  ; from the larger of: the source's
            sec                         ; left, the picture's, 0
            sbc   PcBL
            sta   PcT
            lda   #0
            sec
            sbc   PcOx
            jsr   PcSMax
            stz   PcT
            jsr   PcSMax
            sta   PcLo
            lda   PcSR                  ; up to the smaller of: the source's
            sec                         ; right, the picture's, the width
            sbc   PcBL
            sta   PcT
            lda   GW
            sec
            sbc   PcOx
            jsr   PcSMin
            ldx   PcBW
            stx   PcT
            jsr   PcSMin
            ldx   PcLo                  ; (none: up to where it starts)
            stx   PcT
            jsr   PcSMax
            sta   PcHi
            lda   PcDT                  ; down
            sec
            sbc   PcFT
            jsr   PcScaleY
            clc
            adc   PcBT
            sec
            sbc   PcST
            sta   PcOy
            lda   PcST
            sec
            sbc   PcBT
            sta   PcT
            lda   #0
            sec
            sbc   PcOy
            jsr   PcSMax
            stz   PcT
            jsr   PcSMax
            sta   PcLoY
            lda   PcSB
            sec
            sbc   PcBT
            sta   PcT
            lda   GH
            sec
            sbc   PcOy
            jsr   PcSMin
            ldx   PcBH
            stx   PcT
            jsr   PcSMin
            ldx   PcLoY
            stx   PcT
            jsr   PcSMax
            sta   PcHiY
            rts

* PcSMax, PcSMin: A = the larger or smaller of A and PcT (signed).
PcSMax      pha
            sec
            sbc   PcT
            bvc   :v
            eor   #$8000
:v          bmi   :t
            pla
            rts
:t          pla
            lda   PcT
            rts

PcSMin      pha
            sec
            sbc   PcT
            bvc   :v
            eor   #$8000
:v          bpl   :t
            pla
            rts
:t          pla
            lda   PcT
            rts

* PcWhite: the whole picture white.
PcWhite     lda   GW
            asl
            clc
            adc   GW
            sta   PcT
            stz   PcK
:row        lda   PcK
            jsr   TrueRow
            ldy   #0
            sep   #$20
            lda   #$FF
:px         sta   [q0],y
            iny
            cpy   PcT
            bcc   :px
            rep   #$20
            inc   PcK
            lda   PcK
            cmp   GH
            bcc   :row
            rts

PcBase      dw    0
PcVer       dw    0
PcOpNo      dw    0
PcMade      dw    0
PcFirst     dw    0
PcFT        dw    0
PcFL        dw    0
PcFW        dw    0
PcFH        dw    0
PcRB        dw    0
PcIsPix     dw    0
PcBT        dw    0
PcBL        dw    0
PcBW        dw    0
PcBH        dw    0
PcBits      dw    0
PcCmp       dw    0
PcPack      dw    0
PcPk        dw    0
PcMode      dw    0
PcCFlags    dw    0
PcST        dw    0
PcSL        dw    0
PcSB        dw    0
PcSR        dw    0
PcDT        dw    0
PcDL        dw    0
PcDB        dw    0
PcDR        dw    0
PcNX        dw    0
PcDX        dw    0
PcNY        dw    0
PcDY        dw    0
PcOx        dw    0
PcOy        dw    0
PcLo        dw    0
PcHi        dw    0
PcHiNow     dw    0
PcLoY       dw    0
PcHiY       dw    0
PcJ         dw    0
PcI         dw    0
PcK         dw    0
PcT         dw    0
PcT2        dw    0
PcR         dw    0
PcG         dw    0
PcC         dw    0
PcY0        dw    0
PcBuf       dw    0
PcBLeft     dw    0
PcWLeft     dw    0
PcWRun      dw    0
PcWVal      dw    0
PcRowL      adrl  0
PcEnd0      adrl  0
