---@diagnostic disable: undefined-global
--[[
core/tag/tag_terrain_manager.lua
TeleportFavorites Factorio Mod
-----------------------------
Manages chart tags in relation to terrain changes.

This module handles:
- Checking if chart tags are on water after terrain changes
- Relocating tags to nearby valid positions
- Notifying players about tag relocations due to terrain changes
]]

local Cache = require("core.cache.cache")
local ChartTagUtils = require("core.utils.chart_tag_utils")
local GameHelpers = require("core.utils.game_helpers")
local Lookups = Cache.lookups
local GPSUtils = require("core.utils.gps_utils")
local PositionUtils = require("core.utils.position_utils")
local RichTextFormatter = require("core.utils.rich_text_formatter")
local ErrorHandler = require("core.utils.error_handler")


---@class TagTerrainManager
local TagTerrainManager = {}

--- Check if a chart tag is currently on water
---@param chart_tag LuaCustomChartTag The chart tag to check
---@param surface LuaSurface The surface to check on (defaults to chart tag's surface)
---@return boolean is_on_water True if the chart tag is on a water tile
function TagTerrainManager.is_chart_tag_on_water(chart_tag, surface)
    if not chart_tag or not chart_tag.valid then return false end

    -- Get the surface from chart tag if not provided
    surface = surface or chart_tag.surface
    if not surface or not surface.valid then return false end

    -- Check if position is on water
    return PositionUtils.is_water_tile(surface, chart_tag.position)
end

--- Check if a chart tag is on space
---@param chart_tag LuaCustomChartTag The chart tag to check
---@param surface LuaSurface The surface to check on (defaults to chart tag's surface)
---@return boolean is_on_space True if the chart tag is on a space tile
function TagTerrainManager.is_chart_tag_on_space(chart_tag, surface)
    if not chart_tag or not chart_tag.valid then return false end

    -- Get the surface from chart tag if not provided
    surface = surface or chart_tag.surface
    if not surface or not surface.valid then return false end

    -- Check if position is on space
    return PositionUtils.is_space_tile(surface, chart_tag.position)
end

--- Find the player who owns a tag or who last modified the chart tag
---@param tag table|nil The tag object
---@param chart_tag LuaCustomChartTag The chart tag
---@return LuaPlayer|nil The player who owns the tag or last modified the chart tag
local function find_tag_owner(tag, chart_tag)
    -- the chart tag provided by the tag supercedes
    if tag and tag.chart_tag.valid then
        chart_tag = tag.chart_tag
    end
    return chart_tag and chart_tag.valid and chart_tag.last_user or nil
end

--- Find a valid position near a chart_tag (water tile) that is walkable
---@param chart_tag LuaCustomChartTag The chart tag on water
---@param search_radius number The radius to search for valid land
---@param player LuaPlayer The player for validation context (optional)
---@return MapPosition|nil valid_position A valid position nearby or nil if none found
local function find_valid_position_near_chart_tag(chart_tag, search_radius, player)
    if not chart_tag or not chart_tag.valid then return nil end
    -- Get surface from chart tag
    local surface = chart_tag.surface
    if not surface or not surface.valid then return nil end
    -- Use position utils to find valid position
    return PositionUtils.find_valid_position(surface, chart_tag.position, search_radius, player)
end

--- Relocate a chart tag from water to nearby valid land
---@param chart_tag LuaCustomChartTag The chart tag to relocate
---@param search_radius number The search radius for finding valid land
---@param notify_players boolean Whether to notify affected players
---@return boolean success True if relocation was successful
function TagTerrainManager.relocate_chart_tag_from_water(chart_tag, search_radius, notify_players)
    if not chart_tag or not chart_tag.valid then return false end

    -- Get the tag and a player context
    local surface = chart_tag.surface
    local surface_index = surface and surface.index or 1
    local gps = GPSUtils.gps_from_map_position(chart_tag.position, tonumber(surface_index) or 1)
    local tag = Cache.get_tag_by_gps(gps)
    local player = find_tag_owner(tag, chart_tag)

    -- If no player context, we can't properly validate
    if not player or not player.valid then
        ErrorHandler.debug_log("No valid player context for chart tag relocation", {
            has_tag = tag ~= nil,
            chart_tag_position = chart_tag.position,
            surface_index = surface_index
        })
        return false
    end

    -- Store the old position for notification
    local old_position = { x = chart_tag.position.x, y = chart_tag.position.y }

    -- Find a valid position nearby
    local new_position = find_valid_position_near_chart_tag(chart_tag, search_radius, player)
    if not new_position then
        ErrorHandler.debug_log("No valid position found for chart tag relocation", {
            chart_tag_position = chart_tag.position,
            search_radius = search_radius
        })
        return false
    end    
    -- Create a new chart tag at the valid position using centralized builder    
    local chart_tag_spec = ChartTagUtils.build_chart_tag_spec(new_position, chart_tag, player)
    
    -- Create new chart tag at valid position using safe wrapper
    local new_chart_tag = ChartTagUtils.safe_add_chart_tag(player.force, surface, chart_tag_spec)
    if not new_chart_tag or not new_chart_tag.valid then
        ErrorHandler.debug_log("Failed to create new chart tag during relocation", {
            chart_tag_position = chart_tag.position,
            new_position = new_position
        })
        return false
    end

    -- Update the tag with the new chart tag reference
    local old_gps = gps
    local new_gps = GPSUtils.gps_from_map_position(new_position, tonumber(surface_index) or 1)

    -- If there's a tag, update its GPS and references
    if tag then
        tag.chart_tag = new_chart_tag
        tag.gps = new_gps

        -- Update all favorites that use this tag
        if tag.faved_by_players and #tag.faved_by_players > 0 then
            for _, player_index in ipairs(tag.faved_by_players) do
                local fav_player = game.get_player(player_index)
                if fav_player and fav_player.valid then
                    local favorites = Cache.get_player_favorites(fav_player)
                    for i = 1, #favorites do
                        local favorite = favorites[i]
                        if favorite and favorite.gps == old_gps then
                            favorite.gps = new_gps
                        end
                    end
                end
            end
        end
        -- Update surface tags
        local tags = Cache.get_surface_tags(surface_index)
        tags[old_gps] = nil
        tags[new_gps] = tag
    end    -- Destroy the old chart tag
    chart_tag.destroy()

    -- Refresh cache
    Lookups.invalidate_surface_chart_tags(surface_index)
    
    -- Notify affected players if requested
    if notify_players and tag and tag.faved_by_players and #tag.faved_by_players > 0 then
        local message = RichTextFormatter.position_change_notification_terrain(
            new_chart_tag, old_position, new_position
        )
        for _, player_index in ipairs(tag.faved_by_players) do
            local fav_player = game.get_player(player_index)
            if fav_player and fav_player.valid then
                GameHelpers.player_print(fav_player, message)
            end
        end
    end

    ErrorHandler.debug_log("Chart tag successfully relocated from water", {
        old_position = old_position,
        new_position = new_position,
        old_gps = old_gps,
        new_gps = new_gps
    })

    return true
end

--- Check and relocate all chart tags on a surface that are on water
---@param surface LuaSurface The surface to check
---@param search_radius number The search radius for finding valid land
---@param notify_players boolean Whether to notify affected players
---@return number relocated_count The number of chart tags relocated
function TagTerrainManager.check_and_relocate_all_water_chart_tags(surface, search_radius, notify_players)
    if not surface or not surface.valid then return 0 end

    local relocated_count = 0
    local surface_index = surface.index

    -- Get all chart tags for this surface
    local chart_tags = Lookups.get_surface_chart_tags(surface_index)
    if not chart_tags or #chart_tags == 0 then return 0 end

    -- Make a copy of the tags to avoid modification issues during iteration
    local tags_to_check = {}
    for i = 1, #chart_tags do
        if chart_tags[i] and chart_tags[i].valid then
            table.insert(tags_to_check, chart_tags[i])
        end
    end

    -- Check each chart tag
    for _, chart_tag in ipairs(tags_to_check) do
        if TagTerrainManager.is_chart_tag_on_water(chart_tag, surface) or
            TagTerrainManager.is_chart_tag_on_space(chart_tag, surface) then
            if TagTerrainManager.relocate_chart_tag_from_water(chart_tag, search_radius, notify_players) then
                relocated_count = relocated_count + 1
            end
        end
    end

    return relocated_count
end

--- Check a specific area for chart tags on water after terrain changes
---@param surface LuaSurface The surface to check
---@param area table The area to check {left_top = {x,y}, right_bottom = {x,y}}
---@param search_radius number The search radius for finding valid land
---@param notify_players boolean Whether to notify affected players
---@return number relocated_count The number of chart tags relocated
function TagTerrainManager.check_area_for_water_chart_tags(surface, area, search_radius, notify_players)
    if not surface or not surface.valid or not area then return 0 end

    local relocated_count = 0
    local surface_index = surface.index

    -- Get all chart tags for this surface
    local chart_tags = Lookups.get_surface_chart_tags(surface_index)
    if not chart_tags or #chart_tags == 0 then return 0 end

    -- Make a copy of the tags in the area to avoid modification issues during iteration
    local tags_to_check = {}
    for i = 1, #chart_tags do
        local chart_tag = chart_tags[i]
        if chart_tag and chart_tag.valid and
            chart_tag.position.x >= area.left_top.x and chart_tag.position.x <= area.right_bottom.x and
            chart_tag.position.y >= area.left_top.y and chart_tag.position.y <= area.right_bottom.y then
            table.insert(tags_to_check, chart_tag)
        end
    end

    -- Check each chart tag in the area
    for _, chart_tag in ipairs(tags_to_check) do
        if TagTerrainManager.is_chart_tag_on_water(chart_tag, surface) or
            TagTerrainManager.is_chart_tag_on_space(chart_tag, surface) then
            if TagTerrainManager.relocate_chart_tag_from_water(chart_tag, search_radius, notify_players) then
                relocated_count = relocated_count + 1
            end
        end
    end

    return relocated_count
end

return TagTerrainManager
