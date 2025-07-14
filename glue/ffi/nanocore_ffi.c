/*
 * NanoCore FFI - C binding layer for language bindings
 * Provides a stable C API over the assembly VM core
 */

#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <stdbool.h>

// VM state structure (matches assembly layout)
typedef struct {
    uint64_t pc;
    uint64_t sp;
    uint64_t flags;
    uint64_t gprs[32];
    uint64_t vregs[16][4];  // 16 vector registers, 4 elements each
    uint64_t perf_counters[8];
    uint64_t cache_ctrl;
    uint64_t vbase;
} vm_state_t;

// VM instance structure
typedef struct {
    vm_state_t state;
    uint8_t* memory;
    size_t memory_size;
    bool halted;
    uint64_t breakpoints[64];  // Simple breakpoint array
    int num_breakpoints;
    int vm_id;
} vm_instance_t;

// Global VM instances (simple management)
static vm_instance_t* vms[256] = {0};
static int next_vm_id = 1;

// Status codes
enum {
    NANOCORE_OK = 0,
    NANOCORE_ERROR = -1,
    NANOCORE_ENOMEM = -2,
    NANOCORE_EINVAL = -3,
    NANOCORE_EINIT = -4
};

// Event types
enum {
    EVENT_HALTED = 0,
    EVENT_BREAKPOINT = 1,
    EVENT_EXCEPTION = 2,
    EVENT_DEVICE_INTERRUPT = 3
};

// Initialize the NanoCore library
int nanocore_init(void) {
    // Initialize any global state
    return NANOCORE_OK;
}

// Create a new VM instance
int nanocore_vm_create(uint64_t memory_size, int* vm_handle) {
    if (!vm_handle || memory_size == 0) {
        return NANOCORE_EINVAL;
    }
    
    // Find free slot
    int id = -1;
    for (int i = 0; i < 256; i++) {
        if (vms[i] == NULL) {
            id = i;
            break;
        }
    }
    
    if (id == -1) {
        return NANOCORE_ERROR;  // Too many VMs
    }
    
    // Allocate VM instance
    vm_instance_t* vm = calloc(1, sizeof(vm_instance_t));
    if (!vm) {
        return NANOCORE_ENOMEM;
    }
    
    // Allocate memory
    vm->memory = calloc(memory_size, 1);
    if (!vm->memory) {
        free(vm);
        return NANOCORE_ENOMEM;
    }
    
    // Initialize VM
    vm->memory_size = memory_size;
    vm->state.sp = memory_size - 8;  // Stack at top
    vm->state.pc = 0x10000;          // Default entry point
    vm->vm_id = next_vm_id++;
    vm->halted = false;
    vm->num_breakpoints = 0;
    
    vms[id] = vm;
    *vm_handle = id;
    
    return NANOCORE_OK;
}

// Destroy VM instance
int nanocore_vm_destroy(int vm_handle) {
    if (vm_handle < 0 || vm_handle >= 256 || !vms[vm_handle]) {
        return NANOCORE_EINVAL;
    }
    
    vm_instance_t* vm = vms[vm_handle];
    free(vm->memory);
    free(vm);
    vms[vm_handle] = NULL;
    
    return NANOCORE_OK;
}

// Reset VM to initial state
int nanocore_vm_reset(int vm_handle) {
    if (vm_handle < 0 || vm_handle >= 256 || !vms[vm_handle]) {
        return NANOCORE_EINVAL;
    }
    
    vm_instance_t* vm = vms[vm_handle];
    
    // Clear registers
    memset(&vm->state, 0, sizeof(vm_state_t));
    
    // Reset state
    vm->state.sp = vm->memory_size - 8;
    vm->state.pc = 0x10000;
    vm->halted = false;
    vm->num_breakpoints = 0;
    
    return NANOCORE_OK;
}

