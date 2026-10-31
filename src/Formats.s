*-------------------------------------------------------------
* Formats.s - Super Hi-Res picture files
*
* The picture in memory (ScreenP) always has the layout of a
* $C1 file: 200 lines of 160 bytes, 200 SCBs, 56 spare bytes,
* then 16 colour tables of 32 bytes.
*-------------------------------------------------------------

* ClearScreen: zeroes the picture and gives every colour table
* the standard 320 mode palette.
ClearScreen lda   ScreenP
            sta   p0
            lda   ScreenP+2
            sta   p0+2
            lda   #0
            ldy   #screenSize-2
:zero       sta   [p0],y
            dey
            dey
            bpl   :zero
            ldy   #palOffset
:table      ldx   #0
:entry      lda   Std320,x
            sta   [p0],y
            iny
            iny
            inx
            inx
            cpx   #32
            bcc   :entry
            cpy   #screenSize
            bcc   :table
            rts

* DecodeFile: turns the file in FileP/FileLen into the picture.
*   out: carry clear and A = format (fmtC1...), or carry set
DecodeFile  jsr   ClearScreen
            jsr   FreeTrue              ; no true colour picture any more
            stz   pw                    ; (a smaller picture says its size)
            stz   ph
            stz   p640
            jsr   PairDHR               ; (.BIN and .AUX: one Double HiRes)
            lda   ForceFmt              ; a format chosen in Load formats
            beq   :auto
            jmp   DecodeForced
:auto       lda   FileType              ; the file type says which format it is
            cmp   #$00C0
            bne   :notC0
            lda   FileAux
            cmp   #3
            bcs   :guess
            asl
            tax
            jmp   (:byAux,x)
:byAux      da    :pw,:packed,:apf
:pw         jsr   DecodePW
            bcs   :guess
            lda   #fmtPaintWorks
            clc
            rts
:packed     jsr   DecodePacked
            bcs   :guess
            lda   #fmtPacked
            clc
            rts
:apf        jsr   IsAPF
            bcs   :guess
            jsr   DecodeAPF
            bcc   :apfOK1
            cmp   #0                    ; (an error: said; not one: on)
            beq   :guess
            sec
            rts
:apfOK1     lda   #fmtAPF
            clc
            rts
:notC0      cmp   #$00C1
            bne   :guess
            lda   FileAux
            bne   :guess
            lda   FileLen+2
            bne   :guess
            lda   FileLen
            cmp   #32000
            bcc   :guess
            jsr   CopyRaw32000
            lda   #fmtC1
            clc
            rts
:guess      jsr   DecodeTrue            ; PNG, GIF, JPEG, BMP?
            bcs   :notTrue
            rts
:notTrue    cmp   #0
            beq   :shr
            sec                         ; one of them, but it could not be read
            rts
