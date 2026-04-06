#!/usr/bin/env pwsh
# PowerShell pre-commit hook for Windows
try {
  $root = git rev-parse --show-toplevel 2>$null
  if (-not $?) { $root = Get-Location }
  Set-Location $root
  Write-Host 'Running require lint (PowerShell)...'
  $p = Start-Process -FilePath 'lua' -ArgumentList '.scripts/require_lint.lua','--fix','.' -NoNewWindow -Wait -PassThru
  if ($p.ExitCode -ne 0) {
    Write-Error "Pre-commit: require lint failed (rc=$($p.ExitCode)). Commit aborted."
    exit 1
  }
  Write-Host 'Pre-commit: require lint passed. Proceeding with commit.'
  exit 0
} catch {
  Write-Error $_.Exception.Message
  exit 2
}
