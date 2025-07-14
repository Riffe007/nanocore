"""
NanoCore Python API - High-Performance Assembly VM

Example usage:
    >>> import nanocore
    >>> vm = nanocore.VM(memory_size=1024 * 1024 * 64)  # 64MB
    >>> vm.load_program(bytecode, address=0x10000)
    >>> vm.run(max_instructions=1000000)
    >>> print(f"R1 = {vm.registers[1]}")
"""

__version__ = "0.1.0"
__author__ = "NanoCore Team"

import ctypes
import os
import sys
from enum import IntEnum
from pathlib import Path
from typing import Optional, Union, List, Dict, Any, Callable
import numpy as np

# Load the native library
def _load_library():
    """Load the NanoCore FFI library"""
    if sys.platform == "win32":
        lib_name = "nanocore_ffi.dll"
    elif sys.platform == "darwin":
        lib_name = "libnanocore_ffi.dylib"
    else:
        lib_name = "libnanocore_ffi.so"
    
    # Search paths
    search_paths = [
        Path(__file__).parent,
        Path(__file__).parent / ".." / ".." / ".." / "build" / "lib",
        Path("/usr/local/lib"),
        Path("/usr/lib"),
    ]
    
    for path in search_paths:
        lib_path = path / lib_name
        if lib_path.exists():
            return ctypes.CDLL(str(lib_path))
    
    # Try loading without path (system search)
    try:
        return ctypes.CDLL(lib_name)
    except OSError:
        raise ImportError(f"Could not find NanoCore library: {lib_name}")

# Load library
_lib = _load_library()

# Constants
class Status(IntEnum):
    """VM execution status codes"""
    OK = 0
    ERROR = -1
    ENOMEM = -2
    EINVAL = -3
    EINIT = -4

class EventType(IntEnum):
    """VM event types"""
    HALTED = 0
    BREAKPOINT = 1
    EXCEPTION = 2
    DEVICE_INTERRUPT = 3

class Flags(IntEnum):
    """CPU flags"""
    ZERO = 1 << 0
    CARRY = 1 << 1
    OVERFLOW = 1 << 2
    NEGATIVE = 1 << 3
    INTERRUPT_ENABLE = 1 << 4
    USER_MODE = 1 << 5
    HALTED = 1 << 7

class PerfCounter(IntEnum):
    """Performance counter indices"""
    INST_COUNT = 0
    CYCLE_COUNT = 1
    L1_MISS = 2
    L2_MISS = 3
    BRANCH_MISS = 4
    PIPELINE_STALL = 5
    MEM_OPS = 6
    SIMD_OPS = 7

# C structure definitions
class VmState(ctypes.Structure):
    """VM state structure"""
    _fields_ = [
        ("pc", ctypes.c_uint64),
        ("sp", ctypes.c_uint64),
        ("flags", ctypes.c_uint64),
        ("gprs", ctypes.c_uint64 * 32),
        ("vregs", (ctypes.c_uint64 * 4) * 16),
        ("perf_counters", ctypes.c_uint64 * 8),
        ("cache_ctrl", ctypes.c_uint64),
        ("vbase", ctypes.c_uint64),
    ]

# Function prototypes
_lib.nanocore_init.argtypes = []
_lib.nanocore_init.restype = ctypes.c_int

_lib.nanocore_vm_create.argtypes = [ctypes.c_uint64, ctypes.POINTER(ctypes.c_int)]
_lib.nanocore_vm_create.restype = ctypes.c_int

_lib.nanocore_vm_destroy.argtypes = [ctypes.c_int]
_lib.nanocore_vm_destroy.restype = ctypes.c_int

_lib.nanocore_vm_reset.argtypes = [ctypes.c_int]
_lib.nanocore_vm_reset.restype = ctypes.c_int

_lib.nanocore_vm_run.argtypes = [ctypes.c_int, ctypes.c_uint64]
_lib.nanocore_vm_run.restype = ctypes.c_int

_lib.nanocore_vm_step.argtypes = [ctypes.c_int]
_lib.nanocore_vm_step.restype = ctypes.c_int

