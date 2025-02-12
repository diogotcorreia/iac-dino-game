;=================================================================
; CONSTANTS
;-----------------------------------------------------------------
; GAME
TERM_TERRAIN    EQU     1900h ; line 25, column 0
TERRAIN_SIZE    EQU     80d   ; width of terminal
STACK_ORIGIN    EQU     3000h
RANDOM          EQU     b400h ; value used in geracacto
PROB            EQU     62258d ; probability used in geracacto
CACTUS_HEIGHT   EQU     4h    ; maximum cactus height
DINO_MAX_HEIGHT EQU     6h    ; jump height
DINO_COLUMN     EQU     8h    ; dino offset from left
DINO_MAX_SPEED  EQU     1h    ; dino max absolute speed
GAME_OVER_POS   EQU     0623h ; position to write 'game over'
; TEXT WINDOW
TERM_WRITE      EQU     FFFEh ; write characters
TERM_CURSOR     EQU     FFFCh ; position the cursor
TERM_COLOR      EQU     FFFBh ; change the colors
TERM_DRAW_START EQU     1200h ; position at which to paint every lifecycle
TERM_COUNT_LC   EQU     0230h ; number of characters to paint at every lifecycle
TERM_HEIGHT     EQU     2Dh   ; total number of lines in the terminal
; TERMINAL CUSTOMIZATION
SKY_COLOR       EQU     1bffh ; color to paint the sky
GROUND_CHAR     EQU     ' ' ; ground and sky character
GROUND_COLOR    EQU     daffh ; color to paint the ground
GROUND_LINES    EQU     15h ; count of ground lines + 1
CACTUS_CHAR     EQU     '╢'
CACTUS_COLOR    EQU     1b30h
CACTUS_TOP_CHAR EQU     '╬'   ; character of the top of the cactus
CACTUS_TOP_CLR  EQU     1be1h ; color of the top character of the cactus
DINO_CHAR       EQU     'ƒ'
DINO_COLOR      EQU     1b00h
GAME_OVER_COLOR EQU     1b00h ; game over text color
; 7 segment display
DISP7_D0        EQU     FFF0h
DISP7_D1        EQU     FFF1h
DISP7_D2        EQU     FFF2h
DISP7_D3        EQU     FFF3h
DISP7_D4        EQU     FFEEh
DISP7_D5        EQU     FFEFh
SCORE_DISP_NUM  EQU     6    ; number of 7 segment displays
DECIMAL_BASE    EQU     10d
; TIMER
TIMER_CONTROL   EQU     FFF7h ; enable or disable timer
TIMER_COUNTER   EQU     FFF6h ; set timer delay
TIMER_SETSTART  EQU     1
TIMER_SETSTOP   EQU     0
TIMER_INTERVAL  EQU     1 ; game lifecycle delay = 100ms
; INTERRUPTIONS
INT_MASK        EQU     FFFAh
INT_MASK_VAL    EQU     8009h ; 1000 0000 0000 1001 b

;=================================================================
; Program global variables
;-----------------------------------------------------------------
                ORIG    0000h

SEED            WORD    39263d ; this seed generates a 4 in the first try
TIMER_TICK      WORD    0      ; indicates the number of unattended
                               ; timer interruptions

GAME_START      WORD    0      ; 0 if game stopped, 1 if game on-going
SCORE           WORD    0      ; player score

DINO_HEIGHT     WORD    0       ; current height of the dino
DINO_SPEED      WORD    0       ; current speed of the dino (0 = stopped)
GAME_OVER_MSG   STR     'GAME  OVER', 0

; put all displays in a vector so we can loop through them
SCORE_DISP      STR     DISP7_D0, DISP7_D1, DISP7_D2, DISP7_D3, DISP7_D4, DISP7_D5

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

                ; paint static background on game start
                JAL     PRINT_TERRAIN_STATIC

                ; Reset dino
                MVI     R2, DINO_HEIGHT
                STOR    M[R2], R0
                MVI     R2, DINO_SPEED
                STOR    M[R2], R0
                
                ; WAIT FOR EVENT (TIMER/KEY)
                MVI     R4, GAME_START
                MVI     R5, TIMER_TICK
                
mainLoop:       LOAD    R1, M[R5]
                CMP     R1, R0
                JAL.NZ  lifecycle ; if timer tick is pending, handle it

                LOAD    R1, M[R4]
                CMP     R1, R0
                BR.Z    CheckStart  ; stop game if game has ended
                BR      mainLoop

