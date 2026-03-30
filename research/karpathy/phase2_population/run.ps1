# Phase 2: Population Dynamics - Karpathy Research Runner
# Run this from the phase2_population folder:
#   cd research\karpathy\phase2_population
#   .\run.ps1
#
# REQUIRES: Phase 1 passing (imports brood_sim.py)

Write-Host ""
Write-Host "============================================" -ForegroundColor Yellow
Write-Host "  PHASE 2: POPULATION DYNAMICS" -ForegroundColor Yellow
Write-Host "  Karpathy Incremental Research Machine" -ForegroundColor Yellow
Write-Host "  Requires: Phase 1 (Brood Biology)" -ForegroundColor DarkGray
Write-Host "============================================" -ForegroundColor Yellow
Write-Host ""

# Verify Phase 1 exists
if (-not (Test-Path "..\phase1_brood_biology\brood_sim.py")) {
    Write-Host "ERROR: Phase 1 (brood_sim.py) not found!" -ForegroundColor Red
    Write-Host "Phase 2 imports from Phase 1. Make sure phase1_brood_biology exists." -ForegroundColor Red
    exit 1
}

python population_sim.py

Write-Host ""
if ($LASTEXITCODE -eq 0) {
    Write-Host ">>> ALL PHASE 2 TESTS PASSED <<<" -ForegroundColor Green
    Write-Host ""
    Write-Host "NEXT STEP: Move on to Phase 3." -ForegroundColor Cyan
    Write-Host "  cd ..\phase3_foraging_honey" -ForegroundColor White
    Write-Host "  .\run.ps1" -ForegroundColor White
} else {
    Write-Host ">>> PHASE 2 HAS FAILURES <<<" -ForegroundColor Red
    Write-Host ""
    Write-Host "Check the output above. Common issues:" -ForegroundColor Yellow
    Write-Host "  - Peak month detection is lenient (Full-Earth counts as summer)" -ForegroundColor DarkGray
    Write-Host "  - Population targets: 40k-65k summer, 8k-28k winter" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "Fix issues in population_sim.py, then re-run: .\run.ps1" -ForegroundColor Yellow
}
Write-Host ""
Read-Host "Press Enter to close..."
