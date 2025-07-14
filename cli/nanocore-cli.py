#!/usr/bin/env python3
"""
NanoCore CLI Tool

A command-line interface for the NanoCore VM that provides:
- Assembly and disassembly
- VM execution and debugging
- Performance profiling
- Memory inspection
- Batch processing

Usage:
    nanocore-cli.py assemble input.nc -o output.bin
    nanocore-cli.py run program.bin --debug
    nanocore-cli.py disasm program.bin
    nanocore-cli.py profile program.bin --cycles 1000000
"""

import sys
import os
import argparse
import time
import json
from pathlib import Path
from typing import Optional, List, Dict, Any

# Add parent directory to path for imports
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

try:
    # Import what's available - some modules may not have the expected classes
    import assembler.nanocore_asm as asm_module
    from glue.python.nanocore import VM, Status, EventType, PerfCounter
    # Use our own simple VM simulator instead of the framework one
    class SimpleVMSimulator:
        def __init__(self, memory_size=1024*1024):
            self.memory = bytearray(memory_size)
            self.registers = [0] * 32
            self.pc = 0
            self.halted = False
            
        def load_program(self, program, start_addr=0):
            self.memory[start_addr:start_addr + len(program)] = program
            self.pc = start_addr
    
    VMSimulator = SimpleVMSimulator
    
except ImportError as e:
    print(f"Error importing NanoCore modules: {e}")
    print("Make sure you're running from the NanoCore root directory")
    sys.exit(1)

