#include "llvm/IR/Function.h"
#include "llvm/IR/BasicBlock.h"
#include "llvm/IR/Instruction.h"
#include "llvm/Pass.h"
#include "llvm/IR/PassManager.h"
#include "llvm/Support/raw_ostream.h"
#include <map>
#include <string>
#include <algorithm>

using namespace llvm;

namespace {

/// WeightedInstructionAnalysis - A pass to analyze instruction frequency
/// and calculate weighted computational complexity for functions.
struct WeightedInstructionAnalysis : public PassInfoMixin<WeightedInstructionAnalysis> {

  /// Returns the weight of an instruction based on its opcode.
  /// Weight rules:
  /// - Standard arithmetic (add, sub) = 1
  /// - Multiplication/Division (mul, sdiv, udiv, fmul, fdiv) = 2
  /// - Memory operations (load, store, alloca) = 3
  /// - Function calls (call, invoke) = 5
  /// - All other instructions (default) = 1
  static int getInstructionWeight(unsigned Opcode) {
    switch (Opcode) {
      // Standard arithmetic: weight 1
      case Instruction::Add:
      case Instruction::Sub:
      case Instruction::FAdd:
      case Instruction::FSub:
        return 1;

      // Multiplication/Division: weight 2
      case Instruction::Mul:
      case Instruction::SDiv:
      case Instruction::UDiv:
      case Instruction::FMul:
      case Instruction::FDiv:
      case Instruction::SRem:
      case Instruction::URem:
      case Instruction::FRem:
        return 2;

      // Memory operations: weight 3
      case Instruction::Load:
      case Instruction::Store:
      case Instruction::Alloca:
        return 3;

      // Function calls: weight 5
      case Instruction::Call:
      case Instruction::Invoke:
        return 5;

      // All other instructions: weight 1 (default)
      default:
        return 1;
    }
  }

  /// Main analysis function.
  PreservedAnalyses run(Function &F, FunctionAnalysisManager &FAM) {
    // Skip functions with empty bodies
    if (F.empty()) {
      return PreservedAnalyses::all();
    }

    // Map to count instruction occurrences
    std::map<std::string, int> InstructionCounts;
    
    // Map to track weighted cost per instruction type
    std::map<std::string, int> WeightedCosts;
    
    // Total weighted cost of the function
    int TotalFunctionCost = 0;

    // Iterate over all basic blocks in the function
    for (BasicBlock &BB : F) {
      // Iterate over all instructions in the basic block
      for (Instruction &I : BB) {
        // Get the instruction name (opcode name)
        std::string InstructionName(I.getOpcodeName());
        
        // Increment the count for this instruction type
        InstructionCounts[InstructionName]++;
        
        // Get the weight for this instruction
        int Weight = getInstructionWeight(I.getOpcode());
        
        // Add to the weighted cost for this instruction type
        WeightedCosts[InstructionName] += Weight;
        
        // Add to the total function cost
        TotalFunctionCost += Weight;
      }
    }

    // Print the results
    errs() << "==================================\n";
    errs() << "Function: " << F.getName() << "\n";
    errs() << "==================================\n";

    // Print instruction frequencies
    errs() << "Instruction Frequencies:\n";
    for (const auto &pair : InstructionCounts) {
      errs() << "  " << pair.first << ": " << pair.second << "\n";
    }

    // Calculate and print total weighted cost
    errs() << "\nTotal Weighted Cost: " << TotalFunctionCost << "\n";

    // Find the most expensive instruction type (by weight contribution)
    std::string MostExpensiveType;
    int MaxWeightedCost = -1;
    for (const auto &pair : WeightedCosts) {
      if (pair.second > MaxWeightedCost) {
        MaxWeightedCost = pair.second;
        MostExpensiveType = pair.first;
      }
    }

    if (!MostExpensiveType.empty()) {
      errs() << "Most Expensive Instruction Type: " << MostExpensiveType 
             << " (weighted cost: " << MaxWeightedCost << ")\n";
    }

    errs() << "==================================\n\n";

    // This pass is analysis-only, it doesn't modify the IR
    return PreservedAnalyses::all();
  }
};

} // end anonymous namespace

// Register the pass with the LLVM pass infrastructure
extern "C" ::llvm::PassPluginLibraryInfo llvmGetPassPluginInfo() {
  return {
    LLVM_PLUGIN_API_VERSION, "WeightedInstructionAnalysis", "v0.1",
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
