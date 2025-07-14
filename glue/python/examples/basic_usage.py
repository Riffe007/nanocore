#!/usr/bin/env python3
"""
NanoCore Python API - Basic Usage Examples

This script demonstrates the basic usage of the NanoCore VM Python API.
"""

import nanocore
import numpy as np
from pathlib import Path

def example_hello_world():
    """Run a simple hello world program"""
    print("=== Hello World Example ===")
    
    # Create VM with 64MB memory
    vm = nanocore.VM(memory_size=64 * 1024 * 1024)
    
    # Simple program that loads immediate values and halts
    # This is hand-assembled bytecode for:
    #   LOAD R1, 0x1234
    #   LOAD R2, 0x5678
    #   ADD R3, R1, R2
    #   HALT
    program = bytes([
        0x0F, 0x20, 0x12, 0x34,  # LOAD R1, 0x1234
        0x0F, 0x40, 0x56, 0x78,  # LOAD R2, 0x5678
        0x00, 0x61, 0x40, 0x00,  # ADD R3, R1, R2
        0x84, 0x00, 0x00, 0x00,  # HALT
    ])
    
    # Load program at address 0x10000
    vm.load_program(program, address=0x10000)
    
    # Set PC to program start
    vm.state.pc = 0x10000
    
    # Run the program
    exit_code = vm.run()
    
    print(f"Exit code: {exit_code}")
    print(f"R1 = 0x{vm.registers[1]:04x}")
    print(f"R2 = 0x{vm.registers[2]:04x}")
    print(f"R3 = 0x{vm.registers[3]:04x}")
    print(f"Instructions executed: {vm.get_perf_counter(nanocore.PerfCounter.INST_COUNT)}")
    print()

def example_memory_operations():
    """Demonstrate memory read/write operations"""
    print("=== Memory Operations Example ===")
    
    vm = nanocore.VM()
    
    # Write some data to memory
    data = b"Hello, NanoCore!"
    vm.write_memory(0x20000, data)
    
    # Read it back
    read_data = vm.read_memory(0x20000, len(data))
    print(f"Written: {data}")
    print(f"Read back: {read_data}")
    print(f"Match: {data == read_data}")
    print()

def example_debugging():
    """Demonstrate debugging features"""
    print("=== Debugging Example ===")
    
    vm = nanocore.VM()
    
    # Program that counts from 0 to 10
    # R1 = counter, R2 = limit (10)
    program = bytes([
        0x0F, 0x20, 0x00, 0x00,  # LOAD R1, 0      ; counter = 0
        0x0F, 0x40, 0x00, 0x0A,  # LOAD R2, 10     ; limit = 10
        # Loop:
        0x00, 0x20, 0x20, 0x01,  # ADD R1, R1, 1   ; counter++
        0x18, 0x20, 0x40, 0xFC,  # BNE R1, R2, -4  ; if counter != limit, loop
        0x84, 0x00, 0x00, 0x00,  # HALT
    ])
    
    vm.load_program(program, address=0x10000)
    vm.state.pc = 0x10000
    
    # Set breakpoint at the ADD instruction
    vm.set_breakpoint(0x10008)
    
    # Run with breakpoint handling
    iterations = 0
    while True:
        exit_code = vm.run()
        
        if exit_code == 2:  # Breakpoint hit
            iterations += 1
            print(f"Breakpoint hit! Iteration {iterations}, R1 = {vm.registers[1]}")
            
            # Continue execution
            vm.state.pc += 4  # Skip past breakpoint
        else:
            break
    
    print(f"Final counter value: {vm.registers[1]}")
    print()

