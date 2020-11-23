;=================================================================
; CONSTANTS
;-----------------------------------------------------------------
; GAME
STACK_ORIGIN    EQU     3000h
RANDOM          EQU     b400h
PROB            EQU     62258d
CACTUS_HEIGHT   EQU     4h
; TIMER
TIMER_CONTROL   EQU     FFF7h
TIMER_COUNTER   EQU     FFF6h
TIMER_SETSTART  EQU     1
TIMER_INTERVAL  EQU     10
; INTERRUPTIONS
INT_MASK        EQU     FFFAh
INT_MASK_VAL    EQU     8000h ; 1000 0000 0000 0000 b

;=================================================================
; Program global variables
;-----------------------------------------------------------------
                ORIG    0000h

SEED            WORD    39263d ; this seed generates a 4 in the first try
TIMER_TICK      WORD    0      ; indicates the number of unattended
                               ; timer interruptions

                ORIG    4000h ; board
                
TERRAIN_START   TAB     80

;=================================================================
; MAIN: the starting point of your program
;-----------------------------------------------------------------
                ORIG    0000h

                ; INIT STACK POINTER
                MVI     R6, STACK_ORIGIN
                ; CONFIGURE TIMER ROUNTINES
                ; interrupt mask
                MVI     R1,INT_MASK
                MVI     R2,INT_MASK_VAL
                STOR    M[R1],R2
                ; enable interruptions
                ENI
                
                ; START TIMER
                MVI     R2,TIMER_INTERVAL
                MVI     R1,TIMER_COUNTER
                STOR    M[R1],R2          ; set timer to count 10x100ms
                MVI     R1,TIMER_TICK
                STOR    M[R1],R0          ; clear all timer ticks
                MVI     R1,TIMER_CONTROL
                MVI     R2,TIMER_SETSTART
                STOR    M[R1],R2          ; start timer
                
                ; WAIT FOR EVENT (TIMER/KEY)
                ;MVI     R4,TERM_STATUS
                MVI     R5,TIMER_TICK
                
mainLoop:       LOAD    R1,M[R5]
                CMP     R1,R0
                JAL.NZ  lifecycle
                
                BR      mainLoop

;=================================================================
; lifecycle: function that handles every game tick (~1 sec)
;-----------------------------------------------------------------
lifecycle:      ; DEC TIMER_TICK
                MVI     R2, TIMER_TICK
                DSI     ; critical region: if an interruption occurs, value might become wrong
                LOAD    R1, M[R2]
                DEC     R1
                STOR    M[R2], R1
                ENI
                
                DEC     R6
                STOR    M[R6], R7
                
                MVI     R1, TERRAIN_START  ; altura
                MVI     R2, 80d ; terrain length

                JAL     atualizajogo

                LOAD    R7, M[R6]
                INC     R6
                
                JMP     R7

atualizajogo:   DEC     R6         ; PUSH R4 & R5
                STOR    M[R6], R4
                DEC     R6
                STOR    M[R6], R5

                ADD     R4, R1, R2 ; R1 = 4000h R2 = 80
                DEC     R4 ; last element (R4) = R1 + R2 - 1
                
                LOAD    R5, M[R4] ; R5 = last element value
                
                DEC     R6       ; PUSH R1 & R7
                STOR    M[R6], R1
                DEC     R6
                STOR    M[R6], R7
                
                MVI     R1, CACTUS_HEIGHT
                JAL     geracacto
                
                LOAD    R7, M[R6]  ; POP R7 & R1
                INC     R6
                LOAD    R1, M[R6]
                INC     R6
                
                STOR    M[R4], R3  ; save value from geracacto
                
.loop:          ; shift all terrain values backwards
                ; R2 -> original value
                ; R5 -> value to replace with
                DEC     R4
                LOAD    R2, M[R4]
                STOR    M[R4], R5
                MOV     R5, R2
                CMP     R4, R1
                BR.P    .loop
                
                ; POP R5 & R4
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

                MVI     R4, SEED
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
                BR.NC   .probIf ; if x < 62258
                
                MVI     R3, 0
                BR      .funcEnd ; return 0
                
                
.probIf:        DEC     R1
                AND     R3, R1, R2
                INC     R3
                ; return (x & R1 - 1) + 1
                
.funcEnd:       MVI     R4, SEED
                STOR    M[R4], R2

                ; POP R5 & R4
                LOAD    R5, M[R6]
                INC     R6
                LOAD    R4, M[R6]
                INC     R6
                
                JMP     R7 
; end geracacto

;*****************************************************************
; AUXILIARY INTERRUPT SERVICE ROUTINES
;*****************************************************************
AUX_TIMER_ISR:  ; SAVE CONTEXT
                DEC     R6
                STOR    M[R6],R1
                DEC     R6
                STOR    M[R6],R2
                ; RESTART TIMER
                MVI     R2,TIMER_INTERVAL
                MVI     R1,TIMER_COUNTER
                STOR    M[R1],R2          ; set timer to count value
                MVI     R1,TIMER_CONTROL
                MVI     R2,TIMER_SETSTART
                STOR    M[R1],R2          ; start timer
                ; INC TIMER FLAG
                MVI     R2,TIMER_TICK
                LOAD    R1,M[R2]
                INC     R1
                STOR    M[R2],R1
                ; RESTORE CONTEXT
                LOAD    R2,M[R6]
                INC     R6
                LOAD    R1,M[R6]
                INC     R6
                JMP     R7
                

;*****************************************************************
; INTERRUPT SERVICE ROUTINES
;*****************************************************************
                ORIG    7FF0h
TIMER_ISR:      ; SAVE CONTEXT
                DEC     R6
                STOR    M[R6],R7
                ; CALL AUXILIARY FUNCTION
                JAL     AUX_TIMER_ISR
                ; RESTORE CONTEXT
                LOAD    R7,M[R6]
                INC     R6
                RTI
