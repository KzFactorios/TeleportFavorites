# Factorio Engine Quirks

This document describes quirks, limitations, and workarounds in the Factorio engine that affect our mod implementation.

## GUI Quirks

### NO Native Drag and Drop Support in Factorio

**Key Fact:** Factorio v2 has NO native drag and drop functionality in its GUI API. Our mod implements a fully custom drag-and-drop system.

**Implementation:** Our custom system uses:
- Shift+Left-Click to initiate dragging
- Player cursor stack manipulation for visual feedback
- Player data storage for drag state tracking
- Left-Click to drop at target position
- Right-Click to cancel drag operation

**Drag Cancellation:**
- Since Factorio has no native concept of drag cancellation, we intercept right-clicks during an active drag operation
- The right-click detection is centralized in `gui_event_dispatcher.lua` to catch all GUI click events
- When a right-click is detected during drag, we end the drag operation and notify the player

**Button Caption Quirks:**
- All slot identification must be done via button name (e.g., `fave_bar_slot_1`), not button caption.
- In `fave_bar.lua`, we set the slot button caption to the slot number to satisfy Factorio's engine requirements.
- We also display the slot number using a child label for visual consistency.
- No logic in the mod should ever rely on button.caption for anything related to slot identification.

**Example:**
```lua
local btn = GuiUtils.create_slot_button(parent, "fave_bar_slot_" .. i, sprite, tooltip, { style = style })
if btn and btn.valid then
  btn.caption = tostring(i)  -- Required for Factorio's drag-and-drop to work
  GuiBase.create_label(btn, "tf_fave_bar_slot_number_" .. tostring(i), tostring(i), "tf_fave_bar_slot_number")
end
```
