//! NanoCore FFI - High-performance Foreign Function Interface
//! 
//! Provides safe, zero-copy bindings to the NanoCore VM for use from
//! higher-level languages like Python, JavaScript, and others.

use std::ffi::{c_void, CStr, CString};
use std::os::raw::{c_char, c_int, c_ulonglong};
use std::ptr;
use std::slice;
use std::sync::Arc;

use bitflags::bitflags;
use crossbeam_channel::{bounded, Receiver, Sender};
use memmap2::{Mmap, MmapMut};
use once_cell::sync::Lazy;
use parking_lot::{Mutex, RwLock};

// Re-export core FFI functions
pub use crate::vm::*;
pub use crate::memory::*;
pub use crate::devices::*;

mod vm;
mod memory;
mod devices;
mod perf;

/// Result type for FFI operations
pub type NanoResult = c_int;

/// Success code
pub const NANO_OK: NanoResult = 0;
/// Generic error
pub const NANO_ERROR: NanoResult = -1;
/// Out of memory
pub const NANO_ENOMEM: NanoResult = -2;
/// Invalid argument
pub const NANO_EINVAL: NanoResult = -3;
/// Not initialized
pub const NANO_EINIT: NanoResult = -4;

bitflags! {
    /// VM state flags
    #[derive(Debug, Clone, Copy)]
    pub struct VmFlags: u64 {
        const ZERO = 1 << 0;
        const CARRY = 1 << 1;
        const OVERFLOW = 1 << 2;
        const NEGATIVE = 1 << 3;
        const INTERRUPT_ENABLE = 1 << 4;
        const USER_MODE = 1 << 5;
        const HALTED = 1 << 7;
    }
}

/// VM state structure matching assembly definition
#[repr(C)]
#[derive(Debug, Clone)]
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

/// VM instance handle
pub struct VmInstance {
    state: Arc<RwLock<VmState>>,
    memory: Arc<RwLock<MmapMut>>,
    devices: Arc<Mutex<DeviceManager>>,
    event_tx: Sender<VmEvent>,
    event_rx: Receiver<VmEvent>,
    breakpoints: Arc<RwLock<Vec<u64>>>,
}

/// VM events for async notification
#[derive(Debug, Clone)]
pub enum VmEvent {
    Halted,
    Breakpoint(u64),
    Exception(u32),
    DeviceInterrupt(u32),
}

/// Device manager for MMIO devices
pub struct DeviceManager {
    devices: Vec<Box<dyn Device>>,
    mmio_map: Vec<(u64, u64, usize)>, // (start, end, device_index)
}

/// Trait for MMIO devices
pub trait Device: Send + Sync {
    fn read(&mut self, offset: u64) -> u64;
    fn write(&mut self, offset: u64, value: u64);
    fn reset(&mut self);
}

// External C functions from assembly
extern "C" {
    fn vm_init(memory_size: u64) -> c_int;
    fn vm_reset();
    fn vm_run(max_instructions: u64) -> c_int;
    fn vm_step() -> c_int;
    fn vm_get_state() -> *const VmState;
    fn vm_set_breakpoint(address: u64);
    fn vm_dump_state();
}

/// Global VM instances registry
static VM_INSTANCES: Lazy<RwLock<Vec<Option<Arc<Mutex<VmInstance>>>>>> = 
    Lazy::new(|| RwLock::new(Vec::new()));

/// Initialize the NanoCore FFI library
#[no_mangle]
pub extern "C" fn nanocore_init() -> NanoResult {
    // Initialize logging, allocators, etc.
    std::panic::set_hook(Box::new(|info| {
        eprintln!("NanoCore panic: {}", info);
    }));
    
    NANO_OK
}

/// Create a new VM instance
/// 
/// # Arguments
/// * `memory_size` - Size of VM memory in bytes
/// * `handle_out` - Output parameter for VM handle
#[no_mangle]
pub extern "C" fn nanocore_vm_create(
    memory_size: c_ulonglong,
    handle_out: *mut c_int,
) -> NanoResult {
    if handle_out.is_null() {
        return NANO_EINVAL;
    }
    
    // Initialize VM through assembly
    let result = unsafe { vm_init(memory_size) };
    if result != 0 {
        return NANO_ERROR;
    }
    
    // Create memory mapping
    let memory = match MmapMut::map_anon(memory_size as usize) {
        Ok(m) => m,
        Err(_) => return NANO_ENOMEM,
    };
    
    // Create event channels
    let (event_tx, event_rx) = bounded(1024);
    
    // Get initial state
    let state_ptr = unsafe { vm_get_state() };
    let state = unsafe { (*state_ptr).clone() };
    
    // Create instance
    let instance = VmInstance {
        state: Arc::new(RwLock::new(state)),
        memory: Arc::new(RwLock::new(memory)),
        devices: Arc::new(Mutex::new(DeviceManager::new())),
        event_tx,
        event_rx,
        breakpoints: Arc::new(RwLock::new(Vec::new())),
    };
    
    // Register instance
    let mut instances = VM_INSTANCES.write();
    let handle = instances.len() as c_int;
    instances.push(Some(Arc::new(Mutex::new(instance))));
    
    unsafe {
        *handle_out = handle;
    }
    
    NANO_OK
}

