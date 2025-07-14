#!/usr/bin/env python3
"""
NanoCore Test Framework
Provides utilities for testing VM functionality
"""

import os
import sys
import subprocess
import struct
from typing import List, Dict, Tuple, Optional
from dataclasses import dataclass
import unittest

# Add parent directory to path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from assembler.nanocore_asm import NanoCoreAssembler

@dataclass
class TestResult:
    """Result of a single test execution"""
    name: str
    passed: bool
    cycles: int
    instructions: int
    registers: Dict[int, int]
    memory_changes: List[Tuple[int, int]]
    error_message: Optional[str] = None

class VMSimulator:
    """Simple VM simulator for testing"""
    
    def __init__(self, memory_size: int = 1024 * 1024):
        self.memory = bytearray(memory_size)
        self.registers = [0] * 32
        self.vregisters = [[0.0] * 4 for _ in range(16)]
        self.pc = 0
        self.flags = 0
        self.halted = False
        self.cycles = 0
        self.instructions = 0
        
    def load_program(self, program: bytes, start_address: int = 0):
        """Load program into memory"""
        self.memory[start_address:start_address + len(program)] = program
        self.pc = start_address
        
    def read_instruction(self) -> int:
        """Read 32-bit instruction from memory"""
        if self.pc + 4 > len(self.memory):
            raise ValueError(f"PC out of bounds: {self.pc}")
        
        inst = struct.unpack('<I', self.memory[self.pc:self.pc + 4])[0]
        return inst
        
    def execute_instruction(self, inst: int):
        """Execute a single instruction"""
        opcode = (inst >> 26) & 0x3F
        rd = (inst >> 21) & 0x1F
        rs1 = (inst >> 16) & 0x1F
        rs2 = (inst >> 11) & 0x1F
        imm = inst & 0xFFFF
        
        # Sign extend immediate
        if imm & 0x8000:
            imm |= 0xFFFF0000
            
        # Ensure R0 is always 0
        self.registers[0] = 0
        
        if opcode == 0x00:  # ADD
            if rd != 0:
                self.registers[rd] = (self.registers[rs1] + self.registers[rs2]) & 0xFFFFFFFF
        elif opcode == 0x01:  # SUB
            if rd != 0:
                self.registers[rd] = (self.registers[rs1] - self.registers[rs2]) & 0xFFFFFFFF
        elif opcode == 0x02:  # MUL
            if rd != 0:
                self.registers[rd] = (self.registers[rs1] * self.registers[rs2]) & 0xFFFFFFFF
        elif opcode == 0x04:  # DIV
            if rd != 0 and self.registers[rs2] != 0:
                self.registers[rd] = self.registers[rs1] // self.registers[rs2]
        elif opcode == 0x05:  # MOD
            if rd != 0 and self.registers[rs2] != 0:
                self.registers[rd] = self.registers[rs1] % self.registers[rs2]
        elif opcode == 0x06:  # AND
            if rd != 0:
                self.registers[rd] = self.registers[rs1] & self.registers[rs2]
        elif opcode == 0x07:  # OR
            if rd != 0:
                self.registers[rd] = self.registers[rs1] | self.registers[rs2]
        elif opcode == 0x08:  # XOR
            if rd != 0:
                self.registers[rd] = self.registers[rs1] ^ self.registers[rs2]
        elif opcode == 0x0A:  # SHL
            if rd != 0:
                self.registers[rd] = (self.registers[rs1] << (self.registers[rs2] & 31)) & 0xFFFFFFFF
        elif opcode == 0x0B:  # SHR
            if rd != 0:
                self.registers[rd] = self.registers[rs1] >> (self.registers[rs2] & 31)
        elif opcode == 0x17:  # BEQ
            if self.registers[rd] == self.registers[rs1]:
                self.pc += (imm << 1) - 4
        elif opcode == 0x18:  # BNE
            if self.registers[rd] != self.registers[rs1]:
                self.pc += (imm << 1) - 4
        elif opcode == 0x21:  # HALT
            self.halted = True
        elif opcode == 0x22:  # NOP
            pass
        # Add more instructions as needed
        
        self.instructions += 1
        self.cycles += 1
        
    def run(self, max_cycles: int = 10000) -> TestResult:
        """Run the VM until halt or max cycles"""
        start_registers = self.registers.copy()
        
        while not self.halted and self.cycles < max_cycles:
            try:
                inst = self.read_instruction()
                self.pc += 4
                self.execute_instruction(inst)
            except Exception as e:
                return TestResult(
                    name="VM Execution",
                    passed=False,
                    cycles=self.cycles,
                    instructions=self.instructions,
                    registers={i: v for i, v in enumerate(self.registers) if v != 0},
                    memory_changes=[],
                    error_message=str(e)
                )
                
        # Detect register changes
        reg_changes = {}
        for i in range(32):
            if self.registers[i] != start_registers[i]:
                reg_changes[i] = self.registers[i]
                
        return TestResult(
            name="VM Execution",
            passed=self.halted and self.registers[0] == 0,  # R0 = 0 means success
            cycles=self.cycles,
            instructions=self.instructions,
            registers=reg_changes,
            memory_changes=[]
        )

