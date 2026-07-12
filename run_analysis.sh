#!/bin/bash
# Enhanced Weighted Instruction Analysis - Automated Workflow Script
# Usage: ./run_analysis.sh [ll_file] [--compare baseline.txt] [--output-dir results/]

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PASS_PLUGIN="./WeightedInstructionAnalysis.so"
TOOLKIT="./analysis_toolkit.py"
OUTPUT_DIR="./analysis_results"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Function to print colored output
print_status() {
    echo -e "${BLUE}▶${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

# Function to display usage
usage() {
    cat << EOF
Enhanced Weighted Instruction Analysis - Automated Workflow

Usage: $0 [OPTIONS] <ll_file>

OPTIONS:
    -h, --help              Show this help message
    -o, --output-dir DIR    Output directory (default: ./analysis_results)
    -c, --compare FILE      Compare against baseline analysis
    -f, --format FORMAT     Report format: text, json, csv, all (default: all)
    -v, --verbose           Verbose output
    --build                 Rebuild pass before running

EXAMPLES:
    # Basic analysis
    $0 test1.ll

    # Analysis with custom output directory
    $0 -o my_results test1.ll

    # Compare against baseline
    $0 -c baseline_analysis.txt test1.ll

    # Generate only JSON report
    $0 -f json test1.ll

EOF
    exit 1
}

# Parse command line arguments
COMPARE_FILE=""
OUTPUT_FORMAT="all"
VERBOSE=false
BUILD_FIRST=false
LL_FILE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            usage
            ;;
        -o|--output-dir)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -c|--compare)
            COMPARE_FILE="$2"
            shift 2
            ;;
        -f|--format)
            OUTPUT_FORMAT="$2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        --build)
            BUILD_FIRST=true
            shift
            ;;
        *)
            LL_FILE="$1"
            shift
            ;;
    esac
done

# Validate arguments
if [ -z "$LL_FILE" ]; then
    print_error "No input file specified"
    usage
fi

if [ ! -f "$LL_FILE" ]; then
    print_error "Input file not found: $LL_FILE"
    exit 1
fi

# Create output directory
mkdir -p "$OUTPUT_DIR"

print_status "Enhanced Weighted Instruction Analysis Workflow"
print_status "=================================================="
echo ""

# Step 1: Build if requested
if [ "$BUILD_FIRST" = true ]; then
    print_status "Building pass plugin..."
    if [ -d "build" ]; then
        # Determine number of CPU cores
        if command -v nproc &> /dev/null; then
            NUM_CORES=$(nproc)
        elif command -v sysctl &> /dev/null; then
            NUM_CORES=$(sysctl -n hw.ncpu)
        else
            NUM_CORES=2
        fi
        make -j$NUM_CORES
        cd ..
        print_success "Build completed"
    else
        print_error "Build directory not found. Create it first:"
        print_error "  mkdir build && cd build"
        print_error "  cmake -DCMAKE_BUILD_TYPE=Release -DLLVM_DIR=\$(llvm-config --cmakedir) .."
        exit 1
    fi
    echo ""
fi

# Step 2: Check if pass plugin exists
if [ ! -f "$PASS_PLUGIN" ]; then
    # Try locating the library in current directory or build directory with various suffixes/prefixes
    FOUND_PLUGIN=""
    for name in "WeightedInstructionAnalysis.so" "libWeightedInstructionAnalysis.so" "WeightedInstructionAnalysis.dylib" "libWeightedInstructionAnalysis.dylib"; do
        if [ -f "$name" ]; then
            FOUND_PLUGIN="$name"
            break
        elif [ -f "build/$name" ]; then
            FOUND_PLUGIN="build/$name"
            break
        fi
    done
    
    if [ -n "$FOUND_PLUGIN" ]; then
        PASS_PLUGIN="$FOUND_PLUGIN"
    else
        print_error "Pass plugin not found. Build it first with --build flag"
        exit 1
    fi
fi

print_status "Pass plugin: $PASS_PLUGIN"
echo ""

# Step 3: Run the pass
print_status "Running weighted instruction analysis..."
ANALYSIS_OUTPUT="$OUTPUT_DIR/${TIMESTAMP}_analysis.txt"

opt -load-pass-plugin="$PASS_PLUGIN" \
    -passes=weighted-instruction-analysis \
    -disable-output \
    "$LL_FILE" > "$ANALYSIS_OUTPUT" 2>&1

if [ $? -ne 0 ]; then
    print_error "Pass execution failed"
    exit 1
fi

print_success "Analysis completed"
print_status "Output saved to: $ANALYSIS_OUTPUT"
echo ""

