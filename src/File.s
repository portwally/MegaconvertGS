*-------------------------------------------------------------
* File.s - reading and writing whole files with GS/OS
*-------------------------------------------------------------

* ReadFile: reads a whole file into a new handle.
*   in:  PathPtr = pointer to a GS/OS string (length word, then characters)
*   out: carry clear and FileH, FileP, FileLen set
*        carry set, A = GS/OS or Memory Manager error
ReadFile    lda   PathPtr
            sta   OpenParms+4
            lda   PathPtr+2
            sta   OpenParms+6
            GSOS  _OpenGS;OpenParms
            bcc   :open
            rts
:open       lda   OpenParms+14          ; remember the file type for DecodeFile
            sta   FileType
            lda   OpenParms+16
            sta   FileAux
            lda   OpenParms+2
            sta   EOFParms+2
            sta   ReadParms+2
            sta   CloseParms+2
            GSOS  _GetEOFGS;EOFParms
            bcs   :errClose
            lda   EOFParms+4
            ora   EOFParms+6
            bne   :size
            lda   #$004C                ; empty file: treat as end of file
            bra   :errClose
:size       pha                         ; result: handle
            pha
            PushLongAt EOFParms+4
            lda   UserID
            pha
            pea   attrFile              ; files may be larger than one bank
            PushLong 0
            Tool  _NewHandle
            tax                         ; keep the error, carry is untouched
            pla
            sta   FileH
            pla
            sta   FileH+2
            txa
            bcs   :errClose
            jsr   DerefFile
            lda   FileP
            sta   ReadParms+4
            lda   FileP+2
            sta   ReadParms+6
            lda   EOFParms+4
            sta   ReadParms+8
            sta   FileLen
            lda   EOFParms+6
            sta   ReadParms+10
            sta   FileLen+2
            GSOS  _ReadGS;ReadParms
            bcs   :errFree
            GSOS  _CloseGS;CloseParms
            clc
            rts
:errFree    pha
            jsr   FreeFile
            pla
:errClose   pha
            GSOS  _CloseGS;CloseParms
            pla
            sec
            rts

* DerefFile: FileP = master pointer of FileH.
DerefFile   lda   FileH
            sta   p0
            lda   FileH+2
            sta   p0+2
            lda   [p0]
            sta   FileP
            ldy   #2
            lda   [p0],y
            sta   FileP+2
            rts

* FreeFile: disposes of FileH, if there is one.
FreeFile    lda   FileH
            ora   FileH+2
            beq   :none
            PushLongAt FileH
            Tool  _DisposeHandle
            stz   FileH
            stz   FileH+2
:none       rts

* WriteFile: replaces a file with new contents.
*   in:  PathPtr, WType (file type), WAux (aux type, long), WData (pointer), WLen (long)
*   out: carry clear, or carry set and A = GS/OS error
WriteFile   lda   PathPtr
            sta   DestroyParms+2
            sta   CreateParms+2
            sta   OpenParms+4
            lda   PathPtr+2
            sta   DestroyParms+4
            sta   CreateParms+4
            sta   OpenParms+6
            GSOS  _DestroyGS;DestroyParms   ; no file yet is fine
            lda   WType
            sta   CreateParms+8
            lda   WAux
            sta   CreateParms+10
            lda   WAux+2
            sta   CreateParms+12
            GSOS  _CreateGS;CreateParms
            bcs   :err
            GSOS  _OpenGS;OpenParms
            bcs   :err
            lda   OpenParms+2
            sta   WriteParms+2
            sta   CloseParms+2
            lda   WData
            sta   WriteParms+4
            lda   WData+2
            sta   WriteParms+6
            lda   WLen
            sta   WriteParms+8
            lda   WLen+2
            sta   WriteParms+10
            GSOS  _WriteGS;WriteParms
            php
            pha
            GSOS  _CloseGS;CloseParms
            pla
            plp
            rts
:err        sec
            rts

* NewBuffer: allocates a locked block.
*   in:  n0 = size
*   out: carry clear, n1 = handle, p0 = pointer; or carry set
NewBuffer   pha
            pha
            PushLongAt n0
            lda   UserID
            pha
            pea   attrBuffer
            PushLong 0
            Tool  _NewHandle
            tax
            pla
            sta   n1
            pla
            sta   n1+2
            txa
            bcs   :err
            lda   n1
            sta   p0
            lda   n1+2
            sta   p0+2
            lda   [p0]
            tax
            ldy   #2
            lda   [p0],y
            sta   p0+2
            stx   p0
            clc
:err        rts

*-------------------------------------------------------------
* GS/OS parameter blocks
*-------------------------------------------------------------
OpenParms   dw    7                     ; pCount
            dw    0                     ; refNum
            adrl  0                     ; pathname
            dw    0                     ; request access: whatever is allowed
            dw    0                     ; resource number: the data fork
            dw    0                     ; access (returned)
            dw    0                     ; file type (returned)
            adrl  0                     ; aux type (returned)
EOFParms    dw    2
            dw    0                     ; refNum
            adrl  0                     ; eof
ReadParms   dw    4
            dw    0                     ; refNum
            adrl  0                     ; data buffer
            adrl  0                     ; request count
            adrl  0                     ; transfer count
WriteParms  dw    4
            dw    0
            adrl  0
            adrl  0
            adrl  0
CloseParms  dw    1
            dw    0
DestroyParms dw   1
            adrl  0                     ; pathname
CreateParms dw    4
            adrl  0                     ; pathname
            dw    $00C3                 ; access: read, write, rename, destroy
            dw    0                     ; file type
            adrl  0                     ; aux type

PathPtr     adrl  0
FileH       adrl  0
FileP       adrl  0
FileLen     adrl  0
FileType    dw    0
FileAux     dw    0                     ; low word of the aux type
WType       dw    0
WAux        adrl  0
WData       adrl  0
WLen        adrl  0
