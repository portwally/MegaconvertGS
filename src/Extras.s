*-------------------------------------------------------------
* Extras.s - Apple > Preferences... and other extra commands, as
* SuperConvert's (a segment of its own; docs/superconvert-extras.md).
*
* Preferences: dctl points to the main program's options, eight words
* in the order of the check boxes (6 to 13), then its "SKIP ME" words
* (darg: how many); the options are saved in 9:MCGS.Prefs.
*-------------------------------------------------------------
            rel
            mx    %00
            use   macros/Macs.s
            put   Equates.s

xp0         =     $D0                   ; (a long pointer)
xw0         =     $D4                   ; words
xw1         =     $D6

* PrefsDlg: Apple > Preferences...: the eight options; OK keeps them,
* Save keeps and saves them, Cancel leaves them; Clear all "SKIP ME"
* preferences clears those at once.
*   out: A = 1 if the "SKIP ME" words were cleared
PrefsDlg    ent
            phb
            phk
            plb
            lda   dctl
            sta   xp0
            lda   dctl+2
            sta   xp0+2
            stz   Cleared
            pha                         ; the window (hidden at first)
            pha
            PushLong 0                  ; no title
            PushLong 0
            PushLong PRedraw            ; (its controls drawn)
            PushLong 0                  ; the usual frame
            pea   0                     ; the parameters: a pointer
            PushLong PrefParms
            pea   $800E
            Tool  _NewWindow2
            pla
            sta   PWin
            pla
            sta   PWin+2
            ldx   #6                    ; the boxes as the options are
:box        phx
            txa
            sec
            sbc   #6
            asl
            tay
            lda   [xp0],y
            beq   :v
            lda   #1
:v          pha
            PushLongAt PWin
            pea   0
            phx
            Tool  _SetCtlValueByID
            plx
            inx
            cpx   #14
            bcc   :box
            pea   255                   ; (no Video Overlay Card: its box
            PushLongAt PWin             ; dimmed)
            PushLong 10
            Tool  _HiliteCtlByID
            jsr   AnySkip
            bne   :skips
            pea   255                   ; (no "SKIP ME" set: dimmed)
            PushLongAt PWin
            PushLong 4
            Tool  _HiliteCtlByID
:skips      PushLongAt PWin
            Tool  _ShowWindow
:loop       pha                         ; the user's choice
            pha
            PushLong PEvent
            PushLong 0
            PushLong 0
            PushLong 0
            pea   0
            Tool  _DoModalWindow
            pla
            plx
            cmp   #1
            beq   :ok
            cmp   #2
            beq   :done
            cmp   #3
            beq   :save
            cmp   #4
            bne   :loop
            jsr   ClearSkip             ; Clear all "SKIP ME" preferences
            lda   #1
            sta   Cleared
            pea   255
            PushLongAt PWin
            PushLong 4
            Tool  _HiliteCtlByID
            bra   :loop
:save       jsr   Take
            jsr   SavePrefs
            bra   :done
:ok         jsr   Take
:done       PushLongAt PWin
            Tool  _CloseWindow
            lda   Cleared
            plb
            rtl

* PRedraw: the window's contents: its controls (the toolbox calls it).
PRedraw     phb
            phk
            plb
            pha
            pha
            Tool  _GetPort
            Tool  _DrawControls
            plb
            rtl

* Take: the options from the boxes.
Take        ldx   #6
:box        phx
            pha
            PushLongAt PWin
            pea   0
            phx
            Tool  _GetCtlValueByID
            pla
            plx
            pha
            txa
            sec
            sbc   #6
            asl
            tay
            pla
            sta   [xp0],y
            inx
            cpx   #14
            bcc   :box
            rts

* AnySkip: Z clear if a "SKIP ME" word is set.
AnySkip     ldy   #16
            ldx   darg
            lda   #0
:w          cpx   #0
            beq   :end
            ora   [xp0],y
            iny
            iny
            dex
            bra   :w
:end        cmp   #0
            rts

* ClearSkip: every "SKIP ME" word cleared.
ClearSkip   ldy   #16
            ldx   darg
