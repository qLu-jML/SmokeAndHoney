# Phase 3: Foraging & Honey Economy - Karpathy Research Runner
# Run this from the phase3_foraging_honey folder:
#   cd research\karpathy\phase3_foraging_honey
#   .\run.ps1
#
# REQUIRES: Phase 1 + Phase 2 passing

Write-Host ""
Write-Host "============================================" -ForegroundColor Yellow
Write-Host "  PHASE 3: FORAGING & HONEY ECONOMY" -ForegroundColor Yellow
Write-Host "  Karpathy Incremental Research Machine" -ForegroundColor Yellow
Write-Host "  Requires: Phases 1-2" -ForegroundColor DarkGray
Write-Host "============================================" -ForegroundColor Yellow
Write-Host ""

if (-not (Test-Path "..\phase1_brood_biology\brood_sim.py")) {
    Write-Host "ERROR: Phase 1 not found!" -ForegroundColor Red; exit 1
}
if (-not (Test-Path "..\phase2_population\population_sim.py")) {
    Write-Host "ERROR: Phase 2 not found!" -ForegroundColor Red; exit 1
}

python foraging_sim.py

Write-Host ""
if ($LASTEXITCODE -eq 0) {
    Write-Host ">>> ALL PHASE 3 TESTS PASSED <<<" -ForegroundColor Green
    Write-Host ""
    Write-Host "NEXT STEP: Move on to Phase 4." -ForegroundColor Cyan
    Write-Host "  cd ..\phase4_queen_comb" -ForegroundColor White
    Write-Host "  .\run.ps1" -ForegroundColor White
} else {
    Write-Host ">>> PHASE 3 HAS FAILURES <<<" -ForegroundColor Red
    Write-Host ""
    Write-Host "Check the output above. Key targets:" -ForegroundColor Yellow
    Write-Host "  - Annual production: 150-450 lbs" -ForegroundColor DarkGray
    Write-Host "  - Harvestable honey: 40-120 lbs" -ForegroundColor DarkGray
    Write-Host "  - Winter consumption: 20-45 lbs" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "The winter consumption test may need tuning --" -ForegroundColor Yellow
    Write-Host "this is a known calibration area between the" -ForegroundColor Yellow
    Write-Host "simplified forage mock and the real flower system." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Fix issues in foraging_sim.py, then re-run: .\run.ps1" -ForegroundColor Yellow
}
Write-Host ""
Read-Host "Press Enter to close..."
