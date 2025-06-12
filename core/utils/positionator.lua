---@diagnostic disable: undefined-global
-- Positionator Module
-- Provides a developer utility for fine-tuning positions and bounding boxes
-- before proceeding with the normalization workflow

local DevEnvironment = require("core.utils.dev_environment")
local GuiBase = require("gui.gui_base")
local Constants = require("constants")
local Settings = require("core.control.settings")
local GPSCore = require("core.utils.gps_core")
local GPSParser = require("core.utils.gps_parser")

local Positionator = {}

-- Constants for GUI element names
Positionator.names = {
    main_frame = "tf_positionator_frame",
    title_flow = "tf_positionator_title_flow",
    title_label = "tf_positionator_title_label",
    close_button = "tf_positionator_close_button",
    main_content = "tf_positionator_content",
    original_pos_label = "tf_positionator_original_pos_label",
    original_pos_value = "tf_positionator_original_pos_value",
    normalized_pos_label = "tf_positionator_normalized_pos_label",
    normalized_pos_value = "tf_positionator_normalized_pos_value",
    x_adjust_slider = "tf_positionator_x_adjust_slider",
    y_adjust_slider = "tf_positionator_y_adjust_slider",
    x_value_label = "tf_positionator_x_value_label",
    y_value_label = "tf_positionator_y_value_label",
    radius_slider = "tf_positionator_radius_slider",
    radius_label = "tf_positionator_radius_label",
    box_width_label = "tf_positionator_box_width_label",
    box_height_label = "tf_positionator_box_height_label",
    reset_button = "tf_positionator_reset_button",
    confirm_button = "tf_positionator_confirm_button",
}

-- State data for the positionator
Positionator.state = {
    -- Player index to positionator data mapping
    -- Each entry contains original_pos, adjusted_pos, normalized_pos, and callback_data
    player_data = {},
}

-- Initialize module (register events, etc.)
-- @param script_obj The script object for registering events, passed from the caller
function Positionator.init(script_obj)
    -- Register required events
    local script_to_use = script_obj or script -- Use provided script object or fall back to global script if available
    if not script_to_use then
        log("[TeleportFavorites] Error: Positionator.init called without script object")
        return
    end
    
    script_to_use.on_event(defines.events.on_gui_click, Positionator.on_gui_click)
    script_to_use.on_event(defines.events.on_gui_value_changed, Positionator.on_gui_value_changed)
end

-- Get the player data table, creating it if needed
function Positionator.get_player_data(player_index)
    if not Positionator.state.player_data[player_index] then
        Positionator.state.player_data[player_index] = {}
    end
    return Positionator.state.player_data[player_index]
end

-- Clear player data when no longer needed
function Positionator.clear_player_data(player_index)
    Positionator.state.player_data[player_index] = nil
end

-- Show the position adjustment dialog
function Positionator.show(player, original_pos, normalized_pos, callback_data)
    -- Do nothing if not in dev mode or positionator is disabled
    if not DevEnvironment.is_positionator_enabled() then
        -- Return false to indicate we didn't show the dialog
        return false
    end
    
    -- Store the position data for this player
    local player_data = Positionator.get_player_data(player.index)
    player_data.original_pos = table.deepcopy(original_pos)
    player_data.adjusted_pos = table.deepcopy(original_pos)
    player_data.normalized_pos = table.deepcopy(normalized_pos)
    player_data.callback_data = callback_data
    
    -- Get teleport radius from player settings
    local player_settings = Settings:getPlayerSettings(player)
    player_data.search_radius = player_settings.teleport_radius or Constants.settings.TELEPORT_RADIUS_DEFAULT
    
    -- Create the dialog
    Positionator.create_gui(player)
    
    -- Return true to indicate we showed the dialog
    return true
end

