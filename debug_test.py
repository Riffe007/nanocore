#!/usr/bin/env python3
"""
Debug test for NanoCore VM instruction decoding
"""

import struct

def decode_instruction(instruction: int):
    """Decode instruction into opcode and operands"""
    # Let me analyze the actual bit layout
    opcode = instruction & 0xFF
    rd = (instruction >> 8) & 0x1F
    rs1 = (instruction >> 13) & 0x1F
    rs2 = (instruction >> 18) & 0x1F
    immediate = (instruction >> 23) & 0x1FF
    
    # For LDI instructions, the immediate is in the last byte
    if opcode == 0x0D:  # LDI
        # LDI format: [opcode:8][rd:5][rs1:5][rs2:5][immediate:9]
        # But the immediate is actually in the last byte (bits 24-31)
        immediate = (instruction >> 24) & 0xFF
        rd = (instruction >> 8) & 0x1F
        rs1 = 0
        rs2 = 0
    elif opcode == 0x01:  # ADD
        # ADD format: [opcode:8][rd:5][rs1:5][rs2:5][immediate:9]
        # But the operands are in different positions
        rd = (instruction >> 8) & 0x1F
        rs1 = (instruction >> 16) & 0x1F  # Try bits 16-20
        rs2 = (instruction >> 24) & 0x1F  # Try bits 24-28
        immediate = 0  # Not used for ADD
    
    # Sign extend immediate if needed
    if immediate & 0x100:  # Check sign bit
        immediate |= 0xFFFFFFFFFFFFFE00  # Sign extend to 64 bits
        
    return {
        'opcode': opcode,
        'rd': rd,
        'rs1': rs1,
        'rs2': rs2,
        'immediate': immediate
    }

def analyze_bits(instruction: int, name: str):
    """Analyze the bit layout of an instruction"""
    print(f"\nAnalyzing {name}: 0x{instruction:08x}")
    print(f"Binary: {instruction:032b}")
    print(f"Bytes: {instruction & 0xFF:02x} {(instruction >> 8) & 0xFF:02x} {(instruction >> 16) & 0xFF:02x} {(instruction >> 24) & 0xFF:02x}")
    
    # Try different interpretations
    print("Possible interpretations:")
    print(f"  Opcode (bits 0-7): 0x{instruction & 0xFF:02x}")
    print(f"  RD (bits 8-12): {(instruction >> 8) & 0x1F}")
    print(f"  RS1 (bits 13-17): {(instruction >> 13) & 0x1F}")
    print(f"  RS2 (bits 18-22): {(instruction >> 18) & 0x1F}")
    print(f"  Immediate (bits 23-31): {(instruction >> 23) & 0x1FF}")
    
    # For LDI, try different immediate positions
    if (instruction & 0xFF) == 0x0D:
        print(f"  LDI Immediate (bits 24-31): {(instruction >> 24) & 0xFF}")
        print(f"  LDI RD (bits 8-12): {(instruction >> 8) & 0x1F}")
    elif (instruction & 0xFF) == 0x01:  # ADD
        print(f"  ADD RD (bits 8-12): {(instruction >> 8) & 0x1F}")
        print(f"  ADD RS1 (bits 16-20): {(instruction >> 16) & 0x1F}")
        print(f"  ADD RS2 (bits 24-28): {(instruction >> 24) & 0x1F}")

# Test the first instruction from our test program
test_program = bytes([
    0x0D, 0x01, 0x00, 0x0A,  # LDI R1, 10
    0x0D, 0x02, 0x00, 0x05,  # LDI R2, 5
    0x01, 0x03, 0x01, 0x02,  # ADD R3, R1, R2
])

print("Testing instruction decoding:")
for i in range(0, len(test_program), 4):
    instruction_bytes = test_program[i:i+4]
    instruction = struct.unpack('<I', instruction_bytes)[0]
    
    analyze_bits(instruction, f"Instruction {i//4}")
    
    decoded = decode_instruction(instruction)
    
    print(f"Decoded:")
    print(f"  Opcode: 0x{decoded['opcode']:02x}")
    print(f"  RD: {decoded['rd']}")
    print(f"  RS1: {decoded['rs1']}")
    print(f"  RS2: {decoded['rs2']}")
    print(f"  Immediate: {decoded['immediate']}")
    print()

# Let's also test what we expect:
print("Expected values:")
print("Instruction 0 (LDI R1, 10):")
print("  Opcode: 0x0D")
print("  RD: 1")
print("  RS1: 0")
print("  RS2: 0")
print("  Immediate: 10")
print()

print("Instruction 1 (LDI R2, 5):")
print("  Opcode: 0x0D")
print("  RD: 2")
print("  RS1: 0")
print("  RS2: 0")
print("  Immediate: 5")
print()

print("Instruction 2 (ADD R3, R1, R2):")
print("  Opcode: 0x01")
print("  RD: 3")
print("  RS1: 1")
print("  RS2: 2")
print("  Immediate: 0")
print() 