class NanoCoreTestCase(unittest.TestCase):
    """Base class for NanoCore tests"""
    
    def setUp(self):
        self.assembler = NanoCoreAssembler()
        self.vm = VMSimulator()
        
    def assemble_and_load(self, source_file: str):
        """Assemble a source file and load it into the VM"""
        program = self.assembler.assemble_file(source_file)
        self.vm.load_program(program)
        
    def run_test_program(self, source_file: str) -> TestResult:
        """Run a test program and return results"""
        self.assemble_and_load(source_file)
        return self.vm.run()
        
    def assertTestPassed(self, result: TestResult):
        """Assert that a test passed"""
        if not result.passed:
            msg = f"Test failed: {result.error_message or 'R0 != 0'}"
            msg += f"\nRegisters: {result.registers}"
            msg += f"\nCycles: {result.cycles}, Instructions: {result.instructions}"
            self.fail(msg)

class TestALU(NanoCoreTestCase):
    """Test ALU operations"""
    
    def test_arithmetic(self):
        """Test basic arithmetic operations"""
        # Create simple test program
        asm_code = """
        .text
        main:
            li r1, 10
            li r2, 20
            add r3, r1, r2    ; r3 = 30
            sub r4, r2, r1    ; r4 = 10
            li r0, 0          ; Success
            halt
        """
        
        with open('test_arithmetic.nc', 'w') as f:
            f.write(asm_code)
            
        result = self.run_test_program('test_arithmetic.nc')
        self.assertTestPassed(result)
        self.assertEqual(result.registers.get(3, 0), 30)
        self.assertEqual(result.registers.get(4, 0), 10)
        
        os.remove('test_arithmetic.nc')

def run_all_tests():
    """Run all test suites"""
    test_files = [
        'test_alu.nc',
        'test_memory.nc', 
        'test_branches.nc',
        'test_simd.nc'
    ]
    
    results = []
    
    print("NanoCore Test Suite")
    print("=" * 50)
    
    for test_file in test_files:
        if os.path.exists(test_file):
            print(f"\nRunning {test_file}...")
            
            try:
                assembler = NanoCoreAssembler()
                program = assembler.assemble_file(test_file)
                
                vm = VMSimulator()
                vm.load_program(program)
                result = vm.run()
                
                results.append((test_file, result))
                
                if result.passed:
                    print(f"  ✓ PASSED ({result.instructions} instructions, {result.cycles} cycles)")
                else:
                    print(f"  ✗ FAILED: {result.error_message or 'R0 != 0'}")
                    
            except Exception as e:
                print(f"  ✗ ERROR: {str(e)}")
                results.append((test_file, None))
    
    # Summary
    print("\n" + "=" * 50)
    passed = sum(1 for _, r in results if r and r.passed)
    total = len(results)
    print(f"Tests passed: {passed}/{total}")
    
    return passed == total

if __name__ == "__main__":
    # Run unit tests
    unittest.main(argv=[''], exit=False, verbosity=2)
    
    # Run integration tests
    print("\n" + "=" * 50)
    success = run_all_tests()
    sys.exit(0 if success else 1)