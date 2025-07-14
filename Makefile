# NanoCore Makefile - High-Performance Build System

# Build Configuration
PLATFORM ?= linux
ARCH ?= x64
CC ?= gcc
AS ?= nasm
LD ?= ld
AR ?= ar

# Directories
BUILD_DIR := build
OBJ_DIR := $(BUILD_DIR)/obj
BIN_DIR := $(BUILD_DIR)/bin
LIB_DIR := $(BUILD_DIR)/lib

# Source Directories
ASM_CORE_DIR := asm/core
ASM_DEVICES_DIR := asm/devices
ASM_LABS_DIR := asm/labs
GLUE_DIR := glue
CLI_DIR := cli
TEST_DIR := tests

# Flags
ASFLAGS := -f elf64 -g -F dwarf
LDFLAGS := -nostdlib -static
CFLAGS := -O3 -march=native -mtune=native -Wall -Wextra -fno-stack-protector
CXXFLAGS := $(CFLAGS) -std=c++20

# Performance Flags
ifdef NANOCORE_ENABLE_LTO
    CFLAGS += -flto
    LDFLAGS += -flto
endif

ifdef NANOCORE_ENABLE_PGO
    CFLAGS += -fprofile-generate
    LDFLAGS += -fprofile-generate
endif

# Platform-specific settings
ifeq ($(PLATFORM),darwin)
    ASFLAGS := -f macho64
    LDFLAGS := -macosx_version_min 10.15 -lSystem
endif

ifeq ($(PLATFORM),win64)
    ASFLAGS := -f win64
    LDFLAGS := -subsystem:console
endif

# Core VM Objects
VM_OBJECTS := \
    $(OBJ_DIR)/vm.o \
    $(OBJ_DIR)/memory.o \
    $(OBJ_DIR)/alu.o \
    $(OBJ_DIR)/pipeline.o \
    $(OBJ_DIR)/cache.o \
    $(OBJ_DIR)/interrupts.o \
    $(OBJ_DIR)/instructions.o \
    $(OBJ_DIR)/devices.o

# Device Objects
DEVICE_OBJECTS := \
    $(OBJ_DIR)/console.o

# Targets
.PHONY: all clean vm bindings tests benchmarks docs release-all

all: vm bindings cli tests

# Create directories
$(BUILD_DIR) $(OBJ_DIR) $(BIN_DIR) $(LIB_DIR):
	@mkdir -p $@

# Core VM
vm: $(BIN_DIR)/nanocore

$(BIN_DIR)/nanocore: $(VM_OBJECTS) $(DEVICE_OBJECTS) | $(BIN_DIR)
	@echo "Linking NanoCore VM..."
	$(LD) $(LDFLAGS) -o $@ $^
	@echo "Stripping debug symbols for release..."
	strip -s $@
	@echo "VM built successfully: $@"

# Assembly Rules
$(OBJ_DIR)/%.o: $(ASM_CORE_DIR)/%.asm | $(OBJ_DIR)
	@echo "Assembling $<..."
	$(AS) $(ASFLAGS) -o $@ $<

$(OBJ_DIR)/%.o: $(ASM_DEVICES_DIR)/%.asm | $(OBJ_DIR)
	@echo "Assembling $<..."
	$(AS) $(ASFLAGS) -o $@ $<

# Language Bindings
bindings: rust-ffi python-binding js-binding

rust-ffi: $(LIB_DIR)/libnanocore.so
	@echo "Building Rust FFI..."
	cd $(GLUE_DIR)/ffi && cargo build --release
	cp $(GLUE_DIR)/ffi/target/release/libnanocore_ffi.* $(LIB_DIR)/

