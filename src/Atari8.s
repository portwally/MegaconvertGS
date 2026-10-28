*-------------------------------------------------------------
* Atari8.s - Atari 8-bit pictures (part of the Other segment): screen
* memory, 40 bytes a line (at most 200 lines are kept). Screen images.
*   MicroPainter (.MIC): Graphics 15, 160 wide in 4 colours (2 bits a
*   pixel, shown twice as wide), then the colour registers background,
*   playfield 0, 1, 2 if the file has 4 bytes more; else greys.
*   Graphics 8 (.GR8): 320 wide in 2 colours, black and white.
*   Graphics 9 (.GR9): 80 wide in 16 greys (4 bits a pixel, four times
*   as wide).
* The colours come from A8Pal, an approximation of the Atari's 256.
*-------------------------------------------------------------

* LoadMIC: out: carry clear, or carry set and A = error
LoadMIC     jsr   A8Lines               ; (40 bytes a line, or 4 more)
            bcc   :ok
            rts
:ok         ldx   #6                    ; colours: the file's, or greys
:def        lda   A8Gr15,x
            sta   A8Regs,x
            dex
            dex
            bpl   :def
            lda   A8Extra
            cmp   #4
            bne   :pal
            ldx   #0                    ; background, playfield 0, 1, 2
            lda   A8Len
            tay
:reg        lda   [fp],y
            and   #$00FF
            sta   A8Regs,x
            iny
            inx
            inx
            cpx   #8
            bcc   :reg
:pal        ldx   #0                    ; their Super Hi-Res colours
:pc         lda   A8Regs,x
            asl
            tay
            lda   A8Pal,y
            sta   A8Table,x
            inx
            inx
            cpx   #8
            bcc   :pc
            jsr   A8Begin
:row        ldx   #0
            jsr   A8Line                ; (Y: the line's first byte)
:byte       lda   [fp],y
            and   #$00FF
            sta   t3
            lda   #4                    ; 4 pixels of 2 bits, each twice
            sta   t2
:px         lda   t3
            and   #$00C0
            asl
            asl
            xba
            jsr   A8Put
            jsr   A8Put
            asl   t3
            asl   t3
            dec   t2
            bne   :px
            iny
            cpx   #320
            bcc   :byte
            jsr   A8Next
            bcc   :row
            clc
            rts

* LoadGR8: 1 bit a pixel, white on black.
LoadGR8     jsr   A8Lines
            bcc   :ok
            rts
:ok         stz   A8Table               ; black and white
            lda   #$FFF
            sta   A8Table+2
            jsr   A8Begin
:row        ldx   #0
            jsr   A8Line
:byte       lda   [fp],y
            and   #$00FF
            sta   t3
            lda   #8
            sta   t2
:px         asl   t3
            lda   t3
            xba
            and   #$0001
            jsr   A8Put
            dec   t2
            bne   :px
            iny
            cpx   #320
            bcc   :byte
            jsr   A8Next
            bcc   :row
            clc
            rts

* LoadGR9: 4 bits a pixel, 16 greys, each pixel four times as wide.
LoadGR9     jsr   A8Lines
            bcc   :ok
            rts
:ok         ldx   #30                   ; grey n: $nnn
:grey       txa
            lsr
            sta   t1
            asl
            asl
            asl
            asl
            ora   t1
            asl
            asl
            asl
            asl
            ora   t1
            sta   A8Table,x
            dex
            dex
            bpl   :grey
            jsr   A8Begin
:row        ldx   #0
            jsr   A8Line
:byte       lda   [fp],y
            and   #$00FF
            sta   t3
            lsr
            lsr
            lsr
            lsr
            jsr   A8Put4
            lda   t3
            and   #$000F
            jsr   A8Put4
            iny
            cpx   #320
            bcc   :byte
            jsr   A8Next
            bcc   :row
            clc
            rts

* A8Lines: the file's lines: A8Len = 40 x lines (A8Extra the bytes after
* them: 0, or 4 colour registers), at most 240 lines. Carry set, A = error
* if the file isn't so.
A8Lines     lda   flen+2
            bne   :bad
            lda   flen
            cmp   #40
            bcc   :bad
            cmp   #40*240+5
            bcs   :bad
            ldx   #40                   ; lines = len / 40
            stx   t1
            ldx   #0
:div        cmp   t1
            bcc   :rest
            sec
            sbc   t1
            inx
            bra   :div
:rest       sta   A8Extra
            cmp   #0
            beq   :ok
            cmp   #4
            bne   :bad
