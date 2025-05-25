-- tag_destroy_helper.lua
-- Centralized, recursion-safe destruction for tags and chart_tags in TeleportFavorites.
-- Ensures that tag <-> chart_tag destruction cannot recurse or overflow.
-- Use this helper from all tag/chart_tag destruction logic and event handlers.

-- Weak tables to track objects being destroyed
local destroying_tags = setmetatable({}, { __mode = "k" })
local destroying_chart_tags = setmetatable({}, { __mode = "k" })
local Cache = require("core.cache.cache")
local Favorite = require("core.favorite.favorite")

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
  -- Guard: prevent recursion for tag
  if tag and destroying_tags[tag] then return end
  if tag then destroying_tags[tag] = true end
  -- Guard: prevent recursion for chart_tag
  if chart_tag and destroying_chart_tags[chart_tag] then return end
  if chart_tag then destroying_chart_tags[chart_tag] = true end

  -- Destroy chart_tag if valid and not already being destroyed
  if chart_tag and chart_tag.valid then
    chart_tag:destroy() -- This may trigger an event; guard prevents recursion
  end

  -- Destroy tag if not already being destroyed
  if tag then
    -- Remove from all player favorites
    ---@diagnostic disable-next-line
    if game and type(game.players) == "table" then
      ---@diagnostic disable-next-line
      for _, player in pairs(game.players) do
        local faves = Cache.get_player_favorites(player)
        if type(faves) == "table" then
          for _, fave in pairs(faves) do
            if fave.gps == tag.gps then
              fave.gps = ""
              fave.locked = false
              -- Remove player index from faved_by_players
              if tag.faved_by_players and type(tag.faved_by_players) == "table" then
                for i = #tag.faved_by_players, 1, -1 do
                  if tag.faved_by_players[i] == player.index then
                    table.remove(tag.faved_by_players, i)
                  end
                end
              end
            end
          end
        end
      end
    end
    -- Remove from persistent storage
    Cache.remove_stored_tag(tag.gps)
    destroying_tags[tag] = nil -- clear tag guard only after all tag work is done
  end

  -- Clear chart_tag guard immediately (no queue, no on_nth_tick)
  if chart_tag then
    destroying_chart_tags[chart_tag] = nil
  end
end

--- Should this tag be destroyed? Returns false for blank favorites.
---@param tag table|nil
local function should_destroy(tag)
  return not Favorite.is_blank_favorite(tag)
end

return {
  destroy_tag_and_chart_tag = destroy_tag_and_chart_tag,
  is_tag_being_destroyed = is_tag_being_destroyed,
  is_chart_tag_being_destroyed = is_chart_tag_being_destroyed,
  should_destroy = should_destroy
}