class NanoCoreCLI:
    """Main CLI application class"""
    
    def __init__(self):
        self.vm = None
        self.debug_mode = False
        self.breakpoints = set()
        
    def assemble(self, input_file: str, output_file: str = None, verbose: bool = False) -> bool:
        """Assemble source file to bytecode"""
        try:
            input_path = Path(input_file)
            if not input_path.exists():
                print(f"Error: Input file '{input_file}' not found")
                return False
                
            if output_file is None:
                output_file = input_path.with_suffix('.bin')
            
            print(f"Assembling {input_file} -> {output_file}")
            
            # For now, just copy the file (simplified implementation)
            # In a full implementation, this would call a proper assembler
            print("Note: Using simplified assembler (copying file)")
            with open(input_file, 'rb') as f:
                bytecode = f.read()
            
            # Write output
            with open(output_file, 'wb') as f:
                f.write(bytecode)
                
            print(f"Successfully assembled {len(bytecode)} bytes")
            
            if verbose:
                print(f"\\nBytecode hex dump:")
                for i in range(0, len(bytecode), 16):
                    chunk = bytecode[i:i+16]
                    hex_str = ' '.join(f'{b:02x}' for b in chunk)
                    print(f"  {i:04x}: {hex_str}")
                    
            return True
            
        except Exception as e:
            print(f"Assembly failed: {e}")
            return False
    
    def disassemble(self, input_file: str, output_file: str = None, start_addr: int = 0) -> bool:
        """Disassemble bytecode to assembly"""
        try:
            input_path = Path(input_file)
            if not input_path.exists():
                print(f"Error: Input file '{input_file}' not found")
                return False
                
            with open(input_file, 'rb') as f:
                bytecode = f.read()
                
            print(f"Disassembling {input_file} ({len(bytecode)} bytes)")
            
            # Simple disassembler
            assembly = self._disassemble_bytecode(bytecode, start_addr)
            
            if output_file:
                with open(output_file, 'w') as f:
                    f.write(assembly)
                print(f"Disassembly written to {output_file}")
            else:
                print("\\nDisassembly:")
                print(assembly)
                
            return True
            
        except Exception as e:
            print(f"Disassembly failed: {e}")
            return False
    
    def _disassemble_bytecode(self, bytecode: bytes, start_addr: int = 0) -> str:
        """Simple disassembler for bytecode"""
        lines = []
        addr = start_addr
        
        # Instruction names mapping
        opcodes = {
            0x00: 'ADD', 0x01: 'SUB', 0x02: 'MUL', 0x04: 'DIV', 0x05: 'MOD',
            0x06: 'AND', 0x07: 'OR', 0x08: 'XOR', 0x0A: 'SHL', 0x0B: 'SHR',
            0x0F: 'LD', 0x13: 'ST', 0x17: 'BEQ', 0x18: 'BNE', 0x19: 'BLT',
            0x21: 'HALT', 0x22: 'NOP'
        }
        
        for i in range(0, len(bytecode), 4):
            if i + 4 > len(bytecode):
                break
                
            # Read 32-bit instruction
            inst = int.from_bytes(bytecode[i:i+4], 'little')
            
            opcode = (inst >> 26) & 0x3F
            rd = (inst >> 21) & 0x1F
            rs1 = (inst >> 16) & 0x1F
            rs2 = (inst >> 11) & 0x1F
            imm = inst & 0xFFFF
            
            # Sign extend immediate
            if imm & 0x8000:
                imm |= 0xFFFF0000
                imm = imm - 0x100000000
            
            # Format instruction
            mnemonic = opcodes.get(opcode, f'UNK_{opcode:02x}')
            
            if opcode in [0x00, 0x01, 0x02, 0x04, 0x05, 0x06, 0x07, 0x08, 0x0A, 0x0B]:
                # R-type: op rd, rs1, rs2
                line = f"{addr:08x}: {inst:08x}  {mnemonic} r{rd}, r{rs1}, r{rs2}"
            elif opcode in [0x0F, 0x13]:
                # I-type: op rd, imm(rs1)
                line = f"{addr:08x}: {inst:08x}  {mnemonic} r{rd}, {imm}(r{rs1})"
            elif opcode in [0x17, 0x18, 0x19]:
                # Branch: op rs1, rs2, offset
                line = f"{addr:08x}: {inst:08x}  {mnemonic} r{rd}, r{rs1}, {imm}"
            elif opcode in [0x21, 0x22]:
                # No operands
                line = f"{addr:08x}: {inst:08x}  {mnemonic}"
            else:
                line = f"{addr:08x}: {inst:08x}  {mnemonic} {rd}, {rs1}, {rs2}, {imm}"
            
            lines.append(line)
            addr += 4
            
        return '\\n'.join(lines)
    
    def run(self, program_file: str, debug: bool = False, max_cycles: int = 0, 
            memory_size: int = 64 * 1024 * 1024) -> bool:
        """Run a program on the VM"""
        try:
            # Load program
            with open(program_file, 'rb') as f:
                program = f.read()
            
            print(f"Loading program {program_file} ({len(program)} bytes)")
            
            # Create VM
            self.vm = VM(memory_size)
            self.debug_mode = debug
            
            # Load program at default address
            self.vm.load_program(program, 0x10000)
            
            if debug:
                print("Debug mode enabled. Use 'h' for help.")
                return self._run_debug_mode(max_cycles)
            else:
                return self._run_normal_mode(max_cycles)
                
        except Exception as e:
            print(f"Execution failed: {e}")
            return False
    
    def _run_normal_mode(self, max_cycles: int) -> bool:
        """Run VM in normal mode"""
        print("Running program...")
        start_time = time.time()
        
        try:
            result = self.vm.run(max_cycles)
            
            end_time = time.time()
            elapsed = end_time - start_time
            
            if result == EventType.HALTED:
                print(f"Program completed successfully in {elapsed:.3f}s")
                self._print_final_state()
                return True
            else:
                print(f"Program ended with status: {result}")
                self._print_final_state()
                return False
                
        except Exception as e:
            print(f"Runtime error: {e}")
            return False
    
    def _run_debug_mode(self, max_cycles: int) -> bool:
        """Run VM in debug mode with interactive controls"""
        print("Entering debug mode...")
        
        cycle_count = 0
        
        while cycle_count < max_cycles or max_cycles == 0:
            try:
                # Get current state
                state = self.vm.state
                
                # Check for breakpoints
                if state.pc in self.breakpoints:
                    print(f"Breakpoint hit at 0x{state.pc:08x}")
                    self.breakpoints.remove(state.pc)
                    
                # Show current instruction
                memory = self.vm.read_memory(state.pc, 4)
                inst = int.from_bytes(memory, 'little')
                print(f"PC: 0x{state.pc:08x}  Instruction: 0x{inst:08x}")
                
                # Interactive debug prompt
                cmd = input("(nanocore-debug) ").strip().lower()
                
                if cmd == 'h' or cmd == 'help':
                    self._print_debug_help()
                elif cmd == 's' or cmd == 'step':
                    result = self.vm.step()
                    if result == EventType.HALTED:
                        print("Program halted")
                        break
                    cycle_count += 1
                elif cmd == 'c' or cmd == 'continue':
                    result = self.vm.run(max_cycles - cycle_count)
                    if result == EventType.HALTED:
                        print("Program halted")
                        break
                    cycle_count = max_cycles
                elif cmd == 'r' or cmd == 'registers':
                    self._print_registers()
                elif cmd == 'q' or cmd == 'quit':
                    print("Quitting debugger")
                    break
                elif cmd.startswith('b '):
                    # Set breakpoint
                    try:
                        addr = int(cmd[2:], 16)
                        self.breakpoints.add(addr)
                        print(f"Breakpoint set at 0x{addr:08x}")
                    except ValueError:
                        print("Invalid address")
                elif cmd.startswith('m '):
                    # Memory dump
                    try:
                        addr = int(cmd[2:], 16)
                        self._print_memory(addr, 64)
                    except ValueError:
                        print("Invalid address")
                else:
                    print("Unknown command. Type 'h' for help.")
                    
            except KeyboardInterrupt:
                print("\\nDebug interrupted")
                break
            except Exception as e:
                print(f"Debug error: {e}")
                break
                
        return True
    
    def _print_debug_help(self):
        """Print debug help"""
        print("""
Debug Commands:
  h, help       - Show this help
  s, step       - Execute one instruction
  c, continue   - Continue execution
  r, registers  - Show register values
  b <addr>      - Set breakpoint at address (hex)
  m <addr>      - Memory dump starting at address (hex)
  q, quit       - Quit debugger
""")
    
    def _print_registers(self):
        """Print register values"""
        print("Registers:")
        for i in range(0, 32, 4):
            line = "  "
            for j in range(4):
                if i + j < 32:
                    reg_val = self.vm.registers[i + j]
                    line += f"R{i+j:02d}=0x{reg_val:016x} "
            print(line)
    
    def _print_memory(self, addr: int, size: int):
        """Print memory dump"""
        try:
            memory = self.vm.read_memory(addr, size)
            print(f"Memory dump from 0x{addr:08x}:")
            
            for i in range(0, len(memory), 16):
                chunk = memory[i:i+16]
                hex_str = ' '.join(f'{b:02x}' for b in chunk)
                ascii_str = ''.join(chr(b) if 32 <= b < 127 else '.' for b in chunk)
                print(f"  {addr+i:08x}: {hex_str:<48} {ascii_str}")
                
        except Exception as e:
            print(f"Memory read error: {e}")
    
    def _print_final_state(self):
        """Print final VM state"""
        print("\\nFinal State:")
        try:
            # Performance counters
            inst_count = self.vm.get_perf_counter(PerfCounter.INST_COUNT)
            cycle_count = self.vm.get_perf_counter(PerfCounter.CYCLE_COUNT)
            
            print(f"  Instructions executed: {inst_count:,}")
            print(f"  Cycles: {cycle_count:,}")
            
            if cycle_count > 0:
                print(f"  IPC: {inst_count/cycle_count:.2f}")
                
            # Non-zero registers
            print("  Non-zero registers:")
            for i in range(32):
                val = self.vm.registers[i]
                if val != 0:
                    print(f"    R{i:02d} = 0x{val:016x} ({val})")
                    
        except Exception as e:
            print(f"Error getting final state: {e}")
    
    def profile(self, program_file: str, cycles: int = 1000000) -> bool:
        """Profile program execution"""
        try:
            with open(program_file, 'rb') as f:
                program = f.read()
            
            print(f"Profiling {program_file} for {cycles:,} cycles...")
            
            # Create VM
            self.vm = VM(64 * 1024 * 1024)
            self.vm.load_program(program, 0x10000)
            
            # Run profiling
            start_time = time.time()
            result = self.vm.run(cycles)
            end_time = time.time()
            
            elapsed = end_time - start_time
            
            # Get performance counters
            inst_count = self.vm.get_perf_counter(PerfCounter.INST_COUNT)
            cycle_count = self.vm.get_perf_counter(PerfCounter.CYCLE_COUNT)
            l1_misses = self.vm.get_perf_counter(PerfCounter.L1_MISS)
            l2_misses = self.vm.get_perf_counter(PerfCounter.L2_MISS)
            branch_misses = self.vm.get_perf_counter(PerfCounter.BRANCH_MISS)
            pipeline_stalls = self.vm.get_perf_counter(PerfCounter.PIPELINE_STALL)
            
            # Print profile results
            print(f"\\nProfile Results:")
            print(f"  Execution time: {elapsed:.3f}s")
            print(f"  Instructions: {inst_count:,}")
            print(f"  Cycles: {cycle_count:,}")
            print(f"  IPC: {inst_count/max(cycle_count, 1):.2f}")
            print(f"  Instructions/sec: {inst_count/elapsed:,.0f}")
            print(f"  L1 cache misses: {l1_misses:,}")
            print(f"  L2 cache misses: {l2_misses:,}")
            print(f"  Branch misses: {branch_misses:,}")
            print(f"  Pipeline stalls: {pipeline_stalls:,}")
            
            return result == EventType.HALTED
            
        except Exception as e:
            print(f"Profiling failed: {e}")
            return False

