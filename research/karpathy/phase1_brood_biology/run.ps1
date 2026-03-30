# Phase 1: Brood Biology - Karpathy Research Runner
# Run this from the phase1_brood_biology folder:
#   cd research\karpathy\phase1_brood_biology
#   .\run.ps1
#
# No dependencies on other phases -- this is the foundation.

Write-Host ""
Write-Host "============================================" -ForegroundColor Yellow
Write-Host "  PHASE 1: BROOD BIOLOGY" -ForegroundColor Yellow
Write-Host "  Karpathy Incremental Research Machine" -ForegroundColor Yellow
Write-Host "============================================" -ForegroundColor Yellow
Write-Host ""

python brood_sim.py

Write-Host ""
if ($LASTEXITCODE -eq 0) {
    Write-Host ">>> ALL PHASE 1 TESTS PASSED <<<" -ForegroundColor Green
    Write-Host ""
    Write-Host "NEXT STEP: You are ready to move on to Phase 2." -ForegroundColor Cyan
    Write-Host "  cd ..\phase2_population" -ForegroundColor White
    Write-Host "  .\run.ps1" -ForegroundColor White
} else {
    Write-Host ">>> PHASE 1 HAS FAILURES <<<" -ForegroundColor Red
    Write-Host ""
    Write-Host "DO NOT advance to Phase 2 until all tests pass." -ForegroundColor Red
    Write-Host "Fix the failing tests in brood_sim.py, then re-run:" -ForegroundColor Yellow
    Write-Host "  .\run.ps1" -ForegroundColor White
}
Write-Host ""
Read-Host "Press Enter to close..."