// Simple instruction decoder and executor
static int execute_instruction(vm_instance_t* vm, uint32_t instruction) {
    uint8_t opcode = (instruction >> 26) & 0x3F;
    uint8_t rd = (instruction >> 21) & 0x1F;
    uint8_t rs1 = (instruction >> 16) & 0x1F;
    uint8_t rs2 = (instruction >> 11) & 0x1F;
    int16_t imm = instruction & 0xFFFF;
    
    // Ensure R0 is always zero
    vm->state.gprs[0] = 0;
    
    switch (opcode) {
        case 0x00:  // ADD
            if (rd != 0) {
                vm->state.gprs[rd] = vm->state.gprs[rs1] + vm->state.gprs[rs2];
            }
            break;
            
        case 0x01:  // SUB
            if (rd != 0) {
                vm->state.gprs[rd] = vm->state.gprs[rs1] - vm->state.gprs[rs2];
            }
            break;
            
        case 0x02:  // MUL
            if (rd != 0) {
                vm->state.gprs[rd] = vm->state.gprs[rs1] * vm->state.gprs[rs2];
            }
            break;
            
        case 0x04:  // DIV
            if (rd != 0 && vm->state.gprs[rs2] != 0) {
                vm->state.gprs[rd] = vm->state.gprs[rs1] / vm->state.gprs[rs2];
            }
            break;
            
        case 0x05:  // MOD
            if (rd != 0 && vm->state.gprs[rs2] != 0) {
                vm->state.gprs[rd] = vm->state.gprs[rs1] % vm->state.gprs[rs2];
            }
            break;
            
        case 0x06:  // AND
            if (rd != 0) {
                vm->state.gprs[rd] = vm->state.gprs[rs1] & vm->state.gprs[rs2];
            }
            break;
            
        case 0x07:  // OR
            if (rd != 0) {
                vm->state.gprs[rd] = vm->state.gprs[rs1] | vm->state.gprs[rs2];
            }
            break;
            
        case 0x08:  // XOR
            if (rd != 0) {
                vm->state.gprs[rd] = vm->state.gprs[rs1] ^ vm->state.gprs[rs2];
            }
            break;
            
        case 0x0A:  // SHL
            if (rd != 0) {
                vm->state.gprs[rd] = vm->state.gprs[rs1] << (vm->state.gprs[rs2] & 63);
            }
            break;
            
        case 0x0B:  // SHR
            if (rd != 0) {
                vm->state.gprs[rd] = vm->state.gprs[rs1] >> (vm->state.gprs[rs2] & 63);
            }
            break;
            
        case 0x0F:  // LD (load immediate for now)
            if (rd != 0) {
                vm->state.gprs[rd] = (uint64_t)(int64_t)imm;  // Sign extend
            }
            break;
            
        case 0x13:  // ST (simplified)
            {
                uint64_t addr = vm->state.gprs[rs1] + imm;
                if (addr + 8 <= vm->memory_size) {
                    *(uint64_t*)(vm->memory + addr) = vm->state.gprs[rd];
                }
            }
            break;
            
        case 0x17:  // BEQ
            if (vm->state.gprs[rd] == vm->state.gprs[rs1]) {
                vm->state.pc += (imm << 1) - 4;  // PC will be incremented by 4 later
            }
            break;
            
        case 0x18:  // BNE
            if (vm->state.gprs[rd] != vm->state.gprs[rs1]) {
                vm->state.pc += (imm << 1) - 4;
            }
            break;
            
        case 0x19:  // BLT
            if ((int64_t)vm->state.gprs[rd] < (int64_t)vm->state.gprs[rs1]) {
                vm->state.pc += (imm << 1) - 4;
            }
            break;
            
        case 0x21:  // HALT
            vm->halted = true;
            vm->state.flags |= 0x80;
            return EVENT_HALTED;
            
        case 0x22:  // NOP
            break;
            
        default:
            // Unknown instruction
            vm->halted = true;
            return NANOCORE_ERROR;
    }
    
    // Update performance counters
    vm->state.perf_counters[0]++;  // Instruction count
    vm->state.perf_counters[1]++;  // Cycle count
    
    return NANOCORE_OK;
}

// Execute single instruction
int nanocore_vm_step(int vm_handle) {
    if (vm_handle < 0 || vm_handle >= 256 || !vms[vm_handle]) {
        return NANOCORE_EINVAL;
    }
    
    vm_instance_t* vm = vms[vm_handle];
    
    if (vm->halted) {
        return EVENT_HALTED;
    }
    
    // Check bounds
    if (vm->state.pc + 4 > vm->memory_size) {
        vm->halted = true;
        return NANOCORE_ERROR;
    }
    
    // Check breakpoints
    for (int i = 0; i < vm->num_breakpoints; i++) {
        if (vm->breakpoints[i] == vm->state.pc) {
            return EVENT_BREAKPOINT;
        }
    }
    
    // Fetch instruction
    uint32_t instruction = *(uint32_t*)(vm->memory + vm->state.pc);
    
    // Execute
    vm->state.pc += 4;
    return execute_instruction(vm, instruction);
}

// Run VM for specified number of instructions
int nanocore_vm_run(int vm_handle, uint64_t max_instructions) {
    if (vm_handle < 0 || vm_handle >= 256 || !vms[vm_handle]) {
        return NANOCORE_EINVAL;
    }
    
    vm_instance_t* vm = vms[vm_handle];
    uint64_t count = 0;
    
    while (!vm->halted && (max_instructions == 0 || count < max_instructions)) {
        int result = nanocore_vm_step(vm_handle);
        if (result != NANOCORE_OK) {
            return result;
        }
        count++;
    }
    
    return vm->halted ? EVENT_HALTED : NANOCORE_OK;
}

// Get VM state
int nanocore_vm_get_state(int vm_handle, vm_state_t* state) {
    if (vm_handle < 0 || vm_handle >= 256 || !vms[vm_handle] || !state) {
        return NANOCORE_EINVAL;
    }
    
    *state = vms[vm_handle]->state;
    return NANOCORE_OK;
}

