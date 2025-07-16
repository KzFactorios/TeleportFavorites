# Convenient test runner for Windows PowerShell
# Simply forwards to the infrastructure directory
# Usage: .\run_tests.ps1 [test_file1] [test_file2] ...
# Examples:
#   .\run_tests.ps1                          # Run all tests
#   .\run_tests.ps1 drag_drop_utils_spec     # Run specific test
#   .\run_tests.ps1 cache_spec gui_base_spec # Run multiple specific tests

param(
    [Parameter(ValueFromRemainingArguments=$true)]
    [string[]]$TestFiles
)

Write-Host "Running TeleportFavorites Test Suite..." -ForegroundColor Green

if ($TestFiles -and $TestFiles.Count -gt 0) {
    Write-Host "Specified test files: $($TestFiles -join ', ')" -ForegroundColor Cyan
    $quotedFiles = $TestFiles | ForEach-Object { "`"$_`"" }
    $argsString = $quotedFiles -join " "
    Set-Location "infrastructure"
    Invoke-Expression "lua run_all_tests.lua $argsString"
    Set-Location ".."
} else {
    Write-Host "Running all tests" -ForegroundColor Cyan
    Set-Location "infrastructure"
    lua run_all_tests.lua
    Set-Location ".."
}
