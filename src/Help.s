*-------------------------------------------------------------
* Help.s - Help!, Menu item help and the help window, as SuperConvert's
* (a segment of its own; docs/superconvert-extras.md 2.2-2.4), with
* MegaconvertGS's own help text: the file MCGS.Help in the program's
* folder (prefix 1; build.sh makes it from help/MCGS.Help.txt).
*
* The file: lines ending in CR. A page follows its label lines (".NAME";
* several may name one page) and ends with its navigation line
* "^~previous~next~back" (labels; an empty one: that item off). Its
* lines: text (joined into one static text while the next line starts
* with a letter, a digit or a character $20-$2D); an empty line (5
* pixels); "\N~title~LABEL..." a row of N buttons going to those pages;
* "=0" the Back history cleared, "=1" a pixel, "=2" up 9 pixels; ">..."
* (pictures: none here, skipped). A label not found shows the file's
* first page.
*-------------------------------------------------------------
            rel
            mx    %00
            use   macros/Macs.s
            put   Equates.s

hp          =     $D0                   ; the help text (a long pointer)
hq          =     $D4                   ; (a long pointer)

*-------------------------------------------------------------
* Entry points
*-------------------------------------------------------------

* HelpGo: the help window shows the page labelled with the Pascal string
* at dctl (the window opened and the file read first, if need be).
HelpGo      ent
            phb
            phk
            plb
            tdc
            sta   HDP
            lda   [dctl]                ; the label (31 characters at most)
            and   #$00FF
            cmp   #32
            bcc   :len
            lda   #31
:len        tax
            sep   #$20
            mx    %10
            sta   GoLabel
:c          txy
            beq   :cd
            lda   [dctl],y
            sta   GoLabel,y
            dex
            bra   :c
:cd         rep   #$20
            mx    %00
            jsr   Open
            bcs   :out
            stz   RestV
            stz   RestH
            jsr   GoTo
:out        plb
            rtl

* HelpHome: Help!: the help window's first page; if the window is open,
* it only comes to the front (its page stays).
HelpHome    ent
            phb
            phk
            plb
            lda   HlpWin
            ora   HlpWin+2
            beq   :home
            PushLongAt HlpWin
            Tool  _SelectWindow
            plb
            rtl
:home       plb
            lda   #TxLabHome            ; (HelpGo with "HOME")
            sta   dctl
            lda   #^TxLabHome
            sta   dctl+2
            jml   HelpGo

* HelpTask: TaskMaster's result A while the help window is open (dctl:
* the event record): its close box, its buttons, its info bar, the keys
* while it is in front; $FFFF: the Close command, for it if it is in
* front. A is kept.
*   out: carry set if it was the help window's
HelpTask    ent
            phb
            phk
            plb
            sta   HCode
            tdc
            sta   HDP
            lda   HlpWin
            ora   HlpWin+2
            bne   :jx1
            jmp   :no
:jx1
            ldy   #$10                  ; (the event's window)
            lda   [dctl],y
            sta   EvWin
            iny
            iny
            lda   [dctl],y
            sta   EvWin+2
            jsr   IsFront
            sta   Front
            lda   HCode
            cmp   #wInGoAway
            bne   :n1
            jsr   OurWin
            bcc   :no
            jsr   Close
            bra   :yes
:n1         cmp   #$FFFF
            bne   :n2
            lda   Front
            beq   :no
            jsr   Close
            bra   :yes
:n2         cmp   #wInControl
            bne   :n3
            lda   Front
            beq   :no
            ldy   #$1E                  ; (the control)
            lda   [dctl],y
            sta   EvCtl
            iny
            iny
            lda   [dctl],y
            sta   EvCtl+2
            jsr   Button
            bra   :yes
:n3         cmp   #wInInfo
            bne   :n4
            jsr   OurWin
            bcc   :no
            jsr   InfoClick
            bra   :yes
:n4         cmp   #wInContent
            bne   :n5
            jsr   OurWin
            bcc   :no
            bra   :yes                  ; (the text: nothing to do)
:n5         cmp   #3                    ; keys (not their repeats)
            bne   :n6
            lda   Front
            beq   :no
            ldy   #2
            lda   [dctl],y
            and   #$00FF
            jsr   Key
            bra   :yes
:n6         cmp   #5
            bne   :no
            lda   Front                 ; (a repeat: nothing, but ours)
            beq   :no
            bra   :yes
:yes        lda   HCode
            sec
            plb
            rtl
:no         lda   HCode
            clc
            plb
            rtl

