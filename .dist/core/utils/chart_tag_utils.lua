---@diagnostic disable: undefined-global

local ErrorHandler = require("core.utils.error_handler")
local GPSUtils = require("core.utils.gps_utils")
local Cache = require("core.cache.cache")
local BasicHelpers = require("core.utils.basic_helpers")
local icon_typing = require("core.cache.icon_typing")

---@class ChartTagUtils
local ChartTagUtils = {}

local last_clicked_chart_tags = {}

---@param player LuaPlayer Player context
---@param cursor_position MapPosition Position to check
---@return LuaCustomChartTag? chart_tag Found chart tag or nil
function ChartTagUtils.find_closest_chart_tag_to_position(player, cursor_position)
  if not BasicHelpers.is_valid_player(player) or not cursor_position then return nil end

  if player.render_mode ~= defines.render_mode.chart then
  end
  local surface_index = player.surface and player.surface.index or nil
  if not surface_index then return nil end

  local force_tags = Cache.Lookups.get_chart_tag_cache(surface_index)

  if not force_tags or #force_tags == 0 then
    Cache.Lookups.invalidate_surface_chart_tags(surface_index)
    force_tags = Cache.Lookups.get_chart_tag_cache(surface_index)
  end

  if not force_tags or #force_tags == 0 then
    return nil
  end

  local click_radius = Cache.Settings.get_chart_tag_click_radius(player)

  local min_distance = math.huge
  local closest_tag = nil
  for _, tag in pairs(force_tags) do
    if tag and tag.valid then
      local dx = math.abs(tag.position.x - cursor_position.x)
      local dy = math.abs(tag.position.y - cursor_position.y)
      if dx <= click_radius and dy <= click_radius then
        local distance = math.sqrt(dx * dx + dy * dy)
        if distance < min_distance then
          min_distance = distance
          closest_tag = tag
        end
      end
    end
  end

  return closest_tag
end

---@param force LuaForce The force that will own the chart tag
---@param surface LuaSurface The surface where the tag will be placed
---@param spec table Chart tag specification table (position, text, etc.)
---@param player LuaPlayer? Player context for collision notifications
---@return LuaCustomChartTag|nil chart_tag The created chart tag or nil if failed
function ChartTagUtils.safe_add_chart_tag(force, surface, spec, player)
  if not force or not surface or not spec then
    ErrorHandler.debug_log("Invalid arguments to safe_add_chart_tag", {
      has_force = force ~= nil,
      has_surface = surface ~= nil,
      has_spec = spec ~= nil
    })
    return nil
  end

  if not spec.position or type(spec.position.x) ~= "number" or type(spec.position.y) ~= "number" then
    ErrorHandler.debug_log("Invalid position in chart tag spec", {
      position = spec.position
    })
    return nil
  end
  local surface_index = tonumber(surface.index) or 1
  local gps = GPSUtils.gps_from_map_position(spec.position, surface_index)
  local existing_chart_tag = nil
  if player and player.valid then
    existing_chart_tag = ChartTagUtils.find_closest_chart_tag_to_position(player, spec.position)
  end

  if existing_chart_tag and existing_chart_tag.valid then
    if spec.text then existing_chart_tag.text = spec.text end
    if spec.icon then existing_chart_tag.icon = spec.icon end
    if spec.last_user then existing_chart_tag.last_user = spec.last_user end
    return existing_chart_tag
  end

  local success, result = pcall(function()
    return force.add_chart_tag(surface, spec)
  end)

  if not success then
    ErrorHandler.debug_log("Chart tag creation failed with error", {
      error = result,
      position = spec.position
    })
    return nil
  end

  ---@cast result LuaCustomChartTag
  if not result or not result.valid then
    ErrorHandler.debug_log("Chart tag created but is invalid", {
      chart_tag_exists = result ~= nil,
      position = spec.position
    })
    return nil
  end

  if spec.icon then
    icon_typing.format_icon_as_rich_text(spec.icon)
  end

  return result
end

return ChartTagUtils