/// Destroy a VM instance
#[no_mangle]
pub extern "C" fn nanocore_vm_destroy(handle: c_int) -> NanoResult {
    let mut instances = VM_INSTANCES.write();
    
    if handle < 0 || handle as usize >= instances.len() {
        return NANO_EINVAL;
    }
    
    instances[handle as usize] = None;
    NANO_OK
}

/// Reset VM to initial state
#[no_mangle]
pub extern "C" fn nanocore_vm_reset(handle: c_int) -> NanoResult {
    with_vm_instance(handle, |_vm| {
        unsafe { vm_reset() };
        NANO_OK
    })
}

/// Run VM for specified number of instructions
#[no_mangle]
pub extern "C" fn nanocore_vm_run(
    handle: c_int,
    max_instructions: c_ulonglong,
) -> NanoResult {
    with_vm_instance(handle, |vm| {
        // Update breakpoints in assembly
        let breakpoints = vm.breakpoints.read();
        for &bp in breakpoints.iter() {
            unsafe { vm_set_breakpoint(bp) };
        }
        
        // Run VM
        let result = unsafe { vm_run(max_instructions) };
        
        // Update cached state
        let state_ptr = unsafe { vm_get_state() };
        let new_state = unsafe { (*state_ptr).clone() };
        *vm.state.write() = new_state;
        
        // Check for events
        if result == 2 {
            // Breakpoint hit
            let pc = vm.state.read().pc;
            let _ = vm.event_tx.try_send(VmEvent::Breakpoint(pc));
        }
        
        result
    })
}

/// Single step VM execution
#[no_mangle]
pub extern "C" fn nanocore_vm_step(handle: c_int) -> NanoResult {
    nanocore_vm_run(handle, 1)
}

/// Get VM state
#[no_mangle]
pub extern "C" fn nanocore_vm_get_state(
    handle: c_int,
    state_out: *mut VmState,
) -> NanoResult {
    if state_out.is_null() {
        return NANO_EINVAL;
    }
    
    with_vm_instance(handle, |vm| {
        let state = vm.state.read();
        unsafe {
            *state_out = state.clone();
        }
        NANO_OK
    })
}

/// Set VM register
#[no_mangle]
pub extern "C" fn nanocore_vm_set_register(
    handle: c_int,
    reg: c_int,
    value: c_ulonglong,
) -> NanoResult {
    if reg < 0 || reg >= 32 {
        return NANO_EINVAL;
    }
    
    with_vm_instance(handle, |vm| {
        vm.state.write().gprs[reg as usize] = value;
        NANO_OK
    })
}

/// Get VM register
#[no_mangle]
pub extern "C" fn nanocore_vm_get_register(
    handle: c_int,
    reg: c_int,
    value_out: *mut c_ulonglong,
) -> NanoResult {
    if reg < 0 || reg >= 32 || value_out.is_null() {
        return NANO_EINVAL;
    }
    
    with_vm_instance(handle, |vm| {
        let value = vm.state.read().gprs[reg as usize];
        unsafe {
            *value_out = value;
        }
        NANO_OK
    })
}

/// Load program into VM memory
#[no_mangle]
pub extern "C" fn nanocore_vm_load_program(
    handle: c_int,
    program: *const u8,
    size: c_ulonglong,
    address: c_ulonglong,
) -> NanoResult {
    if program.is_null() {
        return NANO_EINVAL;
    }
    
    with_vm_instance(handle, |vm| {
        let mut memory = vm.memory.write();
        let program_slice = unsafe { slice::from_raw_parts(program, size as usize) };
        
        if address as usize + size as usize > memory.len() {
            return NANO_EINVAL;
        }
        
        memory[address as usize..(address + size) as usize]
            .copy_from_slice(program_slice);
            
        NANO_OK
    })
}

/// Read VM memory
#[no_mangle]
pub extern "C" fn nanocore_vm_read_memory(
    handle: c_int,
    address: c_ulonglong,
    buffer: *mut u8,
    size: c_ulonglong,
) -> NanoResult {
    if buffer.is_null() {
        return NANO_EINVAL;
    }
    
    with_vm_instance(handle, |vm| {
        let memory = vm.memory.read();
        
        if address as usize + size as usize > memory.len() {
            return NANO_EINVAL;
        }
        
        let buffer_slice = unsafe { slice::from_raw_parts_mut(buffer, size as usize) };
        buffer_slice.copy_from_slice(&memory[address as usize..(address + size) as usize]);
        
        NANO_OK
    })
}