* OurWin: carry set if the event's window is the help window.
OurWin      lda   EvWin
            cmp   HlpWin
            bne   :no
            lda   EvWin+2
            cmp   HlpWin+2
            bne   :no
            sec
            rts
:no         clc
            rts

* IsFront: A = 1 if the help window is the front window.
IsFront     pha
            pha
            Tool  _FrontWindow
            pla
            plx
            cmp   HlpWin
            bne   :no
            cpx   HlpWin+2
            bne   :no
            lda   #1
            rts
:no         lda   #0
            rts

* HelpMenu: Apple > Menu item help: the next menu item chosen (dimmed
* ones too), or its Apple-key shortcut, shows that command's page.
HelpMenu    ent
            phb
            phk
            plb
            tdc
            sta   HDP
            pea   $0001                 ; (dimmed items can be chosen)
            Tool  _MenuGlobal
            stz   MItem
:wait       pha                         ; a click or a key
            pea   $002A
            PushLong HTask
            Tool  _GetNextEvent
            pla
            beq   :wait
            lda   HTask
            cmp   #3
            beq   :key
            cmp   #5
            beq   :key
            cmp   #1
            bne   :done
            pha                         ; a click: in the menu bar?
            PushLong HWin
            lda   HTask+$0C
            pha
            lda   HTask+$0A
            pha
            Tool  _FindWindow
            pla
            cmp   #wInMenuBar
            bne   :done
            PushLong HTask
            PushLong 0
            Tool  _MenuSelect
            bra   :item
:key        PushLong HTask              ; a key: its menu item
            PushLong 0
            Tool  _MenuKey
:item       lda   HTask+$10
            sta   MItem
            lda   HTask+$12
            sta   MMenu
:done       pea   $FFFE
            Tool  _MenuGlobal
            Tool  _InitCursor
            lda   MItem                 ; its page: "I" and its number;
            beq   :none                 ; a desk accessory's "DA"
            cmp   #250
            bcc   :da
            ldx   #1
            ldy   #'I'
            jsr   LabelNum
            bra   :go
:da         lda   #TxLabDA
            jsr   SetGo
            bra   :go
:none       lda   #TxLabMenus
            jsr   SetGo
:go         jsr   Open
            bcs   :out
            stz   RestV
            stz   RestH
            jsr   GoTo
            pea   0                     ; the menu unlit
            lda   MMenu
            pha
            Tool  _HiliteMenu
:out        plb
            rtl

* SetGo: GoLabel = the Pascal string at A (this bank).
SetGo       sta   hq
            lda   #^GoLabel
            sta   hq+2
            lda   [hq]
            and   #$00FF
            tay
            sep   #$20
            mx    %10
:c          lda   [hq],y
            sta   GoLabel,y
            dey
            bpl   :c
            rep   #$20
            mx    %00
            rts

* LabelNum: GoLabel = the character Y and A in decimal.
LabelNum    sta   LNum
            tya
            sep   #$20
            mx    %10
            sta   GoLabel+1
            rep   #$20
            mx    %00
            stz   LDig                  ; the digits, last first
:d          lda   LNum
            jsr   Div10
            sta   LNum
            tya
            clc
            adc   #'0'
            pha
            inc   LDig
            lda   LNum
            bne   :d
            lda   LDig
            inc
            sep   #$20
            mx    %10
            sta   GoLabel
            rep   #$20
            mx    %00
            ldy   #2
            ldx   LDig
:o          pla
            sep   #$20
            mx    %10
            sta   GoLabel,y
            rep   #$20
            mx    %00
            iny
            dex
            bne   :o
            rts

* Div10: A = A / 10, Y = the remainder.
Div10       ldy   #0
            sta   DvN
            lda   #0
            ldx   #16
:b          asl   DvN
            rol
            cmp   #10
            bcc   :n
            sbc   #10
            inc   DvN
:n          dex
            bne   :b
            tay
            lda   DvN
            rts

* HelpLog: for tests: a C string at dctl about the page shown: its label,
* its navigation labels, how many buttons, its height.
HelpLog     ent
            phb
            phk
            plb
            stz   LogAt
            lda   #CurLabel
            jsr   LogP
            lda   #TxLPrev
            jsr   LogS
            lda   #NavPrev
            jsr   LogP
            lda   #TxLNext
            jsr   LogS
            lda   #NavNext
            jsr   LogP
            lda   #TxLBack
            jsr   LogS
            lda   #NavBack
            jsr   LogP
            lda   #TxLBtns
            jsr   LogS
            lda   NBtn
            jsr   LogN
            lda   #TxLHigh
            jsr   LogS
            lda   V
            clc
            adc   #3
            jsr   LogN
            lda   #0
            jsr   LogC
            plb
            rtl

