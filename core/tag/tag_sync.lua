---@diagnostic disable: undefined-global
local Tag = require("core.tag.tag")
local GPS = require("core/gps/gps")
local Cache = require("core/cache/cache")

---@class TagSync
---@field tag Tag # The Tag instance this sync object manages
local TagSync = {}
TagSync.__index = TagSync

--- Example instance method: synchronize tag with chart_tag
function TagSync:synchronize()
  -- Implement logic to ensure tag and chart_tag are in sync
  -- e.g., update chart_tag if tag.gps changes, or vice versa
end

--- Example instance method: remove tag and associated chart_tag
function TagSync:remove()
  -- Implement logic to remove both tag and its chart_tag from storage/cache
end

--- Static method: Ensure a chart_tag exists for a given Tag, creating one if needed
---@param tag Tag
---@return LuaEntity?  -- Factorio returns LuaEntity for map-tag
function TagSync.ensure_chart_tag(tag)
  local chart_tag = tag.chart_tag
  if chart_tag then return chart_tag end
  local map_pos = GPS.map_position_from_gps(tag.gps)
  local surface_index = GPS.get_surface_index(tag.gps)
  if not map_pos or not surface_index then error("Invalid GPS string: " .. tostring(tag.gps)) end
  local surface = game.surfaces[surface_index]
  if not surface then error("Surface not found for tag.gps: " .. tag.gps) end
  local chart_tag_obj = surface.create_entity{
    name = "map-tag",
    position = map_pos,
    force = game.forces["player"],
    text = tag.gps,
  }
  tag.chart_tag = chart_tag_obj -- LuaEntity
  return chart_tag_obj
end

--- Static method: Remove a tag and its related chart_tag from all collections
---@param tag Tag
function TagSync.remove_tag_and_chart_tag(tag)
  local chart_tag = tag.chart_tag
  if chart_tag and chart_tag.valid then
    chart_tag.destroy()
  end
  local surface_index = GPS.get_surface_index(tag.gps)
  local surface_data = Cache.get_surface_data(surface_index)
  if surface_data then
    if not surface_data.tags then surface_data.tags = {} end
    surface_data.tags[tag.gps] = nil
    Cache.set("surfaces", Cache.get("surfaces"))
  end
end

--- Remove a player from tag's faved_by_players, and handle cascading deletion if needed
---@param tag Tag
---@param player_index uint
function TagSync.delete_tag_for_player(tag, player_index)
  -- Remove player_index robustly (handles concurrent access)
  local faved_by_players = tag.faved_by_players or {}
  local new_faved = {}
  for _, idx in ipairs(faved_by_players) do
    if idx ~= player_index then
      table.insert(new_faved, idx)
    end
  end
  tag.faved_by_players = new_faved

  if #tag.faved_by_players == 0 then
    -- Remove chart_tag if it exists and is valid
    local chart_tag = tag.chart_tag
    if chart_tag and chart_tag.valid then
      local ok = false
      if pcall(function() chart_tag:destroy() end) then
        ok = true
      elseif pcall(function() chart_tag:destroy_tag() end) then
        ok = true
      end
    end
    -- Remove tag from persistent storage
    local surface_index = GPS.get_surface_index(tag.gps)
    local surface_data = Cache.get_surface_data(surface_index)
    if type(surface_data) == "table" and type(surface_data.tags) == "table" then
      surface_data.tags[tag.gps] = nil
      Cache.set("surfaces", Cache.get("surfaces"))
    end
    -- Refresh chart_tag cache if available
    local lookups = Cache.lookups
    if type(lookups) == "table" and type(lookups.refresh_chart_tags) == "function" then
      lookups.refresh_chart_tags()
    end
  else
    -- If still faved, do not touch chart_tag or tag
    return
  end
end

return TagSync