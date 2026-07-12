# Running on VMware Workstation Pro (Kali Linux)

This guide provides step-by-step instructions and commands to set up, build, and run the **Weighted Instruction Analysis LLVM Pass** within a Kali Linux virtual machine running on VMware Workstation Pro.

---

## 🛠️ Step 1: Install Required Dependencies

Ensure your package lists are updated and install the essential build tools, LLVM, Clang, and Python (for the analysis toolkit):

```bash
sudo apt update
sudo apt install -y llvm clang cmake make libzstd-dev python3
```

---

## 📂 Step 2: Navigate and Set Permissions

If you imported the project folder (either via shared folders or direct copy/drag-and-drop), navigate to the project directory:

```bash
# If using VMware Shared Folders (usually mounted under /mnt/hgfs/)
cd /mnt/hgfs/Weighted-Instruction-Analysis-Pass

# OR if you copied/cloned it to your home directory:
cd ~/Weighted-Instruction-Analysis-Pass
```

### Fix Script Permissions
Files transferred from a Windows host often lose their execution permissions. Make all shell scripts executable:

```bash
chmod +x build.sh run.sh run_analysis.sh
```

---

## 🚀 Step 3: Build the LLVM Pass

Run the build script, which handles CMake configuration and compilation automatically:

```bash
./build.sh
```

*Note: This will compile the pass and create the shared library (typically `build/WeightedInstructionAnalysis.so` or `build/libWeightedInstructionAnalysis.so` depending on the LLVM/CMake toolchain setup on Kali).*

---

## 📊 Step 4: Run the Analysis

You have multiple options to run the analysis depending on your needs.

### Option A: Run the Standard Test Suite (Quickest)
This runs the pass against both `testcases/test1.ll` (Arithmetic-heavy) and `testcases/test2.ll` (Memory/Call-heavy):

```bash
./run.sh
```

### Option B: Run the Advanced Analysis Toolkit
Use the automated Python-wrapped workflow to analyze a specific file and generate reports (in Text, JSON, and CSV formats):

```bash
# Analyze the arithmetic-heavy testcase
./run_analysis.sh testcases/test1.ll

# Analyze the memory/call-heavy testcase
./run_analysis.sh testcases/test2.ll
```

The reports will be saved in the `./analysis_results/` directory.

### Option C: Manual Execution (Using LLVM `opt`)
If you want to run the pass manually using LLVM's `opt` tool:

# Use build/WeightedInstructionAnalysis.so or build/libWeightedInstructionAnalysis.so depending on what was compiled
opt -load-pass-plugin=build/WeightedInstructionAnalysis.so \
    -passes=weighted-instruction-analysis \
    -disable-output \
    testcases/test1.ll
```
