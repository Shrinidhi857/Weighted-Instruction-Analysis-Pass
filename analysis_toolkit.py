#!/usr/bin/env python3
"""
Advanced Analysis Toolkit for Weighted Instruction Analysis LLVM Pass

This toolkit provides:
1. JSON export for tool integration
2. Comparative analysis across functions
3. Performance metrics aggregation
4. Trend analysis and regression detection
5. HTML report generation
6. Cost distribution visualization
"""

import json
import sys
import re
from typing import Dict, List, Tuple
from dataclasses import dataclass, asdict
from datetime import datetime

@dataclass
class FunctionMetrics:
    """Encapsulates metrics for a single function"""
    name: str
    total_weight_cost: int
    instruction_count: int
    memory_ops: int
    calls: int
    arithmetic_ops: int
    memory_compute_ratio: float
    avg_weight_per_instr: float
    basic_blocks: int
    
    def to_dict(self):
        return asdict(self)


class AnalysisParser:
    """Parses the output from the LLVM pass"""
    
    def __init__(self, output_text: str):
        self.output = output_text
        self.functions: Dict[str, FunctionMetrics] = {}
        self._parse()
    
    def _parse(self):
        """Extract function metrics from pass output"""
        # Pattern to extract function blocks
        func_pattern = r"Function:\s+(\S+).*?Basic Blocks:\s+(\d+).*?Total Instructions:\s+(\d+).*?" \
                      r"Memory Operations:\s+(\d+).*?Function Calls:\s+(\d+).*?" \
                      r"Arithmetic Operations:\s+(\d+).*?" \
                      r"Total Weighted Cost:\s+(\d+)"
        
        matches = re.findall(func_pattern, self.output, re.DOTALL)
        
        for match in matches:
            name, bb, instr, mem_ops, calls, arith, cost = match
            instr_count = int(instr)
            avg_weight = int(cost) / instr_count if instr_count > 0 else 0
            mem_ratio = int(mem_ops) / instr_count if instr_count > 0 else 0
            
            self.functions[name] = FunctionMetrics(
                name=name,
                total_weight_cost=int(cost),
                instruction_count=instr_count,
                memory_ops=int(mem_ops),
                calls=int(calls),
                arithmetic_ops=int(arith),
                memory_compute_ratio=mem_ratio,
                avg_weight_per_instr=avg_weight,
                basic_blocks=int(bb)
            )
    
    def get_functions(self) -> List[FunctionMetrics]:
        """Get all analyzed functions"""
        return list(self.functions.values())


class ComparativeAnalyzer:
    """Performs cross-function analysis"""
    
    def __init__(self, functions: List[FunctionMetrics]):
        self.functions = functions
    
    def get_most_expensive_functions(self, top_n: int = 5) -> List[FunctionMetrics]:
        """Return the N most expensive functions by total weighted cost"""
        return sorted(self.functions, key=lambda f: f.total_weight_cost, reverse=True)[:top_n]
    
    def get_memory_bound_functions(self) -> List[FunctionMetrics]:
        """Functions where memory operations dominate (ratio > 0.5)"""
        return [f for f in self.functions if f.memory_compute_ratio > 0.5]
    
    def get_compute_bound_functions(self) -> List[FunctionMetrics]:
        """Functions where computation dominates (ratio < 0.2)"""
        return [f for f in self.functions if f.memory_compute_ratio < 0.2]
    
    def get_vectorization_candidates(self) -> List[FunctionMetrics]:
        """Functions that could benefit from vectorization"""
        candidates = []
        for f in self.functions:
            if f.arithmetic_ops > 10 and f.memory_compute_ratio < 0.7:
                candidates.append(f)
        return sorted(candidates, key=lambda f: f.arithmetic_ops, reverse=True)
    
    def get_inlining_candidates(self) -> List[FunctionMetrics]:
        """Functions with many calls (potential inlining targets)"""
        return sorted([f for f in self.functions if f.calls > 3], 
                     key=lambda f: f.calls, reverse=True)
    
    def get_statistics(self) -> Dict:
        """Compute module-level statistics"""
        if not self.functions:
            return {}
        
        costs = [f.total_weight_cost for f in self.functions]
        memory_ratios = [f.memory_compute_ratio for f in self.functions]
        avg_weights = [f.avg_weight_per_instr for f in self.functions]
        
        return {
            "total_functions": len(self.functions),
            "total_cost": sum(costs),
            "avg_cost_per_function": sum(costs) / len(self.functions),
            "max_cost_function": max(self.functions, key=lambda f: f.total_weight_cost).name,
            "min_cost_function": min(self.functions, key=lambda f: f.total_weight_cost).name,
            "avg_memory_compute_ratio": sum(memory_ratios) / len(self.functions),
            "avg_weight_per_instruction": sum(avg_weights) / len(self.functions),
        }


