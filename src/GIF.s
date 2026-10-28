*-------------------------------------------------------------
* GIF.s - GIF 87a and 89a (the first picture in the file)
*
* The picture is drawn on a white canvas the size of the GIF's
* logical screen; transparent pixels stay white.
*-------------------------------------------------------------

Prefix      =     Work                  ; 4096 words
Suffix      =     Work+8192             ; 4096 bytes
Stack       =     Work+12288            ; 4096 bytes

DecodeGIF   lda   #6
            sta   n0
            stz   n0+2
            jsr   StreamAt
            jsr   GetLE16               ; logical screen
            sta   TrueW
            jsr   GetLE16
            sta   TrueH
            jsr   GetByte
            sta   GifFlags
            jsr   GetByte               ; background, aspect
            jsr   GetByte
            jsr   ClearPal
            lda   GifFlags
            bit   #$0080
            beq   :noGCT
            and   #$0007
            jsr   ReadGifPal
:noGCT      jsr   NewTrue
            bcc   :start
            rts
:start      lda   #$FFFF
            sta   Transp
:blocks     jsr   GetByte
            bcs   :corrupt
            cmp   #$2C
            beq   :image
            cmp   #$21
            bne   :corrupt              ; the trailer, or junk: no picture
            jsr   GetByte               ; extension label
            cmp   #$F9
            bne   :skip
            jsr   GetByte               ; graphic control: size, flags, delay, index
            jsr   GetByte
            sta   GifFlags
            jsr   GetLE16
            jsr   GetByte
            sta   u2
            lda   GifFlags
            lsr
            bcc   :skip
            lda   u2
            sta   Transp
:skip       jsr   SkipBlocks
            bra   :blocks
:corrupt    lda   #errCorrupt
            sec
            rts

:image      jsr   GetLE16
            sta   FrX
            jsr   GetLE16
            sta   FrY
            jsr   GetLE16
            sta   FrW
            jsr   GetLE16
            sta   FrH
            jsr   GetByte
            sta   GifFlags
            bit   #$0080
            beq   :noLCT
            and   #$0007
            jsr   ReadGifPal
:noLCT      lda   GifFlags
            and   #$0040
            sta   Interlace
            lda   FrX                   ; ClipW = pixels of a row inside the canvas
            cmp   TrueW
            bcc   :inside
            stz   ClipW
            bra   :clipped
:inside     lda   TrueW
            sec
            sbc   FrX
            cmp   FrW
            bcc   :narrow
            lda   FrW
:narrow     sta   ClipW
:clipped    jsr   GetByte
            sta   MinCode
            jmp   Lzw

* SkipBlocks: skips data sub-blocks up to the empty one.
SkipBlocks  jsr   GetByte
            bcs   :done
            cmp   #0
            beq   :done
            jsr   SkipA
            bra   SkipBlocks
:done       rts

* ReadGifPal: reads a colour table of 2 << A entries.
ReadGifPal  tax
            lda   #2
:pow        cpx   #0
            beq   :count
            asl
            dex
            bra   :pow
:count      sta   u1
            asl
            clc
            adc   u1
            sta   u1                    ; bytes
            ldx   #0
:byte       phx
            jsr   GetByte
            plx
            sep   #$20
            mx    %10
            sta   Pal,x
            rep   #$20
            mx    %00
            inx
            cpx   u1
            bcc   :byte
            rts

*-------------------------------------------------------------
* LZW decoding
*-------------------------------------------------------------
Lzw         lda   MinCode
            cmp   #2
            bcc   :bad
            cmp   #12
            bcc   :ok
:bad        lda   #errCorrupt
            sec
            rts
:ok         asl
            tax
            lda   PowTab,x
            sta   Clear
            inc
            sta   EOI
            ldx   #0                    ; single-character strings
            sep   #$20
            mx    %10
:suffix     txa
            sta   Suffix,x
            inx
            cpx   Clear
            bcc   :suffix
            rep   #$20
            mx    %00
            stz   BlockLeft
            stz   BlockEnd
            stz   BitLo
            stz   BitHi
            stz   BitCnt
            stz   OX
            stz   OY
            stz   Pass
            stz   OutRow
            jsr   GifRowStart
:reset      lda   MinCode
            inc
            sta   CodeSize
            lda   Clear
            clc
            adc   #2
            sta   Avail
            lda   #$FFFF
            sta   Old
:loop       jsr   ReadCode
            cmp   Clear
            beq   :reset
            cmp   EOI
            bne   :code
            jmp   :end
:code       sta   InCode
            ldx   Old
            cpx   #$FFFF
            bne   :normal
            cmp   Clear                 ; the first code after a clear
            bcc   :first
            jmp   :end
:first      sta   Old
            sta   FirstCh
            jsr   PutGif
            bra   :loop
:normal     ldy   #0
            cmp   Avail
            bcc   :walk
            beq   :kwk
            jmp   :end                  ; damaged: keep what we have
:kwk        lda   FirstCh               ; the code being defined: old + its first
            sep   #$20
            mx    %10
            sta   Stack
            rep   #$20
            mx    %00
            ldy   #1
            lda   Old
