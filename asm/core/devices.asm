; NanoCore Devices Module
; Handles I/O devices, MMIO, and device drivers

BITS 64
SECTION .text

; External symbols
extern vm_state
extern memory_read
extern memory_write
extern interrupt_trigger

; Constants
%define VM_PC 0
%define VM_FLAGS 16
%define VM_GPRS 24
%define VM_VREGS (VM_GPRS + 32 * 8)
%define VM_PERF (VM_VREGS + 16 * 32)

; Device types
%define DEV_CONSOLE 0
%define DEV_TIMER 1
%define DEV_KEYBOARD 2
%define DEV_SERIAL 3
%define DEV_DISK 4
%define DEV_NETWORK 5
%define DEV_GPU 6
%define DEV_AUDIO 7

; MMIO base addresses
%define MMIO_BASE 0x8000000000000000
%define CONSOLE_BASE (MMIO_BASE + 0x0000)
%define TIMER_BASE (MMIO_BASE + 0x1000)
%define KEYBOARD_BASE (MMIO_BASE + 0x2000)
%define SERIAL_BASE (MMIO_BASE + 0x3000)
%define DISK_BASE (MMIO_BASE + 0x4000)
%define NETWORK_BASE (MMIO_BASE + 0x5000)
%define GPU_BASE (MMIO_BASE + 0x6000)
%define AUDIO_BASE (MMIO_BASE + 0x7000)

; Device registers
%define CONSOLE_DATA 0x00
%define CONSOLE_STATUS 0x08
%define CONSOLE_CONTROL 0x10

%define TIMER_COUNTER 0x00
%define TIMER_COMPARE 0x08
%define TIMER_CONTROL 0x10
%define TIMER_STATUS 0x18

%define KEYBOARD_DATA 0x00
%define KEYBOARD_STATUS 0x08
%define KEYBOARD_CONTROL 0x10

%define SERIAL_DATA 0x00
%define SERIAL_STATUS 0x08
%define SERIAL_CONTROL 0x10
%define SERIAL_BAUD 0x18

; Device structure
struc device
    .type: resb 1           ; Device type
    .base_addr: resq 1      ; MMIO base address
    .size: resq 1           ; Device size
    .handler: resq 1        ; Device handler function
    .data: resq 1           ; Device-specific data
    .enabled: resb 1        ; Device enabled flag
    .irq: resb 1            ; IRQ number
    .reserved: resb 5       ; Alignment
endstruc

; Device state
struc device_state
    .devices: resb device_size * 8  ; 8 devices
    .mmio_handlers: resq 64         ; MMIO handler functions
    .mmio_ranges: resq 64 * 2       ; MMIO address ranges
    .num_devices: resd 1            ; Number of registered devices
    .reserved: resd 1               ; Alignment
    .stats: resq 8                  ; Device statistics
endstruc

; Global symbols
global device_init
global device_register
global device_unregister
global device_read
global device_write
global device_io_read
global device_io_write
global mmio_read
global mmio_write

SECTION .bss
align 64
device_state: resb device_state_size
console_buffer: resb 1024  ; Console input/output buffer
timer_counter: resq 1      ; Timer counter
keyboard_buffer: resb 256  ; Keyboard input buffer
keyboard_head: resd 1      ; Keyboard buffer head
keyboard_tail: resd 1      ; Keyboard buffer tail

SECTION .data
align 64
; Device statistics indices
%define STAT_DEVICE_READS 0
%define STAT_DEVICE_WRITES 1
%define STAT_MMIO_READS 2
%define STAT_MMIO_WRITES 3
%define STAT_INTERRUPTS 4
%define STAT_ERRORS 5
%define STAT_BYTES_READ 6
%define STAT_BYTES_WRITTEN 7

SECTION .text

