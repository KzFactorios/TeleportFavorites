# TeleportFavorites Bug Fix Report
## Date: June 16, 2025

## Issues Fixed

### 1. Unknown Locale Key Error: "tf-error.event_handler_error"

**Problem**: When right-clicking on the map, players received an error message about an unknown locale key "tf-error.event_handler_error".

**Root Cause**: The event error handler in `event_registration_dispatcher.lua` was referencing a locale key that didn't exist in any locale files.

**Solution**: Added the missing locale key to all language files:
- **English**: "An unexpected error occurred during event handling"
- **German**: "Ein unerwarteter Fehler ist während der Ereignisbehandlung aufgetreten"  
- **Spanish**: "Se produjo un error inesperado durante el manejo de eventos"
- **French**: "Une erreur inattendue s'est produite lors de la gestion des événements"

**Files Modified**:
- `locale/en/strings.cfg`
- `locale/de/strings.cfg`
- `locale/es/strings.cfg`
- `locale/fr/strings.cfg`

### 2. Favorites Bar Not Showing

**Problem**: The favorites bar was not appearing in the game interface despite being enabled in settings.

**Root Cause**: Multiple incorrect function calls to `fave_bar.build(player, parent)` where the function signature actually expects `fave_bar.build(player, force_show)`. The second parameter should be a boolean, not a GUI parent element.

**Solution**: 
1. **Fixed Function Calls**: Updated all calls to use the correct signature:
   - `core/events/handlers.lua`: Fixed `on_player_created()` and `on_init()` 
   - `core/events/event_registration_dispatcher.lua`: Fixed settings change handler
   - `core/control/control_fave_bar.lua`: Fixed rebuild call
   - `core/pattern/gui_observer.lua`: Fixed favorites bar refresh

2. **Added Missing Function**: Created `fave_bar.destroy(player)` function that was being called but didn't exist.

**Files Modified**:
- `core/events/handlers.lua`
- `core/events/event_registration_dispatcher.lua`  
- `core/control/control_fave_bar.lua`
- `core/pattern/gui_observer.lua`
- `gui/favorites_bar/fave_bar.lua` (added destroy function)

## Technical Details

### Function Signature Correction
**Before**: `fave_bar.build(player, parent)` 
**After**: `fave_bar.build(player)` or `fave_bar.build(player, force_show)`

The `fave_bar.build` function internally determines the GUI parent using `GuiUtils.get_or_create_gui_flow_from_gui_top(player)`, so passing a parent element was unnecessary and incorrect.

### New Function Added
```lua
--- Destroy/hide the favorites bar for a player
---@param player LuaPlayer
function fave_bar.destroy(player)
  if not player or not player.valid then return end
  
  local main_flow = GuiUtils.get_or_create_gui_flow_from_gui_top(player)
  GuiUtils.safe_destroy_frame(main_flow, Enum.GuiEnum.GUI_FRAME.FAVE_BAR)
end
```

## Testing

Both issues should now be resolved:
1. ✅ Right-clicking on the map should no longer show locale key errors
2. ✅ Favorites bar should appear when the setting is enabled
3. ✅ Favorites bar should disappear when the setting is disabled  
4. ✅ All language localizations include the new error message

## Verification Steps

To verify the fixes:
1. Load the mod in Factorio
2. Ensure "Show Favorites Bar" setting is enabled  
3. Right-click on the map - should open tag editor without errors
4. Check that favorites bar appears in the top GUI
5. Toggle the favorites bar setting - bar should show/hide accordingly

## Files Changed Summary

**Core Event Handling**:
- `core/events/handlers.lua` - Fixed fave_bar.build calls
- `core/events/event_registration_dispatcher.lua` - Fixed fave_bar.build calls

**Favorites Bar**:  
- `gui/favorites_bar/fave_bar.lua` - Added destroy function
- `core/control/control_fave_bar.lua` - Fixed rebuild call
- `core/pattern/gui_observer.lua` - Fixed refresh call

**Localization**:
- `locale/en/strings.cfg` - Added event_handler_error key
- `locale/de/strings.cfg` - Added event_handler_error key  
- `locale/es/strings.cfg` - Added event_handler_error key
- `locale/fr/strings.cfg` - Added event_handler_error key

## Impact

These fixes address two critical user-facing issues that prevented normal mod functionality:
- Players can now right-click on the map without encountering error messages
- The favorites bar properly appears and functions as designed
- All error messages are properly localized for international users
