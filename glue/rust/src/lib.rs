/*!
# NanoCore Rust Bindings

High-performance Rust bindings for the NanoCore VM.

## Example Usage

```rust
use nanocore::{VM, Status};

fn main() -> Result<(), Box<dyn std::error::Error>> {
    // Initialize the library
    nanocore::init()?;
    
    // Create a VM with 64MB of memory
    let mut vm = VM::new(64 * 1024 * 1024)?;
    
    // Load a simple program
    let program = vec![
        0x3C, 0x20, 0x00, 0x2A,  // LD R1, 42
        0x3C, 0x40, 0x00, 0x3A,  // LD R2, 58
        0x00, 0x61, 0x40, 0x00,  // ADD R3, R1, R2
        0x84, 0x00, 0x00, 0x00,  // HALT
    ];
    
    vm.load_program(&program, 0x10000)?;
    
    // Run the program
    match vm.run(Some(1000))? {
        Status::Halted => {
            println!("Program completed successfully");
            println!("R1 = {}", vm.get_register(1)?);
            println!("R2 = {}", vm.get_register(2)?);
            println!("R3 = {}", vm.get_register(3)?);
        }
        status => {
            println!("Program ended with status: {:?}", status);
        }
    }
    
    Ok(())
}
```
*/

use std::ffi::CStr;
use std::os::raw::{c_int, c_uint, c_void};
use std::ptr;

mod ffi {
    use super::*;
    
    #[repr(C)]
    pub struct VmState {
        pub pc: u64,
        pub sp: u64,
        pub flags: u64,
        pub gprs: [u64; 32],
        pub vregs: [[u64; 4]; 16],
        pub perf_counters: [u64; 8],
        pub cache_ctrl: u64,
        pub vbase: u64,
    }
    
    extern "C" {
        pub fn nanocore_init() -> c_int;
        pub fn nanocore_vm_create(memory_size: u64, vm_handle: *mut c_int) -> c_int;
        pub fn nanocore_vm_destroy(vm_handle: c_int) -> c_int;
        pub fn nanocore_vm_reset(vm_handle: c_int) -> c_int;
        pub fn nanocore_vm_run(vm_handle: c_int, max_instructions: u64) -> c_int;
        pub fn nanocore_vm_step(vm_handle: c_int) -> c_int;
        pub fn nanocore_vm_get_state(vm_handle: c_int, state: *mut VmState) -> c_int;
        pub fn nanocore_vm_get_register(vm_handle: c_int, reg_index: c_int, value: *mut u64) -> c_int;
        pub fn nanocore_vm_set_register(vm_handle: c_int, reg_index: c_int, value: u64) -> c_int;
        pub fn nanocore_vm_load_program(vm_handle: c_int, data: *const u8, size: u64, address: u64) -> c_int;
        pub fn nanocore_vm_read_memory(vm_handle: c_int, address: u64, buffer: *mut u8, size: u64) -> c_int;
        pub fn nanocore_vm_write_memory(vm_handle: c_int, address: u64, data: *const u8, size: u64) -> c_int;
        pub fn nanocore_vm_set_breakpoint(vm_handle: c_int, address: u64) -> c_int;
        pub fn nanocore_vm_clear_breakpoint(vm_handle: c_int, address: u64) -> c_int;
        pub fn nanocore_vm_get_perf_counter(vm_handle: c_int, counter_index: c_int, value: *mut u64) -> c_int;
        pub fn nanocore_vm_poll_event(vm_handle: c_int, event_type: *mut c_int, event_data: *mut u64) -> c_int;
    }
}

/// VM execution status codes
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Status {
    /// Operation completed successfully
    Ok = 0,
    /// Generic error
    Error = -1,
    /// Out of memory
    OutOfMemory = -2,
    /// Invalid parameter
    InvalidParameter = -3,
    /// Initialization error
    InitializationError = -4,
}

impl Status {
    fn from_code(code: c_int) -> Self {
        match code {
            0 => Status::Ok,
            -1 => Status::Error,
            -2 => Status::OutOfMemory,
            -3 => Status::InvalidParameter,
            -4 => Status::InitializationError,
            _ => Status::Error,
        }
    }
}

/// VM event types
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum EventType {
    /// Program halted normally
    Halted = 0,
    /// Hit a breakpoint
    Breakpoint = 1,
    /// Exception occurred
    Exception = 2,
    /// Device interrupt
    DeviceInterrupt = 3,
}

impl EventType {
    fn from_code(code: c_int) -> Option<Self> {
        match code {
            0 => Some(EventType::Halted),
            1 => Some(EventType::Breakpoint),
            2 => Some(EventType::Exception),
            3 => Some(EventType::DeviceInterrupt),
            _ => None,
        }
    }
}

/// CPU flags
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Flags(pub u64);

