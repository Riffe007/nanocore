; NanoCore Hello World Example
; Demonstrates basic I/O and system calls
;
; This program prints "Hello, NanoCore!" to the console

BITS 64

; NanoCore ISA Constants
%define R0 0
%define R1 1
%define R2 2
%define R3 3
%define R4 4
%define R5 5
%define R31 31

; System call numbers
%define SYS_WRITE 1
%define SYS_EXIT 60

; File descriptors
%define STDOUT 1

; Memory addresses
%define TEXT_BASE 0x10000
%define DATA_BASE 0x20000

SECTION .text
ORG TEXT_BASE

_start:
    ; Load string address into R1
    ; In NanoCore assembly, we use custom instruction encoding
    ; Format: opcode(6) | rd(5) | rs1(5) | imm16(16)
    
    ; LDI R1, hello_str (load immediate address)
    db 0x0F, 0x20, 0x00, 0x20  ; LD R1, DATA_BASE
    
    ; Load string length into R2
    ; LDI R2, 17
    db 0x0F, 0x40, 0x00, 0x11  ; LD R2, 17
    
    ; Prepare system call
    ; R0 = syscall number (SYS_WRITE)
    ; R1 = file descriptor (STDOUT)
    ; R2 = buffer address
    ; R3 = length
    
    ; LDI R0, SYS_WRITE
    db 0x0F, 0x00, 0x00, 0x01  ; LD R0, 1
    
    ; Move string address to R2
    ; MOV R2, R1
    db 0x00, 0x41, 0x00, 0x00  ; ADD R2, R1, R0 (with R0=0)
    
    ; LDI R1, STDOUT
    db 0x0F, 0x20, 0x00, 0x01  ; LD R1, 1
    
    ; LDI R3, 17 (string length)
    db 0x0F, 0x60, 0x00, 0x11  ; LD R3, 17
    
    ; SYSCALL
    db 0x80, 0x00, 0x00, 0x00  ; SYSCALL 0
    
    ; Exit program
    ; LDI R0, SYS_EXIT
    db 0x0F, 0x00, 0x00, 0x3C  ; LD R0, 60
    
    ; LDI R1, 0 (exit code)
    db 0x0F, 0x20, 0x00, 0x00  ; LD R1, 0
    
    ; SYSCALL
    db 0x80, 0x00, 0x00, 0x00  ; SYSCALL 0
    
    ; HALT (in case syscall fails)
    db 0x84, 0x00, 0x00, 0x00  ; HALT

SECTION .data
ORG DATA_BASE

hello_str:
    db "Hello, NanoCore!", 0x0A, 0  ; Include newline and null terminator

; Alternative implementation using NanoCore macro syntax
; This would be processed by a NanoCore-specific assembler

%ifdef NANOCORE_MACROS

SECTION .nanocore
_start_macro:
    ; Using high-level NanoCore assembly
    LOAD    R1, hello_str       ; Load string address
    LOAD    R2, 17              ; Load string length
    
    ; Write system call
    LOAD    R0, SYS_WRITE       ; System call number
    MOVE    R3, R2              ; Length in R3
    MOVE    R2, R1              ; Buffer in R2
    LOAD    R1, STDOUT          ; File descriptor
    SYSCALL
    
    ; Exit system call
    LOAD    R0, SYS_EXIT        ; System call number
    LOAD    R1, 0               ; Exit code
    SYSCALL
    
    HALT                        ; Safety halt

; Extended example with loop
print_multiple:
    LOAD    R4, 5               ; Loop counter
    
.loop:
    ; Print message
    LOAD    R1, hello_str
    LOAD    R2, 17
    LOAD    R0, SYS_WRITE
    MOVE    R3, R2
    MOVE    R2, R1
    LOAD    R1, STDOUT
    SYSCALL
    
    ; Decrement counter
    SUB     R4, R4, 1
    BNE     R4, R0, .loop      ; Branch if R4 != 0
    
    ; Exit
    LOAD    R0, SYS_EXIT
    LOAD    R1, 0
    SYSCALL
    HALT

; Example with SIMD operations
simd_example:
    ; Load vector register with pattern
    VLOAD   V0, pattern_data
    VLOAD   V1, increment_data
    
    ; Add vectors
    VADD.F64 V2, V0, V1
    
    ; Store result
    VSTORE  V2, result_data
    
    RET

SECTION .simd_data
ALIGN 32
pattern_data:
    dq 1.0, 2.0, 3.0, 4.0
    
increment_data:
    dq 0.5, 0.5, 0.5, 0.5
    
result_data:
    dq 0.0, 0.0, 0.0, 0.0

%endif