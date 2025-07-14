# NanoCore ISA Specification v1.0

## Architecture Overview

NanoCore implements a 64-bit RISC-inspired architecture with advanced performance features:

- **Word Size**: 64-bit
- **Endianness**: Little-endian (performance on x86/ARM)
- **Address Space**: 48-bit virtual, 40-bit physical
- **Pipeline**: 5-stage (Fetch, Decode, Execute, Memory, Writeback)
- **Out-of-Order**: Scoreboarding for hazard detection

## Registers

### General Purpose Registers (64-bit)
- **R0-R31**: General purpose
- **R0**: Hardwired to zero (RISC tradition)
- **R31**: Link register for fast calls

### Special Purpose Registers
- **PC**: Program Counter (64-bit)
- **SP**: Stack Pointer (alias for R30)
- **FLAGS**: Status flags (64-bit)
  - Bit 0: Zero (Z)
  - Bit 1: Carry (C)
  - Bit 2: Overflow (V)
  - Bit 3: Negative (N)
  - Bit 4: Interrupt Enable (IE)
  - Bit 5: User Mode (UM)
  - Bit 6-7: Cache hints
  - Bit 8-15: Performance counters enable
- **PERF[0-7]**: Performance counters
- **VBASE**: Interrupt vector base
- **CACHE_CTRL**: Cache control register

### SIMD Registers (256-bit)
- **V0-V15**: Vector registers for SIMD operations
- **VMASK**: Vector mask register

## Memory Model

### Address Space Layout
```
0x0000_0000_0000_0000 - 0x0000_0000_0000_FFFF : Interrupt vectors
0x0000_0000_0001_0000 - 0x0000_0000_7FFF_FFFF : User code
0x0000_0000_8000_0000 - 0x0000_0000_FFFF_FFFF : User heap
0x0000_0001_0000_0000 - 0x0000_7FFF_FFFF_FFFF : User stack (grows down)
0x0000_8000_0000_0000 - 0x0000_8FFF_FFFF_FFFF : MMIO space
0x0000_9000_0000_0000 - 0x0000_FFFF_FFFF_FFFF : Kernel space
```

### Cache Architecture
- L1I: 32KB, 4-way set associative
- L1D: 32KB, 8-way set associative
- Unified L2: 256KB, 16-way set associative
- Cache line: 64 bytes

## Instruction Format

### Encoding Types
All instructions are 32-bit for fetch efficiency:

```
Type R (Register): [31:26 opcode][25:21 rd][20:16 rs1][15:11 rs2][10:6 shamt][5:0 funct]
Type I (Immediate): [31:26 opcode][25:21 rd][20:16 rs1][15:0 imm16]
Type J (Jump): [31:26 opcode][25:0 imm26]
Type V (Vector): [31:26 opcode][25:21 vd][20:16 vs1][15:11 vs2][10:8 vmask][7:0 vfunct]
```

## Instruction Set

### Arithmetic Operations
```
ADD   rd, rs1, rs2      # rd = rs1 + rs2
SUB   rd, rs1, rs2      # rd = rs1 - rs2
MUL   rd, rs1, rs2      # rd = rs1 * rs2 (low 64 bits)
MULH  rd, rs1, rs2      # rd = rs1 * rs2 (high 64 bits)
DIV   rd, rs1, rs2      # rd = rs1 / rs2
MOD   rd, rs1, rs2      # rd = rs1 % rs2
```

### Logical Operations
```
AND   rd, rs1, rs2      # rd = rs1 & rs2
OR    rd, rs1, rs2      # rd = rs1 | rs2
XOR   rd, rs1, rs2      # rd = rs1 ^ rs2
NOT   rd, rs1           # rd = ~rs1
SHL   rd, rs1, rs2      # rd = rs1 << rs2
SHR   rd, rs1, rs2      # rd = rs1 >> rs2 (logical)
SAR   rd, rs1, rs2      # rd = rs1 >> rs2 (arithmetic)
ROL   rd, rs1, rs2      # rd = rotate_left(rs1, rs2)
ROR   rd, rs1, rs2      # rd = rotate_right(rs1, rs2)
```

