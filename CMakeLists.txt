cmake_minimum_required(VERSION 3.13.4)
project(WeightedInstructionAnalysis)

# Find LLVM
find_package(LLVM REQUIRED CONFIG)

# Include LLVM CMake modules
list(APPEND CMAKE_MODULE_PATH "${LLVM_CMAKE_DIR}")
include(AddLLVM)

# Set C++ standard
set(CMAKE_CXX_STANDARD 14 CACHE STRING "C++ standard to conform to")
set(CMAKE_CXX_STANDARD_REQUIRED YES)

# Add the plugin library
add_llvm_pass_plugin(WeightedInstructionAnalysis
  WeightedPass.cpp
)

# Link against LLVM libraries
target_link_libraries(WeightedInstructionAnalysis PRIVATE
  LLVMCore
  LLVMSupport
)

# Include LLVM headers
target_include_directories(WeightedInstructionAnalysis PRIVATE
  ${LLVM_INCLUDE_DIRS}
)

# Add compiler definitions from LLVM
add_definitions(${LLVM_DEFINITIONS})