; Initialize device subsystem
global device_init
device_init:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    
    ; Clear device state
    lea rdi, [device_state]
    xor eax, eax
    mov ecx, device_state_size / 8
    rep stosq
    
    ; Clear device buffers
    lea rdi, [console_buffer]
    xor eax, eax
    mov ecx, 1024 / 8
    rep stosq
    
    lea rdi, [keyboard_buffer]
    mov ecx, 256 / 8
    rep stosq
    
    ; Initialize timer counter
    mov qword [timer_counter], 0
    
    ; Initialize keyboard buffer pointers
    mov dword [keyboard_head], 0
    mov dword [keyboard_tail], 0
    
    ; Register default devices
    mov rdi, DEV_CONSOLE
    mov rsi, CONSOLE_BASE
    mov rdx, 0x1000
    lea rcx, [console_handler]
    call device_register
    
    mov rdi, DEV_TIMER
    mov rsi, TIMER_BASE
    mov rdx, 0x1000
    lea rcx, [timer_handler]
    call device_register
    
    mov rdi, DEV_KEYBOARD
    mov rsi, KEYBOARD_BASE
    mov rdx, 0x1000
    lea rcx, [keyboard_handler]
    call device_register
    
    mov rdi, DEV_SERIAL
    mov rsi, SERIAL_BASE
    mov rdx, 0x1000
    lea rcx, [serial_handler]
    call device_register
    
    ; Set up MMIO handlers
    lea rbx, [device_state + device_state.mmio_handlers]
    lea r12, [device_state + device_state.mmio_ranges]
    
    ; Console MMIO
    mov qword [rbx + 0 * 8], console_mmio_read
    mov qword [rbx + 1 * 8], console_mmio_write
    mov qword [r12 + 0 * 16], CONSOLE_BASE
    mov qword [r12 + 0 * 16 + 8], CONSOLE_BASE + 0x1000
    
    ; Timer MMIO
    mov qword [rbx + 2 * 8], timer_mmio_read
    mov qword [rbx + 3 * 8], timer_mmio_write
    mov qword [r12 + 1 * 16], TIMER_BASE
    mov qword [r12 + 1 * 16 + 8], TIMER_BASE + 0x1000
    
    ; Keyboard MMIO
    mov qword [rbx + 4 * 8], keyboard_mmio_read
    mov qword [rbx + 5 * 8], keyboard_mmio_write
    mov qword [r12 + 2 * 16], KEYBOARD_BASE
    mov qword [r12 + 2 * 16 + 8], KEYBOARD_BASE + 0x1000
    
    ; Serial MMIO
    mov qword [rbx + 6 * 8], serial_mmio_read
    mov qword [rbx + 7 * 8], serial_mmio_write
    mov qword [r12 + 3 * 16], SERIAL_BASE
    mov qword [r12 + 3 * 16 + 8], SERIAL_BASE + 0x1000
    
    xor eax, eax
    pop r12
    pop rbx
    pop rbp
    ret

; Register device
; Input: RDI = device type, RSI = base address, RDX = size, RCX = handler
; Output: RAX = device ID (0-7) or -1 on error
global device_register
device_register:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    
    mov r12, rdi  ; Device type
    mov r13, rsi  ; Base address
    mov r14, rcx  ; Handler
    
    ; Check if we have room for another device
    lea rbx, [device_state + device_state.num_devices]
    mov eax, [rbx]
    cmp eax, 8
    jae .error
    
    ; Find free device slot
    lea rbx, [device_state + device_state.devices]
    mov ecx, 0
    
.find_slot:
    cmp ecx, 8
    jae .error
    
    lea rdi, [rbx + rcx * device_size]
    cmp byte [rdi + device.enabled], 0
    je .found_slot
    
    inc ecx
    jmp .find_slot
    
.found_slot:
    ; Register device
    mov byte [rdi + device.type], r12b
    mov [rdi + device.base_addr], r13
    mov [rdi + device.size], rdx
    mov [rdi + device.handler], r14
    mov qword [rdi + device.data], 0
    mov byte [rdi + device.enabled], 1
    mov byte [rdi + device.irq], 0
    
    ; Increment device count
    lea rbx, [device_state + device_state.num_devices]
    inc dword [rbx]
    
    ; Return device ID
    mov eax, ecx
    jmp .done
    
.error:
    mov eax, -1
    