* LogC: the character A at dctl (LogAt); LogS: the C string at A; LogP:
* the Pascal string at A; LogN: A in decimal.
LogC        ldy   LogAt
            sep   #$20
            mx    %10
            sta   [dctl],y
            rep   #$20
            mx    %00
            inc   LogAt
            rts
LogS        sta   hq
            lda   #^TxLPrev
            sta   hq+2
            ldy   #0
:c          lda   [hq],y
            and   #$00FF
            beq   :e
            phy
            jsr   LogC
            ply
            iny
            bra   :c
:e          rts
LogP        sta   hq
            lda   #^TxLPrev
            sta   hq+2
            lda   [hq]
            and   #$00FF
            sta   LogN0
            ldy   #1
:c          dec   LogN0
            bmi   :e
            lda   [hq],y
            and   #$00FF
            phy
            jsr   LogC
            ply
            iny
            bra   :c
:e          rts
LogN        stz   LogK
:d          jsr   Div10                 ; (it uses X)
            pha
            tya
            clc
            adc   #'0'
            ldx   LogK
            sta   LogDig,x
            inx
            inx
            stx   LogK
            pla
            bne   :d
            ldx   LogK
:o          dex
            dex
            lda   LogDig,x
            phx
            jsr   LogC
            plx
            cpx   #0
            bne   :o
            rts

*-------------------------------------------------------------
* The window
*-------------------------------------------------------------

* Open: the help window, in front (the file read first).
*   out: carry set if the file can't be read (the alert shown)
Open        lda   HlpWin
            ora   HlpWin+2
            beq   :file
            PushLongAt HlpWin
            Tool  _SelectWindow
            clc
            rts
:file       lda   HlpBufH
            ora   HlpBufH+2
            bne   :win
            jsr   LoadFile
            bcc   :win
            pha                         ; "... the help file."
            pea   0
            PushLong 0
            PushLong TxNoHelp
            Tool  _AlertWindow
            pla
            sec
            rts
:win        pha
            pha
            PushLong TxHelpTitle
            PushLong 0
            PushLong HelpDraw
            PushLong 0
            pea   0
            PushLong HlpParms
            pea   $800E
            Tool  _NewWindow2
            pla
            sta   HlpWin
            pla
            sta   HlpWin+2
            stz   Depth                 ; (no history)
            clc
            rts

* Close: the help window closed; the text let go.
Close       PushLongAt HlpWin
            Tool  _CloseWindow
            stz   HlpWin
            stz   HlpWin+2
            lda   HlpBufH
            ora   HlpBufH+2
            beq   :out
            PushLongAt HlpBufH
            Tool  _DisposeHandle
            stz   HlpBufH
            stz   HlpBufH+2
:out        rts

* LoadFile: MCGS.Help (prefix 1) read into a new handle (a CR added at
* its end).
*   out: carry set if it can't be
LoadFile    GSOS  _OpenGS;HOpen
            bcc   :open
            rts
:open       lda   HOpen+2
            sta   HEof+2
            sta   HRead+2
            sta   HClose+2
            GSOS  _GetEOFGS;HEof
            bcc   :jx2
            jmp   :shut
:jx2
            lda   HEof+6                ; (at most 64K less a little)
            bne   :big
            lda   HEof+4
            cmp   #65000
            bcc   :size
:big        lda   #65000
:size       sta   HlpLen
            inc
            pha
            pha
            pea   0
            pha
            lda   uid
            pha
            pea   $C018
            PushLong 0
            Tool  _NewHandle
            pla
            sta   HlpBufH
            pla
            sta   HlpBufH+2
            bcs   :shut
            lda   HlpBufH
            sta   hq
            lda   HlpBufH+2
            sta   hq+2
            ldy   #2
            lda   [hq],y
            sta   HlpBuf+2
            sta   HRead+6
            lda   [hq]
            sta   HlpBuf
            sta   HRead+4
            lda   HlpLen
            sta   HRead+8
            stz   HRead+10
            GSOS  _ReadGS;HRead
            bcs   :free
            lda   HlpBuf
            sta   hp
            lda   HlpBuf+2
            sta   hp+2
            ldy   HlpLen                ; (a CR at the end)
            lda   #$0D
            sep   #$20
            mx    %10
            sta   [hp],y
            rep   #$20
            mx    %00
            inc   HlpLen
            GSOS  _CloseGS;HClose
            clc
            rts
