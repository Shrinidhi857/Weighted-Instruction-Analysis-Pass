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

# Determine number of CPU cores for build
if command -v nproc &> /dev/null; then
    NUM_CORES=$(nproc)
elif command -v sysctl &> /dev/null; then
    NUM_CORES=$(sysctl -n hw.ncpu)
else
    NUM_CORES=2
fi

# Build
echo "Building target with $NUM_CORES cores..."
make -j$NUM_CORES

echo "=== Build Successful! ==="
# Find and display the compiled artifact
ARTIFACT_PATH=""
for name in "WeightedInstructionAnalysis.so" "libWeightedInstructionAnalysis.so" "WeightedInstructionAnalysis.dylib" "libWeightedInstructionAnalysis.dylib"; do
    if [ -f "$name" ]; then
        ARTIFACT_PATH="build/$name"
        break
    fi
done
if [ -z "$ARTIFACT_PATH" ]; then
    ARTIFACT_PATH="build/WeightedInstructionAnalysis.so"
fi
echo "Artifact: $ARTIFACT_PATH"