.done:
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; Unregister device
; Input: RDI = device ID
; Output: RAX = 0 on success, -1 on error
global device_unregister
device_unregister:
    push rbp
    mov rbp, rsp
    push rbx
    
    ; Check device ID range
    cmp rdi, 8
    jae .error
    
    ; Get device
    lea rbx, [device_state + device_state.devices]
    lea rdi, [rbx + rdi * device_size]
    
    ; Check if device is enabled
    cmp byte [rdi + device.enabled], 0
    je .error
    
    ; Disable device
    mov byte [rdi + device.enabled], 0
    
    ; Decrement device count
    lea rbx, [device_state + device_state.num_devices]
    dec dword [rbx]
    
    xor eax, eax
    jmp .done
    
.error:
    mov eax, -1
    
.done:
    pop rbx
    pop rbp
    ret

; Read from device
; Input: RDI = device ID, RSI = offset, RDX = buffer, RCX = size
; Output: RAX = bytes read or error code
global device_read
device_read:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    
    mov r12, rdi  ; Device ID
    mov r13, rsi  ; Offset
    mov r14, rdx  ; Buffer
    mov r15, rcx  ; Size
    
    ; Check device ID range
    cmp r12, 8
    jae .error
    
    ; Get device
    lea rbx, [device_state + device_state.devices]
    lea rdi, [rbx + r12 * device_size]
    
    ; Check if device is enabled
    cmp byte [rdi + device.enabled], 0
    je .error
    
    ; Check offset range
    cmp r13, [rdi + device.size]
    jae .error
    
    ; Call device handler
    mov rax, [rdi + device.handler]
    mov rdi, r12  ; Device ID
    mov rsi, r13  ; Offset
    mov rdx, r14  ; Buffer
    mov rcx, r15  ; Size
    call rax
    
    ; Update statistics
    lea rbx, [device_state + device_state.stats]
    inc qword [rbx + STAT_DEVICE_READS * 8]
    add [rbx + STAT_BYTES_READ * 8], rax
    
    jmp .done
    
.error:
    mov eax, -1
    
    ; Update error statistics
    lea rbx, [device_state + device_state.stats]
    inc qword [rbx + STAT_ERRORS * 8]
    
.done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; Write to device
; Input: RDI = device ID, RSI = offset, RDX = buffer, RCX = size
; Output: RAX = bytes written or error code
global device_write
device_write:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    
    mov r12, rdi  ; Device ID
    mov r13, rsi  ; Offset
    mov r14, rdx  ; Buffer
    mov r15, rcx  ; Size
    
    ; Check device ID range
    cmp r12, 8
    jae .error
    
    ; Get device
    lea rbx, [device_state + device_state.devices]
    lea rdi, [rbx + r12 * device_size]
    
    ; Check if device is enabled
    cmp byte [rdi + device.enabled], 0
    je .error
    
    ; Check offset range
    cmp r13, [rdi + device.size]
    jae .error
    
    ; Call device handler
    mov rax, [rdi + device.handler]
    mov rdi, r12  ; Device ID
    mov rsi, r13  ; Offset
    mov rdx, r14  ; Buffer
    mov rcx, r15  ; Size
    call rax
    
    ; Update statistics
    lea rbx, [device_state + device_state.stats]
    inc qword [rbx + STAT_DEVICE_WRITES * 8]
    add [rbx + STAT_BYTES_WRITTEN * 8], rax
    
    jmp .done
    
.error:
    mov eax, -1
    
    ; Update error statistics
    lea rbx, [device_state + device_state.stats]
    inc qword [rbx + STAT_ERRORS * 8]
    
