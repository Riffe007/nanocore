; NanoCore Basic Test Program
; Tests basic arithmetic and control flow

; Entry point
_start:
    ; Test immediate loads and arithmetic
    LOAD    R1, 10          ; R1 = 10
    LOAD    R2, 20          ; R2 = 20
    ADD     R3, R1, R2      ; R3 = 30
    
    ; Test subtraction
    SUB     R4, R2, R1      ; R4 = 10
    
    ; Test multiplication
    MUL     R5, R1, R2      ; R5 = 200
    
    ; Test division
    LOAD    R6, 100         ; R6 = 100
    DIV     R7, R6, R1      ; R7 = 10
    
    ; Test comparison and branching
    LOAD    R8, 0           ; Counter
    LOAD    R9, 5           ; Limit
    
loop_start:
    ADD     R8, R8, R1      ; Increment counter by 1 (R1=1)
    BLT     R8, R9, loop_start  ; Branch if R8 < R9
    
    ; Test function call
    CALL    test_function
    
    ; Exit program
    LOAD    R0, 60          ; sys_exit
    LOAD    R1, 0           ; exit code
    SYSCALL
    HALT

test_function:
    ; Simple function that doubles R1
    ADD     R1, R1, R1      ; R1 = R1 * 2
    RET

; Data section
data_start:
    .word   0x12345678      ; Test data
    .word   0xDEADBEEF
    .word   0