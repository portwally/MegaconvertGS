*-------------------------------------------------------------
* Other.s - pictures from other computers
* (a segment of its own; called from Formats.s with JSL)
*
* Atari ST: Degas, Degas Elite, Neochrome, Tiny, Spectrum 512.
* Amiga: IFF ILBM (and DeluxePaint PBM). Commodore 64: Doodle,
* Koala, Print Shop. Macintosh: MacPaint, ScreenMaker.
* PC: GEM IMG, PC Paintbrush, FliAway frames. Unix: Sun
* Rasterfile, SGI, PBM/PGM/PPM. And CompuServe RLE, IPI, QRT
* and TIFF (OtherPC.s).
*
* As in GS Remap, black & white pictures taller than a screen
* (Atari ST high resolution, MacPaint, ScreenMaker) become true
* colour pictures, so they can be fitted to the screen.
*-------------------------------------------------------------
            rel
            mx    %00
            use   macros/Macs.s
            put   Equates.s

NewTrueL    ext

* DecodeOther: A = format to read (0: recognise it).
*   out: carry clear and A = format, or carry set and A = error (0: not one of these)
DecodeOther ent
            phb
            phk
            plb
            stz   pw                    ; (PackRow notes the picture's size)
            stz   ph
            stz   p640
            sta   Want
            jsr   ODetect
            bcs   :out
            sta   Found
            sec
            sbc   #fmtDegas
            asl
            tax
            jsr   (OLoaders,x)
            bcs   :out
            lda   Found
:out        plb
            rtl

OLoaders    da    LoadDegas,LoadDegasE,LoadNeo,LoadTiny,LoadSPU,LoadSPC,LoadIFF
            da    LoadDoodle,LoadKoala,LoadC64PS,LoadMac640,LoadMac320,LoadMacMono
            da    LoadMacSM,LoadGEM,LoadPCX,LoadFli,LoadSun,LoadSGI,LoadPNM,LoadRLE
            da    LoadIPI,LoadQRT,LoadTIFF

*-------------------------------------------------------------
* Recognising a file: by its signature, then its name, then its size
*-------------------------------------------------------------
ODetect     lda   Want
            beq   :auto
            clc
            rts
:auto       lda   flen+2                ; at least 16 bytes
            bne   :sig
            lda   flen
            cmp   #16
            bcs   :sig
            jmp   :none
:sig        lda   [fp]                  ; signatures
            ldy   #2
            ldx   #0
:sigs       lda   [fp]
            cmp   SigA,x
            bne   :nextSig
            lda   SigB,x
            beq   :sigHit
            lda   [fp],y
            cmp   SigB,x
            beq   :sigHit
:nextSig    inx
            inx
            cpx   #SigB-SigA
            bcc   :sigs
            bra   :special
:sigHit     lda   SigFmt,x
            cmp   #fmtIFF               ; IFF: the form must hold a picture
            bne   :sigOK
            ldy   #8
            lda   [fp],y
            cmp   #$4C49                ; "IL"
            beq   :sigOK
            cmp   #$4250                ; "PB"
            bne   :special
:sigOK      lda   SigFmt,x              ; (A held the form type)
            clc
            rts
:special    lda   [fp]                  ; PBM, PGM, PPM: "P1" to "P6", then a space
            and   #$00FF
            cmp   #'P'
            bne   :pcx
            lda   [fp]
            xba
            and   #$00FF
            cmp   #'1'
            bcc   :pcx
            cmp   #'7'
            bcs   :pcx
            ldy   #2
            lda   [fp],y
            and   #$00FF
            cmp   #$21
            bcs   :pcx
            lda   #fmtPNM
            clc
            rts
:pcx        lda   [fp]                  ; PC Paintbrush: 10, version, 0 or 1, bits
            and   #$00FF
            cmp   #10
            bne   :name
            ldy   #2
            lda   [fp],y
            and   #$00FF
            cmp   #2
            bcs   :name
            lda   [fp],y
            xba
            and   #$00FF
            beq   :name
            cmp   #9
            bcs   :name
            lda   #fmtPCX
            clc
            rts
:name       jsr   GetExt                ; by the name's ending
            ldx   #0
:ext        lda   ExtList,x
            beq   :size
            cmp   Ext
            bne   :nextExt
            lda   ExtList+2,x
            cmp   Ext+2
            bne   :nextExt
            lda   ExtList+4,x
            clc
            rts
:nextExt    txa
            clc
            adc   #6
            tax
            bra   :ext
:size       lda   flen+2                ; by size
            bne   :none
            lda   flen
            ldx   #0
:sizes      cmp   SizeList,x
            beq   :sizeHit
            inx
            inx
            inx
            inx
            cpx   #SizeEnd-SizeList
            bcc   :sizes
:none       lda   #0
            sec
            rts
:sizeHit    lda   SizeList+2,x
            clc
            rts

* Signatures: the first word, the second word (0: any), the format.
SigA        dw    $4F46,$A659,$DA01,$4949,$4D4D
SigB        dw    $4D52,$956A,0,$002A,$2A00
SigFmt      dw    fmtIFF,fmtSun,fmtSGI,fmtTIFF,fmtTIFF

* Name endings (up to 4 characters, upper case, after the last dot).
ExtList     asc   'PI1',00
            dw    fmtDegas
            asc   'PI2',00
            dw    fmtDegas
            asc   'PI3',00
            dw    fmtDegas
            asc   'PC1',00
            dw    fmtDegasE
            asc   'PC2',00
            dw    fmtDegasE
            asc   'PC3',00
            dw    fmtDegasE
            asc   'NEO',00
            dw    fmtNeo
            asc   'TNY',00
            dw    fmtTiny
            asc   'TN1',00
            dw    fmtTiny
            asc   'TN2',00
            dw    fmtTiny
            asc   'TN3',00
            dw    fmtTiny
            asc   'SPU',00
            dw    fmtSPU
            asc   'SPC',00
            dw    fmtSPC
            asc   'KOA',00
            dw    fmtKoala
            asc   'KLA',00
            dw    fmtKoala
            asc   'MAC',00
            dw    fmtMacMono
            asc   'PNTG'
            dw    fmtMacMono
            asc   'IMG',00
            dw    fmtGEM
            asc   'GEM',00
            dw    fmtGEM
            asc   'PCC',00
            dw    fmtPCX
            asc   'RLE',00
            dw    fmtRLE
            asc   'QRT',00
            dw    fmtQRT
            dw    0

SizeList    dw    32034,fmtDegas
            dw    32066,fmtDegas
            dw    32128,fmtNeo
            dw    51104,fmtSPU
            dw    10003,fmtKoala
            dw    9218,fmtDoodle
SizeEnd

* GetExt: Ext = the end of the name after its last dot, in capitals.
GetExt      stz   Ext
            stz   Ext+2
            lda   [pathp]               ; the path's length
            beq   :done
            clc
            adc   #1                    ; index of its last character
            tay
            ldx   #0
:back       lda   [pathp],y
            and   #$00FF
            cmp   #'.'
            beq   :dot
            cmp   #':'
            beq   :done
            cmp   #'/'
            beq   :done
            inx
            cpx   #5
            bcs   :done
            dey
            cpy   #2
            bcs   :back
            bra   :done
:dot        ldx   #0
:copy       iny
            cpx   #4
            bcs   :done
            tya                         ; past the end? (index - 1 > length)
            dec
            cmp   [pathp]
            beq   :last
            bcs   :done
:last       lda   [pathp],y
            and   #$00FF
            cmp   #'a'
            bcc   :upper
            cmp   #'z'+1
            bcs   :upper
            sbc   #$1F                  ; (carry clear: - $20)
:upper      sep   #$20
            mx    %10
            sta   Ext,x
            rep   #$20
            mx    %00
            inx
            bra   :copy
:done       rts

*-------------------------------------------------------------
* Atari ST
*-------------------------------------------------------------

* STRead16: STWords = 16 palette words from offset A.
STRead16    jsr   SAtA
            ldx   #0
:w          jsr   SBE16
            sta   STWords,x
            inx
            inx
            cpx   #32
            bcc   :w
            rts

* STConv: the first X words of STWords as IIgs colours (Tab12), and as
* 8-bit red, green and blue (TabR, TabG, TabB). Plain ST colours have 3
* bits a channel; STE ones a fourth, lowest bit in bit 3 of each nibble.
STConv      stx   t3
            stz   STEnh
            ldx   #0
:any        lda   STWords,x
            and   #$0888
            beq   :n
            inc   STEnh
:n          inx
            inx
            cpx   t3
            bcc   :any
            ldx   #0
:word       lda   STWords,x
            xba
            jsr   :chan
            sta   TabR,x
            asl
            asl
            asl
            asl
            asl
            asl
            asl
            asl
            sta   t2                    ; 12-bit colour, red so far
            lda   STWords,x
            lsr
            lsr
            lsr
            lsr
            jsr   :chan
            sta   TabG,x
            asl
            asl
            asl
            asl
            ora   t2
            sta   t2
            lda   STWords,x
            jsr   :chan
            sta   TabB,x
            ora   t2
            sta   Tab12,x
            lda   TabR,x                ; 8 bits a channel
            jsr   Times17
            sta   TabR,x
            lda   TabG,x
            jsr   Times17
            sta   TabG,x
            lda   TabB,x
            jsr   Times17
            sta   TabB,x
            inx
            inx
            cpx   t3
            bcc   :word
            rts
:chan       sta   t1                    ; one channel (low nibble of A) to 4 bits
            and   #$0007
            asl
            sta   t0
            lda   STEnh
            beq   :plain
            lda   t1
            lsr
            lsr
            lsr
            and   #$0001
            ora   t0
            rts
:plain      lda   t1
            and   #$0007
            lsr
            lsr
            ora   t0
            rts

* STScreen: 32000 bytes of ST screen memory at q1 in resolution STRes.
STScreen    lda   STRes
            beq   :low
            cmp   #1
            beq   :medium
            jmp   STHigh
:low        jsr   ScrBegin
            ldx   #32
            jsr   STConv
            ldx   #Tab12
            jsr   SetTable0
            stz   Is640
            lda   #320
            sta   PixW
            stz   RowY
:lrow       lda   RowY                  ; line start = y * 160
            jsr   Times160
            jsr   STRow0
            jsr   PackRow
            inc   RowY
            lda   RowY
            cmp   #200
            bcc   :lrow
            clc
            rts
:medium     jsr   ScrBegin
            ldx   #32                   ; (all 16 decide plain or STE colours)
            jsr   STConv
            ldx   #0                    ; the four colours, four times over
:four       txa
            and   #$0007
            tay
            lda   Tab12,y
            sta   Tab4,x
            inx
            inx
            cpx   #32
            bcc   :four
            ldx   #Tab4
            jsr   SetTable0
            lda   #$80
            ldx   #200
            jsr   SetScbs
            lda   #1
            sta   Is640
            lda   #640
            sta   PixW
            stz   RowY
:mrow       lda   RowY
            jsr   Times160
            tay
            ldx   #0                    ; 40 groups of 16 pixels in 2 planes
:mgroup     lda   [q1],y
            xba
            sta   W0
            iny
            iny
            lda   [q1],y
            xba
            sta   W1
            iny
            iny
            phy
            ldy   #16
:mpix       lda   #0
            asl   W1
            rol
            asl   W0
            rol
            sep   #$20
            mx    %10
            sta   RowPix,x
            rep   #$20
            mx    %00
            inx
            dey
            bne   :mpix
            ply
            cpx   #640
            bcc   :mgroup
            jsr   PackRow
            inc   RowY
            lda   RowY
            cmp   #200
            bcc   :mrow
            clc
            rts

Times160    asl
            asl
            asl
            asl
            asl
            sta   t0
            asl
            asl
            clc
            adc   t0
            rts

* STRow0: RowPix = one low resolution line (4 planes) from [q1] at offset A.
STRow0      tay
            ldx   #0
:group      lda   [q1],y
            xba
            sta   W0
            iny
            iny
            lda   [q1],y
            xba
            sta   W1
            iny
            iny
            lda   [q1],y
            xba
            sta   W2
            iny
            iny
            lda   [q1],y
            xba
            sta   W3
            iny
            iny
            phy
            ldy   #16
:pix        lda   #0
            asl   W3
            rol
            asl   W2
            rol
            asl   W1
            rol
            asl   W0
            rol
            sep   #$20
            mx    %10
            sta   RowPix,x
            rep   #$20
            mx    %00
            inx
            dey
            bne   :pix
            ply
            cpx   #320
            bcc   :group
            rts

* STHigh: 640 x 400 black & white, as a true colour picture.
STHigh      lda   STWords               ; colour 0 is normally white: a set bit is ink
            and   #$0001
            sta   STInk
            lda   #640
            ldx   #400
            stz   ttall
            jsr   MakeTrue
            bcc   :rows
            rts
:rows       stz   RowY
:row        lda   RowY
            jsr   TrueRow
            lda   RowY                  ; y * 80
            asl
            asl
            asl
            asl
            sta   t0
            asl
            asl
            clc
            adc   t0
            sta   u0
            ldy   #0
            stz   u1                    ; byte in the line
:byte       phy
            lda   u0
            clc
            adc   u1
            tay
            lda   [q1],y
            ply
            and   #$00FF                ; the byte at the top, to shift out
            xba
            sta   t2
            ldx   #8
:bit        lda   #0
            asl   t2
            bit   #$0000                ; (keeps the carry)
            rol                         ; 1 = set
            eor   STInk                 ; set and ink black: 0 (black)
            beq   :black
            lda   #255
            bra   :put
:black      lda   #0
:put        jsr   PutGrey
            dex
            bne   :bit
            inc   u1
            lda   u1
            cmp   #80
            bcc   :byte
            inc   RowY
            lda   RowY
            cmp   #400
            bcc   :row
            clc
            rts

* Degas .PI1, .PI2, .PI3: resolution, 16 colours, screen memory.
LoadDegas   lda   #32034
            jsr   NeedLen
            bcc   :ok
            rts
:ok         lda   #0
            jsr   STResAt
            bcs   :bad
            lda   #2
            jsr   STRead16
            lda   fp
            clc
            adc   #34
            sta   q1
            lda   fp+2
            adc   #0
            sta   q1+2
            jmp   STScreen
:bad        lda   #errNotPicture
            sec
            rts

* STResAt: STRes = the resolution word at offset A (carry set if not 0-2).
STResAt     jsr   SAtA
            jsr   SBE16
            and   #$0003
            sta   STRes
            cmp   #3
            rts

* Neochrome .NEO
LoadNeo     lda   #32128
            jsr   NeedLen
            bcc   :ok
            rts
:ok         lda   #2
            jsr   STResAt
            bcs   :bad
            lda   #4
            jsr   STRead16
            lda   fp
            clc
            adc   #128
            sta   q1
            lda   fp+2
            adc   #0
            sta   q1+2
            jmp   STScreen
:bad        lda   #errNotPicture
            sec
            rts

* Degas Elite .PC1, .PC2, .PC3: each line packed (PackBits) plane by plane.
LoadDegasE  lda   #35
            jsr   NeedLen
            bcc   :ok
            rts
:ok         lda   #0
            jsr   STResAt
            bcc   :resOK
            lda   #errNotPicture
            sec
            rts
:resOK      lda   #2
            jsr   STRead16
            lda   #32000
            jsr   NewOut
            bcc   :buf
            rts
:buf        lda   STRes                 ; planes, lines, bytes a line and a plane
            asl
            tax
            lda   EPlanes,x
            and   #$00FF
            sta   EP
            lda   #160
            sta   ELine
            lda   #200
            sta   ELines
            lda   STRes
            cmp   #2
            bne   :lo
            lda   #80
            sta   ELine
            lda   #400
            sta   ELines
:lo         lda   ELine
            ldx   EP
            jsr   Div16
            sta   EPB
            lda   #34
            jsr   SAtA
            jsr   PBStart
            stz   RowY
:line       lda   RowY                  ; the line's start in memory
            ldx   ELine
            jsr   Mul16
            lda   MLo
            sta   u0
            stz   u1                    ; plane
:plane      stz   u2                    ; byte in the plane
:byte       jsr   PBGet
            pha
            lda   u2                    ; (i / 2) * planes * 2 + plane * 2 + (i & 1)
            lsr
            ldx   EP
            jsr   Mul16
            lda   MLo
            asl
            sta   t1
            lda   u1
            asl
            clc
            adc   t1
            sta   t1
            lda   u2
            and   #$0001
            clc
            adc   t1
            clc
            adc   u0
            tay
            pla
            sep   #$20
            mx    %10
            sta   [OutDP],y
            rep   #$20
            mx    %00
            inc   u2
            lda   u2
            cmp   EPB
            bcc   :byte
            inc   u1
            lda   u1
            cmp   EP
            bcc   :plane
            inc   RowY
            lda   RowY
            cmp   ELines
            bcc   :line
            lda   OutP
            sta   q1
            lda   OutP+2
            sta   q1+2
            jsr   STScreen
            php
            pha
            jsr   FreeOut
            pla
            plp
            rts

EPlanes     db    4,0,2,0,1,0

* Tiny .TNY: words packed with control bytes, column by column in each plane.
LoadTiny    lda   #38
            jsr   NeedLen
            bcc   :ok
            rts
:ok         lda   [fp]
            and   #$00FF
            sta   STRes
            lda   #1                    ; palette offset
            sta   u0
            lda   STRes
            cmp   #3
            bcc   :res
            sbc   #3
            sta   STRes
            lda   #5
            sta   u0
:res        lda   STRes
            cmp   #3
            bcs   :bad
            lda   u0
            clc
            adc   #36
            jsr   NeedLen
            bcs   :bad
            lda   u0
            jsr   STRead16
            lda   u0                    ; control bytes, then the data words
            clc
            adc   #32
            jsr   SAtA
            jsr   SBE16
            sta   u1                    ; number of control bytes
            lda   u0
            clc
            adc   #36
            sta   TCtl
            clc
            adc   u1
            sta   TCtlEnd
            sta   n0
            stz   n0+2
            jsr   SAt                   ; the stream reads the data words
            lda   #32000
            jsr   NewOut
            bcc   :buf
            rts
:bad        lda   #errNotPicture
            sec
            rts
:buf        stz   TRow
            stz   TCol
            stz   TPlane
:control    lda   TPlane                ; all 16000 words?
            cmp   #4
            bcs   :done
            lda   TCtl
            cmp   TCtlEnd
            bcs   :done
            jsr   CtlByte
            cmp   #$80
            bcs   :copy
            cmp   #2
            bcs   :repeat
            sta   t2                    ; 0 or 1: a 16-bit count follows
            lda   TCtl
            inc
            cmp   flen
            bcs   :done
            jsr   CtlByte
            xba
            sta   t1
            jsr   CtlByte
            ora   t1
            sta   u2
            lda   t2
            beq   :repWord
            bra   :copyN
:copy       eor   #$00FF                ; negative: that many words as they are
            inc
            sta   u2
:copyN      lda   u2
            beq   :control
:cw         jsr   SBE16
            jsr   PutTiny
            dec   u2
            bne   :cw
            bra   :control
:repeat     sta   u2                    ; 2-127: the next word that many times
:repWord    jsr   SBE16
            sta   t3
            lda   u2
            beq   :control
:rw         lda   t3
            jsr   PutTiny
            dec   u2
            bne   :rw
            bra   :control
:done       lda   OutP
            sta   q1
            lda   OutP+2
            sta   q1+2
            jsr   STScreen
            php
            pha
            jsr   FreeOut
            pla
            plp
            rts

CtlByte     ldy   TCtl
            lda   [fp],y
            and   #$00FF
            inc   TCtl
            rts

* PutTiny: the next word of screen memory (row, then column, then plane).
PutTiny     ldx   TPlane
            cpx   #4
            bcs   :full
            xba                         ; stored high byte first
            pha
            lda   TRow
            jsr   Times160
            sta   t1
            lda   TCol
            asl
            asl
            asl
            clc
            adc   t1
            sta   t1
            lda   TPlane
            asl
            clc
            adc   t1
            tay
            pla
            sta   [OutDP],y
            inc   TRow
            lda   TRow
            cmp   #200
            bcc   :full
            stz   TRow
            inc   TCol
            lda   TCol
            cmp   #20
            bcc   :full
            stz   TCol
            inc   TPlane
:full       rts

* Spectrum 512 .SPU: low resolution memory, then 199 lines of 48 colours
* (three palettes, each taking over at its own place across the line).
LoadSPU     lda   #51104
            jsr   NeedLen
            bcc   :ok
            rts
:ok         lda   fp
            sta   q1
            lda   fp+2
            sta   q1+2
            stz   SpcMode
            jmp   Spectrum

* Spectrum 512 compressed .SPC: "SP", packed planes, then palettes with masks.
LoadSPC     lda   #51000
            jsr   NewOut
            bcc   :buf
            rts
:buf        lda   #4
            jsr   SAtA
            jsr   SBE32
            lda   n1                    ; bitmap bytes
            sta   u3
            lda   n1+2
            bne   :bad
            lda   u3
            clc
            adc   #12
            bcs   :bad
            sta   u2                    ; where the palettes start
            jsr   Within
            bcs   :bad
            lda   #12                   ; the planes: 4 x 199 lines x 40 bytes
            jsr   SAtA
            ldy   #0
:ctl        cpy   #31840
            bcs   :pals
            jsr   SPos
            lda   n0
            cmp   u2
            bcs   :pals
            jsr   SByte
            cmp   #$80
            bcs   :run
            inc                         ; n + 1 bytes
            tax
:lit        jsr   SByte
            jsr   :put
            dex
            bne   :lit
            bra   :ctl
:run        eor   #$00FF                ; 2 - n repeats
            clc
            adc   #3
            tax
            jsr   SByte
:rep        jsr   :put
            dex
            bne   :rep
            bra   :ctl
:bad        jsr   FreeOut
            lda   #errNotPicture
            sec
            rts
:put        cpy   #31840
            bcs   :putDone
            sep   #$20
            mx    %10
            sta   [OutDP],y
            rep   #$20
            mx    %00
            iny
:putDone    rts
:pals       lda   u2                    ; 597 masks, each with up to 16 colours
            jsr   SAtA
            ldy   #31840
            lda   #597
            sta   u1
:mask       jsr   SBE16
            sta   t1
            ldx   #16
:bit        lsr   t1
            lda   #0
            bcc   :store
            jsr   SBE16
:store      sta   [OutDP],y
            iny
            iny
            dex
            bne   :bit
            dec   u1
            bne   :mask
            lda   #1
            sta   SpcMode
            jsr   Spectrum
            php
            pha
            jsr   FreeOut
            pla
            plp
            rts

* Spectrum: the true colour picture; line 0 stays black.
Spectrum    lda   #320
            ldx   #200
            stz   ttall
            jsr   MakeTrue
            bcc   :start
            rts
:start      lda   #1
            sta   RowY
:line       ldx   #0                    ; the line's 48 colours
            lda   RowY
            dec
            sta   t1
            asl
            clc
            adc   t1                    ; (line - 1) * 3
            asl
            asl
            asl
            asl
            asl                         ; * 32 = (line - 1) * 96
            sta   u0
            lda   SpcMode
            bne   :fromBuf
            lda   u0
            clc
            adc   #32000
            jsr   SAtA
:fileW      jsr   SBE16
            sta   STWords,x
            inx
            inx
            cpx   #96
            bcc   :fileW
            bra   :conv
:fromBuf    lda   u0
            clc
            adc   #31840
            tay
:bufW       lda   [OutDP],y
            sta   STWords,x
            iny
            iny
            inx
            inx
            cpx   #96
            bcc   :bufW
:conv       ldx   #96
            jsr   STConv
            lda   SpcMode               ; the line's pixels
            bne   :planes
            lda   RowY
            jsr   Times160
            jsr   STRow0
            bra   :draw
:planes     jsr   SpcRow
:draw       lda   RowY
            jsr   TrueRow
            ldy   #0
            ldx   #0
:pix        lda   RowPix,x              ; which of the three palettes
            and   #$00FF
            sta   t1
            asl
            asl
            clc
            adc   t1
            asl                         ; 10 c
            sta   t2
            lda   t1
            lsr
            bcc   :even
            lda   t2
            sec
            sbc   #5
            bra   :start2
:even       lda   t2
            inc
:start2     sta   t2                    ; start
            txa
            cmp   t2
            bcc   :first
            sec
            sbc   t2
            cmp   #160
            bcs   :third
            lda   t1                    ; second palette
            clc
            adc   #16
            bra   :entry
:third      lda   t1
            clc
            adc   #32
            bra   :entry
:first      lda   t1
:entry      asl
            phx
            tax
            lda   TabR,x
            sta   CR
            lda   TabG,x
            sta   CG
            lda   TabB,x
            sta   CB
            plx
            jsr   PutRGB
            inx
            cpx   #320
            bcc   :pix
            inc   RowY
            lda   RowY
            cmp   #200
            bcs   :done
            jmp   :line
:done       clc
            rts

* SpcRow: RowPix for line RowY from the unpacked planes (plane p at p * 7960).
SpcRow      lda   RowY
            dec
            asl
            asl
            asl
            sta   t1
            asl
            asl
            clc
            adc   t1                    ; (line - 1) * 40
            sta   u1
            ldx   #0
:byte       txa
            lsr
            lsr
            lsr
            clc
            adc   u1
            tay
            lda   [OutDP],y
            sta   W0
            tya
            clc
            adc   #7960
            tay
            lda   [OutDP],y
            sta   W1
            tya
            clc
            adc   #7960
            tay
            lda   [OutDP],y
            sta   W2
            tya
            clc
            adc   #7960
            tay
            lda   [OutDP],y
            sta   W3
            ldy   #8
:bit        lda   W3                    ; top bit of each plane's byte
            and   #$0080
            asl
            asl
            sta   t2
            lda   W2
            and   #$0080
            asl
            ora   t2
            sta   t2
            lda   W1
            and   #$0080
            ora   t2
            sta   t2
            lda   W0
            and   #$0080
            lsr
            ora   t2
            lsr
            lsr
            lsr
            lsr
            lsr
            lsr
            sep   #$20
            mx    %10
            sta   RowPix,x
            rep   #$20
            mx    %00
            asl   W0
            asl   W1
            asl   W2
            asl   W3
            inx
            dey
            bne   :bit
            cpx   #320
            bcc   :byte
            rts

*-------------------------------------------------------------
* Commodore 64
*-------------------------------------------------------------

* Doodle: load address, 1000 colour bytes, 24 unused, 8000 bitmap bytes.
LoadDoodle  lda   #9026
            jsr   NeedLen
            bcc   :ok
            rts
:ok         lda   #1026
            sta   HBase
            lda   #9026
            sta   HEnd
            stz   HFixed
            jmp   C64Hires

* Print Shop screen: load address, then a bitmap shown white on black.
LoadC64PS   lda   #8000
            jsr   NeedLen
            bcc   :ok
            rts
:ok         lda   #2
            sta   HBase
            lda   #8002
            ldx   flen+2
            bne   :end
            cmp   flen
            bcc   :end
            lda   flen
:end        sta   HEnd
            lda   #$10
            sta   HFixed
            jmp   C64Hires

* C64Hires: bitmap at HBase (up to HEnd); each 8 x 8 cell has an ink (high
* nibble) and paper (low nibble) colour: HFixed, or the byte at 2 + cell.
C64Hires    jsr   ScrBegin
            ldx   #C64Pal
            jsr   SetTable0
            stz   Is640
            lda   #320
            sta   PixW
            stz   RowY
:row        ldx   #0
:pix        lda   RowY                  ; cell = (y >> 3) * 40 + (x >> 3)
            lsr
            lsr
            lsr
            sta   t1
            asl
            asl
            clc
            adc   t1
            asl
            asl
            asl
            sta   t1
            txa
            lsr
            lsr
            lsr
            clc
            adc   t1
            sta   t2                    ; cell
            lda   HFixed                ; its colours
            bne   :colour
            lda   t2
            clc
            adc   #2
            tay
            lda   [fp],y
            and   #$00FF
:colour     sta   t3
            lda   t2                    ; bitmap byte = base + cell * 8 + (y & 7)
            asl
            asl
            asl
            clc
            adc   HBase
            sta   t1
            lda   RowY
            and   #$0007
            clc
            adc   t1
            cmp   HEnd
            bcs   :paper
            tay
            lda   [fp],y
            sta   t1
            txa
            and   #$0007
            tay
            lda   t1
:shift      cpy   #0
            beq   :test
            asl
            dey
            bra   :shift
:test       and   #$0080
            beq   :paper
            lda   t3                    ; ink
            lsr
            lsr
            lsr
            lsr
            bra   :set
:paper      lda   t3
:set        and   #$000F
            sep   #$20
            mx    %10
            sta   RowPix,x
            rep   #$20
            mx    %00
            inx
            cpx   #320
            bcc   :pix
            jsr   PackRow
            inc   RowY
            lda   RowY
            cmp   #200
            bcs   :done
            jmp   :row
:done       clc
            rts

* Koala: load address, 8000 bitmap, 1000 screen, 1000 colour memory, background.
* 160 double-wide pixels a line, four colour choices per 4 x 8 cell.
LoadKoala   lda   #10003
            jsr   NeedLen
            bcc   :ok
            rts
:ok         jsr   ScrBegin
            ldx   #C64Pal
            jsr   SetTable0
            stz   Is640
            lda   #320
            sta   PixW
            ldy   #10002
            lda   [fp],y
            and   #$000F
            sta   KBack
            stz   RowY
:row        ldx   #0                    ; X = wide pixel
:pix        lda   RowY                  ; cell = (y >> 3) * 40 + (x >> 2)
            lsr
            lsr
            lsr
            sta   t1
            asl
            asl
            clc
            adc   t1
            asl
            asl
            asl
            sta   t1
            txa
            lsr
            lsr
            clc
            adc   t1
            sta   t2
            asl                         ; bitmap byte: 2 + cell * 8 + (y & 7)
            asl
            asl
            sta   t1
            lda   RowY
            and   #$0007
            clc
            adc   t1
            inc
            inc
            tay
            lda   [fp],y
            sta   t1
            txa                         ; the pair: bits 7-6 for x & 3 = 0
            and   #$0003
            eor   #$0003
            asl
            tay
            lda   t1
:sh         cpy   #0
            beq   :pair
            lsr
            dey
            bra   :sh
:pair       and   #$0003
            beq   :back
            cmp   #3
            beq   :colRam
            pha
            lda   t2
            clc
            adc   #8002
            tay
            lda   [fp],y
            sta   t1
            pla
            cmp   #1
            bne   :low
            lda   t1                    ; 1: screen high nibble
            lsr
            lsr
            lsr
            lsr
            bra   :set
:low        lda   t1                    ; 2: screen low nibble
            bra   :set
:colRam     lda   t2                    ; 3: colour memory
            clc
            adc   #9002
            tay
            lda   [fp],y
            bra   :set
:back       lda   KBack
:set        and   #$000F
            sta   t1
            xba
            ora   t1
            pha
            txa
            asl
            tay
            pla
            sta   RowPix,y              ; two pixels
            inx
            cpx   #160
            bcs   :pack
            jmp   :pix
:pack       jsr   PackRow
            inc   RowY
            lda   RowY
            cmp   #200
            bcs   :done
            jmp   :row
:done       clc
            rts

*-------------------------------------------------------------
* Macintosh
*-------------------------------------------------------------

* MacStart: A = where the data fork starts (128 inside a MacBinary file).
MacStart    lda   flen+2
            bne   :check
            lda   flen
            cmp   #129
            bcc   :none
:check      lda   [fp]                  ; byte 0 = 0, name length 1-63
            and   #$00FF
            bne   :none
            lda   [fp]
            xba
            and   #$00FF
            beq   :none
            cmp   #64
            bcs   :none
            ldy   #74
            lda   [fp],y
            and   #$00FF
            bne   :none
            ldy   #82
            lda   [fp],y
            and   #$00FF
            bne   :none
            lda   #83                   ; data fork length: > 0, and in the file
            jsr   SAtA
            jsr   SBE32
            lda   n1
            ora   n1+2
            beq   :none
            lda   flen                  ; length <= file length - 1
            sec
            sbc   #1
            tax
            lda   flen+2
            sbc   #0
            cmp   n1+2
            bne   :cmp
            cpx   n1
:cmp        bcc   :none
            lda   #128
            rts
:none       lda   #0
            rts

* MacRowsStart: the stream at the first packed row of a MacPaint file.
MacRowsStart jsr  MacStart
            clc
            adc   #512
            jsr   Within
            bcs   :bad
            jsr   SAtA
            clc
            rts
:bad        lda   #errNotPicture
            sec
            rts

* MacRow: the next row (72 bytes, PackBits) into MacBuf (X = offset there).
MacRow      jsr   PBStart
            ldy   #72
:b          phy
            jsr   PBGet
            sep   #$20
            mx    %10
            sta   MacBuf,x
            rep   #$20
            mx    %00
            ply
            inx
            dey
            bne   :b
            jmp   PBEnd

* MacPaint as 320 mode black & white (the top left screenful).
LoadMac320  jsr   MacRowsStart
            bcc   :ok
            rts
:ok         jsr   ScrBegin
            ldx   #Std320
            jsr   SetTable0
            stz   Is640
            lda   #576
            sta   PixW
            stz   RowY
:row        ldx   #0
            jsr   MacRow
            ldx   #0
:pix        jsr   MacBit
            beq   :white
            lda   #0
            bra   :set
:white      lda   #15
:set        sep   #$20
            mx    %10
            sta   RowPix,x
            rep   #$20
            mx    %00
            inx
            cpx   #576
            bcc   :pix
            jsr   PackRow
            inc   RowY
            lda   RowY
            cmp   #200
            bcc   :row
            clc
            rts

* MacBit: the dot X of the row in MacBuf (A nonzero = ink). Keeps X.
MacBit      txa
            lsr
            lsr
            lsr
            tay
            lda   MacBuf,y
            sta   t1
            txa
            and   #$0007
            tay
            lda   BitMasks,y
            and   t1
            and   #$00FF
            rts

* MacBit2: the same in the second row (MacBuf + 72).
MacBit2     txa
            lsr
            lsr
            lsr
            tay
            lda   MacBuf+72,y
            sta   t1
            txa
            and   #$0007
            tay
            lda   BitMasks,y
            and   t1
            and   #$00FF
            rts

* MacPaint as 640 mode greys: each pair of lines becomes one line.
LoadMac640  jsr   MacRowsStart
            bcc   :ok
            rts
:ok         jsr   ScrBegin
            ldx   #MacGrey
            jsr   SetTable0
            lda   #$80
            ldx   #200
            jsr   SetScbs
            lda   #1
            sta   Is640
            lda   #576
            sta   PixW
            stz   RowY
:row        ldx   #0
            jsr   MacRow
            ldx   #72
            jsr   MacRow
            ldx   #0
:pix        stz   t2                    ; ink in the two lines
            jsr   MacBit
            beq   :b
            inc   t2
:b          jsr   MacBit2
            beq   :c
            inc   t2
:c          lda   t2
            beq   :white
            cmp   #2
            beq   :black
            txa                         ; half: a checkerboard of the two middle greys
            clc
            adc   RowY
            and   #$0001
            inc
            bra   :set
:white      lda   #3
            bra   :set
:black      lda   #0
:set        sep   #$20
            mx    %10
            sta   RowPix,x
            rep   #$20
            mx    %00
            inx
            cpx   #576
            bcc   :pix
            jsr   PackRow
            inc   RowY
            lda   RowY
            cmp   #200
            bcc   :row
            clc
            rts

* MacPaint as a black & white picture, 576 x 720 (a true colour one).
LoadMacMono jsr   MacRowsStart
            bcc   :ok
            rts
:ok         lda   #576
            ldx   #720
            stz   ttall
            jsr   MakeTrue
            bcc   :rows
            rts
:rows       stz   RowY
:row        ldx   #0
            jsr   MacRow
            lda   RowY
            jsr   TrueRow
            ldy   #0
            ldx   #0
:pix        phy
            jsr   MacBit
            ply
            cmp   #0
            beq   :white
            lda   #0
            bra   :put
:white      lda   #255
:put        jsr   PutGrey
            inx
            cpx   #576
            bcc   :pix
            inc   RowY
            lda   RowY
            cmp   #720
            bcc   :row
            clc
            rts

* ScreenMaker startup screen: a 512 x 342 bitmap, 64 bytes a line.
LoadMacSM   jsr   MacStart
            sta   u0
            lda   flen                  ; 21888 bytes from there on
            sec
            sbc   u0
            tax
            lda   flen+2
            sbc   #0
            bne   :ok
            cpx   #21888
            bcs   :ok
            lda   #errNotPicture
            sec
            rts
:ok         lda   #512
            ldx   #342
            stz   ttall
            jsr   MakeTrue
            bcc   :rows
            rts
:rows       stz   RowY
:row        lda   RowY
            jsr   TrueRow
            lda   RowY                  ; the line: start + y * 64
            asl
            asl
            asl
            asl
            asl
            asl
            clc
            adc   u0
            sta   u1
            ldy   #0
            ldx   #0
:pix        phy
            txa
            lsr
            lsr
            lsr
            clc
            adc   u1
            tay
            lda   [fp],y
            sta   t1
            txa
            and   #$0007
            tay
            lda   BitMasks,y
            and   t1
            and   #$00FF
            ply
            cmp   #0
            beq   :white
            lda   #0
            bra   :put
:white      lda   #255
:put        jsr   PutGrey
            inx
            cpx   #512
            bcc   :pix
            inc   RowY
            lda   RowY
            cmp   #342
            bcc   :row
            clc
            rts

*-------------------------------------------------------------
* CompuServe RLE: ESC G, then H (256 x 192) or M (128 x 96), then
* characters whose value - 32 is a run, alternately black and white.
*-------------------------------------------------------------
LoadRLE     lda   #0
            jsr   SAtA
            stz   t2                    ; the byte before
:find       jsr   SByte
            bcc   :jx4
            jmp   :bad
:jx4
            and   #$007F
            ldx   t2
            sta   t2
            cpx   #$1B
            bne   :find
            cmp   #'G'
            bne   :find
            jsr   SByte                 ; H or M
            and   #$007F
            ldx   #128
            ldy   #96
            cmp   #'H'
            bne   :size
            ldx   #256
            ldy   #192
:size       stx   PixW
            sty   RLEH
            jsr   ScrBegin
            ldx   #Std320
            jsr   SetTable0
            stz   Is640
            stz   RowY
            stz   RLEX
            stz   RLEColour
            lda   #0
            jsr   ClearRow
:char       jsr   SByte
            bcs   :end
            and   #$007F
            cmp   #$1B                  ; the end
            beq   :end
            cmp   #$20
            bcc   :char                 ; line breaks
            sec
            sbc   #32
            tax
            beq   :flip
:run        phx
            ldx   RLEX
            lda   RLEColour
            sep   #$20
            mx    %10
            sta   RowPix,x
            rep   #$20
            mx    %00
            inx
            stx   RLEX
            cpx   PixW
            bcc   :next
            jsr   PackRow               ; a full line
            stz   RLEX
            lda   #0
            jsr   ClearRow
            inc   RowY
            lda   RowY
            cmp   RLEH
            bcc   :next
            plx
            bra   :done
:next       plx
            dex
            bne   :run
:flip       lda   RLEColour
            eor   #15
            sta   RLEColour
            bra   :char
:end        lda   RLEX                  ; a part line
            beq   :done
            jsr   PackRow
:done       clc
            rts
:bad        lda   #errNotPicture
            sec
            rts

*-------------------------------------------------------------
* Data
*-------------------------------------------------------------
C64Pal      dw    $000,$FFF,$D00,$0DD,$D0D,$0D0,$00D,$FE0
            dw    $F70,$B50,$F88,$666,$999,$BFB,$BBF,$CCC
MacGrey     dw    $000,$777,$CCC,$FFF,$000,$777,$CCC,$FFF
            dw    $000,$777,$CCC,$FFF,$000,$777,$CCC,$FFF
BitMasks    db    $80,$40,$20,$10,$08,$04,$02,$01

Want        dw    0
Found       dw    0
Ext         ds    6
STRes       dw    0
STEnh       dw    0
STInk       dw    0
W0          dw    0
W1          dw    0
W2          dw    0
W3          dw    0
EP          dw    0
EPB         dw    0
ELine       dw    0
ELines      dw    0
TCtl        dw    0
TCtlEnd     dw    0
TRow        dw    0
TCol        dw    0
TPlane      dw    0
SpcMode     dw    0
HBase       dw    0
HEnd        dw    0
HFixed      dw    0
KBack       dw    0
RLEH        dw    0
RLEX        dw    0
RLEColour   dw    0
STWords     ds    96
Tab12       ds    96
Tab4        ds    32
TabR        ds    512
TabG        ds    512
TabB        ds    512
MacBuf      ds    144

            put   OtherPC.s
            put   TIFF.s
            put   SegLib.s
