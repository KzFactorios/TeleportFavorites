# Testing Instructions: Favorites Bar Immediate Update

## Step 1: Enable Debug Mode

Edit `constants.lua` line 12:

**Change FROM:**
```lua
DEFAULT_LOG_LEVEL = "production",
```

**Change TO:**
```lua
DEFAULT_LOG_LEVEL = "debug",
```

## Step 2: Completely Restart Factorio

**IMPORTANT:** Must quit and restart Factorio, not just reload mods!

1. Quit Factorio completely
2. Start Factorio
3. Load your save

## Step 3: Check Observer Registration in Log

Open `factorio-current.log` and search for:

```
[TICK 1] *** REGISTERING GUI OBSERVERS ***
```

You should see:
```
[TICK 1] *** REGISTERING GUI OBSERVERS ***
[TICK 1] Registering observers for player YourName
[GUI_OBSERVER] register_player_observers called
GUI observers registered for player (DataObserver)
[TICK 1] Observers registered successfully
[TICK 1] *** ALL GUI OBSERVERS REGISTERED ***
```

**If you DON'T see these messages, the observers are not being registered!**

## Step 4: Test Favoriting a Tag

1. Right-click a map tag to open tag editor
2. Click the favorite (star) button  
3. **Expected:** Favorites bar updates immediately

## Step 5: Check Notification Flow in Log

Search log for these messages (in order):

```
[TAG_EDITOR] favorite_added notification sent
[GUI_OBSERVER] *** NOTIFICATION DEFERRED TO NEXT TICK ***
[GUI_OBSERVER] *** PROCESSING DEFERRED NOTIFICATION ***
[GUI_OBSERVER] *** CALLING OBSERVER UPDATE ***
[DATA OBSERVER] *** UPDATE CALLED ***
[DATA OBSERVER] Calling fave_bar.build
[FAVE_BAR] ========== BUILD CALLED ==========
```

## Expected Results

✅ **Working:** All messages appear in sequence, bar updates immediately
❌ **Broken:** Missing messages indicate where notification chain breaks

## Common Issues

### Issue: No tick 1 observer registration messages
**Cause:** `storage._observers_registered_this_session` is already set from previous load
**Fix:** Delete your save and create a new game, OR manually edit the save file

### Issue: Observers registered but no notifications received
**Cause:** Observers table got reset after registration
**Fix:** Check if `GuiEventBus.ensure_initialized()` is being called multiple times

### Issue: Notifications received but observer.update not called
**Cause:** Observer count is 0 when processing deferred notifications
**Fix:** Check if observers are being cleaned up prematurely

## Send Me This Info

If it's still not working, send me:

1. The tick 1 section of your log (observer registration)
2. The section when you click favorite (notification flow)
3. Your Factorio version
4. Whether this is a new game or loaded save
