*-------------------------------------------------------------
* Screen.s - showing the picture on the whole screen
*-------------------------------------------------------------

* ViewFull: shows the picture until a click or key, then puts
* the desktop back exactly as it was.
ViewFull    lda   HaveScreen
            beq   :none
            jsr   ShowPicture
            pha
            pea   $FFFF                 ; forget earlier clicks and keys
            pea   0
            Tool  _FlushEvents
            pla
:wait       pha
            pea   $002A                 ; mouse down, key down, auto-key
            PushLong WaitEvent
            Tool  _GetNextEvent
            pla
            beq   :wait
            jsr   RestoreDesktop
:none       rts

* ShowTitle: the title picture (MCGS.Title beside the program, a $C1
* screen) on the whole screen until a click, a key or 3 seconds, then the
* desktop back as it was. Nothing if the file isn't there.
ShowTitle   lda   #TitlePath
            sta   PathPtr
            lda   #^TitlePath
            sta   PathPtr+2
            jsr   ReadFile
            bcc   :jx1
            jmp   :none
:jx1
            lda   FileLen+2             ; (a whole screen, nothing else)
            beq   :jx2
            jmp   :free
:jx2
            lda   FileLen
            cmp   #screenSize
            bne   :free
            Tool  _HideCursor
            lda   #$2000                ; the desktop kept,
            sta   p0
            lda   #$00E1
            sta   p0+2
            lda   SavedP
            sta   p1
            lda   SavedP+2
            sta   p1+2
            jsr   Copy32K
            lda   FileP                 ; the title shown
            sta   p0
            lda   FileP+2
            sta   p0+2
            lda   #$2000
            sta   p1
            lda   #$00E1
            sta   p1+2
            jsr   Copy32K
            pha                         ; (its result)
            pea   $FFFF                 ; forget earlier clicks and keys
            pea   0
            Tool  _FlushEvents
            pla
            pha
            pha
            Tool  _TickCount
            pla
            sta   TitleT0
            pla
:wait       pha
            pea   $002A                 ; mouse down, key down, auto-key
            PushLong WaitEvent
            Tool  _GetNextEvent
            pla
            bne   :done
            pha
            pha
            Tool  _TickCount
            pla
            sec
            sbc   TitleT0
            tax
            pla
            cpx   #180                  ; (3 seconds)
            bcc   :wait
:done       jsr   RestoreDesktop
:free       jsr   FreeFile
:none       rts

TitlePath   dw    12
            asc   '1:MCGS.Title'
TitleT0     dw    0

* ShowPicture: saves the desktop screen and puts the picture there.
ShowPicture Tool  _HideCursor
            lda   #$2000
            sta   p0
            lda   #$00E1
            sta   p0+2
            lda   SavedP
            sta   p1
            lda   SavedP+2
            sta   p1+2
            jsr   Copy32K
            lda   ScreenP
            sta   p0
            lda   ScreenP+2
            sta   p0+2
            lda   #$2000
            sta   p1
            lda   #$00E1
            sta   p1+2
            jmp   Copy32K

RestoreDesktop lda SavedP
            sta   p0
            lda   SavedP+2
            sta   p0+2
            lda   #$2000
            sta   p1
            lda   #$00E1
            sta   p1+2
            jsr   Copy32K
            Tool  _ShowCursor
            rts

* Copy32K: 32768 bytes from [p0] to [p1].
Copy32K     ldy   #screenSize-2
:copy       lda   [p0],y
            sta   [p1],y
            dey
            dey
            bpl   :copy
            rts

WaitEvent   ds    16
