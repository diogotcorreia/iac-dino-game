RANDOM          EQU     b400h
PROB            EQU     62258d

ORIG            0000h

seed            WORD    39263d ; this seed generates a 4 in the first try


ORIG            0000h

                MVI     R1, 4  ; altura

                JAL     geracacto

Fim:            BR      Fim

geracacto:      MVI     R4, seed
                LOAD    R2, M[R4] ; load seed into R2
                
                MVI     R4, 1
                AND     R5, R2, R4 ; seed & 1
                SHR     R2
                
                
                CMP     R5, R0
                BR.Z    .bitIf ; if bit(R5)
                
                MVI     R4, RANDOM
                XOR     R2, R2, R4  ; end if
                
.bitIf:         NOP

                MVI     R4, PROB
                
                CMP     R2, R4
                BR.NN   .probIf ; if x < 62258
                
                MVI     R3, 0
                JMP     R7 ; return 0
                
                
.probIf:        DEC     R1
                AND     R3, R1, R2
                INC     R3
                INC     R1
                
                JMP     R7 ; return (x & R1 - 1) + 1