impl Flags {
    pub const ZERO: u64 = 1 << 0;
    pub const CARRY: u64 = 1 << 1;
    pub const OVERFLOW: u64 = 1 << 2;
    pub const NEGATIVE: u64 = 1 << 3;
    pub const INTERRUPT_ENABLE: u64 = 1 << 4;
    pub const USER_MODE: u64 = 1 << 5;
    pub const HALTED: u64 = 1 << 7;
    
    pub fn is_set(&self, flag: u64) -> bool {
        self.0 & flag != 0
    }
}

/// Performance counter indices
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum PerfCounter {
    InstructionCount = 0,
    CycleCount = 1,
    L1Miss = 2,
    L2Miss = 3,
    BranchMiss = 4,
    PipelineStall = 5,
    MemoryOps = 6,
    SIMDOps = 7,
}

/// VM state snapshot
#[derive(Debug, Clone)]
pub struct VmState {
    pub pc: u64,
    pub sp: u64,
    pub flags: Flags,
    pub gprs: [u64; 32],
    pub vregs: [[u64; 4]; 16],
    pub perf_counters: [u64; 8],
    pub cache_ctrl: u64,
    pub vbase: u64,
}

impl From<ffi::VmState> for VmState {
    fn from(state: ffi::VmState) -> Self {
        VmState {
            pc: state.pc,
            sp: state.sp,
            flags: Flags(state.flags),
            gprs: state.gprs,
            vregs: state.vregs,
            perf_counters: state.perf_counters,
            cache_ctrl: state.cache_ctrl,
            vbase: state.vbase,
        }
    }
}

/// VM event with type and data
#[derive(Debug, Clone)]
pub struct Event {
    pub event_type: EventType,
    pub data: u64,
}

/// Error type for NanoCore operations
#[derive(Debug, Clone)]
pub struct Error {
    pub status: Status,
    pub message: String,
}

impl std::fmt::Display for Error {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "NanoCore error: {} ({:?})", self.message, self.status)
    }
}

impl std::error::Error for Error {}

type Result<T> = std::result::Result<T, Error>;

fn check_status(status: c_int, operation: &str) -> Result<()> {
    let status = Status::from_code(status);
    if status == Status::Ok {
        Ok(())
    } else {
        Err(Error {
            status,
            message: format!("Failed to {}", operation),
        })
    }
}

/// Initialize the NanoCore library
pub fn init() -> Result<()> {
    let result = unsafe { ffi::nanocore_init() };
    check_status(result, "initialize NanoCore")
}

/// NanoCore Virtual Machine
pub struct VM {
    handle: c_int,
    memory_size: u64,
}

impl VM {
    /// Create a new VM instance
    pub fn new(memory_size: u64) -> Result<Self> {
        let mut handle = 0;
        let result = unsafe { ffi::nanocore_vm_create(memory_size, &mut handle) };
        check_status(result, "create VM")?;
        
        Ok(VM { handle, memory_size })
    }
    
    /// Reset VM to initial state
    pub fn reset(&mut self) -> Result<()> {
        let result = unsafe { ffi::nanocore_vm_reset(self.handle) };
        check_status(result, "reset VM")
    }
    
    /// Run VM for a specified number of instructions
    pub fn run(&mut self, max_instructions: Option<u64>) -> Result<Status> {
        let max_instructions = max_instructions.unwrap_or(0);
        let result = unsafe { ffi::nanocore_vm_run(self.handle, max_instructions) };
        
        // For run, the return value is the exit status, not an error code
        match result {
            0 => Ok(Status::Ok),
            1 => Ok(Status::Error), // Halted with error
            _ => Ok(Status::from_code(result)),
        }
    }
    
    /// Execute a single instruction
    pub fn step(&mut self) -> Result<Status> {
        let result = unsafe { ffi::nanocore_vm_step(self.handle) };
        
        // For step, the return value is the exit status, not an error code
        match result {
            0 => Ok(Status::Ok),
            1 => Ok(Status::Error), // Halted with error
            _ => Ok(Status::from_code(result)),
        }
    }
    
    /// Get current VM state
    pub fn get_state(&self) -> Result<VmState> {
        let mut state = ffi::VmState {
            pc: 0,
            sp: 0,
            flags: 0,
            gprs: [0; 32],
            vregs: [[0; 4]; 16],
            perf_counters: [0; 8],
            cache_ctrl: 0,
            vbase: 0,
        };
        
        let result = unsafe { ffi::nanocore_vm_get_state(self.handle, &mut state) };
        check_status(result, "get VM state")?;
        
        Ok(state.into())
    }
    
    /// Get a register value
    pub fn get_register(&self, index: u32) -> Result<u64> {
        if index >= 32 {
            return Err(Error {
                status: Status::InvalidParameter,
                message: format!("Register index {} out of range", index),
            });
        }
        
        let mut value = 0;
        let result = unsafe { ffi::nanocore_vm_get_register(self.handle, index as c_int, &mut value) };
        check_status(result, "get register")?;
        
        Ok(value)
    }
    
