---@diagnostic disable: undefined-global

local ErrorHandler = require("core.utils.error_handler")
local TeleportStrategy = require("core.utils.teleport_strategy")
local Cache = require("core.cache.cache")
local GPSUtils = require("core.utils.gps_utils")


---@class Tag
---@field gps string # The GPS string (serves as the index)
---@field chart_tag LuaCustomChartTag? # Cached chart tag (private, can be nil)
---@field faved_by_players uint[] # Array of player indices who have favorited this tag
local Tag = {}
Tag.__index = Tag

local destroying_tags = setmetatable({}, { __mode = "k" })
local destroying_chart_tags = setmetatable({}, { __mode = "k" })

---@param gps string
---@param faved_by_players uint[]|nil
---@return Tag
function Tag.new(gps, faved_by_players)
  return setmetatable({ gps = gps, faved_by_players = faved_by_players or {} }, Tag)
end

---@param old_gps string|nil Original GPS coordinate string
---@param new_gps string|nil New GPS coordinate string
---@param chart_tag LuaCustomChartTag|nil The chart tag object that was modified
---@param player LuaPlayer|nil Player context for surface lookup
function Tag.update_gps_and_surface_mapping(old_gps, new_gps, chart_tag, player)
  if not old_gps or not new_gps then return end
  if not player or not player.valid then
    ErrorHandler.debug_log("Cannot update tag: invalid player", { old_gps = old_gps, new_gps = new_gps })
    return
  end

  local TagClass = Tag
  local old_tag = Cache.get_tag_by_gps(player, old_gps)
  if old_tag == nil and new_gps then
    old_tag = TagClass.new(new_gps, {})
  end

  if type(old_tag) == "table" then
    old_tag.gps = new_gps or ""
    old_tag.chart_tag = chart_tag or nil
  end

  ErrorHandler.debug_log("Updated tag object GPS (shared helper)", {
    old_gps = old_gps or "",
    new_gps = new_gps or "",
    tag_gps_after_update = (type(old_tag) == "table" and old_tag.gps) or "",
    chart_tag_position = chart_tag and chart_tag.position or "nil"
  })

  local surface_index = old_gps and GPSUtils.get_surface_index_from_gps(old_gps) or nil
  if surface_index and old_gps and new_gps and old_gps ~= new_gps then
    local uint_surface_index = math.floor(tonumber(surface_index) or 1)
    local surface_tags = Cache.get_surface_tags(uint_surface_index)
    if type(surface_tags) == "table" and surface_tags[old_gps] then
      surface_tags[new_gps] = surface_tags[old_gps]
      surface_tags[old_gps] = nil
      ErrorHandler.debug_log("Moved tag data in surface mapping (shared helper)", {
        surface_index = surface_index,
        old_gps = old_gps,
        new_gps = new_gps
      })
    end
    if type(surface_tags) == "table" and new_gps and type(old_tag) == "table" then
      surface_tags[new_gps] = old_tag
    end
    ErrorHandler.debug_log("Ensured updated tag is stored at new GPS location (shared helper)", {
      surface_index = surface_index,
      new_gps = new_gps,
      tag_gps = (type(old_tag) == "table" and old_tag.gps) or "",
      tag_has_chart_tag = (type(old_tag) == "table" and old_tag.chart_tag ~= nil) or false
    })
    local CACHE_KEY = "Lookups"
    local runtime_cache = _G[CACHE_KEY]
    if runtime_cache and runtime_cache.surfaces and runtime_cache.surfaces[uint_surface_index] then
      local surface_cache = runtime_cache.surfaces[uint_surface_index]
      if surface_cache.chart_tags_mapped_by_gps then
        surface_cache.chart_tags_mapped_by_gps[old_gps] = nil
        surface_cache.chart_tags_mapped_by_gps[new_gps] = chart_tag
      end
    else
      Cache.Lookups.invalidate_surface_chart_tags(uint_surface_index)
    end
  end
end

Tag.update_gps_and_surface_mapping = Tag.update_gps_and_surface_mapping

return Tag
