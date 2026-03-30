# Phase 8: Full Integration - Karpathy Research Machine
# =====================================================
# Run from the phase8_full_integration folder:
#   cd research\karpathy\phase8_full_integration
#   .\run.ps1
#
# This is the command center. The research loop automatically:
#   1. Runs the full simulation (15 integration tests)
#   2. Identifies which earlier phase is causing failures
#   3. Sends full code + science context to Ollama for analysis
#   4. Applies the AI's fix, validates the phase still passes
#   5. Re-runs integration to check improvement
#   6. Loops until all 15 pass or you press Ctrl+C
#
# MODES:
#   .\run.ps1              Start the automated research loop
#   .\run.ps1 status       Show current test results (no changes)
#   .\run.ps1 test         Run full_sim.py directly (raw output)
#   .\run.ps1 dry          Show what AI would suggest (no changes)

Write-Host ""
Write-Host "============================================" -ForegroundColor Yellow
Write-Host "  PHASE 8: KARPATHY RESEARCH MACHINE" -ForegroundColor Yellow
Write-Host "  Smoke & Honey Simulation Tuning" -ForegroundColor Yellow
Write-Host "============================================" -ForegroundColor Yellow
Write-Host ""

# Verify dependencies
$missing = @()
$phases = @(
    "..\phase1_brood_biology\brood_sim.py",
    "..\phase2_population\population_sim.py",
    "..\phase3_foraging_honey\foraging_sim.py",
    "..\phase4_queen_comb\queen_comb_sim.py",
    "..\phase5_disease_pests\disease_sim.py",
    "..\phase6_environment\environment_sim.py",
    "..\phase7_colony_behavior\colony_behavior_sim.py"
)

foreach ($p in $phases) {
    if (-not (Test-Path $p)) { $missing += $p }
}

if ($missing.Count -gt 0) {
    Write-Host "ERROR: Missing phase dependencies!" -ForegroundColor Red
    foreach ($m in $missing) { Write-Host "  Missing: $m" -ForegroundColor Red }
    Write-Host ""
    Read-Host "Press Enter to close..."
    exit 1
}

$mode = if ($args.Count -gt 0) { $args[0] } else { "loop" }

switch ($mode) {
    "status" {
        Write-Host "Checking current test status..." -ForegroundColor Cyan
        python research_loop.py --status
    }
    "test" {
        Write-Host "Running full_sim.py directly..." -ForegroundColor Cyan
        python full_sim.py
    }
    "dry" {
        Write-Host "Dry run (AI suggests, nothing applied)..." -ForegroundColor Cyan
        python research_loop.py --dry-run
    }
    default {
        Write-Host "Starting automated research loop..." -ForegroundColor Green
        Write-Host "Press Ctrl+C to stop at any time." -ForegroundColor DarkGray
        Write-Host ""
        python research_loop.py
    }
}

Write-Host ""
Read-Host "Press Enter to close..."
