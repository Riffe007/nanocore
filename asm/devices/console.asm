; NanoCore Console Device Driver
; Implements console I/O through MMIO
;
; MMIO Layout:
; Base: 0x0000_8000_0000_0000
; +0x00: Status register (R)
; +0x08: Command register (W)
; +0x10: Data register (R/W)
; +0x18: Buffer size register (R)
; +0x20: Input buffer start
; +0x1020: Output buffer start

BITS 64
SECTION .text

; Constants
%define CONSOLE_BASE 0x0000800000000000
%define STATUS_REG (CONSOLE_BASE + 0x00)
%define CMD_REG (CONSOLE_BASE + 0x08)
%define DATA_REG (CONSOLE_BASE + 0x10)
%define SIZE_REG (CONSOLE_BASE + 0x18)
%define INPUT_BUFFER (CONSOLE_BASE + 0x20)
%define OUTPUT_BUFFER (CONSOLE_BASE + 0x1020)

; Status bits
%define STATUS_INPUT_READY 0x01
%define STATUS_OUTPUT_FULL 0x02
%define STATUS_ERROR 0x80

; Commands
%define CMD_READ_CHAR 0x01
%define CMD_WRITE_CHAR 0x02
%define CMD_READ_LINE 0x03
%define CMD_WRITE_STRING 0x04
%define CMD_CLEAR 0x05
%define CMD_SET_COLOR 0x06

; Global symbols
global console_init
global console_putc
global console_puts
global console_getc
global console_gets
global console_clear
global console_set_color
global console_write
global console_read

; External symbols
extern memory_write
extern memory_read

SECTION .data
console_initialized: db 0
input_buffer_pos: dq 0
output_buffer_pos: dq 0
echo_enabled: db 1

SECTION .text

; Initialize console device
; Output: RAX = 0 on success
console_init:
    push rbp
    mov rbp, rsp
    
    ; Clear buffers
    mov rdi, INPUT_BUFFER
    xor esi, esi
    mov ecx, 4096
    call clear_buffer
    
    mov rdi, OUTPUT_BUFFER
    xor esi, esi
    mov ecx, 4096
    call clear_buffer
    
    ; Reset positions
    mov qword [input_buffer_pos], 0
    mov qword [output_buffer_pos], 0
    
    ; Clear status register
    mov rdi, STATUS_REG
    xor esi, esi
    call memory_write
    
    ; Mark as initialized
    mov byte [console_initialized], 1
    
    xor eax, eax
    pop rbp
    ret

; Write a character to console
; Input: DIL = character
console_putc:
    push rbp
    mov rbp, rsp
    push rbx
    
    ; Check if initialized
    cmp byte [console_initialized], 0
    je .not_initialized
    
    ; Wait for output buffer to be ready
.wait_ready:
    mov rdi, STATUS_REG
    call memory_read
    test al, STATUS_OUTPUT_FULL
    jnz .wait_ready
    
    ; Write character to data register
    movzx esi, dil
    mov rdi, DATA_REG
    call memory_write
    
    ; Send write command
    mov rdi, CMD_REG
    mov esi, CMD_WRITE_CHAR
    call memory_write
    
    ; Update output buffer
    mov rbx, [output_buffer_pos]
    lea rdi, [OUTPUT_BUFFER + rbx]
    movzx esi, dil
    call memory_write
    
    inc qword [output_buffer_pos]
    and qword [output_buffer_pos], 0xFFF  ; Wrap at 4KB
    
.done:
    pop rbx
    pop rbp
    ret
    
.not_initialized:
    mov eax, -1
    jmp .done

; Write a string to console
; Input: RDI = string pointer, RSI = length
console_puts:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    
    mov r12, rdi  ; Save string pointer
    mov r13, rsi  ; Save length
    xor ebx, ebx  ; Character index
    
.loop:
    cmp rbx, r13
    jae .done
    
    ; Load character
    mov dil, [r12 + rbx]
    call console_putc
    
    inc rbx
    jmp .loop
    
.done:
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; Read a character from console
; Output: AL = character, AH = status
console_getc:
    push rbp
    mov rbp, rsp
    
    ; Check if initialized
    cmp byte [console_initialized], 0
    je .not_initialized
    
    ; Wait for input ready
.wait_input:
    mov rdi, STATUS_REG
    call memory_read
    test al, STATUS_INPUT_READY
    jz .wait_input
    
    ; Send read command
    mov rdi, CMD_REG
    mov esi, CMD_READ_CHAR
    call memory_write
    
    ; Read character from data register
    mov rdi, DATA_REG
    call memory_read
    
    push rax  ; Save character
    
    ; Echo if enabled
    cmp byte [echo_enabled], 0
    je .no_echo
    
    mov dil, al
    call console_putc
    
.no_echo:
    pop rax
    
    ; Update input buffer
    push rax
    mov rbx, [input_buffer_pos]
    lea rdi, [INPUT_BUFFER + rbx]
    movzx esi, al
    call memory_write
    
    inc qword [input_buffer_pos]
    and qword [input_buffer_pos], 0xFFF
    
    pop rax
    xor ah, ah  ; Clear status
    
.done:
    pop rbp
    ret
    
.not_initialized:
    mov ax, 0xFF80  ; Error status
    jmp .done

; Read a line from console
; Input: RDI = buffer pointer, RSI = max length
; Output: RAX = actual length
console_gets:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    
    mov r12, rdi  ; Buffer pointer
    mov r13, rsi  ; Max length
    xor r14, r14  ; Current position
    
