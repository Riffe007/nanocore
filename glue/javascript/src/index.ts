/**
 * NanoCore JavaScript/TypeScript Bindings
 * 
 * High-performance JavaScript bindings for the NanoCore VM using WebAssembly.
 * 
 * @example
 * ```typescript
 * import { NanoCore, VM } from 'nanocore-js';
 * 
 * // Initialize the library
 * const nanocore = await NanoCore.init();
 * 
 * // Create a VM with 64MB of memory
 * const vm = new VM(64 * 1024 * 1024);
 * 
 * // Load a simple program
 * const program = new Uint8Array([
 *   0x3C, 0x20, 0x00, 0x2A,  // LD R1, 42
 *   0x3C, 0x40, 0x00, 0x3A,  // LD R2, 58
 *   0x00, 0x61, 0x40, 0x00,  // ADD R3, R1, R2
 *   0x84, 0x00, 0x00, 0x00,  // HALT
 * ]);
 * 
 * vm.loadProgram(program, 0x10000);
 * 
 * // Run the program
 * const result = vm.run(1000);
 * if (result === Status.Halted) {
 *   console.log('Program completed successfully');
 *   console.log('R1 =', vm.getRegister(1));
 *   console.log('R2 =', vm.getRegister(2));
 *   console.log('R3 =', vm.getRegister(3));
 * }
 * ```
 */

/// <reference types="node" />

// Status codes
export enum Status {
  Ok = 0,
  Error = -1,
  OutOfMemory = -2,
  InvalidParameter = -3,
  InitializationError = -4,
}

// Event types
export enum EventType {
  Halted = 0,
  Breakpoint = 1,
  Exception = 2,
  DeviceInterrupt = 3,
}

// Performance counter indices
export enum PerfCounter {
  InstructionCount = 0,
  CycleCount = 1,
  L1Miss = 2,
  L2Miss = 3,
  BranchMiss = 4,
  PipelineStall = 5,
  MemoryOps = 6,
  SIMDOps = 7,
}

// CPU flags
export class Flags {
  static readonly ZERO = 1 << 0;
  static readonly CARRY = 1 << 1;
  static readonly OVERFLOW = 1 << 2;
  static readonly NEGATIVE = 1 << 3;
  static readonly INTERRUPT_ENABLE = 1 << 4;
  static readonly USER_MODE = 1 << 5;
  static readonly HALTED = 1 << 7;
  
  constructor(public value: number) {}
  
  isSet(flag: number): boolean {
    return (this.value & flag) !== 0;
  }
}

// VM state
export interface VmState {
  pc: number;
  sp: number;
  flags: Flags;
  gprs: number[];
  vregs: number[][];
  perfCounters: number[];
  cacheCtrl: number;
  vbase: number;
}

// VM event
export interface Event {
  type: EventType;
  data: number;
}

// Error class
class NanoCoreError extends Error {
  constructor(public status: Status, message: string) {
    super(message);
    this.name = 'NanoCoreError';
  }
}

// WebAssembly module interface
interface WasmModule {
  ccall: (funcName: string, returnType: string, argTypes: string[], args: any[]) => any;
  cwrap: (funcName: string, returnType: string, argTypes: string[]) => (...args: any[]) => any;
  getValue: (ptr: number, type: string) => number;
  setValue: (ptr: number, value: number, type: string) => void;
  allocate: (data: number[], type: string, allocator: number) => number;
  _malloc: (size: number) => number;
  _free: (ptr: number) => void;
  ALLOC_STACK: number;
  ALLOC_STATIC: number;
  ALLOC_DYNAMIC: number;
  ALLOC_NORMAL: number;
  HEAPU8: Uint8Array;
}

// Main NanoCore class
export class NanoCore {
  private static instance: NanoCore | null = null;
  private module: WasmModule;
  
  private constructor(module: WasmModule) {
    this.module = module;
  }
  
  static async init(): Promise<NanoCore> {
    if (NanoCore.instance) {
      return NanoCore.instance;
    }
    
    // Load the WebAssembly module
    let wasmModule: WasmModule;
    
    // For now, we'll use a placeholder that integrates with the C FFI
    // In a real implementation, this would load the compiled WASM module
    throw new Error('WebAssembly module not yet compiled. Run npm run build:wasm first.');
    
    const instance = new NanoCore(wasmModule);
    NanoCore.instance = instance;
    return instance;
  }
  
