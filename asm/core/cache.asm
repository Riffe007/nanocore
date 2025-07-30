; NanoCore Cache Module
; Handles L1 instruction cache, L1 data cache, and L2 unified cache

BITS 64
SECTION .text

; External symbols
extern memory_read
extern memory_write

; Constants
%define CACHE_LINE_SIZE 64
%define CACHE_LINE_SHIFT 6
%define CACHE_LINE_MASK 0x3F

; L1 Cache parameters
%define L1I_SIZE 32768      ; 32KB
%define L1I_WAYS 4
%define L1I_SETS (L1I_SIZE / (CACHE_LINE_SIZE * L1I_WAYS))
%define L1I_SET_SHIFT 8     ; 256 sets

%define L1D_SIZE 32768      ; 32KB
%define L1D_WAYS 8
%define L1D_SETS (L1D_SIZE / (CACHE_LINE_SIZE * L1D_WAYS))
%define L1D_SET_SHIFT 7     ; 128 sets

; L2 Cache parameters
%define L2_SIZE 262144      ; 256KB
%define L2_WAYS 16
%define L2_SETS (L2_SIZE / (CACHE_LINE_SIZE * L2_WAYS))
%define L2_SET_SHIFT 8      ; 256 sets

; Cache line structure
struc cache_line
    .tag: resq 1            ; Address tag
    .data: resb CACHE_LINE_SIZE  ; Cache line data
    .lru: resb 1            ; LRU counter
    .valid: resb 1          ; Valid bit
    .dirty: resb 1          ; Dirty bit
    .reserved: resb 4       ; Alignment
endstruc

; Cache structure
struc cache_state
    .lines: resb cache_line_size * L1I_SETS * L1I_WAYS  ; L1I cache lines
    .l1d_lines: resb cache_line_size * L1D_SETS * L1D_WAYS  ; L1D cache lines
    .l2_lines: resb cache_line_size * L2_SETS * L2_WAYS  ; L2 cache lines
    .stats: resq 8          ; Cache statistics
endstruc

; Global symbols
global cache_init
global cache_lookup
global cache_update
global cache_invalidate
global cache_flush
global cache_get_stats

SECTION .bss
align 64
cache_state: resb cache_state_size

SECTION .data
align 64
; Cache statistics indices
%define STAT_L1I_HITS 0
%define STAT_L1I_MISSES 1
%define STAT_L1D_HITS 2
%define STAT_L1D_MISSES 3
%define STAT_L2_HITS 4
%define STAT_L2_MISSES 5
%define STAT_WRITEBACKS 6
%define STAT_INVALIDATES 7

SECTION .text

; Initialize cache subsystem
global cache_init
cache_init:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    
    ; Clear cache state
    lea rdi, [cache_state]
    xor eax, eax
    mov ecx, cache_state_size / 8
    rep stosq
    
    ; Initialize LRU counters
    lea rbx, [cache_state + cache_state.lines]
    mov r12, 0  ; Way counter
    
.init_l1i_lru:
    cmp r12, L1I_WAYS
    jae .init_l1d
    
    mov ecx, L1I_SETS
    lea rdi, [rbx + r12 * cache_line_size]
    
.init_l1i_set:
    mov byte [rdi + cache_line.lru], 0
    mov byte [rdi + cache_line.valid], 0
    mov byte [rdi + cache_line.dirty], 0
    add rdi, L1I_WAYS * cache_line_size
    loop .init_l1i_set
    
    inc r12
    jmp .init_l1i_lru
    
.init_l1d:
    lea rbx, [cache_state + cache_state.l1d_lines]
    mov r12, 0
    
.init_l1d_lru:
    cmp r12, L1D_WAYS
    jae .init_l2
    
    mov ecx, L1D_SETS
    lea rdi, [rbx + r12 * cache_line_size]
    
.init_l1d_set:
    mov byte [rdi + cache_line.lru], 0
    mov byte [rdi + cache_line.valid], 0
    mov byte [rdi + cache_line.dirty], 0
    add rdi, L1D_WAYS * cache_line_size
    loop .init_l1d_set
    
    inc r12
    jmp .init_l1d_lru
    
.init_l2:
    lea rbx, [cache_state + cache_state.l2_lines]
    mov r12, 0
    
.init_l2_lru:
    cmp r12, L2_WAYS
    jae .done
    
    mov ecx, L2_SETS
    lea rdi, [rbx + r12 * cache_line_size]
    
.init_l2_set:
    mov byte [rdi + cache_line.lru], 0
    mov byte [rdi + cache_line.valid], 0
    mov byte [rdi + cache_line.dirty], 0
    add rdi, L2_WAYS * cache_line_size
    loop .init_l2_set
    
    inc r12
    jmp .init_l2_lru
    