:w          cpx   #0
            beq   :end
            lda   #0
            sta   [xp0],y
            iny
            iny
            dex
            bra   :w
:end        rts

* SavePrefs: the eight options (16 bytes) into 9:MCGS.Prefs (type $5A);
* errors are ignored, as SuperConvert's.
SavePrefs   ldy   #0                    ; (the words, from the main program)
:c          lda   [xp0],y
            sta   PBuf,y
            iny
            iny
            cpy   #16
            bcc   :c
            GSOS  _DestroyGS;PDestroy
            GSOS  _CreateGS;PCreate
            bcs   :out
            GSOS  _OpenGS;POpen
            bcs   :out
            lda   POpen+2
            sta   PWrite+2
            sta   PClose+2
            GSOS  _WriteGS;PWrite
            GSOS  _CloseGS;PClose
:out        rts

* PrefsSave: for tests: the options at dctl saved, as Preferences' Save.
PrefsSave   ent
            phb
            phk
            plb
            lda   dctl
            sta   xp0
            lda   dctl+2
            sta   xp0+2
            jsr   SavePrefs
            plb
            rtl

* PrefsLoad: at start-up: the options from 9:MCGS.Prefs into the eight
* words at dctl (none: all off).
PrefsLoad   ent
            phb
            phk
            plb
            lda   dctl
            sta   xp0
            lda   dctl+2
            sta   xp0+2
            ldy   #0
            lda   #0
:z          sta   PBuf,y
            iny
            iny
            cpy   #16
            bcc   :z
            GSOS  _OpenGS;POpenR
            bcs   :copy
            lda   POpenR+2
            sta   PRead+2
            sta   PClose+2
            GSOS  _ReadGS;PRead
            GSOS  _CloseGS;PClose
:copy       ldy   #0
:c          lda   PBuf,y
            beq   :off
            lda   #1
:off        sta   [xp0],y
            iny
            iny
            cpy   #16
            bcc   :c
            plb
            rtl

*-------------------------------------------------------------
* Available font list, More available fonts (docs/superconvert-extras.md
* 5.1): a 640 mode screen image listing every installed font in itself
*-------------------------------------------------------------

* FontList: A = 0 from the first font, 1 from the one the last page broke
* at; dctl: the screen image's buffer (one screen; a page ends at line
* 196 here where SuperConvert's 400-line images end at 396).
*   out: darg = the lines drawn; dact = 1 if another page follows
FontList    ent
            phb
            phk
            plb
            sta   xw0
            lda   dctl
            sta   FLoc+2
            lda   dctl+2
            sta   FLoc+4
            lda   xw0                   ; where to start
            bne   :more
            stz   FStart
            bra   :fonts
:more       lda   FNext
            sta   FStart
:fonts      jsr   Collect               ; the fonts, sorted
            jsr   SortFonts
            jsr   PortOn                ; drawing in the screen image
            lda   #640                  ; (a new row at once)
            sta   FX
            stz   FY
            stz   FRowH
            stz   FNext
            lda   FStart
            sta   FI
:font       lda   FI
            cmp   FCount
            bcc   :one
            jmp   :end
:one        asl
            asl
            tax
            lda   FIDs,x
            sta   FID
            lda   FIDs+2,x
            sta   FID+2
            PushLongAt FID              ; installed (no scaling)
            pea   1
            Tool  _InstallFont
            bcs   :bad
            pha
            pha
            Tool  _GetFontID
            pla
            plx
            cmp   FID
            bne   :bad
            cpx   FID+2
            bne   :bad
            PushLong FInfo
            Tool  _GetFontInfo
            lda   FInfo                 ; usable sizes?
            ora   FInfo+2
            beq   :bad
            lda   FInfo
            ora   FInfo+2
            ora   FInfo+4
            ora   FInfo+6
            and   #$FF00
            beq   :good
:bad        jsr   Purge
            Tool  _SysBeep
            jmp   :next
