# Multiplayer Desync Fix - Chart Tag Creation

## Problem Summary
When a joined player tried to create a new map tag (chart tag) in multiplayer, the game would immediately desync and disconnect all players.

## Root Cause Analysis

### The Desync Trigger
The desync was caused by **non-deterministic behavior in chart tag creation** due to client-specific state being used in game logic.

### Technical Details

In `core/utils/chart_tag_utils.lua`, the `safe_add_chart_tag()` function uses `find_closest_chart_tag_to_position()` to check for existing chart tags at the target location before creating a new one.

**The Problem:** `find_closest_chart_tag_to_position()` was checking `player.render_mode` to determine if the player was in map view:

```lua
if player.render_mode ~= defines.render_mode.chart then
  return nil  -- Don't find tags if not in map view
end
```

### Why This Causes Desyncs

Factorio uses **deterministic lockstep multiplayer**:
- All game state changes must happen identically on all clients
- GUI events (like button clicks) are synchronized across all clients
- Event handlers run on ALL clients, not just the one where the GUI was clicked

**The Desync Scenario:**
1. Player A clicks "Confirm" in the tag editor on their client
2. The `on_gui_click` event fires on **all clients** in the multiplayer game
3. On Player A's client: Player is in map view → `render_mode == chart` → finds existing tag → **updates** tag
4. On Player B's client: Player B is NOT in map view → `render_mode != chart` → doesn't find tag → **creates NEW** tag
5. **DESYNC:** Different chart tag state across clients → game states diverge → desync error

### Why player.render_mode is Non-Deterministic

`player.render_mode` is **client-specific state**:
- Each player can be in different view modes (normal view, map view, etc.)
- This state is NOT part of the synchronized game state
- Using it in game logic breaks determinism

According to Factorio developer boskid ([source](https://forums.factorio.com/viewtopic.php?t=102156)):
> "Under assumption of a program determinism, if your script is deterministic and uses only data that are part of game state, you can make changes in the game state keeping the invariant safe. If it would not be maintained, a client will desync."

## The Solution

### Code Changes

**File:** `core/utils/chart_tag_utils.lua`

1. **Added optional parameter to skip render mode check:**
   ```lua
   function ChartTagUtils.find_closest_chart_tag_to_position(player, cursor_position, skip_render_mode_check)
     -- Only detect clicks while in map mode (unless explicitly skipped for collision detection)
     if not skip_render_mode_check and player.render_mode ~= defines.render_mode.chart then
       return nil
     end
     -- ... rest of function
   end
   ```

2. **Updated collision detection to skip render mode check:**
   ```lua
   -- CRITICAL: Pass true to skip render_mode check for multiplayer determinism
   -- The render_mode is client-specific and causes desyncs if used in game state logic
   local existing_chart_tag = nil
   if player and player.valid then
     existing_chart_tag = ChartTagUtils.find_closest_chart_tag_to_position(player, spec.position, true)
   end
   ```

### Why This Works

- **For click detection:** Still uses `render_mode` check - this is fine because map clicks only happen when player IS in map view
- **For chart tag creation/collision detection:** Skips `render_mode` check - ensures deterministic behavior across all clients
- All clients now execute the exact same logic regardless of their local view state

## Testing

### Before Fix
- ❌ Joined player creates new tag → Immediate desync and disconnect
- ✅ Host player creates new tag → Works fine (both clients happen to be in same view state)

### After Fix
- ✅ Joined player creates new tag → No desync, tag created successfully on all clients
- ✅ Host player creates new tag → Still works as before
- ✅ Multiple players creating tags simultaneously → No desyncs

## Lessons Learned

### Multiplayer-Safe Coding Principles for Factorio Mods

1. **Never use client-specific state in game logic:**
   - ❌ `player.render_mode`
   - ❌ `player.cursor_stack` (for determining behavior, reading for sync is OK)
   - ❌ Any state that varies between clients

2. **Always use synchronized game state:**
   - ✅ `storage` (global persistence)
   - ✅ `player.index`, `player.name`, `player.force`
   - ✅ `surface`, `entity`, `force` objects
   - ✅ Chart tag positions, text, icons

3. **Understand event synchronization:**
   - GUI events ARE synchronized - they run on all clients
   - Event handlers must be deterministic
   - Non-deterministic operations cause desyncs

4. **Design for determinism:**
   - Event handler on Client A must produce same result as on Client B
   - Use only game state that is guaranteed identical across clients
   - When in doubt, test in actual multiplayer scenarios

## Related Documentation

- [Factorio Multiplayer Determinism Discussion](https://forums.factorio.com/viewtopic.php?t=102156)
- [Factorio Data Lifecycle](https://lua-api.factorio.com/latest/Data-Lifecycle.html)
- [Desynchronization Wiki](https://wiki.factorio.com/Desynchronization)

## Date Fixed
2025-01-12

## Contributors
- Identified by: User bug report (joined player cannot create tags)
- Root cause analysis: AI Agent investigation
- Fix implemented: AI Agent
