-- core/utils/drag_drop_utils.lua
-- Utilities for drag and drop operations in the slots bar

local Logger = require("core.utils.enhanced_error_handler")
local Constants = require("constants")
local BasicHelpers = require("core.utils.basic_helpers")

---@class DragDropUtils
local DragDropUtils = {}

-- Use the official BLANK_GPS constant
local BLANK_GPS = Constants.settings.BLANK_GPS

local is_blank = function(slot_fave)
  if not slot_fave or not slot_fave.gps then
    return true  -- Treat nil or missing gps as blank
  end
  if slot_fave.gps == BLANK_GPS then
    return true
  end
  return false
end

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

  -- Rule: source slot cannot be blank
  if BasicHelpers.is_blank_favorite(source_slot) then
    result.can_drag_source = false
    result.reason = "source_is_blank"
    return result
  end
  
  -- Rule: Blank or locked source cannot be dragged
  if BasicHelpers.is_locked_favorite(source_slot) then
    result.can_drag_source = false
    result.reason = "source_is_locked"
    return result
  end

  -- Rule: Cannot drag onto locked destination
  if BasicHelpers.is_locked_favorite(target_slot) then
    result.can_drop_target = false
    result.reason = "target_is_locked"
    return result
  end

  -- Rule: Same slot is allowed (cancels drag)
  if source_index == target_index then
    result.can_drop_target = false
    result.reason = "same_slot"
  end

  return result
end

--- Reorders favorite slots using blank-seeking cascade algorithm
--- 
--- This algorithm provides intuitive slot reordering by:
--- 1. Finding blank slots between source and destination
--- 2. Cascading items toward available blanks 
--- 3. Placing source item at destination with minimal disruption
---
--- Special Cases:
--- - Move to blank: Direct swap, no cascade
--- - Adjacent slots: Simple swap operation
--- - Locked slots: Completely skipped during operations
---
--- Complex Case (Non-Adjacent, Non-Blank):
--- 1. Source evacuation: Source becomes blank immediately
--- 2. Blank detection: Search for blanks between source and destination
--- 3. Cascade direction: Items shift toward newly-created blank
--- 4. Natural compaction: Items flow into available blanks
---
--- Example: Drag slot 10 → slot 8
--- - Slot 10 content → slot 8 (destination)
--- - Slot 8 content shifts toward blank at slot 10 position
--- - Items cascade naturally to fill available space
---
---@param favorites table Array of favorite slots
---@param source_idx number Source index (1-based)
---@param dest_idx number Destination index (1-based)
---@return table modified_slots Deep copy with reordering applied
---@return boolean success Whether operation succeeded
---@return string error_msg Error description if success is false
function DragDropUtils.reorder_slots(favorites, source_idx, dest_idx)
  -- Validate indices first before accessing array elements
  if not source_idx or not dest_idx or type(source_idx) ~= "number" or type(dest_idx) ~= "number" then
    return favorites, false, "Invalid slot index types"
  end
  
  if source_idx < 1 or source_idx > #favorites or dest_idx < 1 or dest_idx > #favorites then
    return favorites, false, "Invalid slot index"
  end
  
  local validation = DragDropUtils.validate_drag_drop(favorites[source_idx], favorites[dest_idx], source_idx, dest_idx)

  Logger.debug_log("[DRAG_DROP] Simple HBI move", {
    source_idx = source_idx,
    dest_idx = dest_idx
  })

  if not validation.can_drag_source or not validation.can_drop_target then
    Logger.debug_log("[DRAG_DROP] Simple HBI move failed: " .. (validation.reason or "Unknown reason"))
    return favorites, false, validation.reason or "Unknown reason"
  end

  -- Create a copy to avoid modifying original
  local slots = BasicHelpers.deep_copy(favorites)

  -- If adjacent, or if dest is blank, swap and return
  if is_blank(slots[dest_idx]) or math.abs(source_idx - dest_idx) == 1 then
    slots[source_idx], slots[dest_idx] = slots[dest_idx], slots[source_idx]
    return slots, true, ""
  end

  -- Save what's currently at source
  local source_favorite = slots[source_idx]
  slots[source_idx] = { gps = BLANK_GPS, locked = false }

  local blank_idx = source_idx
  if source_idx < dest_idx then
    -- Cascading down
    for i = dest_idx - 1, source_idx + 1, -1 do
      local slot = slots[i]
      if not (slot and slot.locked) then
        if is_blank(slot) then
          blank_idx = i
          break
        end
      end
    end

    -- If we found a blank slot, cascade items down to blank
    for i = blank_idx, dest_idx - 1 do
      if slots[i + 1] and slots[i + 1].locked then
        break -- Skip over locked slots
      end
      slots[i] = slots[i + 1]
    end

    -- Insert the original source item at dest_idx
    slots[dest_idx] = source_favorite
  else
    -- Cascading up
    for i = dest_idx + 1, source_idx - 1 do
      local slot = slots[i]
      if not (slot and slot.locked) then
        if is_blank(slot) then
          blank_idx = i
          break
        end
      end
    end

    for i = blank_idx, dest_idx + 1, -1 do
      if slots[i - 1] and slots[i - 1].locked then
        break
      end
      slots[i] = slots[i - 1]
    end

    -- Insert original into destination
    slots[dest_idx] = source_favorite
  end

  Logger.debug_log("[DRAG_DROP] Simple HBI move completed")
  return slots, true, ""
end

return DragDropUtils
