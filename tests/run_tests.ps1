# Convenient test runner for Windows PowerShell
# Simply forwards to the infrastructure directory

Write-Host "Running TeleportFavorites Test Suite..." -ForegroundColor Green
Set-Location "infrastructure"
lua run_all_tests.lua
Set-Location ".."