.read_loop:
    ; Check if at max length
    cmp r14, r13
    jae .done
    
    ; Read character
    call console_getc
    
    ; Check for newline
    cmp al, 0x0A
    je .done
    
    ; Check for carriage return
    cmp al, 0x0D
    je .done
    
    ; Check for backspace
    cmp al, 0x08
    je .backspace
    
    ; Store character
    mov [r12 + r14], al
    inc r14
    jmp .read_loop
    
.backspace:
    test r14, r14
    jz .read_loop  ; Nothing to delete
    
    dec r14
    
    ; Echo backspace sequence
    mov dil, 0x08  ; Backspace
    call console_putc
    mov dil, 0x20  ; Space
    call console_putc
    mov dil, 0x08  ; Backspace
    call console_putc
    
    jmp .read_loop
    
.done:
    ; Null terminate
    mov byte [r12 + r14], 0
    
    ; Echo newline
    mov dil, 0x0A
    call console_putc
    
    mov rax, r14  ; Return length
    
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; Clear console screen
console_clear:
    push rbp
    mov rbp, rsp
    
    ; Send clear command
    mov rdi, CMD_REG
    mov esi, CMD_CLEAR
    call memory_write
    
    ; Clear buffers
    mov qword [input_buffer_pos], 0
    mov qword [output_buffer_pos], 0
    
    pop rbp
    ret

; Set console text color
; Input: DIL = foreground color, SIL = background color
console_set_color:
    push rbp
    mov rbp, rsp
    
    ; Combine colors
    shl sil, 4
    or sil, dil
    movzx esi, sil
    
    ; Write color to data register
    mov rdi, DATA_REG
    call memory_write
    
    ; Send set color command
    mov rdi, CMD_REG
    mov esi, CMD_SET_COLOR
    call memory_write
    
    pop rbp
    ret

; Generic console write (for device interface)
; Input: RDI = address, RSI = value
console_write:
    push rbp
    mov rbp, rsp
    
    ; Calculate offset from base
    mov rax, rdi
    sub rax, CONSOLE_BASE
    
    ; Handle different registers
    cmp rax, 0x08  ; Command register
    je .write_command
    
    cmp rax, 0x10  ; Data register
    je .write_data
    
    ; Invalid register
    mov eax, -1
    pop rbp
    ret
    
.write_command:
    ; Process command
    cmp sil, CMD_WRITE_CHAR
    je .cmd_write_char
    cmp sil, CMD_READ_CHAR
    je .cmd_read_char
    cmp sil, CMD_CLEAR
    je .cmd_clear
    ; ... other commands
    
    xor eax, eax
    pop rbp
    ret
    
.cmd_write_char:
    ; Write character from data register
    push rsi
    mov rdi, DATA_REG
    call memory_read
    mov dil, al
    call output_char_to_host
    pop rsi
    jmp .done
    
.cmd_read_char:
    ; Read character to data register
    call input_char_from_host
    movzx esi, al
    mov rdi, DATA_REG
    call memory_write
    
    ; Set input ready flag
    mov rdi, STATUS_REG
    call memory_read
    or al, STATUS_INPUT_READY
    movzx esi, al
    mov rdi, STATUS_REG
    call memory_write
    jmp .done
    
.cmd_clear:
    ; Clear screen
    call clear_host_console
    jmp .done
    
.write_data:
    ; Just store the value
    call memory_write
    
.done:
    xor eax, eax
    pop rbp
    ret

; Generic console read (for device interface)
; Input: RDI = address
; Output: RAX = value
console_read:
    push rbp
    mov rbp, rsp
    
    ; Calculate offset
    mov rax, rdi
    sub rax, CONSOLE_BASE
    
    ; Handle different registers
    cmp rax, 0x00  ; Status register
    je .read_status
    
    cmp rax, 0x10  ; Data register
    je .read_data
    
    cmp rax, 0x18  ; Size register
    je .read_size
    
    ; Default: read from memory
    call memory_read
    pop rbp
    ret
    
.read_status:
    ; Build status byte
    xor eax, eax
    
    ; Check if input available
    call input_available_from_host
    test al, al
    jz .no_input
    or al, STATUS_INPUT_READY
    
.no_input:
    ; Check if output buffer full
    cmp qword [output_buffer_pos], 4000
    jb .not_full
    or al, STATUS_OUTPUT_FULL
    
.not_full:
    pop rbp
    ret
    
.read_data:
    mov rdi, DATA_REG
    call memory_read
    pop rbp
    ret
    
.read_size:
    mov eax, 4096  ; Buffer size
    pop rbp
    ret

; Helper functions

; Clear buffer
; Input: RDI = buffer address, ESI = value, ECX = size
clear_buffer:
    push rcx
.loop:
    push rsi
    push rdi
    call memory_write
    pop rdi
    pop rsi
    add rdi, 8
    sub ecx, 8
    jnz .loop
    pop rcx
    ret

; Host system interface stubs
; These would be implemented to interface with the actual host console

output_char_to_host:
    ; Output character in DIL to host console
    ; Real implementation would use host OS syscalls
    ret

input_char_from_host:
    ; Input character from host console to AL
    ; Real implementation would use host OS syscalls
    xor eax, eax
    ret

input_available_from_host:
    ; Check if input is available
    ; Return: AL = 1 if available, 0 otherwise
    xor eax, eax
    ret

clear_host_console:
    ; Clear the host console
    ; Real implementation would send ANSI escape sequences or use OS API
    ret