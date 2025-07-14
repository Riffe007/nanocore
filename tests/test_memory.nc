; Memory instruction tests
; Tests load/store operations

.data
    test_data: .word 0x12345678
    test_array: .word 10, 20, 30, 40, 50
    test_string: .string "Hello, NanoCore!"

.text
main:
    ; Test basic load/store
    la r1, test_data    ; Load address
    ld r2, 0(r1)        ; Load word
    li r3, 0x87654321
    st r3, 0(r1)        ; Store new value
    ld r4, 0(r1)        ; Verify store
    
    ; Test array access
    la r5, test_array
    li r6, 0
    
array_loop:
    shl r7, r6, r30     ; r30 = 2 (multiply index by 4)
    add r8, r5, r7      ; Calculate address
    ld r9, 0(r8)        ; Load array element
    add r9, r9, r30     ; Add 100 to element
    st r9, 0(r8)        ; Store back
    
    addi r6, r6, 1      ; Increment index
    li r10, 5
    blt r6, r10, array_loop
    
    ; Test byte operations
    la r11, test_string
    lb r12, 0(r11)      ; Load 'H'
    lb r13, 1(r11)      ; Load 'e'
    
    ; Test halfword operations
    lh r14, 0(r11)      ; Load "He"
    lh r15, 2(r11)      ; Load "ll"
    
    ; Store bytes
    li r16, 0x21        ; '!'
    sb r16, 15(r11)     ; Replace null terminator
    
    ; Exit
    li r0, 0
    halt