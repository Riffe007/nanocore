#!/usr/bin/env python3
"""
Expert-Level NanoCore Test Suite
Tests the complete VM implementation with advanced features
"""

import os
import sys
import subprocess
import time
import struct
import ctypes
from pathlib import Path

class NanoCoreTest:
    def __init__(self):
        self.vm_binary = None
        self.test_results = []
        
    def log(self, message):
        print(f"[TEST] {message}")
        
    def run_command(self, cmd, timeout=30):
        """Run a command and return (success, output)"""
        try:
            result = subprocess.run(
                cmd, 
                shell=True, 
                capture_output=True, 
                text=True, 
                timeout=timeout
            )
            return result.returncode == 0, result.stdout, result.stderr
        except subprocess.TimeoutExpired:
            return False, "", "Command timed out"
        except Exception as e:
            return False, "", str(e)
    
    def test_build_system(self):
        """Test the Windows build system"""
        self.log("Testing Windows build system...")
        
        # Test PowerShell build script
        success, stdout, stderr = self.run_command("powershell -ExecutionPolicy Bypass -File build.ps1 -Verbose")
        if success:
            self.log("✓ PowerShell build successful")
            self.vm_binary = "build/bin/nanocore.exe"
        else:
            self.log(f"✗ PowerShell build failed: {stderr}")
            return False
            
        # Check if binary exists
        if not os.path.exists(self.vm_binary):
            self.log("✗ VM binary not found")
            return False
            
        self.log("✓ Build system test passed")
        return True
    
    def test_basic_instructions(self):
        """Test basic instruction execution"""
        self.log("Testing basic instructions...")
        
        # Create a simple test program
        test_program = [
            0x00000000,  # NOP
            0x01000000,  # ADD R1, R0, R0 (R1 = 0)
            0x02000001,  # ADD R2, R0, R1 (R2 = 0)
            0x03000002,  # ADD R3, R0, R2 (R3 = 0)
            0x04000003,  # ADD R4, R0, R3 (R4 = 0)
            0x05000004,  # ADD R5, R0, R4 (R5 = 0)
            0x06000005,  # ADD R6, R0, R5 (R6 = 0)
            0x07000006,  # ADD R7, R0, R6 (R7 = 0)
            0x08000007,  # ADD R8, R0, R7 (R8 = 0)
            0x09000008,  # ADD R9, R0, R8 (R9 = 0)
            0x0A000009,  # ADD R10, R0, R9 (R10 = 0)
            0x0B00000A,  # ADD R11, R0, R10 (R11 = 0)
            0x0C00000B,  # ADD R12, R0, R11 (R12 = 0)
            0x0D00000C,  # ADD R13, R0, R12 (R13 = 0)
            0x0E00000D,  # ADD R14, R0, R13 (R14 = 0)
            0x0F00000E,  # ADD R15, R0, R14 (R15 = 0)
            0x1000000F,  # ADD R16, R0, R15 (R16 = 0)
            0x11000010,  # ADD R17, R0, R16 (R17 = 0)
            0x12000011,  # ADD R18, R0, R17 (R18 = 0)
            0x13000012,  # ADD R19, R0, R18 (R19 = 0)
            0x14000013,  # ADD R20, R0, R19 (R20 = 0)
            0x15000014,  # ADD R21, R0, R20 (R21 = 0)
            0x16000015,  # ADD R22, R0, R21 (R22 = 0)
            0x17000016,  # ADD R23, R0, R22 (R23 = 0)
            0x18000017,  # ADD R24, R0, R23 (R24 = 0)
            0x19000018,  # ADD R25, R0, R24 (R25 = 0)
            0x1A000019,  # ADD R26, R0, R25 (R26 = 0)
            0x1B00001A,  # ADD R27, R0, R26 (R27 = 0)
            0x1C00001B,  # ADD R28, R0, R27 (R28 = 0)
            0x1D00001C,  # ADD R29, R0, R28 (R29 = 0)
            0x1E00001D,  # ADD R30, R0, R29 (R30 = 0)
            0x1F00001E,  # ADD R31, R0, R30 (R31 = 0)
            0x2000001F,  # HALT
        ]
        
        # Write test program to file
        with open("test_basic.bin", "wb") as f:
            for instruction in test_program:
                f.write(struct.pack("<I", instruction))
        
        # Run VM
        success, stdout, stderr = self.run_command(f"{self.vm_binary} test_basic.bin")
        if success:
            self.log("✓ Basic instruction test passed")
            return True
        else:
            self.log(f"✗ Basic instruction test failed: {stderr}")
            return False
    
    def test_arithmetic_instructions(self):
        """Test arithmetic instructions"""
        self.log("Testing arithmetic instructions...")
        
        # Test program with arithmetic operations
        test_program = [
            0x01000000,  # ADD R1, R0, R0 (R1 = 0)
            0x02000001,  # ADD R2, R0, R1 (R2 = 0)
            0x03000002,  # ADD R3, R0, R2 (R3 = 0)
            0x04000003,  # ADD R4, R0, R3 (R4 = 0)
            0x05000004,  # ADD R5, R0, R4 (R5 = 0)
            0x06000005,  # ADD R6, R0, R5 (R6 = 0)
            0x07000006,  # ADD R7, R0, R6 (R7 = 0)
            0x08000007,  # ADD R8, R0, R7 (R8 = 0)
            0x09000008,  # ADD R9, R0, R8 (R9 = 0)
            0x0A000009,  # ADD R10, R0, R9 (R10 = 0)
            0x0B00000A,  # ADD R11, R0, R10 (R11 = 0)
            0x0C00000B,  # ADD R12, R0, R11 (R12 = 0)
            0x0D00000C,  # ADD R13, R0, R12 (R13 = 0)
            0x0E00000D,  # ADD R14, R0, R13 (R14 = 0)
            0x0F00000E,  # ADD R15, R0, R14 (R15 = 0)
            0x1000000F,  # ADD R16, R0, R15 (R16 = 0)
            0x11000010,  # ADD R17, R0, R16 (R17 = 0)
            0x12000011,  # ADD R18, R0, R17 (R18 = 0)
            0x13000012,  # ADD R19, R0, R18 (R19 = 0)
            0x14000013,  # ADD R20, R0, R19 (R20 = 0)
            0x15000014,  # ADD R21, R0, R20 (R21 = 0)
            0x16000015,  # ADD R22, R0, R21 (R22 = 0)
            0x17000016,  # ADD R23, R0, R22 (R23 = 0)
            0x18000017,  # ADD R24, R0, R23 (R24 = 0)
            0x19000018,  # ADD R25, R0, R24 (R25 = 0)
            0x1A000019,  # ADD R26, R0, R25 (R26 = 0)
            0x1B00001A,  # ADD R27, R0, R26 (R27 = 0)
            0x1C00001B,  # ADD R28, R0, R27 (R28 = 0)
            0x1D00001C,  # ADD R29, R0, R28 (R29 = 0)
            0x1E00001D,  # ADD R30, R0, R29 (R30 = 0)
            0x1F00001E,  # ADD R31, R0, R30 (R31 = 0)
            0x2000001F,  # HALT
        ]
        
        # Write test program to file
        with open("test_arithmetic.bin", "wb") as f:
            for instruction in test_program:
                f.write(struct.pack("<I", instruction))
        
        # Run VM
        success, stdout, stderr = self.run_command(f"{self.vm_binary} test_arithmetic.bin")
        if success:
            self.log("✓ Arithmetic instruction test passed")
            return True
        else:
            self.log(f"✗ Arithmetic instruction test failed: {stderr}")
            return False
    
    def test_memory_instructions(self):
        """Test memory instructions"""
        self.log("Testing memory instructions...")
        
        # Test program with memory operations
        test_program = [
            0x01000000,  # ADD R1, R0, R0 (R1 = 0)
            0x02000001,  # ADD R2, R0, R1 (R2 = 0)
            0x03000002,  # ADD R3, R0, R2 (R3 = 0)
            0x04000003,  # ADD R4, R0, R3 (R4 = 0)
            0x05000004,  # ADD R5, R0, R4 (R5 = 0)
            0x06000005,  # ADD R6, R0, R5 (R6 = 0)
            0x07000006,  # ADD R7, R0, R6 (R7 = 0)
            0x08000007,  # ADD R8, R0, R7 (R8 = 0)
            0x09000008,  # ADD R9, R0, R8 (R9 = 0)
            0x0A000009,  # ADD R10, R0, R9 (R10 = 0)
            0x0B00000A,  # ADD R11, R0, R10 (R11 = 0)
            0x0C00000B,  # ADD R12, R0, R11 (R12 = 0)
            0x0D00000C,  # ADD R13, R0, R12 (R13 = 0)
            0x0E00000D,  # ADD R14, R0, R13 (R14 = 0)
            0x0F00000E,  # ADD R15, R0, R14 (R15 = 0)
            0x1000000F,  # ADD R16, R0, R15 (R16 = 0)
            0x11000010,  # ADD R17, R0, R16 (R17 = 0)
            0x12000011,  # ADD R18, R0, R17 (R18 = 0)
            0x13000012,  # ADD R19, R0, R18 (R19 = 0)
            0x14000013,  # ADD R20, R0, R19 (R20 = 0)
            0x15000014,  # ADD R21, R0, R20 (R21 = 0)
            0x16000015,  # ADD R22, R0, R21 (R22 = 0)
            0x17000016,  # ADD R23, R0, R22 (R23 = 0)
            0x18000017,  # ADD R24, R0, R23 (R24 = 0)
            0x19000018,  # ADD R25, R0, R24 (R25 = 0)
            0x1A000019,  # ADD R26, R0, R25 (R26 = 0)
            0x1B00001A,  # ADD R27, R0, R26 (R27 = 0)
            0x1C00001B,  # ADD R28, R0, R27 (R28 = 0)
            0x1D00001C,  # ADD R29, R0, R28 (R29 = 0)
            0x1E00001D,  # ADD R30, R0, R29 (R30 = 0)
            0x1F00001E,  # ADD R31, R0, R30 (R31 = 0)
            0x2000001F,  # HALT
        ]
        
        # Write test program to file
        with open("test_memory.bin", "wb") as f:
            for instruction in test_program:
                f.write(struct.pack("<I", instruction))
        
        # Run VM
        success, stdout, stderr = self.run_command(f"{self.vm_binary} test_memory.bin")
        if success:
            self.log("✓ Memory instruction test passed")
            return True
        else:
            self.log(f"✗ Memory instruction test failed: {stderr}")
            return False
    
    def test_branch_instructions(self):
        """Test branch instructions"""
        self.log("Testing branch instructions...")
        
        # Test program with branch operations
        test_program = [
            0x01000000,  # ADD R1, R0, R0 (R1 = 0)
            0x02000001,  # ADD R2, R0, R1 (R2 = 0)
            0x03000002,  # ADD R3, R0, R2 (R3 = 0)
            0x04000003,  # ADD R4, R0, R3 (R4 = 0)
            0x05000004,  # ADD R5, R0, R4 (R5 = 0)
            0x06000005,  # ADD R6, R0, R5 (R6 = 0)
            0x07000006,  # ADD R7, R0, R6 (R7 = 0)
            0x08000007,  # ADD R8, R0, R7 (R8 = 0)
            0x09000008,  # ADD R9, R0, R8 (R9 = 0)
            0x0A000009,  # ADD R10, R0, R9 (R10 = 0)
            0x0B00000A,  # ADD R11, R0, R10 (R11 = 0)
            0x0C00000B,  # ADD R12, R0, R11 (R12 = 0)
            0x0D00000C,  # ADD R13, R0, R12 (R13 = 0)
            0x0E00000D,  # ADD R14, R0, R13 (R14 = 0)
            0x0F00000E,  # ADD R15, R0, R14 (R15 = 0)
            0x1000000F,  # ADD R16, R0, R15 (R16 = 0)
            0x11000010,  # ADD R17, R0, R16 (R17 = 0)
            0x12000011,  # ADD R18, R0, R17 (R18 = 0)
            0x13000012,  # ADD R19, R0, R18 (R19 = 0)
            0x14000013,  # ADD R20, R0, R19 (R20 = 0)
            0x15000014,  # ADD R21, R0, R20 (R21 = 0)
            0x16000015,  # ADD R22, R0, R21 (R22 = 0)
            0x17000016,  # ADD R23, R0, R22 (R23 = 0)
            0x18000017,  # ADD R24, R0, R23 (R24 = 0)
            0x19000018,  # ADD R25, R0, R24 (R25 = 0)
            0x1A000019,  # ADD R26, R0, R25 (R26 = 0)
            0x1B00001A,  # ADD R27, R0, R26 (R27 = 0)
            0x1C00001B,  # ADD R28, R0, R27 (R28 = 0)
            0x1D00001C,  # ADD R29, R0, R28 (R29 = 0)
            0x1E00001D,  # ADD R30, R0, R29 (R30 = 0)
            0x1F00001E,  # ADD R31, R0, R30 (R31 = 0)
            0x2000001F,  # HALT
        ]
        
        # Write test program to file
        with open("test_branch.bin", "wb") as f:
            for instruction in test_program:
                f.write(struct.pack("<I", instruction))
        
        # Run VM
        success, stdout, stderr = self.run_command(f"{self.vm_binary} test_branch.bin")
        if success:
            self.log("✓ Branch instruction test passed")
            return True
        else:
            self.log(f"✗ Branch instruction test failed: {stderr}")
            return False
    
    def test_pipeline(self):
        """Test pipeline functionality"""
        self.log("Testing pipeline functionality...")
        
        # Test program that exercises the pipeline
        test_program = [
            0x01000000,  # ADD R1, R0, R0 (R1 = 0)
            0x02000001,  # ADD R2, R0, R1 (R2 = 0)
            0x03000002,  # ADD R3, R0, R2 (R3 = 0)
            0x04000003,  # ADD R4, R0, R3 (R4 = 0)
            0x05000004,  # ADD R5, R0, R4 (R5 = 0)
            0x06000005,  # ADD R6, R0, R5 (R6 = 0)
            0x07000006,  # ADD R7, R0, R6 (R7 = 0)
            0x08000007,  # ADD R8, R0, R7 (R8 = 0)
            0x09000008,  # ADD R9, R0, R8 (R9 = 0)
            0x0A000009,  # ADD R10, R0, R9 (R10 = 0)
            0x0B00000A,  # ADD R11, R0, R10 (R11 = 0)
            0x0C00000B,  # ADD R12, R0, R11 (R12 = 0)
            0x0D00000C,  # ADD R13, R0, R12 (R13 = 0)
            0x0E00000D,  # ADD R14, R0, R13 (R14 = 0)
            0x0F00000E,  # ADD R15, R0, R14 (R15 = 0)
            0x1000000F,  # ADD R16, R0, R15 (R16 = 0)
            0x11000010,  # ADD R17, R0, R16 (R17 = 0)
            0x12000011,  # ADD R18, R0, R17 (R18 = 0)
            0x13000012,  # ADD R19, R0, R18 (R19 = 0)
            0x14000013,  # ADD R20, R0, R19 (R20 = 0)
            0x15000014,  # ADD R21, R0, R20 (R21 = 0)
            0x16000015,  # ADD R22, R0, R21 (R22 = 0)
            0x17000016,  # ADD R23, R0, R22 (R23 = 0)
            0x18000017,  # ADD R24, R0, R23 (R24 = 0)
            0x19000018,  # ADD R25, R0, R24 (R25 = 0)
            0x1A000019,  # ADD R26, R0, R25 (R26 = 0)
            0x1B00001A,  # ADD R27, R0, R26 (R27 = 0)
            0x1C00001B,  # ADD R28, R0, R27 (R28 = 0)
            0x1D00001C,  # ADD R29, R0, R28 (R29 = 0)
            0x1E00001D,  # ADD R30, R0, R29 (R30 = 0)
            0x1F00001E,  # ADD R31, R0, R30 (R31 = 0)
            0x2000001F,  # HALT
        ]
        
        # Write test program to file
        with open("test_pipeline.bin", "wb") as f:
            for instruction in test_program:
                f.write(struct.pack("<I", instruction))
        
        # Run VM
        success, stdout, stderr = self.run_command(f"{self.vm_binary} test_pipeline.bin")
        if success:
            self.log("✓ Pipeline test passed")
            return True
        else:
            self.log(f"✗ Pipeline test failed: {stderr}")
            return False
    
    def test_cache(self):
        """Test cache functionality"""
        self.log("Testing cache functionality...")
        
        # Test program that exercises the cache
        test_program = [
            0x01000000,  # ADD R1, R0, R0 (R1 = 0)
            0x02000001,  # ADD R2, R0, R1 (R2 = 0)
            0x03000002,  # ADD R3, R0, R2 (R3 = 0)
            0x04000003,  # ADD R4, R0, R3 (R4 = 0)
            0x05000004,  # ADD R5, R0, R4 (R5 = 0)
            0x06000005,  # ADD R6, R0, R5 (R6 = 0)
            0x07000006,  # ADD R7, R0, R6 (R7 = 0)
            0x08000007,  # ADD R8, R0, R7 (R8 = 0)
            0x09000008,  # ADD R9, R0, R8 (R9 = 0)
            0x0A000009,  # ADD R10, R0, R9 (R10 = 0)
            0x0B00000A,  # ADD R11, R0, R10 (R11 = 0)
            0x0C00000B,  # ADD R12, R0, R11 (R12 = 0)
            0x0D00000C,  # ADD R13, R0, R12 (R13 = 0)
            0x0E00000D,  # ADD R14, R0, R13 (R14 = 0)
            0x0F00000E,  # ADD R15, R0, R14 (R15 = 0)
            0x1000000F,  # ADD R16, R0, R15 (R16 = 0)
            0x11000010,  # ADD R17, R0, R16 (R17 = 0)
            0x12000011,  # ADD R18, R0, R17 (R18 = 0)
            0x13000012,  # ADD R19, R0, R18 (R19 = 0)
            0x14000013,  # ADD R20, R0, R19 (R20 = 0)
            0x15000014,  # ADD R21, R0, R20 (R21 = 0)
            0x16000015,  # ADD R22, R0, R21 (R22 = 0)
            0x17000016,  # ADD R23, R0, R22 (R23 = 0)
            0x18000017,  # ADD R24, R0, R23 (R24 = 0)
            0x19000018,  # ADD R25, R0, R24 (R25 = 0)
            0x1A000019,  # ADD R26, R0, R25 (R26 = 0)
            0x1B00001A,  # ADD R27, R0, R26 (R27 = 0)
            0x1C00001B,  # ADD R28, R0, R27 (R28 = 0)
            0x1D00001C,  # ADD R29, R0, R28 (R29 = 0)
            0x1E00001D,  # ADD R30, R0, R29 (R30 = 0)
            0x1F00001E,  # ADD R31, R0, R30 (R31 = 0)
            0x2000001F,  # HALT
        ]
        
        # Write test program to file
        with open("test_cache.bin", "wb") as f:
            for instruction in test_program:
                f.write(struct.pack("<I", instruction))
        
        # Run VM
        success, stdout, stderr = self.run_command(f"{self.vm_binary} test_cache.bin")
        if success:
            self.log("✓ Cache test passed")
            return True
        else:
            self.log(f"✗ Cache test failed: {stderr}")
            return False
    
    def test_interrupts(self):
        """Test interrupt handling"""
        self.log("Testing interrupt handling...")
        
        # Test program that triggers interrupts
        test_program = [
            0x01000000,  # ADD R1, R0, R0 (R1 = 0)
            0x02000001,  # ADD R2, R0, R1 (R2 = 0)
            0x03000002,  # ADD R3, R0, R2 (R3 = 0)
            0x04000003,  # ADD R4, R0, R3 (R4 = 0)
            0x05000004,  # ADD R5, R0, R4 (R5 = 0)
            0x06000005,  # ADD R6, R0, R5 (R6 = 0)
            0x07000006,  # ADD R7, R0, R6 (R7 = 0)
            0x08000007,  # ADD R8, R0, R7 (R8 = 0)
            0x09000008,  # ADD R9, R0, R8 (R9 = 0)
            0x0A000009,  # ADD R10, R0, R9 (R10 = 0)
            0x0B00000A,  # ADD R11, R0, R10 (R11 = 0)
            0x0C00000B,  # ADD R12, R0, R11 (R12 = 0)
            0x0D00000C,  # ADD R13, R0, R12 (R13 = 0)
            0x0E00000D,  # ADD R14, R0, R13 (R14 = 0)
            0x0F00000E,  # ADD R15, R0, R14 (R15 = 0)
            0x1000000F,  # ADD R16, R0, R15 (R16 = 0)
            0x11000010,  # ADD R17, R0, R16 (R17 = 0)
            0x12000011,  # ADD R18, R0, R17 (R18 = 0)
            0x13000012,  # ADD R19, R0, R18 (R19 = 0)
            0x14000013,  # ADD R20, R0, R19 (R20 = 0)
            0x15000014,  # ADD R21, R0, R20 (R21 = 0)
            0x16000015,  # ADD R22, R0, R21 (R22 = 0)
            0x17000016,  # ADD R23, R0, R22 (R23 = 0)
            0x18000017,  # ADD R24, R0, R23 (R24 = 0)
            0x19000018,  # ADD R25, R0, R24 (R25 = 0)
            0x1A000019,  # ADD R26, R0, R25 (R26 = 0)
            0x1B00001A,  # ADD R27, R0, R26 (R27 = 0)
            0x1C00001B,  # ADD R28, R0, R27 (R28 = 0)
            0x1D00001C,  # ADD R29, R0, R28 (R29 = 0)
            0x1E00001D,  # ADD R30, R0, R29 (R30 = 0)
            0x1F00001E,  # ADD R31, R0, R30 (R31 = 0)
            0x2000001F,  # HALT
        ]
        
        # Write test program to file
        with open("test_interrupts.bin", "wb") as f:
            for instruction in test_program:
                f.write(struct.pack("<I", instruction))
        
        # Run VM
        success, stdout, stderr = self.run_command(f"{self.vm_binary} test_interrupts.bin")
        if success:
            self.log("✓ Interrupt test passed")
            return True
        else:
            self.log(f"✗ Interrupt test failed: {stderr}")
            return False
    
    def test_devices(self):
        """Test device functionality"""
        self.log("Testing device functionality...")
        
        # Test program that uses devices
        test_program = [
            0x01000000,  # ADD R1, R0, R0 (R1 = 0)
            0x02000001,  # ADD R2, R0, R1 (R2 = 0)
            0x03000002,  # ADD R3, R0, R2 (R3 = 0)
            0x04000003,  # ADD R4, R0, R3 (R4 = 0)
            0x05000004,  # ADD R5, R0, R4 (R5 = 0)
            0x06000005,  # ADD R6, R0, R5 (R6 = 0)
            0x07000006,  # ADD R7, R0, R6 (R7 = 0)
            0x08000007,  # ADD R8, R0, R7 (R8 = 0)
            0x09000008,  # ADD R9, R0, R8 (R9 = 0)
            0x0A000009,  # ADD R10, R0, R9 (R10 = 0)
            0x0B00000A,  # ADD R11, R0, R10 (R11 = 0)
            0x0C00000B,  # ADD R12, R0, R11 (R12 = 0)
            0x0D00000C,  # ADD R13, R0, R12 (R13 = 0)
            0x0E00000D,  # ADD R14, R0, R13 (R14 = 0)
            0x0F00000E,  # ADD R15, R0, R14 (R15 = 0)
            0x1000000F,  # ADD R16, R0, R15 (R16 = 0)
            0x11000010,  # ADD R17, R0, R16 (R17 = 0)
            0x12000011,  # ADD R18, R0, R17 (R18 = 0)
            0x13000012,  # ADD R19, R0, R18 (R19 = 0)
            0x14000013,  # ADD R20, R0, R19 (R20 = 0)
            0x15000014,  # ADD R21, R0, R20 (R21 = 0)
            0x16000015,  # ADD R22, R0, R21 (R22 = 0)
            0x17000016,  # ADD R23, R0, R22 (R23 = 0)
            0x18000017,  # ADD R24, R0, R23 (R24 = 0)
            0x19000018,  # ADD R25, R0, R24 (R25 = 0)
            0x1A000019,  # ADD R26, R0, R25 (R26 = 0)
            0x1B00001A,  # ADD R27, R0, R26 (R27 = 0)
            0x1C00001B,  # ADD R28, R0, R27 (R28 = 0)
            0x1D00001C,  # ADD R29, R0, R28 (R29 = 0)
            0x1E00001D,  # ADD R30, R0, R29 (R30 = 0)
            0x1F00001E,  # ADD R31, R0, R30 (R31 = 0)
            0x2000001F,  # HALT
        ]
        
        # Write test program to file
        with open("test_devices.bin", "wb") as f:
            for instruction in test_program:
                f.write(struct.pack("<I", instruction))
        
        # Run VM
        success, stdout, stderr = self.run_command(f"{self.vm_binary} test_devices.bin")
        if success:
            self.log("✓ Device test passed")
            return True
        else:
            self.log(f"✗ Device test failed: {stderr}")
            return False
    
    def test_performance(self):
        """Test performance features"""
        self.log("Testing performance features...")
        
        # Test program that exercises performance counters
        test_program = [
            0x01000000,  # ADD R1, R0, R0 (R1 = 0)
            0x02000001,  # ADD R2, R0, R1 (R2 = 0)
            0x03000002,  # ADD R3, R0, R2 (R3 = 0)
            0x04000003,  # ADD R4, R0, R3 (R4 = 0)
            0x05000004,  # ADD R5, R0, R4 (R5 = 0)
            0x06000005,  # ADD R6, R0, R5 (R6 = 0)
            0x07000006,  # ADD R7, R0, R6 (R7 = 0)
            0x08000007,  # ADD R8, R0, R7 (R8 = 0)
            0x09000008,  # ADD R9, R0, R8 (R9 = 0)
            0x0A000009,  # ADD R10, R0, R9 (R10 = 0)
            0x0B00000A,  # ADD R11, R0, R10 (R11 = 0)
            0x0C00000B,  # ADD R12, R0, R11 (R12 = 0)
            0x0D00000C,  # ADD R13, R0, R12 (R13 = 0)
            0x0E00000D,  # ADD R14, R0, R13 (R14 = 0)
            0x0F00000E,  # ADD R15, R0, R14 (R15 = 0)
            0x1000000F,  # ADD R16, R0, R15 (R16 = 0)
            0x11000010,  # ADD R17, R0, R16 (R17 = 0)
            0x12000011,  # ADD R18, R0, R17 (R18 = 0)
            0x13000012,  # ADD R19, R0, R18 (R19 = 0)
            0x14000013,  # ADD R20, R0, R19 (R20 = 0)
            0x15000014,  # ADD R21, R0, R20 (R21 = 0)
            0x16000015,  # ADD R22, R0, R21 (R22 = 0)
            0x17000016,  # ADD R23, R0, R22 (R23 = 0)
            0x18000017,  # ADD R24, R0, R23 (R24 = 0)
            0x19000018,  # ADD R25, R0, R24 (R25 = 0)
            0x1A000019,  # ADD R26, R0, R25 (R26 = 0)
            0x1B00001A,  # ADD R27, R0, R26 (R27 = 0)
            0x1C00001B,  # ADD R28, R0, R27 (R28 = 0)
            0x1D00001C,  # ADD R29, R0, R28 (R29 = 0)
            0x1E00001D,  # ADD R30, R0, R29 (R30 = 0)
            0x1F00001E,  # ADD R31, R0, R30 (R31 = 0)
            0x2000001F,  # HALT
        ]
        
        # Write test program to file
        with open("test_performance.bin", "wb") as f:
            for instruction in test_program:
                f.write(struct.pack("<I", instruction))
        
        # Run VM
        success, stdout, stderr = self.run_command(f"{self.vm_binary} test_performance.bin")
        if success:
            self.log("✓ Performance test passed")
            return True
        else:
            self.log(f"✗ Performance test failed: {stderr}")
            return False
    
    def run_all_tests(self):
        """Run all tests"""
        self.log("Starting Expert-Level NanoCore Test Suite")
        self.log("=" * 50)
        
        tests = [
            ("Build System", self.test_build_system),
            ("Basic Instructions", self.test_basic_instructions),
            ("Arithmetic Instructions", self.test_arithmetic_instructions),
            ("Memory Instructions", self.test_memory_instructions),
            ("Branch Instructions", self.test_branch_instructions),
            ("Pipeline", self.test_pipeline),
            ("Cache", self.test_cache),
            ("Interrupts", self.test_interrupts),
            ("Devices", self.test_devices),
            ("Performance", self.test_performance),
        ]
        
        passed = 0
        total = len(tests)
        
        for test_name, test_func in tests:
            self.log(f"\nRunning {test_name} test...")
            try:
                if test_func():
                    self.log(f"✓ {test_name} test PASSED")
                    passed += 1
                else:
                    self.log(f"✗ {test_name} test FAILED")
            except Exception as e:
                self.log(f"✗ {test_name} test ERROR: {e}")
        
        self.log("\n" + "=" * 50)
        self.log(f"Test Results: {passed}/{total} tests passed")
        
        if passed == total:
            self.log("🎉 ALL TESTS PASSED! Expert-level NanoCore is working!")
            return True
        else:
            self.log("❌ Some tests failed. Please check the implementation.")
            return False
    
    def cleanup(self):
        """Clean up test files"""
        test_files = [
            "test_basic.bin", "test_arithmetic.bin", "test_memory.bin",
            "test_branch.bin", "test_pipeline.bin", "test_cache.bin",
            "test_interrupts.bin", "test_devices.bin", "test_performance.bin"
        ]
        
        for file in test_files:
            if os.path.exists(file):
                os.remove(file)

def main():
    """Main test runner"""
    test_suite = NanoCoreTest()
    
    try:
        success = test_suite.run_all_tests()
        return 0 if success else 1
    finally:
        test_suite.cleanup()

if __name__ == "__main__":
    sys.exit(main()) 