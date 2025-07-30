; NanoCore Interrupts Module
; Handles hardware interrupts, exceptions, and system calls

BITS 64
SECTION .text

; External symbols
extern vm_state
extern memory_read
extern memory_write

; Constants
%define VM_PC 0
%define VM_FLAGS 16
%define VM_GPRS 24
%define VM_VREGS (VM_GPRS + 32 * 8)
%define VM_PERF (VM_VREGS + 16 * 32)

; Interrupt types
%define INT_SYSCALL 0x80
%define INT_BREAKPOINT 0x03
%define INT_PAGE_FAULT 0x0E
%define INT_DIVIDE_ERROR 0x00
%define INT_OVERFLOW 0x04
%define INT_INVALID_OPCODE 0x06
%define INT_DOUBLE_FAULT 0x08
%define INT_TIMER 0x20
%define INT_KEYBOARD 0x21
%define INT_SERIAL 0x24

; Exception error codes
%define ERR_NONE 0
%define ERR_PRESENT 1
%define ERR_WRITE 2
%define ERR_USER 4
%define ERR_RESERVED 8
%define ERR_FETCH 16

; Interrupt descriptor table entry
struc idt_entry
    .offset_low: resw 1     ; Offset bits 0-15
    .selector: resw 1       ; Code segment selector
    .ist: resb 1            ; Interrupt stack table offset
    .flags: resb 1          ; Type and attributes
    .offset_mid: resw 1     ; Offset bits 16-31
    .offset_high: resd 1    ; Offset bits 32-63
    .reserved: resd 1       ; Reserved
endstruc

; Interrupt frame (saved registers)
struc interrupt_frame
    .rax: resq 1
    .rcx: resq 1
    .rdx: resq 1
    .rbx: resq 1
    .rsp: resq 1
    .rbp: resq 1
    .rsi: resq 1
    .rdi: resq 1
    .r8: resq 1
    .r9: resq 1
    .r10: resq 1
    .r11: resq 1
    .r12: resq 1
    .r13: resq 1
    .r14: resq 1
    .r15: resq 1
    .rip: resq 1
    .rflags: resq 1
    .cs: resw 1
    .ss: resw 1
    .error_code: resq 1
    .padding: resq 1
endstruc

; Interrupt state
struc interrupt_state
    .idt: resb idt_entry_size * 256  ; Interrupt descriptor table
    .handlers: resq 256              ; Interrupt handler pointers
    .enabled: resb 1                 ; Interrupts enabled flag
    .nested: resb 1                  ; Nested interrupt counter
    .reserved: resb 6                ; Alignment
    .stats: resq 256                 ; Interrupt statistics
endstruc

; Global symbols
global interrupt_init
global interrupt_enable
global interrupt_disable
global interrupt_register_handler
global interrupt_trigger
global interrupt_dispatch
global exception_handler
global syscall_handler

SECTION .bss
align 64
interrupt_state: resb interrupt_state_size
interrupt_stack: resb 16384  ; 16KB interrupt stack

SECTION .data
align 64
; Default interrupt handlers
default_handlers:
    dq divide_error_handler      ; 0x00
    dq debug_handler             ; 0x01
    dq nmi_handler              ; 0x02
    dq breakpoint_handler        ; 0x03
    dq overflow_handler          ; 0x04
    dq bound_range_handler       ; 0x05
    dq invalid_opcode_handler    ; 0x06
    dq device_not_available_handler ; 0x07
    dq double_fault_handler      ; 0x08
    dq coprocessor_segment_handler ; 0x09
    dq invalid_tss_handler       ; 0x0A
    dq segment_not_present_handler ; 0x0B
    dq stack_segment_fault_handler ; 0x0C
    dq general_protection_handler ; 0x0D
    dq page_fault_handler        ; 0x0E
    dq reserved_handler          ; 0x0F
    dq fpu_error_handler         ; 0x10
    dq alignment_check_handler   ; 0x11
    dq machine_check_handler     ; 0x12
    dq simd_exception_handler    ; 0x13
    dq virtualization_exception_handler ; 0x14
    times 235 dq reserved_handler ; 0x15-0xFF
    dq syscall_handler           ; 0x80

SECTION .text

; Initialize interrupt subsystem
global interrupt_init
interrupt_init:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    
    ; Clear interrupt state
    lea rdi, [interrupt_state]
    xor eax, eax
    mov ecx, interrupt_state_size / 8
    rep stosq
    
    ; Initialize IDT entries
    lea rbx, [interrupt_state + interrupt_state.idt]
    lea r12, [default_handlers]
    mov r13, 0  ; Interrupt number
    
