/**
 * NanoCore WASM Interface
 * Provides a TypeScript wrapper around the WASM VM
 */

export class AssemblyError extends Error {
  constructor(message: string, public line?: number) {
    super(message);
    this.name = 'AssemblyError';
  }
}

interface VMState {
  pc: number;
  sp: number;
  flags: number;
  registers: number[];
  vectorRegisters: number[][];
  performance: {
    instructions: number;
    cycles: number;
    cacheHits: number;
    cacheMisses: number;
  };
}

interface StepResult {
  halted: boolean;
  error?: string;
  output?: string;
}

/**
 * Simple VM implementation in TypeScript for the playground
 * In production, this would be replaced with actual WASM
 */
export class NanoCoreVM {
  private memory: Uint8Array;
  private registers: BigUint64Array;
  private vectorRegisters: Float64Array[];
  private pc: number = 0;
  private sp: number = 0;
  private flags: number = 0;
  private halted: boolean = false;
  private instructionCount: number = 0;
  private cycleCount: number = 0;
  private cacheHits: number = 0;
  private cacheMisses: number = 0;

  constructor(memorySize: number = 1024 * 1024) {
    this.memory = new Uint8Array(memorySize);
    this.registers = new BigUint64Array(32);
    this.vectorRegisters = Array(16).fill(null).map(() => new Float64Array(4));
    this.sp = memorySize - 8;
  }

  static async init(): Promise<NanoCoreVM> {
    // In production, this would load the WASM module
    return new NanoCoreVM();
  }

  reset(): void {
    this.memory.fill(0);
    this.registers.fill(0n);
    this.vectorRegisters.forEach(v => v.fill(0));
    this.pc = 0x10000;
    this.sp = this.memory.length - 8;
    this.flags = 0;
    this.halted = false;
    this.instructionCount = 0;
    this.cycleCount = 0;
    this.cacheHits = 0;
    this.cacheMisses = 0;
  }

  assemble(code: string): Uint8Array {
    // Simple assembler implementation
    const lines = code.split('\n');
    const bytecode: number[] = [];
    const labels: Map<string, number> = new Map();
    
    // First pass: collect labels
    let address = 0;
    for (const line of lines) {
      const trimmed = line.trim();
      if (!trimmed || trimmed.startsWith(';')) continue;
      
      if (trimmed.endsWith(':')) {
        labels.set(trimmed.slice(0, -1), address);
      } else {
        address += 4; // Each instruction is 4 bytes
      }
    }
    
    // Second pass: generate code
    address = 0;
    for (let lineNum = 0; lineNum < lines.length; lineNum++) {
      const line = lines[lineNum].trim();
      if (!line || line.startsWith(';') || line.endsWith(':')) continue;
      
      // Parse instruction
      const parts = line.split(/[\s,]+/).filter(p => p);
      if (parts.length === 0) continue;
      
      const mnemonic = parts[0].toUpperCase();
      const instruction = this.encodeInstruction(mnemonic, parts.slice(1), labels, lineNum + 1);
      
      // Add to bytecode
      bytecode.push(instruction & 0xFF);
      bytecode.push((instruction >> 8) & 0xFF);
      bytecode.push((instruction >> 16) & 0xFF);
      bytecode.push((instruction >> 24) & 0xFF);
      
      address += 4;
    }
    
    return new Uint8Array(bytecode);
  }

  private encodeInstruction(mnemonic: string, operands: string[], labels: Map<string, number>, line: number): number {
    // Opcode mapping
    const opcodes: Record<string, number> = {
      'ADD': 0x00,
      'SUB': 0x01,
      'MUL': 0x02,
      'DIV': 0x04,
      'LD': 0x0F,
      'ST': 0x13,
      'BEQ': 0x17,
      'BNE': 0x18,
      'BLT': 0x19,
      'JMP': 0x1D,
      'CALL': 0x1E,
      'RET': 0x1F,
      'HALT': 0x21,
      'NOP': 0x22,
      'VADD.F64': 0x30,
      'VMUL.F64': 0x32,
      'VLOAD': 0x34,
      'VSTORE': 0x35,
      'VBROADCAST': 0x36,
    };
    
    const opcode = opcodes[mnemonic];
    if (opcode === undefined) {
      throw new AssemblyError(`Unknown instruction: ${mnemonic}`, line);
    }
    
    // Parse operands based on instruction type
    let rd = 0, rs1 = 0, rs2 = 0, imm = 0;
    
    switch (mnemonic) {
      case 'ADD':
      case 'SUB':
      case 'MUL':
      case 'DIV':
        // R-type: rd, rs1, rs2
        if (operands.length !== 3) {
          throw new AssemblyError(`${mnemonic} expects 3 operands`, line);
        }
        rd = this.parseRegister(operands[0]);
        rs1 = this.parseRegister(operands[1]);
        rs2 = this.parseRegister(operands[2]);
        break;
        
      case 'LD':
        // I-type: rd, imm or rd, imm(rs1)
        if (operands.length !== 2) {
          throw new AssemblyError(`LD expects 2 operands`, line);
        }
        rd = this.parseRegister(operands[0]);
        if (operands[1].includes('(')) {
          // Parse offset(base) format
          const match = operands[1].match(/(\d+)\(([^)]+)\)/);
          if (match) {
            imm = parseInt(match[1]);
            rs1 = this.parseRegister(match[2]);
          }
        } else {
          imm = parseInt(operands[1]);
        }
        break;
        
      case 'HALT':
      case 'NOP':
      case 'RET':
        // No operands
        break;
        
      case 'VADD.F64':
      case 'VMUL.F64':
        // V-type: vd, vs1, vs2
        if (operands.length !== 3) {
          throw new AssemblyError(`${mnemonic} expects 3 operands`, line);
        }
        rd = this.parseVectorRegister(operands[0]);
        rs1 = this.parseVectorRegister(operands[1]);
        rs2 = this.parseVectorRegister(operands[2]);
        break;
    }
    
