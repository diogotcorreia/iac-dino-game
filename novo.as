;=================================================================
; CONSTANTS
;-----------------------------------------------------------------
; GAME
TERM_TERRAIN    EQU     1900h ; line 25, column 0
TERRAIN_SIZE    EQU     80d   ; width of terminal
STACK_ORIGIN    EQU     3000h
RANDOM          EQU     b400h
PROB            EQU     62258d
CACTUS_HEIGHT   EQU     4h    ; maximum cactus height
DINO_MAX_HEIGHT EQU     6h    ; jump height
DINO_COLUMN     EQU     8h    ; dino offset from left
; TEXT WINDOW
TERM_READ       EQU     FFFFh ; read characters
TERM_WRITE      EQU     FFFEh ; write characters
TERM_STATUS     EQU     FFFDh ; status (0-no key pressed, 1-key pressed)
TERM_CURSOR     EQU     FFFCh ; position the cursor
TERM_COLOR      EQU     FFFBh ; change the colors
; 7 segment display
DISP7_D0        EQU     FFF0h
DISP7_D1        EQU     FFF1h
DISP7_D2        EQU     FFF2h
DISP7_D3        EQU     FFF3h
DISP7_D4        EQU     FFEEh
DISP7_D5        EQU     FFEFh
; TIMER
TIMER_CONTROL   EQU     FFF7h
TIMER_COUNTER   EQU     FFF6h
TIMER_SETSTART  EQU     1
TIMER_INTERVAL  EQU     1
; INTERRUPTIONS
INT_MASK        EQU     FFFAh
INT_MASK_VAL    EQU     8001h ; 1000 0000 0000 0001 b

;=================================================================
; Program global variables
;-----------------------------------------------------------------
                ORIG    0000h

SEED            WORD    39263d ; this seed generates a 4 in the first try
TIMER_TICK      WORD    0      ; indicates the number of unattended
                               ; timer interruptions

GAME_START      WORD    0      ; 0 if game stopped, 1 if game on-going
SCORE           WORD    0      ; player score

DINO_HEIGHT     WORD    0      ; current height of the dino

                ORIG    4000h ; board
                
TERRAIN_START   TAB     TERRAIN_SIZE

;=================================================================
; MAIN: the starting point of your program
;-----------------------------------------------------------------
                ORIG    0000h

                ; INIT STACK POINTER
                MVI     R6, STACK_ORIGIN
                ; CONFIGURE TIMER ROUNTINES
                ; interrupt mask
                MVI     R1, INT_MASK
                MVI     R2, INT_MASK_VAL
                STOR    M[R1], R2
                ; enable interruptions
                ENI
                
CheckStart:     MVI     R4, GAME_START  ; hold off game start until
                LOAD    R1, M[R4]       ; the zero key is pressed
                CMP     R1, R0
                BR.Z    CheckStart

                ; START TIMER
                MVI     R2, TIMER_INTERVAL
                MVI     R1, TIMER_COUNTER
                STOR    M[R1], R2          ; set timer to handle game lifecycle
                MVI     R1, TIMER_TICK
                STOR    M[R1], R0          ; clear all timer ticks
                MVI     R1, TIMER_CONTROL
                MVI     R2, TIMER_SETSTART
                STOR    M[R1], R2          ; start timer
                
                ; WAIT FOR EVENT (TIMER/KEY)
                MVI     R5, TIMER_TICK
                
mainLoop:       LOAD    R1, M[R5]
                CMP     R1, R0
                JAL.NZ  lifecycle ; if timer tick is pending, handle it
                
                
                MVI     R4, GAME_START
                LOAD    R1, M[R1]
                CMP     R1, R0
                BR.Z    CheckStart  ; stop game if game has ended
                BR      mainLoop