.init_idt:
    cmp r13, 256
    jae .setup_idt
    
    ; Get handler address
    mov rax, [r12 + r13 * 8]
    
    ; Set up IDT entry
    mov [rbx + idt_entry.offset_low], ax
    shr rax, 16
    mov [rbx + idt_entry.offset_mid], ax
    shr rax, 16
    mov [rbx + idt_entry.offset_high], eax
    
    ; Set selector (kernel code segment)
    mov word [rbx + idt_entry.selector], 0x08
    
    ; Set flags (interrupt gate, present, ring 0)
    mov byte [rbx + idt_entry.flags], 0x8E
    
    ; Set IST (interrupt stack table)
    mov byte [rbx + idt_entry.ist], 0
    
    ; Store handler pointer
    lea rdi, [interrupt_state + interrupt_state.handlers]
    mov [rdi + r13 * 8], rax
    
    ; Next entry
    add rbx, idt_entry_size
    inc r13
    jmp .init_idt
    
.setup_idt:
    ; Load IDT
    lea rdi, [interrupt_state + interrupt_state.idt]
    mov rsi, 256 * idt_entry_size - 1
    lidt [rdi]
    
    ; Enable interrupts
    mov byte [interrupt_state + interrupt_state.enabled], 1
    
    ; Clear statistics
    lea rdi, [interrupt_state + interrupt_state.stats]
    xor eax, eax
    mov ecx, 256
    rep stosq
    
    xor eax, eax
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; Enable interrupts
global interrupt_enable
interrupt_enable:
    push rbp
    mov rbp, rsp
    
    ; Set enabled flag
    mov byte [interrupt_state + interrupt_state.enabled], 1
    
    ; Enable hardware interrupts
    sti
    
    pop rbp
    ret

; Disable interrupts
global interrupt_disable
interrupt_disable:
    push rbp
    mov rbp, rsp
    
    ; Disable hardware interrupts
    cli
    
    ; Clear enabled flag
    mov byte [interrupt_state + interrupt_state.enabled], 0
    
    pop rbp
    ret

; Register interrupt handler
; Input: RDI = interrupt number, RSI = handler function
global interrupt_register_handler
interrupt_register_handler:
    push rbp
    mov rbp, rsp
    push rbx
    
    ; Check interrupt number range
    cmp rdi, 256
    jae .error
    
    ; Store handler
    lea rbx, [interrupt_state + interrupt_state.handlers]
    mov [rbx + rdi * 8], rsi
    
    ; Update IDT entry
    lea rbx, [interrupt_state + interrupt_state.idt]
    mov rax, rdi
    imul rax, idt_entry_size
    add rbx, rax
    
    ; Set handler address
    mov [rbx + idt_entry.offset_low], si
    shr rsi, 16
    mov [rbx + idt_entry.offset_mid], si
    shr rsi, 16
    mov [rbx + idt_entry.offset_high], esi
    
    xor eax, eax
    jmp .done
    
.error:
    mov eax, -1
    
.done:
    pop rbx
    pop rbp
    ret

; Trigger interrupt
; Input: RDI = interrupt number
global interrupt_trigger
interrupt_trigger:
    push rbp
    mov rbp, rsp
    push rbx
    
    ; Check if interrupts are enabled
    cmp byte [interrupt_state + interrupt_state.enabled], 0
    je .disabled
    
    ; Check interrupt number range
    cmp rdi, 256
    jae .error
    
    ; Increment nested counter
    inc byte [interrupt_state + interrupt_state.nested]
    
    ; Get handler
    lea rbx, [interrupt_state + interrupt_state.handlers]
    mov rax, [rbx + rdi * 8]
    
    ; Update statistics
    lea rbx, [interrupt_state + interrupt_state.stats]
    inc qword [rbx + rdi * 8]
    
    ; Call handler
    call rax
    
    ; Decrement nested counter
    dec byte [interrupt_state + interrupt_state.nested]
    
    xor eax, eax
    jmp .done
    
.disabled:
    mov eax, -2
    jmp .done
    
.error:
    mov eax, -1
    
.done:
    pop rbx
    pop rbp
    ret