-- Create the GUI elements for the positionator
function Positionator.create_gui(player)
    -- First destroy any existing positionator GUI
    Positionator.destroy_gui(player)

    -- Get player data
    local player_data = Positionator.get_player_data(player.index)
    
    -- Create the main frame
    local main_frame = player.gui.center.add({
        type = "frame",
        name = Positionator.names.main_frame,
        direction = "vertical",
    })
    
    -- Title bar
    local title_flow = main_frame.add({
        type = "flow",
        name = Positionator.names.title_flow,
        direction = "horizontal",
    })
    title_flow.style.horizontal_align = "space-between"
    title_flow.style.height = 28
    title_flow.style.width = 500
    
    -- Title
    title_flow.add({
        type = "label",
        name = Positionator.names.title_label,
        caption = "Position Adjustment Tool (DEV MODE)",
        style = "frame_title",
    })
    title_flow.style.horizontally_stretchable = true
    
    -- Close button
    title_flow.add({
        type = "sprite-button",
        name = Positionator.names.close_button,
        sprite = "utility/close_white",
        style = "frame_action_button",
    })
    
    -- Main content area
    local main_content = main_frame.add({
        type = "flow",
        name = Positionator.names.main_content,
        direction = "vertical",
    })
    main_content.style.padding = 12
    
    -- Original position display
    local orig_pos_flow = main_content.add({
        type = "flow",
        direction = "horizontal",
    })
    orig_pos_flow.style.vertical_align = "center"
    orig_pos_flow.style.horizontally_stretchable = true
    
    orig_pos_flow.add({
        type = "label",
        name = Positionator.names.original_pos_label,
        caption = "Original Position:",
        style = "caption_label",
    })
    
    local original_gps = GPSParser.gps_from_map_position(player_data.original_pos, player.surface.index)
    orig_pos_flow.add({
        type = "label",
        name = Positionator.names.original_pos_value,
        caption = string.format("GPS:%.2f,%.2f", player_data.original_pos.x, player_data.original_pos.y),
        tooltip = original_gps,
    })
    
    -- Normalized position display
    local norm_pos_flow = main_content.add({
        type = "flow",
        direction = "horizontal",
    })
    norm_pos_flow.style.vertical_align = "center"
    norm_pos_flow.style.horizontally_stretchable = true
    
    norm_pos_flow.add({
        type = "label",
        name = Positionator.names.normalized_pos_label,
        caption = "Normalized Position:",
        style = "caption_label",
    })
    
    local normalized_gps = GPSParser.gps_from_map_position(player_data.normalized_pos, player.surface.index)
    norm_pos_flow.add({
        type = "label",
        name = Positionator.names.normalized_pos_value,
        caption = string.format("GPS:%.2f,%.2f", player_data.normalized_pos.x, player_data.normalized_pos.y),
        tooltip = normalized_gps,
    })
    
    -- Add a separator
    main_content.add({
        type = "line",
        direction = "horizontal",
    })
    
    -- X Position adjustment
    local x_flow = main_content.add({
        type = "flow",
        direction = "horizontal",
    })
    x_flow.style.vertical_align = "center"
    x_flow.style.horizontally_stretchable = true
    
    x_flow.add({
        type = "label",
        caption = "X Position:",
    }).style.width = 100
    
    x_flow.add({
        type = "slider",
        name = Positionator.names.x_adjust_slider,
        minimum_value = player_data.original_pos.x - 10,
        maximum_value = player_data.original_pos.x + 10,
        value = player_data.adjusted_pos.x,
    }).style.horizontally_stretchable = true
    
    x_flow.add({
        type = "label",
        name = Positionator.names.x_value_label,
        caption = string.format("%.2f", player_data.adjusted_pos.x),
    }).style.width = 60
    
    -- Y Position adjustment
    local y_flow = main_content.add({
        type = "flow",
        direction = "horizontal",
    })
    y_flow.style.vertical_align = "center"
    y_flow.style.horizontally_stretchable = true
    
    y_flow.add({
        type = "label",
        caption = "Y Position:",
    }).style.width = 100
    
    y_flow.add({
        type = "slider",
        name = Positionator.names.y_adjust_slider,
        minimum_value = player_data.original_pos.y - 10,
        maximum_value = player_data.original_pos.y + 10,
        value = player_data.adjusted_pos.y,
    }).style.horizontally_stretchable = true
    
    y_flow.add({
        type = "label",
        name = Positionator.names.y_value_label,
        caption = string.format("%.2f", player_data.adjusted_pos.y),
    }).style.width = 60
    
    -- Add a separator
    main_content.add({
        type = "line",
        direction = "horizontal",
    })
    
    -- Search radius adjustment
    local radius_flow = main_content.add({
        type = "flow",
        direction = "horizontal",
    })
    radius_flow.style.vertical_align = "center"
    radius_flow.style.horizontally_stretchable = true
    
    radius_flow.add({
        type = "label",
        caption = "Search Radius:",
    }).style.width = 100
    
    radius_flow.add({
        type = "slider",
        name = Positionator.names.radius_slider,
        minimum_value = 0.1,
        maximum_value = 30,
        value = player_data.search_radius,
    }).style.horizontally_stretchable = true
    
    radius_flow.add({
        type = "label",
        name = Positionator.names.radius_label,
        caption = string.format("%.1f", player_data.search_radius),
    }).style.width = 60
    
    -- Bounding box dimensions
    local box_flow = main_content.add({
        type = "flow",
        direction = "horizontal",
    })
    
    box_flow.add({
        type = "label",
        caption = "Box dimensions:",
    }).style.width = 100
    
    box_flow.add({
        type = "label",
        name = Positionator.names.box_width_label,
        caption = string.format("Width: %.1f", player_data.search_radius * 2),
    }).style.width = 100
    
    box_flow.add({
        type = "label",
        name = Positionator.names.box_height_label,
        caption = string.format("Height: %.1f", player_data.search_radius * 2),
    }).style.width = 100
    
    -- Add a separator
    main_content.add({
        type = "line",
        direction = "horizontal",
    })
    
    -- Buttons
    local button_flow = main_content.add({
        type = "flow",
        direction = "horizontal",
    })
    button_flow.style.horizontal_align = "right"
    button_flow.style.top_padding = 8
    
    button_flow.add({
        type = "button",
        name = Positionator.names.reset_button,
        caption = "Reset",
        tooltip = "Reset position to original clicked coordinates",
    })
    
    button_flow.add({
        type = "button",
        name = Positionator.names.confirm_button,
        caption = "Confirm",
        style = "confirm_button",
        tooltip = "Use current position and continue with workflow",
    })
    
    -- Visualize the bounding box on the map
    Positionator.visualize_bounding_box(player)
