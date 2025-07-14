; NanoCore Memory Management System
; Implements virtual memory, paging, and memory protection
;
; Features:
; - 48-bit virtual address space
; - 4-level page tables
; - TLB for fast translation
; - Copy-on-write support
; - Memory protection

BITS 64
SECTION .text

; Constants
%define PAGE_SIZE 4096
%define PAGE_SHIFT 12
%define TLB_ENTRIES 1024
%define TLB_WAYS 4

; Page table entry flags
%define PTE_PRESENT 0x01
%define PTE_WRITE 0x02
%define PTE_USER 0x04
%define PTE_ACCESSED 0x20
%define PTE_DIRTY 0x40
%define PTE_EXECUTE 0x80
%define PTE_COW 0x200

; Memory zones
%define ZONE_USER_CODE 0x0000000000010000
%define ZONE_USER_HEAP 0x0000000080000000
%define ZONE_USER_STACK 0x0001000000000000
%define ZONE_MMIO 0x0008000000000000
%define ZONE_KERNEL 0x0009000000000000

; Global symbols
global memory_init
global memory_read
global memory_write
global memory_allocate
global memory_free
global memory_map
global memory_unmap
global memory_protect
global tlb_flush
global page_fault_handler

; External symbols
extern vm_state
extern raise_exception

SECTION .bss
align 4096
; Page tables (4-level)
pml4_table: resb PAGE_SIZE
pdpt_tables: resb PAGE_SIZE * 512
pd_tables: resb PAGE_SIZE * 512 * 512
pt_tables: resb PAGE_SIZE * 512 * 512 * 64  ; Partial allocation

; TLB structure
tlb_entries: resb TLB_ENTRIES * 32  ; Each entry: 8B vaddr + 8B paddr + 8B flags + 8B LRU

; Memory allocation bitmap
memory_bitmap: resb 1048576  ; 1MB bitmap = 32GB addressable

; Statistics
tlb_hits: resq 1
tlb_misses: resq 1
page_faults: resq 1

SECTION .data
memory_size: dq 0
free_pages: dq 0
next_free_page: dq 0

SECTION .text

; Initialize memory subsystem
; Input: RDI = memory size in bytes
; Output: RAX = 0 on success, error code otherwise
memory_init:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    
    ; Save memory size
    mov [memory_size], rdi
    
    ; Calculate number of pages
    shr rdi, PAGE_SHIFT
    mov [free_pages], rdi
    
    ; Clear page tables
    mov rdi, pml4_table
    xor eax, eax
    mov ecx, PAGE_SIZE / 8
    rep stosq
    
    ; Initialize TLB
    call tlb_init
    
    ; Set up initial mappings
    call setup_initial_mappings
    
    ; Clear statistics
    xor eax, eax
    mov [tlb_hits], rax
    mov [tlb_misses], rax
    mov [page_faults], rax
    
    xor eax, eax
    
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; Read memory with virtual address translation
; Input: RDI = virtual address
; Output: EAX = 32-bit value, RDX:RAX for 64-bit
memory_read:
    push rbp
    mov rbp, rsp
    push rbx
    push rcx
    
    ; Check TLB first
    mov rax, rdi
    call tlb_lookup
    test rax, rax
    jz .tlb_miss
    
    ; TLB hit
    inc qword [tlb_hits]
    mov rbx, rax  ; Physical address
    jmp .do_read
    
.tlb_miss:
    inc qword [tlb_misses]
    
    ; Translate virtual to physical
    mov rax, rdi
    call translate_address
    test rax, rax
    jz .page_fault
    
    mov rbx, rax
    
    ; Update TLB
    mov rsi, rax
    mov rdi, [rbp - 8]  ; Original virtual address
    call tlb_insert
    
.do_read:
    ; Check if MMIO region
    mov rax, rbx
    shr rax, 44
    cmp rax, 0x8
    je .mmio_read
    
    ; Regular memory read
    mov eax, [rbx]
    mov edx, [rbx + 4]
    
    pop rcx
    pop rbx
    pop rbp
    ret
    
.mmio_read:
    ; Handle MMIO read
    mov rdi, rbx
    call device_read
    
    pop rcx
    pop rbx
    pop rbp
    ret
    
.page_fault:
    ; Raise page fault exception
    mov rdi, [rbp - 8]  ; Faulting address
    xor esi, esi  ; Read fault
    call page_fault_handler
    
    ; Retry after handling
    mov rdi, [rbp - 8]
    jmp memory_read

