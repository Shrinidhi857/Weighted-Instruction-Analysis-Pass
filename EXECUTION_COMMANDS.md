# Execution Commands for Weighted Instruction Analysis Pass

## Build Instructions

### Step 1: Create and Navigate to Build Directory

```bash
mkdir build
cd build
```

### Step 2: Configure with CMake

Ensure LLVM is installed and `llvm-config` is available in your PATH.

```bash
cmake -DCMAKE_BUILD_TYPE=Release ..
```

If LLVM is installed in a non-standard location, you may need to specify:

```bash
cmake -DCMAKE_BUILD_TYPE=Release -DLLVM_DIR=/path/to/llvm/lib/cmake/llvm ..
```

### Step 3: Build the Pass

```bash
cmake --build . --config Release
```

This will generate `libWeightedInstructionAnalysis.so` (on Linux/Mac) or
`WeightedInstructionAnalysis.dll` (on Windows) in the build directory.

---

## Running the Pass on Test Files

### Option 1: Run on test1.ll (Arithmetic-Heavy)

```bash
opt -load-pass-plugin=./build/libWeightedInstructionAnalysis.so \
    -passes=weighted-instruction-analysis \
    -disable-output \
    ../test1.ll
```

### Option 2: Run on test2.ll (Memory/Call-Heavy)

```bash
opt -load-pass-plugin=./build/libWeightedInstructionAnalysis.so \
    -passes=weighted-instruction-analysis \
    -disable-output \
    ../test2.ll
```

### Option 3: Run on Both Files (Sequential)

```bash
# Run on test1.ll
opt -load-pass-plugin=./build/libWeightedInstructionAnalysis.so \
    -passes=weighted-instruction-analysis \
    -disable-output \
    ../test1.ll

# Run on test2.ll
opt -load-pass-plugin=./build/libWeightedInstructionAnalysis.so \
    -passes=weighted-instruction-analysis \
    -disable-output \
    ../test2.ll
```

---

## Expected Output Format

When you run the pass, you should see output similar to:

```
==================================
Function: arithmetic_heavy
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

The numbers will vary depending on the specific function being analyzed.

---

## Windows-Specific Notes

If you're on Windows and using Visual Studio:

1. You may need to use `opt.exe` from your LLVM installation.
2. Replace forward slashes with backslashes or use forward slashes with full paths.
3. Example:

```bash
opt.exe -load-pass-plugin=".\build\WeightedInstructionAnalysis.dll" ^
        -passes=weighted-instruction-analysis ^
        -disable-output ^
        .\test1.ll
```

---

## Troubleshooting

1. **"opt" not found**: Ensure LLVM is in your PATH. Try `llvm-config --bindir` to find it.
2. **Plugin load error**: Make sure the path to the .so/.dll file is correct.
3. **Missing LLVM headers**: Ensure LLVM development files are installed.
4. **CMake can't find LLVM**: Install llvm-dev or set LLVM_DIR explicitly.
