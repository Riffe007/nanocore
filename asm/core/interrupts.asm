; NanoCore Interrupt and Exception Handling
; Implements interrupt controller, exception handling, and trap mechanisms
;
; Features:
; - 256 interrupt vectors
; - Nested interrupt support
; - Fast interrupt handling
; - Exception types: page fault, divide by zero, illegal instruction, etc.
; - Software interrupts (traps)
; - Interrupt priority levels

BITS 64
SECTION .text

; Constants
%define MAX_INTERRUPTS 256
%define MAX_PRIORITY 15
%define IRQ_BASE 32         ; Hardware interrupts start at vector 32

; Exception vectors
%define EXC_DIVIDE_ERROR 0
%define EXC_DEBUG 1
%define EXC_NMI 2
%define EXC_BREAKPOINT 3
%define EXC_OVERFLOW 4
%define EXC_BOUND_RANGE 5
%define EXC_INVALID_OPCODE 6
%define EXC_DEVICE_NOT_AVAIL 7
%define EXC_DOUBLE_FAULT 8
%define EXC_INVALID_TSS 10
%define EXC_SEGMENT_NOT_PRESENT 11
%define EXC_STACK_SEGMENT 12
%define EXC_GENERAL_PROTECTION 13
%define EXC_PAGE_FAULT 14
%define EXC_FPU_ERROR 16
%define EXC_ALIGNMENT_CHECK 17
%define EXC_MACHINE_CHECK 18
%define EXC_SIMD_ERROR 19

; Interrupt flags
%define INT_FLAG_PENDING 0x01
%define INT_FLAG_MASKED 0x02
%define INT_FLAG_EDGE 0x04
%define INT_FLAG_LEVEL 0x08
%define INT_FLAG_AUTO_EOI 0x10

; Global symbols
global interrupt_init
global interrupt_enable
global interrupt_disable
global interrupt_register
global interrupt_unregister
global interrupt_mask
global interrupt_unmask
global interrupt_eoi
global raise_interrupt
global raise_exception
global check_interrupts
global get_pending_interrupt
global set_interrupt_priority
global interrupt_handler

; External symbols
extern vm_state
extern pipeline_flush
extern memory_read
extern memory_write

SECTION .bss
align 64
; Interrupt vector table
ivt: resq MAX_INTERRUPTS            ; Handler addresses

; Interrupt controller state
int_pending: resb MAX_INTERRUPTS    ; Pending interrupts bitmap
int_masked: resb MAX_INTERRUPTS     ; Masked interrupts bitmap
int_priority: resb MAX_INTERRUPTS   ; Interrupt priorities
int_flags: resb MAX_INTERRUPTS      ; Interrupt flags
int_in_service: resb MAX_PRIORITY + 1  ; ISR stack

; Interrupt statistics
int_count: resq MAX_INTERRUPTS      ; Interrupt counters
int_cycles: resq 1                  ; Total interrupt cycles
int_nested: resq 1                  ; Nested interrupt count

; CPU interrupt state
int_enabled: resb 1                 ; Global interrupt enable
int_nesting_level: resb 1           ; Current nesting level
saved_context: resq 32              ; Saved register context

SECTION .text

; Initialize interrupt subsystem
interrupt_init:
    push rbp
    mov rbp, rsp
    push rdi
    push rcx
    
    ; Clear interrupt vector table
    lea rdi, [ivt]
    lea rax, [default_handler]
    mov ecx, MAX_INTERRUPTS
.init_ivt:
    stosq
    loop .init_ivt
    
    ; Initialize exception handlers
    lea rax, [exc_divide_error]
    mov [ivt + EXC_DIVIDE_ERROR * 8], rax
    lea rax, [exc_page_fault]
    mov [ivt + EXC_PAGE_FAULT * 8], rax
    lea rax, [exc_general_protection]
    mov [ivt + EXC_GENERAL_PROTECTION * 8], rax
    lea rax, [exc_invalid_opcode]
    mov [ivt + EXC_INVALID_OPCODE * 8], rax
    
    ; Clear interrupt state
    lea rdi, [int_pending]
    xor eax, eax
    mov ecx, MAX_INTERRUPTS * 4 / 8
    rep stosq
    
    ; Set default priorities
    lea rdi, [int_priority]
    mov ecx, 32
    mov al, 15              ; Exceptions have highest priority
    rep stosb
    mov ecx, MAX_INTERRUPTS - 32
    mov al, 7               ; Default priority for IRQs
    rep stosb
    
    ; Clear statistics
    lea rdi, [int_count]
    xor eax, eax
    mov ecx, MAX_INTERRUPTS + 2
    rep stosq
    
    ; Enable interrupts
    mov byte [int_enabled], 1
    mov byte [int_nesting_level], 0
    
    pop rcx
    pop rdi
    pop rbp
    ret

; Enable interrupts globally
interrupt_enable:
    mov byte [int_enabled], 1
    or byte [vm_state + 16], (1 << 4)  ; Set IE flag in VM
    ret

