---@diagnostic disable: undefined-global
-- Handles on_gui_closed (ESC key or GUI close) for the tag editor
local control_tag_editor = require("core.control.control_tag_editor")
local Cache = require("core.cache.cache")
local Helpers = require("core.utils.helpers_suite")
local Enum = require("prototypes.enums.enum")

local function on_gui_closed(event)
  local player = game.get_player(event.player_index)
  if not player then return end
  -- Only handle if the closed GUI is the tag editor
  local gui_frame = Helpers.find_child_by_name(player.gui.screen, Enum.GuiEnum.GUI_FRAME.TAG_EDITOR)
  if gui_frame and gui_frame.name == Enum.GuiEnum.GUI_FRAME.TAG_EDITOR then
    control_tag_editor.close_tag_editor(player)
  end
end

return {
  on_gui_closed = on_gui_closed
}