; Write memory with virtual address translation
; Input: RDI = virtual address, RSI = value to write
memory_write:
    push rbp
    mov rbp, rsp
    push rbx
    push rcx
    push rdx
    
    ; Save value
    mov rdx, rsi
    
    ; Check TLB
    mov rax, rdi
    call tlb_lookup
    test rax, rax
    jz .tlb_miss
    
    ; Check write permission in TLB
    test byte [rax + 16], PTE_WRITE
    jz .write_protected
    
    inc qword [tlb_hits]
    mov rbx, rax
    jmp .do_write
    
.tlb_miss:
    inc qword [tlb_misses]
    
    ; Translate address
    mov rax, rdi
    call translate_address
    test rax, rax
    jz .page_fault
    
    ; Check write permission
    test cl, PTE_WRITE
    jz .write_protected
    
    mov rbx, rax
    
    ; Update TLB
    mov rsi, rax
    mov rdi, [rbp - 8]
    mov rdx, rcx  ; Flags
    call tlb_insert
    
.do_write:
    ; Check for copy-on-write
    test byte [rbx + 16], PTE_COW
    jnz .handle_cow
    
    ; Check if MMIO region
    mov rax, rbx
    shr rax, 44
    cmp rax, 0x8
    je .mmio_write
    
    ; Regular memory write
    mov rax, [rbp - 24]  ; Restore value
    mov [rbx], rax
    
    ; Mark page dirty
    or byte [rbx + 16], PTE_DIRTY
    
    pop rdx
    pop rcx
    pop rbx
    pop rbp
    ret
    
.mmio_write:
    mov rdi, rbx
    mov rsi, [rbp - 24]
    call device_write
    
    pop rdx
    pop rcx
    pop rbx
    pop rbp
    ret
    
.write_protected:
    ; Raise write protection fault
    mov rdi, [rbp - 8]
    mov esi, 1  ; Write fault
    call page_fault_handler
    
    ; Retry
    mov rdi, [rbp - 8]
    mov rsi, [rbp - 24]
    jmp memory_write
    
.handle_cow:
    ; Handle copy-on-write
    mov rdi, [rbp - 8]
    call cow_handler
    
    ; Retry
    mov rdi, [rbp - 8]
    mov rsi, [rbp - 24]
    jmp memory_write
    
.page_fault:
    mov rdi, [rbp - 8]
    mov esi, 1
    call page_fault_handler
    
    mov rdi, [rbp - 8]
    mov rsi, [rbp - 24]
    jmp memory_write

; Translate virtual address to physical
; Input: RAX = virtual address
; Output: RAX = physical address, RCX = flags, or 0 if not mapped
translate_address:
    push rbp
    mov rbp, rsp
    push rbx
    push rdx
    push rsi
    push rdi
    
    mov rbx, rax  ; Save virtual address
    
    ; Extract page table indices
    mov rcx, rax
    shr rcx, 39
    and rcx, 0x1FF  ; PML4 index
    
    mov rdx, rax
    shr rdx, 30
    and rdx, 0x1FF  ; PDPT index
    
    mov rsi, rax
    shr rsi, 21
    and rsi, 0x1FF  ; PD index
    
    mov rdi, rax
    shr rdi, 12
    and rdi, 0x1FF  ; PT index
    
    ; Walk page tables
    ; Level 4 (PML4)
    lea rax, [pml4_table + rcx * 8]
    mov rax, [rax]
    test rax, PTE_PRESENT
    jz .not_mapped
    
    ; Level 3 (PDPT)
    and rax, ~0xFFF  ; Clear flags
    add rax, rdx
    shl rdx, 3
    add rax, rdx
    mov rax, [rax]
    test rax, PTE_PRESENT
    jz .not_mapped
    
    ; Check for 1GB page
    test rax, 0x80  ; PS bit
    jnz .huge_page
    
    ; Level 2 (PD)
    and rax, ~0xFFF
    add rax, rsi
    shl rsi, 3
    add rax, rsi
    mov rax, [rax]
    test rax, PTE_PRESENT
    jz .not_mapped
    
    ; Check for 2MB page
    test rax, 0x80  ; PS bit
    jnz .large_page
    
    ; Level 1 (PT)
    and rax, ~0xFFF
    add rax, rdi
    shl rdi, 3
    add rax, rdi
    mov rax, [rax]
    test rax, PTE_PRESENT
    jz .not_mapped
    
    ; Extract physical address and flags
    mov rcx, rax
    and rcx, 0xFFF  ; Save flags
    and rax, ~0xFFF  ; Clear flags
    
    ; Add page offset
    mov rdx, rbx
    and rdx, 0xFFF
    or rax, rdx
    
    jmp .done
    
