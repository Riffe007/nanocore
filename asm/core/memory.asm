; NanoCore Memory Management Module
; Handles virtual memory, paging, TLB, and MMIO

BITS 64
SECTION .text

; External symbols
extern malloc
extern free
extern memset
extern memcpy

; Constants
%define PAGE_SIZE 4096
%define PAGE_SHIFT 12
%define PAGE_MASK 0xFFF
%define NUM_PAGE_TABLES 4
%define TLB_ENTRIES 256
%define MMIO_BASE 0x8000000000000000

; Memory management structure
struc memory_state
    .memory_size: resq 1          ; Total memory size
    .memory_base: resq 1          ; Base address of memory
    .page_tables: resq NUM_PAGE_TABLES  ; Page table pointers
    .tlb: resq TLB_ENTRIES * 2    ; TLB entries (virtual, physical)
    .tlb_valid: resb TLB_ENTRIES  ; TLB valid bits
    .mmio_handlers: resq 64       ; MMIO handler functions
    .mmio_ranges: resq 64 * 2     ; MMIO address ranges
    .num_mmio: resd 1             ; Number of MMIO regions
    .reserved: resd 1             ; Alignment
endstruc

; Global memory state
SECTION .bss
align 64
memory_state: resb memory_state_size

SECTION .data
align 64
; Default page table (identity mapping for first 1GB)
default_page_table: times 512 dq 0

SECTION .text

; Initialize memory subsystem
; Input: RDI = memory size in bytes
; Output: RAX = 0 on success, error code otherwise
global memory_init
memory_init:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    
    ; Save memory size
    mov [memory_state + memory_state.memory_size], rdi
    
    ; Allocate memory
    call malloc
    test rax, rax
    jz .error
    mov [memory_state + memory_state.memory_base], rax
    
    ; Initialize page tables
    lea r12, [memory_state + memory_state.page_tables]
    mov r13, 0  ; Page table index
    
.init_page_tables:
    cmp r13, NUM_PAGE_TABLES
    jae .page_tables_done
    
    ; Allocate page table
    mov rdi, PAGE_SIZE
    call malloc
    test rax, rax
    jz .error
    
    mov [r12 + r13 * 8], rax
    
    ; Initialize with identity mapping
    mov rdi, rax
    mov rsi, 0
    mov rdx, PAGE_SIZE
    call memset
    
    ; Set up identity mapping for this page table
    mov r14, [r12 + r13 * 8]
    mov r15, 0  ; Page index
    
.setup_mapping:
    cmp r15, 512
    jae .next_page_table
    
    ; Calculate virtual and physical addresses
    mov rax, r13
    shl rax, 39  ; Page table level
    mov rbx, r15
    shl rbx, 12  ; Page offset
    or rax, rbx
    
    ; Set page table entry (present, writable, user)
    mov rbx, rax
    or rbx, 0x87  ; Present, writable, user, accessed, dirty
    mov [r14 + r15 * 8], rbx
    
    inc r15
    jmp .setup_mapping
    
.next_page_table:
    inc r13
    jmp .init_page_tables
    
.page_tables_done:
    
    ; Initialize TLB
    lea rdi, [memory_state + memory_state.tlb_valid]
    mov rsi, 0
    mov rdx, TLB_ENTRIES
    call memset
    
    ; Initialize MMIO handlers
    lea rdi, [memory_state + memory_state.mmio_handlers]
    mov rsi, 0
    mov rdx, 64 * 8
    call memset
    
    ; Set up default MMIO regions
    call setup_default_mmio
    
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

; Set up default MMIO regions
setup_default_mmio:
    push rbp
    mov rbp, rsp
    
    ; Console MMIO (0x8000000000000000 - 0x8000000000001000)
    lea rdi, [memory_state + memory_state.mmio_ranges]
    mov qword [rdi], MMIO_BASE
    mov qword [rdi + 8], MMIO_BASE + 0x1000
    
    lea rdi, [memory_state + memory_state.mmio_handlers]
    mov qword [rdi], console_mmio_handler
    
    mov dword [memory_state + memory_state.num_mmio], 1
    
    pop rbp
    ret

; Read memory with virtual address translation
; Input: RDI = virtual address, RSI = buffer, RDX = size
; Output: RAX = 0 on success, error code otherwise
global memory_read
memory_read:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    
    mov r12, rdi  ; Virtual address
    mov r13, rsi  ; Buffer
    mov r14, rdx  ; Size
    
    ; Check if address is in MMIO space
    cmp r12, MMIO_BASE
    jb .not_mmio
    
    ; Handle MMIO read
    mov rdi, r12
    mov rsi, r13
    mov rdx, r14
    call mmio_read
    jmp .done
    
