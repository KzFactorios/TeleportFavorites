--[[
core/tag/tag_destroy_helper.lua
TeleportFavorites Factorio Mod
-----------------------------
Centralized, recursion-safe destruction for tags and chart_tags.

- Ensures tag <-> chart_tag destruction cannot recurse or overflow.
- Handles all edge cases for multiplayer, favorites, and persistent storage.
- Use this helper from all tag/chart_tag destruction logic and event handlers.

REFACTORED (Phase 1 & 2 Improvements):
- Added comprehensive ErrorHandler integration for debugging
- Extracted complex nested logic into focused helper functions
- Added transaction safety with pcall error recovery
- Performance optimized with early exits for empty favorites
- Added input validation for better error handling
- Improved code organization and maintainability

API:
-----
- destroy_tag_and_chart_tag(tag, chart_tag) -> boolean   -- Safely destroy a tag and its associated chart_tag, returns success status
- is_tag_being_destroyed(tag) -> boolean                -- Check if a tag is being destroyed (recursion guard)
- is_chart_tag_being_destroyed(chart_tag) -> boolean    -- Check if a chart_tag is being destroyed (recursion guard)  
- should_destroy(tag) -> boolean                        -- Returns false for blank favorites

HELPER FUNCTIONS:
- has_any_favorites(tag) -> boolean                     -- Check if tag has favorites that need cleanup
- cleanup_player_favorites(tag) -> number               -- Clean up player favorites, return count cleaned
- cleanup_faved_by_players(tag)                         -- Clean up tag's faved_by_players array
- validate_destruction_inputs(tag, chart_tag) -> boolean, issues  -- Validate inputs before destruction
- safe_destroy_with_cleanup(tag, chart_tag) -> boolean  -- Perform destruction with transaction safety

Notes:
------
- Always use this helper for tag/chart_tag destruction to avoid recursion and multiplayer edge cases.
- All persistent data is updated and cleaned up, including player favorites and tag storage.
- Now includes comprehensive error logging and transaction safety for multiplayer stability.
- Performance optimized to avoid unnecessary iterations when no favorites exist.
--]]

-- Weak tables to track objects being destroyed
local destroying_tags = setmetatable({}, { __mode = "k" })
local destroying_chart_tags = setmetatable({}, { __mode = "k" })
local Cache = require("core.cache.cache")
local FavoriteUtils = require("core.favorite.favorite")
local ErrorHandler = require("core.utils.error_handler")

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
    ErrorHandler.debug_log("Cannot cleanup player favorites: missing game or players", {
      has_tag = tag ~= nil,
      has_game = _G.game ~= nil
    })
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
        ErrorHandler.debug_log("Cleaned favorite for player", {
          player_name = player.name,
          old_gps = tag.gps
        })
      end
    end
  end
  
  ErrorHandler.debug_log("Player favorites cleanup completed", {
    tag_gps = tag.gps,
    cleaned_count = cleaned_count
  })
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
  
  ErrorHandler.debug_log("Faved by players cleanup completed", {
    original_count = original_count,
    final_count = #tag.faved_by_players
  })
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
  
  if chart_tag and not chart_tag.valid then
    table.insert(issues, "Chart tag is invalid")
  end
  
  return #issues == 0, issues
end

--- Safely destroy with transaction safety and error recovery
---@param tag table|nil
---@param chart_tag LuaCustomChartTag|nil
---@return boolean success
local function safe_destroy_with_cleanup(tag, chart_tag)
  local success, error_msg = pcall(function()
    -- Destroy chart tag first
    if chart_tag and chart_tag.valid then 
      chart_tag:destroy()
      ErrorHandler.debug_log("Chart tag destroyed successfully")
    end
    
    -- Clean up tag-related data
    if tag then
      if has_any_favorites(tag) then
        local cleaned_count = cleanup_player_favorites(tag)
        cleanup_faved_by_players(tag)
        ErrorHandler.debug_log("Favorites cleanup completed", { cleaned_count = cleaned_count })
      end
      
      Cache.remove_stored_tag(tag.gps)
      ErrorHandler.debug_log("Tag removed from storage", { gps = tag.gps })
    end
    
    return true
  end)
  
  if not success then
    ErrorHandler.debug_log("Tag destruction failed, cleaning up guards", { error = error_msg })
    -- Clean up destruction guards on failure
    if tag then destroying_tags[tag] = nil end
    if chart_tag then destroying_chart_tags[chart_tag] = nil end
    return false
  end
  
  return true
end

--- Safely destroy a tag and its associated chart_tag, or vice versa.
--- Handles all edge cases and prevents recursion/overflow.
---@param tag table|nil Tag object (may be nil)
---@param chart_tag LuaCustomChartTag|nil Chart tag object (may be nil)
---@return boolean success True if destruction completed successfully
function destroy_tag_and_chart_tag(tag, chart_tag)
  ErrorHandler.debug_log("Starting tag destruction", {
    has_tag = tag ~= nil,
    has_chart_tag = chart_tag ~= nil,
    tag_gps = tag and tag.gps,
    chart_tag_valid = chart_tag and chart_tag.valid
  })
  
  -- Early return if already being destroyed (recursion guard)
  if tag and destroying_tags[tag] then 
    ErrorHandler.debug_log("Tag already being destroyed, skipping")
    return true 
  end
  if chart_tag and destroying_chart_tags[chart_tag] then 
    ErrorHandler.debug_log("Chart tag already being destroyed, skipping")
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
  
  ErrorHandler.debug_log("Tag destruction completed", { 
    success = success,
    tag_gps = tag and tag.gps
  })
  
  return success
end

--- Should this tag be destroyed? Returns false for blank favorites.
---@param tag table|nil
local function should_destroy(tag)
  return not FavoriteUtils.is_blank_favorite(tag)
end

return {
  destroy_tag_and_chart_tag = destroy_tag_and_chart_tag,
  is_tag_being_destroyed = is_tag_being_destroyed,
  is_chart_tag_being_destroyed = is_chart_tag_being_destroyed,
  should_destroy = should_destroy
}