_lib.nanocore_vm_get_state.argtypes = [ctypes.c_int, ctypes.POINTER(VmState)]
_lib.nanocore_vm_get_state.restype = ctypes.c_int

_lib.nanocore_vm_set_register.argtypes = [ctypes.c_int, ctypes.c_int, ctypes.c_uint64]
_lib.nanocore_vm_set_register.restype = ctypes.c_int

_lib.nanocore_vm_get_register.argtypes = [ctypes.c_int, ctypes.c_int, ctypes.POINTER(ctypes.c_uint64)]
_lib.nanocore_vm_get_register.restype = ctypes.c_int

_lib.nanocore_vm_load_program.argtypes = [ctypes.c_int, ctypes.POINTER(ctypes.c_uint8), ctypes.c_uint64, ctypes.c_uint64]
_lib.nanocore_vm_load_program.restype = ctypes.c_int

_lib.nanocore_vm_read_memory.argtypes = [ctypes.c_int, ctypes.c_uint64, ctypes.POINTER(ctypes.c_uint8), ctypes.c_uint64]
_lib.nanocore_vm_read_memory.restype = ctypes.c_int

_lib.nanocore_vm_write_memory.argtypes = [ctypes.c_int, ctypes.c_uint64, ctypes.POINTER(ctypes.c_uint8), ctypes.c_uint64]
_lib.nanocore_vm_write_memory.restype = ctypes.c_int

_lib.nanocore_vm_set_breakpoint.argtypes = [ctypes.c_int, ctypes.c_uint64]
_lib.nanocore_vm_set_breakpoint.restype = ctypes.c_int

_lib.nanocore_vm_clear_breakpoint.argtypes = [ctypes.c_int, ctypes.c_uint64]
_lib.nanocore_vm_clear_breakpoint.restype = ctypes.c_int

_lib.nanocore_vm_get_perf_counter.argtypes = [ctypes.c_int, ctypes.c_int, ctypes.POINTER(ctypes.c_uint64)]
_lib.nanocore_vm_get_perf_counter.restype = ctypes.c_int

_lib.nanocore_vm_poll_event.argtypes = [ctypes.c_int, ctypes.POINTER(ctypes.c_int), ctypes.POINTER(ctypes.c_uint64)]
_lib.nanocore_vm_poll_event.restype = ctypes.c_int

# Initialize library
_initialized = False
def _ensure_initialized():
    global _initialized
    if not _initialized:
        result = _lib.nanocore_init()
        if result != Status.OK:
            raise RuntimeError(f"Failed to initialize NanoCore: {result}")
        _initialized = True

