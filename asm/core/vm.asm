; NanoCore VM - Main Execution Engine
; High-performance 64-bit RISC VM with SIMD support
; 
; Author: NanoCore Team
; License: MIT

BITS 64
SECTION .text

; Constants
%define NUM_GPRS 32
%define NUM_VREGS 16
%define GPR_SIZE 8
%define VREG_SIZE 32
%define CACHE_LINE_SIZE 64
%define PAGE_SIZE 4096

; VM State Structure Offsets
%define VM_PC 0
%define VM_SP 8
%define VM_FLAGS 16
%define VM_GPRS 24
%define VM_VREGS (VM_GPRS + NUM_GPRS * GPR_SIZE)
%define VM_PERF (VM_VREGS + NUM_VREGS * VREG_SIZE)
%define VM_CACHE_CTRL (VM_PERF + 64)
%define VM_VBASE (VM_CACHE_CTRL + 8)
%define VM_STATE_SIZE (VM_VBASE + 8)

; Flags Register Bits
%define FLAG_ZERO 0
%define FLAG_CARRY 1
%define FLAG_OVERFLOW 2
%define FLAG_NEGATIVE 3
%define FLAG_IE 4
%define FLAG_UM 5

; Performance Counter Indices
%define PERF_INST_COUNT 0
%define PERF_CYCLE_COUNT 1
%define PERF_L1_MISS 2
%define PERF_L2_MISS 3
%define PERF_BRANCH_MISS 4
%define PERF_PIPELINE_STALL 5
%define PERF_MEM_OPS 6
%define PERF_SIMD_OPS 7

; Global symbols
global vm_init
global vm_reset
global vm_run
global vm_step
global vm_get_state
global vm_set_breakpoint
global vm_dump_state

; External symbols
extern memory_init
extern memory_read
extern memory_write
extern cache_init
extern cache_lookup
extern cache_update
extern device_init
extern device_read
extern device_write

SECTION .bss
align 64
vm_state: resb VM_STATE_SIZE
instruction_cache: resb 32768   ; 32KB L1I
data_cache: resb 32768          ; 32KB L1D
unified_cache: resb 262144      ; 256KB L2
branch_predictor: resb 16384    ; 2-bit counters
return_stack: resq 16           ; Return address stack
pipeline_buffer: resb 256       ; Instruction prefetch

SECTION .data
align 64
; Opcode dispatch table (256 entries for fast dispatch)
opcode_table:
    dq execute_add      ; 0x00
    dq execute_sub      ; 0x01
    dq execute_mul      ; 0x02
    dq execute_mulh     ; 0x03
    dq execute_div      ; 0x04
    dq execute_mod      ; 0x05
    dq execute_and      ; 0x06
    dq execute_or       ; 0x07
    dq execute_xor      ; 0x08
    dq execute_not      ; 0x09
    dq execute_shl      ; 0x0A
    dq execute_shr      ; 0x0B
    dq execute_sar      ; 0x0C
    dq execute_rol      ; 0x0D
    dq execute_ror      ; 0x0E
    dq execute_ld       ; 0x0F
    dq execute_lw       ; 0x10
    dq execute_lh       ; 0x11
    dq execute_lb       ; 0x12
    dq execute_st       ; 0x13
    dq execute_sw       ; 0x14
    dq execute_sh       ; 0x15
    dq execute_sb       ; 0x16
    dq execute_beq      ; 0x17
    dq execute_bne      ; 0x18
    dq execute_blt      ; 0x19
    dq execute_bge      ; 0x1A
    dq execute_bltu     ; 0x1B
    dq execute_bgeu     ; 0x1C
    dq execute_jmp      ; 0x1D
    dq execute_call     ; 0x1E
    dq execute_ret      ; 0x1F
    dq execute_syscall  ; 0x20
    dq execute_halt     ; 0x21
    dq execute_nop      ; 0x22
    dq execute_cpuid    ; 0x23
    dq execute_rdcycle  ; 0x24
    dq execute_rdperf   ; 0x25
    dq execute_prefetch ; 0x26
    dq execute_clflush  ; 0x27
    dq execute_fence    ; 0x28
    dq execute_lr       ; 0x29
    dq execute_sc       ; 0x2A
    dq execute_amoswap  ; 0x2B
    dq execute_amoadd   ; 0x2C
    dq execute_amoand   ; 0x2D
    dq execute_amoor    ; 0x2E
    dq execute_amoxor   ; 0x2F
    dq execute_vadd_f64 ; 0x30
    dq execute_vsub_f64 ; 0x31
    dq execute_vmul_f64 ; 0x32
    dq execute_vfma_f64 ; 0x33
    dq execute_vload    ; 0x34
    dq execute_vstore   ; 0x35
    dq execute_vbroadcast ; 0x36
    times 201 dq execute_illegal  ; Fill rest with illegal instruction handler

; Performance monitoring
perf_enabled: db 1
turbo_mode: db 0
debug_mode: db 0

SECTION .text

; Initialize VM
; Input: RDI = memory size
; Output: RAX = 0 on success, error code otherwise
vm_init:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    
    ; Clear VM state
    mov rdi, vm_state
    xor eax, eax
    mov ecx, VM_STATE_SIZE / 8
    rep stosq
    
    ; Initialize memory subsystem
    mov rdi, [rbp + 16]
    call memory_init
    test rax, rax
    jnz .error
    
    ; Initialize cache subsystem
    call cache_init
    test rax, rax
    jnz .error
    
    ; Initialize device subsystem
    call device_init
    test rax, rax
    jnz .error
    
    ; Set initial PC to reset vector
    mov qword [vm_state + VM_PC], 0
    
    ; Enable interrupts by default
    mov byte [vm_state + VM_FLAGS], (1 << FLAG_IE)
    
    ; Initialize performance counters
    rdtsc
    mov [vm_state + VM_PERF + PERF_CYCLE_COUNT * 8], rax
    
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

; Reset VM to initial state
vm_reset:
    push rbp
    mov rbp, rsp
    
    ; Clear GPRs (except R0 which is always 0)
    lea rdi, [vm_state + VM_GPRS + 8]
    xor eax, eax
    mov ecx, (NUM_GPRS - 1)
.clear_gprs:
    mov [rdi], rax
    add rdi, 8
    loop .clear_gprs
    
    ; Clear vector registers
    lea rdi, [vm_state + VM_VREGS]
    mov ecx, NUM_VREGS * 4  ; 4 qwords per vreg
.clear_vregs:
    mov [rdi], rax
    add rdi, 8
    loop .clear_vregs
    
    ; Reset PC and flags
    mov qword [vm_state + VM_PC], 0
    mov byte [vm_state + VM_FLAGS], (1 << FLAG_IE)
    
    ; Clear performance counters
    lea rdi, [vm_state + VM_PERF]
    mov ecx, 8
.clear_perf:
    mov [rdi], rax
    add rdi, 8
    loop .clear_perf
    
    ; Flush caches
    call flush_all_caches
    
    pop rbp
    ret

; Main execution loop
; Input: RDI = max instructions (0 = unlimited)
; Output: RAX = exit code
vm_run:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    
    mov r15, rdi  ; Save max instructions
    xor r14, r14  ; Instruction counter
    
    ; Load frequently used values into registers
    lea r13, [vm_state]
    lea r12, [opcode_table]
    
.execution_loop:
    ; Check instruction limit
    test r15, r15
    jz .no_limit
    cmp r14, r15
    jae .done
