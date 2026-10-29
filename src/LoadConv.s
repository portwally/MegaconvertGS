*-------------------------------------------------------------
* LoadConv.s - Load & convert..., Load next and Cancel remaining files, as
* SuperConvert's (part of the main program; docs/superconvert-file.md 3).
* The file dialog, the file filter and the queue are in the Desk segment
* (LoadMulti.s).
*-------------------------------------------------------------

* LoadConv: Load & convert... (and the Load... button, a double click on a
* format): the chosen format's file dialog; the first file chosen is
* loaded, the others wait for Load next. A folder chosen alone (without
* "Load all pictures within selected folders"): the dialog again, in it.
LoadConv    jsl   DeskLoadFmt           ; a format listed, but not here yet?
            cmp   #fmtBabelTC           ; (the Babelfish imports: its own
            beq   :babel                ; dialog, one file)
            cmp   #fmtBabelPM
            bne   :ours
:babel      sta   ForceFmt
            jmp   BabelOpen
:ours       jsr   FmtHere
            bcc   :ok
            lda   #errNotImpl
            jmp   Problem
:ok         lda   #LoadPfx              ; (in the folder of the last load)
            jsr   RecallPfx
:ask        jsl   DeskMultiGet
            lda   #LoadPfx
            jsr   StorePfx
            lda   darg
            beq   :out
            jsl   DeskAddFiles
            lda   dact
            bne   :ask
            jsr   QueueOn
            jmp   LoadNext
:out        rts

* LoadNext: File > Load next (and the Load next button): the queue's next
* file, loaded with the format chosen in Load formats now.
LoadNext    lda   #NextPath
            sta   dctl
            lda   #^NextPath
            sta   dctl+2
            jsl   DeskNextFile
            php
            lda   dact                  ; none left after it: Load... again
            beq   :more
            jsr   QueueOff
:more       plp
            bcs   :out
            jsl   DeskLoadFmt
            sta   ForceFmt
            lda   #NextPath
            sta   PathPtr
            lda   #^NextPath
            sta   PathPtr+2
            jsr   LoadShow
            stz   ForceFmt
:out        rts

* LoadShow: the file at PathPtr loaded (ForceFmt: its format) and shown;
* a true colour picture then opens the Remap dialog, as SuperConvert's.
LoadShow    jsr   LoadPath
            php
            pha
            bcs   :fail
            jsr   KeepPath
:fail       pla
            plp
            bcc   :loaded
            jmp   Problem
:loaded     jmp   AfterLoad

* QueueOn: with files waiting, Load next in Load... 's place, and Load
* next and Cancel remaining files in the File menu.
QueueOn     jsl   DeskQueued
            cmp   #0
            beq   :out
            lda   #1
            jsl   DeskQueue
            pea   iLoadNext
            Tool  _EnableMItem
            pea   iCancelQ
            Tool  _EnableMItem
:out        rts

* QueueOff: Cancel remaining files (and the queue's end): Load... again.
QueueOff    jsl   DeskQueueClear
            lda   #0
            jsl   DeskQueue
            pea   iLoadNext
            Tool  _DisableMItem
            pea   iCancelQ
            Tool  _DisableMItem
            rts

NextPath    dw    0                     ; the next file (a GS/OS string)
            ds    514
