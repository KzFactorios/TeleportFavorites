local Deps = require("core.deps_barrel")
local ErrorHandler, Cache, Constants, BasicHelpers =
  Deps.ErrorHandler, Deps.Cache, Deps.Constants, Deps.BasicHelpers
local FavoriteUtils = require("core.favorite.favorite_utils")
local destroying_tags = setmetatable({}, { __mode = "k" })
local destroying_chart_tags = setmetatable({}, { __mode = "k" })
local function is_tag_being_destroyed(tag)
  return tag and destroying_tags[tag] or false
end
local function is_chart_tag_being_destroyed(chart_tag)
  return chart_tag and destroying_chart_tags[chart_tag] or false
end
local function has_any_favorites(tag)
  if not tag or not tag.faved_by_players then return false end
  return next(tag.faved_by_players) ~= nil
end
local function cleanup_player_favorites(tag)
  if not tag or not _G.game or ((type(_G.game.players) ~= "userdata") and (type(_G.game.players) ~= "table")) then
    return 0
  end
  local cleaned_count = 0
  local blank = (Constants and Constants.settings and Constants.settings.BLANK_GPS) or "1000000.1000000.1"
  BasicHelpers.for_each_player_by_index_asc(function(player)
    local pfaves = Cache.get_player_favorites(player)
    if not pfaves then return end
    for i = 1, #pfaves do
      local fave = pfaves[i]
      if fave and fave.gps == tag.gps then
        fave.gps = blank
        fave.locked = false
        cleaned_count = cleaned_count + 1
      end
    end
  end)
  return cleaned_count
end
local function cleanup_faved_by_players(tag)
  if not tag.faved_by_players or type(tag.faved_by_players) ~= "table" then
    ErrorHandler.debug_log("No faved_by_players to cleanup")
    return
  end
  tag.faved_by_players = {}
end
local function validate_destruction_inputs(tag, chart_tag)
  local issues = {}
  if tag and not tag.gps then
    table.insert(issues, "Tag missing GPS coordinate")
  end
  return #issues == 0, issues
end
local function safe_destroy_with_cleanup(tag, chart_tag)
  local tag_gps = tag and tag.gps or nil
  if tag and tag.chart_tag then
    tag.chart_tag = nil
  end
  if chart_tag and chart_tag.valid then
    local chart_success, chart_error = pcall(function()
      chart_tag:destroy()
    end)
    if not chart_success then
      ErrorHandler.debug_log("Chart tag destruction failed, but continuing with tag cleanup", { error = chart_error })
    end
  end
  if tag then
    if tag_gps then
      cleanup_player_favorites(tag)
    end
    if has_any_favorites(tag) then
      cleanup_faved_by_players(tag)
    end
    if tag_gps then
      Cache.remove_stored_tag(tag_gps)
    end
  end
  return true
end
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
