# TeleportFavorites Localization Guide

This document provides comprehensive information about the localization system and management tools for the TeleportFavorites Factorio mod.

## Directory Structure

```
locale/
├── locale_validator.ps1     # Simple validation script
├── locale_manager.ps1       # Comprehensive management script  
├── README.md               # This guide
├── backups/                # Backup files from operations
├── en/                     # English (source)
│   ├── strings.cfg
│   ├── settings.cfg
│   └── controls.cfg
├── de/                     # German  
│   ├── strings.cfg
│   ├── settings.cfg
│   └── controls.cfg
├── fr/                     # French
│   ├── strings.cfg
│   ├── settings.cfg
│   └── controls.cfg
└── es/                     # Spanish
    ├── strings.cfg
    ├── settings.cfg
    └── controls.cfg
```

## Locale Management Scripts

### 🔧 `locale_validator.ps1` - Quick Validation

Simple, fast validation of all locale files.

**Usage:**
```powershell
# Basic validation
.\locale_validator.ps1

# Show detailed information
.\locale_validator.ps1 -Verbose

# Show summary statistics
.\locale_validator.ps1 -Summary
```

**Features:**
- ✅ Validates file existence and structure
- ✅ Accurate key and section counting
- ✅ Clean, readable output
- ✅ Exit codes for automation

---

### 🛠️ `locale_manager.ps1` - Comprehensive Management

Advanced locale management with validation, reporting, and pruning capabilities.

**Usage:**
```powershell
# Show help and all options
.\locale_manager.ps1 -Help

# Validate all locale files
.\locale_manager.ps1 -Validate

# Generate detailed comparison report
.\locale_manager.ps1 -Report

# Find unused keys (preview only)
.\locale_manager.ps1 -PruneUnused -DryRun

# Remove unused keys with backup
.\locale_manager.ps1 -PruneUnused -Backup

# Target specific language
.\locale_manager.ps1 -Report -Language de
.\locale_manager.ps1 -Validate -Language fr
```

**Key Features:**

#### 📊 **Validation & Reporting**
- Comprehensive file structure validation
- Accurate key/section counting with proper regex patterns
- Detailed comparison reports showing completeness percentages
- Language-specific targeting

#### 🧹 **Unused Key Pruning**
- **Uses English files as source of truth**
- Identifies keys in other languages that don't exist in English
- Safe removal with backup creation
- Dry-run mode for preview
- Preserves comments and formatting

#### 🔒 **Safety Features**
- Automatic backup creation before modifications
- Dry-run mode to preview changes
- Detailed logging with timestamps
- Error handling and recovery

**Example Output:**
```
[2025-06-16 01:49:10] [SUCCESS]   EN (source): 93 keys, 6 sections, 4901 bytes
[2025-06-16 01:49:10] [SUCCESS]   DE: 93 keys, 6 sections, 5590 bytes (100%)
[2025-06-16 01:49:10] [SUCCESS]   FR: 93 keys, 6 sections, 5864 bytes (100%)
[2025-06-16 01:49:10] [SUCCESS]   ES: 93 keys, 6 sections, 5613 bytes (100%)
```

**Common Workflows:**
```powershell
# Daily validation check
.\locale_manager.ps1 -Validate

# Monthly cleanup (safe)
.\locale_manager.ps1 -PruneUnused -DryRun  # Preview first
.\locale_manager.ps1 -PruneUnused -Backup  # Then execute

# Before releases
.\locale_manager.ps1 -Report  # Full status check
```

## Supported Languages

- **English (en)** - Default language, fully implemented
- **German (de)** - Fully implemented with culturally appropriate translations
- **French (fr)** - Complete translation template ready for use
- **Spanish (es)** - Complete translation template ready for use

## Locale Categories

The localization system organizes strings into logical categories across three main files:

### Locale File Structure
Each language directory contains:
- **`strings.cfg`** - Main localization strings (GUI, errors, commands, handlers)
- **`settings.cfg`** - Mod setting names and descriptions
- **`controls.cfg`** - Custom input/hotkey names and descriptions

### 1. Mod Settings (`[mod-setting-name]` and `[mod-setting-description]`) - settings.cfg
- Setting names and descriptions
- Used in the mod settings interface

### 2. Custom Controls (`[controls]`) - controls.cfg  
- Custom input and hotkey descriptions
- Keyboard shortcut names (e.g., "Teleport to favorite 1")
- Used in Factorio's controls settings interface

### 3. GUI Elements (`[tf-gui]`) - strings.cfg
- All user interface text
- Button labels, tooltips, dialog messages
- Most commonly used category

### 4. Commands (`[tf-command]`) - strings.cfg
- Command feedback messages
- Action confirmation messages
- Undo/redo notifications

### 5. Handlers (`[tf-handler]`) - strings.cfg
- Event handler messages
- System notifications
- Internal process feedback

### 6. Errors (`[tf-error]`) - strings.cfg
- Error messages for various failure scenarios
- Teleportation errors, validation failures
- User-facing error notifications

