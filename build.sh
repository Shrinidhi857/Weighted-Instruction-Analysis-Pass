#!/bin/bash
# Fail on any error
set -e

echo "=== Building Weighted Instruction Analysis Pass ==="

# Check for dependencies
if ! command -v cmake &> /dev/null; then
    echo "Error: cmake is not installed. Run 'sudo apt install cmake'."
    exit 1
fi

if ! command -v llvm-config &> /dev/null; then
    echo "Error: llvm-config is not installed. Run 'sudo apt install llvm llvm-dev'."
    exit 1
fi

# Create and navigate to build directory
mkdir -p build
cd build

# Remove old cache to avoid Windows/Linux host-guest conflicts
rm -f CMakeCache.txt

# Configure CMake
echo "Configuring with CMake..."
cmake -DCMAKE_BUILD_TYPE=Release -DLLVM_DIR=$(llvm-config --cmakedir) ..

# Build
echo "Building target..."
make -j$(nproc)

echo "=== Build Successful! ==="
echo "Artifact: build/WeightedInstructionAnalysis.so"