:free       PushLongAt HlpBufH
            Tool  _DisposeHandle
            stz   HlpBufH
            stz   HlpBufH+2
:shut       GSOS  _CloseGS;HClose
            sec
            rts

* HelpDraw: the window's contents (the Window Manager calls it): its
* controls (the page's texts and buttons).
HelpDraw    phb
            phk
            plb
            pha
            pha
            Tool  _GetPort
            Tool  _DrawControls
            plb
            rtl

*-------------------------------------------------------------
* Pages
*-------------------------------------------------------------

* GoTo: the page labelled GoLabel shown (scrolled to RestV, RestH).
GoTo        lda   HlpBuf
            sta   hp
            lda   HlpBuf+2
            sta   hp+2
            ldx   #30                   ; it is the current one now
:cp         lda   GoLabel,x
            sta   CurLabel,x
            dex
            dex
            bpl   :cp
            jsr   Find
            PushLongAt HlpWin
            Tool  _StartDrawing
            PushLongAt HlpWin           ; the old page's controls gone
            Tool  _KillControls
            pea   0
            pea   0
            Tool  _SetOrigin
            PushLong AllRect
            Tool  _EraseRect
            PushLong AllRect
            Tool  _InvalRect
            jsr   Layout
            pea   0                     ; the page's height
            lda   V
            clc
            adc   #3
            pha
            PushLongAt HlpWin
            Tool  _SetDataSize
            pea   0                     ; scrolled as asked (normally the top)
            lda   RestH
            pha
            lda   RestV
            pha
            PushLongAt HlpWin
            Tool  _SetContentOrigin2
            stz   RestV
            stz   RestH
            PushLongAt HlpWin
            Tool  _DrawInfoBar
            rts

* Find: Pos = the line after the label line ".GoLabel" (the case of its
* letters aside); none: the file's start (its first page).
Find        ldy   #0
:scan       cpy   HlpLen
            bcs   :none
            lda   [hp],y
            iny
            and   #$00FF
            cmp   #$0D
            bne   :scan
            cpy   HlpLen
            bcs   :none
            lda   [hp],y
            and   #$00FF
            cmp   #'.'
            bne   :scan
            iny
            jsr   Match
            bcs   :scan
            sty   Pos
            rts
:none       stz   Pos
            rts

* Match: carry clear (Y past its line) if the text at Y is GoLabel and
* a CR; else carry set (Y kept).
Match       sty   MAt
            lda   GoLabel
            and   #$00FF
            sta   MLen
            ldx   #0
:c          cpx   MLen
            bcs   :end
            lda   [hp],y
            eor   GoLabel+1,x
            and   #$005F
            bne   :no
            iny
            inx
            bra   :c
:end        lda   [hp],y
            and   #$00FF
            cmp   #$0D
            bne   :no
            iny
            clc
            rts
:no         ldy   MAt
            sec
            rts

* Layout: the page from Pos: its texts and buttons as controls, from 3
* pixels down (V: past the last); its navigation line read.
Layout      lda   #3
            sta   V
            stz   NBtn
            stz   NavPrev
            stz   NavNext
            stz   NavBack
            ldy   Pos
:line       cpy   HlpLen
            bcc   :more
            rts
:more       lda   [hp],y
            and   #$00FF
            cmp   #$0D                  ; an empty line: 5 pixels
            bne   :notCR
            iny
            lda   V
            clc
            adc   #5
            sta   V
            bra   :line
:notCR      cmp   #'.'                  ; a label line: skipped
            beq   :skip
            cmp   #'>'                  ; a picture: none here
            beq   :skip
            cmp   #'='
            bne   :notEq
            iny
            lda   [hp],y
            and   #$00FF
            cmp   #'0'
            bne   :eq1
            stz   Depth                 ; =0: no Back history
            bra   :skip
:eq1        cmp   #'1'
            bne   :eq2
            inc   V                     ; =1: a pixel
            bra   :skip
:eq2        cmp   #'2'
            bne   :skip
            lda   V                     ; =2: up 9 pixels
            sec
            sbc   #9
            sta   V
            bra   :skip
:notEq      cmp   #'\'
            bne   :notBtn
            jsr   Buttons
            bra   :line
:notBtn     cmp   #'^'
            bne   :text
            iny                         ; "^" and a digit: text
            lda   [hp],y
            dey
            and   #$00FF
            cmp   #'0'
            bcc   :nav
            cmp   #'9'+1
            bcc   :text
:nav        jmp   Nav
:text       jsr   Text
            bra   :line
:skip       jsr   EndLine
            jmp   :line

* EndLine: Y past the CR ending its line.
EndLine     lda   [hp],y
            iny
            and   #$00FF
            cmp   #$0D
            bne   EndLine
            rts

* Text: a static text from the line at Y, the next ones joined while
* they start with a letter, a digit or $20-$2D and it stays under 320
* characters.
Text        sty   TStart
            lda   #1
            sta   TLines
:end        jsr   EndLine               ; (Y: the next line)
            cpy   HlpLen
            bcs   :made
            phy                         ; (with the next line, it stays under
            jsr   EndLine               ; 320 characters)
            tya
            ply
            sec
            sbc   TStart
            cmp   #320
            bcs   :made
            lda   [hp],y
            and   #$00FF
            cmp   #$20
            bcc   :made
            cmp   #$2E
            bcc   :join
            cmp   #'0'
            bcc   :made
            cmp   #'9'+1
            bcc   :join
            and   #$00DF
            cmp   #'A'
            bcc   :made
            cmp   #'Z'+1
            bcs   :made
:join       inc   TLines
            bra   :end
:made       sty   TNext
            tya                         ; its size: up to its last CR
            sec
            sbc   TStart
            dec
            sta   STSize
            lda   hp                    ; its text, in the file
            clc
            adc   TStart
            sta   STText
            lda   hp+2
            adc   #0
            sta   STText+2
            lda   V                     ; its place: 9 pixels a line
            sta   STRect
            lda   TLines
            asl
            asl
            asl
            adc   TLines
            adc   V
            sta   STRect+4
            sta   V
            pha
            pha
            PushLongAt HlpWin
            pea   0
            PushLong STTmpl
            Tool  _NewControl2
            pla
            pla
            ldy   TNext
            rts

* Buttons: a row "\N~title~LABEL~...": N buttons (the width by N), the
* titles and labels kept for the page; an empty title: no button there.
Buttons     iny                         ; N
            lda   [hp],y
            and   #$00FF
            sec
            sbc   #'0'
            beq   :bad
            cmp   #10
            bcc   :n
:bad        jmp   EndLine
:n          sta   BN
            asl
            tax
            lda   BWidths-2,x
            sta   BW
            iny
            lda   #6
            sta   BLeft
            stz   BI
:b          lda   BI
            cmp   BN
            bcc   :pair
            jsr   EndLine
            lda   V                     ; (rows 15 pixels high)
            clc
            adc   #15
            sta   V
            rts
:pair       lda   NBtn                  ; its title and label, kept
            cmp   #MaxBtn
            bcc   :jx3
            jmp   :skipB
:jx3
            asl
            asl
            asl
            asl
            asl
            pha
            asl
            clc
            adc   #BTitles
            tax
            jsr   Field
            pla
            clc
            adc   #BLabels
            tax
            jsr   Field
            lda   NBtn                  ; (a title: a button)
            asl
            asl
            asl
            asl
            asl
            asl
            tax
            lda   BTitles,x
            and   #$00FF
            beq   :next
            stx   BTRef
            lda   #BTitles
            clc
            adc   BTRef
            sta   BTmpl+26
            lda   #^BTitles
            sta   BTmpl+28
            lda   NBtn                  ; (its ID: 1 ...)
            inc
            sta   BTmpl+2
            lda   V
            inc
            sta   BTmpl+6
            clc
            adc   #13
            sta   BTmpl+10
            lda   BLeft
            sta   BTmpl+8
            clc
            adc   BW
            sta   BTmpl+12
            phy
            pha
            pha
            PushLongAt HlpWin
            pea   0
            PushLong BTmpl
            Tool  _NewControl2
            pla
            pla
            ply
            inc   NBtn
            bra   :next
:skipB      ldx   #Scratch              ; (too many: read past)
            jsr   Field
            ldx   #Scratch
            jsr   Field
:next       lda   BLeft
            clc
            adc   BW
            adc   #20
            sta   BLeft
            inc   BI
            jmp   :b

* Field: the field at Y ("~" and its text up to the next "~" or CR) as a
* Pascal string at X (this bank; 31 characters at most); Y at its end.
Field       stx   FAt
            stz   FLen
            lda   [hp],y
            and   #$00FF
            cmp   #'~'
            bne   :end
            iny
:c          lda   [hp],y
            and   #$00FF
            cmp   #'~'
            beq   :end
            cmp   #$0D
            beq   :end
            ldx   FLen
            cpx   #31
            bcs   :skip
            inx
            stx   FLen
            pha
            txa
            clc
            adc   FAt
            tax
            pla
            sep   #$20
            mx    %10
            sta   |0,x
            rep   #$20
            mx    %00
:skip       iny
            bra   :c
:end        lda   FLen
            ldx   FAt
            sep   #$20
            mx    %10
            sta   |0,x
            rep   #$20
            mx    %00
            rts

* Nav: the navigation line "^~previous~next~back": the page's end.
Nav         iny
            ldx   #NavPrev
            jsr   Field
            ldx   #NavNext
            jsr   Field
            ldx   #NavBack
            jsr   Field
            rts

*-------------------------------------------------------------
* The info bar: Home, Previous, Next, Back
*-------------------------------------------------------------

* HelpInfo: the info bar (the Window Manager calls it with its rect, its
* refCon and the window): the four items, those not available greyed.
HelpInfo    phb
            phk
            plb
            phd
            lda   HDP
            tcd
            lda   15,s                  ; the bar's rect
            sta   hq
            lda   17,s
            sta   hq+2
            ldy   #6
:r          lda   [hq],y
            sta   IRect,y
            dey
            dey
            bpl   :r
            jsr   DrawBar
            pld
            plb
            lda   2,s                   ; the parameters off the stack
            sta   14,s
            lda   1,s
            sta   13,s
            tsc
            clc
            adc   #12
            tcs
            rtl

* DrawBar: the four items in the bar at IRect.
DrawBar     PushLong IRect
            Tool  _EraseRect
            Tool  _PenNormal
            pea   0
            Tool  _SetTextMode
            pea   0
            Tool  _SetForeColor
            pea   $FFFF
            Tool  _SetBackColor
            lda   #1
            sta   BItem
:i          lda   BItem                 ; its icon
            dec
            asl
            tax
            lda   IconX,x
            clc
            adc   IRect+2
            sta   DX
            lda   IRect
            inc
            sta   DY
            lda   IconSrc,x
            sta   ISrc
            clc
            adc   #9
            sta   ISrc+4
            PushLong IconLoc
            PushLong ISrc
            lda   DX
            pha
            lda   DY
            pha
            pea   0
            Tool  _PPToPort
            lda   BItem                 ; its name
            dec
            asl
            tax
            lda   LabelX,x
            clc
            adc   IRect+2
            pha
            lda   IRect
            clc
            adc   #9
            pha
            Tool  _MoveTo
            lda   BItem
            dec
            asl
            tax
            lda   LabelTx,x
            tax
            pea   ^TxHome
            phx
            Tool  _DrawString
            lda   BItem                 ; not available: greyed
            jsr   Avail
            bne   :next
            jsr   ItemArea
            PushLong GreyMask
            Tool  _SetPenMask
            pea   3                     ; (white, through the mask)
            Tool  _SetSolidPenPat
            PushLong IArea
            Tool  _PaintRect
            Tool  _PenNormal
:next       inc   BItem
            lda   BItem
            cmp   #5
            bcs   :jx4
            jmp   :i
:jx4
            rts

* Avail: A = 1 if item A (1 Home ... 4 Back) can be used now.
Avail       cmp   #1
            beq   :yes
            cmp   #2
            bne   :n2
            lda   NavPrev
            bra   :len
:n2         cmp   #3
            bne   :n3
            lda   NavNext
            bra   :len
:n3         lda   Depth                 ; Back: the history, or the page's
            bne   :yes
            lda   NavBack
:len        and   #$00FF
            beq   :out
:yes        lda   #1
:out        rts

* ItemArea: IArea = item BItem's area in the bar at IRect.
ItemArea    lda   BItem
            dec
            asl
            tax
            lda   IRect
            sta   IArea
            lda   IRect+4
            sta   IArea+4
            lda   AreaL,x
            clc
            adc   IRect+2
            sta   IArea+2
            lda   AreaR,x
            clc
            adc   IRect+2
            sta   IArea+6
            rts

* InfoClick: a click in the info bar: the item under it tracked like a
* button; released on it, its action.
InfoClick   PushLong IRect
            PushLongAt HlpWin
            Tool  _StartInfoDrawing
            lda   [dctl]                ; (where: local now)
            ldy   #$0A
            lda   [dctl],y
            sta   IPt
            ldy   #$0C
            lda   [dctl],y
            sta   IPt+2
            PushLong IPt
            Tool  _GlobalToLocal
            lda   #1
            sta   BItem
:find       jsr   ItemArea
            pha
            PushLong IPt
            PushLong IArea
            Tool  _PtInRect
            pla
            bne   :got
            inc   BItem
            lda   BItem
            cmp   #5
            bcc   :find
            jmp   :end
:got        lda   BItem
            jsr   Avail
            beq   :end
            PushLong IArea              ; tracked while the button is down
            Tool  _InvertRect
            lda   #1
            sta   IIn
:track      pha
            pea   0
            Tool  _StillDown
            pla
            beq   :up
            PushLong IPt
            Tool  _GetMouse
            pha
            PushLong IPt
            PushLong IArea
            Tool  _PtInRect
            pla
            cmp   IIn
            beq   :track
            sta   IIn
            PushLong IArea
            Tool  _InvertRect
            bra   :track
:up         lda   IIn
            beq   :end
            PushLong IArea
            Tool  _InvertRect
            Tool  _EndInfoDrawing
            lda   BItem
            jmp   Act
:end        Tool  _EndInfoDrawing
            rts

* Key: a key while the help window is in front: H Home, the left and
* right arrows Previous and Next, the up and down arrows Back (the item
* flashes first).
Key         ldx   #1
            cmp   #'h'
            beq   :item
            cmp   #'H'
            beq   :item
            ldx   #2
            cmp   #$08
            beq   :item
            ldx   #3
            cmp   #$15
            beq   :item
            ldx   #4
            cmp   #$0A
            beq   :item
            cmp   #$0B
            beq   :item
            rts
:item       stx   BItem
            txa
            jsr   Avail
            bne   :ok
            rts
:ok         PushLong IRect
            PushLongAt HlpWin
            Tool  _StartInfoDrawing
            jsr   ItemArea
            PushLong IArea
            Tool  _InvertRect
            PushLong IArea
            Tool  _InvertRect
            Tool  _EndInfoDrawing
            lda   BItem

* Act: item A's action: Home, Previous and Next go to their pages; Back
* to the last page the history holds, else the page's own Back.
Act         cmp   #4
            beq   :back
            cmp   #1
            bne   :pn
            lda   #TxLabHome
            jsr   SetGo
            bra   :go
:pn         ldx   #NavPrev
            cmp   #2
            beq   :lab
            ldx   #NavNext
:lab        txa
            jsr   SetGo
:go         stz   RestV
            stz   RestH
            jmp   GoTo
:back       lda   Depth
            beq   :own
            dec   Depth                 ; the last one kept: its label, where
            lda   Depth                 ; it was scrolled to
            jsr   HistAt
            ldy   #0
:h          lda   History,x
            sta   GoLabel,y
            inx
            inx
            iny
            iny
            cpy   #32
            bcc   :h
            lda   History,x
            sta   RestV
            lda   History+2,x
            sta   RestH
            jmp   GoTo
:own        lda   #NavBack
            jsr   SetGo
            bra   :go

* HistAt: X = history entry A's offset (36 bytes each).
HistAt      asl
            asl
            sta   HT
            asl
            asl
            asl
            clc
            adc   HT
            tax
            rts

* Button: a page's button: the page it names (the history keeps this
* one and where it was scrolled to, 20 deep).
Button      pha
            pha
            PushLongAt EvCtl
            Tool  _GetCtlID
            pla
            plx
            dec
            bmi   :out                  ; (a text: ID 0)
            cmp   NBtn
            bcs   :out
            sta   BI
            lda   Depth
            cmp   #20
            bcs   :keep
            jsr   HistAt
            ldy   #0