; Interrupt dispatcher (called by hardware)
global interrupt_dispatch
interrupt_dispatch:
    ; Save all registers
    push rax
    push rcx
    push rdx
    push rbx
    push rbp
    push rsi
    push rdi
    push r8
    push r9
    push r10
    push r11
    push r12
    push r13
    push r14
    push r15
    
    ; Get interrupt number from stack
    mov rax, [rsp + 15 * 8]  ; RIP was pushed by hardware
    
    ; Check if it's a system call
    cmp rax, INT_SYSCALL
    je .syscall
    
    ; Regular interrupt
    mov rdi, rax
    call interrupt_trigger
    jmp .restore
    
.syscall:
    ; Handle system call
    call syscall_handler
    
.restore:
    ; Restore registers
    pop r15
    pop r14
    pop r13
    pop r12
    pop r11
    pop r10
    pop r9
    pop r8
    pop rdi
    pop rsi
    pop rbp
    pop rbx
    pop rdx
    pop rcx
    pop rax
    
    iretq

; Exception handler wrapper
; Input: RDI = exception number, RSI = error code, RDX = fault address
global exception_handler
exception_handler:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    
    mov r12, rdi  ; Exception number
    mov r13, rsi  ; Error code
    mov r14, rdx  ; Fault address
    
    ; Log exception
    lea rbx, [interrupt_state + interrupt_state.stats]
    inc qword [rbx + r12 * 8]
    
    ; Handle specific exceptions
    cmp r12, INT_PAGE_FAULT
    je .page_fault
    
    cmp r12, INT_DIVIDE_ERROR
    je .divide_error
    
    cmp r12, INT_INVALID_OPCODE
    je .invalid_opcode
    
    ; Default: halt VM
    jmp .halt
    
.page_fault:
    ; Handle page fault
    mov rdi, r14  ; Fault address
    mov rsi, r13  ; Error code
    call handle_page_fault
    jmp .done
    
.divide_error:
    ; Handle divide by zero
    call handle_divide_error
    jmp .done
    
.invalid_opcode:
    ; Handle invalid opcode
    call handle_invalid_opcode
    jmp .done
    
.halt:
    ; Halt VM on unhandled exception
    lea rbx, [vm_state]
    or byte [rbx + VM_FLAGS], 0x80  ; Set halt flag
    
.done:
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; System call handler
; Input: RAX = system call number, RDI-RSI-RDX-R10-R8-R9 = arguments
global syscall_handler
syscall_handler:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    
    mov r12, rax  ; System call number
    
    ; Update statistics
    lea rbx, [interrupt_state + interrupt_state.stats]
    inc qword [rbx + INT_SYSCALL * 8]
    
    ; Dispatch system call
    cmp r12, 0
    je .syscall_exit
    cmp r12, 1
    je .syscall_read
    cmp r12, 2
    je .syscall_write
    cmp r12, 3
    je .syscall_open
    cmp r12, 4
    je .syscall_close
    cmp r12, 5
    je .syscall_brk
    cmp r12, 6
    je .syscall_gettime
    cmp r12, 7
    je .syscall_sleep
    cmp r12, 8
    je .syscall_fork
    cmp r12, 9
    je .syscall_exec
    cmp r12, 10
    je .syscall_wait
    
    ; Unknown system call
    mov rax, -1
    jmp .done
    
.syscall_exit:
    ; Exit process
    mov rdi, rdi  ; Exit code
    call handle_exit
    jmp .done
    
.syscall_read:
    ; Read from file
    mov rdi, rdi  ; File descriptor
    mov rsi, rsi  ; Buffer
    mov rdx, rdx  ; Count
    call handle_read
    jmp .done
    
.syscall_write:
    ; Write to file
    mov rdi, rdi  ; File descriptor
    mov rsi, rsi  ; Buffer
    mov rdx, rdx  ; Count
    call handle_write
    jmp .done
    
.syscall_open:
    ; Open file
    mov rdi, rdi  ; Pathname
    mov rsi, rsi  ; Flags
    mov rdx, rdx  ; Mode
    call handle_open
    jmp .done
    
.syscall_close:
    ; Close file
    mov rdi, rdi  ; File descriptor
    call handle_close
    jmp .done
    
.syscall_brk:
    ; Change data segment size
    mov rdi, rdi  ; New break
    call handle_brk
    jmp .done
    
.syscall_gettime:
    ; Get current time
    call handle_gettime
    jmp .done
    
.syscall_sleep:
    ; Sleep for specified time
    mov rdi, rdi  ; Seconds
    call handle_sleep
    jmp .done
    
