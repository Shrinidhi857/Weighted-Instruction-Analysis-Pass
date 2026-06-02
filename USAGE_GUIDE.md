# Enhanced Weighted Instruction Analysis - Complete Usage Guide

## 🎯 Quick Start

### 1. Build the Enhanced Pass

```bash
cd build
cmake -DCMAKE_BUILD_TYPE=Release -DLLVM_DIR=$(llvm-config --cmakedir) ..
make
```

### 2. Run on Your Code

```bash
opt -load-pass-plugin=./WeightedInstructionAnalysis.so \
    -passes=weighted-instruction-analysis \
    -disable-output \
    ../test1.ll > analysis_output.txt
```

### 3. Advanced Analysis (Using Toolkit)

```bash
python3 analysis_toolkit.py analysis_output.txt --text
python3 analysis_toolkit.py analysis_output.txt --json > report.json
python3 analysis_toolkit.py analysis_output.txt --csv > report.csv
```

---

## 📋 Understanding the Enhanced Output

### Section 1: Function Basics

```
📊 Function: arithmetic_heavy
   Basic Blocks: 8 | Total Instructions: 247
```

**What it means:**

- **Function Name**: Name from the IR
- **Basic Blocks**: Number of code paths (higher = more complex control flow)
- **Instructions**: Total number of LLVM IR instructions

**Use for**: Quick complexity assessment

---

### Section 2: Instruction Breakdown

```
📈 INSTRUCTION BREAKDOWN:
┌─ Instruction Frequencies:
│  ├─ load: 45
│  ├─ store: 38
│  ├─ mul: 32
│  ├─ add: 52
```

**What it shows:**

- Frequency of each instruction type
- Visual hierarchy with tree-like formatting

**Use for**: Understanding code composition

---

### Section 3: Categorized Analysis

```
📑 CATEGORIZED ANALYSIS:
   Memory Operations: 83 (33% of instructions)
   Function Calls: 2
   Arithmetic Operations: 84
```

**Categories:**
| Category | Instructions | Cost | Purpose |
|----------|--------------|------|---------|
| Memory | load, store, alloca | High | Data access |
| Calls | call, invoke | Highest | Function invocation |
| Heavy Arithmetic | mul, div, mod | Medium | Complex math |
| Light Arithmetic | add, sub | Low | Simple math |

**Use for:** Identifying operation distribution

---

### Section 4: Cost Analysis

```
💰 COST ANALYSIS:
   Total Weighted Cost: 487
   Average Weight per Instruction: 1.97
   🔥 Bottleneck: load (weighted cost: 135)
```

**Weights Used:**

```
add/sub/fadd/fsub       = 1 (cheapest)
mul/div/fmul/fdiv       = 2
load/store/alloca       = 3
call/invoke             = 5 (most expensive)
other                   = 1
```

**Example Calculation:**

- 45 loads × 3 = 135
- 32 multiplies × 2 = 64
- 52 adds × 1 = 52
- **Total: 487**

**Use for:** Identifying actual computational cost

---

### Section 5: Performance Profile

```
⚙️  PERFORMANCE PROFILE:
   ⚖️  BALANCED: Moderate memory-compute ratio
      Good mix of computation and memory operations
```

**Possible Profiles:**

| Profile          | Memory Ratio | Meaning            | Optimization          |
| ---------------- | ------------ | ------------------ | --------------------- |
| 🎯 COMPUTE-BOUND | < 0.2        | CPU does most work | Vectorization (SIMD)  |
| ⚖️ BALANCED      | 0.2-0.5      | Mix of both        | Balanced optimization |
| ⚡ MEMORY-BOUND  | > 0.5        | Memory dominates   | Cache optimization    |

**Use for:** Choosing optimization strategy

---

### Section 6: Anti-Patterns

```
⚠️  DETECTED ANTI-PATTERNS:
   [SEVERITY 3/5] Call Chain Overhead
   └─ Function contains 2 calls
   💡 Consider: Inlining, batching, function fusion
```

**Severity Levels:**

- **1-2**: Minor issues, nice-to-have optimizations
- **3**: Moderate issues, worth investigating
- **4**: Significant issues, should address
- **5**: Critical performance problems

**Use for:** Prioritizing optimization work

---

### Section 7: Optimization Recommendations

```
💡 OPTIMIZATION RECOMMENDATIONS:
   ✓ [VECTORIZE] High arithmetic - consider SIMD/AVX optimizations
   ✓ [MEMORY-BOUND] Apply memory opt: improve cache locality
```

**Recommendation Types:**

| Type            | Trigger                        | Suggestion         |
| --------------- | ------------------------------ | ------------------ |
| [VECTORIZE]     | >10 arithmetic ops, low memory | Use SIMD/AVX       |
| [MEMORY-BOUND]  | Memory ratio > 0.5             | Cache optimization |
| [COMPUTE-BOUND] | Memory ratio < 0.2             | Parallelization    |
| [CALL-OPT]      | Calls > 0                      | Inline analysis    |

