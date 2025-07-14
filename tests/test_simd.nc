; SIMD instruction tests
; Tests vector operations

.data
    vec_a: .word 0x3FF00000, 0x00000000  ; 1.0
           .word 0x40000000, 0x00000000  ; 2.0
           .word 0x40080000, 0x00000000  ; 3.0
           .word 0x40100000, 0x00000000  ; 4.0
           
    vec_b: .word 0x40140000, 0x00000000  ; 5.0
           .word 0x40180000, 0x00000000  ; 6.0
           .word 0x401C0000, 0x00000000  ; 7.0
           .word 0x40200000, 0x00000000  ; 8.0
           
    vec_result: .word 0, 0, 0, 0, 0, 0, 0, 0

.text
main:
    ; Load vector registers
    la r1, vec_a
    vload v0, 0(r1)
    
    la r2, vec_b
    vload v1, 0(r2)
    
    ; Test VADD.F64
    vadd.f64 v2, v0, v1    ; v2 = [6.0, 8.0, 10.0, 12.0]
    
    ; Test VSUB.F64
    vsub.f64 v3, v1, v0    ; v3 = [4.0, 4.0, 4.0, 4.0]
    
    ; Test VMUL.F64
    vmul.f64 v4, v0, v1    ; v4 = [5.0, 12.0, 21.0, 32.0]
    
    ; Test VFMA.F64 (fused multiply-add)
    ; v5 = v0 * v1 + v2
    vfma.f64 v5, v0, v1, v2 ; v5 = [11.0, 20.0, 31.0, 44.0]
    
    ; Test VBROADCAST
    li r3, 0x40240000       ; 10.0 (upper 32 bits)
    shl r3, r3, r30         ; Shift to upper half
    vbroadcast v6, r3       ; v6 = [10.0, 10.0, 10.0, 10.0]
    
    ; Store results
    la r4, vec_result
    vstore v2, 0(r4)
    
    ; Exit
    li r0, 0
    halt