;=================================================================
; lifecycle: function that handles every game tick (~0.3 sec)
;-----------------------------------------------------------------
lifecycle:      ; decrement TIMER_TICK
                MVI     R2, TIMER_TICK
                DSI     ; critical region: if an interruption occurs,
                        ; value might become wrong
                LOAD    R1, M[R2]
                DEC     R1
                STOR    M[R2], R1
                ENI
                
                DEC     R6
                STOR    M[R6], R7 ; PUSH R7
                
                MVI     R1, TERRAIN_START  ; altura
                MVI     R2, TERRAIN_SIZE ; terrain length

                JAL     atualizajogo
                
                JAL     PRINT_TERRAIN
                
                MVI     R1, DINO_HEIGHT
                LOAD    R1, M[R1]
                JAL     PRINT_DINO
                
                JAL     PROCESS_TIMER_EVENT
                

                LOAD    R7, M[R6]
                INC     R6
                
                JMP     R7

;=================================================================
; atualizajogo: shift the terrain to the left and add new cactus
;-----------------------------------------------------------------
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

;=================================================================
; geracacto: pseudo-randomly generate cactus heights
;-----------------------------------------------------------------
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

;=================================================================
; Print Terrain: Clear the terminal and print the terrain with cactus
;-----------------------------------------------------------------
                  
PRINT_TERRAIN:  DEC     R6         ; PUSH R7, R4 & R5
                STOR    M[R6], R7
                DEC     R6
                STOR    M[R6], R4
                DEC     R6
                STOR    M[R6], R5
                
                MVI     R1, TERM_CURSOR
                MVI     R2, FFFFh ; clear terminal
                STOR    M[R1], R2
                MVI     R2, TERM_TERRAIN  ; position cursor at line 25
                STOR    M[R1], R2
                
                ; prepare loop variables
                MVI     R1, TERM_WRITE
                MOV     R4, R0
                MVI     R5, TERRAIN_SIZE
                

.loop:          ; load terrain value at R4
                MVI     R3, TERRAIN_START
                ADD     R3, R3, R4
                LOAD    R2, M[R3]
                
                CMP     R2, R0
                BR.Z    .ground
                ; if cactus
                MVI     R3, '┴'
                STOR    M[R1], R3
                
                ; PUSH R1 & R3
                DEC     R6
                STOR    M[R6], R1
                DEC     R6
                STOR    M[R6], R3
                ; R1 - column index, R2 - cactus value
                MOV     R1, R4
                JAL     PRINT_CACTUS
                
                ; restore cursor location
                MVI     R1, TERM_CURSOR
                MVI     R2, TERM_TERRAIN
                ADD     R2, R2, R4
                INC     R2
                STOR    M[R1], R2
                
                ; POP R1 & R3
                LOAD    R3, M[R6]
                INC     R6
                LOAD    R1, M[R6]
                INC     R6
                
                BR      .endif
                
                ; if not cactus
.ground:        MVI     R3, '─'
                STOR    M[R1], R3
                
.endif:         INC     R4

                CMP     R4, R5 ; loop until the end of the terrain
                BR.N    .loop
                
                ; POP R5, R4 & R7
                LOAD    R5, M[R6]
                INC     R6
                LOAD    R4, M[R6]
                INC     R6
                LOAD    R7, M[R6]
                INC     R6
                JMP     R7

;=================================================================
; Print cactus  function that prints a cactus at a specific column
;               with a specific height
;   R1 -> column
;   R2 -> height
;-----------------------------------------------------------------
PRINT_CACTUS:   DEC     R6 ; PUSH R7, R4, R5
                STOR    M[R6], R7
                DEC     R6
                STOR    M[R6], R4
                DEC     R6
                STOR    M[R6], R5
                
                ; get terminal cursor position
                MVI     R5, TERM_TERRAIN
                ADD     R5, R5, R1
                
.loop:          MVI     R4, 0100h
                SUB     R5, R5, R4 ; go up one column
                
                MVI     R4, TERM_CURSOR
                STOR    M[R4], R5
                
                ; write cactus
                MVI     R4, TERM_WRITE
                MVI     R3, '│'
                STOR    M[R4], R3
                
                DEC     R2
                CMP     R2, R0
                BR.NZ   .loop ; repeat for cactus height
                
                ; POP R5, R4 & R7
                LOAD    R5, M[R6]
                INC     R6
                LOAD    R4, M[R6]
                INC     R6
                LOAD    R7, M[R6]
                INC     R6
                JMP     R7
                