**Use for:** Taking action to optimize

---

## 🛠️ Common Workflows

### Workflow 1: Find Slow Functions

```bash
# Run analysis
opt -load-pass-plugin=./WeightedInstructionAnalysis.so \
    -passes=weighted-instruction-analysis \
    -disable-output \
    mycode.ll > analysis.txt

# Extract top expensive functions
python3 analysis_toolkit.py analysis.txt --text | grep "TOP 5"
```

**Result:**
Shows which functions consume the most CPU cycles.

---

### Workflow 2: Identify Vectorization Opportunities

```bash
# Run toolkit in text mode
python3 analysis_toolkit.py analysis.txt --text

# Look for this section:
#   VECTORIZATION CANDIDATES:
#   • multiply_kernel: 256 arithmetic ops
```

**Next Step:**

- Use `-O3 -march=native` or manually add SIMD intrinsics
- Rerun pass to verify improvements

---

### Workflow 3: Cache Optimization Focus

```bash
# Export to CSV for analysis
python3 analysis_toolkit.py analysis.txt --csv > metrics.csv

# Look for high memory_ratio functions (> 0.5)
# Calculate stride patterns
# Profile with: perf record -e cache-misses
```

**Next Step:**

- Restructure data layout (AOS → SoA)
- Prefetch hot data
- Reduce working set size

---

### Workflow 4: Inlining Analysis

```bash
# Get functions with many calls
python3 analysis_toolkit.py analysis.txt --text | grep "INLINING CANDIDATES"

# Example output shows:
#   • helper_function: 8 function calls
#   • utility_fn: 5 function calls
```

**Next Step:**

- Try: `opt -O3 -inline ...`
- Measure impact with passes

---

### Workflow 5: Generate Comparative Reports

```bash
# Run on multiple files
for file in test*.ll; do
  echo "Analyzing $file..."
  opt -load-pass-plugin=./WeightedInstructionAnalysis.so \
      -passes=weighted-instruction-analysis \
      -disable-output \
      "$file" > "${file%.ll}_analysis.txt"
done

# Create comparison
python3 analysis_toolkit.py test1_analysis.txt --json > report1.json
python3 analysis_toolkit.py test2_analysis.txt --json > report2.json

# Use jq or custom scripts to compare:
# jq '.statistics.total_cost' report1.json
# jq '.statistics.total_cost' report2.json
```

---

## 📊 Analysis Toolkit Usage

### Text Report (Human-Readable)

```bash
python3 analysis_toolkit.py output.txt --text
```

**Output sections:**

- Module statistics
- Top 5 expensive functions
- Memory-bound functions
- Compute-bound functions
- Vectorization candidates
- Inlining candidates

---

### JSON Report (Machine-Readable)

```bash
python3 analysis_toolkit.py output.txt --json > report.json
```

**Usage:**

```bash
# Extract total cost
jq '.statistics.total_cost' report.json

# Get all function names
jq '.functions[].name' report.json

# Find functions with >10 calls
jq '.functions[] | select(.calls > 10)' report.json

# Filter memory-bound
jq '.functions[] | select(.memory_compute_ratio > 0.5)' report.json
```

---

### CSV Report (Spreadsheet Analysis)

```bash
python3 analysis_toolkit.py output.txt --csv > report.csv
```

**Open in Excel/Sheets:**

- Sort by Total_Cost (descending) → Find expensive functions
- Sort by Memory_Ratio (descending) → Memory optimization targets
- Sort by Arithmetic_Ops (descending) → Vectorization candidates
- Filter by Calls > 5 → Inlining opportunities

---

## 🎓 Interpreting Results

### Example 1: Memory-Bound Function

```
Function: image_filter
   Basic Blocks: 15 | Total Instructions: 542

Memory Operations: 412 (76% of instructions)
Arithmetic Operations: 45

Memory-Compute Ratio: 0.76
⚡ MEMORY-BOUND: High memory pressure

DETECTED ANTI-PATTERNS:
   [SEVERITY 4/5] High Memory Pressure
   💡 Consider: Cache optimization, vectorization for aligned accesses
```

**Interpretation:**

- 76% of instructions are memory operations
- CPU is stalling waiting for memory
- Optimization should focus on cache efficiency

**Actions:**

1. Profile cache misses: `perf record -e cache-misses`
2. Consider SIMD for grouped memory access
3. Restructure data layout
4. Use prefetching instructions

---

### Example 2: Compute-Bound Function

```
Function: matrix_multiply
   Basic Blocks: 4 | Total Instructions: 256

Arithmetic Operations: 234 (91%)
Memory Operations: 22 (9%)

Memory-Compute Ratio: 0.09
🎯 COMPUTE-BOUND: Low memory pressure

OPTIMIZATION RECOMMENDATIONS:
   ✓ [VECTORIZE] High arithmetic - consider SIMD/AVX optimizations
```

