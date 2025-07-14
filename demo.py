#\!/usr/bin/env python3
"""
NanoCore Demonstration Script
Run this to see NanoCore in action without needing to build anything\!
"""

import sys
import os

# Add current directory to Python path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

print("🚀 NanoCore Virtual Machine Demo")
print("================================\n")

# First, build the FFI library if it doesn't exist
lib_path = "build/lib/libnanocore_ffi.so"
if not os.path.exists(lib_path):
    print("📦 Building NanoCore FFI library...")
    os.makedirs("build/lib", exist_ok=True)
    
    import subprocess
    result = subprocess.run([
        "gcc", "-shared", "-fPIC", "-O2", 
        "-o", lib_path, 
        "glue/ffi/nanocore_ffi.c"
    ], capture_output=True, text=True)
    
    if result.returncode \!= 0:
        print("❌ Failed to build FFI library")
        print("Make sure you have gcc installed")
        sys.exit(1)
    
    print("✅ FFI library built successfully\n")

# Set library path
os.environ['LD_LIBRARY_PATH'] = f"{os.getcwd()}/build/lib:{os.environ.get('LD_LIBRARY_PATH', '')}"

# Now import and use NanoCore
try:
    from glue.python.nanocore import VM, Status, PerfCounter
    
    print("📊 Creating VM with 64MB memory...")
    vm = VM(64 * 1024 * 1024)
    
    # Example 1: Simple Addition
    print("\n1️⃣ Example 1: Simple Addition")
    print("   Program: R3 = 42 + 58")
    
    program1 = bytes([
        0x3C, 0x20, 0x00, 0x2A,  # LD R1, 42
        0x3C, 0x40, 0x00, 0x3A,  # LD R2, 58
        0x00, 0x61, 0x40, 0x00,  # ADD R3, R1, R2
        0x84, 0x00, 0x00, 0x00,  # HALT
    ])
    
    vm.load_program(program1)
    vm.run()
    
    print(f"   ✅ Result: R3 = {vm.registers[3]} (expected: 100)")
    
    # Example 2: Loop Counter
    print("\n2️⃣ Example 2: Loop Simulation")
    print("   Program: Count from 0 to 5")
    
    vm.reset()
    program2 = bytes([
        0x3C, 0x20, 0x00, 0x00,  # LD R1, 0     ; counter
        0x3C, 0x40, 0x00, 0x05,  # LD R2, 5     ; limit
        0x3C, 0x60, 0x00, 0x01,  # LD R3, 1     ; increment
        # Loop would go here in full implementation
        0x00, 0x21, 0x60, 0x00,  # ADD R1, R1, R3
        0x00, 0x21, 0x60, 0x00,  # ADD R1, R1, R3
        0x00, 0x21, 0x60, 0x00,  # ADD R1, R1, R3
        0x00, 0x21, 0x60, 0x00,  # ADD R1, R1, R3
        0x00, 0x21, 0x60, 0x00,  # ADD R1, R1, R3
        0x84, 0x00, 0x00, 0x00,  # HALT
    ])
    
    vm.load_program(program2)
    vm.run()
    
    print(f"   ✅ Counter: R1 = {vm.registers[1]} (expected: 5)")
    
    # Example 3: Arithmetic Operations
    print("\n3️⃣ Example 3: Arithmetic Operations")
    print("   Program: (100 - 10) * 2")
    
    vm.reset()
    program3 = bytes([
        0x3C, 0x20, 0x00, 0x64,  # LD R1, 100
        0x3C, 0x40, 0x00, 0x0A,  # LD R2, 10
        0x04, 0x61, 0x40, 0x00,  # SUB R3, R1, R2  ; R3 = 90
        0x3C, 0x80, 0x00, 0x02,  # LD R4, 2
        0x08, 0xA3, 0x80, 0x00,  # MUL R5, R3, R4  ; R5 = 180
        0x84, 0x00, 0x00, 0x00,  # HALT
    ])
    
    vm.load_program(program3)
    vm.run()
    
    print(f"   ✅ Result: R5 = {vm.registers[5]} (expected: 180)")
    
    # Performance metrics
    print("\n📈 Performance Metrics:")
    instructions = vm.get_perf_counter(PerfCounter.INST_COUNT)
    cycles = vm.get_perf_counter(PerfCounter.CYCLE_COUNT)
    
    print(f"   Instructions executed: {instructions}")
    print(f"   Cycles: {cycles}")
    print(f"   IPC: {instructions/max(cycles, 1):.2f}")
    
    # Show VM state
    print("\n🔍 Final VM State:")
    state = vm.state
    print(f"   PC: 0x{state.pc:016x}")
    print(f"   SP: 0x{state.sp:016x}")
    print(f"   Flags: 0x{state.flags:016x}")
    
    print("\n✨ Demo completed successfully\!")
    
    # Interactive section
    print("\n" + "="*50)
    print("🎮 Try it yourself\!")
    print("="*50)
    print("\nPython shell with VM loaded. Try:")
    print("  >>> vm.registers[1]  # Read register")
    print("  >>> vm.reset()       # Reset VM")
    print("  >>> vm.step()        # Single step")
    print("  >>> exit()           # Exit")
    print()
    
    # Drop into interactive mode
    import code
    code.interact(local=locals())
    
except ImportError as e:
    print(f"\n❌ Import error: {e}")
    print("\nTroubleshooting:")
    print("1. Make sure the FFI library was built successfully")
    print("2. Check that you're in the NanoCore root directory")
    print("3. On Linux, you may need to install python3-dev")
    
except Exception as e:
    print(f"\n❌ Error: {e}")
    import traceback
    traceback.print_exc()