.no_limit:
    
    ; Fetch instruction
    mov rax, [r13 + VM_PC]
    
    ; Check for breakpoint
    cmp byte [debug_mode], 0
    jne .check_breakpoint
.continue_fetch:
    
    ; Prefetch next cache line
    prefetchnta [rax + CACHE_LINE_SIZE]
    
    ; Read instruction from memory
    mov rdi, rax
    call fetch_instruction
    mov ebx, eax  ; Save instruction
    
    ; Advance PC
    add qword [r13 + VM_PC], 4
    
    ; Decode and dispatch
    mov eax, ebx
    shr eax, 26  ; Extract opcode
    and eax, 0x3F
    
    ; Bounds check opcode
    cmp eax, 0x36
    ja .illegal_instruction
    
    ; Dispatch to handler
    mov rax, [r12 + rax * 8]
    call rax
    
    ; Update performance counters
    inc qword [r13 + VM_PERF + PERF_INST_COUNT * 8]
    inc r14
    
    ; Check for halt
    test byte [r13 + VM_FLAGS], 0x80
    jnz .done
    
    ; Check for interrupts
    test byte [r13 + VM_FLAGS], (1 << FLAG_IE)
    jz .execution_loop
    call check_interrupts
    
    jmp .execution_loop
    
.check_breakpoint:
    mov rdi, [r13 + VM_PC]
    call is_breakpoint
    test rax, rax
    jz .continue_fetch
    mov eax, 2  ; Breakpoint hit
    jmp .exit
    
.illegal_instruction:
    mov eax, 1  ; Illegal instruction
    jmp .exit
    
.done:
    xor eax, eax  ; Normal completion
    
.exit:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; Fetch instruction with cache lookup
; Input: RDI = address
; Output: EAX = instruction
fetch_instruction:
    push rbx
    push rcx
    
    ; Check L1I cache
    mov rax, rdi
    shr rax, 6  ; Cache line index
    and rax, 0x1FF  ; 512 lines
    
    lea rbx, [instruction_cache + rax * 64]
    mov rcx, [rbx]  ; Tag
    cmp rcx, rdi
    jne .cache_miss
    
    ; Cache hit - get instruction
    mov eax, rdi
    and eax, 0x3C  ; Offset within cache line
    mov eax, [rbx + rax + 8]
    
    pop rcx
    pop rbx
    ret
    
.cache_miss:
    ; Update miss counter
    inc qword [vm_state + VM_PERF + PERF_L1_MISS * 8]
    
    ; Fetch from memory
    call memory_read
    mov edx, eax  ; Save instruction
    
    ; Update cache
    mov [rbx], rdi  ; Store tag
    mov eax, edi
    and eax, 0x3C
    mov [rbx + rax + 8], edx
    
    mov eax, edx
    pop rcx
    pop rbx
    ret

; Execute ADD instruction
execute_add:
    push rbp
    mov rbp, rsp
    
    ; Extract operands
    mov eax, ebx
    shr eax, 21
    and eax, 0x1F  ; rd
    
    mov ecx, ebx
    shr ecx, 16
    and ecx, 0x1F  ; rs1
    
    mov edx, ebx
    shr edx, 11
    and edx, 0x1F  ; rs2
    
    ; Load operands
    mov r8, [r13 + VM_GPRS + rcx * 8]
    mov r9, [r13 + VM_GPRS + rdx * 8]
    
    ; Perform addition
    add r8, r9
    
    ; Store result (skip if rd = 0)
    test eax, eax
    jz .done
    mov [r13 + VM_GPRS + rax * 8], r8
    
    ; Update flags
    pushfq
    pop rax
    call update_flags
    
.done:
    pop rbp
    ret

; Update flags based on result
; Input: RAX = CPU flags
update_flags:
    push rbx
    
    mov bl, [r13 + VM_FLAGS]
    and bl, 0xF0  ; Clear arithmetic flags
    
    ; Zero flag
    test ah, 0x40
    jz .not_zero
    or bl, (1 << FLAG_ZERO)
.not_zero:
    
    ; Carry flag
    test al, 0x01
    jz .not_carry
    or bl, (1 << FLAG_CARRY)
.not_carry:
    
    ; Overflow flag
    test ah, 0x08
    jz .not_overflow
    or bl, (1 << FLAG_OVERFLOW)
.not_overflow:
    
    ; Negative flag
    test ah, 0x80
    jz .not_negative
    or bl, (1 << FLAG_NEGATIVE)
.not_negative:
    
    mov [r13 + VM_FLAGS], bl
    
    pop rbx
    ret

; SIMD VADD.F64 implementation
execute_vadd_f64:
    push rbp
    mov rbp, rsp
    
    ; Extract operands
    mov eax, ebx
    shr eax, 21
    and eax, 0xF  ; vd
    
    mov ecx, ebx
    shr ecx, 16
    and ecx, 0xF  ; vs1
    
    mov edx, ebx
    shr edx, 11
    and edx, 0xF  ; vs2
    
    ; Load vector operands
    lea rsi, [r13 + VM_VREGS + rcx * 32]
    lea rdi, [r13 + VM_VREGS + rdx * 32]
    lea r8, [r13 + VM_VREGS + rax * 32]
    
    ; Perform vector addition (4x double precision)
    vmovupd ymm0, [rsi]
    vmovupd ymm1, [rdi]
    vaddpd ymm2, ymm0, ymm1
    vmovupd [r8], ymm2
    
    ; Update SIMD operation counter
    inc qword [r13 + VM_PERF + PERF_SIMD_OPS * 8]
    
    pop rbp
    ret

; Execute SUB instruction
execute_sub:
    push rbp
    mov rbp, rsp
    
    ; Extract operands
    mov eax, ebx
    shr eax, 21
    and eax, 0x1F  ; rd
    
    mov ecx, ebx
    shr ecx, 16
    and ecx, 0x1F  ; rs1
    
    mov edx, ebx
    shr edx, 11
    and edx, 0x1F  ; rs2
    
    ; Load operands
    mov r8, [r13 + VM_GPRS + rcx * 8]
    mov r9, [r13 + VM_GPRS + rdx * 8]
    
    ; Perform subtraction
    sub r8, r9
    
    ; Store result (skip if rd = 0)
    test eax, eax
    jz .done
    mov [r13 + VM_GPRS + rax * 8], r8
    
    ; Update flags
    pushfq
    pop rax
    call update_flags
    
.done:
    pop rbp
    ret

; Execute MUL instruction
execute_mul:
    push rbp
    mov rbp, rsp
    push rdx
    
    ; Extract operands
    mov eax, ebx
    shr eax, 21
    and eax, 0x1F  ; rd
    
    mov ecx, ebx
    shr ecx, 16
    and ecx, 0x1F  ; rs1
    
    mov edx, ebx
    shr edx, 11
    and edx, 0x1F  ; rs2
    
    ; Load operands
    mov rax, [r13 + VM_GPRS + rcx * 8]
    mov r8, [r13 + VM_GPRS + rdx * 8]
    
    ; Perform multiplication
    mul r8  ; Result in RDX:RAX
    
    ; Store low 64 bits (skip if rd = 0)
    mov ecx, ebx
    shr ecx, 21
    and ecx, 0x1F
    test ecx, ecx
    jz .done
    mov [r13 + VM_GPRS + rcx * 8], rax
    
.done:
    pop rdx
    pop rbp
    ret

