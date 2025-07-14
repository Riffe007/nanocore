/*
 * Simple NanoCore VM Implementation for Testing
 * This is a minimal implementation to verify our instruction encoding
 */

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>

// Simple VM structure
typedef struct {
    uint64_t pc;
    uint64_t gprs[32];
    uint64_t flags;
    uint8_t* memory;
    size_t memory_size;
    int halted;
} SimpleVM;

// Create VM
SimpleVM* vm_create(size_t memory_size) {
    SimpleVM* vm = calloc(1, sizeof(SimpleVM));
    vm->memory = calloc(memory_size, 1);
    vm->memory_size = memory_size;
    return vm;
}

void vm_destroy(SimpleVM* vm) {
    free(vm->memory);
    free(vm);
}

// Load program into memory
void vm_load_program(SimpleVM* vm, uint32_t* program, size_t size, uint64_t address) {
    memcpy(vm->memory + address, program, size * sizeof(uint32_t));
}

// Execute one instruction
int vm_step(SimpleVM* vm) {
    if (vm->halted) return 0;
    
    // Fetch instruction
    uint32_t inst = *(uint32_t*)(vm->memory + vm->pc);
    
    // Decode
    uint8_t opcode = (inst >> 26) & 0x3F;
    uint8_t rd = (inst >> 21) & 0x1F;
    uint8_t rs1 = (inst >> 16) & 0x1F;
    uint8_t rs2 = (inst >> 11) & 0x1F;
    uint16_t imm16 = inst & 0xFFFF;
    
    // For now, treat immediate as unsigned
    
    printf("PC=0x%lx: opcode=0x%02x rd=R%d rs1=R%d rs2=R%d imm=0x%04x\n",
           vm->pc, opcode, rd, rs1, rs2, imm16);
    
    // Execute
    switch (opcode) {
        case 0x00:  // ADD
            if (rd != 0) {
                vm->gprs[rd] = vm->gprs[rs1] + vm->gprs[rs2];
                printf("  ADD R%d = R%d + R%d = %lu + %lu = %lu\n",
                       rd, rs1, rs2, vm->gprs[rs1], vm->gprs[rs2], vm->gprs[rd]);
            }
            break;
            
        case 0x0F:  // LD (immediate load for testing)
            if (rd != 0) {
                vm->gprs[rd] = imm16;
                printf("  LD R%d = %d\n", rd, imm16);
            }
            break;
            
        case 0x21:  // HALT
            printf("  HALT\n");
            vm->halted = 1;
            return 0;
            
        default:
            printf("  Unknown opcode: 0x%02x\n", opcode);
            return -1;
    }
    
    vm->pc += 4;
    return 0;
}

// Run VM
int vm_run(SimpleVM* vm, int max_steps) {
    int steps = 0;
    while (!vm->halted && steps < max_steps) {
        if (vm_step(vm) < 0) {
            return -1;
        }
        steps++;
    }
    return steps;
}

int main() {
    printf("Simple NanoCore VM Test\n");
    printf("=======================\n\n");
    
    // Create VM
    SimpleVM* vm = vm_create(64 * 1024);
    
    // Test program: Load two values and add them
    uint32_t program[] = {
        0x3C200005,  // LD R1, 5    (opcode=0F, rd=1, rs1=0, imm=5)
        0x3C40000A,  // LD R2, 10   (opcode=0F, rd=2, rs1=0, imm=10)
        0x00614000,  // ADD R3, R1, R2 (opcode=00, rd=3, rs1=1, rs2=2)
        0x84000000,  // HALT        (opcode=21)
    };
    
    // Load and run
    vm_load_program(vm, program, 4, 0x10000);
    vm->pc = 0x10000;
    
    printf("Running program...\n");
    printf("-----------------\n");
    
    int steps = vm_run(vm, 10);
    
    printf("\nExecution complete!\n");
    printf("Steps executed: %d\n", steps);
    printf("\nFinal register values:\n");
    printf("  R1 = %lu (expected: 5)\n", vm->gprs[1]);
    printf("  R2 = %lu (expected: 10)\n", vm->gprs[2]);
    printf("  R3 = %lu (expected: 15)\n", vm->gprs[3]);
    
    int success = (vm->gprs[1] == 5 && vm->gprs[2] == 10 && vm->gprs[3] == 15);
    printf("\nTest result: %s\n", success ? "PASS" : "FAIL");
    
    vm_destroy(vm);
    return success ? 0 : 1;
}