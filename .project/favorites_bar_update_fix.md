# Fix: Favorites Bar Not Updating After Tag Deletion

## Problem

When right-clicking a favorite in the favorites bar to open the tag editor, then deleting the tag from the tag editor, the favorites bar was not updating to reflect the deletion. The slot remained showing the deleted favorite until the player manually refreshed the bar or changed surfaces.

## Root Cause

The issue was caused by duplicate `on_tick` event handler registrations that were overwriting each other:

1. **First Registration** (event_registration_dispatcher.lua line 281):
   ```lua
   script.on_event(defines.events.on_tick, function(event)
     GuiObserver.GuiEventBus.process_deferred_notifications()
   end)
   ```
   This handler processes deferred GUI notifications, including `favorite_removed` events.

2. **Second Registration** (control.lua line 88):
   ```lua
   script.on_event(defines.events.on_tick, function(event)
     if global and not global.did_run_fave_bar_startup then
       global.did_run_fave_bar_startup = true
       -- ... startup initialization
     end
   end)
   ```
   This handler performs run-once startup initialization.

**The Problem:** Factorio only allows ONE handler per event type. When `control.lua` registered its `on_tick` handler AFTER the event dispatcher, it **completely overwrote** the deferred notification processing handler.

### Event Flow (Before Fix)

1. User deletes tag from tag editor
2. `handle_delete_confirm()` fires `favorite_removed` notification
3. `GuiEventBus.notify()` defers the notification to next tick (because it's a GUI event)
4. Notification gets queued in `_deferred_queue`
5. **On next tick:** startup handler runs, but doesn't process deferred queue
6. Deferred notifications are NEVER processed
7. Favorites bar never updates

## Solution

Merged both handlers into a single `on_tick` handler that performs BOTH tasks:
1. Run-once startup initialization
2. Process deferred GUI notifications every tick

### Implementation

**event_registration_dispatcher.lua (lines 281-294):**
```lua
-- MULTIPLAYER FIX: Process deferred GUI notifications every tick
-- This ensures GUI updates happen separately from game logic events, preventing desyncs
-- ALSO handles run-once startup initialization for favorites bar
script.on_event(defines.events.on_tick, function(event)
  -- Run-once startup handler for favorites bar initialization
  if global and not global.did_run_fave_bar_startup then
    global.did_run_fave_bar_startup = true
    if GuiObserver and GuiObserver.GuiEventBus and GuiObserver.GuiEventBus.register_player_observers then
      for _, player in pairs(game.players) do
        GuiObserver.GuiEventBus.register_player_observers(player)
      end
    end
  end
  
  -- Process deferred GUI notifications every tick
  GuiObserver.GuiEventBus.process_deferred_notifications()
end)
```

**control.lua (lines 83-86):**
```lua
-- Register all mod events through centralized dispatcher
event_registration_dispatcher.register_all_events(script)

-- NOTE: on_tick handler is registered inside event_registration_dispatcher.register_core_events
-- It handles BOTH deferred GUI notifications AND run-once startup initialization
-- DO NOT register another on_tick handler here as it would overwrite the deferred notification processing!
```

## Why Deferred Notifications?

The mod uses deferred notifications for GUI updates to prevent multiplayer desyncs. GUI-related events (`favorite_added`, `favorite_removed`, `cache_updated`, etc.) are automatically deferred to the next tick to ensure GUI updates happen AFTER game logic events complete.

From `gui_observer.lua` lines 85-90:
```lua
local gui_event_types = {
  cache_updated = true,
  favorite_added = true,
  favorite_removed = true,
  favorite_updated = true,
  tag_modified = true,
  tag_created = true,
  tag_deleted = true
}
```

This prevents desyncs that occur when GUI code runs during game logic events like `on_chart_tag_added`.

## Impact

This fix ensures:

✅ **Favorites bar updates immediately** after deleting a tag  
✅ **Startup initialization still works** (run-once observer registration)  
✅ **Deferred notifications are processed** every tick  
✅ **Multiplayer sync is maintained** (GUI updates deferred properly)  
✅ **No duplicate event handlers** causing conflicts

## Testing

- ✅ All existing tests pass (4/4)
- ✅ No new lint errors (only pre-existing warnings about runtime globals)
- ✅ Verified both startup initialization and deferred notification processing work together

## Files Modified

1. **core/events/event_registration_dispatcher.lua**
   - Merged startup initialization into on_tick handler (lines 281-294)
   - Added comment explaining dual purpose of handler

2. **control.lua**
   - Removed duplicate on_tick handler registration (lines 83-86)
   - Added warning comment to prevent future duplicates

3. **changelog.txt**
   - Documented the fix under Version 0.0.8 bugfixes

## Related Code

**Notification Flow:**
1. `control_tag_editor.lua:506` - Fires `favorite_removed` event
2. `control_shared_utils.lua:21` - Calls `GuiEventBus.notify()`
3. `gui_observer.lua:82` - Defers notification to next tick
4. `event_registration_dispatcher.lua:293` - Processes deferred queue on tick
5. `gui_observer.lua:545` - DataObserver rebuilds favorites bar

## Version Information

- **Fixed in**: Version 0.0.8
- **Status**: Complete and tested
- **Breaking Changes**: None
- **Performance Impact**: Minimal (startup check is O(1) after first tick)

## Lessons Learned

1. **Never register the same event handler twice** - Factorio silently overwrites previous registrations
2. **Centralize event registration** - All event handlers should be registered from one place
3. **Document handler locations** - Add comments warning against duplicate registrations
4. **Test deferred notifications** - Verify that deferred queue processing is actually working

## Future Prevention

Added explicit warning comment in `control.lua` to prevent accidentally registering another `on_tick` handler in the future.
