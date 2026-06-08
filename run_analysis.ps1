# Enhanced Weighted Instruction Analysis - Automated Workflow Script (PowerShell)
# Usage: .\run_analysis.ps1 -LLFile test1.ll -OutputDir results -Compare baseline.txt

param(
    [Parameter(Mandatory=$true, HelpMessage="Path to LLVM IR (.ll) file")]
    [string]$LLFile,
    
    [Parameter(HelpMessage="Output directory for reports")]
    [string]$OutputDir = "./analysis_results",
    
    [Parameter(HelpMessage="Baseline analysis file for comparison")]
    [string]$CompareFile = "",
    
    [Parameter(HelpMessage="Report format: text, json, csv, all")]
    [string]$Format = "all",
    
    [Parameter(HelpMessage="Build pass plugin before running")]
    [switch]$BuildFirst,
    
    [Parameter(HelpMessage="Verbose output")]
    [switch]$Verbose
)

# Configuration
$PassPlugin = "./WeightedInstructionAnalysis.so"
$Toolkit = "./analysis_toolkit.py"
$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"

# Color output functions
function Write-Status {
    param([string]$Message)
    Write-Host "▶ $Message" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "✓ $Message" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "⚠ $Message" -ForegroundColor Yellow
}

function Write-Error-Custom {
    param([string]$Message)
    Write-Host "✗ $Message" -ForegroundColor Red
}

# Validate input
if (-not (Test-Path $LLFile)) {
    Write-Error-Custom "Input file not found: $LLFile"
    exit 1
}

# Create output directory
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

Write-Status "Enhanced Weighted Instruction Analysis Workflow"
Write-Status "=================================================="
Write-Host ""

# Step 1: Build if requested
if ($BuildFirst) {
    Write-Status "Building pass plugin..."
    if (Test-Path "build") {
        Push-Location build
        cmake --build . --config Release
        Pop-Location
        Write-Success "Build completed"
    }
    else {
        Write-Error-Custom "Build directory not found. Create it first:"
        Write-Host "  mkdir build"
        Write-Host "  cd build"
        Write-Host "  cmake -DCMAKE_BUILD_TYPE=Release -DLLVM_DIR=\$(llvm-config --cmakedir) .."
        exit 1
    }
    Write-Host ""
}

# Step 2: Check if pass plugin exists
if (-not (Test-Path $PassPlugin)) {
    $PassPlugin = "build/WeightedInstructionAnalysis.so"
    if (-not (Test-Path $PassPlugin)) {
        Write-Error-Custom "Pass plugin not found. Build it first with -BuildFirst flag"
        exit 1
    }
}

Write-Status "Pass plugin: $PassPlugin"
Write-Host ""

# Step 3: Run the pass
Write-Status "Running weighted instruction analysis..."
$AnalysisOutput = Join-Path $OutputDir "${Timestamp}_analysis.txt"

