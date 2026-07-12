# Weighted Instruction Analysis LLVM Pass

## Project Overview

The Weighted Instruction Analysis pass is an LLVM compiler pass that analyzes LLVM intermediate representation (IR) code and calculates weighted computational complexity metrics for functions. This pass assigns different weights to different instruction types based on their computational cost:

- **Arithmetic Operations** (add, sub, fadd, fsub): Weight 1 - Simple operations with minimal computational overhead
- **Multiplication/Division** (mul, sdiv, udiv, fmul, fdiv, srem, urem, frem): Weight 2 - More expensive than basic arithmetic
- **Memory Operations** (load, store, alloca): Weight 3 - Access to memory has higher latency than register operations
- **Function Calls** (call, invoke): Weight 5 - Most expensive due to context switching and potential side effects
- **Other Instructions**: Weight 1 - Default weight for control flow and other operations

The pass produces detailed analysis output showing:

- Frequency of each instruction type
- Total weighted cost across all instructions
- The most expensive instruction type and its impact

This is useful for:

- Performance profiling and bottleneck identification
- Code optimization targeting
- Understanding computational complexity distribution in functions
- Compiler research and education

---

## Complete Setup and Build Workflow

> [!NOTE]
> * For dedicated instructions on running inside a VMware Workstation Pro Kali Linux VM, please refer to the [VMWARE_KALI_GUIDE.md](VMWARE_KALI_GUIDE.md).
> * For dedicated macOS instructions (covering Apple Silicon/Intel architectures and Homebrew configuration), please refer to the [MAC_RUN_GUIDE.md](MAC_RUN_GUIDE.md).

### Step 1: Environment Setup on Kali Linux

If running on a virtual machine with shared folders, install VMware tools for file sharing:

```bash
sudo apt install open-vm-tools open-vm-tools-desktop
sudo reboot
```

Create and mount the shared folder:

```bash
sudo mkdir -p /mnt/hgfs
sudo vmhgfs-fuse .host:/ /mnt/hgfs -o allow_other
```

### Step 2: Navigate to Project

```bash
cd /mnt/hgfs/cd-el
```

This directory contains:

- `WeightedPass.cpp` - The LLVM pass implementation
- `CMakeLists.txt` - Build configuration
- `test1.ll` - Arithmetic-heavy test file
- `test2.ll` - Memory/call-heavy test file

### Step 3: Install Dependencies

Update package manager and install required tools:

```bash
sudo apt update
sudo apt install llvm clang cmake make libzstd-dev
```

These packages provide:

- **llvm/clang**: The LLVM compiler infrastructure needed to compile passes
- **cmake**: Build system generator
- **make**: Build tool
- **libzstd-dev**: Compression library required by LLVM

### Step 4: Create and Configure Build Directory

Clean any previous builds and create a fresh build directory:

```bash
rm -rf build
mkdir build
cd build
```

Configure the project with CMake. This step is critical—it detects LLVM installation and sets up C++17 compilation:

```bash
cmake -DCMAKE_BUILD_TYPE=Release -DLLVM_DIR=$(llvm-config --cmakedir) ..
```

Breakdown of this command:

- `-DCMAKE_BUILD_TYPE=Release`: Builds optimized release binary (no debug symbols)
- `-DLLVM_DIR=$(llvm-config --cmakedir)`: Automatically finds LLVM installation path
- `..`: Specifies parent directory contains CMakeLists.txt

### Step 5: Build the LLVM Pass Plugin

```bash
make
```

Expected output sequence:

```
[ 50%] Building CXX object CMakeFiles/WeightedInstructionAnalysis.dir/WeightedPass.cpp.o
[100%] Linking CXX shared module WeightedInstructionAnalysis.so
[100%] Built target WeightedInstructionAnalysis
```

This generates `WeightedInstructionAnalysis.so` - a shared library containing the pass.

**Important Build Configuration Details:**

The `CMakeLists.txt` specifies:

- C++17 standard (required by LLVM 21)
- Release build optimization flags
- Automatic LLVM header and library detection
- Pass plugin registration

---

## Running the Pass

### Prerequisites

Before running the pass, examine your test files. The pass only runs on functions that:

1. Are defined (not just declarations)
2. Contain at least one basic block
3. Do **not** have the `optnone` attribute

If your `.ll` files have `optnone` attributes, remove them:

```bash
sed -i 's/ optnone//g' ../test1.ll
sed -i 's/ optnone//g' ../test2.ll
```

### Execute on Test1 (Arithmetic-Heavy)

```bash
opt -load-pass-plugin=./WeightedInstructionAnalysis.so \
    -passes=weighted-instruction-analysis \
    -disable-output \
    ../test1.ll
```

### Execute on Test2 (Memory/Call-Heavy)

```bash
opt -load-pass-plugin=./WeightedInstructionAnalysis.so \
    -passes=weighted-instruction-analysis \
    -disable-output \
    ../test2.ll
```

### Expected Output Format

```
==================================
Function: function_name
==================================
Instruction Frequencies:
  alloca: 3
  store: 7
  load: 8
  icmp: 1
  br: 5
  add: 3
  mul: 1
  sub: 1
  getelementptr: 0

Total Weighted Cost: 47

Most Expensive Instruction Type: load (weighted cost: 24)
==================================
```

The output shows:

- **Instruction Frequencies**: How many times each instruction type appears
- **Total Weighted Cost**: Sum of (frequency × weight) for all instructions
- **Most Expensive**: Which instruction type contributes most to overall cost

### Debugging Mode

If the pass doesn't produce output, run with debug flags to verify execution:

```bash
opt -load-pass-plugin=./WeightedInstructionAnalysis.so \
    -passes=weighted-instruction-analysis \
    -debug-pass-manager \
    -disable-output \
    ../test1.ll
```

