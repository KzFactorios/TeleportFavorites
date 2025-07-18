---@diagnostic disable: undefined-global

--[[
misc_event_handlers.lua
TeleportFavorites Factorio Mod
-----------------------------
Miscellaneous event handlers for GUI and player controller events.

This module consolidates smaller event handlers that don't warrant separate files:
- GUI close handler (ESC key and modal close functionality)
- Player controller change handler (show/hide favorites bar in editor mode)

Consolidated from:
- on_gui_closed_handler.lua
- player_controller_handler.lua

Features:
---------
- Handles ESC key press and modal GUI close events for TeleportFavorites GUIs
- Manages tag editor modal behavior and cleanup
- Handles player controller changes to show/hide favorites bar in editor mode
- Provides clean integration with control.lua event registration system
- Ensures proper data cleanup and player.opened state management

Architecture:
-------------
- Pure event handler module with minimal external dependencies
- Follows single responsibility principle for each handler function
- Integrates seamlessly with existing control module patterns
- Maintains separation of concerns between event detection and business logic

Integration Pattern:
--------------------
-- Register in control.lua:
script.on_event(defines.events.on_gui_closed, misc_event_handlers.on_gui_closed)
script.on_event(defines.events.on_player_controller_changed, misc_event_handlers.on_player_controller_changed)
]]

local control_tag_editor = require("core.control.control_tag_editor")
local teleport_history_modal = require("gui.teleport_history_modal.teleport_history_modal")
local GuiValidation = require("core.utils.gui_validation")
local GuiHelpers = require("core.utils.gui_helpers")
local BasicHelpers = require("core.utils.basic_helpers")
local ValidationUtils = require("core.utils.validation_utils")
local Enum = require("prototypes.enums.enum")
local Cache = require("core.cache.cache")
local fave_bar = require("gui.favorites_bar.fave_bar")

---@class MiscEventHandlers
local MiscEventHandlers = {}

-- ====== GUI CLOSE HANDLER ======

--- Main event handler for on_gui_closed events
---@param event table GUI close event from Factorio
function MiscEventHandlers.on_gui_closed(event)
  -- Validate player exists and is valid
  local player = game.players[event.player_index]
  if not player or not player.valid then return end
  
  -- Validate event structure
  if not event.element or not event.element.valid then return end
  
  -- Check if this is a teleport history modal being closed
  if (gui_frame and gui_frame.name == Enum.GuiEnum.GUI_FRAME.TELEPORT_HISTORY_MODAL) or
     event.element.name == "teleport_history_modal" then
    -- Route to teleport history modal control for proper cleanup
    teleport_history_modal.destroy(player)
    return
  end
  
  -- Check if this is a tag editor GUI being closed
  local gui_frame = GuiValidation.get_gui_frame_by_element(event.element)
  if gui_frame and (gui_frame.name == Enum.GuiEnum.GUI_FRAME.TAG_EDITOR or 
                    gui_frame.name == Enum.GuiEnum.GUI_FRAME.TAG_EDITOR_DELETE_CONFIRM) then
    -- Route to tag editor control for proper cleanup
    control_tag_editor.close_tag_editor(player)
    return
  end
  
  -- Check if this is a tag editor root frame (handles various close scenarios)
  local tag_editor_frame = Cache.get_player_data(player).tag_editor_frame
  if tag_editor_frame and tag_editor_frame.valid and event.element == tag_editor_frame then
    control_tag_editor.close_tag_editor(player)
    return
  end
  
  -- Future: Add other GUI close handlers here as needed
  -- For example:
  -- if GuiValidation.is_some_other_gui(event.element) then
  --   some_other_control.close_gui(player)
  --   return
  -- end
end

-- ====== PLAYER CONTROLLER HANDLER ======

--- Function to get the favorites bar frame for a player
---@param player LuaPlayer Player to get favorites bar frame for
---@return LuaGuiElement? fave_bar_frame The favorites bar frame or nil if not found
local function _get_fave_bar_frame(player)
  if not ValidationUtils.validate_player(player) then return nil end
  local main_flow = GuiHelpers.get_or_create_gui_flow_from_gui_top(player)
  if not main_flow or not main_flow.valid then return nil end
  return GuiValidation.find_child_by_name(main_flow, "fave_bar_frame")
end

--- Function to show/hide the entire favorites bar based on controller type
---@param player LuaPlayer Player whose favorites bar visibility should be updated
function MiscEventHandlers.update_fave_bar_visibility(player)
  if not ValidationUtils.validate_player(player) then return end
  
  local fave_bar_frame = _get_fave_bar_frame(player)
  if not fave_bar_frame or not fave_bar_frame.valid then return end
  
  -- Use the same logic as fave_bar.build for consistency
  local should_hide = false
  
  -- Use shared space platform detection logic
  if BasicHelpers.should_hide_favorites_bar_for_space_platform(player) then
    should_hide = true
  end
  
  -- Also hide for god mode and spectator mode
  if player.controller_type == defines.controllers.god or 
     player.controller_type == defines.controllers.spectator then
    should_hide = true
  end
  
  fave_bar_frame.visible = not should_hide
end

--- Event handler for controller changes
---@param event table Player controller change event
function MiscEventHandlers.on_player_controller_changed(event)
  if not event or not event.player_index then return end
  local player = game.players[event.player_index]
  if not player or not player.valid then return end
  
  -- Update favorites bar visibility based on new controller type
  MiscEventHandlers.update_fave_bar_visibility(player)
  
  -- If switching to character or cutscene mode, rebuild the bar and initialize labels
  if player.controller_type == defines.controllers.character or player.controller_type == defines.controllers.cutscene then
    fave_bar.build(player)
    -- Note: Label management no longer needed - static slot labels handled in fave_bar.lua
  end
end

-- Export legacy names for backward compatibility
MiscEventHandlers.OnGuiClosedHandler = {
  on_gui_closed = MiscEventHandlers.on_gui_closed
}

MiscEventHandlers.PlayerControllerHandler = {
  update_fave_bar_visibility = MiscEventHandlers.update_fave_bar_visibility,
  on_player_controller_changed = MiscEventHandlers.on_player_controller_changed
}

return MiscEventHandlers
