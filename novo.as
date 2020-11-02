STACK_ORIGIN    EQU     3000h
RANDOM          EQU     b400h
PROB            EQU     62258d
CACTUS_HEIGHT   EQU     4h

                ORIG    0000h

seed            WORD    39263d ; this seed generates a 4 in the first try

                ORIG    4000h ; board
                
TERRAIN_START   WORD    4
VETOR           TAB     78
TERRAIN_END     WORD    3

                ORIG    0000h

                MVI     R6, STACK_ORIGIN
                MVI     R1, CACTUS_HEIGHT  ; altura

                JAL     geracacto

Fim:            BR      Fim


atualizajogo:   DEC     R6
                STOR    M[R6], R4
                DEC     R6
                STOR    M[R6], R5

                ADD     R4, R1, R2 ; R1 = 4000h R2 = 80
                DEC     R4 ; last element (R4) = R1 + R2 - 1
                
                LOAD    R5, M[R4]
                
                DEC     R6  ; Push R1
                STOR    M[R6], R1
                DEC     R6
                STOR    M[R6], R7
                
                MVI     R1, CACTUS_HEIGHT
                
                JAL     geracacto
                LOAD    R7, M[R6]
                INC     R6
                LOAD    R1, M[R1]
                INC     R6
                
                STOR    M[R4], R3
                
.loop:          DEC     R4
                LOAD    R2, M[R4]
                STOR    M[R4], R5
                MOV     R5, R2
                CMP     R4, R1
                BR.NN   .loop
                
                LOAD    R5, M[R6]
                INC     R6
                LOAD    R4, M[R6]
                INC     R6
                
                JMP     R7



geracacto:      ; PUSH R4 & R5
                DEC     R6
                STOR    M[R6], R4
                DEC     R6
                STOR    M[R6], R5

                MVI     R4, seed
                LOAD    R2, M[R4] ; load seed into R2
                
                MVI     R4, 1
                AND     R5, R2, R4 ; seed & 1
                SHR     R2
                
                
                CMP     R5, R0
                BR.Z    .bitIf ; if bit(R5)
                
                MVI     R4, RANDOM
                XOR     R2, R2, R4  ; end if
                
.bitIf:         MVI     R4, PROB
                
                CMP     R2, R4
                BR.NN   .probIf ; if x < 62258
                
                MVI     R3, 0
                BR      .funcEnd ; return 0
                
                
.probIf:        DEC     R1
                AND     R3, R1, R2
                INC     R3
                INC     R1
                ; return (x & R1 - 1) + 1
                
.funcEnd:       ; POP R5 & R4
                LOAD    R5, M[R6]
                INC     R6
                LOAD    R4, M[R6]
                INC     R6
                
                JMP     R7 
; end geracacto