.done:
    xor eax, eax
    pop r12
    pop rbx
    pop rbp
    ret

; Look up address in cache
; Input: RDI = address, RSI = cache type (0=L1I, 1=L1D, 2=L2)
; Output: RAX = pointer to cache line (0 if miss)
cache_lookup:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    
    mov r12, rdi  ; Address
    mov r13, rsi  ; Cache type
    
    ; Calculate set index and tag
    mov rax, r12
    shr rax, CACHE_LINE_SHIFT
    
    ; Select cache based on type
    cmp r13, 0
    je .l1i_lookup
    cmp r13, 1
    je .l1d_lookup
    cmp r13, 2
    je .l2_lookup
    jmp .miss
    
.l1i_lookup:
    ; L1I cache lookup
    and rax, (L1I_SETS - 1)  ; Set index
    mov rbx, rax
    shl rbx, L1I_WAYS
    shl rbx, CACHE_LINE_SHIFT  ; Set offset
    lea rbx, [cache_state + cache_state.lines + rbx]
    
    mov rcx, L1I_WAYS
    mov r14, 0  ; Way counter
    
.search_l1i:
    lea rdi, [rbx + r14 * cache_line_size]
    cmp byte [rdi + cache_line.valid], 0
    je .next_l1i_way
    
    mov rax, r12
    shr rax, CACHE_LINE_SHIFT
    shr rax, L1I_SET_SHIFT
    cmp [rdi + cache_line.tag], rax
    je .hit
    
.next_l1i_way:
    inc r14
    loop .search_l1i
    jmp .miss
    
.l1d_lookup:
    ; L1D cache lookup
    and rax, (L1D_SETS - 1)  ; Set index
    mov rbx, rax
    shl rbx, L1D_WAYS
    shl rbx, CACHE_LINE_SHIFT  ; Set offset
    lea rbx, [cache_state + cache_state.l1d_lines + rbx]
    
    mov rcx, L1D_WAYS
    mov r14, 0  ; Way counter
    
.search_l1d:
    lea rdi, [rbx + r14 * cache_line_size]
    cmp byte [rdi + cache_line.valid], 0
    je .next_l1d_way
    
    mov rax, r12
    shr rax, CACHE_LINE_SHIFT
    shr rax, L1D_SET_SHIFT
    cmp [rdi + cache_line.tag], rax
    je .hit
    
.next_l1d_way:
    inc r14
    loop .search_l1d
    jmp .miss
    
.l2_lookup:
    ; L2 cache lookup
    and rax, (L2_SETS - 1)  ; Set index
    mov rbx, rax
    shl rbx, L2_WAYS
    shl rbx, CACHE_LINE_SHIFT  ; Set offset
    lea rbx, [cache_state + cache_state.l2_lines + rbx]
    
    mov rcx, L2_WAYS
    mov r14, 0  ; Way counter
    
.search_l2:
    lea rdi, [rbx + r14 * cache_line_size]
    cmp byte [rdi + cache_line.valid], 0
    je .next_l2_way
    
    mov rax, r12
    shr rax, CACHE_LINE_SHIFT
    shr rax, L2_SET_SHIFT
    cmp [rdi + cache_line.tag], rax
    je .hit
    
.next_l2_way:
    inc r14
    loop .search_l2
    jmp .miss
    
.hit:
    ; Update LRU
    call update_lru
    
    ; Return cache line pointer
    mov rax, rdi
    jmp .done
    
.miss:
    xor eax, eax
    
.done:
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; Update cache line
; Input: RDI = address, RSI = data pointer, RDX = cache type
; Output: RAX = 0 on success, error code otherwise
cache_update:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    
    mov r12, rdi  ; Address
    mov r13, rsi  ; Data pointer
    mov r14, rdx  ; Cache type
    
    ; Try to find existing cache line
    mov rdi, r12
    mov rsi, r14
    call cache_lookup
    test rax, rax
    jnz .update_existing
    
    ; Cache miss - allocate new line
    mov rdi, r12
    mov rsi, r14
    call allocate_cache_line
    test rax, rax
    jz .error
    
.update_existing:
    mov r15, rax  ; Cache line pointer
    
    ; Copy data to cache line
    mov rdi, r15
    add rdi, cache_line.data
    mov rsi, r13
    mov rdx, CACHE_LINE_SIZE
    call memcpy
    
    ; Set tag and valid bit
    mov rax, r12
    shr rax, CACHE_LINE_SHIFT
    
    ; Set tag based on cache type
    cmp r14, 0
    je .set_l1i_tag
    cmp r14, 1
    je .set_l1d_tag
    cmp r14, 2
    je .set_l2_tag
    
