# TeleportFavorites Deployment & Release Automation Plan

_Last updated: July 23, 2025_

## Overview
This document describes the step-by-step workflow for deploying and releasing the TeleportFavorites Factorio mod, including automation scripts, changelog management, version bumping, Lua code preparation, and GitHub integration. All steps are designed for Windows/PowerShell environments and follow strict project coding standards.

---

## 1. Prerequisites
- Windows OS with PowerShell v5.1+
- Git installed and configured
- Access to the mod repository on GitHub
- All production code and assets in correct directories (see architecture docs)
- Changelog file: `changelog.txt` in root
- Version file: `info.json` in root

---

## 2. Pre-Deployment Checklist
- [ ] All code changes are committed and pushed to the main branch
- [ ] All tests pass (`.test.ps1`)
- [ ] Changelog is up to date
- [ ] No test files or debug artifacts in root directory
- [ ] Lint and static analysis completed

---

## 3. Automated Deployment Workflow

### Step 1: Version Bumping
- Update the `version` field in `info.json` to the new release version.
- Use PowerShell to automate JSON editing:
  ```powershell
  $json = Get-Content 'info.json' | ConvertFrom-Json
  $json.version = 'NEW_VERSION'
  $json | ConvertTo-Json -Depth 10 | Set-Content 'info.json'
  ```

### Step 2: Changelog Prepending
- Prepend the new release notes to `changelog.txt`.
- Use PowerShell to insert at the top:
  ```powershell
  $newEntry = "Version NEW_VERSION - $(Get-Date -Format 'yyyy-MM-dd')`r`n- ...release notes...`r`n"
  $oldContent = Get-Content 'changelog.txt'
  Set-Content 'changelog.txt' ($newEntry + ($oldContent -join "`r`n"))
  ```

### Step 3: Lua Comment Stripping
- Remove all comments from Lua files before packaging (except for license headers).
- Use PowerShell or a Python script to process all `.lua` files in production directories:
  ```powershell
  Get-ChildItem -Recurse -Filter *.lua | ForEach-Object {
    $content = Get-Content $_.FullName | Where-Object { $_ -notmatch '^\s*--' }
    Set-Content $_.FullName $content
  }
  ```
  _Note: Always keep a backup before stripping comments._

### Step 4: Packaging
- Zip the mod directory, excluding test files and debug artifacts.
- Example PowerShell command:
  ```powershell
  Compress-Archive -Path .\* -DestinationPath ..\TeleportFavorites_vNEW_VERSION.zip -Force
  ```

### Step 5: GitHub Release
- Create a new release on GitHub with the updated changelog and zip file.
- Use GitHub web UI or `gh` CLI:
  ```powershell
  gh release create vNEW_VERSION ..\TeleportFavorites_vNEW_VERSION.zip --notes "$(Get-Content changelog.txt -First 20)"
  ```

---

## 4. Post-Deployment Checklist
- [ ] Verify release appears on GitHub and Factorio mod portal
- [ ] Test download and install of the new mod zip
- [ ] Update documentation if needed
- [ ] Announce release (Discord, forums, etc.)

---

## 5. Troubleshooting & Notes
- Always run `.test.ps1` before packaging
- Use backups before comment stripping
- For PowerShell errors, check path conventions and script permissions
- For GitHub CLI issues, ensure authentication is set up

---

## References
- `.project/architecture.md` — System design
- `.project/coding_standards.md` — Coding rules
- `.github/workflows/` — CI/CD automation (if present)
- [Factorio Mod Portal](https://mods.factorio.com/)
- [GitHub CLI Docs](https://cli.github.com/manual/)

---


---

## 6. Development Settings & Flags Exclusion

To ensure that no "development" settings, flags, or constants are present in production deployments, follow this sub-plan:

### Step 1: Identification
- Maintain a list of all development-only flags, settings, and constants (e.g., `DEV_MODE`, `DEBUG`, `ENABLE_TEST_FEATURES`, etc.) in `.project/coding_standards.md` or a dedicated config file.
- Use PowerShell or Python scripts to search for these identifiers in all Lua and config files:
  ```powershell
  Get-ChildItem -Recurse -Filter *.lua | Select-String -Pattern 'DEV_MODE|DEBUG|ENABLE_TEST_FEATURES'
  ```

### Step 2: Automated Removal/Exclusion
- For each flagged item, either:
  - Remove the code block entirely if not needed in production
  - Use conditional compilation or packaging scripts to exclude development code
- Example PowerShell snippet to comment out or remove dev blocks:
  ```powershell
  # Remove lines containing DEV_MODE
  Get-ChildItem -Recurse -Filter *.lua | ForEach-Object {
    $content = Get-Content $_.FullName | Where-Object { $_ -notmatch 'DEV_MODE' }
    Set-Content $_.FullName $content
  }
  ```

### Step 3: Validation
- After packaging, run a final scan to ensure no development flags/settings remain:
  ```powershell
  Get-ChildItem -Recurse -Filter *.lua | Select-String -Pattern 'DEV_MODE|DEBUG|ENABLE_TEST_FEATURES'
  ```
- If any matches are found, abort deployment and resolve before proceeding.

### Step 4: Documentation & Review
- Document all development-only flags/settings in `.project/coding_standards.md`.
- Review this exclusion process before each release.

### Step 5: CI/CD Integration (Optional)
- Add automated checks to CI/CD workflows to block releases containing development flags/settings.

---

_This plan should be updated as automation scripts and workflows evolve._
