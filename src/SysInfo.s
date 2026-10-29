*-------------------------------------------------------------
* SysInfo.s - Extras > System info report..., as SuperConvert's (part of
* the Extras segment; docs/superconvert-extras.md 5.5): memory, the load
* files in memory, the started tool sets, versions, the battery RAM, in a
* TextEdit control, with Save as text file (and Print).
*-------------------------------------------------------------

* SysInfo: the report's window. dctl: for tests, a path to save the
* report at without the dialogs (0: the window as usual).
*   out: A = what was chosen (1 Cancel, 2 Save, 3 Print)
SysInfo     ent
            phb
            phk
            plb
            lda   dctl
            sta   STest
            lda   dctl+2
            sta   STest+2
            Tool  _WaitCursor
            pha                         ; the text buffer (32K)
            pha
            PushLong 32768
            lda   uid
            pha
            pea   $C018
            PushLong 0
            Tool  _NewHandle
            pla
            sta   SBufH
            pla
            sta   SBufH+2
            bcc   :buf
            Tool  _InitCursor
            lda   #1
            plb
            rtl
:buf        lda   SBufH
            sta   xp0
            lda   SBufH+2
            sta   xp0+2
            ldy   #2
            lda   [xp0],y
            sta   SBuf+2
            lda   [xp0]
            sta   SBuf
            pha                         ; the window
            pha
            PushLong 0
            PushLong 0
            PushLong SIDraw
            PushLong 0
            pea   0
            PushLong SIParms
            pea   $800E
            Tool  _NewWindow2
            pla
            sta   SIWin
            pla
            sta   SIWin+2
            pha                         ; the TextEdit control
            pha
            PushLongAt SIWin
            pea   0
            PushLong SITE
            Tool  _NewControl2
            pla
            sta   STE
            pla
            sta   STE+2
            PushLong 14                 ; the version, after the name
            PushLong 14
            PushLongAt STE
            Tool  _TESetSelection
            lda   #TxVersion
            jsr   TEIns
            PushLong 65000              ; the report after the title, in
            PushLong 65000              ; Shaston 8, black on white
            PushLongAt STE
            Tool  _TESetSelection
            pea   $0022
            PushLong SIStyle
            PushLongAt STE
            Tool  _TEStyleChange
            jsr   SecMemory
            jsr   SecFiles
            jsr   SecTools
            jsr   SecMisc
            jsr   SecBattery
            PushLong 0                  ; its start in view
            PushLong 0
            PushLongAt STE
            Tool  _TESetSelection
            pea   0
            PushLong 0
            PushLong 0
            PushLongAt STE
            Tool  _TEScroll
            Tool  _InitCursor
            lda   STest                 ; (a test: saved at once)
            ora   STest+2
            beq   :loop
            jsr   SaveText
            lda   #2
            bra   :close
:loop       pha                         ; the user's choice
            pha
            PushLong SEvent
            PushLong 0
            PushLong 0
            PushLong 0
            pea   $0008
            Tool  _DoModalWindow
            pla
            plx
            cmp   #1
            beq   :close
            cmp   #2
            beq   :save
            cmp   #3
            bne   :loop
            Tool  _SysBeep              ; (Print: not here yet)
            lda   #3
            bra   :close
:save       jsr   SaveText
            lda   #2
:close      pha
            PushLongAt SIWin
            Tool  _CloseWindow
            PushLongAt SBufH
            Tool  _DisposeHandle
            pla
            plb
            rtl

* SIDraw: the window's contents: its controls.
SIDraw      phb
            phk
            plb
            pha
            pha
            Tool  _GetPort
            Tool  _DrawControls
            plb
            rtl

* TEIns: the C string at A (this bank) inserted at the selection.
TEIns       pea   $0001                 ; (a C string, by pointer)
            pea   ^TxVersion
            pha
            PushLong 0
            pea   0                     ; (no style: the one there)
            PushLong 0
            PushLongAt STE
            Tool  _TEInsert
            rts

