; NanoCore Pipeline Implementation
; 5-stage pipeline with hazard detection and forwarding
;
; Pipeline stages:
; 1. IF (Instruction Fetch)
; 2. ID (Instruction Decode)
; 3. EX (Execute)
; 4. MEM (Memory Access)
; 5. WB (Write Back)

BITS 64
SECTION .text

; Pipeline register structure
struc pipeline_reg
    .valid:     resb 1      ; Stage valid flag
    .pc:        resq 1      ; Program counter
    .inst:      resd 1      ; Instruction
    .opcode:    resb 1      ; Decoded opcode
    .rd:        resb 1      ; Destination register
    .rs1:       resb 1      ; Source register 1
    .rs2:       resb 1      ; Source register 2
    .imm:       resq 1      ; Immediate value
    .alu_out:   resq 1      ; ALU result
    .mem_data:  resq 1      ; Memory data
    .branch:    resb 1      ; Branch taken flag
    .mem_op:    resb 1      ; Memory operation type
    .padding:   resb 6      ; Alignment padding
endstruc

; Constants
%define PIPELINE_STAGES 5
%define BRANCH_PRED_SIZE 1024
%define BTB_SIZE 256

; Hazard types
%define HAZ_NONE 0
%define HAZ_DATA 1
%define HAZ_CONTROL 2
%define HAZ_STRUCT 3

; Memory operation types
%define MEM_NONE 0
%define MEM_LOAD 1
%define MEM_STORE 2

; Global symbols
global pipeline_init
global pipeline_step
global pipeline_flush
global pipeline_stall
global detect_hazards
global forward_data
global branch_predict
global branch_update

; External symbols
extern vm_state
extern fetch_instruction
extern opcode_table
extern memory_read
extern memory_write
extern update_flags

SECTION .bss
align 64
; Pipeline registers
if_id:  resb pipeline_reg_size
id_ex:  resb pipeline_reg_size
ex_mem: resb pipeline_reg_size
mem_wb: resb pipeline_reg_size

; Branch prediction structures
branch_history: resb BRANCH_PRED_SIZE   ; 2-bit saturating counters
btb_tags: resq BTB_SIZE                 ; Branch target buffer tags
btb_targets: resq BTB_SIZE              ; Branch targets
global_history: resb 1                  ; Global branch history

; Pipeline control
stall_cycles: resq 1
flush_flag: resb 1
forwarding_enabled: resb 1

; Statistics
pipeline_stalls: resq 1
pipeline_flushes: resq 1
branch_predictions: resq 1
branch_mispredicts: resq 1

SECTION .text

; Initialize pipeline
pipeline_init:
    push rbp
    mov rbp, rsp
    push rdi
    push rcx
    
    ; Clear pipeline registers
    lea rdi, [if_id]
    xor eax, eax
    mov ecx, pipeline_reg_size * 4 / 8
    rep stosq
    
    ; Initialize branch predictor
    lea rdi, [branch_history]
    mov al, 0x55            ; Weakly taken
    mov ecx, BRANCH_PRED_SIZE
    rep stosb
    
    ; Clear BTB
    lea rdi, [btb_tags]
    xor eax, eax
    mov ecx, BTB_SIZE * 2
    rep stosq
    
    ; Reset control state
    mov qword [stall_cycles], 0
    mov byte [flush_flag], 0
    mov byte [forwarding_enabled], 1
    mov byte [global_history], 0
    
    ; Clear statistics
    lea rdi, [pipeline_stalls]
    xor eax, eax
    mov ecx, 4
    rep stosq
    
    pop rcx
    pop rdi
    pop rbp
    ret

; Execute one pipeline cycle
pipeline_step:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    
    ; Check for stalls
    cmp qword [stall_cycles], 0
    je .no_stall
    dec qword [stall_cycles]
    inc qword [pipeline_stalls]
    jmp .done
    
