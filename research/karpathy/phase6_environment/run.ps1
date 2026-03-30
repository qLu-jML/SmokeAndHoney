# Phase 6: Environmental Systems - Karpathy Research Runner
# Run this from the phase6_environment folder:
#   cd research\karpathy\phase6_environment
#   .\run.ps1
#
# STANDALONE: No imports from other phases

Write-Host ""
Write-Host "============================================" -ForegroundColor Yellow
Write-Host "  PHASE 6: ENVIRONMENTAL SYSTEMS" -ForegroundColor Yellow
Write-Host "  Karpathy Incremental Research Machine" -ForegroundColor Yellow
Write-Host "  Standalone (no phase imports)" -ForegroundColor DarkGray
Write-Host "============================================" -ForegroundColor Yellow
Write-Host ""

python environment_sim.py

Write-Host ""
if ($LASTEXITCODE -eq 0) {
    Write-Host ">>> ALL PHASE 6 TESTS PASSED <<<" -ForegroundColor Green
    Write-Host ""
    Write-Host "NEXT STEP: Move on to Phase 7." -ForegroundColor Cyan
    Write-Host "  cd ..\phase7_colony_behavior" -ForegroundColor White
    Write-Host "  .\run.ps1" -ForegroundColor White
} else {
    Write-Host ">>> PHASE 6 HAS FAILURES <<<" -ForegroundColor Red
    Write-Host ""
    Write-Host "This phase validates Iowa-specific environmental data." -ForegroundColor Yellow
    Write-Host "Check bloom windows, weather probabilities, and" -ForegroundColor Yellow
    Write-Host "season ranking math." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Fix issues in environment_sim.py, then re-run: .\run.ps1" -ForegroundColor Yellow
}
Write-Host ""
Read-Host "Press Enter to close..."
