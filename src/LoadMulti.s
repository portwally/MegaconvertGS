*-------------------------------------------------------------
* LoadMulti.s - Load & convert's file dialog and the load queue, as
* SuperConvert's (part of the Desk segment; docs/superconvert-file.md 3):
* Standard File's SFPMultiGet2 with SuperConvert's dialog (its two check
* boxes), the file filter for the format chosen in Load formats, several
* files (and folders' pictures) queued and loaded one at a time with Load
* next.
*-------------------------------------------------------------

* DeskMultiGet: the file dialog.
*   out: darg = how many entries were chosen (0: none), dctl = Standard
*   File's names handle; dact bit 0: Load all pictures within selected
*   folders, bit 1: Allow files to be selected regardless of type
DeskMultiGet ent
            phb
            phk
            plb
            jsr   ChosenFmt             ; the chosen format's filter
            ldx   t3
            lda   |10,x
            sta   FiltRec
            stz   LoadAll               ; (both boxes start unchecked)
            stz   AnyType
            pea   120
            pea   40
            PushLong 0                  ; (Standard File draws the items)
            pea   0                     ; the prompt: a Pascal string
            PushLong MPrompt
            PushLong FiltProc
            PushLong 0                  ; (no type list)
            PushLong MTmpl
            PushLong HookProc
            PushLong MReply
            Tool  _SFPMultiGet2
            lda   MReply
            sta   darg
            lda   MReply+2
            sta   dctl
            lda   MReply+4
            sta   dctl+2
            lda   AnyType
            asl
            ora   LoadAll
            sta   dact
            plb
            rtl

* FiltProc: Standard File's filter: a GetDirEntry record (on the stack)
* rated 0 not shown, 1 shown dimmed, 2 can be chosen.
FiltProc    phb
            phk
            plb
            phd
            tsc
            tcd                         ; (7: the record, 11: the result)
            lda   7
            sta   FPtr
            lda   9
            sta   FPtr+2
            pld
            phd                         ; (the program's direct page)
            lda   AppDP
            tcd
            lda   FPtr
            sta   ip0
            lda   FPtr+2
            sta   ip0+2
            jsr   Rate
            pld
            sta   9,s                   ; (the result, past B, the return
            plb                         ; address and the record's pointer)
            lda   2,s                   ; the record's pointer off the stack
            sta   6,s
            lda   1,s
            sta   5,s
            pla
            pla
            rtl

* HookProc: the dialog's own items: the two check boxes turn on and off
* (Allow files ... regardless of type: the list filtered again); Standard
* File doesn't see them.
HookProc    phb
            phk
            plb
            phd
            tsc
            tcd                         ; (7: the item hit, 11: the dialog)
            lda   [7]
            cmp   #16
            bcc   :out
            cmp   #18
            bcs   :out
            pha                         ; its value turned over
            pei   13
            pei   11
            lda   [7]
            pha
            Tool  _GetDItemValue
            pla
            eor   #1
            sta   HookV
            pha
            pei   13
            pei   11
            lda   [7]
            pha
            Tool  _SetDItemValue
            lda   [7]
            cmp   #17
            beq   :any
            lda   HookV
            sta   LoadAll
            bra   :none
:any        lda   HookV
            sta   AnyType
            PushLong 0                  ; (the filter and type list as they are)
            PushLong 0
            Tool  _SFReScan
:none       lda   #0
            sta   [7]
:out        pld
            plb
            lda   2,s                   ; the parameters off the stack
            sta   10,s
            lda   1,s
            sta   9,s
            tsc
            clc
            adc   #8
            tcs
            rtl

* Rate: the filter (FiltRec) for the GetDirEntry record at ip0 (file type
* +$10, EOF +$12, aux type +$2C): A = 1 dimmed, 2 can be chosen.
Rate        lda   AnyType
            beq   :typed
            lda   #2
            rts
:typed      ldx   FiltRec
            ldy   #$10
            lda   [ip0],y
            sta   RType
            ldy   #$12
            lda   [ip0],y
            sta   REof
            iny
            iny
            lda   [ip0],y
            sta   REof+2
            ldy   #$2C
            lda   [ip0],y
            sta   RAux
            iny
            iny
            lda   [ip0],y
            sta   RAux+2
            lda   |0,x                  ; the format's types
            cmp   #$FFFF
            bne   :single
            jmp   RateList
:single     lda   RType                 ; type A or B
            sep   #$20
            mx    %10
            cmp   |0,x
            beq   :check8
            cmp   |1,x
            beq   :check8
            rep   #$20
            mx    %00
            lda   RType
            cmp   #$0F                  ; folders: always
            beq   :yes
            cmp   #0                    ; no type: for "$04 or $06" formats
            bne   :no
            lda   |0,x
            cmp   #$0406
            beq   :check
            cmp   #$0604
            beq   :check
:no         lda   #1
            rts
:check8     rep   #$20
            mx    %00
:check      lda   REof+2                ; EOF within (32 bits)
            cmp   |8,x
            bcc   :no
            bne   :minOK
            lda   REof
            cmp   |6,x
            bcc   :no
:minOK      lda   |12,x
            cmp   REof+2
            bcc   :no
            bne   :maxOK
            lda   |10,x
            cmp   REof
            bcc   :no
:maxOK      lda   RAux                  ; the aux type's low word within
            cmp   |2,x
            bcc   :no
            lda   |4,x
            cmp   RAux
            bcc   :no
:yes        lda   #2
            rts

* RateList: a list of types (FiltRec + 2: its address): each half of the
* aux type and EOF compared on its own, as SuperConvert does.
RateList    lda   RType
            cmp   #$0F
            beq   :yes
            lda   |2,x
            tax
:e          lda   |0,x
            cmp   #$FFFF
            beq   :no
            cmp   RType
            bne   :next
            lda   RAux+2                ; aux type: high words, low words
            cmp   |4,x
            bcc   :next
            lda   RAux
            cmp   |2,x
            bcc   :next
            lda   |8,x
            cmp   RAux+2
            bcc   :next
            lda   |6,x
            cmp   RAux
            bcc   :next
            lda   REof+2                ; EOF the same way
            cmp   |12,x
            bcc   :next
            lda   REof
            cmp   |10,x
            bcc   :next
            lda   |16,x
            cmp   REof+2
            bcc   :next
            lda   |14,x
            cmp   REof
            bcc   :next
:yes        lda   #2
            rts
:next       txa
            clc
            adc   #18
            tax
            bra   :e
:no         lda   #1
            rts

*-------------------------------------------------------------
* The queue
*-------------------------------------------------------------

* DeskAddFiles: the entries Standard File gave (dctl: its names handle,
* darg: how many, dact: the check boxes) go to the queue (full paths);
* folders' pictures too with Load all pictures within selected folders.
* The names handle is disposed of.
*   out: dact = 1: one folder chosen without that: prefix 8 is it now
*   (the dialog again, inside it); else 0
DeskAddFiles ent
            phb
            phk
            plb
            jsr   QueueMake
            lda   dact
            and   #1
            sta   LoadAll
            lda   dctl
            sta   NamesH
            lda   dctl+2
            sta   NamesH+2
            lda   darg
            sta   NCount
            stz   dact
            stz   Depth
            lda   NamesH                ; the entries: type, aux type, name
            sta   ip1                   ; (a Pascal string), from offset 2
            lda   NamesH+2
            sta   ip1+2
            ldy   #2
            lda   [ip1],y
            tax
            lda   [ip1]
            sta   ip1
            stx   ip1+2
            lda   #2
            sta   NOff
            lda   NCount                ; one folder without Load all: inside
            cmp   #1
            bne   :each
            ldy   NOff
            lda   [ip1],y
            cmp   #$0F
            bne   :each
            lda   LoadAll
            bne   :each
            jsr   NameOf
            jsr   PathTo8               ; prefix 8 := the folder
            lda   #1
            sta   dact
            bra   :done
:each       ldy   NOff                  ; its type
            lda   [ip1],y
            sta   AddType
            jsr   NameOf                ; "8:" and its name in Path8
            jsr   AddOne
            ldy   NOff                  ; the next entry: 7 + the name
            iny
            iny
            iny
            iny
            iny
            iny
            lda   [ip1],y
            and   #$00FF
            clc
            adc   #7
            adc   NOff
            sta   NOff
            dec   NCount
            bne   :each
:done       PushLongAt NamesH
            Tool  _DisposeHandle
            plb
            rtl

* NameOf: Path8 = the name of the entry at ip1 + NOff (a Pascal string at
* + 6; Standard File gives them with their prefix, "8:NAME").
NameOf      lda   NOff
            clc
            adc   #6
            tay
            lda   [ip1],y
            and   #$00FF
            sta   Path8                 ; its length
            ldx   #0
:c          cpx   Path8
            bcs   :end
            iny
            lda   [ip1],y
            sep   #$20
            mx    %10
            sta   Path8+2,x
            rep   #$20
            mx    %00
            inx
            bra   :c
:end        rts

* PathTo8: prefix 8 := Path8 (a folder relative to it).
PathTo8     lda   #Path8
            sta   PfxSet+4
            lda   #^Path8
            sta   PfxSet+6
            GSOS  _SetPrefixGS;PfxSet
            rts

* AddOne: the entry in Path8 (AddType: its file type): a file goes to the
* queue as a full path; a folder (with Load all) gives each of its entries
* the filter rates 2, its folders the same way, depth first.
AddOne      lda   AddType
            cmp   #$0F
            beq   :folder
            lda   #Path8                ; a file: its full path
            sta   ExpParms+2
            lda   #^Path8
            sta   ExpParms+4
            GSOS  _ExpandPathGS;ExpParms
            bcc   :jx1
            jmp   :out
:jx1
            jmp   QueueAdd
:folder     lda   LoadAll
            bne   :jx2
            jmp   :out
:jx2
            lda   Depth
            cmp   #MaxDepth
            bcc   :jx3
            jmp   :out
:jx3
            asl                         ; its prefix 8 kept
            tax
            lda   PfxSaves,x
            sta   PfxGet+4
            lda   #^PfxSave0
            sta   PfxGet+6
            GSOS  _GetPrefixGS;PfxGet
            bcc   :jx4
            jmp   :out
:jx4
            jsr   PathTo8               ; inside it
            bcc   :jx5
            jmp   :back
:jx5
            GSOS  _OpenGS;DirOpen       ; its entries
            bcc   :jx6
            jmp   :back
:jx6
            lda   DirOpen+2
            ldx   Depth
            inc   Depth
            pha
:entry      lda   1,s
            sta   DirParms+2
            lda   #1                    ; (the next one)
            sta   DirParms+6
            sta   DirParms+8
            lda   #DirName
            sta   DirParms+10
            lda   #^DirName
            sta   DirParms+12
            GSOS  _GetDirEntryGS;DirParms
            bcs   :close
            lda   #DirParms             ; the filter's say
            sta   ip0
            lda   #^DirParms
            sta   ip0+2
            jsr   Rate
            cmp   #2
            bne   :entry
            lda   DirParms+$10
            sta   AddType
            lda   DirName+2             ; Path8 = "8:" and its name
            sta   iw2
            clc
            adc   #2
            sta   Path8
            lda   #$3A38               ; ("8:")
            sta   Path8+2
            ldx   #0
:n          cpx   iw2
            bcs   :add
            lda   DirName+4,x
            sta   Path8+4,x
            inx
            inx
            bra   :n
:add        jsr   AddOne
            bra   :entry
:close      pla                         ; done: closed, prefix 8 back
            sta   DirClose+2
            GSOS  _CloseGS;DirClose
            dec   Depth
            lda   Depth
            asl
            tax
            lda   PfxSaves,x
            clc
            adc   #2
            sta   PfxSet+4
            lda   #^PfxSave0
            sta   PfxSet+6
            GSOS  _SetPrefixGS;PfxSet
:out        rts
:back       lda   Depth                 ; (could not go in: prefix 8 back)
            asl
            tax
            lda   PfxSaves,x
            clc
            adc   #2
            sta   PfxSet+4
            lda   #^PfxSave0
            sta   PfxSet+6
            GSOS  _SetPrefixGS;PfxSet
            rts

* QueueMake: the queue's block, made once (16K).
QueueMake   lda   QueueH
            ora   QueueH+2
            bne   :have
            pha
            pha
            PushLong 16384
            lda   uid
            pha
            pea   $C018                 ; (locked, fixed)
            PushLong 0
            Tool  _NewHandle
            pla
            sta   QueueH
            pla
            sta   QueueH+2
            bcc   :have
            stz   QueueH
            stz   QueueH+2
:have       rts

* QueueAdd: the full path in ExpOut (a result buffer) onto the queue's end.
QueueAdd    lda   QueueH
            ora   QueueH+2
            beq   :out
            lda   ExpOut+2              ; (room for it?)
            clc
            adc   #2
            adc   QLen
            cmp   #16384
            bcs   :out
            lda   QueueH
            sta   ip0
            lda   QueueH+2
            sta   ip0+2
            ldy   #2
            lda   [ip0],y
            tax
            lda   [ip0]
            sta   ip0
            stx   ip0+2
            lda   ExpOut+2
            clc
            adc   #2
            sta   iw2                   ; bytes: its length word and name
            ldy   QLen
            ldx   #0
:c          lda   ExpOut+2,x
            sta   [ip0],y
            iny
            iny
            inx
            inx
            cpx   iw2
            bcc   :c
            lda   QLen                  ; (odd lengths: one byte too many
            clc                         ; copied, never counted)
            adc   iw2
            sta   QLen
:out        rts

* DeskNextFile: the queue's next path (a GS/OS string) into the buffer at
* dctl, and off the queue.
*   out: carry set if there is none; dact = 1 if the queue is empty now
DeskNextFile ent
            phb
            phk
            plb
            stz   dact
            lda   QPos
            cmp   QLen
            bcc   :have
            jsr   QClear
            lda   #1
            sta   dact
            sec
            plb
            rtl
:have       lda   QueueH
            sta   ip0
            lda   QueueH+2
            sta   ip0+2
            ldy   #2
            lda   [ip0],y
            tax
            lda   [ip0]
            sta   ip0
            stx   ip0+2
            ldy   QPos
            lda   [ip0],y
            clc
            adc   #2
            sta   iw2
            sty   iw3
            ldy   #0
:c          phy
            tya
            clc
            adc   iw3
            tay
            lda   [ip0],y
            ply
            sta   [dctl],y
            iny
            iny
            cpy   iw2
            bcc   :c
            lda   QPos
            clc
            adc   iw2
            sta   QPos
            cmp   QLen
            bcc   :more
            jsr   QClear
            lda   #1
            sta   dact
:more       clc
            plb
            rtl

* DeskQueueClear: Cancel remaining files: the queue emptied.
DeskQueueClear ent
            phb
            phk
            plb
            jsr   QClear
            plb
            rtl
QClear      stz   QLen
            stz   QPos
            rts

* DeskQueued: A = 1 if paths are waiting in the queue.
DeskQueued  ent
            phb
            phk
            plb
            lda   #0
            ldx   QPos
            cpx   QLen
            bcs   :none
            lda   #1
:none       plb
            rtl

* DeskQueue: A = 1: Load next takes the Load... button's place; 0: Load...
* again.
DeskQueue   ent
            phb
            phk
            plb
            tax
            beq   :off
            PushLongAt CtlLoad
            Tool  _HideControl
            PushLongAt CtlNext
            Tool  _ShowControl
            plb
            rtl
:off        PushLongAt CtlNext
            Tool  _HideControl
            PushLongAt CtlLoad
            Tool  _ShowControl
            plb
            rtl

* DeskAddPath: for tests: the path at dctl (a GS/OS string; AddType in
* darg: $0F a folder, whose pictures go with Load all) added as if chosen
* in the dialog.
DeskAddPath ent
            phb
            phk
            plb
            jsr   QueueMake
            jsr   ChosenFmt             ; (the chosen format's filter)
            ldx   t3
            lda   |10,x
            sta   FiltRec
            stz   AnyType
            lda   #1
            sta   LoadAll
            lda   darg
            sta   AddType
            ldy   #0                    ; Path8: the path given
            lda   [dctl]
            clc
            adc   #2
            sta   iw2
:c          lda   [dctl],y
            sta   Path8,y
            iny
            iny
            cpy   iw2
            bcc   :c
            stz   Depth
            jsr   AddOne
            plb
            rtl

* DeskQueueText: for tests: dctl = a text: how many paths wait in the
* queue, then the last part of each.
DeskQueueText ent
            phb
            phk
            plb
            lda   #QText
            sta   mp1
            stz   TLen
            stz   iw4                   ; how many
            lda   QueueH
            ora   QueueH+2
            beq   :count
            lda   QueueH
            sta   ip0
            lda   QueueH+2
            sta   ip0+2
            ldy   #2
            lda   [ip0],y
            tax
            lda   [ip0]
            sta   ip0
            stx   ip0+2
            ldy   QPos
:n          cpy   QLen
            bcs   :count
            inc   iw4
            lda   [ip0],y
            sta   iw2
            tya
            clc
            adc   iw2
            adc   #2
            tay
            bra   :n
:count      lda   iw4
            jsr   TDec
            lda   iw4
            beq   :end
            ldy   QPos
:path       cpy   QLen
            bcs   :end
            lda   [ip0],y               ; its length; its last part: after
            sta   iw2                   ; the last ':'
            iny
            iny
            sty   iw3
            tya
            clc
            adc   iw2
            sta   iw5                   ; (past its end)
            ldx   iw3
:colon      cpy   iw5
            bcs   :part
            lda   [ip0],y
            and   #$00FF
            cmp   #':'
            bne   :nc
            tyx
            inx
:nc         iny
            bra   :colon
:part       stx   iw3
            lda   #' '
            jsr   QPut
            ldy   iw3
:ch         cpy   iw5
            bcs   :next
            lda   [ip0],y
            jsr   QPut
            iny
            bra   :ch
:next       ldy   iw5
            bra   :path
:end        lda   #0
            jsr   QPut
            lda   #QText
            sta   dctl
            lda   #^QText
            sta   dctl+2
            plb
            rtl

* QPut: the character in A's low byte onto QText (at TLen; at most 590).
QPut        phx
            ldx   TLen
            cpx   #590
            bcs   :full
            sep   #$20
            mx    %10
            sta   QText,x
            rep   #$20
            mx    %00
            inc   TLen
:full       plx
            rts

*-------------------------------------------------------------
* Data
*-------------------------------------------------------------
MaxDepth    =     6
QText       ds    600                   ; (DeskQueueText's text)
FiltRec     dw    0                     ; the chosen format's filter
LoadAll     dw    0                     ; the check boxes
AnyType     dw    0
HookV       dw    0
FPtr        adrl  0
RType       dw    0
REof        adrl  0
RAux        adrl  0
NamesH      adrl  0
NCount      dw    0
NOff        dw    0
AddType     dw    0
Depth       dw    0
QueueH      adrl  0                     ; the queue: GS/OS strings, end to end
QLen        dw    0
QPos        dw    0
MReply      dw    0                     ; how many chosen,
            adrl  0                     ; their names
MPrompt     str   'Select file(s) to load and convert:'
PfxSet      dw    2,8                   ; SetPrefix 8
            adrl  0
PfxGet      dw    2,8                   ; GetPrefix 8
            adrl  0
ExpParms    dw    2                     ; ExpandPath: Path8 to ExpOut
            adrl  0
            adrl  ExpOut
DirOpen     dw    2                     ; Open "8:"
            dw    0
            adrl  DirPath
DirClose    dw    1
            dw    0
DirParms    dw    13                    ; GetDirEntry (to $2C: aux type)
            dw    0,0,1,1
            adrl  DirName
            dw    0,0
            adrl  0,0
            ds    16
            dw    0
            adrl  0
DirPath     dw    2
            asc   '8:'
DirName     dw    68                    ; (a result buffer: 64 characters)
            ds    66
Path8       dw    0                     ; "8:" and a name (GS/OS string)
            asc   '8:'
            ds    260
ExpOut      dw    516                   ; ExpandPath's result buffer
            ds    514
PfxSaves    da    PfxSave0,PfxSave1,PfxSave2,PfxSave3,PfxSave4,PfxSave5
PfxSave0    dw    260
            ds    258
PfxSave1    dw    260
            ds    258
PfxSave2    dw    260
            ds    258
PfxSave3    dw    260
            ds    258
PfxSave4    dw    260
            ds    258
PfxSave5    dw    260
            ds    258

* The dialog (SuperConvert's template, segment 2 $144A): Standard File's
* items 1-8, and the two check boxes.
MTmpl       dw    0,0,138,400           ; rect
            dw    $FFFF                 ; visible
            adrl  0                     ; refCon
            adrl  MItem1,MItem2,MItem3,MItem4,MItem5,MItem6,MItem7,MItem8
            adrl  MItem16,MItem17,0
MItem1      dw    1,61,265,73,375,$000A
            adrl  TxMOpen
            dw    0,0
            adrl  0
MItem2      dw    2,79,265,91,375,$000A
            adrl  TxMClose
            dw    0,0
            adrl  0
MItem3      dw    3,25,265,37,375,$000A
            adrl  TxMVolumes
            dw    0,0
            adrl  0
MItem4      dw    4,97,265,109,375,$000A
            adrl  TxMCancel
            dw    0,0
            adrl  0
MItem5      dw    5,43,265,55,375,$000A
            adrl  TxMAccept
            dw    0,0
            adrl  0
MItem6      dw    6,12,15,24,395,$0014
            adrl  0
            dw    0,0
            adrl  0
MItem7      dw    7,25,18,107,215,$8014
            adrl  0
            dw    0,0
            adrl  0
MItem8      dw    8,3,15,12,395,$800F
            adrl  0
            dw    0,0
            adrl  0
MItem16     dw    16,113,15,0,0,$000B
            adrl  TxMAll
            dw    0,0
            adrl  0
MItem17     dw    17,125,15,0,0,$000B
            adrl  TxMAny
            dw    0,0
            adrl  0
TxMOpen     str   'Open'
TxMClose    str   'Close'
TxMVolumes  str   'Volumes'
TxMCancel   str   'Cancel'
TxMAccept   str   'Accept'
TxMAll      str   'Load all pictures within selected folders'
TxMAny      str   'Allow files to be selected regardless of type'