.no_stall:
    ; Check for flush
    cmp byte [flush_flag], 0
    je .no_flush
    call pipeline_flush
    mov byte [flush_flag], 0
    inc qword [pipeline_flushes]
    
.no_flush:
    ; Execute pipeline stages in reverse order
    call stage_wb
    call stage_mem
    call stage_ex
    call stage_id
    call stage_if
    
    ; Check for hazards
    call detect_hazards
    test rax, rax
    jz .done
    
    ; Handle hazard
    cmp al, HAZ_DATA
    je .data_hazard
    cmp al, HAZ_CONTROL
    je .control_hazard
    jmp .done
    
.data_hazard:
    ; Insert bubble
    call insert_bubble
    jmp .done
    
.control_hazard:
    ; Flush pipeline
    mov byte [flush_flag], 1
    
.done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; Instruction Fetch stage
stage_if:
    push rbp
    mov rbp, rsp
    push rbx
    push rcx
    push rdx
    
    ; Check if stage is stalled
    cmp byte [if_id + pipeline_reg.valid], 0
    jne .stalled
    
    ; Get PC from VM state
    mov rax, [vm_state + 0]  ; VM_PC
    
    ; Branch prediction
    mov rdi, rax
    call branch_predict
    mov rbx, rax            ; Save prediction
    
    ; Fetch instruction
    mov rdi, [vm_state + 0]
    call fetch_instruction
    mov edx, eax            ; Save instruction
    
    ; Update IF/ID register
    mov byte [if_id + pipeline_reg.valid], 1
    mov rax, [vm_state + 0]
    mov [if_id + pipeline_reg.pc], rax
    mov [if_id + pipeline_reg.inst], edx
    
    ; Update PC based on prediction
    test rbx, rbx
    jz .no_branch_predict
    mov [vm_state + 0], rbx  ; Use predicted target
    jmp .done
    
.no_branch_predict:
    add qword [vm_state + 0], 4  ; Normal increment
    
.done:
.stalled:
    pop rdx
    pop rcx
    pop rbx
    pop rbp
    ret

; Instruction Decode stage
stage_id:
    push rbp
    mov rbp, rsp
    push rbx
    push rcx
    push rdx
    
    ; Check if stage has valid data
    cmp byte [if_id + pipeline_reg.valid], 0
    je .done
    
    ; Check if next stage is ready
    cmp byte [id_ex + pipeline_reg.valid], 0
    jne .stalled
    
    ; Decode instruction
    mov ebx, [if_id + pipeline_reg.inst]
    
    ; Extract opcode
    mov eax, ebx
    shr eax, 26
    and al, 0x3F
    mov [id_ex + pipeline_reg.opcode], al
    
    ; Extract register fields
    mov eax, ebx
    shr eax, 21
    and al, 0x1F
    mov [id_ex + pipeline_reg.rd], al
    
    mov eax, ebx
    shr eax, 16
    and al, 0x1F
    mov [id_ex + pipeline_reg.rs1], al
    
    mov eax, ebx
    shr eax, 11
    and al, 0x1F
    mov [id_ex + pipeline_reg.rs2], al
    
    ; Extract immediate
    movsx rax, bx           ; Sign extend 16-bit immediate
    mov [id_ex + pipeline_reg.imm], rax
    
    ; Determine instruction type
    movzx eax, byte [id_ex + pipeline_reg.opcode]
    call get_instruction_type
    mov [id_ex + pipeline_reg.mem_op], al
    
    ; Copy other fields
    mov rax, [if_id + pipeline_reg.pc]
    mov [id_ex + pipeline_reg.pc], rax
    mov eax, [if_id + pipeline_reg.inst]
    mov [id_ex + pipeline_reg.inst], eax
    
    ; Mark stage as valid
    mov byte [id_ex + pipeline_reg.valid], 1
    
    ; Clear previous stage
    mov byte [if_id + pipeline_reg.valid], 0
    