.not_mmio:
    ; Translate virtual address to physical
    mov rdi, r12
    call translate_address
    test rax, rax
    jz .error
    
    mov r15, rax  ; Physical address
    
    ; Check bounds
    mov rax, [memory_state + memory_state.memory_size]
    sub rax, r14
    cmp r15, rax
    ja .error
    
    ; Copy data
    mov rdi, r13
    mov rsi, [memory_state + memory_state.memory_base]
    add rsi, r15
    mov rdx, r14
    call memcpy
    
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

; Write memory with virtual address translation
; Input: RDI = virtual address, RSI = data, RDX = size
; Output: RAX = 0 on success, error code otherwise
global memory_write
memory_write:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    
    mov r12, rdi  ; Virtual address
    mov r13, rsi  ; Data
    mov r14, rdx  ; Size
    
    ; Check if address is in MMIO space
    cmp r12, MMIO_BASE
    jb .not_mmio
    
    ; Handle MMIO write
    mov rdi, r12
    mov rsi, r13
    mov rdx, r14
    call mmio_write
    jmp .done
    
.not_mmio:
    ; Translate virtual address to physical
    mov rdi, r12
    call translate_address
    test rax, rax
    jz .error
    
    mov r15, rax  ; Physical address
    
    ; Check bounds
    mov rax, [memory_state + memory_state.memory_size]
    sub rax, r14
    cmp r15, rax
    ja .error
    
    ; Copy data
    mov rdi, [memory_state + memory_state.memory_base]
    add rdi, r15
    mov rsi, r13
    mov rdx, r14
    call memcpy
    
    ; Invalidate TLB entry
    mov rdi, r12
    call invalidate_tlb
    
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

; Translate virtual address to physical address
; Input: RDI = virtual address
; Output: RAX = physical address (0 if translation failed)
translate_address:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    
    mov r12, rdi
    
    ; Check TLB first
    mov rdi, r12
    call tlb_lookup
    test rax, rax
    jnz .found
    
    ; Walk page tables
    mov r13, r12
    shr r13, 39  ; Level 4 index
    and r13, 0x1FF
    
    mov rax, [memory_state + memory_state.page_tables + 3 * 8]
    test rax, rax
    jz .error
    
    mov rax, [rax + r13 * 8]
    test rax, 1  ; Present bit
    jz .error
    
    and rax, ~0xFFF  ; Clear flags
    
    ; Level 3
    mov r13, r12
    shr r13, 30
    and r13, 0x1FF
    
    mov rax, [rax + r13 * 8]
    test rax, 1
    jz .error
    and rax, ~0xFFF
    
    ; Level 2
    mov r13, r12
    shr r13, 21
    and r13, 0x1FF
    
    mov rax, [rax + r13 * 8]
    test rax, 1
    jz .error
    and rax, ~0xFFF
    
    ; Level 1
    mov r13, r12
    shr r13, 12
    and r13, 0x1FF
    
    mov rax, [rax + r13 * 8]
    test rax, 1
    jz .error
    and rax, ~0xFFF
    
    ; Add page offset
    mov r13, r12
    and r13, PAGE_MASK
    add rax, r13
    
    ; Update TLB
    mov rdi, r12
    mov rsi, rax
    call tlb_update
    
.found:
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret
    
.error:
    xor eax, eax
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; TLB lookup
; Input: RDI = virtual address
; Output: RAX = physical address (0 if not found)
tlb_lookup:
    push rbp
    mov rbp, rsp
    
    ; Calculate TLB index
    mov rax, rdi
    shr rax, 12  ; Page number
    and rax, 0xFF  ; 256 entries
    
    ; Check if valid
    lea rbx, [memory_state + memory_state.tlb_valid]
    mov cl, [rbx + rax]
    test cl, cl
    jz .not_found
    
    ; Get physical address
    lea rbx, [memory_state + memory_state.tlb]
    mov rax, [rbx + rax * 16 + 8]  ; Physical address
    
    pop rbp
    ret
    
.not_found:
    xor eax, eax
    pop rbp
    ret

