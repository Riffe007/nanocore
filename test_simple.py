#!/usr/bin/env python3
"""
Simple test of NanoCore assembler and basic VM simulation
"""

import sys
import struct
from pathlib import Path

# Add assembler to path
sys.path.insert(0, str(Path(__file__).parent / "assembler"))

try:
    from nanocore_asm import Assembler, Opcode
except ImportError:
    print("Error: Could not import assembler module")
    sys.exit(1)

class SimpleVM:
    """Minimal VM for testing"""
    def __init__(self, memory_size=64*1024):
        self.memory = bytearray(memory_size)
        self.gprs = [0] * 32
        self.pc = 0
        self.halted = False
        
    def load_program(self, bytecode: bytes, address: int = 0x10000):
        """Load program into memory"""
        self.memory[address:address+len(bytecode)] = bytecode
        self.pc = address
        
    def fetch(self) -> int:
        """Fetch 32-bit instruction"""
        if self.pc + 4 > len(self.memory):
            raise Exception("PC out of bounds")
        return struct.unpack('<I', self.memory[self.pc:self.pc+4])[0]
        
    def step(self):
        """Execute one instruction"""
        if self.halted:
            return False
            
        inst = self.fetch()
        
        # Decode
        opcode = (inst >> 26) & 0x3F
        rd = (inst >> 21) & 0x1F
        rs1 = (inst >> 16) & 0x1F
        rs2 = (inst >> 11) & 0x1F
        imm = inst & 0xFFFF
        
        print(f"PC=0x{self.pc:04x}: inst=0x{inst:08x} op=0x{opcode:02x} " +
              f"rd=R{rd} rs1=R{rs1} rs2=R{rs2} imm=0x{imm:04x}")
        
        # Execute
        if opcode == Opcode.ADD:
            if rd != 0:
                self.gprs[rd] = (self.gprs[rs1] + self.gprs[rs2]) & 0xFFFFFFFFFFFFFFFF
                print(f"  ADD R{rd} = R{rs1} + R{rs2} = {self.gprs[rs1]} + {self.gprs[rs2]} = {self.gprs[rd]}")
                
        elif opcode == Opcode.LD:
            if rd != 0:
                # Simplified: just load immediate
                self.gprs[rd] = imm
                print(f"  LD R{rd} = {imm}")
                
        elif opcode == Opcode.HALT:
            print("  HALT")
            self.halted = True
            return False
            
        else:
            print(f"  Unknown opcode: 0x{opcode:02x}")
            return False
            
        self.pc += 4
        return True
        
    def run(self, max_steps=100):
        """Run until halt or max steps"""
        steps = 0
        while steps < max_steps and self.step():
            steps += 1
        return steps

def test_assembler():
    """Test the assembler with a simple program"""
    print("Testing NanoCore Assembler")
    print("=" * 50)
    
    # Simple test program
    source = """
    ; Test program
    start:
        LD   R1, 5       ; Load 5 into R1
        LD   R2, 10      ; Load 10 into R2  
        ADD  R3, R1, R2  ; Add R1 + R2 -> R3
        HALT             ; Stop
    """
    
    # Assemble
    asm = Assembler()
    try:
        bytecode = asm.assemble(source.split('\n'))
        print(f"✅ Assembly successful: {len(bytecode)} bytes")
        
        # Show bytecode
        print("\nBytecode:")
        for i in range(0, len(bytecode), 4):
            word = struct.unpack('<I', bytecode[i:i+4])[0]
            print(f"  0x{i:04x}: 0x{word:08x}")
            
        return bytecode
    except Exception as e:
        print(f"❌ Assembly failed: {e}")
        return None

def test_vm(bytecode):
    """Test the VM with assembled code"""
    print("\nTesting Simple VM")
    print("=" * 50)
    
    vm = SimpleVM()
    vm.load_program(bytecode)
    
    print("Running program...")
    print("-" * 30)
    
    steps = vm.run()
    
    print(f"\n✅ Execution complete: {steps} steps")
    print("\nFinal register state:")
    print(f"  R1 = {vm.gprs[1]} (expected: 5)")
    print(f"  R2 = {vm.gprs[2]} (expected: 10)")
    print(f"  R3 = {vm.gprs[3]} (expected: 15)")
    
    success = (vm.gprs[1] == 5 and vm.gprs[2] == 10 and vm.gprs[3] == 15)
    print(f"\nTest: {'✅ PASS' if success else '❌ FAIL'}")
    return success

def main():
    print("🚀 NanoCore Simple Test")
    print("=" * 60)
    print()
    
    # Test assembler
    bytecode = test_assembler()
    if not bytecode:
        return 1
        
    print()
    
    # Test VM
    success = test_vm(bytecode)
    
    print("\n" + "=" * 60)
    print(f"Overall: {'✅ ALL TESTS PASSED' if success else '❌ TEST FAILED'}")
    
    return 0 if success else 1

if __name__ == "__main__":
    sys.exit(main())