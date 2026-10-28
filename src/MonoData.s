* MonoData.s - the monochrome dialogs' menus, texts and arrow icon, from SuperConvert
* 4.0 (made by test/make_monodata.py).

* ToMono: horizontal size pop-up: b'##  Horizontal size:  \\N1\r--1X\\N1\r--2X\\N2\r--4X\\N4\r.\x00'
PopHSize    =     *
            hex   23232020486F72697A6F6E74616C2073697A653A20205C4E
            hex   310D2D2D31585C4E310D2D2D32585C4E320D2D2D34585C4E
            hex   340D2E00

* ToMono: vertical size pop-up: b'##  Vertical size:  \\N1\r--1X\\N1\r--2X\\N2\r--4X\\N4\r.\x00'
PopVSize    =     *
            hex   23232020566572746963616C2073697A653A20205C4E310D
            hex   2D2D31585C4E310D2D2D32585C4E320D2D2D34585C4E340D
            hex   2E00

* ToMono: rendering method pop-up: b'##  Rendering method:  \\N1\r--Error diffusion\\N1\r--Pattern di'
PopMethod   =     *
            hex   2323202052656E646572696E67206D6574686F643A20205C
            hex   4E310D2D2D4572726F7220646966667573696F6E5C4E310D
            hex   2D2D5061747465726E206469746865725C4E320D2D2D4861
            hex   6C66746F6E655C4E340D2D2D353025207468726573686F6C
            hex   645C4E330D2E00

* FromMono: aspect ratio pop-up: b'##  Aspect ratio:  \\N1\r--Square\\N1*Ss\r--Tall\\N2*Tt\r--Wide\\N3'
PopAspect   =     *
            hex   2323202041737065637420726174696F3A20205C4E310D2D
            hex   2D5371756172655C4E312A53730D2D2D54616C6C5C4E322A
            hex   54740D2D2D576964655C4E332A57770D2E00

* FromMono: scaling pop-up: b'##  Scaling:  \\N1\r--1:1\\N1*11\r--1:2\\N2*22\r--1:4\\N4*44\r.\x00'
PopScale    =     *
            hex   232320205363616C696E673A20205C4E310D2D2D313A315C
            hex   4E312A31310D2D2D313A325C4E322A32320D2D2D313A345C
            hex   4E342A34340D2E00

* FromMono: shrink as pop-up: b'##  Shrink as:  \\N1\r--Grayscale\\N1\r--Black & white (50% thre'
PopShrink   =     *
            hex   23232020536872696E6B2061733A20205C4E310D2D2D4772
            hex   61797363616C655C4E310D2D2D426C61636B202620776869
            hex   74652028353025207468726573686F6C64295C4E320D2D2D
            hex   42265720286C696E6520617274206F6E2077686974652062
            hex   61636B67726F756E64295C4E330D2D2D42265720286C696E
            hex   6520617274206F6E20626C61636B206261636B67726F756E
            hex   64295C4E340D2E00

* ToMono: the size text (28 characters, substitutions): b'Image will be *0 by *1*2. *3'
TxWillBe    =     *
            hex   496D6167652077696C6C206265202A30206279202A312A32
            hex   2E202A33

* FromMono: "Resulting image:": b'Resulting image:'
TxResult    =     *
            hex   526573756C74696E6720696D6167653A

* FromMono: the sizes text (62 characters, substitutions): b'Monochrome pixels\r*0 x *1\r\x01CUUResulting pixels\r*2 x *3*4*5*6'
TxPixels    =     *
            hex   4D6F6E6F6368726F6D6520706978656C730D2A302078202A
            hex   310D01435555526573756C74696E6720706978656C730D2A
            hex   322078202A332A342A352A362A37

* the SKIP ME check box: b'!SKIP ME: always use these options'
TxSkipMe    =     *
            hex   21534B4950204D453A20616C776179732075736520746865
            hex   7365206F7074696F6E73

* Info on options...: b'\x12Info on options...'
TxInfoOpt   =     *
            hex   12496E666F206F6E206F7074696F6E732E2E2E

* OK: b'\x02OK'
TxOKm       =     *
            hex   024F4B

* Cancel: b'\x06Cancel'
TxCancelm   =     *
            hex   0643616E63656C

* FromMono to screen: radio 16: b'\x08320 mode'
Tx320Mode   =     *
            hex   08333230206D6F6465

* FromMono to screen: radio 17: b'\x08640 mode'
Tx640Mode   =     *
            hex   08363430206D6F6465

* FromMono to true colour: radio 16: b'\x10320-sized pixels'
Tx320Pix    =     *
            hex   103332302D73697A656420706978656C73

* FromMono to true colour: radio 17: b'\x10640-sized pixels'
Tx640Pix    =     *
            hex   103634302D73697A656420706978656C73

* the screen image icon (16 x 10)
MIcScr      =     *
            hex   000028000A000800FFFFFFFFC0000000C37FFFF0
            hex   DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD
            hex   DDDDDDDDFFFFFFFF000000003FFFFFFF3FFFFFFF
            hex   3FFFFFFF3FFFFFFF3FFFFFFF3FFFFFFF3FFFFFFF
            hex   3FFFFFFF00000000

* the true colour image icon (16 x 10)
MIcTrue     =     *
            hex   000028000A000800FFFFFFFFFF7777FFFF4447FF
            hex   FF4447FFFF7777FFBBBBDDDD888BD111888BD111
            hex   BBBBDDDDFFFFFFFF0000000000FFFC0000FFFC00
            hex   00FFFC0000FFFC00FFFC3FFFFFFC3FFFFFFC3FFF
            hex   FFFC3FFF00000000

* the monochrome image icon (16 x 10)
MIcMono     =     *
            hex   000028000A000800FFFFFFFFFF00FF00FF00FF00
            hex   00FF00FF00FF00FFFF00FF00FF00FF0000FF00FF
            hex   00FF00FFFFFFFFFF00000000FFFFFFFFFFFFFFFF
            hex   FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
            hex   FFFFFFFF00000000

* the arrow between the icons (32 x 7)
IcArrowR    =     *
            hex   0000380007001000FFFFFFFFC0FFFFFFFFFFFFFF
            hex   F000FFFFFFFFFFFFFC0000FF0000000000000000
            hex   FFFFFFFFFC0000FFFFFFFFFFF000FFFFFFFFFFFF
            hex   C0FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
            hex   FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
            hex   FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
