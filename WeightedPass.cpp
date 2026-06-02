#include "llvm/IR/Function.h"
#include "llvm/IR/BasicBlock.h"
#include "llvm/IR/Instruction.h"
#include "llvm/IR/Module.h"
#include "llvm/IR/LoopInfo.h"
#include "llvm/IR/Dominators.h"
#include "llvm/Pass.h"
#include "llvm/IR/PassManager.h"
#include "llvm/Passes/PassBuilder.h"
#include "llvm/Passes/PassPlugin.h"
#include "llvm/Support/raw_ostream.h"
#include "llvm/Analysis/LoopPass.h"
#include <map>
#include <string>
#include <algorithm>
#include <vector>
#include <cmath>
#include <iostream>
#include <sstream>

using namespace llvm;

namespace {

/// Data structure to hold analysis results for a function
struct FunctionAnalysisData {
  std::string FunctionName;
  int TotalWeightedCost;
  int InstructionCount;
  std::map<std::string, int> InstructionCounts;
  std::map<std::string, int> WeightedCosts;
  int MemoryOpsCount;
  int CallsCount;
  int ArithmeticOpsCount;
  int LoopNestingDepth;
  double MemoryComputeRatio;
  int BasicBlockCount;
};

/// Anti-pattern detection results
struct AntiPattern {
  std::string PatternName;
  std::string Description;
  int Severity; // 1-5, 5 being highest
  std::string Recommendation;
/// Anti-pattern detection results
struct AntiPattern {
  std::string PatternName;
  std::string Description;
  int Severity; // 1-5, 5 being highest
  std::string Recommendation;
};

/// WeightedInstructionAnalysis - Enhanced LLVM pass with anti-pattern detection,
/// optimization recommendations, and comparative analysis
struct WeightedInstructionAnalysis : public PassInfoMixin<WeightedInstructionAnalysis> {

  /// Global statistics for module-level analysis
  static std::vector<FunctionAnalysisData> ModuleStatistics;
  static int ModuleFunctionCount;
  
  /// Returns the weight of an instruction based on its opcode.
  static int getInstructionWeight(unsigned Opcode) {
    switch (Opcode) {
      case Instruction::Add:
      case Instruction::Sub:
      case Instruction::FAdd:
      case Instruction::FSub:
        return 1;
      case Instruction::Mul:
      case Instruction::SDiv:
      case Instruction::UDiv:
      case Instruction::FMul:
      case Instruction::FDiv:
      case Instruction::SRem:
      case Instruction::URem:
      case Instruction::FRem:
        return 2;
      case Instruction::Load:
      case Instruction::Store:
      case Instruction::Alloca:
        return 3;
      case Instruction::Call:
      case Instruction::Invoke:
        return 5;
      default:
        return 1;
    }
  }

  /// Get instruction category for analysis
  static std::string getInstructionCategory(const Instruction &I) {
    unsigned Opcode = I.getOpcode();
    if (Opcode == Instruction::Load || Opcode == Instruction::Store || 
        Opcode == Instruction::Alloca)
      return "Memory";
    if (Opcode == Instruction::Call || Opcode == Instruction::Invoke)
      return "Call";
    if (Opcode == Instruction::Mul || Opcode == Instruction::SDiv || 
        Opcode == Instruction::UDiv || Opcode == Instruction::FMul || 
        Opcode == Instruction::FDiv)
      return "HeavyArithmetic";
    if (Opcode == Instruction::Add || Opcode == Instruction::Sub || 
        Opcode == Instruction::FAdd || Opcode == Instruction::FSub)
      return "LightArithmetic";
    return "Other";
  }

