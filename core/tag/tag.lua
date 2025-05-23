---@class Tag
---@field gps string # The GPS string (serves as the index)
---@field chart_tag LuaCustomChartTag|nil # Cached chart tag (private, but no underscore)
---@field faved_by_players uint[] # Array of player indices who have favorited this tag

local Tag = {}
Tag.__index = Tag

--- Constructor for Tag
---@param gps string
---@param faved_by_players uint[]|nil
function Tag:new(gps, faved_by_players)
  assert(type(gps) == "string", "gps must be a string")
  local obj = setmetatable({}, self)
  obj.gps = gps
  obj.chart_tag = nil
  obj.faved_by_players = faved_by_players or {}
  return obj
end

--- Get the related LuaCustomChartTag, retrieving and caching it by gps
---@return LuaCustomChartTag|nil
function Tag:get_chart_tag()
  if not self.chart_tag then
    self.chart_tag = Tag.get_chart_tag_by_gps(self.gps)
  end
  return self.chart_tag
end

--- Static method to fetch a LuaCustomChartTag by gps (implement lookup logic as needed)
---@param gps string
---@return LuaCustomChartTag|nil
function Tag.get_chart_tag_by_gps(gps)
  -- TODO: Implement actual lookup logic using your runtime cache or helpers
  -- Example: return Cache.Lookups.get_chart_tag_by_gps(gps)


  
  return nil
end

--- Add a player index to faved_by_players (if not already present)
---@param player_index uint
function Tag:add_faved_by_player(player_index)
  assert(type(player_index) == "number", "player_index must be a number")
  for _, idx in ipairs(self.faved_by_players) do
    if idx == player_index then return end
  end
  table.insert(self.faved_by_players, player_index)
end

--- Remove a player index from faved_by_players
---@param player_index uint
function Tag:remove_faved_by_player(player_index)
  for i, idx in ipairs(self.faved_by_players) do
    if idx == player_index then
      table.remove(self.faved_by_players, i)
      return
    end
  end
end

return Tag
