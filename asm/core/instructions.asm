; NanoCore Instructions Module
; Handles instruction decoding and execution

BITS 64
SECTION .text

; External symbols
extern vm_state
extern alu_add
extern alu_sub
extern alu_mul
extern alu_div
extern alu_and
extern alu_or
extern alu_xor
extern alu_not
extern alu_shl
extern alu_shr
extern alu_sar
extern alu_rol
extern alu_ror
extern alu_cmp
extern alu_test
extern memory_read
extern memory_write
extern interrupt_trigger

; Constants
%define VM_PC 0
%define VM_FLAGS 16
%define VM_GPRS 24
%define VM_VREGS (VM_GPRS + 32 * 8)
%define VM_PERF (VM_VREGS + 16 * 32)

; Instruction opcodes
%define OP_ADD 0x00
%define OP_SUB 0x01
%define OP_MUL 0x02
%define OP_DIV 0x03
%define OP_AND 0x04
%define OP_OR 0x05
%define OP_XOR 0x06
%define OP_NOT 0x07
%define OP_SHL 0x08
%define OP_SHR 0x09
%define OP_SAR 0x0A
%define OP_ROL 0x0B
%define OP_ROR 0x0C
%define OP_CMP 0x0D
%define OP_TEST 0x0E
%define OP_LD 0x0F
%define OP_ST 0x10
%define OP_BEQ 0x11
%define OP_BNE 0x12
%define OP_BLT 0x13
%define OP_BGE 0x14
%define OP_JMP 0x15
%define OP_CALL 0x16
%define OP_RET 0x17
%define OP_SYSCALL 0x18
%define OP_HALT 0x19
%define OP_NOP 0x1A

; Global symbols
global decode_instruction
global execute_instruction
global get_register_value
global set_register_value
global get_flags
global set_flags

SECTION .text

; Decode instruction
; Input: RDI = instruction word
; Output: RAX = opcode, RCX = rd, RDX = rs1, R8 = rs2, R9 = immediate
global decode_instruction
decode_instruction:
    push rbp
    mov rbp, rsp
    push rbx
    
    mov rbx, rdi  ; Instruction word
    
    ; Extract opcode (bits 31-26)
    mov rax, rbx
    shr rax, 26
    and rax, 0x3F
    
    ; Extract rd (bits 25-21)
    mov rcx, rbx
    shr rcx, 21
    and rcx, 0x1F
    
    ; Extract rs1 (bits 20-16)
    mov rdx, rbx
    shr rdx, 16
    and rdx, 0x1F
    
    ; Extract rs2 (bits 15-11)
    mov r8, rbx
    shr r8, 11
    and r8, 0x1F
    
    ; Extract immediate (bits 15-0)
    mov r9, rbx
    and r9, 0xFFFF
    ; Sign extend
    movsx r9, r9w
    
    pop rbx
    pop rbp
    ret

; Execute instruction
; Input: RDI = opcode, RSI = rd, RDX = rs1, RCX = rs2, R8 = immediate
; Output: RAX = 0 on success, error code otherwise
global execute_instruction
execute_instruction:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    
    mov r12, rdi  ; Opcode
    mov r13, rsi  ; rd
    mov r14, rdx  ; rs1
    mov r15, rcx  ; rs2
    mov rbx, r8   ; immediate
    
    ; Get register values
    mov rdi, r14
    call get_register_value
    mov r14, rax  ; rs1 value
    
    mov rdi, r15
    call get_register_value
    mov r15, rax  ; rs2 value
    
    ; Execute based on opcode
    cmp r12, OP_ADD
    je .add
    cmp r12, OP_SUB
    je .sub
    cmp r12, OP_MUL
    je .mul
    cmp r12, OP_DIV
    je .div
    cmp r12, OP_AND
    je .and
    cmp r12, OP_OR
    je .or
    cmp r12, OP_XOR
    je .xor
    cmp r12, OP_NOT
    je .not
    cmp r12, OP_SHL
    je .shl
    cmp r12, OP_SHR
    je .shr
    cmp r12, OP_SAR
    je .sar
    cmp r12, OP_ROL
    je .rol
    cmp r12, OP_ROR
    je .ror
    cmp r12, OP_CMP
    je .cmp
    cmp r12, OP_TEST
    je .test
    cmp r12, OP_LD
    je .ld
    cmp r12, OP_ST
    je .st
    cmp r12, OP_BEQ
    je .beq
    cmp r12, OP_BNE
    je .bne
    cmp r12, OP_BLT
    je .blt
    cmp r12, OP_BGE
    je .bge
    cmp r12, OP_JMP
    je .jmp
    cmp r12, OP_CALL
    je .call
    cmp r12, OP_RET
    je .ret
    cmp r12, OP_SYSCALL
    je .syscall
    cmp r12, OP_HALT
    je .halt
    cmp r12, OP_NOP
    je .nop
    
    ; Unknown opcode
    mov rax, -1
    jmp .done
    
.add:
    mov rdi, r14
    mov rsi, r15
    call alu_add
    mov rdi, r13
    mov rsi, rax
    call set_register_value
    jmp .success
    
.sub:
    mov rdi, r14
    mov rsi, r15
    call alu_sub
    mov rdi, r13
    mov rsi, rax
    call set_register_value
    jmp .success
    
.mul:
    mov rdi, r14
    mov rsi, r15
    call alu_mul
    mov rdi, r13
    mov rsi, rax
    call set_register_value
    jmp .success
    
.div:
    mov rdi, r14
    mov rsi, r15
    call alu_div
    mov rdi, r13
    mov rsi, rax
    call set_register_value
    jmp .success
    
