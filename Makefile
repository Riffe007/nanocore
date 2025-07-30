# NanoCore VM Makefile
# Builds the expert-level virtual machine

# Configuration
VERSION = 1.0.0
PRODUCT_NAME = NanoCore VM

# Directories
BUILD_DIR = build
OBJ_DIR = $(BUILD_DIR)/obj
BIN_DIR = $(BUILD_DIR)/bin
LIB_DIR = $(BUILD_DIR)/lib

# Source directories
ASM_CORE_DIR = asm/core
ASM_DEVICES_DIR = asm/devices
ASM_LABS_DIR = asm/labs
GLUE_DIR = glue
CLI_DIR = cli
TEST_DIR = tests

# Compiler and assembler
CC = gcc
AS = nasm
AR = ar
LD = ld

# Detect OS
ifeq ($(OS),Windows_NT)
    PLATFORM = win64
    BIN_EXT = .exe
    LIB_EXT = .dll
    STATIC_LIB_EXT = .lib
    OBJ_EXT = .obj
    ASFLAGS = -f win64 -g -F cv8
    CFLAGS = -O2 -Wall -Wextra -std=c99 -D_CRT_SECURE_NO_WARNINGS
    LDFLAGS = -static
else
    PLATFORM = elf64
    BIN_EXT = 
    LIB_EXT = .so
    STATIC_LIB_EXT = .a
    OBJ_EXT = .o
    ASFLAGS = -f elf64 -g -F dwarf
    CFLAGS = -O2 -Wall -Wextra -std=c99 -fPIC
    LDFLAGS = 
endif

# Debug flags
ifeq ($(DEBUG),1)
    CFLAGS += -g -DDEBUG
    ASFLAGS += -g
else
    CFLAGS += -DNDEBUG
endif

# Optimization flags
ifeq ($(RELEASE),1)
    CFLAGS += -O3 -march=native
    ASFLAGS += -O2
endif

# Target binaries
NANOCORE_CLI = $(BIN_DIR)/nanocore-cli$(BIN_EXT)
NANOCORE_LIB = $(LIB_DIR)/libnanocore$(STATIC_LIB_EXT)
NANOCORE_SHARED = $(LIB_DIR)/libnanocore$(LIB_EXT)

