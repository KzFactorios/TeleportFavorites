-- core/utils/drag_drop_utils.lua
-- Utilities for drag and drop operations in the favorites bar
--
-- This module encapsulates the complex logic for reordering favorites through
-- drag and drop operations. It handles various scenarios including:
-- - Simple swaps with blank slots
-- - Adjacent slot swaps  
-- - Complex cascade reordering for non-adjacent slots
-- - Validation of drag/drop rules (locked slots, blank slots, etc.)
--
-- The drag and drop algorithm supports three main operation types:
-- 1. Swap with blank: Moving a favorite to an empty slot
-- 2. Adjacent swap: Swapping two neighboring favorites
-- 3. Cascade reorder: Moving a favorite across multiple slots, shifting others
--
-- All operations respect locking rules and blank slot constraints.

local ErrorHandler = require("core.utils.error_handler")

---@class DragDropUtils
local DragDropUtils = {}

-- Constants for drag and drop operations
local BLANK_GPS = "1000000.1000000.1"

---@class DragDropRule
---@field can_drag_source boolean Whether the source can be dragged
---@field can_drop_target boolean Whether the target can accept a drop
---@field reason string? Optional reason for rejection

--- Validate if a drag operation can be performed from source to target
---@param source_slot table The source favorite slot
---@param target_slot table The target favorite slot
---@param source_index number The source slot index
---@param target_index number The target slot index
---@return DragDropRule validation_result
function DragDropUtils.validate_drag_drop(source_slot, target_slot, source_index, target_index)
  local result = {
    can_drag_source = true,
    can_drop_target = true,
    reason = nil
  }
  
  -- Rule: Blank or locked source cannot be dragged
  if source_slot.gps == BLANK_GPS then
    result.can_drag_source = false
    result.reason = "source_is_blank"
    return result
  end
  
  if source_slot.locked then
    result.can_drag_source = false
    result.reason = "source_is_locked"
    return result
  end
  
  -- Rule: Cannot drag onto locked destination
  if target_slot.locked then
    result.can_drop_target = false
    result.reason = "target_is_locked"
    return result
  end
  
  -- Rule: Same slot is allowed (cancels drag)
  if source_index == target_index then
    result.reason = "same_slot"
  end
  
  return result
end

--- Perform drag and drop reordering of favorites
---@param slots table Array of favorite slots
---@param src_idx number Source index (1-based)
---@param dest_idx number Destination index (1-based)
---@return table modified_slots The reordered slots array
function DragDropUtils.reorder_slots(slots, src_idx, dest_idx)
  -- Validate indices (Lua 1-based)
  if src_idx < 1 or src_idx > #slots or dest_idx < 1 or dest_idx > #slots then
    ErrorHandler.debug_log("[DRAG_DROP] Invalid indices", {
      src_idx = src_idx,
      dest_idx = dest_idx,
      slots_count = #slots
    })
    return slots
  end
  
  local src = slots[src_idx]
  local dest = slots[dest_idx]
  
  ErrorHandler.debug_log("[DRAG_DROP] reorder_slots invoked", {
    src_idx = src_idx,
    dest_idx = dest_idx,
    src_gps = src.gps,
    dest_gps = dest.gps
  })
  
  -- Validate the drag operation
  local validation = DragDropUtils.validate_drag_drop(src, dest, src_idx, dest_idx)
  
  if not validation.can_drag_source or not validation.can_drop_target then
    ErrorHandler.debug_log("[DRAG_DROP] Drag operation rejected", {
      reason = validation.reason,
      can_drag_source = validation.can_drag_source,
      can_drop_target = validation.can_drop_target
    })
    return slots
  end
  
  -- If source and destination are the same, do nothing
  if src_idx == dest_idx then
    ErrorHandler.debug_log("[DRAG_DROP] Same slot operation", { slot = src_idx })
    return slots
  end
  
  -- If destination is blank, perform simple swap
  if dest.gps == BLANK_GPS then
    return DragDropUtils._swap_with_blank(slots, src_idx, dest_idx)
  end
  
  -- If source and destination are adjacent, perform simple swap
  if math.abs(src_idx - dest_idx) == 1 then
    return DragDropUtils._swap_adjacent(slots, src_idx, dest_idx)
  end
  
  -- Otherwise, perform cascade reordering
  return DragDropUtils._cascade_reorder(slots, src_idx, dest_idx)
end

--- Swap source with blank destination
---@param slots table Array of favorite slots
---@param src_idx number Source index
---@param dest_idx number Destination index (blank)
---@return table modified_slots
function DragDropUtils._swap_with_blank(slots, src_idx, dest_idx)
  ErrorHandler.debug_log("[DRAG_DROP] Swapping with blank destination", {
    src_idx = src_idx,
    dest_idx = dest_idx
  })
  
  local src = slots[src_idx]
  slots[dest_idx] = { gps = src.gps, locked = src.locked }
  slots[src_idx] = { gps = BLANK_GPS, locked = false }
  
  return slots
end

--- Swap adjacent slots
---@param slots table Array of favorite slots
---@param src_idx number Source index
---@param dest_idx number Destination index (adjacent)
---@return table modified_slots
function DragDropUtils._swap_adjacent(slots, src_idx, dest_idx)
  ErrorHandler.debug_log("[DRAG_DROP] Swapping adjacent slots", {
    src_idx = src_idx,
    dest_idx = dest_idx
  })
  
  slots[src_idx], slots[dest_idx] = slots[dest_idx], slots[src_idx]
  return slots
end

--- Perform cascade reordering for non-adjacent slots
---@param slots table Array of favorite slots
---@param src_idx number Source index
---@param dest_idx number Destination index
---@return table modified_slots
function DragDropUtils._cascade_reorder(slots, src_idx, dest_idx)
  ErrorHandler.debug_log("[DRAG_DROP] Performing cascade reorder", {
    src_idx = src_idx,
    dest_idx = dest_idx
  })
  
  local step = (src_idx < dest_idx) and -1 or 1  -- reversed direction
  local start_idx, end_idx
  
  if src_idx < dest_idx then
    start_idx, end_idx = dest_idx, src_idx + 1
  else
    start_idx, end_idx = dest_idx, src_idx - 1
  end
  
  -- Check for locked slots or blanks in the cascade path (excluding src and dest)
  for i = start_idx, end_idx, step do
    if slots[i].locked then
      ErrorHandler.debug_log("[DRAG_DROP] Cascade blocked by locked slot", { 
        blocked_at = i 
      })
      return slots  -- Abort if cascade would overwrite a locked slot
    end
    if slots[i].gps == BLANK_GPS then
      ErrorHandler.debug_log("[DRAG_DROP] Cascade blocked by blank slot", { 
        blocked_at = i 
      })
      return slots  -- Abort cascade if a blank favorite is encountered
    end
  end
  
  -- Shift all intervening slots toward the source
  for i = start_idx, end_idx, step do
    slots[i] = { gps = slots[i - step].gps, locked = slots[i - step].locked }
  end
  
  -- Place dragged item at destination
  local src = slots[src_idx]
  slots[dest_idx] = { gps = src.gps, locked = src.locked }
  -- Set source to blank
  slots[src_idx] = { gps = BLANK_GPS, locked = false }
  
  ErrorHandler.debug_log("[DRAG_DROP] Cascade reorder completed", {
    src_idx = src_idx,
    dest_idx = dest_idx
  })
  
  return slots
end

return DragDropUtils
