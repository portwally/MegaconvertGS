*-------------------------------------------------------------
* Examine.s - File > Examine file..., as SuperConvert's (part of the
* Extras segment; docs/superconvert-file.md 7): the chosen files, one
* after another, each in a window showing its data or resource fork as
* hex and text, or a histogram of its data fork's byte values.
*
* Not copied from the original: its percentage going wrong above 429,496
* occurrences of a byte, a dump line left blank where its read data
* ended, the window left behind when there was no memory for the buffer.
* Added: Escape, Apple-. and Apple-W close the window, the arrow keys
* scroll the dump (with Apple: a page) and move through the histogram.
*-------------------------------------------------------------

* Examine: the files chosen with Standard File (any file, invisible ones
* too), each examined in turn. dctl: 0 as usual; for tests a record:
*   +0 the file's path (GS/OS string), +4 a path to save the screen at
*   (a $C1 file) when the steps are done, +8 a buffer for a C string
*   about the window's state then, +12 how many steps, +14 the steps
*   (words, each taken at a null event): 1-3 that mode, as its button;
*   5-8 the scroll bar's part (arrows, pages); 9 h v the pointer at
*   h, v (the content's coordinates); 1000 + n the scroll bar's thumb
*   at n
Examine     ent
            phb
            phk
            plb
            tdc
            sta   ExDP
            lda   dctl
            sta   ExTest
            lda   dctl+2
            sta   ExTest+2
            ora   ExTest
            beq   :ask
            lda   ExTest                ; a test: its file
            sta   xp0
            lda   ExTest+2
            sta   xp0+2
            lda   [xp0]
            sta   ExPathP
            ldy   #2
            lda   [xp0],y
            sta   ExPathP+2
            jsr   ExamineOne
            plb
            rtl
:ask        pha                         ; invisible files listed too
            pea   1
            Tool  _SFShowInvisible
            pea   120
            pea   30
            PushLong 0
            pea   0                     ; the prompt: a Pascal string
            PushLong ExPrompt
            PushLong 0                  ; (no filter: any file can be chosen)
            PushLong 0
            PushLong ExTmpl
            PushLong 0
            PushLong ExReply
            Tool  _SFPMultiGet2
            pla                         ; (Standard File as it was)
            pha
            pha
            Tool  _SFShowInvisible
            pla
            lda   ExReply               ; cancelled
            beq   :out
            sta   ExCount
            lda   #2                    ; the entries: type, aux type, name
            sta   ExOff                 ; (a Pascal string), from offset 2
:each       jsr   NameAt
            bcs   :next
            jsr   ExamineOne
:next       jsr   NamesP                ; the next entry: 7 + its name
            ldy   ExOff
            iny
            iny
            iny
            iny
            iny
            iny
            lda   [xp0],y
            and   #$00FF
            clc
            adc   #7
            adc   ExOff
            sta   ExOff
            dec   ExCount
            bne   :each
            PushLongAt ExReply+2
            Tool  _DisposeHandle
:out        plb
            rtl

* NamesP: xp0 = the names (the reply's handle, locked).
NamesP      lda   ExReply+2
            sta   xp0
            lda   ExReply+4
            sta   xp0+2
            ldy   #2
            lda   [xp0],y
            tax
            lda   [xp0]
            sta   xp0
            stx   xp0+2
            rts

* NameAt: ExPathP = the full path of the entry at ExOff (Standard File
* gives the names with their prefix, "8:NAME").
*   out: carry set if it can't be had
NameAt      jsr   NamesP
            lda   ExOff
            clc
            adc   #6
            tay
            lda   [xp0],y
            and   #$00FF
            sta   ExName                ; its length
            ldx   #0
:c          cpx   ExName
            bcs   :exp
            iny
            lda   [xp0],y
            sep   #$20
            mx    %10
            sta   ExName+2,x
            rep   #$20
            mx    %00
            inx
            bra   :c
:exp        GSOS  _ExpandPathGS;ExExpand
            bcs   :out
            lda   #ExPath+2
            sta   ExPathP
            lda   #^ExPath
            sta   ExPathP+2
            clc
:out        rts

*-------------------------------------------------------------
* The window
*-------------------------------------------------------------

* ExamineOne: the file at ExPathP in its window, until that is closed (a
* folder, or a file with both forks empty: nothing).
ExamineOne  stz   ExErr
            stz   ExCounted
            stz   ExMode
            stz   ExMax
            stz   ExMax+2
            stz   ExTop
            stz   ExTop+2
            stz   ExLines
            stz   ExLines+2
            stz   ExS
            lda   #$FFFF
            sta   ExHi
            stz   ExSBarH
            stz   ExSBarH+2
            stz   ExStep
            lda   ExPathP
            sta   ExInfo+2
            lda   ExPathP+2
            sta   ExInfo+4
            GSOS  _GetFileInfoGS;ExInfo
            bcc   :info
            sta   ExErr
            jmp   ExAlert
:info       lda   ExInfo+8
            cmp   #$0F
            bne   :forks
            rts
:forks      lda   ExInfo+$24
            ora   ExInfo+$26
            ora   ExInfo+$2C
            ora   ExInfo+$2E
            bne   :title
            rts
:title      jsr   MakeTitle
            Tool  _InitCursor
            pha                         ; the window (hidden at first)
            pha
            PushLong ExTitle
            PushLong 0
            PushLong ExDraw
            PushLong 0
            pea   0                     ; the parameters: a pointer
            PushLong ExWParms
            pea   $800E
            Tool  _NewWindow2
            pla
            sta   ExWin
            pla
            sta   ExWin+2
            bcc   :buf
            lda   #$0201
            sta   ExErr
            jmp   ExAlert
:buf        pha                         ; the read buffer
            pha
            PushLong ExBufSize
            lda   uid
            pha
            pea   $C018
            PushLong 0
            Tool  _NewHandle
            pla
            sta   ExBufH
            pla
            sta   ExBufH+2
            bcc   :rgn
            lda   #$0201
            sta   ExErr
            PushLongAt ExWin
            Tool  _CloseWindow
            jmp   ExAlert
:rgn        lda   ExBufH
            sta   xp0
            lda   ExBufH+2
            sta   xp0+2
            ldy   #2
            lda   [xp0],y
            sta   ExBuf+2
            lda   [xp0]
            sta   ExBuf
            pha
            pha
            Tool  _NewRgn
            pla
            sta   ExRgn
            pla
            sta   ExRgn+2
            lda   #1                    ; the start: the data fork, unless it
            sta   ExNew                 ; is empty
            lda   ExInfo+$2C
            ora   ExInfo+$2E
            bne   :hasRes
            pea   255                   ; (no resource fork)
            pea   $0001
            pea   $0003
            jsr   CtlH
            Tool  _HiliteControl
            bra   :show
:hasRes     lda   ExInfo+$24
            ora   ExInfo+$26
            bne   :show
            pea   1                     ; (no data fork)
            pea   $0001
            pea   $0003
            jsr   CtlH
            Tool  _SetCtlValue
            pea   0
            pea   $0001
            pea   $0001
            jsr   CtlH
            Tool  _SetCtlValue
            pea   255
            pea   $0001
            pea   $0001
            jsr   CtlH
            Tool  _HiliteControl
            pea   255
            pea   $0001
            pea   $0002
            jsr   CtlH
            Tool  _HiliteControl
            lda   #3
            sta   ExNew
:show       PushLongAt ExWin
            Tool  _ShowWindow
            lda   ExNew
            jsr   SetMode
:loop       lda   ExErr
            beq   :task
            jmp   :close
:task       PushLongAt ExWin
            Tool  _SetPort
            pha
            pea   $FFFF
            PushLong ExTask
            Tool  _TaskMaster
            pla
            cmp   #wInControl
            beq   :ctl
            cmp   #$0016                ; (wInGoAway)
            beq   :close
            cmp   #3                    ; (keyDown, autoKey)
            beq   :key
            cmp   #5
            beq   :key
            cmp   #0
            bne   :loop
            lda   ExTest
            ora   ExTest+2
            beq   :mouse
            lda   ExTask                ; a test: its steps at null events
            bne   :loop
            jsr   TestStep
            bcs   :close
            bra   :loop
:mouse      lda   ExMode                ; the histogram: the value under the
            cmp   #2                    ; pointer
            bne   :loop
            lda   ExTask+$0A
            sta   ExPt
            lda   ExTask+$0C
            sta   ExPt+2
            PushLong ExPt
            Tool  _GlobalToLocal
            jsr   PointAt
            jmp   :loop
:ctl        pha                         ; a button: its mode
            pha
            PushLongAt ExTask+$1E
            Tool  _GetCtlID
            pla
            plx
            beq   :jloop
            jsr   SetMode
:jloop      jmp   :loop
:key        jsr   Key
            bcc   :jloop
:close      lda   #0                    ; (the fork closed)
            jsr   SetMode
            PushLongAt ExWin
            Tool  _CloseWindow
            PushLongAt ExBufH
            Tool  _DisposeHandle
            PushLongAt ExRgn
            Tool  _DisposeRgn
            lda   ExErr
            beq   :done
            jmp   ExAlert
:done       rts

* CtlH: the control whose ID is on the stack (a long, under the return
* address) replaced by its handle.
CtlH        pha                         ; (room for the handle)
            pha
            PushLongAt ExWin
            lda   13,s                  ; the ID's high word
            pha
            lda   13,s                  ; its low word
            pha
            Tool  _GetCtlHandleFromID
            pla                         ; the handle where the ID was
            sta   5,s
            pla
            sta   5,s
            rts

* MakeTitle: ExTitle = the path's last part (a Pascal string).
MakeTitle   lda   ExPathP
            sta   xp0
            lda   ExPathP+2
            sta   xp0+2
            lda   [xp0]
            clc
            adc   #2
            sta   ExEnd                 ; (past its last character)
            ldy   #2
            sty   ExFrom
:c          cpy   ExEnd                 ; after the last ':'
            bcs   :copy
            lda   [xp0],y
            and   #$00FF
            cmp   #':'
            bne   :n
            tya
            inc
            sta   ExFrom
:n          iny
            bra   :c
:copy       ldx   #0
            ldy   ExFrom
:p          cpy   ExEnd
            bcs   :end
            cpx   #255
            bcs   :end
            lda   [xp0],y
            sep   #$20
            mx    %10
            sta   ExTitle+1,x
            rep   #$20
            mx    %00
            inx
            iny
            bra   :p
:end        txa
            sep   #$20
            mx    %10
            sta   ExTitle
            rep   #$20
            mx    %00
            rts

* Key: the key in the task record. Escape, Apple-. and Apple-W close;
* the up and down arrows scroll a dump a line (with Apple: a page), the
* left and right arrows move along the histogram.
*   out: carry set to close
Key         lda   ExTask+2
            and   #$00FF
            cmp   #$1B
            beq   :close
            ldx   ExTask+$0E            ; (the modifiers)
            cmp   #'.'
            beq   :apple
            cmp   #'w'
            beq   :apple
            cmp   #'W'
            beq   :apple
            ldy   ExMode
            cpy   #2
            beq   :hist
            ldy   #5                    ; a dump: up or down
            cmp   #$0B
            beq   :scroll
            ldy   #6
            cmp   #$0A
            bne   :no
:scroll     txa
            and   #$0100
            beq   :line
            iny                         ; (Apple: a page)
            iny
:line       tya
            jsr   Scroll
:no         clc
            rts
:apple      txa
            and   #$0100
            beq   :no
:close      sec
            rts
:hist       ldx   ExHi                  ; the histogram: the value before
            cmp   #$08                  ; or after
            bne   :right
            dex
            bpl   :to
            ldx   #255
            bra   :to
:right      cmp   #$15
            bne   :no
            inx
            cpx   #256
            bcc   :to
            ldx   #0
:to         txa
            jsr   ShowValue
            clc
            rts

* SetMode: the window shows mode A (1 the data fork, 2 the histogram, 3
* the resource fork; 0: none, the window about to close). A dump starts
* at its top.
SetMode     cmp   ExMode
            bne   :change
            rts
:change     sta   ExNew
            lda   ExMode                ; a dump's fork closed
            cmp   #1
            beq   :shut
            cmp   #3
            bne   :closed
:shut       lda   ExRef
            sta   ExClose+2
            GSOS  _CloseGS;ExClose
:closed     lda   ExNew
            sta   ExMode
            bne   :show
            rts
:show       PushLongAt ExWin
            Tool  _SetPort
            PushLong ExAll              ; all below the buttons drawn again
            Tool  _InvalRect
            PushLong ExAll
            Tool  _EraseRect
            lda   ExSBarH               ; no scroll bar
            ora   ExSBarH+2
            beq   :nobar
            PushLongAt ExSBarH
            Tool  _DisposeControl
            stz   ExSBarH
            stz   ExSBarH+2
:nobar      lda   ExMode
            cmp   #2
            beq   :hist
            lsr                         ; a dump: its fork (0 data, 1 resource)
            sta   ExOpen+10
            ldx   #$24
            cmp   #0
            beq   :eof
            ldx   #$2C
:eof        lda   ExInfo,x
            sta   ExEOF
            lda   ExInfo+2,x
            sta   ExEOF+2
            stz   ExTop
            stz   ExTop+2
            stz   ExValid
            jsr   MakeBar
            lda   ExPathP
            sta   ExOpen+4
            lda   ExPathP+2
            sta   ExOpen+6
            GSOS  _OpenGS;ExOpen
            bcs   :err
            lda   ExOpen+2
            sta   ExRef
            rts
:err        sta   ExErr
            rts
:hist       lda   #$FFFF                ; the histogram: no value shown
            sta   ExHi
            lda   ExCounted
            bne   :out
            inc   ExCounted
            jsr   CountAll
:out        rts

* MakeBar: the dump's scroll bar: its lines (16 bytes each) brought below
* 32768 by s right shifts, 17 lines in view.
MakeBar     lda   ExEOF                 ; lines = (EOF + 15) / 16
            clc
            adc   #15
            sta   ExLines
            lda   ExEOF+2
            adc   #0
            sta   ExLines+2
            ldx   #4
:d16        lsr   ExLines+2
            ror   ExLines
            dex
            bne   :d16
            lda   ExLines               ; the most the top line can be
            sec
            sbc   #17
            sta   ExMaxTop
            lda   ExLines+2
            sbc   #0
            sta   ExMaxTop+2
            bpl   :sh
            stz   ExMaxTop
            stz   ExMaxTop+2
:sh         lda   ExLines
            sta   ExT
            lda   ExLines+2
            sta   ExT+2
            stz   ExS
:s          lda   ExT+2
            bne   :more
            lda   ExT
            bpl   :size
:more       lsr   ExT+2
            ror   ExT
            inc   ExS
            bra   :s
:size       sta   ExSMax
            lda   #17
            ldx   ExS
            beq   :view
:vs         lsr
            dex
            bne   :vs
            cmp   #0
            bne   :view
            lda   #1
:view       sta   ExSView
            stz   ExSVal
            pha
            pha
            PushLongAt ExWin
            pea   0
            PushLong ExSBar
            Tool  _NewControl2
            pla
            sta   ExSBarH
            pla
            sta   ExSBarH+2
            PushLong ExAction
            PushLongAt ExSBarH
            Tool  _SetCtlAction
            rts

*-------------------------------------------------------------
* Drawing
*-------------------------------------------------------------

* ExDraw: the window's content (the Window Manager calls it).
ExDraw      phb
            phk
            plb
            phd
            lda   ExDP
            tcd
            pha
            pha
            Tool  _GetPort
            Tool  _DrawControls
            lda   ExErr
            bne   :out
            lda   ExMode
            beq   :out
            cmp   #2
            beq   :hist
            Tool  _PenNormal            ; a dump: a line under the buttons,
            pea   0                     ; then its 17 lines
            pea   12
            Tool  _MoveTo
            pea   640
            pea   0
            Tool  _Line
            lda   #0
            ldx   #16
            jsr   DrawLines
            bra   :out
:hist       jsr   DrawHist
:out        pld
            plb
            rtl

* DrawLines: the dump's lines A to X (0-16 in the window).
DrawLines   sta   ExR
            stx   ExRLast
:r          jsr   DrawLine
            lda   ExErr
            bne   :out
            lda   ExR
            cmp   ExRLast
            bcs   :out
            inc   ExR
            bra   :r
:out        rts

* DrawLine: the dump's line ExR: "OOOOOO | xx ... xx | " and the bytes
* as text, every character 8 pixels across.
DrawLine    lda   ExR                   ; its offset: (top + r) x 16
            clc
            adc   ExTop
            sta   ExOffL
            lda   ExTop+2
            adc   #0
            sta   ExOffL+2
            ldx   #4
:x16        asl   ExOffL
            rol   ExOffL+2
            dex
            bne   :x16
            lda   ExOffL                ; past the end: nothing
            sec
            sbc   ExEOF
            lda   ExOffL+2
            sbc   ExEOF+2
            bcc   :in
            rts
:in         lda   ExEOF                 ; its bytes: up to 16
            sec
            sbc   ExOffL
            tax
            lda   ExEOF+2
            sbc   ExOffL+2
            bne   :full
            cpx   #16
            bcc   :n
:full       ldx   #16
:n          stx   ExN
            jsr   Have                  ; (read if they aren't in the buffer)
            bcc   :got
            rts
:got        lda   ExOffL+2              ; the offset: 6 hex digits
            ldx   #0
            jsr   HexAt
            lda   ExOffL
            xba
            ldx   #2
            jsr   HexAt
            lda   ExOffL
            ldx   #4
            jsr   HexAt
            lda   ExBuf                 ; the bytes
            clc
            adc   ExIdx
            sta   xp0
            lda   ExBuf+2
            adc   #0
            sta   xp0+2
            ldy   #0
            ldx   #9
:hex        cpy   ExN
            bcs   :blank
            lda   [xp0],y
            phy
            jsr   HexAt
            ply
            bra   :hn
:blank      lda   #'  '
            sta   ExLine,x
:hn         inx
            inx
            inx
            iny
            cpy   #16
            bcc   :hex
            pea   2                     ; drawn: the hex part
            Tool  _SetFontFlags
            pea   0
            Tool  _SetForeColor
            pea   3
            Tool  _SetBackColor
            pea   5
            lda   ExR                   ; (baseline 21 + 9r)
            asl
            asl
            asl
            adc   ExR
            adc   #21
            pha
            Tool  _MoveTo
            PushLong ExLine
            Tool  _DrawCString
            ldy   #0                    ; the text: runs of bytes with the same
:run        cpy   ExN                   ; top three bits
            bcc   :byte
            cpy   #16
            bcc   :jx1
            jmp   :done
:jx1
            lda   #16                   ; (past the end: spaces)
            sec
            sbc   ExN
            sta   ExRunL
            lda   #1
            jsr   RunColours
            PushLong ExSpaces
            lda   ExRunL
            pha
            Tool  _DrawText
            bra   :done
:byte       lda   [xp0],y
            and   #$00E0
            sta   ExCls
            ldx   #0
:same       lda   [xp0],y
            and   #$00FF
            pha
            and   #$00E0
            cmp   ExCls
            beq   :char
            pla
            bra   :draw
:char       pla                         ; its character: the low 7 bits,
            and   #$007F                ; $7F a triangle, controls as @, A ...
            cmp   #$7F
            bne   :ctrl
            lda   #$C6
            bra   :put
:ctrl       cmp   #$20
            bcs   :put
            ora   #$40
:put        sep   #$20
            mx    %10
            sta   ExText,x
            rep   #$20
            mx    %00
            inx
            iny
            cpy   ExN
            bcc   :same
:draw       stx   ExRunL
            phy
            lda   ExCls
            lsr                         ; (the top three bits: 0-7)
            lsr
            lsr
            lsr
            lsr
            jsr   RunColours
            PushLong ExText
            lda   ExRunL
            pha
            Tool  _DrawText
            ply
            jmp   :run
:done       pea   0
            Tool  _SetFontFlags
            rts

* RunColours: the text's colours for bytes whose top three bits are A:
* controls in colour 1, $80-$FF on colour 2.
RunColours  asl
            tax
            phx
            lda   ExFore,x
            pha
            Tool  _SetForeColor
            plx
            lda   ExBack,x
            pha
            Tool  _SetBackColor
            rts

* HexAt: A's low byte as 2 hex digits at ExLine + X.
HexAt       pha
            lsr
            lsr
            lsr
            lsr
            and   #$000F
            tay
            lda   SHexD,y
            sep   #$20
            mx    %10
            sta   ExLine,x
            rep   #$20
            mx    %00
            pla
            and   #$000F
            tay
            lda   SHexD,y
            sep   #$20
            mx    %10
            sta   ExLine+1,x
            rep   #$20
            mx    %00
            rts

* Have: the fork's bytes ExOffL to ExOffL + ExN in the buffer, read if
* need be (from 16K before them, at a multiple of 256); ExIdx: where.
*   out: carry set on an error
Have        lda   ExValid
            beq   :read
            lda   ExOffL                ; before the buffer's?
            sec
            sbc   ExStart
            tax
            lda   ExOffL+2
            sbc   ExStart+2
            bcc   :read
            bne   :read
            txa                         ; past them?
            clc
            adc   ExN
            bcs   :read
            cmp   ExGot
            beq   :ok
            bcs   :read
:ok         stx   ExIdx
            clc
            rts
:read       lda   ExOffL
            sec
            sbc   #16384
            and   #$FF00
            sta   ExStart
            lda   ExOffL+2
            sbc   #0
            sta   ExStart+2
            bcs   :mark
            stz   ExStart
            stz   ExStart+2
:mark       lda   ExRef
            sta   ExMark+2
            sta   ExRead+2
            lda   ExStart
            sta   ExMark+6
            lda   ExStart+2
            sta   ExMark+8
            GSOS  _SetMarkGS;ExMark
            bcs   :err
            Tool  _WaitCursor
            jsr   ReadPiece
            php
            pha
            Tool  _InitCursor
            pla
            plp
            bcs   :err
            lda   #1
            sta   ExValid
            lda   ExOffL                ; there now?
            sec
            sbc   ExStart
            tax
            clc
            adc   ExN
            cmp   ExGot
            beq   :ok
            bcc   :ok
            lda   #$004C                ; (the file shorter than it said)
:err        sta   ExErr
            sec
            rts

* ReadPiece: up to 32K of the open fork into the buffer; ExGot: how many.
*   out: carry set on an error (its end is no error)
ReadPiece   lda   ExRef
            sta   ExRead+2
            lda   ExBuf
            sta   ExRead+4
            lda   ExBuf+2
            sta   ExRead+6
            lda   #$8000
            sta   ExRead+8
            stz   ExRead+10
            stz   ExRead+12
            GSOS  _ReadGS;ExRead
            bcc   :got
            cmp   #$004C
            bne   :err
:got        lda   ExRead+12
            sta   ExGot
            clc
            rts
:err        sec
            rts

* Scroll: the dump moved by the scroll bar's part A: 5 and 6 a line up and
* down, 7 and 8 a page (16 lines), $81 to its thumb.
Scroll      sta   ExPart
            lda   ExSBarH
            ora   ExSBarH+2
            bne   :bar
            rts
:bar        lda   ExPart
            cmp   #$81
            beq   :thumb
            sec
            sbc   #5
            cmp   #4
            bcc   :step
            rts
:step       asl
            tax
            lda   ExTop
            clc
            adc   ExDelta,x
            sta   ExNewT
            lda   ExDelta,x
            and   #$8000                ; (sign extended)
            beq   :pos
            lda   #$FFFF
:pos        adc   ExTop+2
            sta   ExNewT+2
            bra   :clamp
:thumb      pha                         ; the thumb's value, x 2^s
            PushLongAt ExSBarH
            Tool  _GetCtlValue
            pla
            sta   ExNewT
            stz   ExNewT+2
            ldx   ExS
            beq   :clamp
:ts         asl   ExNewT
            rol   ExNewT+2
            dex
            bne   :ts
:clamp      lda   ExNewT+2              ; 0 to the last top line
            bpl   :notNeg
            stz   ExNewT
            stz   ExNewT+2
:notNeg     lda   ExMaxTop
            sec
            sbc   ExNewT
            lda   ExMaxTop+2
            sbc   ExNewT+2
            bcs   :move
            lda   ExMaxTop
            sta   ExNewT
            lda   ExMaxTop+2
            sta   ExNewT+2
:move       lda   ExNewT                ; d = new - top
            sec
            sbc   ExTop
            sta   ExD
            lda   ExNewT+2
            sbc   ExTop+2
            tax
            lda   ExNewT
            sta   ExTop
            lda   ExNewT+2
            sta   ExTop+2
            txa                         ; (d's high word)
            beq   :down
            cmp   #$FFFF
            bne   :all
            lda   ExD                   ; -16 to -1: down by -9d, the top
            cmp   #-16                  ; lines drawn
            bcc   :all
            eor   #$FFFF
            inc
            sta   ExD
            asl
            asl
            asl
            adc   ExD
            jsr   ScrollBy
            lda   ExD
            dec
            tax
            lda   #0
            jsr   DrawLines
            bra   :value
:down       lda   ExD                   ; 1 to 16: up by 9d, the bottom ones
            beq   :value
            cmp   #17
            bcs   :all
            asl
            asl
            asl
            adc   ExD
            eor   #$FFFF
            inc
            jsr   ScrollBy
            lda   #17
            sec
            sbc   ExD
            ldx   #16
            jsr   DrawLines
            bra   :value
:all        lda   #0                    ; further: every line
            ldx   #16
            jsr   DrawLines
:value      lda   ExTop                 ; the thumb: top / 2^s
            sta   ExT
            lda   ExTop+2
            sta   ExT+2
            ldx   ExS
            beq   :set
:vs         lsr   ExT+2
            ror   ExT
            dex
            bne   :vs
:set        lda   ExT
            pha
            PushLongAt ExSBarH
            Tool  _SetCtlValue
            rts

* ScrollBy: the dump's lines moved down by A pixels (negative: up).
ScrollBy    tax
            PushLong ExLinesR
            pea   0
            phx
            PushLongAt ExRgn
            Tool  _ScrollRect
            rts

* ExAction: the scroll bar's action procedure (the Control Manager calls
* it with a part code and the control's handle while it is clicked).
ExAction    phb
            phk
            plb
            phd
            lda   ExDP
            tcd
            lda   9,s                   ; (the part code on top, as Pascal
            cmp   ExSBarH               ; pushes them; or the other way round)
            bne   :swap
            lda   11,s
            cmp   ExSBarH+2
            bne   :swap
            lda   7,s
            bra   :part
:swap       lda   11,s
:part       jsr   Scroll
            pld
            plb
            lda   2,s                   ; the parameters off the stack
            sta   8,s
            lda   1,s
            sta   7,s
            pla
            pla
            pla
            rtl

*-------------------------------------------------------------
* The histogram
*-------------------------------------------------------------

* CountAll: each byte value counted through the data fork, the largest
* count, each value's bar height (count x 140 / largest).
CountAll    Tool  _WaitCursor
            ldx   #0
:z          stz   ExCounts,x
            inx
            inx
            cpx   #1024
            bcc   :z
            stz   ExOpen+10             ; the data fork
            lda   ExPathP
            sta   ExOpen+4
            lda   ExPathP+2
            sta   ExOpen+6
            GSOS  _OpenGS;ExOpen
            bcc   :open
            sta   ExErr
            jmp   :cursor
:open       lda   ExOpen+2
            sta   ExRef
:piece      jsr   ReadPiece
            bcc   :got
            sta   ExErr
            bra   :shut
:got        lda   ExBuf
            sta   xp0
            lda   ExBuf+2
            sta   xp0+2
            ldy   #0
            lda   ExGot
            beq   :shut
:b          lda   [xp0],y
            and   #$00FF
            asl
            asl
            tax
            inc   ExCounts,x
            bne   :nx
            inc   ExCounts+2,x
:nx         iny
            cpy   ExGot
            bcc   :b
            lda   ExGot
            cmp   #$8000
            bcs   :piece
:shut       lda   ExRef
            sta   ExClose+2
            GSOS  _CloseGS;ExClose
            stz   ExMax                 ; the largest
            stz   ExMax+2
            ldx   #0
:m          lda   ExCounts,x
            cmp   ExMax
            lda   ExCounts+2,x
            sbc   ExMax+2
            bcc   :mn
            lda   ExCounts,x
            sta   ExMax
            lda   ExCounts+2,x
            sta   ExMax+2
:mn         inx
            inx
            inx
            inx
            cpx   #1024
            bcc   :m
            lda   ExMax                 ; (at least 1)
            ora   ExMax+2
            bne   :h
            inc   ExMax
:h          ldx   #0                    ; the heights; counts kept below 2^24
:hv         phx
            lda   ExCounts,x
            sta   ExNum
            lda   ExCounts+2,x
            sta   ExNum+2
            lda   ExMax
            sta   ExDen
            lda   ExMax+2
            sta   ExDen+2
            and   #$FF00
            beq   :mul
            ldy   #8
:sc         lsr   ExNum+2
            ror   ExNum
            lsr   ExDen+2
            ror   ExDen
            dey
            bne   :sc
:mul        lda   #140
            jsr   MulK
            jsr   Div32
            pla
            pha
            lsr
            tax
            lda   ExNum
            sta   ExHeights,x
            plx
            inx
            inx
            inx
            inx
            cpx   #1024
            bcc   :hv
:cursor     Tool  _InitCursor
            rts

* DrawHist: the histogram: under each group of 16 values a scale, each
* value that occurs as a bar up from row 152, the info line.
DrawHist    PushLong ExPat
            Tool  _SetPenPat
            lda   #1
            sta   ExBox+2
            lda   #34
            sta   ExBox+6
:box        PushLong ExBox
            Tool  _PaintRect
            lda   ExBox+2
            clc
            adc   #40
            sta   ExBox+2
            lda   ExBox+6
            clc
            adc   #40
            sta   ExBox+6
            cmp   #640
            bcc   :box
            Tool  _PenNormal
            stz   ExV
:bar        lda   ExV
            ldx   #0
            cmp   ExHi
            bne   :colour
            inx
:colour     txa
            jsr   DrawBar
            inc   ExV
            lda   ExV
            cmp   #256
            bcc   :bar
            jmp   InfoLine

* DrawBar: value ExV's bar in colour A (if it occurs).
DrawBar     tax
            lda   ExV
            asl
            asl
            tay
            lda   ExCounts,y
            ora   ExCounts+2,y
            bne   :draw
            rts
:draw       phx
            Tool  _SetSolidPenPat
            pea   1
            pea   1
            Tool  _SetPenSize
            lda   ExV                   ; h: 40 x (v >> 4) + 2 x (v & 15) + 2
            and   #$00F0
            lsr
            lsr
            lsr
            lsr
            sta   ExT
            asl
            asl
            adc   ExT
            asl
            asl
            asl
            sta   ExT
            lda   ExV
            and   #$000F
            asl
            adc   ExT
            adc   #2
            pha
            pea   152
            Tool  _MoveTo
            pea   0
            lda   ExV
            asl
            tax
            lda   ExHeights,x
            eor   #$FFFF
            inc
            pha
            Tool  _Line
            rts

* PointAt: the value under the point ExPt (v, h in the content): none
* outside the bars' columns (a bar's and the one right of it).
PointAt     ldx   #$FFFF
            lda   ExPt                  ; rows 12-156
            cmp   #12
            bmi   :to
            cmp   #157
            bpl   :to
            lda   ExPt+2                ; (h - 2) / 2 = 20k + r, r < 16
            sec
            sbc   #2
            bmi   :to
            lsr
            ldy   #0
:k          cmp   #20
            bcc   :r
            sbc   #20
            iny
            bra   :k
:r          cmp   #16
            bcs   :to
            cpy   #16
            bcs   :to
            sta   ExT
            tya
            asl
            asl
            asl
            asl
            ora   ExT
            tax
:to         txa

* ShowValue: value A ($FFFF: none) shown: its bar in colour 1, the one
* before in colour 0 again, the info line.
ShowValue   cmp   ExHi
            bne   :new
            rts
:new        ldx   ExHi
            sta   ExHi
            cpx   #256
            bcs   :old
            stx   ExV
            lda   #0
            jsr   DrawBar
:old        lda   ExHi
            cmp   #256
            bcs   :info
            sta   ExV
            lda   #1
            jsr   DrawBar
:info       jmp   InfoLine

* InfoLine: under the histogram, about the value shown:
*   "A"  $41 hex   65 decimal          12 occurrences,   0.52% of file
InfoLine    pea   0
            Tool  _SetForeColor
            pea   3
            Tool  _SetBackColor
            PushLong ExInfoR
            Tool  _EraseRect
            lda   ExHi
            cmp   #256
            bcc   :text
            rts
:text       jsr   InfoText
            pea   0
            Tool  _SetFontFlags
            pea   10
            pea   166
            Tool  _MoveTo
            PushLong ExIS
            Tool  _DrawString
            rts

* InfoText: ExIS (a Pascal string) about value ExHi.
InfoText    stz   ExISL
            lda   ExHi
            cmp   #$20
            bcc   :ctrl
            lda   #'"'                  ; "x"
            jsr   IPut
            lda   ExHi
            jsr   IPut
            lda   #'"'
            bra   :q
:ctrl       lda   #'^'                  ; ^X and a space
            jsr   IPut
            lda   ExHi
            ora   #$40
            jsr   IPut
            lda   #' '
:q          jsr   IPut
            lda   #TxDollar
            jsr   IPutS
            lda   ExHi
            ldx   #0
            jsr   HexAt
            lda   ExLine
            jsr   IPut
            lda   ExLine+1
            jsr   IPut
            lda   #TxHex
            jsr   IPutS
            lda   ExHi
            sta   ExNum
            stz   ExNum+2
            lda   #3
            jsr   IPutDec
            lda   #TxDecimal
            jsr   IPutS
            lda   ExHi
            asl
            asl
            tax
            lda   ExCounts,x
            sta   ExNum
            lda   ExCounts+2,x
            sta   ExNum+2
            lda   #7
            jsr   IPutDec
            lda   #TxOccur
            jsr   IPutS
            jsr   Percent               ; count x 10000 / the data fork's size
            sta   ExNum
            stz   ExNum+2
            lda   #5
            jsr   IPutDec               ; (5 places, then 2 of them after a
            ldx   ExISL                 ; point, blanks before it as 0; ExIS
            sep   #$20                  ; + 1 + i holds character i)
            mx    %10
            lda   ExIS-2,x              ; (the third digit)
            cmp   #' '
            bne   :d3
            lda   #'0'
            sta   ExIS-2,x
:d3         lda   ExIS-1,x              ; (the fourth)
            cmp   #' '
            bne   :pt
            lda   #'0'
            sta   ExIS-1,x
:pt         lda   ExIS,x                ; the last two moved right, '.' before
            sta   ExIS+1,x
            lda   ExIS-1,x
            sta   ExIS,x
            lda   #'.'
            sta   ExIS-1,x
            rep   #$20
            mx    %00
            inc   ExISL
            lda   #TxOfFile
            jsr   IPutS
            lda   ExISL
            sep   #$20
            mx    %10
            sta   ExIS
            rep   #$20
            mx    %00
            rts

* Percent: A = count x 10000 / the data fork's size, exactly
* (q1 = count x 100 / size, then (q1 x 100) + (the remainder x 100 /
* size); sizes over 42,949,672 brought down first).
Percent     lda   ExHi
            asl
            asl
            tax
            lda   ExCounts,x
            sta   ExNum
            lda   ExCounts+2,x
            sta   ExNum+2
            lda   ExInfo+$24
            sta   ExDen
            lda   ExInfo+$26
            sta   ExDen+2
:big        lda   ExDen                 ; (x 100 must fit in 32 bits)
            cmp   #$5C29
            lda   ExDen+2
            sbc   #$028F
            bcc   :fits
            lsr   ExDen+2
            ror   ExDen
            lsr   ExNum+2
            ror   ExNum
            bra   :big
:fits       lda   #100
            jsr   MulK
            jsr   Div32
            lda   ExNum                 ; q1 x 100
            asl
            asl
            sta   ExT
            asl
            asl
            asl
            sta   ExT+2
            asl
            adc   ExT+2
            adc   ExT
            sta   ExQ
            lda   ExRem                 ; the remainder x 100 / size
            sta   ExNum
            lda   ExRem+2
            sta   ExNum+2
            lda   #100
            jsr   MulK
            jsr   Div32
            lda   ExNum
            clc
            adc   ExQ
            rts

* IPut: the character A onto ExIS; IPutS: the C string at A.
IPut        ldx   ExISL
            sep   #$20
            mx    %10
            sta   ExIS+1,x
            rep   #$20
            mx    %00
            inc   ExISL
            rts
IPutS       sta   xw1
            ldy   #0
:c          lda   (xw1),y
            and   #$00FF
            beq   :end
            phy
            jsr   IPut
            ply
            iny
            bra   :c
:end        rts

* IPutDec: ExNum in decimal, right-aligned in A places (more if need be).
IPutDec     sta   ExW
            ldx   #0
:d          phx
            jsr   Div10L
            plx
            clc
            adc   #'0'
            sta   ExDigits,x
            inx
            inx
            lda   ExNum
            ora   ExNum+2
            bne   :d
            stx   ExT
            lda   ExW                   ; the spaces before
            asl
            sec
            sbc   ExT
            bcc   :digits
            beq   :digits
            lsr
            tax
:sp         phx
            lda   #' '
            jsr   IPut
            plx
            dex
            bne   :sp
:digits     ldx   ExT
:o          dex
            dex
            lda   ExDigits,x
            phx
            jsr   IPut
            plx
            cpx   #0
            bne   :o
            rts

*-------------------------------------------------------------
* Arithmetic (unsigned)
*-------------------------------------------------------------

* Div10L: ExNum = ExNum / 10, A = the remainder.
Div10L      lda   #0
            ldx   #32
:b          asl   ExNum
            rol   ExNum+2
            rol
            cmp   #10
            bcc   :n
            sbc   #10
            inc   ExNum
:n          dex
            bne   :b
            rts

* MulK: ExNum = ExNum x A (the product's low 32 bits).
MulK        sta   ExK
            lda   ExNum
            sta   ExM
            lda   ExNum+2
            sta   ExM+2
            stz   ExNum
            stz   ExNum+2
:b          lsr   ExK
            bcc   :s
            clc
            lda   ExNum
            adc   ExM
            sta   ExNum
            lda   ExNum+2
            adc   ExM+2
            sta   ExNum+2
:s          asl   ExM
            rol   ExM+2
            lda   ExK
            bne   :b
            rts

* Div32: ExNum = ExNum / ExDen, ExRem the remainder (ExDen below 2^31).
Div32       stz   ExRem
            stz   ExRem+2
            ldx   #32
:b          asl   ExNum
            rol   ExNum+2
            rol   ExRem
            rol   ExRem+2
            lda   ExRem
            sec
            sbc   ExDen
            tay
            lda   ExRem+2
            sbc   ExDen+2
            bcc   :n
            sta   ExRem+2
            sty   ExRem
            inc   ExNum
:n          dex
            bne   :b
            rts

*-------------------------------------------------------------
* Errors, tests
*-------------------------------------------------------------

* ExAlert: "I am having a hard time viewing this file." with ExErr.
ExAlert     lda   ExErr
            xba
            pha
            and   #$00FF
            ldx   #ExErrHex-ExLine
            jsr   HexAt
            pla
            xba
            ldx   #ExErrHex-ExLine+2
            jsr   HexAt
            pha
            pea   0
            PushLong 0
            PushLong ExErrMsg
            Tool  _AlertWindow
            pla
            rts

* TestStep: a test's next step; when they are done, the window's state
* (a C string in the test's buffer) and the screen saved.
*   out: carry set to close the window
TestStep    lda   ExTest
            sta   xp0
            lda   ExTest+2
            sta   xp0+2
            ldy   #12
            lda   [xp0],y
            asl
            clc
            adc   #14
            sta   ExT                   ; (past the last step)
            lda   ExStep
            asl
            clc
            adc   #14
            cmp   ExT
            bcc   :step
            jmp   TestEnd
:step       tay
            lda   [xp0],y
            inc   ExStep
            cmp   #4
            bcs   :notMode
            pha                         ; a mode, as its button: the buttons
            jsr   Radios                ; set, then the mode
            pla
            jsr   SetMode
            clc
            rts
:notMode    cmp   #9
            bne   :notPt
            iny                         ; the pointer at h, v
            iny
            lda   [xp0],y
            sta   ExPt+2
            iny
            iny
            lda   [xp0],y
            sta   ExPt
            inc   ExStep
            inc   ExStep
            jsr   PointAt
            clc
            rts
:notPt      cmp   #1000
            bcc   :part
            sec                         ; the thumb at n
            sbc   #1000
            pha
            PushLongAt ExSBarH
            Tool  _SetCtlValue
            lda   #$81
:part       jsr   Scroll
            clc
            rts

* Radios: the buttons for mode A: its own on, the others off.
Radios      sta   ExT
            ldx   #1
:b          phx
            lda   #0
            cpx   ExT
            bne   :v
            inc
:v          pha
            PushLongAt ExWin
            pea   $0001
            phx
            Tool  _SetCtlValueByID
            plx
            inx
            cpx   #4
            bcc   :b
            rts

* TestEnd: the window's state for the test's log, the screen saved.
TestEnd     ldy   #8                    ; (PutC writes at SBuf)
            lda   [xp0],y
            sta   SBuf
            iny
            iny
            lda   [xp0],y
            sta   SBuf+2
            stz   SLen
            lda   #TxTMode
            jsr   PutS
            lda   ExMode
            jsr   PutDec
            lda   #TxTTop
            jsr   PutS
            lda   ExTop
            ldy   ExTop+2
            jsr   PutDecL
            lda   #TxTLines
            jsr   PutS
            lda   ExLines
            ldy   ExLines+2
            jsr   PutDecL
            lda   #TxTShift
            jsr   PutS
            lda   ExS
            jsr   PutDec
            lda   #TxTThumb
            jsr   PutS
            stz   ExT
            lda   ExSBarH
            ora   ExSBarH+2
            beq   :th
            pha
            PushLongAt ExSBarH
            Tool  _GetCtlValue
            pla
            sta   ExT
:th         lda   ExT
            jsr   PutDec
            lda   #TxTMax
            jsr   PutS
            lda   ExMax
            ldy   ExMax+2
            jsr   PutDecL
            lda   #TxTValue
            jsr   PutS
            lda   ExHi
            cmp   #256
            bcs   :none
            jsr   PutDec
            lda   #TxTInfo
            jsr   PutS
            jsr   InfoText
            ldx   #0
:is         cpx   ExISL
            bcs   :end
            lda   ExIS+1,x
            and   #$00FF
            phx
            jsr   PutC
            plx
            inx
            bra   :is
:none       lda   #TxTNone
            jsr   PutS
:end        lda   #0
            jsr   PutC
            lda   ExTest                ; the screen saved
            sta   xp0
            lda   ExTest+2
            sta   xp0+2
            ldy   #4
            lda   [xp0],y
            sta   ExDestroy+2
            sta   ExCreate+2
            sta   ExOpenW+4
            iny
            iny
            lda   [xp0],y
            sta   ExDestroy+4
            sta   ExCreate+4
            sta   ExOpenW+6
            GSOS  _DestroyGS;ExDestroy
            GSOS  _CreateGS;ExCreate
            GSOS  _OpenGS;ExOpenW
            bcs   :out
            lda   ExOpenW+2
            sta   ExWrite+2
            sta   ExClose+2
            GSOS  _WriteGS;ExWrite
            GSOS  _CloseGS;ExClose
:out        sec
            rts

* PutDecL: Y:A in decimal (onto the text at SBuf).
PutDecL     sta   ExNum
            sty   ExNum+2
            ldx   #0
:d          phx
            jsr   Div10L
            plx
            clc
            adc   #'0'
            sta   ExDigits,x
            inx
            inx
            lda   ExNum
            ora   ExNum+2
            bne   :d
:o          dex
            dex
            lda   ExDigits,x
            phx
            jsr   PutC
            plx
            cpx   #0
            bne   :o
            rts

*-------------------------------------------------------------
* Data
*-------------------------------------------------------------
ExBufSize   =     32768
ExDP        dw    0
ExTest      adrl  0
ExReply     dw    0                     ; how many chosen,
            adrl  0                     ; their names
ExCount     dw    0
ExOff       dw    0
ExPathP     adrl  0                     ; the file's path (GS/OS string)
ExErr       dw    0
ExWin       adrl  0
ExBufH      adrl  0
ExBuf       adrl  0
ExRgn       adrl  0
ExSBarH     adrl  0
ExMode      dw    0                     ; 1 data fork, 2 histogram, 3 resource
ExNew       dw    0
ExRef       dw    0
ExEOF       adrl  0                     ; the dump's fork's size
ExLines     adrl  0                     ; its lines
ExMaxTop    adrl  0
ExS         dw    0                     ; the scroll bar's shift
ExTop       adrl  0                     ; the top line
ExNewT      adrl  0
ExD         dw    0
ExPart      dw    0
ExR         dw    0
ExRLast     dw    0
ExOffL      adrl  0
ExN         dw    0
ExIdx       dw    0
ExValid     dw    0
ExStart     adrl  0                     ; the buffer: from where in the fork,
ExGot       dw    0                     ; how many bytes
ExCls       dw    0
ExRunL      dw    0
ExCounted   dw    0
ExHi        dw    $FFFF                 ; the value shown in the histogram
ExV         dw    0
ExMax       adrl  0
ExNum       adrl  0
ExDen       adrl  0
ExRem       adrl  0
ExM         adrl  0
ExK         dw    0
ExQ         dw    0
ExW         dw    0
ExT         adrl  0
ExStep      dw    0
ExEnd       dw    0
ExFrom      dw    0
ExISL       dw    0
ExPt        dw    0,0                   ; v, h
ExDigits    ds    24
ExCounts    ds    1024                  ; the byte values' counts (longs)
ExHeights   ds    512                   ; their bars' heights
ExDelta     dw    -1,1,-16,16
ExFore      dw    1,0,0,0,1,0,0,0       ; the text's colours by the top bits
ExBack      dw    3,3,3,3,2,2,2,2
ExAll       dw    12,0,200,640          ; below the buttons
ExLinesR    dw    14,2,167,610          ; the dump's lines
ExInfoR     dw    157,0,167,640         ; the info line
ExBox       dw    153,1,157,34          ; a scale (moved right 40 at a time)
* The scales' pattern (rows 153-156 of the window use its rows 1-4)
ExPat       hex   1000DDDDBFBFBFBFBFFFFFFFFFFFFFFF
            hex   FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
ExLine      asc   'OOOOOO | xx xx xx xx xx xx xx xx xx xx xx xx xx xx xx xx | ',00
ExSpaces    asc   '                '
ExText      ds    16
ExErrMsg    asc   '52/I am having a hard time viewing this file (error $'
ExErrHex    asc   '0000)./^#0',00
ExIS        ds    82                    ; the info line (a Pascal string)
ExTitle     ds    256
ExName      dw    0                     ; a name from the reply (GS/OS string)
            ds    260
ExPath      dw    516                   ; its full path
            ds    514
ExExpand    dw    2
            adrl  ExName
            adrl  ExPath
ExInfo      dw    11                    ; GetFileInfo: +8 type, +$24 the data
            adrl  0                     ; fork's size, +$2C the resource fork's
            dw    0,0
            adrl  0
            dw    0
            ds    16
            adrl  0
            adrl  0,0,0
ExOpen      dw    4                     ; a fork, to read
            dw    0
            adrl  0
            dw    1,0
ExMark      dw    3
            dw    0,0
            adrl  0
ExRead      dw    4
            dw    0
            adrl  0,0,0
ExClose     dw    1
            dw    0
ExDestroy   dw    1
            adrl  0
ExCreate    dw    5
            adrl  0
            dw    $C3,$C1
            adrl  0
            dw    1
ExOpenW     dw    2
            dw    0
            adrl  0
ExWrite     dw    4
            dw    0
            adrl  $E12000,$8000,0
ExTask      dw    0                     ; TaskMaster's record
            adrl  0,0
            dw    0,0,0
            adrl  0
            adrl  $00130106             ; updates, close box, the controls
            adrl  0
            dw    0
            adrl  0,0,0
            ds    16
TxDollar    asc   '  $',00
TxHex       asc   ' hex  ',00
TxDecimal   asc   ' decimal     ',00
TxOccur     asc   ' occurrences, ',00
TxOfFile    asc   '% of file',00
TxTMode     asc   'mode ',00
TxTTop      asc   ', top ',00
TxTLines    asc   ', lines ',00
TxTShift    asc   ', shift ',00
TxTThumb    asc   ', thumb ',00
TxTMax      asc   ', max ',00
TxTValue    asc   ', value ',00
TxTNone     asc   'none',00
TxTInfo     asc   ': ',00
ExPrompt    str   'Select file(s) to examine:'

* The window (SuperConvert's LONGCODE $0420, $0492): title bar and close
* box, its three buttons.
ExWParms    dw    $50,$C000
            adrl  0,0
            dw    0,0,0,0
            adrl  0
            dw    0,0,0,0,0,0,0,0,0,0
            adrl  0
            dw    0
            adrl  0,0,0
            dw    30,2,197,638
            adrl  $FFFFFFFF
            adrl  ExCtls
            dw    $0003
ExCtls      adrl  ExRad1,ExRad2,ExRad3,0
ExRad1      dw    8
            adrl  $00010001
            dw    1,10,0,0
            adrl  $84000000
            dw    0,$1000
            adrl  0
            adrl  TxExData
            dw    1
ExRad2      dw    8
            adrl  $00010002
            dw    1,160,0,0
            adrl  $84000000
            dw    0,$1000
            adrl  0
            adrl  TxExHist
            dw    0
ExRad3      dw    8
            adrl  $00010003
            dw    1,320,0,0
            adrl  $84000000
            dw    0,$1000
            adrl  0
            adrl  TxExRes
            dw    0
* The dump's scroll bar (LONGCODE $0532)
ExSBar      dw    9
            adrl  1
            dw    12,612,168,638
            adrl  $86000000
            dw    $0003,$1000
            adrl  0
ExSMax      dw    0
ExSView     dw    0
ExSVal      dw    0
TxExData    str   'Data fork'
TxExHist    str   'Histogram'
TxExRes     str   'Resource fork'

* The file dialog (segment 2 $60FB): Standard File's items 1-8.
ExTmpl      dw    0,0,114,400
            dw    $FFFF
            adrl  0
            adrl  ExIt1,ExIt2,ExIt3,ExIt4,ExIt5,ExIt6,ExIt7,ExIt8,0
ExIt1       dw    1,61,265,73,375,$000A
            adrl  TxExOpen
            dw    0,0
            adrl  0
ExIt2       dw    2,79,265,91,375,$000A
            adrl  TxExClose
            dw    0,0
            adrl  0
ExIt3       dw    3,25,265,37,375,$000A
            adrl  TxExVolume
            dw    0,0
            adrl  0
ExIt4       dw    4,97,265,109,375,$000A
            adrl  TxExCancel
            dw    0,0
            adrl  0
ExIt5       dw    5,43,265,55,375,$000A
            adrl  TxExAccept
            dw    0,0
            adrl  0
ExIt6       dw    6,12,15,24,395,$0014
            adrl  0
            dw    0,0
            adrl  0
ExIt7       dw    7,25,18,107,215,$8014
            adrl  0
            dw    0,0
            adrl  0
ExIt8       dw    8,3,15,12,395,$800F
            adrl  0
            dw    0,0
            adrl  0
TxExOpen    str   'Open'
TxExClose   str   'Close'
TxExVolume  str   'Volume'
TxExCancel  str   'Cancel'
TxExAccept  str   'Accept'