.syscall_fork:
    ; Create new process
    call handle_fork
    jmp .done
    
.syscall_exec:
    ; Execute new program
    mov rdi, rdi  ; Pathname
    mov rsi, rsi  ; Arguments
    call handle_exec
    jmp .done
    
.syscall_wait:
    ; Wait for child process
    mov rdi, rdi  ; Status pointer
    call handle_wait
    jmp .done
    
.done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; Default interrupt handlers

divide_error_handler:
    mov rdi, INT_DIVIDE_ERROR
    xor rsi, rsi
    xor rdx, rdx
    call exception_handler
    iretq

debug_handler:
    iretq

nmi_handler:
    iretq

breakpoint_handler:
    mov rdi, INT_BREAKPOINT
    xor rsi, rsi
    xor rdx, rdx
    call exception_handler
    iretq

overflow_handler:
    mov rdi, INT_OVERFLOW
    xor rsi, rsi
    xor rdx, rdx
    call exception_handler
    iretq

bound_range_handler:
    iretq

invalid_opcode_handler:
    mov rdi, INT_INVALID_OPCODE
    xor rsi, rsi
    xor rdx, rdx
    call exception_handler
    iretq

device_not_available_handler:
    iretq

double_fault_handler:
    mov rdi, INT_DOUBLE_FAULT
    xor rsi, rsi
    xor rdx, rdx
    call exception_handler
    iretq

coprocessor_segment_handler:
    iretq

invalid_tss_handler:
    iretq

segment_not_present_handler:
    iretq

stack_segment_fault_handler:
    iretq

general_protection_handler:
    iretq

page_fault_handler:
    mov rdi, INT_PAGE_FAULT
    mov rsi, [rsp + 8]  ; Error code
    mov rdx, cr2        ; Fault address
    call exception_handler
    iretq

reserved_handler:
    iretq

fpu_error_handler:
    iretq

alignment_check_handler:
    iretq

machine_check_handler:
    iretq

simd_exception_handler:
    iretq

virtualization_exception_handler:
    iretq

; Exception handling functions

handle_page_fault:
    push rbp
    mov rbp, rsp
    
    ; For now, just return error
    mov rax, -1
    
    pop rbp
    ret

handle_divide_error:
    push rbp
    mov rbp, rsp
    
    ; For now, just return error
    mov rax, -1
    
    pop rbp
    ret

handle_invalid_opcode:
    push rbp
    mov rbp, rsp
    
    ; For now, just return error
    mov rax, -1
    
    pop rbp
    ret

; System call handling functions

handle_exit:
    push rbp
    mov rbp, rsp
    
    ; Set exit code and halt VM
    lea rbx, [vm_state]
    mov [rbx + VM_GPRS + 0 * 8], rdi  ; Store exit code in R0
    or byte [rbx + VM_FLAGS], 0x80    ; Set halt flag
    
    mov rax, 0
    pop rbp
    ret

handle_read:
    push rbp
    mov rbp, rsp
    
    ; For now, just return 0 (no data read)
    mov rax, 0
    
    pop rbp
    ret

handle_write:
    push rbp
    mov rbp, rsp
    
    ; For now, just return count (all bytes written)
    mov rax, rdx
    
    pop rbp
    ret

handle_open:
    push rbp
    mov rbp, rsp
    
    ; For now, just return -1 (error)
    mov rax, -1
    
    pop rbp
    ret

handle_close:
    push rbp
    mov rbp, rsp
    
    ; For now, just return 0 (success)
    mov rax, 0
    
    pop rbp
    ret

handle_brk:
    push rbp
    mov rbp, rsp
    
    ; For now, just return current break
    mov rax, 0x1000000  ; 16MB
    
    pop rbp
    ret

handle_gettime:
    push rbp
    mov rbp, rsp
    
    ; For now, just return 0
    mov rax, 0
    
    pop rbp
    ret

handle_sleep:
    push rbp
    mov rbp, rsp
    
    ; For now, just return 0
    mov rax, 0
    
    pop rbp
    ret

handle_fork:
    push rbp
    mov rbp, rsp
    
    ; For now, just return -1 (error)
    mov rax, -1
    
    pop rbp
    ret

handle_exec:
    push rbp
    mov rbp, rsp
    
    ; For now, just return -1 (error)
    mov rax, -1
    
    pop rbp
    ret

handle_wait:
    push rbp
    mov rbp, rsp
    
    ; For now, just return -1 (error)
    mov rax, -1
    
    pop rbp
    ret