; Disable interrupts globally
interrupt_disable:
    mov byte [int_enabled], 0
    and byte [vm_state + 16], ~(1 << 4)  ; Clear IE flag
    ret

; Register interrupt handler
; Input: RDI = vector, RSI = handler address
interrupt_register:
    cmp rdi, MAX_INTERRUPTS
    jae .error
    
    mov [ivt + rdi * 8], rsi
    xor eax, eax
    ret
    
.error:
    mov rax, -1
    ret

; Unregister interrupt handler
; Input: RDI = vector
interrupt_unregister:
    cmp rdi, MAX_INTERRUPTS
    jae .error
    
    lea rax, [default_handler]
    mov [ivt + rdi * 8], rax
    xor eax, eax
    ret
    
.error:
    mov rax, -1
    ret

; Mask interrupt
; Input: RDI = vector
interrupt_mask:
    cmp rdi, MAX_INTERRUPTS
    jae .done
    
    or byte [int_masked + rdi], 1
    or byte [int_flags + rdi], INT_FLAG_MASKED
    
.done:
    ret

; Unmask interrupt
; Input: RDI = vector
interrupt_unmask:
    cmp rdi, MAX_INTERRUPTS
    jae .done
    
    and byte [int_masked + rdi], 0
    and byte [int_flags + rdi], ~INT_FLAG_MASKED
    
.done:
    ret

; End of interrupt
; Input: RDI = vector
interrupt_eoi:
    push rbx
    
    ; Get priority
    movzx ebx, byte [int_priority + rdi]
    
    ; Clear in-service bit
    and byte [int_in_service + rbx], 0
    
    ; Clear pending if level-triggered
    test byte [int_flags + rdi], INT_FLAG_LEVEL
    jz .done
    and byte [int_pending + rdi], 0
    
.done:
    pop rbx
    ret

; Raise interrupt
; Input: RDI = vector
raise_interrupt:
    cmp rdi, MAX_INTERRUPTS
    jae .done
    
    ; Set pending bit
    or byte [int_pending + rdi], 1
    or byte [int_flags + rdi], INT_FLAG_PENDING
    
    ; Increment counter
    inc qword [int_count + rdi * 8]
    
.done:
    ret

; Raise exception
; Input: RDI = exception vector, RSI = error code
raise_exception:
    push rbp
    mov rbp, rsp
    push rbx
    push rcx
    
    ; Save error code
    push rsi
    
    ; Exceptions bypass normal interrupt logic
    cmp byte [int_nesting_level], 15
    jae .double_fault
    
    ; Save context
    call save_context
    
    ; Call exception handler directly
    mov rax, [ivt + rdi * 8]
    pop rdi                 ; Error code
    call rax
    
    ; Restore context
    call restore_context
    
    jmp .done
    
.double_fault:
    ; Triple fault - halt CPU
    or byte [vm_state + 16], 0x80  ; Set halt flag
    
.done:
    pop rcx
    pop rbx
    pop rbp
    ret

; Check for pending interrupts
; Output: RAX = 1 if interrupt pending, 0 otherwise
check_interrupts:
    push rbx
    push rcx
    push rdx
    
    ; Check if interrupts enabled
    cmp byte [int_enabled], 0
    je .no_interrupt
    
    ; Check VM interrupt enable flag
    test byte [vm_state + 16], (1 << 4)
    jz .no_interrupt
    
    ; Find highest priority pending interrupt
    call get_pending_interrupt
    test rax, rax
    js .no_interrupt
    
    ; Handle the interrupt
    mov rdi, rax
    call handle_interrupt
    
    mov rax, 1
    jmp .done
    
.no_interrupt:
    xor eax, eax
    
.done:
    pop rdx
    pop rcx
    pop rbx
    ret

; Get highest priority pending interrupt
; Output: RAX = vector (-1 if none)
get_pending_interrupt:
    push rbx
    push rcx
    push rdx
    push rsi
    
    mov rax, -1             ; Default: no interrupt
    mov dl, 255             ; Lowest priority
    
    ; Scan all vectors
    xor ecx, ecx
.scan_loop:
    ; Check if pending and not masked
    test byte [int_pending + rcx], 1
    jz .next
    test byte [int_masked + rcx], 1
    jnz .next
    
    ; Check priority
    movzx ebx, byte [int_priority + rcx]
    
    ; Check if already in service at this priority
    test byte [int_in_service + rbx], 1
    jnz .next
    
    ; Compare with current best
    cmp bl, dl
    jae .next
    
    mov dl, bl              ; New best priority
    mov eax, ecx            ; New best vector
    
.next:
    inc ecx
    cmp ecx, MAX_INTERRUPTS
    jl .scan_loop
    
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    ret

; Set interrupt priority
; Input: RDI = vector, RSI = priority (0-15)
set_interrupt_priority:
    cmp rdi, MAX_INTERRUPTS
    jae .error
    cmp rsi, MAX_PRIORITY
    ja .error
    
    mov [int_priority + rdi], sil
    xor eax, eax
    ret
    
.error:
    mov rax, -1
    ret

