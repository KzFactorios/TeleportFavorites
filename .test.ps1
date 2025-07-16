# TeleportFavorites Test Runner
# Simple PowerShell script to run tests from anywhere
# Usage: .\.test.ps1 [test_file1] [test_file2] ...
# Examples:
#   .\.test.ps1                              # Run all tests
#   .\.test.ps1 drag_drop_utils_spec         # Run specific test
#   .\.test.ps1 cache_spec gui_base_spec     # Run multiple specific tests

param(
    [Parameter(ValueFromRemainingArguments=$true)]
    [string[]]$TestFiles
)

$ErrorActionPreference = "Stop"

# Get the directory where this script is located
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$TestsDir = Join-Path $ScriptDir "tests"

Write-Host "TeleportFavorites Test Runner" -ForegroundColor Cyan
Write-Host "Project root: $ScriptDir" -ForegroundColor Gray
Write-Host "Running tests from: $TestsDir" -ForegroundColor Gray

if ($TestFiles -and $TestFiles.Count -gt 0) {
    Write-Host "Specified test files: $($TestFiles -join ', ')" -ForegroundColor Yellow
} else {
    Write-Host "Running all tests" -ForegroundColor Yellow
}

Write-Host ("=" * 60) -ForegroundColor Gray

# Change to tests directory and run the infrastructure test runner
Push-Location $TestsDir
try {
    if ($TestFiles -and $TestFiles.Count -gt 0) {
        $quotedFiles = $TestFiles | ForEach-Object { "`"$_`"" }
        $argsString = $quotedFiles -join " "
        Invoke-Expression "lua infrastructure\run_all_tests.lua $argsString"
    } else {
        & lua "infrastructure\run_all_tests.lua"
    }
    
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
