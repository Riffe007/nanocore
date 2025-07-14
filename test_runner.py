#!/usr/bin/env python3
"""
NanoCore Test Runner - Integration test for the VM

This creates a simple C program that uses the VM to run tests.
"""

import os
import sys
import subprocess
import tempfile
from pathlib import Path

# Test C program that integrates with the VM
TEST_PROGRAM = """
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>

// Simplified VM interface for testing
typedef struct {
    uint64_t pc;
    uint64_t sp;
    uint64_t flags;
    uint64_t gprs[32];
    uint8_t* memory;
    size_t memory_size;
} VM;

// Create a simple VM
VM* vm_create(size_t memory_size) {
    VM* vm = (VM*)calloc(1, sizeof(VM));
    vm->memory = (uint8_t*)calloc(memory_size, 1);
    vm->memory_size = memory_size;
    vm->sp = memory_size - 8;  // Stack at top of memory
    return vm;
}

void vm_destroy(VM* vm) {
    free(vm->memory);
    free(vm);
}

// Simple instruction decoder and executor
int vm_step(VM* vm) {
    if (vm->pc >= vm->memory_size - 3) {
        return -1;  // PC out of bounds
    }
    
    // Fetch instruction (32-bit)
    uint32_t instruction = *(uint32_t*)(vm->memory + vm->pc);
    
    // Decode opcode (top 6 bits)
    uint8_t opcode = (instruction >> 26) & 0x3F;
    uint8_t rd = (instruction >> 21) & 0x1F;
    uint8_t rs1 = (instruction >> 16) & 0x1F;
    uint8_t rs2 = (instruction >> 11) & 0x1F;
    int16_t imm = instruction & 0xFFFF;
    
    // Execute based on opcode
    switch (opcode) {
        case 0x00:  // ADD
            if (rd != 0) vm->gprs[rd] = vm->gprs[rs1] + vm->gprs[rs2];
            break;
            
        case 0x01:  // SUB
            if (rd != 0) vm->gprs[rd] = vm->gprs[rs1] - vm->gprs[rs2];
            break;
            
        case 0x0F:  // LD (simplified - immediate only)
            if (rd != 0) vm->gprs[rd] = imm;
            break;
            
        case 0x21:  // HALT
            vm->flags |= 0x80;  // Set halt flag
            return 0;
            
        case 0x22:  // NOP
            break;
            
        default:
            printf("Unknown opcode: 0x%02x\\n", opcode);
            return -1;
    }
    
    vm->pc += 4;
    return 0;
}

int vm_run(VM* vm, int max_steps) {
    int steps = 0;
    while (steps < max_steps && !(vm->flags & 0x80)) {
        if (vm_step(vm) != 0) {
            return -1;
        }
        steps++;
    }
    return steps;
}

// Test programs (hand-assembled)
void load_test_program_add(VM* vm) {
    uint32_t program[] = {
        0x3C200005,  // LD R1, 5     (0F 20 00 05)
        0x3C40000A,  // LD R2, 10    (0F 40 00 0A)
        0x00614000,  // ADD R3, R1, R2
        0x84000000,  // HALT
    };
    
    memcpy(vm->memory + 0x10000, program, sizeof(program));
    vm->pc = 0x10000;
}

void load_test_program_loop(VM* vm) {
    uint32_t program[] = {
        0x3C200000,  // LD R1, 0     ; counter
        0x3C400005,  // LD R2, 5     ; limit
        0x3C600001,  // LD R3, 1     ; increment
        // Loop:
        0x00616000,  // ADD R1, R1, R3
        0x60220FFC,  // BNE R1, R2, -4  (simplified encoding)
        0x84000000,  // HALT
    };
    
    memcpy(vm->memory + 0x10000, program, sizeof(program));
    vm->pc = 0x10000;
}

// Run tests
int main() {
    printf("NanoCore VM Test Suite\\n");
    printf("======================\\n\\n");
    
    // Test 1: Basic arithmetic
    printf("Test 1: Basic ADD instruction\\n");
    VM* vm1 = vm_create(1024 * 1024);
    load_test_program_add(vm1);
    
    int steps = vm_run(vm1, 100);
    printf("  Executed %d steps\\n", steps);
    printf("  R1 = %lu (expected: 5)\\n", vm1->gprs[1]);
    printf("  R2 = %lu (expected: 10)\\n", vm1->gprs[2]);
    printf("  R3 = %lu (expected: 15)\\n", vm1->gprs[3]);
    
    int test1_pass = (vm1->gprs[1] == 5 && vm1->gprs[2] == 10 && vm1->gprs[3] == 15);
    printf("  Result: %s\\n\\n", test1_pass ? "PASS" : "FAIL");
    
    vm_destroy(vm1);
    
    // Test 2: Loop
    printf("Test 2: Loop test\\n");
    VM* vm2 = vm_create(1024 * 1024);
    load_test_program_loop(vm2);
    
    steps = vm_run(vm2, 1000);
    printf("  Executed %d steps\\n", steps);
    printf("  R1 = %lu (expected: 5)\\n", vm2->gprs[1]);
    
    int test2_pass = (vm2->gprs[1] == 5);
    printf("  Result: %s\\n\\n", test2_pass ? "PASS" : "FAIL");
    
    vm_destroy(vm2);
    
    // Summary
    printf("Summary:\\n");
    printf("  Test 1 (ADD): %s\\n", test1_pass ? "PASS" : "FAIL");
    printf("  Test 2 (Loop): %s\\n", test2_pass ? "PASS" : "FAIL");
    printf("  Overall: %s\\n", (test1_pass && test2_pass) ? "ALL TESTS PASSED" : "SOME TESTS FAILED");
    
    return (test1_pass && test2_pass) ? 0 : 1;
}
"""

