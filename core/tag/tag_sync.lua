---@diagnostic disable: undefined-global
local Tag = require("core.tag.tag")
local Helpers_gps = require("core/utils/Helpers_gps")
local Cache = require("core/cache/cache")

---@class TagSync
---@field tag Tag # The Tag instance this sync object manages
local TagSync = {}
TagSync.__index = TagSync

--- Constructor for TagSync
---@param tag Tag
---@return TagSync
function TagSync:new(tag)
  assert(tag and type(tag) == "table", "TagSync requires a Tag instance")
  local obj = setmetatable({}, self)
  obj.tag = tag
  return obj
end

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
---@return LuaCustomChartTag
function TagSync.ensure_chart_tag_for_tag(tag)
---@diagnostic disable-next-line: unnecessary-assert
  assert(tag and tag.gps, "Tag required")
  local chart_tag = tag.chart_tag
  if chart_tag then return chart_tag end
  -- Convert tag.gps to position and surface
  local pos, surface_index = Helpers_gps.gps_to_position_and_surface(tag.gps)
  local surface = game.surfaces[surface_index]
  assert(surface, "Surface not found for tag.gps: " .. tag.gps)
  -- Create the chart_tag
  local chart_tag_spec = {
    position = pos,
    text = tag.gps,
    surface = surface,
    last_user = "",
  }
  local chart_tag_obj = surface.create_entity{
    name = "map-tag",
    position = pos,
    force = game.forces["player"],
    text = tag.gps,
  }
  tag.chart_tag = chart_tag_obj
  return chart_tag_obj
end

--- Static method: Remove a tag and its related chart_tag from all collections
---@param tag Tag
function TagSync.remove_tag_and_chart_tag(tag)
  assert(tag and tag.gps, "Tag required")
  -- Remove chart_tag if it exists
  local chart_tag = tag:get_chart_tag()
  if chart_tag and chart_tag.valid then
    chart_tag.destroy()
  end
  -- Remove tag from persistent storage (example, actual logic may differ)
  local surface_index = Helpers_gps.gps_to_surface_index(tag.gps)
  local surface_data = Cache.get_surface_data(surface_index)
  if surface_data and surface_data.tags then
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
    ---@diagnostic disable-next-line: undefined-field
    if chart_tag and chart_tag.valid then
      -- Use pcall to safely attempt destroy methods (static analysis workaround)
      ---@diagnostic disable-next-line: undefined-field
      local ok = false
      if pcall(function() chart_tag:destroy() end) then
        ok = true
      ---@diagnostic disable-next-line: undefined-field
      elseif pcall(function() chart_tag:destroy_tag() end) then
        ok = true
      end
    end
    -- Remove tag from persistent storage
    local surface_index = Helpers_gps.gps_to_surface_index(tag.gps)
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