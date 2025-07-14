/**
 * Mock NanoCore WASM module for development
 * This simulates the WASM API without requiring Emscripten
 */

class MockVM {
  constructor() {
    this.memory = new ArrayBuffer(1024 * 1024); // 1MB
    this.registers = new BigUint64Array(32);
    this.pc = 0n;
    this.sp = 0n;
    this.flags = 0n;
    this.halted = false;
    this.instructions = 0n;
    this.cycles = 0n;
  }
  
  reset() {
    this.registers.fill(0n);
    this.pc = 0x10000n;
    this.sp = BigInt(this.memory.byteLength - 8);
    this.flags = 0n;
    this.halted = false;
    this.instructions = 0n;
    this.cycles = 0n;
  }
  
  step() {
    if (this.halted) return 1;
    
    // Simulate instruction execution
    const view = new DataView(this.memory);
    const inst = view.getUint32(Number(this.pc), true);
    const opcode = (inst >> 26) & 0x3F;
    const rd = (inst >> 21) & 0x1F;
    const rs1 = (inst >> 16) & 0x1F;
    const rs2 = (inst >> 11) & 0x1F;
    const imm = inst & 0xFFFF;
    
    // Execute instruction
    switch (opcode) {
      case 0x00: // ADD
        if (rd !== 0) {
          this.registers[rd] = this.registers[rs1] + this.registers[rs2];
        }
        break;
      case 0x01: // SUB
        if (rd !== 0) {
          this.registers[rd] = this.registers[rs1] - this.registers[rs2];
        }
        break;
      case 0x0F: // LD
        if (rd !== 0) {
          this.registers[rd] = BigInt(imm);
        }
        break;
      case 0x21: // HALT
        this.halted = true;
        this.flags |= 0x80n;
        return 0;
      case 0x22: // NOP
        break;
      default:
        console.warn(`Unknown opcode: 0x${opcode.toString(16)}`);
    }
    
    this.pc += 4n;
    this.instructions++;
    this.cycles++;
    
    return 0;
  }
}

// Global VM instances
const vms = new Map();
let nextVmId = 1;

