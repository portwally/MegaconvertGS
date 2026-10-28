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
            cmp   #svDesk-svPW+1
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
            da    SaveGIF,SavePNG,SaveTIFF,SaveDesk

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
            ldx   #8190                 ; no colours yet
            lda   #$FFFF
:clr        sta   CIdx,x
            dex
            dex
            bpl   :clr
            stz   NCol
            stz   PY
:row        stz   PX
:pix        jsr   Pix
            jsr   Colour
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
            sta   PY
            stz   PX
            ldy   #0
:pix        phy                         ; (they use Y)
            jsr   Pix
            jsr   Colour
            ply
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
            ldy   OW
:z          lda   #0
            jsr   Raw
            dey
            bne   :z
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

* Sym: a symbol of the fixed literal/length code.
Sym         cmp   #144
            bcs   :s9
            clc
            adc   #$30                  ; 0-143: 8 bits from $30
            ldx   #8
            jmp   BitsRev
:s9         cmp   #256
            bcs   :s7
            clc
            adc   #$190-144             ; 144-255: 9 bits from $190
            ldx   #9
            jmp   BitsRev
:s7         cmp   #280
            bcs   :s8
            sec
            sbc   #256                  ; 256-279: 7 bits from 0
            ldx   #7
            jmp   BitsRev
:s8         sec
            sbc   #280-$C0              ; 280-287: 8 bits from $C0
            ldx   #8
            jmp   BitsRev

* BitsRev: a Huffman code of X bits, highest bit first.
BitsRev     sta   t0
            stx   t1
:bit        lda   t1
            beq   :done
            dec   t1
            ldx   t1
            lda   t0
:sh         cpx   #0
            beq   :b
            lsr
            dex
            bra   :sh
:b          and   #$0001
            jsr   Bit
            bra   :bit
:done       rts

* Bits: the low X bits of A, lowest first.
Bits        sta   t0
:bit        cpx   #0
            beq   :done
            lda   t0
            and   #$0001
            jsr   Bit
            lsr   t0
            dex
            bra   :bit
:done       rts

* Bit: one bit (A = 0 or 1) into the output, lowest bit of each byte first.
Bit         phx
            ldx   BitCnt
            cmp   #0
            beq   :zero
            lda   BitMask,x
            and   #$00FF
            tsb   BitBuf
:zero       inx
            stx   BitCnt
            cpx   #8
            bcc   :done
            lda   BitBuf
            phy
            jsr   CPut
            ply
            stz   BitBuf
            stz   BitCnt
:done       plx
            rts

BitMask     db    1,2,4,8,16,32,64,128,0

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
:pix        cpy   OW
            bcs   :nextLine
            phy
            lda   ShowLine,y
            and   #$00FF
            jsr   LzwChar
            ply
            iny
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
SaveTIFF    jsr   Shown
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
BitBuf      dw    0
BitCnt      dw    0
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
CurRaw      ds    1286                  ; PNG lines (DeflateM): this one,
PrevRaw     ds    1286                  ; the one above
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
HChr        ds    10008
            put   SaveDlg.s
            put   SaveOpts.s