.huge_page:
    ; 1GB page
    mov rcx, rax
    and rcx, 0xFFF
    and rax, ~0x3FFFFFFF  ; Clear lower 30 bits
    mov rdx, rbx
    and rdx, 0x3FFFFFFF
    or rax, rdx
    jmp .done
    
.large_page:
    ; 2MB page
    mov rcx, rax
    and rcx, 0xFFF
    and rax, ~0x1FFFFF  ; Clear lower 21 bits
    mov rdx, rbx
    and rdx, 0x1FFFFF
    or rax, rdx
    jmp .done
    
.not_mapped:
    xor eax, eax
    xor ecx, ecx
    
.done:
    pop rdi
    pop rsi
    pop rdx
    pop rbx
    pop rbp
    ret

; TLB lookup
; Input: RAX = virtual address
; Output: RAX = physical address or 0 if not found
tlb_lookup:
    push rbx
    push rcx
    push rdx
    
    ; Calculate TLB set
    mov rbx, rax
    shr rbx, PAGE_SHIFT
    and rbx, (TLB_ENTRIES / TLB_WAYS - 1)
    shl rbx, 5  ; * 32 bytes per entry
    lea rbx, [tlb_entries + rbx * TLB_WAYS]
    
    ; Search all ways
    mov ecx, TLB_WAYS
.search_loop:
    mov rdx, [rbx]  ; Virtual address tag
    cmp rdx, rax
    je .found
    
    add rbx, 32
    loop .search_loop
    
    ; Not found
    xor eax, eax
    jmp .done
    
.found:
    mov rax, [rbx + 8]  ; Physical address
    ; Update LRU
    inc qword [rbx + 24]
    
.done:
    pop rdx
    pop rcx
    pop rbx
    ret

; TLB insert
; Input: RDI = virtual address, RSI = physical address, RDX = flags
tlb_insert:
    push rbx
    push rcx
    push r8
    
    ; Calculate TLB set
    mov rbx, rdi
    shr rbx, PAGE_SHIFT
    and rbx, (TLB_ENTRIES / TLB_WAYS - 1)
    shl rbx, 5
    lea rbx, [tlb_entries + rbx * TLB_WAYS]
    
    ; Find LRU way
    xor r8, r8  ; Min LRU value
    xor rcx, rcx  ; LRU way index
    mov rax, TLB_WAYS
    
.find_lru:
    cmp qword [rbx + rax * 32 - 8], r8
    cmova r8, [rbx + rax * 32 - 8]
    cmova rcx, rax
    dec rax
    jnz .find_lru
    
    ; Insert into LRU way
    shl rcx, 5
    add rbx, rcx
    mov [rbx], rdi      ; Virtual address
    mov [rbx + 8], rsi  ; Physical address
    mov [rbx + 16], rdx ; Flags
    mov qword [rbx + 24], 0  ; Reset LRU
    
    pop r8
    pop rcx
    pop rbx
    ret

; Initialize TLB
tlb_init:
    push rdi
    push rcx
    
    lea rdi, [tlb_entries]
    xor eax, eax
    mov ecx, TLB_ENTRIES * 4  ; 4 qwords per entry
    rep stosq
    
    pop rcx
    pop rdi
    ret

; Flush entire TLB
tlb_flush:
    push rdi
    push rcx
    
    lea rdi, [tlb_entries]
    xor eax, eax
    mov ecx, TLB_ENTRIES * 4
    rep stosq
    
    pop rcx
    pop rdi
    ret

; Allocate physical pages
; Input: RDI = number of pages
; Output: RAX = physical address or 0 if out of memory
memory_allocate:
    push rbx
    push rcx
    push rdx
    
    ; Check if enough free pages
    cmp rdi, [free_pages]
    ja .out_of_memory
    
    ; Find contiguous free pages in bitmap
    mov rcx, rdi  ; Pages needed
    mov rbx, [next_free_page]
    
.search_loop:
    ; Check if page is free
    mov rax, rbx
    shr rax, 3
    movzx edx, byte [memory_bitmap + rax]
    mov eax, ebx
    and eax, 7
    bt edx, eax
    jc .not_free
    
    ; Found free page, check for contiguous block
    push rcx
    push rbx
    
