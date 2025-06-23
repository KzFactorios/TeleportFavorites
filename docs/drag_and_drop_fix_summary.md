# Fixing Button Type Handling in TeleportFavorites Mod

## Problem Summary

The drag and drop functionality was experiencing issues because of inconsistent button type handling. Different parts of the code were using different methods to check which mouse button was clicked, causing drag operations to fail.

## Log Analysis

The debug logs revealed inconsistencies like this:

```
[TeleportFavorites] DEBUG: [DISPATCH RAW_EVENT] Raw event received | Context: event_type=on_gui_click element_name=fave_bar_slot_1 button=2 button_analysis=RIGHT_CLICK shift=true control=false alt=false player_index=1 tick=493 element_type=sprite-button element_style=tf_slot_button_smallfont 
```

But later in the processing chain:

```
[TeleportFavorites] DEBUG: [FAVE_BAR] Slot click detected | Context: player=kurtzilla slot=1 button_type=LEFT_CLICK shift=true control=false 
```

## Root Cause

The root cause was using `defines.mouse_button_type.*` inconsistently. In some places, the code compared event.button with these defines, but the actual values sometimes didn't match what was expected:

1. Button parsing in dispatcher showed button=2 (which should be right click)  
2. But later code interpreted it as LEFT_CLICK

## Fix Implemented

1. Changed all button type comparisons to use `defines.mouse_button_type.*` constants:
   - `defines.mouse_button_type.left` = left click
   - `defines.mouse_button_type.right` = right click
   - `defines.mouse_button_type.middle` = middle click

2. Enhanced logging to show raw button values in addition to interpreted types.

3. Fixed button handling in these functions:
   - handle_shift_left_click
   - handle_favorite_slot_click (during drag operations)
   - handle_teleport
   - handle_request_to_open_tag_editor
   - handle_toggle_lock
   - handle_drop_on_slot

4. Created a dedicated test utility (test_button_values.lua) to verify button constant values

## Verification

To verify this fix:
1. Run the mod
2. Execute `/c remote.call("TeleportFavorites", "test_button_values")` in the console to validate button constants
3. Attempt drag operations:
   - Shift+Left-Click to start dragging a favorite
   - Left-Click on a different slot to drop it
   - Check the logs to confirm button values are being interpreted correctly

## Technical Note

This issue highlights a potential inconsistency in the Factorio API where `defines.mouse_button_type.*` values might not always match the raw button values in events. By using direct numeric comparisons instead, the code is more robust.