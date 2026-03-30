# Phase 5: Disease & Pests - Karpathy Research Runner
# Run this from the phase5_disease_pests folder:
#   cd research\karpathy\phase5_disease_pests
#   .\run.ps1
#
# STANDALONE: No imports from other phases

Write-Host ""
Write-Host "============================================" -ForegroundColor Yellow
Write-Host "  PHASE 5: DISEASE & PEST DYNAMICS" -ForegroundColor Yellow
Write-Host "  Karpathy Incremental Research Machine" -ForegroundColor Yellow
Write-Host "  Standalone (no phase imports)" -ForegroundColor DarkGray
Write-Host "============================================" -ForegroundColor Yellow
Write-Host ""

python disease_sim.py

Write-Host ""
if ($LASTEXITCODE -eq 0) {
    Write-Host ">>> ALL PHASE 5 TESTS PASSED <<<" -ForegroundColor Green
    Write-Host ""
    Write-Host "NEXT STEP: Move on to Phase 6." -ForegroundColor Cyan
    Write-Host "  cd ..\phase6_environment" -ForegroundColor White
    Write-Host "  .\run.ps1" -ForegroundColor White
} else {
    Write-Host ">>> PHASE 5 HAS FAILURES <<<" -ForegroundColor Red
    Write-Host ""
    Write-Host "Key targets:" -ForegroundColor Yellow
    Write-Host "  - Varroa doubling: 40-70 days" -ForegroundColor DarkGray
    Write-Host "  - Treatment must reduce mites by stated %" -ForegroundColor DarkGray
    Write-Host "  - AFB spread: 1.2% per neighbor per tick" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "Fix issues in disease_sim.py, then re-run: .\run.ps1" -ForegroundColor Yellow
}
Write-Host ""
Read-Host "Press Enter to close..."
