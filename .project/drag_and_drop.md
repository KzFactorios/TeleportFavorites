# Custom Drag and Drop & Algorithm

## Overview

TeleportFavorites implements a fully custom drag and drop system for reordering favorites in the favorites bar, using a blank-seeking cascade algorithm for intuitive slot management. Factorio v2 provides no native drag and drop GUI support, so this mod handles all logic, state, and feedback manually.

---

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

---

## Drag and Drop Algorithm

### Function Signature
```lua
function DragDropUtils.reorder_slots(favorites, source_idx, dest_idx)
-- Returns: (modified_slots, success, error_message)
```

### Core Logic Flow

#### 1. Validation Phase
- Validates source is not blank or locked
- Validates destination is not locked
- Validates indices are within bounds
- Returns early with error if any validation fails

#### 2. Simple Cases (Fast Path)
```lua
-- Case A: Moving to blank destination
if is_blank(dest) then
    return simple_swap(source, dest)
end

-- Case B: Adjacent slots (distance = 1)
if math.abs(source_idx - dest_idx) == 1 then
    return simple_swap(source, dest)
end
```

#### 3. Complex Case: Blank-Seeking Cascade

**Step 1: Source Evacuation**
```lua
-- Source immediately becomes blank, creating cascade target
local source_favorite = slots[source_idx]
slots[source_idx] = { gps = BLANK_GPS, locked = false }
```

**Step 2: Blank Detection Between Source and Destination**
```lua
local blank_idx = source_idx  -- Default: cascade to source position

if source_idx < dest_idx then
    -- Moving rightward: scan left from dest-1 to source+1
    for i = dest_idx - 1, source_idx + 1, -1 do
        if is_blank(slots[i]) and not slots[i].locked then
            blank_idx = i
            break
        end
    end
else
    -- Moving leftward: scan right from dest+1 to source-1
    for i = dest_idx + 1, source_idx - 1 do
        if is_blank(slots[i]) and not slots[i].locked then
            blank_idx = i
            break
        end
    end
end
```

**Step 3: Cascade Items Toward Blank**
```lua
if source_idx < dest_idx then
    -- Rightward move: cascade items leftward to fill blank
    for i = blank_idx, dest_idx - 1 do
        if slots[i + 1] and not slots[i + 1].locked then
            slots[i] = slots[i + 1]  -- Shift left
        end
    end
else
    -- Leftward move: cascade items rightward to fill blank
    for i = blank_idx, dest_idx + 1, -1 do
        if slots[i - 1] and not slots[i - 1].locked then
            slots[i] = slots[i - 1]  -- Shift right
        end
    end
end
```

**Step 4: Place Source at Destination**
```lua
slots[dest_idx] = source_favorite
```

---

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

---

## Behavior Example

### Example: Rightward Move with No Intermediate Blanks
**Initial**: `[A][B][C][D][E][F][G][H][I][J]`
**Action**: Drag slot 1 (A) → slot 4 (D)

1. Source evacuation: `[_][B][C][D][E][F][G][H][I][J]`
2. No blanks found between positions 2-3, cascade target = position 1
3. Cascade leftward: `[B][C][D][_][E][F][G][H][I][J]`
4. Place A at destination: `[B][C][A][D][E][F][G][H][I][J]`