.done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; Read from I/O port
; Input: RDI = port number, RSI = buffer, RDX = size
; Output: RAX = bytes read or error code
global device_io_read
device_io_read:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    
    mov r12, rdi  ; Port number
    mov r13, rsi  ; Buffer
    mov r14, rdx  ; Size
    
    ; For now, just return 0 (no I/O ports implemented)
    xor eax, eax
    
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; Write to I/O port
; Input: RDI = port number, RSI = buffer, RDX = size
; Output: RAX = bytes written or error code
global device_io_write
device_io_write:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    
    mov r12, rdi  ; Port number
    mov r13, rsi  ; Buffer
    mov r14, rdx  ; Size
    
    ; For now, just return size (all bytes written)
    mov rax, r14
    
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; Read from MMIO address
; Input: RDI = address, RSI = buffer, RDX = size
; Output: RAX = bytes read or error code
global mmio_read
mmio_read:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    
    mov r12, rdi  ; Address
    mov r13, rsi  ; Buffer
    mov r14, rdx  ; Size
    
    ; Check if address is in MMIO range
    cmp r12, MMIO_BASE
    jb .error
    
    ; Find MMIO handler
    lea rbx, [device_state + device_state.mmio_ranges]
    lea r15, [device_state + device_state.mmio_handlers]
    mov ecx, 0
    
.find_handler:
    cmp ecx, 64
    jae .error
    
    mov rax, [rbx + rcx * 16]      ; Range start
    mov rdx, [rbx + rcx * 16 + 8]  ; Range end
    
    cmp r12, rax
    jb .next_handler
    cmp r12, rdx
    jae .next_handler
    
    ; Found handler
    mov rax, [r15 + rcx * 8]
    test rax, rax
    jz .error
    
    ; Call handler
    mov rdi, r12  ; Address
    mov rsi, r13  ; Buffer
    mov rdx, r14  ; Size
    call rax
    
    ; Update statistics
    lea rbx, [device_state + device_state.stats]
    inc qword [rbx + STAT_MMIO_READS * 8]
    add [rbx + STAT_BYTES_READ * 8], rax
    
    jmp .done
    
.next_handler:
    inc ecx
    jmp .find_handler
    
.error:
    mov eax, -1
    
    ; Update error statistics
    lea rbx, [device_state + device_state.stats]
    inc qword [rbx + STAT_ERRORS * 8]
    
.done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; Write to MMIO address
; Input: RDI = address, RSI = buffer, RDX = size
; Output: RAX = bytes written or error code
global mmio_write
mmio_write:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    
    mov r12, rdi  ; Address
    mov r13, rsi  ; Buffer
    mov r14, rdx  ; Size
    
    ; Check if address is in MMIO range
    cmp r12, MMIO_BASE
    jb .error
    
    ; Find MMIO handler
    lea rbx, [device_state + device_state.mmio_ranges]
    lea r15, [device_state + device_state.mmio_handlers]
    mov ecx, 0
    
.find_handler:
    cmp ecx, 64
    jae .error
    
    mov rax, [rbx + rcx * 16]      ; Range start
    mov rdx, [rbx + rcx * 16 + 8]  ; Range end
    
    cmp r12, rax
    jb .next_handler
    cmp r12, rdx
    jae .next_handler
    
    ; Found handler
    mov rax, [r15 + rcx * 8 + 8]  ; Write handler
    test rax, rax
    jz .error
    
    ; Call handler
    mov rdi, r12  ; Address
    mov rsi, r13  ; Buffer
    mov rdx, r14  ; Size
    call rax
    
    ; Update statistics
    lea rbx, [device_state + device_state.stats]
    inc qword [rbx + STAT_MMIO_WRITES * 8]
    add [rbx + STAT_BYTES_WRITTEN * 8], rax
    
    jmp .done
    
.next_handler:
    inc ecx
    jmp .find_handler
    
.error:
    mov eax, -1
    
    ; Update error statistics
    lea rbx, [device_state + device_state.stats]
    inc qword [rbx + STAT_ERRORS * 8]
    
.done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; Device handlers

; Console device handler
console_handler:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    
    mov r12, rdi  ; Device ID
    mov r13, rsi  ; Offset
    mov r14, rdx  ; Buffer
    mov r15, rcx  ; Size
    
    ; Handle different offsets
    cmp r13, CONSOLE_DATA
    je .data
    cmp r13, CONSOLE_STATUS
    je .status
    cmp r13, CONSOLE_CONTROL
    je .control
    
    ; Unknown offset
    mov rax, -1
    jmp .done
    