* Flush: the section built in the buffer (SLen) inserted, then emptied.
Flush       lda   #0
            jsr   PutC
            pea   $0001
            PushLongAt SBuf
            PushLong 0
            pea   0
            PushLong 0
            PushLongAt STE
            Tool  _TEInsert
            stz   SLen
            rts

*-------------------------------------------------------------
* The sections
*-------------------------------------------------------------

* SecMemory: "MEMORY USAGE:  TotalMem=nK, ..., n handles.  By ID range
* (ID=norm/purgeable): $txxx=nK/nK, ..." (the Memory Manager's handles,
* walked from $E1/1600).
SecMemory   stz   SLen
            lda   #TxMem
            jsr   PutS
            pha
            pha
            Tool  _TotalMem
            jsr   PutKPull
            lda   #TxFree
            jsr   PutS
            pha
            pha
            Tool  _FreeMem
            jsr   PutKPull
            lda   #TxReal
            jsr   PutS
            pha
            pha
            Tool  _RealFreeMem
            jsr   PutKPull
            lda   #TxMax
            jsr   PutS
            pha
            pha
            Tool  _MaxBlock
            jsr   PutKPull
            lda   #TxComma2
            jsr   PutS
            ldx   #0                    ; the totals by ID type
:z          stz   SNorm,x
            stz   SPurg,x
            inx
            inx
            cpx   #64
            bcc   :z
            stz   SCount
            stz   SNIDs
            lda   #$1600                ; the handles
            sta   xp1
            lda   #$00E1
            sta   xp1+2
:h          ldy   #6                    ; its owner, by type
            lda   [xp1],y
            sta   SOwner
            jsr   AddID
            lda   SOwner
            xba
            lsr
            lsr
            lsr
            and   #$001E
            asl
            tax                         ; (x 4: longs)
            ldy   #4
            lda   [xp1],y
            and   #$0300
            beq   :norm
            ldy   #8
            lda   [xp1],y
            clc
            adc   SPurg,x
            sta   SPurg,x
            iny
            iny
            lda   [xp1],y
            adc   SPurg+2,x
            sta   SPurg+2,x
            bra   :next
:norm       ldy   #8
            lda   [xp1],y
            clc
            adc   SNorm,x
            sta   SNorm,x
            iny
            iny
            lda   [xp1],y
            adc   SNorm+2,x
            sta   SNorm+2,x
:next       inc   SCount
            lda   SCount
            cmp   #30000
            bcs   :walked
            ldy   #$10                  ; the next
            lda   [xp1],y
            tax
            ldy   #$12
            lda   [xp1],y
            sta   xp1+2
            stx   xp1
            ora   xp1
            beq   :walked
            jmp   :h
:walked     lda   SCount
            jsr   PutDec
            lda   #TxHandles
            jsr   PutS
            stz   SFirst
            ldx   #0                    ; each type with something
:t          lda   SNorm,x
            ora   SNorm+2,x
            ora   SPurg,x
            ora   SPurg+2,x
            beq   :tn
            phx
            jsr   Sep
            lda   #'$'
            jsr   PutC
            lda   1,s
            lsr
            lsr
            jsr   PutHex1
            lda   #TxXXX
            jsr   PutS
            plx
            phx
            lda   SNorm,x
            ldy   SNorm+2,x
            jsr   PutK
            lda   #'/'
            jsr   PutC
            plx
            phx
            lda   SPurg,x
            ldy   SPurg+2,x
            jsr   PutK
            plx
:tn         inx
            inx
            inx
            inx
            cpx   #64
            bcc   :t
            lda   #$0D
            jsr   PutC
            jmp   Flush

* AddID: SOwner added to the distinct IDs (kept in order).
AddID       lda   SOwner
            ldx   #0
:f          cpx   SNIDs
            bcs   :ins
            cmp   SIDs,x
            beq   :out
            bcc   :ins
            inx
            inx
            bra   :f
:ins        ldy   SNIDs                 ; room made at X
            cpy   #2*400
            bcs   :out
:mv         cpy   #0
            beq   :put
            stx   SMark
            cpy   SMark
            beq   :put
            lda   SIDs-2,y
            sta   SIDs,y
            dey
            dey
            bra   :mv
