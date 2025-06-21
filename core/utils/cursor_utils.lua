-- filepath: core/utils/cursor_utils.lua
-- Utilities for manipulating the player's cursor stack for drag-and-drop in the favorites bar

local GuiUtils = require("core.utils.gui_utils")
local Enum = require("prototypes.enums.enum")
local ErrorHandler = require("core.utils.error_handler")

local CursorUtils = {}

--- Add a favorite's icon to the player's cursor stack for drag-and-drop
---@param player LuaPlayer
---@param favorite table
function CursorUtils.add_favorite_to_cursor(player, favorite)
  if not player or not player.valid then return false end
  if not favorite then return false end
  -- Clear any existing cursor
  player.clear_cursor()
  -- Try to use a blueprint as a visual indicator (Factorio limitation)
  local icon = favorite.tag and favorite.tag.chart_tag and favorite.tag.chart_tag.icon
  local sprite_path = icon or Enum.SpriteEnum.PIN
  -- Use blueprint if available
  if player.can_insert({name = "blueprint", count = 1}) then
    player.cursor_stack.set_stack({name = "blueprint", count = 1})
    -- Optionally set blueprint icon (not visible in cursor, but for future extensibility)
    -- player.cursor_stack.set_blueprint_icons({{index = 1, signal = {type = "virtual", name = sprite_path}}})
    return true
  end
  -- Fallback: nothing else possible
  return false
end

--- Remove any item from the player's cursor stack
---@param player LuaPlayer
function CursorUtils.clear_favorite_from_cursor(player)
  if not player or not player.valid then return end
  player.clear_cursor()
end

return CursorUtils
