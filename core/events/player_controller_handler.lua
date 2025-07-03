--[[
player_controller_handler.lua
TeleportFavorites Factorio Mod
-----------------------------
Handles player controller changes to show/hide favorites bar in editor mode.
]]

local GuiHelpers = require("core.utils.gui_helpers")
local GuiValidation = require("core.utils.gui_validation")
local SmallHelpers = require("core.utils.small_helpers")

local PlayerControllerHandler = {}

-- Function to get the favorites bar frame for a player
local function _get_fave_bar_frame(player)
    if not player or not player.valid then return nil end
    local main_flow = GuiHelpers.get_or_create_gui_flow_from_gui_top(player)
    if not main_flow or not main_flow.valid then return nil end
    return GuiValidation.find_child_by_name(main_flow, "fave_bar_frame")
end

-- Function to show/hide the entire favorites bar based on controller type
function PlayerControllerHandler.update_fave_bar_visibility(player)
    if not player or not player.valid then return end
    
    local fave_bar_frame = _get_fave_bar_frame(player)
    if not fave_bar_frame or not fave_bar_frame.valid then return end
    
    -- Use the same logic as fave_bar.build for consistency
    local should_hide = false
    
    -- Use shared space platform detection logic
    if SmallHelpers.should_hide_favorites_bar_for_space_platform(player) then
        should_hide = true
    end
    
    -- Also hide for god mode and spectator mode
    if player.controller_type == defines.controllers.god or 
       player.controller_type == defines.controllers.spectator then
        should_hide = true
    end
    
    fave_bar_frame.visible = not should_hide
end

-- Event handler for controller changes
function PlayerControllerHandler.on_player_controller_changed(event)
    if not event or not event.player_index then return end
    local player = game.get_player(event.player_index)
    if not player or not player.valid then return end
    
    PlayerControllerHandler.update_fave_bar_visibility(player)
    
    -- If switching to character or cutscene mode, rebuild the bar and initialize labels
    if player.controller_type == defines.controllers.character or player.controller_type == defines.controllers.cutscene then
        local fave_bar = require("gui.favorites_bar.fave_bar")
        fave_bar.build(player)
        
        -- Initialize labels after a short delay to ensure GUI is ready
        script.on_nth_tick(10, function()
            local FaveBarGuiLabelsManager = require("core.control.fave_bar_gui_labels_manager")
            FaveBarGuiLabelsManager.update_label_for_player("player_coords", player, script, "show-player-coords", "fave_bar_coords_label", FaveBarGuiLabelsManager.get_coords_caption)
            FaveBarGuiLabelsManager.update_label_for_player("teleport_history", player, script, "show-teleport-history", "fave_bar_teleport_history_label", FaveBarGuiLabelsManager.get_history_caption)
            script.on_nth_tick(10, nil) -- Unregister this one-time handler
        end)
    end
end

return PlayerControllerHandler
