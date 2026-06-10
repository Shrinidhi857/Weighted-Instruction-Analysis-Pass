#include "llvm/Passes/PassBuilder.h"
#include "llvm/Passes/PassPlugin.h"
#include "llvm/IR/Function.h"
#include "llvm/IR/BasicBlock.h"
#include "llvm/IR/Instructions.h"
#include "llvm/Support/raw_ostream.h"

#include <map>
#include <string>
#include <algorithm>

using namespace llvm;

namespace {

struct WeightedInstructionAnalysis : public PassInfoMixin<WeightedInstructionAnalysis> {
  PreservedAnalyses run(Function &F, FunctionAnalysisManager &FAM) {
    if (F.isDeclaration()) {
      return PreservedAnalyses::all();
    }

    std::map<std::string, int> Frequencies;
    int TotalWeightedCost = 0;

    // Iterate all basic blocks and instructions in the function
    for (BasicBlock &BB : F) {
      for (Instruction &I : BB) {
        std::string OpcodeName = I.getOpcodeName();
        Frequencies[OpcodeName]++;

        int Weight = 1;
        unsigned Opcode = I.getOpcode();
        switch (Opcode) {
          // add/sub/fadd/fsub = 1
          case Instruction::Add:
          case Instruction::Sub:
          case Instruction::FAdd:
          case Instruction::FSub:
            Weight = 1;
            break;
          // mul/div/fmul/fdiv = 2
          case Instruction::Mul:
          case Instruction::SDiv:
          case Instruction::UDiv:
          case Instruction::FMul:
          case Instruction::FDiv:
            Weight = 2;
            break;
          // load/store/alloca = 3
          case Instruction::Load:
          case Instruction::Store:
          case Instruction::Alloca:
            Weight = 3;
            break;
          // call/invoke = 5
          case Instruction::Call:
          case Instruction::Invoke:
            Weight = 5;
            break;
          // all others = 1
          default:
            Weight = 1;
            break;
        }
        TotalWeightedCost += Weight;
      }
    }

    // Identify the most expensive instruction type (by weighted cost)
    std::string MostExpensiveType = "";
    int MaxWeightedCost = -1;

    for (auto const& [OpcodeName, Count] : Frequencies) {
      int Weight = 1;
      if (OpcodeName == "add" || OpcodeName == "sub" || OpcodeName == "fadd" || OpcodeName == "fsub") {
        Weight = 1;
      } else if (OpcodeName == "mul" || OpcodeName == "sdiv" || OpcodeName == "udiv" || OpcodeName == "fmul" || OpcodeName == "fdiv") {
        Weight = 2;
      } else if (OpcodeName == "load" || OpcodeName == "store" || OpcodeName == "alloca") {
        Weight = 3;
      } else if (OpcodeName == "call" || OpcodeName == "invoke") {
        Weight = 5;
      } else {
        Weight = 1;
      }

      int WeightedCost = Count * Weight;
      if (WeightedCost > MaxWeightedCost) {
        MaxWeightedCost = WeightedCost;
        MostExpensiveType = OpcodeName;
      } else if (WeightedCost == MaxWeightedCost) {
        // Lexicographical tie-breaker for deterministic output
        if (MostExpensiveType.empty() || OpcodeName < MostExpensiveType) {
          MostExpensiveType = OpcodeName;
        }
      }
    }

    // Print formatted output to llvm::outs()
    outs() << "==================================\n";
    outs() << "Function: " << F.getName() << "\n";
    outs() << "==================================\n";
    outs() << "Instruction Frequencies:\n";
    for (auto const& [OpcodeName, Count] : Frequencies) {
      outs() << "  " << OpcodeName << ": " << Count << "\n";
    }
    outs() << "Total Weighted Cost: " << TotalWeightedCost << "\n";
    outs() << "Most Expensive Instruction Type: " << MostExpensiveType 
           << " (weighted cost: " << MaxWeightedCost << ")\n";
    outs() << "==================================\n";

    return PreservedAnalyses::all();
  }
};

} // end anonymous namespace

// Register the pass with the LLVM pass infrastructure
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