end

-- Update the UI elements based on current state
function Positionator.update_ui(player)
    -- Get player data
    local player_data = Positionator.get_player_data(player.index)
    if not player_data then return end
    
    -- Get the GUI elements
    local frame = player.gui.center[Positionator.names.main_frame]
    if not frame then return end
    
    local main_content = frame[Positionator.names.main_content]
    
    -- Update position labels and values
    local adjusted_gps = GPSParser.gps_from_map_position(player_data.adjusted_pos, player.surface.index)
    
    -- Update position sliders and labels
    local x_slider = main_content[Positionator.names.x_adjust_slider]
    local y_slider = main_content[Positionator.names.y_adjust_slider]
    local x_label = main_content[Positionator.names.x_value_label]
    local y_label = main_content[Positionator.names.y_value_label]
    
    if x_slider and x_label then
        x_slider.value = player_data.adjusted_pos.x
        x_label.caption = string.format("%.2f", player_data.adjusted_pos.x)
    end
    
    if y_slider and y_label then
        y_slider.value = player_data.adjusted_pos.y
        y_label.caption = string.format("%.2f", player_data.adjusted_pos.y)
    end
    
    -- Update radius and box dimensions
    local radius_label = main_content[Positionator.names.radius_label]
    local box_width_label = main_content[Positionator.names.box_width_label]
    local box_height_label = main_content[Positionator.names.box_height_label]
    
    if radius_label then
        radius_label.caption = string.format("%.1f", player_data.search_radius)
    end
    
    if box_width_label and box_height_label then
        box_width_label.caption = string.format("Width: %.1f", player_data.search_radius * 2)
        box_height_label.caption = string.format("Height: %.1f", player_data.search_radius * 2)
    end
    
    -- Update visualization
    Positionator.visualize_bounding_box(player)
end

