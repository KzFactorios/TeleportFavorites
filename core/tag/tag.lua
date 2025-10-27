---@diagnostic disable: undefined-global

-- core/tag/tag.lua
-- TeleportFavorites Factorio Mod
-- Tag model and utilities for managing teleportation tags, chart tags, and player favorites.

local ErrorHandler = require("core.utils.error_handler")
local TeleportStrategy = require("core.utils.teleport_strategy")
local Cache = require("core.cache.cache")
local GPSUtils = require("core.utils.gps_utils")


---@class Tag
---@field gps string # The GPS string (serves as the index)
---@field chart_tag LuaCustomChartTag? # Cached chart tag (private, can be nil)
---@field faved_by_players uint[] # Array of player indices who have favorited this tag
---@field owner_name string? # Name of the player who created/owns this tag
local Tag = {}
Tag.__index = Tag

local destroying_tags = setmetatable({}, { __mode = "k" })
local destroying_chart_tags = setmetatable({}, { __mode = "k" })

--- Create a new Tag instance.
---@param gps string
---@param faved_by_players uint[]|nil
---@param owner_name string|nil
---@return Tag
function Tag.new(gps, faved_by_players, owner_name)
  return setmetatable({ gps = gps, faved_by_players = faved_by_players or {}, owner_name = owner_name }, Tag)
end

--- Update GPS and surface mapping for a tag modification event.
---@param old_gps string|nil Original GPS coordinate string
---@param new_gps string|nil New GPS coordinate string
---@param chart_tag LuaCustomChartTag|nil The chart tag object that was modified
---@param player LuaPlayer|nil Player context for surface lookup
---@param preserve_owner_name string|nil Optional: explicitly preserve this owner name during the move
function Tag.update_gps_and_surface_mapping(old_gps, new_gps, chart_tag, player, preserve_owner_name)
  if not old_gps or not new_gps then return end
  if not player or not player.valid then
    ErrorHandler.debug_log("Cannot update tag: invalid player", { old_gps = old_gps, new_gps = new_gps })
    return
  end

  -- Get or create tag object
  local TagClass = Tag
  local old_tag = Cache.get_tag_by_gps(player, old_gps)
  if old_tag == nil and new_gps then
    old_tag = TagClass.new(new_gps, {})
  end

  -- Only update if old_tag is a table
  if type(old_tag) == "table" then
    old_tag.gps = new_gps or ""
    old_tag.chart_tag = chart_tag or nil
    -- OWNERSHIP PRESERVATION: Explicitly preserve owner_name if provided
    if preserve_owner_name then
      old_tag.owner_name = preserve_owner_name
      ErrorHandler.debug_log("Explicitly preserved owner_name during tag move", {
        old_gps = old_gps,
        new_gps = new_gps,
        owner_name = preserve_owner_name
      })
    end
  end

  ErrorHandler.debug_log("Updated tag object GPS (shared helper)", {
    old_gps = old_gps or "",
    new_gps = new_gps or "",
    tag_gps_after_update = (type(old_tag) == "table" and old_tag.gps) or "",
    chart_tag_position = chart_tag and chart_tag.position or "nil"
  })

  -- Update the surface mapping table from old GPS to new GPS
  local surface_index = old_gps and GPSUtils.get_surface_index_from_gps(old_gps) or nil
  if surface_index and old_gps and new_gps and old_gps ~= new_gps then
    local uint_surface_index = math.floor(tonumber(surface_index) or 1) -- ensure integer
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
    -- Update the lookup table chart_tags_mapped_by_gps
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
    
    -- Invalidate rehydrated favorites cache for all players on this surface
    -- Tag GPS change affects all favorites pointing to this tag
    Cache.invalidate_rehydrated_favorites(nil, uint_surface_index)
  end
end

-- Ensure method is attached to Tag table for module export
Tag.update_gps_and_surface_mapping = Tag.update_gps_and_surface_mapping

return Tag