:shr        lda   #$FFFF                ; MegaconvertGS's own formats, by name
            jsr   CallOther             ; (before the Apple formats' sizes)
            bcs   :notOwn
            rts
:notOwn     cmp   #0                    ; (named so, but not one: the others)
            beq   :apple
            cmp   #errNotPicture
            beq   :apple
            sec
            rts
:apple      lda   #0                    ; Apple II and IIgs formats
            jsr   CallApple
            bcs   :notApple
            rts
:notApple   cmp   #0
            beq   :shrGuess
            sec
            rts
:shrGuess   jsr   IsIPIName             ; IPI: three files, .R .G .B
            bcs   :notIPI
            jmp   DecodeIPI
:notIPI     lda   #0                    ; other computers' formats
            jsr   CallOther
            bcs   :notOther
            rts
:notOther   cmp   #0
            beq   :shrGuess2
            sec
            rts
:shrGuess2  jsr   ClearScreen           ; otherwise go by the contents
            lda   FileLen+2
            bne   :notRaw
            lda   FileLen
            cmp   #screenSize
            beq   :raw
            cmp   #32000
            beq   :raw
:notRaw     jsr   IsAPF
            bcs   :notAPF
            jsr   DecodeAPF
            bcc   :apfOK2
            cmp   #0
            beq   :fail
            sec
            rts
:apfOK2     lda   #fmtAPF
            clc
            rts
:notAPF     jsr   DecodePacked
            bcs   :notPacked
            lda   #fmtPacked
            clc
            rts
:notPacked  jsr   ClearScreen
            jsr   DecodePW
            bcs   :fail
            lda   #fmtPaintWorks
            clc
            rts
:raw        jsr   CopyRaw
            lda   #fmtC1
            clc
            rts
:fail       lda   #errNotPicture
            sec
            rts

* DecodeForced: reads the file as format A (ForceFmt).
DecodeForced cmp  #fmtWOA              ; (Works of Art: the Apple segment)
            bne   :notWOA
            jmp   CallApple
:notWOA     cmp   #fmtTGA               ; (TGA, PICT: the Other segment)
            bcc   :notNew
            cmp   #fmtLast+1
            bcs   :notNew
            jmp   CallOther
:notNew     cmp   #fmtCount             ; (listed, not implemented yet)
            bcc   :known
            lda   #errNotImpl
            sec
            rts
:known      cmp   #fmtPWGold
            bne   :notGold
            jmp   DecodePWGold
:notGold    cmp   #fmtIPI
            bne   :notIPI
            jmp   DecodeIPI
:notIPI     cmp   #fmtDegas
            bcc   :notOther
            jmp   CallOther
:notOther   cmp   #fmtHGR
            bcc   :here
            jmp   CallApple
:here       asl
            tax
            jmp   (:kinds,x)
:kinds      da    :fail,:c1,:apf,:packed,:pw,:true,:true,:true,:true
:c1         lda   FileLen+2
            bne   :c1ok
            lda   FileLen
            cmp   #32000
            bcc   :fail
:c1ok       jsr   CopyRaw32000
            lda   #fmtC1
            clc
            rts
:apf        jsr   IsAPF
            bcs   :fail
            jsr   DecodeAPF
            bcc   :apfOK3
            cmp   #0
            beq   :fail
            sec
            rts
:apfOK3     lda   #fmtAPF
            clc
            rts
:packed     jsr   DecodePacked
            bcs   :fail
            lda   #fmtPacked
            clc
            rts
:pw         jsr   DecodePW
            bcs   :fail
            lda   #fmtPaintWorks
            clc
            rts
:true       jsr   DecodeTrue
            bcc   :ok
            cmp   #0
            bne   :err
:fail       lda   #errNotPicture
:err        sec
:ok         rts

* CallOther: the other computers' loader segment, for format A (0: any).
* A file named .SCR may be an Amstrad CPC screen: its .PAL file goes along.
CallOther   pha
            jsr   PalRead
            pla
            ldx   #1
            jsr   CallSeg
            php
            pha
            ldx   #PalH
            jsr   FreeHandleAt
            pla
            plp
            rts

* CallApple: the Apple II and IIgs loader segment, for format A (0: any).
CallApple   ldx   #0
CallSeg     stx   SegNo
            pha
            lda   PathPtr
            sta   pathp
            lda   PathPtr+2
            sta   pathp+2
            lda   FileP
            sta   fp
            lda   FileP+2
            sta   fp+2
            lda   FileLen
            sta   flen
            lda   FileLen+2
            sta   flen+2
            lda   ScreenP
            sta   scrp
            lda   ScreenP+2
            sta   scrp+2
            lda   FileType
            sta   ftype
            lda   FileAux
            sta   faux
            lda   UserID
            sta   uid
            lda   #MonoBlk              ; (a loader may make a monochrome image)
            sta   mblk
            lda   #^MonoBlk
            sta   mblk+2
            pla
            ldx   SegNo
            bne   :other
            jsl   DecodeApple
            rts
:other      jsl   DecodeOther
            rts

SegNo       dw    0

*-------------------------------------------------------------
* IPI: a picture in three files, name.R, name.G and name.B, each a
* square of 8-bit samples (256 or 512 a side). Any one may be opened.
*-------------------------------------------------------------

* PairDHR: a Double HiRes picture in two files, NAME.BIN (main memory)
* and NAME.AUX (auxiliary memory), 8184 or 8192 bytes each (Beagle
* Graphics; bmp2dhr's option A): either one opened, with no format chosen
* or a Double HiRes one, and the other one there too, become one 16384-byte
* file, the auxiliary half first, as Double HiRes is read (no format
* chosen: Double HiRes colour). Else nothing changes: a lone .BIN is HiRes.
PairDHR     lda   ForceFmt
            beq   :fmt
            cmp   #fmtDHR
            beq   :fmt
            cmp   #fmtDHRBW
            beq   :fmt
:no         rts
:fmt        jsr   PairSize
            bcs   :no
            lda   PathPtr
            sta   p0
            lda   PathPtr+2
            sta   p0+2
            lda   [p0]                  ; "x.BIN" or "x.AUX", any case
            cmp   #5
            bcc   :no
            cmp   #255
            bcs   :no
            sta   t0
            dec                         ; (the dot: length - 2, after the
            dec                         ;  length word)
            tay
            lda   [p0],y
            and   #$00FF
            cmp   #'.'
            bne   :no
            iny
            jsr   :up
            sta   t1
            iny
            jsr   :up
            xba
            ora   t1
            sta   t1                    ; the first two letters
            iny
            jsr   :up
            sta   t2                    ; the third
            stz   PairAux
            lda   t1
            cmp   #$4942               ; "BI"
            bne   :aux
            lda   t2
            cmp   #'N'
            bne   :no
            bra   :name
:aux        cmp   #$5541               ; "AU"
            bne   :no
            lda   t2
            cmp   #'X'
            bne   :no
            inc   PairAux
:name       ldy   #0                    ; the other one's name: a copy, the
:copy       lda   [p0],y                ; three letters changed (each in
            sta   IpiPath,y             ; its own case)
            iny
            iny
            cpy   #258
            bcc   :copy
            lda   PairAux
            asl
            asl
            tax                         ; (0: "AUX" wanted, 4: "BIN")
            ldy   t0
            iny
            iny
            iny
            sty   t3                    ; past the last letter
            ldy   t0
            dey
:letter     lda   [p0],y
            and   #$0020                ; (lower case: bit 5)
            ora   PairOther,x
            sep   #$20
            mx    %10
            sta   IpiPath,y
            rep   #$20
            mx    %00
            inx
            iny
            cpy   t3
            bcc   :letter
            lda   PathPtr               ; the other one read (this one kept)
            sta   PairPath
            lda   PathPtr+2
            sta   PairPath+2
            ldx   #0
:keep       lda   FileH,x
            sta   PairOwn,x
            inx
            inx
            cpx   #12
            bcc   :keep
            lda   FileType
            sta   PairType
            lda   FileAux
            sta   PairTAux
            lda   #IpiPath
            sta   PathPtr
            lda   #^IpiPath
            sta   PathPtr+2
            jsr   ReadFile
            php
            lda   PairPath
            sta   PathPtr
            lda   PairPath+2
            sta   PathPtr+2
            plp
            bcs   :alone
            jsr   PairSize
            bcc   :both
            jsr   FreeFile              ; (not a half: this one alone)
:alone      ldx   #0
:back       lda   PairOwn,x
            sta   FileH,x
            inx
            inx
            cpx   #12
            bcc   :back
            bra   :types
:both       lda   #16384                ; both: one picture, black where a
            sta   n0                    ; half is 8184 bytes
            stz   n0+2
            jsr   NewBuffer
            bcs   :alone2
            lda   #0
            ldy   #16382
:zero       sta   [p0],y
            dey
            dey
            bpl   :zero
            lda   PairOwnP              ; this one's half (kept)
            sta   p1
            lda   PairOwnP+2
            sta   p1+2
            lda   PairOwn+8
            ldx   PairAux
            jsr   :copyHalf
            lda   FileP                 ; the other one's
            sta   p1
            lda   FileP+2
            sta   p1+2
            lda   PairAux
            eor   #1
            tax
            lda   FileLen
            jsr   :copyHalf
            jsr   FreeFile              ; both files go: the picture stays
            PushLongAt PairOwn
            Tool  _DisposeHandle
            lda   n1
            sta   FileH
            lda   n1+2
            sta   FileH+2
            lda   p0
            sta   FileP
            lda   p0+2
            sta   FileP+2
            lda   #16384
            sta   FileLen
            stz   FileLen+2
            lda   ForceFmt
            bne   :types
            lda   #fmtDHR
            sta   ForceFmt
:types      lda   PairType
            sta   FileType
            lda   PairTAux
            sta   FileAux
            rts
:alone2     jsr   FreeFile
            jmp   :alone
:copyHalf   sta   t1                    ; A bytes from p1 to the picture's
            lda   p0                    ; auxiliary half (X = 1) or main
            cpx   #0                    ; half (X = 0)
            bne   :at
            clc
            adc   #8192
:at         sta   p2
            lda   p0+2
            sta   p2+2
            ldy   #0
            sep   #$20
            mx    %10
:c          lda   [p1],y
            sta   [p2],y
            iny
            cpy   t1
            bcc   :c
            rep   #$20
            mx    %00
            rts
:up         lda   [p0],y                ; a character, in upper case
            and   #$00FF
            cmp   #'a'
            bcc   :u
            cmp   #'z'+1
            bcs   :u
            and   #$00DF
:u          rts

* PairSize: carry clear if the file read is 8184-8192 bytes long.
PairSize    lda   FileLen+2
            bne   :no
            lda   FileLen
            cmp   #8184
            bcc   :no
            cmp   #8193
            bcs   :no
            clc
            rts
:no         sec
            rts

PairOther   asc   'AUX',00,'BIN',00     ; (the other one's letters)
PairAux     dw    0                     ; (the file opened is the .AUX)
PairPath    adrl  0
PairType    dw    0
PairTAux    dw    0
PairOwn     adrl  0                     ; (FileH, FileP, FileLen as read)
PairOwnP    adrl  0
            adrl  0

* IsIPIName: carry clear if the path ends in .R, .G or .B (any case).
IsIPIName   lda   PathPtr
            sta   p0
            lda   PathPtr+2
            sta   p0+2
            lda   [p0]                  ; length
            cmp   #3
            bcc   :no
            tay                         ; the last character is at length + 1
            iny
            lda   [p0],y
            and   #$00DF                ; (upper case)
            cmp   #'R'
            beq   :dot
            cmp   #'G'
            beq   :dot
            cmp   #'B'
            bne   :no
:dot        dey
            lda   [p0],y
            and   #$00FF
            cmp   #'.'
            bne   :no
            clc
            rts
:no         sec
            rts

* PalRead: for a name ending in .SCR, the .PAL file beside it (an Amstrad
* CPC screen's mode and palette, from OCP Art Studio): its data at ipg and
* its length in opal (0: none). The picture's own file stays as it was.
PalRead     stz   opal
            lda   PathPtr
            sta   p0
            lda   PathPtr+2
            sta   p0+2
            lda   [p0]                  ; at least "x.SCR", and room for a copy
            cmp   #5
            bcs   :jx3
            jmp   :no
:jx3
            cmp   #258
            bcc   :jx4
            jmp   :no
:jx4
            tay                         ; (the last character: length + 1)
            iny
            ldx   #6
:end        lda   [p0],y                ; ".SCR" in any case
            and   #$00FF
            cpx   #0
            beq   :dot
            and   #$00DF
:dot        cmp   PalScr,x
            beq   :jx5
            jmp   :no
:jx5
            dey
            dex
            dex
            bpl   :end
            ldy   #0                    ; the same name ending in .PAL
            lda   [p0]
            clc
            adc   #2
            sta   t0
:copy       lda   [p0],y
            sta   IpiPath,y
            iny
            iny
            cpy   t0
            bcc   :copy
            lda   [p0]
            inc
            tay
            dey
            dey
            lda   [p0],y                ; (lower case if the S was)
            and   #$0020
            sta   t0
            ldx   #0
:pal        lda   PalPal,x
            ora   t0
            sep   #$20
            mx    %10
            sta   IpiPath,y
            rep   #$20
            mx    %00
            iny
            inx
            inx
            cpx   #6
            bcc   :pal
            ldx   #14                   ; keep the picture's file (handle, pointer,
:keep       lda   FileH,x               ; length, type, aux type)
            sta   PalKeep,x
            dex
            dex
            bpl   :keep
            lda   PathPtr
            sta   PalPathP
            lda   PathPtr+2
            sta   PalPathP+2
            lda   #IpiPath
            sta   PathPtr
            lda   #^IpiPath
            sta   PathPtr+2
            jsr   ReadFile
            bcs   :back
            lda   FileH
            sta   PalH
            lda   FileH+2
            sta   PalH+2
            lda   FileP
            sta   ipg
            lda   FileP+2
            sta   ipg+2
            lda   FileLen+2
            bne   :back
            lda   FileLen
            sta   opal
:back       ldx   #14
:put        lda   PalKeep,x
            sta   FileH,x
            dex
            dex
            bpl   :put
            lda   PalPathP
            sta   PathPtr
            lda   PalPathP+2
            sta   PathPtr+2
:no         rts

PalScr      dw    '.','S','C','R'
PalPal      dw    'P','A','L'
PalH        adrl  0
PalPathP    adrl  0
PalKeep     ds    16

* DecodeIPI: reads the other two files, then the Other segment builds the picture.
DecodeIPI   jsr   IsIPIName
            bcc   :name
            jmp   :bad
:name       lda   PathPtr               ; (put back afterwards)
            sta   IpiPathP
            lda   PathPtr+2
            sta   IpiPathP+2
            lda   FileH                 ; the file already read
            sta   IpiOwn
            lda   FileH+2
            sta   IpiOwn+2
            lda   FileP
            sta   IpiOwnP
            lda   FileP+2
            sta   IpiOwnP+2
            lda   FileLen
            sta   IpiOwnL
            lda   FileLen+2
            sta   IpiOwnL+2
            ldy   #2                    ; a copy of the path to change
            lda   [p0]
            clc
            adc   #2
            sta   t0
:copy       lda   [p0],y
            sta   IpiPath,y
            iny
            iny
            cpy   t0
            bcc   :copy
            lda   [p0]
            sta   IpiPath
            inc
            sta   IpiLast               ; index of the last character
            tay
            lda   [p0],y
            and   #$00FF
            sta   IpiOwnC               ; R, G or B as it was written
            stz   IpiH
            stz   IpiH+2
            stz   IpiH+4
            stz   IpiH+6
            stz   IpiH+8
            stz   IpiH+10
            ldx   #0                    ; each colour: R, G, B
:colour     stx   IpiC
            lda   IpiOwnC
            and   #$00DF
            cmp   IpiLetters,x
            bne   :read
            txa                         ; this is the file already read
            asl
            tax
            lda   IpiOwnP
            sta   IpiP,x
            lda   IpiOwnP+2
            sta   IpiP+2,x
            lda   IpiOwnL
            sta   IpiL,x
            lda   IpiOwnL+2
            sta   IpiL+2,x
            bra   :next
:read       lda   IpiLetters,x          ; the same name with this letter,
            ldy   IpiOwnC               ; in the same case
            cpy   #'a'
            bcc   :case
            ora   #$0020
:case       ldy   IpiLast
            sep   #$20
            mx    %10
            sta   IpiPath,y
            rep   #$20
            mx    %00
            lda   #IpiPath
            sta   PathPtr
            lda   #^IpiPath
            sta   PathPtr+2
            jsr   ReadFile
            bcc   :jx1
            jmp   :readErr
:jx1
            lda   IpiC
            asl
            tax
            lda   FileH
            sta   IpiH,x
            lda   FileH+2
            sta   IpiH+2,x
            lda   FileP
            sta   IpiP,x
            lda   FileP+2
            sta   IpiP+2,x
            lda   FileLen
            sta   IpiL,x
            lda   FileLen+2
            sta   IpiL+2,x
:next       ldx   IpiC
            inx
            inx
            cpx   #6
            bcs   :jx2
            jmp   :colour
:jx2
            ldx   #8                    ; each at least side x side bytes
            lda   IpiL+2                ; (512 if red has 262144 or more, else 256)
            cmp   #4
            bcs   :side
            ldx   #0
:side       stx   t1
            ldx   #0
:size       lda   IpiL+2,x
            cmp   #4
            bcs   :sizeOK
            ldy   t1
            bne   :short
            cmp   #1
            bcs   :sizeOK
:short      lda   #errNotPicture
            bra   :fail
:sizeOK     inx
            inx
            inx
            inx
            cpx   #12
            bcc   :size
            lda   IpiP                  ; the Other segment does the rest
            sta   FileP
            lda   IpiP+2
            sta   FileP+2
            lda   IpiL
            sta   FileLen
            lda   IpiL+2
            sta   FileLen+2
            lda   IpiP+4
            sta   ipg
            lda   IpiP+6
            sta   ipg+2
            lda   IpiP+8
            sta   ipb
            lda   IpiP+10
            sta   ipb+2
            lda   #fmtIPI
            jsr   CallOther
            bcs   :fail
            jsr   :restore
            lda   #fmtIPI
            clc
            rts
:readErr    cmp   #0
            bne   :fail
:bad        lda   #errNotPicture
:fail       pha
            jsr   :restore
            pla
            sec
            rts
:restore    lda   IpiPathP
            sta   PathPtr
            lda   IpiPathP+2
            sta   PathPtr+2
            ldx   #IpiH                 ; free the other two, and put back the first
            jsr   FreeHandleAt
            ldx   #IpiH+4
            jsr   FreeHandleAt
            ldx   #IpiH+8
            jsr   FreeHandleAt
            lda   IpiOwn
            sta   FileH
            lda   IpiOwn+2
            sta   FileH+2
            lda   IpiOwnP
            sta   FileP
            lda   IpiOwnP+2
            sta   FileP+2
            lda   IpiOwnL
            sta   FileLen
            lda   IpiOwnL+2
            sta   FileLen+2
            rts

IpiLetters  dw    'R','G','B'
IpiOwn      adrl  0
IpiOwnP     adrl  0
IpiOwnL     adrl  0
IpiOwnC     dw    0
IpiPathP    adrl  0
IpiC        dw    0
IpiLast     dw    0
IpiH        adrl  0,0,0
IpiP        adrl  0,0,0
IpiL        adrl  0,0,0
IpiPath     ds    260

* DecodePWGold: Paintworks Gold's 640 mode pictures, saved with 320 mode
* headers: as Apple Preferred, a screen, or a Paint file. 640 mode throughout.
DecodePWGold jsr  IsAPF
            bcs   :notAPF
            inc   Force640
            jsr   DecodeAPF
            stz   Force640
            bcc   :jx1
            jmp   :fail
:jx1
            jmp   :ok
:notAPF     lda   FileLen+2
            bne   :paint
            lda   FileLen
            cmp   #32000
            bcc   :paint
            cmp   #33281
            bcs   :paint
            jsr   CopyRaw32000
            lda   FileLen               ; no colour tables: 640 mode's if the
            cmp   #32768                ; lines mostly say 640 mode
            bcs   :all640
            jsr   CountWide
            cmp   #101
            bcc   :all640
            jsr   Table640
:all640     jsr   Scbs640
            lda   #640
            sta   pw
            lda   #200
            sta   ph
            lda   #1
            sta   p640
            bra   :ok
:paint      lda   FileLen+2             ; Paint file: PackBytes from $222 on
            bne   :unpack
            lda   FileLen
            cmp   #$223
            bcc   :fail
:unpack     lda   FileP
            clc
            adc   #$222
            sta   UPSrc
            lda   FileP+2
            adc   #0
            sta   UPSrc+2
            lda   FileLen
            sec
            sbc   #$222
            sta   n0
            lda   FileLen+2
            sbc   #0
            sta   n0+2
            lda   ScreenP
            sta   UPStart
            lda   ScreenP+2
            sta   UPStart+2
            lda   #32000
            sta   UPSize
            jsr   UnpackAll
            lda   #32000                ; whole lines unpacked
            sec
            sbc   UPSize
            ldx   #0
:lines      cmp   #160
            bcc   :counted
            sbc   #160
            inx
            bra   :lines
:counted    cpx   #0
            beq   :fail
            stx   t3
            stx   ph
            lda   #640
            sta   pw
            lda   #1
            sta   p640
            jsr   Table640
            ldx   t3
            jsr   ScbsX
:ok         lda   #fmtPWGold
            clc
            rts
:fail       lda   #errNotPicture
            sec
            rts

* CountWide: how many of the picture's SCBs are for 640 mode.
CountWide   jsr   PicP0
            stz   t1
            ldy   #scbOffset
:scb        lda   [p0],y
            and   #$0080
            beq   :n
            inc   t1
:n          iny
            cpy   #scbOffset+200
            bcc   :scb
            lda   t1
            rts

* Table640: colour table 0 = the standard 640 mode one.
Table640    jsr   PicP0
            ldy   #palOffset
            ldx   #0
:copy       lda   Std640,x
            sta   [p0],y
            iny
            iny
            inx
            inx
            cpx   #32
            bcc   :copy
            rts

* Scbs640 / ScbsX: the first 200 (or X) lines in 640 mode, table 0.
Scbs640     ldx   #200
ScbsX       jsr   PicP0
            ldy   #scbOffset
            sep   #$20
            mx    %10
            lda   #$80
:scb        sta   [p0],y
            iny
            dex
            bne   :scb
            rep   #$20
            mx    %00
            rts

PicP0       lda   ScreenP
            sta   p0
            lda   ScreenP+2
            sta   p0+2
            rts

* CopyRaw32000: copies a $C1 file of 32000 bytes or more (up to 32768).
CopyRaw32000 lda  FileLen
            cmp   #screenSize
            bcc   CopyRaw
            lda   #screenSize
            sta   FileLen

* CopyRaw: copies a 32000 or 32768 byte screen file as it is.
CopyRaw     lda   FileP
            sta   p0
            lda   FileP+2
            sta   p0+2
            lda   ScreenP
            sta   p1
            lda   ScreenP+2
            sta   p1+2
            ldy   FileLen
            dey
            dey
:copy       lda   [p0],y
            sta   [p1],y
            dey
            dey
            bpl   :copy
            rts

*-------------------------------------------------------------
* Apple Preferred ($C0/0002): a chain of named blocks
*-------------------------------------------------------------

* IsAPF: carry clear if the file starts like an Apple Preferred
* file (a sane block length and a printable block name).
IsAPF       lda   FileLen+2
            bne   :long
            lda   FileLen
            cmp   #11
            bcc   :no
:long       lda   FileP
            sta   p0
            lda   FileP+2
            sta   p0+2
            ldy   #4
            lda   [p0],y
            and   #$00FF
            beq   :no
            cmp   #16
            bcs   :no
            sta   t0
            ldy   #2                    ; block length <= file length
            lda   [p0],y
            cmp   FileLen+2
            bcc   :name
            bne   :no
            lda   [p0]
            cmp   FileLen
            beq   :name
            bcs   :no
:name       ldy   #5
:char       lda   [p0],y
            and   #$00FF
            cmp   #$20
            bcc   :no
            cmp   #$7F
            bcs   :no
            iny
            dec   t0
            bne   :char
            clc
            rts
:no         sec
            rts

* DecodeAPF: finds the MAIN block (and a MULTIPAL block: a colour table
* for every line) and unpacks it.
DecodeAPF   stz   MPalN
            lda   FileP
            sta   p1                    ; p1 = current block
            lda   FileP+2
            sta   p1+2
            clc                         ; p3 = end of file
            lda   FileP
            adc   FileLen
            sta   p3
            lda   FileP+2
            adc   FileLen+2
            sta   p3+2
            stz   FoundMain
            bra   :block
:doneJ      jmp   :done                 ; (far)
:block      clc                         ; room for a block header?
            lda   p1
            adc   #5
            sta   n0
            lda   p1+2
            adc   #0
            sta   n0+2
            jsr   PastEnd
            bcs   :doneJ
            lda   [p1]                  ; n1 = block length
            sta   n1
            ldy   #2
            lda   [p1],y
            sta   n1+2
            bne   :big
            lda   n1
            cmp   #5
            bcc   :doneJ
:big        clc                         ; n0 = next block
            lda   p1
            adc   n1
            sta   n0
            lda   p1+2
            adc   n1+2
            sta   n0+2
            jsr   PastEnd
            bcs   :doneJ
            ldy   #4                    ; named "MAIN"?
            lda   [p1],y
            and   #$00FF
            cmp   #8
            beq   :multi
            cmp   #4
            bne   :next
            ldy   #5
            lda   [p1],y
            cmp   #$414D                ; "MA"
            bne   :next
            ldy   #7
            lda   [p1],y
            cmp   #$4E49                ; "IN"
            bne   :next
            lda   p1                    ; (parsed when all are known)
            sta   MainAt
            lda   p1+2
            sta   MainAt+2
            inc   FoundMain
            bra   :next
:multi      ldy   #5                    ; "MULTIPAL": count, then the tables
            lda   [p1],y
            cmp   #$554D                ; "MU"
            bne   :next
            ldy   #11
            lda   [p1],y
            cmp   #$4C41                ; "AL"
            bne   :next
            ldy   #13
            lda   [p1],y
            sta   MPalN
            lda   p1
            clc
            adc   #15
            sta   MPalAt
            lda   p1+2
            adc   #0
            sta   MPalAt+2
:next       lda   n0
            sta   p1
            lda   n0+2
            sta   p1+2
            jmp   :block
:done       lda   FoundMain
            beq   :fail
            lda   MainAt
            sta   p1
            lda   MainAt+2
            sta   p1+2
            jsr   ParseMain
            bcs   :err
            clc
            rts
:fail       lda   #0                    ; (0: not one; else an error, such
            sec                         ; as no memory for a large one)
:err        rts

* PastEnd: carry set if n0 is beyond p3.
PastEnd     lda   p3+2
            cmp   n0+2
            bne   :hi
            lda   p3
            cmp   n0
:hi         bcs   :inside
            sec
            rts
:inside     clc
            rts

* ParseMain: unpacks the MAIN block at p1 into the picture.
* Lines beyond 200 and bytes beyond 160 per line are left out.
ParseMain   clc                         ; p2 = block contents
            lda   p1
            adc   #9
            sta   p2
            lda   p1+2
            adc   #0
            sta   p2+2
            lda   [p2]
            sta   MasterMode
            ldy   #2
            lda   [p2],y
            sta   PixPerLine
            ldy   #4
            lda   [p2],y
            sta   NumTables
            lda   #6
            jsr   AddP2
            lda   p2                    ; (the tables, for a true colour one)
            sta   TabAt
            lda   p2+2
            sta   TabAt+2
            lda   ScreenP               ; colour tables (at most 16)
            sta   p0
            lda   ScreenP+2
            sta   p0+2
            lda   NumTables
            cmp   #17
            bcc   :tables
            lda   #16
:tables     asl
            asl
            asl
            asl
            asl
            beq   :noTables
            sta   t0                    ; bytes to copy
            ldx   #palOffset
            ldy   #0
:copyTab    lda   [p2],y
            phy
            txy
            sta   [p0],y
            ply
            inx
            inx
            iny
            iny
            cpy   t0
            bcc   :copyTab
:noTables   lda   MasterMode            ; the picture's size, at most a screen
            and   #$0080
            ora   Force640
            beq   :m
            lda   #1
:m          sta   p640
            lda   PixPerLine
            ldx   p640
            bne   :w640
            cmp   #321
            bcc   :w
            lda   #320
            bra   :w
:w640       cmp   #641
            bcc   :w
            lda   #640
:w          ldx   Force640
            beq   :w2
            lda   #640
:w2         sta   pw
:noTables2  lda   NumTables             ; skip all the tables
            asl
            asl
            asl
            asl
            asl
            jsr   AddP2
            lda   [p2]
            sta   NumLines
            cmp   #201
            bcc   :lines
            lda   #200
:lines      sta   ph
            lda   #2
            jsr   AddP2
            lda   p2                    ; Dir = scan line directory
            sta   Dir
            lda   p2+2
            sta   Dir+2
            lda   NumLines              ; p2 = packed data
            asl
            asl
            jsr   AddP2
            lda   Force640              ; Paintworks Gold: 640 pixels whatever it says
            beq   :byMode
            lda   #160
            bra   :bprOK
:byMode     lda   MasterMode            ; bytes per line: 4 pixels a byte in 640 mode
            and   #$0080
            beq   :narrow
            lda   PixPerLine
            lsr
            lsr
            bra   :bpr
:narrow     lda   PixPerLine
            lsr
:bpr        cmp   #640
            bcc   :bprOK
            lda   #640
:bprOK      sta   BytesPerLine
            jsr   ApfBig                ; larger than a screen, or 3200 colors:
            bcc   :lines0               ; a true colour picture
            rts
:lines0     stz   LineNo
:line       lda   LineNo
            cmp   NumLines
            bcc   :more
            clc
            rts
:more       lda   Dir                   ; directory entry: packed size, mode
            sta   p0
            lda   Dir+2
            sta   p0+2
            lda   LineNo
            asl
            asl
            tay
            lda   [p0],y
            sta   PackedLen
            iny
            iny
            lda   [p0],y
            sta   LineMode
            lda   Force640
            beq   :mode
            lda   #$80
            sta   LineMode
:mode       lda   ApfTrueOn
            bne   :unpack
            lda   LineNo
            cmp   #200
            bcs   :skip
:unpack     lda   p2                    ; unpack the line into LineBuf
            sta   UPSrc
            lda   p2+2
            sta   UPSrc+2
            lda   PackedLen
            sta   UPSrcLen
            lda   #LineBuf
            sta   UPStart
            lda   #^LineBuf
            sta   UPStart+2
            lda   BytesPerLine
            sta   UPSize
            jsr   Unpack
            lda   ApfTrueOn
            beq   :put
            jsr   ApfTrueLine
            bra   :skip
:put        jsr   PutLine
:skip       lda   PackedLen
            jsr   AddP2
            inc   LineNo
            bra   :line

* ApfBig: an Apple Preferred picture larger than the screen (wider than 320
* pixels in 320 mode or 640 in 640 mode, or taller than 200 lines), or with
* a MULTIPAL block (a colour table for each line: 3200 colors), becomes a
* true colour picture of its whole size, each line in its own colours, as
* GS Remap reads it (PaintWorks Gold's 640 mode files stay screens).
*   out: carry set and A = error if it can't be made
ApfBig      stz   ApfTrueOn
            lda   Force640
            bne   :screen
            lda   MPalN                 ; a table for every line?
            beq   :size
            cmp   NumLines
            bcs   :true
:size       lda   NumLines
            cmp   #201
            bcs   :true
            lda   MasterMode
            and   #$0080
            beq   :w320
            lda   PixPerLine
            cmp   #641
            bcs   :true
            bra   :screen
:w320       lda   PixPerLine
            cmp   #321
            bcs   :true
:screen     clc
            rts
:true       lda   MasterMode            ; (no wider than a line holds)
            and   #$0080
            beq   :two
            lda   BytesPerLine
            asl
            asl
            bra   :cap
:two        lda   BytesPerLine
            asl
:cap        cmp   PixPerLine
            bcc   :w
            lda   PixPerLine
:w          sta   TrueW
            lda   NumLines
            sta   TrueH
            jsr   NewTrue               ; (IsTrue, TrueP, TrueStride)
            bcs   :err
            stz   TrueTall              ; 640 mode: pixels twice as tall
            lda   MasterMode
            and   #$0080
            beq   :sq
            inc   TrueTall
:sq         lda   TrueP
            sta   ApfRow
            lda   TrueP+2
            sta   ApfRow+2
            inc   ApfTrueOn
            clc
:err        rts

* ApfTrueLine: LineBuf (line LineNo, mode LineMode) into the true colour
* picture's next row: its colours from MULTIPAL's table for the line, else
* MAIN's table its mode names (table 0 if there aren't that many).
ApfTrueLine lda   MPalN
            beq   :main
            lda   LineNo                ; MULTIPAL + line x 32
            xba
            and   #$00FF
            lsr
            lsr
            lsr
            sta   t1                    ; (the high word of line x 32)
            lda   LineNo
            asl
            asl
            asl
            asl
            asl
            clc
            adc   MPalAt
            sta   q1
            lda   MPalAt+2
            adc   t1
            sta   q1+2
            bra   :lut
:main       lda   LineMode
            and   #$000F
            cmp   NumTables
            bcc   :tab
            lda   #0
:tab        asl
            asl
            asl
            asl
            asl
            clc
            adc   TabAt
            sta   q1
            lda   TabAt+2
            adc   #0
            sta   q1+2
:lut        ldy   #0                    ; the 16 colours as RGB
            ldx   #0
:entry      lda   [q1],y
            sta   t2
            xba
            and   #$000F
            jsr   :x17
            sta   ApfLUT,x
            lda   t2
            lsr
            lsr
            lsr
            lsr
            and   #$000F
            jsr   :x17
            sta   ApfLUT+1,x
            lda   t2
            and   #$000F
            jsr   :x17
            sta   ApfLUT+2,x
            iny
            iny
            inx
            inx
            inx
            cpx   #48
            bcc   :entry
            lda   ApfRow
            sta   q0
            lda   ApfRow+2
            sta   q0+2
            stz   t2                    ; t2: the pixel; Y: its RGB
            ldy   #0
:pix        lda   t2
            cmp   TrueW
            bcc   :inRow
            jmp   :next
:inRow      lda   LineMode
            and   #$0080
            bne   :p640
            lda   t2                    ; 320 mode: a nibble, the high one first
            lsr
            tax
            lda   LineBuf,x
            and   #$00FF
            sta   t3
            lda   t2
            and   #1
            bne   :lo
            lda   t3
            lsr
            lsr
            lsr
            lsr
            bra   :idx
:lo         lda   t3
            and   #$000F
            bra   :idx
:p640       lda   t2                    ; 640 mode: two bits, the colours
            lsr                         ; 8-11, 12-15, 0-3, 4-7 by place
            lsr
            tax
            lda   LineBuf,x
            and   #$00FF
            sta   t3
            lda   t2
            and   #3
            tax
            beq   :sh
:shift      asl   t3
            asl   t3
            dex
            bne   :shift
:sh         lda   t3
            and   #$00C0
            lsr
            lsr
            lsr
            lsr
            lsr
            lsr
            sta   t3
            lda   t2
            and   #3
            tax
            lda   ApfBase,x
            and   #$00FF
            clc
            adc   t3
:idx        sta   t3                    ; x 3
            asl
            adc   t3
            tax
            sep   #$20
            mx    %10
            lda   ApfLUT,x
            sta   [q0],y
            iny
            lda   ApfLUT+1,x
            sta   [q0],y
            iny
            lda   ApfLUT+2,x
            sta   [q0],y
            iny
            rep   #$20
            mx    %00
            inc   t2
            jmp   :pix
:next       lda   ApfRow                ; the next row
            clc
            adc   TrueStride
            sta   ApfRow
            bcc   :out
            inc   ApfRow+2
:out        rts
:x17        sta   t3                    ; (A x 17)
            asl
            asl
            asl
            asl
            clc
            adc   t3
            rts

ApfBase     db    8,12,0,4
ApfLUT      ds    50
ApfRow      adrl  0
ApfTrueOn   dw    0
MainAt      adrl  0
MPalAt      adrl  0
MPalN       dw    0
TabAt       adrl  0

* PutLine: copies LineBuf to picture line LineNo and sets its SCB.
PutLine     lda   ScreenP
            sta   p0
            lda   ScreenP+2
            sta   p0+2
            lda   LineNo                ; y = line * 160
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
            tay
            ldx   #0
:copy       lda   LineBuf,x
            sta   [p0],y
            iny
            iny
            inx
            inx
            cpx   #160
            bcs   :scb
            cpx   BytesPerLine
            bcc   :copy
:scb        lda   LineNo
            clc
            adc   #scbOffset
            tay
            sep   #$20
            mx    %10
            lda   LineMode
            sta   [p0],y
            rep   #$20
            mx    %00
            rts

* AddP2: p2 += A
AddP2       clc
            adc   p2
            sta   p2
            lda   p2+2
            adc   #0
            sta   p2+2
            rts

*-------------------------------------------------------------
* PackBytes screen ($C0/0001) and PaintWorks ($C0/0000)
*-------------------------------------------------------------

* DecodePacked: unpacks the whole file as a $C1 screen.
DecodePacked lda  FileP
            sta   UPSrc
            lda   FileP+2
            sta   UPSrc+2
            lda   FileLen
            sta   n0
            lda   FileLen+2
            sta   n0+2
            lda   ScreenP
            sta   UPStart
            lda   ScreenP+2
            sta   UPStart+2
            lda   #screenSize
            sta   UPSize
            jsr   UnpackAll
            lda   UPSize                ; produced = 32768 - left over
            cmp   #screenSize-32000+1
            bcs   :short
            clc
            rts
:short      sec
            rts

* DecodePW: PaintWorks: a palette, pattern data, then packed lines.
DecodePW    lda   FileLen+2
            bne   :size
            lda   FileLen
            cmp   #$0223
            bcc   :fail
:size       lda   FileP
            sta   p0
            lda   FileP+2
            sta   p0+2
            lda   ScreenP
            sta   p1
            lda   ScreenP+2
            sta   p1+2
            ldy   #0                    ; palette 0
            ldx   #palOffset
:pal        lda   [p0],y
            phy
            txy
            sta   [p1],y
            ply
            inx
            inx
            iny
            iny
            cpy   #32
            bcc   :pal
            clc
            lda   FileP
            adc   #$0222
            sta   UPSrc
            lda   FileP+2
            adc   #0
            sta   UPSrc+2
            sec
            lda   FileLen
            sbc   #$0222
            sta   n0
            lda   FileLen+2
            sbc   #0
            sta   n0+2
            lda   ScreenP
            sta   UPStart
            lda   ScreenP+2
            sta   UPStart+2
            lda   #32000                ; first 200 lines only
            sta   UPSize
            jsr   UnpackAll
            lda   UPSize
            cmp   #32000-160+1          ; at least one line
            bcs   :fail
            clc
            rts
:fail       sec
            rts

* UnpackAll: unpacks n0 bytes from UPSrc, in pieces of at most
* 32767 (the toolbox takes a 16-bit length), until the output
* (UPStart/UPSize) is full or the input runs out.
UnpackAll   lda   UPSize
            beq   :done
            lda   n0+2
            bne   :piece
            lda   n0
            beq   :done
            cmp   #32767
            bcc   :len
:piece      lda   #32767
:len        sta   UPSrcLen
            jsr   Unpack
            cmp   #0
            beq   :done                 ; nothing used: stop
            sta   t0
            clc
            adc   UPSrc
            sta   UPSrc
            lda   UPSrc+2
            adc   #0
            sta   UPSrc+2
            sec
            lda   n0
            sbc   t0
            sta   n0
            lda   n0+2
            sbc   #0
            sta   n0+2
            bra   UnpackAll
:done       rts

* Unpack: one UnPackBytes call. A = packed bytes used.
Unpack      pha
            PushLongAt UPSrc
            lda   UPSrcLen
            pha
            PushLong UPStart
            PushLong UPSize
            Tool  _UnPackBytes
            pla
            rts

*-------------------------------------------------------------
* Saving
*-------------------------------------------------------------

* BuildC1: the picture as it is. Sets WData/WLen/WType/WAux.
BuildC1     lda   scrp                  ; (the screen image, or the size chosen
            sta   WData                 ; when saving: one screen)
            lda   scrp+2
            sta   WData+2
            lda   #screenSize
            sta   WLen
            stz   WLen+2
            lda   #$00C1
            sta   WType
            stz   WAux
            stz   WAux+2
            clc
            rts

* BuildPacked: the picture packed with PackBytes, into OutHnd.
BuildPacked lda   #34000
            jsr   NewOut
            bcs   :err
            lda   scrp
            sta   PKSrc
            lda   scrp+2
            sta   PKSrc+2
            jsr   PackHalf              ; PackBytes takes 16-bit sizes:
            jsr   PackHalf              ; two halves of 16K
            lda   OutP
            sta   WData
            lda   OutP+2
            sta   WData+2
            lda   OutUsed
            sta   WLen
            stz   WLen+2
            lda   #$00C0
            sta   WType
            lda   #1
            sta   WAux
            stz   WAux+2
            clc
:err        rts

PackHalf    lda   #16384
            sta   PKSize
            lda   #17000
            jmp   Pack

* BuildAPF: Apple Preferred with a MAIN block, one packed line each.
BuildAPF    lda   SvLines               ; room: the header, the directory,
            asl                         ; each line packed (at most 3 more
            asl                         ; bytes than its own, and 2 a 64)
            clc
            adc   #529+16
            sta   t0
            lda   SvBytes
            lsr
            lsr
            lsr
            lsr
            lsr
            lsr
            clc
            adc   SvBytes
            adc   #4
            ldx   SvLines
            jsr   Mul16
            lda   ProdLo
            clc
            adc   t0
            sta   t0
            lda   ProdHi
            adc   #0
            beq   :size
            lda   #$FFF0                ; (at most 64K)
            sta   t0
:size       lda   t0
            sta   APFRoom
            jsr   NewOut
            bcc   :room
            rts
:room       lda   OutP
            sta   p1
            lda   OutP+2
            sta   p1+2
            lda   scrp
            sta   p0
            lda   scrp+2
            sta   p0+2
            ldy   #4                    ; name: "MAIN"
            lda   #$4D04
            sta   [p1],y
            ldy   #6
            lda   #$4941
            sta   [p1],y
            ldy   #8
            lda   #$004E                ; "N" and the low byte of master mode
            sta   [p1],y
            ldy   cscb                  ; master mode and width from line 0
            lda   [p0],y
            and   #$0080
            sta   t0
            ldy   #9
            sta   [p1],y
            lda   SvBytes               ; pixels: 2 or 4 a byte
            asl
            ldx   t0
            beq   :width
            asl
:width      ldy   #11
            sta   [p1],y
            ldy   #13
            lda   #16
            sta   [p1],y
            ldy   cpal                  ; 16 colour tables
            ldx   #15
:tab        lda   [p0],y
            phy
            txy
            sta   [p1],y
            ply
            iny
            iny
            inx
            inx
            cpx   #15+512
            bcc   :tab
            ldy   #527                  ; the lines
            lda   SvLines
            sta   [p1],y
            asl                         ; packed lines start after the
            asl                         ; directory
            clc
            adc   #529
            sta   OutUsed
            stz   LineNo
:line       lda   OutUsed               ; (room for one more?)
            clc
            adc   SvBytes
            adc   #8
            bcs   :full
            cmp   APFRoom
            bcc   :fits
:full       lda   #errTooBig
            sec
            rts
:fits       lda   LineNo                ; PKSrc = line start
            jsr   TimesStrM
            clc
            adc   scrp
            sta   PKSrc
            lda   scrp+2
            adc   #0
            sta   PKSrc+2
            lda   SvBytes
            sta   PKSize
            clc
            adc   #8
            jsr   Pack                  ; A = packed size
            pha
            lda   LineNo                ; directory entry
            asl
            asl
            clc
            adc   #529
            tay
            pla
            sta   [p1],y
            iny
            iny
            lda   LineNo
            clc
            adc   cscb
            phy
            tay
            lda   [p0],y
            ply
            and   #$00FF
            sta   [p1],y
            inc   LineNo
            lda   LineNo
            cmp   SvLines
            bcc   :line
            lda   OutUsed               ; block length = file length
            sta   [p1]
            ldy   #2
            lda   #0
            sta   [p1],y
            lda   OutP
            sta   WData
            lda   OutP+2
            sta   WData+2
            lda   OutUsed
            sta   WLen
            stz   WLen+2
            lda   #$00C0
            sta   WType
            lda   #2
            sta   WAux
            stz   WAux+2
            clc
:err        rts

* TimesStrM: A x the saved picture's bytes a line (cstr: 160 or 320).
TimesStrM   asl
            asl
            asl
            asl
            asl
            sta   t0
            asl
            asl
            clc
            adc   t0
            ldx   cstr
            cpx   #320
            bne   :done
            asl
:done       rts

APFRoom     dw    0

* Pack: PackBytes from PKSrc/PKSize to OutP+OutUsed, at most A bytes.
*   out: A = bytes written; OutUsed advanced
Pack        sta   t1
            clc
            lda   OutP
            adc   OutUsed
            sta   PKDest
            lda   OutP+2
            adc   #0
            sta   PKDest+2
            pha                         ; result
            PushLong PKSrc
            PushLong PKSize
            PushLongAt PKDest
            lda   t1
            pha
            Tool  _PackBytes
            pla
            pha
            clc
            adc   OutUsed
            sta   OutUsed
            pla
            rts

* NewOut: allocates the output buffer (A bytes) as OutHnd/OutP.
NewOut      sta   n0
            stz   n0+2
            jsr   NewBuffer
            bcs   :err
            lda   n1
            sta   OutHnd
            lda   n1+2
            sta   OutHnd+2
            lda   p0
            sta   OutP
            lda   p0+2
            sta   OutP+2
            stz   OutUsed
            clc
:err        rts

FreeOut     lda   OutHnd
            ora   OutHnd+2
            beq   :none
            PushLongAt OutHnd
            Tool  _DisposeHandle
            stz   OutHnd
            stz   OutHnd+2
:none       rts

*-------------------------------------------------------------
* Data
*-------------------------------------------------------------
Std640      dw    $0000,$0F00,$00F0,$0FFF,$0000,$000F,$0FF0,$0FFF
            dw    $0000,$0F00,$00F0,$0FFF,$0000,$000F,$0FF0,$0FFF
Std320      dw    $0000,$0777,$0841,$072C,$000F,$0080,$0F70,$0D00
            dw    $0FA9,$0FF0,$00E0,$04DF,$0DAF,$078F,$0CCC,$0FFF

FoundMain   dw    0
Force640    dw    0
ForceFmt    dw    0
MasterMode  dw    0
PixPerLine  dw    0
NumTables   dw    0
NumLines    dw    0
BytesPerLine dw   0
LineNo      dw    0
LineMode    dw    0
PackedLen   dw    0
Dir         adrl  0

UPSrc       adrl  0                     ; UnPackBytes: packed data
UPSrcLen    dw    0
UPStart     adrl  0                     ; output pointer (advanced by the toolbox)
UPSize      dw    0                     ; output room (counted down)

PKSrc       adrl  0                     ; PackBytes: input pointer (advanced)
PKSize      dw    0                     ; input bytes (counted down)
PKDest      adrl  0

OutHnd        adrl  0
OutP        adrl  0
OutUsed     dw    0

LineBuf     ds    640