.done:
.stalled:
    pop rdx
    pop rcx
    pop rbx
    pop rbp
    ret

; Execute stage
stage_ex:
    push rbp
    mov rbp, rsp
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi
    
    ; Check if stage has valid data
    cmp byte [id_ex + pipeline_reg.valid], 0
    je .done
    
    ; Check if next stage is ready
    cmp byte [ex_mem + pipeline_reg.valid], 0
    jne .stalled
    
    ; Get operands with forwarding
    movzx ecx, byte [id_ex + pipeline_reg.rs1]
    test ecx, ecx
    jz .rs1_zero
    mov rdi, rcx
    call get_forwarded_value
    mov rsi, rax
    jmp .get_rs2
    
.rs1_zero:
    xor esi, esi
    
.get_rs2:
    movzx ecx, byte [id_ex + pipeline_reg.rs2]
    test ecx, ecx
    jz .rs2_zero
    mov rdi, rcx
    call get_forwarded_value
    mov rdi, rax
    jmp .execute_alu
    
.rs2_zero:
    xor edi, edi
    
.execute_alu:
    ; Execute based on opcode
    movzx eax, byte [id_ex + pipeline_reg.opcode]
    cmp al, 0x00            ; ADD
    je .alu_add
    cmp al, 0x01            ; SUB
    je .alu_sub
    cmp al, 0x02            ; MUL
    je .alu_mul
    cmp al, 0x06            ; AND
    je .alu_and
    cmp al, 0x07            ; OR
    je .alu_or
    cmp al, 0x08            ; XOR
    je .alu_xor
    cmp al, 0x0F            ; LD
    je .alu_add_imm
    cmp al, 0x13            ; ST
    je .alu_add_imm
    
    ; Default: pass through rs1
    mov rax, rsi
    jmp .store_result
    
.alu_add:
    lea rax, [rsi + rdi]
    jmp .store_result
    
.alu_sub:
    mov rax, rsi
    sub rax, rdi
    jmp .store_result
    
.alu_mul:
    mov rax, rsi
    imul rax, rdi
    jmp .store_result
    
.alu_and:
    mov rax, rsi
    and rax, rdi
    jmp .store_result
    
.alu_or:
    mov rax, rsi
    or rax, rdi
    jmp .store_result
    
.alu_xor:
    mov rax, rsi
    xor rax, rdi
    jmp .store_result
    
.alu_add_imm:
    mov rax, rsi
    add rax, [id_ex + pipeline_reg.imm]
    
.store_result:
    mov [ex_mem + pipeline_reg.alu_out], rax
    
    ; Handle branches
    movzx eax, byte [id_ex + pipeline_reg.opcode]
    cmp al, 0x17            ; BEQ
    jl .not_branch
    cmp al, 0x1C            ; BGEU
    jg .not_branch
    
    ; Evaluate branch condition
    call evaluate_branch
    mov [ex_mem + pipeline_reg.branch], al
    
    ; Check prediction
    mov rdi, [id_ex + pipeline_reg.pc]
    movzx esi, al
    call check_branch_prediction
    test rax, rax
    jz .not_branch
    
    ; Misprediction - flush pipeline
    mov byte [flush_flag], 1
    inc qword [branch_mispredicts]
    
.not_branch:
    ; Copy fields to next stage
    mov rax, [id_ex + pipeline_reg.pc]
    mov [ex_mem + pipeline_reg.pc], rax
    mov eax, [id_ex + pipeline_reg.inst]
    mov [ex_mem + pipeline_reg.inst], eax
    movzx eax, byte [id_ex + pipeline_reg.rd]
    mov [ex_mem + pipeline_reg.rd], al
    movzx eax, byte [id_ex + pipeline_reg.mem_op]
    mov [ex_mem + pipeline_reg.mem_op], al
    
    ; For stores, save rs2 value
    cmp al, MEM_STORE
    jne .not_store
    mov [ex_mem + pipeline_reg.mem_data], rdi
    
