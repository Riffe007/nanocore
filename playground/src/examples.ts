export const examples = [
  {
    id: 'hello',
    name: 'Hello World',
    code: `// Hello World Example
// Load values and halt
// Format: Hex bytes for each instruction

3C 20 00 2A  // LD R1, 42
3C 40 00 3A  // LD R2, 58
00 61 40 00  // ADD R3, R1, R2 (R3 = 100)
84 00 00 00  // HALT
`
  },
  {
    id: 'fibonacci',
    name: 'Fibonacci',
    code: `// Fibonacci Sequence
// Calculate first 10 Fibonacci numbers

3C 20 00 00  // LD R1, 0     ; First number
3C 40 00 01  // LD R2, 1     ; Second number
3C 60 00 0A  // LD R3, 10    ; Counter

// loop:
00 81 40 00  // ADD R4, R1, R2  ; Calculate next
// Move operations would go here
04 63 00 01  // SUB R3, R3, 1   ; Decrement counter
// Branch back if not zero
84 00 00 00  // HALT
`
  },
  {
    id: 'arithmetic',
    name: 'Arithmetic Ops',
    code: `// Arithmetic Operations Demo
// Test various math instructions

3C 20 00 64  // LD R1, 100
3C 40 00 0A  // LD R2, 10

00 61 40 00  // ADD R3, R1, R2  ; R3 = 110
04 61 40 00  // SUB R3, R1, R2  ; R3 = 90
08 61 40 00  // MUL R3, R1, R2  ; R3 = 1000
10 61 40 00  // DIV R3, R1, R2  ; R3 = 10
14 61 40 00  // MOD R3, R1, R2  ; R3 = 0

84 00 00 00  // HALT
`
  },
  {
    id: 'bitwise',
    name: 'Bitwise Ops',
    code: `// Bitwise Operations Demo

3C 20 00 FF  // LD R1, 0xFF
3C 40 00 0F  // LD R2, 0x0F

18 61 40 00  // AND R3, R1, R2  ; R3 = 0x0F
1C 61 40 00  // OR  R3, R1, R2  ; R3 = 0xFF
20 61 40 00  // XOR R3, R1, R2  ; R3 = 0xF0
28 61 40 00  // SHL R3, R1, R2  ; R3 = R1 << R2
2C 61 40 00  // SHR R3, R1, R2  ; R3 = R1 >> R2

84 00 00 00  // HALT
`
  },
  {
    id: 'memory',
    name: 'Memory Access',
    code: `// Memory Operations Demo

3C 20 10 00  // LD R1, 0x1000   ; Base address
3C 40 00 42  // LD R2, 66       ; Value to store

4C 41 00 00  // ST R2, 0(R1)    ; Store at 0x1000
4C 41 00 08  // ST R2, 8(R1)    ; Store at 0x1008

3C 41 00 00  // LD R2, 0(R1)    ; Load from 0x1000
3C 61 00 08  // LD R3, 8(R1)    ; Load from 0x1008

84 00 00 00  // HALT
`
  },
  {
    id: 'advanced',
    name: 'Advanced Demo',
    code: `// Advanced NanoCore Demo
// Combines multiple concepts

// Initialize data
3C 20 00 05  // LD R1, 5        ; Loop counter
3C 40 00 00  // LD R2, 0        ; Sum accumulator
3C 60 00 01  // LD R3, 1        ; Increment value

// Main loop
00 42 60 00  // ADD R2, R2, R3  ; Add to sum
00 63 60 00  // ADD R3, R3, 1   ; Increment
04 21 60 00  // SUB R1, R1, 1   ; Decrement counter

// In a real implementation, we'd branch here
// For now, just demonstrate a few more iterations
00 42 60 00  // ADD R2, R2, R3
00 63 60 00  // ADD R3, R3, 1
04 21 60 00  // SUB R1, R1, 1

00 42 60 00  // ADD R2, R2, R3
00 63 60 00  // ADD R3, R3, 1
04 21 60 00  // SUB R1, R1, 1

// Result: R2 should contain 1+2+3+4+5 = 15
84 00 00 00  // HALT
`
  }
]