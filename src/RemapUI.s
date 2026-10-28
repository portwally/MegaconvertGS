*-------------------------------------------------------------
* RemapUI.s - part of the Remap segment: the Remap dialog, drawn as
* SuperConvert's own, pixel for pixel. The choices on the left; the
* picture's colours and the other options at the top; the scaling (a
* scroll bar across and one down, with a diagram of the size against a
* grid of screens) and the buttons below. Return remaps, Esc cancels.
*-------------------------------------------------------------

* RemapDialog: out: carry set to cancel; else A = 0 for a normal remap
* with the options chosen, or 2 for a quick remap.
RemapDialog ent
            phb
            phk
            plb
            jsr   Fit                   ; fitted to start with
            jsr   Normalise
            lda   tgen                  ; a new picture: its colours to count
            cmp   StGen
            beq   :same
            stz   StDone
:same       pha                         ; result: window pointer
            pha
            PushLong DlgParms
            Tool  _NewWindow
            pla
            sta   DlgWin
            pla
            sta   DlgWin+2
            jsr   ToDlg
            jsr   DrawAll
            lda   StDone
            bne   :counted
            jsr   Stats                 ; (a moment for a big picture)
            jsr   DrawStats
:counted    jsr   Flush
:wait       jsr   NextEvent
            bcs   :wait
            lda   Event
            cmp   #1
            beq   :mouse
            lda   Event+2               ; keys: Return remaps, Esc cancels
            and   #$007F
            cmp   #$0D
            beq   :normal
            cmp   #$1B
            beq   :cancel
            bra   :wait
:mouse      jsr   LocalPt
            ldx   #Items
            jsr   HitItem               ; A = the action, or $FFFF
            cmp   #$FFFF
            beq   :wait
            cmp   #actCancel
            beq   :cancel
            cmp   #actNormal
            beq   :normal
            cmp   #actQuick
            beq   :quick
            jsr   DoAction
            bra   :wait
:normal     lda   #0
            bra   :ok
:quick      lda   #2
:ok         pha
            PushLongAt DlgWin
            Tool  _CloseWindow
            pla
            clc
            plb
            rtl
:cancel     PushLongAt DlgWin
            Tool  _CloseWindow
            sec
            plb
            rtl

* Actions, as the Items table gives them.
actMode     =     0                     ; 0-3: graphic modes
actPal      =     4                     ; 4-9: default, greys, calculated, stored,
actAlg      =     10                    ;      current, other; 10-12: rendering
actGetOther =     13
actInfo     =     14
actCancel   =     15
actQuick    =     16
actNormal   =     17
actHBar     =     18
actVBar     =     19

* DoAction: action A.
DoAction    sta   DI
            cmp   #actPal
            bcs   :notMode
            sta   OMode                 ; a mode: fitted again
            jsr   Normalise
            jsr   Fit
            jsr   DrawChoices
            jmp   DrawScaling
:notMode    cmp   #actGetOther
            bcs   :notRow
            jsr   Enabled               ; (greyed out: nothing)
            bcs   :done
            lda   DI
            cmp   #actAlg
            bcs   :alg
            sec                         ; a palette
            sbc   #actPal
            asl
            tax
            lda   PalOfRow,x
            sta   OPal
            jsr   Normalise
            jmp   DrawChoices
:alg        sec
            sbc   #actAlg
            sta   OAlg
            jmp   DrawChoices
:notRow     cmp   #actGetOther
            bne   :notOther
            jmp   GetOther
:notOther   cmp   #actInfo
            bne   :notInfo
            jmp   Info
:notInfo    cmp   #actHBar
            bne   :notH
            jmp   TrackH
:notH       cmp   #actVBar
            bne   :done
            jmp   TrackV
:done       rts

