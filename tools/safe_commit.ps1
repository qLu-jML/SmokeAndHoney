# safe_commit.ps1 -- Close Godot, git commit, reopen Godot.
# Usage:  powershell -ExecutionPolicy Bypass -File tools\safe_commit.ps1 "commit message"
# Run from the project root (where project.godot lives).

param(
    [string]$CommitMessage = ""
)

$ProjectDir = Split-Path -Parent $PSScriptRoot
Push-Location $ProjectDir

if ([string]::IsNullOrWhiteSpace($CommitMessage)) {
    $CommitMessage = "Auto-commit at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host " Safe Commit - Smoke and Honey" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# -- Step 1: Find and remember the Godot executable path, then close it --
Write-Host "[1/4] Closing Godot editor..." -ForegroundColor Yellow
$godotProcs = Get-Process -Name "Godot*" -ErrorAction SilentlyContinue
$godotPath = $null

if ($godotProcs) {
    # Remember the executable path so we can relaunch it
    foreach ($proc in $godotProcs) {
        try {
            $p = $proc.MainModule.FileName
            if ($p -and (Test-Path $p)) {
                $godotPath = $p
                break
            }
        } catch {}
    }

    # Kill all Godot processes
    $godotProcs | Stop-Process -Force -ErrorAction SilentlyContinue
    Write-Host "      Godot closed. (was: $godotPath)" -ForegroundColor Green

    # Wait for file handles to release
    Start-Sleep -Seconds 2
} else {
    Write-Host "      Godot not running." -ForegroundColor DarkGray
}

# -- Step 2: Clean lock files --
Write-Host "[2/4] Cleaning lock files..." -ForegroundColor Yellow
$cleaned = $false
foreach ($lockFile in @(".git\HEAD.lock", ".git\index.lock")) {
    if (Test-Path $lockFile) {
        Remove-Item $lockFile -Force -ErrorAction SilentlyContinue
        Write-Host "      Removed $lockFile" -ForegroundColor Green
        $cleaned = $true
    }
}
if (-not $cleaned) {
    Write-Host "      No lock files found." -ForegroundColor DarkGray
}

# -- Step 3: Git commit --
Write-Host "[3/4] Committing..." -ForegroundColor Yellow
Write-Host "      Message: $CommitMessage" -ForegroundColor White
git add -A
$result = git commit -m $CommitMessage 2>&1
$exitCode = $LASTEXITCODE
if ($exitCode -eq 0) {
    Write-Host "      Commit successful." -ForegroundColor Green
} else {
    Write-Host "      Commit result (exit $exitCode):" -ForegroundColor Red
    Write-Host "      $result" -ForegroundColor DarkGray
}

# -- Step 4: Reopen Godot --
Write-Host "[4/4] Reopening Godot editor..." -ForegroundColor Yellow

if ($godotPath -and (Test-Path $godotPath)) {
    Start-Process $godotPath -ArgumentList "--editor", "--path", "`"$ProjectDir`""
    Write-Host "      Godot reopened." -ForegroundColor Green
} else {
    # Search common locations
    $searchPaths = @(
        (Get-Command "Godot.exe" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source),
        (Get-Command "Godot_v4*" -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty Source),
        "$env:USERPROFILE\scoop\apps\godot\current\Godot.exe",
        "C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\Godot_v4.4-stable_win64.exe",
        "$env:LOCALAPPDATA\Godot\Godot.exe"
    )
    $found = $false
    foreach ($sp in $searchPaths) {
        if ($sp -and (Test-Path $sp)) {
            Start-Process $sp -ArgumentList "--editor", "--path", "`"$ProjectDir`""
            Write-Host "      Godot reopened from: $sp" -ForegroundColor Green
            $found = $true
            break
        }
    }
    if (-not $found) {
        Write-Host "      [!] Could not find Godot. Please reopen manually." -ForegroundColor Red
        Write-Host "      Tip: Set GODOT_PATH env var or add Godot to PATH." -ForegroundColor DarkGray
    }
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host " Done!" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

Pop-Location
