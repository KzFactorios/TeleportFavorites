@echo off
REM TeleportFavorites Test Runner
REM Simple batch script to run tests from anywhere

setlocal

REM Get the directory where this script is located
set "SCRIPT_DIR=%~dp0"
set "TESTS_DIR=%SCRIPT_DIR%tests"

echo TeleportFavorites Test Runner
echo Project root: %SCRIPT_DIR%
echo Running tests from: %TESTS_DIR%
echo ============================================================

REM Change to tests directory and run the infrastructure test runner
cd /d "%TESTS_DIR%"
lua infrastructure\run_all_tests.lua

if %ERRORLEVEL% equ 0 (
    echo ============================================================
    echo ✅ Test execution completed successfully!
) else (
    echo ============================================================
    echo ❌ Test execution failed with exit code: %ERRORLEVEL%
    exit /b %ERRORLEVEL%
)