const NanoCoreMock = () => {
  const heapSize = 16 * 1024 * 1024; // 16MB heap
  const memory = new ArrayBuffer(heapSize);
  const HEAP8 = new Int8Array(memory);
  const HEAP16 = new Int16Array(memory);
  const HEAP32 = new Int32Array(memory);
  const HEAPU8 = new Uint8Array(memory);
  const HEAPU16 = new Uint16Array(memory);
  const HEAPU32 = new Uint32Array(memory);
  const HEAPF32 = new Float32Array(memory);
  const HEAPF64 = new Float64Array(memory);
  
  let heapPtr = 1024; // Start allocation after 1KB
  
  const module = {
    // Memory management
    _malloc: (size) => {
      const ptr = heapPtr;
      heapPtr += size;
      heapPtr = (heapPtr + 7) & ~7; // Align to 8 bytes
      return ptr;
    },
    
    _free: (ptr) => {
      // No-op for simplicity
    },
    
    // Value access
    getValue: (ptr, type) => {
      switch (type) {
        case 'i8': return HEAP8[ptr];
        case 'i16': return HEAP16[ptr >> 1];
        case 'i32': return HEAP32[ptr >> 2];
        case 'i64': return BigInt(HEAP32[ptr >> 2]) | (BigInt(HEAP32[(ptr >> 2) + 1]) << 32n);
        case 'float': return HEAPF32[ptr >> 2];
        case 'double': return HEAPF64[ptr >> 3];
        default: throw new Error(`Unknown type: ${type}`);
      }
    },
    
    setValue: (ptr, value, type) => {
      switch (type) {
        case 'i8': HEAP8[ptr] = value; break;
        case 'i16': HEAP16[ptr >> 1] = value; break;
        case 'i32': HEAP32[ptr >> 2] = value; break;
        case 'i64': 
          const bigVal = BigInt(value);
          HEAP32[ptr >> 2] = Number(bigVal & 0xFFFFFFFFn);
          HEAP32[(ptr >> 2) + 1] = Number(bigVal >> 32n);
          break;
        case 'float': HEAPF32[ptr >> 2] = value; break;
        case 'double': HEAPF64[ptr >> 3] = value; break;
        default: throw new Error(`Unknown type: ${type}`);
      }
    },
    
    // Function calling
    ccall: (name, returnType, argTypes, args) => {
      const func = module['_' + name];
      if (!func) throw new Error(`Function not found: ${name}`);
      return func(...args);
    },
    
    cwrap: (name, returnType, argTypes) => {
      return (...args) => module.ccall(name, returnType, argTypes, args);
    },
    
    // NanoCore API
    _nanocore_init: () => 0,
    
    _nanocore_vm_create: (memorySize, vmHandlePtr) => {
      const vm = new MockVM();
      const id = nextVmId++;
      vms.set(id, vm);
      HEAP32[vmHandlePtr >> 2] = id;
      return 0;
    },
    
    _nanocore_vm_destroy: (handle) => {
      vms.delete(handle);
      return 0;
    },
    
    _nanocore_vm_reset: (handle) => {
      const vm = vms.get(handle);
      if (!vm) return -3;
      vm.reset();
      return 0;
    },
    
    _nanocore_vm_step: (handle) => {
      const vm = vms.get(handle);
      if (!vm) return -3;
      return vm.step();
    },
    
    _nanocore_vm_run: (handle, maxInstructions) => {
      const vm = vms.get(handle);
      if (!vm) return -3;
      
      let count = 0;
      while (!vm.halted && (maxInstructions === 0 || count < maxInstructions)) {
        const result = vm.step();
        if (result !== 0) return result;
        count++;
      }
      
      return vm.halted ? 0 : 0;
    },
    
    _nanocore_vm_get_register: (handle, index, valuePtr) => {
      const vm = vms.get(handle);
      if (!vm || index < 0 || index >= 32) return -3;
      
      const value = vm.registers[index];
      module.setValue(valuePtr, value, 'i64');
      return 0;
    },
    
    _nanocore_vm_set_register: (handle, index, value) => {
      const vm = vms.get(handle);
      if (!vm || index < 0 || index >= 32) return -3;
      
      if (index !== 0) { // R0 is always zero
        vm.registers[index] = BigInt(value);
      }
      return 0;
    },
    
    _nanocore_vm_load_program: (handle, dataPtr, size, address) => {
      const vm = vms.get(handle);
      if (!vm) return -3;
      
      const program = new Uint8Array(HEAPU8.buffer, dataPtr, size);
      const vmMemory = new Uint8Array(vm.memory);
      vmMemory.set(program, address);
      vm.pc = BigInt(address);
      
      return 0;
    },
    
    _nanocore_vm_read_memory: (handle, address, bufferPtr, size) => {
      const vm = vms.get(handle);
      if (!vm) return -3;
      
      const vmMemory = new Uint8Array(vm.memory);
      const buffer = new Uint8Array(HEAPU8.buffer, bufferPtr, size);
      buffer.set(vmMemory.slice(address, address + size));
      
      return 0;
    },
    
    _nanocore_vm_write_memory: (handle, address, dataPtr, size) => {
      const vm = vms.get(handle);
      if (!vm) return -3;
      
      const data = new Uint8Array(HEAPU8.buffer, dataPtr, size);
      const vmMemory = new Uint8Array(vm.memory);
      vmMemory.set(data, address);
      
      return 0;
    },
    
    _nanocore_vm_get_state: (handle, statePtr) => {
      const vm = vms.get(handle);
      if (!vm) return -3;
      
      // Write state structure
      let offset = statePtr;
      module.setValue(offset, vm.pc, 'i64'); offset += 8;
      module.setValue(offset, vm.sp, 'i64'); offset += 8;
      module.setValue(offset, vm.flags, 'i64'); offset += 8;
      
      // Write registers
      for (let i = 0; i < 32; i++) {
        module.setValue(offset, vm.registers[i], 'i64');
        offset += 8;
      }
      
      // Skip vector registers (16 * 4 * 8 bytes)
      offset += 16 * 4 * 8;
      
      // Write performance counters
      module.setValue(offset, vm.instructions, 'i64'); offset += 8;
      module.setValue(offset, vm.cycles, 'i64'); offset += 8;
      // Skip remaining counters
      offset += 6 * 8;
      
      return 0;
    },
    
    _nanocore_vm_get_perf_counter: (handle, counter, valuePtr) => {
      const vm = vms.get(handle);
      if (!vm) return -3;
      
      let value = 0n;
      switch (counter) {
        case 0: value = vm.instructions; break;
        case 1: value = vm.cycles; break;
        default: value = 0n;
      }
      
      module.setValue(valuePtr, value, 'i64');
      return 0;
    },
    
    _nanocore_vm_set_breakpoint: (handle, address) => 0,
    _nanocore_vm_clear_breakpoint: (handle, address) => 0,
    _nanocore_vm_poll_event: (handle, typePtr, dataPtr) => -1,
    
    // Memory arrays
    HEAP8, HEAP16, HEAP32, HEAPU8, HEAPU16, HEAPU32, HEAPF32, HEAPF64
  };
  
  return Promise.resolve(module);
};

export default NanoCoreMock;