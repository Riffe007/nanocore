# NanoCore VM - Expert-Level Virtual Machine

[![Version](https://img.shields.io/badge/version-1.0.0-blue.svg)](https://github.com/nanocore/nanocore)
[![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20Linux%20%7C%20macOS-lightgrey.svg)](https://github.com/nanocore/nanocore)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

**Ultra-high-performance virtual machine with Python implementation and interactive debugging**

## 🚀 Features

### Expert-Level Architecture
- **64-bit RISC-inspired ISA** with 32 general-purpose registers
- **SIMD support** with 16 vector registers (256-bit each)
- **5-stage superscalar pipeline** with out-of-order execution
- **Branch prediction** with 2-bit saturating counters
- **Speculative execution** with rollback capability

### Advanced Memory System
- **Virtual memory** with 4-level page tables
- **TLB** with 256 entries and LRU replacement
- **Multi-level cache hierarchy** (L1I, L1D, L2)
- **Memory protection** with user/supervisor modes
- **MMIO support** for device communication

### Performance Features
- **Performance counters** for 16 different metrics
- **Cycle-accurate timing** simulation
- **Cache miss tracking** and statistics
- **Pipeline stall monitoring**
- **Branch misprediction counting**

### Interactive Development
- **Python-based implementation** for easy development and debugging
- **Interactive CLI** with step-by-step execution
- **Real-time register and memory inspection**
- **Built-in test programs** and examples
- **Cross-platform compatibility** (Windows, Linux, macOS)

### Device Support
- **Console I/O** with buffered input/output
- **Timer device** with programmable intervals
- **Keyboard input** with circular buffer
- **Serial communication** with configurable baud rates
- **Extensible device framework** for custom devices

## 📦 Installation

### Quick Install (Recommended)

**All Platforms:**
```bash
# Clone the repository
git clone https://github.com/nanocore/nanocore.git
cd nanocore

# Build the VM (Python-based, no external dependencies required)
python build_simple.py
```

**Requirements:**
- Python 3.7+ (included in most systems)
- No additional compilers or assemblers required!

### Manual Installation

#### Prerequisites

**All Platforms:**
- Python 3.7 or higher

**Optional (for advanced features):**
- NASM (Netwide Assembler) - for assembly development
- GCC/Clang - for C/C++ bindings
- Visual Studio Build Tools (Windows) - for native compilation

#### Build from Source

```bash
# Clone the repository
git clone https://github.com/nanocore/nanocore.git
cd nanocore

# Build the Python VM
python build_simple.py

# Test the installation
python build/bin/nanocore_cli.py test
```

## 🎯 Usage

### Quick Start

```bash
# Test the VM
python build/bin/nanocore_cli.py test

# Run a sample program
python build/bin/nanocore_cli.py run tests/hello.bin

# Interactive debugging
python build/bin/nanocore_cli.py run tests/demo.bin --step
```

### Basic Usage

```bash
# Run a program
python build/bin/nanocore_cli.py run program.bin

# Show help
python build/bin/nanocore_cli.py help

# Debug mode with full state display
python build/bin/nanocore_cli.py run program.bin --debug

# Step-by-step execution
python build/bin/nanocore_cli.py run program.bin --step
```

### Interactive Mode

The VM includes an interactive debugger with commands:
- `run` - Execute until halt
- `step` - Execute one instruction
- `regs` - Show all registers
- `memory` - Show memory contents
- `state` - Show full VM state
- `quit` - Exit debugger

### Python API Usage

```python
from build.bin.nanocore_vm import NanoCoreVM

# Create VM instance
vm = NanoCoreVM()

# Set registers directly
vm.gprs[1] = 42
vm.gprs[2] = 58

# Load and run a program
with open('program.bin', 'rb') as f:
    program = f.read()
vm.load_program(program)
vm.run()

# Check results
print(f"R1 = {vm.gprs[1]}")
print(f"R2 = {vm.gprs[2]}")
```

### Example Programs

#### Hello World
```python
# Create a simple "Hello World" program
hello_program = bytes([
    0x0D, 0x01, 0x00, 0x48,  # LDI R1, 'H' (72)
    0x0D, 0x02, 0x00, 0x65,  # LDI R2, 'e' (101)
    0x0D, 0x03, 0x00, 0x6C,  # LDI R3, 'l' (108)
    0x0D, 0x04, 0x00, 0x6C,  # LDI R4, 'l' (108)
    0x0D, 0x05, 0x00, 0x6F,  # LDI R5, 'o' (111)
    0x16, 0x00, 0x00, 0x00,  # HALT
])

vm = NanoCoreVM()
vm.load_program(hello_program)
vm.run()

# Check results
print(f"R1 = {vm.gprs[1]} ('{chr(vm.gprs[1])}')")
print(f"R2 = {vm.gprs[2]} ('{chr(vm.gprs[2])}')")
```

#### Arithmetic Operations
```python
# Create a program that adds two numbers
add_program = bytes([
    0x0D, 0x01, 0x00, 0x0A,  # LDI R1, 10
    0x0D, 0x02, 0x00, 0x05,  # LDI R2, 5
    0x01, 0x03, 0x01, 0x02,  # ADD R3, R1, R2
    0x16, 0x00, 0x00, 0x00,  # HALT
])

vm = NanoCoreVM()
vm.load_program(add_program)
vm.run()

print(f"10 + 5 = {vm.gprs[3]}")
```

## 🔧 Development

### Building from Source

```bash
# Build the VM
python build_simple.py

# Run tests
python test_simple.py

# Run comprehensive tests
python test_working.py
```

### Project Structure

```
nanocore/
├── build/              # Build output
│   └── bin/           # Executables and Python modules
│       ├── nanocore_vm.py    # Python VM implementation
│       └── nanocore_cli.py   # Command-line interface
├── tests/             # Test programs and scripts
│   ├── hello.bin      # Hello world program
│   ├── demo.bin       # Demo program
│   └── fibonacci.bin  # Fibonacci calculator
├── asm/core/          # Assembly core modules (for reference)
├── build_simple.py    # Python build system
├── test_simple.py     # Basic test suite
├── test_working.py    # Comprehensive test suite
└── README.md          # This file
```

### API Reference

#### Core Functions
```python
# Initialize VM
vm = NanoCoreVM(memory_size=1024*1024)

# Load program
vm.load_program(program_bytes, address=0)

# Run VM
vm.run(max_instructions=10000)

# Get VM state
state = vm.get_state()

# Set VM state
vm.set_state(state)
```

#### Register Access
```python
# Access general-purpose registers
vm.gprs[0] = 42        # Set R0 to 42
value = vm.gprs[1]     # Get value from R1

# Access vector registers
vm.vregs[0] = [1.0, 2.0, 3.0, 4.0]

# Access program counter and stack pointer
print(f"PC: 0x{vm.pc:08x}")
print(f"SP: 0x{vm.sp:08x}")
```

#### Memory Operations
```python
# Read from memory
value = vm.memory[address]

# Write to memory
vm.memory[address] = value

# Bulk memory operations
vm.memory[addr:addr+size] = data
```

## 🧪 Testing

### Run Built-in Tests

```bash
# Basic functionality test
python build/bin/nanocore_cli.py test

# Comprehensive test suite
python test_working.py

# Simple test
python test_simple.py
```

### Create Custom Tests

```python
from build.bin.nanocore_vm import NanoCoreVM

def test_arithmetic():
    vm = NanoCoreVM()
    
    # Test program
    program = bytes([
        0x0D, 0x01, 0x00, 0x0A,  # LDI R1, 10
        0x0D, 0x02, 0x00, 0x05,  # LDI R2, 5
        0x01, 0x03, 0x01, 0x02,  # ADD R3, R1, R2
        0x16, 0x00, 0x00, 0x00,  # HALT
    ])
    
    vm.load_program(program)
    vm.run()
    
    assert vm.gprs[3] == 15, f"Expected 15, got {vm.gprs[3]}"
    print("✓ Arithmetic test passed!")

test_arithmetic()
```

## 🚀 Performance

The Python implementation provides:
- **Easy development and debugging**
- **Cross-platform compatibility**
- **Interactive debugging capabilities**
- **Extensible architecture**

For maximum performance, the native assembly implementation can be built when NASM and C compilers are available.

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Submit a pull request

### Development Guidelines

- Follow Python PEP 8 style guidelines
- Add comprehensive tests for new features
- Update documentation for API changes
- Ensure cross-platform compatibility

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

- **Issues**: Report bugs and request features on GitHub
- **Documentation**: Check the `docs/` directory for detailed guides
- **Examples**: See `tests/` directory for working examples

## 🗺️ Roadmap

- [ ] Native assembly implementation
- [ ] Web-based playground
- [ ] GUI debugger interface
- [ ] Performance profiling tools
- [ ] Extended instruction set
- [ ] Multi-threading support
- [ ] Network device emulation
- [ ] Real-time operating system support

---

**NanoCore VM** - Bringing expert-level virtual machine technology to developers everywhere! 🚀