.data:
    ; Read/write console data
    test r15, r15
    jz .done
    
    ; For now, just copy data
    mov rdi, r14
    lea rsi, [console_buffer]
    add rsi, r13
    mov rcx, r15
    rep movsb
    
    mov rax, r15
    jmp .done
    
.status:
    ; Read console status
    mov qword [r14], 0x01  ; Ready for read/write
    mov rax, 8
    jmp .done
    
.control:
    ; Read/write console control
    mov qword [r14], 0x00  ; No special control
    mov rax, 8
    
.done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; Timer device handler
timer_handler:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    
    mov r12, rdi  ; Device ID
    mov r13, rsi  ; Offset
    mov r14, rdx  ; Buffer
    mov r15, rcx  ; Size
    
    ; Handle different offsets
    cmp r13, TIMER_COUNTER
    je .counter
    cmp r13, TIMER_COMPARE
    je .compare
    cmp r13, TIMER_CONTROL
    je .control
    cmp r13, TIMER_STATUS
    je .status
    
    ; Unknown offset
    mov rax, -1
    jmp .done
    
.counter:
    ; Read/write timer counter
    mov rax, [timer_counter]
    mov [r14], rax
    mov rax, 8
    jmp .done
    
.compare:
    ; Read/write timer compare value
    mov qword [r14], 0x1000  ; Default compare value
    mov rax, 8
    jmp .done
    
.control:
    ; Read/write timer control
    mov qword [r14], 0x01  ; Timer enabled
    mov rax, 8
    jmp .done
    
.status:
    ; Read timer status
    mov qword [r14], 0x00  ; No interrupt pending
    mov rax, 8
    
.done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; Keyboard device handler
keyboard_handler:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    
    mov r12, rdi  ; Device ID
    mov r13, rsi  ; Offset
    mov r14, rdx  ; Buffer
    mov r15, rcx  ; Size
    
    ; Handle different offsets
    cmp r13, KEYBOARD_DATA
    je .data
    cmp r13, KEYBOARD_STATUS
    je .status
    cmp r13, KEYBOARD_CONTROL
    je .control
    
    ; Unknown offset
    mov rax, -1
    jmp .done
    
.data:
    ; Read keyboard data
    mov eax, [keyboard_head]
    cmp eax, [keyboard_tail]
    je .no_data
    
    ; Read from buffer
    lea rbx, [keyboard_buffer]
    movzx eax, byte [rbx + rax]
    mov [r14], rax
    
    ; Increment head
    inc dword [keyboard_head]
    and dword [keyboard_head], 0xFF
    
    mov rax, 1
    jmp .done
    
.no_data:
    mov rax, 0
    jmp .done
    
.status:
    ; Read keyboard status
    mov eax, [keyboard_head]
    cmp eax, [keyboard_tail]
    setne al
    movzx rax, al
    mov [r14], rax
    mov rax, 8
    jmp .done
    
.control:
    ; Read/write keyboard control
    mov qword [r14], 0x01  ; Keyboard enabled
    mov rax, 8
    
.done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; Serial device handler
serial_handler:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    
    mov r12, rdi  ; Device ID
    mov r13, rsi  ; Offset
    mov r14, rdx  ; Buffer
    mov r15, rcx  ; Size
    
    ; Handle different offsets
    cmp r13, SERIAL_DATA
    je .data
    cmp r13, SERIAL_STATUS
    je .status
    cmp r13, SERIAL_CONTROL
    je .control
    cmp r13, SERIAL_BAUD
    je .baud
    
    ; Unknown offset
    mov rax, -1
    jmp .done
    
.data:
    ; Read/write serial data
    mov qword [r14], 0x00  ; No data
    mov rax, 8
    jmp .done
    
.status:
    ; Read serial status
    mov qword [r14], 0x01  ; Ready for read/write
    mov rax, 8
    jmp .done
    
.control:
    ; Read/write serial control
    mov qword [r14], 0x01  ; Serial enabled
    mov rax, 8
    jmp .done
    