### Memory Operations (with cache hints)
```
LD    rd, offset(rs1)       # Load 64-bit
LW    rd, offset(rs1)       # Load 32-bit (sign extend)
LH    rd, offset(rs1)       # Load 16-bit (sign extend)
LB    rd, offset(rs1)       # Load 8-bit (sign extend)
ST    rs2, offset(rs1)      # Store 64-bit
SW    rs2, offset(rs1)      # Store 32-bit
SH    rs2, offset(rs1)      # Store 16-bit
SB    rs2, offset(rs1)      # Store 8-bit

# Cache control
PREFETCH offset(rs1), hint  # Prefetch cache line
CLFLUSH  offset(rs1)        # Flush cache line
FENCE    mode               # Memory fence
```

### Control Flow
```
BEQ   rs1, rs2, offset  # Branch if equal
BNE   rs1, rs2, offset  # Branch if not equal
BLT   rs1, rs2, offset  # Branch if less than
BGE   rs1, rs2, offset  # Branch if greater or equal
BLTU  rs1, rs2, offset  # Branch if less than (unsigned)
BGEU  rs1, rs2, offset  # Branch if greater or equal (unsigned)

JMP   rd, offset(rs1)   # Jump and link
CALL  offset            # Call (PC+4 -> R31, PC = PC + offset)
RET                     # Return (PC = R31)
```

### SIMD Operations (256-bit vectors)
```
VADD.F64  vd, vs1, vs2    # Vector add (4x double)
VSUB.F64  vd, vs1, vs2    # Vector subtract
VMUL.F64  vd, vs1, vs2    # Vector multiply
VFMA.F64  vd, vs1, vs2    # Fused multiply-add
VLOAD     vd, offset(rs1) # Load 256-bit vector
VSTORE    vs2, offset(rs1)# Store 256-bit vector
VBROADCAST vd, rs1        # Broadcast scalar to vector
```

### System Instructions
```
SYSCALL  imm            # System call
HALT                    # Halt processor
NOP                     # No operation
CPUID    rd             # Get CPU info
RDCYCLE  rd             # Read cycle counter
RDPERF   rd, imm        # Read performance counter
```

### Atomic Operations
```
LR       rd, (rs1)      # Load reserved
SC       rd, rs2, (rs1) # Store conditional
AMOSWAP  rd, rs2, (rs1) # Atomic swap
AMOADD   rd, rs2, (rs1) # Atomic add
AMOAND   rd, rs2, (rs1) # Atomic AND
AMOOR    rd, rs2, (rs1) # Atomic OR
AMOXOR   rd, rs2, (rs1) # Atomic XOR
```

## Interrupt Architecture

### Interrupt Vector Table
Located at 0x0000_0000_0000_0000:
- 0x00: Reset
- 0x08: Invalid instruction
- 0x10: Memory fault
- 0x18: Timer interrupt
- 0x20: External interrupt 0
- 0x28: External interrupt 1
- 0x30-0xFF: Device interrupts

### Interrupt Handling
1. Push PC, FLAGS to shadow registers
2. Disable interrupts (FLAGS.IE = 0)
3. Jump to VBASE + (vector * 8)
4. IRET instruction restores PC, FLAGS

## Performance Features

### Pipeline Optimizations
- Branch prediction: 2-bit saturating counter
- Return address stack: 16 entries
- Loop buffer: 64 instructions
- Instruction fusion for common patterns

### Prefetch Hints
```
hint = 0: No prefetch
hint = 1: Prefetch for read
hint = 2: Prefetch for write
hint = 3: Prefetch for instruction
```

### Performance Counters
- PERF0: Instruction count
- PERF1: Cycle count
- PERF2: Cache misses (L1)
- PERF3: Cache misses (L2)
- PERF4: Branch mispredictions
- PERF5: Pipeline stalls
- PERF6: Memory operations
- PERF7: SIMD operations

## MMIO Device Map

```
0x0000_8000_0000_0000 : Console I/O
0x0000_8000_0001_0000 : Timer control
0x0000_8000_0002_0000 : Interrupt controller
0x0000_8000_0003_0000 : DMA controller
0x0000_8000_0004_0000 : Network interface
0x0000_8000_0005_0000 : Block storage
0x0000_8000_0006_0000 : Graphics controller
0x0000_8000_0007_0000 : Audio controller
```

## Optimization Guidelines

1. **Alignment**: All instructions must be 4-byte aligned
2. **Load/Store**: Align data to natural boundaries for best performance
3. **Branches**: Place likely targets within ±32KB for short encoding
4. **SIMD**: Use VFMA for maximum throughput
5. **Atomics**: Use LR/SC for lock-free algorithms

## Future Extensions

Reserved opcode space for:
- AVX-512 style operations
- Tensor operations
- Cryptographic instructions
- Transactional memory