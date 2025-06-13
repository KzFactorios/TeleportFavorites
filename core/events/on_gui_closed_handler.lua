---@diagnostic disable: undefined-global

--[[
on_gui_closed_handler.lua
TeleportFavorites Factorio Mod
-----------------------------
Centralized handler for on_gui_closed events (ESC key and modal close functionality).

Features:
---------
- Handles ESC key press and modal GUI close events for TeleportFavorites GUIs
- Specifically manages tag editor modal behavior and cleanup
- Provides clean integration with control.lua event registration system
- Ensures proper data cleanup and player.opened state management

Architecture:
-------------
- Pure event handler module with no external dependencies beyond core modules
- Follows single responsibility principle - only handles GUI closure events
- Integrates seamlessly with existing control module patterns
- Maintains separation of concerns between event detection and business logic

Integration Pattern:
--------------------
-- Register in control.lua:
script.on_event(defines.events.on_gui_closed, on_gui_closed_handler.on_gui_closed)

-- The handler automatically detects which GUI was closed and routes to appropriate cleanup logic

Event Flow:
-----------
1. Factorio triggers on_gui_closed when player presses ESC or clicks outside modal
2. Handler validates player and determines which GUI was closed
3. Routes to appropriate control module for business logic and cleanup
4. Ensures proper state management and data persistence

Supported GUIs:
---------------
- Tag Editor: Routes to control_tag_editor.close_tag_editor() for complete cleanup

Future Extensibility:
---------------------
The pattern can be easily extended to support additional modal GUIs by adding
new conditional branches in the main handler function.
--]]

local control_tag_editor = require("core.control.control_tag_editor")
local Cache = require("core.cache.cache")
local Helpers = require("core.utils.helpers_suite")
local Enum = require("prototypes.enums.enum")

--- Handle on_gui_closed events for TeleportFavorites modal GUIs
--- This function is called when a player presses ESC or clicks outside a modal GUI
---@param event table Event data containing player_index and element
local function on_gui_closed(event)
  -- Validate player existence and state
  ---@diagnostic disable-next-line: param-type-mismatch
  local player = game.get_player(event.player_index)
  if not player or not player.valid then return end
  
  -- Check if the closed element corresponds to the tag editor
  -- Note: We check the specific GUI frame rather than relying on event.element
  -- because the event.element might be a child component, not the main frame
  local tag_editor_frame = Helpers.find_child_by_name(player.gui.screen, Enum.GuiEnum.GUI_FRAME.TAG_EDITOR)
  if tag_editor_frame and tag_editor_frame.valid and tag_editor_frame.name == Enum.GuiEnum.GUI_FRAME.TAG_EDITOR then
    -- Direct close since command pattern isn't available
    control_tag_editor.close_tag_editor(player)
    return
  end
    -- Future GUI handlers can be added here:
  -- local data_viewer_frame = Helpers.find_child_by_name(player.gui.screen, Enum.GuiEnum.GUI_FRAME.DATA_VIEWER)
  -- if data_viewer_frame and data_viewer_frame.valid then
  --   control_data_viewer.close_data_viewer(player)
  --   return
  -- end
end

--- Undo the last GUI close action for a player
--- This can be called from other modules to provide undo functionality
---@param player LuaPlayer
---@return boolean success Always returns false since command pattern isn't implemented
local function undo_last_gui_close(player)
  -- Command pattern not implemented, return false
  return false
end

return {
  on_gui_closed = on_gui_closed,
  undo_last_gui_close = undo_last_gui_close
}
