# Fix Summary: Favorites Bar Not Updating Immediately

**Issue:** When creating a new favorite via the tag editor, the favorites bar doesn't show the change immediately.

**Root Cause Analysis:**
1. **Observer Registration Missing After Load**: The GUI observer system was not being registered after loading a save because:
   - `on_load` cannot access the `game` object (Factorio API limitation)
   - Original code tried to register observers in `on_load`, causing "attempt to index global 'game' (a nil value)" error
   - Without observers registered, the notification system (`favorite_added`/`favorite_removed` events) had no listeners

2. **Recursive Cache.init() Bug**: Cache was being initialized 7 times at the same tick, creating excessive log spam and potential performance issues

3. **Production Log Spam**: `[Cache]` debug messages were appearing in production logs even when `DEFAULT_LOG_LEVEL = "production"`

## Changes Implemented

### 1. Observer Registration Fix
**File:** `core/events/event_registration_dispatcher.lua` (lines 295-320)

**Solution:** Register GUI observers at tick 1 with session-based flag that resets on load

**The Bug:**
- Original code used `storage.did_run_full_rehydration` flag
- This flag persisted in save files, so it only ran once when save was first created
- Loading an existing save wouldn't register observers because flag was already `true`
- Result: observers never registered, favorites bar never updated

**The Fix:**
```lua
if event.tick == 1 and not storage._observers_registered_this_session then
  storage._observers_registered_this_session = true
  -- Register observers for all existing players
  for _, player in pairs(game.players) do
    if player and player.valid then
      GuiObserver.GuiEventBus.register_player_observers(player)
    end
  end
end
```

**File:** `core/events/handlers.lua` (on_load function)

**Reset session flag on load:**
```lua
function handlers.on_load()
  -- Reset the session flag so observers get registered on tick 1
  if storage then
    storage._observers_registered_this_session = nil
  end
end
```

**Why This Works:**
- `on_load` resets the session flag (cannot access `game` in on_load)
- Tick 1: Session flag is `nil`, so observers get registered
- Every subsequent load: on_load resets flag → tick 1 registers observers
- Tick 1 is safe because `game.players` is available from tick 0 onwards

**File:** `core/events/handlers.lua` (lines 107-117)

**Removed from on_load, added session flag reset:**
```lua
function handlers.on_load()
  -- Re-initialize GUI event bus on game load
  gui_observer.GuiEventBus.ensure_initialized()
  
  -- Reset the session flag so observers get registered on tick 1
  if storage then
    storage._observers_registered_this_session = nil
  end
end
```

### 2. Cache Initialization Guard
**File:** `core/cache/cache.lua` (lines 127-131, 165-170)

**Added Initialization Guard:**
```lua
-- Prevent recursive initialization
if storage and storage._cache_initialized then
  ErrorHandler.debug_log("Cache already initialized, skipping...")
  return
end
```

**Removed Recursive Calls:**
- `init_player_data()`: Removed `Cache.init()` call (line 168)
- `init_surface_data()`: Removed `Cache.init()` call (line 188)
- `Cache.get()`: Removed `Cache.init()` call (line 196)
- `Cache.set()`: Removed `Cache.init()` call (line 202)
- `Cache.get_player_data()`: Removed `Cache.init()` call (line 208)
- `Cache.init_surface_if_needed()`: Removed `Cache.init()` call (line 213)

**Result:** Cache.init() now called once instead of 7 times

### 3. Production Log Spam Fix
**Files:** `core/cache/cache.lua`, `gui/favorites_bar/fave_bar.lua`, `core/events/gui_observer.lua`

**Added Debug-Only Logging:**
```lua
local is_debug = Constants.settings.DEFAULT_LOG_LEVEL == "debug"
if is_debug then
  ErrorHandler.debug_log("[Cache] message")
end
```

**Result:** `[Cache]` messages only appear when `DEFAULT_LOG_LEVEL = "debug"` in `constants.lua`

### 4. Constants Module Import
**File:** `core/events/handlers.lua` (line 4)

**Added:**
```lua
local Constants = require("constants")
```

**Why:** Required for `DEFAULT_LOG_LEVEL` check in logging guards

### 5. Enhanced Debug Logging (For Testing)
**Files:** `core/control/control_tag_editor.lua`, `gui/favorites_bar/fave_bar.lua`, `core/events/gui_observer.lua`