; Execute MULH instruction (high 64 bits of multiplication)
execute_mulh:
    push rbp
    mov rbp, rsp
    push rdx
    
    ; Extract operands
    mov eax, ebx
    shr eax, 21
    and eax, 0x1F  ; rd
    
    mov ecx, ebx
    shr ecx, 16
    and ecx, 0x1F  ; rs1
    
    mov edx, ebx
    shr edx, 11
    and edx, 0x1F  ; rs2
    
    ; Load operands
    mov rax, [r13 + VM_GPRS + rcx * 8]
    mov r8, [r13 + VM_GPRS + rdx * 8]
    
    ; Perform multiplication
    mul r8  ; Result in RDX:RAX
    
    ; Store high 64 bits (skip if rd = 0)
    mov ecx, ebx
    shr ecx, 21
    and ecx, 0x1F
    test ecx, ecx
    jz .done
    mov [r13 + VM_GPRS + rcx * 8], rdx
    
.done:
    pop rdx
    pop rbp
    ret

; Execute DIV instruction
execute_div:
    push rbp
    mov rbp, rsp
    push rdx
    
    ; Extract operands
    mov eax, ebx
    shr eax, 21
    and eax, 0x1F  ; rd
    
    mov ecx, ebx
    shr ecx, 16
    and ecx, 0x1F  ; rs1
    
    mov edx, ebx
    shr edx, 11
    and edx, 0x1F  ; rs2
    
    ; Load divisor and check for zero
    mov r9, [r13 + VM_GPRS + rdx * 8]
    test r9, r9
    jz .divide_by_zero
    
    ; Load dividend
    mov rax, [r13 + VM_GPRS + rcx * 8]
    xor edx, edx
    
    ; Perform division
    div r9  ; Quotient in RAX
    
    ; Store result (skip if rd = 0)
    mov ecx, ebx
    shr ecx, 21
    and ecx, 0x1F
    test ecx, ecx
    jz .done
    mov [r13 + VM_GPRS + rcx * 8], rax
    jmp .done
    
.divide_by_zero:
    ; Set result to -1
    mov ecx, ebx
    shr ecx, 21
    and ecx, 0x1F
    test ecx, ecx
    jz .done
    mov qword [r13 + VM_GPRS + rcx * 8], -1
    
.done:
    pop rdx
    pop rbp
    ret

; Execute MOD instruction
execute_mod:
    push rbp
    mov rbp, rsp
    push rdx
    
    ; Extract operands
    mov eax, ebx
    shr eax, 21
    and eax, 0x1F  ; rd
    
    mov ecx, ebx
    shr ecx, 16
    and ecx, 0x1F  ; rs1
    
    mov edx, ebx
    shr edx, 11
    and edx, 0x1F  ; rs2
    
    ; Load divisor and check for zero
    mov r9, [r13 + VM_GPRS + rdx * 8]
    test r9, r9
    jz .divide_by_zero
    
    ; Load dividend
    mov rax, [r13 + VM_GPRS + rcx * 8]
    xor edx, edx
    
    ; Perform division
    div r9  ; Remainder in RDX
    
    ; Store remainder (skip if rd = 0)
    mov ecx, ebx
    shr ecx, 21
    and ecx, 0x1F
    test ecx, ecx
    jz .done
    mov [r13 + VM_GPRS + rcx * 8], rdx
    jmp .done
    
.divide_by_zero:
    ; Return dividend as result
    mov ecx, ebx
    shr ecx, 21
    and ecx, 0x1F
    test ecx, ecx
    jz .done
    mov edx, ebx
    shr edx, 16
    and edx, 0x1F
    mov rax, [r13 + VM_GPRS + rdx * 8]
    mov [r13 + VM_GPRS + rcx * 8], rax
    
.done:
    pop rdx
    pop rbp
    ret

; Execute AND instruction
execute_and:
    push rbp
    mov rbp, rsp
    
    ; Extract operands
    mov eax, ebx
    shr eax, 21
    and eax, 0x1F  ; rd
    
    mov ecx, ebx
    shr ecx, 16
    and ecx, 0x1F  ; rs1
    
    mov edx, ebx
    shr edx, 11
    and edx, 0x1F  ; rs2
    
    ; Load operands
    mov r8, [r13 + VM_GPRS + rcx * 8]
    mov r9, [r13 + VM_GPRS + rdx * 8]
    
    ; Perform AND
    and r8, r9
    
    ; Store result (skip if rd = 0)
    test eax, eax
    jz .done
    mov [r13 + VM_GPRS + rax * 8], r8
    
    ; Update flags
    test r8, r8
    pushfq
    pop rax
    call update_flags
    
.done:
    pop rbp
    ret

; Execute OR instruction
execute_or:
    push rbp
    mov rbp, rsp
    
    ; Extract operands
    mov eax, ebx
    shr eax, 21
    and eax, 0x1F  ; rd
    
    mov ecx, ebx
    shr ecx, 16
    and ecx, 0x1F  ; rs1
    
    mov edx, ebx
    shr edx, 11
    and edx, 0x1F  ; rs2
    
    ; Load operands
    mov r8, [r13 + VM_GPRS + rcx * 8]
    mov r9, [r13 + VM_GPRS + rdx * 8]
    
    ; Perform OR
    or r8, r9
    
    ; Store result (skip if rd = 0)
    test eax, eax
    jz .done
    mov [r13 + VM_GPRS + rax * 8], r8
    
    ; Update flags
    test r8, r8
    pushfq
    pop rax
    call update_flags
    
.done:
    pop rbp
    ret

; Execute XOR instruction
execute_xor:
    push rbp
    mov rbp, rsp
    
    ; Extract operands
    mov eax, ebx
    shr eax, 21
    and eax, 0x1F  ; rd
    
    mov ecx, ebx
    shr ecx, 16
    and ecx, 0x1F  ; rs1
    
    mov edx, ebx
    shr edx, 11
    and edx, 0x1F  ; rs2
    
    ; Load operands
    mov r8, [r13 + VM_GPRS + rcx * 8]
    mov r9, [r13 + VM_GPRS + rdx * 8]
    
    ; Perform XOR
    xor r8, r9
    
    ; Store result (skip if rd = 0)
    test eax, eax
    jz .done
    mov [r13 + VM_GPRS + rax * 8], r8
    
    ; Update flags
    test r8, r8
    pushfq
    pop rax
    call update_flags
    
.done:
    pop rbp
    ret

; Execute NOT instruction
execute_not:
    push rbp
    mov rbp, rsp
    
    ; Extract operands
    mov eax, ebx
    shr eax, 21
    and eax, 0x1F  ; rd
    
    mov ecx, ebx
    shr ecx, 16
    and ecx, 0x1F  ; rs1
    
    ; Load operand
    mov r8, [r13 + VM_GPRS + rcx * 8]
    
    ; Perform NOT
    not r8
    
    ; Store result (skip if rd = 0)
    test eax, eax
    jz .done
    mov [r13 + VM_GPRS + rax * 8], r8
    
    ; Update flags
    test r8, r8
    pushfq
    pop rax
    call update_flags
    
.done:
    pop rbp
    ret

; Execute SHL (shift left) instruction
execute_shl:
    push rbp
    mov rbp, rsp
    push rcx
    
    ; Extract operands
    mov eax, ebx
    shr eax, 21
    and eax, 0x1F  ; rd
    
    mov ecx, ebx
    shr ecx, 16
    and ecx, 0x1F  ; rs1
    
    mov edx, ebx
    shr edx, 11
    and edx, 0x1F  ; rs2
    
    ; Load operands
    mov r8, [r13 + VM_GPRS + rcx * 8]
    mov rcx, [r13 + VM_GPRS + rdx * 8]
    and rcx, 63  ; Limit shift to 63
    
    ; Perform shift left
    shl r8, cl
    
    ; Store result (skip if rd = 0)
    test eax, eax
    jz .done
    mov [r13 + VM_GPRS + rax * 8], r8
    
    ; Update flags
    pushfq
    pop rax
    call update_flags
    