python-binding: $(LIB_DIR)/libnanocore.so
	@echo "Building Python bindings..."
	cd $(GLUE_DIR)/python && python3 setup.py build_ext --inplace
	cp $(GLUE_DIR)/python/*.so $(LIB_DIR)/

js-binding: $(LIB_DIR)/libnanocore.so
	@echo "Building JavaScript bindings..."
	cd $(GLUE_DIR)/js && npm install && npm run build
	cp $(GLUE_DIR)/js/build/Release/*.node $(LIB_DIR)/

$(LIB_DIR)/libnanocore.so: $(VM_OBJECTS) $(DEVICE_OBJECTS) | $(LIB_DIR)
	@echo "Creating shared library..."
	$(CC) -shared -fPIC $(LDFLAGS) -o $@ $^

# CLI
cli: $(BIN_DIR)/nanocore-cli

$(BIN_DIR)/nanocore-cli: $(CLI_DIR)/main.c $(LIB_DIR)/libnanocore.so | $(BIN_DIR)
	@echo "Building CLI..."
	$(CC) $(CFLAGS) -o $@ $< -L$(LIB_DIR) -lnanocore -Wl,-rpath,$(LIB_DIR)

# Tests
tests: test-isa test-unit test-integration test-performance

test-isa:
	@echo "Running ISA compliance tests..."
	@for test in $(TEST_DIR)/isa/*.asm; do \
		echo "Testing $$test..."; \
		$(AS) $(ASFLAGS) -o $(OBJ_DIR)/$$(basename $$test .asm).o $$test; \
		$(BIN_DIR)/nanocore --test $(OBJ_DIR)/$$(basename $$test .asm).o; \
	done

test-unit:
	@echo "Running unit tests..."
	$(CC) $(CFLAGS) -o $(BIN_DIR)/test-unit $(TEST_DIR)/unit/*.c -L$(LIB_DIR) -lnanocore
	$(BIN_DIR)/test-unit

test-integration:
	@echo "Running integration tests..."
	python3 $(TEST_DIR)/integration/run_tests.py

test-performance:
	@echo "Running performance tests..."
	$(BIN_DIR)/nanocore --benchmark > $(BUILD_DIR)/perf-results.json

test-valgrind: vm
	@echo "Running memory leak tests..."
	valgrind --leak-check=full --show-leak-kinds=all \
		--track-origins=yes --verbose \
		$(BIN_DIR)/nanocore $(ASM_LABS_DIR)/hello_world.asm

test-security:
	@echo "Running security tests..."
	# Stack canary tests
	$(CC) $(CFLAGS) -fstack-protector-strong -o $(BIN_DIR)/test-security \
		$(TEST_DIR)/security/*.c -L$(LIB_DIR) -lnanocore
	$(BIN_DIR)/test-security

# Benchmarks
benchmarks: $(BIN_DIR)/benchmark

$(BIN_DIR)/benchmark: $(TEST_DIR)/benchmarks/*.c $(LIB_DIR)/libnanocore.so | $(BIN_DIR)
	@echo "Building benchmarks..."
	$(CC) $(CFLAGS) -o $@ $(TEST_DIR)/benchmarks/*.c -L$(LIB_DIR) -lnanocore -lm
	@echo "Running benchmarks..."
	$@ --json > $(BUILD_DIR)/benchmarks.json
	$@ --compare baseline.json

# Documentation
docs:
	@echo "Building documentation..."
	cd docs && make html pdf

# Coverage
coverage:
	@echo "Building with coverage..."
	$(MAKE) clean
	$(MAKE) CFLAGS="$(CFLAGS) --coverage" LDFLAGS="$(LDFLAGS) --coverage" all
	$(MAKE) tests
	lcov --capture --directory . --output-file coverage.info
	genhtml coverage.info --output-directory $(BUILD_DIR)/coverage

# Release
release-all:
	@echo "Building release artifacts..."
	$(MAKE) clean
	$(MAKE) NANOCORE_ENABLE_LTO=1 vm
	$(MAKE) bindings
	@mkdir -p dist
	tar -czf dist/nanocore-$(PLATFORM)-$(ARCH).tar.gz \
		$(BIN_DIR)/nanocore $(LIB_DIR)/* README.md LICENSE docs/

# Clean
clean:
	@echo "Cleaning build artifacts..."
	rm -rf $(BUILD_DIR) dist/

# Install
install: vm cli
	@echo "Installing NanoCore..."
	install -m 755 $(BIN_DIR)/nanocore /usr/local/bin/
	install -m 755 $(BIN_DIR)/nanocore-cli /usr/local/bin/
	install -m 644 $(LIB_DIR)/libnanocore.so /usr/local/lib/
	ldconfig

# Development helpers
.PHONY: format lint profile

format:
	@echo "Formatting code..."
	find . -name "*.c" -o -name "*.h" | xargs clang-format -i
	cd $(GLUE_DIR)/ffi && cargo fmt

lint:
	@echo "Linting code..."
	cppcheck --enable=all --suppress=missingIncludeSystem $(CLI_DIR) $(TEST_DIR)
	cd $(GLUE_DIR)/ffi && cargo clippy

profile: vm
	@echo "Profiling VM..."
	perf record -g $(BIN_DIR)/nanocore $(ASM_LABS_DIR)/mandelbrot.asm
	perf report

# Help
help:
	@echo "NanoCore Build System"
	@echo "===================="
	@echo "Targets:"
	@echo "  all          - Build everything"
	@echo "  vm           - Build core VM"
	@echo "  bindings     - Build language bindings"
	@echo "  cli          - Build CLI tool"
	@echo "  tests        - Run all tests"
	@echo "  benchmarks   - Run performance benchmarks"
	@echo "  docs         - Build documentation"
	@echo "  clean        - Clean build artifacts"
	@echo "  install      - Install system-wide"
	@echo ""
	@echo "Variables:"
	@echo "  PLATFORM     - Target platform (linux/darwin/win64)"
	@echo "  ARCH         - Target architecture (x64/arm64)"
	@echo "  CC           - C compiler (gcc/clang)"
	@echo ""
	@echo "Examples:"
	@echo "  make PLATFORM=darwin ARCH=arm64"
	@echo "  make NANOCORE_ENABLE_LTO=1 NANOCORE_ENABLE_PGO=1"