:put        lda   SOwner
            sta   SIDs,x
            inc   SNIDs
            inc   SNIDs
:out        rts

* SecFiles: "LOAD FILES IN MEMORY:  $iiii name, ..." for each owner and
* file number while the Loader knows a path.
SecFiles    stz   SLen
            lda   #TxFiles
            jsr   PutS
            stz   SFirst
            ldx   #0
:id         cpx   SNIDs
            bcs   :done
            phx
            lda   SIDs,x
            sta   SOwner
            lda   #1
            sta   SFile
:file       pha                         ; its path
            pha
            lda   SOwner
            pha
            lda   SFile
            pha
            Tool  _GetPathname2
            pla
            sta   xp1
            pla
            sta   xp1+2
            bcs   :nextID
            jsr   Sep
            lda   #'$'
            jsr   PutC
            lda   SOwner
            jsr   PutHex4
            lda   #' '
            jsr   PutC
            jsr   PutLast
            inc   SFile
            lda   SFile
            cmp   #64
            bcc   :file
:nextID     plx
            inx
            inx
            bra   :id
:done       lda   #$0D
            jsr   PutC
            jmp   Flush

* PutLast: the path at xp1 (a GS/OS string): its last part, or "(unnamed)".
PutLast     lda   [xp1]
            beq   :none
            clc
            adc   #2
            sta   SMark                 ; (past its last character)
            ldy   #2
            sty   SFrom
:c          cpy   SMark                 ; after the last ':'
            bcs   :put
            lda   [xp1],y
            and   #$00FF
            cmp   #':'
            bne   :n
            tya
            inc
            sta   SFrom
:n          iny
            bra   :c
:put        ldy   SFrom
:p          cpy   SMark
            bcs   :end
            lda   [xp1],y
            jsr   PutC
            iny
            bra   :p
:end        rts
:none       lda   #TxUnnamed
            jmp   PutS

* SecTools: "STARTED TOOLSETS:  $tt vM.m, ..." for each tool set whose
* status says it is started.
SecTools    stz   SLen
            lda   #TxTools
            jsr   PutS
            stz   SFirst
            lda   #1
            sta   STool
:t          lda   STool                 ; its status
            ora   #$0600
            sta   SCall
            pha
            ldx   SCall
            jsl   $E10000
            pla
            bcs   :next
            cmp   #0
            beq   :next
            lda   STool                 ; its version
            ora   #$0400
            sta   SCall
            pha
            ldx   SCall
            jsl   $E10000
            pla
            sta   SVer
            jsr   Sep
            lda   #'$'
            jsr   PutC
            lda   STool
            jsr   PutHex2
            lda   #TxV
            jsr   PutS
            jsr   PutVer
:next       inc   STool
            lda   STool
            cmp   #$7F
            bcc   :t
            lda   #$0D
            jsr   PutC
            jmp   Flush

* PutVer: SVer as "M.m" (and $A7 for a prerelease).
PutVer      lda   SVer
            xba
            and   #$007F
            jsr   PutDec
            lda   #'.'
            jsr   PutC
            lda   SVer
            and   #$00FF
            jsr   PutDec
            lda   SVer
            bpl   :out
            lda   #$A7
            jsr   PutC
:out        rts

* SecMisc: "MISCELLANEOUS:  GS/OS vM.m, ROM ID $xxxx & features $xxxx,  key
* translation n".
SecMisc     stz   SLen
            lda   #TxMisc
            jsr   PutS
            GSOS  _GetVersionGS;SVerParms
            lda   SVerParms+2
            sta   SVer
            jsr   PutVer
            lda   #TxROM
            jsr   PutS
            pha                         ; FWEntry($FE1F): the machine's ID
            pha
            pha
            pha
            pea   0
            pea   0
            pea   0
            pea   $FE1F
            Tool  _FWEntry
            pla
            sta   SW1
            pla
            pla
            sta   SW3
            pla
            lda   SW1
            jsr   PutHex4
            lda   #TxFeat
            jsr   PutS
            lda   SW3
            jsr   PutHex4
            lda   #TxKeyTr
            jsr   PutS
            pha
            Tool  _GetKeyTranslation
            pla
            jsr   PutDec
            lda   #$0D
            jsr   PutC
            jmp   Flush

