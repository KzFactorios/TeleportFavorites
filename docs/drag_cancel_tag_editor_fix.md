# Drag Cancellation & Tag Editor Interaction Fix

## Issues Addressed
1. When a user was dragging a favorite and right-clicked to cancel the drag operation, the tag editor would open immediately afterward, creating a confusing user experience.
2. Right-clicking on the map during a drag operation wouldn't cancel the drag properly.

## Root Causes
1. The right-click event in GUI contexts was correctly detected but was propagating to other handlers
2. Right-clicks on the map weren't being processed by the GUI event dispatcher at all
3. The tag editor input handler wasn't canceling drag operations

## Solution Implementation

### 1. Multi-layered Defense

We implemented a comprehensive solution with multiple safeguards to prevent the tag editor from opening during drag cancellation:

#### Layer 1: GUI Event Dispatcher - Event Propagation Control
- Location: `gui_event_dispatcher.lua`
- Added proper return value (`return true`) after handling right-click drag cancellation
- Prevents event from propagating to other handlers
- Sets a suppression flag at the player data level to prevent tag editor from opening

```lua
if event.button == defines.mouse_button_type.right then
  if player_data.drag_favorite and player_data.drag_favorite.active then
    CursorUtils.end_drag_favorite(player)
    GameHelpers.player_print(player, {"tf-gui.fave_bar_drag_canceled"})
    
    -- Set a flag to prevent tag editor opening on this tick
    if not player_data.suppress_tag_editor then
      player_data.suppress_tag_editor = {}
    end
    player_data.suppress_tag_editor.tick = game.tick
    
    _tf_gui_click_guard = false
    return true -- Return true to indicate event was handled and stop propagation
  end
end
```

#### Layer 2: Tag Editor Custom Input Handler - Drag Check & Cancel
- Location: `handlers.lua`
- Added check in `on_open_tag_editor_custom_input` to detect active drag operations
- Now actively cancels drag operations when right-clicking on the map
- Prevents tag editor from opening if a drag is in progress
- Also checks for the suppression flag set by the GUI event dispatcher

```lua
-- Check if player is currently in drag mode, if so, don't open tag editor and cancel the drag
local player_data = Cache.get_player_data(player)
if player_data and player_data.drag_favorite and player_data.drag_favorite.active then
  ErrorHandler.debug_log("[TAG EDITOR] Canceling drag operation and aborting tag editor open", 
    { player = player.name, source_slot = player_data.drag_favorite.source_slot })
  
  -- Cancel the drag operation here since right-clicks on map don't go through gui_event_dispatcher
  CursorUtils.end_drag_favorite(player)
  GameHelpers.player_print(player, {"tf-gui.fave_bar_drag_canceled"})
  
  return
end

-- Check if tag editor opening was suppressed due to a recent drag cancellation
if player_data and player_data.suppress_tag_editor and 
   player_data.suppress_tag_editor.tick and 
   player_data.suppress_tag_editor.tick == game.tick then
  ErrorHandler.debug_log("[TAG EDITOR] Suppressing tag editor open on same tick as drag cancellation", 
    { player = player.name, tick = game.tick })
  return
end
```

#### Layer 3: Control Fave Bar - Tag Editor Request Handler
- Location: `control_fave_bar.lua`
- Modified `handle_request_to_open_tag_editor` to check for active drags
- Prevents tag editor from opening if called during a drag operation

```lua
local function handle_request_to_open_tag_editor(event, player, fav, slot)
  if event.button == defines.mouse_button_type.right then
    -- Check if player is currently in a drag operation
    local is_dragging, _ = CursorUtils.is_dragging_favorite(player)
    if is_dragging then
      -- Don't open tag editor during drag operations
      return false
    end
    
    if fav and not FavoriteUtils.is_blank_favorite(fav) then
      open_tag_editor_from_favorite(player, fav)
      return true
    end
  end
  return false
end
```

#### Layer 4: Favorite Slot Right-Click Handler
- Location: `control_fave_bar.lua`
- Modified `handle_favorite_slot_click` to check for right-clicks during drag
- Properly cancels drag operations when right-clicking on favorite slots
- Provides feedback to the user

```lua
-- First check if we're in drag mode and this is a drop or cancel
local is_dragging, source_slot = CursorUtils.is_dragging_favorite(player)
if is_dragging then
  -- Check if this is a right-click to cancel the drag
  if event.button == defines.mouse_button_type.right then
    ErrorHandler.debug_log("[FAVE_BAR] Right-click detected during drag, canceling drag operation", 
      { player = player.name, source_slot = source_slot })
    end_drag(player)
    GameHelpers.player_print(player, {"tf-gui.fave_bar_drag_canceled"})
    return
  end
  
  -- This is a drop attempt
  if handle_drop_on_slot(event, player, slot, favorites) then return end
  
  -- If we get here, the drop didn't work, but we need to exit drag mode anyway
  end_drag(player)
  return
end
```

### 2. Documentation & Testing

- Updated `custom_drag_and_drop.md` with detailed information about drag cancellation
- Created test files with comprehensive test scenarios:
  - `test_drag_cancel.lua` for general drag cancellation testing
  - `test_tag_editor_suppression.lua` for specific tag editor interaction testing
  - `test_map_rightclick_cancel.lua` for map-specific right-click testing
  - `test_drag_right_click_integration.lua` for comprehensive integrated testing
- Added test cases for verifying correct behavior

## Testing

Manual testing should verify:

1. Drag cancellation works correctly when right-clicking anywhere:
   - On GUI elements in the game interface
   - On the map view
   - On favorite slots in the favorites bar
2. Tag editor does not open when canceling drag with right-click
3. Tag editor opens normally when right-clicking without an active drag
4. Multiple drag-cancel operations work consistently

We've added a integration test script `test_drag_right_click_integration.lua` that documents all the expected behaviors and test scenarios to verify the fix is working properly.

## Implementation Note

The multi-layered approach provides redundant protection against the issue. Even if one check fails, the others will prevent the unwanted behavior, ensuring a consistent user experience.

## Summary of Changes

1. Modified `gui_event_dispatcher.lua` to properly stop event propagation
2. Updated `handlers.lua` to cancel drags on map right-clicks
3. Enhanced `control_fave_bar.lua` to handle right-clicks on favorite slots during drag
4. Added comprehensive test files and documentation
5. Added user feedback for all drag cancellation operations
