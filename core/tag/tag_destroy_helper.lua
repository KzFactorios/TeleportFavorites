--[[
core/tag/tag_destroy_helper.lua
TeleportFavorites Factorio Mod
-----------------------------
Centralized, recursion-safe destruction for tags and chart_tags.

- Ensures tag <-> chart_tag destruction cannot recurse or overflow.
- Handles all edge cases for multiplayer, favorites, and persistent storage.
- Use this helper from all tag/chart_tag destruction logic and event handlers.

API:
-----
- destroy_tag_and_chart_tag(tag, chart_tag)      -- Safely destroy a tag and its associated chart_tag, or vice versa.
- is_tag_being_destroyed(tag)                    -- Check if a tag is being destroyed (recursion guard).
- is_chart_tag_being_destroyed(chart_tag)        -- Check if a chart_tag is being destroyed (recursion guard).
- should_destroy(tag)                            -- Returns false for blank favorites.

Notes:
------
- Always use this helper for tag/chart_tag destruction to avoid recursion and multiplayer edge cases.
- All persistent data is updated and cleaned up, including player favorites and tag storage.
--]]

-- Weak tables to track objects being destroyed
local destroying_tags = setmetatable({}, { __mode = "k" })
local destroying_chart_tags = setmetatable({}, { __mode = "k" })
local Cache = require("core.cache.cache")
local FavoriteUtils = require("core.favorite.favorite")

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

--- Safely destroy a tag and its associated chart_tag, or vice versa.
--- Handles all edge cases and prevents recursion/overflow.
---@param tag table|nil Tag object (may be nil)
---@param chart_tag LuaCustomChartTag|nil Chart tag object (may be nil)
function destroy_tag_and_chart_tag(tag, chart_tag)
  local game = _G.game
  if tag and destroying_tags[tag] then return end
  if tag then destroying_tags[tag] = true end
  if chart_tag and destroying_chart_tags[chart_tag] then return end
  if chart_tag then destroying_chart_tags[chart_tag] = true end
  if chart_tag and chart_tag.valid then chart_tag:destroy() end
  if tag then
    if game and type(game.players) == "table" then
      for _, player in pairs(game.players) do
        local pfaves = Cache.get_player_favorites(player)
        for _, fave in pairs(pfaves) do
          if fave.gps == tag.gps then
            fave.gps = ""; fave.locked = false
            if tag.faved_by_players and type(tag.faved_by_players) == "table" then
              for i = #tag.faved_by_players, 1, -1 do
                if tag.faved_by_players[i] == player.index then table.remove(tag.faved_by_players, i) end
              end
            end
          end
        end
      end
    end
    Cache.remove_stored_tag(tag.gps)
    destroying_tags[tag] = nil
  end
  if chart_tag then destroying_chart_tags[chart_tag] = nil end
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
