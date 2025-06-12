-- Updated Positionator.visualize_map_preview function to implement the reticle visibility toggle
-- Add this to your positionator.lua file as a complete replacement for the existing function

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
