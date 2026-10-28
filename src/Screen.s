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