:good       jsr   FName                 ; "Family Style size "
            pha                         ; its width without the last space
            lda   FText
            dec
            sta   FText
            PushLong FText
            Tool  _StringWidth
            inc   FText
            pla
            clc
            adc   FX
            cmp   #640
            bcc   :fits
            stz   FX                    ; a new row
            lda   FY
            clc
            adc   FRowH
            sta   FY
            stz   FRowH
            cmp   #FLines
            bcc   :fits
            jsr   Purge                 ; (the image is full)
            bra   :end
:fits       lda   FInfo                 ; the row's height
            clc
            adc   FInfo+2
            inc
            cmp   FRowH
            bcc   :h
            sta   FRowH
:h          lda   FX
            pha
            lda   FY
            clc
            adc   FInfo
            pha
            Tool  _MoveTo
            PushLong FText
            Tool  _DrawString
            jsr   Purge
            pha
            PushLong FText
            Tool  _StringWidth
            pla
            clc
            adc   FX
            sta   FX
            lda   FNext                 ; the next page starts with the first
            bne   :next                 ; font reaching its last lines
            lda   FY
            clc
            adc   FInfo
            adc   FInfo+2
            cmp   #FLines-4
            bcc   :next
            lda   FI
            sta   FNext
:next       inc   FI
            jmp   :font
:end        jsr   PortOff
            lda   FY                    ; the lines used
            clc
            adc   FRowH
            inc
            cmp   #FLines
            bcc   :lines
            lda   #FLines
:lines      sta   darg
            jsr   Std640                ; 640 mode, the standard colours
            lda   #0
            ldx   FNext
            beq   :last
            lda   #1
:last       sta   dact
            plb
            rtl

*-------------------------------------------------------------
* Font key chart... (docs/superconvert-extras.md 5.2): a font chosen with
* the Font Manager's dialog, each of its characters with its code and the
* keys that type it
*-------------------------------------------------------------

* KeyChart: dctl: the screen image's buffer.
*   out: carry set if the dialog was cancelled (nothing drawn); else darg
*   = the lines drawn, and A = 0, or an error ($FF03: the font is damaged)
KeyChart    ent
            phb
            phk
            plb
            lda   dctl
            sta   FLoc+2
            lda   dctl+2
            sta   FLoc+4
            pha                         ; the font
            pha
            PushLongAt KLast
            pea   0                     ; (famSpecs: every family)
            Tool  _ChooseFont
            pla
            sta   FID
            pla
            sta   FID+2
            ora   FID
            bne   :chosen
            sec
            plb
            rtl
:chosen     lda   FID
            sta   KLast
            lda   FID+2
            sta   KLast+2
            jsr   PortOn
            pea   4                     ; (foreground copy)
            Tool  _SetTextMode
            pea   0                     ; the font's name at the top
            pea   11
            Tool  _MoveTo
            Tool  _LoadSysFont
            jsr   FName
            PushLong FText
            Tool  _DrawString
            pha
            PushLong FText
            Tool  _StringWidth
            pla
            clc
            adc   #8
            sta   FX
            stz   FY
            PushLongAt FID              ; (scaled if need be)
            pea   0
            Tool  _InstallFont
            bcs   :damaged
            PushLong FInfo
            Tool  _GetFontInfo
            lda   FInfo
            ora   FInfo+2
            beq   :damaged
            lda   FInfo
            ora   FInfo+2
            ora   FInfo+4
            ora   FInfo+6
            and   #$FF00
            beq   :ok
:damaged    jsr   Purge
            jsr   PortOff
            lda   #$FF03
            clc
            plb
            rtl
:ok         lda   FInfo                 ; the rows: at least 18 high
            clc
            adc   FInfo+2
            adc   FInfo+6
            cmp   #18
            bcs   :rh
            lda   #18
:rh         sta   FRowH
            jsr   FontRange             ; KFirst, KLast2, KOW: its characters
            stz   KC
:char       lda   KC
            jsr   HasChar
            bcs   :has
            jmp   :next
:has        pea   0                     ; its right edge
            pea   0
            Tool  _MoveTo
            lda   KC
            pha
            PushLong KRect
            Tool  _CharBounds
            Tool  _LoadSysFont          ; its code and keys, in the system
            lda   #2                    ; font: green, red past $7F
            ldx   KC
            cpx   #$80
            bcc   :col
            lda   #1