;=================================================================
; lifecycle: function that handles every game tick (~0.1 sec)
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

                JAL     GRAVITY_LC
                
                JAL     PRINT_TERRAIN
                
                MVI     R1, DINO_HEIGHT
                LOAD    R1, M[R1]
                JAL     PRINT_DINO
                
                JAL     INCREMENT_SCORE
                
                JAL     CHECK_COLLISIONS
                CMP     R3, R0
                BR.Z    .notGameOver
                JAL     GAME_OVER

.notGameOver:
                LOAD    R7, M[R6]
                INC     R6
                
                JMP     R7

;=================================================================
; atualizajogo: shift the terrain to the left and add new cactus
;-----------------------------------------------------------------
atualizajogo:   DEC     R6         ; PUSH R4, R5 & R7
                STOR    M[R6], R4
                DEC     R6
                STOR    M[R6], R5
                DEC     R6
                STOR    M[R6], R7

                ADD     R4, R1, R2 ; R1 = 4000h R2 = 80
                DEC     R4 ; last element (R4) = R1 + R2 - 1
                
                LOAD    R5, M[R4] ; R5 = last element value
                
                DEC     R6       ; PUSH R1
                STOR    M[R6], R1
                
                MVI     R1, CACTUS_HEIGHT
                JAL     geracacto
                
                LOAD    R1, M[R6] ; POP R1
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
                
                ; POP R7, R5 & R4
                LOAD    R7, M[R6]  
                INC     R6
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
; Print Terrain: Print the background on the dynamic area and all cactus
;-----------------------------------------------------------------
PRINT_TERRAIN:  DEC     R6         ; PUSH R7, R4 & R5
                STOR    M[R6], R7
                DEC     R6
                STOR    M[R6], R4
                DEC     R6
                STOR    M[R6], R5
                
                MVI     R1, TERM_CURSOR
                MVI     R2, TERM_DRAW_START ; move to drawing position
                STOR    M[R1], R2

                MVI     R1, TERM_COLOR
                MVI     R2, SKY_COLOR ; change writing color to sky
                STOR    M[R1], R2

                ; prepare loop variables
                MVI     R1, TERM_WRITE
                MVI     R2, TERM_COUNT_LC
                MVI     R3, GROUND_CHAR

                ; print sky on dynamic area
.terrainLoop:   STOR    M[R1], R3
                DEC     R2
                BR.NZ   .terrainLoop

                ; print all cactus
                MOV     R4, R0
                MVI     R5, TERRAIN_SIZE
.loop:          ; load terrain value at R4
                MVI     R3, TERRAIN_START
                ADD     R3, R3, R4
                LOAD    R2, M[R3]
                
                CMP     R2, R0
                BR.Z    .ground
                ; if cactus
                
                ; R1 - column index, R2 - cactus value
                MOV     R1, R4
                JAL     PRINT_CACTUS
                
.ground:        INC     R4

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
; Print Terrain Static: Clear the terminal and paint the background
;                       for the game.
;-----------------------------------------------------------------
PRINT_TERRAIN_STATIC:
                DEC     R6
                STOR    M[R6], R4  ; PUSH R4 & R5
                DEC     R6
                STOR    M[R6], R5
                
                MVI     R1, TERM_CURSOR
                MVI     R2, FFFFh ; clear terminal
                STOR    M[R1], R2
                STOR    M[R1], R0 ; move to first position

                MVI     R1, TERM_COLOR
                MVI     R2, SKY_COLOR
                STOR    M[R1], R2

                ; prepare loop variables
                MVI     R1, TERM_WRITE
                MVI     R2, GROUND_LINES ; know when to change colors
                MVI     R3, GROUND_CHAR
                MVI     R4, TERM_HEIGHT

                ; print sky and ground
.terrainLoop:   MVI     R5, TERRAIN_SIZE

.lineLoop:      STOR    M[R1], R3
                DEC     R5
                BR.NZ   .lineLoop

                CMP     R4, R2
                BR.NZ   .loopEnd
                MVI     R1, TERM_COLOR
                MVI     R3, GROUND_COLOR
                STOR    M[R1], R3
                ; restore R1 & R3
                MVI     R1, TERM_WRITE
                MVI     R3, GROUND_CHAR

