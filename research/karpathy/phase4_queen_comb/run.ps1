# Phase 4: Queen & Comb Mechanics - Karpathy Research Runner
# Run this from the phase4_queen_comb folder:
#   cd research\karpathy\phase4_queen_comb
#   .\run.ps1
#
# STANDALONE: No imports from other phases (pure math validation)

Write-Host ""
Write-Host "============================================" -ForegroundColor Yellow
Write-Host "  PHASE 4: QUEEN & COMB MECHANICS" -ForegroundColor Yellow
Write-Host "  Karpathy Incremental Research Machine" -ForegroundColor Yellow
Write-Host "  Standalone (no phase imports)" -ForegroundColor DarkGray
Write-Host "============================================" -ForegroundColor Yellow
Write-Host ""

python queen_comb_sim.py

Write-Host ""
if ($LASTEXITCODE -eq 0) {
    Write-Host ">>> ALL PHASE 4 TESTS PASSED <<<" -ForegroundColor Green
    Write-Host ""
    Write-Host "NEXT STEP: Move on to Phase 5." -ForegroundColor Cyan
    Write-Host "  cd ..\phase5_disease_pests" -ForegroundColor White
    Write-Host "  .\run.ps1" -ForegroundColor White
} else {
    Write-Host ">>> PHASE 4 HAS FAILURES <<<" -ForegroundColor Red
    Write-Host ""
    Write-Host "Fix issues in queen_comb_sim.py, then re-run: .\run.ps1" -ForegroundColor Yellow
}
Write-Host ""
Read-Host "Press Enter to close..."
