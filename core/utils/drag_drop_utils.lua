-- core/utils/drag_drop_utils.lua
-- Utilities for drag and drop operations in the slots bar

local ErrorHandler = require("core.utils.error_handler")
local Logger = require("core.utils.enhanced_error_handler")
local Constants = require("constants")
local BasicHelpers = require("core.utils.basic_helpers")
local Enum = require("prototypes.enums.enum")

---@class DragDropUtils
local DragDropUtils = {}

-- Use the official BLANK_GPS constant
local BLANK_GPS = Constants.settings.BLANK_GPS

local is_blank = function(slot_fave)
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

--- Simple HBI move: source replaces destination, destination shifts one step towards source
---@param favorites table Array of favorite slots
---@param source_idx number Source index
---@param dest_idx number Destination index
---@return table modified_slots, boolean success, string error_msg
function DragDropUtils.reorder_slots(favorites, source_idx, dest_idx)
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
