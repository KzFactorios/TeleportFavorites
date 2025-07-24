local Cache = require("core.cache.cache")
local FavoriteUtils = require("core.favorite.favorite_utils")
local ErrorHandler = require("core.utils.error_handler")

local destroying_tags = setmetatable({}, { __mode = "k" })
local destroying_chart_tags = setmetatable({}, { __mode = "k" })

---@param tag table|nil
local function is_tag_being_destroyed(tag)
  return tag and destroying_tags[tag] or false
end

---@param chart_tag LuaCustomChartTag|nil
local function is_chart_tag_being_destroyed(chart_tag)
  return chart_tag and destroying_chart_tags[chart_tag] or false
end

---@param tag table|nil
---@return boolean
local function has_any_favorites(tag)
  if not tag or not tag.faved_by_players then return false end
  return #tag.faved_by_players > 0
end

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

---@param tag table|nil
---@param chart_tag LuaCustomChartTag|nil
---@return boolean is_valid
---@return string[] issues
local function validate_destruction_inputs(tag, chart_tag)
  local issues = {}

  if tag and not tag.gps then
    table.insert(issues, "Tag missing GPS coordinate")
  end

  if chart_tag then
    local valid_check_success, is_valid = pcall(function() return chart_tag.valid end)
    if not valid_check_success or not is_valid then
      ErrorHandler.debug_log("Chart tag already invalid or inaccessible, skipping chart_tag destruction")
    end
  end

  return #issues == 0, issues
end

---@param tag table|nil
---@param chart_tag LuaCustomChartTag|nil
---@return boolean success
local function safe_destroy_with_cleanup(tag, chart_tag)
  local tag_gps = tag and tag.gps or nil

  if tag and tag.chart_tag then
    tag.chart_tag = nil
  end

  if chart_tag then
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

  local is_valid, issues = validate_destruction_inputs(tag, chart_tag)
  if not is_valid then
    ErrorHandler.debug_log("Destruction validation failed", { issues = issues })
    return false
  end

  if tag then destroying_tags[tag] = true end
  if chart_tag then destroying_chart_tags[chart_tag] = true end

  local success = safe_destroy_with_cleanup(tag, chart_tag)

  if tag then destroying_tags[tag] = nil end
  if chart_tag then destroying_chart_tags[chart_tag] = nil end

  return success
end

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