.set_l1i_tag:
    shr rax, L1I_SET_SHIFT
    jmp .store_tag
    
.set_l1d_tag:
    shr rax, L1D_SET_SHIFT
    jmp .store_tag
    
.set_l2_tag:
    shr rax, L2_SET_SHIFT
    
.store_tag:
    mov [r15 + cache_line.tag], rax
    mov byte [r15 + cache_line.valid], 1
    
    ; Update LRU
    mov rdi, r15
    call update_lru
    
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

; Allocate cache line (evict if necessary)
; Input: RDI = address, RSI = cache type
; Output: RAX = pointer to cache line (0 if error)
allocate_cache_line:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    
    mov r12, rdi  ; Address
    mov r13, rsi  ; Cache type
    
    ; Calculate set index
    mov rax, r12
    shr rax, CACHE_LINE_SHIFT
    
    ; Select cache based on type
    cmp r13, 0
    je .alloc_l1i
    cmp r13, 1
    je .alloc_l1d
    cmp r13, 2
    je .alloc_l2
    jmp .error
    
.alloc_l1i:
    and rax, (L1I_SETS - 1)
    mov rbx, rax
    shl rbx, L1I_WAYS
    shl rbx, CACHE_LINE_SHIFT
    lea rbx, [cache_state + cache_state.lines + rbx]
    mov r14, L1I_WAYS
    jmp .find_victim
    
.alloc_l1d:
    and rax, (L1D_SETS - 1)
    mov rbx, rax
    shl rbx, L1D_WAYS
    shl rbx, CACHE_LINE_SHIFT
    lea rbx, [cache_state + cache_state.l1d_lines + rbx]
    mov r14, L1D_WAYS
    jmp .find_victim
    
.alloc_l2:
    and rax, (L2_SETS - 1)
    mov rbx, rax
    shl rbx, L2_WAYS
    shl rbx, CACHE_LINE_SHIFT
    lea rbx, [cache_state + cache_state.l2_lines + rbx]
    mov r14, L2_WAYS
    
.find_victim:
    ; Find invalid line or LRU victim
    mov rcx, r14
    mov r15, 0  ; Way counter
    
.search_invalid:
    lea rdi, [rbx + r15 * cache_line_size]
    cmp byte [rdi + cache_line.valid], 0
    je .found_victim
    
    inc r15
    loop .search_invalid
    
    ; All lines valid - find LRU victim
    mov rcx, r14
    mov r15, 0
    mov rdx, 0xFF  ; Max LRU value
    
.find_lru:
    lea rdi, [rbx + r15 * cache_line_size]
    movzx eax, byte [rdi + cache_line.lru]
    cmp al, dl
    cmovb rdx, rax
    cmovb r15, rcx
    
    inc r15
    loop .find_lru
    
    ; Use way 0 as fallback
    mov r15, 0
    
.found_victim:
    lea rax, [rbx + r15 * cache_line_size]
    
    ; Write back if dirty
    cmp byte [rax + cache_line.dirty], 0
    je .no_writeback
    
    ; Write back to memory (simplified)
    ; In real implementation, would write to L2 or memory
    
.no_writeback:
    ; Clear the line
    mov byte [rax + cache_line.valid], 0
    mov byte [rax + cache_line.dirty], 0
    mov byte [rax + cache_line.lru], 0
    
    jmp .done
    
.error:
    xor eax, eax
    
.done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; Update LRU counter for cache line
; Input: RDI = cache line pointer
update_lru:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    
    mov r12, rdi  ; Cache line pointer
    
    ; Find which set this line belongs to
    lea rbx, [cache_state + cache_state.lines]
    sub r12, rbx
    cmp r12, L1I_SIZE
    jb .l1i_lru
    
    lea rbx, [cache_state + cache_state.l1d_lines]
    sub r12, rbx
    cmp r12, L1D_SIZE
    jb .l1d_lru
    
    lea rbx, [cache_state + cache_state.l2_lines]
    sub r12, rbx
    jmp .l2_lru
    
.l1i_lru:
    ; L1I LRU update
    mov rax, r12
    shr rax, CACHE_LINE_SHIFT
    and rax, (L1I_SETS - 1)
    shl rax, L1I_WAYS
    shl rax, CACHE_LINE_SHIFT
    lea rbx, [cache_state + cache_state.lines + rax]
    mov r13, L1I_WAYS
    jmp .update_lru_set
    