* The palette each palette row stands for (OPal: 0 calculated, 1 default,
* 2 greys, 3 other, 4 the picture's current, 5 stored).
PalOfRow    dw    1,2,0,5,4,3

* Marked: A = 1 if row DI is the one chosen in its group, else 0.
Marked      lda   DI
            cmp   #actPal
            bcs   :pal
            cmp   OMode
            beq   :yes
            bra   :no
:pal        cmp   #actAlg
            bcs   :alg
            sec
            sbc   #actPal
            asl
            tax
            lda   PalOfRow,x
            cmp   OPal
            beq   :yes
            bra   :no
:alg        sec
            sbc   #actAlg
            cmp   OAlg
            beq   :yes
:no         lda   #0
            rts
:yes        lda   #1
            rts

* Enabled: carry set if row DI can't be chosen now (it is greyed out).
Enabled     lda   DI
            cmp   #actPal
            bcc   :yes
            cmp   #actAlg
            bcs   :alg
            cmp   #actPal+5             ; other: once one was picked with
            bne   :pal                  ; Get other...
            lda   OPal
            cmp   #3
            beq   :yes
            lda   OMode
            asl
            tax
            lda   OtherSet,x
            beq   :no
            bra   :yes
:pal        sec
            sbc   #actPal
            asl
            tax
            lda   PalOfRow,x
            jmp   PalOK
:alg        cmp   #actAlg+2
            bne   :yes
            jmp   DiffusionOK
:yes        clc
            rts
:no         sec
            rts

*-------------------------------------------------------------
* Events
*-------------------------------------------------------------

* NextEvent: a mouse down or key down in Event; carry set if none. Clicks
* given by a test come first.
NextEvent   lda   ClickN
            beq   :real
            dec   ClickN
            lda   ClickI
            asl
            asl
            tax
            lda   ClickQ,x              ; (already in the window's coordinates)
            sta   Event+10
            lda   ClickQ+2,x
            sta   Event+12
            inc   ClickI
            lda   #1
            sta   Event
            sta   Given
            clc
            rts
:real       stz   Given
            pha
            pea   $000A
            PushLong Event
            Tool  _GetNextEvent
            pla
            beq   :none
            clc
            rts
:none       sec
            rts

* LocalPt: the event's place (Event+10 v, +12 h) in window coordinates.
LocalPt     lda   Given
            bne   :done
            PushLong Event+10
            Tool  _GlobalToLocal
:done       rts

* RemapClicks: clicks for the next Remap dialog, for tests: A of them at p0
* (v, h each, in the window's own coordinates).
RemapClicks ent
            phb
            phk
            plb
            cmp   #17
            bcc   :n
            lda   #16
:n          sta   ClickN
            stz   ClickI
            asl
            asl
            tay
:c          dey
            dey
            bmi   :done
            lda   [p0],y
            sta   ClickQ,y
            bra   :c
:done       plb
            rtl

* Flush: forget clicks and keys from before.
Flush       pha
            pea   $FFFF
            pea   0
            Tool  _FlushEvents
            pla
            rts

* ToDlg: drawing into the dialog window.
ToDlg       PushLongAt DlgWin
            Tool  _SetPort
            rts

* HitItem: the action under the click, from the table at X (top, left,
* bottom, right, action; $FFFF ends it).   out: A = action or $FFFF
HitItem     lda   |0,x
            cmp   #$FFFF
            beq   :none
            lda   Event+10
            cmp   |0,x
            bcc   :next
            cmp   |4,x
            bcs   :next
            lda   Event+12
            cmp   |2,x
            bcc   :next
            cmp   |6,x
            bcs   :next
            lda   |8,x
            rts
:next       txa
            clc
            adc   #10
            tax
            bra   HitItem
:none       lda   #$FFFF
            rts

* Still: carry clear while the mouse button is still down (a click given
* by a test is let go at once).
Still       lda   Given
            bne   :up
            pha
            pea   0
            Tool  _StillDown
            pla
            beq   :up
            clc
            rts
:up         sec
            rts

* Mouse: the mouse's place in the window into Event+10 (v) and +12 (h).
Mouse       PushLong Event+10
            Tool  _GetMouse
            rts

* Pause: A ticks.
Pause       sta   t3
            pha
            pha
            Tool  _TickCount
            pla
            plx
            clc
            adc   t3
            sta   t3
:wait       pha
            pha
            Tool  _TickCount
            pla
            plx
            cmp   t3
            bmi   :wait
            rts

*-------------------------------------------------------------
* The scroll bars: the arrows step; elsewhere the box follows the mouse.
* As in SuperConvert, a bar runs from nothing to 4:1, so 1:1 is a quarter
* along; the box goes to the scale step nearest the mouse.
*-------------------------------------------------------------
TrackH      lda   Event+12
            cmp   #HTrackL
            bcs   :notLess
            lda   #OHStep
            ldx   #$FFFF
            jmp   Arrow
:notLess    cmp   #HTrackR
            bcc   :track
            lda   #OHStep
            ldx   #1
            jmp   Arrow
:track      lda   Event+12              ; (the box's middle, at step 0's place)
            sec
            sbc   #HTrackL+8
            ldx   #HPos
            jsr   NearStep
            cmp   OHStep
            beq   :same
            sta   OHStep
            jsr   DrawScaling
:same       jsr   Still
            bcs   :done
            jsr   Mouse
            bra   :track
:done       rts

TrackV      lda   Event+10
            cmp   #VTrackT
            bcs   :notLess
            lda   #OVStep
            ldx   #$FFFF
            jmp   Arrow
:notLess    cmp   #VTrackB
            bcc   :track
            lda   #OVStep
            ldx   #1
            jmp   Arrow
:track      lda   Event+10
            sec
            sbc   #VTrackT+4
            ldx   #VPos
            jsr   NearStep
            cmp   OVStep
            beq   :same
            sta   OVStep
            jsr   DrawScaling
:same       jsr   Still
            bcs   :done
            jsr   Mouse
            bra   :track
:done       rts

* NearStep: the scale step whose box place in the table at X is nearest to
* place A (the first one, if two are as near).
NearStep    cmp   #$8000                ; (left of step 0: step 0)
            bcc   :pos
            lda   #0
:pos        sta   t2
            stx   t3
            lda   #$7FFF
            sta   t1
            stz   NBest
            ldy   #0
:s          lda   (t3),y
            sec
            sbc   t2
            bpl   :abs
            eor   #$FFFF
            inc
:abs        cmp   t1
            bcs   :next
            sta   t1
            tya
            lsr
            sta   NBest
:next       iny
            iny
            cpy   #46
            bcc   :s
            lda   NBest
            rts

* Arrow: the step at A one less (X = $FFFF) or one more (X = 1), again
* and again while the button is held.
Arrow       sta   ArStep
            stx   ArDelta
            lda   #20                   ; (a longer wait before repeating)
            sta   ArWait
:step       ldx   ArStep
            lda   |0,x
            clc
            adc   ArDelta
            bmi   :held                 ; (0 to 22)
            cmp   #23
            bcs   :held
            sta   |0,x
            jsr   DrawScaling
:held       lda   ArWait
            jsr   Pause
            lda   #6
            sta   ArWait
            jsr   Still
            bcc   :step
            rts

*-------------------------------------------------------------
* Get other...: the mode's other palettes (in multipalette mode, its
* techniques), in a window of their own
*-------------------------------------------------------------
GetOther    lda   OMode
            asl
            tax
            lda   OtherCount,x
            sta   SubN
            lda   OtherNames,x
            sta   SubList
            lda   OOther,x
            cmp   OtherCount,x
            bcc   :sel
            lda   #0
:sel        sta   SubSel
            lda   SubN                  ; the window: 11 lines an item
            asl
            asl
            asl
            clc
            adc   SubN
            adc   SubN
            adc   SubN
            sta   t3                    ; (n * 11)
            clc
            adc   #SubTop+52
            sta   SubParms+SubBottom
            lda   t3                    ; Cancel under the list
            clc
            adc   #30
            sta   SubCancel
            clc
            adc   #13
            sta   SubCancel+4
            pha
            pha
            PushLong SubParms
            Tool  _NewWindow
            pla
            sta   SubWin
            pla
            sta   SubWin+2
            PushLongAt SubWin
            Tool  _SetPort
            lda   #TxOtherHead          ; the heading
            ldx   OMode
            cpx   #3
            bne   :head
            lda   #TxTechHead
:head       ldx   #9
            ldy   #12
            jsr   Heading
            stz   DI                    ; the list
:item       lda   DI
            cmp   SubN
            bcs   :listed
            jsr   SubBase               ; Y = its baseline
            sty   RBase
            tya
            sec
            sbc   #7
            tay
            ldx   #10
            lda   DI
            cmp   SubSel
            beq   :on
            lda   #0
            bra   :radio
:on         lda   #1
:radio      jsr   Radio
            lda   DI                    ; its name
            asl
            clc
            adc   SubList
            tax
            lda   |0,x
            ldy   RBase
            iny
            ldx   #35
            jsr   TextAt
            inc   DI
            bra   :item
:listed     ldx   #SubCancel            ; (Return takes the one marked)
            lda   #TxCancel
            jsr   Button
            jsr   Flush
:wait       jsr   NextEvent
            bcs   :wait
            lda   Event
            cmp   #1
            beq   :mouse
            lda   Event+2
            and   #$007F
            cmp   #$1B                  ; Esc: as it was
            beq   :cancel
            cmp   #$0D                  ; Return: the one marked
            bne   :wait
            lda   SubSel
            bra   :pick
:mouse      jsr   LocalPt
            ldx   #SubCancel            ; Cancel?
            lda   Event+10
            cmp   |0,x
            bcc   :list
            cmp   |4,x
            bcs   :list
            lda   Event+12
            cmp   |2,x
            bcc   :list
            cmp   |6,x
            bcc   :cancel
:list       lda   Event+12              ; a line of the list?
            cmp   #8
            bcc   :wait
            cmp   #SubRight-SubLeft-8
            bcs   :wait
            lda   Event+10
            sec
            sbc   #SubList0-9
            bmi   :wait
            sta   n0
            stz   n0+2
            lda   #11
            jsr   Div32
            cmp   SubN
            bcs   :wait
:pick       pha
            jsr   CloseSub
            pla
            ldx   OMode
            pha
            txa
            asl
            tax
            pla
            sta   OOther,x
            lda   #1                    ; (now the radio button can be used)
            sta   OtherSet,x
            lda   #3                    ; and the palette: other
            sta   OPal
            jsr   Normalise
            jmp   DrawAll
:cancel     jsr   CloseSub
            jmp   DrawAll

CloseSub    PushLongAt SubWin
            Tool  _CloseWindow
            jmp   ToDlg

* SubBase: Y = the baseline of list item DI.
SubBase     lda   DI
            asl
            asl
            asl
            clc
            adc   DI
            adc   DI
            adc   DI
            clc
            adc   #SubList0
            tay
            rts

*-------------------------------------------------------------
* Info on these options
*-------------------------------------------------------------
Info        pha
            pea   0                     ; a C string
            PushLong 0
            PushLong InfoTxt
            Tool  _AlertWindow
            pla
            jsr   ToDlg
            jmp   DrawAll

*-------------------------------------------------------------
* Drawing
*-------------------------------------------------------------
DrawAll     PushLong AllRect
            Tool  _EraseRect
            jsr   DrawChoices
            jsr   DrawStats
            jsr   DrawOptions
            PushLong IconLoc            ; true colour to screen
            PushLong IconRect
            pea   IconX
            pea   IconY
            pea   0
            Tool  _PPToPort
            ldx   #InfoRect
            lda   #TxInfo
            jsr   Button
            jmp   DrawScaling

* DrawChoices: the left column.
DrawChoices PushLong LeftRect
            Tool  _EraseRect
            lda   #TxHMode
            ldx   #HeadL
            ldy   #BHead1
            jsr   Heading
            lda   #TxHPal
            ldx   #HeadL
            ldy   #BHead2
            jsr   Heading
            lda   #TxHAlg
            ldx   #HeadL
            ldy   #BHead3
            jsr   Heading
            ldx   #0
:row        lda   Rows,x                ; action, top, text
            cmp   #$FFFF
            beq   :done
            stx   RI
            sta   DI
            lda   Rows+2,x
            sta   RTop
            jsr   Marked                ; A = 1 if chosen
            ldx   #RadL
            ldy   RTop
            jsr   Radio
            ldx   RI
            lda   Rows+4,x
            beq   :noText               ; (Other's text is its button)
            pha
            lda   RTop
            clc
            adc   #8
            tay
            pla
            ldx   #TxtL
            jsr   TextAt
:noText     jsr   Enabled
            bcc   :next
            lda   RTop                  ; can't be chosen now: greyed out
            dec
            sta   Box
            lda   #RadL-2
            sta   Box+2
            lda   RTop
            clc
            adc   #10
            sta   Box+4
            lda   #LeftW
            ldx   RI
            ldy   Rows+4,x
            bne   :wide
            lda   #RadL+22
:wide       sta   Box+6
            jsr   GreyBox
:next       lda   RI
            clc
            adc   #6
            tax
            bra   :row
:done       ldx   #OtherRect
            lda   #TxGetOther
            jmp   Button

* DrawStats: the picture's distinct colours and what kind of picture it is.
DrawStats   PushLong StatRect
            Tool  _EraseRect
            lda   StDone
            bne   :have
            lda   #TxCounting
            ldx   #StatX
            ldy   #StatY1
            jmp   TextAt
:have       lda   #TxDistinct
            ldx   #StatX
            ldy   #StatY1
            jsr   TextAt
            stz   SizeLen               ; the number, ending at StatNumR
            lda   StDistinct
            jsr   AddDec
            jsr   SizeWidth
            eor   #$FFFF
            sec
            adc   #StatNumR
            tax
            ldy   #StatY1
            jsr   DrawSize
            lda   #TxDistrib
            ldx   #StatX
            ldy   #StatY2
            jsr   TextAt
            lda   #TxFull
            ldx   StBW
            beq   :grey
            lda   #TxBW
            bra   :kind
:grey       ldx   StGrey
            beq   :kind
            lda   #TxGreys
:kind       ldx   #StatKindX
            ldy   #StatY2
            jmp   TextAt

* DrawOptions: SuperConvert's other options, as MegaconvertGS always has
* them (greyed out: they can't be changed).
DrawOptions lda   #TxHOpt
            ldx   #OptHeadL
            ldy   #BHead1
            jsr   Heading
            stz   DI
:box        lda   DI
            asl
            tax
            lda   OptTexts,x
            pha
            lda   OptState,x
            pha
            lda   DI                    ; top: 12 + 10 each
            asl
            sta   t3
            asl
            asl
            clc
            adc   t3
            adc   #OptTop
            sta   RTop
            tay
            pla
            ldx   #OptBoxL
            jsr   Checkbox
            lda   RTop
            clc
            adc   #8
            tay
            pla
            ldx   #OptTxtL
            jsr   TextAt
            inc   DI
            lda   DI
            cmp   #4
            bcc   :box
            lda   #OptTop-1
            sta   Box
            lda   #OptBoxL-2
            sta   Box+2
            lda   #OptTop+40
            sta   Box+4
            lda   #618
            sta   Box+6
            jmp   GreyBox

* DrawScaling: the sizes, the lines to the scroll bars, the bars, the
* diagram and the buttons.
DrawScaling PushLong ScaleRect
            Tool  _EraseRect
            jsr   Sizes                 ; (NatW, NatH, WantW, WantH, ROutW, ROutH)
            stz   SizeLen               ; down
            lda   #TxVert
            jsr   AddTx
            lda   NatH
            jsr   AddDec
            lda   #TxTo
            jsr   AddTx
            lda   WantH
            jsr   AddDec
            lda   OVStep
            jsr   AddRatio
            ldx   #VTxtX
            ldy   #VTxtY
            jsr   DrawSize
            stz   SizeLen               ; across
            lda   #TxHorz
            jsr   AddTx
            lda   NatW
            jsr   AddDec
            lda   #TxTo
            jsr   AddTx
            lda   WantW
            jsr   AddDec
            lda   OHStep
            jsr   AddRatio
            ldx   #HTxtX
            ldy   #HTxtY
            jsr   DrawSize
            lda   ROutW                 ; more than a screen: cut off
            cmp   WantW
            bne   :clip
            lda   ROutH
            cmp   WantH
            beq   :whole
:clip       stz   SizeLen
            lda   #TxClip
            jsr   AddTx
            lda   ROutW
            jsr   AddDec
            lda   #TxTimes
            jsr   AddTx
            lda   ROutH
            jsr   AddDec
            ldx   #ClipX
            ldy   #ClipY
            jsr   DrawSize
:whole      ldx   #Lead1                ; the lines from the texts to the bars
            jsr   Runs
            ldx   #Lead2
            jsr   Runs
            jsr   DrawHBar
            jsr   DrawVBar
            jsr   Diagram
            ldx   #CancelRect
            lda   #TxCancel
            jsr   Button
            ldx   #QuickRect
            lda   #TxQuick
            jsr   Button
            ldx   #RingRect             ; Normal remap: the one Return presses
            lda   #EndRing
            ldy   #11
            jsr   BtnFrame
            ldx   #NormalRect
            lda   #TxNormal
            jmp   Button

* DrawHBar: the scroll bar across.
DrawHBar    pea   2
            pea   1
            Tool  _SetPenSize
            PushLong HBarRect
            Tool  _FrameRect
            Tool  _PenNormal
            PushLong HSepL              ; the arrows' boxes
            Tool  _PaintRect
            PushLong HSepR
            Tool  _PaintRect
            ldx   #ArLeft
            jsr   Runs
            ldx   #ArRight
            jsr   Runs
            PushLong Stripes            ; the track
            Tool  _SetPenPat
            PushLong HTrack
            Tool  _PaintRect
            Tool  _PenNormal
            lda   OHStep                ; the box
            asl
            tax
            lda   HPos,x
            clc
            adc   #HTrackL
            sta   Box+2
            clc
            adc   #16
            sta   Box+6
            lda   #HBarT+1
            sta   Box
            lda   #HBarT+10
            sta   Box+4
            jmp   ThumbBox

* DrawVBar: the scroll bar down.
DrawVBar    pea   2
            pea   1
            Tool  _SetPenSize
            PushLong VBarRect
            Tool  _FrameRect
            Tool  _PenNormal
            lda   #VTrackT-1            ; the arrows' boxes
            ldx   #VBarL
            ldy   #VBarR-1
            jsr   HLine
            lda   #VTrackB
            ldx   #VBarL
            ldy   #VBarR-1
            jsr   HLine
            ldx   #ArUp
            jsr   Runs
            ldx   #ArDown
            jsr   Runs
            PushLong Stripes            ; the track
            Tool  _SetPenPat
            PushLong VTrack
            Tool  _PaintRect
            Tool  _PenNormal
            lda   OVStep                ; the box
            asl
            tax
            lda   VPos,x
            clc
            adc   #VTrackT
            sta   Box
            clc
            adc   #8
            sta   Box+4
            lda   #VBarL+2
            sta   Box+2
            lda   #VBarR-2
            sta   Box+6
            jmp   ThumbBox

* Diagram: a grid of screens, two across and two down, cut by the 64K
* limit; the size asked for (thin) and the size remapped (thick).
Diagram     PushLong Purple
            Tool  _SetPenPat
            ldx   #GridRuns
            jsr   Runs
            PushLong GridL1
            Tool  _PaintRect
            PushLong GridL2
            Tool  _PaintRect
            PushLong GridL3
            Tool  _PaintRect
            Tool  _PenNormal
            pea   5                     ; (pixel value 1, as the grid)
            Tool  _SetForeColor
            lda   #TxScreen
            ldx   #ScreenTxX
            ldy   #ScreenTxY
            jsr   TextAt
            pea   0
            Tool  _SetForeColor
            PushLong YelGreen
            Tool  _SetPenPat
            lda   WantW                 ; asked for: up to two screens
            ldx   #80
            ldy   #160
            jsr   Across
            sta   Box+6
            lda   WantH
            ldx   #25
            ldy   #50
            jsr   Down
            sta   Box+4
            lda   #GridT+1
            sta   Box
            lda   #GridL+2
            sta   Box+2
            pea   2
            pea   1
            Tool  _SetPenSize
            PushLong Box
            Tool  _FrameRect
            lda   ROutW                 ; remapped: a screen at most
            ldx   #80
            ldy   #80
            jsr   Across
            sta   Box+6
            lda   ROutH
            ldx   #25
            ldy   #25
            jsr   Down
            sta   Box+4
            pea   4
            pea   2
            Tool  _SetPenSize
            PushLong Box
            Tool  _FrameRect
            Tool  _PenNormal
            rts

* Across: the right edge for A pixels across, X pixels a screen, at most Y.
Across      sty   t3
            stx   t1
            pha
            jsr   ScreenW
            sta   t2
            pla
            ldx   t1
            jsr   Mul16
            lda   MLo
            sta   n0
            lda   MHi
            sta   n0+2
            lda   t2
            jsr   Div32
            cmp   #8
            bcs   :min
            lda   #8
:min        cmp   t3
            bcc   :max
            lda   t3
:max        clc
            adc   #GridL+2
            rts

* Down: the bottom edge for A lines, X lines a screen, at most Y.
Down        sty   t3
            jsr   Mul16
            lda   MLo
            sta   n0
            lda   MHi
            sta   n0+2
            lda   #200
            jsr   Div32
            cmp   #4
            bcs   :min
            lda   #4
:min        cmp   t3
            bcc   :max
            lda   t3
:max        clc
            adc   #GridT+1
            rts

* AddRatio: " (n:d)" for step A onto SizeTxt.
AddRatio    asl
            sta   t3
            lda   #TxOpen
            jsr   AddTx
            ldx   t3
            lda   StepN,x
            jsr   AddDec
            lda   #TxColon
            jsr   AddTx
            ldx   t3
            lda   StepD,x
            jsr   AddDec
            lda   #TxClose
            jmp   AddTx

*-------------------------------------------------------------
* Layout, in the window (its content is at 20, 10 on the screen, as
* SuperConvert's). Merlin works expressions out from left to right, so
* most places are written out.
*-------------------------------------------------------------
LeftW       =     186                   ; the choices
HeadL       =     5
RadL        =     5
TxtL        =     30
BHead1      =     10                     ; headings' baselines
BHead2      =     63
BHead3      =     138
StatX       =     205                   ; the colours
StatY1      =     41
StatY2      =     50
StatNumR    =     384
StatKindX   =     306
OptHeadL    =     420                   ; other options
OptBoxL     =     420
OptTxtL     =     448
OptTop      =     12
VTxtX       =     207                   ; the scaling
VTxtY       =     66
HTxtX       =     250
HTxtY       =     76
ClipX       =     382
ClipY       =     161
IconX       =     258
IconY       =     3
GridL       =     375                   ; screens of 82 x 26 lines
GridT       =     95
ScreenTxX   =     387
ScreenTxY   =     112
HBarT       =     82                    ; the bar across, over the grid
HTrackL     =     402                   ; (its box at step 0; arrows to 401, from 588)
HTrackR     =     588
VBarL       =     344                   ; the bar down, left of the grid
VBarR       =     370
VTrackT     =     108                   ; (arrows to 107, from 157)
VTrackB     =     157

AllRect     dw    0,0,172,620
LeftRect    dw    0,0,172,LeftW
StatRect    dw    30,200,53,410
ScaleRect   dw    55,LeftW,172,620
InfoRect    dw    15,205,28,395
OtherRect   dw    115,35,126,150
CancelRect  dw    121,215,134,305
QuickRect   dw    137,205,150,315
RingRect    dw    152,191,169,329
NormalRect  dw    154,195,167,325
HBarRect    dw    82,375,93,615
HSepL       dw    83,400,92,403
HSepR       dw    83,588,92,590
HTrack      dw    83,403,92,588
VBarRect    dw    95,344,170,370
VTrack      dw    108,346,157,368
GridL1      dw    95,375,147,377        ; left, middle and right edges
GridL2      dw    95,457,147,459
GridL3      dw    95,537,123,539

* Where each scale step puts the scroll boxes (from step 0's place).
HPos        dw    3,4,4,5,7,9,11,14,17,21,26,28,32,34,43,53,57,64,71,85,106,128,170
VPos        dw    1,1,1,1,2,2,3,3,4,5,6,7,8,8,10,13,14,15,17,21,26,31,41

* Rows of the left column: action, top, text.
Rows        dw    0,12,TxM0
            dw    1,22,TxM1
            dw    2,32,TxM2
            dw    3,42,TxM3
            dw    4,65,TxP0
            dw    5,75,TxP1
            dw    6,85,TxP2
            dw    7,95,TxP3
            dw    8,105,TxP4
            dw    9,116,0
            dw    10,140,TxA0
            dw    11,150,TxA1
            dw    12,160,TxA2
            dw    $FFFF

* Where a click does what: top, left, bottom, right, action.
Items       dw    115,35,126,150,actGetOther
            dw    115,3,126,27,9
            dw    11,3,22,LeftW,0
            dw    21,3,32,LeftW,1
            dw    31,3,42,LeftW,2
            dw    41,3,52,LeftW,3
            dw    64,3,75,LeftW,4
            dw    74,3,85,LeftW,5
            dw    84,3,95,LeftW,6
            dw    94,3,105,LeftW,7
            dw    104,3,115,LeftW,8
            dw    139,3,150,LeftW,10
            dw    149,3,160,LeftW,11
            dw    159,3,170,LeftW,12
            dw    15,205,28,395,actInfo
            dw    121,215,134,305,actCancel
            dw    137,205,150,315,actQuick
            dw    152,191,169,329,actNormal
            dw    82,375,93,615,actHBar
            dw    95,344,170,370,actVBar
            dw    $FFFF

* The other options: texts and how they are.
OptTexts    da    TxO0,TxO1,TxO2,TxO3
OptState    dw    1,1,1,0

* Runs (row, first, last): the lines from the scaling texts to the bars,
* the bars' arrows, and the grid's lines across with the 64K limit.
Lead1       dw    67,221,226,68,222,227,69,222,227,70,223,228,71,224,229
            dw    72,225,230,73,226,231,74,227,232,75,228,233,76,229,234
            dw    77,231,236,78,232,237,79,234,239,80,236,241,81,237,243
            dw    82,239,245,83,242,247,84,244,249,85,246,252,86,249,254
            dw    87,252,257,88,255,260,89,258,263,90,261,267,91,265,271
            dw    92,269,275,93,273,279,94,278,284,95,283,289,96,288,295
            dw    97,294,302,98,302,310,99,310,321,100,321,336,101,336,345
            dw    $FFFF
Lead2       dw    77,277,283,78,280,286,79,283,290,80,288,294,81,292,300
            dw    82,298,306,83,305,314,84,313,324,85,323,336,86,336,356
            dw    87,356,376,$FFFF
ArLeft      dw    83,387,389,84,385,386,84,388,389,85,383,384,85,388,396
            dw    86,381,382,86,395,396,87,379,380,87,395,396,88,381,382
            dw    88,395,396,89,383,384,89,388,396,90,385,386,90,388,389
            dw    91,387,389,$FFFF
ArRight     dw    83,599,601,84,599,600,84,602,603,85,592,600,85,604,605
            dw    86,592,593,86,606,607,87,592,593,87,608,609,88,592,593
            dw    88,606,607,89,592,600,89,604,605,90,599,600,90,602,603
            dw    91,599,601,$FFFF
ArUp        dw    97,356,357,98,354,355,98,358,359,99,352,353,99,360,361
            dw    100,350,351,100,362,363,101,348,353,101,360,365
            dw    102,352,353,102,360,361,103,352,353,103,360,361
            dw    104,352,353,104,360,361,105,352,361,$FFFF
ArDown      dw    159,352,361,160,352,353,160,360,361,161,352,353,161,360,361
            dw    162,352,353,162,360,361,163,348,353,163,360,365
            dw    164,350,351,164,362,363,165,352,353,165,360,361
            dw    166,354,355,166,358,359,167,356,357,$FFFF
GridRuns    dw    95,375,538,121,375,538,146,375,461
            dw    122,535,538,123,528,535,124,521,528,125,516,521,126,512,516
            dw    127,508,512,128,504,508,129,500,504,130,496,500,131,493,496
            dw    132,490,493,133,487,490,134,484,487,135,482,484,136,480,482
            dw    137,477,480,138,475,477,139,472,475,140,470,472,141,468,470
            dw    142,466,468,143,465,466,144,463,465,145,461,463,$FFFF

* The picture at the top: a true colour picture becomes a screen.
IconLoc     dw    $0080                 ; 640 mode
            adrl  IconPix
            dw    22                    ; bytes a line
            dw    0,0,8,88
IconRect    dw    0,0,8,84
IconPix     hex   FFF7777FFFFFFFFFFFFFFFFFFFFFFFFFFC0000000FFF
            hex   FFF4447FFFFFFFFFFFFFFC0FFFFFFFFFFC37FFFF0FFF
            hex   FFF4447FFFFFFFFFFFFFFF000FFFFFFFFDDDDDDDDFFF
            hex   FFF7777FFFFFFFFFFFFFFFC0000FFFFFFDDDDDDDDFFF
            hex   FBBBBDDDDFFFF0000000000000000FFFFDDDDDDDDFFF
            hex   F888BD111FFFFFFFFFFFFFC0000FFFFFFDDDDDDDDFFF
            hex   F888BD111FFFFFFFFFFFFF000FFFFFFFFDDDDDDDDFFF
            hex   FBBBBDDDDFFFFFFFFFFFFC0FFFFFFFFFFDDDDDDDDFFF

TxHMode     asc   'Graphic mode',00
TxHPal      asc   'Palette to use',00
TxHAlg      asc   'Rendering algorithm',00
TxHOpt      asc   'Other options',00
TxM0        asc   '320 x 200, 16 colors',00
TxM1        asc   '640 x 200, 4 colors',00
TxM2        asc   '640 x 200 dither mode',00
TxM3        asc   'Multipalette modes',00
TxP0        asc   'Default color',00
TxP1        asc   'Grayscale',00
TxP2        asc   'Calculated',00
TxP3        asc   'Stored palette',00
TxP4        asc   'Picture',27,'s current',00
TxA0        asc   'Closest match',00
TxA1        asc   'Pattern dither',00
TxA2        asc   'Error diffusion',00
TxO0        asc   'Integral scaling only',00
TxO1        asc   'Clip Horiz. before Vert.',00
TxO2        asc   'Clip to one screen',00
TxO3        asc   'Auto aspect ratio',00
TxGetOther  asc   'Get other...',00
TxInfo      asc   'Info on these options',00
TxCancel    asc   'Cancel',00
TxQuick     asc   'Quick remap',00
TxNormal    asc   'Normal remap',00
TxCounting  asc   'Counting colors...',00
TxDistinct  asc   'Distinct colors used:',00
TxDistrib   asc   'Distribution:',00
TxFull      asc   'full color',00
TxGreys     asc   'grayscale',00
TxBW        asc   'black & white',00
TxVert      asc   'Vertical scaling: from ',00
TxHorz      asc   'Horizontal: from ',00
TxTo        asc   ' to ',00
TxOpen      asc   ' (',00
TxColon     asc   ':',00
TxClose     asc   ')',00
TxClip      asc   'Clipped to ',00
TxTimes     asc   ' x ',00
TxScreen    asc   '1 Screen',00
TxOtherHead asc   'Other palettes for this mode',00
TxTechHead  asc   'Multipalette technique',00
InfoTxt     asc   '93/Graphic mode is the IIgs screen mode of the result, and Palette to use its '
            asc   'colors: Calculated finds the best ones for this picture. The scroll bars set '
            asc   'the size across and down; the diagram shows it against a grid of screens, the '
            asc   'thin outline the size asked for, the thick one what is remapped (one screen '
            asc   'at most). Quick remap ignores the options and makes a one-screen preview.'
            asc   '/^#0',00

* The names of each mode's other palettes (and multipalette's techniques).
OtherNames  da    On320,On640,On640D,OnMulti
On320       da    On320a,On320b,On320c,On320d,On320e,On320f
On640       da    On640a,On640b,On640c,On640d
On640D      da    On640Da,On640Db,On640Dc
OnMulti     da    OnMa,OnMb,OnMc,OnMd
On320a      asc   'Black & white only',00
On320b      asc   'Apple II LoRes/Double HiRes colors',00
On320c      asc   'Apple II HiRes colors',00
On320d      asc   'Calculate 14, leave 2 for editing',00
On320e      asc   'Calculate 9, leave 7 for editing',00
On320f      asc   'The palette Quick remap uses',00
On640a      asc   'Black & white only',00
On640b      asc   'Black, cyan, magenta, yellow',00
On640c      asc   'Red, green, blue, white',00
On640d      asc   '3 grays, leave a color for editing',00
On640Da     asc   'Black & white only',00
On640Db     asc   'Backwards default colors (flipped)',00
On640Dc     asc   'Grays, leave a color for editing',00
OnMa        asc   'Use no more than 8 palettes',00
OnMb        asc   'Optimized palettes (takes long)',00
OnMc        asc   'Zone division',00
OnMd        asc   'Zone division, at most 8 palettes',00

DlgWin      adrl  0
SubWin      adrl  0
Event       ds    16
DI          dw    0
RI          dw    0
RTop        dw    0
NBest       dw    0
ArStep      dw    0
ArDelta     dw    0
ArWait      dw    0
SubN        dw    0
SubList     dw    0
SubSel      dw    0
SubCancel   dw    0,256,0,326
OtherSet    dw    0,0,0,0               ; an other palette picked, by mode
ClickN      dw    0                     ; clicks given by a test
ClickI      dw    0
ClickQ      ds    64
Given       dw    0                     ; the event is one of them

DlgParms    dw    78
            dw    $2020                 ; an alert frame, visible
            adrl  0
            adrl  0
            dw    0,0,0,0
            adrl  0
            dw    0,0
            dw    0,0
            dw    0,0
            dw    0,0
            dw    0,0
            adrl  0
            dw    0
            adrl  0
            adrl  0
            adrl  0                     ; drawn by the dialog itself
            dw    20,10,192,630         ; top, left, bottom, right
            adrl  $FFFFFFFF
            adrl  0

* The Get other window: as wide as SubLeft to SubRight, its bottom set by
* the number of items (SubBottom: its offset in SubParms).
SubTop      =     44
SubLeft     =     150
SubRight    =     490
SubList0    =     25                    ; the first item's baseline
SubBottom   =     66
SubParms    dw    78
            dw    $2020
            adrl  0
            adrl  0
            dw    0,0,0,0
            adrl  0
            dw    0,0
            dw    0,0
            dw    0,0
            dw    0,0
            dw    0,0
            adrl  0
            dw    0
            adrl  0
            adrl  0
            adrl  0
            dw    SubTop,SubLeft,0,SubRight
            adrl  $FFFFFFFF
            adrl  0
