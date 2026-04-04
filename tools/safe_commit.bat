@echo off
REM safe_commit.bat -- Close Godot, git commit, reopen Godot.
REM Usage:  safe_commit.bat "commit message here"
REM Called from the project root (where project.godot lives).
REM
REM Steps:
REM   1. Kill any running Godot editor process
REM   2. Wait for lock files to clear
REM   3. Stage and commit all tracked changes
REM   4. Reopen Godot editor on this project
REM
REM If no commit message is provided, it will use a default timestamp message.

setlocal enabledelayedexpansion

REM -- Locate project root (directory this script lives in is tools/, go up one) --
set "PROJECT_DIR=%~dp0.."
pushd "%PROJECT_DIR%"
set "PROJECT_DIR=%CD%"

REM -- Parse commit message --
if "%~1"=="" (
    for /f "tokens=*" %%a in ('powershell -command "Get-Date -Format \"yyyy-MM-dd HH:mm:ss\""') do set "TIMESTAMP=%%a"
    set "COMMIT_MSG=Auto-commit at !TIMESTAMP!"
) else (
    set "COMMIT_MSG=%~1"
)

echo ============================================
echo  Safe Commit - Smoke and Honey
echo ============================================
echo.

REM -- Step 1: Close Godot --
echo [1/4] Closing Godot editor...
tasklist /FI "IMAGENAME eq Godot*" 2>NUL | find /I "Godot" >NUL
if %ERRORLEVEL% EQU 0 (
    REM Try graceful close first, then force kill
    taskkill /IM "Godot_v4.4-stable_win64.exe" /T 2>NUL
    taskkill /IM "Godot_v4.4-stable_win64_console.exe" /T 2>NUL
    taskkill /IM "Godot.exe" /T 2>NUL
    REM Catch any other Godot variant
    for /f "tokens=2" %%p in ('tasklist /FI "IMAGENAME eq Godot*" /NH 2^>NUL') do (
        taskkill /PID %%p /T 2>NUL
    )
    echo      Godot processes terminated.
    REM Wait a moment for file handles to release
    timeout /t 2 /nobreak >NUL
) else (
    echo      Godot not running.
)

REM -- Step 2: Clean up stale lock files --
echo [2/4] Cleaning lock files...
if exist ".git\HEAD.lock" (
    del /f ".git\HEAD.lock" 2>NUL
    echo      Removed HEAD.lock
)
if exist ".git\index.lock" (
    del /f ".git\index.lock" 2>NUL
    echo      Removed index.lock
)
echo      Lock files cleared.

REM -- Step 3: Git add and commit --
echo [3/4] Committing: %COMMIT_MSG%
git add -A
git commit -m "%COMMIT_MSG%"
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo      [!] Commit failed or nothing to commit.
) else (
    echo      Commit successful.
)

REM -- Step 4: Reopen Godot --
echo [4/4] Reopening Godot editor...
REM Try common Godot executable names. The "start" command runs it detached.
REM Check for Godot on PATH first, then common install locations.
where Godot_v4.4-stable_win64.exe >NUL 2>NUL
if %ERRORLEVEL% EQU 0 (
    start "" Godot_v4.4-stable_win64.exe --editor --path "%PROJECT_DIR%"
    goto :done
)
where Godot.exe >NUL 2>NUL
if %ERRORLEVEL% EQU 0 (
    start "" Godot.exe --editor --path "%PROJECT_DIR%"
    goto :done
)
REM Check Scoop install location
if exist "%USERPROFILE%\scoop\apps\godot\current\Godot.exe" (
    start "" "%USERPROFILE%\scoop\apps\godot\current\Godot.exe" --editor --path "%PROJECT_DIR%"
    goto :done
)
REM Check Steam common location
if exist "C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\Godot_v4.4-stable_win64.exe" (
    start "" "C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\Godot_v4.4-stable_win64.exe" --editor --path "%PROJECT_DIR%"
    goto :done
)
echo      [!] Could not find Godot executable. Please reopen manually.
echo      Tip: Add Godot to your PATH or set GODOT_PATH environment variable.

:done
echo.
echo ============================================
echo  Done!
echo ============================================
popd
endlocal