; TLB update
; Input: RDI = virtual address, RSI = physical address
tlb_update:
    push rbp
    mov rbp, rsp
    
    ; Calculate TLB index
    mov rax, rdi
    shr rax, 12
    and rax, 0xFF
    
    ; Store entry
    lea rbx, [memory_state + memory_state.tlb]
    mov [rbx + rax * 16], rdi      ; Virtual address
    mov [rbx + rax * 16 + 8], rsi  ; Physical address
    
    ; Mark as valid
    lea rbx, [memory_state + memory_state.tlb_valid]
    mov byte [rbx + rax], 1
    
    pop rbp
    ret

; Invalidate TLB entry
; Input: RDI = virtual address
tlb_invalidate:
    push rbp
    mov rbp, rsp
    
    ; Calculate TLB index
    mov rax, rdi
    shr rax, 12
    and rax, 0xFF
    
    ; Mark as invalid
    lea rbx, [memory_state + memory_state.tlb_valid]
    mov byte [rbx + rax], 0
    
    pop rbp
    ret

; MMIO read handler
; Input: RDI = address, RSI = buffer, RDX = size
mmio_read:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    
    mov r12, rdi  ; Address
    mov r13, rsi  ; Buffer
    mov r14, rdx  ; Size
    
    ; Find MMIO handler
    lea rbx, [memory_state + memory_state.mmio_ranges]
    lea rcx, [memory_state + memory_state.mmio_handlers]
    mov rdx, [memory_state + memory_state.num_mmio]
    
.find_handler:
    test rdx, rdx
    jz .no_handler
    
    dec rdx
    mov rax, [rbx + rdx * 16]      ; Start address
    mov r8, [rbx + rdx * 16 + 8]   ; End address
    
    cmp r12, rax
    jb .find_handler
    cmp r12, r8
    jae .find_handler
    
    ; Found handler
    mov rax, [rcx + rdx * 8]
    test rax, rax
    jz .no_handler
    
    ; Call handler
    mov rdi, r12
    mov rsi, r13
    mov rdx, r14
    call rax
    
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret
    
.no_handler:
    ; Default: return zeros
    mov rdi, r13
    mov rsi, 0
    mov rdx, r14
    call memset
    
    xor eax, eax
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; MMIO write handler
; Input: RDI = address, RSI = data, RDX = size
mmio_write:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    
    mov r12, rdi  ; Address
    mov r13, rsi  ; Data
    mov r14, rdx  ; Size
    
    ; Find MMIO handler (similar to read)
    lea rbx, [memory_state + memory_state.mmio_ranges]
    lea rcx, [memory_state + memory_state.mmio_handlers]
    mov rdx, [memory_state + memory_state.num_mmio]
    
.find_handler:
    test rdx, rdx
    jz .no_handler
    
    dec rdx
    mov rax, [rbx + rdx * 16]
    mov r8, [rbx + rdx * 16 + 8]
    
    cmp r12, rax
    jb .find_handler
    cmp r12, r8
    jae .find_handler
    
    ; Found handler - call with write flag
    mov rax, [rcx + rdx * 8]
    test rax, rax
    jz .no_handler
    
    ; Call handler with write flag
    mov rdi, r12
    mov rsi, r13
    mov rdx, r14
    mov rcx, 1  ; Write flag
    call rax
    
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret
    
.no_handler:
    ; Default: ignore writes
    xor eax, eax
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; Console MMIO handler
; Input: RDI = address, RSI = buffer/data, RDX = size, RCX = write flag
console_mmio_handler:
    push rbp
    mov rbp, rsp
    
    ; Check if it's a write operation
    test rcx, rcx
    jnz .write
    
    ; Read operation - return console status
    mov rax, 0x1234  ; Console ready
    mov [rsi], rax
    
    xor eax, eax
    jmp .done
    
.write:
    ; Write operation - output to console
    ; For now, just return success
    xor eax, eax
    
.done:
    pop rbp
    ret

; Clean up memory subsystem
global memory_cleanup
memory_cleanup:
    push rbp
    mov rbp, rsp
    push rbx
    
    ; Free memory
    mov rdi, [memory_state + memory_state.memory_base]
    test rdi, rdi
    jz .no_memory
    call free
    
.no_memory:
    
    ; Free page tables
    lea rbx, [memory_state + memory_state.page_tables]
    mov rcx, NUM_PAGE_TABLES
    
.free_page_tables:
    test rcx, rcx
    jz .done
    
    dec rcx
    mov rdi, [rbx + rcx * 8]
    test rdi, rdi
    jz .free_page_tables
    call free
    jmp .free_page_tables
    
.done:
    pop rbx
    pop rbp
    ret