*-------------------------------------------------------------
* Test.s - test commands, read from *:MC.TEST at start-up
*
* One command per line:
*   LOAD path            load a picture
*   LOAD AS id path      load a picture as the format with that short name
*   SAVE AS id path      save in the save format with that short name (iconadd,
*                        riconadd: add to the file at path)
*   SAVE APF path        save as Apple Preferred
*   SAVE C1 path         save as an uncompressed screen
*   SAVE PACK path       save as a PackBytes screen
*   SAVE RGB path        save a true colour picture as raw RGB bytes
*   SHOT path            save the screen as it shows (windows, menus) as a $C1 file
*   REMAP                remap to 320 mode, calculated palette, pattern dither
*   REMAP QUICK          quick remap (a one-screen preview)
*   REMAP WITH m p a h v o  remap with mode m (0 320, 1 640, 2 640 dither, 3 multi),
*                        palette p (0 calculated, 1 default, 2 greys, 3 other,
*                        4 the picture's current),
*                        rendering a (0 closest, 1 pattern, 2 diffusion), scale
*                        steps h and v across and down (255: fit), other o
*   MEM                  log the free memory and the largest free block (hex)
*   IDLE n               run the event loop for n ticks (windows get drawn)
*   PICK t f             choose computer type t and its format f in Load formats
*   PICKSAVE s           choose format s in Save formats (all from 0)
*   CLICKS v h v h ...   clicks for the next Remap dialog to take before waiting for
*                        the mouse (in the dialog's own coordinates; up to 16)
*   CLICK x y [n]        n clicks (default 1; 2 is a double click) at x, y on the
*                        screen, through the event queue as the mouse makes them
*                        (n = 0: the pointer only moves there)
*   FILTER k [f]         True color filter k (0 histogram equalization, 1 median, 2
*                        sigma, 3 emboss, 4 blur, 5 sharpen, 6 solarize, 7 find
*                        edges, 8 and 9 increase and decrease contrast), factor f
*                        (default 50), without the menu's dialogs
*   TURN b               rotate/flip the true colour picture (bits: 1 mirror, 2 flip,
*                        4 turn)
*   SNAP, BACK           keep a copy of the true colour picture; put it back
*   MONO k h v m         a monochrome image from the screen (k 0) or true colour
*                        (k 2) image, h and v times larger, method m (1 error
*                        diffusion, 2 pattern dither, 3 50% threshold, 4 halftone)
*   MONOOUT k a s m sh   the monochrome image as a screen (k 0) or true colour (k 2)
*                        image: aspect a (1 square, 2 tall, 3 wide), scaling s (1, 2,
*                        4), 640 mode m, shrink sh (1 grayscale ... 4 line art on black)
*   MONONEG              the monochrome image negated
*   SAVE MONO path       save the monochrome image's bits (rows of (w + 7) / 8 bytes)
*   SAVE DESK path       save the desktop message (Use as desktop background), or log
*                        that there is none
*   PREFIX path          set prefix 8 (where a file dialog opens when no folder is kept)
*   PATHS                log the folders kept for the load and the save dialogs
*   IMAGES               log which images there are (screen, true colour, monochrome)
*   QUEUE t path         path added to the load queue as if chosen in Load & convert's
*                        dialog (t: its file type; $0F = 15 a folder: its pictures the
*                        chosen format's filter takes, with its folders')
*   QUEUED               log the paths waiting in the queue
*   NAME n               the name the save dialog offers (the picture's name)
*   BFNAME name          the Babelfish translator the next exports (SAVE AS bftrue,
*                        bfpix) use, by its name (empty: the first for the kind);
*                        LOAD AS bftrue, bfpix: the translator ranking the file best;
*                        BFLAST logs the last translator's name and the kind it sent
*   SYSINFO path         the System info report made and saved as a text file at path
*                        (without its window's buttons)
*   EXAMINE k s... path  File > Examine file... for the file at path, without the file
*                        dialog: steps s taken at null events (1-3 that mode, as its
*                        button; 5-8 a scroll bar part; 9 h v the pointer at h, v in
*                        the window; 1000 + n the thumb at n), then the window's state
*                        logged and the screen saved as *:MCOUT:EXAMx (x: the k-th
*                        letter, from A for 0)
*   WOAPAGE n           a Works of Art file's page n loaded without its window (0:
*                        the window)
*   BPARAM n v           battery RAM parameter n set to v (tests: the printer port's
*                        handshaking off, as MAME's null modem gives none)
*   PNGOPT l f text      the next PNG saved with the options window's choices: level
*                        l (1-9), filter f (0 None, 1 Auto), text as comments
*   TIFFOPT w m f text   the next TIFF saved with TIFF Save Options' answers: image w
*                        (0 screen, 1 true colour, 2 both), m 1 Motorola, f bit 0
*                        more compatible, bit 1 sizing left to the receiver; text
*   HELP label           the help window at that page; HELPLOG logs the page shown
*                        (its label, navigation labels, buttons, height)
*   A2OPT d f            the Apple II saves from now on: dithering d (0 error diffusion,
*                        1 pattern, 2 none), size f (0 the whole screen, 1 proportions),
*                        also the options window's last choices; A2OPT 3 0: the window again
*   HEXOPT s|t|e         Hex data's options: s before each line, t between its bytes,
*                        e after it (as typed into its options window)
*   SAVEDLG n [s a w]    Save conversion's dialogs (size, alignment, warnings) in tests
*                        too (1, 2) or not (0); 2: answered without showing them: size
*                        item s (2-6), alignment item a, warning answer w (1 Cancel
*                        save, 3 Save anyway); 3: answered the same, but the format's
*                        own window shows (Hex data's options, the GIF note, the
*                        Finder icon's criteria). SAVEWARN logs the last save's warnings
*                        (bits 0-4: 640 mode, mixed modes, colour tables, dithering, not
*                        the default 640 dither colours)
*   TIMING n             1: after each command a line "TIME $t": the ticks it took
*   SMOOTH n             640 mode screens become true colour Exact (0) or Smoothed (1)
*                        (the window's choice, which tests don't show; 2: the window)
*   PREF n v             Preferences' option n (0-7, in the order of its check boxes)
*                        set to v; PREFS logs the eight; PREFSAVE and PREFLOAD save
*                        them to and read them from 9:MCGS.Prefs
*   DESK k n ...         the image window's tools (ImgTools.s DeskTest): 1 n tool n
*                        (1 selection, 2 pixel peek), 2 n show type n, 3 z zoom z - 3,
*                        4 c v h v h ... a drag in content coordinates clicked c times,
*                        5 log the selection and the info bar's text, 6 n action n (3
*                        crop, 4 discard this type, 5 the others), 7 c m key c with
*                        modifiers m, 8 log the content's origin, 9 v h m log the
*                        pointer's shape code at v, h, 12 the content drawn again now
*   SAVE SCRAP path      the Clipboard's picture drawn into a screen (its line modes and
*                        colours from the screen image's buffer), saved as a $C1 file;
*                        the colour table scrap ($8002) is logged
*   MENU n               choose menu item n, as if from the menu bar (dialogs it opens
*                        wait for real keys, which the test types into the emulator)
*   SHOW                 put the picture on the screen and stop
*   QUIT                 leave the program
* Each command and its result are written to *:MC.LOG.
*-------------------------------------------------------------

RunTests    lda   #TestPath
            sta   PathPtr
            lda   #^TestPath
            sta   PathPtr+2
            jsr   ReadFile
            bcc   :have
            rts                         ; no test file: a normal start
:have       inc   TestMode
            lda   FileH                 ; keep the commands apart from FileH,
            sta   TestH                 ; which LOAD uses
            lda   FileH+2
            sta   TestH+2
            lda   FileP
            sta   TestP
            lda   FileP+2
            sta   TestP+2
            lda   FileLen
            sta   TestLen
            stz   FileH
            stz   FileH+2
            stz   TestPos
            stz   LogLen
            jsr   WriteLog              ; an empty log to add to
:next       lda   QuitFlag
            bne   :end
            jsr   GetLine
            bcs   :end
            pha                         ; (TIMING: the command's start)
            pha
            Tool  _TickCount
            pla
            sta   CmdTick
            pla
            jsr   DoCommand
            jsr   TimeLine
            jsr   AppendLog             ; after every command, in case the next one fails
            bra   :next
:end        jsr   AppendLog
            PushLongAt TestH
            Tool  _DisposeHandle
            jmp   MarkDone

* TimeLine: with TIMING 1, "TIME $t" after each command's line: the ticks
* (60ths of a second) it took.
TimeLine    lda   TimeOn
            beq   :out
            pha
            pha
            Tool  _TickCount
            pla
            sec
            sbc   CmdTick
            sta   Ticks
            pla
            lda   #TxtTime
            jsr   LogC
            lda   Ticks
            jsr   LogHex
            jmp   LogCR
:out        rts

* MarkDone: DONE at the start of the text screen memory, where the
* emulator's test script looks to see that the commands are done.
MarkDone    lda   #$CFC4                ; "DO", high bits set
            stal  $E00400
            lda   #$C5CE                ; "NE"
            stal  $E00402
            rts

* GetLine: the next non-empty line into CmdBuf (C string).
*   out: carry set when there are no more lines
GetLine     lda   TestP
            sta   p0
            lda   TestP+2
            sta   p0+2
:skip       ldy   TestPos
            cpy   TestLen
            bcs   :end
            lda   [p0],y
            and   #$00FF
            cmp   #$0D
            beq   :blank
            cmp   #$0A
            bne   :start
:blank      inc   TestPos
            bra   :skip
:start      ldx   #0
:char       ldy   TestPos
            cpy   TestLen
            bcs   :done
            lda   [p0],y
            and   #$00FF
            cmp   #$0D
            beq   :done
            cmp   #$0A
            beq   :done
            sep   #$20
            mx    %10
            sta   CmdBuf,x
            rep   #$20
            mx    %00
            inx
            inc   TestPos
            cpx   #250
            bcc   :char
:done       sep   #$20
            mx    %10
            stz   CmdBuf,x
            rep   #$20
            mx    %00
            stx   CmdLen
            clc
            rts
:end        sec
            rts

DoCommand   lda   #CmdBuf
            jsr   LogC
            lda   #TxtColon
            jsr   LogC
            stz   ForceFmt
            lda   #CmdLoadAsTxt
            jsr   Match
            bcs   :notAs
            jsr   FindId                ; ForceFmt = the format; A = where the path starts
            bcc   :load
            jmp   :unknown
:notAs      lda   #CmdLoadTxt
            jsr   Match
            bcc   :load
            jmp   :notLoad
:load       jsr   MakePath
            pha
            pha
            Tool  _TickCount
            pla
            sta   StartTick
            pla
            jsr   LoadPath
            php
            pha
            pha
            pha
            Tool  _TickCount
            pla
            sec
            sbc   StartTick
            sta   Ticks
            pla
            pla
            plp
            bcc   :loaded
            jmp   :error
:loaded
            lda   #TxtLoaded
            jsr   LogC
            lda   Format
            jsr   LogHex
            lda   IsTrue
            bne   :jx25
            jmp   :eol
:jx25
            lda   #TxtSize              ; true colour: its size, and the fitted size
            jsr   LogC
            lda   TrueW
            jsr   LogHex
            lda   #TxtSpace
            jsr   LogC
            lda   TrueH
            jsr   LogHex
            lda   #TxtFit
            jsr   LogC
            lda   PicW
            jsr   LogHex
            lda   #TxtSpace
            jsr   LogC
            lda   PicH
            jsr   LogHex
            lda   #TxtTicks             ; and how long it took (60ths of a second)
            jsr   LogC
            lda   Ticks
            jsr   LogHex
            jmp   LogCR
:notLoad    lda   #CmdAPFTxt
            jsr   Match
            bcs   :notAPF
            ldx   #fmtAPF
            bra   :save
:notAPF     lda   #CmdC1Txt
            jsr   Match
            bcs   :notC1
            ldx   #fmtC1
            bra   :save
:notC1      lda   #CmdPackTxt
            jsr   Match
            bcs   :notPack
            ldx   #fmtPacked
:save       stx   t3
            jsr   MakePath
            lda   t3
            jsr   SavePath
            bcc   :saved
            jmp   :error
:saved
            lda   #TxtOK
            jsr   LogC
            jmp   LogCR
:notPack    lda   #CmdSaveAsTxt
            jsr   Match
            bcs   :notSaveAs
            ldx   #SaveIds
            ldy   #saveCount
            jsr   FindIdIn
            bcc   :saveAs
            jmp   :unknown
:saveAs     jsr   MakePath
            lda   FoundId
            jsr   SaveAs
            bcc   :savedAs
            jmp   :error
:savedAs    jmp   :saved
:notSaveAs  lda   #CmdRGBTxt
            jsr   Match
            bcs   :notRGB
            jsr   MakePath
            jsr   SaveRGB
            bcs   :rgbErr
            jmp   :saved
:rgbErr     jmp   :error
:notRGB     lda   #CmdShotTxt
            jsr   Match
            bcs   :notShot
            jsr   MakePath              ; SHOT path: the screen as it shows
            jsr   SaveShot
            bcs   :shotErr
            jmp   :saved
:shotErr    jmp   :error
:notShot    lda   #CmdRemapTxt
            jsr   Match
            bcs   :notRemap
            pha
            pha
            Tool  _TickCount
            pla
            sta   StartTick
            pla
            jsr   RemapCmd
            bcc   :remapped
            jmp   :error
:remapped
            pha
            pha
            Tool  _TickCount
            pla
            sec
            sbc   StartTick
            sta   Ticks
            pla
            lda   #TxtOK
            jsr   LogC
            lda   #TxtTicks
            jsr   LogC
            lda   Ticks
            jsr   LogHex
            jmp   LogCR
:notRemap   lda   #CmdMemTxt
            jsr   Match
            bcs   :notMem
            lda   #TxtOK                ; MEM: free memory and the largest block
            jsr   LogC
            pha                         ; (a long result: low word first off)
            pha
            Tool  _FreeMem
            pla
            sta   MemLo
            pla
            jsr   LogHex
            lda   MemLo
            jsr   LogHex
            pha
            pha
            Tool  _MaxBlock
            pla
            sta   MemLo
            pla
            jsr   LogHex
            lda   MemLo
            jsr   LogHex
            jmp   LogCR
:notMem     lda   #CmdIdleTxt
            jsr   Match
            bcs   :notIdle
            jsr   ParseNumber           ; IDLE n: the event loop for n ticks
            jsr   Idle                  ; (windows get drawn)
            lda   #TxtOK
            jsr   LogC
            jmp   LogCR
:notIdle    lda   #CmdPickTxt
            jsr   Match
            bcs   :notPick
            jsr   ParseArgs             ; PICK t f: Load formats' computer type t
            lda   Args                  ; and its format f (from 0)
            ldx   Args+2
            ldy   #0
            jsl   DeskPick
            lda   #TxtOK
            jsr   LogC
            jmp   LogCR
:notPick    lda   #CmdPickSTxt
            jsr   Match
            bcs   :notPickS
            jsr   ParseArgs             ; PICKSAVE s: Save formats' format s
            lda   Args
            ldy   #1
            jsl   DeskPick
            lda   #TxtOK
            jsr   LogC
            jmp   LogCR
:notPickS   lda   #CmdClicksTxt
            jsr   Match
            bcs   :notClicks
            jsr   ParseArgs             ; clicks for the next Remap dialog
            lda   #Args
            sta   p0
            lda   #^Args
            sta   p0+2
            lda   NArgs                 ; (4 bytes a click)
            lsr
            lsr
            jsl   RemapClicks
            lda   #TxtOK
            jsr   LogC
            jmp   LogCR
:notClicks  lda   #CmdClickTxt
            jsr   Match
            bcs   :notClick
            jsr   ParseArgs             ; CLICK x y n: n clicks at x, y
            pea   1                     ; (global), as the mouse would make:
            pea   0                     ; the pointer goes there (as from
            lda   Args                  ; another pointing device), then the
            pha                         ; clicks go in the event queue
            lda   Args+2
            pha
            pea   0                     ; (the button up)
            Tool  _FakeMouse
            lda   #4                    ; the Event Manager sees the mouse there
            jsr   Idle
            lda   #1                    ; one click, or n (0: the pointer
            ldx   NArgs                 ; only moves there)
            cpx   #6
            bcc   :clicks
            lda   Args+4
:clicks     sta   ClickN
            beq   :moved
:click      pha
            pea   1                     ; mouse down
            PushLong 0
            Tool  _PostEvent
            pla
            pha
            pea   2                     ; mouse up
            PushLong 0
            Tool  _PostEvent
            pla
            dec   ClickN
            bne   :click
:moved      lda   #10                   ; and what they do
            jsr   Idle
            lda   #TxtOK
            jsr   LogC
            jmp   LogCR
:notClick   lda   #CmdMenuTxt
            jsr   Match
            bcs   :notMenu
            jsr   ParseNumber
            sta   EventRec+TaskData     ; item, as TaskMaster would report it
            stz   EventRec+TaskData+2
            jsr   DoMenu
            lda   #TxtOK
            jsr   LogC
            jmp   LogCR
:notMenu    lda   #CmdFilterTxt
            jsr   Match
            bcs   :notFilter
            jsr   ParseArgs             ; FILTER k f: filter k, factor f
            lda   Args+2
            ldx   NArgs
            cpx   #4
            bcs   :factor
            lda   #50
:factor     tax
            lda   Args
            jsr   RunFilter
            bcs   :fxErr
            lda   #TxtOK
            jsr   LogC
            jmp   LogCR
:fxErr      jmp   :error
:notFilter  lda   #CmdTurnTxt
            jsr   Match
            bcs   :notTurn
            jsr   ParseNumber           ; TURN b: rotate/flip, bits b
            jsr   RunTurn
            bcs   :fxErr
            lda   #TxtOK
            jsr   LogC
            jmp   LogCR
:notTurn    lda   #CmdSnapTxt
            jsr   Match
            bcs   :notSnap
            jsr   Snap                  ; SNAP: keep a copy of the true colour picture
            bcs   :fxErr
            lda   #TxtOK
            jsr   LogC
            jmp   LogCR
:notSnap    lda   #CmdBackTxt
            jsr   Match
            bcs   :notBack
            jsr   Back                  ; BACK: the copy kept back in its place
            bcs   :fxErr
            lda   #TxtOK
            jsr   LogC
            jmp   LogCR
:notBack    lda   #CmdMonoTxt
            jsr   Match
            bcs   :notMono
            jsr   ParseArgs             ; MONO k h v m: a monochrome image from
            jsr   DeskDP                ; the screen (k 0) or true colour image
            lda   Args+6                ; (k 2), h and v times larger, method m
            jsl   MonoMethod
            lda   Args
            ldx   Args+2
            ldy   Args+4
            jsl   MonoMake
            bcs   :mErr
            lda   #3                    ; (shown, as after the menu's conversion)
            sta   ShowType
            jsr   PictureMenus
            lda   #TxtOK
            jsr   LogC
            jmp   LogCR
:mErr       jmp   :error
:notMono    lda   #CmdMonoOutTxt
            jsr   Match
            bcs   :notMonoOut
            jsr   ParseArgs             ; MONOOUT k a s m sh: the monochrome image
            jsr   DeskDP                ; as a screen (k 0) or true colour (k 2)
            lda   Args+8                ; image: aspect a, scaling s, 640 mode m,
            xba                         ; shrink sh
            ora   Args+6
            tay
            lda   Args+2
            ldx   Args+4
            jsl   MonoOpts
            lda   Args
            jsl   MonoOut
            bcs   :mErr
            lda   Args
            jsr   AfterMonoOut
            jsr   TellDesk
            lda   #TxtOK
            jsr   LogC
            jmp   LogCR
:notMonoOut lda   #CmdMonoNegTxt
            jsr   Match
            bcs   :notNeg
            jsr   DeskDP                ; MONONEG: the monochrome image negated
            jsl   MonoNeg
            lda   #TxtOK
            jsr   LogC
            jmp   LogCR
:notNeg     lda   #CmdMonoSaveTxt
            jsr   Match
            bcs   :notMSave
            jsr   MakePath              ; SAVE MONO path: its bits, row by row
            lda   MonoBlk
            beq   :noMono
            lda   #$0006
            sta   WType
            stz   WAux
            stz   WAux+2
            lda   MonoP
            sta   WData
            lda   MonoP+2
            sta   WData+2
            lda   MonoStr
            ldx   MonoH
            jsr   Mul16
            lda   ProdLo
            sta   WLen
            lda   ProdHi
            sta   WLen+2
            jsr   WriteFile
            bcc   :jx1
            jmp   :mErr
:jx1
            lda   #TxtOK
            jsr   LogC
            jmp   LogCR
:noMono     lda   #errNotPicture
            jmp   :error
:notMSave   lda   #CmdDeskSaveTxt
            jsr   Match
            bcc   :jx3
            jmp   :notDSave
:jx3
            jsr   MakePath              ; SAVE DESK path: the desktop message
            pha                         ; (an empty handle to get it into)
            pha
            PushLong 0
            lda   UserID
            pha
            pea   0
            PushLong 0
            Tool  _NewHandle
            pla
            sta   DeskH
            pla
            sta   DeskH+2
            pea   2                     ; MessageCenter: get it
            pea   2
            PushLongAt DeskH
            Tool  _MessageCenter
            bcc   :desk
            PushLongAt DeskH
            Tool  _DisposeHandle
            lda   #TxtNoDesk
            jsr   LogC
            jmp   LogCR
:desk       PushLongAt DeskH
            Tool  _HLock
            pha
            pha
            PushLongAt DeskH
            Tool  _GetHandleSize
            pla
            sta   WLen
            pla
            sta   WLen+2
            lda   DeskH
            sta   p3
            lda   DeskH+2
            sta   p3+2
            lda   [p3]
            sta   WData
            ldy   #2
            lda   [p3],y
            sta   WData+2
            lda   #$0006
            sta   WType
            stz   WAux
            stz   WAux+2
            jsr   WriteFile
            php
            pha
            PushLongAt DeskH
            Tool  _DisposeHandle
            pla
            plp
            bcc   :jx2
            jmp   :mErr
:jx2
            lda   #TxtOK
            jsr   LogC
            jmp   LogCR
:notDSave   lda   #CmdPrefixTxt
            jsr   Match
            bcs   :notPfx
            jsr   MakePath              ; PREFIX path: prefix 8
            lda   PathPtr
            sta   TPfxParms+4
            lda   PathPtr+2
            sta   TPfxParms+6
            GSOS  _SetPrefixGS;TPfxParms
            bcc   :pfxOK
            jmp   :mErr
:pfxOK      lda   #TxtOK
            jsr   LogC
            jmp   LogCR
:notPfx     lda   #CmdPathsTxt
            jsr   Match
            bcs   :notPaths
            lda   #TxtLoadPfx           ; PATHS: the folders kept
            jsr   LogC
            lda   #LoadPfx+2
            jsr   LogGS
            lda   #TxtSavePfx
            jsr   LogC
            lda   #SavePfx+2
            jsr   LogGS
            jmp   LogCR
:notPaths   lda   #CmdScrapTxt
            jsr   Match
            bcc   :scrapCmd
            jmp   :notScrap
:scrapCmd   jsr   MakePath              ; SAVE SCRAP path
            pha
            pha
            pea   1                     ; the picture
            Tool  _GetScrapHandle
            pla
            sta   ScrapH
            pla
            sta   ScrapH+2
            bcc   :scrap
            lda   #TxtNoScrap
            jsr   LogC
            jmp   LogCR
:scrap      lda   #screenSize           ; a screen to draw it into
            sta   n0
            stz   n0+2
            jsr   NewBuffer
            bcc   :sbuf
            jmp   :mErr
:sbuf       lda   n1
            sta   TBufH
            lda   n1+2
            sta   TBufH+2
            lda   p0
            sta   TLoc+2
            sta   WData
            lda   p0+2
            sta   TLoc+4
            sta   WData+2
            lda   ScreenP
            sta   p1
            lda   ScreenP+2
            sta   p1+2
            ldy   #0                    ; no pixels; the lines' modes and colours
:zero       lda   #0                    ; of the screen image
            cpy   #scbOffset
            bcc   :z
            lda   [p1],y
:z          sta   [p0],y
            iny
            iny
            cpy   #screenSize
            bcc   :zero
            ldy   #scbOffset            ; its mode: that of line 0
            lda   [p1],y
            and   #$00FF
            sta   TLoc
            ldx   #320
            and   #$0080
            beq   :w
            ldx   #640
:w          stx   TLoc+14
            pha
            pha
            Tool  _GetPort
            pla
            sta   TOld
            pla
            sta   TOld+2
            PushLong TPort
            Tool  _OpenPort
            PushLong TLoc
            Tool  _SetPortLoc
            PushLong TLoc+8
            Tool  _SetPortRect
            PushLong TLoc+8
            Tool  _ClipRect
            lda   ScrapH                ; drawn in its own frame
            sta   p1
            lda   ScrapH+2
            sta   p1+2
            ldy   #2
            lda   [p1],y
            tax
            lda   [p1]
            sta   p1
            stx   p1+2
            ldy   #2
            ldx   #0
:frame      lda   [p1],y
            sta   TFrame,x
            iny
            iny
            inx
            inx
            cpx   #8
            bcc   :frame
            PushLongAt ScrapH
            PushLong TFrame
            Tool  _DrawPicture
            PushLongAt TOld
            Tool  _SetPort
            PushLong TPort
            Tool  _ClosePort
            lda   #$00C1
            sta   WType
            stz   WAux
            stz   WAux+2
            lda   #screenSize
            sta   WLen
            stz   WLen+2
            jsr   WriteFile
            php
            pha
            PushLongAt TBufH
            Tool  _DisposeHandle
            pla
            plp
            bcc   :sOK
            jmp   :mErr
:sOK        lda   #TxtOK
            jsr   LogC
            pha                         ; the colour table scrap
            pha
            pea   $8002
            Tool  _GetScrapHandle
            pla
            sta   p1
            pla
            sta   p1+2
            bcs   :noPal
            ldy   #2
            lda   [p1],y
            tax
            lda   [p1]
            sta   p1
            stx   p1+2
            ldy   #0
:pword      phy
            lda   #TxtSpace
            jsr   LogC
            ply
            phy
            lda   [p1],y
            jsr   LogHex
            ply
            iny
            iny
            cpy   #34
            bcc   :pword
:noPal      jmp   LogCR
:notScrap   lda   #CmdImagesTxt
            jsr   Match
            bcs   :notImages
            lda   #TxtImgScr            ; IMAGES: screen n, true n, mono n
            jsr   LogC
            lda   HaveScreen
            jsr   LogFlag
            lda   #TxtImgTrue
            jsr   LogC
            lda   IsTrue
            jsr   LogFlag
            lda   #TxtImgMono
            jsr   LogC
            lda   MonoBlk
            jsr   LogFlag
            jmp   LogCR
:notImages  lda   #CmdQueueTxt
            jsr   Match
            bcs   :notQueue
            jsr   ParseArgs             ; QUEUE t path
            lda   Args
            sta   darg
            ldy   #0                    ; (the path: after the number)
:sp         lda   CmdBuf+6,y
            and   #$00FF
            cmp   #' '
            beq   :path
            iny
            bra   :sp
:path       tya
            clc
            adc   #7
            jsr   MakePath
            lda   #PathBuf
            sta   dctl
            lda   #^PathBuf
            sta   dctl+2
            jsl   DeskAddPath
            jsr   QueueOn
            lda   #TxtOK
            jsr   LogC
            jmp   LogCR
:notQueue   lda   #CmdQueuedTxt
            jsr   Match
            bcs   :notQueued
            jsl   DeskQueueText         ; QUEUED: the paths waiting
            lda   #TxtOK
            jsr   LogC
            lda   #TxtSpace
            jsr   LogC
            jsr   LogLong
            jmp   LogCR
:notQueued  lda   #CmdSaveDlgTxt
            jsr   Match
            bcs   :notSDlg
            jsr   ParseArgs             ; SAVEDLG n [s a w]
            lda   Args
            sta   TestSaveDlg
            lda   Args                  ; (the answers: none unless 2 or 3;
            cmp   #2                    ; 3: the format's own windows show)
            bcc   :sAns
            lda   Args+2
            ldx   Args
            cpx   #3
            bne   :sNo
            ora   #$8000
:sNo        ldx   Args+4
            ldy   Args+6
            bra   :sSet
:sAns       lda   #0
            ldx   #0
            ldy   #0
:sSet       jsl   SaveTest
            lda   #TxtOK
            jsr   LogC
            jmp   LogCR
:notSDlg    lda   #CmdSysInfoTxt
            jsr   Match
            bcs   :notSys
            jsr   MakePath              ; SYSINFO path
            lda   #PathBuf
            sta   dctl
            lda   #^PathBuf
            sta   dctl+2
            lda   UserID
            sta   uid
            jsl   SysInfo
            lda   #TxtOK
            jsr   LogC
            jmp   LogCR
:notSys     lda   #CmdExamineTxt
            jsr   Match
            bcs   :notExam
            jsr   ParseArgs             ; EXAMINE k steps... path
            tya                         ; (the path: after the numbers)
            jsr   MakePath
            lda   Args                  ; the screen saved as *:MCOUT:EXAMx,
            clc                         ; x the letter k (0 A, 1 B, ...)
            adc   #'A'
            sep   #$20
            mx    %10
            sta   ExamOut+14
            rep   #$20
            mx    %00
            ldx   #2                    ; the steps: the other numbers
:exs        cpx   NArgs
            bcs   :exGo
            lda   Args,x
            sta   ExamRec+12,x
            inx
            inx
            bra   :exs
:exGo       lda   NArgs
            lsr
            dec
            sta   ExamRec+12
            stz   ExamRes
            lda   #ExamRec
            sta   dctl
            lda   #^ExamRec
            sta   dctl+2
            lda   UserID
            sta   uid
            jsl   Examine
            lda   #ExamRes
            jsr   LogC
            jmp   LogCR
:notExam    lda   #CmdWoaTxt
            jsr   Match
            bcs   :notWoa
            jsr   ParseArgs             ; WOAPAGE n
            lda   Args
            jsl   WoaTest
            lda   #TxtOK
            jsr   LogC
            jmp   LogCR
:notWoa     lda   #CmdBParamTxt
            jsr   Match
            bcs   :notBP
            jsr   ParseArgs             ; BPARAM n v: battery RAM
            lda   Args+2
            pha
            lda   Args
            pha
            Tool  _WriteBParam
            lda   #TxtOK
            jsr   LogC
            jmp   LogCR
:notBP      lda   #CmdPngOptTxt
            jsr   Match
            bcs   :notPO
            jsr   ParseArgs             ; PNGOPT l f text
            tya
            clc
            adc   #CmdBuf
            sta   dctl
            lda   #^CmdBuf
            sta   dctl+2
            lda   Args
            ldx   Args+2
            jsl   PngSet
            lda   #TxtOK
            jsr   LogC
            jmp   LogCR
:notPO      lda   #CmdA2OptTxt
            jsr   Match
            bcs   :notA2
            jsr   ParseArgs             ; A2OPT d f
            lda   Args
            ldx   Args+2
            jsl   A2Set
            lda   #TxtOK
            jsr   LogC
            jmp   LogCR
:notA2      lda   #CmdTiffOptTxt
            jsr   Match
            bcs   :notTO
            jsr   ParseArgs             ; TIFFOPT w m f text
            tya
            clc
            adc   #CmdBuf
            sta   dctl
            lda   #^CmdBuf
            sta   dctl+2
            lda   Args
            ldx   Args+2
            ldy   Args+4
            jsl   TiffSet
            lda   #TxtOK
            jsr   LogC
            jmp   LogCR
:notTO      lda   #CmdHelpLogTxt
            jsr   Match
            bcs   :notHLog
            lda   #HelpBuf              ; HELPLOG: the help page shown
            sta   dctl
            lda   #^HelpBuf
            sta   dctl+2
            jsl   HelpLog
            lda   #HelpBuf
            jsr   LogC
            jmp   LogCR
:notHLog    lda   #CmdHelpTxt
            jsr   Match
            bcs   :notHelpC
            tay                         ; HELP label: that page
            ldx   #0
            sep   #$20
            mx    %10
:hl         lda   CmdBuf,y
            beq   :hlEnd
            sta   HelpLab+1,x
            iny
            inx
            bra   :hl
:hlEnd      txa
            sta   HelpLab
            rep   #$20
            mx    %00
            lda   #HelpLab
            sta   dctl
            lda   #^HelpLab
            sta   dctl+2
            lda   UserID
            sta   uid
            jsl   HelpGo
            lda   #TxtOK
            jsr   LogC
            jmp   LogCR
:notHelpC   lda   #CmdHexOptTxt
            jsr   Match
            bcs   :notHexO
            clc                         ; HEXOPT start|separator|end
            adc   #CmdBuf
            sta   dctl
            lda   #^CmdBuf
            sta   dctl+2
            jsl   HexSet
            lda   #TxtOK
            jsr   LogC
            jmp   LogCR
:notHexO    lda   #CmdNameTxt
            jsr   Match
            bcs   :notName
            tay                         ; NAME n: NameGS
            ldx   #0
            sep   #$20
            mx    %10
:nm         lda   CmdBuf,y
            beq   :nmEnd
            sta   NameGS+2,x
            iny
            inx
            bra   :nm
:nmEnd      rep   #$20
            mx    %00
            stx   NameGS
            lda   #TxtOK
            jsr   LogC
            jmp   LogCR
:notName    lda   #CmdBFNameTxt
            jsr   Match
            bcs   :notBFName
            tay                         ; BFNAME name: the translator the
            lda   CmdBuf,y              ; Babelfish imports and exports use
            and   #$00FF                ; (none: the usual choice)
            cmp   #' '
            bne   :bfn
            iny
:bfn        tya
            clc
            adc   #CmdBuf
            sta   fp
            lda   #^CmdBuf
            sta   fp+2
            jsl   BabelName
            lda   #TxtOK
            jsr   LogC
            jmp   LogCR
:notBFName  lda   #CmdBFLastTxt
            jsr   Match
            bcs   :notBFLast
            jsl   BabelLast             ; BFLAST: the last translator, and
            sta   t3                    ; the kind it sent
            lda   #TxtOK
            jsr   LogC
            lda   [fp]
            and   #$00FF
            tax
            ldy   #1
:bl         cpx   #0
            beq   :blEnd
            lda   [fp],y
            and   #$007F                ; (™: $AA, logged as '*')
            phx
            ldx   LogLen
            cpx   #2000
            bcs   :blFull
            sep   #$20
            mx    %10
            sta   LogBuf,x
            rep   #$20
            mx    %00
            inc   LogLen
:blFull     plx
            iny
            dex
            bra   :bl
:blEnd      lda   #TxtSpace
            jsr   LogC
            lda   t3
            jsr   LogHex
            lda   #TxtSpace             ; the last request, the last Match
            jsr   LogC                  ; list (number, ranking ...)
            lda   dact
            jsr   LogHex
            ldy   #0
:bll        cpy   darg
            bcs   :bllEnd
            phy
            lda   #TxtSpace
            jsr   LogC
            ply
            lda   [dctl],y
            phy
            jsr   LogHex
            ply
            iny
            iny
            bra   :bll
:bllEnd     jmp   LogCR
:notBFLast  lda   #CmdSaveWarnTxt
            jsr   Match
            bcs   :notSWarn
            lda   #TxtOK                ; SAVEWARN
            jsr   LogC
            lda   #TxtSpace
            jsr   LogC
            jsl   SaveWarned
            jsr   LogHex
            jmp   LogCR
:notSWarn   lda   #CmdTimingTxt
            jsr   Match
            bcs   :notTiming
            jsr   ParseArgs             ; TIMING n
            lda   Args
            sta   TimeOn
            lda   #TxtOK
            jsr   LogC
            jmp   LogCR
:notTiming  lda   #CmdSmoothTxt
            jsr   Match
            bcs   :notSmooth
            jsr   ParseArgs             ; SMOOTH n
            lda   Args
            sta   TestSmooth
            lda   #TxtOK
            jsr   LogC
            jmp   LogCR
:notSmooth  lda   #CmdPrefTxt
            jsr   Match
            bcs   :notPref
            jsr   ParseArgs             ; PREF n v
            lda   Args
            asl
            tax
            lda   Args+2
            sta   Prefs,x
            bra   :pOK
:notPref    lda   #CmdPSaveTxt
            jsr   Match
            bcs   :notPSave
            jsr   PrefsAt               ; PREFSAVE
            jsl   PrefsSave
            bra   :pOK
:notPSave   lda   #CmdPLoadTxt
            jsr   Match
            bcs   :notPLoad
            jsr   PrefsAt               ; PREFLOAD
            jsl   PrefsLoad
:pOK        lda   #TxtOK
            jsr   LogC
            jmp   LogCR
:notPLoad   lda   #CmdPrefsTxt
            jsr   Match
            bcs   :notPrefs
            ldx   #0                    ; PREFS: the eight
:p          phx
            lda   Prefs,x
            jsr   LogFlag
            plx
            inx
            inx
            cpx   #16
            bcc   :p
            jmp   LogCR
:notPrefs   lda   #CmdDeskTxt
            jsr   Match
            bcs   :notDesk
            jsr   ParseArgs             ; DESK k ...
            lda   #Args
            sta   dctl
            lda   #^Args
            sta   dctl+2
            lda   NArgs
            sta   darg
            jsl   DeskTest
            lda   #TxtOK
            jsr   LogC
            lda   dctl
            ora   dctl+2
            beq   :dAct
            lda   #TxtSpace
            jsr   LogC
            jsr   LogLong               ; (its text)
:dAct       jsr   LogCR
            jmp   ImgAction
:notDesk    lda   #CmdShowTxt
            jsr   Match
            bcs   :notShow
            lda   #TxtOK
            jsr   LogC
            jsr   LogCR
            jsr   AppendLog
            jsr   ShowPicture
            jsr   MarkDone
:halt       bra   :halt                 ; leave the picture up for the test to see
:notShow    lda   #CmdQuitTxt
            jsr   Match
            bcs   :unknown
            inc   QuitFlag
            lda   #TxtOK
            jsr   LogC
            jmp   LogCR
:unknown    lda   #TxtUnknown
            jsr   LogC
            jmp   LogCR
:error      pha
            lda   #TxtError
            jsr   LogC
            pla
            jsr   LogHex
:eol        jmp   LogCR

* Match: carry clear if CmdBuf starts with the C string at A;
* then A = length of that string (where the argument starts).
Match       sta   t0
            ldy   #0
            sep   #$20
            mx    %10
:char       lda   (t0),y
            beq   :yes
            cmp   CmdBuf,y
            bne   :no
            iny
            bra   :char
:yes        rep   #$20
            mx    %00
            tya
            clc
            rts
:no         rep   #$20
            mx    %00
            sec
            rts

* FindId: the format whose short name is in CmdBuf at offset A, then a space.
*   out: carry clear, ForceFmt set and A = offset after the space
FindId      ldx   #FmtIds
            ldy   #fmtLast+1
            jsr   FindIdIn
            bcs   :no
            pha
            lda   FoundId
            sta   ForceFmt
            pla
:no         rts

* FindIdIn: the same with the name table at X (Y names, entry 0 unused).
*   out: carry clear, FoundId and A = offset after the space
FindIdIn    sta   u0
            stx   IdTab
            tya
            asl
            sta   IdEnd
            ldx   #2
:format     txa
            clc
            adc   IdTab
            tay
            lda   |0,y
            sta   t0
            ldy   u0
            sep   #$20
            mx    %10
:char       lda   (t0)
            beq   :end
            cmp   CmdBuf,y
            bne   :no
            iny
            rep   #$20
            mx    %00
            inc   t0
            sep   #$20
            mx    %10
            bra   :char
:end        lda   CmdBuf,y
            cmp   #' '
            bne   :no
            rep   #$20
            mx    %00
            txa
            lsr
            sta   FoundId
            iny
            tya
            clc
            rts
:no         rep   #$20
            mx    %00
            inx
            inx
            cpx   IdEnd
            bcc   :format
            sec
            rts

FoundId     dw    0
IdTab       dw    0
IdEnd       dw    0

* RemapCmd: REMAP (the defaults, fitted), or REMAP WITH and the options.
RemapCmd    lda   #CmdRemapQTxt
            jsr   Match
            bcs   :notQuick
            lda   #2
            jmp   RunRemap
:notQuick   lda   #CmdRemapWTxt
            jsr   Match
            bcc   :with
            lda   #1
            jmp   RunRemap
:with       jsr   ParseArgs
            jsr   SourceTrue            ; (the options' sizes need the picture)
            bcc   :src
            rts
:src        jsr   SetRemapDP
            lda   Args
            sta   rmode
            lda   Args+2
            sta   rpal
            lda   Args+4
            sta   ralg
            lda   Args+6
            sta   rhs
            lda   Args+8
            sta   rvs
            lda   Args+10
            sta   rother
            jsl   RemapSet
            lda   #0
            jmp   RunRemap

* ParseArgs: up to 6 decimal numbers in CmdBuf from offset A (spaces between).
ParseArgs   tay
            stz   NArgs
:next       lda   CmdBuf,y
            and   #$00FF
            cmp   #' '
            bne   :num
            iny
            bra   :next
:num        cmp   #'0'
            bcc   :done
            cmp   #'9'+1
            bcs   :done
            tya
            jsr   ParseNumber           ; (Y: after it)
            ldx   NArgs
            sta   Args,x
            inx
            inx
            stx   NArgs
            cpx   #80
            bcc   :next
:done       rts

* Idle: the event loop (OneEvent) for A ticks.
Idle        sta   IdleN
            pha
            pha
            Tool  _TickCount
            pla
            sta   IdleStart
            pla
:idle       jsr   OneEvent
            pha
            pha
            Tool  _TickCount
            pla
            plx
            sec
            sbc   IdleStart
            cmp   IdleN
            bcc   :idle
            rts

NArgs       dw    0
Args        ds    80                    ; (up to 40 numbers)

* ParseNumber: the decimal number in CmdBuf from offset A on.
ParseNumber tay
            stz   t1
:digit      lda   CmdBuf,y
            and   #$00FF
            sec
            sbc   #'0'
            bcc   :end
            cmp   #10
            bcs   :end
            sta   t2
            lda   t1                    ; t1 = t1 * 10 + digit
            asl
            sta   t1
            asl
            asl
            clc
            adc   t1
            clc
            adc   t2
            sta   t1
            iny
            bra   :digit
:end        lda   t1
            rts

* SaveRGB: the true colour picture, as its RGB bytes (binary file).
SaveRGB     lda   IsTrue
            bne   :have
            lda   #errNotPicture
            sec
            rts
:have       lda   #$0006
            sta   WType
            stz   WAux
            stz   WAux+2
            lda   TrueP
            sta   WData
            lda   TrueP+2
            sta   WData+2
            lda   TrueSize
            sta   WLen
            lda   TrueSize+2
            sta   WLen+2
            jmp   WriteFile

* SaveShot: the Super Hi-Res display (bank $E1 from $2000: pixels, SCBs,
* colour tables) saved as a $C1 file, without the pointer (for the manual).
SaveShot    Tool  _HideCursor
            lda   #$00C1
            sta   WType
            stz   WAux
            stz   WAux+2
            lda   #$2000
            sta   WData
            lda   #$00E1
            sta   WData+2
            lda   #32768
            sta   WLen
            stz   WLen+2
            jsr   WriteFile
            php
            pha
            Tool  _ShowCursor
            pla
            plp
            rts

* MakePath: PathBuf = GS/OS string of CmdBuf from offset A on.
MakePath    tay
            ldx   #0
            sep   #$20
            mx    %10
:char       lda   CmdBuf,y
            beq   :end
            sta   PathBuf+2,x
            iny
            inx
            bra   :char
:end        rep   #$20
            mx    %00
            stx   PathBuf
            lda   #PathBuf
            sta   PathPtr
            lda   #^PathBuf
            sta   PathPtr+2
            rts

*-------------------------------------------------------------
* The log
*-------------------------------------------------------------

* LogC: appends the C string at A (in this bank).
LogC        sta   t0
            ldy   #0
            ldx   LogLen
            sep   #$20
            mx    %10
:char       lda   (t0),y
            beq   :end
            cpx   #2000                 ; full: drop the rest
            bcs   :end
            sta   LogBuf,x
            iny
            inx
            bra   :char
:end        rep   #$20
            mx    %00
            stx   LogLen
            rts

* LogLong: appends the C string at dctl (a long pointer).
LogLong     ldy   #0
            ldx   LogLen
:char       lda   [dctl],y
            and   #$00FF
            beq   :end
            cpx   #2000
            bcs   :end
            sep   #$20
            mx    %10
            sta   LogBuf,x
            rep   #$20
            mx    %00
            iny
            inx
            bra   :char
:end        stx   LogLen
            rts

* PrefsAt: dctl = the options' address.
PrefsAt     lda   #Prefs
            sta   dctl
            lda   #^Prefs
            sta   dctl+2
            rts

* LogFlag: appends 1 if A is not zero, else 0.
LogFlag     cmp   #0
            beq   :zero
            lda   #TxtOne
            jmp   LogC
:zero       lda   #TxtZero
            jmp   LogC

* LogGS: appends the GS/OS string at A (in this bank).
LogGS       sta   t0
            lda   (t0)
            clc
            adc   #2
            sta   t2
            ldy   #2
            ldx   LogLen
            sep   #$20
            mx    %10
:char       cpy   t2
            bcs   :end
            cpx   #2000                 ; full: drop the rest
            bcs   :end
            lda   (t0),y
            sta   LogBuf,x
            iny
            inx
            bra   :char
:end        rep   #$20
            mx    %00
            stx   LogLen
            rts

LogCR       lda   #TxtCR
            jmp   LogC

* LogHex: appends A as "$hhhh".
LogHex      sta   t1
            lda   #TxtDollar
            jsr   LogC
            ldy   #4
:digit      lda   t1
            xba                         ; top nibble first
            lsr
            lsr
            lsr
            lsr
            and   #$000F
            tax
            lda   HexDigits,x
            ldx   LogLen
            sep   #$20
            mx    %10
            sta   LogBuf,x
            rep   #$20
            mx    %00
            inc   LogLen
            asl   t1
            asl   t1
            asl   t1
            asl   t1
            dey
            bne   :digit
            rts

* AppendLog: adds the log text to MC.LOG and empties the buffer.
AppendLog   lda   LogLen
            beq   :done
            lda   #LogPath
            sta   OpenParms+4
            lda   #^LogPath
            sta   OpenParms+6
            GSOS  _OpenGS;OpenParms
            bcs   :done
            lda   OpenParms+2
            sta   EOFParms+2
            sta   MarkParms+2
            sta   WriteParms+2
            sta   CloseParms+2
            GSOS  _GetEOFGS;EOFParms
            lda   EOFParms+4            ; write at the end
            sta   MarkParms+6
            lda   EOFParms+6
            sta   MarkParms+8
            GSOS  _SetMarkGS;MarkParms
            lda   #LogBuf
            sta   WriteParms+4
            lda   #^LogBuf
            sta   WriteParms+6
            lda   LogLen
            sta   WriteParms+8
            stz   WriteParms+10
            GSOS  _WriteGS;WriteParms
            GSOS  _CloseGS;CloseParms
:done       stz   LogLen
            rts

MarkParms   dw    3
            dw    0                     ; refNum
            dw    0                     ; base: from the start
            adrl  0                     ; displacement

* WriteLog: replaces MC.LOG with the log text.
WriteLog    lda   #LogPath
            sta   PathPtr
            lda   #^LogPath
            sta   PathPtr+2
            lda   #$0004                ; text file
            sta   WType
            stz   WAux
            stz   WAux+2
            lda   #LogBuf
            sta   WData
            lda   #^LogBuf
            sta   WData+2
            lda   LogLen
            sta   WLen
            stz   WLen+2
            jmp   WriteFile

*-------------------------------------------------------------
* Data
*-------------------------------------------------------------
TestMode    dw    0
TestH       adrl  0
TestP       adrl  0
TestLen     dw    0
TestPos     dw    0
CmdLen      dw    0
LogLen      dw    0

TestPath    dw    9
            asc   '*:MC.TEST'
LogPath     dw    8
            asc   '*:MC.LOG'

CmdLoadTxt  asc   'LOAD ',00
CmdLoadAsTxt asc  'LOAD AS ',00
CmdAPFTxt   asc   'SAVE APF ',00
CmdC1Txt    asc   'SAVE C1 ',00
CmdPackTxt  asc   'SAVE PACK ',00
CmdShowTxt  asc   'SHOW',00
CmdRemapTxt asc   'REMAP',00
CmdMenuTxt  asc   'MENU ',00
CmdRemapWTxt asc  'REMAP WITH ',00
CmdRemapQTxt asc  'REMAP QUICK',00
CmdClicksTxt asc  'CLICKS ',00
CmdMemTxt   asc   'MEM',00
CmdIdleTxt  asc   'IDLE ',00
CmdPickTxt  asc   'PICK ',00
CmdPickSTxt asc   'PICKSAVE ',00
CmdClickTxt asc   'CLICK ',00
CmdFilterTxt asc  'FILTER ',00
CmdTurnTxt  asc   'TURN ',00
CmdSnapTxt  asc   'SNAP',00
CmdMonoTxt  asc   'MONO ',00
CmdMonoOutTxt asc 'MONOOUT ',00
CmdMonoNegTxt asc 'MONONEG',00
CmdMonoSaveTxt asc 'SAVE MONO ',00
CmdDeskSaveTxt asc 'SAVE DESK ',00
CmdPrefixTxt asc  'PREFIX ',00
CmdPathsTxt asc   'PATHS',00
CmdScrapTxt asc   'SAVE SCRAP ',00
CmdImagesTxt asc  'IMAGES',00
CmdDeskTxt  asc   'DESK ',00
CmdQueueTxt asc   'QUEUE ',00
CmdPrefTxt  asc   'PREF ',00
CmdSmoothTxt asc  'SMOOTH ',00
CmdTimingTxt asc  'TIMING ',00
TxtTime     asc   'TIME ',00
TimeOn      dw    0                     ; (TIMING: log each command's time)
CmdTick     dw    0
CmdSaveDlgTxt asc 'SAVEDLG ',00
CmdSaveWarnTxt asc 'SAVEWARN',00
CmdNameTxt  asc   'NAME ',00
CmdBFNameTxt asc  'BFNAME',00
CmdShotTxt  asc   'SHOT ',00
CmdBFLastTxt asc  'BFLAST',00
CmdSysInfoTxt asc 'SYSINFO ',00
CmdExamineTxt asc 'EXAMINE ',00
CmdHexOptTxt asc 'HEXOPT ',00
CmdWoaTxt   asc 'WOAPAGE ',00
CmdBParamTxt asc 'BPARAM ',00
CmdPngOptTxt asc 'PNGOPT ',00
CmdA2OptTxt asc  'A2OPT ',00
CmdTiffOptTxt asc 'TIFFOPT ',00
CmdHelpLogTxt asc 'HELPLOG',00
CmdHelpTxt  asc 'HELP ',00
HelpLab     ds    40
HelpBuf     ds    200
ExamRec     adrl  PathBuf               ; Examine's test record: the file,
            adrl  ExamOut               ; where the screen goes, the text
            adrl  ExamRes               ; about the window, the steps
            dw    0
            ds    80
ExamOut     dw    13
            asc   '*:MCOUT:EXAMA'
ExamRes     ds    300
CmdPrefsTxt asc   'PREFS',00
CmdPSaveTxt asc   'PREFSAVE',00
CmdPLoadTxt asc   'PREFLOAD',00
CmdQueuedTxt asc  'QUEUED',00
TxtImgScr   asc   'screen ',00
TxtImgTrue  asc   ', true ',00
TxtImgMono  asc   ', mono ',00
TxtZero     asc   '0',00
TxtOne      asc   '1',00
TxtNoScrap  asc   'no picture on the Clipboard',00
ScrapH      adrl  0
TBufH       adrl  0
TOld        adrl  0
TLoc        dw    0                     ; SCB
            adrl  0                     ; pixels
            dw    160                   ; bytes a line
            dw    0,0,200,0             ; bounds
TFrame      dw    0,0,0,0
TPort       ds    $AA
TxtLoadPfx  asc   'load ',00
TxtSavePfx  asc   ', save ',00
TPfxParms   dw    2                     ; SetPrefix 8
            dw    8
            adrl  0
TxtNoDesk   asc   'no desktop message',00
DeskH       adrl  0                     ; SAVE DESK: the message
CmdBackTxt  asc   'BACK',00
SnapH       adrl  0
SnapW       dw    0
SnapH2      dw    0
SnapTall    dw    0
SnapSize    adrl  0

* Snap: a copy of the true colour picture (SnapH).   out: carry set and A =
* error if there is none or no memory
Snap        lda   IsTrue
            bne   :have
            lda   #errNotPicture
            sec
            rts
:have       lda   SnapH                 ; (the copy before, gone)
            ora   SnapH+2
            beq   :none
            PushLongAt SnapH
            Tool  _DisposeHandle
            stz   SnapH
            stz   SnapH+2
:none       lda   TrueW
            sta   SnapW
            lda   TrueH
            sta   SnapH2
            lda   TrueTall
            sta   SnapTall
            lda   TrueSize
            sta   SnapSize
            lda   TrueSize+2
            sta   SnapSize+2
            jsr   CopyBlock             ; TrueHnd's bytes into a new handle
            bcs   :err
            lda   n1
            sta   SnapH
            lda   n1+2
            sta   SnapH+2
:err        rts

* Back: the kept copy becomes the true colour picture (a copy of it, so it
* can come back again).
Back        lda   SnapH
            ora   SnapH+2
            bne   :have
            lda   #errNotPicture
            sec
            rts
:have       lda   SnapSize
            sta   n0
            lda   SnapSize+2
            sta   n0+2
            jsr   NewBig                ; n1 handle, p0 pointer
            bcs   :err
            PushLongAt SnapH
            PushLongAt n1
            PushLongAt SnapSize
            Tool  _HandToHand
            lda   TrueHnd               ; the picture before, gone
            ora   TrueHnd+2
            beq   :none
            PushLongAt TrueHnd
            Tool  _DisposeHandle
:none       lda   n1
            sta   TrueHnd
            lda   n1+2
            sta   TrueHnd+2
            lda   p0
            sta   TrueP
            lda   p0+2
            sta   TrueP+2
            lda   SnapW
            sta   TrueW
            asl
            clc
            adc   SnapW
            sta   TrueStride
            lda   SnapH2
            sta   TrueH
            lda   SnapTall
            sta   TrueTall
            lda   SnapSize
            sta   TrueSize
            lda   SnapSize+2
            sta   TrueSize+2
            lda   #1
            sta   IsTrue
            inc   TrueGen
            jsr   TellDesk
            clc
:err        rts

* CopyBlock: a new handle (n1) with a copy of the true colour picture.
CopyBlock   lda   TrueSize
            sta   n0
            lda   TrueSize+2
            sta   n0+2
            jsr   NewBig
            bcs   :err
            PushLongAt TrueHnd
            PushLongAt n1
            PushLongAt TrueSize
            Tool  _HandToHand
            clc
:err        rts
ClickN      dw    0
IdleN       dw    0
IdleStart   dw    0
MemLo       dw    0
CmdRGBTxt   asc   'SAVE RGB ',00
CmdSaveAsTxt asc  'SAVE AS ',00
TxtSize     asc   ', size ',00
TxtFit      asc   ', fitted ',00
TxtSpace    asc   ' ',00
TxtTicks    asc   ', ticks ',00
StartTick   dw    0
Ticks       dw    0
CmdQuitTxt  asc   'QUIT',00
TxtColon    asc   ': ',00
TxtOK       asc   'ok',00
TxtLoaded   asc   'ok, format ',00
TxtError    asc   'error ',00
TxtUnknown  asc   'unknown command',00
TxtDollar   asc   '$',00
TxtCR       hex   0D00
HexDigits   asc   '0123456789ABCDEF'

CmdBuf      ds    256
PathBuf     ds    260
LogBuf      ds    2048