.baud:
    ; Read/write baud rate
    mov qword [r14], 115200  ; Default baud rate
    mov rax, 8
    
.done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; MMIO handlers

; Console MMIO read
console_mmio_read:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    
    mov r12, rdi  ; Address
    mov r13, rsi  ; Buffer
    mov r14, rdx  ; Size
    
    ; Calculate offset
    sub r12, CONSOLE_BASE
    
    ; Handle different offsets
    cmp r12, CONSOLE_DATA
    je .data
    cmp r12, CONSOLE_STATUS
    je .status
    cmp r12, CONSOLE_CONTROL
    je .control
    
    ; Unknown offset
    mov rax, -1
    jmp .done
    
.data:
    ; Read console data
    mov qword [r13], 0x00  ; No data
    mov rax, 8
    jmp .done
    
.status:
    ; Read console status
    mov qword [r13], 0x01  ; Ready
    mov rax, 8
    jmp .done
    
.control:
    ; Read console control
    mov qword [r13], 0x00  ; No special control
    mov rax, 8
    
.done:
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; Console MMIO write
console_mmio_write:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    
    mov r12, rdi  ; Address
    mov r13, rsi  ; Buffer
    mov r14, rdx  ; Size
    
    ; Calculate offset
    sub r12, CONSOLE_BASE
    
    ; Handle different offsets
    cmp r12, CONSOLE_DATA
    je .data
    cmp r12, CONSOLE_STATUS
    je .status
    cmp r12, CONSOLE_CONTROL
    je .control
    
    ; Unknown offset
    mov rax, -1
    jmp .done
    
.data:
    ; Write console data
    mov rax, r14
    jmp .done
    
.status:
    ; Write console status (ignored)
    mov rax, r14
    jmp .done
    
.control:
    ; Write console control (ignored)
    mov rax, r14
    
.done:
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; Timer MMIO read
timer_mmio_read:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    
    mov r12, rdi  ; Address
    mov r13, rsi  ; Buffer
    mov r14, rdx  ; Size
    
    ; Calculate offset
    sub r12, TIMER_BASE
    
    ; Handle different offsets
    cmp r12, TIMER_COUNTER
    je .counter
    cmp r12, TIMER_COMPARE
    je .compare
    cmp r12, TIMER_CONTROL
    je .control
    cmp r12, TIMER_STATUS
    je .status
    
    ; Unknown offset
    mov rax, -1
    jmp .done
    
.counter:
    ; Read timer counter
    mov rax, [timer_counter]
    mov [r13], rax
    mov rax, 8
    jmp .done
    
.compare:
    ; Read timer compare value
    mov qword [r13], 0x1000
    mov rax, 8
    jmp .done
    
.control:
    ; Read timer control
    mov qword [r13], 0x01
    mov rax, 8
    jmp .done
    
.status:
    ; Read timer status
    mov qword [r13], 0x00
    mov rax, 8
    
.done:
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; Timer MMIO write
timer_mmio_write:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    
    mov r12, rdi  ; Address
    mov r13, rsi  ; Buffer
    mov r14, rdx  ; Size
    
    ; Calculate offset
    sub r12, TIMER_BASE
    
    ; Handle different offsets
    cmp r12, TIMER_COUNTER
    je .counter
    cmp r12, TIMER_COMPARE
    je .compare
    cmp r12, TIMER_CONTROL
    je .control
    cmp r12, TIMER_STATUS
    je .status
    
    ; Unknown offset
    mov rax, -1
    jmp .done
    
.counter:
    ; Write timer counter
    mov rax, [r13]
    mov [timer_counter], rax
    mov rax, r14
    jmp .done
    
.compare:
    ; Write timer compare value (ignored)
    mov rax, r14
    jmp .done
    
.control:
    ; Write timer control (ignored)
    mov rax, r14
    jmp .done
    
.status:
    ; Write timer status (ignored)
    mov rax, r14
    