.done:
    pop rcx
    pop rbp
    ret

; Execute SHR (shift right logical) instruction
execute_shr:
    push rbp
    mov rbp, rsp
    push rcx
    
    ; Extract operands
    mov eax, ebx
    shr eax, 21
    and eax, 0x1F  ; rd
    
    mov ecx, ebx
    shr ecx, 16
    and ecx, 0x1F  ; rs1
    
    mov edx, ebx
    shr edx, 11
    and edx, 0x1F  ; rs2
    
    ; Load operands
    mov r8, [r13 + VM_GPRS + rcx * 8]
    mov rcx, [r13 + VM_GPRS + rdx * 8]
    and rcx, 63  ; Limit shift to 63
    
    ; Perform shift right
    shr r8, cl
    
    ; Store result (skip if rd = 0)
    test eax, eax
    jz .done
    mov [r13 + VM_GPRS + rax * 8], r8
    
    ; Update flags
    pushfq
    pop rax
    call update_flags
    
.done:
    pop rcx
    pop rbp
    ret

; Execute SAR (shift right arithmetic) instruction
execute_sar:
    push rbp
    mov rbp, rsp
    push rcx
    
    ; Extract operands
    mov eax, ebx
    shr eax, 21
    and eax, 0x1F  ; rd
    
    mov ecx, ebx
    shr ecx, 16
    and ecx, 0x1F  ; rs1
    
    mov edx, ebx
    shr edx, 11
    and edx, 0x1F  ; rs2
    
    ; Load operands
    mov r8, [r13 + VM_GPRS + rcx * 8]
    mov rcx, [r13 + VM_GPRS + rdx * 8]
    and rcx, 63  ; Limit shift to 63
    
    ; Perform arithmetic shift right
    sar r8, cl
    
    ; Store result (skip if rd = 0)
    test eax, eax
    jz .done
    mov [r13 + VM_GPRS + rax * 8], r8
    
    ; Update flags
    pushfq
    pop rax
    call update_flags
    
.done:
    pop rcx
    pop rbp
    ret

; Execute ROL (rotate left) instruction
execute_rol:
    push rbp
    mov rbp, rsp
    push rcx
    
    ; Extract operands
    mov eax, ebx
    shr eax, 21
    and eax, 0x1F  ; rd
    
    mov ecx, ebx
    shr ecx, 16
    and ecx, 0x1F  ; rs1
    
    mov edx, ebx
    shr edx, 11
    and edx, 0x1F  ; rs2
    
    ; Load operands
    mov r8, [r13 + VM_GPRS + rcx * 8]
    mov rcx, [r13 + VM_GPRS + rdx * 8]
    and rcx, 63  ; Limit rotate to 63
    
    ; Perform rotate left
    rol r8, cl
    
    ; Store result (skip if rd = 0)
    test eax, eax
    jz .done
    mov [r13 + VM_GPRS + rax * 8], r8
    
.done:
    pop rcx
    pop rbp
    ret

; Execute ROR (rotate right) instruction
execute_ror:
    push rbp
    mov rbp, rsp
    push rcx
    
    ; Extract operands
    mov eax, ebx
    shr eax, 21
    and eax, 0x1F  ; rd
    
    mov ecx, ebx
    shr ecx, 16
    and ecx, 0x1F  ; rs1
    
    mov edx, ebx
    shr edx, 11
    and edx, 0x1F  ; rs2
    
    ; Load operands
    mov r8, [r13 + VM_GPRS + rcx * 8]
    mov rcx, [r13 + VM_GPRS + rdx * 8]
    and rcx, 63  ; Limit rotate to 63
    
    ; Perform rotate right
    ror r8, cl
    
    ; Store result (skip if rd = 0)
    test eax, eax
    jz .done
    mov [r13 + VM_GPRS + rax * 8], r8
    
.done:
    pop rcx
    pop rbp
    ret

; Execute LD (load 64-bit) instruction
execute_ld:
    push rbp
    mov rbp, rsp
    push rbx
    push rcx
    
    ; Extract operands
    mov eax, ebx
    shr eax, 21
    and eax, 0x1F  ; rd
    
    mov ecx, ebx
    shr ecx, 16
    and ecx, 0x1F  ; rs1
    
    ; Extract immediate offset (16-bit signed)
    movsx rdx, bx  ; Sign extend lower 16 bits
    
    ; Calculate effective address
    mov rdi, [r13 + VM_GPRS + rcx * 8]
    add rdi, rdx
    
    ; Read from memory
    call memory_read  ; Returns value in RAX
    
    ; Store to register (skip if rd = 0)
    mov ecx, ebx
    shr ecx, 21
    and ecx, 0x1F
    test ecx, ecx
    jz .done
    mov [r13 + VM_GPRS + rcx * 8], rax
    
    ; Update memory operation counter
    inc qword [r13 + VM_PERF + PERF_MEM_OPS * 8]
    
.done:
    pop rcx
    pop rbx
    pop rbp
    ret

; Execute LW (load 32-bit sign extend) instruction
execute_lw:
    push rbp
    mov rbp, rsp
    push rbx
    push rcx
    
    ; Extract operands
    mov eax, ebx
    shr eax, 21
    and eax, 0x1F  ; rd
    
    mov ecx, ebx
    shr ecx, 16
    and ecx, 0x1F  ; rs1
    
    ; Extract immediate offset
    movsx rdx, bx
    
    ; Calculate effective address
    mov rdi, [r13 + VM_GPRS + rcx * 8]
    add rdi, rdx
    
    ; Read from memory
    call memory_read
    
    ; Sign extend 32-bit to 64-bit
    movsx rax, eax
    
    ; Store to register
    mov ecx, ebx
    shr ecx, 21
    and ecx, 0x1F
    test ecx, ecx
    jz .done
    mov [r13 + VM_GPRS + rcx * 8], rax
    
    inc qword [r13 + VM_PERF + PERF_MEM_OPS * 8]
    
.done:
    pop rcx
    pop rbx
    pop rbp
    ret

; Execute LH (load 16-bit sign extend) instruction
execute_lh:
    push rbp
    mov rbp, rsp
    push rbx
    push rcx
    
    ; Extract operands
    mov eax, ebx
    shr eax, 21
    and eax, 0x1F  ; rd
    
    mov ecx, ebx
    shr ecx, 16
    and ecx, 0x1F  ; rs1
    
    ; Extract immediate offset
    movsx rdx, bx
    
    ; Calculate effective address
    mov rdi, [r13 + VM_GPRS + rcx * 8]
    add rdi, rdx
    
    ; Read from memory
    call memory_read
    
    ; Sign extend 16-bit to 64-bit
    movsx rax, ax
    
    ; Store to register
    mov ecx, ebx
    shr ecx, 21
    and ecx, 0x1F
    test ecx, ecx
    jz .done
    mov [r13 + VM_GPRS + rcx * 8], rax
    
    inc qword [r13 + VM_PERF + PERF_MEM_OPS * 8]
    
.done:
    pop rcx
    pop rbx
    pop rbp
    ret