.not_store:
    ; Mark stage as valid
    mov byte [ex_mem + pipeline_reg.valid], 1
    
    ; Clear previous stage
    mov byte [id_ex + pipeline_reg.valid], 0
    
.done:
.stalled:
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    pop rbp
    ret

; Memory stage
stage_mem:
    push rbp
    mov rbp, rsp
    push rbx
    push rcx
    push rdx
    
    ; Check if stage has valid data
    cmp byte [ex_mem + pipeline_reg.valid], 0
    je .done
    
    ; Check if next stage is ready
    cmp byte [mem_wb + pipeline_reg.valid], 0
    jne .stalled
    
    ; Check memory operation type
    movzx eax, byte [ex_mem + pipeline_reg.mem_op]
    cmp al, MEM_LOAD
    je .do_load
    cmp al, MEM_STORE
    je .do_store
    
    ; No memory operation - pass through ALU result
    mov rax, [ex_mem + pipeline_reg.alu_out]
    mov [mem_wb + pipeline_reg.mem_data], rax
    jmp .copy_fields
    
.do_load:
    ; Load from memory
    mov rdi, [ex_mem + pipeline_reg.alu_out]
    call memory_read
    mov [mem_wb + pipeline_reg.mem_data], rax
    jmp .copy_fields
    
.do_store:
    ; Store to memory
    mov rdi, [ex_mem + pipeline_reg.alu_out]
    mov rsi, [ex_mem + pipeline_reg.mem_data]
    call memory_write
    ; Pass through for forwarding
    mov rax, [ex_mem + pipeline_reg.mem_data]
    mov [mem_wb + pipeline_reg.mem_data], rax
    
.copy_fields:
    ; Copy fields to next stage
    mov rax, [ex_mem + pipeline_reg.pc]
    mov [mem_wb + pipeline_reg.pc], rax
    mov eax, [ex_mem + pipeline_reg.inst]
    mov [mem_wb + pipeline_reg.inst], eax
    movzx eax, byte [ex_mem + pipeline_reg.rd]
    mov [mem_wb + pipeline_reg.rd], al
    mov rax, [ex_mem + pipeline_reg.alu_out]
    mov [mem_wb + pipeline_reg.alu_out], rax
    
    ; Mark stage as valid
    mov byte [mem_wb + pipeline_reg.valid], 1
    
    ; Clear previous stage
    mov byte [ex_mem + pipeline_reg.valid], 0
    
.done:
.stalled:
    pop rdx
    pop rcx
    pop rbx
    pop rbp
    ret

; Write Back stage
stage_wb:
    push rbp
    mov rbp, rsp
    push rbx
    push rcx
    
    ; Check if stage has valid data
    cmp byte [mem_wb + pipeline_reg.valid], 0
    je .done
    
    ; Get destination register
    movzx ecx, byte [mem_wb + pipeline_reg.rd]
    test ecx, ecx
    jz .no_writeback        ; R0 is always zero
    
    ; Write result to register file
    mov rax, [mem_wb + pipeline_reg.mem_data]
    mov [vm_state + 24 + rcx * 8], rax  ; VM_GPRS offset
    
.no_writeback:
    ; Clear stage
    mov byte [mem_wb + pipeline_reg.valid], 0
    
.done:
    pop rcx
    pop rbx
    pop rbp
    ret

; Detect pipeline hazards
; Output: RAX = hazard type
detect_hazards:
    push rbx
    push rcx
    push rdx
    
    ; Check for data hazards (RAW)
    cmp byte [id_ex + pipeline_reg.valid], 0
    je .no_hazard
    
    ; Get source registers from ID stage
    movzx ebx, byte [id_ex + pipeline_reg.rs1]
    movzx ecx, byte [id_ex + pipeline_reg.rs2]
    
    ; Check against EX stage destination
    cmp byte [ex_mem + pipeline_reg.valid], 0
    je .check_mem
    
    movzx edx, byte [ex_mem + pipeline_reg.rd]
    test edx, edx
    jz .check_mem
    
    cmp ebx, edx
    je .data_hazard
    cmp ecx, edx
    je .data_hazard
    
