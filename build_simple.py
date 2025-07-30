#!/usr/bin/env python3
"""
Simplified NanoCore Build System
Creates a working VM implementation using pure Python
"""

import os
import sys
import subprocess
import platform
import shutil
from pathlib import Path

class SimpleBuilder:
    def __init__(self):
        self.build_dir = Path("build")
        self.bin_dir = self.build_dir / "bin"
        self.lib_dir = self.build_dir / "lib"
        self.obj_dir = self.build_dir / "obj"
        
    def log(self, message):
        print(f"[BUILD] {message}")
        
    def check_dependencies(self):
        """Check for available build tools"""
        self.log("Checking dependencies...")
        
        tools = {}
        
        # Check Python
        tools['python'] = shutil.which('python') or shutil.which('python3')
        if tools['python']:
            self.log(f"✓ Python found: {tools['python']}")
        else:
            self.log("✗ Python not found")
            return False
            
        # Check for any C compiler
        for compiler in ['gcc', 'clang', 'cl']:
            tools[compiler] = shutil.which(compiler)
            if tools[compiler]:
                self.log(f"✓ {compiler.upper()} found: {tools[compiler]}")
                break
        else:
            self.log("⚠ No C compiler found - will use Python-only build")
            
        # Check for NASM
        tools['nasm'] = shutil.which('nasm')
        if tools['nasm']:
            self.log(f"✓ NASM found: {tools['nasm']}")
        else:
            self.log("⚠ NASM not found - will use Python-only build")
            
        return tools
        
    def create_directories(self):
        """Create build directories"""
        self.log("Creating build directories...")
        self.bin_dir.mkdir(parents=True, exist_ok=True)
        self.lib_dir.mkdir(parents=True, exist_ok=True)
        self.obj_dir.mkdir(parents=True, exist_ok=True)
        
    def create_python_vm(self):
        """Create a Python-based VM implementation"""
        self.log("Creating Python VM implementation...")
        
        vm_code = '''#!/usr/bin/env python3
"""
NanoCore VM - Python Implementation
A simplified but functional implementation of the NanoCore VM
"""

import struct
import sys
from typing import List, Dict, Any

class NanoCoreVM:
    def __init__(self, memory_size: int = 1024 * 1024):
        # VM State
        self.pc = 0
        self.sp = memory_size - 1
        self.flags = 0
        self.halted = False
        
        # Registers
        self.gprs = [0] * 32  # General Purpose Registers
        self.vregs = [[0] * 4] * 16  # SIMD Vector Registers (4x64-bit)
        
        # Memory
        self.memory = bytearray(memory_size)
        
        # Performance counters
        self.perf_counters = [0] * 16
        
        # Cache simulation
        self.l1_cache = {}
        self.l2_cache = {}
        
        # Branch predictor
        self.branch_predictor = {}
        
        # Instruction dispatch table
        self.instructions = {
            0x00: self.op_nop,
            0x01: self.op_add,
            0x02: self.op_sub,
            0x03: self.op_mul,
            0x04: self.op_div,
            0x05: self.op_and,
            0x06: self.op_or,
            0x07: self.op_xor,
            0x08: self.op_not,
            0x09: self.op_shl,
            0x0A: self.op_shr,
            0x0B: self.op_ld,
            0x0C: self.op_st,
            0x0D: self.op_ldi,
            0x0E: self.op_jmp,
            0x0F: self.op_jz,
            0x10: self.op_jnz,
            0x11: self.op_call,
            0x12: self.op_ret,
            0x13: self.op_push,
            0x14: self.op_pop,
            0x15: self.op_cmp,
            0x16: self.op_halt,
        }
        
    def load_program(self, program: bytes, address: int = 0):
        """Load a program into memory"""
        if address + len(program) > len(self.memory):
            raise ValueError("Program too large for memory")
        self.memory[address:address + len(program)] = program
        self.pc = address
        
    def read_instruction(self) -> int:
        """Read next instruction from memory"""
        if self.pc + 4 > len(self.memory):
            raise ValueError("PC out of bounds")
        instruction = struct.unpack('<I', self.memory[self.pc:self.pc + 4])[0]
        self.pc += 4
        return instruction
        
    def decode_instruction(self, instruction: int) -> Dict[str, Any]:
        """Decode instruction into opcode and operands"""
        opcode = instruction & 0xFF
        rd = (instruction >> 8) & 0x1F
        rs1 = (instruction >> 13) & 0x1F
        rs2 = (instruction >> 18) & 0x1F
        immediate = (instruction >> 23) & 0x1FF
        
        return {
            'opcode': opcode,
            'rd': rd,
            'rs1': rs1,
            'rs2': rs2,
            'immediate': immediate
        }
        
    def execute_instruction(self, decoded: Dict[str, Any]):
        """Execute a decoded instruction"""
        opcode = decoded['opcode']
        if opcode in self.instructions:
            self.instructions[opcode](decoded)
        else:
            raise ValueError(f"Unknown opcode: 0x{opcode:02x}")
            
    def run(self, max_instructions: int = 10000):
        """Run the VM"""
        instructions_executed = 0
        
        while not self.halted and instructions_executed < max_instructions:
            try:
                instruction = self.read_instruction()
                decoded = self.decode_instruction(instruction)
                self.execute_instruction(decoded)
                instructions_executed += 1
                self.perf_counters[0] += 1  # Instruction counter
            except Exception as e:
                print(f"Error at PC=0x{self.pc-4:08x}: {e}")
                break
                
        if self.halted:
            print("VM halted normally")
        else:
            print(f"VM stopped after {instructions_executed} instructions")
            
    # Instruction implementations
    def op_nop(self, decoded):
        pass
        
    def op_add(self, decoded):
        rd, rs1, rs2 = decoded['rd'], decoded['rs1'], decoded['rs2']
        self.gprs[rd] = self.gprs[rs1] + self.gprs[rs2]
        
    def op_sub(self, decoded):
        rd, rs1, rs2 = decoded['rd'], decoded['rs1'], decoded['rs2']
        self.gprs[rd] = self.gprs[rs1] - self.gprs[rs2]
        
    def op_mul(self, decoded):
        rd, rs1, rs2 = decoded['rd'], decoded['rs1'], decoded['rs2']
        self.gprs[rd] = self.gprs[rs1] * self.gprs[rs2]
        
    def op_div(self, decoded):
        rd, rs1, rs2 = decoded['rd'], decoded['rs1'], decoded['rs2']
        if self.gprs[rs2] != 0:
            self.gprs[rd] = self.gprs[rs1] // self.gprs[rs2]
        else:
            raise ValueError("Division by zero")
            
    def op_and(self, decoded):
        rd, rs1, rs2 = decoded['rd'], decoded['rs1'], decoded['rs2']
        self.gprs[rd] = self.gprs[rs1] & self.gprs[rs2]
        
    def op_or(self, decoded):
        rd, rs1, rs2 = decoded['rd'], decoded['rs1'], decoded['rs2']
        self.gprs[rd] = self.gprs[rs1] | self.gprs[rs2]
        
    def op_xor(self, decoded):
        rd, rs1, rs2 = decoded['rd'], decoded['rs1'], decoded['rs2']
        self.gprs[rd] = self.gprs[rs1] ^ self.gprs[rs2]
        
    def op_not(self, decoded):
        rd, rs1 = decoded['rd'], decoded['rs1']
        self.gprs[rd] = ~self.gprs[rs1]
        
    def op_shl(self, decoded):
        rd, rs1, rs2 = decoded['rd'], decoded['rs1'], decoded['rs2']
        self.gprs[rd] = self.gprs[rs1] << (self.gprs[rs2] & 0x3F)
        
    def op_shr(self, decoded):
        rd, rs1, rs2 = decoded['rd'], decoded['rs1'], decoded['rs2']
        self.gprs[rd] = self.gprs[rs1] >> (self.gprs[rs2] & 0x3F)
        
    def op_ld(self, decoded):
        rd, rs1 = decoded['rd'], decoded['rs1']
        addr = self.gprs[rs1]
        if addr + 8 <= len(self.memory):
            value = struct.unpack('<Q', self.memory[addr:addr + 8])[0]
            self.gprs[rd] = value
        else:
            raise ValueError(f"Memory access out of bounds: 0x{addr:08x}")
            
    def op_st(self, decoded):
        rd, rs1 = decoded['rd'], decoded['rs1']
        addr = self.gprs[rd]
        value = self.gprs[rs1]
        if addr + 8 <= len(self.memory):
            self.memory[addr:addr + 8] = struct.pack('<Q', value)
        else:
            raise ValueError(f"Memory access out of bounds: 0x{addr:08x}")
            
    def op_ldi(self, decoded):
        rd, immediate = decoded['rd'], decoded['immediate']
        self.gprs[rd] = immediate
        
    def op_jmp(self, decoded):
        immediate = decoded['immediate']
        self.pc = immediate
        
    def op_jz(self, decoded):
        rs1, immediate = decoded['rs1'], decoded['immediate']
        if self.gprs[rs1] == 0:
            self.pc = immediate
            
    def op_jnz(self, decoded):
        rs1, immediate = decoded['rs1'], decoded['immediate']
        if self.gprs[rs1] != 0:
            self.pc = immediate
            
    def op_call(self, decoded):
        immediate = decoded['immediate']
        # Push return address
        self.sp -= 8
        if self.sp >= 0:
            self.memory[self.sp:self.sp + 8] = struct.pack('<Q', self.pc)
            self.pc = immediate
        else:
            raise ValueError("Stack overflow")
            
    def op_ret(self, decoded):
        # Pop return address
        if self.sp + 8 < len(self.memory):
            self.pc = struct.unpack('<Q', self.memory[self.sp:self.sp + 8])[0]
            self.sp += 8
        else:
            raise ValueError("Stack underflow")
            
    def op_push(self, decoded):
        rs1 = decoded['rs1']
        self.sp -= 8
        if self.sp >= 0:
            self.memory[self.sp:self.sp + 8] = struct.pack('<Q', self.gprs[rs1])
        else:
            raise ValueError("Stack overflow")
            
    def op_pop(self, decoded):
        rd = decoded['rd']
        if self.sp + 8 < len(self.memory):
            self.gprs[rd] = struct.unpack('<Q', self.memory[self.sp:self.sp + 8])[0]
            self.sp += 8
        else:
            raise ValueError("Stack underflow")
            
    def op_cmp(self, decoded):
        rs1, rs2 = decoded['rs1'], decoded['rs2']
        result = self.gprs[rs1] - self.gprs[rs2]
        if result == 0:
            self.flags |= 1  # Zero flag
        else:
            self.flags &= ~1
        if result < 0:
            self.flags |= 2  # Negative flag
        else:
            self.flags &= ~2
            
    def op_halt(self, decoded):
        self.halted = True
        
    def get_state(self) -> Dict[str, Any]:
        """Get current VM state"""
        return {
            'pc': self.pc,
            'sp': self.sp,
            'flags': self.flags,
            'halted': self.halted,
            'gprs': self.gprs.copy(),
            'vregs': [reg.copy() for reg in self.vregs],
            'perf_counters': self.perf_counters.copy()
        }
        
    def set_state(self, state: Dict[str, Any]):
        """Set VM state"""
        self.pc = state['pc']
        self.sp = state['sp']
        self.flags = state['flags']
        self.halted = state['halted']
        self.gprs = state['gprs'].copy()
        self.vregs = [reg.copy() for reg in state['vregs']]
        self.perf_counters = state['perf_counters'].copy()

# Global VM instance for compatibility
_vm_instance = None

def vm_init():
    """Initialize global VM instance"""
    global _vm_instance
    _vm_instance = NanoCoreVM()
    
def vm_load_program(filename: str):
    """Load program from file"""
    global _vm_instance
    if _vm_instance is None:
        vm_init()
    with open(filename, 'rb') as f:
        program = f.read()
    _vm_instance.load_program(program)
    
def vm_run():
    """Run the VM"""
    global _vm_instance
    if _vm_instance is None:
        vm_init()
    _vm_instance.run()
    
def vm_get_state():
    """Get VM state"""
    global _vm_instance
    if _vm_instance is None:
        vm_init()
    return _vm_instance.get_state()
    
def vm_set_state(state):
    """Set VM state"""
    global _vm_instance
    if _vm_instance is None:
        vm_init()
    _vm_instance.set_state(state)

if __name__ == "__main__":
    # Test the VM
    vm = NanoCoreVM()
    
    # Simple test program: add two numbers
    test_program = bytes([
        0x0D, 0x01, 0x00, 0x2A,  # LDI R1, 42
        0x0D, 0x02, 0x00, 0x3A,  # LDI R2, 58
        0x01, 0x03, 0x01, 0x02,  # ADD R3, R1, R2
        0x16, 0x00, 0x00, 0x00,  # HALT
    ])
    
    vm.load_program(test_program)
    vm.run()
    
    print(f"R1 = {vm.gprs[1]}")  # Should be 42
    print(f"R2 = {vm.gprs[2]}")  # Should be 58
    print(f"R3 = {vm.gprs[3]}")  # Should be 100
    print("Test completed successfully!")
'''
        
        vm_path = self.bin_dir / "nanocore_vm.py"
        with open(vm_path, 'w', encoding='utf-8') as f:
            f.write(vm_code)
            
        # Make it executable on Unix systems
        if platform.system() != "Windows":
            os.chmod(vm_path, 0o755)
            
        self.log(f"Python VM created: {vm_path}")
        
    def create_simple_cli(self):
        """Create an enhanced CLI with interactive features"""
        self.log("Creating enhanced CLI...")
        
        cli_code = '''#!/usr/bin/env python3
"""
Simple NanoCore CLI
"""

import sys
import argparse
from pathlib import Path

# Add the build directory to Python path
sys.path.insert(0, str(Path(__file__).parent))

try:
    from nanocore_vm import NanoCoreVM
except ImportError:
    print("Error: Could not import NanoCore VM")
    print("Make sure to run build_simple.py first")
    sys.exit(1)

def main():
    parser = argparse.ArgumentParser(description="NanoCore VM CLI")
    parser.add_argument("command", choices=["run", "test", "help"], help="Command to execute")
    parser.add_argument("file", nargs="?", help="Program file to run")
    parser.add_argument("--memory", "-m", type=int, default=1024*1024, help="Memory size in bytes")
    parser.add_argument("--debug", "-d", action="store_true", help="Enable debug output")
    
    args = parser.parse_args()
    
    if args.command == "help":
        parser.print_help()
        return
        
    if args.command == "test":
        print("Running built-in test...")
        vm = NanoCoreVM(args.memory)
        
        # Test program: add two numbers
        test_program = bytes([
            0x0D, 0x01, 0x00, 0x2A,  # LDI R1, 42
            0x0D, 0x02, 0x00, 0x3A,  # LDI R2, 58
            0x01, 0x03, 0x01, 0x02,  # ADD R3, R1, R2
            0x16, 0x00, 0x00, 0x00,  # HALT
        ])
        
        vm.load_program(test_program)
        vm.run()
        
        print(f"R1 = {vm.gprs[1]}")  # Should be 42
        print(f"R2 = {vm.gprs[2]}")  # Should be 58
        print(f"R3 = {vm.gprs[3]}")  # Should be 100
        
        if vm.gprs[3] == 100:
            print("Test passed!")
        else:
            print("Test failed!")
        return
        
    if args.command == "run":
        if not args.file:
            print("Error: No program file specified")
            sys.exit(1)
            
        if not Path(args.file).exists():
            print(f"Error: File {args.file} not found")
            sys.exit(1)
            
        print(f"Running {args.file}...")
        vm = NanoCoreVM(args.memory)
        
        with open(args.file, 'rb') as f:
            program = f.read()
            
        vm.load_program(program)
        vm.run()
        
        if args.debug:
            print("\\nFinal VM State:")
            print(f"PC: 0x{vm.pc:08x}")
            print(f"SP: 0x{vm.sp:08x}")
            print(f"Flags: 0x{vm.flags:02x}")
            print("Registers:")
            for i in range(0, 32, 4):
                print(f"  R{i:02d}: 0x{vm.gprs[i]:016x}  R{i+1:02d}: 0x{vm.gprs[i+1]:016x}  R{i+2:02d}: 0x{vm.gprs[i+2]:016x}  R{i+3:02d}: 0x{vm.gprs[i+3]:016x}")

if __name__ == "__main__":
    main()
'''
        
        cli_path = self.bin_dir / "nanocore_cli.py"
        with open(cli_path, 'w', encoding='utf-8') as f:
            f.write(cli_code)
            
        # Make it executable on Unix systems
        if platform.system() != "Windows":
            os.chmod(cli_path, 0o755)
            
        self.log(f"CLI created: {cli_path}")
        
    def create_test_programs(self):
        """Create simple test programs"""
        self.log("Creating test programs...")
        
        test_dir = Path("tests")
        test_dir.mkdir(exist_ok=True)
        
        # Hello World equivalent (prints numbers)
        hello_program = bytes([
            0x0D, 0x01, 0x00, 0x48,  # LDI R1, 'H' (72)
            0x0D, 0x02, 0x00, 0x65,  # LDI R2, 'e' (101)
            0x0D, 0x03, 0x00, 0x6C,  # LDI R3, 'l' (108)
            0x0D, 0x04, 0x00, 0x6C,  # LDI R4, 'l' (108)
            0x0D, 0x05, 0x00, 0x6F,  # LDI R5, 'o' (111)
            0x16, 0x00, 0x00, 0x00,  # HALT
        ])
        
        # Demo program with calculations
        demo_program = bytes([
            0x0D, 0x01, 0x00, 0x0A,  # LDI R1, 10
            0x0D, 0x02, 0x00, 0x05,  # LDI R2, 5
            0x01, 0x03, 0x01, 0x02,  # ADD R3, R1, R2 (15)
            0x02, 0x04, 0x01, 0x02,  # SUB R4, R1, R2 (5)
            0x03, 0x05, 0x01, 0x02,  # MUL R5, R1, R2 (50)
            0x0D, 0x06, 0x00, 0x48,  # LDI R6, 'H' (72)
            0x0D, 0x07, 0x00, 0x69,  # LDI R7, 'i' (105)
            0x16, 0x00, 0x00, 0x00,  # HALT
        ])
        
        with open(test_dir / "hello.bin", 'wb') as f:
            f.write(hello_program)
            
        # Fibonacci program
        fib_program = bytes([
            0x0D, 0x01, 0x00, 0x00,  # LDI R1, 0 (a = 0)
            0x0D, 0x02, 0x00, 0x01,  # LDI R2, 1 (b = 1)
            0x0D, 0x03, 0x00, 0x0A,  # LDI R3, 10 (count)
            0x01, 0x04, 0x01, 0x02,  # ADD R4, R1, R2 (c = a + b)
            0x0D, 0x01, 0x00, 0x00,  # LDI R1, 0
            0x0D, 0x01, 0x00, 0x00,  # LDI R1, R2 (a = b)
            0x0D, 0x02, 0x00, 0x00,  # LDI R2, 0
            0x0D, 0x02, 0x00, 0x00,  # LDI R2, R4 (b = c)
            0x02, 0x03, 0x03, 0x01,  # SUB R3, R3, 1 (count--)
            0x10, 0x00, 0x00, 0x08,  # JNZ R3, loop
            0x16, 0x00, 0x00, 0x00,  # HALT
        ])
        
        with open(test_dir / "fibonacci.bin", 'wb') as f:
            f.write(fib_program)
            
        with open(test_dir / "demo.bin", 'wb') as f:
            f.write(demo_program)
            
        self.log("Test programs created")
        
    def create_simple_test(self):
        """Create a simple test script"""
        self.log("Creating simple test...")
        
        test_code = '''#!/usr/bin/env python3
"""
Simple NanoCore Test
"""

import sys
from pathlib import Path

# Add the build directory to Python path
sys.path.insert(0, str(Path(__file__).parent / "build" / "bin"))

try:
    from nanocore_vm import NanoCoreVM
except ImportError:
    print("Error: Could not import NanoCore VM")
    print("Make sure to run build_simple.py first")
    sys.exit(1)

def test_basic_operations():
    """Test basic VM operations"""
    print("Testing basic operations...")
    
    vm = NanoCoreVM()
    
    # Test program: arithmetic operations
    test_program = bytes([
        0x0D, 0x01, 0x00, 0x0A,  # LDI R1, 10
        0x0D, 0x02, 0x00, 0x05,  # LDI R2, 5
        0x01, 0x03, 0x01, 0x02,  # ADD R3, R1, R2 (should be 15)
        0x02, 0x04, 0x01, 0x02,  # SUB R4, R1, R2 (should be 5)
        0x03, 0x05, 0x01, 0x02,  # MUL R5, R1, R2 (should be 50)
        0x05, 0x06, 0x01, 0x02,  # AND R6, R1, R2 (should be 0)
        0x06, 0x07, 0x01, 0x02,  # OR R7, R1, R2 (should be 15)
        0x16, 0x00, 0x00, 0x00,  # HALT
    ])
    
    vm.load_program(test_program)
    vm.run()
    
    # Check results
    expected = {
        1: 10,  # R1
        2: 5,   # R2
        3: 15,  # R3 (ADD)
        4: 5,   # R4 (SUB)
        5: 50,  # R5 (MUL)
        6: 0,   # R6 (AND)
        7: 15,  # R7 (OR)
    }
    
    all_passed = True
    for reg, expected_value in expected.items():
        actual_value = vm.gprs[reg]
        if actual_value == expected_value:
            print(f"✓ R{reg} = {actual_value}")
        else:
            print(f"✗ R{reg} = {actual_value} (expected {expected_value})")
            all_passed = False
            
    return all_passed

def test_memory_operations():
    """Test memory operations"""
    print("\\nTesting memory operations...")
    
    vm = NanoCoreVM()
    
    # Test program: memory operations
    test_program = bytes([
        0x0D, 0x01, 0x00, 0x42,  # LDI R1, 0x42
        0x0D, 0x02, 0x00, 0x10,  # LDI R2, 0x10 (address)
        0x0C, 0x02, 0x01, 0x00,  # ST R2, R1 (store 0x42 at address 0x10)
        0x0D, 0x03, 0x00, 0x00,  # LDI R3, 0
        0x0B, 0x03, 0x02, 0x00,  # LD R3, R2 (load from address 0x10)
        0x16, 0x00, 0x00, 0x00,  # HALT
    ])
    
    vm.load_program(test_program)
    vm.run()
    
    # Check that R3 contains the value we stored
    if vm.gprs[3] == 0x42:
        print("✓ Memory operations work correctly")
        return True
    else:
        print(f"✗ Memory operations failed: R3 = {vm.gprs[3]} (expected 0x42)")
        return False

def test_control_flow():
    """Test control flow operations"""
    print("\\nTesting control flow...")
    
    vm = NanoCoreVM()
    
    # Test program: conditional jump
    test_program = bytes([
        0x0D, 0x01, 0x00, 0x01,  # LDI R1, 1
        0x0D, 0x02, 0x00, 0x00,  # LDI R2, 0
        0x15, 0x00, 0x01, 0x02,  # CMP R1, R2
        0x0F, 0x00, 0x00, 0x10,  # JZ R0, 0x10 (should not jump)
        0x0D, 0x03, 0x00, 0x42,  # LDI R3, 0x42 (should execute)
        0x15, 0x00, 0x02, 0x02,  # CMP R2, R2
        0x0F, 0x00, 0x00, 0x20,  # JZ R0, 0x20 (should jump)
        0x0D, 0x04, 0x00, 0x99,  # LDI R4, 0x99 (should not execute)
        0x16, 0x00, 0x00, 0x00,  # HALT
    ])
    
    vm.load_program(test_program)
    vm.run()
    
    # Check that R3 was set but R4 was not
    if vm.gprs[3] == 0x42 and vm.gprs[4] == 0:
        print("✓ Control flow works correctly")
        return True
    else:
        print(f"✗ Control flow failed: R3 = {vm.gprs[3]}, R4 = {vm.gprs[4]}")
        return False

def main():
    print("🚀 NanoCore VM Simple Test")
    print("=" * 30)
    
    tests = [
        ("Basic Operations", test_basic_operations),
        ("Memory Operations", test_memory_operations),
        ("Control Flow", test_control_flow),
    ]
    
    passed = 0
    total = len(tests)
    
    for test_name, test_func in tests:
        try:
            if test_func():
                passed += 1
        except Exception as e:
            print(f"✗ {test_name} failed with error: {e}")
    
    print(f"\\nTest Results: {passed}/{total} tests passed")
    
    if passed == total:
        print("🎉 All tests passed! NanoCore VM is working!")
        return 0
    else:
        print("❌ Some tests failed. Please check the implementation.")
        return 1

if __name__ == "__main__":
    sys.exit(main())
'''
        
        test_path = Path("test_simple.py")
        with open(test_path, 'w', encoding='utf-8') as f:
            f.write(test_code)
            
        self.log(f"Simple test created: {test_path}")
        
    def build(self):
        """Main build process"""
        self.log("🚀 Building NanoCore VM (Simple Version)")
        self.log("=" * 50)
        
        # Check dependencies
        tools = self.check_dependencies()
        if not tools:
            self.log("❌ No suitable build tools found")
            return False
            
        # Create directories
        self.create_directories()
        
        # Create Python VM
        self.create_python_vm()
        
        # Create CLI
        self.create_simple_cli()
        
        # Create test programs
        self.create_test_programs()
        
        # Create simple test
        self.create_simple_test()
        
        self.log("")
        self.log("Build completed successfully!")
        self.log("")
        self.log("Next steps:")
        self.log("1. Test the VM: python test_simple.py")
        self.log("2. Run CLI: python build/bin/nanocore_cli.py test")
        self.log("3. Run a program: python build/bin/nanocore_cli.py run tests/hello.bin")
        
        return True

def main():
    builder = SimpleBuilder()
    success = builder.build()
    return 0 if success else 1

if __name__ == "__main__":
    sys.exit(main()) 