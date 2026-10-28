*-------------------------------------------------------------
* MegaconvertGS - an image converter for the Apple IIgs
* Copyright (c) 2026 Walter Tengler
*
* Opens Super Hi-Res pictures ($C1, PackBytes, Apple Preferred,
* PaintWorks) and true colour ones (PNG, GIF, JPEG, BMP), remaps
* them to 320 mode, views and saves them.
*-------------------------------------------------------------
            rel
            mx    %00
            use   macros/Macs.s
            put   Equates.s

DecodeApple ext                         ; Apple.s, the Apple II and IIgs loaders
DecodeOther ext                         ; Other.s, the other computers' formats
SaveFormat  ext                         ; Save.s, the save formats
SaveAsk     ext                         ; (SaveDlg.s: its dialogs)
SaveFree    ext
SaveTest    ext
SaveWarned  ext
HexSet      ext
PngSet      ext
TiffSet     ext
SaveDone    ext
RemapRun    ext                         ; RemapSeg.s: Remap, and its dialog
RemapSet    ext
RemapDialog ext
RemapClicks ext
RemapStore  ext
DeskStart   ext                         ; Desk.s: the Load formats, Save formats
DeskControl ext                         ; and screen image windows
DeskLoadFmt ext
DeskSaveFmt ext
DeskShowSave ext
DeskWindow  ext
DeskClose   ext
DeskPicture ext
DeskPick    ext
DeskImages  ext
DeskNoImages ext
DeskCursor  ext                         ; ImgTools.s: the image window's tools
DeskIdle    ext
DeskContent ext
DeskKey     ext
DeskSel     ext
DeskSelClear ext
DeskExitPals ext
DeskTop     ext
DeskTest    ext
DeskMultiGet ext                        ; LoadMulti.s: Load & convert's dialog
DeskAddFiles ext                        ; and the queue
DeskNextFile ext
DeskQueueClear ext
DeskQueued  ext
DeskQueue   ext
DeskAddPath ext
DeskQueueText ext
PrefsDlg    ext                         ; Extras.s: Preferences
PrefsLoad   ext
PrefsSave   ext
FontList    ext
KeyChart    ext
SysInfo     ext
Examine     ext
HelpGo      ext
HelpTask    ext
HelpMenu    ext
HelpLog     ext
HelpHome    ext
PrintAlign  ext
PrintQuit   ext
PrintPic    ext
WoaName     ext
WoaTest     ext
DeskPixSize ext
MonoFromSet ext
OscArt      ext
MonoSkips   ext
Dlg640      ext                         ; True640.s: Convert to true color,
SmoothLine  ext                         ; 640 mode
MonoNoSkip  ext
DeskInfoClick ext
FilterRun   ext                         ; Filter.s: the True color filters
FilterTurn  ext                         ; and Rotate/flip
FilterAsk   ext
FilterBusy  ext
FilterIdle  ext
FilterInfo  ext
FilterTurnAsk ext
ViewRun     ext                         ; View.s: the full-screen views
MonoMake    ext                         ; MonoSeg.s: monochrome images
MonoMethod  ext
MonoOut     ext
MonoOpts    ext
MonoNeg     ext
MonoWhite   ext
MonoToDlg   ext
MonoFromDlg ext
MonoInfoAlert ext

*-------------------------------------------------------------
* Start-up
*-------------------------------------------------------------
Start       phk
            plb
            Tool  _TLStartUp
            pha
            Tool  _MMStartUp
            pla
            sta   UserID

            pha                         ; result: start/stop reference (long)
            pha
            lda   UserID
            pha
            pea   0                     ; the reference below is a pointer
            PushLong StartStop
            Tool  _StartUpTools
            pla
            sta   SSRef
            pla
            sta   SSRef+2
            bcc   :toolsUp
            jmp   Fatal

:toolsUp    jsr   AllocBuffers
            bcc   :buffers
            jmp   Fatal
:buffers    Tool  _InitCursor           ; arrow instead of the launch watch
            jsr   ShowTitle             ; (the title picture, if it is there)
            jsr   MakeMenus
            jsr   CheckDesk             ; (Revert to normal desktop)
            lda   #Prefs                ; the options saved with Preferences
            sta   dctl
            lda   #^Prefs
            sta   dctl+2
            jsl   PrefsLoad
            lda   UserID                ; (its memory is ours)
            sta   uid
            jsl   DeskStart             ; the Load formats and Save formats windows
            jsr   RunTests              ; only when *:MC.TEST exists

*-------------------------------------------------------------
* Main event loop
*-------------------------------------------------------------
EventLoop   lda   QuitFlag
            beq   :jx1
            jmp   Quit
:jx1
            jsr   OneEvent
            bra   EventLoop

