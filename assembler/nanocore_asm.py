#!/usr/bin/env python3
"""
NanoCore Assembler - Convert assembly mnemonics to machine code

Usage:
    python nanocore_asm.py input.asm -o output.bin
"""

import sys
import argparse
import struct
from enum import IntEnum
from typing import Dict, List, Tuple, Optional, Union

class Opcode(IntEnum):
    """Instruction opcodes"""
    ADD = 0x00
    SUB = 0x01
    MUL = 0x02
    MULH = 0x03
    DIV = 0x04
    MOD = 0x05
    AND = 0x06
    OR = 0x07
    XOR = 0x08
    NOT = 0x09
    SHL = 0x0A
    SHR = 0x0B
    SAR = 0x0C
    ROL = 0x0D
    ROR = 0x0E
    LD = 0x0F
    LW = 0x10
    LH = 0x11
    LB = 0x12
    ST = 0x13
    SW = 0x14
    SH = 0x15
    SB = 0x16
    BEQ = 0x17
    BNE = 0x18
    BLT = 0x19
    BGE = 0x1A
    BLTU = 0x1B
    BGEU = 0x1C
    JMP = 0x1D
    CALL = 0x1E
    RET = 0x1F
    SYSCALL = 0x20
    HALT = 0x21
    NOP = 0x22
    CPUID = 0x23
    RDCYCLE = 0x24
    RDPERF = 0x25
    PREFETCH = 0x26
    CLFLUSH = 0x27
    FENCE = 0x28
    LR = 0x29
    SC = 0x2A
    AMOSWAP = 0x2B
    AMOADD = 0x2C
    AMOAND = 0x2D
    AMOOR = 0x2E
    AMOXOR = 0x2F
    VADD_F64 = 0x30
    VSUB_F64 = 0x31
    VMUL_F64 = 0x32
    VFMA_F64 = 0x33
    VLOAD = 0x34
    VSTORE = 0x35
    VBROADCAST = 0x36

class InstructionFormat(IntEnum):
    """Instruction encoding formats"""
    R_TYPE = 1  # Register: opcode rd, rs1, rs2
    I_TYPE = 2  # Immediate: opcode rd, rs1, imm16
    J_TYPE = 3  # Jump: opcode imm26
    V_TYPE = 4  # Vector: opcode vd, vs1, vs2