.check_mem:
    ; Check against MEM stage destination
    cmp byte [mem_wb + pipeline_reg.valid], 0
    je .no_hazard
    
    movzx edx, byte [mem_wb + pipeline_reg.rd]
    test edx, edx
    jz .no_hazard
    
    cmp ebx, edx
    je .check_forwarding
    cmp ecx, edx
    je .check_forwarding
    jmp .no_hazard
    
.check_forwarding:
    ; Check if forwarding can resolve it
    cmp byte [forwarding_enabled], 0
    je .data_hazard
    
    ; Check if it's a load-use hazard
    movzx eax, byte [ex_mem + pipeline_reg.mem_op]
    cmp al, MEM_LOAD
    je .data_hazard
    
.no_hazard:
    xor eax, eax
    jmp .done
    
.data_hazard:
    mov al, HAZ_DATA
    
.done:
    pop rdx
    pop rcx
    pop rbx
    ret

; Get forwarded value for register
; Input: RDI = register number
; Output: RAX = value
get_forwarded_value:
    push rbx
    push rcx
    
    ; Check if forwarding is enabled
    cmp byte [forwarding_enabled], 0
    je .no_forward
    
    ; Check EX/MEM stage
    cmp byte [ex_mem + pipeline_reg.valid], 0
    je .check_mem_wb
    
    movzx ecx, byte [ex_mem + pipeline_reg.rd]
    cmp ecx, edi
    jne .check_mem_wb
    
    ; Forward from EX/MEM
    mov rax, [ex_mem + pipeline_reg.alu_out]
    jmp .done
    
.check_mem_wb:
    ; Check MEM/WB stage
    cmp byte [mem_wb + pipeline_reg.valid], 0
    je .no_forward
    
    movzx ecx, byte [mem_wb + pipeline_reg.rd]
    cmp ecx, edi
    jne .no_forward
    
    ; Forward from MEM/WB
    mov rax, [mem_wb + pipeline_reg.mem_data]
    jmp .done
    
.no_forward:
    ; Read from register file
    mov rax, [vm_state + 24 + rdi * 8]  ; VM_GPRS offset
    
.done:
    pop rcx
    pop rbx
    ret

; Insert pipeline bubble
insert_bubble:
    ; Invalidate ID/EX stage
    mov byte [id_ex + pipeline_reg.valid], 0
    
    ; Stall IF/ID stage
    ; (keeping its valid bit set prevents IF from overwriting)
    
    ret

; Flush pipeline
pipeline_flush:
    push rdi
    push rcx
    
    ; Clear all pipeline registers except WB
    lea rdi, [if_id]
    xor eax, eax
    mov ecx, pipeline_reg_size * 3 / 8
    rep stosq
    
    pop rcx
    pop rdi
    ret

; Stall pipeline for N cycles
; Input: RDI = number of cycles
pipeline_stall:
    mov [stall_cycles], rdi
    ret

; Get instruction type
; Input: AL = opcode
; Output: AL = memory operation type
get_instruction_type:
    cmp al, 0x0F            ; LD
    jl .not_mem
    cmp al, 0x12            ; LB
    jle .is_load
    cmp al, 0x13            ; ST
    jl .not_mem
    cmp al, 0x16            ; SB
    jle .is_store
    
.not_mem:
    mov al, MEM_NONE
    ret
    
.is_load:
    mov al, MEM_LOAD
    ret
    
.is_store:
    mov al, MEM_STORE
    ret