**Interpretation:**

- Almost all instructions are computation
- CPU can keep busy without memory stalls
- Perfect candidate for parallelization

**Actions:**

1. Enable auto-vectorization: `-O3 -march=native`
2. Use SIMD intrinsics manually for better control
3. OpenMP pragma: `#pragma omp simd`
4. Target: 2-8x speedup with vectorization

---

### Example 3: Call-Heavy Function

```
Function: processing_pipeline
   Basic Blocks: 8 | Total Instructions: 189

Function Calls: 12

DETECTED ANTI-PATTERNS:
   [SEVERITY 3/5] Call Chain Overhead
   💡 Consider: Inlining, batching, function fusion
```

**Interpretation:**

- 12 function calls in 189 instructions
- ~6% of execution is context switching overhead
- Potential for optimization through inlining

**Actions:**

1. Profile to identify hot call sites
2. Try inlining hot functions: `opt -O3 -inline`
3. Consider function fusion for frequently called pairs
4. Measure impact before/after

---

## 🔍 Troubleshooting

### Issue: No Anti-Patterns Detected

**Possible Causes:**

- Function is well-optimized
- Thresholds don't match this code

**Check:**

- Are memory ops < 40%? ✓ (not flagged)
- Are calls < 5? ✓ (not flagged)
- Is arithmetic > 20%? ✓ (not flagged)

**Solution:** This is good! Few anti-patterns means efficient code.

---

### Issue: High Memory Ratio But Can't Optimize

**Check:**

- Is the algorithm inherently memory-intensive?
- Is memory access pattern irregular?
- Are you hitting bandwidth limit?

**Advanced Options:**

1. Profile with: `perf stat -e cache-references,cache-misses`
2. Use NUMA awareness: `numactl`
3. Consider GPU acceleration if available
4. Look for algorithmic alternative

---

### Issue: Vectorization Recommended But Can't Apply

**Possible Reasons:**

1. **Data Dependencies**: Loop-carry dependence
2. **Irregular Access**: Non-contiguous memory
3. **Branches**: Loop-carried if statements

**Solutions:**

1. Try `-O3 -march=native` first (compiler attempts auto-vectorization)
2. Check if loop is amenable: regular stride, no branches
3. Consider manual SIMD if compiler can't auto-vectorize
4. Look at `-fno-math-errno -fno-rounding-math` flags

---

## 📈 Performance Improvement Tracking

### Before & After Comparison

```bash
# Original code
opt -load-pass-plugin=./WeightedInstructionAnalysis.so \
    -passes=weighted-instruction-analysis \
    -disable-output \
    original.ll > original_analysis.txt

# Optimized code
opt -load-pass-plugin=./WeightedInstructionAnalysis.so \
    -passes=weighted-instruction-analysis \
    -disable-output \
    optimized.ll > optimized_analysis.txt

# Compare
python3 analysis_toolkit.py original_analysis.txt --json > original.json
python3 analysis_toolkit.py optimized_analysis.txt --json > optimized.json

# Extract costs
echo "Original Total Cost: $(jq '.statistics.total_cost' original.json)"
echo "Optimized Total Cost: $(jq '.statistics.total_cost' optimized.json)"
```

**Example Results:**

```
Original Total Cost: 2847
Optimized Total Cost: 1124
Improvement: 60.5% reduction in weighted cost!
```

---

## 🚀 Advanced Features

### Module-Level Statistics

Use the toolkit's `--text` output to get aggregate metrics:

```
📊 MODULE STATISTICS:
  Total Functions: 47
  Total Cost: 125,847
  Average Cost/Function: 2678.4
  Most Expensive: encrypt_aes_256
  Average Memory-Compute Ratio: 0.34
```

---

### Per-Function Targeting

From JSON output, identify specific functions to optimize:

```bash
jq '.functions | sort_by(.total_weight_cost) | reverse | .[0:5]' report.json
```

This shows the 5 most expensive functions to target first.

---

## 📚 Additional Resources

- **LLVM Documentation**: https://llvm.org/docs/
- **Performance Tuning**: https://easyperf.net/blog/
- **SIMD Optimization**: https://www.agner.org/optimize/
- **Cache Optimization**: "What Every Programmer Should Know About Memory" by Ulrich Drepper

---

## ✅ Checklist: Using Enhanced Analysis

- [ ] Build pass: `make` in build directory
- [ ] Run on code: `opt -load-pass-plugin=...`
- [ ] Review enhanced output with anti-patterns
- [ ] Use toolkit for cross-function analysis
- [ ] Identify bottleneck type (memory/compute/calls)
- [ ] Check optimization recommendations
- [ ] Apply targeted optimizations
- [ ] Rerun pass to verify improvements
- [ ] Track metrics before/after

---

**Version**: 0.2 Enhanced
**Last Updated**: 2026
**Status**: Ready for production use in research and optimization
