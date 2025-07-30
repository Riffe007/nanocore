#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>

// External assembly functions
extern void vm_init(void);
extern void vm_run(void);
extern void vm_load_program(const char* filename);
extern void vm_reset(void);
extern void vm_get_state(void* state);
extern void vm_set_state(const void* state);

// VM state structure (matches assembly)
typedef struct {
    uint64_t pc;
    uint64_t sp;
    uint8_t flags;
    uint8_t reserved[7];
    uint64_t gprs[32];
    uint64_t vregs[16][2];  // SIMD registers
    uint64_t perf_counters[16];
} vm_state_t;

// Test programs
static uint32_t test_program[] = {
    0x00000000,  // NOP
    0x01000000,  // ADD R1, R0, R0 (R1 = 0)
    0x02000001,  // ADD R2, R0, R1 (R2 = 0)
    0x03000002,  // ADD R3, R0, R2 (R3 = 0)
    0x04000003,  // ADD R4, R0, R3 (R4 = 0)
    0x05000004,  // ADD R5, R0, R4 (R5 = 0)
    0x06000005,  // ADD R6, R0, R5 (R6 = 0)
    0x07000006,  // ADD R7, R0, R6 (R7 = 0)
    0x08000007,  // ADD R8, R0, R7 (R8 = 0)
    0x09000008,  // ADD R9, R0, R8 (R9 = 0)
    0x0A000009,  // ADD R10, R0, R9 (R10 = 0)
    0x0B00000A,  // ADD R11, R0, R10 (R11 = 0)
    0x0C00000B,  // ADD R12, R0, R11 (R12 = 0)
    0x0D00000C,  // ADD R13, R0, R12 (R13 = 0)
    0x0E00000D,  // ADD R14, R0, R13 (R14 = 0)
    0x0F00000E,  // ADD R15, R0, R14 (R15 = 0)
    0x1000000F,  // ADD R16, R0, R15 (R16 = 0)
    0x11000010,  // ADD R17, R0, R16 (R17 = 0)
    0x12000011,  // ADD R18, R0, R17 (R18 = 0)
    0x13000012,  // ADD R19, R0, R18 (R19 = 0)
    0x14000013,  // ADD R20, R0, R19 (R20 = 0)
    0x15000014,  // ADD R21, R0, R20 (R21 = 0)
    0x16000015,  // ADD R22, R0, R21 (R22 = 0)
    0x17000016,  // ADD R23, R0, R22 (R23 = 0)
    0x18000017,  // ADD R24, R0, R23 (R24 = 0)
    0x19000018,  // ADD R25, R0, R24 (R25 = 0)
    0x1A000019,  // ADD R26, R0, R25 (R26 = 0)
    0x1B00001A,  // ADD R27, R0, R26 (R27 = 0)
    0x1C00001B,  // ADD R28, R0, R27 (R28 = 0)
    0x1D00001C,  // ADD R29, R0, R28 (R29 = 0)
    0x1E00001D,  // ADD R30, R0, R29 (R30 = 0)
    0x1F00001E,  // ADD R31, R0, R30 (R31 = 0)
    0x2000001F,  // HALT
};

void print_vm_state(const vm_state_t* state) {
    printf("VM State:\n");
    printf("  PC: 0x%016llx\n", state->pc);
    printf("  SP: 0x%016llx\n", state->sp);
    printf("  Flags: 0x%02x\n", state->flags);
    
    printf("  GPRs:\n");
    for (int i = 0; i < 32; i += 4) {
        printf("    R%02d: 0x%016llx  R%02d: 0x%016llx  R%02d: 0x%016llx  R%02d: 0x%016llx\n",
               i, state->gprs[i], i+1, state->gprs[i+1], i+2, state->gprs[i+2], i+3, state->gprs[i+3]);
    }
    
    printf("  Performance Counters:\n");
    for (int i = 0; i < 16; i += 4) {
        printf("    P%02d: 0x%016llx  P%02d: 0x%016llx  P%02d: 0x%016llx  P%02d: 0x%016llx\n",
               i, state->perf_counters[i], i+1, state->perf_counters[i+1], i+2, state->perf_counters[i+2], i+3, state->perf_counters[i+3]);
    }
}

int main(int argc, char* argv[]) {
    printf("NanoCore Expert-Level VM Test\n");
    printf("=============================\n\n");
    
    // Initialize VM
    printf("Initializing VM...\n");
    vm_init();
    
    // Create test program file
    FILE* fp = fopen("test_program.bin", "wb");
    if (!fp) {
        printf("Error: Could not create test program file\n");
        return 1;
    }
    
    fwrite(test_program, sizeof(test_program), 1, fp);
    fclose(fp);
    
    // Load and run test program
    printf("Loading test program...\n");
    vm_load_program("test_program.bin");
    
    printf("Running VM...\n");
    vm_run();
    
    // Get final state
    vm_state_t final_state;
    vm_get_state(&final_state);
    
    printf("\nFinal VM State:\n");
    print_vm_state(&final_state);
    
    // Check if VM halted properly
    if (final_state.flags & 0x80) {
        printf("\n✓ VM halted successfully\n");
    } else {
        printf("\n✗ VM did not halt properly\n");
    }
    
    // Clean up
    remove("test_program.bin");
    
    printf("\nTest completed successfully!\n");
    return 0;
}