; Execute LB (load 8-bit sign extend) instruction
execute_lb:
    push rbp
    mov rbp, rsp
    push rbx
    push rcx
    
    ; Extract operands
    mov eax, ebx
    shr eax, 21
    and eax, 0x1F  ; rd
    
    mov ecx, ebx
    shr ecx, 16
    and ecx, 0x1F  ; rs1
    
    ; Extract immediate offset
    movsx rdx, bx
    
    ; Calculate effective address
    mov rdi, [r13 + VM_GPRS + rcx * 8]
    add rdi, rdx
    
    ; Read from memory
    call memory_read
    
    ; Sign extend 8-bit to 64-bit
    movsx rax, al
    
    ; Store to register
    mov ecx, ebx
    shr ecx, 21
    and ecx, 0x1F
    test ecx, ecx
    jz .done
    mov [r13 + VM_GPRS + rcx * 8], rax
    
    inc qword [r13 + VM_PERF + PERF_MEM_OPS * 8]
    
.done:
    pop rcx
    pop rbx
    pop rbp
    ret

; Execute ST (store 64-bit) instruction
execute_st:
    push rbp
    mov rbp, rsp
    push rbx
    push rcx
    
    ; Extract operands
    mov ecx, ebx
    shr ecx, 16
    and ecx, 0x1F  ; rs1 (base address)
    
    mov edx, ebx
    shr edx, 11
    and edx, 0x1F  ; rs2 (value to store)
    
    ; Extract immediate offset
    movsx rax, bx
    
    ; Calculate effective address
    mov rdi, [r13 + VM_GPRS + rcx * 8]
    add rdi, rax
    
    ; Get value to store
    mov rsi, [r13 + VM_GPRS + rdx * 8]
    
    ; Write to memory
    call memory_write
    
    ; Update memory operation counter
    inc qword [r13 + VM_PERF + PERF_MEM_OPS * 8]
    
    pop rcx
    pop rbx
    pop rbp
    ret

; Execute SW (store 32-bit) instruction
execute_sw:
    push rbp
    mov rbp, rsp
    push rbx
    push rcx
    
    ; Extract operands
    mov ecx, ebx
    shr ecx, 16
    and ecx, 0x1F  ; rs1 (base address)
    
    mov edx, ebx
    shr edx, 11
    and edx, 0x1F  ; rs2 (value to store)
    
    ; Extract immediate offset
    movsx rax, bx
    
    ; Calculate effective address
    mov rdi, [r13 + VM_GPRS + rcx * 8]
    add rdi, rax
    
    ; Get value to store (32-bit)
    mov esi, dword [r13 + VM_GPRS + rdx * 8]
    
    ; Write to memory
    call memory_write
    
    inc qword [r13 + VM_PERF + PERF_MEM_OPS * 8]
    
    pop rcx
    pop rbx
    pop rbp
    ret

; Execute SH (store 16-bit) instruction
execute_sh:
    push rbp
    mov rbp, rsp
    push rbx
    push rcx
    
    ; Extract operands
    mov ecx, ebx
    shr ecx, 16
    and ecx, 0x1F  ; rs1 (base address)
    
    mov edx, ebx
    shr edx, 11
    and edx, 0x1F  ; rs2 (value to store)
    
    ; Extract immediate offset
    movsx rax, bx
    
    ; Calculate effective address
    mov rdi, [r13 + VM_GPRS + rcx * 8]
    add rdi, rax
    
    ; Get value to store (16-bit)
    mov si, word [r13 + VM_GPRS + rdx * 8]
    
    ; Write to memory
    call memory_write
    
    inc qword [r13 + VM_PERF + PERF_MEM_OPS * 8]
    
    pop rcx
    pop rbx
    pop rbp
    ret

; Execute SB (store 8-bit) instruction
execute_sb:
    push rbp
    mov rbp, rsp
    push rbx
    push rcx
    
    ; Extract operands
    mov ecx, ebx
    shr ecx, 16
    and ecx, 0x1F  ; rs1 (base address)
    
    mov edx, ebx
    shr edx, 11
    and edx, 0x1F  ; rs2 (value to store)
    
    ; Extract immediate offset
    movsx rax, bx
    
    ; Calculate effective address
    mov rdi, [r13 + VM_GPRS + rcx * 8]
    add rdi, rax
    
    ; Get value to store (8-bit)
    mov sil, byte [r13 + VM_GPRS + rdx * 8]
    
    ; Write to memory
    call memory_write
    
    inc qword [r13 + VM_PERF + PERF_MEM_OPS * 8]
    
    pop rcx
    pop rbx
    pop rbp
    ret

; Execute BEQ (branch if equal) instruction
execute_beq:
    push rbp
    mov rbp, rsp
    
    ; Extract operands
    mov ecx, ebx
    shr ecx, 21
    and ecx, 0x1F  ; rs1
    
    mov edx, ebx
    shr edx, 16
    and edx, 0x1F  ; rs2
    
    ; Load values
    mov r8, [r13 + VM_GPRS + rcx * 8]
    mov r9, [r13 + VM_GPRS + rdx * 8]
    
    ; Compare
    cmp r8, r9
    jne .no_branch
    
    ; Extract offset (13-bit signed, shifted left by 1)
    mov eax, ebx
    shl eax, 19  ; Shift to get sign bit in position
    sar eax, 18  ; Sign extend and shift back (keeping 1-bit shift)
    movsx rax, eax
    
    ; Update PC
    add [r13 + VM_PC], rax
    sub qword [r13 + VM_PC], 4  ; Compensate for PC increment
    
    ; Update branch prediction counter
    inc qword [r13 + VM_PERF + PERF_BRANCH_MISS * 8]
    
.no_branch:
    pop rbp
    ret

; Execute BNE (branch if not equal) instruction
execute_bne:
    push rbp
    mov rbp, rsp
    
    ; Extract operands
    mov ecx, ebx
    shr ecx, 21
    and ecx, 0x1F  ; rs1
    
    mov edx, ebx
    shr edx, 16
    and edx, 0x1F  ; rs2
    
    ; Load values
    mov r8, [r13 + VM_GPRS + rcx * 8]
    mov r9, [r13 + VM_GPRS + rdx * 8]
    
    ; Compare
    cmp r8, r9
    je .no_branch
    
    ; Extract offset
    mov eax, ebx
    shl eax, 19
    sar eax, 18
    movsx rax, eax
    
    ; Update PC
    add [r13 + VM_PC], rax
    sub qword [r13 + VM_PC], 4
    
    inc qword [r13 + VM_PERF + PERF_BRANCH_MISS * 8]
    
.no_branch:
    pop rbp
    ret

; Execute BLT (branch if less than) instruction
execute_blt:
    push rbp
    mov rbp, rsp
    
    ; Extract operands
    mov ecx, ebx
    shr ecx, 21
    and ecx, 0x1F  ; rs1
    
    mov edx, ebx
    shr edx, 16
    and edx, 0x1F  ; rs2
    
    ; Load values
    mov r8, [r13 + VM_GPRS + rcx * 8]
    mov r9, [r13 + VM_GPRS + rdx * 8]
    
    ; Signed compare
    cmp r8, r9
    jge .no_branch
    
    ; Extract offset
    mov eax, ebx
    shl eax, 19
    sar eax, 18
    movsx rax, eax
    
    ; Update PC
    add [r13 + VM_PC], rax
    sub qword [r13 + VM_PC], 4
    
    inc qword [r13 + VM_PERF + PERF_BRANCH_MISS * 8]
    
.no_branch:
    pop rbp
    ret

