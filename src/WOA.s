*-------------------------------------------------------------
* WOA.s - Works of Art (Springboard Publisher) pages, as SuperConvert
* reads them (part of the Apple segment; docs/superconvert-formats-extra.md
* section 1): a container of chunks found through a directory; the page
* chosen from its list of names becomes a 270 x 360 monochrome image.
* Unlike the original, bits past the page's right edge are dropped and
* cells past its last strip ignored (its notes (a) and (b)).
*-------------------------------------------------------------

* LoadWOA: the file in fp/flen. The page: the one a test asked for
* (WoaTest), or the one chosen in the original's window.
*   out: carry clear, A = fmtWOA: the monochrome image made (through
*   mblk); carry set, A = an error (errCancel: the window's Cancel)
LoadWOA     lda   flen+2                ; the header: "SS" at 5
            bne   :hdr
            lda   flen
            cmp   #16
            bcs   :hdr
:bad        lda   #errNotPicture
            sec
            rts
:hdr        ldy   #5
            lda   [fp],y
            cmp   #$5353
            bne   :bad
            ldy   #$0B                  ; the directory's entries, the data's
            lda   [fp],y                ; first block
            sta   WN
            ldy   #$0D
            lda   [fp],y
            and   #$00FF
            sta   WB
            lda   WN                    ; (the directory in the file)
            stz   WT+2
            asl
            rol   WT+2
            asl
            rol   WT+2
            asl
            rol   WT+2
            asl
            rol   WT+2
            clc
            adc   #16
            sta   WT
            lda   WT+2
            adc   #0
            sta   WT+2
            jsr   InFileT
            bcs   :bad
            lda   #0                    ; the page names
            ldx   #4
            jsr   Find
            bcc   :names
:var        lda   #errUnsupported
            sec
            rts
:names      lda   CLen                  ; their count (at least 1)
            cmp   #3
            bcc   :var
            ldy   #0
            lda   [p3],y
            beq   :var
            sta   WC
            jsr   Members
            bcc   :jx1
            jmp   :out
:jx1
            lda   WoaPage               ; the page
            beq   :ask
            cmp   WC
            beq   :page
            bcs   :var
            bra   :page
:ask        jsr   PageWin
            bcc   :page
            pha
            jsr   NoMembers
            pla
            sec
            rts
:page       sta   WK
            jsr   KeepName              ; (its name, for the picture's)
            jsr   NoMembers
            lda   WK                    ; its bitmap
            ldx   #$0B
            jsr   Find
            bcs   :var
            lda   CLen                  ; 0, 0, 269, 359 only
            cmp   #10
            bcc   :var
            ldy   #2
            lda   [p3],y
            ldy   #4
            ora   [p3],y
            bne   :var
            ldy   #6
            lda   [p3],y
            cmp   #269
            bne   :var
            ldy   #8
            lda   [p3],y
            cmp   #359
            bne   :var
            jsr   NewPage               ; the monochrome image
            bcs   :out
            jsr   Decode
            bcc   :made
            pha                         ; (damaged: no image)
            PushLongAt WH
            Tool  _DisposeHandle
            pla
            sec
            rts
:made       lda   #1                    ; it is Main's monochrome image now
            sta   [mblk]
            ldy   #2
            lda   WH
            sta   [mblk],y
            iny
            iny
            lda   WH+2
            sta   [mblk],y
            iny
            iny
            lda   p0
            sta   [mblk],y
            iny
            iny
            lda   p0+2
            sta   [mblk],y
            iny
            iny
            lda   #270
            sta   [mblk],y
            iny
            iny
            lda   #360
            sta   [mblk],y
            iny
            iny
            lda   #34
            sta   [mblk],y
            lda   #fmtWOA
            clc
:out        rts

* InFileT: carry clear if WT <= the file's length.
InFileT     lda   flen
            cmp   WT
            lda   flen+2
            sbc   WT+2
            bcc   :no
            clc
            rts
:no         sec
            rts

* Find: the chunk of type A and ID X (the directory searched from its
* last entry, as the original): p3 = its data, CLen its length.
*   out: carry set if there is none (or it runs past the file's end)
Find        sta   FType
            stx   FId
            lda   WN
            sta   FK
:k          lda   FK
            bne   :look
            sec
            rts
:look       dec   FK
            lda   FK
            jsr   DirEnt
            lda   [p2]
            cmp   FType
            bne   :k
            ldy   #2
            lda   [p2],y
            cmp   FId
            bne   :k
            ldy   #8
            lda   [p2],y
            sta   CLen
            lda   WB                    ; its offset: B x 512, then the lengths
            xba                         ; before it
            asl
            sta   WT
            lda   WB
            lsr
            lsr
            lsr
            lsr
            lsr
            lsr
            lsr
            sta   WT+2
            lda   WT
            and   #$FE00
            sta   WT
            stz   FI
:sum        lda   FI
            cmp   FK
            bcs   :at
            jsr   DirEnt
            ldy   #8
            lda   [p2],y
            clc
            adc   WT
            sta   WT
            bcc   :nc
            inc   WT+2
:nc         inc   FI
            bra   :sum
:at         lda   fp                    ; p3 = there
            clc
            adc   WT
            sta   p3
            lda   fp+2
            adc   WT+2
            sta   p3+2
            lda   WT                    ; (all of it in the file)
            clc
            adc   CLen
            sta   WT
            bcc   :in
            inc   WT+2
:in         jsr   InFileT
            rts

* DirEnt: p2 = directory entry A (at 16 + 16 A).
DirEnt      stz   WE+2
            asl
            rol   WE+2
            asl
            rol   WE+2
            asl
            rol   WE+2
            asl
            rol   WE+2
            clc
            adc   #16
            bcc   :n
            inc   WE+2
:n          clc
            adc   fp
            sta   p2
            lda   WE+2
            adc   fp+2
            sta   p2+2
            rts

* Members: the list's members for the WC names (Pascal strings from
* the names chunk's offset 3): a pointer and a flag each, the first
* selected.
*   out: carry set (A = an error) if the names don't fit in the chunk
Members     lda   WC                    ; 5 bytes each
            asl
            asl
            clc
            adc   WC
            sta   WT
            pha
            pha
            PushLong 0
            lda   WT
            sta   1,s
            lda   uid
            pha
            pea   $C018
            PushLong 0
            Tool  _NewHandle
            tax
            pla
            sta   MemH
            pla
            sta   MemH+2
            txa
            bcc   :got
            sec
            rts
:got        lda   MemH
            sta   p2
            lda   MemH+2
            sta   p2+2
            ldy   #2
            lda   [p2],y
            sta   MemP+2
            lda   [p2]
            sta   MemP
            sta   p2
            lda   MemP+2
            sta   p2+2
            lda   #3                    ; each name: where it is, inside
            sta   FI
            ldx   #0
            ldy   #0
:m          cpx   WC
            bcs   :ok
            lda   FI
            cmp   CLen
            bcs   :short
            clc                         ; (its pointer)
            adc   p3
            sta   [p2],y
            iny
            iny
            lda   p3+2
            adc   #0
            sta   [p2],y
            iny
            iny
            lda   #0                    ; (its flag: the first selected)
            cpx   #0
            bne   :flag
            lda   #$80
:flag       sep   #$20
            mx    %10
            sta   [p2],y
            rep   #$20
            mx    %00
            iny
            phy
            ldy   FI                    ; past its characters
            lda   [p3],y
            and   #$00FF
            sec
            adc   FI
            sta   FI
            ply
            inx
            bra   :m
:ok         lda   FI
            cmp   CLen
            beq   :fits
            bcs   :short
:fits       clc
            rts
:short      jsr   NoMembers
            lda   #errCorrupt
            sec
            rts

* NoMembers: the members' block disposed of.
NoMembers   lda   MemH
            ora   MemH+2
            beq   :out
            PushLongAt MemH
            Tool  _DisposeHandle
            stz   MemH
            stz   MemH+2
:out        rts

* KeepName: page WK's name kept (WoaName gives it to Main).
KeepName    lda   MemP
            sta   p2
            lda   MemP+2
            sta   p2+2
            lda   WK                    ; its member
            dec
            sta   WT
            asl
            asl
            clc
            adc   WT
            tay
            lda   [p2],y
            sta   p0
            iny
            iny
            lda   [p2],y
            sta   p0+2
            lda   [p0]
            and   #$00FF
            tax
            ldy   #0
:c          cpy   #31
            bcs   :end
            txa
            beq   :end
            iny
            lda   [p0],y
            sep   #$20
            mx    %10
            sta   PageName-1,y
            rep   #$20
            mx    %00
            dex
            bra   :c
:end        lda   #0
            sep   #$20
            mx    %10
            sta   PageName,y
            rep   #$20
            mx    %00
            rts

* PageWin: the original's window: the list of the pages' names, Cancel
* and OK (a double click on a name is OK too).
*   out: A = the page chosen (1 ...), or carry set, A = errCancel
PageWin     pha
            pha
            PushLong 0
            PushLong 0
            PushLong PwDraw
            PushLong 0
            pea   0
            PushLong PwParms
            pea   $800E
            Tool  _NewWindow2
            pla
            sta   PwWin
            pla
            sta   PwWin+2
            lda   WC                    ; the list
            sta   PwList+8
            lda   MemP
            sta   PwList+28
            lda   MemP+2
            sta   PwList+30
            pha
            pha
            PushLongAt PwWin
            PushLong PwList
            Tool  _CreateList
            pla
            sta   PwCtl
            pla
            sta   PwCtl+2
            PushLongAt PwWin
            Tool  _ShowWindow
:loop       PushLongAt PwWin
            Tool  _SetPort
            pha
            pea   $FFFF
            PushLong PwTask
            Tool  _TaskMaster
            pla
            cmp   #wInControl
            bne   :loop
            lda   PwTask+$1E            ; the list: a double click is OK
            cmp   PwCtl
            bne   :btn
            lda   PwTask+$20
            cmp   PwCtl+2
            bne   :btn
            lda   PwTask+$1C
            cmp   #2
            bcc   :loop
            pea   2                     ; (OK flashes)
            pea   $0000
            pea   $0001
            jsr   PwCtlH
            Tool  _HiliteControl
            pea   0
            pea   $0000
            pea   $0001
            jsr   PwCtlH
            Tool  _HiliteControl
            bra   :ok
:btn        pha
            pha
            PushLongAt PwTask+$1E
            Tool  _GetCtlID
            pla
            plx
            cmp   #2
            beq   :cancel
            cmp   #1
            beq   :jx2
            jmp   :loop
:jx2
:ok         lda   MemP                  ; the name selected (the members
            sta   p2                    ; again: drawing other windows may use
            lda   MemP+2                ; the direct page)
            sta   p2+2
            ldx   #0
            ldy   #4
:s          cpx   WC
            bcs   :none
            lda   [p2],y                ; (p2: the members)
            and   #$0080
            bne   :sel
            iny
            iny
            iny
            iny
            iny
            inx
            bra   :s
:none       ldx   #0                    ; (none: the first)
:sel        inx
            phx
            jsr   :close
            pla
            clc
            rts
:cancel     jsr   :close
            lda   #errCancel
            sec
            rts
:close      PushLongAt PwWin
            Tool  _CloseWindow
            rts

* PwCtlH: the window's control whose ID is on the stack (a long, under
* the return address) replaced by its handle.
PwCtlH      pha
            pha
            PushLongAt PwWin
            lda   13,s
            pha
            lda   13,s
            pha
            Tool  _GetCtlHandleFromID
            pla
            sta   5,s
            pla
            sta   5,s
            rts

* PwDraw: the window's contents: its controls.
PwDraw      phb
            phk
            plb
            pha
            pha
            Tool  _GetPort
            Tool  _DrawControls
            plb
            rtl

* NewPage: a new 270 x 360 monochrome image, all black (34 bytes a row,
* and a little more): its handle WH, p0 its bytes. The one
* there was goes first.
*   out: carry set, A = the error, if there was no memory
NewPage     lda   [mblk]
            beq   :new
            ldy   #2
            lda   [mblk],y
            tax
            iny
            iny
            lda   [mblk],y
            pha
            phx
            Tool  _DisposeHandle
            lda   #0
            sta   [mblk]
:new        pha
            pha
            PushLong 12242
            lda   uid
            pha
            pea   $C018
            PushLong 0
            Tool  _NewHandle
            tax
            pla
            sta   WH
            pla
            sta   WH+2
            txa
            bcc   :got
            rts
:got        lda   WH
            sta   p0
            lda   WH+2
            sta   p0+2
            ldy   #2
            lda   [p0],y
            tax
            lda   [p0]
            sta   p0
            stx   p0+2
            lda   #0
            ldy   #12240
:z          sta   [p0],y
            dey
            dey
            bpl   :z
            clc
            rts

* Decode: page chunk p3 (CLen bytes, a 10-byte header) into the image at
* p0: codes of cells (7 pixels across, bit 0 leftmost), going down the
* first 7-pixel strip, up the second, and so on.
*   out: carry set, A = errCorrupt, if the data ends inside a code
Decode      lda   #10
            sta   DI
            stz   Strip
            stz   DY
            stz   DRow
            lda   #1
            sta   Down
:code       lda   DI
            cmp   CLen
            bcc   :byte
            clc
            rts
:byte       jsr   WNext
            cmp   #$80
            bcs   :run
            jsr   Put                   ; a cell
            bra   :code
:run        pha                         ; a run: its pattern's length L
            lsr
            lsr
            lsr
            lsr
            and   #$0007
            inc
            sta   PL
            pla
            and   #$000F                ; and how many times, less one
            cmp   #8
            bcc   :count
            and   #$0007
            xba
            sta   PN
            lda   DI
            cmp   CLen
            bcs   :eof
            jsr   WNext
            ora   PN
:count      sta   PN
            lda   DI                    ; the pattern
            sta   PAt
            clc
            adc   PL
            bcs   :eof
            cmp   CLen
            beq   :pat
            bcs   :eof
:pat        sta   DI
:rep        ldx   #0
:pc         phx
            txa
            clc
            adc   PAt
            tay
            lda   [p3],y
            jsr   Put
            plx
            inx
            cpx   PL
            bcc   :pc
            lda   PN
            beq   :code
            dec   PN
            bra   :rep
:eof        lda   #errCorrupt
            sec
            rts

* WNext: A = the next byte of the chunk.
WNext        ldy   DI
            lda   [p3],y
            and   #$00FF
            inc   DI
            rts

* Put: cell A (its low 7 bits) at strip Strip, row DY; then the next
* place (down, or up, the strip; past its end, the next strip).
Put         ldx   Strip
            cpx   #39
            bcs   :out                  ; (past the last strip: dropped)
            and   #$007F
            beq   :move
            sta   PCell
            txa                         ; the strip's left edge
            asl
            tax
            lda   X7,x
            sta   PX
            ldx   #0
:bit        lsr   PCell
            bcc   :nb
            txa
            clc
            adc   PX
            cmp   #270                  ; (past the right edge: dropped)
            bcs   :nb
            phx
            pha
            lsr
            lsr
            lsr
            clc
            adc   DRow
            tay
            pla
            and   #$0007
            asl
            tax
            lda   WBits,x
            sep   #$20
            mx    %10
            ora   [p0],y
            sta   [p0],y
            rep   #$20
            mx    %00
            plx
:nb         inx
            lda   PCell
            bne   :bit
:move       lda   Down
            beq   :up
            lda   DY
            cmp   #359
            bcs   :turn
            inc   DY
            lda   DRow
            clc
            adc   #34
            sta   DRow
:out        rts
:up         lda   DY
            beq   :turn
            dec   DY
            lda   DRow
            sec
            sbc   #34
            sta   DRow
            rts
:turn       inc   Strip
            lda   Down
            eor   #1
            sta   Down
            rts

* WoaName: the page's name (a C string, at most 24 characters) at dname.
WoaName     ent
            phb
            phk
            plb
            ldy   #0
:c          lda   PageName,y
            and   #$00FF
            cpy   #24
            bcc   :put
            lda   #0
:put        sep   #$20
            mx    %10
            sta   [dname],y
            rep   #$20
            mx    %00
            iny
            cmp   #0
            bne   :c
            plb
            rtl

* WoaTest: for tests: page A loaded without the window (0: the window).
WoaTest     ent
            phb
            phk
            plb
            sta   WoaPage
            plb
            rtl

WoaPage     dw    0
WN          dw    0                     ; the directory's entries
WB          dw    0                     ; the data's first block (512 bytes)
WC          dw    0                     ; the pages
WK          dw    0                     ; the page chosen
WT          adrl  0
WE          adrl  0
WH          adrl  0                     ; the image's handle
FType       dw    0
FId         dw    0
FK          dw    0
FI          dw    0
CLen        dw    0                     ; the chunk's length
MemH        adrl  0                     ; the list's members
MemP        adrl  0
DI          dw    0                     ; Decode: where in the chunk
Strip       dw    0
DY          dw    0
DRow        dw    0                     ; (DY x 34)
Down        dw    0
PL          dw    0
PN          dw    0
PAt         dw    0
PCell       dw    0
PX          dw    0
PageName    ds    34
X7          dw    0,7,14,21,28,35,42,49,56,63,70,77,84,91,98,105,112,119,126
            dw    133,140,147,154,161,168,175,182,189,196,203,210,217,224,231,238
            dw    245,252,259,266
WBits        dw    $80,$40,$20,$10,$08,$04,$02,$01
PwWin       adrl  0
PwCtl       adrl  0
* The window (SuperConvert's FRED $B2C5): alert frame
PwParms     dw    $50,$2000
            adrl  0,0
            dw    0,0,0,0
            adrl  0
            dw    0,0,0,0,0,0,0,0,0,0
            adrl  0
            dw    0
            adrl  0,0,0
            dw    40,110,150,510
            adrl  $FFFFFFFF
            adrl  PwCtls
            dw    $0003
PwCtls      adrl  PwText,PwCancel,PwOK,0
PwText      dw    9
            adrl  0
            dw    5,270,25,390
            adrl  $81000000
            dw    0,$1000
            adrl  0
            adrl  TxPwText
            dw    TxPwTextEnd-TxPwText,0
PwCancel    dw    9
            adrl  2
            dw    70,280,85,380
            adrl  $80000000
            dw    0,$3000
            adrl  0
            adrl  TxPwCancel
            adrl  0
            db    $1B,$1B
            dw    0,0
PwOK        dw    9
            adrl  1
            dw    90,280,105,380
            adrl  $80000000
            dw    $0001,$3000
            adrl  0
            adrl  TxPwOK
            adrl  0
            db    $0D,$0D
            dw    0,0
TxPwText    asc   'Select page',0D,'to be loaded:'
TxPwTextEnd
TxPwCancel  str   'Cancel'
TxPwOK      str   'OK'
* The list (List Manager record): rect, size, rows shown, type (2: one
* at a time), first shown, control, draw routine (0: the standard one),
* row height, member size, members, refCon, scroll bar colours
PwList      dw    4,10,106,260
            dw    0,10,2,1
            adrl  0
            adrl  0
            dw    10,5
            adrl  0
            adrl  0
            adrl  0
PwTask      dw    0                     ; TaskMaster's record
            adrl  0,0
            dw    0,0,0
            adrl  0
            adrl  $001B0006             ; updates, controls, double clicks
            adrl  0
            dw    0
            adrl  0,0,0
            ds    16