def main():
    """Main CLI entry point"""
    parser = argparse.ArgumentParser(description='NanoCore VM Command Line Interface')
    subparsers = parser.add_subparsers(dest='command', help='Available commands')
    
    # Assemble command
    asm_parser = subparsers.add_parser('assemble', help='Assemble source to bytecode')
    asm_parser.add_argument('input', help='Input assembly file')
    asm_parser.add_argument('-o', '--output', help='Output bytecode file')
    asm_parser.add_argument('-v', '--verbose', action='store_true', help='Verbose output')
    
    # Disassemble command
    disasm_parser = subparsers.add_parser('disasm', help='Disassemble bytecode')
    disasm_parser.add_argument('input', help='Input bytecode file')
    disasm_parser.add_argument('-o', '--output', help='Output assembly file')
    disasm_parser.add_argument('-a', '--address', type=lambda x: int(x, 16), default=0, help='Start address (hex)')
    
    # Run command
    run_parser = subparsers.add_parser('run', help='Run program')
    run_parser.add_argument('program', help='Program bytecode file')
    run_parser.add_argument('-d', '--debug', action='store_true', help='Enable debug mode')
    run_parser.add_argument('-c', '--cycles', type=int, default=0, help='Max cycles (0 = unlimited)')
    run_parser.add_argument('-m', '--memory', type=int, default=64*1024*1024, help='Memory size in bytes')
    
    # Profile command
    profile_parser = subparsers.add_parser('profile', help='Profile program execution')
    profile_parser.add_argument('program', help='Program bytecode file')
    profile_parser.add_argument('-c', '--cycles', type=int, default=1000000, help='Cycles to profile')
    
    args = parser.parse_args()
    
    if not args.command:
        parser.print_help()
        return 1
    
    # Create CLI instance
    cli = NanoCoreCLI()
    
    # Execute command
    try:
        if args.command == 'assemble':
            success = cli.assemble(args.input, args.output, args.verbose)
        elif args.command == 'disasm':
            success = cli.disassemble(args.input, args.output, args.address)
        elif args.command == 'run':
            success = cli.run(args.program, args.debug, args.cycles, args.memory)
        elif args.command == 'profile':
            success = cli.profile(args.program, args.cycles)
        else:
            print(f"Unknown command: {args.command}")
            return 1
            
        return 0 if success else 1
        
    except KeyboardInterrupt:
        print("\\nInterrupted by user")
        return 1
    except Exception as e:
        print(f"Fatal error: {e}")
        return 1

if __name__ == '__main__':
    sys.exit(main())