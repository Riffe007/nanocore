; ALU instruction tests
; Tests basic arithmetic and logic operations

.text

main:
    ; Test ADD
    li r1, 10
    li r2, 20
    add r3, r1, r2      ; r3 = 30
    
    ; Test SUB
    li r4, 50
    li r5, 15
    sub r6, r4, r5      ; r6 = 35
    
    ; Test MUL
    li r7, 6
    li r8, 7
    mul r9, r7, r8      ; r9 = 42
    
    ; Test DIV
    li r10, 100
    li r11, 4
    div r12, r10, r11   ; r12 = 25
    
    ; Test MOD
    li r13, 17
    li r14, 5
    mod r15, r13, r14   ; r15 = 2
    
    ; Test AND
    li r16, 0xFF00
    li r17, 0x0FF0
    and r18, r16, r17   ; r18 = 0x0F00
    
    ; Test OR
    li r19, 0x00FF
    li r20, 0xFF00
    or r21, r19, r20    ; r21 = 0xFFFF
    
    ; Test XOR
    li r22, 0xAAAA
    li r23, 0x5555
    xor r24, r22, r23   ; r24 = 0xFFFF
    
    ; Test shifts
    li r25, 0x01
    shl r26, r25, r1    ; r26 = 0x400 (shift left by 10)
    
    li r27, 0x8000
    li r28, 4
    shr r29, r27, r28   ; r29 = 0x800
    
    ; Exit with success
    li r0, 0
    halt