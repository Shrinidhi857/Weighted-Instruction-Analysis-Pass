# Running on macOS

This guide provides step-by-step instructions and commands to set up, build, and run the **Weighted Instruction Analysis LLVM Pass** on macOS.

---

## 🛠️ Step 1: Install Homebrew and Dependencies

macOS does not come with LLVM, CMake, or other build dependencies pre-installed. The recommended way to install them is via [Homebrew](https://brew.sh/).

Open your terminal and run:

```bash
# Install Homebrew if you haven't already
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install LLVM, CMake, and Python 3
brew install llvm cmake python3
```

---

## ⚙️ Step 2: Configure Environment Paths (Crucial)

Homebrew installs LLVM as a "keg-only" formula. This means it is **not** linked into your system's global paths to avoid conflicts with Xcode's default (and older) toolchains. 

To use the Homebrew-installed version of `llvm-config` and `opt`, you **must** prepend the Homebrew LLVM binary directory to your `PATH` environment variable.

### Identify Your Mac Architecture:

* **For Apple Silicon Macs (M1/M2/M3/M4):**
  Homebrew packages are installed under `/opt/homebrew`. Run:
  ```bash
  export PATH="/opt/homebrew/opt/llvm/bin:$PATH"
  ```
  *(To make this change permanent, add the line above to your `~/.zshrc` file).*

* **For Intel-based Macs:**
  Homebrew packages are installed under `/usr/local`. Run:
  ```bash
  export PATH="/usr/local/opt/llvm/bin:$PATH"
  ```
  *(To make this change permanent, add the line above to your `~/.zshrc` file).*

### Verify Setup:
Verify that your terminal is pointing to the correct Homebrew LLVM version:
```bash
which llvm-config
# Output should point to /opt/homebrew/... or /usr/local/... rather than /usr/bin/llvm-config
```

---

## 📂 Step 3: Navigate and Set Permissions

Navigate to your project directory and make the compilation/execution scripts executable:

```bash
cd /path/to/Weighted-Instruction-Analysis-Pass
chmod +x build.sh run.sh run_analysis.sh
```

---

## 🚀 Step 4: Build the LLVM Pass

Run the build script to compile the pass. It will automatically detect your Mac's CPU cores and handle the CMake configuration:

```bash
./build.sh
```

*Note: On macOS, this compiles the pass and creates a dynamic plugin library in the `build/` directory. Depending on your version of LLVM and CMake, this file will be named `WeightedInstructionAnalysis.so`, `libWeightedInstructionAnalysis.so`, `WeightedInstructionAnalysis.dylib`, or `libWeightedInstructionAnalysis.dylib`.*

---

## 📊 Step 5: Run the Analysis

The helper scripts (`run.sh` and `run_analysis.sh`) have been enhanced to automatically detect the dynamic library on macOS regardless of whether it was built with a `.so` or `.dylib` extension.

### Option A: Run the Standard Test Suite (Quickest)
This runs the pass against both `testcases/test1.ll` and `testcases/test2.ll`:

```bash
./run.sh
```

### Option B: Run the Advanced Analysis Toolkit
Analyze a test case and generate comprehensive text, JSON, and CSV reports:

```bash
# Analyze the arithmetic-heavy testcase
./run_analysis.sh testcases/test1.ll

# Analyze the memory/call-heavy testcase
./run_analysis.sh testcases/test2.ll
```
Reports will be saved in the `./analysis_results/` directory.

### Option C: Manual Execution (Using LLVM `opt`)
If you want to run the pass manually using LLVM's `opt` tool, specify the path to your compiled plugin:

```bash
# Replace WeightedInstructionAnalysis.so with the exact filename generated in build/ (e.g. libWeightedInstructionAnalysis.dylib)
opt -load-pass-plugin=build/WeightedInstructionAnalysis.dylib \
    -passes=weighted-instruction-analysis \
    -disable-output \
    testcases/test1.ll
```