; Execute BGE (branch if greater or equal) instruction
execute_bge:
    push rbp
    mov rbp, rsp
    
    ; Extract operands
    mov ecx, ebx
    shr ecx, 21
    and ecx, 0x1F  ; rs1
    
    mov edx, ebx
    shr edx, 16
    and edx, 0x1F  ; rs2
    
    ; Load values
    mov r8, [r13 + VM_GPRS + rcx * 8]
    mov r9, [r13 + VM_GPRS + rdx * 8]
    
    ; Signed compare
    cmp r8, r9
    jl .no_branch
    
    ; Extract offset
    mov eax, ebx
    shl eax, 19
    sar eax, 18
    movsx rax, eax
    
    ; Update PC
    add [r13 + VM_PC], rax
    sub qword [r13 + VM_PC], 4
    
    inc qword [r13 + VM_PERF + PERF_BRANCH_MISS * 8]
    
.no_branch:
    pop rbp
    ret

; Execute BLTU (branch if less than unsigned) instruction
execute_bltu:
    push rbp
    mov rbp, rsp
    
    ; Extract operands
    mov ecx, ebx
    shr ecx, 21
    and ecx, 0x1F  ; rs1
    
    mov edx, ebx
    shr edx, 16
    and edx, 0x1F  ; rs2
    
    ; Load values
    mov r8, [r13 + VM_GPRS + rcx * 8]
    mov r9, [r13 + VM_GPRS + rdx * 8]
    
    ; Unsigned compare
    cmp r8, r9
    jae .no_branch
    
    ; Extract offset
    mov eax, ebx
    shl eax, 19
    sar eax, 18
    movsx rax, eax
    
    ; Update PC
    add [r13 + VM_PC], rax
    sub qword [r13 + VM_PC], 4
    
    inc qword [r13 + VM_PERF + PERF_BRANCH_MISS * 8]
    
.no_branch:
    pop rbp
    ret

; Execute BGEU (branch if greater or equal unsigned) instruction
execute_bgeu:
    push rbp
    mov rbp, rsp
    
    ; Extract operands
    mov ecx, ebx
    shr ecx, 21
    and ecx, 0x1F  ; rs1
    
    mov edx, ebx
    shr edx, 16
    and edx, 0x1F  ; rs2
    
    ; Load values
    mov r8, [r13 + VM_GPRS + rcx * 8]
    mov r9, [r13 + VM_GPRS + rdx * 8]
    
    ; Unsigned compare
    cmp r8, r9
    jb .no_branch
    
    ; Extract offset
    mov eax, ebx
    shl eax, 19
    sar eax, 18
    movsx rax, eax
    
    ; Update PC
    add [r13 + VM_PC], rax
    sub qword [r13 + VM_PC], 4
    
    inc qword [r13 + VM_PERF + PERF_BRANCH_MISS * 8]
    
.no_branch:
    pop rbp
    ret

; Execute JMP (jump and link) instruction
execute_jmp:
    push rbp
    mov rbp, rsp
    
    ; Extract operands
    mov eax, ebx
    shr eax, 21
    and eax, 0x1F  ; rd (link register)
    
    mov ecx, ebx
    shr ecx, 16
    and ecx, 0x1F  ; rs1 (base)
    
    ; Extract immediate offset
    movsx rdx, bx
    
    ; Calculate target address
    mov r8, [r13 + VM_GPRS + rcx * 8]
    add r8, rdx
    
    ; Save return address if rd != 0
    test eax, eax
    jz .no_link
    mov r9, [r13 + VM_PC]
    mov [r13 + VM_GPRS + rax * 8], r9
    
.no_link:
    ; Jump to target
    mov [r13 + VM_PC], r8
    
    pop rbp
    ret

; Execute CALL instruction
execute_call:
    push rbp
    mov rbp, rsp
    
    ; Extract 26-bit offset
    mov eax, ebx
    and eax, 0x3FFFFFF
    shl eax, 6  ; Sign bit in position
    sar eax, 4  ; Sign extend and scale by 4
    movsx rax, eax
    
    ; Save return address in R31
    mov rdx, [r13 + VM_PC]
    mov [r13 + VM_GPRS + 31 * 8], rdx
    
    ; Update PC
    add [r13 + VM_PC], rax
    sub qword [r13 + VM_PC], 4
    
    pop rbp
    ret

; Execute RET instruction
execute_ret:
    ; Simple implementation: JMP to R31
    mov rax, [r13 + VM_GPRS + 31 * 8]
    mov [r13 + VM_PC], rax
    ret

; Execute SYSCALL instruction
execute_syscall:
    push rbp
    mov rbp, rsp
    
    ; Extract immediate
    movzx edi, bx
    
    ; System call number in R0
    mov rax, [r13 + VM_GPRS + 0 * 8]
    
    ; Handle basic system calls
    cmp rax, 1  ; SYS_WRITE
    je .sys_write
    cmp rax, 60 ; SYS_EXIT
    je .sys_exit
    
    ; Unknown syscall
    mov qword [r13 + VM_GPRS + 0 * 8], -1  ; Return error
    jmp .done
    
.sys_write:
    ; fd in R1, buffer in R2, count in R3
    ; For now, just simulate success
    mov rax, [r13 + VM_GPRS + 3 * 8]  ; Return count
    mov [r13 + VM_GPRS + 0 * 8], rax
    jmp .done
    
.sys_exit:
    ; Exit code in R1
    or byte [r13 + VM_FLAGS], 0x80  ; Set halt flag
    
.done:
    pop rbp
    ret

; Execute HALT instruction
execute_halt:
    or byte [r13 + VM_FLAGS], 0x80  ; Set halt flag
    ret

; Execute NOP instruction
execute_nop:
    ; No operation
    ret

; Execute CPUID instruction
execute_cpuid:
    push rbp
    mov rbp, rsp
    
    ; Extract operands
    mov eax, ebx
    shr eax, 21
    and eax, 0x1F  ; rd
    
    ; For now, return a simple CPU ID
    mov rcx, 0x4E616E6F436F7265  ; "NanoCore"
    
    ; Store result (skip if rd = 0)
    test eax, eax
    jz .done
    mov [r13 + VM_GPRS + rax * 8], rcx
    
.done:
    pop rbp
    ret

; Execute RDCYCLE instruction
execute_rdcycle:
    push rbp
    mov rbp, rsp
    
    ; Extract operands
    mov eax, ebx
    shr eax, 21
    and eax, 0x1F  ; rd
    
    ; Read cycle counter
    rdtsc
    shl rdx, 32
    or rax, rdx
    
    ; Store result (skip if rd = 0)
    mov ecx, ebx
    shr ecx, 21
    and ecx, 0x1F
    test ecx, ecx
    jz .done
    mov [r13 + VM_GPRS + rcx * 8], rax
    
.done:
    pop rbp
    ret

; Execute RDPERF instruction
execute_rdperf:
    push rbp
    mov rbp, rsp
    
    ; Extract operands
    mov eax, ebx
    shr eax, 21
    and eax, 0x1F  ; rd
    
    mov ecx, ebx
    shr ecx, 16
    and ecx, 0x1F  ; rs1 (perf counter index)
    
    ; Get perf counter index
    mov rdx, [r13 + VM_GPRS + rcx * 8]
    and rdx, 7  ; Limit to 8 counters
    
    ; Read performance counter
    mov rax, [r13 + VM_PERF + rdx * 8]
    
    ; Store result (skip if rd = 0)
    mov ecx, ebx
    shr ecx, 21
    and ecx, 0x1F
    test ecx, ecx
    jz .done
    mov [r13 + VM_GPRS + rcx * 8], rax
    
.done:
    pop rbp
    ret