.and:
    mov rdi, r14
    mov rsi, r15
    call alu_and
    mov rdi, r13
    mov rsi, rax
    call set_register_value
    jmp .success
    
.or:
    mov rdi, r14
    mov rsi, r15
    call alu_or
    mov rdi, r13
    mov rsi, rax
    call set_register_value
    jmp .success
    
.xor:
    mov rdi, r14
    mov rsi, r15
    call alu_xor
    mov rdi, r13
    mov rsi, rax
    call set_register_value
    jmp .success
    
.not:
    mov rdi, r14
    call alu_not
    mov rdi, r13
    mov rsi, rax
    call set_register_value
    jmp .success
    
.shl:
    mov rdi, r14
    mov rsi, r15
    call alu_shl
    mov rdi, r13
    mov rsi, rax
    call set_register_value
    jmp .success
    
.shr:
    mov rdi, r14
    mov rsi, r15
    call alu_shr
    mov rdi, r13
    mov rsi, rax
    call set_register_value
    jmp .success
    
.sar:
    mov rdi, r14
    mov rsi, r15
    call alu_sar
    mov rdi, r13
    mov rsi, rax
    call set_register_value
    jmp .success
    
.rol:
    mov rdi, r14
    mov rsi, r15
    call alu_rol
    mov rdi, r13
    mov rsi, rax
    call set_register_value
    jmp .success
    
.ror:
    mov rdi, r14
    mov rsi, r15
    call alu_ror
    mov rdi, r13
    mov rsi, rax
    call set_register_value
    jmp .success
    
.cmp:
    mov rdi, r14
    mov rsi, r15
    call alu_cmp
    jmp .success
    
.test:
    mov rdi, r14
    mov rsi, r15
    call alu_test
    jmp .success
    
.ld:
    ; Load from memory
    mov rdi, r14  ; Address
    lea rsi, [rsp - 8]  ; Buffer
    mov rdx, 8  ; Size
    call memory_read
    test rax, rax
    jnz .error
    
    mov rax, [rsp - 8]
    mov rdi, r13
    mov rsi, rax
    call set_register_value
    jmp .success
    
.st:
    ; Store to memory
    mov rdi, r14  ; Address
    lea rsi, [r15]  ; Data
    mov rdx, 8  ; Size
    call memory_write
    test rax, rax
    jnz .error
    jmp .success
    
.beq:
    ; Branch if equal
    call get_flags
    test al, 1  ; Zero flag
    jz .success
    ; Update PC
    lea rbx, [vm_state]
    add qword [rbx + VM_PC], rbx
    jmp .success
    
.bne:
    ; Branch if not equal
    call get_flags
    test al, 1  ; Zero flag
    jnz .success
    ; Update PC
    lea rbx, [vm_state]
    add qword [rbx + VM_PC], rbx
    jmp .success
    
.blt:
    ; Branch if less than
    call get_flags
    test al, 8  ; Negative flag
    jz .success
    ; Update PC
    lea rbx, [vm_state]
    add qword [rbx + VM_PC], rbx
    jmp .success
    
.bge:
    ; Branch if greater or equal
    call get_flags
    test al, 8  ; Negative flag
    jnz .success
    ; Update PC
    lea rbx, [vm_state]
    add qword [rbx + VM_PC], rbx
    jmp .success
    
.jmp:
    ; Jump
    lea rbx, [vm_state]
    mov [rbx + VM_PC], r14
    jmp .success
    
.call:
    ; Call function
    lea rbx, [vm_state]
    mov rax, [rbx + VM_PC]
    add rax, 4
    mov rdi, 31  ; Link register
    mov rsi, rax
    call set_register_value
    mov [rbx + VM_PC], r14
    jmp .success
    
.ret:
    ; Return
    mov rdi, 31  ; Link register
    call get_register_value
    lea rbx, [vm_state]
    mov [rbx + VM_PC], rax
    jmp .success
    
.syscall:
    ; System call
    mov rdi, 0x80  ; System call interrupt
    call interrupt_trigger
    jmp .success
    
.halt:
    ; Halt VM
    lea rbx, [vm_state]
    or byte [rbx + VM_FLAGS], 0x80
    jmp .success
    
.nop:
    ; No operation
    jmp .success
    
.success:
    xor eax, eax
    jmp .done
    
.error:
    mov eax, -1
    
.done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; Get register value
; Input: RDI = register number
; Output: RAX = register value
global get_register_value
get_register_value:
    push rbp
    mov rbp, rsp
    push rbx
    
    ; Check if R0 (always zero)
    test rdi, rdi
    jz .zero
    
    ; Get register value
    lea rbx, [vm_state]
    mov rax, [rbx + VM_GPRS + rdi * 8]
    jmp .done
    
.zero:
    xor eax, eax
    
.done:
    pop rbx
    pop rbp
    ret

; Set register value
; Input: RDI = register number, RSI = value
global set_register_value
set_register_value:
    push rbp
    mov rbp, rsp
    push rbx
    
    ; Check if R0 (cannot be written)
    test rdi, rdi
    jz .done
    
    ; Set register value
    lea rbx, [vm_state]
    mov [rbx + VM_GPRS + rdi * 8], rsi
    
.done:
    pop rbx
    pop rbp
    ret

; Get flags
; Output: AL = flags
global get_flags
get_flags:
    push rbp
    mov rbp, rsp
    push rbx
    
    lea rbx, [vm_state]
    mov al, [rbx + VM_FLAGS]
    
    pop rbx
    pop rbp
    ret

; Set flags
; Input: AL = flags
global set_flags
set_flags:
    push rbp
    mov rbp, rsp
    push rbx
    
    lea rbx, [vm_state]
    mov [rbx + VM_FLAGS], al
    
    pop rbx
    pop rbp
    ret