;=================================================================
; PRINT_DINO:   function that prints the player at specific height
;   R1 -> height
;-----------------------------------------------------------------
PRINT_DINO:     
                MVI     R2, 8
.columnLoop:    SHL     R1 ; make R1 a column by SHL 8 times
                DEC     R2
                BR.NZ   .columnLoop
                NEG     R1 ; neg R1 so it decrements columns

                MVI     R2, TERM_TERRAIN
                ADD     R1, R1, R2 ; get terrain location
                MVI     R2, 0100h
                SUB     R1, R1, R2 ; go up one line
                MVI     R2, DINO_COLUMN ; add horizontal offset
                ADD     R1, R1, R2
                
                
                MVI     R2, TERM_CURSOR
                STOR    M[R2], R1  ; set cursor to dino position
                
                MVI     R2, TERM_WRITE
                MVI     R1, 'ƒ'
                STOR    M[R2], R1
                
                JMP     R7
                


;=================================================================
; PROCESS_TIMER_EVENT: Checks if the game has started and changes,
; starting the timer and changing the score value, if it has, by 
; one, every 0.3 seconds
;-----------------------------------------------------------------
PROCESS_TIMER_EVENT:

                ; UPDATE TIME
                MVI     R1,SCORE
                LOAD    R2,M[R1]
                INC     R2
                STOR    M[R1],R2
                ; SHOW TIME ON DISP7_D0
                MVI     R3,fh
                AND     R3,R2,R3
                MVI     R1,DISP7_D0
                STOR    M[R1],R3
                ; SHOW TIME ON DISP7_D1
                SHR     R2
                SHR     R2
                SHR     R2
                SHR     R2
                MVI     R3,fh
                AND     R3,R2,R3
                MVI     R1,DISP7_D1
                STOR    M[R1],R3
                ; SHOW TIME ON DISP7_D2
                SHR     R2
                SHR     R2
                SHR     R2
                SHR     R2
                MVI     R3,fh
                AND     R3,R2,R3
                MVI     R1,DISP7_D2
                STOR    M[R1],R3
                ; SHOW TIME ON DISP7_D3
                SHR     R2
                SHR     R2
                SHR     R2
                SHR     R2
                MVI     R3,fh
                AND     R3,R2,R3
                MVI     R1,DISP7_D3
                STOR    M[R1],R3
                
                JMP     R7




;*****************************************************************
; AUXILIARY INTERRUPT SERVICE ROUTINES
;*****************************************************************
AUX_TIMER_ISR:  ; SAVE CONTEXT
                DEC     R6
                STOR    M[R6], R1
                DEC     R6
                STOR    M[R6], R2
                ; RESTART TIMER
                MVI     R2, TIMER_INTERVAL
                MVI     R1, TIMER_COUNTER
                STOR    M[R1], R2          ; set timer to count value
                MVI     R1, TIMER_CONTROL
                MVI     R2, TIMER_SETSTART
                STOR    M[R1], R2          ; start timer
                ; INC TIMER FLAG
                MVI     R2, TIMER_TICK
                LOAD    R1, M[R2]
                INC     R1
                STOR    M[R2], R1
                ; RESTORE CONTEXT
                LOAD    R2, M[R6]
                INC     R6
                LOAD    R1, M[R6]
                INC     R6
                JMP     R7
                

;*****************************************************************
; INTERRUPT SERVICE ROUTINES
;*****************************************************************
                ORIG    7FF0h
TIMER_ISR:      ; SAVE CONTEXT
                DEC     R6
                STOR    M[R6], R7
                ; CALL AUXILIARY FUNCTION
                JAL     AUX_TIMER_ISR
                ; RESTORE CONTEXT
                LOAD    R7, M[R6]
                INC     R6
                RTI


                ORIG    7F00h
KEYZERO:        ; SAVE CONTEXT
                DEC     R6
                STOR    M[R6], R1
                DEC     R6
                STOR    M[R6], R2
                ; START GAME
                MVI     R1, GAME_START
                MVI     R2, 1
                STOR    M[R1], R2
                ; RESTORE CONTEXT
                LOAD    R2, M[R6]
                INC     R6
                LOAD    R1, M[R6]
                INC     R6
                RTI
