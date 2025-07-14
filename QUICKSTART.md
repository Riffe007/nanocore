# NanoCore Quick Start Guide

This guide will help you get NanoCore up and running quickly.

## Prerequisites

- **Linux/macOS** (Windows via WSL2)
- **NASM** (Netwide Assembler) 
- **GCC** (GNU Compiler Collection)
- **Python 3.8+**
- **Node.js 16+** (for playground)
- **Rust** (optional, for Rust bindings)

### Install Prerequisites

**Ubuntu/Debian:**
```bash
sudo apt update
sudo apt install -y nasm gcc python3 python3-pip nodejs npm
```

**macOS:**
```bash
brew install nasm gcc python node
```

## 1. Build the Core VM

```bash
# From the NanoCore root directory
./build.sh
```

This builds the assembly VM and creates static/shared libraries.

## 2. Build the FFI Library

```bash
# Compile the C FFI wrapper
mkdir -p build/lib
gcc -shared -fPIC -O2 -o build/lib/libnanocore_ffi.so glue/ffi/nanocore_ffi.c
```

## 3. Test Python Bindings

```bash
# Test that Python bindings work
export LD_LIBRARY_PATH=$PWD/build/lib:$LD_LIBRARY_PATH
python3 -c "import sys; sys.path.append('.'); from glue.python.nanocore import VM; print('✅ Python bindings work!')"
```

## 4. Run the CLI Tool

```bash
# Make the CLI executable
chmod +x cli/nanocore-cli.py

# Show help
python3 cli/nanocore-cli.py --help

# Run a simple test
echo "3C 20 00 2A 84 00 00 00" | xxd -r -p > test.bin
python3 cli/nanocore-cli.py run test.bin
```

## 5. Run the Web Playground

```bash
# Navigate to playground
cd playground

# Install dependencies
npm install

# Start development server
npm run dev
```

Open http://localhost:5173 in your browser.

## 6. Run Tests

```bash
# From root directory
python3 test_runner.py

# Run specific test framework
cd tests
python3 test_framework.py
```

## Complete Example Workflow

Here's a complete example from assembly to execution:

### 1. Create an Assembly Program

Create `hello.asm`:
```asm
; Simple addition program
_start:
    LD   R1, 42      ; Load 42 into R1
    LD   R2, 58      ; Load 58 into R2
    ADD  R3, R1, R2  ; R3 = R1 + R2 = 100
    HALT
```

### 2. Assemble to Bytecode

```bash
# Using the assembler (if implemented)
python3 assembler/nanocore_asm.py hello.asm -o hello.bin

# Or manually create hex bytes
echo "3C 20 00 2A 3C 40 00 3A 00 61 40 00 84 00 00 00" | xxd -r -p > hello.bin
```

### 3. Run with CLI

```bash
# Execute the program
python3 cli/nanocore-cli.py run hello.bin

# Debug mode
python3 cli/nanocore-cli.py run hello.bin --debug

# Profile performance
python3 cli/nanocore-cli.py profile hello.bin --cycles 1000
```

### 4. Use Python API

Create `test_vm.py`:
```python
#!/usr/bin/env python3
import sys
sys.path.append('.')
from glue.python.nanocore import VM

# Create VM with 1MB memory
vm = VM(1024 * 1024)

# Load program (ADD two numbers)
program = bytes([
    0x3C, 0x20, 0x00, 0x2A,  # LD R1, 42
    0x3C, 0x40, 0x00, 0x3A,  # LD R2, 58
    0x00, 0x61, 0x40, 0x00,  # ADD R3, R1, R2
    0x84, 0x00, 0x00, 0x00,  # HALT
])
vm.load_program(program)

# Run
vm.run()

# Check results
print(f"R1 = {vm.registers[1]}")  # 42
print(f"R2 = {vm.registers[2]}")  # 58
print(f"R3 = {vm.registers[3]}")  # 100
```

Run it:
```bash
export LD_LIBRARY_PATH=$PWD/build/lib:$LD_LIBRARY_PATH
python3 test_vm.py
```

## Quick Test Everything

Run this script to test all components:

```bash
#!/bin/bash
# save as test_all.sh

echo "🚀 Testing NanoCore Components"
echo "=============================="

# Build
echo "1. Building VM..."
./build.sh
if [ $? -eq 0 ]; then echo "✅ Build successful"; else echo "❌ Build failed"; exit 1; fi

# FFI Library
echo -e "\n2. Building FFI library..."
mkdir -p build/lib
gcc -shared -fPIC -O2 -o build/lib/libnanocore_ffi.so glue/ffi/nanocore_ffi.c
if [ $? -eq 0 ]; then echo "✅ FFI build successful"; else echo "❌ FFI build failed"; fi

# Python bindings
echo -e "\n3. Testing Python bindings..."
export LD_LIBRARY_PATH=$PWD/build/lib:$LD_LIBRARY_PATH
python3 -c "import sys; sys.path.append('.'); from glue.python.nanocore import VM; print('✅ Python bindings work!')" 2>/dev/null
if [ $? -ne 0 ]; then echo "❌ Python bindings failed"; fi

# CLI
echo -e "\n4. Testing CLI..."
python3 cli/nanocore-cli.py --help > /dev/null 2>&1
if [ $? -eq 0 ]; then echo "✅ CLI works"; else echo "❌ CLI failed"; fi

# Playground
echo -e "\n5. Checking playground..."
cd playground && npm list > /dev/null 2>&1
if [ $? -eq 0 ]; then echo "✅ Playground dependencies OK"; else echo "❌ Run 'npm install' in playground/"; fi
cd ..

echo -e "\n✨ Testing complete!"
```

Make it executable and run:
```bash
chmod +x test_all.sh
./test_all.sh
```

## Docker Quick Start (Alternative)

Create a `Dockerfile`:
```dockerfile
FROM ubuntu:22.04
RUN apt-get update && apt-get install -y \
    nasm gcc python3 python3-pip nodejs npm \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /nanocore
COPY . .
RUN ./build.sh
RUN gcc -shared -fPIC -O2 -o build/lib/libnanocore_ffi.so glue/ffi/nanocore_ffi.c
CMD ["python3", "cli/nanocore-cli.py", "--help"]
```

Build and run:
```bash
docker build -t nanocore .
docker run -it nanocore
```

## Troubleshooting

### Library not found
```bash
export LD_LIBRARY_PATH=$PWD/build/lib:$LD_LIBRARY_PATH
```

### Permission denied
```bash
chmod +x build.sh cli/nanocore-cli.py
```

### NASM not found
Install NASM for your platform (see Prerequisites).

### Python module not found
Make sure you're in the NanoCore root directory and using the correct Python path.

## Next Steps

1. **Explore Examples** - Check out the `tests/` directory
2. **Read the Docs** - See `docs/isa_spec.md` for instruction details
3. **Try the Playground** - Best way to learn and experiment
4. **Build Something** - Create your own NanoCore programs!

Happy coding! 🚀