# Design Document: Weighted Instruction Analysis Pass

## 1. Approach
The primary objective of the **Weighted Instruction Analysis Pass** is to statically estimate the computational complexity of LLVM IR functions by assigning weighted scores to different instruction classes. Unlike raw instruction counts, our design factors in hardware realities (e.g., latency, memory hierarchy, branch overhead) to pinpoint execution bottlenecks.

### Architectural Core
*   **Granularity:** Implemented as a `FunctionPass` utilizing LLVM's new PassManager infrastructure. It analyzes functions independently, preserving scalability and enabling parallel analysis.
*   **Static Traversal:** The pass walks through the control flow graph (CFG) by iterating over all `BasicBlock` elements in a function, and then sequentially iterating over the `Instruction` elements in each block.
*   **Weighted Scoring Model:** A mapping framework maps each instruction class to a weight coefficient:
    *   **Simple Arithmetic (weight = 1):** `add`, `sub`, `fadd`, `fsub` (cheap, single-cycle CPU operations).
    *   **Heavy Arithmetic (weight = 2):** `mul`, `div`, `fmul`, `fdiv`, `sdiv`, `udiv` (multi-cycle ALU execution).
    *   **Memory Operations (weight = 3):** `load`, `store`, `alloca` (subject to cache hits/misses and memory latency).
    *   **Control/Call Operations (weight = 5):** `call`, `invoke` (context-switch overhead, register saving, and call stack creation).
    *   **Other (weight = 1):** `br`, `ret`, `icmp`, etc.
*   **Frequency Tracking:** Uses a sorted associative container (`std::map<std::string, int>`) to track occurrences of instruction type names (lowercase opcodes from `I.getOpcodeName()`) to ensure deterministic output.
*   **Bottleneck Identification:** Computes the total weighted cost per instruction type (`count * weight`) and selects the instruction type that contributes the most to the function's overall weighted cost.

---

## 2. Alternatives Considered

### Alternative A: Runtime / Dynamic Profiling (e.g., gprof, Valgrind, or PAPI)
*   **Description:** Injecting instrumentation code at compile-time to measure actual CPU cycle counts or instruction retirement counts at runtime.
*   **Why Rejected:** Dynamic profiling requires representative inputs and a target execution environment. It also introduces runtime instrumentation overhead. Static analysis via an LLVM pass is input-independent, executes entirely during compilation, and has zero runtime footprint.

### Alternative B: Legacy Pass Manager Registration
*   **Description:** Registering the pass using the legacy PassManager via `RegisterPass<T>` or `llvm::RegisterStandardPasses`.
*   **Why Rejected:** LLVM has deprecated the legacy PassManager in favor of the new PassManager. The new PassManager offers a cleaner separation of analyses and transformations, better execution caching, and is the default framework starting in LLVM 15 through LLVM 21.

### Alternative C: ModulePass instead of FunctionPass
*   **Description:** Traversing the entire translation unit (`Module`) as a single unit rather than block-by-block per `Function`.
*   **Why Rejected:** A `ModulePass` requires loading and holding reference tracking for the entire module, consuming more memory and limiting LLVM's ability to run the analysis pipeline in parallel. A `FunctionPass` is modular, thread-safe, and integrates perfectly with LLVM's scheduling design.