  createVM(memorySize: number): VM {
    return new VM(this.module, memorySize);
  }
}

// VM class
class VM {
  private module: WasmModule;
  private handle: number;
  private memorySize: number;
  
  constructor(module: WasmModule, memorySize: number) {
    this.module = module;
    this.memorySize = memorySize;
    
    // Create VM handle
    const handlePtr = this.module._malloc(4);
    const result = this.module.ccall('nanocore_vm_create', 'number', ['number', 'number'], [memorySize, handlePtr]);
    
    if (result !== Status.Ok) {
      this.module._free(handlePtr);
      throw new NanoCoreError(result, 'Failed to create VM');
    }
    
    this.handle = this.module.getValue(handlePtr, 'i32');
    this.module._free(handlePtr);
  }
  
  // Destructor
  destroy(): void {
    if (this.handle !== 0) {
      this.module.ccall('nanocore_vm_destroy', 'number', ['number'], [this.handle]);
      this.handle = 0;
    }
  }
  
  // Reset VM
  reset(): void {
    const result = this.module.ccall('nanocore_vm_reset', 'number', ['number'], [this.handle]);
    if (result !== Status.Ok) {
      throw new NanoCoreError(result, 'Failed to reset VM');
    }
  }
  
  // Run VM
  run(maxInstructions: number = 0): Status {
    const result = this.module.ccall('nanocore_vm_run', 'number', ['number', 'number'], [this.handle, maxInstructions]);
    return result;
  }
  
  // Step VM
  step(): Status {
    const result = this.module.ccall('nanocore_vm_step', 'number', ['number'], [this.handle]);
    return result;
  }
  
  // Get VM state
  getState(): VmState {
    const stateSize = 8 + 8 + 8 + (32 * 8) + (16 * 4 * 8) + (8 * 8) + 8 + 8; // Approximate size
    const statePtr = this.module._malloc(stateSize);
    
    const result = this.module.ccall('nanocore_vm_get_state', 'number', ['number', 'number'], [this.handle, statePtr]);
    if (result !== Status.Ok) {
      this.module._free(statePtr);
      throw new NanoCoreError(result, 'Failed to get VM state');
    }
    
    let offset = 0;
    const pc = this.module.getValue(statePtr + offset, 'i64'); offset += 8;
    const sp = this.module.getValue(statePtr + offset, 'i64'); offset += 8;
    const flags = this.module.getValue(statePtr + offset, 'i64'); offset += 8;
    
    const gprs: number[] = [];
    for (let i = 0; i < 32; i++) {
      gprs.push(this.module.getValue(statePtr + offset, 'i64'));
      offset += 8;
    }
    
    const vregs: number[][] = [];
    for (let i = 0; i < 16; i++) {
      const vreg: number[] = [];
      for (let j = 0; j < 4; j++) {
        vreg.push(this.module.getValue(statePtr + offset, 'i64'));
        offset += 8;
      }
      vregs.push(vreg);
    }
    
    const perfCounters: number[] = [];
    for (let i = 0; i < 8; i++) {
      perfCounters.push(this.module.getValue(statePtr + offset, 'i64'));
      offset += 8;
    }
    
    const cacheCtrl = this.module.getValue(statePtr + offset, 'i64'); offset += 8;
    const vbase = this.module.getValue(statePtr + offset, 'i64'); offset += 8;
    
    this.module._free(statePtr);
    
    return {
      pc,
      sp,
      flags: new Flags(flags),
      gprs,
      vregs,
      perfCounters,
      cacheCtrl,
      vbase,
    };
  }
  
  // Get register value
  getRegister(index: number): number {
    if (index < 0 || index >= 32) {
      throw new NanoCoreError(Status.InvalidParameter, `Register index ${index} out of range`);
    }
    
    const valuePtr = this.module._malloc(8);
    const result = this.module.ccall('nanocore_vm_get_register', 'number', ['number', 'number', 'number'], [this.handle, index, valuePtr]);
    
    if (result !== Status.Ok) {
      this.module._free(valuePtr);
      throw new NanoCoreError(result, 'Failed to get register');
    }
    
    const value = this.module.getValue(valuePtr, 'i64');
    this.module._free(valuePtr);
    
    return value;
  }
  