:c          lda   CurLabel,y
            sta   History,x
            inx
            inx
            iny
            iny
            cpy   #32
            bcc   :c
            phx
            pha
            pha
            PushLongAt HlpWin
            Tool  _GetContentOrigin
            pla
            sta   HT
            pla
            plx
            sta   History+2,x
            lda   HT
            sta   History,x
            inc   Depth
:keep       lda   BI                    ; its page
            asl
            asl
            asl
            asl
            asl
            clc
            adc   #BLabels
            jsr   SetGo
            stz   RestV
            stz   RestH
            jsr   GoTo
:out        rts

*-------------------------------------------------------------
* Data
*-------------------------------------------------------------
HDP         dw    0
HCode       dw    0
Front       dw    0
EvWin       adrl  0
EvCtl       adrl  0
HlpWin      adrl  0                     ; the help window (0: closed)
HlpBufH     adrl  0                     ; the text
HlpBuf      adrl  0
HlpLen      dw    0
Pos         dw    0
V           dw    0
RestV       dw    0                     ; where the next page is scrolled to
RestH       dw    0
Depth       dw    0                     ; the Back history
MItem       dw    0
MMenu       dw    0
LNum        dw    0
LogAt       dw    0
LogN0       dw    0
LogK        dw    0
LogDig      ds    12
TxLPrev     asc   ': prev ',00
TxLNext     asc   ', next ',00
TxLBack     asc   ', back ',00
TxLBtns     asc   ', buttons ',00
TxLHigh     asc   ', height ',00
LDig        dw    0
DvN         dw    0
MAt         dw    0
MLen        dw    0
TStart      dw    0
TNext       dw    0
TLines      dw    0
BN          dw    0
BW          dw    0
BI          dw    0
BLeft       dw    0
BTRef       dw    0
NBtn        dw    0
FAt         dw    0
FLen        dw    0
BItem       dw    0
IIn         dw    0
HT          dw    0
DX          dw    0
DY          dw    0
IRect       ds    8
IArea       ds    8
IPt         ds    4
ISrc        dw    0,0,9,32
GoLabel     ds    32                    ; the page asked for
CurLabel    ds    32                    ; the page shown
NavPrev     ds    32                    ; its navigation line's labels
NavNext     ds    32
NavBack     ds    32
Scratch     ds    32
MaxBtn      =     24
BTitles     ds    MaxBtn*64             ; the page's buttons: titles
BLabels     ds    MaxBtn*32             ; and the pages they go to
History     ds    20*36                 ; label, scroll v, h
BWidths     dw    596,288,185,134,103,82,68,57,48
AllRect     dw    0,0,9999,608
HWin        adrl  0
HTask       dw    0                     ; an event record (for MenuSelect)
            adrl  0,0
            dw    0,0,0
            adrl  0
            adrl  $001FFFFF
            adrl  0
            dw    0
            adrl  0,0,0
            ds    16
