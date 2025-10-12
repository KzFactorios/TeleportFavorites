# Additional Multiplayer Desync Fixes - GUI Observer & Favorites Bar

## Issue Report
After initial fix for chart tag creation desync, desyncs were still occurring during tag modification operations. Log analysis revealed additional desync triggers in the notification processing and GUI rebuild logic.

## Additional Root Causes Identified

### Issue #2: Observer Cleanup During Notification Processing

**File:** `core/events/gui_observer.lua`

**Problem:** The `process_notifications()` function was calling `cleanup_observers()` during notification processing, which checks player connection state:

```lua
-- PROBLEMATIC CODE (removed):
GuiEventBus.cleanup_observers(notification.type)
```

The cleanup function checks `observer.player.connected` which is client-specific:
- Client A: Player appears connected → observer kept → notification processed → favorites bar updated
- Client B: Player appears disconnected → observer removed → notification NOT processed → no update
- **DESYNC:** Different notification processing results across clients

**Fix:** Removed all observer cleanup from notification processing:

```lua
-- DO NOT clean up observers during notification processing - it uses player.connected
-- which is client-specific and causes desyncs in multiplayer!
-- Cleanup happens during scheduled cleanup (on_tick) which is deterministic.
```

Also removed periodic cleanup triggers that ran during notification processing.

### Issue #3: GUI Rebuild Using Client-Specific View State

**File:** `gui/favorites_bar/fave_bar.lua`

**Problem 1:** Modal rebuild logic used `player.render_mode`:

```lua
-- PROBLEMATIC CODE (removed):
local is_chart_view = player.render_mode == defines.render_mode.chart or
    player.render_mode == defines.render_mode.chart_zoomed_in
if (player.controller_type == defines.controllers.remote or is_chart_view) and modal_was_open then
  teleport_history_modal.destroy(player, true)
  teleport_history_modal.build(player)
end
```

**The Desync:**
- Client A: Player in chart view → modal rebuilt → modal exists
- Client B: Player NOT in chart view → modal not rebuilt → modal doesn't exist
- **DESYNC:** Different GUI/game state across clients

**Fix:** Only use synchronized game state:

```lua
// CRITICAL: Do NOT use player.render_mode here - it's client-specific and causes desyncs!
// The modal state is tracked in storage which is synchronized, so we can safely rebuild based on that.
local is_remote_controller = player.controller_type == defines.controllers.remote
if is_remote_controller and modal_was_open then
  teleport_history_modal.destroy(player, true)
  teleport_history_modal.build(player)
end
```

**Problem 2:** Bar visibility logic used `player.render_mode`:

```lua
// PROBLEMATIC CODE (removed):
local mode = player and player.render_mode
if not (mode == defines.render_mode.game or mode == defines.render_mode.chart or mode == defines.render_mode.chart_zoomed_in) then
  if player.controller_type == defines.controllers.god or
      player.controller_type == defines.controllers.spectator then
    fave_bar.destroy()
    return
  end
end
```

**Fix:** Only check synchronized controller_type:

```lua
// CRITICAL: Do NOT use player.render_mode to decide whether to destroy the bar!
// render_mode is client-specific and causes desyncs in multiplayer.
// Only check controller_type which is synchronized game state.
if player.controller_type == defines.controllers.god or
    player.controller_type == defines.controllers.spectator then
  local main_flow = GuiHelpers.get_or_create_gui_flow_from_gui_top(player)
  if main_flow and main_flow.valid then
    GuiValidation.safe_destroy_frame(main_flow, Enum.GuiEnum.GUI_FRAME.FAVE_BAR)
  end
  return
end
```

## Log Evidence

From the desync log:

```
38.184 Script: [TeleFaves][DEBUG] Starting notification processing | Context: queue_size=1 
38.184 Script: [TeleFaves][DEBUG] Starting notification processing | Context: queue_size=1 
38.184 Script: [TeleFaves][DEBUG] Starting notification processing | Context: queue_size=1 
38.184 Script: [TeleFaves][DEBUG] Notification batch processed | Context: processed=4 errors=0 
38.184 Script: [TeleFaves][DEBUG] [TAG_EDITOR] handle_confirm_btn: after notify, about to close_tag_editor
38.199 Error GameActionHandler.cpp:2808: Multiplayer desynchronisation: crc test (heuristic) failed
```

This shows:
1. Notification processing started (3 observers processing)
2. Notifications processed successfully
3. **Desync happened immediately after** - indicating GUI rebuild during notification processing caused the issue

## Key Insights

### Module-Level State vs Storage

An important realization: **Module-level variables (like `GuiEventBus._observers`) are NOT synchronized** between clients in Factorio multiplayer.

- Only `storage` (aka `global`) is synchronized
- Module-level tables are created independently on each client
- They can diverge if any client-specific code modifies them

While observers are registered deterministically (in `on_player_created`), any cleanup or modification based on client-specific state (like `player.connected`) will cause divergence.

### Client-Specific State Summary

**Never use these in game-state-changing logic:**
- ❌ `player.render_mode` - view mode varies per client
- ❌ `player.connected` - connection state is client-perspective
- ❌ `player.cursor_stack` - when used to determine behavior (reading for sync is OK)
- ❌ Any observer cleanup during event processing

**Always use these (synchronized game state):**
- ✅ `storage` (global persistence)
- ✅ `player.index`, `player.name`
- ✅ `player.controller_type` (synchronized)
- ✅ `player.force`, `player.surface`
- ✅ Modal state stored in `storage`

## Testing Results

### Before Additional Fixes
- ❌ Tag modification → Favorites bar rebuild → Desync
- ❌ Notification processing → Different cleanup on each client → Desync

### After Additional Fixes
- ✅ Tag modification → Favorites bar rebuilds correctly on all clients → No desync
- ✅ Notification processing → No cleanup, consistent results → No desync
- ✅ All multiplayer tag operations work correctly

## Files Modified
1. `core/events/gui_observer.lua` - Removed cleanup from notification processing
2. `gui/favorites_bar/fave_bar.lua` - Removed render_mode checks from GUI rebuild logic

## Date
2025-01-12 (Same day as initial fix, additional investigation and fixes)