## LocaleUtils Module

The `core/utils/locale_utils.lua` module provides centralized localization functionality:

### Key Functions

```lua
-- Get GUI strings
LocaleUtils.get_gui_string(player, "confirm")
LocaleUtils.get_gui_string(player, "teleported_to", {player.name, destination})

-- Get error messages
LocaleUtils.get_error_string(player, "driving_teleport_blocked")

-- Get command feedback
LocaleUtils.get_command_string(player, "action_undone")

-- Generic string access
LocaleUtils.get_string(player, "gui", "favorite_slot_empty")

-- Parameter substitution
LocaleUtils.substitute_parameters("Hello __1__!", {"World"})
```

### Features

- ✅ Automatic fallback to English for missing translations
- ✅ Parameter substitution support (`__1__`, `__2__`, named parameters)
- ✅ Category-based organization
- ✅ Debug mode for missing translation detection
- ✅ Invalid player handling
- ✅ Comprehensive error handling

## Implementation Status

### Phase 1: Foundation ✅ COMPLETE
- [x] Locale directory structure created
- [x] English locale file enhanced with all strings
- [x] German translation completed
- [x] French and Spanish templates created
- [x] LocaleUtils helper module implemented
- [x] Test suite created

### Phase 2: String Extraction 🔄 IN PROGRESS
- [ ] Replace hardcoded strings in teleport_strategy.lua
- [ ] Replace hardcoded strings in control modules
- [ ] Replace hardcoded strings in GUI modules
- [ ] Update all GameHelpers.player_print calls to use LocaleUtils
- [ ] Validate string completeness

### Phase 3: Multi-Language Support 📋 PENDING
- [ ] Test locale switching functionality
- [ ] Performance testing with multiple locales
- [ ] Community translation framework
- [ ] Documentation for translators

## Key Locale Strings

### Critical Error Messages
```ini
[tf-error]
driving_teleport_blocked=Are you crazy? Trying to teleport while driving is strictly prohibited.
player_missing=Unable to teleport. Player is missing
no_safe_position=No safe landing position found within safety radius
```

### Common GUI Elements
```ini
[tf-gui]
confirm=Confirm
cancel=Cancel
close=Close
teleport_success=Teleported successfully!
teleport_failed=Teleportation failed
```

### Favorites Bar
```ini
[tf-gui]
fave_slot_tooltip=Favorite: __1__ __2__
fave_bar_reordered=Moved favorite from slot __1__ to slot __2__
toggle_fave_bar=Show or hide your favorites bar
```

## Translation Guidelines

### For Translators

1. **Parameter Preservation**: Always preserve `__1__`, `__2__` parameter placeholders
2. **Context Awareness**: Consider the gaming context and Factorio terminology
3. **Consistency**: Maintain consistent terminology across all strings
4. **Cultural Adaptation**: Adapt phrases culturally (e.g., "Are you crazy?" in German becomes "Bist du verrückt?")

### Technical Requirements

1. **File Format**: Use `.cfg` format with proper section headers
2. **Encoding**: UTF-8 encoding required
3. **Comments**: Use `#` for comments within sections
4. **Key Format**: Use lowercase with underscores (e.g., `favorite_slot_empty`)

## Testing

Run the test suite to validate LocaleUtils functionality:

```lua
local TestLocaleUtils = require("tests.test_locale_utils")
local results = TestLocaleUtils.run_all_tests()
TestLocaleUtils.print_test_results(results)
```

## Migration Strategy

### From Hardcoded Strings

Replace patterns like:
```lua
-- OLD
GameHelpers.player_print(player, "Are you crazy? Trying to teleport while driving is strictly prohibited.")

-- NEW  
GameHelpers.player_print(player, LocaleUtils.get_error_string(player, "driving_teleport_blocked"))
```

### GUI Creation
```lua
-- OLD
parent.add{type = "button", caption = "Confirm"}

-- NEW
parent.add{type = "button", caption = LocaleUtils.get_gui_string(player, "confirm")}
```

## Adding New Languages

1. Create new language directory: `locale/{language_code}/`
2. Copy `locale/en/strings.cfg` as template
3. Translate all strings while preserving parameters
4. Test with native speakers
5. Submit via pull request

## Best Practices

### Development Workflow
1. **Always use LocaleUtils** - Never hardcode user-facing strings
2. **English first** - Add new strings to English locale files before translating
3. **Validate early, validate often** - Use the validation scripts during development:
   ```powershell
   .\locale_validator.ps1 -Verbose  # Quick check
   .\locale_manager.ps1 -Report     # Detailed analysis
   ```
4. **Clean up regularly** - Use pruning to remove obsolete keys:
   ```powershell
   .\locale_manager.ps1 -PruneUnused -Backup
   ```