TxLabHome   str   'HOME'
TxLabDA     str   'DA'
TxLabMenus  str   'MENUS'
TxHelpTitle str   ' MegaconvertGS Help '
TxNoHelp    asc   '53/I am having a hard time attempting to load & display the help '
            asc   'file (MCGS.Help, beside MegaconvertGS)./^#0',00
TxHome      str   'Home'
TxPrev      str   'Previous'
TxNext      str   'Next'
TxBack      str   'Back'
LabelTx     da    TxHome,TxPrev,TxNext,TxBack
* The items: their areas, icons and names across the bar (SuperConvert's)
AreaL       dw    20,190,320,470
AreaR       dw    110,310,410,560
IconX       dw    30,268,330,480
LabelX      dw    70,200,370,520
IconSrc     dw    0,9,18,27
GreyMask    hex   55AA55AA55AA55AA
* A static text (its text and place set for each)
STTmpl      dw    9
            adrl  0
STRect      dw    0,6,0,602
            adrl  $81000000
            dw    0,$1000
            adrl  0
STText      adrl  0
STSize      dw    0
            dw    0
* A button (its ID, place and title set for each)
BTmpl       dw    7
            adrl  0
            dw    0,0,0,0
            adrl  $80000000
            dw    0,$1000
            adrl  0
            adrl  0
* The help file and the window
HOpen       dw    3
            dw    0
            adrl  TxHelpPath
            dw    1
HEof        dw    2
            dw    0
            adrl  0
HRead       dw    4
            dw    0
            adrl  0,0,0
HClose      dw    1
            dw    0
TxHelpPath  dw    11
            asc   '1:MCGS.Help'
HlpParms    dw    $50
            dw    $D0B8                 ; title, close box, right scroll bar,
            adrl  0                     ; moves, visible, info bar, controls
            adrl  0                     ; tied to the content
            dw    0,0,0,0
            adrl  0
            dw    0,0                   ; origin
            dw    0,0                   ; data height, width
            dw    0,0                   ; at most
            dw    10,0                  ; scroll steps: 10 pixels down
            dw    0,0
            adrl  0                     ; info bar refCon
            dw    13                    ; info bar height
            adrl  0
            adrl  HelpInfo
            adrl  HelpDraw
            dw    45,4,197,612
            adrl  $FFFFFFFF
            adrl  0
            dw    0
* The items' icons: 32 x 9 pixels each (640 mode, 0 black, 3 white),
* Home, Previous, Next, Back one under the other
IconLoc     dw    $0080
            adrl  Icons
            dw    8
            dw    0,0,36,32
            put   HelpIcons.s
