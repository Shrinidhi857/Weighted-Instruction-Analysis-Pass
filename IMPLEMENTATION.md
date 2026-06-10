# Implementation Details: Weighted Instruction Analysis Pass

## 1. LLVM Pass Infrastructure
The pass is built using the **new LLVM PassManager** API (introduced as the default in modern LLVM releases up to LLVM 21).

### Inheritance and Standard Boilerplate
The analysis pass class `WeightedInstructionAnalysis` inherits from `llvm::PassInfoMixin<WeightedInstructionAnalysis>`:
```cpp
struct WeightedInstructionAnalysis : public PassInfoMixin<WeightedInstructionAnalysis> {
  PreservedAnalyses run(Function &F, FunctionAnalysisManager &FAM);
};
```
*   `PassInfoMixin<T>` is a CRTP (Curiously Recurring Template Pattern) helper class that provides standard boilerplate methods (like `name()`) for pass execution tracking.
*   The `run` method is invoked by the PassManager. It returns a `PreservedAnalyses` struct. Because this pass only gathers and prints metrics and does not mutate the IR, it returns `PreservedAnalyses::all()` to inform the compiler that all existing analysis results remain valid.

---

## 2. Dynamic Plugin Registration
To allow LLVM's `opt` driver to load the pass dynamically from a shared object/DLL, the pass implements the standard `llvmGetPassPluginInfo` entry point:

```cpp
extern "C" ::llvm::PassPluginLibraryInfo llvmGetPassPluginInfo() {
  return {
    LLVM_PLUGIN_API_VERSION, "weighted-instruction-analysis", "1.0",
    [](PassBuilder &PB) {
      PB.registerPipelineParsingCallback(
          [](StringRef Name, FunctionPassManager &FPM,
             ArrayRef<PassBuilder::PipelineElement>) {
            if (Name == "weighted-instruction-analysis") {
              FPM.addPass(WeightedInstructionAnalysis());
              return true;
            }
            return false;
          });
    }
  };
}
```
*   `extern "C"` prevents C++ name mangling, allowing LLVM's plugin loader to look up `llvmGetPassPluginInfo` via `dlsym`.
*   `registerPipelineParsingCallback` hooks into LLVM's command-line pass pipeline parser, checking if `-passes=weighted-instruction-analysis` is specified and appending our pass to the pipeline.

---

## 3. Instruction Classification & Weight Mapping
Within the `run` method, we loop over basic blocks and instructions:

```cpp
for (BasicBlock &BB : F) {
  for (Instruction &I : BB) {
    std::string OpcodeName = I.getOpcodeName();
    // ...
```
1.  **Opcodes name mapping:** `I.getOpcodeName()` returns a lowercase string corresponding to the instruction opcode (e.g. `"alloca"`, `"load"`, `"add"`). This is used as the key in our frequency tracking map (`std::map<std::string, int> Frequencies`).
2.  **Opcode evaluation:** To calculate weights, the pass queries the integer opcode using `I.getOpcode()` and processes it using a `switch` statement:
    *   `Instruction::Add`, `Instruction::Sub`, `Instruction::FAdd`, `Instruction::FSub` -> Weight = 1
    *   `Instruction::Mul`, `Instruction::SDiv`, `Instruction::UDiv`, `Instruction::FMul`, `Instruction::FDiv` -> Weight = 2
    *   `Instruction::Load`, `Instruction::Store`, `Instruction::Alloca` -> Weight = 3
    *   `Instruction::Call`, `Instruction::Invoke` -> Weight = 5
    *   Default fallback -> Weight = 1

---

## 4. Bottleneck Analysis and Tie-Breaking
The pass identifies the instruction type that contributes the most to the total weighted cost.
*   **Total Cost per Type:** Evaluated as `Count * Weight`.
*   **Determinism & Tie-Breaker:** In case two instruction classes yield the same weighted cost contribution, a lexicographical comparison on their names (`OpcodeName < MostExpensiveType`) is used. This guarantees that the printed bottleneck is 100% deterministic regardless of instruction parsing order.

---

## 5. Output Management
We print formatted summaries directly to the LLVM standard output stream `llvm::outs()`. This makes it easy to pipe output to files or parse it via custom scripts:

```cpp
outs() << "==================================\n";
outs() << "Function: " << F.getName() << "\n";
outs() << "==================================\n";
// ...
```
Using `llvm::outs()` ensures that warnings or unrelated messages written to `llvm::errs()` do not pollute the analysis log files.
