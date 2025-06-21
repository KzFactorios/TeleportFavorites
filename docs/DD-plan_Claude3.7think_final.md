# Drag and Drop Integration Plan - Favorites Bar

## Overview
This document outlines the implementation plan for adding drag-and-drop functionality to the favorites bar in TeleportFavorites mod. This feature will allow players to reorder their favorite teleport locations through an intuitive interface.

## Feature Requirements

- Shift+Left-Click initiates dragging a favorite from its slot
- Visual feedback during drag operations (cursor item and slot styling)
- Ability to drop favorites into new positions (Left-Click)
- Handle locked slots (cannot be moved or targeted)
- Direction-aware shifting of other favorites when reordering
- Detect left/right side of slots for precise insertion

## Components to Modify/Create

1. **PlayerData Structure**
   - Add drag state tracking to player cache

2. **Cursor Manipulation**
   - Functions to add/remove items from player cursor

3. **Event Handlers**
   - Shift+Left-Click handler (drag start)
   - Left-Click handler (drop)
   - Cancel drag handlers (key release, cursor changed)

4. **Reordering Logic**
   - Functions to reorder favorites collection

5. **UI Updates**
   - Visual styling for drag states
   - Slot highlighting for valid/invalid targets

6. **Locale Additions**
   - User feedback messages

## Integration Steps

### Phase 1: Core Structure Setup

1. Add drag state to player data in `Cache.lua`
```lua
-- In player_data structure:
drag_favorite = {
  active = false,
  source_slot = nil,
  favorite = nil
}
```

2. Create cursor manipulation utilities in `core/utils/cursor_utils.lua`
```lua
function add_favorite_to_cursor(player, favorite)
  -- Implementation
end

function clear_favorite_from_cursor(player)
  -- Implementation
end
```

3. Add styles for drag states in `prototypes/styles-fave_bar.lua`

### Phase 2: Event Handler Implementation

1. Update `control_fave_bar.lua` to handle Shift+Left-Click (drag start)
2. Create drop handler for regular Left-Click during active drag
3. Implement drag cancellation logic
4. Add event registration in `gui_event_dispatcher.lua`

### Phase 3: Reordering Logic

1. Add reordering functions to `PlayerFavorites.lua`:
```lua
function PlayerFavorites.reorder(player, source_slot, target_slot)
  -- Implementation
end
```

2. Update UI refresh logic to show drag states

### Phase 4: Testing

1. Test individual components
2. Perform integrated testing
3. Add user feedback and polish

## Challenges & Solutions

### Challenge 1: No Native Drag and Drop API
**Solution**: Use cursor manipulation and internal state tracking to simulate drag operations.

### Challenge 2: No Hover Events
**Solution**: Use visual styling to indicate valid drop targets, detect cursor position on click.

### Challenge 3: Cursor Stack Limitations
**Solution**: Use blueprint items with custom icons as visual indicators.

### Challenge 4: Position Detection
**Solution**: Use `event.cursor_position` and element positions to detect left/right side of slot buttons.

## Testing Plan

1. Test dragging favorites to empty slots
2. Test dragging favorites between populated slots
3. Verify locked slots cannot be moved or targeted
4. Test cancellation mechanisms
5. Verify proper visual feedback during all operations

## Files to Modify

- `core/cache/cache.lua`
- `core/player/player_favorites.lua`
- `core/control/control_fave_bar.lua`
- `core/events/gui_event_dispatcher.lua`
- `gui/favorites_bar/fave_bar.lua`
- `prototypes/styles-fave_bar.lua`
- `locale/en/teleportfavorites.cfg`

## New Files to Create

- `core/utils/cursor_utils.lua` (optional, could be integrated into existing utilities)

## Dependencies

- Depends on existing favorites bar functionality
- Uses Factorio's cursor stack API for visual feedback

## Completion Criteria

- Players can drag and drop favorites to reorder them
- Visual feedback clearly indicates drag operations
- Locked slots are respected
- All edge cases handled gracefully
