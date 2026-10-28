*-------------------------------------------------------------
* Prefs.s - Preferences and what they change, as SuperConvert's (part of
* the main program; docs/superconvert-extras.md 2.5 and
* docs/superconvert-file.md 3.7 and 9). The dialog is in Extras.s.
*-------------------------------------------------------------

* DoPrefs: Apple > Preferences...
DoPrefs     jsl   MonoSkips             ; ("SKIP ME" set in a monochrome window?)
            sta   SkipMe
            lda   #Prefs
            sta   dctl
            lda   #^Prefs
            sta   dctl+2
            lda   #1                    ; (one "SKIP ME" word here)
            sta   darg
            jsl   PrefsDlg
            cmp   #0
            beq   :out
            jsl   MonoNoSkip            ; Clear all "SKIP ME" preferences
:out        rts

* AfterLoad: after a picture loaded: a screen image is first viewed full
* screen (unless "Don't automatically view screen images after loading"),
* then remapped if "Automatically show Remap dialog after loading screen
* images"; a true colour image gets the Remap dialog unless "Don't
* automatically show Remap dialog for true color images". "Automatically
* save (print) picture after loading" then waits for the next idle moment.
AfterLoad   lda   TestMode              ; (tests: no dialogs, no views)
            bne   :out
            lda   IsTrue
            bne   :true
            lda   HaveScreen            ; (a monochrome page only: nothing
            beq   :pend                 ; to view or remap)
            lda   PrefNoView
            bne   :noView
            lda   #0
            jsr   DoView
:noView     lda   PrefRemapScr
            beq   :pend
            jsr   DoRemap
            bra   :pend
:true       lda   PrefNoRemap
            bne   :pend
            jsr   DoRemap
:pend       lda   PrefSave
            sta   PendSave
            lda   PrefPrint
            sta   PendPrint
:out        rts

* AfterRemap: a Remap made the screen image: viewed full screen unless
* "Don't automatically view screen images after loading".
AfterRemap  lda   TestMode
            bne   :out
            lda   PrefNoView
            bne   :out
            lda   #0
            jmp   DoView
:out        rts

* AfterSave: a picture saved: with "Automatically load next picture after
* saving", the queue's next file loads at the next idle moment.
AfterSave   lda   PrefNext
            beq   :out
            jsl   DeskQueued
            sta   PendNext
:out        rts

* Pending: an idle moment: a save waiting (as File > Save conversion),
* then a print (not here yet), then a load next (only with neither
* waiting).
Pending     lda   PendSave
            beq   :print
            stz   PendSave
            jsl   DeskSaveFmt
            jmp   DoSave
:print      lda   PendPrint
            beq   :next
            stz   PendPrint
            rts
:next       lda   PendNext
            beq   :out
            stz   PendNext
            jmp   LoadNext
:out        rts

* DoFonts: Extras > Available font list (A = 0) and More available fonts
* (A = 1): every image goes; the screen image lists the installed fonts in
* themselves (Extras.s), named FontList00, FontList01 ...
DoFonts     sta   t2
            jsr   CloseImages
            lda   ScreenP
            sta   dctl
            lda   ScreenP+2
            sta   dctl+2
            lda   t2
            bne   :page
            stz   FontPage
            bra   :list
:page       inc   FontPage
:list       lda   t2
            jsl   FontList
            lda   #640                  ; 640 x the lines used, 640 mode
            sta   PicW
            lda   darg
            sta   PicH
            lda   #1
            sta   Pic640
            sta   HaveScreen
            ldx   #0                    ; its name
:n          lda   TxFontList,x
            sta   PicName,x
            sta   NameGS+2,x
            inx
            inx
            cpx   #8
            bcc   :n
            lda   FontPage
            ldx   #'0'
:tens       cmp   #10
            bcc   :ones
            sbc   #10
            inx
            bra   :tens
:ones       clc
            adc   #'0'
            xba
            sta   t0
            txa
            and   #$00FF
            ora   t0
            sta   PicName+8
            sta   NameGS+10
            stz   PicName+10
            lda   #10
            sta   NameGS
            pea   iMoreFonts            ; another page follows?
            lda   dact
            beq   :noMore
            Tool  _EnableMItem
            bra   :re
:noMore     Tool  _DisableMItem
:re         pea   iReconvert            ; (not a file)
            Tool  _DisableMItem
            lda   #0
            jsl   DeskSelClear
            lda   #1
            sta   ShowType
            jsr   PictureMenus
            jmp   AfterRemap            ; (viewed full screen)

FontPage    dw    0
TxFontList  asc   'FontList'

* DoKeyChart: Extras > Font key chart...: every image goes; a font chosen
* with the Font Manager's dialog is drawn with each character's code and
* keys (Extras.s), named KeyChart.
DoKeyChart  jsr   CloseImages
            lda   ScreenP
            sta   dctl
            lda   ScreenP+2
            sta   dctl+2
            jsl   KeyChart
            bcs   :out                  ; (cancelled)
            cmp   #0
            beq   :drawn
            jmp   Problem
:drawn      lda   #640                  ; 640 x the lines used, 640 mode
            sta   PicW
            lda   darg
            sta   PicH
            lda   #1
            sta   Pic640
            sta   HaveScreen
            ldx   #0
:n          lda   TxKeyChart,x
            sta   PicName,x
            sta   NameGS+2,x
            inx
            inx
            cpx   #10
            bcc   :n
            lda   #8
            sta   NameGS
            pea   iReconvert            ; (not a file)
            Tool  _DisableMItem
            lda   #0
            jsl   DeskSelClear
            lda   #1
            sta   ShowType
            jsr   PictureMenus
            jmp   AfterRemap            ; (viewed full screen)
