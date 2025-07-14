# TeleportFavorites Test Runner
# Simple PowerShell script to run tests from anywhere

$ErrorActionPreference = "Stop"

# Get the directory where this script is located
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$TestsDir = Join-Path $ScriptDir "tests"

Write-Host "TeleportFavorites Test Runner" -ForegroundColor Cyan
Write-Host "Project root: $ScriptDir" -ForegroundColor Gray
Write-Host "Running tests from: $TestsDir" -ForegroundColor Gray
Write-Host ("=" * 60) -ForegroundColor Gray

# Change to tests directory and run the infrastructure test runner
Push-Location $TestsDir
try {
    & lua "infrastructure\run_all_tests.lua"
    if ($LASTEXITCODE -eq 0) {
        Write-Host ("=" * 60) -ForegroundColor Gray
        Write-Host "✅ Test execution completed successfully!" -ForegroundColor Green
    } else {
        Write-Host ("=" * 60) -ForegroundColor Gray
        Write-Host "❌ Test execution failed with exit code: $LASTEXITCODE" -ForegroundColor Red
        exit $LASTEXITCODE
    }
} finally {
    Pop-Location
}