# Step 4: Generate reports
print_status "Generating reports..."
echo ""

case "$OUTPUT_FORMAT" in
    text)
        print_status "Generating text report..."
        python3 "$TOOLKIT" "$ANALYSIS_OUTPUT" --text > "$OUTPUT_DIR/${TIMESTAMP}_report.txt"
        print_success "Text report: $OUTPUT_DIR/${TIMESTAMP}_report.txt"
        ;;
    json)
        print_status "Generating JSON report..."
        python3 "$TOOLKIT" "$ANALYSIS_OUTPUT" --json > "$OUTPUT_DIR/${TIMESTAMP}_report.json"
        print_success "JSON report: $OUTPUT_DIR/${TIMESTAMP}_report.json"
        ;;
    csv)
        print_status "Generating CSV report..."
        python3 "$TOOLKIT" "$ANALYSIS_OUTPUT" --csv > "$OUTPUT_DIR/${TIMESTAMP}_report.csv"
        print_success "CSV report: $OUTPUT_DIR/${TIMESTAMP}_report.csv"
        ;;
    all)
        print_status "Generating all reports..."
        python3 "$TOOLKIT" "$ANALYSIS_OUTPUT" --text > "$OUTPUT_DIR/${TIMESTAMP}_report.txt"
        print_success "  ✓ Text report"
        python3 "$TOOLKIT" "$ANALYSIS_OUTPUT" --json > "$OUTPUT_DIR/${TIMESTAMP}_report.json"
        print_success "  ✓ JSON report"
        python3 "$TOOLKIT" "$ANALYSIS_OUTPUT" --csv > "$OUTPUT_DIR/${TIMESTAMP}_report.csv"
        print_success "  ✓ CSV report"
        ;;
    *)
        print_error "Unknown format: $OUTPUT_FORMAT"
        exit 1
        ;;
esac

echo ""

# Step 5: Compare if requested
if [ -n "$COMPARE_FILE" ]; then
    print_status "Comparing with baseline: $COMPARE_FILE"
    echo ""
    
    if [ ! -f "$COMPARE_FILE" ]; then
        print_warning "Baseline file not found: $COMPARE_FILE"
    else
        # Extract costs from both files
        CURRENT_COST=$(grep -o "Total Weighted Cost: [0-9]*" "$ANALYSIS_OUTPUT" | \
                      awk '{sum += $NF} END {print sum}')
        BASELINE_COST=$(grep -o "Total Weighted Cost: [0-9]*" "$COMPARE_FILE" | \
                       awk '{sum += $NF} END {print sum}')
        
        if [ -n "$CURRENT_COST" ] && [ -n "$BASELINE_COST" ]; then
            IMPROVEMENT=$(echo "scale=2; ($BASELINE_COST - $CURRENT_COST) * 100 / $BASELINE_COST" | bc)
            
            print_status "Comparison Results:"
            echo "  Baseline Total Cost:  $BASELINE_COST"
            echo "  Current Total Cost:   $CURRENT_COST"
            
            if (( $(echo "$IMPROVEMENT > 0" | bc -l) )); then
                echo -e "  ${GREEN}Improvement: +$IMPROVEMENT%${NC}"
            elif (( $(echo "$IMPROVEMENT < 0" | bc -l) )); then
                echo -e "  ${RED}Regression: $IMPROVEMENT%${NC}"
            else
                echo "  Change: No change"
            fi
        else
            print_warning "Could not extract cost data for comparison"
        fi
    fi
    echo ""
fi

# Step 6: Display summary
print_status "Analysis Summary"
print_status "================="
echo ""
print_success "Output directory: $OUTPUT_DIR"
echo "  Files:"
echo "    - $ANALYSIS_OUTPUT (raw pass output)"
echo "    - ${TIMESTAMP}_report.* (formatted reports)"
echo ""

# Display key statistics from raw output
if [ "$VERBOSE" = true ]; then
    print_status "Key Statistics:"
    echo ""
    grep -E "(Function:|Total Weighted Cost:|Memory Operations:|Arithmetic Operations:|MEMORY-BOUND|COMPUTE-BOUND|PERFORMANCE PROFILE)" \
        "$ANALYSIS_OUTPUT" | head -20
    echo ""
fi

print_success "Analysis workflow completed!"
print_status "Next steps:"
echo "  1. Review text report:     cat $OUTPUT_DIR/${TIMESTAMP}_report.txt"
echo "  2. Parse JSON data:        jq . $OUTPUT_DIR/${TIMESTAMP}_report.json"
echo "  3. Open CSV in Excel:      $OUTPUT_DIR/${TIMESTAMP}_report.csv"
echo ""

