#!/bin/bash
# Fail on any error
set -e

echo "=== Running Weighted Instruction Analysis Pass ==="

# Check if build artifact exists
SO_FILE=""
for name in "WeightedInstructionAnalysis.so" "libWeightedInstructionAnalysis.so" "WeightedInstructionAnalysis.dylib" "libWeightedInstructionAnalysis.dylib"; do
    if [ -f "build/$name" ]; then
        SO_FILE="build/$name"
        break
    fi
done

if [ -z "$SO_FILE" ]; then
    echo "Error: Build artifact not found in build/. Please run ./build.sh first."
    exit 1
fi

# Check for opt tool
if ! command -v opt &> /dev/null; then
    echo "Error: opt is not installed. Run 'sudo apt install llvm'."
    exit 1
fi

# Run on testcase 1 (Arithmetic-Heavy)
echo ""
echo "Running on testcases/test1.ll (Arithmetic-Heavy)..."
opt -load-pass-plugin="$SO_FILE" \
    -passes=weighted-instruction-analysis \
    -disable-output \
    testcases/test1.ll

# Run on testcase 2 (Memory and Call-Heavy)
echo ""
echo "Running on testcases/test2.ll (Memory/Call-Heavy)..."
opt -load-pass-plugin="$SO_FILE" \
    -passes=weighted-instruction-analysis \
    -disable-output \
    testcases/test2.ll

echo ""
echo "=== Execution Finished! ==="
