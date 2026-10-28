* FilterMed.s - the median of nine bytes (V0-V8; 8-bit accumulator): 19
* compare-and-swaps, each putting the smaller value first (part of BMedian).
* The middle value ends in V0+4.
            lda   V0+1
            cmp   V0+2
            bcc   :m0
            beq   :m0
            xba
            lda   V0+2
            sta   V0+1
            xba
            sta   V0+2
:m0
            lda   V0+4
            cmp   V0+5
            bcc   :m1
            beq   :m1
            xba
            lda   V0+5
            sta   V0+4
            xba
            sta   V0+5
:m1
            lda   V0+7
            cmp   V0+8
            bcc   :m2
            beq   :m2
            xba
            lda   V0+8
            sta   V0+7
            xba
            sta   V0+8
:m2
            lda   V0+0
            cmp   V0+1
            bcc   :m3
            beq   :m3
            xba
            lda   V0+1
            sta   V0+0
            xba
            sta   V0+1
:m3
            lda   V0+3
            cmp   V0+4
            bcc   :m4
            beq   :m4
            xba
            lda   V0+4
            sta   V0+3
            xba
            sta   V0+4
:m4
            lda   V0+6
            cmp   V0+7
            bcc   :m5
            beq   :m5
            xba
            lda   V0+7
            sta   V0+6
            xba
            sta   V0+7
:m5
            lda   V0+1
            cmp   V0+2
            bcc   :m6
            beq   :m6
            xba
            lda   V0+2
            sta   V0+1
            xba
            sta   V0+2
:m6
            lda   V0+4
            cmp   V0+5
            bcc   :m7
            beq   :m7
            xba
            lda   V0+5
            sta   V0+4
            xba
            sta   V0+5
:m7
            lda   V0+7
            cmp   V0+8
            bcc   :m8
            beq   :m8
            xba
            lda   V0+8
            sta   V0+7
            xba
            sta   V0+8
:m8
            lda   V0+0
            cmp   V0+3
            bcc   :m9
            beq   :m9
            xba
            lda   V0+3
            sta   V0+0
            xba
            sta   V0+3
:m9
            lda   V0+5
            cmp   V0+8
            bcc   :m10
            beq   :m10
            xba
            lda   V0+8
            sta   V0+5
            xba
            sta   V0+8
:m10
            lda   V0+4
            cmp   V0+7
            bcc   :m11
            beq   :m11
            xba
            lda   V0+7
            sta   V0+4
            xba
            sta   V0+7
:m11
            lda   V0+3
            cmp   V0+6
            bcc   :m12
            beq   :m12
            xba
            lda   V0+6
            sta   V0+3
            xba
            sta   V0+6
:m12
            lda   V0+1
            cmp   V0+4
            bcc   :m13
            beq   :m13
            xba
            lda   V0+4
            sta   V0+1
            xba
            sta   V0+4
:m13
            lda   V0+2
            cmp   V0+5
            bcc   :m14
            beq   :m14
            xba
            lda   V0+5
            sta   V0+2
            xba
            sta   V0+5
:m14
            lda   V0+4
            cmp   V0+7
            bcc   :m15
            beq   :m15
            xba
            lda   V0+7
            sta   V0+4
            xba
            sta   V0+7
:m15
            lda   V0+4
            cmp   V0+2
            bcc   :m16
            beq   :m16
            xba
            lda   V0+2
            sta   V0+4
            xba
            sta   V0+2
:m16
            lda   V0+6
            cmp   V0+4
            bcc   :m17
            beq   :m17
            xba
            lda   V0+4
            sta   V0+6
            xba
            sta   V0+4
:m17
            lda   V0+4
            cmp   V0+2
            bcc   :m18
            beq   :m18
            xba
            lda   V0+2
            sta   V0+4
            xba
            sta   V0+2
:m18