class VM:
    """NanoCore Virtual Machine"""
    
    def __init__(self, memory_size: int = 64 * 1024 * 1024):
        """
        Create a new VM instance
        
        Args:
            memory_size: VM memory size in bytes (default: 64MB)
        """
        _ensure_initialized()
        
        self._handle = ctypes.c_int()
        result = _lib.nanocore_vm_create(memory_size, ctypes.byref(self._handle))
        if result != Status.OK:
            raise RuntimeError(f"Failed to create VM: {result}")
        
        self._memory_size = memory_size
        self._breakpoints = set()
        self._event_handlers = {}
    
    def __del__(self):
        """Clean up VM instance"""
        if hasattr(self, '_handle'):
            _lib.nanocore_vm_destroy(self._handle)
    
    def reset(self):
        """Reset VM to initial state"""
        result = _lib.nanocore_vm_reset(self._handle)
        if result != Status.OK:
            raise RuntimeError(f"Failed to reset VM: {result}")
        self._breakpoints.clear()
    
    def run(self, max_instructions: int = 0) -> int:
        """
        Run VM execution
        
        Args:
            max_instructions: Maximum instructions to execute (0 = unlimited)
            
        Returns:
            Exit code (0 = normal, 1 = illegal instruction, 2 = breakpoint)
        """
        return _lib.nanocore_vm_run(self._handle, max_instructions)
    
    def step(self) -> int:
        """Execute a single instruction"""
        return _lib.nanocore_vm_step(self._handle)
    
    @property
    def state(self) -> VmState:
        """Get current VM state"""
        state = VmState()
        result = _lib.nanocore_vm_get_state(self._handle, ctypes.byref(state))
        if result != Status.OK:
            raise RuntimeError(f"Failed to get VM state: {result}")
        return state
    
    @property
    def pc(self) -> int:
        """Program counter"""
        return self.state.pc
    
    @pc.setter
    def pc(self, value: int):
        """Set program counter"""
        state = self.state
        state.pc = value
        # Note: Would need a set_state function to update
    
    @property
    def registers(self) -> 'RegisterBank':
        """Access to general-purpose registers"""
        return RegisterBank(self)
    
    @property
    def vector_registers(self) -> 'VectorRegisterBank':
        """Access to SIMD vector registers"""
        return VectorRegisterBank(self)
    
    @property
    def flags(self) -> int:
        """CPU flags register"""
        return self.state.flags
    
    def is_flag_set(self, flag: Flags) -> bool:
        """Check if a specific flag is set"""
        return bool(self.flags & flag)
    
    def load_program(self, data: Union[bytes, bytearray, np.ndarray], address: int = 0x10000):
        """
        Load program into VM memory
        
        Args:
            data: Program bytecode
            address: Load address (default: 0x10000)
        """
        if isinstance(data, np.ndarray):
            data = data.tobytes()
        elif isinstance(data, bytearray):
            data = bytes(data)
        
        c_data = (ctypes.c_uint8 * len(data)).from_buffer_copy(data)
        result = _lib.nanocore_vm_load_program(self._handle, c_data, len(data), address)
        if result != Status.OK:
            raise RuntimeError(f"Failed to load program: {result}")
    
    def read_memory(self, address: int, size: int) -> bytes:
        """
        Read memory from VM
        
        Args:
            address: Starting address
            size: Number of bytes to read
            
        Returns:
            Memory contents as bytes
        """
        buffer = (ctypes.c_uint8 * size)()
        result = _lib.nanocore_vm_read_memory(self._handle, address, buffer, size)
        if result != Status.OK:
            raise RuntimeError(f"Failed to read memory: {result}")
        return bytes(buffer)
    
    def write_memory(self, address: int, data: Union[bytes, bytearray, np.ndarray]):
        """
        Write memory to VM
        
        Args:
            address: Starting address
            data: Data to write
        """
        if isinstance(data, np.ndarray):
            data = data.tobytes()
        elif isinstance(data, bytearray):
            data = bytes(data)
        
        c_data = (ctypes.c_uint8 * len(data)).from_buffer_copy(data)
        result = _lib.nanocore_vm_write_memory(self._handle, address, c_data, len(data))
        if result != Status.OK:
            raise RuntimeError(f"Failed to write memory: {result}")
    
    def set_breakpoint(self, address: int):
        """Set a breakpoint at the specified address"""
        result = _lib.nanocore_vm_set_breakpoint(self._handle, address)
        if result != Status.OK:
            raise RuntimeError(f"Failed to set breakpoint: {result}")
        self._breakpoints.add(address)
    
    def clear_breakpoint(self, address: int):
        """Clear a breakpoint at the specified address"""
        result = _lib.nanocore_vm_clear_breakpoint(self._handle, address)
        if result != Status.OK:
            raise RuntimeError(f"Failed to clear breakpoint: {result}")
        self._breakpoints.discard(address)
    
    def get_perf_counter(self, counter: PerfCounter) -> int:
        """Get performance counter value"""
        value = ctypes.c_uint64()
        result = _lib.nanocore_vm_get_perf_counter(self._handle, counter, ctypes.byref(value))
        if result != Status.OK:
            raise RuntimeError(f"Failed to get performance counter: {result}")
        return value.value
    
    def poll_event(self) -> Optional[tuple[EventType, int]]:
        """
        Poll for VM events (non-blocking)
        
        Returns:
            Tuple of (event_type, event_data) or None if no event
        """
        event_type = ctypes.c_int()
        event_data = ctypes.c_uint64()
        result = _lib.nanocore_vm_poll_event(self._handle, 
                                            ctypes.byref(event_type), 
                                            ctypes.byref(event_data))
        if result == Status.OK:
            return (EventType(event_type.value), event_data.value)
        return None
    
    def on_event(self, event_type: EventType, handler: Callable[[int], None]):
        """Register an event handler"""
        self._event_handlers[event_type] = handler
    
    def process_events(self):
        """Process all pending events"""
        while True:
            event = self.poll_event()
            if event is None:
                break
            
            event_type, event_data = event
            handler = self._event_handlers.get(event_type)
            if handler:
                handler(event_data)
    
    def dump_state(self):
        """Print VM state for debugging"""
        state = self.state
        print(f"PC: 0x{state.pc:016x}")
        print(f"SP: 0x{state.sp:016x}")
        print(f"Flags: 0x{state.flags:016x}")
        print("Registers:")
        for i in range(32):
            if i % 4 == 0:
                print(f"  ", end="")
            print(f"R{i:02d}=0x{state.gprs[i]:016x} ", end="")
            if i % 4 == 3:
                print()
        print("\nPerformance Counters:")
        for i, name in enumerate(["INST", "CYCLE", "L1_MISS", "L2_MISS", 
                                  "BR_MISS", "STALL", "MEM", "SIMD"]):
            print(f"  {name}: {state.perf_counters[i]:,}")