; Handle interrupt
; Input: RDI = vector
handle_interrupt:
    push rbp
    mov rbp, rsp
    push rbx
    
    ; Save context
    call save_context
    
    ; Update statistics
    rdtsc
    push rdx
    push rax
    
    ; Clear pending bit for edge-triggered
    test byte [int_flags + rdi], INT_FLAG_EDGE
    jz .skip_clear
    and byte [int_pending + rdi], 0
    
.skip_clear:
    ; Mark in-service
    movzx ebx, byte [int_priority + rdi]
    or byte [int_in_service + rbx], 1
    
    ; Increment nesting level
    inc byte [int_nesting_level]
    cmp byte [int_nesting_level], 1
    jne .nested
    inc qword [int_nested]
    
.nested:
    ; Enable interrupts for nested handling
    sti
    
    ; Call handler
    push rdi                ; Save vector
    mov rax, [ivt + rdi * 8]
    call rax
    pop rdi
    
    ; Disable interrupts
    cli
    
    ; Auto EOI if configured
    test byte [int_flags + rdi], INT_FLAG_AUTO_EOI
    jz .no_auto_eoi
    call interrupt_eoi
    
.no_auto_eoi:
    ; Decrement nesting level
    dec byte [int_nesting_level]
    
    ; Update cycle count
    rdtsc
    pop rbx                 ; Original low
    pop rcx                 ; Original high
    sub rax, rbx
    sbb rdx, rcx
    add [int_cycles], rax
    adc [int_cycles + 8], rdx
    
    ; Restore context
    call restore_context
    
    pop rbx
    pop rbp
    ret

; Save CPU context
save_context:
    push rdi
    push rcx
    
    ; Save all GPRs
    lea rdi, [saved_context]
    lea rsi, [vm_state + 24]    ; VM_GPRS
    mov ecx, 32
    rep movsq
    
    pop rcx
    pop rdi
    ret

; Restore CPU context
restore_context:
    push rsi
    push rdi
    push rcx
    
    ; Restore all GPRs
    lea rsi, [saved_context]
    lea rdi, [vm_state + 24]    ; VM_GPRS
    mov ecx, 32
    rep movsq
    
    pop rcx
    pop rdi
    pop rsi
    ret

; Default interrupt handler
default_handler:
    ; Just return - interrupt ignored
    ret

; Exception handlers

; Divide error exception
exc_divide_error:
    push rbp
    mov rbp, rsp
    
    ; Set exception flag in VM
    or byte [vm_state + 16], 0x80  ; Halt
    
    ; Could implement recovery logic here
    
    pop rbp
    ret

; Page fault exception
; Input: RDI = error code
exc_page_fault:
    push rbp
    mov rbp, rsp
    push rbx
    
    ; Get faulting address (would be in CR2 on real x86)
    ; For now, use the current PC
    mov rbx, [vm_state + 0]     ; VM_PC
    
    ; Extract error code bits
    mov rax, rdi
    and rax, 0x7                ; P, W, U bits
    
    ; Call page fault handler in memory subsystem
    mov rdi, rbx                ; Faulting address
    mov rsi, rax                ; Fault type
    extern page_fault_handler
    call page_fault_handler
    
    ; Check if handled successfully
    test rax, rax
    jnz .fatal
    
    ; Successfully handled - return
    jmp .done
    
.fatal:
    ; Unhandled page fault - halt
    or byte [vm_state + 16], 0x80
    
.done:
    pop rbx
    pop rbp
    ret

; General protection fault
exc_general_protection:
    push rbp
    mov rbp, rsp
    
    ; Log the fault
    inc qword [int_count + EXC_GENERAL_PROTECTION * 8]
    
    ; Halt VM
    or byte [vm_state + 16], 0x80
    
    pop rbp
    ret

; Invalid opcode exception
exc_invalid_opcode:
    push rbp
    mov rbp, rsp
    
    ; Could implement opcode emulation here
    
    ; For now, just halt
    or byte [vm_state + 16], 0x80
    
    pop rbp
    ret

; Software interrupt handler (INT instruction)
; Input: RDI = interrupt vector
interrupt_handler:
    push rbp
    mov rbp, rsp
    
    ; Validate vector
    cmp rdi, MAX_INTERRUPTS
    jae .invalid
    
    ; Check if masked
    test byte [int_masked + rdi], 1
    jnz .masked
    
    ; Raise the interrupt
    call raise_interrupt
    
    ; Process immediately if enabled
    call check_interrupts
    
    jmp .done
    
.invalid:
.masked:
    ; Return error in RAX
    mov rax, -1
    
.done:
    pop rbp
    ret

; Timer interrupt handler (example device interrupt)
global timer_interrupt
timer_interrupt:
    push rbp
    mov rbp, rsp
    
    ; Update timer counter
    inc qword [vm_state + 0x200]  ; Example timer location
    
    ; Check for timer callbacks
    ; ... implementation ...
    
    pop rbp
    ret

; Enable/disable specific CPU features
global sti  ; Enable interrupts
sti:
    call interrupt_enable
    ret

global cli  ; Disable interrupts
cli:
    call interrupt_disable
    ret