/// Write VM memory
#[no_mangle]
pub extern "C" fn nanocore_vm_write_memory(
    handle: c_int,
    address: c_ulonglong,
    data: *const u8,
    size: c_ulonglong,
) -> NanoResult {
    if data.is_null() {
        return NANO_EINVAL;
    }
    
    with_vm_instance(handle, |vm| {
        let mut memory = vm.memory.write();
        
        if address as usize + size as usize > memory.len() {
            return NANO_EINVAL;
        }
        
        let data_slice = unsafe { slice::from_raw_parts(data, size as usize) };
        memory[address as usize..(address + size) as usize].copy_from_slice(data_slice);
        
        NANO_OK
    })
}

/// Set breakpoint
#[no_mangle]
pub extern "C" fn nanocore_vm_set_breakpoint(
    handle: c_int,
    address: c_ulonglong,
) -> NanoResult {
    with_vm_instance(handle, |vm| {
        vm.breakpoints.write().push(address);
        NANO_OK
    })
}

/// Clear breakpoint
#[no_mangle]
pub extern "C" fn nanocore_vm_clear_breakpoint(
    handle: c_int,
    address: c_ulonglong,
) -> NanoResult {
    with_vm_instance(handle, |vm| {
        vm.breakpoints.write().retain(|&x| x != address);
        NANO_OK
    })
}

/// Get performance counter
#[no_mangle]
pub extern "C" fn nanocore_vm_get_perf_counter(
    handle: c_int,
    counter: c_int,
    value_out: *mut c_ulonglong,
) -> NanoResult {
    if counter < 0 || counter >= 8 || value_out.is_null() {
        return NANO_EINVAL;
    }
    
    with_vm_instance(handle, |vm| {
        let value = vm.state.read().perf_counters[counter as usize];
        unsafe {
            *value_out = value;
        }
        NANO_OK
    })
}

/// Poll for VM events (non-blocking)
#[no_mangle]
pub extern "C" fn nanocore_vm_poll_event(
    handle: c_int,
    event_type_out: *mut c_int,
    event_data_out: *mut c_ulonglong,
) -> NanoResult {
    if event_type_out.is_null() || event_data_out.is_null() {
        return NANO_EINVAL;
    }
    
    with_vm_instance(handle, |vm| {
        match vm.event_rx.try_recv() {
            Ok(event) => {
                let (event_type, event_data) = match event {
                    VmEvent::Halted => (0, 0),
                    VmEvent::Breakpoint(addr) => (1, addr),
                    VmEvent::Exception(code) => (2, code as u64),
                    VmEvent::DeviceInterrupt(id) => (3, id as u64),
                };
                
                unsafe {
                    *event_type_out = event_type;
                    *event_data_out = event_data;
                }
                NANO_OK
            }
            Err(_) => NANO_ERROR, // No event available
        }
    })
}

// Helper function to access VM instance
fn with_vm_instance<F, R>(handle: c_int, f: F) -> R
where
    F: FnOnce(&mut VmInstance) -> R,
{
    let instances = VM_INSTANCES.read();
    
    if handle < 0 || handle as usize >= instances.len() {
        return f(&mut VmInstance {
            state: Arc::new(RwLock::new(VmState::default())),
            memory: Arc::new(RwLock::new(unsafe { MmapMut::map_anon(0).unwrap() })),
            devices: Arc::new(Mutex::new(DeviceManager::new())),
            event_tx: bounded(0).0,
            event_rx: bounded(0).1,
            breakpoints: Arc::new(RwLock::new(Vec::new())),
        });
    }
    
    match &instances[handle as usize] {
        Some(instance) => {
            let mut vm = instance.lock();
            f(&mut vm)
        }
        None => f(&mut VmInstance {
            state: Arc::new(RwLock::new(VmState::default())),
            memory: Arc::new(RwLock::new(unsafe { MmapMut::map_anon(0).unwrap() })),
            devices: Arc::new(Mutex::new(DeviceManager::new())),
            event_tx: bounded(0).0,
            event_rx: bounded(0).1,
            breakpoints: Arc::new(RwLock::new(Vec::new())),
        }),
    }
}

impl Default for VmState {
    fn default() -> Self {
        Self {
            pc: 0,
            sp: 0,
            flags: 0,
            gprs: [0; 32],
            vregs: [[0; 4]; 16],
            perf_counters: [0; 8],
            cache_ctrl: 0,
            vbase: 0,
        }
    }
}

impl DeviceManager {
    fn new() -> Self {
        Self {
            devices: Vec::new(),
            mmio_map: Vec::new(),
        }
    }
}