.done:
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; Keyboard MMIO read
keyboard_mmio_read:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    
    mov r12, rdi  ; Address
    mov r13, rsi  ; Buffer
    mov r14, rdx  ; Size
    
    ; Calculate offset
    sub r12, KEYBOARD_BASE
    
    ; Handle different offsets
    cmp r12, KEYBOARD_DATA
    je .data
    cmp r12, KEYBOARD_STATUS
    je .status
    cmp r12, KEYBOARD_CONTROL
    je .control
    
    ; Unknown offset
    mov rax, -1
    jmp .done
    
.data:
    ; Read keyboard data
    mov eax, [keyboard_head]
    cmp eax, [keyboard_tail]
    je .no_data
    
    lea rbx, [keyboard_buffer]
    movzx eax, byte [rbx + rax]
    mov [r13], rax
    
    inc dword [keyboard_head]
    and dword [keyboard_head], 0xFF
    
    mov rax, 8
    jmp .done
    
.no_data:
    mov qword [r13], 0x00
    mov rax, 8
    jmp .done
    
.status:
    ; Read keyboard status
    mov eax, [keyboard_head]
    cmp eax, [keyboard_tail]
    setne al
    movzx rax, al
    mov [r13], rax
    mov rax, 8
    jmp .done
    
.control:
    ; Read keyboard control
    mov qword [r13], 0x01
    mov rax, 8
    
.done:
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; Keyboard MMIO write
keyboard_mmio_write:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    
    mov r12, rdi  ; Address
    mov r13, rsi  ; Buffer
    mov r14, rdx  ; Size
    
    ; Calculate offset
    sub r12, KEYBOARD_BASE
    
    ; Handle different offsets
    cmp r12, KEYBOARD_DATA
    je .data
    cmp r12, KEYBOARD_STATUS
    je .status
    cmp r12, KEYBOARD_CONTROL
    je .control
    
    ; Unknown offset
    mov rax, -1
    jmp .done
    
.data:
    ; Write keyboard data (ignored)
    mov rax, r14
    jmp .done
    
.status:
    ; Write keyboard status (ignored)
    mov rax, r14
    jmp .done
    
.control:
    ; Write keyboard control (ignored)
    mov rax, r14
    
.done:
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; Serial MMIO read
serial_mmio_read:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    
    mov r12, rdi  ; Address
    mov r13, rsi  ; Buffer
    mov r14, rdx  ; Size
    
    ; Calculate offset
    sub r12, SERIAL_BASE
    
    ; Handle different offsets
    cmp r12, SERIAL_DATA
    je .data
    cmp r12, SERIAL_STATUS
    je .status
    cmp r12, SERIAL_CONTROL
    je .control
    cmp r12, SERIAL_BAUD
    je .baud
    
    ; Unknown offset
    mov rax, -1
    jmp .done
    
.data:
    ; Read serial data
    mov qword [r13], 0x00
    mov rax, 8
    jmp .done
    
.status:
    ; Read serial status
    mov qword [r13], 0x01
    mov rax, 8
    jmp .done
    
.control:
    ; Read serial control
    mov qword [r13], 0x01
    mov rax, 8
    jmp .done
    
.baud:
    ; Read baud rate
    mov qword [r13], 115200
    mov rax, 8
    
.done:
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; Serial MMIO write
serial_mmio_write:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    
    mov r12, rdi  ; Address
    mov r13, rsi  ; Buffer
    mov r14, rdx  ; Size
    
    ; Calculate offset
    sub r12, SERIAL_BASE
    
    ; Handle different offsets
    cmp r12, SERIAL_DATA
    je .data
    cmp r12, SERIAL_STATUS
    je .status
    cmp r12, SERIAL_CONTROL
    je .control
    cmp r12, SERIAL_BAUD
    je .baud
    
    ; Unknown offset
    mov rax, -1
    jmp .done
    
.data:
    ; Write serial data
    mov rax, r14
    jmp .done
    
.status:
    ; Write serial status (ignored)
    mov rax, r14
    jmp .done
    
.control:
    ; Write serial control (ignored)
    mov rax, r14
    jmp .done
    
.baud:
    ; Write baud rate (ignored)
    mov rax, r14
    
.done:
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret