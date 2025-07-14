; NanoCore Cache Subsystem
; Implements L1I/L1D and L2 unified cache with LRU replacement
;
; Features:
; - 32KB L1 instruction cache (4-way set associative)
; - 32KB L1 data cache (4-way set associative)  
; - 256KB L2 unified cache (8-way set associative)
; - Write-back policy with dirty tracking
; - Hardware prefetching
; - Cache coherency support

BITS 64
SECTION .text

; Constants
%define L1_SIZE 32768           ; 32KB
%define L1_LINE_SIZE 64         ; 64 byte cache lines
%define L1_WAYS 4               ; 4-way set associative
%define L1_SETS (L1_SIZE / (L1_LINE_SIZE * L1_WAYS))

%define L2_SIZE 262144          ; 256KB
%define L2_LINE_SIZE 64         ; 64 byte cache lines
%define L2_WAYS 8               ; 8-way set associative
%define L2_SETS (L2_SIZE / (L2_LINE_SIZE * L2_WAYS))

; Cache line states
%define CACHE_INVALID 0
%define CACHE_VALID 1
%define CACHE_DIRTY 2
%define CACHE_SHARED 4
%define CACHE_EXCLUSIVE 8

; Global symbols
global cache_init
global cache_lookup
global cache_update
global cache_flush
global cache_invalidate
global l1i_lookup
global l1i_insert
global l1d_lookup
global l1d_insert
global l2_lookup
global l2_insert
global prefetch_enable
global prefetch_disable

; External symbols
extern memory_read
extern memory_write

SECTION .bss
align 64
; L1 Instruction Cache
l1i_tags: resq L1_SETS * L1_WAYS       ; Tag array
l1i_state: resb L1_SETS * L1_WAYS      ; State array
l1i_lru: resb L1_SETS * L1_WAYS        ; LRU counters
l1i_data: resb L1_SIZE                 ; Data array

; L1 Data Cache
l1d_tags: resq L1_SETS * L1_WAYS
l1d_state: resb L1_SETS * L1_WAYS
l1d_lru: resb L1_SETS * L1_WAYS
l1d_data: resb L1_SIZE

; L2 Unified Cache
l2_tags: resq L2_SETS * L2_WAYS
l2_state: resb L2_SETS * L2_WAYS
l2_lru: resb L2_SETS * L2_WAYS
l2_data: resb L2_SIZE

; Statistics
cache_hits: resq 4      ; L1I, L1D, L2, Prefetch
cache_misses: resq 4
cache_evictions: resq 4
cache_writebacks: resq 4

; Prefetcher state
prefetch_enabled: resb 1
prefetch_stride: resq 1
prefetch_last_addr: resq 1
prefetch_confidence: resb 1

SECTION .text

; Initialize cache subsystem
; Output: RAX = 0 on success
cache_init:
    push rbp
    mov rbp, rsp
    push rdi
    push rcx
    
    ; Clear L1I cache
    lea rdi, [l1i_tags]
    xor eax, eax
    mov ecx, (L1_SETS * L1_WAYS * 9 + L1_SIZE) / 8
    rep stosq
    
    ; Clear L1D cache
    lea rdi, [l1d_tags]
    mov ecx, (L1_SETS * L1_WAYS * 9 + L1_SIZE) / 8
    rep stosq
    
    ; Clear L2 cache
    lea rdi, [l2_tags]
    mov ecx, (L2_SETS * L2_WAYS * 9 + L2_SIZE) / 8
    rep stosq
    
    ; Clear statistics
    lea rdi, [cache_hits]
    mov ecx, 16
    rep stosq
    
    ; Enable prefetcher
    mov byte [prefetch_enabled], 1
    mov qword [prefetch_stride], 0
    mov qword [prefetch_last_addr], 0
    mov byte [prefetch_confidence], 0
    
    xor eax, eax
    
    pop rcx
    pop rdi
    pop rbp
    ret

; Generic cache lookup
; Input: RDI = address, RSI = cache type (0=L1I, 1=L1D, 2=L2)
; Output: RAX = data if hit, 0 if miss, RCX = hit flag
cache_lookup:
    push rbp
    mov rbp, rsp
    
    cmp rsi, 0
    je l1i_lookup
    cmp rsi, 1
    je l1d_lookup
    cmp rsi, 2
    je l2_lookup
    
    ; Invalid cache type
    xor eax, eax
    xor ecx, ecx
    
    pop rbp
    ret

; L1 Instruction Cache lookup
; Input: RDI = address
; Output: RAX = data if hit, 0 if miss, RCX = hit flag
l1i_lookup:
    push rbp
    mov rbp, rsp
    push rbx
    push rdx
    push rsi
    push r8
    push r9
    
    ; Calculate set index
    mov rax, rdi
    shr rax, 6              ; Divide by line size
    and rax, (L1_SETS - 1)  ; Modulo number of sets
    mov r8, rax             ; Save set index
    
    ; Calculate tag
    mov r9, rdi
    shr r9, 6 + 7           ; Remove offset and index bits
    
    ; Search all ways in the set
    xor ecx, ecx            ; Way counter
.search_ways:
    ; Calculate index into arrays
    mov rax, r8
    shl rax, 2              ; Multiply by L1_WAYS
    add rax, rcx
    
    ; Check if valid
    movzx edx, byte [l1i_state + rax]
    test dl, CACHE_VALID
    jz .next_way
    
    ; Check tag match
    mov rbx, [l1i_tags + rax * 8]
    cmp rbx, r9
    jne .next_way
    
    ; Cache hit!
    inc qword [cache_hits]
    
    ; Update LRU
    mov byte [l1i_lru + rax], 0
    call update_lru_l1i
    
    ; Calculate data offset
    mov rdx, rdi
    and rdx, 63             ; Offset within line
    mov rax, r8
    shl rax, 8              ; Set * 256 (4 ways * 64 bytes)
    mov rbx, rcx
    shl rbx, 6              ; Way * 64
    add rax, rbx
    add rax, rdx
    
    ; Load data
    mov rax, [l1i_data + rax]
    mov ecx, 1              ; Hit flag
    jmp .done
    
.next_way:
    inc ecx
    cmp ecx, L1_WAYS
    jl .search_ways
    
    ; Cache miss
    inc qword [cache_misses]
    xor eax, eax
    xor ecx, ecx
    
.done:
    pop r9
    pop r8
    pop rsi
    pop rdx
    pop rbx
    pop rbp
    ret

; L1 Data Cache lookup
; Input: RDI = address
; Output: RAX = data if hit, 0 if miss, RCX = hit flag
l1d_lookup:
    push rbp
    mov rbp, rsp
    push rbx
    push rdx
    push rsi
    push r8
    push r9
    
    ; Calculate set index
    mov rax, rdi
    shr rax, 6              ; Divide by line size
    and rax, (L1_SETS - 1)  ; Modulo number of sets
    mov r8, rax             ; Save set index
    
    ; Calculate tag
    mov r9, rdi
    shr r9, 6 + 7           ; Remove offset and index bits
    
    ; Search all ways in the set
    xor ecx, ecx            ; Way counter
.search_ways:
    ; Calculate index into arrays
    mov rax, r8
    shl rax, 2              ; Multiply by L1_WAYS
    add rax, rcx
    
    ; Check if valid
    movzx edx, byte [l1d_state + rax]
    test dl, CACHE_VALID
    jz .next_way
    
    ; Check tag match
    mov rbx, [l1d_tags + rax * 8]
    cmp rbx, r9
    jne .next_way
    
    ; Cache hit!
    inc qword [cache_hits + 8]
    
    ; Update LRU
    mov byte [l1d_lru + rax], 0
    call update_lru_l1d
    
    ; Calculate data offset
    mov rdx, rdi
    and rdx, 63             ; Offset within line
    mov rax, r8
    shl rax, 8              ; Set * 256 (4 ways * 64 bytes)
    mov rbx, rcx
    shl rbx, 6              ; Way * 64
    add rax, rbx
    add rax, rdx
    
    ; Load data
    mov rax, [l1d_data + rax]
    mov ecx, 1              ; Hit flag
    
    ; Trigger prefetch on hit
    cmp byte [prefetch_enabled], 0
    je .done
    call update_prefetcher
    
    jmp .done
    
.next_way:
    inc ecx
    cmp ecx, L1_WAYS
    jl .search_ways
    
    ; Cache miss
    inc qword [cache_misses + 8]
    xor eax, eax
    xor ecx, ecx
    
.done:
    pop r9
    pop r8
    pop rsi
    pop rdx
    pop rbx
    pop rbp
    ret

; L2 Unified Cache lookup
; Input: RDI = address
; Output: RAX = data if hit, 0 if miss, RCX = hit flag
l2_lookup:
    push rbp
    mov rbp, rsp
    push rbx
    push rdx
    push rsi
    push r8
    push r9
    
    ; Calculate set index
    mov rax, rdi
    shr rax, 6              ; Divide by line size
    and rax, (L2_SETS - 1)  ; Modulo number of sets
    mov r8, rax             ; Save set index
    
    ; Calculate tag
    mov r9, rdi
    shr r9, 6 + 9           ; Remove offset and index bits
    
    ; Search all ways in the set
    xor ecx, ecx            ; Way counter
.search_ways:
    ; Calculate index into arrays
    mov rax, r8
    shl rax, 3              ; Multiply by L2_WAYS
    add rax, rcx
    
    ; Check if valid
    movzx edx, byte [l2_state + rax]
    test dl, CACHE_VALID
    jz .next_way
    
    ; Check tag match
    mov rbx, [l2_tags + rax * 8]
    cmp rbx, r9
    jne .next_way
    
    ; Cache hit!
    inc qword [cache_hits + 16]
    
    ; Update LRU
    mov byte [l2_lru + rax], 0
    call update_lru_l2
    
    ; Calculate data offset
    mov rdx, rdi
    and rdx, 63             ; Offset within line
    mov rax, r8
    shl rax, 9              ; Set * 512 (8 ways * 64 bytes)
    mov rbx, rcx
    shl rbx, 6              ; Way * 64
    add rax, rbx
    add rax, rdx
    
    ; Load data
    mov rax, [l2_data + rax]
    mov ecx, 1              ; Hit flag
    jmp .done
    
.next_way:
    inc ecx
    cmp ecx, L2_WAYS
    jl .search_ways
    
    ; Cache miss
    inc qword [cache_misses + 16]
    xor eax, eax
    xor ecx, ecx
    
.done:
    pop r9
    pop r8
    pop rsi
    pop rdx
    pop rbx
    pop rbp
    ret

; Insert line into L1I cache
; Input: RDI = address, RSI = data pointer
l1i_insert:
    push rbp
    mov rbp, rsp
    push rbx
    push rcx
    push rdx
    push r8
    push r9
    push r10
    
    ; Calculate set index
    mov rax, rdi
    shr rax, 6              ; Divide by line size
    and rax, (L1_SETS - 1)  ; Modulo number of sets
    mov r8, rax             ; Save set index
    
    ; Calculate tag
    mov r9, rdi
    shr r9, 6 + 7           ; Remove offset and index bits
    
    ; Find victim way (LRU)
    call find_lru_way_l1i
    mov r10, rax            ; Save victim way
    
    ; Calculate index into arrays
    mov rax, r8
    shl rax, 2              ; Multiply by L1_WAYS
    add rax, r10
    
    ; Check if dirty and evict if needed
    movzx edx, byte [l1i_state + rax]
    test dl, CACHE_DIRTY
    jz .no_writeback
    
    ; Writeback not applicable for I-cache
    
.no_writeback:
    ; Update tag
    mov [l1i_tags + rax * 8], r9
    
    ; Update state
    mov byte [l1i_state + rax], CACHE_VALID
    
    ; Update LRU
    mov byte [l1i_lru + rax], 0
    call update_lru_l1i
    
    ; Copy data to cache
    mov rdx, rdi
    and rdx, -64            ; Align to cache line
    
    ; Calculate data offset
    mov rax, r8
    shl rax, 8              ; Set * 256
    mov rbx, r10
    shl rbx, 6              ; Way * 64
    add rax, rbx
    
    ; Copy 64 bytes
    lea rdi, [l1i_data + rax]
    mov rcx, 8
    rep movsq
    
    pop r10
    pop r9
    pop r8
    pop rdx
    pop rcx
    pop rbx
    pop rbp
    ret

; Insert line into L1D cache
; Input: RDI = address, RSI = data pointer
l1d_insert:
    push rbp
    mov rbp, rsp
    push rbx
    push rcx
    push rdx
    push r8
    push r9
    push r10
    
    ; Calculate set index
    mov rax, rdi
    shr rax, 6              ; Divide by line size
    and rax, (L1_SETS - 1)  ; Modulo number of sets
    mov r8, rax             ; Save set index
    
    ; Calculate tag
    mov r9, rdi
    shr r9, 6 + 7           ; Remove offset and index bits
    
    ; Find victim way (LRU)
    call find_lru_way_l1d
    mov r10, rax            ; Save victim way
    
    ; Calculate index into arrays
    mov rax, r8
    shl rax, 2              ; Multiply by L1_WAYS
    add rax, r10
    
    ; Check if dirty and evict if needed
    movzx edx, byte [l1d_state + rax]
    test dl, CACHE_DIRTY
    jz .no_writeback
    
    ; Perform writeback
    inc qword [cache_writebacks]
    call writeback_l1d_line
    
.no_writeback:
    ; Update tag
    mov [l1d_tags + rax * 8], r9
    
    ; Update state
    mov byte [l1d_state + rax], CACHE_VALID
    
    ; Update LRU
    mov byte [l1d_lru + rax], 0
    call update_lru_l1d
    
    ; Copy data to cache
    mov rdx, rdi
    and rdx, -64            ; Align to cache line
    
    ; Calculate data offset
    mov rax, r8
    shl rax, 8              ; Set * 256
    mov rbx, r10
    shl rbx, 6              ; Way * 64
    add rax, rbx
    
    ; Copy 64 bytes
    lea rdi, [l1d_data + rax]
    mov rcx, 8
    rep movsq
    
    pop r10
    pop r9
    pop r8
    pop rdx
    pop rcx
    pop rbx
    pop rbp
    ret

; Insert line into L2 cache
; Input: RDI = address, RSI = data pointer
l2_insert:
    push rbp
    mov rbp, rsp
    push rbx
    push rcx
    push rdx
    push r8
    push r9
    push r10
    
    ; Calculate set index
    mov rax, rdi
    shr rax, 6              ; Divide by line size
    and rax, (L2_SETS - 1)  ; Modulo number of sets
    mov r8, rax             ; Save set index
    
    ; Calculate tag
    mov r9, rdi
    shr r9, 6 + 9           ; Remove offset and index bits
    
    ; Find victim way (LRU)
    call find_lru_way_l2
    mov r10, rax            ; Save victim way
    
    ; Calculate index into arrays
    mov rax, r8
    shl rax, 3              ; Multiply by L2_WAYS
    add rax, r10
    
    ; Check if dirty and evict if needed
    movzx edx, byte [l2_state + rax]
    test dl, CACHE_DIRTY
    jz .no_writeback
    
    ; Perform writeback
    inc qword [cache_writebacks + 8]
    call writeback_l2_line
    
.no_writeback:
    ; Update tag
    mov [l2_tags + rax * 8], r9
    
    ; Update state
    mov byte [l2_state + rax], CACHE_VALID
    
    ; Update LRU
    mov byte [l2_lru + rax], 0
    call update_lru_l2
    
    ; Copy data to cache
    mov rdx, rdi
    and rdx, -64            ; Align to cache line
    
    ; Calculate data offset
    mov rax, r8
    shl rax, 9              ; Set * 512
    mov rbx, r10
    shl rbx, 6              ; Way * 64
    add rax, rbx
    
    ; Copy 64 bytes
    lea rdi, [l2_data + rax]
    mov rcx, 8
    rep movsq
    
    pop r10
    pop r9
    pop r8
    pop rdx
    pop rcx
    pop rbx
    pop rbp
    ret

; Update cache line
; Input: RDI = address, RSI = data, RDX = size, RCX = cache type
cache_update:
    push rbp
    mov rbp, rsp
    
    ; For now, just invalidate the line
    call cache_invalidate
    
    pop rbp
    ret

; Flush entire cache
cache_flush:
    push rbp
    mov rbp, rsp
    push rbx
    push rcx
    push rdx
    
    ; Flush L1D (writebacks if dirty)
    xor ecx, ecx
.flush_l1d:
    movzx edx, byte [l1d_state + rcx]
    test dl, CACHE_DIRTY
    jz .next_l1d
    
    mov rax, rcx
    call writeback_l1d_line
    
.next_l1d:
    inc ecx
    cmp ecx, L1_SETS * L1_WAYS
    jl .flush_l1d
    
    ; Flush L2
    xor ecx, ecx
.flush_l2:
    movzx edx, byte [l2_state + rcx]
    test dl, CACHE_DIRTY
    jz .next_l2
    
    mov rax, rcx
    call writeback_l2_line
    
.next_l2:
    inc ecx
    cmp ecx, L2_SETS * L2_WAYS
    jl .flush_l2
    
    ; Invalidate all caches
    call cache_invalidate_all
    
    pop rdx
    pop rcx
    pop rbx
    pop rbp
    ret

; Invalidate cache line
; Input: RDI = address
cache_invalidate:
    push rbp
    mov rbp, rsp
    
    ; Invalidate in all caches
    call invalidate_l1i_line
    call invalidate_l1d_line
    call invalidate_l2_line
    
    pop rbp
    ret

; Invalidate all caches
cache_invalidate_all:
    push rdi
    push rcx
    
    ; Clear state arrays
    lea rdi, [l1i_state]
    xor eax, eax
    mov ecx, L1_SETS * L1_WAYS
    rep stosb
    
    lea rdi, [l1d_state]
    mov ecx, L1_SETS * L1_WAYS
    rep stosb
    
    lea rdi, [l2_state]
    mov ecx, L2_SETS * L2_WAYS
    rep stosb
    
    pop rcx
    pop rdi
    ret

; Find LRU way in L1I set
; Input: R8 = set index
; Output: RAX = way index
find_lru_way_l1i:
    push rcx
    push rdx
    
    mov rax, r8
    shl rax, 2              ; Base index
    
    ; Find way with highest LRU counter
    xor ecx, ecx            ; Best way
    mov dl, 0               ; Best LRU value
    
    push rax
    xor eax, eax
.search:
    mov dh, [l1i_lru + rax]
    cmp dh, dl
    jbe .next
    mov dl, dh
    mov ecx, eax
    pop rax
    push rax
    sub ecx, eax
    
.next:
    inc eax
    cmp eax, L1_WAYS
    jl .search
    
    pop rax
    mov eax, ecx
    
    pop rdx
    pop rcx
    ret

; Find LRU way in L1D set
; Input: R8 = set index
; Output: RAX = way index
find_lru_way_l1d:
    push rcx
    push rdx
    
    mov rax, r8
    shl rax, 2              ; Base index
    
    ; Find way with highest LRU counter
    xor ecx, ecx            ; Best way
    mov dl, 0               ; Best LRU value
    
    push rax
    xor eax, eax
.search:
    mov dh, [l1d_lru + rax]
    cmp dh, dl
    jbe .next
    mov dl, dh
    mov ecx, eax
    pop rax
    push rax
    sub ecx, eax
    
.next:
    inc eax
    cmp eax, L1_WAYS
    jl .search
    
    pop rax
    mov eax, ecx
    
    pop rdx
    pop rcx
    ret

; Find LRU way in L2 set
; Input: R8 = set index
; Output: RAX = way index
find_lru_way_l2:
    push rcx
    push rdx
    
    mov rax, r8
    shl rax, 3              ; Base index
    
    ; Find way with highest LRU counter
    xor ecx, ecx            ; Best way
    mov dl, 0               ; Best LRU value
    
    push rax
    xor eax, eax
.search:
    mov dh, [l2_lru + rax]
    cmp dh, dl
    jbe .next
    mov dl, dh
    mov ecx, eax
    pop rax
    push rax
    sub ecx, eax
    
.next:
    inc eax
    cmp eax, L2_WAYS
    jl .search
    
    pop rax
    mov eax, ecx
    
    pop rdx
    pop rcx
    ret

; Update LRU counters for L1I
; Input: R8 = set index, RAX = accessed way
update_lru_l1i:
    push rcx
    push rax
    
    mov rcx, r8
    shl rcx, 2              ; Base index
    
    ; Increment all other ways' LRU counters
    xor eax, eax
.update:
    cmp eax, [rsp]          ; Compare with accessed way
    je .skip
    inc byte [l1i_lru + rcx + rax]
.skip:
    inc eax
    cmp eax, L1_WAYS
    jl .update
    
    pop rax
    pop rcx
    ret

; Update LRU counters for L1D
; Input: R8 = set index, RAX = accessed way
update_lru_l1d:
    push rcx
    push rax
    
    mov rcx, r8
    shl rcx, 2              ; Base index
    
    ; Increment all other ways' LRU counters
    xor eax, eax
.update:
    cmp eax, [rsp]          ; Compare with accessed way
    je .skip
    inc byte [l1d_lru + rcx + rax]
.skip:
    inc eax
    cmp eax, L1_WAYS
    jl .update
    
    pop rax
    pop rcx
    ret

; Update LRU counters for L2
; Input: R8 = set index, RAX = accessed way
update_lru_l2:
    push rcx
    push rax
    
    mov rcx, r8
    shl rcx, 3              ; Base index
    
    ; Increment all other ways' LRU counters
    xor eax, eax
.update:
    cmp eax, [rsp]          ; Compare with accessed way
    je .skip
    inc byte [l2_lru + rcx + rax]
.skip:
    inc eax
    cmp eax, L2_WAYS
    jl .update
    
    pop rax
    pop rcx
    ret

; Writeback L1D cache line
; Input: RAX = absolute index
writeback_l1d_line:
    push rbp
    mov rbp, rsp
    push rax
    push rbx
    push rcx
    push rdx
    push rdi
    push rsi
    
    ; Get tag and reconstruct address
    mov rbx, [l1d_tags + rax * 8]
    mov rcx, rax
    shr rcx, 2              ; Get set index
    shl rbx, 6 + 7          ; Shift tag back
    shl rcx, 6              ; Shift set index
    or rbx, rcx             ; Combine to get address
    
    ; Calculate data offset
    mov rdx, rax
    and rdx, 3              ; Way within set
    shr rax, 2              ; Set index
    shl rax, 8              ; Set * 256
    shl rdx, 6              ; Way * 64
    add rax, rdx
    
    ; Write back to memory
    mov rdi, rbx            ; Address
    lea rsi, [l1d_data + rax]  ; Data
    mov rdx, 64             ; Size
    call memory_write
    
    pop rsi
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    pop rbp
    ret

; Writeback L2 cache line
; Input: RAX = absolute index
writeback_l2_line:
    push rbp
    mov rbp, rsp
    push rax
    push rbx
    push rcx
    push rdx
    push rdi
    push rsi
    
    ; Get tag and reconstruct address
    mov rbx, [l2_tags + rax * 8]
    mov rcx, rax
    shr rcx, 3              ; Get set index
    shl rbx, 6 + 9          ; Shift tag back
    shl rcx, 6              ; Shift set index
    or rbx, rcx             ; Combine to get address
    
    ; Calculate data offset
    mov rdx, rax
    and rdx, 7              ; Way within set
    shr rax, 3              ; Set index
    shl rax, 9              ; Set * 512
    shl rdx, 6              ; Way * 64
    add rax, rdx
    
    ; Write back to memory
    mov rdi, rbx            ; Address
    lea rsi, [l2_data + rax]   ; Data
    mov rdx, 64             ; Size
    call memory_write
    
    pop rsi
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    pop rbp
    ret

; Invalidate L1I line
; Input: RDI = address
invalidate_l1i_line:
    push rax
    push rcx
    push rdx
    push r8
    push r9
    
    ; Calculate set index
    mov rax, rdi
    shr rax, 6              ; Divide by line size
    and rax, (L1_SETS - 1)  ; Modulo number of sets
    mov r8, rax             ; Save set index
    
    ; Calculate tag
    mov r9, rdi
    shr r9, 6 + 7           ; Remove offset and index bits
    
    ; Search all ways in the set
    xor ecx, ecx            ; Way counter
.search_ways:
    ; Calculate index into arrays
    mov rax, r8
    shl rax, 2              ; Multiply by L1_WAYS
    add rax, rcx
    
    ; Check tag match
    mov rdx, [l1i_tags + rax * 8]
    cmp rdx, r9
    jne .next_way
    
    ; Invalidate
    mov byte [l1i_state + rax], CACHE_INVALID
    inc qword [cache_evictions]
    jmp .done
    
.next_way:
    inc ecx
    cmp ecx, L1_WAYS
    jl .search_ways
    
.done:
    pop r9
    pop r8
    pop rdx
    pop rcx
    pop rax
    ret

; Invalidate L1D line
; Input: RDI = address
invalidate_l1d_line:
    push rax
    push rcx
    push rdx
    push r8
    push r9
    
    ; Calculate set index
    mov rax, rdi
    shr rax, 6              ; Divide by line size
    and rax, (L1_SETS - 1)  ; Modulo number of sets
    mov r8, rax             ; Save set index
    
    ; Calculate tag
    mov r9, rdi
    shr r9, 6 + 7           ; Remove offset and index bits
    
    ; Search all ways in the set
    xor ecx, ecx            ; Way counter
.search_ways:
    ; Calculate index into arrays
    mov rax, r8
    shl rax, 2              ; Multiply by L1_WAYS
    add rax, rcx
    
    ; Check tag match
    mov rdx, [l1d_tags + rax * 8]
    cmp rdx, r9
    jne .next_way
    
    ; Check if dirty
    movzx edx, byte [l1d_state + rax]
    test dl, CACHE_DIRTY
    jz .invalidate
    
    ; Writeback if dirty
    call writeback_l1d_line
    
.invalidate:
    ; Invalidate
    mov byte [l1d_state + rax], CACHE_INVALID
    inc qword [cache_evictions + 8]
    jmp .done
    
.next_way:
    inc ecx
    cmp ecx, L1_WAYS
    jl .search_ways
    
.done:
    pop r9
    pop r8
    pop rdx
    pop rcx
    pop rax
    ret

; Invalidate L2 line
; Input: RDI = address
invalidate_l2_line:
    push rax
    push rcx
    push rdx
    push r8
    push r9
    
    ; Calculate set index
    mov rax, rdi
    shr rax, 6              ; Divide by line size
    and rax, (L2_SETS - 1)  ; Modulo number of sets
    mov r8, rax             ; Save set index
    
    ; Calculate tag
    mov r9, rdi
    shr r9, 6 + 9           ; Remove offset and index bits
    
    ; Search all ways in the set
    xor ecx, ecx            ; Way counter
.search_ways:
    ; Calculate index into arrays
    mov rax, r8
    shl rax, 3              ; Multiply by L2_WAYS
    add rax, rcx
    
    ; Check tag match
    mov rdx, [l2_tags + rax * 8]
    cmp rdx, r9
    jne .next_way
    
    ; Check if dirty
    movzx edx, byte [l2_state + rax]
    test dl, CACHE_DIRTY
    jz .invalidate
    
    ; Writeback if dirty
    call writeback_l2_line
    
.invalidate:
    ; Invalidate
    mov byte [l2_state + rax], CACHE_INVALID
    inc qword [cache_evictions + 16]
    jmp .done
    
.next_way:
    inc ecx
    cmp ecx, L2_WAYS
    jl .search_ways
    
.done:
    pop r9
    pop r8
    pop rdx
    pop rcx
    pop rax
    ret

; Update prefetcher based on access pattern
; Input: RDI = current address
update_prefetcher:
    push rax
    push rbx
    push rcx
    push rdx
    
    ; Calculate stride
    mov rax, rdi
    sub rax, [prefetch_last_addr]
    
    ; Check if stride matches
    cmp rax, [prefetch_stride]
    jne .new_pattern
    
    ; Increase confidence
    inc byte [prefetch_confidence]
    cmp byte [prefetch_confidence], 3
    jl .update_last
    
    ; High confidence - issue prefetch
    mov rbx, rdi
    add rbx, rax            ; Next predicted address
    
    ; Prefetch into L2
    mov rdi, rbx
    call prefetch_to_l2
    
    jmp .update_last
    
.new_pattern:
    ; New stride detected
    mov [prefetch_stride], rax
    mov byte [prefetch_confidence], 1
    
.update_last:
    mov [prefetch_last_addr], rdi
    
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

; Prefetch address to L2
; Input: RDI = address
prefetch_to_l2:
    push rax
    push rcx
    push rsi
    
    ; Check if already in L2
    call l2_lookup
    test rcx, rcx
    jnz .done               ; Already cached
    
    ; Load from memory
    mov rsi, rdi
    and rsi, -64            ; Align to cache line
    call memory_read
    
    ; Insert into L2
    ; RSI already has data pointer
    call l2_insert
    
    inc qword [cache_hits + 24]  ; Prefetch hits
    
.done:
    pop rsi
    pop rcx
    pop rax
    ret

; Enable prefetcher
prefetch_enable:
    mov byte [prefetch_enabled], 1
    ret

; Disable prefetcher
prefetch_disable:
    mov byte [prefetch_enabled], 0
    ret