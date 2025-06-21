## Plan for Implementing Drag and Drop Reordering in TeleportFavorites

This plan outlines how to add intuitive drag-and-drop reordering of favorite slots in the favorites bar for the TeleportFavorites Factorio mod, given the lack of built-in drag-and-drop support. The approach leverages creative use of the cursor stack, GUI events, and visual feedback, while respecting locked slots and providing clear user interaction cues.

---

**1. Drag Initiation: Detecting Shift + Left Click**

- Listen for GUI click events on favorite slots.
- On Shift + Left Click:
  - Verify the slot is not locked.
  - Mark the slot as the "drag source" internally.
  - Add the favorite's icon to the player's cursor stack:
    - Preferably as a slot button with the favorite's icon.
    - If not possible, fallback to just the icon, or use the default `tf_slot_button_smallfont_map_pin`.
  - Visually indicate the slot is being dragged (e.g., highlight or outline).
- Store the original slot index and data for later use.

---

**2. Drag Tracking: Mouse Movement and Hover Feedback**

- While the drag is active (Shift held and cursor stack contains the favorite):
  - Track the mouse position over the favorites bar.
  - On hover over other slots:
    - If the slot is locked, do not highlight or allow as a drop target.
    - For eligible slots, highlight them and show a visual indicator for insertion:
      - If the cursor is on the left half, show a left-side insertion marker.
      - If on the right half, show a right-side insertion marker.
  - Optionally, dim or gray out locked slots to reinforce their immovability.

---

**3. Drop Handling: Completing the Reorder**

- The drag ends when the player:
  - Releases the left mouse button, or
  - Releases the Shift key.
- On drop:
  - Determine the target slot and insertion side (left/right).
  - If the target is a locked slot, ignore and cancel the drag.
  - If the drag source index is less than the target, shift intervening slots left; if greater, shift right.
  - Insert the dragged favorite into the new position, updating the favorites collection accordingly.
  - Remove the icon from the cursor stack.
  - Refresh the favorites bar UI to reflect the new order.
  - Clear all drag-related highlights and state.

---

**4. Visual and UX Feedback**

- Use Factorio-style GUI highlights for drag source, drop targets, and insertion points.
- Ensure locked slots are visually distinct and never highlighted as drop targets.
- Provide subtle sound or animation cues on drag start and drop, if feasible.
- Ensure the cursor stack always reflects the dragged favorite, or the fallback icon if unavailable.

---

**5. Edge Cases and Robustness**

- If the drag is canceled (e.g., the cursor leaves the bar, or the player presses Escape), clear the cursor stack and reset all highlights.
- Prevent dropping onto the original slot (no-op).
- Ensure multi-player safety: all drag state should be per-player.
- Handle rapid Shift/click events gracefully to avoid state desync.

---

## Implementation Steps in Codebase

1. **Extend GUI Event Handlers**
   - Modify the GUI event handler to detect Shift + Left Click on favorite slots.
   - Add logic to start a drag operation, set internal drag state, and update the cursor stack.

2. **Cursor Stack Management**
   - Use Factorio's Lua API to set the cursor stack with the appropriate icon or fallback.
   - Ensure the cursor stack is cleared on drag end or cancel.

3. **Slot Highlighting and Insertion Markers**
   - Update slot rendering to show highlights and insertion markers based on mouse position and drag state.
   - Use Factorio's GUI styling for consistency.

4. **Drag State Machine**
   - Maintain a per-player drag state (drag source index, favorite data, etc.).
   - Track mouse-over events on slots to update highlights and determine drop targets.

5. **Favorites Collection Update**
   - On drop, update the favorites array according to the insertion logic (shift left/right, insert at correct position).
   - Ensure locked slots are never moved or overwritten.

6. **UI Refresh and Cleanup**
   - Redraw the favorites bar after reordering.
   - Remove all visual indicators and reset drag state.

---

## Styling and Factorio Idioms

- Follow Factorio's established UI idioms for slot buttons, highlights, and cursor stack visuals.
- Use the mod's existing localization and styling utilities for any new text or tooltips[1].
- Document all new APIs and logic for maintainability.

---

## Summary Table

| Step                 | Action                                  | Visual Feedback                | Constraints           |
|----------------------|-----------------------------------------|-------------------------------|-----------------------|
| Drag Start           | Shift+Left Click on slot                | Icon in cursor stack, highlight| Slot must be unlocked |
| Drag Tracking        | Mouse over slots                        | Highlight, insertion marker    | Locked slots ignored  |
| Drop                 | Release mouse/Shift                     | Slot order updates, clear icon | No drop on locked     |
| Cancel Drag          | Escape/leave bar                        | Reset UI, clear icon           |                       |

---

This plan leverages creative use of the Factorio GUI API and cursor stack to deliver an intuitive drag-and-drop reordering feature, while respecting locked slots and providing clear, idiomatic feedback to users[1][2][3].

[1] https://github.com/KzFactorios/TeleportFavorites
[2] programming.game_modding
[3] programming.ui_customization
[4] https://developer.android.com/codelabs/codelab-dnd-views?authuser=19
[5] https://www.reddit.com/r/runescape/comments/lfaddk/i_like_the_teleportation_improvement_stuff_but/
[6] https://github.com/decentraland/proposals/issues/59
[7] https://gamefaqs.gamespot.com/boards/678050-final-fantasy-xiv-online-a-realm-reborn/77824684
[8] https://www.youtube.com/watch?v=jskGEKbqNAs
[9] https://www.esoui.com/downloads/info2143-BeamMeUp-TeleporterFastTravel.html
[10] https://mods.factorio.com/mod/QuickMapTagTeleport
[11] https://www.reddit.com/r/Cityofheroes/comments/1bbw9zt/psa_easy_oneclick_teleports_at_your_cursor/
[12] https://apps.apple.com/us/app/cursor-teleporter/id6471482080?mt=12
[13] https://www.youtube.com/watch?v=gqMJ63r-Wbg