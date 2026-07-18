@echo off
setlocal EnableDelayedExpansion

REM ============================================================
REM Flutter Analyze Script for Codex / AI Agent
REM ============================================================

REM Move to project root: scripts\analyze_codex.bat -> project root
set "SCRIPT_DIR=%~dp0"
set "PROJECT_ROOT=%SCRIPT_DIR%.."
cd /d "%PROJECT_ROOT%"

set "LOG_DIR=audit"
set "LOG_FILE=%LOG_DIR%\flutter_analyze.txt"

if not exist "%LOG_DIR%" mkdir "%LOG_DIR%"

REM Generate metadata
for /f "delims=" %%i in ('powershell -NoProfile -Command "[guid]::NewGuid().ToString()"') do set "RUN_ID=%%i"
for /f "delims=" %%i in ('powershell -NoProfile -Command "Get-Date -Format 'yyyy-MM-dd HH:mm:ss'"') do set "START_TIME=%%i"
for /f "delims=" %%i in ('powershell -NoProfile -Command "[DateTimeOffset]::Now.ToUnixTimeMilliseconds()"') do set "START_MS=%%i"

REM Git metadata
set "GIT_BRANCH=N/A"
set "GIT_COMMIT=N/A"

where git >nul 2>&1
if %ERRORLEVEL%==0 (
    for /f "delims=" %%i in ('git rev-parse --abbrev-ref HEAD 2^>nul') do set "GIT_BRANCH=%%i"
    for /f "delims=" %%i in ('git rev-parse --short HEAD 2^>nul') do set "GIT_COMMIT=%%i"
)

REM Header
(
echo ============================================================
echo Flutter Analyze Report
echo ============================================================
echo Run ID       : %RUN_ID%
echo Generated At : %START_TIME%
echo Computer     : %COMPUTERNAME%
echo User         : %USERNAME%
echo Working Dir  : %CD%
echo Git Branch   : %GIT_BRANCH%
echo Git Commit   : %GIT_COMMIT%
echo Log File     : %LOG_FILE%
echo Command      : flutter analyze --no-pub
echo ------------------------------------------------------------
echo.
echo Flutter SDK:
call flutter --version
echo.
echo Dart SDK:
call dart --version
echo.
echo ------------------------------------------------------------
echo Project Check:
) > "%LOG_FILE%" 2>&1

if not exist "pubspec.yaml" (
    (
    echo pubspec.yaml : NOT FOUND
    echo.
    echo ERROR: This script must run from a Flutter project root.
    echo Current directory: %CD%
    echo.
    echo Status      : FAILED
    echo Exit Code   : 100
    echo ============================================================
    ) >> "%LOG_FILE%" 2>&1

    type "%LOG_FILE%"
    exit /b 100
) else (
    echo pubspec.yaml : FOUND >> "%LOG_FILE%"
)

where flutter >nul 2>&1
if not %ERRORLEVEL%==0 (
    (
    echo flutter      : NOT FOUND IN PATH
    echo.
    echo ERROR: Flutter command is not available in PATH.
    echo.
    echo Status      : FAILED
    echo Exit Code   : 101
    echo ============================================================
    ) >> "%LOG_FILE%" 2>&1

    type "%LOG_FILE%"
    exit /b 101
) else (
    echo flutter      : FOUND >> "%LOG_FILE%"
)

(
echo.
echo ============================================================
echo BEGIN FLUTTER ANALYZE
echo ============================================================
echo.
) >> "%LOG_FILE%"

REM Run analyzer
call flutter analyze --no-pub >> "%LOG_FILE%" 2>&1
set "ANALYZE_EXIT_CODE=%ERRORLEVEL%"

REM Finish metadata
for /f "delims=" %%i in ('powershell -NoProfile -Command "Get-Date -Format 'yyyy-MM-dd HH:mm:ss'"') do set "FINISH_TIME=%%i"
for /f "delims=" %%i in ('powershell -NoProfile -Command "[DateTimeOffset]::Now.ToUnixTimeMilliseconds()"') do set "FINISH_MS=%%i"
for /f "delims=" %%i in ('powershell -NoProfile -Command "[math]::Round((%FINISH_MS% - %START_MS%) / 1000, 2)"') do set "DURATION=%%i"

REM Count only analyzer diagnostic rows, regardless of leading indentation.
for /f "delims=" %%i in ('powershell -NoProfile -Command "$text = Get-Content '%LOG_FILE%' -Raw; ([regex]::Matches($text, '(?m)^\s*error\s+-')).Count"') do set "ERROR_COUNT=%%i"
for /f "delims=" %%i in ('powershell -NoProfile -Command "$text = Get-Content '%LOG_FILE%' -Raw; ([regex]::Matches($text, '(?m)^\s*warning\s+-')).Count"') do set "WARNING_COUNT=%%i"
for /f "delims=" %%i in ('powershell -NoProfile -Command "$text = Get-Content '%LOG_FILE%' -Raw; ([regex]::Matches($text, '(?m)^\s*info\s+-')).Count"') do set "INFO_COUNT=%%i"

set "STATUS=FAILED"
if "%ANALYZE_EXIT_CODE%"=="0" set "STATUS=SUCCESS"

(
echo.
echo ============================================================
echo END FLUTTER ANALYZE
echo ============================================================
echo Finished At : %FINISH_TIME%
echo Duration    : %DURATION%s
echo Exit Code   : %ANALYZE_EXIT_CODE%
echo Status      : %STATUS%
echo ------------------------------------------------------------
echo Analyzer Summary:
echo Errors      : %ERROR_COUNT%
echo Warnings    : %WARNING_COUNT%
echo Infos       : %INFO_COUNT%
echo ============================================================
) >> "%LOG_FILE%"

type "%LOG_FILE%"

exit /b %ANALYZE_EXIT_CODE%