.loopEnd:       DEC     R4
                BR.NZ   .terrainLoop

                ; POP R5, R4
                LOAD    R5, M[R6]
                INC     R6
                LOAD    R4, M[R6]
                INC     R6
                JMP     R7

;=================================================================
; Print cactus: function that prints a cactus at a specific column
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
                SUB     R5, R5, R4 ; go up one line
                
                MVI     R4, TERM_CURSOR
                STOR    M[R4], R5

                MVI     R4, TERM_COLOR

                DEC     R2
                BR.Z    .topCactus
                ; if not top of cactus
                MVI     R3, CACTUS_COLOR
                STOR    M[R4], R3

                MVI     R3, CACTUS_CHAR
                BR      .write
                
.topCactus:     ; if top of cactus
                MVI     R3, CACTUS_TOP_CLR
                STOR    M[R4], R3

                MVI     R3, CACTUS_TOP_CHAR
                
.write:         ; write cactus
                MVI     R4, TERM_WRITE
                STOR    M[R4], R3
                
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

                MVI     R2, TERM_COLOR
                MVI     R1, DINO_COLOR
                STOR    M[R2], R1
                
                MVI     R2, TERM_WRITE
                MVI     R1, DINO_CHAR
                STOR    M[R2], R1
                
                JMP     R7
                


;=================================================================
; INCREMENT_SCORE: Increments the score by one and updates
;                  the 7-segment display with the new score
;-----------------------------------------------------------------
INCREMENT_SCORE:
                ; SAVE CONTEXT
                DEC     R6
                STOR    M[R6], R4
                DEC     R6
                STOR    M[R6], R5
                DEC     R6
                STOR    M[R6], R7

                ; UPDATE TIME
                MVI     R1, SCORE
                LOAD    R2, M[R1]
                INC     R2
                STOR    M[R1], R2
                                
                MOV     R1, R2

                ; prepare loop variables
                MVI     R4, SCORE_DISP
                MVI     R5, SCORE_DISP_NUM
.dispLoop:
                ; SHOW TIME ON DISP7_DX
                JAL     HEX_DECIMAL
                LOAD    R2, M[R4]
                STOR    M[R2], R3
                
                LOAD    R1, M[R6] ; pop the second returned value from the stack
                INC     R6        ; to use as the argument on the next iteration
                
                INC     R4
                DEC     R5
                BR.NZ   .dispLoop
                
                ; RESTORE CONTEXT
                LOAD    R7, M[R6]
                INC     R6
                LOAD    R5, M[R6]
                INC     R6
                LOAD    R4, M[R6]
                INC     R6
                
                JMP     R7
                
                
;=================================================================
; HEX_DECIMAL: Takes a number in hexadecimal, returns remainder
; of a division by ten and and the quocient
; R1 -> number to convert
; R3 <- number converted (remainder)
; STACK <- quocient of the number
;-----------------------------------------------------------------
HEX_DECIMAL:    ;SAVE CONTEXT
                DEC     R6
                STOR    M[R6], R7
                DEC     R6
                STOR    M[R6], R5
                DEC     R6
                STOR    M[R6], R4
                
                MOV     R4, R0
                
                ; If the given argument is 0, exit function and return 0
                CMP     R1, R0
                BR.Z    .noDisplay
                ; If argument is 10 (A in hexadecimal), return 0 and 
                ; place the value 1 in R1
                MVI     R5, DECIMAL_BASE
                CMP     R1, R5
                BR.Z    .scoreTen
                
                MVI     R2, DECIMAL_BASE

.loop:          INC     R4
                SUB     R1, R1, R2
                
                CMP     R1, R0
                BR.P    .loop
                
                CMP     R1, R0  ; if the argument was a multiple of 10     
                BR.Z    .multipleOfTen
                        
                ADD     R3, R1, R2
                
                ; DECREMENT R4, TO ACCOUNT FOR THE EXTRA SUBTRACTION
                ; USED TO END THE LOOP
                DEC     R4
                ; FEED NEW VALUE TO R1 FOR NEXT ITERATION
                MOV     R1, R4
                BR      .exit
                
.noDisplay:     MOV     R3, R0
                BR      .exit

.scoreTen:      MOV     R3, R0
                MVI     R1, 1
                BR      .exit
                
.multipleOfTen: MOV     R3, R0  ; return remainder as 0
                MOV     R1, R4  ; return quocient as the number of subtractions

