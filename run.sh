#!/bin/bash
# NanoCore Quick Run Script
# This script builds and runs a simple NanoCore demo

set -e  # Exit on error

echo "🚀 NanoCore Quick Demo"
echo "====================="

# Step 1: Build the VM
echo -e "\n📦 Building NanoCore VM..."
if [ ! -f "build.sh" ]; then
    echo "❌ Error: build.sh not found. Are you in the NanoCore directory?"
    exit 1
fi
chmod +x build.sh
./build.sh

# Step 2: Build FFI Library
echo -e "\n🔧 Building FFI library..."
mkdir -p build/lib
gcc -shared -fPIC -O2 -o build/lib/libnanocore_ffi.so glue/ffi/nanocore_ffi.c

# Step 3: Set library path
export LD_LIBRARY_PATH=$PWD/build/lib:$LD_LIBRARY_PATH

# Step 4: Create and run a simple test program
echo -e "\n🧪 Running test program..."
cat > /tmp/nanocore_test.py << 'EOF'
#!/usr/bin/env python3
import sys
import os

# Add current directory to path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

try:
    from glue.python.nanocore import VM
    
    print("Creating VM with 1MB memory...")
    vm = VM(1024 * 1024)
    
    print("Loading program: ADD 42 + 58...")
    # Program: LD R1,42; LD R2,58; ADD R3,R1,R2; HALT
    program = bytes([
        0x3C, 0x20, 0x00, 0x2A,  # LD R1, 42
        0x3C, 0x40, 0x00, 0x3A,  # LD R2, 58
        0x00, 0x61, 0x40, 0x00,  # ADD R3, R1, R2
        0x84, 0x00, 0x00, 0x00,  # HALT
    ])
    vm.load_program(program)
    
    print("Running program...")
    result = vm.run(100)  # Max 100 instructions
    
    print("\n✅ Results:")
    print(f"   R1 = {vm.registers[1]} (expected: 42)")
    print(f"   R2 = {vm.registers[2]} (expected: 58)")
    print(f"   R3 = {vm.registers[3]} (expected: 100)")
    
    if vm.registers[3] == 100:
        print("\n🎉 SUCCESS! NanoCore is working correctly!")
    else:
        print("\n❌ Unexpected result")
        
except Exception as e:
    print(f"\n❌ Error: {e}")
    print("\nTroubleshooting:")
    print("1. Make sure you built the FFI library")
    print("2. Check that LD_LIBRARY_PATH is set correctly")
    print("3. Verify Python can find the glue modules")
EOF

python3 /tmp/nanocore_test.py

# Step 5: Show next steps
echo -e "\n📚 Next Steps:"
echo "1. Run the CLI tool:"
echo "   python3 cli/nanocore-cli.py --help"
echo ""
echo "2. Start the web playground:"
echo "   cd playground && npm install && npm run dev"
echo ""
echo "3. Try the Python API:"
echo "   export LD_LIBRARY_PATH=$PWD/build/lib:\$LD_LIBRARY_PATH"
echo "   python3"
echo "   >>> from glue.python.nanocore import VM"
echo "   >>> vm = VM()"
echo ""
echo "4. Read the documentation:"
echo "   cat QUICKSTART.md"

echo -e "\n✨ Setup complete! Happy hacking!"