* SecBattery: "BATTERY RAM (non-255 values):  $pp=n, ..."
SecBattery  stz   SLen
            lda   #TxBattery
            jsr   PutS
            stz   SFirst
            stz   SParm
:p          pha
            lda   SParm
            pha
            Tool  _ReadBParam
            pla
            and   #$00FF
            cmp   #255
            beq   :next
            sta   SW1
            jsr   Sep
            lda   #'$'
            jsr   PutC
            lda   SParm
            jsr   PutHex2
            lda   #'='
            jsr   PutC
            lda   SW1
            jsr   PutDec
:next       inc   SParm
            lda   SParm
            cmp   #$FC
            bcc   :p
            jmp   Flush

*-------------------------------------------------------------
* Save as text file
*-------------------------------------------------------------

* SaveText: the report's text, lines broken at a space past 76 characters
* (double spaces aren't break points), $A7 as "B", saved as a text file
* (SysInfoReport, or the test's path).
SaveText    pha                         ; the text into the buffer
            pha
            pea   $0005                 ; (a text block, by pointer)
            PushLongAt SBuf
            PushLong 32000
            pea   0
            PushLong 0
            PushLongAt STE
            Tool  _TEGetText
            pla
            sta   STLen
            pla
            lda   SBuf
            sta   xp1
            lda   SBuf+2
            sta   xp1+2
            stz   SFrom                 ; the line's start
            ldy   #0
:c          cpy   STLen
            bcs   :wrapped
            lda   [xp1],y
            and   #$00FF
            cmp   #$A7
            bne   :notA7
            lda   #'B'
            jsr   PutAt
            bra   :n
:notA7      cmp   #$0D
            bne   :sp
            iny
            sty   SFrom
            bra   :c
:sp         cmp   #' '
            bne   :n
            tya                         ; a space past 76 from the line's start:
            sec                         ; a break at the line's last earlier
            sbc   SFrom                 ; single space (not after or before
            cmp   #77                   ; another), or at this one
            bcc   :n
            sty   SMark
:back       dec   SMark
            lda   SMark
            cmp   SFrom
            beq   :self
            bcc   :self
            ldx   SMark
            jsr   Single
            bcs   :brk
            bra   :back
:self       sty   SMark
:brk        phy
            ldy   SMark
            lda   #$0D
            jsr   PutAt
            iny
            sty   SFrom
            ply
:n          iny
            bra   :c
:wrapped    lda   STest                 ; where to
            ora   STest+2
            beq   :ask
            lda   STest
            sta   STPath
            lda   STest+2
            sta   STPath+2
            bra   :write
:ask        lda   #3
            sta   SReply+8
            sta   SReply+14
            pea   160
            pea   50
            pea   0
            PushLong TxNameAs
            pea   0
            PushLong TxReportName
            PushLong SReply
            Tool  _SFPutFile2
            lda   SReply
            bne   :got
            rts
:got        lda   SReply+16             ; (the path handle: size, then the path)
            sta   xp1
            lda   SReply+18
            sta   xp1+2
            ldy   #2
            lda   [xp1],y
            tax
            lda   [xp1]
            clc
            adc   #2
            sta   STPath
            txa
            adc   #0
            sta   STPath+2
:write      lda   STPath                ; Destroy, Create (text), Open, Write
            sta   STDestroy+2
            sta   STCreate+2
            sta   STOpen+4
            lda   STPath+2
            sta   STDestroy+4
            sta   STCreate+4
            sta   STOpen+6
            GSOS  _DestroyGS;STDestroy
            GSOS  _CreateGS;STCreate
            bcs   :out
            GSOS  _OpenGS;STOpen
            bcs   :out
            lda   STOpen+2
            sta   STWrite+2
            sta   STClose+2
            lda   SBuf
            sta   STWrite+4
            lda   SBuf+2
            sta   STWrite+6
            lda   STLen
            sta   STWrite+8
            GSOS  _WriteGS;STWrite
            GSOS  _CloseGS;STClose
:out        lda   STest                 ; (the dialog's handles freed)
            ora   STest+2
            bne   :done
            PushLongAt SReply+10
            Tool  _DisposeHandle
            PushLongAt SReply+16
            Tool  _DisposeHandle
:done       rts

* Single: carry set if the character at X (in the text at xp1) is a space
* with no space before or after it.
Single      phy
            txy
            lda   [xp1],y
            and   #$00FF
            cmp   #' '
            bne   :no
            dey
            lda   [xp1],y
            and   #$00FF
            cmp   #' '
            beq   :no
            iny
            iny
            lda   [xp1],y
            and   #$00FF
            cmp   #' '
            beq   :no
            ply
            sec
            rts
:no         ply
            clc
            rts

* PutAt: the character in A stored at the text's Y.
PutAt       sep   #$20
            mx    %10
            sta   [xp1],y
            rep   #$20
            mx    %00
            rts

*-------------------------------------------------------------
* Building the text
*-------------------------------------------------------------

* PutC: the character in A onto the section (at SLen).
PutC        phy
            ldy   SLen
            cpy   #32000
            bcs   :full
            pha
            lda   SBuf
            sta   xp0
            lda   SBuf+2
            sta   xp0+2
            pla
            sep   #$20
            mx    %10
            sta   [xp0],y
            rep   #$20
            mx    %00
            inc   SLen
:full       ply
            rts

* PutS: the C string at A (this bank).
PutS        sta   xw1
            ldy   #0
:c          lda   (xw1),y
            and   #$00FF
            beq   :end
            jsr   PutC
            iny
            bra   :c
:end        rts

* Sep: ", " before every item but the first.
Sep         lda   SFirst
            bne   :comma
            inc   SFirst
            rts
:comma      lda   #TxComma2
            jmp   PutS

* PutDec: A in decimal.
PutDec      ldx   #0
:d          sta   SDiv
            phx
            jsr   Div10
            plx
            lda   SRem
            clc
            adc   #'0'
            pha
            inx
            lda   SDiv
            bne   :d
:o          pla
            jsr   PutC
            dex
            bne   :o
            rts

* Div10: SDiv = SDiv / 10, SRem the remainder.
Div10       lda   #0
            ldx   #16
:b          asl   SDiv
            rol
            cmp   #10
            bcc   :n
            sbc   #10
            inc   SDiv
:n          dex
            bne   :b
            sta   SRem
            rts

* PutKPull: the long result left on the stack (under the return address)
* in K; PutK: Y:A in K (/ 1024, then "K").
PutKPull    lda   3,s                   ; (low word)
            sta   SW1
            lda   5,s                   ; (high word)
            sta   SW3
            lda   1,s                   ; the return address over it
            sta   5,s
            pla
            pla
            lda   SW1
            ldy   SW3
PutK        sty   SW2                   ; Y:A / 1024
            ldx   #10
:s          lsr   SW2
            ror
            dex
            bne   :s
            jsr   PutDec
            lda   #'K'
            jmp   PutC

* PutHex1, PutHex2, PutHex4: A's low 1, 2 or 4 hex digits.
PutHex4     pha
            xba
            jsr   PutHex2
            pla
PutHex2     pha
            lsr
            lsr
            lsr
            lsr
            jsr   PutHex1
            pla
PutHex1     and   #$000F
            tax
            lda   SHexD,x
            and   #$00FF
            jmp   PutC

*-------------------------------------------------------------
* Data
*-------------------------------------------------------------
xp1         =     $CC                   ; (a long pointer)
STest       adrl  0
SBufH       adrl  0
SBuf        adrl  0
SLen        dw    0
SIWin       adrl  0
STE         adrl  0
SCount      dw    0
SOwner      dw    0
SNIDs       dw    0
SFirst      dw    0
SFile       dw    0
STool       dw    0
SCall       dw    0
SVer        dw    0
SParm       dw    0
SMark       dw    0
SFrom       dw    0
STLen       dw    0
SW1         dw    0
SW2         dw    0
SW3         dw    0
SDiv        dw    0
SRem        dw    0
SNorm       ds    64                    ; (longs, by ID type)
SPurg       ds    64
SIDs        ds    800
SHexD       asc   '0123456789ABCDEF'
SVerParms   dw    1
            dw    0
STPath      adrl  0
STDestroy   dw    1
            adrl  0
STCreate    dw    5
            adrl  0
            dw    $C3,$04
            adrl  0
            dw    1
STOpen      dw    3
            dw    0
            adrl  0
            dw    2
STWrite     dw    4
            dw    0
            adrl  0
            adrl  0
            adrl  0
STClose     dw    1
            dw    0
SReply      dw    0
            dw    0
            adrl  0
            dw    3
            adrl  0
            dw    3
            adrl  0
SEvent      dw    0
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
TxNameAs    str   'Name to save as:'
TxReportName dw   13
            asc   'SysInfoReport'
TxVersion   asc   '1.2',00
TxMem       asc   'MEMORY USAGE:  TotalMem=',00
TxFree      asc   ', FreeMem=',00
TxReal      asc   ', RealFreeMem=',00
TxMax       asc   ', MaxBlock=',00
TxComma2    asc   ', ',00
TxHandles   asc   ' handles.  By ID range (ID=norm/purgeable): ',00
TxXXX       asc   'xxx=',00
TxFiles     asc   'LOAD FILES IN MEMORY:  ',00
TxUnnamed   asc   '(unnamed)',00
TxTools     asc   'STARTED TOOLSETS:  ',00
TxV         asc   ' v',00
TxMisc      asc   'MISCELLANEOUS:  GS/OS v',00
TxROM       asc   ', ROM ID $',00
TxFeat      asc   ' & features $',00
TxKeyTr     asc   ',  key translation ',00
TxBattery   asc   'BATTERY RAM (non-255 values):  ',00

* The window (SuperConvert's DYNAMINFO $0008 and $0153).
SIParms     dw    $50,$2020
            adrl  0,0
            dw    0,0,0,0
            adrl  0
            dw    0,0,0,0,0,0,0,0,0,0
            adrl  0
            dw    0
            adrl  0,0,0
            dw    25,10,185,630
            adrl  $FFFFFFFF
            adrl  SICtls
            dw    $0003
SICtls      adrl  SICancel,SISave,SIPrint,0
SICancel    dw    9
            adrl  1
            dw    142,50,155,150
            adrl  $80000000
            dw    0,$3000
            adrl  0
            adrl  TxSICancel
            adrl  0
            db    $1B,$1B
            dw    0,0
SISave      dw    9
            adrl  2
            dw    142,230,155,390
            adrl  $80000000
            dw    0,$3000
            adrl  0
            adrl  TxSISave
            adrl  0
            db    'S','s'
            dw    $0100,$0100
SIPrint     dw    9
            adrl  3
            dw    142,470,155,570
            adrl  $80000000
            dw    0,$3000
            adrl  0
            adrl  TxSIPrint
            adrl  0
            db    'P','p'
            dw    $0100,$0100
SIStyle     adrl  $0800FFFE             ; Shaston, plain, 8
            dw    $0000,$FFFF           ; black on white
            adrl  0
TxSICancel  str   'Cancel'
TxSISave    str   'Save as text file'
TxSIPrint   str   'Print'
* The TextEdit control (DYNAMINFO $0058): its starting text (LETextBox2):
* the title in Shaston 16, then Shaston 8.
SITE        dw    17
            adrl  0
            dw    5,10,136,610
            adrl  $85000000
            dw    0,$7400
            adrl  0
            adrl  $40800000
            dw    $FFFF,$FFFF,$FFFF,$FFFF
            adrl  $FFFFFFFF
            dw    0
            adrl  0
            dw    0
            adrl  0
            dw    $0004
            adrl  SIText
            adrl  SITextEnd-SIText
            adrl  65000
SIText      db    $01,'F'
            dw    $FFFE
            db    $02,$10
            asc   'MegaconvertGS  System Info:',0D
            db    $01,'F'
            dw    $FFFE
            db    $00,$08
SITextEnd
