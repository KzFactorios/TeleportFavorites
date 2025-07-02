-- This file provides debugging instructions for the coordinates update issue.
-- Run these tests in-game to diagnose the problem:

--[[
DEBUGGING STEPS:
================

1. First, enable the coordinates setting:
   - Go to Settings > Mod settings > Player
   - Enable "Show player coordinates"

2. Check if the favorites bar is built:
   - Type: /tf_force_build_bar

3. Check the current state of the label system:
   - Type: /tf-debug-labels
   - Look for:
     * "coords_label found: true"
     * "show-player-coords setting: true"
     * "tick handler registered: true"
     * "this player enabled: true"

4. If the tick handler is not registered, try:
   - Type: /tf-init-player

5. Test if the tick handler can work manually:
   - Type: /tf-test-tick

6. Try forcing a coordinate update:
   - Type: /tf-update-coords

7. If none of the above work, restart the label system:
   - Type: /tf-reinit-labels

EXPECTED BEHAVIOR:
==================
- After step 3, you should see the coordinates appear in the favorites bar
- The coordinates should update automatically as you move around
- Manual updates with /tf-update-coords should work immediately

LIKELY ISSUES:
==============
1. Setting not enabled -> Enable in mod settings
2. Label not found -> Bar not built, use /tf_force_build_bar
3. Tick handler not registered -> Use /tf-init-player
4. Player not enabled -> Use /tf-test-tick to force registration
5. Handler registered but not calling -> Check debug logs for tick messages

Look for debug messages like:
[LABELS] update_handler_registration for player_coords...
[LABELS] Registering tick handler for player_coords...
[LABELS] Tick handler for player_coords at tick...

If you don't see these messages, the system isn't working correctly.
]]

-- Use the in-game debug commands to troubleshoot the coordinates update issue.
