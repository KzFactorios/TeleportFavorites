# Custom Drag and Drop System Implementation

## Overview

Factorio v2 has NO native drag and drop support in its GUI API. Our mod implements a fully custom drag-and-drop system for the favorites bar.

## Implementation

* We use a completely custom approach combining multiple Factorio GUI events and cursor stack manipulation
* Our implementation uses Shift+Left-Click to initiate dragging and Left-Click to drop
* Right-Click during an active drag operation cancels the drag
* The drag state is tracked in player data storage, not by Factorio's engine

## User Experience

* **Start Drag**: Shift+Left-Click on a favorite slot (unless locked)
* **Drop**: Left-Click on target slot to reorder (unless target is locked)
* **Cancel Drag**: Right-Click anywhere to abort the drag operation
* **Feedback**: Visual cursor feedback and notification messages for all operations

## Changes Made

1. Modified `fave_bar.lua` to include button captions for the slot number.
2. All slot identification logic continues to use the button name, not caption.
3. Maintained both the caption (for Factorio engine) and the child label (for visual consistency).
4. Created documentation in `docs/factorio_quirks.md` to explain this engine limitation.
5. Added right-click cancellation in `gui_event_dispatcher.lua` for improved user experience.
6. Added localization string for drag cancellation feedback.

## Verification

* Drag and drop now works with the caption restored.
* All slot identification logic remains based on button.name parsing.
* Added checks confirmed no logic relies on the caption content.
* Right-click cancellation provides a clean way to abort drag operations.

This fix addresses the Factorio engine quirk while maintaining our coding standards.

## Future Recommendation

Always ensure slot buttons have a non-empty caption to avoid breaking drag/drop functionality in the Factorio engine.
