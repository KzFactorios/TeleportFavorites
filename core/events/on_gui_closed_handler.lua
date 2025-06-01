---@diagnostic disable: undefined-global
-- Handles on_gui_closed (ESC key or GUI close) for the tag editor
local control_tag_editor = require("core.control.control_tag_editor")
local Cache = require("core.cache.cache")
local Helpers = require("core.utils.helpers_suite")

local function on_gui_closed(event)
  local player = game.get_player(event.player_index)
  if not player then return end
  -- Only handle if the closed GUI is the tag editor
  local outer = Helpers.find_child_by_name(player.gui.screen, "tag_editor_outer_frame")
  if outer and (event.element == outer or event.gui_type == defines.gui_type.custom) then
    control_tag_editor.close_tag_editor(player)
  end
end

return {
  on_gui_closed = on_gui_closed
}
