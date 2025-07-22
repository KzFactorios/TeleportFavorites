---@diagnostic disable: undefined-global

-- core/control/control_teleport_history_modal.lua
-- Handles interaction logic for the teleport history modal.

local Enum = require("prototypes.enums.enum")
local Cache = require("core.cache.cache")
local ErrorHandler = require("core.utils.error_handler")
local BasicHelpers = require("core.utils.basic_helpers")

local M = {}



local function get_mouse_position(event)
  if event and event.cursor_position then
    return event.cursor_position.x, event.cursor_position.y
  end
  return nil, nil
end

local function set_modal_size(player, width, height)
  local modal_frame = player.gui.screen[Enum.GuiEnum.GUI_FRAME.TELEPORT_HISTORY_MODAL]
  if modal_frame and modal_frame.valid then
    if modal_frame.style then
      if width then pcall(function() modal_frame.style.minimal_width = width; modal_frame.style.maximal_width = width end) end
      if height then pcall(function() modal_frame.style.minimal_height = height; modal_frame.style.maximal_height = height end) end
    end
  end
end







return M
