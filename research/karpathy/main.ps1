# Karpathy Research Machine - Smoke & Honey
# ============================================
# Modeled after github.com/karpathy/autoresearch
#
# Main entry point. Run from the research\karpathy folder:
#   cd research\karpathy
#   .\main.ps1
#
# WHAT THIS DOES:
#   1. Works bottom-up: perfects Phase 1, locks it, moves to Phase 2, etc.
#   2. Each phase loops INDEFINITELY until all tests pass (or Ctrl+C)
#   3. Phase 8 integrates all systems -- fixes go to SOURCE phases
#   4. All experiments tracked in results.tsv
#   5. All file changes backed up in backups/
#
# MODES:
#   .\main.ps1                 Full pipeline (never stops)
#   .\main.ps1 skip            Skip phase validation, straight to integration
#   .\main.ps1 status          Show current test results
#   .\main.ps1 dry             Show AI suggestions without applying

Write-Host ""
Write-Host "============================================" -ForegroundColor Yellow
Write-Host "  KARPATHY RESEARCH MACHINE" -ForegroundColor Yellow
Write-Host "  Smoke & Honey Simulation" -ForegroundColor Yellow
Write-Host "  github.com/karpathy/autoresearch method" -ForegroundColor DarkGray
Write-Host "============================================" -ForegroundColor Yellow
Write-Host ""

# Check Python
$pythonCmd = Get-Command python -ErrorAction SilentlyContinue
if (-not $pythonCmd) {
    Write-Host "ERROR: Python not found in PATH." -ForegroundColor Red
    Write-Host "Install Python 3.8+ and make sure it's on your PATH." -ForegroundColor Yellow
    Write-Host ""
    Read-Host "Press Enter to close..."
    exit 1
}

$mode = if ($args.Count -gt 0) { $args[0] } else { "" }

switch ($mode) {
    "status" {
        Write-Host "Checking current status..." -ForegroundColor Cyan
        Write-Host ""
        python main.py --status
    }
    "skip" {
        Write-Host "Skipping phase validation, straight to integration..." -ForegroundColor Cyan
        Write-Host "NEVER STOPS -- press Ctrl+C to interrupt" -ForegroundColor DarkGray
        Write-Host ""
        python main.py --skip-validate
    }
    "dry" {
        Write-Host "Dry run (AI suggests, nothing applied)..." -ForegroundColor Cyan
        Write-Host ""
        python main.py --dry-run
    }
    default {
        Write-Host "Starting full research pipeline..." -ForegroundColor Green
        Write-Host "  Bottom-up: Phase 1 -> 2 -> ... -> 8" -ForegroundColor DarkGray
        Write-Host "  Each phase loops until all tests pass" -ForegroundColor DarkGray
        Write-Host "  NEVER STOPS -- press Ctrl+C to interrupt" -ForegroundColor DarkGray
        Write-Host ""
        python main.py
    }
}

Write-Host ""
Read-Host "Press Enter to close..."