-- Visualize the bounding box on the map
function Positionator.visualize_bounding_box(player)
    local player_data = Positionator.get_player_data(player.index)
    if not player_data then return end
    
    -- Clear any previous rendering
    rendering.clear(player.index)
    
    -- Draw the bounding box
    local left_top = {
        x = player_data.adjusted_pos.x - player_data.search_radius,
        y = player_data.adjusted_pos.y - player_data.search_radius
    }
    
    local right_bottom = {
        x = player_data.adjusted_pos.x + player_data.search_radius,
        y = player_data.adjusted_pos.y + player_data.search_radius
    }
    
    -- Draw the box
    rendering.draw_rectangle({
        color = {r = 0, g = 1, b = 0, a = 0.2},
        filled = true,
        left_top = left_top,
        right_bottom = right_bottom,
        surface = player.surface,
        players = {player},
        draw_on_ground = true,
    })
    
    rendering.draw_rectangle({
        color = {r = 0, g = 1, b = 0, a = 0.8},
        width = 2,
        filled = false,
        left_top = left_top,
        right_bottom = right_bottom,
        surface = player.surface,
        players = {player},
    })
    
    -- Draw a marker at the center position
    rendering.draw_circle({
        color = {r = 1, g = 0, b = 0, a = 1},
        radius = 0.3,
        filled = true,
        target = player_data.adjusted_pos,
        surface = player.surface,
        players = {player},
    })
end

-- Destroy the GUI for a player
function Positionator.destroy_gui(player)
    if player.gui.center[Positionator.names.main_frame] then
        player.gui.center[Positionator.names.main_frame].destroy()
    end
    
    -- Clear any visualizations
    rendering.clear(player.index)
end

-- Handle GUI click events
function Positionator.on_gui_click(event)
    local player = game.get_player(event.player_index)
    if not player then return end
    
    local element = event.element
    if not element or not element.valid then return end
    
    -- Handle close button
    if element.name == Positionator.names.close_button then
        -- Just close the dialog without applying changes
        Positionator.destroy_gui(player)
        Positionator.clear_player_data(player.index)
        return
    end
    
    -- Handle reset button
    if element.name == Positionator.names.reset_button then
        local player_data = Positionator.get_player_data(player.index)
        if player_data then
            -- Reset position to original
            player_data.adjusted_pos = table.deepcopy(player_data.original_pos)
            
            -- Reset search radius to default
            local player_settings = Settings:getPlayerSettings(player)
            player_data.search_radius = player_settings.teleport_radius or Constants.settings.TELEPORT_RADIUS_DEFAULT
            
            -- Update the UI
            Positionator.update_ui(player)
        end
        return
    end
    
    -- Handle confirm button
    if element.name == Positionator.names.confirm_button then
        Positionator.confirm_and_continue(player)
        return
    end
end

-- Handle GUI value changed events (sliders)
function Positionator.on_gui_value_changed(event)
    local player = game.get_player(event.player_index)
    if not player then return end
    
    local element = event.element
    if not element or not element.valid then return end
    
    local player_data = Positionator.get_player_data(player.index)
    if not player_data then return end
    
    -- Handle X position slider
    if element.name == Positionator.names.x_adjust_slider then
        player_data.adjusted_pos.x = element.slider_value
        Positionator.update_ui(player)
        return
    end
    
    -- Handle Y position slider
    if element.name == Positionator.names.y_adjust_slider then
        player_data.adjusted_pos.y = element.slider_value
        Positionator.update_ui(player)
        return
    end
    
    -- Handle radius slider
    if element.name == Positionator.names.radius_slider then
        player_data.search_radius = element.slider_value
        Positionator.update_ui(player)
        return
    end
end

-- Confirm the adjustments and continue with the workflow
function Positionator.confirm_and_continue(player)
    local player_data = Positionator.get_player_data(player.index)
    if not player_data or not player_data.callback_data or not player_data.callback_data.callback then
        -- No callback data, just close
        Positionator.destroy_gui(player)
        Positionator.clear_player_data(player.index)
        return
    end
    
    -- Extract the adjusted position and callback
    local adjusted_position = player_data.adjusted_pos
    local search_radius = player_data.search_radius
    local callback = player_data.callback_data.callback
    local callback_args = player_data.callback_data.args or {}
    
    -- Clean up
    Positionator.destroy_gui(player)
    Positionator.clear_player_data(player.index)
    
    -- Call the callback with the adjusted position
    callback(player, adjusted_position, search_radius, table.unpack(callback_args))
end

return Positionator
