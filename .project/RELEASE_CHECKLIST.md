# TeleportFavorites Release Preparation Checklist

_Use this checklist to manually prepare and publish a production release from a commit. This process ensures only intentional, validated releases are published. Keep this file in the `.project` directory for reference._

---

## Release Preparation Steps



- [ ] **Review Commit:**
     - Confirm the commit contains production-ready code and assets. Test files and development artifacts may be present in the repository, but only production files will be included in the distributed release.
     - Ensure the distributed code (in `.dist`) excludes all test files, debug artifacts, unwanted documentation/config files, workspace configs, and empty files.

---

## Explicit Commands for Release Preparation

Run the following commands in PowerShell from the mod root directory:

1. **Copy production files to .dist:**
    ```powershell
    python .scripts\copy_for_deploy.py
    ```

2. **Strip comments from Lua files in .dist:**
    ```powershell
    python .scripts\strip_comments.py
    ```

3. **Scan for forbidden dev flags/settings in .dist:**
    # (find_dev_flags.py removed)

4. **Validate changelog.txt format in .dist:**
    ```powershell
    python .scripts\validate_changelog.py
    ```

5. **Zip the .dist directory for release:**
    ```powershell
    Compress-Archive -Path .dist\* -DestinationPath TeleportFavorites_v{version}.zip -Force
    ```

6. **Manually trigger the GitHub Actions release workflow:**
    - Go to the GitHub Actions tab and start the release workflow manually.

7. **Manual verification:**
    - Review the contents of `.dist` and the zipped artifact before publishing.

---

- [ ] **Update Version & Changelog:**
    - Decide on the new semantic version number.
    - Update `info.json` with the new version.
    - Prepend a new section to `changelog.txt` using strict Factorio format.
    - Review and approve changelog entries.

- [ ] **Push Changes to GitHub:**
    - Commit and push all changes to the main branch.

- [ ] **Manually Trigger CI/CD Pipeline:**
    - Go to the GitHub Actions tab.
    - Select the release workflow and trigger it manually (do not use auto-trigger).

- [ ] **Run Deployment Scripts:**
    - `.scripts/copy_for_deploy.py` — Copy production files to `.dist`.
    - `.scripts/strip_comments.py` — Remove comments from Lua files in `.dist`.
    - `.scripts/validate_changelog.py` — Validate `changelog.txt` format in `.dist`.

- [ ] **Manual Verification:**
    - Review the contents of `.dist` (artifact, changelog, version, etc.).
    - Confirm only allowed files are present (no tests, dotfiles, unwanted docs, workspace configs, or empty files).
    - Approve the release to continue.

- [ ] **Package Artifact:**
    - Zip the `.dist` directory as `TeleportFavorites_v{version}.zip`.

- [ ] **Create GitHub Release:**
    - Use the zipped artifact and changelog for the release.
    - Publish the release only after final manual review.

- [ ] **Post-Release Validation:**
    - Verify the release appears on GitHub and Factorio mod portal.
    - Test downloading and installing the new mod zip in Factorio.

---

_If any step fails or issues are found, resolve them before proceeding to the next step. This checklist ensures only intentional, validated releases are published._