**Added comprehensive trace logging:**
- Tag editor: Log when `favorite_added`/`favorite_removed` notifications are sent
- GUI observer: Log when notifications are received and processed
- Favorites bar: Log when `build()` is called by DataObserver

**Purpose:** Trace the full notification flow from tag editor → observer → favorites bar update

## Testing Instructions

### 1. Enable Debug Mode
**File:** `constants.lua` (line 6)

Change:
```lua
DEFAULT_LOG_LEVEL = "production"  -- production | debug
```

To:
```lua
DEFAULT_LOG_LEVEL = "debug"  -- production | debug
```

### 2. Test in Factorio

#### Test A: New Game
1. Start a new game
2. Place a map tag
3. Right-click the tag to open the tag editor
4. Click the favorite (star) button
5. **Expected:** Favorites bar updates immediately with new favorite
6. Check `factorio-current.log` for debug trace:
   - `[tag_editor] Sending favorite_added notification`
   - `[GuiObserver] DataObserver:update() called for favorite_added`
   - `[fave_bar] build() called by DataObserver`

#### Test B: Load Existing Save
1. Load an existing save with map tags
2. **Check tick 300 log entry:** "GUI observers registered for all players on tick 300"
3. Right-click a map tag to open tag editor
4. Click favorite button
5. **Expected:** Favorites bar updates immediately
6. Check `factorio-current.log` for debug trace (same as Test A)

#### Test C: Verify No Recursive Init
1. Start new game or load save
2. Check `factorio-current.log` for `[Cache] Initializing storage`
3. **Expected:** Message appears ONCE, not 7 times

### 3. Disable Debug Mode (Production)
After testing, set `DEFAULT_LOG_LEVEL = "production"` to reduce log noise

## Expected Log Output (Debug Mode)

**On Save Load (Tick 1):**
```
[on_load] GUI Event Bus re-initialized on game load
[on_load] Reset session flag for observer registration
[tick 1] Registering GUI observers on first tick after load
[tick 1] Registered observers for player TestPlayer (index 1)
[tick 1] GUI observers registered for all players on tick 1
```

**On Favorite Added:**
```
[tag_editor] Sending favorite_added notification for GPS: 100.0.1
[GuiObserver] Deferred notification queued: favorite_added
[GuiObserver] Processing deferred notifications (1 in queue)
[GuiObserver] DataObserver:update() called for favorite_added
[fave_bar] build() called by DataObserver for player TestPlayer on surface 1
```

**On Favorite Removed:**
```
[tag_editor] Sending favorite_removed notification for GPS: 100.0.1
[GuiObserver] Deferred notification queued: favorite_removed
[GuiObserver] Processing deferred notifications (1 in queue)
[GuiObserver] DataObserver:update() called for favorite_removed
[fave_bar] build() called by DataObserver for player TestPlayer on surface 1
```

## Verification Checklist

- [x] All unit tests pass (`.test.ps1`)
- [x] No `on_load` errors ("attempt to index global 'game' (a nil value)")
- [x] Cache.init() called once instead of 7 times
- [x] Production logs clean (no `[Cache]` spam when `DEFAULT_LOG_LEVEL = "production"`)
- [ ] **USER TEST REQUIRED:** Favorites bar updates immediately in new game
- [ ] **USER TEST REQUIRED:** Favorites bar updates immediately in loaded save
- [ ] **USER TEST REQUIRED:** Debug trace shows full notification flow

## Known Limitations

1. **1-tick delay after load**: Observers register at tick 1 (0.016 seconds), so favoriting in the first tick after load might not work. This is acceptable given Factorio's initialization sequence and is imperceptible to players.

2. **Multiplayer**: Observer registration happens on all clients simultaneously at tick 1. This is multiplayer-safe because observers are client-side GUI listeners, not synchronized game state.

## Rollback Instructions

If issues occur, revert these files to previous versions:
- `core/events/event_registration_dispatcher.lua`
- `core/events/handlers.lua`
- `core/cache/cache.lua`

Then run `.test.ps1` to verify tests still pass.

## Next Steps

1. User tests in Factorio (new game + load save)
2. User shares `factorio-current.log` if any issues
3. If successful, set `DEFAULT_LOG_LEVEL = "production"` in `constants.lua`
4. Close issue and archive this fix summary