.check_contiguous:
    mov rax, rbx
    shr rax, 3
    movzx edx, byte [memory_bitmap + rax]
    mov eax, ebx
    and eax, 7
    bt edx, eax
    jc .not_contiguous
    
    inc rbx
    loop .check_contiguous
    
    ; Found contiguous block
    pop rbx
    pop rcx
    
    ; Mark pages as allocated
    push rbx
    push rcx
    
.mark_allocated:
    mov rax, rbx
    shr rax, 3
    mov edx, ebx
    and edx, 7
    bts [memory_bitmap + rax], edx
    inc rbx
    loop .mark_allocated
    
    pop rcx
    pop rbx
    
    ; Update free pages count
    sub [free_pages], rdi
    
    ; Update next free hint
    add rbx, rcx
    mov [next_free_page], rbx
    
    ; Return physical address
    mov rax, rbx
    shl rax, PAGE_SHIFT
    
    jmp .done
    
.not_contiguous:
    pop rbx
    pop rcx
    
.not_free:
    inc rbx
    mov rax, [memory_size]
    shr rax, PAGE_SHIFT
    cmp rbx, rax
    jb .search_loop
    
    ; Wrap around
    xor ebx, ebx
    jmp .search_loop
    
.out_of_memory:
    xor eax, eax
    
.done:
    pop rdx
    pop rcx
    pop rbx
    ret

; Free physical pages
; Input: RDI = physical address, RSI = number of pages
memory_free:
    push rbx
    push rcx
    push rdx
    
    ; Convert to page number
    mov rbx, rdi
    shr rbx, PAGE_SHIFT
    
    mov rcx, rsi
.free_loop:
    mov rax, rbx
    shr rax, 3
    mov edx, ebx
    and edx, 7
    btr [memory_bitmap + rax], edx
    inc rbx
    loop .free_loop
    
    ; Update free pages count
    add [free_pages], rsi
    
    ; Update next free hint if lower
    shr rdi, PAGE_SHIFT
    cmp rdi, [next_free_page]
    cmovb [next_free_page], rdi
    
    pop rdx
    pop rcx
    pop rbx
    ret

; Set up initial memory mappings
setup_initial_mappings:
    ; Identity map first 1GB for kernel
    xor edi, edi
    mov esi, edi
    mov edx, 0x40000000  ; 1GB
    mov ecx, PTE_PRESENT | PTE_WRITE
    call map_region
    
    ; Map MMIO space
    mov rdi, ZONE_MMIO
    mov rsi, ZONE_MMIO
    mov edx, 0x100000000  ; 4GB
    mov ecx, PTE_PRESENT | PTE_WRITE
    call map_region
    
    ret

; Map a region of memory
; Input: RDI = virtual address, RSI = physical address, 
;        RDX = size, RCX = flags
map_region:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    
    ; Save parameters
    mov r12, rdi            ; Virtual address
    mov r13, rsi            ; Physical address
    mov r14, rdx            ; Size
    mov r15, rcx            ; Flags
    
    ; Align addresses to page boundary
    and r12, ~0xFFF
    and r13, ~0xFFF
    
    ; Round size up to page boundary
    add r14, 0xFFF
    and r14, ~0xFFF
    
.map_loop:
    ; Map one page
    mov rdi, r12
    mov rsi, r13
    mov rcx, r15
    call map_page
    
    ; Advance to next page
    add r12, PAGE_SIZE
    add r13, PAGE_SIZE
    sub r14, PAGE_SIZE
    jnz .map_loop
    
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; Page fault handler
; Input: RDI = faulting address, RSI = fault type
page_fault_handler:
    push rbp
    mov rbp, rsp
    
    ; Increment counter
    inc qword [page_faults]
    
    ; Check if valid address
    mov rax, rdi
    cmp rax, ZONE_USER_CODE
    jb .invalid_address
    cmp rax, ZONE_KERNEL
    jae .invalid_address
    
    ; Allocate new page
    push rdi
    push rsi
    mov rdi, 1  ; One page
    call memory_allocate
    test rax, rax
    jz .out_of_memory
    
    ; Map the page
    pop rsi
    pop rdi
    push rax  ; Save physical address
    
    mov rsi, rax
    mov rdx, PAGE_SIZE
    mov rcx, PTE_PRESENT | PTE_WRITE | PTE_USER
    call map_page
    
    pop rax
    
    pop rbp
    ret
    
.invalid_address:
    ; Raise segmentation fault
    mov rdi, 11  ; SIGSEGV
    call raise_exception
    