### Translation Guidelines
1. **Test missing translations** - Enable debug mode during development
2. **Validate parameters** - Ensure parameter placeholders are preserved (e.g., `__1__`, `__2__`)
3. **Cultural sensitivity** - Consider cultural context in translations
4. **Consistency** - Use established Factorio terminology
5. **Verify completeness** - All languages should have 100% key coverage:
   ```powershell
   .\locale_manager.ps1 -Report  # Check for 100% completion
   ```

### File Management
- **Use backups** - Always use `-Backup` flag when making changes
- **Preview first** - Use `-DryRun` to see what would change
- **Check status regularly** - Monitor translation completeness
- **Keep English as source of truth** - Other languages follow English structure

## Maintenance

### Managing Locale Files with Scripts

#### **Quick Validation**
```powershell
# Validate all files and show summary
.\locale_validator.ps1 -Verbose
```

#### **Comprehensive Management**
```powershell
# Check status of all locale files
.\locale_manager.ps1 -Report

# Clean up unused keys (English as source of truth)
.\locale_manager.ps1 -PruneUnused -Backup
```

### Adding New Strings
1. **Add to English locale file first** (strings.cfg, settings.cfg, or controls.cfg)
2. **Run validation** to ensure proper formatting:
   ```powershell
   .\locale_validator.ps1 -Verbose
   ```
3. **Add translations** to other language files
4. **Validate completeness**:
   ```powershell
   .\locale_manager.ps1 -Report
   ```
5. Test with LocaleUtils in-game
6. Update documentation

### Updating Existing Strings
1. **Update English version first**
2. **Update corresponding translations**
3. **Run pruning** to clean up any obsolete keys:
   ```powershell
   .\locale_manager.ps1 -PruneUnused -DryRun  # Preview
   .\locale_manager.ps1 -PruneUnused -Backup  # Execute
   ```
4. **Validate final state**:
   ```powershell
   .\locale_manager.ps1 -Report
   ```

### Cleaning Up Obsolete Keys
When you remove keys from English files, other language files may retain obsolete translations:

```powershell
# Find obsolete keys
.\locale_manager.ps1 -PruneUnused -DryRun

# Clean them up safely
.\locale_manager.ps1 -PruneUnused -Backup
```

**The pruning process:**
- Uses English files as the authoritative source
- Identifies keys in other languages that don't exist in English
- Creates backups before removing anything
- Preserves all comments and formatting
- Reports exactly what was removed

## Performance Considerations

- LocaleUtils caches translations where possible
- Parameter substitution is optimized for common patterns
- Fallback system minimizes lookup overhead
- Debug mode can be disabled in production

## Support & Troubleshooting

### Common Issues

#### **Validation Failures**
```powershell
# Check specific language
.\locale_manager.ps1 -Validate -Language de

# Get detailed information
.\locale_validator.ps1 -Verbose
```

#### **Inconsistent Key Counts**
```powershell
# Generate comparison report
.\locale_manager.ps1 -Report

# Clean up unused keys
.\locale_manager.ps1 -PruneUnused -Backup
```

#### **Missing Translations**
1. Check the detailed report for completion percentages
2. Add missing keys to target language files
3. Validate the fixes

#### **File Corruption or Formatting Issues**
1. Check the backup files in `locale/backups/`
2. Restore from backup if needed
3. Re-run validation to confirm fix

### Script Troubleshooting

**If locale_manager.ps1 fails:**
- Check PowerShell execution policy: `Get-ExecutionPolicy`
- Run with explicit execution policy: `powershell -ExecutionPolicy Bypass -File .\locale_manager.ps1 -Help`
- Check file permissions in the locale directory

**If pruning removes too much:**
- Backups are automatically created in `locale/backups/`
- Restore from backup files if needed
- Always use `-DryRun` first to preview changes

### Getting Help
```powershell
# Show all available options
.\locale_manager.ps1 -Help

# Check script version and capabilities
.\locale_validator.ps1 -Verbose
```

For localization issues:
1. Run the validation scripts first
2. Check the generated reports for specific problems  
3. Enable debug mode to identify missing strings in-game
4. Validate locale file syntax with the scripts
5. Check parameter placeholder preservation
6. Test with different player locales

---

## Quick Reference

### Daily Development
```powershell
# Quick validation check
.\locale_validator.ps1

# Check translation status
.\locale_manager.ps1 -Report
```

### Before Committing Changes
```powershell
# Comprehensive validation
.\locale_validator.ps1 -Verbose

# Clean up any obsolete keys
.\locale_manager.ps1 -PruneUnused -DryRun   # Preview
.\locale_manager.ps1 -PruneUnused -Backup   # Execute

# Final status check
.\locale_manager.ps1 -Report
```

### Monthly Maintenance
```powershell
# Full cleanup and verification
.\locale_manager.ps1 -PruneUnused -Backup
.\locale_manager.ps1 -Report
```

---

**Last Updated**: June 16, 2025  
**Version**: 2.0.0  
**Status**: Complete with Management Tools  
**Scripts**: locale_validator.ps1, locale_manager.ps1