; Execute PREFETCH instruction
execute_prefetch:
    push rbp
    mov rbp, rsp
    
    ; Extract operands
    mov ecx, ebx
    shr ecx, 16
    and ecx, 0x1F  ; rs1
    
    ; Extract immediate offset
    movsx rdx, bx
    
    ; Calculate effective address
    mov rdi, [r13 + VM_GPRS + rcx * 8]
    add rdi, rdx
    
    ; Prefetch cache line
    prefetchnta [rdi]
    
    pop rbp
    ret

; Execute CLFLUSH instruction
execute_clflush:
    push rbp
    mov rbp, rsp
    
    ; Extract operands
    mov ecx, ebx
    shr ecx, 16
    and ecx, 0x1F  ; rs1
    
    ; Extract immediate offset
    movsx rdx, bx
    
    ; Calculate effective address
    mov rdi, [r13 + VM_GPRS + rcx * 8]
    add rdi, rdx
    
    ; Flush cache line
    clflush [rdi]
    
    pop rbp
    ret

; Execute FENCE instruction
execute_fence:
    ; Memory fence
    mfence
    ret

; Execute LR (load reserved) instruction
execute_lr:
    push rbp
    mov rbp, rsp
    
    ; Extract operands
    mov eax, ebx
    shr eax, 21
    and eax, 0x1F  ; rd
    
    mov ecx, ebx
    shr ecx, 16
    and ecx, 0x1F  ; rs1
    
    ; Load address
    mov rdi, [r13 + VM_GPRS + rcx * 8]
    
    ; Perform atomic load
    mov rax, [rdi]
    
    ; Store reservation address
    mov [r13 + VM_VBASE], rdi  ; Use VBASE as reservation register
    
    ; Store result (skip if rd = 0)
    test eax, eax
    jz .done
    mov ecx, ebx
    shr ecx, 21
    and ecx, 0x1F
    mov [r13 + VM_GPRS + rcx * 8], rax
    
.done:
    pop rbp
    ret

; Execute SC (store conditional) instruction
execute_sc:
    push rbp
    mov rbp, rsp
    
    ; Extract operands
    mov eax, ebx
    shr eax, 21
    and eax, 0x1F  ; rd
    
    mov ecx, ebx
    shr ecx, 16
    and ecx, 0x1F  ; rs1 (address)
    
    mov edx, ebx
    shr edx, 11
    and edx, 0x1F  ; rs2 (value)
    
    ; Load address and value
    mov rdi, [r13 + VM_GPRS + rcx * 8]
    mov rsi, [r13 + VM_GPRS + rdx * 8]
    
    ; Check reservation
    cmp rdi, [r13 + VM_VBASE]
    jne .fail
    
    ; Attempt store
    mov [rdi], rsi
    xor ecx, ecx  ; Success
    jmp .store_result
    
.fail:
    mov ecx, 1  ; Failure
    
.store_result:
    ; Store result (skip if rd = 0)
    test eax, eax
    jz .done
    mov eax, ebx
    shr eax, 21
    and eax, 0x1F
    mov [r13 + VM_GPRS + rax * 8], rcx
    
    ; Clear reservation
    mov qword [r13 + VM_VBASE], 0
    
.done:
    pop rbp
    ret

; Execute AMOSWAP (atomic swap) instruction
execute_amoswap:
    push rbp
    mov rbp, rsp
    
    ; Extract operands
    mov eax, ebx
    shr eax, 21
    and eax, 0x1F  ; rd
    
    mov ecx, ebx
    shr ecx, 16
    and ecx, 0x1F  ; rs1 (address)
    
    mov edx, ebx
    shr edx, 11
    and edx, 0x1F  ; rs2 (value)
    
    ; Load address and value
    mov rdi, [r13 + VM_GPRS + rcx * 8]
    mov rsi, [r13 + VM_GPRS + rdx * 8]
    
    ; Atomic exchange
    xchg [rdi], rsi
    
    ; Store old value (skip if rd = 0)
    test eax, eax
    jz .done
    mov [r13 + VM_GPRS + rax * 8], rsi
    
.done:
    pop rbp
    ret

; Execute AMOADD (atomic add) instruction
execute_amoadd:
    push rbp
    mov rbp, rsp
    
    ; Extract operands
    mov eax, ebx
    shr eax, 21
    and eax, 0x1F  ; rd
    
    mov ecx, ebx
    shr ecx, 16
    and ecx, 0x1F  ; rs1 (address)
    
    mov edx, ebx
    shr edx, 11
    and edx, 0x1F  ; rs2 (value)
    
    ; Load address and value
    mov rdi, [r13 + VM_GPRS + rcx * 8]
    mov rsi, [r13 + VM_GPRS + rdx * 8]
    
    ; Atomic add (fetch and add)
    lock xadd [rdi], rsi
    
    ; Store old value (skip if rd = 0)
    test eax, eax
    jz .done
    mov [r13 + VM_GPRS + rax * 8], rsi
    
.done:
    pop rbp
    ret

; Execute AMOAND (atomic AND) instruction
execute_amoand:
    push rbp
    mov rbp, rsp
    push rbx
    
    ; Extract operands
    mov eax, ebx
    shr eax, 21
    and eax, 0x1F  ; rd
    
    mov ecx, ebx
    shr ecx, 16
    and ecx, 0x1F  ; rs1 (address)
    
    mov edx, ebx
    shr edx, 11
    and edx, 0x1F  ; rs2 (value)
    
    ; Load address and value
    mov rdi, [r13 + VM_GPRS + rcx * 8]
    mov rsi, [r13 + VM_GPRS + rdx * 8]
    
    ; Atomic AND using compare-exchange loop
.retry:
    mov rax, [rdi]
    mov rbx, rax
    and rbx, rsi
    lock cmpxchg [rdi], rbx
    jnz .retry
    
    ; Store old value (skip if rd = 0)
    mov ecx, ebx
    shr ecx, 21
    and ecx, 0x1F
    test ecx, ecx
    jz .done
    mov [r13 + VM_GPRS + rcx * 8], rax
    
.done:
    pop rbx
    pop rbp
    ret

; Execute AMOOR (atomic OR) instruction
execute_amoor:
    push rbp
    mov rbp, rsp
    push rbx
    
    ; Extract operands
    mov eax, ebx
    shr eax, 21
    and eax, 0x1F  ; rd
    
    mov ecx, ebx
    shr ecx, 16
    and ecx, 0x1F  ; rs1 (address)
    
    mov edx, ebx
    shr edx, 11
    and edx, 0x1F  ; rs2 (value)
    
    ; Load address and value
    mov rdi, [r13 + VM_GPRS + rcx * 8]
    mov rsi, [r13 + VM_GPRS + rdx * 8]
    
    ; Atomic OR using compare-exchange loop
.retry:
    mov rax, [rdi]
    mov rbx, rax
    or rbx, rsi
    lock cmpxchg [rdi], rbx
    jnz .retry
    
    ; Store old value (skip if rd = 0)
    mov ecx, ebx
    shr ecx, 21
    and ecx, 0x1F
    test ecx, ecx
    jz .done
    mov [r13 + VM_GPRS + rcx * 8], rax
    
.done:
    pop rbx
    pop rbp
    ret

; Execute AMOXOR (atomic XOR) instruction
execute_amoxor:
    push rbp
    mov rbp, rsp
    push rbx
    
    ; Extract operands
    mov eax, ebx
    shr eax, 21
    and eax, 0x1F  ; rd
    
    mov ecx, ebx
    shr ecx, 16
    and ecx, 0x1F  ; rs1 (address)
    
    mov edx, ebx
    shr edx, 11
    and edx, 0x1F  ; rs2 (value)
    
    ; Load address and value
    mov rdi, [r13 + VM_GPRS + rcx * 8]
    mov rsi, [r13 + VM_GPRS + rdx * 8]
    
    ; Atomic XOR using compare-exchange loop
