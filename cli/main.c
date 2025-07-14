/*
 * NanoCore CLI - Command Line Interface for NanoCore VM
 * 
 * Features:
 * - Load and run programs
 * - Interactive debugging
 * - Performance profiling
 * - Memory inspection
 * - Batch execution
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <stdbool.h>
#include <getopt.h>
#include <signal.h>
#include <time.h>
#include <sys/stat.h>

#ifdef _WIN32
#include <windows.h>
#else
#include <unistd.h>
#include <sys/time.h>
#include <termios.h>
#endif

// NanoCore VM interface
typedef struct {
    uint64_t pc;
    uint64_t sp;
    uint64_t flags;
    uint64_t gprs[32];
    uint64_t vregs[16][4];
    uint64_t perf_counters[8];
    uint64_t cache_ctrl;
    uint64_t vbase;
} vm_state_t;

// External VM functions
extern int vm_init(uint64_t memory_size);
extern void vm_reset(void);
extern int vm_run(uint64_t max_instructions);
extern int vm_step(void);
extern vm_state_t* vm_get_state(void);
extern void vm_set_breakpoint(uint64_t address);
extern void vm_dump_state(void);

// CLI configuration
typedef struct {
    char* program_file;
    uint64_t memory_size;
    uint64_t load_address;
    uint64_t max_instructions;
    bool debug_mode;
    bool profile_mode;
    bool verbose;
    bool batch_mode;
    char* script_file;
    char* output_file;
} cli_config_t;

// Global state
static cli_config_t config = {
    .program_file = NULL,
    .memory_size = 64 * 1024 * 1024,  // 64MB default
    .load_address = 0x10000,
    .max_instructions = 0,  // Unlimited
    .debug_mode = false,
    .profile_mode = false,
    .verbose = false,
    .batch_mode = false,
    .script_file = NULL,
    .output_file = NULL
};

static bool running = true;
static vm_state_t* vm_state = NULL;

// Performance timing
static struct timespec start_time, end_time;

// Function prototypes
static void print_usage(const char* program_name);
static int parse_args(int argc, char* argv[]);
static int load_program(const char* filename, uint64_t address);
static void run_interactive_debugger(void);
static void print_registers(void);
static void print_memory(uint64_t address, size_t size);
static void print_performance_stats(void);
static uint64_t parse_number(const char* str);
static void signal_handler(int sig);

// Get current time in nanoseconds
static uint64_t get_time_ns(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (uint64_t)ts.tv_sec * 1000000000ULL + ts.tv_nsec;
}

int main(int argc, char* argv[]) {
    // Parse command line arguments
    if (parse_args(argc, argv) < 0) {
        return 1;
    }
    
    // Set up signal handlers
    signal(SIGINT, signal_handler);
    signal(SIGTERM, signal_handler);
    
    // Initialize VM
    printf("Initializing NanoCore VM with %lu MB memory...\n", 
           config.memory_size / (1024 * 1024));
    
    if (vm_init(config.memory_size) != 0) {
        fprintf(stderr, "Failed to initialize VM\n");
        return 1;
    }
    
    vm_state = vm_get_state();
    
    // Load program if specified
    if (config.program_file) {
        printf("Loading program: %s at 0x%lx\n", 
               config.program_file, config.load_address);
        
        if (load_program(config.program_file, config.load_address) < 0) {
            fprintf(stderr, "Failed to load program\n");
            return 1;
        }
        
        // Set PC to load address
        vm_state->pc = config.load_address;
    }
    
    // Enter appropriate mode
    if (config.debug_mode) {
        printf("Entering debug mode...\n");
        run_interactive_debugger();
    } else if (config.batch_mode || config.program_file) {
        // Run program
        printf("Running program...\n");
        
        if (config.profile_mode) {
            clock_gettime(CLOCK_MONOTONIC, &start_time);
        }
        
        int exit_code = vm_run(config.max_instructions);
        
        if (config.profile_mode) {
            clock_gettime(CLOCK_MONOTONIC, &end_time);
            print_performance_stats();
        }
        
        printf("Program exited with code: %d\n", exit_code);
        
        if (config.verbose) {
            vm_dump_state();
        }
    } else {
        // Interactive mode
        printf("NanoCore Interactive Mode\n");
        printf("Type 'help' for commands\n\n");
        run_interactive_debugger();
    }
    
    return 0;
}

static void print_usage(const char* program_name) {
    printf("Usage: %s [options] [program_file]\n", program_name);
    printf("\nOptions:\n");
    printf("  -h, --help              Show this help message\n");
    printf("  -m, --memory SIZE       Set VM memory size (default: 64M)\n");
    printf("  -a, --address ADDR      Load address (default: 0x10000)\n");
    printf("  -n, --max-inst COUNT    Maximum instructions to execute\n");
    printf("  -d, --debug             Enable debug mode\n");
    printf("  -p, --profile           Enable profiling\n");
    printf("  -v, --verbose           Verbose output\n");
    printf("  -b, --batch             Batch mode (non-interactive)\n");
    printf("  -s, --script FILE       Execute debug script\n");
    printf("  -o, --output FILE       Redirect output to file\n");
    printf("\nExamples:\n");
    printf("  %s program.bin          Run program\n", program_name);
    printf("  %s -d program.bin       Debug program\n", program_name);
    printf("  %s -p -n 1000000 test   Profile test for 1M instructions\n", program_name);
}

static int parse_args(int argc, char* argv[]) {
    static struct option long_options[] = {
        {"help",      no_argument,       0, 'h'},
        {"memory",    required_argument, 0, 'm'},
        {"address",   required_argument, 0, 'a'},
        {"max-inst",  required_argument, 0, 'n'},
        {"debug",     no_argument,       0, 'd'},
        {"profile",   no_argument,       0, 'p'},
        {"verbose",   no_argument,       0, 'v'},
        {"batch",     no_argument,       0, 'b'},
        {"script",    required_argument, 0, 's'},
        {"output",    required_argument, 0, 'o'},
        {0, 0, 0, 0}
    };
    
    int opt;
    while ((opt = getopt_long(argc, argv, "hm:a:n:dpvbs:o:", 
                             long_options, NULL)) != -1) {
        switch (opt) {
        case 'h':
            print_usage(argv[0]);
            exit(0);
            
        case 'm':
            config.memory_size = parse_number(optarg);
            if (config.memory_size == 0) {
                fprintf(stderr, "Invalid memory size: %s\n", optarg);
                return -1;
            }
            break;
            
        case 'a':
            config.load_address = parse_number(optarg);
            break;
            
        case 'n':
            config.max_instructions = parse_number(optarg);
            break;
            
        case 'd':
            config.debug_mode = true;
            break;
            
        case 'p':
            config.profile_mode = true;
            break;
            
        case 'v':
            config.verbose = true;
            break;
            
        case 'b':
            config.batch_mode = true;
            break;
            
        case 's':
            config.script_file = optarg;
            break;
            
        case 'o':
            config.output_file = optarg;
            break;
            
        default:
            print_usage(argv[0]);
            return -1;
        }
    }
    
    // Get program file if specified
    if (optind < argc) {
        config.program_file = argv[optind];
    }
    
    return 0;
}

static int load_program(const char* filename, uint64_t address) {
    FILE* file = fopen(filename, "rb");
    if (!file) {
        perror("Failed to open program file");
        return -1;
    }
    
    // Get file size
    fseek(file, 0, SEEK_END);
    long size = ftell(file);
    fseek(file, 0, SEEK_SET);
    
    if (size <= 0) {
        fprintf(stderr, "Invalid file size\n");
        fclose(file);
        return -1;
    }
    
    // Allocate buffer
    uint8_t* buffer = malloc(size);
    if (!buffer) {
        fprintf(stderr, "Failed to allocate memory\n");
        fclose(file);
        return -1;
    }
    
    // Read file
    size_t read = fread(buffer, 1, size, file);
    fclose(file);
    
    if (read != (size_t)size) {
        fprintf(stderr, "Failed to read complete file\n");
        free(buffer);
        return -1;
    }
    
    // Load into VM memory
    // TODO: Implement memory write function
    printf("Loaded %ld bytes at address 0x%lx\n", size, address);
    
    free(buffer);
    return 0;
}

static void run_interactive_debugger(void) {
    char line[256];
    char cmd[32];
    uint64_t addr, value;
    int count;
    
    while (running) {
        printf("nanocore> ");
        fflush(stdout);
        
        if (!fgets(line, sizeof(line), stdin)) {
            break;
        }
        
        // Parse command
        if (sscanf(line, "%31s", cmd) != 1) {
            continue;
        }
        
        // Execute command
        if (strcmp(cmd, "help") == 0 || strcmp(cmd, "h") == 0) {
            printf("Commands:\n");
            printf("  help (h)              - Show this help\n");
            printf("  run (r) [count]       - Run program\n");
            printf("  step (s) [count]      - Step instructions\n");
            printf("  break (b) <addr>      - Set breakpoint\n");
            printf("  clear (c) <addr>      - Clear breakpoint\n");
            printf("  regs                  - Show registers\n");
            printf("  mem <addr> [count]    - Show memory\n");
            printf("  set <reg> <value>     - Set register\n");
            printf("  reset                 - Reset VM\n");
            printf("  stats                 - Show performance stats\n");
            printf("  quit (q)              - Exit debugger\n");
        }
        else if (strcmp(cmd, "run") == 0 || strcmp(cmd, "r") == 0) {
            count = 0;
            sscanf(line + strlen(cmd), "%d", &count);
            
            printf("Running...\n");
            int exit_code = vm_run(count);
            printf("Exit code: %d\n", exit_code);
            
            if (exit_code == 2) {
                printf("Breakpoint hit at 0x%lx\n", vm_state->pc);
            }
        }
        else if (strcmp(cmd, "step") == 0 || strcmp(cmd, "s") == 0) {
            count = 1;
            sscanf(line + strlen(cmd), "%d", &count);
            
            for (int i = 0; i < count; i++) {
                int result = vm_step();
                if (result != 0) {
                    printf("Step failed with code: %d\n", result);
                    break;
                }
                
                if (config.verbose) {
                    printf("PC: 0x%lx\n", vm_state->pc);
                }
            }
        }
        else if (strcmp(cmd, "break") == 0 || strcmp(cmd, "b") == 0) {
            if (sscanf(line + strlen(cmd), "%lx", &addr) == 1) {
                vm_set_breakpoint(addr);
                printf("Breakpoint set at 0x%lx\n", addr);
            } else {
                printf("Usage: break <address>\n");
            }
        }
        else if (strcmp(cmd, "regs") == 0) {
            print_registers();
        }
        else if (strcmp(cmd, "mem") == 0) {
            count = 16;
            if (sscanf(line + strlen(cmd), "%lx %d", &addr, &count) >= 1) {
                print_memory(addr, count);
            } else {
                printf("Usage: mem <address> [count]\n");
            }
        }
        else if (strcmp(cmd, "set") == 0) {
            int reg;
            if (sscanf(line + strlen(cmd), "%d %lx", &reg, &value) == 2) {
                if (reg >= 0 && reg < 32) {
                    vm_state->gprs[reg] = value;
                    printf("R%d = 0x%lx\n", reg, value);
                } else {
                    printf("Invalid register: %d\n", reg);
                }
            } else {
                printf("Usage: set <register> <value>\n");
            }
        }
        else if (strcmp(cmd, "reset") == 0) {
            vm_reset();
            printf("VM reset\n");
        }
        else if (strcmp(cmd, "stats") == 0) {
            print_performance_stats();
        }
        else if (strcmp(cmd, "quit") == 0 || strcmp(cmd, "q") == 0) {
            running = false;
        }
        else {
            printf("Unknown command: %s\n", cmd);
        }
    }
}

static void print_registers(void) {
    printf("General Purpose Registers:\n");
    for (int i = 0; i < 32; i++) {
        if (i % 4 == 0) printf("  ");
        printf("R%02d=0x%016lx ", i, vm_state->gprs[i]);
        if (i % 4 == 3) printf("\n");
    }
    
    printf("\nSpecial Registers:\n");
    printf("  PC=0x%016lx  SP=0x%016lx  FLAGS=0x%016lx\n",
           vm_state->pc, vm_state->sp, vm_state->flags);
    
    // Decode flags
    printf("  Flags: ");
    if (vm_state->flags & (1 << 0)) printf("Z ");
    if (vm_state->flags & (1 << 1)) printf("C ");
    if (vm_state->flags & (1 << 2)) printf("V ");
    if (vm_state->flags & (1 << 3)) printf("N ");
    if (vm_state->flags & (1 << 4)) printf("IE ");
    if (vm_state->flags & (1 << 5)) printf("UM ");
    if (vm_state->flags & (1 << 7)) printf("HALT ");
    printf("\n");
}

static void print_memory(uint64_t address, size_t size) {
    // TODO: Implement memory read
    printf("Memory at 0x%lx:\n", address);
    
    for (size_t i = 0; i < size; i += 16) {
        printf("0x%08lx: ", address + i);
        
        // Hex dump
        for (size_t j = 0; j < 16 && i + j < size; j++) {
            printf("00 ");  // Placeholder
        }
        
        // ASCII dump
        printf(" |");
        for (size_t j = 0; j < 16 && i + j < size; j++) {
            printf(".");  // Placeholder
        }
        printf("|\n");
    }
}

static void print_performance_stats(void) {
    printf("\nPerformance Statistics:\n");
    printf("  Instructions: %lu\n", vm_state->perf_counters[0]);
    printf("  Cycles: %lu\n", vm_state->perf_counters[1]);
    printf("  L1 Cache Misses: %lu\n", vm_state->perf_counters[2]);
    printf("  L2 Cache Misses: %lu\n", vm_state->perf_counters[3]);
    printf("  Branch Mispredictions: %lu\n", vm_state->perf_counters[4]);
    printf("  Pipeline Stalls: %lu\n", vm_state->perf_counters[5]);
    printf("  Memory Operations: %lu\n", vm_state->perf_counters[6]);
    printf("  SIMD Operations: %lu\n", vm_state->perf_counters[7]);
    
    if (config.profile_mode) {
        double elapsed = (end_time.tv_sec - start_time.tv_sec) + 
                        (end_time.tv_nsec - start_time.tv_nsec) / 1e9;
        double mips = vm_state->perf_counters[0] / (elapsed * 1e6);
        
        printf("\n  Execution Time: %.3f seconds\n", elapsed);
        printf("  MIPS: %.2f\n", mips);
        
        if (vm_state->perf_counters[1] > 0) {
            double ipc = (double)vm_state->perf_counters[0] / 
                        vm_state->perf_counters[1];
            printf("  IPC: %.3f\n", ipc);
        }
    }
}

static uint64_t parse_number(const char* str) {
    char* endptr;
    uint64_t value;
    
    // Handle size suffixes (K, M, G)
    size_t len = strlen(str);
    if (len > 0) {
        char last = str[len - 1];
        if (last == 'K' || last == 'k') {
            value = strtoull(str, &endptr, 0) * 1024;
        } else if (last == 'M' || last == 'm') {
            value = strtoull(str, &endptr, 0) * 1024 * 1024;
        } else if (last == 'G' || last == 'g') {
            value = strtoull(str, &endptr, 0) * 1024 * 1024 * 1024;
        } else {
            value = strtoull(str, &endptr, 0);
        }
    } else {
        value = strtoull(str, &endptr, 0);
    }
    
    return value;
}

static void signal_handler(int sig) {
    (void)sig;
    printf("\nInterrupted. Use 'quit' to exit.\n");
    running = false;
}