:col        pha
            Tool  _SetForeColor
            jsr   KTexts                ; KHex, KKey
            pha
            PushLong KHex
            Tool  _CStringWidth
            pla
            sta   KWH
            pha
            PushLong KKey
            Tool  _CStringWidth
            pla
            sta   KWK
            cmp   KWH
            bcs   :w
            lda   KWH
:w          sta   KW                    ; the column's width
            lda   FX                    ; past the right edge: a new row
            clc
            adc   KRect+6
            adc   KW
            adc   #4
            cmp   #640
            bcc   :place
            lda   FY
            clc
            adc   FRowH
            sta   FY
            stz   FX
:place      lda   KW                    ; the code, centred
            sec
            sbc   KWH
            lsr
            clc
            adc   FX
            pha
            lda   FY
            clc
            adc   #7
            pha
            Tool  _MoveTo
            PushLong KHex
            Tool  _DrawCString
            lda   KW                    ; the keys, centred below
            sec
            sbc   KWK
            lsr
            clc
            adc   FX
            pha
            lda   FY
            clc
            adc   #16
            pha
            Tool  _MoveTo
            PushLong KKey
            Tool  _DrawCString
            PushLongAt FID              ; the character itself, in black
            pea   0
            Tool  _InstallFont
            pea   0
            Tool  _SetForeColor
            lda   FX
            clc
            adc   KW
            adc   #4
            pha
            lda   FY
            clc
            adc   FInfo
            pha
            Tool  _MoveTo
            lda   KC
            pha
            Tool  _DrawChar
            lda   FX                    ; the next column
            clc
            adc   KW
            adc   #16
            adc   KRect+6
            sta   FX
:next       inc   KC
            lda   KC
            cmp   #256
            bcs   :done
            jmp   :char
:done       jsr   Purge
            jsr   PortOff
            lda   FY                    ; the lines used
            clc
            adc   FRowH
            cmp   #FLines
            bcc   :lines
            lda   #FLines
:lines      sta   darg
            jsr   Std640
            lda   #0
            clc
            plb
            rtl

* FontRange: the current font's first and last characters and its
* offset/width table (to skip the characters it lacks).
FontRange   pha
            pha
            Tool  _GetFont
            pla
            sta   xp0
            pla
            sta   xp0+2
            ldy   #2
            lda   [xp0],y
            tax
            lda   [xp0]
            sta   xp0
            stx   xp0+2
            lda   [xp0]                 ; (offset to the Macintosh font record,
            asl                         ; in words)
            clc
            adc   xp0
            sta   xp0
            lda   xp0+2
            adc   #0
            sta   xp0+2
            ldy   #2                    ; firstChar, lastChar
            lda   [xp0],y
            sta   KFirst
            ldy   #4
            lda   [xp0],y
            sta   KLast2
            ldy   #16                   ; owTLoc: words from itself to the
            lda   [xp0],y               ; offset/width table
            asl
            clc
            adc   #16
            adc   xp0
            sta   KOW
            lda   xp0+2
            adc   #0
            sta   KOW+2
            rts

* HasChar: carry set if the font has character A.
HasChar     cmp   KFirst
            bcc   :no
            cmp   KLast2
            beq   :in
            bcs   :no
:in         sec
            sbc   KFirst
            asl
            tay
            lda   KOW
            sta   xp0
            lda   KOW+2
            sta   xp0+2
            lda   [xp0],y
            cmp   #$FFFF
            beq   :no
            sec
            rts
:no         clc
            rts

* KTexts: KHex = character KC's code (2 hex digits); KKey = the keys
* typing it: ^ and a letter for control characters, the character itself
* (Spc, Del), or the solid Apple (Option) and a dead key, a space and a
* key from SuperConvert's table; none past $FB.
KTexts      lda   KC
            lsr
            lsr
            lsr
            lsr
            tax
            lda   KHexD,x
            and   #$00FF
            sta   KHex
            lda   KC
            and   #$000F
            tax
            lda   KHexD,x
            and   #$00FF
            xba
            ora   KHex
            sta   KHex                  ; (and a 0 after)
            stz   KHex+2
            ldx   #0                    ; the keys
            lda   KC
            cmp   #$20
            bcs   :print
            lda   #'^'
            jsr   KPut
            lda   KC
            ora   #$40
            jsr   KPut
            bra   :end
