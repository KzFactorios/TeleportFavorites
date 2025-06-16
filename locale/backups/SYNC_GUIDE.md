# Locale Synchronization Guide

This guide explains how to use the locale synchronization scripts to maintain consistency across all language files based on the English source.

## 📁 Locale File Structure

The synchronization scripts handle three types of locale files:
- **`strings.cfg`** - Main localization strings (GUI, errors, commands, handlers)
- **`settings.cfg`** - Mod setting names and descriptions  
- **`controls.cfg`** - Custom input/hotkey names and descriptions

## 📁 Script Files

### 1. `enhanced_locale_sync.ps1` - Enhanced Full-Featured Script
Complete synchronization tool with support for all locale file types.

### 2. `locale_sync_script.ps1` - Legacy Script (strings.cfg only)
Original synchronization tool for strings.cfg files only.

### 3. `locale_helper.ps1` - Quick Helper  
Simple wrapper for common operations across all file types.

## 🚀 Quick Start

### Most Common Workflow:

```powershell
# 1. Check current status
.\locale_helper.ps1 report

# 2. Preview what changes would be made
.\locale_helper.ps1 sync-dry

# 3. Add missing keys safely (recommended first step)
.\locale_helper.ps1 add-missing

# 4. Full synchronization when ready
.\locale_helper.ps1 sync
```

## 📊 Understanding the Reports

### Comparison Report Shows:
- **Completion percentage** for each language
- **Missing keys** that need to be added
- **Obsolete keys** that should be removed
- **Section-by-section breakdown**

### Example Report Output:
```
### de (GERMAN)
- File exists: True
- Total sections: 5
- Total keys: 45
- Completion: 98.2%

Missing keys (1):
- tf-error.new_error_key

Obsolete keys (0):
(none)
```

## 🔧 Script Options

### locale_sync_script.ps1 Parameters:

| Parameter | Description | Example |
|-----------|-------------|---------|
| `-Sync` | Full synchronization | `.\locale_sync_script.ps1 -Sync` |
| `-AddMissing` | Add missing keys only | `.\locale_sync_script.ps1 -AddMissing` |
| `-Report` | Generate comparison report | `.\locale_sync_script.ps1 -Report` |
| `-Validate` | Validate file integrity | `.\locale_sync_script.ps1 -Validate` |
| `-TargetLang` | Specific language only | `.\locale_sync_script.ps1 -Sync -TargetLang de` |
| `-Backup` | Create backup files | `.\locale_sync_script.ps1 -Sync -Backup` |
| `-DryRun` | Preview changes only | `.\locale_sync_script.ps1 -Sync -DryRun` |

### locale_helper.ps1 Commands:

| Command | Description | Equivalent Full Command |
|---------|-------------|------------------------|
| `report` | Generate report | `locale_sync_script.ps1 -Report` |
| `sync` | Full sync with backup | `locale_sync_script.ps1 -Sync -Backup` |
| `sync-dry` | Preview sync | `locale_sync_script.ps1 -Sync -DryRun` |
| `add-missing` | Add missing keys | `locale_sync_script.ps1 -AddMissing -Backup` |
| `validate` | Validate files | `locale_sync_script.ps1 -Validate` |
| `de/fr/es` | Language-specific | `locale_sync_script.ps1 -Sync -TargetLang X -Backup` |

## 📝 Common Scenarios

### Scenario 1: Added New English Strings
You've added new keys to `en/strings.cfg` and want to update other languages:

```powershell
# Safe approach - add placeholders
.\locale_helper.ps1 add-missing

# This adds English text as placeholders in other languages
# Translators can then replace the English text with proper translations
```

### Scenario 2: Modified Existing English Strings
You've changed existing English strings:

```powershell
# Check what needs updating
.\locale_helper.ps1 report

# Preview changes
.\locale_helper.ps1 sync-dry

# Apply changes (keeps existing translations for unchanged keys)
.\locale_helper.ps1 sync
```

### Scenario 3: Working on Specific Language
You're focusing on improving one language:

```powershell
# German-specific sync
.\locale_helper.ps1 de

# Or with full options
.\locale_sync_script.ps1 -Sync -TargetLang de -Backup -DryRun
```

### Scenario 4: Quality Assurance
Before releasing, validate everything:

```powershell
# Comprehensive validation
.\locale_helper.ps1 validate

# Generate final report
.\locale_helper.ps1 report
```

## 🔍 What the Scripts Do

### Adding Missing Keys:
- Parses English `strings.cfg` as the source of truth
- Identifies keys that exist in English but not in other languages
- Adds missing keys with English text as placeholders
- Preserves existing translations

### Synchronization:
- Ensures all languages have the same key structure as English
- Adds missing sections and keys
- Identifies obsolete keys (exist in target but not in English)
- Maintains proper locale file formatting

### Validation:
- Checks file parsing integrity
- Validates parameter consistency (`__1__`, `__2__` placeholders)
- Reports structural issues
- Ensures all files are properly formatted

## 📋 File Backup System

When using `-Backup` option:
- Creates `locale/backups/` directory
- Saves timestamped backups: `de-strings-20250616-143052.cfg`
- Allows easy rollback if needed

## ⚠️ Important Notes

### Parameter Preservation:
The scripts automatically check that parameter placeholders (`__1__`, `__2__`) are preserved in translations:

```ini
# English
failed_add_favorite=Failed to add favorite: __1__

# German (correct)
failed_add_favorite=Fehler beim Hinzufügen des Favoriten: __1__

# German (incorrect - missing parameter)
failed_add_favorite=Fehler beim Hinzufügen des Favoriten
```

### Translation Workflow:
1. Scripts add English text as placeholders
2. Translators replace placeholders with proper translations
3. Parameter placeholders (`__1__`, `__2__`) must be preserved
4. Validation catches parameter mismatches

### Safe Operations:
- Always use `-DryRun` first to preview changes
- Use `-Backup` for safety
- `add-missing` is safer than full `sync`
- Validate after major changes

## 🎯 Best Practices

### For Developers:
1. **Always update English first** - it's the source of truth
2. **Use descriptive keys** - `teleport_success` not `msg1`
3. **Test with sync-dry** before applying changes
4. **Validate after updates** to catch issues early

### For Translators:
1. **Never modify English files** - changes will be overwritten
2. **Preserve parameter placeholders** (`__1__`, `__2__`)
3. **Use locale helper** to check your progress
4. **Test in-game** to ensure translations fit UI elements

### For Release:
1. **Final validation** before packaging
2. **Generate completion report** for documentation
3. **Backup current state** for rollback capability
4. **Test with different language settings** in-game

## 📞 Troubleshooting

### Script Won't Run:
```powershell
# Set execution policy temporarily
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process
.\locale_helper.ps1 help
```

### Missing Keys Not Added:
- Check if English file is properly formatted
- Ensure sections use `[section-name]` format
- Verify key=value pairs are correctly formatted

### Parameter Validation Fails:
- Count `__1__`, `__2__` placeholders in both English and translation
- Ensure exact match in parameter count
- Use validation to identify specific issues

### File Parsing Errors:
- Check for proper UTF-8 encoding
- Ensure no special characters in section names
- Verify `=` separators in key-value pairs

The locale synchronization system provides a robust foundation for maintaining multi-language support while keeping all translations in sync with the authoritative English source.