.exit:          ; RESTORE CONTEXT
                LOAD    R4, M[R6]
                INC     R6
                LOAD    R5, M[R6]
                INC     R6
                LOAD    R7, M[R6]
                INC     R6
                
                ; SAVE SECOND RETURN VALUE
                DEC     R6          ; store quocient on stack
                STOR    M[R6], R1   ; as R3 already returns another value

                JMP     R7

;=================================================================
; GRAVITY_LIFECYCLE: handle gravity logic every lifecycle tick
;-----------------------------------------------------------------
GRAVITY_LC:     MVI     R1, DINO_SPEED
                LOAD    R1, M[R1]
                CMP     R1, R0
                BR.Z    .exit   ; skip if dino speed is zero

                MVI     R2, DINO_HEIGHT
                LOAD    R3, M[R2]

                ADD     R3, R3, R1      ; add speed to height
                STOR    M[R2], R3

                ; if height is zero (ground), set speed to zero
                CMP     R3, R0
                BR.NZ   .notGround
                MVI     R2, DINO_SPEED
                STOR    M[R2], R0
                BR      .exit

.notGround:     ; else if height is max height, set speed to -speed
                MVI     R2, DINO_MAX_HEIGHT
                CMP     R3, R2
                BR.NZ   .exit
                MVI     R2, DINO_SPEED
                NEG     R1
                STOR    M[R2], R1

.exit:          JMP R7

;=================================================================
; CHECK_COLLISIONS: function that checks if the dino collided
;   If so, it returns 1 on R3, otherwise returns 0 on R3.
; R3 <- collided?
;-----------------------------------------------------------------
CHECK_COLLISIONS:
                MVI     R1, TERRAIN_START
                MVI     R2, DINO_COLUMN
                ADD     R1, R1, R2 ; get column where dino is
                LOAD    R2, M[R1]  ; get height of cactus in that column

                MVI     R1, DINO_HEIGHT
                LOAD    R1, M[R1]  ; get current dino height
                
                MOV     R3, R0 ; make sure the return value is empty
                
                CMP     R1, R2
                BR.NN   .exit
                MVI     R3, 1h ; if R1 (zero based) < R2, return game over

.exit:          JMP R7

;=================================================================
; GAME_OVER: function that ends the game, and prints 'Game Over'
;   in the terminal. It also resets all the values.
;-----------------------------------------------------------------
GAME_OVER:      MVI     R1, GAME_START
                STOR    M[R1], R0       ; stop game

                ; stop timer
                MVI     R1, TIMER_CONTROL
                MVI     R2, TIMER_SETSTOP
                STOR    M[R1], R2

                ; clear terrain
                MVI     R1, TERRAIN_START
                MVI     R2, TERRAIN_SIZE
.terrainLoop:   STOR    M[R1], R0
                INC     R1
                DEC     R2
                BR.NZ   .terrainLoop

                ; reset score
                MVI     R1, SCORE
                STOR    M[R1], R0

                ; write game over
                MVI     R1, TERM_COLOR
                MVI     R2, GAME_OVER_COLOR
                STOR    M[R1], R2

                MVI     R1, TERM_CURSOR
                MVI     R2, GAME_OVER_POS
                STOR    M[R1], R2

                MVI     R3, TERM_WRITE
                MVI     R1, GAME_OVER_MSG
                LOAD    R2, M[R1]
.termLoop:      STOR    M[R3], R2
                INC R1
                LOAD    R2, M[R1]
                CMP     R2, R0
                BR.NZ   .termLoop

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
                
;=================================================================
; AUX_KEYUP_ISR: function that handles the UP arrow action
;-----------------------------------------------------------------
AUX_KEYUP_ISR:
                MVI     R1, DINO_SPEED
                LOAD    R2, M[R1]
                CMP     R2, R0
                BR.NZ   .exit   ; exit if not on ground

                MVI     R2, DINO_MAX_SPEED
                STOR    M[R1], R2

.exit:          JMP R7

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
                
                ORIG    7F30h
KEYUP:          ; SAVE CONTEXT
                DEC     R6
                STOR    M[R6], R1
                DEC     R6
                STOR    M[R6], R2
                DEC     R6
                STOR    M[R6], R7
                ; CALL AUXILIARY FUNCTION
                JAL     AUX_KEYUP_ISR
                ; RESTORE CONTEXT
                LOAD    R7, M[R6]
                INC     R6
                LOAD    R2, M[R6]
                INC     R6
                LOAD    R1, M[R6]
                INC     R6
                RTI
