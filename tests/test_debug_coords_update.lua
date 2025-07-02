-- test_debug_coords_update.lua
--[[
Test script to debug coordinates label update issues.

TESTING PROCEDURE:
==================

1. Load the game with TeleportFavorites mod
2. Open the console and run these debug commands in sequence:

   a) First, check the overall state:
      /tf-debug-labels

   b) If the label isn't found, check the favorites bar build:
      /tf_force_build_bar

   c) Try to initialize the player's label system:
      /tf-init-player

   d) Check if the tick handler is working:
      /tf-test-tick

   e) Force an immediate coordinate update:
      /tf-update-coords

   f) Move around and check if coordinates update automatically
      If not, re-run /tf-debug-labels to see current state

   g) If needed, reinitialize the entire system:
      /tf-reinit-labels

EXPECTED BEHAVIOR:
=================
- show-player-coords setting should be enabled (true)
- coords_label should be found in GUI hierarchy
- Tick handler should be registered when setting is enabled
- Player should be in enabled_players table
- Label should update automatically as player moves
- Manual updates should work with /tf-update-coords

COMMON ISSUES TO CHECK:
======================
1. Label not found in GUI hierarchy
   → Bar not built properly, use /tf_force_build_bar

2. Setting is disabled
   → Check mod settings, enable "Show player coordinates"

3. Tick handler not registered
   → Use /tf-init-player to register the player

4. Player not in enabled_players table
   → Use /tf-test-tick to force registration

5. Label found but not updating
   → Check if tick handler is actually being called (debug logs)

RECENT FIXES APPLIED:
====================
- Fixed infinite re-registration of tick handlers
- Added proper debug logging to track handler registration
- Fixed issue where handler was unregistered incorrectly
- Improved player state tracking in enabled_players table
- Added comprehensive debug commands

DEBUG LOG MESSAGES TO LOOK FOR:
==============================
[LABELS] update_label_for_player for player_coords...
[LABELS] update_handler_registration for player_coords...
[LABELS] Registering tick handler for player_coords...
[LABELS] Tick handler for player_coords at tick...

If you don't see these messages, the handler isn't being called properly.
]]

-- This test file documents the debugging process for coordinates label updates.
-- Use the in-game debug commands listed above to troubleshoot label update issues.
