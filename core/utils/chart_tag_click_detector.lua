---@diagnostic disable: undefined-global
local chart_tag_click_detector = {}

-- Cache dependencies
local gps_parser = require("__TeleportFavorites__.core.gps.gps_parser")

-- Settings for chart tag detection
local CHART_TAG_CLICK_RADIUS = 1.0  -- How close the click needs to be to the chart tag center

-- Stores last clicked chart tag for each player
chart_tag_click_detector.last_clicked_chart_tags = {}

-- Find chart tag at cursor position
local function find_chart_tag_at_position(player, cursor_position)
    if not player or not player.valid or not cursor_position then return nil end
    
    -- Only detect clicks while in map mode
    if player.render_mode ~= defines.render_mode.chart and 
       player.render_mode ~= defines.render_mode.chart_zoomed_in then 
        return nil
    end
    
    -- Get all chart tags on the current surface
    local force_tags = player.force.find_chart_tags(player.surface)
    if not force_tags or #force_tags == 0 then return nil end
    
    -- Find the closest chart tag within detection radius
    local closest_tag = nil
    local min_distance = CHART_TAG_CLICK_RADIUS
    
    for _, tag in pairs(force_tags) do
        if tag and tag.valid then
            local dx = tag.position.x - cursor_position.x
            local dy = tag.position.y - cursor_position.y
            local distance = math.sqrt(dx*dx + dy*dy)
            
            if distance < min_distance then
                min_distance = distance
                closest_tag = tag
            end
        end
    end
    
    return closest_tag
end

-- Function to be called when the map is clicked
function chart_tag_click_detector.on_map_clicked(event)
    local player = game.get_player(event.player_index)
    if not player or not player.valid then return end
    
    -- Only process when player is in map view
    if player.render_mode ~= defines.render_mode.chart and 
       player.render_mode ~= defines.render_mode.chart_zoomed_in then 
        return 
    end
    
    -- Get cursor position
    local cursor_position = player.position  -- This is the map center, not the cursor position
    if player.selected then
        -- If something is selected, use that position
        cursor_position = player.selected.position
    end
    
    -- Try to find chart tag at cursor position
    local clicked_chart_tag = find_chart_tag_at_position(player, cursor_position)
    
    -- Store last clicked tag for this player
    chart_tag_click_detector.last_clicked_chart_tags[player.index] = clicked_chart_tag
    
    -- If a tag was found, trigger the click event
    if clicked_chart_tag and clicked_chart_tag.valid then
        -- Create a GPS string for the tag
        local gps = gps_parser.gps_from_map_position(clicked_chart_tag.position, player.surface.index)
        
        -- Log or handle the clicked tag
        if _G.log then _G.log(string.format("[TeleportFavorites] Player %s clicked chart tag at %s", 
            player.name, gps)) end
            
        -- Trigger any custom handlers for chart tag click
        script.raise_event("tf-chart-tag-clicked", {
            player_index = player.index,
            tag = clicked_chart_tag,
            gps = gps
        })
    end
end

-- Check if a player has clicked a chart tag recently
-- @param player_index The player index to check
-- @return The last clicked chart tag, or nil if none
function chart_tag_click_detector.get_last_clicked_chart_tag(player_index)
    return chart_tag_click_detector.last_clicked_chart_tags[player_index]
end

-- Register all necessary events
function chart_tag_click_detector.register(script)
    if not script then return end
    
    -- Register the custom input handler
    script.on_event("tf-map-left-click", chart_tag_click_detector.on_map_clicked)
    
    -- Create a custom event for other modules to listen to
    script.generate_event_name("tf-chart-tag-clicked")
end

return chart_tag_click_detector