# Assembly source files
ASM_CORE_SOURCES = $(wildcard $(ASM_CORE_DIR)/*.asm)
ASM_DEVICE_SOURCES = $(wildcard $(ASM_DEVICES_DIR)/*.asm)
ASM_LAB_SOURCES = $(wildcard $(ASM_LABS_DIR)/*.asm)

# C source files
C_SOURCES = $(wildcard $(CLI_DIR)/*.c)
C_SOURCES += $(wildcard $(GLUE_DIR)/c/*.c)

# Object files
ASM_CORE_OBJECTS = $(ASM_CORE_SOURCES:$(ASM_CORE_DIR)/%.asm=$(OBJ_DIR)/%.o)
ASM_DEVICE_OBJECTS = $(ASM_DEVICE_SOURCES:$(ASM_DEVICES_DIR)/%.asm=$(OBJ_DIR)/%.o)
ASM_LAB_OBJECTS = $(ASM_LAB_SOURCES:$(ASM_LABS_DIR)/%.asm=$(OBJ_DIR)/%.o)
C_OBJECTS = $(C_SOURCES:%.c=$(OBJ_DIR)/%.o)

ALL_OBJECTS = $(ASM_CORE_OBJECTS) $(ASM_DEVICE_OBJECTS) $(ASM_LAB_OBJECTS) $(C_OBJECTS)

# Default target
.PHONY: all
all: directories $(NANOCORE_CLI) $(NANOCORE_LIB) $(NANOCORE_SHARED)

# Create build directories
.PHONY: directories
directories:
	@echo "Creating build directories..."
	@mkdir -p $(BUILD_DIR) $(OBJ_DIR) $(BIN_DIR) $(LIB_DIR)
	@mkdir -p $(OBJ_DIR)/$(ASM_CORE_DIR) $(OBJ_DIR)/$(ASM_DEVICES_DIR) $(OBJ_DIR)/$(ASM_LABS_DIR)
	@mkdir -p $(OBJ_DIR)/$(CLI_DIR) $(OBJ_DIR)/$(GLUE_DIR)

# Build CLI executable
$(NANOCORE_CLI): $(C_OBJECTS) $(NANOCORE_LIB)
	@echo "Linking $@..."
	$(CC) $(C_OBJECTS) -L$(LIB_DIR) -lnanocore $(LDFLAGS) -o $@

# Build static library
$(NANOCORE_LIB): $(ASM_CORE_OBJECTS) $(ASM_DEVICE_OBJECTS) $(ASM_LAB_OBJECTS)
	@echo "Creating static library $@..."
	$(AR) rcs $@ $^

# Build shared library
$(NANOCORE_SHARED): $(ASM_CORE_OBJECTS) $(ASM_DEVICE_OBJECTS) $(ASM_LAB_OBJECTS)
	@echo "Creating shared library $@..."
ifeq ($(OS),Windows_NT)
	$(CC) -shared -o $@ $^ $(LDFLAGS)
else
	$(CC) -shared -o $@ $^ $(LDFLAGS)
endif

# Compile C files
$(OBJ_DIR)/%.o: %.c
	@echo "Compiling $<..."
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -c $< -o $@

# Assemble NASM files
$(OBJ_DIR)/%.o: %.asm
	@echo "Assembling $<..."
	@mkdir -p $(dir $@)
	$(AS) $(ASFLAGS) $< -o $@

# Test targets
.PHONY: test
test: all
	@echo "Running tests..."
	@python test_expert.py

.PHONY: test-simple
test-simple: all
	@echo "Running simple test..."
	@python test_simple.py

# Clean targets
.PHONY: clean
clean:
	@echo "Cleaning build artifacts..."
	rm -rf $(BUILD_DIR)

.PHONY: distclean
distclean: clean
	@echo "Cleaning all generated files..."
	rm -f *.o *.a *.so *.dll *.exe
	rm -f test_*.bin

# Install targets
.PHONY: install
install: all
	@echo "Installing NanoCore VM..."
ifeq ($(OS),Windows_NT)
	@powershell -ExecutionPolicy Bypass -File install.ps1
else
	@chmod +x install.sh
	@./install.sh
endif

.PHONY: install-user
install-user: all
	@echo "Installing NanoCore VM (user mode)..."
ifeq ($(OS),Windows_NT)
	@powershell -ExecutionPolicy Bypass -File install.ps1 -UserInstall
else
	@chmod +x install.sh
	@./install.sh --user
endif

# Development targets
.PHONY: debug
debug: CFLAGS += -g -DDEBUG
debug: ASFLAGS += -g
debug: all

.PHONY: release
release: CFLAGS += -O3 -DNDEBUG
release: ASFLAGS += -O2
release: all

# Documentation
.PHONY: docs
docs:
	@echo "Generating documentation..."
	@mkdir -p docs
	@echo "# NanoCore VM Documentation" > docs/README.md
	@echo "" >> docs/README.md
	@echo "## Version: $(VERSION)" >> docs/README.md
	@echo "## Build Date: $(shell date)" >> docs/README.md

# Package targets
.PHONY: package
package: clean all docs
	@echo "Creating package..."
	@mkdir -p dist
	@tar -czf dist/nanocore-$(VERSION).tar.gz \
		--exclude=build \
		--exclude=.git \
		--exclude=*.o \
		--exclude=*.a \
		--exclude=*.so \
		--exclude=*.dll \
		--exclude=*.exe \
		.

# Help target
.PHONY: help
help:
	@echo "$(PRODUCT_NAME) v$(VERSION) - Build System"
	@echo ""
	@echo "Available targets:"
	@echo "  all          - Build everything (default)"
	@echo "  clean        - Remove build artifacts"
	@echo "  distclean    - Remove all generated files"
	@echo "  debug        - Build with debug symbols"
	@echo "  release      - Build optimized release version"
	@echo "  test         - Run all tests"
	@echo "  test-simple  - Run simple test"
	@echo "  install      - Install system-wide"
	@echo "  install-user - Install for current user only"
	@echo "  docs         - Generate documentation"
	@echo "  package      - Create distribution package"
	@echo "  help         - Show this help message"
	@echo ""
	@echo "Variables:"
	@echo "  DEBUG=1      - Enable debug build"
	@echo "  RELEASE=1    - Enable release optimizations"
	@echo "  CC=compiler  - Set C compiler"
	@echo "  AS=assembler - Set assembler"
	@echo ""
	@echo "Examples:"
	@echo "  make                    # Build everything"
	@echo "  make debug              # Debug build"
	@echo "  make install            # Install system-wide"
	@echo "  make install-user       # User installation"
	@echo "  make test               # Run tests"

# Dependencies
-include $(ALL_OBJECTS:.o=.d)

# Generate dependency files
%.d: %.c
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -MM -MT $(@:.d=.o) $< > $@

# Show build info
.PHONY: info
info:
	@echo "$(PRODUCT_NAME) v$(VERSION)"
	@echo "Platform: $(PLATFORM)"
	@echo "Compiler: $(CC)"
	@echo "Assembler: $(AS)"
	@echo "Build directory: $(BUILD_DIR)"
	@echo "Installation:"
	@echo "  Windows: powershell -ExecutionPolicy Bypass -File install.ps1"
	@echo "  Linux/macOS: ./install.sh"