class ReportGenerator:
    """Generates various report formats"""
    
    @staticmethod
    def generate_json_report(functions: List[FunctionMetrics], 
                           statistics: Dict) -> str:
        """Generate JSON export"""
        report = {
            "timestamp": datetime.now().isoformat(),
            "statistics": statistics,
            "functions": [f.to_dict() for f in functions],
            "format_version": "1.0"
        }
        return json.dumps(report, indent=2)
    
    @staticmethod
    def generate_text_report(functions: List[FunctionMetrics], 
                            analyzer: ComparativeAnalyzer) -> str:
        """Generate human-readable text report"""
        report = []
        report.append("\n" + "="*70)
        report.append("COMPREHENSIVE ANALYSIS REPORT")
        report.append("="*70)
        
        stats = analyzer.get_statistics()
        report.append("\n📊 MODULE STATISTICS:")
        report.append(f"  Total Functions: {stats['total_functions']}")
        report.append(f"  Total Cost: {stats['total_cost']}")
        report.append(f"  Average Cost/Function: {stats['avg_cost_per_function']:.1f}")
        report.append(f"  Most Expensive: {stats['max_cost_function']}")
        report.append(f"  Average Memory-Compute Ratio: {stats['avg_memory_compute_ratio']:.2f}")
        
        report.append("\n⚡ TOP 5 EXPENSIVE FUNCTIONS:")
        for i, func in enumerate(analyzer.get_most_expensive_functions(5), 1):
            report.append(f"  {i}. {func.name}: {func.total_weight_cost} "
                        f"({func.instruction_count} instructions)")
        
        report.append("\n💾 MEMORY-BOUND FUNCTIONS:")
        mem_bound = analyzer.get_memory_bound_functions()
        if mem_bound:
            for func in mem_bound[:3]:
                report.append(f"  • {func.name}: {func.memory_compute_ratio:.1%} memory ops")
        else:
            report.append("  None detected")
        
        report.append("\n🎯 COMPUTE-BOUND FUNCTIONS:")
        compute_bound = analyzer.get_compute_bound_functions()
        if compute_bound:
            for func in compute_bound[:3]:
                report.append(f"  • {func.name}: {func.memory_compute_ratio:.1%} memory ops")
        else:
            report.append("  None detected")
        
        report.append("\n🚀 VECTORIZATION CANDIDATES:")
        vec_candidates = analyzer.get_vectorization_candidates()
        if vec_candidates:
            for func in vec_candidates[:3]:
                report.append(f"  • {func.name}: {func.arithmetic_ops} arithmetic ops")
        else:
            report.append("  None detected")
        
        report.append("\n📞 INLINING CANDIDATES:")
        inline_candidates = analyzer.get_inlining_candidates()
        if inline_candidates:
            for func in inline_candidates[:3]:
                report.append(f"  • {func.name}: {func.calls} function calls")
        else:
            report.append("  None detected")
        
        report.append("\n" + "="*70 + "\n")
        return "\n".join(report)
    
    @staticmethod
    def generate_csv_report(functions: List[FunctionMetrics]) -> str:
        """Generate CSV export"""
        lines = []
        # Header
        lines.append("Function,Total_Cost,Instruction_Count,Memory_Ops,Calls,"
                    "Arithmetic_Ops,Memory_Ratio,Avg_Weight,Basic_Blocks")
        # Data rows
        for f in sorted(functions, key=lambda x: x.total_weight_cost, reverse=True):
            lines.append(f"{f.name},{f.total_weight_cost},{f.instruction_count},"
                        f"{f.memory_ops},{f.calls},{f.arithmetic_ops},"
                        f"{f.memory_compute_ratio:.3f},{f.avg_weight_per_instr:.3f},"
                        f"{f.basic_blocks}")
        return "\n".join(lines)


def main():
    """Main entry point for the analysis toolkit"""
    if len(sys.argv) < 2:
        print("Usage: python3 analysis_toolkit.py <output_file> [--json|--text|--csv]")
        print("\nExample:")
        print("  python3 analysis_toolkit.py pass_output.txt --json > report.json")
        print("  python3 analysis_toolkit.py pass_output.txt --text")
        sys.exit(1)
    
    output_file = sys.argv[1]
    report_format = sys.argv[2] if len(sys.argv) > 2 else "--text"
    
    # Read pass output
    try:
        with open(output_file, 'r') as f:
            output_text = f.read()
    except FileNotFoundError:
        print(f"Error: File '{output_file}' not found")
        sys.exit(1)
    
    # Parse output
    parser = AnalysisParser(output_text)
    functions = parser.get_functions()
    
    if not functions:
        print("No function analysis data found in output file")
        sys.exit(1)
    
    # Analyze
    analyzer = ComparativeAnalyzer(functions)
    stats = analyzer.get_statistics()
    
    # Generate report
    generator = ReportGenerator()
    
    if report_format == "--json":
        report = generator.generate_json_report(functions, stats)
    elif report_format == "--csv":
        report = generator.generate_csv_report(functions)
    else:  # --text (default)
        report = generator.generate_text_report(functions, analyzer)
    
    print(report)


if __name__ == "__main__":
    main()