:walk       cmp   Clear
            bcc   :root
            tax
            sep   #$20
            mx    %10
            lda   Suffix,x
            sta   Stack,y
            rep   #$20
            mx    %00
            iny
            cpy   #4096
            bcs   :end
            txa
            asl
            tax
            lda   Prefix,x
            bra   :walk
:root       sta   FirstCh
            sep   #$20
            mx    %10
            sta   Stack,y
            rep   #$20
            mx    %00
            iny
            sty   SP
            ldx   Avail                 ; new string: old + first
            cpx   #4096
            bcs   :noAdd
            sep   #$20
            mx    %10
            lda   FirstCh
            sta   Suffix,x
            rep   #$20
            mx    %00
            txa
            asl
            tax
            lda   Old
            sta   Prefix,x
            inc   Avail
            lda   CodeSize
            cmp   #12
            bcs   :noAdd
            asl
            tax
            lda   Avail
            cmp   PowTab,x
            bne   :noAdd
            inc   CodeSize
:noAdd      lda   InCode
            sta   Old
:pop        dec   SP                    ; the string, first character first
            ldx   SP
            lda   Stack,x
            and   #$00FF
            jsr   PutGif
            lda   SP
            bne   :pop
            jmp   :loop
:end        clc
            rts

* ReadCode: the next CodeSize-bit code (EOI at the end of the data).
ReadCode    lda   BitCnt
            cmp   CodeSize
            bcs   :have
            jsr   GetCodeByte
            bcs   :eoi
            sta   ShLo
            stz   ShHi
            ldx   BitCnt
            beq   :or
:sh         asl   ShLo
            rol   ShHi
            dex
            bne   :sh
:or         lda   BitLo
            ora   ShLo
            sta   BitLo
            lda   BitHi
            ora   ShHi
            sta   BitHi
            lda   BitCnt
            clc
            adc   #8
            sta   BitCnt
            bra   ReadCode
:have       lda   CodeSize
            asl
            tax
            lda   PowTab,x
            dec
            and   BitLo
            pha
            ldx   CodeSize
:drop       lsr   BitHi
            ror   BitLo
            dex
            bne   :drop
            lda   BitCnt
            sec
            sbc   CodeSize
            sta   BitCnt
            pla
            rts
:eoi        lda   EOI
            rts

* GetCodeByte: the next byte of the image data sub-blocks.
GetCodeByte lda   BlockLeft
            bne   :have
            lda   BlockEnd
            bne   :end
            jsr   GetByte
            bcs   :last
            cmp   #0
            beq   :last
            sta   BlockLeft
:have       dec   BlockLeft
            jmp   GetByte
:last       inc   BlockEnd
:end        sec
            rts

* PutGif: the next pixel of the frame is colour A.
PutGif      ldx   OY
            cpx   FrH
            bcs   :done
            cmp   Transp
            beq   :skip
            ldx   RowOK
            beq   :skip
            ldx   OX
            cpx   ClipW
            bcs   :skip
            ldy   DestOff
            jsr   PutIdx
            sty   DestOff
            bra   :step
:skip       lda   DestOff
            clc
            adc   #3
            sta   DestOff
:step       inc   OX
            lda   OX
            cmp   FrW
            bcc   :done
            stz   OX
            inc   OY
            jmp   NextRow
:done       rts

* NextRow: the frame row that comes next, in interlaced order if need be.
NextRow     lda   Interlace
            bne   :inter
            lda   OY
            sta   OutRow
            bra   GifRowStart
:inter      ldx   Pass
            lda   OutRow
            clc
            adc   IStep,x
            sta   OutRow
:check      lda   OutRow
            cmp   FrH
            bcc   GifRowStart
            ldx   Pass
            inx
            inx
            cpx   #8
            bcs   :done
            stx   Pass
            lda   IStart,x
            sta   OutRow
            bra   :check
:done       rts

* GifRowStart: points q0 and DestOff at frame row OutRow.
GifRowStart stz   RowOK
            lda   FrY
            clc
            adc   OutRow
            cmp   TrueH
            bcs   :out
            jsr   TrueRowAt
            inc   RowOK
:out        lda   FrX
            asl
            clc
            adc   FrX
            sta   DestOff
            rts

PowTab      dw    1,2,4,8,16,32,64,128,256,512,1024,2048,4096
IStart      dw    0,4,2,1
IStep       dw    8,8,4,2

GifFlags    dw    0
Transp      dw    0
FrX         dw    0
FrY         dw    0
FrW         dw    0
FrH         dw    0
ClipW       dw    0
Interlace   dw    0
MinCode     dw    0
Clear       dw    0
EOI         dw    0
CodeSize    dw    0
Avail       dw    0
Old         dw    0
InCode      dw    0
FirstCh     dw    0
SP          dw    0
BlockLeft   dw    0
BlockEnd    dw    0
BitLo       dw    0
BitHi       dw    0
BitCnt      dw    0
ShLo        dw    0
ShHi        dw    0
OX          dw    0
OY          dw    0
Pass        dw    0
OutRow      dw    0
RowOK       dw    0
DestOff     dw    0