This shows detailed pass execution information and helps identify issues.

---

## Critical Issues Fixed During Development

### Issue 1: C++ Standard Incompatibility

**Problem**: Compilation errors with `std::optional`, `std::is_enum_v`, and `if constexpr`

**Root Cause**: CMakeLists.txt specified C++14, but LLVM 21 requires C++17

**Solution**: Updated CMakeLists.txt:

```cmake
set(CMAKE_CXX_STANDARD 17 CACHE STRING "C++ standard to conform to")
```

### Issue 2: Missing PassPlugin Header

**Problem**: Error `'PassPluginLibraryInfo' in namespace 'llvm' does not name a type`

**Root Cause**: Required headers not included for plugin infrastructure

**Solution**: Added to WeightedPass.cpp:

```cpp
#include "llvm/Passes/PassBuilder.h"
#include "llvm/Passes/PassPlugin.h"
```

### Issue 3: Incomplete Type Error

**Problem**: `invalid use of incomplete type 'class llvm::PassBuilder'`

**Root Cause**: Forward declaration without full definition

**Solution**: Ensured `PassBuilder.h` is included before using `PassBuilder::PipelineElement`

### Issue 4: Library Not Found at Runtime

**Problem**: `Could not load library './libWeightedInstructionAnalysis.so': No such file or directory`

**Root Cause**: Generated library name is `WeightedInstructionAnalysis.so` (not `libWeightedInstructionAnalysis.so`)

**Solution**: Use correct filename in opt command:

```bash
opt -load-pass-plugin=./WeightedInstructionAnalysis.so ...
```

### Issue 5: optnone Attribute Prevents Analysis

**Problem**: Pass doesn't produce output even though it loads successfully

**Root Cause**: LLVM skips functions with `optnone` attribute to preserve debug fidelity

**Solution**: Remove `optnone` from test files:

```bash
sed -i 's/ optnone//g' ../test1.ll
```

---

## Project Structure

```
cd-el/
├── CMakeLists.txt                    # Build configuration
├── WeightedPass.cpp                  # Pass implementation
├── test1.ll                          # Test file with arithmetic operations
├── test2.ll                          # Test file with memory/call operations
├── EXECUTION_COMMANDS.md             # Quick reference for commands
├── EXPLANATION.txt                   # Detailed pass explanation
└── build/                            # Generated build directory
    ├── CMakeLists.txt (generated)
    ├── Makefile (generated)
    └── WeightedInstructionAnalysis.so # Generated plugin library
```

---

## How the Pass Works

### 1. Pass Registration

The pass registers with LLVM's pipeline using the `PassPluginLibraryInfo` mechanism. This allows `opt` to discover and load the pass dynamically.

### 2. Function Analysis

For each function in the IR:

- Iterate through all basic blocks
- For each instruction, determine its opcode
- Look up the weight based on instruction type
- Accumulate statistics

### 3. Statistics Collection

Data structures track:

- **Instruction frequency**: Count of each opcode type
- **Weighted cost**: Accumulated cost (frequency × weight)
- **Maximum cost instruction**: Type contributing most to total

### 4. Output Generation

Results are printed to stdout using `llvm::outs()` in a formatted table showing:

- Per-instruction-type breakdown
- Total computational cost
- Performance bottleneck identification

---

## Rebuild Workflow

After making changes to `WeightedPass.cpp`:

```bash
cd build
cmake --build . --config Release
# Or on Linux: make
```

This recompiles only changed files and regenerates `WeightedInstructionAnalysis.so`.

For a complete clean rebuild:

```bash
cd /path/to/project
rm -rf build
mkdir build
cd build
cmake -DCMAKE_BUILD_TYPE=Release -DLLVM_DIR=$(llvm-config --cmakedir) ..
make
```

---

## Platform-Specific Notes

### Linux/Kali

- Use forward slashes in paths
- Plugin has `.so` extension
- Command: `opt -load-pass-plugin=./WeightedInstructionAnalysis.so`

### macOS

- Plugin has `.dylib` extension
- Otherwise identical to Linux

### Windows

- Plugin has `.dll` extension
- Use `opt.exe` from LLVM installation
- Use backslashes or forward slashes for paths
- Example: `opt.exe -load-pass-plugin=".\build\WeightedInstructionAnalysis.dll"`

---

## Troubleshooting

| Issue                             | Cause                             | Solution                                               |
| --------------------------------- | --------------------------------- | ------------------------------------------------------ |
| CMake can't find LLVM             | LLVM not installed or not in PATH | `sudo apt install llvm` or set `-DLLVM_DIR` explicitly |
| `PassPluginLibraryInfo` not found | Missing PassPlugin header         | Add `#include "llvm/Passes/PassPlugin.h"`              |
| `PassBuilder` incomplete type     | Missing PassBuilder header        | Add `#include "llvm/Passes/PassBuilder.h"`             |
| `.so` file not found at runtime   | Wrong filename or path            | Verify exact filename with `ls`                        |
| No analysis output                | `optnone` attribute blocks pass   | Remove with `sed -i 's/ optnone//g'`                   |
| C++17 compilation errors          | Using C++14 in CMakeLists.txt     | Set `CMAKE_CXX_STANDARD 17`                            |

---

## Summary

This LLVM pass demonstrates how to:

1. Build a custom compiler pass using modern LLVM infrastructure
2. Implement plugin-based architecture for dynamic loading
3. Analyze IR for performance characteristics
4. Generate formatted analysis reports

The weighted instruction model provides a simple but effective way to identify computational bottlenecks in compiled code, useful for optimization targeting and educational purposes.
