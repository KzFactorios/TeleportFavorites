# Nil player_index Fix for Chart Tag Events

## Problem

The mod was crashing when chart tags were added or modified by scripts or other mods with the error:

```
[TeleFaves][WARN] Event handler failed | Context: handler_name=on_chart_tag_added 
error=__TeleportFavorites__/core/events/handlers.lua:211: bad argument #3 of 3 to '__index' (string expected, got nil)
```

## Root Cause

The Factorio API for chart tag events (`on_chart_tag_added`, `on_chart_tag_modified`, `on_chart_tag_removed`) includes an optional `player_index` field that can be `nil` when:

1. Chart tags are added/modified by scripts (e.g., via `force.add_chart_tag()`)
2. Chart tags are added/modified by other mods
3. Chart tags are added/modified through console commands

The mod's event handlers were assuming `event.player_index` would always be present and were directly accessing `game.players[event.player_index]` without checking for nil, causing a Lua error.

## Solution

Added nil checks for `event.player_index` in both handlers before attempting to access the players table:

### handlers.lua - on_chart_tag_added (Lines 209-216)

```lua
function handlers.on_chart_tag_added(event)
  -- Get the player object from the event.player_index (can be nil if added by script)
  if not event.player_index then
    ErrorHandler.debug_log("Chart tag added without player_index (added by script or other mod)")
    return
  end
  
  local player = game.players[event.player_index]
  if not player or not player.valid then return end
  -- ... rest of handler
```

### handlers.lua - on_chart_tag_modified (Lines 251-259)

```lua
function handlers.on_chart_tag_modified(event)
  if not event or not event.old_position then return end
  
  -- Check for valid player_index (can be nil if modified by script)
  if not event.player_index then
    ErrorHandler.debug_log("Chart tag modified without player_index (modified by script or other mod)")
    return
  end
  
  local player = game.players[event.player_index]
  if not player or not player.valid then return end
  -- ... rest of handler
```

### Note on on_chart_tag_removed

The `on_chart_tag_removed` handler already had proper protection through the `with_valid_player()` helper function, which gracefully handles nil player_index by returning early.

## Impact

This fix:

1. **Prevents crashes** when other mods or scripts manipulate chart tags
2. **Improves mod compatibility** with other mods that use the chart tag system
3. **Maintains existing functionality** for player-initiated chart tag operations
4. **Provides debug logging** to help track when tags are added/modified programmatically

## Testing

- ✅ All existing tests pass (4/4)
- ✅ No new lint errors introduced
- ✅ Early return pattern ensures no downstream effects when player_index is nil

## Files Modified

1. `core/events/handlers.lua`
   - Added nil check in `on_chart_tag_added` (line 211)
   - Added nil check in `on_chart_tag_modified` (line 253)

2. `changelog.txt`
   - Documented the fix under Version 0.0.7 bugfixes

## Version Information

- **Fixed in**: Version 0.0.7
- **Status**: Complete and tested
- **Breaking Changes**: None
- **Mod Compatibility**: Improved (now compatible with script-based chart tag manipulation)

## Related API Documentation

From Factorio API:
- `on_chart_tag_added` - Fired when a chart tag is added. `player_index` is optional.
- `on_chart_tag_modified` - Fired when a chart tag is modified. `player_index` is optional.
- `on_chart_tag_removed` - Fired when a chart tag is removed. `player_index` is optional.

All three events can have `nil` player_index when triggered by non-player actions.