:print      cmp   #$80
            bcs   :option
            cmp   #' '
            beq   :spc
            cmp   #$7F
            beq   :del
            jsr   KPut
            bra   :end
:spc        jsr   KSpc
            bra   :end
:del        lda   #'D'
            jsr   KPut
            lda   #'e'
            jsr   KPut
            lda   #'l'
            jsr   KPut
            bra   :end
:option     cmp   #$FC
            bcs   :end
            lda   #$14                  ; (the solid Apple: Option)
            jsr   KPut
            lda   KC                    ; the table: a dead key (a space if
            sec                         ; none), then the key
            sbc   #$80
            asl
            tay
            lda   KeyTab,y
            and   #$00FF
            cmp   #' '
            beq   :key
            jsr   KPut
            lda   #' '
            jsr   KPut
:key        lda   KeyTab+1,y
            and   #$00FF
            cmp   #' '
            bne   :k
            jsr   KSpc
            bra   :end
:k          jsr   KPut
:end        lda   #0
            sta   KKey,x
            rts
KSpc        lda   #'S'
            jsr   KPut
            lda   #'p'
            jsr   KPut
            lda   #'c'
KPut        sep   #$20
            mx    %10
            sta   KKey,x
            rep   #$20
            mx    %00
            inx
            rts

* Purge: the font at FID purgeable again.
Purge       PushLongAt FID
            pea   1
            Tool  _SetPurgeStat
            rts

* Collect: FIDs, FCount: every installed font (FindFontStats over all of
* them, until one says it is the last).
Collect     stz   FCount
            lda   #1
            sta   xw1
:n          pea   $00FF                 ; (font ID $00FF0000: every font)
            pea   $0000
            pea   $001E
            lda   xw1
            pha
            PushLong FStat
            Tool  _FindFontStats
            bcs   :skip
            lda   FStat+4               ; (bit 15: past the last)
            bmi   :done
            lda   FCount
            cmp   #MaxFonts
            bcs   :done
            asl
            asl
            tax
            lda   FStat
            sta   FIDs,x
            lda   FStat+2
            sta   FIDs+2,x
            inc   FCount
:skip       inc   xw1
            lda   xw1
            cmp   #1000
            bcc   :n
:done       rts

* SortFonts: by size, then by family name (insertion sort).
SortFonts   lda   #1
            sta   xw0
:i          lda   xw0
            cmp   FCount
            bcs   :done
            sta   xw1                   ; move entry i down while it is smaller
:j          lda   xw1
            beq   :next
            jsr   Less                  ; entry j < entry j - 1?
            bcc   :next
            lda   xw1                   ; swap them
            asl
            asl
            tax
            lda   FIDs,x
            ldy   FIDs-4,x
            sta   FIDs-4,x
            tya
            sta   FIDs,x
            lda   FIDs+2,x
            ldy   FIDs-2,x
            sta   FIDs-2,x
            tya
            sta   FIDs+2,x
            dec   xw1
            bra   :j
:next       inc   xw0
            bra   :i
:done       rts