class Assembler:
    def __init__(self):
        self.symbols = {}  # Label -> address mapping
        self.relocations = []  # Instructions that need label resolution
        self.instructions = []  # Assembled instructions
        self.current_address = 0
        self.errors = []
        
        # Instruction format mapping
        self.formats = {
            # R-type instructions
            'ADD': (Opcode.ADD, InstructionFormat.R_TYPE),
            'SUB': (Opcode.SUB, InstructionFormat.R_TYPE),
            'MUL': (Opcode.MUL, InstructionFormat.R_TYPE),
            'MULH': (Opcode.MULH, InstructionFormat.R_TYPE),
            'DIV': (Opcode.DIV, InstructionFormat.R_TYPE),
            'MOD': (Opcode.MOD, InstructionFormat.R_TYPE),
            'AND': (Opcode.AND, InstructionFormat.R_TYPE),
            'OR': (Opcode.OR, InstructionFormat.R_TYPE),
            'XOR': (Opcode.XOR, InstructionFormat.R_TYPE),
            'NOT': (Opcode.NOT, InstructionFormat.R_TYPE),
            'SHL': (Opcode.SHL, InstructionFormat.R_TYPE),
            'SHR': (Opcode.SHR, InstructionFormat.R_TYPE),
            'SAR': (Opcode.SAR, InstructionFormat.R_TYPE),
            'ROL': (Opcode.ROL, InstructionFormat.R_TYPE),
            'ROR': (Opcode.ROR, InstructionFormat.R_TYPE),
            
            # I-type instructions
            'LD': (Opcode.LD, InstructionFormat.I_TYPE),
            'LW': (Opcode.LW, InstructionFormat.I_TYPE),
            'LH': (Opcode.LH, InstructionFormat.I_TYPE),
            'LB': (Opcode.LB, InstructionFormat.I_TYPE),
            'ST': (Opcode.ST, InstructionFormat.I_TYPE),
            'SW': (Opcode.SW, InstructionFormat.I_TYPE),
            'SH': (Opcode.SH, InstructionFormat.I_TYPE),
            'SB': (Opcode.SB, InstructionFormat.I_TYPE),
            'BEQ': (Opcode.BEQ, InstructionFormat.I_TYPE),
            'BNE': (Opcode.BNE, InstructionFormat.I_TYPE),
            'BLT': (Opcode.BLT, InstructionFormat.I_TYPE),
            'BGE': (Opcode.BGE, InstructionFormat.I_TYPE),
            'BLTU': (Opcode.BLTU, InstructionFormat.I_TYPE),
            'BGEU': (Opcode.BGEU, InstructionFormat.I_TYPE),
            'JMP': (Opcode.JMP, InstructionFormat.I_TYPE),
            
            # J-type instructions
            'CALL': (Opcode.CALL, InstructionFormat.J_TYPE),
            'RET': (Opcode.RET, InstructionFormat.J_TYPE),
            'SYSCALL': (Opcode.SYSCALL, InstructionFormat.J_TYPE),
            'HALT': (Opcode.HALT, InstructionFormat.J_TYPE),
            'NOP': (Opcode.NOP, InstructionFormat.J_TYPE),
            
            # V-type instructions
            'VADD.F64': (Opcode.VADD_F64, InstructionFormat.V_TYPE),
            'VSUB.F64': (Opcode.VSUB_F64, InstructionFormat.V_TYPE),
            'VMUL.F64': (Opcode.VMUL_F64, InstructionFormat.V_TYPE),
            'VFMA.F64': (Opcode.VFMA_F64, InstructionFormat.V_TYPE),
            'VLOAD': (Opcode.VLOAD, InstructionFormat.V_TYPE),
            'VSTORE': (Opcode.VSTORE, InstructionFormat.V_TYPE),
            'VBROADCAST': (Opcode.VBROADCAST, InstructionFormat.V_TYPE),
        }
        
        # Pseudo-instructions
        self.pseudo_ops = {
            'LOAD': self._expand_load,
            'MOVE': self._expand_move,
            'PUSH': self._expand_push,
            'POP': self._expand_pop,
            'ZERO': self._expand_zero,
        }
    
    def assemble_file(self, filename: str) -> bytes:
        """Assemble a file and return machine code"""
        with open(filename, 'r') as f:
            lines = f.readlines()
        
        return self.assemble(lines)
    
    def assemble(self, lines: List[str]) -> bytes:
        """Assemble source lines to machine code"""
        # First pass: collect labels and directives
        self._first_pass(lines)
        
        # Second pass: generate code
        self._second_pass(lines)
        
        # Resolve relocations
        self._resolve_relocations()
        
        # Check for errors
        if self.errors:
            for error in self.errors:
                print(f"Error: {error}", file=sys.stderr)
            raise AssemblyError("Assembly failed")
        
        # Convert to bytes
        return self._to_bytes()
    
    def _first_pass(self, lines: List[str]):
        """First pass: collect labels and calculate addresses"""
        address = 0
        
        for line_num, line in enumerate(lines, 1):
            # Remove comments and strip
            line = line.split(';')[0].strip()
            if not line:
                continue
            
            # Check for label
            if line.endswith(':'):
                label = line[:-1]
                if label in self.symbols:
                    self.errors.append(f"Line {line_num}: Duplicate label '{label}'")
                else:
                    self.symbols[label] = address
                continue
            
            # Check for directive
            if line.startswith('.'):
                address += self._process_directive(line, address)
                continue
            
            # Regular instruction
            address += 4  # All instructions are 32-bit
    
    def _second_pass(self, lines: List[str]):
        """Second pass: generate machine code"""
        self.current_address = 0
        
        for line_num, line in enumerate(lines, 1):
            # Remove comments and strip
            line = line.split(';')[0].strip()
            if not line or line.endswith(':'):
                continue
            
            # Process directive
            if line.startswith('.'):
                self._emit_directive(line)
                continue
            
            # Parse instruction
            parts = line.replace(',', ' ').split()
            if not parts:
                continue
            
            mnemonic = parts[0].upper()
            operands = parts[1:] if len(parts) > 1 else []
            
            try:
                # Check for pseudo-instruction
                if mnemonic in self.pseudo_ops:
                    self.pseudo_ops[mnemonic](operands, line_num)
                else:
                    self._assemble_instruction(mnemonic, operands, line_num)
            except Exception as e:
                self.errors.append(f"Line {line_num}: {str(e)}")
    
    def _assemble_instruction(self, mnemonic: str, operands: List[str], line_num: int):
        """Assemble a single instruction"""
        if mnemonic not in self.formats:
            raise ValueError(f"Unknown instruction: {mnemonic}")
        
        opcode, format_type = self.formats[mnemonic]
        
        if format_type == InstructionFormat.R_TYPE:
            self._encode_r_type(opcode, operands, line_num)
        elif format_type == InstructionFormat.I_TYPE:
            self._encode_i_type(opcode, operands, line_num)
        elif format_type == InstructionFormat.J_TYPE:
            self._encode_j_type(opcode, operands, line_num)
        elif format_type == InstructionFormat.V_TYPE:
            self._encode_v_type(opcode, operands, line_num)
    
    def _encode_r_type(self, opcode: int, operands: List[str], line_num: int):
        """Encode R-type instruction: opcode rd, rs1, rs2"""
        if len(operands) != 3:
            raise ValueError(f"R-type instruction expects 3 operands, got {len(operands)}")
        
        rd = self._parse_register(operands[0])
        rs1 = self._parse_register(operands[1])
        rs2 = self._parse_register(operands[2])
        
        # R-type: [31:26 opcode][25:21 rd][20:16 rs1][15:11 rs2][10:0 unused]
        instruction = (opcode << 26) | (rd << 21) | (rs1 << 16) | (rs2 << 11)
        
        self._emit_instruction(instruction)
    
    def _encode_i_type(self, opcode: int, operands: List[str], line_num: int):
        """Encode I-type instruction: opcode rd, rs1, imm or opcode rd, imm(rs1)"""
        # Handle load/store format: LD rd, offset(rs1)
        if opcode in [Opcode.LD, Opcode.LW, Opcode.LH, Opcode.LB]:
            if len(operands) != 2:
                raise ValueError(f"Load instruction expects 2 operands")
            
            rd = self._parse_register(operands[0])
            # Parse offset(base) format
            if '(' in operands[1]:
                offset_str, base_str = operands[1].split('(')
                offset = self._parse_immediate(offset_str, 16)
                rs1 = self._parse_register(base_str.rstrip(')'))
            else:
                # Direct address
                rs1 = 0
                offset = self._parse_immediate(operands[1], 16)
        
        elif opcode in [Opcode.ST, Opcode.SW, Opcode.SH, Opcode.SB]:
            if len(operands) != 2:
                raise ValueError(f"Store instruction expects 2 operands")
            
            rs2 = self._parse_register(operands[0])  # Value to store
            # Parse offset(base) format
            if '(' in operands[1]:
                offset_str, base_str = operands[1].split('(')
                offset = self._parse_immediate(offset_str, 16)
                rs1 = self._parse_register(base_str.rstrip(')'))
            else:
                rs1 = 0
                offset = self._parse_immediate(operands[1], 16)
            
            # For stores, rs2 goes in rd field
            rd = rs2
        
        elif opcode in [Opcode.BEQ, Opcode.BNE, Opcode.BLT, Opcode.BGE, Opcode.BLTU, Opcode.BGEU]:
            # Branch instructions: BEQ rs1, rs2, label
            if len(operands) != 3:
                raise ValueError(f"Branch instruction expects 3 operands")
            
            rs1 = self._parse_register(operands[0])
            rs2 = self._parse_register(operands[1])
            
            # Handle label or immediate offset
            if operands[2] in self.symbols or not operands[2].startswith(('0x', '-', '0', '1', '2', '3', '4', '5', '6', '7', '8', '9')):
                # This is a label reference - store it for later resolution
                self.instructions.append(operands[2])  # Store label name for resolution
                offset = 0  # Placeholder
            else:
                offset = self._parse_immediate(operands[2], 13)
            
            # For branches, rs1 goes in rd field, rs2 in rs1 field
            rd = rs1
            rs1 = rs2
            offset &= 0xFFFF  # 16-bit immediate
        
        else:
            # Regular I-type: opcode rd, rs1, imm
            if len(operands) != 3:
                raise ValueError(f"I-type instruction expects 3 operands")
            
            rd = self._parse_register(operands[0])
            rs1 = self._parse_register(operands[1])
            offset = self._parse_immediate(operands[2], 16)
        
        # I-type: [31:26 opcode][25:21 rd][20:16 rs1][15:0 imm16]
        instruction = (opcode << 26) | (rd << 21) | (rs1 << 16) | (offset & 0xFFFF)
        
        self._emit_instruction(instruction)
    
    def _encode_j_type(self, opcode: int, operands: List[str], line_num: int):
        """Encode J-type instruction: opcode imm26"""
        if opcode == Opcode.RET:
            # RET has no operands
            offset = 0
        elif opcode in [Opcode.HALT, Opcode.NOP]:
            # These have no operands
            offset = 0
        elif opcode == Opcode.SYSCALL:
            # SYSCALL can have optional immediate
            offset = self._parse_immediate(operands[0], 26) if operands else 0
        else:
            # CALL instruction with label or offset
            if len(operands) != 1:
                raise ValueError(f"J-type instruction expects 1 operand")
            
            if operands[0] in self.symbols:
                # Label - calculate relative offset
                target = self.symbols[operands[0]]
                offset = (target - self.current_address) >> 2
            else:
                offset = self._parse_immediate(operands[0], 26)
        
        # J-type: [31:26 opcode][25:0 imm26]
        instruction = (opcode << 26) | (offset & 0x3FFFFFF)
        
        self._emit_instruction(instruction)
    
    def _encode_v_type(self, opcode: int, operands: List[str], line_num: int):
        """Encode V-type instruction: opcode vd, vs1, vs2"""
        if len(operands) < 2:
            raise ValueError(f"V-type instruction expects at least 2 operands")
        
        vd = self._parse_vector_register(operands[0])
        vs1 = self._parse_vector_register(operands[1])
        vs2 = self._parse_vector_register(operands[2]) if len(operands) > 2 else 0
        
        # V-type: [31:26 opcode][25:21 vd][20:16 vs1][15:11 vs2][10:0 unused]
        instruction = (opcode << 26) | (vd << 21) | (vs1 << 16) | (vs2 << 11)
        
        self._emit_instruction(instruction)
    
    def _parse_register(self, reg_str: str) -> int:
        """Parse register name to number"""
        reg_str = reg_str.upper().strip()
        
        # Handle R0-R31
        if reg_str.startswith('R') and reg_str[1:].isdigit():
            reg_num = int(reg_str[1:])
            if 0 <= reg_num <= 31:
                return reg_num
        
        # Handle special names
        special_regs = {
            'ZERO': 0,
            'SP': 30,
            'LR': 31,
            'RA': 31,  # Return address
        }
        
        if reg_str in special_regs:
            return special_regs[reg_str]
        
        raise ValueError(f"Invalid register: {reg_str}")
    
    def _parse_vector_register(self, reg_str: str) -> int:
        """Parse vector register name to number"""
        reg_str = reg_str.upper().strip()
        
        # Handle V0-V15
        if reg_str.startswith('V') and reg_str[1:].isdigit():
            reg_num = int(reg_str[1:])
            if 0 <= reg_num <= 15:
                return reg_num
        
        raise ValueError(f"Invalid vector register: {reg_str}")
    
    def _parse_immediate(self, imm_str: str, bits: int) -> int:
        """Parse immediate value"""
        imm_str = imm_str.strip()
        
        # Handle hex
        if imm_str.startswith('0x') or imm_str.startswith('0X'):
            value = int(imm_str, 16)
        # Handle binary
        elif imm_str.startswith('0b') or imm_str.startswith('0B'):
            value = int(imm_str, 2)
        # Handle decimal
        else:
            value = int(imm_str)
        
        # Check range
        max_val = (1 << bits) - 1
        min_val = -(1 << (bits - 1))
        
        if value < 0:
            # Sign extend negative values
            value = value & max_val
        
        return value
    
    def _emit_instruction(self, instruction: int):
        """Emit a 32-bit instruction"""
        self.instructions.append(instruction)
        self.current_address += 4
    
    def _emit_directive(self, line: str):
        """Process and emit directive data"""
        parts = line.split(None, 1)
        directive = parts[0].lower()
        
        if directive == '.word':
            # Emit 32-bit word
            value = self._parse_immediate(parts[1], 32)
            self.instructions.append(value)
            self.current_address += 4
        
        elif directive == '.byte':
            # Emit bytes (pack into words)
            if len(parts) > 1:
                values = []
                for item in parts[1].split(','):
                    item = item.strip()
                    values.append(self._parse_immediate(item, 8))
                
                # Pack bytes into 32-bit words
                while len(values) % 4 != 0:
                    values.append(0)  # Pad with zeros
                
                for i in range(0, len(values), 4):
                    word = (values[i] | 
                           (values[i+1] << 8) | 
                           (values[i+2] << 16) | 
                           (values[i+3] << 24))
                    self.instructions.append(word)
                    self.current_address += 4
        
        elif directive == '.string':
            # Emit string data
            if len(parts) > 1:
                string_val = parts[1].strip('"')
                bytes_val = string_val.encode('ascii') + b'\0'  # Null terminate
                
                # Pack into 32-bit words
                for i in range(0, len(bytes_val), 4):
                    word = 0
                    for j in range(4):
                        if i + j < len(bytes_val):
                            word |= bytes_val[i + j] << (j * 8)
                    self.instructions.append(word)
                    self.current_address += 4
    
    def _process_directive(self, line: str, address: int) -> int:
        """Process directive and return size"""
        parts = line.split(None, 1)
        directive = parts[0].lower()
        
        if directive == '.word':
            return 4
        elif directive == '.byte':
            return 1
        elif directive == '.string':
            if len(parts) > 1:
                # Account for string length + null terminator
                string_val = parts[1].strip('"')
                return len(string_val) + 1
        
        return 0
    
    def _resolve_relocations(self):
        """Resolve label references"""
        # Second pass: resolve all label references in branch instructions
        new_instructions = []
        i = 0
        
        while i < len(self.instructions):
            instruction = self.instructions[i]
            
            if isinstance(instruction, int):
                # Check if next item is a label reference for branch
                if i + 1 < len(self.instructions) and isinstance(self.instructions[i + 1], str):
                    label = self.instructions[i + 1]
                    if label in self.labels:
                        # This is a branch with a label
                        opcode = (instruction >> 26) & 0x3F
                        
                        if 0x17 <= opcode <= 0x1C:  # Branch instructions
                            # Calculate relative offset
                            label_addr = self.labels[label]
                            pc = len(new_instructions) * 4  # Current address
                            offset = (label_addr - pc - 4) >> 1  # Branch offset in halfwords
                            
                            # Update instruction with offset
                            instruction = (instruction & 0xFFFF0000) | (offset & 0xFFFF)
                            new_instructions.append(instruction)
                            i += 2  # Skip label
                            continue
                
                new_instructions.append(instruction)
            else:
                # Standalone label reference (shouldn't happen in proper code)
                if instruction in self.labels:
                    new_instructions.append(self.labels[instruction])
                else:
                    raise ValueError(f"Undefined label: {instruction}")
            
            i += 1
        
        self.instructions = new_instructions
    
    def _to_bytes(self) -> bytes:
        """Convert instructions to byte array"""
        result = bytearray()
        
        for instruction in self.instructions:
            # Little-endian encoding
            result.extend(struct.pack('<I', instruction))
        
        return bytes(result)
    
    # Pseudo-instruction expansions
    def _expand_load(self, operands: List[str], line_num: int):
        """Expand LOAD pseudo-instruction"""
        if len(operands) != 2:
            raise ValueError("LOAD expects 2 operands")
        
        rd = operands[0]
        value = operands[1]
        
        # For now, use LD with zero base
        self._assemble_instruction('LD', [rd, f"{value}(R0)"], line_num)
    
    def _expand_move(self, operands: List[str], line_num: int):
        """Expand MOVE pseudo-instruction to ADD rd, rs, R0"""
        if len(operands) != 2:
            raise ValueError("MOVE expects 2 operands")
        
        rd = operands[0]
        rs = operands[1]
        
        self._assemble_instruction('ADD', [rd, rs, 'R0'], line_num)
    
    def _expand_push(self, operands: List[str], line_num: int):
        """Expand PUSH pseudo-instruction"""
        if len(operands) != 1:
            raise ValueError("PUSH expects 1 operand")
        
        reg = operands[0]
        
        # SUB SP, SP, 8
        self._assemble_instruction('SUB', ['SP', 'SP', 'R1'], line_num)  # Assumes R1=8
        # ST reg, 0(SP)
        self._assemble_instruction('ST', [reg, '0(SP)'], line_num)
    
    def _expand_pop(self, operands: List[str], line_num: int):
        """Expand POP pseudo-instruction"""
        if len(operands) != 1:
            raise ValueError("POP expects 1 operand")
        
        reg = operands[0]
        
        # LD reg, 0(SP)
        self._assemble_instruction('LD', [reg, '0(SP)'], line_num)
        # ADD SP, SP, 8
        self._assemble_instruction('ADD', ['SP', 'SP', 'R1'], line_num)  # Assumes R1=8
    
    def _expand_zero(self, operands: List[str], line_num: int):
        """Expand ZERO pseudo-instruction to XOR rd, rd, rd"""
        if len(operands) != 1:
            raise ValueError("ZERO expects 1 operand")
        
        rd = operands[0]
        self._assemble_instruction('XOR', [rd, rd, rd], line_num)

class AssemblyError(Exception):
    """Assembly error exception"""
    pass

def main():
    parser = argparse.ArgumentParser(description='NanoCore Assembler')
    parser.add_argument('input', help='Input assembly file')
    parser.add_argument('-o', '--output', help='Output binary file', 
                       default='a.out')
    parser.add_argument('-v', '--verbose', action='store_true',
                       help='Verbose output')
    
    args = parser.parse_args()
    
    # Create assembler
    asm = Assembler()
    
    try:
        # Assemble file
        code = asm.assemble_file(args.input)
        
        # Write output
        with open(args.output, 'wb') as f:
            f.write(code)
        
        if args.verbose:
            print(f"Assembled {len(code)} bytes")
            print(f"Output written to: {args.output}")
            
            # Print symbol table
            if asm.symbols:
                print("\nSymbol Table:")
                for label, addr in sorted(asm.symbols.items()):
                    print(f"  {label:20s} 0x{addr:08x}")
    
    except Exception as e:
        print(f"Assembly failed: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == '__main__':
    main()