.retry:
    mov rax, [rdi]
    mov rbx, rax
    xor rbx, rsi
    lock cmpxchg [rdi], rbx
    jnz .retry
    
    ; Store old value (skip if rd = 0)
    mov ecx, ebx
    shr ecx, 21
    and ecx, 0x1F
    test ecx, ecx
    jz .done
    mov [r13 + VM_GPRS + rcx * 8], rax
    
.done:
    pop rbx
    pop rbp
    ret

; SIMD VSUB.F64 implementation
execute_vsub_f64:
    push rbp
    mov rbp, rsp
    
    ; Extract operands
    mov eax, ebx
    shr eax, 21
    and eax, 0xF  ; vd
    
    mov ecx, ebx
    shr ecx, 16
    and ecx, 0xF  ; vs1
    
    mov edx, ebx
    shr edx, 11
    and edx, 0xF  ; vs2
    
    ; Load vector operands
    lea rsi, [r13 + VM_VREGS + rcx * 32]
    lea rdi, [r13 + VM_VREGS + rdx * 32]
    lea r8, [r13 + VM_VREGS + rax * 32]
    
    ; Perform vector subtraction (4x double precision)
    vmovupd ymm0, [rsi]
    vmovupd ymm1, [rdi]
    vsubpd ymm2, ymm0, ymm1
    vmovupd [r8], ymm2
    
    ; Update SIMD operation counter
    inc qword [r13 + VM_PERF + PERF_SIMD_OPS * 8]
    
    pop rbp
    ret

; SIMD VMUL.F64 implementation
execute_vmul_f64:
    push rbp
    mov rbp, rsp
    
    ; Extract operands
    mov eax, ebx
    shr eax, 21
    and eax, 0xF  ; vd
    
    mov ecx, ebx
    shr ecx, 16
    and ecx, 0xF  ; vs1
    
    mov edx, ebx
    shr edx, 11
    and edx, 0xF  ; vs2
    
    ; Load vector operands
    lea rsi, [r13 + VM_VREGS + rcx * 32]
    lea rdi, [r13 + VM_VREGS + rdx * 32]
    lea r8, [r13 + VM_VREGS + rax * 32]
    
    ; Perform vector multiplication (4x double precision)
    vmovupd ymm0, [rsi]
    vmovupd ymm1, [rdi]
    vmulpd ymm2, ymm0, ymm1
    vmovupd [r8], ymm2
    
    ; Update SIMD operation counter
    inc qword [r13 + VM_PERF + PERF_SIMD_OPS * 8]
    
    pop rbp
    ret

; SIMD VFMA.F64 implementation (fused multiply-add)
execute_vfma_f64:
    push rbp
    mov rbp, rsp
    
    ; Extract operands
    mov eax, ebx
    shr eax, 21
    and eax, 0xF  ; vd
    
    mov ecx, ebx
    shr ecx, 16
    and ecx, 0xF  ; vs1
    
    mov edx, ebx
    shr edx, 11
    and edx, 0xF  ; vs2
    
    mov r8d, ebx
    shr r8d, 7
    and r8d, 0xF  ; vs3
    
    ; Load vector operands
    lea rsi, [r13 + VM_VREGS + rcx * 32]
    lea rdi, [r13 + VM_VREGS + rdx * 32]
    lea r9, [r13 + VM_VREGS + r8 * 32]
    lea r10, [r13 + VM_VREGS + rax * 32]
    
    ; Perform vector FMA (vd = vs1 * vs2 + vs3)
    vmovupd ymm0, [rsi]
    vmovupd ymm1, [rdi]
    vmovupd ymm2, [r9]
    vfmadd231pd ymm2, ymm0, ymm1  ; ymm2 = ymm0 * ymm1 + ymm2
    vmovupd [r10], ymm2
    
    ; Update SIMD operation counter
    inc qword [r13 + VM_PERF + PERF_SIMD_OPS * 8]
    
    pop rbp
    ret

; SIMD VLOAD implementation
execute_vload:
    push rbp
    mov rbp, rsp
    
    ; Extract operands
    mov eax, ebx
    shr eax, 21
    and eax, 0xF  ; vd
    
    mov ecx, ebx
    shr ecx, 16
    and ecx, 0x1F  ; rs1 (base address)
    
    ; Extract immediate offset
    movsx rdx, bx
    
    ; Calculate effective address
    mov rdi, [r13 + VM_GPRS + rcx * 8]
    add rdi, rdx
    
    ; Load 256-bit vector
    lea r8, [r13 + VM_VREGS + rax * 32]
    vmovupd ymm0, [rdi]
    vmovupd [r8], ymm0
    
    ; Update counters
    inc qword [r13 + VM_PERF + PERF_MEM_OPS * 8]
    inc qword [r13 + VM_PERF + PERF_SIMD_OPS * 8]
    
    pop rbp
    ret

; SIMD VSTORE implementation
execute_vstore:
    push rbp
    mov rbp, rsp
    
    ; Extract operands
    mov eax, ebx
    shr eax, 16
    and eax, 0x1F  ; rs1 (base address)
    
    mov ecx, ebx
    shr ecx, 11
    and ecx, 0xF  ; vs2 (vector to store)
    
    ; Extract immediate offset
    movsx rdx, bx
    
    ; Calculate effective address
    mov rdi, [r13 + VM_GPRS + rax * 8]
    add rdi, rdx
    
    ; Store 256-bit vector
    lea r8, [r13 + VM_VREGS + rcx * 32]
    vmovupd ymm0, [r8]
    vmovupd [rdi], ymm0
    
    ; Update counters
    inc qword [r13 + VM_PERF + PERF_MEM_OPS * 8]
    inc qword [r13 + VM_PERF + PERF_SIMD_OPS * 8]
    
    pop rbp
    ret

; SIMD VBROADCAST implementation
execute_vbroadcast:
    push rbp
    mov rbp, rsp
    
    ; Extract operands
    mov eax, ebx
    shr eax, 21
    and eax, 0xF  ; vd
    
    mov ecx, ebx
    shr ecx, 16
    and ecx, 0x1F  ; rs1 (scalar source)
    
    ; Load scalar value
    mov rdx, [r13 + VM_GPRS + rcx * 8]
    
    ; Broadcast to all vector elements
    lea r8, [r13 + VM_VREGS + rax * 32]
    vmovq xmm0, rdx
    vbroadcastsd ymm1, xmm0
    vmovupd [r8], ymm1
    
    ; Update SIMD operation counter
    inc qword [r13 + VM_PERF + PERF_SIMD_OPS * 8]
    
    pop rbp
    ret

; Execute ILLEGAL instruction
execute_illegal:
    ; Set illegal instruction flag and halt
    or byte [r13 + VM_FLAGS], 0x80  ; Set halt flag
    mov rax, 1  ; Return illegal instruction error
    ret

; Utility functions
check_interrupts:
flush_all_caches:
is_breakpoint:
    xor eax, eax
    ret

; Get VM state pointer
; Output: RAX = pointer to VM state
vm_get_state:
    lea rax, [vm_state]
    ret

; Single step execution
; Output: RAX = 0 on success, error code otherwise
vm_step:
    mov rdi, 1
    jmp vm_run

; Dump VM state (for debugging)
vm_dump_state:
    ; Implementation would dump all registers and state
    ret