:out        rts

TxKeyChart  asc   'KeyChart',00,00

* DoOscope: Screen > Oscilloscope Art (Extras.s Oscope.s): the screen
* image becomes a 320 mode picture for an oscilloscope, shown as after a
* load.
DoOscope    lda   HaveScreen
            bne   :have
            Tool  _SysBeep
            rts
:have       lda   ScreenP
            sta   scrp
            lda   ScreenP+2
            sta   scrp+2
            lda   PicW                  ; its bytes a line
            ldx   Pic640
            beq   :b320
            clc
            adc   #3
            lsr
            lsr
            bra   :bytes
:b320       inc
            lsr
:bytes      sta   darg
            lda   PicH
            sta   dact
            lda   UserID
            sta   uid
            Tool  _WaitCursor
            jsl   OscArt
            php
            pha
            Tool  _InitCursor
            pla
            plp
            bcc   :made
            jmp   Problem
:made       lda   #320                  ; a whole 320 mode screen now
            sta   PicW
            lda   #200
            sta   PicH
            stz   Pic640
            lda   #1
            jsl   DeskSelClear
            lda   #1
            sta   ShowType
            jmp   PictureMenus

* SaveDialogs: Save conversion's dialogs (Save.s SaveDlg.s): the size of
* the saved picture, where it goes, what the format can't hold; the
* picture is made at that size (the canvas).
*   out: carry set if cancelled (an error already shown)
SaveDialogs lda   #1                    ; the screen image's selection
            jsl   DeskSel
            lda   ScreenP
            sta   scrp
            lda   ScreenP+2
            sta   scrp+2
            lda   PicW
            sta   pw
            lda   PicH
            sta   ph
            lda   Pic640
            sta   p640
            lda   UserID
            sta   uid
            lda   SaveFmt
            jsl   SaveAsk
            bcc   :made
            cmp   #$FFFF
            beq   :cancel
            jsr   Problem
:cancel     sec
            rts
:made       lda   dctl
            sta   CanvasP
            lda   dctl+2
            sta   CanvasP+2
            lda   darg
            sta   CanvBytes
            lda   dact
            sta   CanvLines
            lda   cstr
            sta   CanvStr
            lda   cscb
            sta   CanvScb
            lda   cpal
            sta   CanvPal
            lda   dsel                  ; (the original, whole: its own width)
            sta   CanvSel
            lda   #1
            sta   CanvasOn
            clc
            rts

* SaveCanvas: the picture the savers read (scrp; cstr, cscb, cpal; pw, ph,
* p640; SvBytes, SvLines): the canvas the dialogs made, or the screen
* image (its whole screen for the Apple IIgs formats).
SaveCanvas  lda   Pic640
            sta   p640
            lda   CanvasOn
            beq   :screen
            lda   CanvasP
            sta   scrp
            lda   CanvasP+2
            sta   scrp+2
            lda   CanvStr
            sta   cstr
            lda   CanvScb
            sta   cscb
            lda   CanvPal
            sta   cpal
            lda   CanvBytes
            sta   SvBytes
            lda   CanvLines
            sta   SvLines
            sta   ph
            lda   CanvSel               ; the original, whole: its width in
            bne   :bytes                ; pixels
            lda   CanvLines
            cmp   PicH
            bne   :bytes
            lda   PicW
            ldx   Pic640
            beq   :b320
            clc
            adc   #3
            lsr
            lsr
            bra   :bw
:b320       inc
            lsr
:bw         cmp   CanvBytes
            bne   :bytes
            lda   PicW
            sta   pw
            rts
:bytes      lda   CanvBytes             ; else whole bytes
            asl
            ldx   Pic640
            beq   :w
            asl
:w          sta   pw
            rts
:screen     lda   ScreenP
            sta   scrp
            lda   ScreenP+2
            sta   scrp+2
            lda   #160
            sta   cstr
            sta   SvBytes
            lda   #scbOffset
            sta   cscb
            lda   #palOffset
            sta   cpal
            lda   #200
            sta   SvLines
            lda   PicW
            sta   pw
            lda   PicH
            sta   ph
            rts

* NoCanvas: the canvas disposed of (after saving or cancelling).
NoCanvas    lda   CanvasOn
            beq   :out
            stz   CanvasOn
            jsl   SaveFree
:out        rts

CanvasOn    dw    0                     ; a canvas was made for this save
CanvasP     adrl  0
CanvBytes   dw    0
CanvLines   dw    0
CanvStr     dw    0
CanvScb     dw    0
CanvPal     dw    0
CanvSel     dw    0
SvBytes     dw    160                   ; the Apple IIgs formats' size
SvLines     dw    200
TestSaveDlg dw    0                     ; (tests: SAVEDLG 1 shows the dialogs)

* The options (Preferences' check boxes 6-13, saved in 9:MCGS.Prefs), then
* the "SKIP ME" words Preferences can clear.
Prefs       =     *
PrefSave    dw    0                     ; Automatically save picture after loading
PrefPrint   dw    0                     ; ... print picture after loading
PrefNext    dw    0                     ; ... load next picture after saving
PrefNoView  dw    0                     ; Don't automatically view screen images
PrefVOC     dw    0                     ; Use second monitor (VOC)
PrefNoRemap dw    0                     ; Don't ... Remap dialog for true color
PrefRemapScr dw   0                     ; ... Remap dialog after screen images
PrefDisk    dw    0                     ; Disk insertion starts load
SkipMe      dw    0                     ; (any monochrome window's "SKIP ME")
PendSave    dw    0                     ; waiting for an idle moment
PendPrint   dw    0
PendNext    dw    0
