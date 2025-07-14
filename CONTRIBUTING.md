# Contributing to NanoCore

Thank you for your interest in contributing to NanoCore! This high-performance assembly VM project welcomes contributions from developers of all skill levels.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Process](#development-process)
- [Coding Standards](#coding-standards)
- [Testing Requirements](#testing-requirements)
- [Submitting Changes](#submitting-changes)
- [Performance Guidelines](#performance-guidelines)

## Code of Conduct

We are committed to providing a welcoming and inclusive environment. Please:

- Be respectful and considerate
- Welcome newcomers and help them get started
- Focus on constructive criticism
- Respect differing viewpoints and experiences

## Getting Started

1. **Fork the repository** on GitHub
2. **Clone your fork** locally:
   ```bash
   git clone https://github.com/yourusername/nanocore.git
   cd nanocore
   ```
3. **Set up the development environment**:
   ```bash
   # Install dependencies
   sudo apt-get install nasm gcc make python3-dev rustc cargo
   
   # Build the project
   make all
   
   # Run tests
   make test
   ```

## Development Process

### Branches

- `main` - Stable release branch
- `develop` - Active development branch
- `feature/*` - Feature branches
- `bugfix/*` - Bug fix branches
- `perf/*` - Performance improvement branches

### Workflow

1. Create a new branch from `develop`:
   ```bash
   git checkout -b feature/your-feature-name develop
   ```

2. Make your changes following our coding standards

3. Write or update tests for your changes

4. Run the test suite:
   ```bash
   make test
   make test-performance  # If you made performance-related changes
   ```

5. Commit your changes with clear, descriptive messages

6. Push to your fork and create a pull request

## Coding Standards

### Assembly Code (NASM)

```asm
; Function: brief description
; Input: RDI = param1, RSI = param2
; Output: RAX = result
; Clobbers: RBX, RCX
function_name:
    push rbp
    mov rbp, rsp
    push rbx        ; Save callee-saved registers
    
    ; Function body with clear comments
    mov rax, rdi    ; Load first parameter
    
    ; Use meaningful labels
.loop_start:
    ; Loop body
    loop .loop_start
    
.done:
    pop rbx         ; Restore registers
    pop rbp
    ret
```

**Assembly Guidelines:**
- Use consistent indentation (4 spaces)
- Comment every non-trivial operation
- Document register usage
- Align data on cache line boundaries
- Optimize for the common case

### C Code

```c
/**
 * @brief Brief function description
 * @param param1 Description
 * @return Return value description
 */
int function_name(int param1) {
    // Use clear variable names
    int result = 0;
    
    // Early returns for error cases
    if (param1 < 0) {
        return -1;
    }
    
    // Main logic
    result = compute_something(param1);
    
    return result;
}
```

### Rust Code

```rust
/// Brief function description
///
/// # Arguments
/// * `param1` - Description
///
/// # Returns
/// Description of return value
pub fn function_name(param1: u64) -> Result<u64, Error> {
    // Prefer functional style
    (0..param1)
        .filter(|x| x % 2 == 0)
        .sum()
}
```

## Testing Requirements

All contributions must include appropriate tests:

### Unit Tests
- Test individual functions/modules
- Cover edge cases and error conditions
- Aim for >90% code coverage

### Integration Tests
- Test component interactions
- Verify API contracts
- Test real-world usage scenarios

### Performance Tests
- Benchmark critical paths
- Compare against baseline performance
- Document any performance impacts

Example test:
```asm
; tests/isa/test_add.asm
test_add_basic:
    ; Test: ADD R1, R2, R3
    LOAD R2, 10
    LOAD R3, 20
    ADD R1, R2, R3
    
    ; Verify result
    CMP R1, 30
    JNE test_failed
    
    ; Test overflow
    LOAD R2, 0x7FFFFFFFFFFFFFFF
    LOAD R3, 1
    ADD R1, R2, R3
    
    ; Check overflow flag
    TEST FLAGS, FLAG_OVERFLOW
    JZ test_failed
    
    RET
```

## Submitting Changes

### Pull Request Process

1. **Update documentation** for any changed functionality
2. **Add tests** for new features
3. **Update CHANGELOG.md** with your changes
4. **Ensure CI passes** - all tests must pass
5. **Request review** from maintainers

### PR Title Format
```
[Component] Brief description

Examples:
[VM] Add SIMD dot product instruction
[CLI] Fix memory leak in debugger
[Perf] Optimize branch predictor
```

### PR Description Template
```markdown
## Description
Brief description of changes

## Motivation
Why these changes are needed

## Testing
How the changes were tested

## Performance Impact
Any performance implications

## Breaking Changes
List any breaking changes
```

## Performance Guidelines

NanoCore prioritizes performance. When contributing:

### Do:
- Profile before and after changes
- Use cache-friendly data structures
- Minimize memory allocations
- Leverage SIMD where appropriate
- Document performance characteristics

### Don't:
- Add features that significantly impact baseline performance
- Use dynamic allocation in hot paths
- Add unnecessary abstraction layers
- Ignore cache effects

### Performance Testing

```bash
# Run benchmarks
make benchmarks

# Profile specific test
perf record ./nanocore examples/benchmark.nc
perf report

# Compare performance
make benchmark-compare BASELINE=main
```

## Questions?

- Check the [documentation](docs/)
- Ask in [GitHub Discussions](https://github.com/nanocore/nanocore/discussions)
- Join our [Discord server](https://discord.gg/nanocore)

Thank you for contributing to NanoCore!