// Get register value
int nanocore_vm_get_register(int vm_handle, int reg_index, uint64_t* value) {
    if (vm_handle < 0 || vm_handle >= 256 || !vms[vm_handle] || 
        reg_index < 0 || reg_index >= 32 || !value) {
        return NANOCORE_EINVAL;
    }
    
    *value = vms[vm_handle]->state.gprs[reg_index];
    return NANOCORE_OK;
}

// Set register value
int nanocore_vm_set_register(int vm_handle, int reg_index, uint64_t value) {
    if (vm_handle < 0 || vm_handle >= 256 || !vms[vm_handle] || 
        reg_index < 0 || reg_index >= 32) {
        return NANOCORE_EINVAL;
    }
    
    if (reg_index != 0) {  // R0 is hardwired to zero
        vms[vm_handle]->state.gprs[reg_index] = value;
    }
    
    return NANOCORE_OK;
}

// Load program into memory
int nanocore_vm_load_program(int vm_handle, const uint8_t* data, uint64_t size, uint64_t address) {
    if (vm_handle < 0 || vm_handle >= 256 || !vms[vm_handle] || !data) {
        return NANOCORE_EINVAL;
    }
    
    vm_instance_t* vm = vms[vm_handle];
    
    if (address + size > vm->memory_size) {
        return NANOCORE_EINVAL;
    }
    
    memcpy(vm->memory + address, data, size);
    vm->state.pc = address;  // Set PC to start of program
    
    return NANOCORE_OK;
}

// Read memory
int nanocore_vm_read_memory(int vm_handle, uint64_t address, uint8_t* buffer, uint64_t size) {
    if (vm_handle < 0 || vm_handle >= 256 || !vms[vm_handle] || !buffer) {
        return NANOCORE_EINVAL;
    }
    
    vm_instance_t* vm = vms[vm_handle];
    
    if (address + size > vm->memory_size) {
        return NANOCORE_EINVAL;
    }
    
    memcpy(buffer, vm->memory + address, size);
    return NANOCORE_OK;
}

// Write memory
int nanocore_vm_write_memory(int vm_handle, uint64_t address, const uint8_t* data, uint64_t size) {
    if (vm_handle < 0 || vm_handle >= 256 || !vms[vm_handle] || !data) {
        return NANOCORE_EINVAL;
    }
    
    vm_instance_t* vm = vms[vm_handle];
    
    if (address + size > vm->memory_size) {
        return NANOCORE_EINVAL;
    }
    
    memcpy(vm->memory + address, data, size);
    return NANOCORE_OK;
}

// Set breakpoint
int nanocore_vm_set_breakpoint(int vm_handle, uint64_t address) {
    if (vm_handle < 0 || vm_handle >= 256 || !vms[vm_handle]) {
        return NANOCORE_EINVAL;
    }
    
    vm_instance_t* vm = vms[vm_handle];
    
    if (vm->num_breakpoints >= 64) {
        return NANOCORE_ERROR;  // Too many breakpoints
    }
    
    vm->breakpoints[vm->num_breakpoints++] = address;
    return NANOCORE_OK;
}

// Clear breakpoint
int nanocore_vm_clear_breakpoint(int vm_handle, uint64_t address) {
    if (vm_handle < 0 || vm_handle >= 256 || !vms[vm_handle]) {
        return NANOCORE_EINVAL;
    }
    
    vm_instance_t* vm = vms[vm_handle];
    
    for (int i = 0; i < vm->num_breakpoints; i++) {
        if (vm->breakpoints[i] == address) {
            // Remove by shifting others down
            for (int j = i; j < vm->num_breakpoints - 1; j++) {
                vm->breakpoints[j] = vm->breakpoints[j + 1];
            }
            vm->num_breakpoints--;
            return NANOCORE_OK;
        }
    }
    
    return NANOCORE_ERROR;  // Breakpoint not found
}

// Get performance counter
int nanocore_vm_get_perf_counter(int vm_handle, int counter_index, uint64_t* value) {
    if (vm_handle < 0 || vm_handle >= 256 || !vms[vm_handle] || 
        counter_index < 0 || counter_index >= 8 || !value) {
        return NANOCORE_EINVAL;
    }
    
    *value = vms[vm_handle]->state.perf_counters[counter_index];
    return NANOCORE_OK;
}

// Poll for events (simplified)
int nanocore_vm_poll_event(int vm_handle, int* event_type, uint64_t* event_data) {
    if (vm_handle < 0 || vm_handle >= 256 || !vms[vm_handle] || !event_type || !event_data) {
        return NANOCORE_EINVAL;
    }
    
    vm_instance_t* vm = vms[vm_handle];
    
    if (vm->halted) {
        *event_type = EVENT_HALTED;
        *event_data = 0;
        return NANOCORE_OK;
    }
    
    // No events pending
    return NANOCORE_ERROR;
}