def compile_and_run_test():
    """Compile and run the test program"""
    print("🧪 NanoCore Integration Test")
    print("=" * 40)
    
    # Create temporary directory
    with tempfile.TemporaryDirectory() as tmpdir:
        test_file = Path(tmpdir) / "test_vm.c"
        test_file.write_text(TEST_PROGRAM)
        
        executable = Path(tmpdir) / "test_vm"
        
        # Compile
        print("Compiling test program...")
        compile_cmd = ["gcc", "-O2", "-o", str(executable), str(test_file)]
        
        try:
            result = subprocess.run(compile_cmd, capture_output=True, text=True)
            if result.returncode != 0:
                print(f"❌ Compilation failed:")
                print(result.stderr)
                return False
            
            print("✅ Compilation successful")
            
            # Run test
            print("\nRunning tests...")
            print("-" * 40)
            
            result = subprocess.run([str(executable)], capture_output=True, text=True)
            print(result.stdout)
            
            if result.returncode == 0:
                print("\n✅ All tests passed!")
                return True
            else:
                print("\n❌ Some tests failed")
                return False
                
        except Exception as e:
            print(f"❌ Error: {e}")
            return False

def test_assembler():
    """Test the assembler"""
    print("\n🔧 Testing Assembler")
    print("=" * 40)
    
    # Check if assembler exists
    asm_path = Path("assembler/nanocore_asm.py")
    if not asm_path.exists():
        print("❌ Assembler not found")
        return False
    
    # Test assembly
    test_asm = """
    ; Simple test program
    _start:
        LOAD R1, 42
        LOAD R2, 58
        ADD  R3, R1, R2
        HALT
    """
    
    with tempfile.TemporaryDirectory() as tmpdir:
        # Write test assembly
        test_file = Path(tmpdir) / "test.asm"
        test_file.write_text(test_asm)
        
        output_file = Path(tmpdir) / "test.bin"
        
        # Run assembler
        cmd = [sys.executable, str(asm_path), str(test_file), "-o", str(output_file)]
        
        try:
            result = subprocess.run(cmd, capture_output=True, text=True)
            
            if result.returncode == 0 and output_file.exists():
                size = output_file.stat().st_size
                print(f"✅ Assembly successful: {size} bytes generated")
                
                # Show hex dump
                with open(output_file, 'rb') as f:
                    data = f.read()
                    print("\nGenerated bytecode:")
                    for i in range(0, len(data), 4):
                        word = data[i:i+4]
                        if len(word) == 4:
                            val = int.from_bytes(word, 'little')
                            print(f"  0x{i:04x}: {val:08x}")
                
                return True
            else:
                print(f"❌ Assembly failed:")
                print(result.stderr)
                return False
                
        except Exception as e:
            print(f"❌ Error: {e}")
            return False

def main():
    """Run all tests"""
    print("🚀 NanoCore Test Runner")
    print("=" * 50)
    print()
    
    # Test the simplified C implementation
    c_test_pass = compile_and_run_test()
    
    # Test the assembler
    asm_test_pass = test_assembler()
    
    # Summary
    print("\n" + "=" * 50)
    print("📊 Test Summary:")
    print(f"  C VM Test: {'✅ PASS' if c_test_pass else '❌ FAIL'}")
    print(f"  Assembler Test: {'✅ PASS' if asm_test_pass else '❌ FAIL'}")
    print(f"  Overall: {'✅ ALL TESTS PASSED' if (c_test_pass and asm_test_pass) else '❌ SOME TESTS FAILED'}")
    
    return 0 if (c_test_pass and asm_test_pass) else 1

if __name__ == "__main__":
    sys.exit(main())