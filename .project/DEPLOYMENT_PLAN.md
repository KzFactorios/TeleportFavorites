---

## Changelog.txt Integration & Best Practices

All releases must include a properly formatted `changelog.txt` in the root of the `.dist` directory, following strict Factorio mod guidelines:

- **File Naming & Location:**
  - Must be named `changelog.txt` and placed in the root of the release folder.
  - Encode in UTF-8.

- **Version Section Formatting:**
  - Each version section starts with a header line of exactly 99 dashes (no spaces).
  - Immediately followed by a `Version: X.Y.Z` line (no indentation).
  - Optionally, a `Date: YYYY-MM-DD` line (no indentation).

- **Categories & Entries:**
  - Categories are indented with 2 spaces and end with a colon (e.g., `  Features:`).
  - Entries under categories are indented with 4 spaces, start with `- `, and continuation lines use 6 spaces.
  - No tabs or trailing whitespace anywhere.

- **Empty Lines:**
  - Only completely empty lines are allowed (no spaces/tabs).

- **Version Uniqueness:**
  - No duplicate version sections; `0.0.0` is invalid.

- **Content:**
  - Entries should be concise, grouped by category, and informative.
  - The changelog must be updated for each release, with the agent prompting you to review and approve the new section.

- **Validation:**
  - Validate the changelog format before packaging (Python script can check for header, indentation, tabs, trailing spaces, etc.).
  - Optionally, use community tools for additional validation.

**Automation Steps:**
- The agent/script will:
  - Prepend a new version section using the strict Factorio format.
  - Prompt you to review and approve the changelog before finalizing the release.
  - Validate the changelog for formatting errors before packaging.