def example_simd_operations():
    """Demonstrate SIMD vector operations"""
    print("=== SIMD Operations Example ===")
    
    vm = nanocore.VM()
    
    # Prepare vector data in memory
    vec1 = np.array([1.0, 2.0, 3.0, 4.0], dtype=np.float64)
    vec2 = np.array([5.0, 6.0, 7.0, 8.0], dtype=np.float64)
    
    vm.write_memory(0x30000, vec1.tobytes())
    vm.write_memory(0x30020, vec2.tobytes())
    
    # Program to add two vectors
    # VLOAD V0, [0x30000]
    # VLOAD V1, [0x30020]
    # VADD.F64 V2, V0, V1
    # VSTORE V2, [0x30040]
    # HALT
    program = bytes([
        0xD0, 0x00, 0x00, 0x03,  # VLOAD V0, [0x30000]
        0x00, 0x00,
        0xD0, 0x20, 0x00, 0x03,  # VLOAD V1, [0x30020]
        0x00, 0x20,
        0xC0, 0x40, 0x00, 0x20,  # VADD.F64 V2, V0, V1
        0xD4, 0x40, 0x00, 0x03,  # VSTORE V2, [0x30040]
        0x00, 0x40,
        0x84, 0x00, 0x00, 0x00,  # HALT
    ])
    
    vm.load_program(program, address=0x10000)
    vm.state.pc = 0x10000
    
    # Run the program
    vm.run()
    
    # Read back result
    result_bytes = vm.read_memory(0x30040, 32)
    result = np.frombuffer(result_bytes, dtype=np.float64)
    
    print(f"Vector 1: {vec1}")
    print(f"Vector 2: {vec2}")
    print(f"Result:   {result}")
    print(f"Expected: {vec1 + vec2}")
    print(f"SIMD operations: {vm.get_perf_counter(nanocore.PerfCounter.SIMD_OPS)}")
    print()

def example_performance_monitoring():
    """Demonstrate performance monitoring"""
    print("=== Performance Monitoring Example ===")
    
    vm = nanocore.VM()
    
    # Compute factorial(10)
    # R1 = n (10), R2 = result (1), R3 = counter
    program = bytes([
        0x0F, 0x20, 0x00, 0x0A,  # LOAD R1, 10     ; n = 10
        0x0F, 0x40, 0x00, 0x01,  # LOAD R2, 1      ; result = 1
        0x0F, 0x60, 0x00, 0x01,  # LOAD R3, 1      ; counter = 1
        # Loop:
        0x02, 0x40, 0x40, 0x60,  # MUL R2, R2, R3  ; result *= counter
        0x00, 0x60, 0x60, 0x01,  # ADD R3, R3, 1   ; counter++
        0x19, 0x60, 0x20, 0xF8,  # BLE R3, R1, -8  ; if counter <= n, loop
        0x84, 0x00, 0x00, 0x00,  # HALT
    ])
    
    vm.load_program(program, address=0x10000)
    vm.state.pc = 0x10000
    
    # Run and measure performance
    import time
    start_time = time.perf_counter()
    vm.run()
    end_time = time.perf_counter()
    
    # Display performance metrics
    print(f"Factorial(10) = {vm.registers[2]}")
    print(f"Execution time: {(end_time - start_time) * 1000:.3f} ms")
    print(f"Instructions: {vm.get_perf_counter(nanocore.PerfCounter.INST_COUNT)}")
    print(f"Cycles: {vm.get_perf_counter(nanocore.PerfCounter.CYCLE_COUNT)}")
    print(f"L1 cache misses: {vm.get_perf_counter(nanocore.PerfCounter.L1_MISS)}")
    print(f"Branch mispredictions: {vm.get_perf_counter(nanocore.PerfCounter.BRANCH_MISS)}")
    print()

def example_event_handling():
    """Demonstrate event handling"""
    print("=== Event Handling Example ===")
    
    vm = nanocore.VM()
    
    # Set up event handlers
    def on_halt(data):
        print(f"VM halted at PC = 0x{vm.pc:08x}")
    
    def on_breakpoint(address):
        print(f"Breakpoint hit at 0x{address:08x}")
    
    vm.on_event(nanocore.EventType.HALTED, on_halt)
    vm.on_event(nanocore.EventType.BREAKPOINT, on_breakpoint)
    
    # Simple program with events
    program = bytes([
        0x0F, 0x20, 0x00, 0x42,  # LOAD R1, 0x42
        0x84, 0x00, 0x00, 0x00,  # HALT
    ])
    
    vm.load_program(program, address=0x10000)
    vm.state.pc = 0x10000
    
    # Run and process events
    vm.run()
    vm.process_events()
    print()

def main():
    """Run all examples"""
    print("NanoCore Python API Examples")
    print("=" * 40)
    print()
    
    examples = [
        example_hello_world,
        example_memory_operations,
        example_debugging,
        example_simd_operations,
        example_performance_monitoring,
        example_event_handling,
    ]
    
    for example in examples:
        try:
            example()
        except Exception as e:
            print(f"Error in {example.__name__}: {e}")
            print()
    
    print("All examples completed!")

if __name__ == "__main__":
    main()