:ok         stx   A8Rows
            lda   flen
            sec
            sbc   A8Extra
            sta   A8Len
            clc
            rts
:bad        lda   #errNotPicture
            sec
            rts

* A8Begin: an empty screen image, 320 wide, colours A8Table.
A8Begin     jsr   ScrBegin
            ldx   #A8Table
            jsr   SetTable0
            stz   Is640
            lda   #320
            sta   PixW
            stz   RowY
            rts

* A8Line: Y = the first byte of line RowY.
A8Line      lda   RowY
            asl
            asl
            asl
            sta   t1                    ; x 8
            asl
            asl
            clc
            adc   t1                    ; x 40
            tay
            rts

* A8Next: the line done. Carry clear: on to the next; set: the last.
A8Next      jsr   PackRow
            inc   RowY
            lda   RowY
            cmp   A8Rows
            bcs   :done
            cmp   #200
:done       rts

* A8Put: pixel A (a colour table entry) at X; X on. A8Put4: four of them.
A8Put4      jsr   A8Put
            jsr   A8Put
            jsr   A8Put
A8Put       sep   #$20
            mx    %10
            sta   RowPix,x
            rep   #$20
            mx    %00
            inx
            rts

* Graphics 15's colours when the file has none: background, playfields.
A8Gr15      dw    $00,$04,$08,$0C
A8Regs      ds    8
A8Table     ds    32
A8Len       dw    0
A8Extra     dw    0
A8Rows      dw    0

* The Atari 8-bit's colours by register value (test/make_atari8_pal.py).
A8Pal       dw    $000,$000,$222,$222,$444,$444,$666,$666
            dw    $999,$999,$BBB,$BBB,$DDD,$DDD,$FFF,$FFF
            dw    $210,$210,$541,$541,$862,$862,$B83,$B83
            dw    $CA4,$CA4,$DB7,$DB7,$EDA,$EDA,$FED,$FED
            dw    $210,$210,$521,$521,$832,$832,$B53,$B53
            dw    $C74,$C74,$D97,$D97,$EBA,$EBA,$FDD,$FDD
            dw    $201,$201,$512,$512,$823,$823,$B34,$B34
            dw    $C45,$C45,$D78,$D78,$EAB,$EAB,$FDD,$FDD
            dw    $201,$201,$513,$513,$825,$825,$B37,$B37
            dw    $C49,$C49,$D7A,$D7A,$EAC,$EAC,$FDE,$FDE
            dw    $202,$202,$515,$515,$827,$827,$B3A,$B3A
            dw    $C4C,$C4C,$D7D,$D7D,$EAE,$EAE,$FDE,$FDE
            dw    $102,$102,$415,$415,$628,$628,$83B,$83B
            dw    $A4C,$A4C,$B7D,$B7D,$DAE,$DAE,$EDF,$EDF
            dw    $102,$102,$215,$215,$328,$328,$53B,$53B
            dw    $74C,$74C,$97D,$97D,$BAE,$BAE,$DDF,$DDF
            dw    $012,$012,$125,$125,$238,$238,$34B,$34B
            dw    $45C,$45C,$78D,$78D,$ABE,$ABE,$DDF,$DDF
            dw    $012,$012,$135,$135,$258,$258,$37B,$37B
            dw    $49C,$49C,$7AD,$7AD,$ACE,$ACE,$DEF,$DEF
            dw    $022,$022,$155,$155,$278,$278,$3AB,$3AB
            dw    $4CC,$4CC,$7DD,$7DD,$AEE,$AEE,$DEF,$DEF
            dw    $021,$021,$154,$154,$286,$286,$3B8,$3B8
            dw    $4CA,$4CA,$7DB,$7DB,$AED,$AED,$DFE,$DFE
            dw    $021,$021,$152,$152,$283,$283,$3B5,$3B5
            dw    $4C7,$4C7,$7D9,$7D9,$AEB,$AEB,$DFD,$DFD
            dw    $120,$120,$251,$251,$382,$382,$4B3,$4B3
            dw    $5C4,$5C4,$8D7,$8D7,$BEA,$BEA,$DFD,$DFD
            dw    $120,$120,$351,$351,$582,$582,$7B3,$7B3
            dw    $9C4,$9C4,$AD7,$AD7,$CEA,$CEA,$EFD,$EFD
            dw    $220,$220,$551,$551,$782,$782,$AB3,$AB3
            dw    $CC4,$CC4,$DD7,$DD7,$EEA,$EEA,$EFD,$EFD