.out_of_memory:
    ; Raise out of memory exception
    mov rdi, 12  ; ENOMEM
    call raise_exception
    
    pop rbp
    ret

; Map a single page
; Input: RDI = virtual address, RSI = physical address, RCX = flags
map_page:
    push rbp
    mov rbp, rsp
    push rbx
    push rdx
    push r8
    push r9
    push r10
    push r11
    
    ; Align addresses
    and rdi, ~0xFFF
    and rsi, ~0xFFF
    
    ; Extract page table indices
    mov rax, rdi
    mov r8, rax
    shr r8, 39
    and r8, 0x1FF           ; PML4 index
    
    mov r9, rax
    shr r9, 30
    and r9, 0x1FF           ; PDPT index
    
    mov r10, rax
    shr r10, 21
    and r10, 0x1FF          ; PD index
    
    mov r11, rax
    shr r11, 12
    and r11, 0x1FF          ; PT index
    
    ; Walk/create page tables
    ; Level 4 (PML4)
    lea rbx, [pml4_table + r8 * 8]
    mov rax, [rbx]
    test rax, PTE_PRESENT
    jnz .have_pdpt
    
    ; Allocate PDPT
    push rcx
    push rdi
    push rsi
    mov rdi, 1
    call memory_allocate
    pop rsi
    pop rdi
    pop rcx
    test rax, rax
    jz .error
    
    or rax, PTE_PRESENT | PTE_WRITE | PTE_USER
    mov [rbx], rax
    
.have_pdpt:
    and rax, ~0xFFF         ; Clear flags
    
    ; Level 3 (PDPT)
    lea rbx, [rax + r9 * 8]
    mov rax, [rbx]
    test rax, PTE_PRESENT
    jnz .have_pd
    
    ; Allocate PD
    push rcx
    push rdi
    push rsi
    mov rdi, 1
    call memory_allocate
    pop rsi
    pop rdi
    pop rcx
    test rax, rax
    jz .error
    
    or rax, PTE_PRESENT | PTE_WRITE | PTE_USER
    mov [rbx], rax
    
.have_pd:
    and rax, ~0xFFF
    
    ; Level 2 (PD)
    lea rbx, [rax + r10 * 8]
    mov rax, [rbx]
    test rax, PTE_PRESENT
    jnz .have_pt
    
    ; Allocate PT
    push rcx
    push rdi
    push rsi
    mov rdi, 1
    call memory_allocate
    pop rsi
    pop rdi
    pop rcx
    test rax, rax
    jz .error
    
    or rax, PTE_PRESENT | PTE_WRITE | PTE_USER
    mov [rbx], rax
    
.have_pt:
    and rax, ~0xFFF
    
    ; Level 1 (PT)
    lea rbx, [rax + r11 * 8]
    
    ; Set page table entry
    mov rax, rsi            ; Physical address
    or rax, rcx             ; Flags
    or rax, PTE_PRESENT     ; Ensure present
    mov [rbx], rax
    
    ; Invalidate TLB entry
    invlpg [rdi]
    
    xor eax, eax            ; Success
    jmp .done
    
.error:
    mov rax, -1
    
.done:
    pop r11
    pop r10
    pop r9
    pop r8
    pop rdx
    pop rbx
    pop rbp
    ret

; Handle copy-on-write
; Input: RDI = virtual address
cow_handler:
    push rbp
    mov rbp, rsp
    push rbx
    push rcx
    push rdx
    push rsi
    push r8
    push r9
    
    ; Save faulting address
    mov r8, rdi
    and r8, ~0xFFF          ; Page align
    
    ; Get current mapping
    mov rax, r8
    call translate_address
    test rax, rax
    jz .error               ; Not mapped
    
    mov r9, rax             ; Save physical address
    
    ; Check if really COW
    test cl, PTE_COW
    jz .error               ; Not COW page
    
    ; Allocate new page
    mov rdi, 1
    call memory_allocate
    test rax, rax
    jz .error
    
    mov rbx, rax            ; New physical page
    
    ; Copy page contents
    mov rdi, rbx            ; Destination
    mov rsi, r9             ; Source
    mov rcx, PAGE_SIZE / 8
    rep movsq
    
    ; Update page table entry
    mov rdi, r8             ; Virtual address
    mov rsi, rbx            ; New physical address
    mov rcx, PTE_PRESENT | PTE_WRITE | PTE_USER
    call map_page
    
    ; Success
    xor eax, eax
    jmp .done
    
.error:
    mov rax, -1
    
.done:
    pop r9
    pop r8
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    pop rbp
    ret