.l1d_lru:
    ; L1D LRU update
    mov rax, r12
    shr rax, CACHE_LINE_SHIFT
    and rax, (L1D_SETS - 1)
    shl rax, L1D_WAYS
    shl rax, CACHE_LINE_SHIFT
    lea rbx, [cache_state + cache_state.l1d_lines + rax]
    mov r13, L1D_WAYS
    jmp .update_lru_set
    
.l2_lru:
    ; L2 LRU update
    mov rax, r12
    shr rax, CACHE_LINE_SHIFT
    and rax, (L2_SETS - 1)
    shl rax, L2_WAYS
    shl rax, CACHE_LINE_SHIFT
    lea rbx, [cache_state + cache_state.l2_lines + rax]
    mov r13, L2_WAYS
    
.update_lru_set:
    ; Calculate which way this line is
    sub r12, rbx
    shr r12, CACHE_LINE_SHIFT
    and r12, (r13 - 1)
    
    ; Increment LRU counters for all other ways
    mov rcx, r13
    mov rdx, 0
    
.lru_loop:
    cmp rdx, r12
    je .skip_way
    
    lea rdi, [rbx + rdx * cache_line_size]
    inc byte [rdi + cache_line.lru]
    
.skip_way:
    inc rdx
    loop .lru_loop
    
    ; Set this way's LRU to 0
    lea rdi, [rbx + r12 * cache_line_size]
    mov byte [rdi + cache_line.lru], 0
    
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; Invalidate cache line
; Input: RDI = address, RSI = cache type
cache_invalidate:
    push rbp
    mov rbp, rsp
    push rbx
    
    ; Look up the cache line
    call cache_lookup
    test rax, rax
    jz .not_found
    
    ; Invalidate it
    mov byte [rax + cache_line.valid], 0
    mov byte [rax + cache_line.dirty], 0
    
    ; Update statistics
    lea rbx, [cache_state + cache_state.stats]
    inc qword [rbx + STAT_INVALIDATES * 8]
    
.not_found:
    pop rbx
    pop rbp
    ret

; Flush entire cache
; Input: RDI = cache type (0=all, 1=L1I, 2=L1D, 3=L2)
cache_flush:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    
    mov r12, rdi  ; Cache type
    
    ; Flush L1I
    cmp r12, 0
    je .flush_l1i
    cmp r12, 1
    je .flush_l1i
    jmp .check_l1d
    
.flush_l1i:
    lea rbx, [cache_state + cache_state.lines]
    mov rcx, L1I_SETS * L1I_WAYS
    
.flush_l1i_loop:
    mov byte [rbx + cache_line.valid], 0
    mov byte [rbx + cache_line.dirty], 0
    mov byte [rbx + cache_line.lru], 0
    add rbx, cache_line_size
    loop .flush_l1i_loop
    
.check_l1d:
    ; Flush L1D
    cmp r12, 0
    je .flush_l1d
    cmp r12, 2
    je .flush_l1d
    jmp .check_l2
    
.flush_l1d:
    lea rbx, [cache_state + cache_state.l1d_lines]
    mov rcx, L1D_SETS * L1D_WAYS
    
.flush_l1d_loop:
    mov byte [rbx + cache_line.valid], 0
    mov byte [rbx + cache_line.dirty], 0
    mov byte [rbx + cache_line.lru], 0
    add rbx, cache_line_size
    loop .flush_l1d_loop
    
.check_l2:
    ; Flush L2
    cmp r12, 0
    je .flush_l2
    cmp r12, 3
    je .flush_l2
    jmp .done
    
.flush_l2:
    lea rbx, [cache_state + cache_state.l2_lines]
    mov rcx, L2_SETS * L2_WAYS
    
.flush_l2_loop:
    mov byte [rbx + cache_line.valid], 0
    mov byte [rbx + cache_line.dirty], 0
    mov byte [rbx + cache_line.lru], 0
    add rbx, cache_line_size
    loop .flush_l2_loop
    
.done:
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; Get cache statistics
; Input: RDI = statistics array pointer
cache_get_stats:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    
    mov r12, rdi  ; Statistics array pointer
    
    ; Copy statistics
    lea rbx, [cache_state + cache_state.stats]
    mov rcx, 8  ; 8 statistics counters
    
.copy_stats:
    mov rax, [rbx + rcx * 8 - 8]
    mov [r12 + rcx * 8 - 8], rax
    loop .copy_stats
    
    pop r12
    pop rbx
    pop rbp
    ret

; Memory copy function (simplified)
memcpy:
    push rbp
    mov rbp, rsp
    push rbx
    push rcx
    
    mov rbx, rdi  ; Destination
    mov rcx, rdx  ; Count
    
    ; Copy bytes
    rep movsb
    
    pop rcx
    pop rbx
    pop rbp
    ret