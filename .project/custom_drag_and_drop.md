# Custom Drag and Drop Implementation

## Overview

Factorio v2 provides no native drag and drop functionality in its GUI API. Our mod implements a fully custom drag and drop system for reordering favorites in the favorites bar.

## Implementation Details

### State Management
- Player drag state is tracked in `player_data.drag_favorite`:
  ```lua
  player_data.drag_favorite = {
    active = boolean,         -- Whether a drag operation is in progress
    source_slot = number,     -- The slot index being dragged (1-based)
    favorite = table          -- Copy of the favorite data being dragged
  }
  ```

### Drag Initiation 
- Triggered by `Shift+Left-Click` on a slot button
- Implementation in `control_fave_bar.lua` -> `handle_shift_left_click()`
- Sets the player's cursor stack to display a visual indicator (blueprint with icon)
- Updates player's drag state in data storage

### Visual Feedback
- `CursorUtils.start_drag_favorite()` handles:
  - Setting blueprint icon in cursor stack
  - Setting blueprint label
  - Providing feedback to player

### Drop Operation
- Triggered by `Left-Click` on a target slot
- Implementation in `control_fave_bar.lua` -> `handle_drop_on_slot()`
- Reorders favorites using `DragDropUtils.reorder_slots(favorites, source_idx, dest_idx)`
- Uses **blank-seeking cascade algorithm** for intuitive reordering:
  - Finds blank slots between source and destination
  - Cascades items toward available blanks for natural compaction
  - Handles special cases (adjacent slots, blank destinations) efficiently
  - Respects locked slot boundaries throughout operations
- Refreshes UI to display new order
- Cleans up cursor stack and drag state

### Drag Cancellation
- Automatic cancellation if player leaves favorites bar or presses Escape
- Manual cancellation by `Right-Click` anywhere during drag operation:
  - Works when right-clicking on GUI elements
  - Works when right-clicking on the map view
  - Works when right-clicking on favorite slots
- `CursorUtils.end_drag_favorite()` resets:
  - Cursor stack
  - Drag state data
- User receives feedback message: "Drag operation canceled"
- Tag editor is prevented from opening during/after drag cancellation
- Multi-layered implementation ensures consistent behavior

## Technical Details

1. **Button Naming**
   - All slot buttons use naming pattern: `fave_bar_slot_{index}`
   - Event handlers parse index from button name: `element.name:match("fave_bar_slot_(%d+)")`

2. **Event Flow**
   - `on_gui_click` -> `handle_favorite_slot_click()` -> checks drag state -> routes to appropriate handler
   - If dragging: routes to drop handler
   - If not dragging: routes to normal click/shift-click/ctrl-click handlers

3. **State Verification**
   - All operations check for player/element validity
   - All drag operations validate state before proceeding

4. **Cancellation Handling**
   - Comprehensive right-click detection in multiple layers:
     - `gui_event_dispatcher.lua`: For GUI elements
     - `handlers.lua`: For map view clicks
     - `control_fave_bar.lua`: For favorite slot clicks
   - Intercepts right-clicks during active drag operations
   - Calls `CursorUtils.end_drag_favorite()` and shows notification
   - Sets suppression flag to prevent tag editor from opening
   - Multiple levels of validation ensure consistent behavior
   - Provides consistent user experience regardless of where right-click occurs

## Usage Example

```lua
-- Start drag
if event.button == defines.mouse_button_type.left and event.shift then
  if can_start_drag(fav) then
    start_drag(player, fav, slot)
    return true
  end
end

-- Handle drop
local is_dragging, source_slot = CursorUtils.is_dragging_favorite(player)
if is_dragging and source_slot != slot then
  return reorder_favorites(player, favorites, source_slot, slot)
end

-- Cancel drag on right-click (in gui_event_dispatcher.lua)
if event.button == defines.mouse_button_type.right then
  if player_data.drag_favorite and player_data.drag_favorite.active then
    CursorUtils.end_drag_favorite(player)
    PlayerHelpers.safe_player_print(player, {"tf-gui.fave_bar_drag_canceled"})
    -- Set flag to suppress tag editor opening
    player_data.suppress_tag_editor = { tick = game.tick }
    return true -- Stop event propagation
  end
end
```

This implementation provides a complete drag and drop experience despite Factorio's lack of native support for such interactions.
