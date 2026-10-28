* MegaconvertGS macros: toolbox and GS/OS calls, and parameter pushes.

* Toolbox call: Tool $nnmm (call number in X, then the dispatcher).
Tool        MAC
            ldx   #]1
            jsl   $E10000
            <<<

* Push a long immediate value or address (two words, high word first).
PushLong    MAC
            pea   ^]1
            pea   ]1
            <<<

* Push the long stored at a label.
PushLongAt  MAC
            lda   ]1+2
            pha
            lda   ]1
            pha
            <<<

* GS/OS class 1 call: GSOS callnumber;parameterblock
GSOS        MAC
            jsl   $E100A8
            da    ]1
            adrl  ]2
            <<<
