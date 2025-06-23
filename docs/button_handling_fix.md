# Button Handling Fix for Drag and Drop Functionality

## Problem Analysis

We identified an inconsistency in how mouse button clicks were being interpreted in the TeleportFavorites mod:

1. In the dispatcher logs, button=2 would correctly identify as a RIGHT_CLICK
2. Yet within handler functions, those same clicks would sometimes be incorrectly identified as LEFT_CLICK

This mismatch appears to be related to how button values are compared against `defines.mouse_button_type.*` constants.

## Solution Implemented

We've implemented a consistent approach to button handling across the mod:

1. **Defines-Based Comparisons**: All button handling now uses `defines.mouse_button_type.*` constants:
   - `defines.mouse_button_type.left` = Left Click
   - `defines.mouse_button_type.right` = Right Click
   - `defines.mouse_button_type.middle` = Middle Click

2. **Enhanced Debugging**: Added comprehensive logging of both raw button values and the interpretation as click types.

3. **Files Modified**:
   - `core/control/control_fave_bar.lua` - Updated all button handlers
   - `core/events/gui_event_dispatcher.lua` - Updated button detection in central dispatcher
   - `core/utils/cursor_utils.lua` - Enhanced drag state management

4. **Key Function Updates**:
   - `handle_favorite_slot_click`: Improved detection of left-click drop operations
   - `handle_shift_left_click`: Updated to use direct button value comparison
   - `handle_drop_on_slot`: Enhanced failure handling and reporting
   - `handle_teleport` and `handle_toggle_lock`: Updated to use direct button values

5. **Testing Tools Created**:
   - `test_button_values.lua`: Tests and displays button constant values
   - `test_button_direct_values.lua`: Validates direct numeric button comparisons

## Validation Process

To confirm the fix is working correctly:

1. Run the mod and execute: `/c remote.call("TeleportFavorites", "test_button_values")`
2. Verify the constants match the expected values
3. Test the drag and drop workflow:
   - Shift+Left-click to start dragging
   - Left-click on target slot to drop
   - Check debug logs to ensure proper button detection

## Technical Note

This issue highlights a potential inconsistency in how the Factorio API's `defines.mouse_button_type.*` constants are compared against raw event button values in some contexts. Using direct numeric comparisons provides a more reliable approach.

## References

- `docs/factorio_quirks.md` - Documentation of Factorio engine quirks
- `docs/custom_drag_and_drop.md` - Custom drag and drop implementation details
