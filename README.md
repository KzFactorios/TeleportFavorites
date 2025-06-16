# TeleportFavorites

A comprehensive teleportation and favorites management mod for Factorio with full multi-language support.

This mod uses graphical assets from Factorio, © Wube Software Ltd. Used with permission under the Factorio modding terms. All rights reserved by Wube Software Ltd. These assets are only for use within Factorio and Factorio mods.

## 🌍 Multi-Language Support

TeleportFavorites features comprehensive localization support with robust translation management:

### Supported Languages
- **English (en)** - Complete (source language)
- **German (de)** - Complete with cultural adaptations
- **French (fr)** - Complete translation available
- **Spanish (es)** - Complete translation available

### Translation Quality
- **100% Coverage** - All user-facing text is localized
- **Cultural Adaptation** - Context-appropriate translations (e.g., "Are you crazy?" → "Bist du verrückt?")
- **Parameter Preservation** - All dynamic text placeholders maintained
- **Robust Fallbacks** - Graceful handling of missing translations

## 🚀 Key Features

### Teleportation System
- **Strategy Pattern Implementation** - Flexible teleportation modes
- **Vehicle Support** - Teleport with vehicles safely
- **Safety Validation** - Collision detection and safe landing
- **Multi-Surface Support** - Works across different game surfaces

### Favorites Management
- **Visual Favorites Bar** - Quick access to favorite locations
- **Drag & Drop** - Intuitive reordering of favorites
- **Lock System** - Prevent accidental changes to favorites
- **Smart Integration** - Seamless chart tag integration

### Error Handling
- **Localized Error Messages** - Clear, translated error feedback
- **Graceful Degradation** - Robust handling of edge cases
- **Debug Support** - Comprehensive logging for troubleshooting

## 🛠 Development

### Localization Management

The mod includes automated tools for managing translations:

```powershell
# Navigate to locale directory
cd "locale"

# Quick status check
.\locale_helper.ps1 report

# Add missing keys to all languages
.\locale_helper.ps1 add-missing

# Synchronize all locales with English source
.\locale_helper.ps1 sync

# Work on specific language
.\locale_helper.ps1 de  # German
.\locale_helper.ps1 fr  # French
.\locale_helper.ps1 es  # Spanish
```

### Translation Workflow
1. **English First** - Add new strings to `locale/en/strings.cfg`
2. **Sync Scripts** - Use locale tools to propagate to other languages
3. **Translation** - Replace English placeholders with proper translations
4. **Validation** - Ensure parameter placeholders (`__1__`, `__2__`) are preserved
5. **Testing** - Validate in-game with different language settings

For detailed localization information, see:
- [`locale/README.md`](locale/README.md) - Complete localization guide
- [`locale/SYNC_GUIDE.md`](locale/SYNC_GUIDE.md) - Translation management tools
- [`locale/Phase2_Progress_Report.md`](locale/Phase2_Progress_Report.md) - Implementation details

### Command Line Usage

This project is developed on Windows using PowerShell. When running commands, please follow the [PowerShell Command Formatting Guidelines](notes/powershell_command_format.md).

### Documentation

The `notes/` directory contains important development documentation:
- [PowerShell Command Format](notes/powershell_command_format.md) - Guidance for formatting PowerShell commands correctly
- [Design Specs](notes/design_specs.md) - Design specifications
- [Architecture](notes/architecture.md) - Architectural overview
- [Coding Standards](notes/coding_standards.md) - Coding standards for this project
- [Test Organization Guidelines](notes/test_organization_guidelines.md) - Guidelines for organizing test files

## 🏗 Architecture

### Localization System
- **LocaleUtils Module** - Centralized localization API
- **Category-Based Organization** - GUI, Error, Command, Handler categories
- **Fallback Mechanisms** - English fallbacks for missing translations
- **Parameter Substitution** - Dynamic content support with `__1__`, `__2__` placeholders

### Core Components
- **Strategy Pattern** - Flexible teleportation strategies
- **Observer Pattern** - GUI event management
- **Cache System** - Performance-optimized data access
- **Error Handling** - Comprehensive error management with localized messages

## 🧪 Testing

The mod includes comprehensive test coverage:
- **LocaleUtils Tests** - Unit tests for localization system
- **Integration Tests** - Real-world usage scenarios
- **Validation Tests** - Translation completeness and parameter validation

```powershell
# Run localization tests (in-game)
/c local test = require("tests.test_locale_utils"); test.print_test_results()

# Run integration tests
/c local test = require("tests.test_localization_integration"); test.print_test_results()
```

## 🤝 Contributing

### For Developers
1. Always update English locale files first (`locale/en/strings.cfg`)
2. Use LocaleUtils API for all user-facing text: `LocaleUtils.get_error_string(player, "key")`
3. Test with locale sync tools before committing
4. Follow established coding patterns and architecture

### For Translators
1. Use locale sync tools to identify missing translations
2. Preserve parameter placeholders (`__1__`, `__2__`) in translations
3. Consider cultural context and Factorio terminology
4. Test translations in-game to ensure proper fit

### Quality Standards
- **Zero Breaking Changes** - All updates maintain backward compatibility
- **Comprehensive Testing** - Full test coverage for new features
- **Documentation** - Clear documentation for all APIs and tools
- **Performance** - No measurable impact on game performance

## 📋 Requirements

- **Factorio** 2.0+
- **Multi-language Support** - Automatic detection of player language settings
- **Modern Lua** - Uses contemporary Lua patterns and best practices

## 📄 License

See [LICENSE](LICENSE) file for details.

---

**Status**: Production Ready | **Languages**: 4 Complete | **Test Coverage**: Comprehensive
