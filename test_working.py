#!/usr/bin/env python3
"""
Working NanoCore VM Test
Demonstrates the VM working with properly formatted instructions
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

def test_basic_arithmetic():
    """Test basic arithmetic operations"""
    print("Testing basic arithmetic operations...")
    
    vm = NanoCoreVM()
    
    # Test program: arithmetic operations with correct instruction format
    # LDI R1, 10; LDI R2, 5; ADD R3, R1, R2; SUB R4, R1, R2; MUL R5, R1, R2; HALT
    test_program = bytes([
        0x0D, 0x01, 0x00, 0x0A,  # LDI R1, 10
        0x0D, 0x02, 0x00, 0x05,  # LDI R2, 5
        0x01, 0x03, 0x01, 0x02,  # ADD R3, R1, R2 (should be 15)
        0x02, 0x04, 0x01, 0x02,  # SUB R4, R1, R2 (should be 5)
        0x03, 0x05, 0x01, 0x02,  # MUL R5, R1, R2 (should be 50)
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

def test_logical_operations():
    """Test logical operations"""
    print("\nTesting logical operations...")
    
    vm = NanoCoreVM()
    
    # Test program: logical operations
    # LDI R1, 0x0F; LDI R2, 0x03; AND R3, R1, R2; OR R4, R1, R2; XOR R5, R1, R2; HALT
    test_program = bytes([
        0x0D, 0x01, 0x00, 0x0F,  # LDI R1, 0x0F (15)
        0x0D, 0x02, 0x00, 0x03,  # LDI R2, 0x03 (3)
        0x05, 0x03, 0x01, 0x02,  # AND R3, R1, R2 (should be 3)
        0x06, 0x04, 0x01, 0x02,  # OR R4, R1, R2 (should be 15)
        0x07, 0x05, 0x01, 0x02,  # XOR R5, R1, R2 (should be 12)
        0x16, 0x00, 0x00, 0x00,  # HALT
    ])
    
    vm.load_program(test_program)
    vm.run()
    
    # Check results
    expected = {
        1: 0x0F,  # R1
        2: 0x03,  # R2
        3: 0x03,  # R3 (AND)
        4: 0x0F,  # R4 (OR)
        5: 0x0C,  # R5 (XOR)
    }
    
    all_passed = True
    for reg, expected_value in expected.items():
        actual_value = vm.gprs[reg]
        if actual_value == expected_value:
            print(f"✓ R{reg} = 0x{actual_value:02x}")
        else:
            print(f"✗ R{reg} = 0x{actual_value:02x} (expected 0x{expected_value:02x})")
            all_passed = False
            
    return all_passed

def test_memory_operations():
    """Test memory operations"""
    print("\nTesting memory operations...")
    
    vm = NanoCoreVM()
    
    # Test program: memory operations
    # LDI R1, 0x42; LDI R2, 0x1000; ST R2, R1; LDI R3, 0; LD R3, R2; HALT
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
        print(f"✗ Memory operations failed: R3 = 0x{vm.gprs[3]:02x} (expected 0x42)")
        return False

def test_control_flow():
    """Test control flow operations"""
    print("\nTesting control flow...")
    
    vm = NanoCoreVM()
    
    # Test program: conditional jump
    # LDI R1, 1; LDI R2, 0; CMP R1, R2; JZ R0, skip1; LDI R3, 0x42; skip1: CMP R2, R2; JZ R0, skip2; LDI R4, 0x99; skip2: HALT
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
        print(f"✗ Control flow failed: R3 = 0x{vm.gprs[3]:02x}, R4 = 0x{vm.gprs[4]:02x}")
        return False

def test_fibonacci():
    """Test a simple Fibonacci calculation"""
    print("\nTesting Fibonacci calculation...")
    
    vm = NanoCoreVM()
    
    # Calculate Fibonacci(10) = 55
    # R1 = a, R2 = b, R3 = count, R4 = temp
    test_program = bytes([
        0x0D, 0x01, 0x00, 0x00,  # LDI R1, 0 (a = 0)
        0x0D, 0x02, 0x00, 0x01,  # LDI R2, 1 (b = 1)
        0x0D, 0x03, 0x00, 0x0A,  # LDI R3, 10 (count)
        0x01, 0x04, 0x01, 0x02,  # ADD R4, R1, R2 (temp = a + b)
        0x0D, 0x01, 0x00, 0x00,  # LDI R1, 0
        0x0D, 0x01, 0x00, 0x00,  # LDI R1, R2 (a = b)
        0x0D, 0x02, 0x00, 0x00,  # LDI R2, 0
        0x0D, 0x02, 0x00, 0x00,  # LDI R2, R4 (b = temp)
        0x02, 0x03, 0x03, 0x01,  # SUB R3, R3, 1 (count--)
        0x10, 0x00, 0x00, 0x0C,  # JNZ R3, loop (jump back 12 bytes)
        0x16, 0x00, 0x00, 0x00,  # HALT
    ])
    
    vm.load_program(test_program)
    vm.run()
    
    # The result should be in R2 (Fibonacci(10) = 55)
    if vm.gprs[2] == 55:
        print(f"✓ Fibonacci(10) = {vm.gprs[2]}")
        return True
    else:
        print(f"✗ Fibonacci calculation failed: R2 = {vm.gprs[2]} (expected 55)")
        return False

def main():
    print("🚀 NanoCore VM Working Test")
    print("=" * 40)
    
    tests = [
        ("Basic Arithmetic", test_basic_arithmetic),
        ("Logical Operations", test_logical_operations),
        ("Memory Operations", test_memory_operations),
        ("Control Flow", test_control_flow),
        ("Fibonacci", test_fibonacci),
    ]
    
    passed = 0
    total = len(tests)
    
    for test_name, test_func in tests:
        try:
            if test_func():
                passed += 1
        except Exception as e:
            print(f"✗ {test_name} failed with error: {e}")
    
    print(f"\nTest Results: {passed}/{total} tests passed")
    
    if passed == total:
        print("🎉 ALL TESTS PASSED! NanoCore VM is fully functional!")
        return 0
    else:
        print("❌ Some tests failed. The VM needs more work.")
        return 1

if __name__ == "__main__":
    sys.exit(main()) 