* OneEvent: the next event, from TaskMaster, and what it asks for (the
* test commands' IDLE runs this too).
OneEvent    jsr   EditMenus
            jsl   DeskCursor            ; (the pointer over the picture)
            pha
            pea   $FFFF                 ; every event
            PushLong EventRec
            Tool  _TaskMaster
            pla
            bne   :event
            jsl   DeskIdle              ; (the selection's ants march)
            jmp   Pending               ; (a save or load next waiting)
:event      jsr   HelpEvent             ; (the help window's events)
            bcc   :ours
            rts
:ours       cmp   #wInContent
            bne   :notContent
            lda   EventRec+10           ; a click in the picture
            sta   dctl
            lda   EventRec+12
            sta   dctl+2
            lda   EventRec+ClickCount
            sta   dclk
            jsl   DeskContent
            rts
:notContent cmp   #3                    ; a key: for the image window
            bne   :notKey
            lda   EventRec+2
            sta   dctl
            lda   EventRec+14
            sta   dctl+2
            stz   dact
            jsl   DeskKey
            jmp   ImgAction
:notKey     cmp   #wInMenuBar
            beq   :menu
            cmp   #wInSpecial
            beq   :menu
            cmp   #wInGoAway
            beq   :close
            cmp   #wInControl
            beq   :control
            cmp   #wInInfo
            beq   :info
            rts
:info       lda   EventRec+10           ; where: v, h
            sta   dctl
            lda   EventRec+12
            sta   dctl+2
            jsl   DeskInfoClick
            jmp   ImgAction             ; (its actions: crop, discard)
:menu       jmp   DoMenu
:close      jmp   CloseImages           ; (only the image window has one)
:control    jmp   DoControl

* HelpEvent: TaskMaster's result A, for the help window if it is its
* (Help.s; $FFFF: the Close command).
*   out: carry set if it was; A kept
HelpEvent   pha
            lda   #EventRec
            sta   dctl
            lda   #^EventRec
            sta   dctl+2
            lda   UserID
            sta   uid
            pla
            jsl   HelpTask
            rts

* DoHelp: Help! (the page HOME, or the help window to the front).
DoHelp      lda   UserID
            sta   uid
            jsl   HelpHome
            rts

* EditMenus: the Edit menu for the front window, before each TaskMaster
* call: a desk accessory's window has all of it (TaskMaster passes the
* commands on); otherwise Undo, Paste and Clear stay dimmed, Cut and Copy
* need a screen image and Close any image.
EditMenus   pha
            pha
            Tool  _FrontWindow
            pla
            plx
            sta   n0
            stx   n0+2
            ora   n0+2
            beq   :ours
            pha
            PushLongAt n0
            Tool  _GetSysWFlag
            pla
            beq   :ours
            lda   #%111111              ; (bits: Undo, Cut, Copy, Paste, Clear,
            bra   :set                  ; Close)
:ours       lda   #0
            ldx   HaveScreen
            beq   :noScr
            lda   #%000110
:noScr      ldx   HaveScreen
            bne   :any
            ldx   IsTrue
            bne   :any
            ldx   MonoBlk
            beq   :set
:any        ora   #%100000
:set        cmp   EditState
            beq   :out
            sta   EditState
            sta   t0
            ldx   #iUndo
:item       phx
            phx
            lsr   t0
            bcc   :off
            Tool  _EnableMItem
            bra   :next
:off        Tool  _DisableMItem
:next       plx
            inx
            cpx   #iClose+1
            bcc   :item
:out        rts

EditState   dw    $FFFF                 ; (as last set: none yet)

* CopyImage: Edit > Copy (A = 0) and Cut (A = 1): the screen image goes to
* the Clipboard as a QuickDraw II picture in the mode of its first line,
* with its first colour table as a private scrap (type $8002: a count of 1,
* then the 16 colours); a picture with more than one colour table or with
* both modes gets a warning. Cut then discards the screen image.
CopyImage   sta   CutFlag
            lda   HaveScreen
            bne   :have
            rts
:have       lda   ScreenP               ; the image: its LocInfo, in the mode
            sta   p0                    ; of its first line
            sta   CLoc+2
            lda   ScreenP+2
            sta   p0+2
            sta   CLoc+4
            ldy   #scbOffset
            lda   [p0],y
            and   #$00FF
            sta   CLoc
            lda   PicH
            sta   CLoc+12               ; bounds: 0, 0, lines, pixels
            lda   PicW
            sta   CLoc+14
            ldx   #0                    ; the whole image
:fr         lda   CLoc+8,x
            sta   CFrame,x
            inx
            inx
            cpx   #8
            bcc   :fr
            lda   #1                    ; or its selection (columns: pixels
            jsl   DeskSel               ; in 640 mode, half in 320 mode)
            lda   dsel
            sta   CopySel
            beq   :port
            lda   dselr
            sta   CFrame
            lda   dselr+4
            sta   CFrame+4
            lda   dselr+2
            ldx   dselr+6
            bit   CLoc-1                ; (the SCB's bit 7)
            bmi   :lr
            lsr
            pha
            txa
            lsr
            tax
            pla
:lr         sta   CFrame+2
            stx   CFrame+6
:port       pha                         ; a port over the image
            pha
            Tool  _GetPort
            pla
            sta   COld
            pla
            sta   COld+2
            PushLong CPort
            Tool  _OpenPort
            PushLong CLoc
            Tool  _SetPortLoc
            PushLong CFrame
            Tool  _SetPortRect
            PushLong CFrame
            Tool  _ClipRect
            pha                         ; the picture: the image copied into
            pha                         ; the port onto itself
            PushLong CFrame
            Tool  _OpenPicture
            pla
            sta   CPic
            pla
            sta   CPic+2
            PushLong CLoc
            PushLong CFrame
            lda   CFrame+2              ; (left, top)
            pha
            lda   CFrame
            pha
            pea   0                     ; copy
            Tool  _PPToPort
            Tool  _ClosePicture
            PushLongAt COld
            Tool  _SetPort
            PushLong CPort
            Tool  _ClosePort
            lda   CPic
            ora   CPic+2
            bne   :pic
            lda   #errCopy
            jmp   Problem
:pic        Tool  _ZeroScrap
            PushLongAt CPic             ; its size and bytes
            Tool  _HLock
            pha
            pha
            PushLongAt CPic
            Tool  _GetHandleSize
            pla
            sta   CSize
            pla
            sta   CSize+2
            lda   CPic
            sta   p1
            lda   CPic+2
            sta   p1+2
            PushLongAt CSize            ; PutScrap(size, 1: a picture, bytes)
            pea   1
            ldy   #2
            lda   [p1],y
            pha
            lda   [p1]
            pha
            Tool  _PutScrap
            PushLongAt CPic
            Tool  _KillPicture
            ldy   #palOffset            ; the colour table scrap
            ldx   #0
:pal        lda   [p0],y
            sta   CPal+2,x
            iny
            iny
            inx
            inx
            cpx   #32
            bcc   :pal
            PushLong 34
            pea   $8002
            PushLong CPal
            Tool  _PutScrap
            jsr   Mixed                 ; one colour table, one mode?
            bcc   :one
            pha
            pea   0                     ; (a C string, no substitutions)
            PushLong 0
            PushLong MixedText
            Tool  _AlertWindow
            pla
:one        lda   CutFlag               ; Cut without a selection: the
            beq   :out                  ; screen image goes (with one, as
            lda   CopySel               ; Copy)
            bne   :out
            stz   HaveScreen
            lda   IsTrue
            ora   MonoBlk
            bne   :others
            jmp   CloseImages
:others     jsr   TellDesk
:out        rts

* Mixed: carry set if the image's lines use more than one colour table, or
* both modes.
Mixed       ldy   #scbOffset
            lda   [p0],y
            and   #$008F
            sta   t0
            ldx   PicH
:line       lda   [p0],y
            and   #$008F
            cmp   t0
            bne   :yes
            iny
            dex
            bne   :line
            clc
            rts
:yes        sec
            rts

CutFlag     dw    0
CopySel     dw    0
CSize       adrl  0
COld        adrl  0
CPic        adrl  0
CLoc        dw    0                     ; SCB
            adrl  0                     ; pixels
            dw    160                   ; bytes a line
            dw    0,0,0,0               ; bounds
CFrame      dw    0,0,0,0
CPal        dw    1                     ; one colour table
            ds    32
CPort       ds    $AA                   ; a GrafPort
MixedText   asc   '64/The Clipboard does not currently support mixed graphics '
            asc   'modes or multiple color palettes.  This image will probably '
            asc   'not look right when pasted./^#6',00

* CloseImages: Edit > Close and the image window's close box: every image
* (screen, true colour, monochrome) is discarded; the image window, the
* Save... button and the commands that need an image go.
CloseImages stz   HaveScreen
            jsr   FreeTrue
            lda   MonoBlk
            beq   :noMono
            PushLongAt MonoHnd
            Tool  _DisposeHandle
            stz   MonoBlk
:noMono     jsr   DeskDP
            jsl   DeskNoImages
            lda   #0                    ; no Save... in Save formats
            jsl   DeskShowSave
            pea   $0080                 ; the Screen, True color and Monochrome
            pea   5                     ; menus dimmed
            Tool  _SetMenuFlag
            pea   $0080
            pea   9
            Tool  _SetMenuFlag
            pea   $0080
            pea   6
            Tool  _SetMenuFlag
            pea   iSaveAPF
            Tool  _DisableMItem
            pea   iWinLast              ; (Windows: Current image)
            Tool  _DisableMItem
            Tool  _DrawMenuBar
            rts

* DoControl: a click in a button or list of the Load formats or Save
* formats window: Load... and Save... (or a double click on a format)
* use the formats chosen there.
DoControl   lda   EventRec+TaskData2    ; the control's handle
            sta   dctl
            lda   EventRec+TaskData2+2
            sta   dctl+2
            lda   EventRec+ClickCount
            sta   dclk
            jsl   DeskControl
            lda   dact
            cmp   #1
            beq   :load
            cmp   #2
            beq   :save
            cmp   #3
            beq   :next
            rts
:next       jmp   LoadNext              ; (the Load next button)
:load       jmp   LoadConv              ; (Load..., a double click)
:save       lda   darg
            jmp   SaveChosen

*-------------------------------------------------------------
* Shut down and return to the program selector
*-------------------------------------------------------------
Quit        jsl   PrintQuit             ; (the Print Manager, if started)
            pea   0                     ; start/stop reference is a pointer
            PushLongAt SSRef
            Tool  _ShutDownTools
            lda   UserID
            pha
            Tool  _MMShutDown
            Tool  _TLShutDown
            GSOS  _QuitGS;QuitParms
            brk   $00                   ; not reached

Fatal       Tool  _SysBeep              ; tools could not start: just quit
            GSOS  _QuitGS;QuitParms
            brk   $00

* AllocBuffers: the picture and the copy of the desktop screen.
AllocBuffers lda  #screenSize
            sta   n0
            stz   n0+2
            jsr   NewBuffer
            bcs   :err
            lda   p0
            sta   ScreenP
            lda   p0+2
            sta   ScreenP+2
            jsr   NewBuffer
            bcs   :err
            lda   p0
            sta   SavedP
            lda   p0+2
            sta   SavedP+2
            jsr   NewBuffer
            bcs   :err
            lda   p0
            sta   RemapP
            lda   p0+2
            sta   RemapP+2
            clc
:err        rts

*-------------------------------------------------------------
* Menus
*-------------------------------------------------------------
MakeMenus   PushLong ExtrasMenu
            jsr   AddMenu
            PushLong WindowsMenu
            jsr   AddMenu
            PushLong MonoMenu
            jsr   AddMenu
            PushLong TrueMenu
            jsr   AddMenu
            PushLong ScreenMenu
            jsr   AddMenu
            PushLong EditMenu
            jsr   AddMenu
            PushLong FileMenu
            jsr   AddMenu
            PushLong AppleMenu
            jsr   AddMenu
            pea   1                     ; Apple menu number: add desk accessories
            Tool  _FixAppleMenu
            pha
            Tool  _FixMenuBar
            pla
            Tool  _DrawMenuBar
            rts

* AddMenu: pointer to a menu string on the stack (pushed before the JSR).
AddMenu     pla                         ; return address
            sta   :ret
            pha                         ; result: menu handle
            pha
            lda   7,s                   ; copy the caller's pointer above the result:
            pha                         ; high word, then low word (each now at 7,s)
            lda   7,s
            pha
            Tool  _NewMenu              ; leaves the handle on the stack
            pea   0                     ; insert at the front of the bar
            Tool  _InsertMenu
            pla                         ; drop the caller's pointer
            pla
            lda   :ret
            pha
            rts
:ret        dw    0

DoMenu      jsl   DeskExitPals          ; (the desktop's colours first)
            lda   EventRec+TaskData     ; item number
            jsr   ScreenFirst           ; (the Screen menu: a screen image first)
            bcc   :item
            jmp   :done
:item       cmp   #iQuit
            bne   :jx1
            jmp   :quit
:jx1
            cmp   #iAbout
            bne   :jx2
            jmp   :about
:jx2
            cmp   #iClose
            bne   :jx3
            jmp   :close
:jx3
            cmp   #iCut
            bne   :jxCut
            jmp   :cut
:jxCut
            cmp   #iCopy
            bne   :jxCopy
            jmp   :copy
:jxCopy
            cmp   #iOpen
            bne   :jx5
            jmp   :open
:jx5
            cmp   #iLoadConv
            bne   :jx6
            jmp   :loadConv
:jx6
            cmp   #iReconvert
            bne   :jx12
            jmp   :reconv
:jx12
            cmp   #iView
            bne   :jx13
            jmp   :view
:jx13
            cmp   #iRemap
            bne   :jx4
            jmp   :remap
:jx4
            cmp   #iSaveAPF             ; (Save conversion)
            bne   :jx7
            jmp   :save
:jx7
            cmp   #iScrInfo
            bne   :jx11
            jmp   :scrInfo
:jx11
            cmp   #iTrueInfo
            bne   :jx8
            jmp   :trueInfo
:jx8
            cmp   #iScrMono             ; monochrome images: the two
            beq   :mono                 ; conversions and the Monochrome menu
            cmp   #iTrueMono
            beq   :mono
            cmp   #iMonoInfo
            bcc   :notMono
            cmp   #iMonoNeg+1
            bcs   :notMono
:mono       jsr   DoMono
            jmp   :done
:notMono    cmp   #iHalf                ; the views
            bne   :notHalf
            lda   #1
            jsr   DoView
            jmp   :done
:notHalf    cmp   #iX4
            bne   :notX4
            lda   #2
            jsr   DoView
            jmp   :done
:notX4      cmp   #iApprox
            bne   :notApprox
            lda   #3
            jsr   DoView
            jmp   :done
:notApprox  cmp   #iTurn
            bne   :notTurn
            jsr   DoTurnMenu
            jmp   :done
:notTurn    cmp   #iToTrue
            bne   :notToTrue
            jsr   ToTrue
            jmp   :done
:notToTrue  cmp   #iStore
            bne   :notStore
            jsr   StorePal
            jmp   :done
:notStore   cmp   #iDesk
            bne   :notDesk
            jsr   UseDesk
            jmp   :done
:notDesk    cmp   #iRevert
            bne   :notRevert
            jsr   RevertDesk
            jmp   :done
:notRevert  cmp   #iLoadNext
            bne   :notNext
            jsr   LoadNext
            jmp   :done
:notNext    cmp   #iCancelQ
            bne   :notCancel
            jsr   QueueOff
            jmp   :done
:notCancel  cmp   #iFonts
            bne   :notFonts
            lda   #0
            jsr   DoFonts
            jmp   :done
:notFonts   cmp   #iMoreFonts
            bne   :notMore
            lda   #1
            jsr   DoFonts
            jmp   :done
:notMore    cmp   #iKeyChart
            bne   :notChart
            jsr   DoKeyChart
            jmp   :done
:notChart   cmp   #iSysInfo
            bne   :notSys
            stz   dctl                  ; (the window, as usual)
            stz   dctl+2
            lda   UserID
            sta   uid
            jsl   SysInfo
            jmp   :done
:notSys     cmp   #iExamine
            bne   :notExam
            stz   dctl                  ; (the dialog, as usual)
            stz   dctl+2
            lda   UserID
            sta   uid
            jsl   Examine
            jmp   :done
:notExam    cmp   #iAlign
            bne   :notAlign
            lda   UserID
            sta   uid
            jsl   PrintAlign
            jmp   :done
:notAlign   cmp   #iPrint
            bne   :notPrint
            jsr   DoPrint
            jmp   :done
:notPrint   cmp   #iHelp
            bne   :notHelp
            jsr   DoHelp
            jmp   :done
:notHelp    cmp   #iMenuHelp
            bne   :notMHelp
            lda   UserID
            sta   uid
            jsl   HelpMenu
            jmp   :done
:notMHelp   cmp   #iOscope
            bne   :notOsc
            jsr   DoOscope
            jmp   :done
:notOsc     cmp   #iPrefs
            bne   :notPrefs
            jsr   DoPrefs
            jmp   :done
:notPrefs   cmp   #iExchange
            bne   :notExch
            jsr   Exchange
            jmp   :done
:notExch    cmp   #iFirstFx             ; the True color filters
            bcc   :notFx
            cmp   #iLastFx+1
            bcs   :notFx
            sbc   #iFirstFx-1           ; (carry clear: one less)
            jsr   DoFilter
            bra   :done
:notFx      cmp   #iWinFirst
            bcc   :done
            cmp   #iWinLast+1
            bcs   :done
            sbc   #iWinFirst-1          ; (carry clear: one less)
            jsl   DeskWindow
            bra   :done
:quit       inc   QuitFlag
            bra   :done
:about      jsr   About
            bra   :done
:close      lda   #$FFFF                ; (the help window in front: it goes)
            jsr   HelpEvent
            bcs   :closed
            jsr   CloseImages           ; every image goes
:closed
            bra   :done
:cut        lda   #1
            bra   :copy2
:copy       lda   #0
:copy2      jsr   CopyImage
            bra   :done
:open       jsr   DoOpen                ; any kind: MegaconvertGS recognises it
            bra   :done
:loadConv   jsr   LoadConv              ; the kind chosen in Load formats
            bra   :done
:reconv     jsr   Reconvert
            bra   :done
:view       lda   #0
            jsr   DoView
            bra   :done
:remap      jsr   DoRemap
            bra   :done
:save       jsl   DeskSaveFmt           ; the kind chosen in Save formats
            jsr   DoSave
            bra   :done
:scrInfo    jsr   ScreenInfo
            bra   :done
:trueInfo   jsr   TrueInfo
:done       lda   EventRec+TaskData+2   ; menu number (0: chosen by a test)
            beq   :noMenu
            pea   0                     ; un-highlight the menu title
            pha
            Tool  _HiliteMenu
:noMenu     rts

About       pha                         ; result: button pressed
            pea   0                     ; alert string is a C string
            PushLong 0                  ; no substitution strings
            PushLong AboutText
            Tool  _AlertWindow
            pla
            rts

* Problem: shows an alert for the error in A.
Problem     cmp   #errCancel            ; (cancelled in a window: nothing to say)
            bne   :say
            rts
:say        sta   t1
            ldx   #0
:find       lda   ErrCodes,x
            beq   :number
            cmp   t1
            beq   :known
            inx
            inx
            bra   :find
:known      lda   ErrTexts,x
            tax
            pha
            pea   0
            PushLong 0
            pea   ^MsgNotPic
            phx
            Tool  _AlertWindow
            pla
            rts
:number
            lda   LogLen                ; build the text after the end of the log,
            sta   t3                    ; so a test log is kept
            lda   #TxtProblem
            jsr   LogC
            lda   t1
            jsr   LogHex
            lda   #TxtProblemEnd
            jsr   LogC
            sep   #$20
            mx    %10
            ldx   LogLen
            stz   LogBuf,x
            rep   #$20
            mx    %00
            lda   t3
            sta   LogLen
            clc
            adc   #LogBuf
            tax
            pha                         ; result: button pressed
            pea   0                     ; alert string is a C string
            PushLong 0                  ; no substitution strings
            pea   ^LogBuf
            phx
            Tool  _AlertWindow
            pla
            rts

*-------------------------------------------------------------
* Open and Save
*-------------------------------------------------------------
DoOpen      lda   ForceFmt              ; a format listed, but not here yet?
            jsr   FmtHere
            bcc   :ask
            lda   #errNotImpl
            jmp   Problem
:ask        lda   #3                    ; ask for handles to the name and path
            sta   Reply+8
            sta   Reply+14
            pea   120                   ; where (ignored when centred)
            pea   40
            pea   0                     ; prompt: Pascal string pointer
            PushLong OpenPrompt
            PushLong 0                  ; no filter
            PushLong 0                  ; every file type
            PushLong Reply
            lda   #LoadPfx              ; (in the folder of the last load)
            jsr   RecallPfx
            Tool  _SFGetFile2
            lda   #LoadPfx
            jsr   StorePfx
            lda   Reply                 ; good?
            beq   :cancel
            lda   Reply+16              ; path handle: buffer size, then GS/OS string
            sta   p0
            lda   Reply+18
            sta   p0+2
            lda   [p0]
            tax
            ldy   #2
            lda   [p0],y
            sta   PathPtr+2
            txa
            clc
            adc   #2
            sta   PathPtr
            lda   PathPtr+2
            adc   #0
            sta   PathPtr+2
            jsr   LoadPath
            php
            pha
            bcs   :free
            jsr   KeepPath
:free       jsr   FreeReply
            pla
            plp
            bcc   :loaded
            jmp   Problem
:loaded     jmp   AfterLoad             ; (a view, the Remap dialog ...)
:cancel     rts

* RecallPfx: A = LoadPfx or SavePfx: prefix 8 becomes the folder kept
* there (none kept yet: it stays), so the file dialog opens in it.
RecallPfx   sta   q2
            lda   #^LoadPfx
            sta   q2+2
            ldy   #2                    ; (the string's length)
            lda   [q2],y
            beq   :out
            lda   q2
            clc
            adc   #2
            sta   PfxParms+4
            lda   q2+2
            sta   PfxParms+6
            GSOS  _SetPrefixGS;PfxParms
:out        rts

* StorePfx: A = LoadPfx or SavePfx: the folder the file dialog was in
* (prefix 8) is kept there (if it does not fit, none is).
StorePfx    sta   q2
            sta   PfxParms+4
            lda   #^LoadPfx
            sta   q2+2
            sta   PfxParms+6
            GSOS  _GetPrefixGS;PfxParms
            bcc   :out
            lda   #0
            ldy   #2
            sta   [q2],y
:out        rts

* Exchange: File > Exchange load/save paths: the next load starts in the
* folder of the last save, and the other way round.
Exchange    ldx   #0
:swap       lda   LoadPfx+2,x
            tay
            lda   SavePfx+2,x
            sta   LoadPfx+2,x
            tya
            sta   SavePfx+2,x
            inx
            inx
            cpx   #pfxSize-2
            bcc   :swap
            rts

PfxParms    dw    2                     ; GetPrefix, SetPrefix: prefix 8
            dw    8
            adrl  0
pfxSize     =     512
LoadPfx     dw    pfxSize               ; the folders of the last load and save:
            dw    0                     ; result buffers (size, then a GS/OS
            ds    pfxSize-4             ; string; length 0: none yet)
SavePfx     dw    pfxSize
            dw    0
            ds    pfxSize-4

FreeReply   PushLongAt Reply+10
            Tool  _DisposeHandle
            PushLongAt Reply+16
            Tool  _DisposeHandle
            rts

* FmtHere: carry clear if load format A is implemented (below fmtCount,
* Works of Art, and from TGA to the last).
FmtHere     cmp   #fmtCount
            bcc   :yes
            cmp   #fmtWOA
            beq   :yes
            cmp   #fmtTGA
            bcc   :no
            cmp   #fmtLast+1
            bcc   :yes
:no         sec
            rts
:yes        clc
            rts

* SaveChosen: the format chosen in Save formats (A). DoSave: A = save
* format; asks for a name (or, to add an icon, for the file to add it
* to), then saves.
SaveChosen
DoSave      sta   SaveFmt
            lda   HaveScreen
            bne   :have
            jsr   MakeScreen            ; (none: made first, as the original)
            bcc   :have
            rts
:have       lda   SaveFmt               ; a format listed, but not here yet?
            cmp   #saveCount
            bcs   :notHere
            cmp   #14                   ; (the Babelfish exports)
            bcc   :dlgs
            cmp   #16
            bcs   :dlgs
:notHere    lda   #errNotImpl
            jmp   Problem
:dlgs       lda   TestMode              ; the size, where it goes, warnings
            beq   :sizes                ; (tests: with SAVEDLG 1 only)
            lda   TestSaveDlg
            beq   :ask
:sizes      jsr   SaveDialogs
            bcc   :ask
            rts
:ask        lda   #3
            sta   Reply+8
            sta   Reply+14
            lda   #SavePfx              ; (in the folder of the last save)
            jsr   RecallPfx
            lda   SaveFmt
            cmp   #6                    ; icon: add to a file
            beq   :add
            cmp   #8                    ; icon resource: add to a file
            beq   :add
            pea   120
            pea   40
            pea   0                     ; prompt: Pascal string pointer
            PushLong SavePrompt
            pea   0                     ; default name: pointer to a GS/OS string
            PushLong NameGS
            PushLong Reply
            Tool  _SFPutFile2
            bra   :reply
:add        pea   120
            pea   40
            pea   0
            PushLong AddPrompt
            PushLong 0                  ; no filter
            PushLong 0                  ; every file type
            PushLong Reply
            Tool  _SFGetFile2
:reply      lda   #SavePfx
            jsr   StorePfx
            lda   Reply
            beq   :cancel
            lda   Reply+16
            sta   p0
            lda   Reply+18
            sta   p0+2
            lda   [p0]
            tax
            ldy   #2
            lda   [p0],y
            sta   PathPtr+2
            txa
            clc
            adc   #2
            sta   PathPtr
            lda   PathPtr+2
            adc   #0
            sta   PathPtr+2
            lda   SaveFmt
            jsr   SaveAs
            php
            pha
            jsr   FreeReply
            pla
            plp
            bcc   :saved
            cmp   #errCancel            ; (cancelled in the format's own window)
            beq   :cancel
            jmp   Problem
:saved      jsr   NoCanvas
            jmp   AfterSave             ; (Load next waiting, perhaps)
:cancel     jmp   NoCanvas

* PictureMenus: there is a picture: what needs one can be chosen.
PictureMenus pea  $FF7F                 ; the Screen and True color menus
            pea   5
            Tool  _SetMenuFlag
            pea   $FF7F
            pea   9
            Tool  _SetMenuFlag
            pea   $FF7F                 ; (and the Monochrome menu)
            pea   6
            Tool  _SetMenuFlag
            ldx   #iMonoInfo            ; its items need a monochrome image
:mono       phx
            phx
            lda   MonoBlk
            beq   :moff
            Tool  _EnableMItem
            bra   :mnext
:moff       Tool  _DisableMItem
:mnext      plx
            inx
            cpx   #iMonoNeg
            bcc   :mono
            pea   iSaveAPF
            Tool  _EnableMItem
            pea   iReconvert
            Tool  _EnableMItem
            pea   iWinLast              ; (Windows: Current image)
            Tool  _EnableMItem
            ldx   #iFirstFx             ; the filters, with a true colour picture
:fx         phx
            phx
            Tool  _EnableMItem
            plx
            inx
            cpx   #iLastFx+1
            bcc   :fx
            Tool  _DrawMenuBar
            lda   #1                    ; and Save... in Save formats
            jsl   DeskShowSave
            jsr   DeskDP                ; the screen image window shows it
            lda   ShowType
            sta   dshow
            lda   #1
            sta   ShowType
            jsl   DeskPicture
            rts

* DeskDP: the images, on the direct page for the Desk segment.
DeskDP      jsr   SetRemapDP            ; (tp, tstride, rw, rh, rtall, scrp, uid)
            lda   #MonoBlk              ; (the monochrome image)
            sta   mblk
            lda   #^MonoBlk
            sta   mblk+2
            lda   PicW
            sta   pw
            lda   PicH
            sta   ph
            lda   Pic640
            sta   p640
            lda   #PicName
            sta   dname
            lda   #^PicName
            sta   dname+2
            lda   #0
            ldx   HaveScreen
            beq   :noScr
            ora   #1
:noScr      ldx   IsTrue
            beq   :noTrue
            ora   #2
:noTrue     ldx   MonoBlk
            beq   :noMono
            ora   #4
:noMono     sta   dhave
            stz   dshow
            rts

* TellDesk: the images changed; the window follows (the same type shown).
TellDesk    jsr   DeskDP
            jsl   DeskImages
            rts

ShowType    dw    1                     ; the type the window shows next (2: true colour)

* The monochrome image (MonoSeg.s reads and sets it through mblk).
MonoBlk     dw    0                     ; there is one
MonoHnd     adrl  0
MonoP       adrl  0
MonoW       dw    0
MonoH       dw    0
MonoStr     dw    0                     ; bytes a row

* AfterMonoOut: the screen image MonoOut made (A = 0) becomes the one
* shown, or the true colour image it made (A = 2) is there now.
AfterMonoOut cmp  #0
            bne   :true
            lda   pw
            sta   PicW
            lda   ph
            sta   PicH
            lda   p640
            sta   Pic640
            lda   #1
            sta   HaveScreen
            jsl   DeskSelClear          ; (a new image: no selection)
            rts
:true       lda   #2
            jsl   DeskSelClear
            rts

* Reconvert: the last file loaded, loaded again the same way.
Reconvert   lda   LastPath
            beq   :none
            lda   #LastPath
            sta   PathPtr
            lda   #^LastPath
            sta   PathPtr+2
            lda   LastFmt
            sta   ForceFmt
            jsr   LoadPath
            stz   ForceFmt
            bcc   :loaded
            jmp   Problem
:loaded     jmp   AfterLoad
:none       rts

* KeepPath: the path at PathPtr (a GS/OS string) and the format it was
* loaded as, for Re-convert last file.
KeepPath    lda   PathPtr
            sta   p0
            lda   PathPtr+2
            sta   p0+2
            lda   [p0]                  ; length
            cmp   #250
            bcs   :long
            inc
            inc
            tay
            sep   #$20
            mx    %10
:c          dey
            lda   [p0],y
            sta   LastPath,y
            cpy   #0
            bne   :c
            rep   #$20
            mx    %00
            lda   ForceFmt
            sta   LastFmt
:long       rts

LastPath    ds    256                   ; (0: none yet)
LastFmt     dw    0

* ScreenInfo: the screen image's size and mode.
ScreenInfo  lda   HaveScreen
            bne   :have
            Tool  _SysBeep
            rts
:have       stz   DescLen
            lda   #TxtSInfo
            jsr   AddText
            lda   PicW
            jsr   AddDec
            lda   #TxtBy
            jsr   AddText
            lda   PicH
            jsr   AddDec
            lda   #TxtIn320
            ldx   Pic640
            beq   :mode
            lda   #TxtIn640
:mode       jsr   AddText
            lda   #TxtInfoEnd
            jsr   AddText
            bra   InfoAlert

* TrueInfo: the true colour picture's size.
TrueInfo    jsr   MakeTrue              ; SuperConvert's dialog, with the graph
            bcs   :err
            jsr   SetRemapDP
            jsl   FilterInfo
            rts
:err        jmp   Problem

* MakeTrue: a true colour image (from the screen image if there is none).
*   out: carry set and A = error if it couldn't be made
MakeTrue    lda   IsTrue
            bne   :ok
            lda   HaveScreen
            bne   :make
            lda   #errNotPicture
            sec
            rts
:make       jsr   ScreenToTrue
            bcs   :err
            jsr   TellDesk
:ok         clc
:err        rts

* TrueInfoOld: the earlier alert (kept for the test log's text).
TrueInfoOld stz   DescLen
            lda   #TxtTInfo
            jsr   AddText
            lda   TrueW
            jsr   AddDec
            lda   #TxtBy
            jsr   AddText
            lda   TrueH
            jsr   AddDec
            lda   #TxtPixels
            jsr   AddText
            lda   #TxtInfoEnd
            jsr   AddText
InfoAlert   pha
            pea   0
            PushLong 0
            PushLong DescBuf
            Tool  _AlertWindow
            pla
            rts

* DoRemap: remaps, then shows the result.
DoRemap     lda   HaveScreen
            bne   :go
            Tool  _SysBeep
            rts
:go         jsr   SourceTrue            ; what to remap from
            bcs   :err
            jsr   SetRemapDP
            jsl   RemapDialog           ; A = 0: remap, 2: quick remap
            bcs   :cancel
            jsr   RunRemap
            bcs   :err
            jsr   PictureMenus
            jmp   AfterRemap            ; (viewed full screen)
:err        jmp   Problem
:cancel     rts

* RunRemap: remaps (A = 1: with the default options, fitted, as Open does;
* 0: as the Remap dialog set them; 2: quick remap) from the true colour picture.
*   out: carry clear, or carry set and A = error
RunRemap    pha
            jsr   SourceTrue
            bcc   :src
            plx
            rts
:src        jsr   SetRemapDP
            pla
            jsl   RemapRun
            bcs   :err
            lda   rout_w                ; the screen picture made
            sta   PicW
            lda   rout_h
            sta   PicH
            lda   rout640
            sta   Pic640
            lda   #1                    ; (a new screen image: no selection)
            jsl   DeskSelClear
            clc
:err        rts

* SourceTrue: the true colour picture to remap: the one loaded, or else
* the screen picture made into one (and kept, for remapping again).
SourceTrue  lda   IsTrue
            bne   :have
            jmp   ScreenToTrue
:have       clc
            rts

* StorePal: Screen > Store palette: the screen picture's colours are kept
* for Remap's Stored palette choice.
StorePal    lda   HaveScreen
            beq   :none
            jsr   DeskDP
            jsl   RemapStore
:none       rts

*-------------------------------------------------------------
* The desktop background
*-------------------------------------------------------------

* UseDesk: Screen > Use as desktop background: the screen picture's bytes
* become the desktop's picture through a Window Manager desktop message, so
* they show in the desktop's own 640 mode colours.
UseDesk     lda   HaveScreen
            beq   :beep
            jsr   DeskMsg               ; (n1: its handle)
            bcc   :made
:beep       Tool  _SysBeep
            rts
:made       pea   1                     ; MessageCenter: add it (a copy is kept)
            pea   2                     ; (type 2: the desktop)
            PushLongAt n1
            Tool  _MessageCenter
            PushLongAt n1
            Tool  _DisposeHandle
            jsr   NewDesk
            jmp   CheckDesk

* DeskMsg: the desktop message for the screen picture in a new handle (n1,
* p0 its data): the light blue dither, and the picture's lines of up to 160
* bytes centred across (a wider one cut on the right); 200 lines or more from
* the top, 187 or more at the bottom, fewer centred below the menu bar.
* Carry set if there is no memory for it.
DeskMsg     lda   #$7D08                ; 8 bytes, then 200 lines of 160 bytes
            sta   n0
            stz   n0+2
            jsr   NewBuffer
            bcc   :jx9
            jmp   :out
:jx9
            ldy   #0
            lda   #$DDDD
:fill       sta   [p0],y
            iny
            iny
            cpy   #$7D08
            bcc   :fill
            ldy   #6                    ; a picture follows
            lda   #1
            sta   [p0],y
            lda   PicW                  ; bytes a line: 2 or 4 pixels a byte
            ldx   Pic640
            beq   :w320
            clc
            adc   #3
            lsr
            lsr
            bra   :bytes
:w320       inc
            lsr
:bytes      stz   t0                    ; t0: the first byte across
            cmp   #160
            bcc   :narrow
            lda   #160
            bra   :across
:narrow     sta   t1
            lda   #160
            sec
            sbc   t1
            lsr
            sta   t0
            lda   t1
:across     sta   t1                    ; t1: bytes a line
            lda   PicH                  ; t2: lines, t3: the first line
            stz   t3
            cmp   #200
            bcc   :short
            lda   #200
            bra   :lines
:short      cmp   #187
            bcc   :centre
            sta   t2
            lda   #200
            sec
            sbc   t2
            sta   t3
            lda   t2
            bra   :lines
:centre     sta   t2
            lda   #187
            sec
            sbc   t2
            lsr
            clc
            adc   #13
            sta   t3
            lda   t2
:lines      sta   t2
            ora   t1
            beq   :done
            lda   t3                    ; p1: where the first line goes
            asl
            asl
            asl
            asl
            asl
            sta   u0                    ; * 32
            asl
            asl                         ; * 128
            clc
            adc   u0
            adc   #8
            adc   t0
            adc   p0
            sta   p1
            lda   p0+2
            sta   p1+2
            lda   ScreenP               ; q0: the picture's line
            sta   q0
            lda   ScreenP+2
            sta   q0+2
:row        sep   #$20
            mx    %10
            ldy   #0
:b          lda   [q0],y
            sta   [p1],y
            iny
            cpy   t1
            bcc   :b
            rep   #$21                  ; (carry clear)
            mx    %00
            lda   q0
            adc   #160
            sta   q0
            lda   p1
            clc
            adc   #160
            sta   p1
            dec   t2
            bne   :row
:done       clc
:out        rts

* NewDesk: the Window Manager takes the new desktop message and draws the
* desktop again (SetDeskPat with the pattern it has).
NewDesk     pha
            pha
            pea   8                     ; CheckForNewDeskMsg
            PushLong 0
            Tool  _Desktop
            pla
            pla
            pha                         ; SetDeskPat(GetDeskPat)
            pha
            pea   5
            pha
            pha
            pea   4
            PushLong 0
            Tool  _Desktop
            Tool  _Desktop
            pla
            pla
            rts

* RevertDesk: Extras > Revert to normal desktop: the light blue pattern
* again, and no desktop message.
RevertDesk  lda   #40                   ; a pattern message
            sta   n0
            stz   n0+2
            jsr   NewBuffer
            bcs   :out
            ldy   #0
            lda   #$DDDD
:fill       sta   [p0],y
            iny
            iny
            cpy   #40
            bcc   :fill
            ldy   #6                    ; a pattern follows
            lda   #0
            sta   [p0],y
            pea   1
            pea   2
            PushLongAt n1
            Tool  _MessageCenter
            PushLongAt n1
            Tool  _DisposeHandle
            pha
            pha
            pea   8                     ; CheckForNewDeskMsg
            PushLong 0
            Tool  _Desktop
            pla
            pla
            pea   3                     ; and the message goes away
            pea   2
            PushLong 0
            Tool  _MessageCenter
            jsr   NewDesk
:out        jmp   CheckDesk

* CheckDesk: Revert to normal desktop is there to choose while some program
* has left a desktop message.
CheckDesk   pha                         ; an empty handle to get it into
            pha
            PushLong 0
            lda   UserID
            pha
            pea   0
            PushLong 0
            Tool  _NewHandle
            plx
            ply
            bcs   :no
            phy                         ; (for DisposeHandle)
            phx
            pea   2                     ; MessageCenter: get it
            pea   2
            phy
            phx
            Tool  _MessageCenter
            sta   t0
            Tool  _DisposeHandle
            lda   t0
            beq   :yes
            cmp   #$0201                ; (there, but no memory for a copy)
            beq   :yes
:no         pea   iRevert
            Tool  _DisableMItem
            rts
:yes        pea   iRevert
            Tool  _EnableMItem
            rts

* ToTrue: Screen > Convert to true color: the screen picture becomes the
* true colour picture (in place of any other), ready for the filters.
ToTrue      lda   HaveScreen
            bne   :have
            Tool  _SysBeep
            rts
:have       jsr   ScreenToTrue
            bcc   :ok
            jmp   Problem
:ok         lda   #2
            sta   ShowType
            jmp   PictureMenus

* DoFilter: True color filter A from the menu: Blur, Sharpen and Find edges
* ask for a factor first (the last one used for each, 50 at first); the
* message shows while it works; then the Remap dialog, to see the result.
DoFilter    sta   FxKind
            jsr   MakeTrue
            bcc   :true
            jmp   Problem
:true       ldx   #50
            lda   FxKind
            cmp   #fxBlur
            beq   :ask
            cmp   #fxSharpen
            beq   :ask
            cmp   #fxEdges
            bne   :run
:ask        lda   #50                   ; (always 50 at first, as SuperConvert)
            jsl   FilterAsk
            bcc   :got
            rts
:got        tax
:run        stx   FxFactor
            lda   FxKind
            jsl   FilterBusy
            lda   FxKind
            ldx   FxFactor
            jsr   RunFilter
            php
            pha
            jsl   FilterIdle
            pla
            plp
            bcc   :done
            jmp   Problem
:done       lda   #2                    ; the window shows the result, then
            sta   ShowType              ; the Remap dialog (as SuperConvert)
            jsr   PictureMenus
            jmp   DoRemap

FxKind      dw    0
FxFactor    dw    0

* DoMono: the monochrome commands (A: the item). Convert to monochrome
* (Screen, True color), Monochrome image info, Convert to screen / true
* color, Negative image; each with SuperConvert's dialog where it has one.
DoMono      cmp   #iScrMono
            beq   :fromScr
            cmp   #iTrueMono
            beq   :fromTrue
            cmp   #iMonoInfo
            beq   :info
            cmp   #iMonoScr
            beq   :toScr
            cmp   #iMonoTrue
            beq   :toTrue
            cmp   #iMonoNeg
            beq   :neg
            rts
:fromScr    lda   HaveScreen
            bne   :fs
            Tool  _SysBeep
            rts
:fs         lda   #0
            bra   :to
:fromTrue   jsr   MakeTrue
            bcc   :ft
            jmp   Problem
:ft         lda   #2
:to         pha
            jsr   DeskDP
            pla
            jsl   MonoToDlg
            bcc   :made
            cmp   #$FFFF                ; (Cancel)
            beq   :out
            jmp   Problem
:made       lda   #3                    ; (a new image: no selection)
            jsl   DeskSelClear
:shown      lda   #3
            sta   ShowType
            jmp   PictureMenus
:info       jsr   MakeMono
            bcs   :out
            jsr   DeskDP
            jsl   MonoInfoAlert
:out        rts
:neg        jsr   MakeMono
            bcs   :out
            jsr   DeskDP
            jsl   MonoNeg
            bra   :shown
:toScr      lda   #0
            bra   :from
:toTrue     lda   #2
:from       sta   t0
            lda   MonoBlk
            bne   :have
            Tool  _SysBeep
            rts
:have       jsr   DeskDP
            lda   t0
            jsl   MonoFromDlg
            bcc   :made2
            cmp   #$FFFF
            beq   :out
            jmp   Problem
:made2      lda   t0
            jsr   AfterMonoOut
            lda   t0                    ; the window shows what was made
            lsr
            inc
            sta   ShowType
            jmp   PictureMenus

* MakeMono: a monochrome image (with the Convert to monochrome dialog
* from the true colour or screen image if there is none yet).
*   out: carry set if there is none (cancelled, or no picture)
MakeMono    lda   MonoBlk
            bne   :ok
            lda   IsTrue
            beq   :scr
            jsr   DeskDP
            lda   #2
            bra   :ask
:scr        lda   HaveScreen
            beq   :none
            jsr   DeskDP
            lda   #0
:ask        jsl   MonoToDlg
            bcs   :none
            lda   #3
            jsl   DeskSelClear
:ok         clc
            rts
:none       sec
            rts

* DoView: view A (0 full screen, 1 half size, 2 X4 magnified, 3 the true
* colour approximation).
DoView      sta   t0
            cmp   #3
            bne   :screen
            jsr   MakeTrue              ; (the approximation: a true colour image)
            bcc   :go
            jmp   Problem
:screen     lda   HaveScreen
            bne   :go
            Tool  _SysBeep
            rts
:go         jsr   DeskDP
            lda   t0
            jsl   ViewRun
            bcc   :ok
            jmp   Problem
:ok         rts

* DoTurnMenu: True color > Rotate/flip image: SuperConvert's dialog (only
* flips for pictures 801 wide or 655 high and more), then as a filter.
DoTurnMenu  jsr   MakeTrue
            bcc   :true
            jmp   Problem
:true       jsr   SetRemapDP
            lda   #0
            ldx   TrueW
            cpx   #801
            bcs   :big
            ldx   TrueH
            cpx   #655
            bcc   :ask
:big        lda   #1
:ask        jsl   FilterTurnAsk
            and   #7
            bne   :turn
            rts
:turn       pha
            Tool  _WaitCursor
            pla
            jsr   RunTurn
            php
            pha
            Tool  _InitCursor
            pla
            plp
            bcc   :done
            jmp   Problem
:done       pea   $8005                 ; (SuperConvert's beep, on System 6)
            Tool  _SysBeep2
            lda   #2
            sta   ShowType
            jsr   PictureMenus
            jmp   DoRemap

* RunFilter: True color filter A (fxEqualize ...) with factor X on the true
* colour picture.   out: carry clear, or carry set and A = error
RunFilter   sta   t0
            stx   t1
            lda   IsTrue
            bne   :have
            lda   #errNotPicture
            sec
            rts
:have       jsr   SetRemapDP
            lda   t0
            ldx   t1
            jsl   FilterRun
            bcs   :err
            inc   TrueGen               ; (a different picture now)
            lda   #2
            jsl   DeskSelClear
            jsr   TellDesk
            clc
:err        rts

* RunTurn: rotate/flip the true colour picture (A: 1 mirror, 2 flip,
* 4 turn; together in that order).   out: carry clear, or carry set and
* A = error
RunTurn     sta   t0
            lda   IsTrue
            bne   :have
            lda   #errNotPicture
            sec
            rts
:have       jsr   SetRemapDP
            lda   t0
            jsl   FilterTurn
            bcs   :err
            lda   t0
            and   #4
            beq   :same
            PushLongAt TrueHnd          ; turned: a new block, the other way round
            Tool  _DisposeHandle
            lda   fhnd
            sta   TrueHnd
            lda   fhnd+2
            sta   TrueHnd+2
            lda   tp
            sta   TrueP
            lda   tp+2
            sta   TrueP+2
            lda   TrueW
            ldx   TrueH
            sta   TrueH
            stx   TrueW
            txa
            asl
            clc
            adc   TrueW
            sta   TrueStride
            stz   TrueTall
:same       inc   TrueGen
            lda   #2
            jsl   DeskSelClear
            jsr   TellDesk
            clc
:err        rts

* SetRemapDP: the true colour picture and the screen, for the Remap segment.
SetRemapDP  lda   TrueP
            sta   tp
            lda   TrueP+2
            sta   tp+2
            lda   TrueStride
            sta   tstride
            lda   TrueW
            sta   rw
            lda   TrueH
            sta   rh
            lda   TrueTall
            sta   rtall
            lda   ScreenP
            sta   scrp
            lda   ScreenP+2
            sta   scrp+2
            lda   UserID
            sta   uid
            lda   TrueGen
            sta   tgen
            rts

* LoadPath: loads the picture file at PathPtr.
*   out: carry clear, or carry set and A = error ($FFFF: not a picture)
LoadPath    jsr   ReadFile
            bcs   :err
            jsr   DecodeFile
            php
            sta   t2
            stz   ForceFmt              ; a chosen format is for one file
            jsr   FreeFile
            plp
            bcc   :ok
            lda   t2
            bne   :code
            lda   #errNotPicture
:code       sec
:err        rts
:ok         lda   t2
            sta   Format
            lda   FileType              ; (its type, for a Finder icon's criteria)
            sta   PicType
            lda   FileAux
            sta   PicAux
            lda   t2                    ; a Works of Art page: monochrome only
            cmp   #fmtWOA
            bne   :screen
            jmp   LoadMono
:screen     lda   #1
            sta   HaveScreen
            lda   IsTrue                ; true colour: show it fitted to the screen
            beq   :screenSize
            lda   #1
            jsr   RunRemap
            bcc   :named
            jmp   :err2
:screenSize lda   pw                    ; a picture smaller than the screen says its size
            beq   :whole
            sta   PicW
            lda   ph
            sta   PicH
            lda   p640
            sta   Pic640
            bra   :named
:whole      jsr   CountWide             ; else the whole screen, in the mode most lines have
            ldx   #0
            cmp   #101
            bcc   :mode
            inx
:mode       stx   Pic640
            lda   #320
            cpx   #0
            beq   :wide
            asl
:wide       sta   PicW
            lda   #200
            sta   PicH
:named      lda   #0                    ; (new images: no selections)
            jsl   DeskSelClear
            jsr   NameFromPath
            jsr   PictureMenus
:done       clc
            rts
:err2       sec                         ; (A = the Remap's error)
            rts

* SaveAs: saves the picture to PathPtr in save format A (1 $C1, 2 Apple
* Preferred, 3 PackBytes here; the others in the Save segment).
SaveAs      cmp   #4
            bcs   :seg
            jmp   SavePath
:seg        sta   SvCode
            jsr   SetRemapDP            ; (the true colour image too: TIFF)
            stz   dhave
            lda   IsTrue
            beq   :canvas
            lda   #2
            sta   dhave
:canvas     jsr   SaveCanvas            ; (the picture to save, as chosen)
            stz   SvRead
            stz   SvMsg
            lda   SvCode
            cmp   #13                   ; the desktop INIT: its message (fp)
            bne   :notInit
            jsr   DeskMsg
            bcc   :msg
            lda   #$0201
            rts
:msg        inc   SvMsg
            lda   n1
            sta   SvMsgH
            lda   n1+2
            sta   SvMsgH+2
            lda   p0
            sta   fp
            lda   p0+2
            sta   fp+2
            bra   :call
:notInit    cmp   #6                    ; adding an icon: the file as it is
            bne   :call
            jsr   ReadFile
            bcc   :read
            rts
:read       inc   SvRead
            lda   FileP
            sta   fp
            lda   FileP+2
            sta   fp+2
            lda   FileLen
            sta   flen
            lda   FileLen+2
            sta   flen+2
:call       lda   PathPtr
            sta   pathp
            lda   PathPtr+2
            sta   pathp+2
            lda   UserID
            sta   uid
            lda   PicType               ; (the loaded file's type and name, for
            sta   ftype                 ; a Finder icon's criteria)
            lda   PicAux
            sta   faux
            lda   #PicName
            sta   dname
            lda   #^PicName
            sta   dname+2
            lda   SvCode
            jsl   SaveFormat
            php
            pha
            lda   SvMsg                 ; (the desktop message: gone)
            beq   :noMsg
            PushLongAt SvMsgH
            Tool  _DisposeHandle
:noMsg      lda   SvRead
            beq   :noFree
            jsr   FreeFile
:noFree     pla
            plp
            bcs   :done
            lda   outl                  ; something to write?
            ora   outl+2
            bne   :out
            clc
            bra   :done
:out
            lda   otype
            sta   WType
            lda   oaux
            sta   WAux
            lda   oaux+2
            sta   WAux+2
            lda   outp
            sta   WData
            lda   outp+2
            sta   WData+2
            lda   outl
            sta   WLen
            lda   outl+2
            sta   WLen+2
            jsr   WriteFile
            php
            pha
            ldx   #OutHand
            lda   ohnd
            sta   OutHand
            lda   ohnd+2
            sta   OutHand+2
            jsr   FreeHandleAt
            pla
            plp
:done       php                         ; the format's own window gone (GIF:
            pha                         ; "GIF save completed" first)
            lda   #0
            rol
            jsl   SaveDone
            pla
            plp
            rts

SvCode      dw    0
SvRead      dw    0
SvMsg       dw    0
SvMsgH      adrl  0
OutHand     adrl  0

* SavePath: saves the picture to PathPtr in format A.
SavePath    pha                         ; (the picture to save, as chosen)
            jsr   SaveCanvas
            pla
            cmp   #fmtAPF
            beq   :apf
            cmp   #fmtPacked
            beq   :packed
            jsr   BuildC1
            bra   :write
:apf        jsr   BuildAPF
            bcs   :err
            bra   :write
:packed     jsr   BuildPacked
            bcs   :err
:write      jsr   WriteFile
            php
            pha
            jsr   FreeOut
            pla
            plp
:err        rts

* LoadMono: a page loaded as a monochrome image only (Works of Art): it is
* shown, named after the page, with 320 sized pixels, and Convert to
* screen offers Square, 1:1, 320 mode, as the original sets them.
LoadMono    stz   HaveScreen
            lda   #PicName
            sta   dname
            lda   #^PicName
            sta   dname+2
            jsl   WoaName
            ldx   #0                    ; (the save dialog's name too)
:c          lda   PicName,x
            and   #$00FF
            beq   :named
            sep   #$20
            mx    %10
            sta   NameGS+2,x
            rep   #$20
            mx    %00
            inx
            bra   :c
:named      stx   NameGS
            lda   #3
            ldx   #0
            jsl   DeskPixSize
            jsl   MonoFromSet
            lda   #0                    ; (new images: no selections)
            jsl   DeskSelClear
            lda   #3
            sta   ShowType
            jsr   PictureMenus
            clc
            rts

* ScreenFirst: A = a menu item: a Screen menu command with no screen
* image gets one first (MakeScreen), as the original's do.
*   out: carry set if there is none; A kept
ScreenFirst pha
            cmp   #270                  ; (View full screen, and 290-297)
            beq   :scr
            cmp   #290
            bcc   :ok
            cmp   #298
            bcs   :ok
:scr        lda   HaveScreen
            bne   :ok
            lda   HaveScreen            ; (no picture at all: nothing to do)
            ora   IsTrue
            ora   MonoBlk
            beq   :ok
            jsr   MakeScreen
            bcc   :ok
            pla
            sec
            rts
:ok         pla
            clc
            rts

* DoPrint: File > Print (normal)...: the screen image (made first if
* need be) on the printer, at full size (Print.s).
DoPrint     lda   HaveScreen
            bne   :have
            jsr   MakeScreen
            bcc   :have
            rts
:have       lda   ScreenP
            sta   scrp
            lda   ScreenP+2
            sta   scrp+2
            lda   PicW
            sta   pw
            lda   PicH
            sta   ph
            lda   UserID
            sta   uid
            jsl   PrintPic
            rts

* MakeScreen: no screen image for Save conversion or a Screen menu
* command: one made first, as the original does: from the true colour
* image by Remap (its dialog), else from the monochrome image by Convert
* to screen (its window).
*   out: carry set if there is none (cancelled, or an error shown)
MakeScreen  lda   IsTrue
            beq   :mono
            jsr   SetRemapDP
            jsl   RemapDialog           ; A = 0: remap, 2: quick remap
            bcs   :no
            jsr   RunRemap
            bcs   :err
            lda   #1
            sta   HaveScreen
            jsr   PictureMenus
            clc
            rts
:mono       lda   MonoBlk
            bne   :conv
            Tool  _SysBeep
            sec
            rts
:conv       jsr   DeskDP
            lda   #0
            jsl   MonoFromDlg
            bcc   :made
            cmp   #$FFFF                ; (Cancel)
            beq   :no
:err        jsr   Problem
:no         sec
            rts
:made       lda   #0
            jsr   AfterMonoOut
            jsr   PictureMenus
            clc
            rts

* NameFromPath: the last part of the path at PathPtr becomes the
* picture's name (NameGS) and the window title.
NameFromPath lda  PathPtr
            sta   p0
            lda   PathPtr+2
            sta   p0+2
            lda   [p0]                  ; t0 = index just past the last character
            clc
            adc   #2
            sta   t0
            ldy   #2                    ; t1 = start of the last part
            sty   t1
:scan       cpy   t0
            bcs   :found
            lda   [p0],y
            and   #$00FF
            iny
            cmp   #':'
            beq   :sep
            cmp   #'/'
            bne   :scan
:sep        sty   t1
            bra   :scan
:found      ldx   #0                    ; copy at most 24 characters
            ldy   t1
:copy       cpy   t0
            bcs   :end
            cpx   #24
            bcs   :end
            lda   [p0],y
            sep   #$20
            mx    %10
            sta   NameGS+2,x
            sta   PicName,x
            rep   #$20
            mx    %00
            iny
            inx
            bra   :copy
:end        stx   NameGS
            stz   PicName,x             ; (and as a C string, for the window)
            rts

* AddText: appends the C string at A to DescBuf.
AddText     sta   t0
            ldy   #0
            ldx   DescLen
            sep   #$20
            mx    %10
:char       lda   (t0),y
            sta   DescBuf,x
            beq   :end
            iny
            inx
            bra   :char
:end        rep   #$20
            mx    %00
            stx   DescLen
            rts

* AddDec: appends A in decimal to DescBuf.
AddDec      ldx   #0                    ; digits, last first, on the stack
:digit      sta   ProdLo
            stz   ProdHi
            phx
            lda   #10
            jsr   Div32
            plx
            lda   Rem
            clc
            adc   #'0'
            pha
            inx
            lda   QuotLo
            bne   :digit
            ldy   DescLen
:out        pla
            sep   #$20
            mx    %10
            sta   DescBuf,y
            rep   #$20
            mx    %00
            iny
            dex
            bne   :out
            lda   #0
            sta   DescBuf,y
            sty   DescLen
            rts

*-------------------------------------------------------------
* Data
*-------------------------------------------------------------
UserID      dw    0
SSRef       adrl  0
QuitFlag    dw    0
PicName     ds    26                    ; the picture's name (C string)
PicType     dw    0                     ; the loaded file's type, aux type
PicAux      dw    0
ScreenP     adrl  0                     ; the picture ($C1 layout)
SavedP      adrl  0                     ; the desktop, while the picture is shown
RemapP      adrl  0                     ; where Remap builds its result
HaveScreen  dw    0
PicW        dw    320                   ; the picture's own size and mode
PicH        dw    200
Pic640      dw    0
Format      dw    0
SaveFmt     dw    0

QuitParms   dw    2                     ; pCount
            adrl  0                     ; no next program: back to the selector
            dw    0                     ; flags

* Tools to load. Versions are the minimum needed.
StartStop   dw    0                     ; flags
            dw    $C080                 ; video mode: 640 pixels
            dw    0                     ; resource file
            adrl  0                     ; direct page handle (filled in)
            dw    17                    ; number of tools
            dw    3,$0300               ; Miscellaneous Tools
            dw    4,$0307               ; QuickDraw II
            dw    5,$0302               ; Desk Manager
            dw    6,$0300               ; Event Manager
            dw    11,$0200              ; Integer Math
            dw    14,$0301              ; Window Manager
            dw    15,$0301              ; Menu Manager
            dw    16,$0301              ; Control Manager
            dw    18,$0201              ; QuickDraw II Auxiliary
            dw    20,$0300              ; LineEdit
            dw    21,$0300              ; Dialog Manager
            dw    22,$0101              ; Scrap Manager
            dw    23,$0301              ; Standard File
            dw    27,$0300              ; Font Manager
            dw    28,$0300              ; List Manager
            dw    30,$0100              ; Resource Manager
            dw    34,$0100              ; TextEdit (System info report)

* Extended task record for TaskMaster.
EventRec    dw    0                     ; what
            adrl  0                     ; message
            adrl  0                     ; when
            dw    0,0                   ; where
            dw    0                     ; modifiers
            adrl  0                     ; task data
            adrl  $001FFFFF             ; task mask: everything
            adrl  0                     ; last click tick
            dw    0                     ; click count
            adrl  0                     ; task data 2
            adrl  0                     ; task data 3
            adrl  0                     ; task data 4
            dw    0,0                   ; last click point
TaskData    =     16                    ; offset of task data in the record
ClickCount  =     28                    ; (2: a double click)
TaskData2   =     30                    ; (the control clicked)

* Standard File reply (SFReplyRec2).
Reply       dw    0                     ; good
            dw    0                     ; file type
            adrl  0                     ; aux type
            dw    3                     ; name: return a handle
            adrl  0
            dw    3                     ; path: return a handle
            adrl  0

* Menus, in Menu Manager text form, as SuperConvert's (D: dimmed, V: a line
* under the item, *: Command key). Lines end with a zero byte.
AppleMenu   asc   '>>@\XN1',00
            asc   '--About MegaconvertGS...\N257',00
            asc   '--Help!\N265*?/',00
            asc   '--Menu item help\N266',00
            asc   '--Preferences...\N267V',00
            asc   '.',00
FileMenu    asc   '>>  File  \N2',00
            asc   '--Load & convert...\N280*Ll',00
            asc   '--Load any picture...\N259*Oo',00
            asc   '--Re-convert last file\N281D*Rr',00
            asc   '--Load next\N282D*Nn',00
            asc   '--Cancel remaining files\N283D*Dd',00
            asc   '--Save conversion...\N260D*Ss',00
            asc   '--Exchange load/save paths\N285V',00
            asc   '--Print (normal)...\N286D',00
            asc   '--Print (enhanced)...\N287D*Pp',00
            asc   '--Print alignment page...\N288V',00
            asc   '--Examine file...\N289V',00
            asc   '--Quit\N256*Qq',00
            asc   '.',00
EditMenu    asc   '>>  Edit  \N3',00
            asc   '--Undo\N250DV*Zz',00
            asc   '--Cut\N251*Xx',00
            asc   '--Copy\N252*Cc',00
            asc   '--Paste\N253*Vv',00
            asc   '--Clear\N254DV',00
            asc   '--Close\N255',00
            asc   '.',00
ScreenMenu  asc   '>>  Screen  \N5D',00
            asc   '--Screen image info...\N290*Ii',00
            asc   '--Convert to true color...\N291',00
            asc   '--Convert to monochrome...\N292V',00
            asc   '--View full screen\N270*Ff',00
            asc   '--View half size\N293*Hh',00
            asc   '--View X4 magnified\N294V*44',00
            asc   '--Store palette\N295',00
            asc   '--Use as desktop background\N296',00
            asc   '--Oscilloscope Art\N297',00
            asc   '.',00
TrueMenu    asc   '>>  True color  \N9D',00
            asc   '--True color image info...\N300*Tt',00
            asc   '--Convert to screen (Remap)...\N271*Mm',00
            asc   '--Convert to monochrome...\N301V',00
            asc   '--View approximation\N302V*Aa',00
            asc   '--Rotate/flip image...\N303',00
            asc   '--Histogram equalization...\N304D',00
            asc   '--Median filter\N305D',00
            asc   '--Sigma filter\N306D',00
            asc   '--Emboss image\N307D',00
            asc   '--Blur image...\N308D',00
            asc   '--Sharpen image...\N309D',00
            asc   '--Solarize image\N310D',00
            asc   '--Find edges...\N311D',00
            asc   '--Increase contrast\N312D',00
            asc   '--Decrease contrast\N313D',00
            asc   '.',00
MonoMenu    asc   '>>  Monochrome  \N6D',00
            asc   '--Monochrome image info...\N320D',00
            asc   '--Convert to screen...\N321D',00
            asc   '--Convert to true color...\N322DV',00
            asc   '--Negative image\N323',00
            asc   '.',00
WindowsMenu asc   '>>  Windows  \N4',00
            asc   '--Normal positions\N330V',00
            asc   '--Load formats\N331',00
            asc   '--Save formats\N332',00
            asc   '--Current image\N333D',00
            asc   '.',00
ExtrasMenu  asc   '>>  Extras  \N8',00
            asc   '--Available font list\N340',00
            asc   '--More available fonts\N341D',00
            asc   '--Font key chart...\N342',00
            asc   '--Print banner...\N343D',00
            asc   '--Revert to normal desktop\N344D',00
            asc   '--System info report...\N345',00
            asc   '.',00

AboutText   asc   '93/MegaconvertGS 0.4',0D,'An image converter for the Apple IIgs.',0D,'Walter Tengler, 2026',0D,0D
            asc   'A successor to SuperConvert by Jason Harper and Ian Brumby, '
            asc   'published with the kind permission of Ian Brumby./^#0',00
TxtProblem  asc   '52/The file could not be read or saved (error ',00
TxtProblemEnd asc ')./^#0',00
ErrCodes    dw    errNotPicture,errUnsupported,errTooBig,errCorrupt,$0201
            dw    errPW640,errIcon640,errIconBig,errIconRes,errNotImpl,errCopy,errFont,0
ErrTexts    da    MsgNotPic,MsgUnsup,MsgBig,MsgCorrupt,MsgMemory
            da    MsgPW640,MsgIcon640,MsgIconBig,MsgIconRes,MsgNotImpl,MsgCopy,MsgFont
MsgNotPic   asc   '52/This file is not a picture MegaconvertGS can read./^#0',00
MsgUnsup    asc   '52/This kind of picture can',27,'t be read yet./^#0',00
MsgBig      asc   '52/The picture is too large (at most 4096 x 4096 pixels, JPEG 2048 wide)./^#0',00
MsgCorrupt  asc   '52/The picture file is damaged./^#0',00
MsgPW640    asc   '52/PaintWorks pictures are 320 mode only./^#0',00
MsgIcon640  asc   '52/Finder icons are 640 mode pictures. Open or make a small 640 mode one first./^#0',00
MsgIconBig  asc   '52/A Finder icon can be at most 160 x 50 (80 x 25 is usual)./^#0',00
MsgIconRes  asc   '52/An icon resource can be at most a quarter of the screen./^#0',00
MsgMemory   asc   '52/There isn',27,'t enough memory for this picture./^#0',00
MsgNotImpl  asc   '52/This format has not been implemented yet./^#0',00
MsgCopy     asc   '52/I am having a hard time cutting or copying to the Clipboard./^#0',00
MsgFont     asc   '52/I am having a hard time trying to display a font. Font appears to be damaged./^#0',00
OpenPrompt  str   'Select file to load and convert:'
SavePrompt  str   'Name to save as:'
AddPrompt   str   'Select file to add picture to:'

* Short names of the formats, for the test commands.
FmtIds      da    0,IdC1,IdAPF,IdPacked,IdPW,IdBMP,IdGIF,IdPNG,IdJPEG
            da    IdHGR,IdHGRBW,IdDHR,IdDHRBW,IdPSBW,IdPSGS,IdCGT,IdIcon,IdTScan
            da    IdTDM40,IdTDM80,IdDG,IdDG3200,IdAST,IdCEyes,Id3200,Id3200C,IdPWGold
            da    IdO27,IdO28,IdO29,IdO30,IdO31,IdO32,IdO33,IdO34
            da    IdO35,IdO36,IdO37,IdO38,IdO39,IdO40,IdO41,IdO42
            da    IdO43,IdO44,IdO45,IdO46,IdO47,IdO48,IdO49,IdO50
            da    IdNone,IdWOA,IdNone,IdNone,IdTGA,IdPICT   ; (51: none)
            da    IdZX,IdMS2,IdMS5,IdMS7,IdMS8,IdArtSt,IdAAS,IdCPC0,IdCPC1,IdCPC2
IdNone      asc   '-',00                ; (53, 54: the Babelfish imports)
IdTGA       asc   'tga',00
IdPICT      asc   'pict',00
IdZX        asc   'zx',00
IdMS2       asc   'msx2',00
IdMS5       asc   'msx5',00
IdMS7       asc   'msx7',00
IdMS8       asc   'msx8',00
IdArtSt     asc   'artst',00
IdAAS       asc   'aas',00
IdCPC0      asc   'cpc0',00
IdCPC1      asc   'cpc1',00
IdCPC2      asc   'cpc2',00
IdWOA       asc   'woa',00
IdC1        asc   'c1',00
IdAPF       asc   'apf',00
IdPacked    asc   'packed',00
IdPW        asc   'pw',00
IdBMP       asc   'bmp',00
IdGIF       asc   'gif',00
IdPNG       asc   'png',00
IdJPEG      asc   'jpeg',00
IdHGR       asc   'hgr',00
IdHGRBW     asc   'hgrbw',00
IdDHR       asc   'dhr',00
IdDHRBW     asc   'dhrbw',00
IdPSBW      asc   'psbw',00
IdPSGS      asc   'psgs',00
IdCGT       asc   'cgt',00
IdIcon      asc   'icon',00
IdTScan     asc   'tscan',00
IdTDM40     asc   'tdm40',00
IdTDM80     asc   'tdm80',00
IdDG        asc   'drm',00
IdDG3200    asc   'drm3200',00
IdAST       asc   'ast',00
IdCEyes     asc   'ceyes',00
Id3200      asc   '3200',00
Id3200C     asc   '3200c',00
IdPWGold    asc   'pwgold',00
IdO27   asc   'degas',00
IdO28   asc   'degaselite',00
IdO29   asc   'neo',00
IdO30   asc   'tiny',00
IdO31   asc   'spu',00
IdO32   asc   'spc',00
IdO33   asc   'iff',00
IdO34   asc   'doodle',00
IdO35   asc   'koala',00
IdO36   asc   'c64ps',00
IdO37   asc   'mpnt640',00
IdO38   asc   'mpnt320',00
IdO39   asc   'mpntmono',00
IdO40   asc   'macsm',00
IdO41   asc   'gem',00
IdO42   asc   'pcx',00
IdO43   asc   'fliaway',00
IdO44   asc   'sun',00
IdO45   asc   'sgi',00
IdO46   asc   'pnm',00
IdO47   asc   'rle',00
IdO48   asc   'ipi',00
IdO49   asc   'qrt',00
IdO50   asc   'tiff',00

* Save formats, by number: short names for the test commands.
SaveIds     da    0,IdC1,IdAPF,IdPacked,IdPW,SiIcon,SiIconAdd,SiRIcon,SiRIconAdd,SiHex,IdGIF,IdPNG,IdO50
            da    SiDesk,SiNone,SiNone,IdBMP
SiDesk      asc   'desk',00
SiNone      asc   '-',00                ; (14, 15: the Babelfish exports)
SiIcon      asc   'icon',00
SiIconAdd   asc   'iconadd',00
SiRIcon     asc   'ricon',00
SiRIconAdd  asc   'riconadd',00
SiHex       asc   'hex',00

TxtIn320    asc   ' in 320 mode',00
TxtIn640    asc   ' in 640 mode',00
TxtSInfo    asc   '53/The screen image is ',00
TxtTInfo    asc   '53/The true color image is ',00
TxtBy       asc   ' by ',00
TxtPixels   asc   ' pixels',00
TxtInfoEnd  asc   './^#0',00
DescLen     dw    0
DescBuf     ds    96

* The picture's name, as a GS/OS string (default name for Save).
NameGS      dw    8
            asc   'Untitled'
            ds    24

* NewWindow parameter list (78 bytes).
            ds    24

            put   File.s
            put   Stream.s
            put   Formats.s
            put   True.s
            put   BMP.s
            put   GIF.s
            put   Inflate.s
            put   PNG.s
            put   JPEG.s
            put   Screen.s
            put   Test.s
            put   Actions.s
            put   LoadConv.s
            put   Prefs.s