    // Encode instruction
    return (opcode << 26) | (rd << 21) | (rs1 << 16) | (rs2 << 11) | (imm & 0xFFFF);
  }

  private parseRegister(reg: string): number {
    const upper = reg.toUpperCase();
    if (upper === 'R0' || upper === 'ZERO') return 0;
    if (upper === 'SP') return 30;
    if (upper === 'LR' || upper === 'RA') return 31;
    
    const match = upper.match(/R(\d+)/);
    if (match) {
      const num = parseInt(match[1]);
      if (num >= 0 && num < 32) return num;
    }
    
    throw new Error(`Invalid register: ${reg}`);
  }

  private parseVectorRegister(reg: string): number {
    const match = reg.toUpperCase().match(/V(\d+)/);
    if (match) {
      const num = parseInt(match[1]);
      if (num >= 0 && num < 16) return num;
    }
    throw new Error(`Invalid vector register: ${reg}`);
  }

  loadProgram(bytecode: Uint8Array, address: number = 0x10000): void {
    this.memory.set(bytecode, address);
    this.pc = address;
  }

  step(): StepResult {
    if (this.halted) {
      return { halted: true };
    }
    
    // Fetch instruction
    if (this.pc + 4 > this.memory.length) {
      return { halted: true, error: 'PC out of bounds' };
    }
    
    const inst = this.memory[this.pc] |
                (this.memory[this.pc + 1] << 8) |
                (this.memory[this.pc + 2] << 16) |
                (this.memory[this.pc + 3] << 24);
    
    // Decode
    const opcode = (inst >> 26) & 0x3F;
    const rd = (inst >> 21) & 0x1F;
    const rs1 = (inst >> 16) & 0x1F;
    const rs2 = (inst >> 11) & 0x1F;
    const imm = inst & 0xFFFF;
    
    // Execute
    let output: string | undefined;
    
    switch (opcode) {
      case 0x00: // ADD
        if (rd !== 0) {
          this.registers[rd] = this.registers[rs1] + this.registers[rs2];
        }
        break;
        
      case 0x01: // SUB
        if (rd !== 0) {
          this.registers[rd] = this.registers[rs1] - this.registers[rs2];
        }
        break;
        
      case 0x0F: // LD
        if (rd !== 0) {
          this.registers[rd] = BigInt(imm);
        }
        break;
        
      case 0x21: // HALT
        this.halted = true;
        this.flags |= 0x80;
        return { halted: true };
        
      case 0x22: // NOP
        break;
        
      default:
        return { halted: true, error: `Unknown opcode: 0x${opcode.toString(16)}` };
    }
    
    // Update counters
    this.pc += 4;
    this.instructionCount++;
    this.cycleCount += 1; // Simplified - real CPU would vary
    
    // Simulate cache (random for demo)
    if (Math.random() > 0.1) {
      this.cacheHits++;
    } else {
      this.cacheMisses++;
      this.cycleCount += 10; // Cache miss penalty
    }
    
    return { halted: false, output };
  }

  getState(): VMState {
    return {
      pc: this.pc,
      sp: this.sp,
      flags: this.flags,
      registers: Array.from(this.registers).map(r => Number(r)),
      vectorRegisters: this.vectorRegisters.map(v => Array.from(v)),
      performance: {
        instructions: this.instructionCount,
        cycles: this.cycleCount,
        cacheHits: this.cacheHits,
        cacheMisses: this.cacheMisses,
      },
    };
  }

  readMemory(address: number, length: number): Uint8Array {
    return this.memory.slice(address, address + length);
  }

  writeMemory(address: number, data: Uint8Array): void {
    this.memory.set(data, address);
  }
}