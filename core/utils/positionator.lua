---@diagnostic disable: undefined-global
-- Positionator Module
-- Provides a developer utility for fine-tuning positions and bounding boxes
-- before proceeding with the normalization workflow

local DevMode = require("core.utils.dev_mode")
local GuiBase = require("gui.gui_base")
local Constants = require("constants")
local Settings = require("__TeleportFavorites__.settings")
local GPSCore = require("core.utils.gps_core")
local GPSParser = require("core.utils.gps_parser")
local TableHelpers = require("core.utils.table_helpers")

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
    nearby_tags_label = "tf_positionator_nearby_tags_label",
    nearby_tags_scroll = "tf_positionator_nearby_tags_scroll",
    nearby_tags_list = "tf_positionator_nearby_tags_list"
}

-- State data for the positionator
Positionator.state = {
    -- Player index to positionator data mapping
    -- Each entry contains original_pos, adjusted_pos, normalized_pos, and callback_data
    player_data = {},
    
    -- Map preview state when right-clicking
    map_preview = {
        -- Player index to map preview data
        -- Each entry tracks if preview is active and cursor position
        -- {active = bool, position = {x=number, y=number}, search_radius = number}
    }
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
    
    -- Register GUI events
    script_to_use.on_event(defines.events.on_gui_click, Positionator.on_gui_click)
    script_to_use.on_event(defines.events.on_gui_value_changed, Positionator.on_gui_value_changed)    -- Register input events for right-click detection in map view
    script_to_use.on_event(defines.events.on_player_selected_area, Positionator.on_player_selected_area) -- We'll use this as a proxy for right-click
    script_to_use.on_event(defines.events.on_player_cursor_stack_changed, Positionator.on_cursor_changed)
    
    -- Register tick handler for continuous tracking while right-button is held
    script_to_use.on_event(defines.events.on_tick, Positionator.on_tick)
    script_to_use.on_event(defines.events.on_player_display_scale_changed, Positionator.on_display_change)
    script_to_use.on_event(defines.events.on_player_toggled_map_editor, Positionator.on_map_view_change)
    script_to_use.on_event(defines.events.on_pre_player_toggled_map_editor, Positionator.on_map_view_change)
    
    -- Register tick event for cursor position tracking in map view
    script_to_use.on_nth_tick(30, Positionator.on_nth_tick) -- Update every 30 ticks to reduce UPS impact (was 10)
end

-- Get the player data table, creating it if needed
function Positionator.get_player_data(player_index)
    if not Positionator.state.player_data[player_index] then
        Positionator.state.player_data[player_index] = {}
    end
    return Positionator.state.player_data[player_index]
end

-- Get map preview state data for a player, creating it if needed
function Positionator.get_map_preview_data(player_index)
    if not Positionator.state.map_preview[player_index] then
        Positionator.state.map_preview[player_index] = {
            active = false,
            position = nil,
            search_radius = nil,
            right_click_held = false
        }
    end
    return Positionator.state.map_preview[player_index]
end

-- Clear player data when no longer needed
function Positionator.clear_player_data(player_index)
    Positionator.state.player_data[player_index] = nil
end

-- Clear map preview data for a player
function Positionator.clear_map_preview(player_index)
    -- Clear any visualizations first
    if game.players[player_index] then
        rendering.clear(player_index)
    end
    
    Positionator.state.map_preview[player_index] = nil
end

-- Show the position adjustment dialog
function Positionator.show(player, original_pos, normalized_pos, callback_data)    -- First determine if we should show the Positionator GUI (requires dev mode)
    local show_gui = DevMode.is_positionator_enabled()
    
    -- If not in dev mode, return false to indicate we didn't show the dialog
    if not show_gui then
        return false
    end
    
    -- Store the position data for this player
    local player_data = Positionator.get_player_data(player.index)
    player_data.original_pos = TableHelpers.deep_copy(original_pos)
    player_data.adjusted_pos = TableHelpers.deep_copy(original_pos)
    player_data.normalized_pos = TableHelpers.deep_copy(normalized_pos)
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
    Positionator.destroy_gui(player)    -- Get player data
    local player_data = Positionator.get_player_data(player.index)
    
    -- Create the main frame in the left GUI
    local main_frame = player.gui.left.add({
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
    
    -- Add a separator
    main_content.add({
        type = "line",
        direction = "horizontal",
    })
      -- Nearby Chart Tags Section (sorted by distance - closest at top)
    local nearby_tags_header = main_content.add({
        type = "flow",
        direction = "horizontal",
    })
    nearby_tags_header.style.vertical_align = "center"
    nearby_tags_header.style.horizontally_stretchable = true
    
    nearby_tags_header.add({
        type = "label",
        name = Positionator.names.nearby_tags_label,
        caption = "Nearby Chart Tags (closest first):",
        style = "caption_label",
    })
    
    -- Scrollable list for nearby chart tags
    local scroll_pane = main_content.add({
        type = "scroll-pane",
        name = Positionator.names.nearby_tags_scroll,
        horizontal_scroll_policy = "never",
        vertical_scroll_policy = "auto"
    })
    scroll_pane.style.maximal_height = 150
    scroll_pane.style.horizontally_stretchable = true
    
    -- Flow for the list of tags
    local tags_list = scroll_pane.add({
        type = "flow",
        name = Positionator.names.nearby_tags_list,
        direction = "vertical"
    })
    tags_list.style.vertical_spacing = 2
    tags_list.style.horizontally_stretchable = true
    
    -- Visualize the bounding box on the map
    Positionator.visualize_bounding_box(player)
    
    -- Update the nearby chart tags list
    Positionator.update_nearby_chart_tags(player)
end

-- Update the nearby chart tags list in the UI
function Positionator.update_nearby_chart_tags(player)
    -- Get the main frame
    local frame = player.gui.left[Positionator.names.main_frame]
    if not frame then return end
    
    -- Get the scroll pane and list container
    local main_content = frame[Positionator.names.main_content]
    local scroll_pane = main_content[Positionator.names.nearby_tags_scroll]
    if not scroll_pane then return end
    
    local tags_list = scroll_pane[Positionator.names.nearby_tags_list]
    if not tags_list then return end
    
    -- Clear the existing list
    tags_list.clear()
    
    -- Get player data
    local player_data = Positionator.get_player_data(player.index)
    if not player_data then return end
    
    -- Get position and radius
    local position = player_data.adjusted_pos
    local radius = player_data.search_radius
    local surface = player.surface
    
    -- Define the search area
    local search_area = {
        {position.x - radius, position.y - radius},
        {position.x + radius, position.y + radius}
    }
    
    -- Get all chart tags in the area
    local chart_tags = player.force.find_chart_tags(surface, search_area)
    if not chart_tags or #chart_tags == 0 then
        -- No tags found
        tags_list.add({
            type = "label",
            caption = "No chart tags found in radius"
        }).style.font_color = {r=0.7, g=0.7, b=0.7}
        return
    end
    
    -- Calculate distance from center position for each tag
    local tags_with_distance = {}
    for _, tag in pairs(chart_tags) do
        if tag and tag.valid then
            local dx = tag.position.x - position.x
            local dy = tag.position.y - position.y
            local distance = math.sqrt(dx*dx + dy*dy)
            
            table.insert(tags_with_distance, {
                tag = tag,
                distance = distance
            })
        end
    end
      -- Sort by distance (closest first, to appear at the top of the list)
    table.sort(tags_with_distance, function(a, b)
        return a.distance < b.distance
    end)
    
    -- Add each tag to the list
    for _, tag_data in ipairs(tags_with_distance) do
        local tag = tag_data.tag
        local distance = tag_data.distance
        
        -- Create the GPS string
        local gps = GPSParser.gps_from_map_position(tag.position, surface.index)
        
        -- Create a flow for this tag
        local tag_flow = tags_list.add({
            type = "flow",
            direction = "horizontal"
        })
        tag_flow.style.horizontally_stretchable = true
        
        -- Distance indicator
        local distance_label = tag_flow.add({
            type = "label",
            caption = string.format("%.1f", distance)
        })
        distance_label.style.width = 40
        distance_label.style.font = "default-small"
        distance_label.style.font_color = {r=0.7, g=0.7, b=0.7}        -- Icon if present
        if tag.icon and tag.icon.type and tag.icon.name then
            local sprite_name = tag.icon.type .. "/" .. tag.icon.name
            -- Just try to add the sprite - Factorio will handle invalid sprites gracefully
            tag_flow.add({
                type = "sprite",
                sprite = sprite_name,
                tooltip = tag.text or ""
            })
        end
        
        -- GPS text
        local gps_label = tag_flow.add({
            type = "label",
            caption = gps
        })
        gps_label.style.font = "default-small"
        
        -- Add tooltip with full tag info
        local tooltip = tag.text or ""
        if tooltip ~= "" then
            tooltip = tooltip .. "\n"
        end
        tooltip = tooltip .. gps
        gps_label.tooltip = tooltip
    end
end

-- Update the UI elements based on current state
function Positionator.update_ui(player)
    -- Get player data
    local player_data = Positionator.get_player_data(player.index)
    if not player_data then return end
    
    -- Get the GUI elements
    local frame = player.gui.left[Positionator.names.main_frame]
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
    
    -- Update the nearby chart tags list
    Positionator.update_nearby_chart_tags(player)
    
    -- Visualize the bounding box on the map
    Positionator.visualize_bounding_box(player)
end

-- Visualize the bounding box on the map
function Positionator.visualize_bounding_box(player)
    local player_data = Positionator.get_player_data(player.index)
    if not player_data then return end
    
    -- Clear any previous rendering
    rendering.clear(player.index)
    
    -- Draw the bounding box (square)
    local left_top = {
        x = player_data.adjusted_pos.x - player_data.search_radius,
        y = player_data.adjusted_pos.y - player_data.search_radius
    }
    
    local right_bottom = {
        x = player_data.adjusted_pos.x + player_data.search_radius,
        y = player_data.adjusted_pos.y + player_data.search_radius
    }
    
    -- Draw the square box with lighter color (secondary visualization)
    rendering.draw_rectangle({
        color = {r = 0, g = 0.6, b = 1, a = 0.15}, -- Light blue, more transparent
        filled = true,
        left_top = left_top,
        right_bottom = right_bottom,
        surface = player.surface,
        players = {player},
        draw_on_ground = true,
    })
    
    rendering.draw_rectangle({
        color = {r = 0, g = 0.6, b = 1, a = 0.4}, -- Light blue outline
        width = 1,
        filled = false,
        left_top = left_top,
        right_bottom = right_bottom,
        surface = player.surface,
        players = {player},
    })
    
    -- Draw the circle (primary visualization - matching find_non_colliding_position behavior)
    rendering.draw_circle({
        color = {r = 0, g = 1, b = 0, a = 0.25}, -- Green, semi-transparent
        radius = player_data.search_radius,
        filled = true,
        target = player_data.adjusted_pos,
        surface = player.surface,
        players = {player},
        draw_on_ground = true,
    })
    
    rendering.draw_circle({
        color = {r = 0, g = 1, b = 0, a = 0.8}, -- Green, more visible outline
        radius = player_data.search_radius,
        width = 2,
        filled = false,
        target = player_data.adjusted_pos,
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
    if player.gui.left[Positionator.names.main_frame] then
        player.gui.left[Positionator.names.main_frame].destroy()
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
        if player_data then            -- Reset position to original
            player_data.adjusted_pos = TableHelpers.deep_copy(player_data.original_pos)
            
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

-- Get cursor position from event
local function get_cursor_position(event)
    return {
        x = event.cursor_position.x,
        y = event.cursor_position.y
    }
end

-- Handle right-click in map view event
function Positionator.on_player_selected_area(event)
    local player = game.get_player(event.player_index)
    if not player or not player.valid then return end
    
    -- Only process when player is in map view
    if player.render_mode ~= defines.render_mode.chart and 
       player.render_mode ~= defines.render_mode.chart_zoomed_in then 
        return 
    end
    
    -- Check if normal GUI is already open - don't show preview during regular positioning
    local main_frame = player.gui.left[Positionator.names.main_frame]
    if main_frame and main_frame.valid then return end
    
    -- Get cursor position from event
    local cursor_position = event.cursor_position
    if not cursor_position or not (cursor_position.x and cursor_position.y) then return end
    
    -- Get player's teleport radius setting and adjust it based on zoom level
    local player_settings = Settings:getPlayerSettings(player)
    local search_radius = player_settings.teleport_radius or Constants.settings.TELEPORT_RADIUS_DEFAULT
    
    -- Check if user has enabled the map reticle in settings
    local show_reticle = player_settings.map_reticle_on
    if not show_reticle then return end
    
    -- Create/update map preview data
    local preview_data = Positionator.get_map_preview_data(player.index)
    preview_data.active = true
    preview_data.position = TableHelpers.deep_copy(cursor_position)
    preview_data.search_radius = search_radius
    preview_data.right_click_held = true
    preview_data.last_update_time = game.tick
    preview_data.zoom_level = tonumber(player.zoom) or 0.3 -- Convert to number with fallback
    
    -- Start showing preview visualization
    Positionator.visualize_map_preview(player)
    
    -- Don't consume the event - let it continue to the regular handler
    -- so that the tag editor can open when released
end

-- Handle player cursor stack changes
function Positionator.on_cursor_changed(event)
    if not DevMode.is_dev_environment() then return end
    
    local player = game.get_player(event.player_index)
    if not player or not player.valid then return end
    
    -- Clear map preview if player grabs something with cursor
    local preview_data = Positionator.state.map_preview[player.index]
    if preview_data and preview_data.active and player.cursor_stack and player.cursor_stack.valid_for_read then
        Positionator.clear_map_preview(player.index)
    end
end

-- Handle tick events for continuous tracking
function Positionator.on_tick(event)
    -- Only process every 5 ticks to save UPS
    if event.tick % 5 ~= 0 then return end
    
    -- Process any active preview for each player
    for player_index, preview_data in pairs(Positionator.state.map_preview) do
        local player = game.get_player(player_index)
        if player and player.valid and preview_data.active then
            -- Get player settings to check if reticle is enabled
            local player_settings = Settings:getPlayerSettings(player)
            local show_reticle = player_settings.map_reticle_on
            
            -- Clear preview if reticle setting is turned off
            if not show_reticle then
                Positionator.clear_map_preview(player_index)
                return
            end
            
            -- Check if player is still in map view
            if player.render_mode == defines.render_mode.chart or
               player.render_mode == defines.render_mode.chart_zoomed_in then
                
                -- Check if right mouse button is still held down
                -- The most reliable way to detect this in Factorio is to check
                -- if player has selection tool active or is selecting area
                  -- Get the player's selected blueprint or tool
                local right_click_active = false
                
                -- Method 1: Check if player is actively selecting area
                if player.is_cursor_blueprint() then
                    right_click_active = true
                end
                
                -- Method 2: Check if we received a recent right-click event
                -- Time-based detection - if it's been more than 1 second since the last detection,
                -- assume the right-click has been released
                if preview_data.last_update_time and (event.tick - preview_data.last_update_time < 60) then
                    right_click_active = true
                end
                
                -- If right-click is no longer active, clear the preview
                if not right_click_active then
                    Positionator.clear_map_preview(player_index)
                end
            else
                -- Not in map view anymore
                Positionator.clear_map_preview(player_index)
            end
        else
            -- Player not valid or preview not active
            Positionator.clear_map_preview(player_index)
        end
    end
end

-- Handle nth tick events for cursor position updates
function Positionator.on_nth_tick(event)
    local current_tick = event.tick
    
    -- Update cursor positions for any active map previews
    for player_index, preview_data in pairs(Positionator.state.map_preview) do
        local player = game.get_player(player_index)
        if player and player.valid and preview_data.active and
           (player.render_mode == defines.render_mode.chart or player.render_mode == defines.render_mode.chart_zoomed_in) then
            
            -- Throttle updates based on zoom level
            -- More zoomed out = less frequent updates needed
            local update_needed = true
            local zoom_throttle = 60 -- Base throttle tick count
              -- Apply throttling based on zoom level
            local zoom_value = tonumber(player.zoom) or 0.3 -- Convert to number with fallback
            if zoom_value > 0.5 then
                zoom_throttle = math.max(30, zoom_throttle * 0.5) -- Faster updates when zoomed in
            elseif zoom_value < 0.2 then
                zoom_throttle = math.min(120, zoom_throttle * 2) -- Slower updates when zoomed out
            end
            
            -- Check if we need to update based on throttling and last update time
            if preview_data.last_update_time and (current_tick - preview_data.last_update_time < zoom_throttle) then
                update_needed = false
            end
              -- Skip expensive rendering if right mouse button is no longer held
            local right_click_held = player.is_cursor_blueprint() or 
                (player.cursor_stack and player.cursor_stack.valid_for_read)
              -- Check if zoom level has changed significantly
            local zoom_value = tonumber(player.zoom) or 0.3 -- Convert to number with fallback
            local zoom_changed = preview_data.zoom_level and math.abs(preview_data.zoom_level - zoom_value) > 0.1
            
            -- Get current cursor position using LuaPlayer.position which returns the 
            -- cursor position when in map view
            local position = player.position
            if position and position.x and position.y and update_needed then
                -- Only update if position changed meaningfully
                local position_changed = not preview_data.position or
                   math.abs(preview_data.position.x - position.x) > 0.5 or
                   math.abs(preview_data.position.y - position.y) > 0.5
                  if position_changed or zoom_changed then
                    -- Ensure position is proper table format
                    preview_data.position = {
                        x = position.x,
                        y = position.y
                    }
                    preview_data.last_update_time = current_tick
                    preview_data.zoom_level = zoom_value
                    Positionator.visualize_map_preview(player)
                end
            end
        end
    end
end

-- Handle display scale change events
function Positionator.on_display_change(event)
    local player = game.get_player(event.player_index)
    if not player or not player.valid then return end
      -- For GUI: Only refresh if in dev mode
    if DevMode.is_positionator_enabled() and Positionator.state.player_data[player.index] then
        Positionator.update_ui(player)
    end
    
    -- For map reticle: Refresh if active, regardless of dev mode
    if Positionator.state.map_preview[player.index] and 
       Positionator.state.map_preview[player.index].active then
        Positionator.visualize_map_preview(player)
    end
end

-- Handle map view change events
function Positionator.on_map_view_change(event)
    local player = game.get_player(event.player_index)
    if not player or not player.valid then return end
    
    -- Clear map preview when exiting map view
    if player.render_mode ~= defines.render_mode.chart and 
       player.render_mode ~= defines.render_mode.chart_zoomed_in then
        Positionator.clear_map_preview(player.index)
    end
end

-- Visualize the map preview at cursor position
function Positionator.visualize_map_preview(player)
    if not player or not player.valid then return end
    
    local preview_data = Positionator.state.map_preview[player.index]
    if not preview_data or not preview_data.active or not preview_data.position then return end
    
    -- Get player settings to check if reticle is enabled
    local player_settings = Settings:getPlayerSettings(player)
    if not player_settings.map_reticle_on then
        -- Clear any existing visualizations and exit
        rendering.clear(player.index)
        return
    end
    
    -- Clear any previous rendering
    rendering.clear(player.index)
    
    -- Draw the preview visualization (same style as the regular positionator visualization)
    local position = preview_data.position
    local search_radius = preview_data.search_radius
      -- Adapt rendering complexity based on zoom level
    local zoom_value = tonumber(player.zoom) or 0.3 -- Convert to number with fallback
    local is_zoomed_in = zoom_value > 0.5
    local zoom_factor = math.min(1, zoom_value * 2)  -- Scale factor for visual elements
    
    -- Draw the bounding box (square)
    local left_top = {
        x = position.x - search_radius,
        y = position.y - search_radius
    }
    
    local right_bottom = {
        x = position.x + search_radius,
        y = position.y + search_radius
    }
    
    -- First, determine what to render based on zoom and performance considerations
    local render_square = true
    local render_circle = true
    local render_center = is_zoomed_in -- Only render center marker when zoomed in
    
    -- Reduce transparency when zoomed out for better visibility
    local square_alpha = 0.15 * zoom_factor
    local circle_alpha = 0.25 * zoom_factor
    local outline_alpha = 0.4 + (0.4 * (1 - zoom_factor))  -- Make outlines more visible when zoomed out
      -- When very zoomed out, only show one visualization to save UPS
    if zoom_value < 0.2 then
        render_square = false -- Only show circle when zoomed out
        render_center = false -- Don't show center when very zoomed out
    end
    
    -- Draw the square box if needed
    if render_square then
        rendering.draw_rectangle({
            color = {r = 0, g = 0.6, b = 1, a = square_alpha}, -- Light blue, transparent
            filled = true,
            left_top = left_top,
            right_bottom = right_bottom,
            surface = player.surface,
            players = {player},
            draw_on_ground = true,
        })
        
        rendering.draw_rectangle({
            color = {r = 0, g = 0.6, b = 1, a = outline_alpha}, -- Light blue outline
            width = 1,
            filled = false,
            left_top = left_top,
            right_bottom = right_bottom,
            surface = player.surface,
            players = {player},
        })
    end
    
    -- Draw the circle (primary visualization - matching find_non_colliding_position behavior)
    if render_circle then
        rendering.draw_circle({
            color = {r = 0, g = 1, b = 0, a = circle_alpha}, -- Green, semi-transparent
            radius = search_radius,
            filled = true,
            target = position,
            surface = player.surface,
            players = {player},
            draw_on_ground = true,
        })
        
        rendering.draw_circle({
            color = {r = 0, g = 1, b = 0, a = outline_alpha}, -- Green, more visible outline
            radius = search_radius,
            width = math.max(1, math.ceil(2 * zoom_factor)), -- Adjust line width based on zoom
            filled = false,
            target = position,
            surface = player.surface,
            players = {player},
        })
    end
    
    -- Draw a marker at the center position only when zoomed in enough
    if render_center then
        rendering.draw_circle({
            color = {r = 1, g = 0, b = 0, a = 1},
            radius = 0.3,
            filled = true,
            target = position,
            surface = player.surface,
            players = {player},
        })
    end
end

return Positionator
