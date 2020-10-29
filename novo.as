CONST           EQU     b400h
PROB            EQU     62258d


ORIG            0000h



                MVI     R1, 4  ; altura
                MVI     R2, 5


Geracacto:             
                MVI     R4, 1
                AND     R5, R2, R4
                SHR     R2
                
                
                CMP     R5, R0
                BR.Z    .bitIf ; if bit(R5)
                
                MVI     R4, CONST
                XOR     R2, R2, R4  ; end if
                
.bitIf:         NOP

                MVI     R4, PROB
                CMP     R2, R4
                BR.NN   .ProbIf
                MVI     R3, 0
                
                JMP     R7
                
                
.ProbIf:        NOP

                DEC     R1
                AND     R3, R1, R2
                INC     R3
                INC     R1
                
                JMP     R7


Fim:            BR      Fim