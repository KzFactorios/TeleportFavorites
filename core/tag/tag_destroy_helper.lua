-- core/tag/tag_destroy_helper.lua
-- TeleportFavorites Factorio Mod
-- Centralized, recursion-safe destruction for tags and chart_tags, with multiplayer and transaction safety.

-- Weak tables to track objects being destroyed
local Cache = require("core.cache.cache")
local FavoriteUtils = require("core.favorite.favorite")
local ErrorHandler = require("core.utils.error_handler")

local destroying_tags = setmetatable({}, { __mode = "k" })
local destroying_chart_tags = setmetatable({}, { __mode = "k" })

--- Check if a tag is being destroyed
---@param tag table|nil
local function is_tag_being_destroyed(tag)
  return tag and destroying_tags[tag] or false
end

--- Check if a chart_tag is being destroyed
---@param chart_tag LuaCustomChartTag|nil
local function is_chart_tag_being_destroyed(chart_tag)
  return chart_tag and destroying_chart_tags[chart_tag] or false
end

--- Check if tag has any favorites that need cleanup
---@param tag table|nil
---@return boolean
local function has_any_favorites(tag)
  if not tag or not tag.faved_by_players then return false end
  return #tag.faved_by_players > 0
end

--- Clean up player favorites that match the tag's GPS
---@param tag table Tag object with GPS coordinate
---@return number cleaned_count Number of favorites cleaned up
local function cleanup_player_favorites(tag)
  if not tag or not _G.game or type(_G.game.players) ~= "table" then 
    return 0 
  end
  
  local cleaned_count = 0
  for _, player in pairs(_G.game.players) do
    local pfaves = Cache.get_player_favorites(player)
    for _, fave in pairs(pfaves) do
      if fave.gps == tag.gps then
        fave.gps = ""
        fave.locked = false
        cleaned_count = cleaned_count + 1
      end
    end
  end

  return cleaned_count
end

--- Clean up faved_by_players array for the tag
---@param tag table Tag object with faved_by_players array
local function cleanup_faved_by_players(tag)
  if not tag.faved_by_players or type(tag.faved_by_players) ~= "table" then 
    ErrorHandler.debug_log("No faved_by_players to cleanup")
    return 
  end
  
  local original_count = #tag.faved_by_players
  for i = #tag.faved_by_players, 1, -1 do
    for _, player in pairs(_G.game.players) do
      if tag.faved_by_players[i] == player.index then
        table.remove(tag.faved_by_players, i)
        break
      end
    end
  end
end

--- Validate inputs for destruction
---@param tag table|nil
---@param chart_tag LuaCustomChartTag|nil
---@return boolean is_valid
---@return string[] issues
local function validate_destruction_inputs(tag, chart_tag)
  local issues = {}
  
  if tag and not tag.gps then
    table.insert(issues, "Tag missing GPS coordinate")
  end
  
  -- Don't treat invalid chart_tag as an error - it might have already been destroyed
  if chart_tag then
    local valid_check_success, is_valid = pcall(function() return chart_tag.valid end)
    if not valid_check_success or not is_valid then
      ErrorHandler.debug_log("Chart tag already invalid or inaccessible, skipping chart_tag destruction")
    end
  end
  
  return #issues == 0, issues
end

--- Safely destroy with transaction safety and error recovery
---@param tag table|nil
---@param chart_tag LuaCustomChartTag|nil
---@return boolean success
local function safe_destroy_with_cleanup(tag, chart_tag)
  -- Store gps for cleanup before any modifications
  local tag_gps = tag and tag.gps or nil
  
  -- FIRST: Clear the chart_tag reference from the tag immediately to prevent invalid access
  if tag and tag.chart_tag then
    tag.chart_tag = nil
  end
  
  -- SECOND: Handle chart tag destruction safely
  if chart_tag then
    -- Use pcall to safely check if chart_tag.valid can be accessed
    local valid_check_success, is_valid = pcall(function() return chart_tag.valid end)
    if valid_check_success and is_valid then 
      local chart_success, chart_error = pcall(function()
        chart_tag:destroy()
      end)
      if chart_success then
        ErrorHandler.debug_log("Chart tag destroyed successfully")
      else
        ErrorHandler.debug_log("Chart tag destruction failed, but continuing with tag cleanup", { error = chart_error })
      end
    else
      ErrorHandler.debug_log("Chart tag already invalid or inaccessible, skipping destruction")
    end
  end
  
  -- THIRD: Clean up tag-related data - this should always succeed even if chart_tag failed
  if tag then
    local tag_success, tag_error = pcall(function()
      if has_any_favorites(tag) then
        local cleaned_count = cleanup_player_favorites(tag)
        cleanup_faved_by_players(tag)
      end
    end)
    
    if not tag_success then
      ErrorHandler.debug_log("Tag favorites cleanup failed", { error = tag_error })
    end
    
    -- FOURTH: Try storage removal separately using the stored GPS
    if tag_gps then
      local storage_success, storage_error = pcall(function()
        Cache.remove_stored_tag(tag_gps)
        ErrorHandler.debug_log("Tag removed from storage", { gps = tag_gps })
      end)
      
      if not storage_success then
        ErrorHandler.debug_log("Tag storage removal failed", { error = storage_error })
        return false
      end
    end
  end
  
  return true
end

--- Safely destroy a tag and its associated chart_tag, or vice versa.
--- Handles all edge cases and prevents recursion/overflow.
---@param tag table|nil Tag object (may be nil)
---@param chart_tag LuaCustomChartTag|nil Chart tag object (may be nil)
---@return boolean success True if destruction completed successfully
local function destroy_tag_and_chart_tag(tag, chart_tag)
  if tag and destroying_tags[tag] then 
    return true 
  end
  if chart_tag and destroying_chart_tags[chart_tag] then 
    return true 
  end
  
  -- Input validation
  local is_valid, issues = validate_destruction_inputs(tag, chart_tag)
  if not is_valid then
    ErrorHandler.debug_log("Destruction validation failed", { issues = issues })
    return false
  end
  
  -- Set destruction guards
  if tag then destroying_tags[tag] = true end
  if chart_tag then destroying_chart_tags[chart_tag] = true end
  
  -- Perform safe destruction with transaction safety
  local success = safe_destroy_with_cleanup(tag, chart_tag)
  
  -- Clean up destruction guards
  if tag then destroying_tags[tag] = nil end
  if chart_tag then destroying_chart_tags[chart_tag] = nil end
  
  return success
end

--- Should this tag be destroyed? Returns false for blank favorites.
---@param tag table|nil
local function should_destroy(tag)
  return not FavoriteUtils.is_blank_favorite(tag)
end

local export = {
  destroy_tag_and_chart_tag = destroy_tag_and_chart_tag,
  is_tag_being_destroyed = is_tag_being_destroyed,
  is_chart_tag_being_destroyed = is_chart_tag_being_destroyed,
  should_destroy = should_destroy
}

return export