  // Set register value
  setRegister(index: number, value: number): void {
    if (index < 0 || index >= 32) {
      throw new NanoCoreError(Status.InvalidParameter, `Register index ${index} out of range`);
    }
    
    const result = this.module.ccall('nanocore_vm_set_register', 'number', ['number', 'number', 'number'], [this.handle, index, value]);
    if (result !== Status.Ok) {
      throw new NanoCoreError(result, 'Failed to set register');
    }
  }
  
  // Load program
  loadProgram(data: Uint8Array, address: number): void {
    const dataPtr = this.module._malloc(data.length);
    
    // Copy data to WASM memory
    const heapU8 = new Uint8Array(this.module.HEAPU8.buffer, dataPtr, data.length);
    heapU8.set(data);
    
    const result = this.module.ccall('nanocore_vm_load_program', 'number', ['number', 'number', 'number', 'number'], [this.handle, dataPtr, data.length, address]);
    
    this.module._free(dataPtr);
    
    if (result !== Status.Ok) {
      throw new NanoCoreError(result, 'Failed to load program');
    }
  }
  
  // Read memory
  readMemory(address: number, size: number): Uint8Array {
    const bufferPtr = this.module._malloc(size);
    const result = this.module.ccall('nanocore_vm_read_memory', 'number', ['number', 'number', 'number', 'number'], [this.handle, address, bufferPtr, size]);
    
    if (result !== Status.Ok) {
      this.module._free(bufferPtr);
      throw new NanoCoreError(result, 'Failed to read memory');
    }
    
    const data = new Uint8Array(size);
    const heapU8 = new Uint8Array(this.module.HEAPU8.buffer, bufferPtr, size);
    data.set(heapU8);
    
    this.module._free(bufferPtr);
    
    return data;
  }
  
  // Write memory
  writeMemory(address: number, data: Uint8Array): void {
    const dataPtr = this.module._malloc(data.length);
    
    // Copy data to WASM memory
    const heapU8 = new Uint8Array(this.module.HEAPU8.buffer, dataPtr, data.length);
    heapU8.set(data);
    
    const result = this.module.ccall('nanocore_vm_write_memory', 'number', ['number', 'number', 'number', 'number'], [this.handle, address, dataPtr, data.length]);
    
    this.module._free(dataPtr);
    
    if (result !== Status.Ok) {
      throw new NanoCoreError(result, 'Failed to write memory');
    }
  }
  
  // Set breakpoint
  setBreakpoint(address: number): void {
    const result = this.module.ccall('nanocore_vm_set_breakpoint', 'number', ['number', 'number'], [this.handle, address]);
    if (result !== Status.Ok) {
      throw new NanoCoreError(result, 'Failed to set breakpoint');
    }
  }
  
  // Clear breakpoint
  clearBreakpoint(address: number): void {
    const result = this.module.ccall('nanocore_vm_clear_breakpoint', 'number', ['number', 'number'], [this.handle, address]);
    if (result !== Status.Ok) {
      throw new NanoCoreError(result, 'Failed to clear breakpoint');
    }
  }
  
  // Get performance counter
  getPerfCounter(counter: PerfCounter): number {
    const valuePtr = this.module._malloc(8);
    const result = this.module.ccall('nanocore_vm_get_perf_counter', 'number', ['number', 'number', 'number'], [this.handle, counter, valuePtr]);
    
    if (result !== Status.Ok) {
      this.module._free(valuePtr);
      throw new NanoCoreError(result, 'Failed to get performance counter');
    }
    
    const value = this.module.getValue(valuePtr, 'i64');
    this.module._free(valuePtr);
    
    return value;
  }
  
  // Poll event
  pollEvent(): Event | null {
    const eventTypePtr = this.module._malloc(4);
    const eventDataPtr = this.module._malloc(8);
    
    const result = this.module.ccall('nanocore_vm_poll_event', 'number', ['number', 'number', 'number'], [this.handle, eventTypePtr, eventDataPtr]);
    
    if (result === Status.Ok) {
      const eventType = this.module.getValue(eventTypePtr, 'i32');
      const eventData = this.module.getValue(eventDataPtr, 'i64');
      
      this.module._free(eventTypePtr);
      this.module._free(eventDataPtr);
      
      return {
        type: eventType,
        data: eventData,
      };
    }
    
    this.module._free(eventTypePtr);
    this.module._free(eventDataPtr);
    
    return null;
  }
  
  // Get memory size
  getMemorySize(): number {
    return this.memorySize;
  }
}

// Export everything
export default NanoCore;
export { VM, NanoCoreError };