  /// Detect anti-patterns in the function
  std::vector<AntiPattern> detectAntiPatterns(const Function &F, 
                                              const FunctionAnalysisData &Data) {
    std::vector<AntiPattern> Patterns;

    // Anti-pattern 1: Excessive memory operations (> 40% of cost)
    if (Data.MemoryComputeRatio > 0.4) {
      AntiPattern P;
      P.PatternName = "High Memory Pressure";
      P.Description = "Memory operations dominate the function (" + 
                      std::to_string((int)(Data.MemoryComputeRatio * 100)) + "% of cost)";
      P.Severity = 4;
      P.Recommendation = "Consider: (1) Cache optimization, (2) Data structure changes, " 
                         "(3) Memory pooling, (4) Vectorization for aligned accesses";
      Patterns.push_back(P);
    }

    // Anti-pattern 2: Many function calls
    if (Data.CallsCount > 5) {
      AntiPattern P;
      P.PatternName = "Call Chain Overhead";
      P.Description = "Function contains " + std::to_string(Data.CallsCount) + 
                      " calls - potential context switching overhead";
      P.Severity = 3;
      P.Recommendation = "Consider: (1) Inlining hot call sites, (2) Reducing call frequency, " 
                         "(3) Batching operations, (4) Function fusion";
      Patterns.push_back(P);
    }

    // Anti-pattern 3: Imbalanced instruction mix
    double ArithRatio = (double)Data.ArithmeticOpsCount / Data.InstructionCount;
    if (ArithRatio < 0.2 && Data.InstructionCount > 10) {
      AntiPattern P;
      P.PatternName = "Computation Underutilization";
      P.Description = "Low arithmetic intensity (" + std::to_string((int)(ArithRatio * 100)) + 
                      "%) - mostly control flow or memory ops";
      P.Severity = 2;
      P.Recommendation = "Consider: (1) Loop fusion to increase compute density, "
                         "(2) Kernel redesign, (3) Algorithmic optimization";
      Patterns.push_back(P);
    }

    // Anti-pattern 4: High cost despite small instruction count
    if (Data.InstructionCount > 0 && 
        (Data.TotalWeightedCost / Data.InstructionCount) > 2.5) {
      AntiPattern P;
      P.PatternName = "Expensive Instruction Mix";
      P.Description = "Average weight per instruction is " + 
                      std::to_string((int)(Data.TotalWeightedCost / Data.InstructionCount * 100) / 100.0);
      P.Severity = 3;
      P.Recommendation = "Consider: (1) Replace multiplications with shifts where possible, "
                         "(2) Vectorization, (3) Precomputation/lookup tables";
      Patterns.push_back(P);
    }

    return Patterns;
  }

  /// Generate optimization recommendations
  std::vector<std::string> generateRecommendations(const FunctionAnalysisData &Data) {
    std::vector<std::string> Recommendations;

    // Memory-bound analysis
    if (Data.MemoryComputeRatio > 0.5) {
      Recommendations.push_back("[MEMORY-BOUND] Apply memory optimization: "
                                "improve cache locality, reduce bandwidth");
    } else if (Data.MemoryComputeRatio < 0.2) {
      Recommendations.push_back("[COMPUTE-BOUND] Use SIMD/vectorization to "
                                "increase throughput");
    }

    // Call optimization
    if (Data.CallsCount > 0) {
      Recommendations.push_back("[CALL-OPT] Profile call sites to identify "
                                "inlining candidates");
    }

    // Vectorization potential
    if (Data.ArithmeticOpsCount > 10 && Data.MemoryComputeRatio < 0.7) {
      Recommendations.push_back("[VECTORIZE] High arithmetic intensity - "
                                "consider SIMD/AVX optimizations");
    }

    return Recommendations;
  }

