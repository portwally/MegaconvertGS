*-------------------------------------------------------------
* ImgTools.s - the image window's tools, as SuperConvert's (part of the
* Desk segment; docs/superconvert-image-window.md 4.5, 5.4, 5.5, 6, 7.4,
* 7.5 and 8): the selection with its marching ants, pixel peek, the
* pointer's shapes over the picture, the tool and action pop-ups, and the
* keys.
*
* Selections are kept for each image type in image units (SelImg, by
* type) and, for the type shown, in window units (SelWin). The main
* program reads them with DeskSel.
*-------------------------------------------------------------

* SelInit: the shown type's selection and the snap steps, after a change
* of image, type, zoom or pixel size (ImgChanged; Units has run).
SelInit     lda   #4                    ; snap: a byte for the screen image,
            ldx   Shown                 ; a pixel for the others
            cpx   #2
            bcc   :step
            jsr   Shape
            lda   #2
            ldx   ImgPix
            beq   :step
            lda   #1
:step       eor   #$FFFF                ; maskX = Act2Zoom(-step)
            inc
            jsr   A2Z
            sta   MaskX
            eor   #$FFFF
            inc
            lsr
            sta   HalfX
            lda   #$FFFF                ; maskY = Act2Zoom(-1)
            jsr   A2Z
            sta   MaskY
            eor   #$FFFF
            inc
            lsr
            sta   HalfY
            jsr   SelIndex
            lda   SelFlag,x
            sta   HasSel
            bne   :have
            lda   #0                    ; none: the whole image
            sta   SelImg,y
            sta   SelImg+2,y
            lda   UnitsH
            sta   SelImg+4,y
            lda   UnitsW
            sta   SelImg+6,y
:have       jsr   SelToWin
            lda   #$8000                ; no pixel peeked yet
            sta   PeekX
            sta   PeekY
            rts

* SelIndex: X = 2 x the shown type, Y = 8 x the shown type.
SelIndex    lda   Shown
            asl
            tax
            asl
            asl
            tay
            rts

* SelToWin: SelWin from the shown type's stored selection.
SelToWin    jsr   SelIndex
            lda   SelImg,y
            jsr   A2Z
            sta   SelWin
            lda   SelImg+2,y
            jsr   A2Z
            sta   SelWin+2
            lda   SelImg+4,y
            jsr   A2ZR
            sta   SelWin+4
            lda   SelImg+6,y
            jsr   A2ZR
            sta   SelWin+6
            rts

* Store: the shown type's selection flag and rectangle (image units) from
* HasSel and SelWin.
Store       jsr   SelIndex
            lda   HasSel
            sta   SelFlag,x
            lda   SelWin
            jsr   Z2A
            sta   SelImg,y
            lda   SelWin+2
            jsr   Z2A
            sta   SelImg+2,y
            lda   SelWin+4
            jsr   Z2AR
            cmp   UnitsH
            bcc   :b
            lda   UnitsH
:b          sta   SelImg+4,y
            lda   SelWin+6
            jsr   Z2AR
            cmp   UnitsW
            bcc   :r
            lda   UnitsW
:r          sta   SelImg+6,y
            rts

* DeskSel: the selection of image type A (1 screen, 2 true colour, 3
* monochrome): dsel = 1 if it has one, dselr = its rectangle in image
* units (the whole image without one).
DeskSel     ent
            phb
            phk
            plb
            asl
            tax
            asl
            asl
            tay
            lda   SelFlag,x
            sta   dsel
            lda   PixSize,x             ; (units a pixel: 640 sized 1, 320 2)
            eor   #1
            inc
            sta   dselu
            ldx   #0
:r          lda   SelImg,y
            sta   dselr,x
            iny
            iny
            inx
            inx
            cpx   #8
            bcc   :r
            plb
            rtl

* DeskTop: the picture's top left in view (after a crop).
DeskTop     ent
            phb
            phk
            plb
            lda   ScrWin
            ora   ScrWin+2
            beq   :out
            pea   0
            pea   0
            PushLongAt ScrWin
            Tool  _SetContentOrigin
:out        plb
            rtl