**References:**
- [Factorio changelog format guide](https://wiki.factorio.com/Tutorial:Mod_changelog_format)
- [Factorio mod structure](https://wiki.factorio.com/Tutorial:Mod_structure)
- [Community changelog tools](https://github.com/marketplace/actions/release-please-factorio-changelog)

---
# TeleportFavorites Deployment & Release Automation Plan

_Last updated: July 23, 2025_

## Note on CI/CD Usage
This deployment plan is a guide, not a prescriptive process. The actual deployment and release workflow will be implemented using GitHub Actions CI/CD pipelines. Manual steps described here may be replaced or automated by pipeline jobs and scripts. Always refer to the latest `.github/workflows/` files for the authoritative release process.

---

## User-Specified Deployment Requirements & Preferences

9. **Documentation & Config File Exclusion:**
  - Only `README.md`, `LICENSE`, `changelog.txt`, and `info.json` are included in the release. All other documentation files are excluded.
  - Workspace configuration files (e.g., `TeleportFavorites_workspace.code-workspace`) are excluded from the release.
  - Empty files should be removed from the codebase before packaging.

1. **Staging Directory:**
  - All production edits and packaging will use the `.dist` directory. Source files are never modified.

2. **Automation Scripts:**
  - Python scripts for copying, comment stripping, and flag detection will be created and tested for robustness. No configuration is needed; scripts are for production releases only.

3. **Versioning:**
  - Semantic versioning is required. The agent will prompt for the new version number and display the previous version for reference.

4. **Artifact Naming:**
  - Release zip files will be named `TeleportFavorites_v{version}.zip`.

5. **Changelog Handling:**
  - `changelog.txt` must be included in the release artifact. The agent will update it with notes for the latest release and prompt for user review before finalizing.
  - Best practices from Factorio modding and API documentation should be followed for changelog formatting and inclusion.

6. **Manual Verification:**
  - A manual verification step is required before publishing a release.

7. **Validation/Fail Conditions:**
  - No additional validation steps at this time, but may be added as the release process evolves.

8. **Platform:**
  - All automation and deployment will be performed on Windows/PowerShell. No cross-platform support is required.

---

## Overview
This document describes the step-by-step workflow for deploying and releasing the TeleportFavorites Factorio mod, including automation scripts, changelog management, version bumping, Lua code preparation, and GitHub integration. All steps are designed for Windows/PowerShell environments and follow strict project coding standards. **This plan is a guide for CI/CD-based deployments and may be superseded by automated pipeline steps.**

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
- [ ] No test files or debug artifacts in root deployment directory
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


### Step 3: Staging/Deploy Directory & Lua Comment Stripping
- **Never modify original codebase files during deployment.**
- Create a staging/deploy directory (e.g., `deploy/` or `dist/`) and copy all files to be included in the release into this directory.
- Perform all comment stripping, flag exclusion, and other production optimizations only on the copied files in the staging directory.
- Use Python scripts (run via PowerShell) to automate copying, comment stripping, and flag detection. Example:
  ```powershell
  python .scripts/copy_for_deploy.py
  python .scripts/strip_comments.py --target deploy/
  # (find_dev_flags.py removed)
  ```
  _Note: The source files in the repository must remain untouched. All modifications for deployment are performed only on the copies in the staging directory._


### Step 4: Packaging
- Zip the staging/deploy directory, excluding test files and debug artifacts.
- Example PowerShell command:
  ```powershell
  Compress-Archive -Path .\deploy\* -DestinationPath ..\TeleportFavorites_vNEW_VERSION.zip -Force
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
- [ ] Review README.md documentation 

---

## 5. Troubleshooting & Notes
- Always run `.test.ps1` before packaging (ask if I would like to perform)
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

To ensure that only production debug settings are present (and no other development flags, settings, or constants) in production deployments, follow this sub-plan:

### Step 1: Identification
- Maintain a list of all development-only flags, settings, and constants (e.g., `DEV_MODE`, `ENABLE_TEST_FEATURES`, etc.) in `.project/coding_standards.md` or a dedicated config file. Only production-level debug settings (e.g., `DEBUG_LEVEL = "production"`) are permitted in release builds.
- Use Python scripts (run via PowerShell) to search for these identifiers in all Lua and config files:
  ```powershell
  # (find_dev_flags.py removed)
  ```

### Step 2: Automated Exclusion (Comments Only)
- No code should be removed for production; only comments should be stripped from Lua files (except license headers).
- Use Python scripts to automate comment stripping and flag detection. Example:
  ```powershell
  python .scripts/strip_comments.py
  # (find_dev_flags.py removed)
  ```

### Step 3: Validation
- After packaging, run a final scan using the Python script to ensure no development flags/settings remain except permitted production debug settings:
  ```powershell
  # (find_dev_flags.py removed)
  ```
- If any matches are found (other than allowed production debug settings), abort deployment and resolve before proceeding.

### Step 4: Documentation & Review
- Document all development-only flags/settings in `.project/coding_standards.md`.
- Review this exclusion process before each release.

### Step 5: CI/CD Integration (Options)
- You may add automated checks to CI/CD workflows to block releases containing development flags/settings. Options include:
  - Run the Python flag detection script as a CI step and fail the build if any dev-only flags/settings are found.
  - Use GitHub Actions to automate comment stripping and flag validation before packaging.
  - Integrate with existing lint/static analysis tools for additional safety.
- Example GitHub Actions step:
  ```yaml
  - name: Check for dev flags
  # (find_dev_flags.py removed)
  ```
---

---

## Additional Steps for GitHub CI/CD Release
- [ ] Exclude all documentation files except `README.md`, `LICENSE`, `changelog.txt`, and `info.json`
- [ ] Exclude workspace configuration files (e.g., `TeleportFavorites_workspace.code-workspace`)
- [ ] Remove any empty files from the codebase before packaging



When using GitHub Actions pipelines for deployment, ensure the following steps are included in your workflow:

- [ ] Use the `.dist` directory for all production edits and packaging
- [ ] Create and test Python scripts for copying, comment stripping, and flag detection
- [ ] Prompt for semantic version number and display previous version
- [ ] Name release zip as `TeleportFavorites_v{version}.zip`
- [ ] Include and update `changelog.txt` in the release artifact; prompt user for review
- [ ] Require manual verification before publishing
- [ ] (Optional) Add further validation steps as needed
- [ ] Run all automation on Windows/PowerShell

- [ ] Specify a custom version number for each release. If GitHub CI/CD does not provide a way to set the version, add a manual or scripted step to set the desired version in `info.json` and related files before packaging.

- [ ] Create a clean staging/deploy directory for each build (do not modify source files)
- [ ] Copy only production files to the staging directory (exclude tests, debug, and dev artifacts)
- [ ] Run Python scripts for comment stripping and dev flag detection on the staging directory
- [ ] Fail the build if forbidden dev flags/settings are found
- [ ] Automate version bumping and changelog prepending in the deploy artifact, or set a custom version number as needed
- [ ] Package (zip) only the staging directory
- [ ] Run a final validation scan on the deploy artifact
- [ ] Create a GitHub release using the validated artifact and changelog
- [ ] Clean up staging/deploy directories after each run
- [ ] (Optional) Add manual approval steps before publishing

Refer to `.github/workflows/` for the latest pipeline configuration and update this guide as automation evolves.

_This plan should be updated as automation scripts and workflows evolve._