class RegisterBank:
    """Access to general-purpose registers"""
    
    def __init__(self, vm: VM):
        self._vm = vm
    
    def __getitem__(self, index: int) -> int:
        if not 0 <= index < 32:
            raise IndexError(f"Register index out of range: {index}")
        
        value = ctypes.c_uint64()
        result = _lib.nanocore_vm_get_register(self._vm._handle, index, ctypes.byref(value))
        if result != Status.OK:
            raise RuntimeError(f"Failed to get register: {result}")
        return value.value
    
    def __setitem__(self, index: int, value: int):
        if not 0 <= index < 32:
            raise IndexError(f"Register index out of range: {index}")
        
        if index == 0:  # R0 is hardwired to zero
            return
            
        result = _lib.nanocore_vm_set_register(self._vm._handle, index, value)
        if result != Status.OK:
            raise RuntimeError(f"Failed to set register: {result}")

class VectorRegisterBank:
    """Access to SIMD vector registers"""
    
    def __init__(self, vm: VM):
        self._vm = vm
    
    def __getitem__(self, index: int) -> np.ndarray:
        if not 0 <= index < 16:
            raise IndexError(f"Vector register index out of range: {index}")
        
        state = self._vm.state
        values = state.vregs[index]
        return np.array([values[i] for i in range(4)], dtype=np.uint64)
    
    def __setitem__(self, index: int, value: Union[list, np.ndarray]):
        if not 0 <= index < 16:
            raise IndexError(f"Vector register index out of range: {index}")
        
        if len(value) != 4:
            raise ValueError("Vector register must have 4 elements")
        
        # Note: Would need a set_vector_register function to update

# Convenience functions
def assemble(source: str) -> bytes:
    """
    Assemble NanoCore assembly source to bytecode
    
    Args:
        source: Assembly source code
        
    Returns:
        Assembled bytecode
    """
    # This would integrate with the assembler
    raise NotImplementedError("Assembler integration not yet implemented")

def disassemble(bytecode: bytes, address: int = 0) -> str:
    """
    Disassemble bytecode to assembly
    
    Args:
        bytecode: Machine code bytes
        address: Starting address for disassembly
        
    Returns:
        Disassembled code as string
    """
    # This would integrate with the disassembler
    raise NotImplementedError("Disassembler integration not yet implemented")

# Module initialization
__all__ = [
    "VM",
    "Status",
    "EventType", 
    "Flags",
    "PerfCounter",
    "VmState",
    "RegisterBank",
    "VectorRegisterBank",
    "assemble",
    "disassemble",
]