# Phase 7: Colony Behavior - Karpathy Research Runner
# Run this from the phase7_colony_behavior folder:
#   cd research\karpathy\phase7_colony_behavior
#   .\run.ps1
#
# STANDALONE: No imports from other phases

Write-Host ""
Write-Host "============================================" -ForegroundColor Yellow
Write-Host "  PHASE 7: COLONY BEHAVIOR & HEALTH" -ForegroundColor Yellow
Write-Host "  Karpathy Incremental Research Machine" -ForegroundColor Yellow
Write-Host "  Standalone (no phase imports)" -ForegroundColor DarkGray
Write-Host "============================================" -ForegroundColor Yellow
Write-Host ""

python colony_behavior_sim.py

Write-Host ""
if ($LASTEXITCODE -eq 0) {
    Write-Host ">>> ALL PHASE 7 TESTS PASSED <<<" -ForegroundColor Green
    Write-Host ""
    Write-Host "NEXT STEP: Move on to Phase 8 (Full Integration)." -ForegroundColor Cyan
    Write-Host "  cd ..\phase8_full_integration" -ForegroundColor White
    Write-Host "  .\run.ps1" -ForegroundColor White
} else {
    Write-Host ">>> PHASE 7 HAS FAILURES <<<" -ForegroundColor Red
    Write-Host ""
    Write-Host "Key targets:" -ForegroundColor Yellow
    Write-Host "  - Health weights must sum to 1.0" -ForegroundColor DarkGray
    Write-Host "  - Health score always 0-100" -ForegroundColor DarkGray
    Write-Host "  - Congestion thresholds: honey=0.62, brood=0.65" -ForegroundColor DarkGray
    Write-Host "  - Swarm impulse needs 7+ congested ticks" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "Fix issues in colony_behavior_sim.py, then re-run: .\run.ps1" -ForegroundColor Yellow
}
Write-Host ""
Read-Host "Press Enter to close..."
