; Branch instruction tests
; Tests all conditional branches and jumps

.text
main:
    ; Test BEQ (branch if equal)
    li r1, 10
    li r2, 10
    beq r1, r2, test_beq_pass
    li r0, 1            ; Error code
    halt
    
test_beq_pass:
    ; Test BNE (branch if not equal)
    li r3, 20
    li r4, 30
    bne r3, r4, test_bne_pass
    li r0, 2            ; Error code
    halt
    
test_bne_pass:
    ; Test BLT (branch if less than)
    li r5, -10
    li r6, 5
    blt r5, r6, test_blt_pass
    li r0, 3            ; Error code
    halt
    
test_blt_pass:
    ; Test BGE (branch if greater or equal)
    li r7, 100
    li r8, 50
    bge r7, r8, test_bge_pass
    li r0, 4            ; Error code
    halt
    
test_bge_pass:
    ; Test BLTU (branch if less than unsigned)
    li r9, 0xFFFFFFFF   ; -1 as unsigned = max value
    li r10, 1
    bltu r10, r9, test_bltu_pass
    li r0, 5            ; Error code
    halt
    
test_bltu_pass:
    ; Test BGEU (branch if greater or equal unsigned)
    li r11, 0x80000000
    li r12, 0x7FFFFFFF
    bgeu r11, r12, test_bgeu_pass
    li r0, 6            ; Error code
    halt
    
test_bgeu_pass:
    ; Test function calls
    call test_function
    
    ; Test computed jump
    la r13, jump_table
    li r14, 2           ; Select third entry
    shl r14, r14, r30   ; Multiply by 4
    add r13, r13, r14
    ld r15, 0(r13)
    jmp r15, r0         ; Jump to address
    
jump_target_0:
    li r0, 7            ; Should not reach here
    halt
    
jump_target_1:
    li r0, 8            ; Should not reach here
    halt
    
jump_target_2:
    ; Success - all tests passed
    li r0, 0
    halt

test_function:
    ; Simple function that modifies r20
    li r20, 0x1234
    ret

.data
jump_table:
    .word jump_target_0
    .word jump_target_1
    .word jump_target_2