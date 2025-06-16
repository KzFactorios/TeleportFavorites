# TeleportFavorites Localization Guide

This document provides comprehensive information about the localization system implemented for the TeleportFavorites Factorio mod.

## Directory Structure

```
locale/
├── en/              # English (default)
│   └── strings.cfg
├── de/              # German  
│   └── strings.cfg
├── fr/              # French
│   └── strings.cfg
└── es/              # Spanish
    └── strings.cfg
```

## Supported Languages

- **English (en)** - Default language, fully implemented
- **German (de)** - Fully implemented with culturally appropriate translations
- **French (fr)** - Complete translation template ready for use
- **Spanish (es)** - Complete translation template ready for use

## Locale Categories

The localization system organizes strings into logical categories:

### 1. Mod Settings (`[mod-setting-name]` and `[mod-setting-description]`)
- Setting names and descriptions
- Used in the mod settings interface

### 2. GUI Elements (`[tf-gui]`)
- All user interface text
- Button labels, tooltips, dialog messages
- Most commonly used category

### 3. Commands (`[tf-command]`)
- Command feedback messages
- Action confirmation messages
- Undo/redo notifications

### 4. Handlers (`[tf-handler]`)
- Event handler messages
- System notifications
- Internal process feedback

### 5. Errors (`[tf-error]`)
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

1. **Always use LocaleUtils** - Never hardcode user-facing strings
2. **Test missing translations** - Enable debug mode during development
3. **Validate parameters** - Ensure parameter placeholders are preserved
4. **Cultural sensitivity** - Consider cultural context in translations
5. **Consistency** - Use established Factorio terminology

## Maintenance

### Adding New Strings
1. Add to English locale file first
2. Add to LocaleUtils fallbacks if critical
3. Update translation templates
4. Test with LocaleUtils
5. Update documentation

### Updating Existing Strings
1. Update English version
2. Mark translations as needing update
3. Test for breaking changes
4. Update fallback strings if needed

## Performance Considerations

- LocaleUtils caches translations where possible
- Parameter substitution is optimized for common patterns
- Fallback system minimizes lookup overhead
- Debug mode can be disabled in production

## Support

For localization issues:
1. Check test suite results
2. Enable debug mode to identify missing strings
3. Validate locale file syntax
4. Check parameter placeholder preservation
5. Test with different player locales

---

**Last Updated**: June 16, 2025  
**Version**: 1.0.0  
**Status**: Foundation Complete, Implementation In Progress
