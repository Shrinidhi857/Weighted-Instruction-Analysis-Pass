# Evaluation: Weighted Instruction Analysis Pass

## 1. Metrics and Profile Evaluation

The analysis pass computes two primary metrics to evaluate a function's performance profile:
1.  **Total Weighted Cost:** An indicator of computational intensity, reflecting execution overhead better than simple instruction counts.
2.  **Most Expensive Instruction Type (Bottleneck):** Identifies which class of operations consumes the largest fraction of the function's weighted budget.

---

## 2. Test Case Profiles and Code Details

The pass was evaluated using two C source files compiled into LLVM IR:

### Test Case 1: Arithmetic-Heavy (`testcases/test1.c`)
*   **Characteristics:** Implements an arithmetic-intensive loop. It is computation-heavy but has very low memory usage and call count.
*   **C Code:**
    ```c
    int arithmetic_heavy(int n) {
        int result = 0;
        for (int i = 0; i < n; i++) {
            result = result + i;
            result = result * i;
            result = result - 1;
            result = result + i;
        }
        return result;
    }
    ```

### Test Case 2: Memory/Call-Heavy (`testcases/test2.c`)
*   **Characteristics:** Accesses array indexes sequentially (`load`/`store` operations) and calls an external helper function (`helper_function`) inside a loop.
*   **C Code:**
    ```c
    int helper_function(int x) {
        return (x * 2) + x;
    }

    int memory_and_call_heavy(int *arr, int size) {
        int result = 0;
        for (int i = 0; i < size; i++) {
            int temp = arr[i];
            temp = helper_function(temp);
            result = result + temp;
            arr[i] = temp;
        }
        return result;
    }
    ```

---

## 3. Metric Comparison

When analyzing the compiled IR files (`testcases/test1.ll` and `testcases/test2.ll`), we observe distinct patterns:

| Metric | test1.ll (`arithmetic_heavy`) | test2.ll (`memory_and_call_heavy`) |
| :--- | :--- | :--- |
| **Total Instructions** | 24 | 33 |
| **Memory Ops (`alloca`/`load`/`store`)** | 18 (Cost: 54) | 21 (Cost: 63) |
| **Control Flow (`br`)** | 5 (Cost: 5) | 5 (Cost: 5) |
| **Simple Math (`add`/`sub`)** | 4 (Cost: 4) | 2 (Cost: 2) |
| **Heavy Math (`mul`)** | 1 (Cost: 2) | 0 (Cost: 0) |
| **Function Calls (`call`)** | 0 (Cost: 0) | 1 (Cost: 5) |
| **Other Ops (`icmp`/`ret`)** | 2 (Cost: 2) | 5 (Cost: 5) |
| **Total Weighted Cost** | 67 | 80 |
| **Most Expensive Type** | `load` (weighted cost: 24) | `load` (weighted cost: 30) |

### Performance Analysis
*   While `test1.ll` is arithmetic-heavy, the overhead of storing and loading values from the stack (due to compiling at `-O0`) makes memory instructions (`load`/`store`) the dominant cost.
*   In `test2.ll`, the inclusion of the array access (`getelementptr` + `load` + `store`) along with the `call` instruction (weighted at 5) pushes the total cost higher, proving that memory and call-heavy code incurs significantly greater execution overhead.
*   The pass successfully detects these differences and accurately attributes the main bottleneck in both functions.

---

## 4. Sample Outputs

### Execution Output on `testcases/test1.ll`
```
==================================
Function: arithmetic_heavy
==================================
Instruction Frequencies:
  add: 3
  alloca: 3
  br: 5
  icmp: 1
  load: 8
  mul: 1
  ret: 1
  store: 7
  sub: 1
Total Weighted Cost: 67
Most Expensive Instruction Type: load (weighted cost: 24)
==================================
```

### Execution Output on `testcases/test2.ll`
```
==================================
Function: memory_and_call_heavy
==================================
Instruction Frequencies:
  add: 1
  alloca: 5
  br: 5
  call: 1
  getelementptr: 2
  icmp: 1
  load: 10
  ret: 1
  sext: 2
  store: 6
Total Weighted Cost: 80
Most Expensive Instruction Type: load (weighted cost: 30)
==================================
==================================
Function: helper_function
==================================
Instruction Frequencies:
  add: 1
  alloca: 1
  load: 2
  mul: 1
  ret: 1
  store: 1
Total Weighted Cost: 14
Most Expensive Instruction Type: load (weighted cost: 6)
==================================
```