try {
    $output = & opt -load-pass-plugin="$PassPlugin" `
        -passes=weighted-instruction-analysis `
        -disable-output `
        "$LLFile" 2>&1
    
    $output | Out-File -FilePath $AnalysisOutput -Encoding UTF8
    
    Write-Success "Analysis completed"
    Write-Status "Output saved to: $AnalysisOutput"
}
catch {
    Write-Error-Custom "Pass execution failed: $_"
    exit 1
}

Write-Host ""

# Step 4: Generate reports
Write-Status "Generating reports..."
Write-Host ""

switch ($Format) {
    "text" {
        Write-Status "Generating text report..."
        python $Toolkit $AnalysisOutput --text | Out-File -FilePath "$OutputDir/${Timestamp}_report.txt" -Encoding UTF8
        Write-Success "Text report: $OutputDir/${Timestamp}_report.txt"
    }
    "json" {
        Write-Status "Generating JSON report..."
        python $Toolkit $AnalysisOutput --json | Out-File -FilePath "$OutputDir/${Timestamp}_report.json" -Encoding UTF8
        Write-Success "JSON report: $OutputDir/${Timestamp}_report.json"
    }
    "csv" {
        Write-Status "Generating CSV report..."
        python $Toolkit $AnalysisOutput --csv | Out-File -FilePath "$OutputDir/${Timestamp}_report.csv" -Encoding UTF8
        Write-Success "CSV report: $OutputDir/${Timestamp}_report.csv"
    }
    "all" {
        Write-Status "Generating all reports..."
        python $Toolkit $AnalysisOutput --text | Out-File -FilePath "$OutputDir/${Timestamp}_report.txt" -Encoding UTF8
        Write-Success "  ✓ Text report"
        python $Toolkit $AnalysisOutput --json | Out-File -FilePath "$OutputDir/${Timestamp}_report.json" -Encoding UTF8
        Write-Success "  ✓ JSON report"
        python $Toolkit $AnalysisOutput --csv | Out-File -FilePath "$OutputDir/${Timestamp}_report.csv" -Encoding UTF8
        Write-Success "  ✓ CSV report"
    }
    default {
        Write-Error-Custom "Unknown format: $Format"
        exit 1
    }
}

Write-Host ""

# Step 5: Compare if requested
if ($CompareFile) {
    Write-Status "Comparing with baseline: $CompareFile"
    Write-Host ""
    
    if (-not (Test-Path $CompareFile)) {
        Write-Warning "Baseline file not found: $CompareFile"
    }
    else {
        # Extract costs
        $currentCost = (Get-Content $AnalysisOutput | Select-String "Total Weighted Cost: (\d+)" -AllMatches | 
                       ForEach-Object { $_.Matches.Groups[1].Value } | 
                       Measure-Object -Sum | Select-Object -ExpandProperty Sum)
        
        $baselineCost = (Get-Content $CompareFile | Select-String "Total Weighted Cost: (\d+)" -AllMatches | 
                        ForEach-Object { $_.Matches.Groups[1].Value } | 
                        Measure-Object -Sum | Select-Object -ExpandProperty Sum)
        
        if ($currentCost -and $baselineCost) {
            $improvement = [math]::Round(($baselineCost - $currentCost) * 100 / $baselineCost, 2)
            
            Write-Status "Comparison Results:"
            Write-Host "  Baseline Total Cost:  $baselineCost"
            Write-Host "  Current Total Cost:   $currentCost"
            
            if ($improvement -gt 0) {
                Write-Host "  Improvement: +$improvement%" -ForegroundColor Green
            }
            elseif ($improvement -lt 0) {
                Write-Host "  Regression: $improvement%" -ForegroundColor Red
            }
            else {
                Write-Host "  Change: No change"
            }
        }
        else {
            Write-Warning "Could not extract cost data for comparison"
        }
    }
    Write-Host ""
}

# Step 6: Display summary
Write-Status "Analysis Summary"
Write-Status "================="
Write-Host ""
Write-Success "Output directory: $OutputDir"
Write-Host "  Files:"
Write-Host "    - $AnalysisOutput (raw pass output)"
Write-Host "    - ${Timestamp}_report.* (formatted reports)"
Write-Host ""

# Display key statistics if verbose
if ($Verbose) {
    Write-Status "Key Statistics:"
    Write-Host ""
    Get-Content $AnalysisOutput | 
    Select-String "Function:|Total Weighted Cost:|Memory Operations:|Arithmetic Operations:|MEMORY-BOUND|COMPUTE-BOUND" | 
    Select-Object -First 20
    Write-Host ""
}

Write-Success "Analysis workflow completed!"
Write-Status "Next steps:"
Write-Host "  1. Review text report:     Get-Content $OutputDir/${Timestamp}_report.txt"
Write-Host "  2. Parse JSON:             Get-Content $OutputDir/${Timestamp}_report.json | ConvertFrom-Json"
Write-Host "  3. Open CSV in Excel:      ii $OutputDir/${Timestamp}_report.csv"
Write-Host ""
