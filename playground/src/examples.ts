export const examples = {
  helloWorld: `; NanoCore Hello World Example
; Demonstrates basic instructions and halt

_start:
    ; Load some values
    LD   R1, 42         ; Load 42 into R1
    LD   R2, 58         ; Load 58 into R2
    
    ; Add them together
    ADD  R3, R1, R2     ; R3 = R1 + R2 = 100
    
    ; Store result in memory
    ST   R3, 0x1000(R0) ; Store at address 0x1000
    
    ; Done!
    HALT                ; Stop execution
`,

  fibonacci: `; Fibonacci Sequence Calculator
; Calculates first 10 Fibonacci numbers

_start:
    LD   R1, 10         ; Calculate 10 numbers
    LD   R2, 0          ; F(0) = 0
    LD   R3, 1          ; F(1) = 1
    LD   R4, 0          ; Counter
    LD   R10, 0x2000    ; Memory pointer
    
    ; Store first two numbers
    ST   R2, 0(R10)     ; Store F(0)
    ST   R3, 8(R10)     ; Store F(1)
    ADD  R10, R10, 16   ; Advance pointer
    LD   R4, 2          ; Counter = 2
    
fib_loop:
    ; Calculate next Fibonacci number
    ADD  R5, R2, R3     ; R5 = R2 + R3
    
    ; Store result
    ST   R5, 0(R10)     ; Store in memory
    ADD  R10, R10, 8    ; Advance pointer
    
    ; Update for next iteration
    ADD  R2, R3, R0     ; R2 = R3
    ADD  R3, R5, R0     ; R3 = R5
    
    ; Increment counter
    LD   R6, 1
    ADD  R4, R4, R6
    
    ; Check if done (simplified)
    ; Real implementation would use compare & branch
    
    HALT
`,

  simd: `; SIMD Vector Operations Demo
; Shows parallel processing capabilities

_start:
    ; Load base addresses
    LD   R1, 0x3000     ; Vector A address
    LD   R2, 0x3020     ; Vector B address
    LD   R3, 0x3040     ; Result address
    
    ; Load vectors from memory
    VLOAD V0, 0(R1)     ; Load vector A
    VLOAD V1, 0(R2)     ; Load vector B
    
    ; Perform vector operations
    VADD.F64 V2, V0, V1 ; Vector addition
    VMUL.F64 V3, V0, V1 ; Vector multiplication
    
    ; Store results
    VSTORE V2, 0(R3)    ; Store sum
    VSTORE V3, 32(R3)   ; Store product
    
    ; Broadcast scalar to vector
    LD   R4, 2
    VBROADCAST V4, R4   ; V4 = [2, 2, 2, 2]
    
    ; Scale vector
    VMUL.F64 V5, V2, V4 ; V5 = V2 * 2
    
    HALT
`,

  loops: `; Loops and Branching Demo
; Shows control flow instructions

_start:
    ; Initialize
    LD   R1, 0          ; Counter
    LD   R2, 5          ; Limit
    LD   R3, 0          ; Sum
    
loop_start:
    ; Add counter to sum
    ADD  R3, R3, R1     ; sum += counter
    
    ; Increment counter
    LD   R4, 1
    ADD  R1, R1, R4     ; counter++
    
    ; Compare and branch
    ; BLT  R1, R2, loop_start
    ; For demo, using simplified loop
    
    ; Nested loop example
    LD   R5, 0          ; Inner counter
    LD   R6, 3          ; Inner limit
    
inner_loop:
    ; Do something in inner loop
    ADD  R7, R5, R1     ; Some calculation
    
    ; Increment inner counter
    ADD  R5, R5, R4
    
    ; Would branch here in real implementation
    
done:
    ; Store final result
    ST   R3, 0x4000(R0)
    
    HALT
`
};