* Less: carry set if font xw1 comes before font xw1 - 1 (smaller size, or
* the same size and a family name that sorts first).
Less        lda   xw1
            asl
            asl
            tax
            lda   FIDs+3,x              ; sizes (the IDs' top bytes)
            and   #$00FF
            sta   FSz
            lda   FIDs-1,x
            and   #$00FF
            cmp   FSz
            beq   :names
            bcs   :yes                  ; (j - 1 larger)
            clc
            rts
:yes        sec
            rts
:names      pha                         ; family names
            lda   FIDs,x
            pha
            PushLong FNameA
            Tool  _GetFamInfo
            pla
            lda   xw1
            asl
            asl
            tax
            pha
            lda   FIDs-4,x
            pha
            PushLong FNameB
            Tool  _GetFamInfo
            pla
            ldx   #0                    ; byte by byte, case sensitive;
:c          lda   FNameA                ; the shorter first
            and   #$00FF
            sta   FSz
            cpx   FSz
            bcs   :aEnd
            lda   FNameB
            and   #$00FF
            sta   FSz
            cpx   FSz
            bcs   :no                   ; (B ended: B first)
            lda   FNameA+1,x
            and   #$00FF
            sta   FSz
            lda   FNameB+1,x
            and   #$00FF
            cmp   FSz
            beq   :same
            bcs   :yes2                 ; (B larger: A first)
:no         clc
            rts
:same       inx
            bra   :c
:aEnd       lda   FNameB
            and   #$00FF
            sta   FSz
            cpx   FSz
            bcs   :no                   ; (equal)
:yes2       sec
            rts

* FName: FText = the font's family name, its style words, " ", its size
* and " " (a Pascal string).
FName       pha
            lda   FID
            pha
            PushLong FText
            Tool  _GetFamInfo
            pla
            lda   FID+2                 ; style bits 0-7
            and   #$00FF
            sta   xw0
            ldx   #0
:style      lsr   xw0
            bcc   :ns
            phx
            txa
            asl
            tax
            lda   StyleTx,x
            jsr   FAdd
            plx
:ns         inx
            cpx   #8
            bcc   :style
            lda   #TxFSpace
            jsr   FAdd
            lda   FID+3                 ; the size, decimal
            and   #$00FF
            jsr   FDec
            lda   #TxFSpace
            jmp   FAdd

* FAdd: the C string at A onto FText.
FAdd        sta   xw1
            ldy   #0
:c          lda   (xw1),y
            and   #$00FF
            beq   :end
            phy
            pha
            lda   FText
            and   #$00FF
            inc
            tay
            pla
            sep   #$20
            mx    %10
            sta   FText,y
            inc   FText
            rep   #$20
            mx    %00
            ply
            iny
            bra   :c
:end        rts

* FDec: A (0-255) in decimal onto FText.
FDec        sta   xw0
            ldx   #0                    ; hundreds
:h          lda   xw0
            cmp   #100
            bcc   :hd
            sbc   #100
            sta   xw0
            inx
            bra   :h
:hd         stx   FHund
            cpx   #0
            beq   :t0
            txa
            jsr   FDigit
:t0         ldx   #0                    ; tens (none: only past hundreds)
:t          lda   xw0
            cmp   #10
            bcc   :td
            sbc   #10
            sta   xw0
            inx
            bra   :t
:td         txa
            ora   FHund
            beq   :o
            txa
            jsr   FDigit
:o          lda   xw0
FDigit      clc
            adc   #'0'
            sta   FCh
            lda   #FCh
            jmp   FAdd

* PortOn: a port drawing in the screen image (640 mode, 160 bytes a
* line), erased white, black text on white; PortOff: back.
PortOn      pha
            pha
            Tool  _GetPort
            pla
            sta   FOld
            pla
            sta   FOld+2
            PushLong FPort
            Tool  _OpenPort
            PushLong FLoc
            Tool  _SetPortLoc
            PushLong FRect
            Tool  _SetPortRect
            PushLong FRect
            Tool  _ClipRect
            pea   $FFFF
            Tool  _SetSolidBackPat
            PushLong FRect
            Tool  _EraseRect
            pea   0
            Tool  _SetForeColor
            pea   $FFFF
            Tool  _SetBackColor
            pea   0
            Tool  _SetTextMode
            rts
PortOff     PushLongAt FOld
            Tool  _SetPort
            PushLong FPort
            Tool  _ClosePort
            rts

* Std640: the screen image's lines all 640 mode, colour table 0 the
* standard 640 colours ($000 $F00 $0F0 $FFF four times).
Std640      lda   FLoc+2
            sta   xp0
            lda   FLoc+4
            sta   xp0+2
            ldy   #scbOffset
            lda   #$8080
:s          sta   [xp0],y
            iny
            iny
            cpy   #scbOffset+200
            bcc   :s
            ldy   #palOffset
            ldx   #0
:p          lda   Colors640,x
            sta   [xp0],y
            iny
            iny
            inx
            inx
            cpx   #32
            bcc   :p
            rts

            put   SysInfo.s
            put   Examine.s
            put   Oscope.s

*-------------------------------------------------------------
* Data
*-------------------------------------------------------------
PWin        adrl  0
FLines      =     200                   ; (a page: one screen)
MaxFonts    =     200
FStart      dw    0
FNext       dw    0                     ; the font the next page starts with
FCount      dw    0
FI          dw    0
FID         adrl  0
FX          dw    0
FY          dw    0
FRowH       dw    0
FSz         dw    0
FCh         dw    0
FHund       dw    0
KLast       adrl  $10000000             ; the last font chosen (Shaston 16)
KC          dw    0
KFirst      dw    0
KLast2      dw    0
KOW         adrl  0
KW          dw    0
KWH         dw    0
KWK         dw    0
KRect       dw    0,0,0,0
KHex        ds    4
KKey        ds    8
KHexD       asc   '0123456789ABCDEF'
* Option-key characters $80-$FB (SuperConvert's table): a dead key (a
* space: none) and a key.
KeyTab      =     *
            hex   75412041204365456E4E754F755565616061696175616E6120612063656560
            hex   656965756565696069696975696E6E656F606F696F756F6E6F657560756975
            hex   75752074202A20342033203620382037207320722067203265207520203D20
            hex   22204F2035202B202C202E2079206D2064207720502070206220392030207A
            hex   2027206F203F2031206C207620662078206A205C207C203B202060416E416E
            hex   4F20512071202D205F205B207B205D207D202F20567579207E202120402023
            hex   20242025205E20262028202920572045205220542059205520492053204420
            hex   4620472048204A204B204C203A205A20582042204E204D203C203E2068206B
FInfo       dw    0,0,0,0               ; ascent, descent, widMax, leading
FStat       adrl  0                     ; FindFontStats: the font ID, its stats
            dw    0
FOld        adrl  0
FLoc        dw    $0080                 ; the screen image (640 mode)
            adrl  0
            dw    160
            dw    0,0,200,640
FRect       dw    0,0,200,640
FPort       ds    $AA
FText       ds    256                   ; (a Pascal string)
FNameA      ds    64
FNameB      ds    64
FIDs        ds    MaxFonts*4
StyleTx     da    TxBold,TxItalic,TxUnder,TxOutline,TxShadow,TxUnknown,TxUnknown,TxUnknown
TxBold      asc   ' Bold',00
TxItalic    asc   ' Italic',00
TxUnder     asc   ' Underline',00
TxOutline   asc   ' Outline',00
TxShadow    asc   ' Shadow',00
TxUnknown   asc   ' Unknown',00
TxFSpace    asc   ' ',00
Colors640   dw    $000,$F00,$0F0,$FFF,$000,$F00,$0F0,$FFF
            dw    $000,$F00,$0F0,$FFF,$000,$F00,$0F0,$FFF
Cleared     dw    0
PBuf        ds    16
PEvent      dw    0                     ; (an extended event record)
            adrl  0
            adrl  0
            dw    0,0
            dw    0
            adrl  0
            adrl  $001FFFFF
            adrl  0
            dw    0
            adrl  0
            dw    0
            ds    20
PrefsName   dw    12
            asc   '9:MCGS.Prefs'
PDestroy    dw    1
            adrl  PrefsName
PCreate     dw    5
            adrl  PrefsName
            dw    $C3                   ; access
            dw    $5A                   ; file type
            adrl  0                     ; aux type
            dw    1                     ; storage type
POpen       dw    3
            dw    0
            adrl  PrefsName
            dw    2                     ; (write)
POpenR      dw    3
            dw    0
            adrl  PrefsName
            dw    1                     ; (read)
PWrite      dw    4
            dw    0
            adrl  PBuf
            adrl  16
            adrl  0
PRead       dw    4
            dw    0
            adrl  PBuf
            adrl  16
            adrl  0
PClose      dw    1
            dw    0

* The window (SuperConvert's rWindParam1 6 and rControlList 6; its title
* picture left out).
PrefParms   dw    $50,$2000
            adrl  0,0
            dw    0,0,0,0
            adrl  0
            dw    0,0,0,0,0,0,0,0,0,0
            adrl  0
            dw    0
            adrl  0,0,0                 ; (frame, info and content routines)
            dw    34,24,178,616
            adrl  $FFFFFFFF
            adrl  PrefCtls
            dw    $0003
PrefCtls    adrl  PcOK,PcCancel,PcSave,PcClear,PcTitle
            adrl  PcBox6,PcBox7,PcBox8,PcBox9,PcBox10,PcBox11,PcBox12,PcBox13,0
PcOK        dw    9
            adrl  1
            dw    125,494,138,578
            adrl  $80000000
            dw    $0001,$3000
            adrl  0
            adrl  TxPOK
            adrl  0
            db    $0D,$0D
            dw    0,0
PcCancel    dw    9
            adrl  2
            dw    126,399,139,481
            adrl  $80000000
            dw    $0000,$3000
            adrl  0
            adrl  TxPCancel
            adrl  0
            db    $1B,$1B
            dw    0,0
PcSave      dw    9
            adrl  3
            dw    126,311,139,389
            adrl  $80000000
            dw    $0000,$3000
            adrl  0
            adrl  TxPSave
            adrl  0
            db    'S','s'
            dw    $0100,$0100
PcClear     dw    7
            adrl  4
            dw    126,9,139,269
            adrl  $80000000
            dw    $0002,$1000
            adrl  0
            adrl  TxPClear
PcTitle     dw    8                     ; (in the title picture's place)
            adrl  5
            dw    8,182,24,383
            adrl  $81000000
            dw    $0000,$1000
            adrl  0
            adrl  TxPTitle
            dw    TxPTitleEnd-TxPTitle
PcBox6      dw    8
            adrl  6
            dw    38,12,48,338
            adrl  $82000000
            dw    $0000,$1000
            adrl  0
            adrl  TxBox6
            dw    0
PcBox7      dw    8
            adrl  7
            dw    48,12,57,340
            adrl  $82000000
            dw    $0000,$1000
            adrl  0
            adrl  TxBox7
            dw    0
PcBox8      dw    8
            adrl  8
            dw    58,12,67,364
            adrl  $82000000
            dw    $0000,$1000
            adrl  0
            adrl  TxBox8
            dw    0
PcBox9      dw    8
            adrl  9
            dw    68,12,77,380
            adrl  $82000000
            dw    $0000,$1000
            adrl  0
            adrl  TxBox9
            dw    0
PcBox10     dw    8
            adrl  10
            dw    78,12,87,579
            adrl  $82000000
            dw    $0000,$1000
            adrl  0
            adrl  TxBox10
            dw    0
PcBox11     dw    8
            adrl  11
            dw    88,12,97,429
            adrl  $82000000
            dw    $0000,$1000
            adrl  0
            adrl  TxBox11
            dw    0
PcBox12     dw    8
            adrl  12
            dw    98,12,107,476
            adrl  $82000000
            dw    $0000,$1000
            adrl  0
            adrl  TxBox12
            dw    0
PcBox13     dw    8
            adrl  13
            dw    108,12,117,550
            adrl  $82000000
            dw    $0000,$1000
            adrl  0
            adrl  TxBox13
            dw    0
TxPOK       str   'OK'
TxPCancel   str   'Cancel'
TxPSave     str   'Save'
TxPClear    dfb   31
            asc   'Clear all ',D2,'SKIP ME',D3,' preferences'
TxPTitle    asc   'MegaconvertGS Preferences'
TxPTitleEnd
TxBox6      str   'Automatically save picture after loading'
TxBox7      str   'Automatically print picture after loading'
TxBox8      str   'Automatically load next picture after saving'
TxBox9      dfb   52
            asc   'Don',27,'t automatically view screen images after loading'
TxBox10     str   'Use second monitor (attached to Video Overlay Card) for continuous viewing'
TxBox11     dfb   59
            asc   'Don',27,'t automatically show Remap dialog for true color images'
TxBox12     str   'Automatically show Remap dialog after loading screen images'
TxBox13     str   'Disk insertion starts load (save, if disk was blank; Requires System 6+)'