* DeskSelClear: the selection of type A goes (its image was replaced; 0:
* every type's).
DeskSelClear ent
            phb
            phk
            plb
            cmp   #0
            bne   :one
            jsr   SelClear
            bra   :out
:one        asl
            tax
            stz   SelFlag,x
            stz   HasSel
:out        plb
            rtl
SelClear    stz   SelFlag+2
            stz   SelFlag+4
            stz   SelFlag+6
            stz   HasSel
            rts

*-------------------------------------------------------------
* The frame and its marching ants (4.5)
*-------------------------------------------------------------

* Frame: SelWin framed with pen 2 x 1 in XOR mode and the pattern at A (in
* this bank); drawing it again with the same pattern removes it.
Frame       pha
            pea   2
            pea   1
            Tool  _SetPenSize
            pea   2                     ; XOR
            Tool  _SetPenMode
            pla
            pea   ^AntsTab
            pha
            Tool  _SetPenPat
            PushLong SelWin
            Tool  _FrameRect
            Tool  _PenNormal
            rts

* DrawAnts: the frame with the ants as they are now (ANTS[phase]).
DrawAnts    lda   Phase
            asl
            asl
            asl
            asl
            asl
            clc
            adc   #AntsTab
            jmp   Frame

* DrawFrame: the frame of SelWin, if it has a height and a width
* (HasSel = 1); otherwise nothing (HasSel = 0).
DrawFrame   stz   HasSel
            lda   SelWin+4
            cmp   SelWin
            beq   :none
            lda   SelWin+6
            cmp   SelWin+2
            beq   :none
            inc   HasSel
            jsr   DrawAnts
:none       rts

* StepAnts: the ants move on (STEP[phase] turns the frame into the next
* pattern in place).
StepAnts    lda   Phase
            asl
            asl
            asl
            asl
            asl
            clc
            adc   #AntsTab+16
            jsr   Frame
NextPhase   lda   Phase
            inc
            and   #3
            sta   Phase
            pha                         ; (when)
            pha
            Tool  _GetTick
            pla
            sta   AntTick
            pla
            sta   AntTick+2
            rts

* AntsDue: carry set if 6 ticks or more passed since the last step.
AntsDue     pha
            pha
            Tool  _GetTick
            pla
            sec
            sbc   AntTick
            tax
            pla
            sbc   AntTick+2
            bne   :due                  ; (a long time)
            cpx   #6
            rts
:due        sec
            rts

* DeskIdle: a null event: the ants march.
DeskIdle    ent
            phb
            phk
            plb
            lda   HasSel
            beq   :out
            lda   ScrWin
            ora   ScrWin+2
            beq   :out
            jsr   AntsDue
            bcc   :out
            jsr   WinDraw
            jsr   StepAnts
            jsr   WinDone
:out        plb
            rtl

* WinDraw: drawing in the window's content (content coordinates), the
* port in use kept; WinDone: back to it.
WinDraw     pha
            pha
            Tool  _GetPort
            pla
            sta   OldPort
            pla
            sta   OldPort+2
            PushLongAt ScrWin
            Tool  _StartDrawing
            rts
WinDone     pea   0
            pea   0
            Tool  _SetOrigin
            PushLongAt OldPort
            Tool  _SetPort
            rts

*-------------------------------------------------------------
* The pointer (6.1)
*-------------------------------------------------------------

* DeskCursor: before each TaskMaster call: the pointer's shape for where
* it is (only over the front image window's content), and the image's
* colours there (Use image's palette).
DeskCursor  ent
            phb
            phk
            plb
            pha                         ; where the pointer is
            pea   0
            PushLong CurEv
            Tool  _GetNextEvent
            pla
            pha
            PushLong CurWin
            lda   CurEv+12              ; (h, v)
            pha
            lda   CurEv+10
            pha
            Tool  _FindWindow
            pla
            sta   CurPart
            stz   iw1                   ; the shape: 0 the arrow
            lda   ScrWin
            ora   ScrWin+2
            beq   :palOut
            lda   CurPart
            cmp   #wInContent
            bne   :palOut
            lda   CurWin
            cmp   ScrWin
            bne   :palOut
            lda   CurWin+2
            cmp   ScrWin+2
            bne   :palOut
            jsr   EnterPals             ; over the picture
            pha
            pha
            Tool  _FrontWindow
            pla
            plx
            cmp   ScrWin
            bne   :set
            cpx   ScrWin+2
            bne   :set
            lda   #10                   ; pixel peek
            ldx   ToolNo
            cpx   #2
            beq   :code
            lda   #11                   ; a new selection
            ldx   HasSel
            beq   :code
            jsr   WinDraw               ; the pointer in content coordinates
            lda   CurEv+10
            sta   ZPt
            lda   CurEv+12
            sta   ZPt+2
            PushLong ZPt
            Tool  _GlobalToLocal
            jsr   WinDone
            lda   CurEv+14
            sta   ZMods
            jsr   Zones
:code       sta   iw1
            bra   :set
:palOut     jsr   ExitPals
:set        lda   iw1
            cmp   CurCode
            beq   :out
            sta   CurCode
            asl
            tax
            lda   CurTab,x
            bne   :shape
            Tool  _InitCursor
            bra   :out
:shape      pea   ^Cur1
            pha
            Tool  _SetCursor
:out        plb
            rtl

* Zones: the shape's code for the pointer at ZPt (content coordinates;
* ZMods its modifiers) near or in SelWin: the corners and edges (in the
* numeric keypad's layout), inside (5) or outside (11); with Option the
* nearest corner.
Zones       lda   ZMods                 ; Option: the nearest corner
            and   #$0800
            beq   :zones
            ldx   #1
            lda   SelWin+2
            clc
            adc   SelWin+6
            lsr
            cmp   ZPt+2
            bcs   :hz
            ldx   #3
:hz         stx   iw2
            ldx   #4
            lda   SelWin
            clc
            adc   SelWin+4
            lsr
            cmp   ZPt
            bcs   :vz
            ldx   #12
:vz         txa
            bra   :code
:zones      ldx   #1                    ; across: within 6 of the left edge,
            lda   ZPt+2                 ; of the right edge, between, outside
            sec
            sbc   SelWin+2
            clc
            adc   #6
            cmp   #12
            bcc   :h
            ldx   #3
            lda   ZPt+2
            sec
            sbc   SelWin+6
            clc
            adc   #6
            cmp   #12
            bcc   :h
            ldx   #0
            lda   ZPt+2
            cmp   SelWin+2
            bmi   :h
            cmp   SelWin+6
            bpl   :h
            ldx   #2
:h          stx   iw2
            ldx   #4                    ; down: within 3 of the top, of the
            lda   ZPt                   ; bottom, between, outside
            sec
            sbc   SelWin
            clc
            adc   #3
            cmp   #6
            bcc   :v
            ldx   #12
            lda   ZPt
            sec
            sbc   SelWin+4
            clc
            adc   #3
            cmp   #6
            bcc   :v
            ldx   #0
            lda   ZPt
            cmp   SelWin
            bmi   :v
            cmp   SelWin+4
            bpl   :v
            ldx   #8
:v          txa
:code       clc
            adc   iw2
            tax
            lda   ZoneCodes,x
            and   #$00FF
            rts

*-------------------------------------------------------------
* Clicks in the picture (6.2, 6.3)
*-------------------------------------------------------------

* DeskContent: a click in the image window's content (dctl: where, global
* v and h; dclk: the click count): a new selection, its corners, edges or
* itself moved, or pixel peek while the button is down.
DeskContent ent
            phb
            phk
            plb
            lda   CurCode
            bne   :go
            plb
            rtl
:go         jsr   Updates               ; (the window drawn first)
            jsr   WinDraw
            lda   dctl                  ; the click in content coordinates
            sta   Mouse
            lda   dctl+2
            sta   Mouse+2
            PushLong Mouse
            Tool  _GlobalToLocal
            jsr   Click
            plb
            rtl

* Click: a click at Mouse (content coordinates; the window drawing).
Click       lda   dclk                  ; a double click outside: all of it
            cmp   #2
            bne   :single
            lda   CurCode
            cmp   #11
            bne   :single
            jsr   SelIndex
            lda   #0
            sta   SelImg,y
            sta   SelImg+2,y
            lda   UnitsH
            sta   SelImg+4,y
            lda   UnitsW
            sta   SelImg+6,y
            lda   #1
            sta   SelFlag,x
            jsr   SelToWin
            jsr   DrawFrame
            jsr   Store
            jsr   InfoTxt
            jmp   :end
:single     lda   Mouse                 ; the fixed point: the click, snapped
            sta   Pt
            lda   Mouse+2
            sta   Pt+2
            jsr   Snap
            lda   Pt
            sta   Anchor
            lda   Pt+2
            sta   Anchor+2
            lda   HasSel                ; no selection yet: none to erase
            bne   :kind
            stz   SelWin+2
            stz   SelWin+6
            jsr   SelIndex
            lda   #0
            sta   SelImg+2,y
            sta   SelImg+6,y
:kind       lda   CurCode               ; corners: the opposite one stays
            ldx   SelWin
            ldy   SelWin+4
            cmp   #1
            beq   :top
            cmp   #3
            beq   :top
            cmp   #2
            beq   :top
            cmp   #7
            beq   :bottom
            cmp   #9
            beq   :bottom
            cmp   #8
            beq   :bottom
            bra   :across
:top        stx   Anchor
            bra   :across
:bottom     sty   Anchor
:across     ldx   SelWin+2
            ldy   SelWin+6
            cmp   #1
            beq   :right
            cmp   #7
            beq   :right
            cmp   #4
            beq   :right
            cmp   #3
            beq   :left
            cmp   #9
            beq   :left
            cmp   #6
            beq   :left
            bra   :loop
:right      sty   Anchor+2
            bra   :loop
:left       stx   Anchor+2
:loop       jsr   GetPt                 ; where the pointer is now
            lda   CurCode
            cmp   #10
            bne   :sel
            jsr   Peek
            jmp   :next
:sel        jsr   Snap
            jsr   NewRect               ; NewSel from the kind of change
            ldx   #6
:same       lda   NewSel,x
            cmp   SelWin,x
            bne   :changed
            dex
            dex
            bpl   :same
            jsr   AntsDue               ; the same: the ants march
            bcc   :next
            lda   HasSel
            beq   :next
            jsr   StepAnts
            bra   :next
:changed    jsr   DrawFrame             ; the old frame off
            ldx   #6
:copy       lda   NewSel,x
            sta   SelWin,x
            dex
            dex
            bpl   :copy
            jsr   AntsDue
            bcc   :draw
            jsr   NextPhase
:draw       jsr   DrawFrame             ; the new one on
            jsr   Store
            jsr   InfoTxt
:next       jsr   AutoScroll
            jsr   Still
            bcc   :up
            jmp   :loop
:up         lda   CurCode
            cmp   #10
            beq   :end
            lda   HasSel                ; none: the whole image again
            bne   :store
            stz   SelWin
            stz   SelWin+2
            lda   ZoomH
            sta   SelWin+4
            lda   ZoomW
            sta   SelWin+6
:store      jsr   Store
:end        jsr   WinDone
            stz   ScriptN
            rts

* GetPt: Pt = where the pointer is (content coordinates); in a test, the
* drag's next point.
GetPt       lda   ScriptN
            bne   :script
            PushLong Pt
            Tool  _GetMouse
            rts
:script     ldy   ScriptI
            lda   [ScriptP],y
            sta   Pt
            iny
            iny
            lda   [ScriptP],y
            sta   Pt+2
            rts

* Still: carry set while the button is down; in a test, while the drag
* has points left.
Still       lda   ScriptN
            bne   :script
            pha
            pea   0
            Tool  _StillDown
            pla
            cmp   #1
            rts
:script     lda   ScriptI
            clc
            adc   #4
            sta   ScriptI
            cmp   ScriptN
            bcs   :done                 ; (no more points: up)
            sec
            rts
:done       clc
            rts

* Snap: Pt rounded to the nearest pixel boundary of the shown image, kept
* within the picture.
Snap        lda   Pt
            clc
            adc   HalfY
            and   MaskY
            bpl   :v0
            lda   #0
:v0         cmp   ZoomH
            bcc   :v1
            lda   ZoomH
            and   MaskY
:v1         sta   Pt
            lda   Pt+2
            clc
            adc   HalfX
            and   MaskX
            bpl   :h0
            lda   #0
:h0         cmp   ZoomW
            bcc   :h1
            lda   ZoomW
            and   MaskX
:h1         sta   Pt+2
            rts

* NewRect: NewSel for the pointer at Pt: the selection moved (kept inside
* the picture), spanned by Anchor and Pt (a new one, or a corner), or one
* pair of edges changed.
NewRect     ldx   #6
:c          lda   SelWin,x
            sta   NewSel,x
            dex
            dex
            bpl   :c
            lda   CurCode
            cmp   #5
            bne   :notMove
            lda   Pt                    ; moved by the pointer's move
            sec
            sbc   Mouse
            sta   iw2
            lda   Pt+2
            sec
            sbc   Mouse+2
            sta   iw3
            lda   Pt
            sta   Mouse
            lda   Pt+2
            sta   Mouse+2
            lda   NewSel
            clc
            adc   iw2
            sta   NewSel
            lda   NewSel+4
            clc
            adc   iw2
            sta   NewSel+4
            lda   NewSel+2
            clc
            adc   iw3
            sta   NewSel+2
            lda   NewSel+6
            clc
            adc   iw3
            sta   NewSel+6
            lda   NewSel+2              ; back inside: left first, then
            bpl   :l                    ; right, top, bottom
            eor   #$FFFF
            inc
            jsr   AddH
:l          lda   NewSel+6
            sec
            sbc   ZoomW
            bmi   :r
            beq   :r
            eor   #$FFFF
            inc
            jsr   AddH
:r          lda   NewSel
            bpl   :t
            eor   #$FFFF
            inc
            jsr   AddV
:t          lda   NewSel+4
            sec
            sbc   ZoomH
            bmi   :b
            beq   :b
            eor   #$FFFF
            inc
            jsr   AddV
:b          rts
:notMove    cmp   #2                    ; the top or bottom edge
            beq   :vert
            cmp   #8
            beq   :vert
            cmp   #4                    ; the left or right edge
            beq   :horz
            cmp   #6
            beq   :horz
            jsr   :vert                 ; a corner or a new one: both pairs
:horz       lda   Anchor+2
            ldx   Pt+2
            jsr   Sort
            sta   NewSel+2
            stx   NewSel+6
            rts
:vert       lda   Anchor
            ldx   Pt
            jsr   Sort
            sta   NewSel
            stx   NewSel+4
            rts

* Sort: A, X in order (A the smaller).
Sort        stx   iw2
            cmp   iw2
            bcc   :ok
            tay
            txa
            tyx
:ok         rts

AddH        pha
            clc
            adc   NewSel+2
            sta   NewSel+2
            pla
            clc
            adc   NewSel+6
            sta   NewSel+6
            rts
AddV        pha
            clc
            adc   NewSel
            sta   NewSel
            pla
            clc
            adc   NewSel+4
            sta   NewSel+4
            rts

* Peek: the pixel under the pointer (Pt) is the one whose value the info
* bar shows.
Peek        lda   Pt+2
            jsr   Z2A
            cmp   #$8000
            bcc   :x0
            lda   #0
:x0         cmp   UnitsW
            bcc   :x1
            lda   UnitsW
            dec
:x1         sta   iw2
            lda   Pt
            jsr   Z2A
            cmp   #$8000
            bcc   :y0
            lda   #0
:y0         cmp   UnitsH
            bcc   :y1
            lda   UnitsH
            dec
:y1         cmp   PeekY
            bne   :new
            ldx   iw2
            cpx   PeekX
            beq   :out
:new        sta   PeekY
            lda   iw2
            sta   PeekX
            lda   #1
            sta   PeekShown
            jsr   InfoTxt
:out        rts

* AutoScroll: with the pointer at or past an edge of the visible content
* (or of the screen), the content scrolls 8 rows or 16 columns.
AutoScroll  jsr   GetPt                 ; the pointer, and the visible part
            PushLong VisRect
            Tool  _GetPortRect
            lda   VisRect               ; the origin now
            sta   Org
            lda   VisRect+2
            sta   Org+2
            lda   Pt                    ; up or down
            cmp   VisRect
            bmi   :up
            beq   :up
            inc
            cmp   VisRect+4
            bmi   :across
            lda   Org
            clc
            adc   #8
            bra   :v
:up         lda   Org
            sec
            sbc   #8
:v          sta   Org
:across     lda   Pt+2
            cmp   VisRect+2
            bmi   :left
            beq   :left
            inc
            cmp   VisRect+6
            bmi   :limits
            lda   Org+2
            clc
            adc   #16
            bra   :h
:left       lda   Org+2
            sec
            sbc   #16
:h          sta   Org+2
:limits     lda   ZoomW                 ; horizontal: 0 to (data width - view
            clc                         ; width + 1) & ~1
            adc   #7
            sec
            sbc   VisRect+6
            clc
            adc   VisRect+2
            inc
            and   #$FFFE
            jsr   Limit
            sta   Org+2
            lda   ZoomH                 ; vertical: 0 to Hz - view height
            sec
            sbc   VisRect+4
            clc
            adc   VisRect
            sta   iw4
            lda   Org
            ldx   iw4
            jsr   LimitV
            sta   Org
            cmp   VisRect
            bne   :scroll
            lda   Org+2
            cmp   VisRect+2
            bne   :scroll
            rts
:scroll     lda   Org+2                 ; scrolled, and the new part drawn
            pha
            lda   Org
            pha
            PushLongAt ScrWin
            Tool  _SetContentOrigin
            lda   ZoomH
            pha
            lda   ZoomW
            clc
            adc   #7
            pha
            PushLongAt ScrWin
            Tool  _SetDataSize
            jsr   WinDone
            jsr   Updates
            jsr   WinDraw
            jmp   EnterScbs

* Limit: Org+2 (A = the largest) kept within 0 and A; LimitV: A kept
* within 0 and X.
Limit       sta   iw4
            lda   Org+2
            ldx   iw4
LimitV      stx   iw4
            cmp   iw4
            bmi   :in
            lda   iw4
:in         cmp   #0
            bpl   :ok
            lda   #0
:ok         rts

* Updates: the window's update, if one is due, drawn now.
Updates     jsr   WinDraw
            PushLongAt ScrWin
            Tool  _BeginUpdate
            jsl   DrawScr
            PushLongAt ScrWin
            Tool  _EndUpdate
            jmp   WinDone

*-------------------------------------------------------------
* The info bar's text: the selection and pixel peek (5.4, 5.5)
*-------------------------------------------------------------

* InfoTxt: only the text drawn again, the rest of the bar to its right
* erased.
InfoTxt     pha
            pha
            Tool  _GetPort
            PushLong TxRect
            PushLongAt ScrWin
            Tool  _StartInfoDrawing
            ldx   #6
:r          lda   TxRect,x
            sta   IRect,x
            dex
            dex
            bpl   :r
            jsr   FitText
            pea   0
            Tool  _SetForeColor
            pea   15
            Tool  _SetBackColor
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
            PushLong TxPen
            Tool  _GetPen
            lda   TxPen+2               ; the rest erased
            sta   TxRect+2
            PushLong TxRect
            Tool  _EraseRect
            Tool  _EndInfoDrawing
            Tool  _SetPort
            rts

* FitText: the longest text that fits the bar (IRect), in InfoTx.
FitText     stz   iw0
:level      lda   iw0
            jsr   InfoText
            inc   iw0
            lda   LastLevel
            cmp   iw0
            beq   :done
            bcc   :done
            pha
            PushLong InfoTx
            Tool  _CStringWidth
            pla
            clc
            adc   IRect+2
            clc
            adc   #142
            cmp   IRect+6
            bcs   :level
:done       rts

* SelText: "Selection: W x H   (T, L, B, R)" (level 0), without the
* corners (1, 2), "W x H" (3).
SelText     lda   iw4
            cmp   #3
            bcs   :wh
            lda   #TxSelection
            jsr   TAdd
:wh         jsr   SelIndex
            lda   SelImg+6,y
            sec
            sbc   SelImg+2,y
            jsr   ToPix
            jsr   TDec
            lda   #TxTimes
            jsr   TAdd
            jsr   SelIndex
            lda   SelImg+4,y
            sec
            sbc   SelImg,y
            jsr   TDec
            lda   iw4
            bne   :end
            lda   #TxOpen
            jsr   TAdd
            jsr   SelIndex
            lda   SelImg,y
            jsr   TDec
            lda   #TxComma
            jsr   TAdd
            jsr   SelIndex
            lda   SelImg+2,y
            jsr   ToPix
            jsr   TDec
            lda   #TxComma
            jsr   TAdd
            jsr   SelIndex
            lda   SelImg+4,y
            jsr   TDec
            lda   #TxComma
            jsr   TAdd
            jsr   SelIndex
            lda   SelImg+6,y
            jsr   ToPix
            jsr   TDec
            lda   #TxClose
            jsr   TAdd
:end        lda   #4
            sta   LastLevel
            jmp   TEnd

* ToPix: image units across (A) in the image's own pixels: halved for a
* screen image without 640 mode lines, and for 320-sized pixels.
ToPix       pha
            lda   Shown
            cmp   #2
            bcs   :other
            lda   Modes
            and   #2
            bne   :whole
            bra   :half
:other      phy
            jsr   Shape
            ply
            lda   ImgPix
            bne   :whole
:half       pla
            lsr
            rts
:whole      pla
            rts

* PeekText: the peeked pixel's value; before any, how to get one.
PeekText    lda   PeekX
            cmp   #$8000
            bne   :point
            lda   PeekShown             ; none yet: how (once shown, a space)
            beq   :how
            lda   #TxSpace
            jsr   TAdd
            lda   #1
            sta   LastLevel
            jmp   TEnd
:how        lda   #TxClick
            ldx   iw4
            beq   :c
            lda   #TxClickShort
:c          jsr   TAdd
            lda   #2
            sta   LastLevel
            jmp   TEnd
:point      lda   #3
            sta   LastLevel
            lda   iw4                   ; "x,y    " (levels 0, 1)
            cmp   #2
            bcs   :value
            lda   PeekX
            jsr   ToPix
            jsr   TDec
            lda   #TxComma1
            jsr   TAdd
            lda   PeekY
            jsr   TDec
            lda   #TxGap
            jsr   TAdd
:value      lda   Shown
            cmp   #2
            beq   :true
            bcs   :mono
            jmp   PeekScr
:true       jmp   PeekTrue
:mono       jmp   PeekMono

* PeekScr: the screen image's pixel: its colour table, index and colour.
PeekScr     lda   ScrLoc+2              ; the line's SCB and byte
            sta   ip0
            lda   ScrLoc+4
            sta   ip0+2
            lda   PeekY
            clc
            adc   #$7D00
            tay
            lda   [ip0],y
            and   #$00FF
            sta   iw5                   ; the SCB
            lda   PeekY                 ; byte = row[x / 4]
            xba
            lsr
            lsr                         ; * 64
            sta   iw3
            lsr
            lsr                         ; * 16
            clc
            adc   iw3                   ; * 80 ...
            asl                         ; * 160
            sta   iw3
            lda   PeekX
            lsr
            lsr
            clc
            adc   iw3
            tay
            lda   [ip0],y
            and   #$00FF
            sta   iw3                   ; the byte
            lda   iw5
            and   #$0080
            bne   :m640
            lda   PeekX                 ; 320 mode: the high nibble for the
            and   #2                    ; first pixel
            bne   :low
            lda   iw3
            lsr
            lsr
            lsr
            lsr
            bra   :i320
:low        lda   iw3
            and   #$000F
:i320       sta   PeekI
            sta   PeekE                 ; (the colour's entry)
            stz   PeekEO
            bra   :text
:m640       lda   PeekX                 ; 640 mode: the 2-bit value at
            and   #3                    ; position x & 3, "e" or "o"
            tax
            lda   iw3
:shift      cpx   #3
            beq   :v
            lsr
            lsr
            inx
            bra   :shift
:v          and   #3
            sta   PeekI
            lda   PeekX
            and   #3
            asl
            asl
            clc
            adc   PeekI
            sta   PeekE
            lda   PeekX
            and   #1
            inc
            sta   PeekEO                ; 1 "e", 2 "o"
:text       lda   iw4                   ; "Palette p  Index i  Color $RGB"
            ldx   #TxPalette
            cmp   #1
            bcc   :p
            ldx   #TxP
:p          txa
            jsr   TAdd
            lda   iw5
            and   #$000F
            jsr   TDec
            lda   iw4
            ldx   #TxIndex
            cmp   #1
            bcc   :i
            ldx   #TxI
:i          txa
            jsr   TAdd
            lda   PeekI
            jsr   TDec
            lda   PeekEO
            beq   :noEO
            ldx   #TxE
            cmp   #1
            beq   :eo
            ldx   #TxO
:eo         txa
            jsr   TAdd
:noEO       lda   iw4
            ldx   #TxColor
            cmp   #1
            bcc   :col
            ldx   #TxDollarSp
:col        txa
            jsr   TAdd
            lda   iw5                   ; the colour: table p, entry e
            and   #$000F
            asl
            asl
            asl
            asl
            asl
            sta   iw3
            lda   PeekE
            asl
            clc
            adc   iw3
            clc
            adc   #$7E00
            tay
            lda   [ip0],y
            jsr   THex3
            jmp   TEnd

* PeekTrue: the true colour pixel: red, green, blue (0-31 each), or its
* grey level in a grey image.
PeekTrue    lda   TrueP                 ; its bytes: row y, pixel x (3 bytes)
            sta   ip0
            lda   TrueP+2
            sta   ip0+2
            lda   PeekY
            ldx   TrueStr
            jsr   MulTx                 ; (iw2:iw3 = A x X)
            lda   PeekX
            jsr   ToPixT
            sta   iw5
            asl
            clc
            adc   iw5                   ; x 3
            clc
            adc   iw2
            sta   iw2
            lda   iw3
            adc   #0
            sta   iw3
            lda   ip0
            clc
            adc   iw2
            sta   ip0
            lda   ip0+2
            adc   iw3
            sta   ip0+2
            jsr   GreyImage
            bcs   :colour
            lda   iw4
            ldx   #TxGray
            txa
            jsr   TAdd
            lda   [ip0]
            and   #$00FF
            jsr   TDec
            jmp   TEnd
:colour     ldy   #0                    ; "Red r  Green g  Blue b"
:chan       phy
            lda   iw4
            beq   :long
            lda   ChanShort,y
            bra   :name
:long       lda   ChanLong,y
:name       jsr   TAdd
            ply
            phy
            tya
            lsr
            tay
            lda   [ip0],y
            and   #$00FF
            lsr
            lsr
            lsr
            jsr   TDec
            ply
            iny
            iny
            cpy   #6
            bcc   :chan
            jmp   TEnd

* ToPixT: true colour image units across (A) in its own pixels.
ToPixT      pha
            jsr   Shape
            pla
            ldx   ImgPix
            bne   :w
            lsr
:w          rts

* GreyImage: carry clear if every pixel of the true colour image has red =
* green = blue (worked out once for each image).
GreyImage   lda   GreyKnown
            beq   :scan
            jmp   :answer
:scan       lda   TrueP
            sta   ip1
            lda   TrueP+2
            sta   ip1+2
            lda   TrueH
            sta   iw2
            stz   GreyIs
:row        ldy   #0
            ldx   TrueW
:px         lda   [ip1],y
            and   #$00FF
            sta   iw3
            iny
            lda   [ip1],y
            and   #$00FF
            cmp   iw3
            bne   :no
            iny
            lda   [ip1],y
            and   #$00FF
            cmp   iw3
            bne   :no
            iny
            dex
            bne   :px
            lda   ip1
            clc
            adc   TrueStr
            sta   ip1
            lda   ip1+2
            adc   #0
            sta   ip1+2
            dec   iw2
            bne   :row
            lda   #1
            sta   GreyIs
:no         lda   #1
            sta   GreyKnown
:answer     lda   GreyIs                ; (carry clear: grey)
            beq   :colour
            clc
            rts
:colour     sec
            rts

* PeekMono: the monochrome pixel: White or Black.
PeekMono    lda   MonoP
            sta   ip0
            lda   MonoP+2
            sta   ip0+2
            lda   PeekY
            ldx   MonoStr
            jsr   MulTx
            lda   PeekX
            jsr   ToPixT
            sta   iw5
            lsr
            lsr
            lsr
            clc
            adc   iw2
            sta   iw2
            lda   iw3
            adc   #0
            sta   iw3
            lda   ip0
            clc
            adc   iw2
            sta   ip0
            lda   ip0+2
            adc   iw3
            sta   ip0+2
            lda   iw5
            and   #7
            asl
            tax
            lda   [ip0]
            and   BitMask,x
            and   #$00FF
            beq   :black
            lda   #TxWhite
            bra   :t
:black      lda   #TxBlack
:t          jsr   TAdd
            jmp   TEnd

* MulTx: iw2:iw3 = A x X (16 x 16 bits).
MulTx       sta   MulA
            stx   MulB
            stz   iw2
            stz   iw3
            ldx   #16
:bit        asl   iw2
            rol   iw3
            asl   MulB
            bcc   :next
            lda   MulA
            clc
            adc   iw2
            sta   iw2
            lda   iw3
            adc   #0
            sta   iw3
:next       dex
            bne   :bit
            rts

* THex3: A's low 12 bits as "$RGB"... three hex digits (the "$" is in the
* text before).
THex3       sta   iw3
            ldx   #3
THexN
:d          lda   iw3
            xba
            and   #$000F
            tay
            lda   HexDig,y
            and   #$00FF
            sta   TCh
            phx
            lda   #TCh
            jsr   TAdd
            plx
            lda   iw3
            asl
            asl
            asl
            asl
            sta   iw3
            dex
            bne   :d
            rts

* TEnd: the text's end.
TEnd        ldy   TLen
            lda   #0
            sep   #$20
            mx    %10
            sta   (mp1),y
            rep   #$20
            mx    %00
            rts

*-------------------------------------------------------------
* The tool and action pop-ups (7.4, 7.5)
*-------------------------------------------------------------

* ToolPop: Selection mode or Pixel peek mode.
ToolPop     lda   ToolNo
            ora   #$0200
            ldx   #8
            jsr   PopBelow0
            beq   :none
            and   #$00FF
            cmp   ToolNo
            beq   :none
            sta   ToolNo
            stz   CurCode               ; (the pointer's shape follows)
            PushLongAt ScrWin
            Tool  _DrawInfoBar
:none       rts

* ActPop: the actions: Crop to selection (with a selection), Discard this
* image type, Discard other image types (selection mode); Clicking sets
* VOC key color (pixel peek mode; there is no Video Overlay Card tool
* set). dact: 3 crop, 4 discard this, 5 discard the others.
ActPop      PushLongAt PopBar
            Tool  _SetMenuBar
            pea   1025
            lda   HasSel
            beq   :off
            Tool  _EnableMItem
            bra   :voc
:off        Tool  _DisableMItem
:voc        pea   1281
            Tool  _DisableMItem
            PushLongAt SysBar
            Tool  _SetMenuBar
            jsr   ActStrip              ; the strip inverted while it is up
            lda   IGlobal+2             ; below the bar
            clc
            adc   #120
            sta   PopLeft
            lda   IGlobal+4
            inc
            cmp   #188
            bcc   :top
            lda   #188
:top        sta   PopTop
            ldx   #12                   ; menu 4, or 5 in pixel peek mode
            lda   ToolNo
            cmp   #2
            bne   :menu
            ldx   #16
:menu       lda   #0
            jsr   PopAt
            pha
            jsr   ActStrip
            pla
            beq   :none
            sec
            sbc   #1025-3               ; 1025-1027: 3-5
            cmp   #6
            bcs   :none
            sta   dact
            lda   Shown                 ; (on the type shown)
            sta   darg
:none       rts

* ActStrip: the 18 columns at the bar's left + 120 inverted.
ActStrip    pha
            pha
            Tool  _GetPort
            PushLong TxRect
            PushLongAt ScrWin
            Tool  _StartInfoDrawing
            lda   TxRect+2
            clc
            adc   #120
            sta   TxRect+2
            clc
            adc   #18
            sta   TxRect+6
            PushLong TxRect
            Tool  _InvertRect
            Tool  _EndInfoDrawing
            Tool  _SetPort
            rts

* PopBelow0: pop-up X at the bar's left + 10 X (its top), item A shown.
PopBelow0   pha
            txa
            asl
            asl
            sta   iw2
            txa
            clc
            adc   iw2
            asl                         ; 10 X
            clc
            adc   IGlobal+2
            sta   PopLeft
            lda   IGlobal
            dec
            sta   PopTop
            pla
* PopAt: pop-up menu X (PopH + X) at PopLeft, PopTop, item A shown.
*   out: A = the item chosen (0: none), Z set if 0
PopAt       stx   iw0
            pha                         ; result
            pha                         ; the item shown
            lda   PopLeft
            pha
            lda   PopTop
            pha
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
* Keys (8)
*-------------------------------------------------------------

* DeskKey: a key with the image window in front (dctl: the key, dctl+2
* its modifiers): 1-9 and space show a part of the selection (or of the
* picture) in the middle; Apple-w closes the window (dact 6: every image
* goes).
DeskKey     ent
            phb
            phk
            plb
            jsr   KeyCore
            plb
            rtl
KeyCore     lda   ScrWin
            ora   ScrWin+2
            beq   :out
            pha
            pha
            Tool  _FrontWindow
            pla
            plx
            cmp   ScrWin
            bne   :out
            cpx   ScrWin+2
            bne   :out
            lda   dctl
            and   #$00FF
            cmp   #'w'
            bne   :notW
            lda   dctl+2
            and   #$0100                ; (Apple)
            beq   :out
            lda   #6
            sta   dact
            rts
:notW       cmp   #' '
            bne   :digit
            lda   #'5'
:digit      sec
            sbc   #'1'
            cmp   #9
            bcs   :out
            jsr   Centre
:out        rts

* Centre: keypad point A (0 = 1 bottom left ... 8 = 9 top right) of SelWin
* in the middle of the view.
Centre      asl
            tax
            lda   KeyV,x                ; v: the average of two of its edges
            tay
            lda   SelWin,y
            ldy   KeyV2,x
            clc
            adc   SelWin,y
            lsr
            sta   iw2
            lda   KeyH,x                ; h
            tay
            lda   SelWin,y
            ldy   KeyH2,x
            clc
            adc   SelWin,y
            lsr
            sta   iw3
            jsr   WinDraw
            PushLong VisRect
            Tool  _GetPortRect
            jsr   WinDone
            lda   VisRect+6             ; h = ph - vw / 2, within the data,
            sec                         ; even
            sbc   VisRect+2
            sta   iw4                   ; vw
            lsr
            eor   #$FFFF
            sec
            adc   iw3
            bpl   :h0
            lda   #0
:h0         and   #$FFFE
            sta   Org+2
            clc
            adc   iw4
            cmp   ZoomW
            bcc   :h1
            lda   ZoomW
            sec
            sbc   iw4
            bpl   :h2
            lda   #0
:h2         and   #$FFFE
            sta   Org+2
:h1         lda   VisRect+4             ; v = pv - vh / 2, within the data
            sec
            sbc   VisRect
            sta   iw4                   ; vh
            lsr
            eor   #$FFFF
            sec
            adc   iw2
            bpl   :v0
            lda   #0
:v0         sta   Org
            clc
            adc   iw4
            cmp   ZoomH
            bcc   :v1
            lda   ZoomH
            sec
            sbc   iw4
            bpl   :v2
            lda   #0
:v2         sta   Org
:v1         lda   Org+2
            pha
            lda   Org
            pha
            PushLongAt ScrWin
            Tool  _SetContentOrigin
            lda   ZoomH
            pha
            lda   ZoomW
            clc
            adc   #7
            pha
            PushLongAt ScrWin
            Tool  _SetDataSize
            jmp   EnterScbs

*-------------------------------------------------------------
* Use image's palette (4.6)
*-------------------------------------------------------------

* EnterPals: with Use image's palette on and the screen image shown, its
* colour tables go to the hardware's (table p to 15 - p) and the lines of
* the window take its lines' modes.
EnterPals   lda   PalsIn
            bne   :out
            lda   UsePal
            beq   :out
            lda   Shown
            cmp   #1
            bne   :out
            lda   #1
            sta   PalsIn
            lda   ScrLoc+2
            sta   ip0
            lda   ScrLoc+4
            sta   ip0+2
            stz   iw2                   ; table p
:p          lda   iw2                   ; SetColorTable(15 - p, its colours)
            eor   #15
            pha
            lda   iw2
            asl
            asl
            asl
            asl
            asl
            clc
            adc   #$7E00
            clc
            adc   ip0
            tax
            lda   ip0+2
            adc   #0
            pha
            phx
            Tool  _SetColorTable
            lda   iw2
            inc
            sta   iw2
            cmp   HiPal
            bcc   :p
            beq   :p
            bra   EnterScbs
:out        rts

* EnterScbs: each screen line the picture shows on takes the line's mode
* and colour table (15 - its table).
EnterScbs   lda   PalsIn
            beq   :out
            lda   Shown
            cmp   #1
            bne   :out
            jsr   WinDraw
            jsr   VisBox                ; the visible part's box
            lda   VisRect               ; its first line on the screen
            sta   ZPt
            lda   VisRect+2
            sta   ZPt+2
            PushLong ZPt
            Tool  _LocalToGlobal
            jsr   WinDone
            lda   ScrLoc+2
            sta   ip0
            lda   ScrLoc+4
            sta   ip0+2
            lda   VisRect+4
            sec
            sbc   VisRect
            sta   iw3                   ; lines
            lda   VisRect
            sta   iw2                   ; the content's line
:line       lda   ZPt
            cmp   #200
            bcs   :out
            lda   iw2
            jsr   Z2A
            cmp   ScrLines
            bcs   :next
            clc
            adc   #$7D00
            tay
            lda   [ip0],y
            and   #$00FF
            eor   #$000F
            sta   iw5
            lda   ZPt                   ; SetSCB(line, scb)
            pha
            lda   iw5
            pha
            Tool  _SetSCB
:next       inc   iw2
            inc   ZPt
            dec   iw3
            bne   :line
:out        rts

* VisBox: VisRect = the box of the current port's visible region.
VisBox      pha
            pha
            Tool  _GetPort
            pla
            sta   ip1
            pla
            sta   ip1+2
            ldy   #28                   ; (visRgn)
            lda   [ip1],y
            tax
            iny
            iny
            lda   [ip1],y
            sta   ip1+2
            stx   ip1
            lda   [ip1]
            tax
            ldy   #2
            lda   [ip1],y
            sta   ip1+2
            stx   ip1
            ldy   #2                    ; rgnBBox
            ldx   #0
:b          lda   [ip1],y
            sta   VisRect,x
            iny
            iny
            inx
            inx
            cpx   #8
            bcc   :b
            rts

* ExitPals: the desktop's colours and modes again.
ExitPals    lda   PalsIn
            beq   :out
            stz   PalsIn
            PushLong StdTable
            Tool  _InitColorTable
            pea   0
            PushLong StdTable
            Tool  _SetColorTable
            pea   $0080
            Tool  _SetAllSCBs
            Tool  _InitPalette
:out        rts

* DeskExitPals: before a menu command: the desktop's colours.
DeskExitPals ent
            phb
            phk
            plb
            jsr   ExitPals
            plb
            rtl

*-------------------------------------------------------------
* Test commands (DESK k ...; Test.s): dctl = the numbers (long pointer),
* darg = their count x 2; dctl back: a text to log (long pointer, 0: none);
* dact: an action for the main program
*-------------------------------------------------------------
DeskTest    ent
            phb
            phk
            plb
            lda   dctl
            sta   ScriptP
            lda   dctl+2
            sta   ScriptP+2
            stz   dctl
            stz   dctl+2
            stz   dact
            lda   [ScriptP]             ; k
            asl
            tax
            lda   ScriptP               ; (the numbers after it)
            clc
            adc   #2
            sta   ScriptP
            jsr   (TestTab,x)
            plb
            rtl
TestTab     da    TNone,TTool,TType,TZoom,TDrag,TLog,TAct,TKey,TOrigin,TZone
            da    TPal,TScb,TRedraw

TNone       rts
TRedraw     PushLongAt ScrWin           ; 12: the whole content drawn again now
            Tool  _SetPort              ; (as an update event would; TIMING
            PushLong BigRect            ; measures it)
            Tool  _InvalRect
            jmp   Updates
TTool       lda   [ScriptP]             ; 1 n: tool n
            sta   ToolNo
            PushLongAt ScrWin
            Tool  _DrawInfoBar
            rts
TType       lda   [ScriptP]             ; 2 n: show type n
            sta   Shown
            jmp   ImgChanged
TZoom       lda   [ScriptP]             ; 3 z: zoom z - 3
            sec
            sbc   #3
            sta   Zoom
            jmp   ImgChanged
TDrag       lda   [ScriptP]             ; 4 c v h v h ...: a drag (content
            sta   dclk                  ; coordinates), clicked c times
            lda   ScriptP
            clc
            adc   #2
            sta   ScriptP
            lda   darg
            sec
            sbc   #4
            sta   ScriptN
            stz   ScriptI
            jsr   GetPt                 ; the click: the shape there
            lda   Pt
            sta   Mouse
            sta   ZPt
            lda   Pt+2
            sta   Mouse+2
            sta   ZPt+2
            stz   ZMods
            lda   #10
            ldx   ToolNo
            cpx   #2
            beq   :code
            lda   #11
            ldx   HasSel
            beq   :code
            jsr   Zones
:code       sta   CurCode
            jsr   Updates
            jsr   WinDraw
            jmp   Click
TLog        lda   #TLogTx               ; 5: the selection and the text
            sta   mp1
            stz   TLen
            jsr   SelIndex
            lda   SelFlag,x
            jsr   TDec
            jsr   SelIndex
            sty   TIdx
            lda   #4
            sta   TCnt
:r          lda   #TxSpace
            jsr   TAdd
            ldy   TIdx
            lda   SelImg,y
            jsr   TDec
            inc   TIdx
            inc   TIdx
            dec   TCnt
            bne   :r
            lda   #TxBar
            jsr   TAdd
            lda   TLen
            sta   TLogLen
            jsr   FitText               ; then the info bar's text, appended
            ldx   #0
            ldy   TLogLen
:c          lda   InfoTx,x
            and   #$00FF
            sep   #$20
            mx    %10
            sta   TLogTx,y
            rep   #$20
            mx    %00
            beq   :done
            inx
            iny
            cpy   #126
            bcc   :c
            lda   #0
            sta   TLogTx,y
:done       lda   #TLogTx
            sta   dctl
            lda   #^TLogTx
            sta   dctl+2
            rts
TAct        lda   [ScriptP]             ; 6 n: action n on the shown type
            sta   dact
            lda   Shown
            sta   darg
            rts
TKey        lda   [ScriptP]             ; 7 c m: key c with modifiers m
            sta   iw2
            ldy   #2
            lda   [ScriptP],y
            sta   dctl+2
            lda   iw2
            sta   dctl
            jsr   KeyCore
            stz   dctl                  ; (no text to log)
            stz   dctl+2
            rts
TOrigin     pha                         ; 8: the content's origin
            pha
            PushLongAt ScrWin
            Tool  _GetContentOrigin
            pla
            sta   iw3                   ; v
            pla
            sta   iw2                   ; h
            lda   #TLogTx
            sta   mp1
            stz   TLen
            lda   iw3
            jsr   TDec
            lda   #TxSpace
            jsr   TAdd
            lda   iw2
            jsr   TDec
            jsr   TEnd
            lda   #TLogTx
            sta   dctl
            lda   #^TLogTx
            sta   dctl+2
            rts
TZone       lda   [ScriptP]             ; 9 v h m: the shape's code there
            sta   ZPt
            ldy   #2
            lda   [ScriptP],y
            sta   ZPt+2
            ldy   #4
            lda   [ScriptP],y
            sta   ZMods
            jsr   Zones
            pha
            lda   #TLogTx
            sta   mp1
            stz   TLen
            pla
            jsr   TDec
            jsr   TEnd
            lda   #TLogTx
            sta   dctl
            lda   #^TLogTx
            sta   dctl+2
            rts

TPal        lda   UsePal                ; 10: Use image's palette on or off
            eor   #1
            sta   UsePal
            jmp   ExitPals
TScb        lda   #TLogTx               ; 11 v: screen line v's SCB, and colour
            sta   mp1                   ; table 15's first 4 colours (hex)
            stz   TLen
            lda   [ScriptP]
            tax
            ldal  $E19D00,x
            and   #$00FF
            jsr   THex2
            ldx   #0
:c          phx
            lda   #TxSpace
            jsr   TAdd
            plx
            phx
            ldal  $E19FE0,x
            jsr   THex3
            plx
            inx
            inx
            cpx   #8
            bcc   :c
            jsr   TEnd
            lda   #TLogTx
            sta   dctl
            lda   #^TLogTx
            sta   dctl+2
            rts

* THex2: A's low byte as two hex digits.
THex2       asl                         ; (the digits at bits 8-11, 4-7)
            asl
            asl
            asl
            sta   iw3
            ldx   #2
            jmp   THexN

*-------------------------------------------------------------
* Data
*-------------------------------------------------------------
ScriptP     =     $5C                   ; (a long pointer on the direct page)
ScriptN     dw    0                     ; a test's drag: its points (bytes)
ScriptI     dw    0
ZMods       dw    0
TLogTx      ds    128
TLogLen     dw    0
TIdx        dw    0
TCnt        dw    0
TxBar       asc   ' | ',00
SelFlag     dw    0,0,0,0               ; each type (1-3) has a selection
SelImg      ds    32                    ; and its rectangle (image units)
SelWin      dw    0,0,0,0               ; the shown type's, in the window
NewSel      dw    0,0,0,0
HasSel      dw    0                     ; the shown type has a selection
HalfX       dw    0                     ; snapping: half a step and the mask
MaskX       dw    $FFFF
HalfY       dw    0
MaskY       dw    $FFFF
Phase       dw    0                     ; the ants, 0-3
AntTick     adrl  0                     ; their last step
PeekX       dw    $8000                 ; the pixel peeked ($8000: none)
PeekY       dw    $8000
PeekShown   dw    0                     ; one has been shown
PeekI       dw    0
PeekE       dw    0
PeekEO      dw    0
CurCode     dw    0                     ; the pointer's shape (6.1)
CurPart     dw    0
CurWin      adrl  0
CurEv       ds    16                    ; (an event record: where the pointer is)
OldPort     adrl  0
Mouse       dw    0,0                   ; v, h
Pt          dw    0,0
ZPt         dw    0,0
Anchor      dw    0,0
Org         dw    0,0                   ; v, h
VisRect     dw    0,0,0,0
TxRect      dw    0,0,0,0
TxPen       dw    0,0
PopLeft     dw    0
PopTop      dw    0
LastLevel   dw    4
GreyKnown   dw    0
GreyIs      dw    0
UsePal      dw    0                     ; Use image's palette is on
PalsIn      dw    0                     ; the image's colours are in use
StdTable    ds    32
TCh         dw    0
MulA        dw    0
MulB        dw    0
CurTab      da    0,Cur4,Cur2,Cur1,Cur3,Cur8,Cur3,Cur1,Cur2,Cur4,Cur6,Cur5
ZoneCodes   db    11,11,11,11,11,7,8,9,11,4,5,6,11,1,2,3
* Keys 1-9: v from the average of two edges (offsets in SelWin), h too.
KeyV        dw    4,4,4,0,0,0,0,0,0
KeyV2       dw    4,4,4,4,4,4,0,0,0
KeyH        dw    2,2,6,2,2,6,2,2,6
KeyH2       dw    2,6,6,2,6,6,2,6,6
BitMask     dw    $80,$40,$20,$10,$08,$04,$02,$01
HexDig      asc   '0123456789ABCDEF'
ChanLong    da    TxRed,TxGreen,TxBlue
ChanShort   da    TxR,TxG,TxB
TxSelection asc   'Selection: ',00
TxOpen      asc   '   (',00
TxClose     asc   ')',00
TxClick     asc   'Click in image to view pixel values',00
TxClickShort asc  'Click in image',00
TxGap       asc   '    ',00
TxPalette   asc   'Palette ',00
TxP         asc   'P',00
TxIndex     asc   '  Index ',00
TxI         asc   '  I',00
TxE         asc   'e',00
TxO         asc   'o',00
TxColor     asc   '  Color $',00
TxDollarSp  asc   '  $',00
TxRed       asc   'Red ',00
TxGreen     asc   '  Green ',00
TxBlue      asc   '  Blue ',00
TxR         asc   'R',00
TxG         asc   '  G',00
TxB         asc   '  B',00
TxGray      asc   'Gray ',00
TxWhite     asc   'White',00
TxBlack     asc   'Black',00