; Evaluate branch condition
; Input: RSI = rs1 value, RDI = rs2 value, opcode in id_ex
; Output: AL = 1 if branch taken, 0 otherwise
evaluate_branch:
    push rbx
    
    movzx ebx, byte [id_ex + pipeline_reg.opcode]
    
    cmp bl, 0x17            ; BEQ
    je .beq
    cmp bl, 0x18            ; BNE
    je .bne
    cmp bl, 0x19            ; BLT
    je .blt
    cmp bl, 0x1A            ; BGE
    je .bge
    cmp bl, 0x1B            ; BLTU
    je .bltu
    cmp bl, 0x1C            ; BGEU
    je .bgeu
    
    ; Not a branch
    xor al, al
    jmp .done
    
.beq:
    cmp rsi, rdi
    sete al
    jmp .done
    
.bne:
    cmp rsi, rdi
    setne al
    jmp .done
    
.blt:
    cmp rsi, rdi
    setl al
    jmp .done
    
.bge:
    cmp rsi, rdi
    setge al
    jmp .done
    
.bltu:
    cmp rsi, rdi
    setb al
    jmp .done
    
.bgeu:
    cmp rsi, rdi
    setae al
    
.done:
    pop rbx
    ret

; Branch prediction
; Input: RDI = PC
; Output: RAX = predicted target (0 if not taken)
branch_predict:
    push rbx
    push rcx
    push rdx
    
    inc qword [branch_predictions]
    
    ; Hash PC for predictor index
    mov rax, rdi
    xor rax, [global_history]
    and rax, (BRANCH_PRED_SIZE - 1)
    
    ; Check 2-bit counter
    movzx ecx, byte [branch_history + rax]
    cmp cl, 2               ; Weakly/strongly taken threshold
    jb .not_taken
    
    ; Check BTB for target
    mov rax, rdi
    and rax, (BTB_SIZE - 1)
    mov rbx, [btb_tags + rax * 8]
    cmp rbx, rdi
    jne .not_taken
    
    ; Return predicted target
    mov rax, [btb_targets + rax * 8]
    jmp .done
    
.not_taken:
    xor eax, eax
    
.done:
    pop rdx
    pop rcx
    pop rbx
    ret

; Update branch predictor
; Input: RDI = PC, RSI = actual taken (0/1), RDX = target
branch_update:
    push rbx
    push rcx
    
    ; Update global history
    shl byte [global_history], 1
    or [global_history], sil
    
    ; Hash PC for predictor index
    mov rax, rdi
    xor rax, [global_history]
    and rax, (BRANCH_PRED_SIZE - 1)
    
    ; Update 2-bit counter
    movzx ecx, byte [branch_history + rax]
    test sil, sil
    jz .not_taken
    
    ; Branch taken - increment counter (saturating)
    cmp cl, 3
    je .update_btb
    inc cl
    jmp .store_counter
    
.not_taken:
    ; Branch not taken - decrement counter (saturating)
    test cl, cl
    jz .done
    dec cl
    
.store_counter:
    mov [branch_history + rax], cl
    
.update_btb:
    ; Update BTB if taken
    test sil, sil
    jz .done
    
    mov rax, rdi
    and rax, (BTB_SIZE - 1)
    mov [btb_tags + rax * 8], rdi
    mov [btb_targets + rax * 8], rdx
    
.done:
    pop rcx
    pop rbx
    ret

; Check branch prediction
; Input: RDI = PC, RSI = actual taken
; Output: RAX = 1 if mispredicted, 0 if correct
check_branch_prediction:
    push rbx
    push rcx
    
    ; Get prediction
    push rsi
    call branch_predict
    pop rsi
    
    ; Check if prediction matches actual
    test rax, rax
    setz cl             ; CL = 1 if predicted not taken
    test sil, sil
    setz ch             ; CH = 1 if actual not taken
    xor cl, ch
    movzx eax, cl
    
    pop rcx
    pop rbx
    ret