  /// Main analysis function
  PreservedAnalyses run(Function &F, FunctionAnalysisManager &FAM) {
    if (F.empty() || F.isDeclaration()) {
      return PreservedAnalyses::all();
    }

    FunctionAnalysisData Data;
    Data.FunctionName = F.getName().str();
    Data.TotalWeightedCost = 0;
    Data.InstructionCount = 0;
    Data.MemoryOpsCount = 0;
    Data.CallsCount = 0;
    Data.ArithmeticOpsCount = 0;
    Data.BasicBlockCount = F.size();
    Data.LoopNestingDepth = 0;

    std::map<std::string, int> InstructionCounts;
    std::map<std::string, int> WeightedCosts;

    // Analyze all instructions
    for (BasicBlock &BB : F) {
      for (Instruction &I : BB) {
        std::string InstructionName(I.getOpcodeName());
        InstructionCounts[InstructionName]++;
        Data.InstructionCount++;

        int Weight = getInstructionWeight(I.getOpcode());
        WeightedCosts[InstructionName] += Weight;
        Data.TotalWeightedCost += Weight;

        // Categorize instructions
        std::string Category = getInstructionCategory(I);
        if (Category == "Memory") Data.MemoryOpsCount++;
        else if (Category == "Call") Data.CallsCount++;
        else if (Category == "HeavyArithmetic" || Category == "LightArithmetic") 
          Data.ArithmeticOpsCount++;
      }
    }

    Data.InstructionCounts = InstructionCounts;
    Data.WeightedCosts = WeightedCosts;
    Data.MemoryComputeRatio = Data.InstructionCount > 0 ? 
      (double)Data.MemoryOpsCount / Data.InstructionCount : 0.0;

    ModuleStatistics.push_back(Data);
    ModuleFunctionCount++;

    // === ENHANCED OUTPUT ===
    errs() << "\n╔════════════════════════════════════════════════════════════╗\n";
    errs() << "║  WEIGHTED INSTRUCTION ANALYSIS - ENHANCED REPORT           ║\n";
    errs() << "╚════════════════════════════════════════════════════════════╝\n\n";

    errs() << "📊 Function: " << F.getName() << "\n";
    errs() << "   Basic Blocks: " << Data.BasicBlockCount << " | "
           << "Total Instructions: " << Data.InstructionCount << "\n\n";

    // Instruction breakdown
    errs() << "📈 INSTRUCTION BREAKDOWN:\n";
    errs() << "┌─ Instruction Frequencies:\n";
    for (const auto &pair : InstructionCounts) {
      errs() << "│  ├─ " << pair.first << ": " << pair.second << "\n";
    }
    errs() << "│\n";

    // Categorized analysis
    errs() << "📑 CATEGORIZED ANALYSIS:\n";
    errs() << "   Memory Operations: " << Data.MemoryOpsCount << " ("
           << (int)(Data.MemoryComputeRatio * 100) << "% of instructions)\n";
    errs() << "   Function Calls: " << Data.CallsCount << "\n";
    errs() << "   Arithmetic Operations: " << Data.ArithmeticOpsCount << "\n";

    // Cost analysis
    errs() << "\n💰 COST ANALYSIS:\n";
    errs() << "   Total Weighted Cost: " << Data.TotalWeightedCost << "\n";
    
    if (Data.InstructionCount > 0) {
      double AvgWeight = (double)Data.TotalWeightedCost / Data.InstructionCount;
      errs() << "   Average Weight per Instruction: " << AvgWeight << "\n";
    }

    // Most expensive instruction type
    std::string MostExpensiveType;
    int MaxWeightedCost = -1;
    for (const auto &pair : WeightedCosts) {
      if (pair.second > MaxWeightedCost) {
        MaxWeightedCost = pair.second;
        MostExpensiveType = pair.first;
      }
    }

    if (!MostExpensiveType.empty()) {
      errs() << "   🔥 Bottleneck: " << MostExpensiveType 
             << " (weighted cost: " << MaxWeightedCost << ")\n";
    }

    // Memory vs Compute ratio
    errs() << "\n⚙️  PERFORMANCE PROFILE:\n";
    if (Data.MemoryComputeRatio > 0.5) {
      errs() << "   ⚡ MEMORY-BOUND: High memory pressure\n";
      errs() << "      Cache optimization is critical\n";
    } else if (Data.MemoryComputeRatio < 0.2) {
      errs() << "   🎯 COMPUTE-BOUND: Low memory pressure\n";
      errs() << "      SIMD/vectorization opportunities exist\n";
    } else {
      errs() << "   ⚖️  BALANCED: Moderate memory-compute ratio\n";
    }

    // Anti-patterns
    std::vector<AntiPattern> Patterns = detectAntiPatterns(F, Data);
    if (!Patterns.empty()) {
      errs() << "\n⚠️  DETECTED ANTI-PATTERNS:\n";
      for (const auto &P : Patterns) {
        errs() << "   [SEVERITY " << P.Severity << "/5] " << P.PatternName << "\n";
        errs() << "   └─ " << P.Description << "\n";
        errs() << "   💡 " << P.Recommendation << "\n\n";
      }
    }

    // Optimization recommendations
    std::vector<std::string> Recommendations = generateRecommendations(Data);
    if (!Recommendations.empty()) {
      errs() << "💡 OPTIMIZATION RECOMMENDATIONS:\n";
      for (const auto &Rec : Recommendations) {
        errs() << "   ✓ " << Rec << "\n";
      }
      errs() << "\n";
    }

    errs() << "╔════════════════════════════════════════════════════════════╗\n\n";

    return PreservedAnalyses::all();
  }
};

std::vector<FunctionAnalysisData> WeightedInstructionAnalysis::ModuleStatistics;
int WeightedInstructionAnalysis::ModuleFunctionCount = 0;

} // end anonymous namespace

// Register the pass with the LLVM pass infrastructure
extern "C" ::llvm::PassPluginLibraryInfo llvmGetPassPluginInfo() {
  return {
    LLVM_PLUGIN_API_VERSION, "WeightedInstructionAnalysis", "v0.2",
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