    /// Set a register value
    pub fn set_register(&mut self, index: u32, value: u64) -> Result<()> {
        if index >= 32 {
            return Err(Error {
                status: Status::InvalidParameter,
                message: format!("Register index {} out of range", index),
            });
        }
        
        let result = unsafe { ffi::nanocore_vm_set_register(self.handle, index as c_int, value) };
        check_status(result, "set register")
    }
    
    /// Load a program into memory
    pub fn load_program(&mut self, data: &[u8], address: u64) -> Result<()> {
        let result = unsafe {
            ffi::nanocore_vm_load_program(
                self.handle,
                data.as_ptr(),
                data.len() as u64,
                address,
            )
        };
        check_status(result, "load program")
    }
    
    /// Read memory from VM
    pub fn read_memory(&self, address: u64, size: u64) -> Result<Vec<u8>> {
        let mut buffer = vec![0u8; size as usize];
        let result = unsafe {
            ffi::nanocore_vm_read_memory(
                self.handle,
                address,
                buffer.as_mut_ptr(),
                size,
            )
        };
        check_status(result, "read memory")?;
        
        Ok(buffer)
    }
    
    /// Write memory to VM
    pub fn write_memory(&mut self, address: u64, data: &[u8]) -> Result<()> {
        let result = unsafe {
            ffi::nanocore_vm_write_memory(
                self.handle,
                address,
                data.as_ptr(),
                data.len() as u64,
            )
        };
        check_status(result, "write memory")
    }
    
    /// Set a breakpoint
    pub fn set_breakpoint(&mut self, address: u64) -> Result<()> {
        let result = unsafe { ffi::nanocore_vm_set_breakpoint(self.handle, address) };
        check_status(result, "set breakpoint")
    }
    
    /// Clear a breakpoint
    pub fn clear_breakpoint(&mut self, address: u64) -> Result<()> {
        let result = unsafe { ffi::nanocore_vm_clear_breakpoint(self.handle, address) };
        check_status(result, "clear breakpoint")
    }
    
    /// Get performance counter value
    pub fn get_perf_counter(&self, counter: PerfCounter) -> Result<u64> {
        let mut value = 0;
        let result = unsafe {
            ffi::nanocore_vm_get_perf_counter(self.handle, counter as c_int, &mut value)
        };
        check_status(result, "get performance counter")?;
        
        Ok(value)
    }
    
    /// Poll for VM events (non-blocking)
    pub fn poll_event(&self) -> Result<Option<Event>> {
        let mut event_type = 0;
        let mut event_data = 0;
        let result = unsafe {
            ffi::nanocore_vm_poll_event(self.handle, &mut event_type, &mut event_data)
        };
        
        if result == 0 {
            if let Some(event_type) = EventType::from_code(event_type) {
                Ok(Some(Event {
                    event_type,
                    data: event_data,
                }))
            } else {
                Ok(None)
            }
        } else {
            Ok(None)
        }
    }
    
    /// Get memory size
    pub fn memory_size(&self) -> u64 {
        self.memory_size
    }
}

impl Drop for VM {
    fn drop(&mut self) {
        unsafe {
            ffi::nanocore_vm_destroy(self.handle);
        }
    }
}

// Ensure VM is Send and Sync safe
unsafe impl Send for VM {}
unsafe impl Sync for VM {}

#[cfg(test)]
mod tests {
    use super::*;
    
    #[test]
    fn test_vm_creation() {
        init().unwrap();
        let vm = VM::new(1024 * 1024).unwrap();
        assert_eq!(vm.memory_size(), 1024 * 1024);
    }
    
    #[test]
    fn test_register_access() {
        init().unwrap();
        let mut vm = VM::new(1024 * 1024).unwrap();
        
        // R0 should always be 0
        assert_eq!(vm.get_register(0).unwrap(), 0);
        vm.set_register(0, 42).unwrap();
        assert_eq!(vm.get_register(0).unwrap(), 0);
        
        // Other registers should work normally
        vm.set_register(1, 42).unwrap();
        assert_eq!(vm.get_register(1).unwrap(), 42);
    }
    
    #[test]
    fn test_memory_access() {
        init().unwrap();
        let mut vm = VM::new(1024 * 1024).unwrap();
        
        let data = vec![0x12, 0x34, 0x56, 0x78];
        vm.write_memory(0x1000, &data).unwrap();
        
        let read_data = vm.read_memory(0x1000, 4).unwrap();
        assert_eq!(read_data, data);
    }
    
    #[test]
    fn test_simple_program() {
        init().unwrap();
        let mut vm = VM::new(1024 * 1024).unwrap();
        
        // Simple program: LD R1, 42; HALT
        let program = vec![
            0x3C, 0x20, 0x00, 0x2A,  // LD R1, 42
            0x84, 0x00, 0x00, 0x00,  // HALT
        ];
        
        vm.load_program(&program, 0x10000).unwrap();
        
        match vm.run(Some(100)).unwrap() {
            Status::Ok => {
                // Check that R1 contains 42
                assert_eq!(vm.get_register(1).unwrap(), 42);
            }
            status => panic!("Expected Ok, got {:?}", status),
        }
    }
}