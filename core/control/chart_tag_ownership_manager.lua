---@diagnostic disable: undefined-global

-- core/control/chart_tag_ownership_manager.lua
-- TeleportFavorites Factorio Mod
-- Manages chart tag ownership lifecycle, cleanup, and transfer utilities.
--
-- PLAYER STATE HANDLING:
-- - Temporarily offline (player.connected == false): Ownership PRESERVED
-- - Kicked/banned (on_player_left_game): Ownership PRESERVED (can rejoin)
-- - Permanently removed (on_player_removed): Ownership RESET to nil
--
-- The Tag.owner_name field stores the player's name as a string, which persists
-- even when the player is offline, kicked, or banned. Only permanent removal
-- via on_player_removed triggers ownership cleanup.

local Cache = require("core.cache.cache")
local ErrorHandler = require("core.utils.error_handler")


--- Ensure Cache is initialized before accessing Lookups
local function ensure_cache_initialized()
  if not Cache.Lookups then
    -- no-op for test
  end
end

---@class ChartTagOwnershipManager
local ChartTagOwnershipManager = {}

--- Reset ownership for all Tags owned by a specific player
---@param player_name string Name of the player whose ownership should be reset
function ChartTagOwnershipManager.reset_ownership_for_player(player_name)
  if not player_name or player_name == "" then
    ErrorHandler.warn_log("Cannot reset ownership: invalid player name")
    return 0
  end
  local reset_count = 0
  ensure_cache_initialized()
  
  -- Iterate through all surfaces and their tags
  for _, surface in pairs(game.surfaces) do
    if surface and surface.valid then
      local surface_tags = Cache.get_surface_tags(surface.index)
      if surface_tags then
        for gps, tag in pairs(surface_tags) do
          -- Reset Tag.owner_name if it matches the removed player
          if tag and tag.owner_name == player_name then
            tag.owner_name = nil
            reset_count = reset_count + 1
          end
        end
      end
    end
  end
  
  return reset_count
end

---@param event table Player left game event
function ChartTagOwnershipManager.on_player_left_game(event)
  local player = game.get_player(event.player_index)
  if not player then
    ErrorHandler.warn_log("Cannot handle player left: invalid player index", {
      player_index = event.player_index
    })
    return
  end
  
  -- DO NOT reset ownership when players leave the game
  -- Players who are kicked, banned, or disconnected can still rejoin
  -- Only on_player_removed (permanent deletion) should reset ownership
  -- The Tag.owner_name field persists in storage and preserves ownership
  -- even when the player is offline or kicked/banned
  
  ErrorHandler.debug_log("Player left game (ownership preserved)", {
    player_name = player.name,
    reason = event.reason or "unknown"
  })
end

---@param event table Player removed event
function ChartTagOwnershipManager.on_player_removed(event)
  -- IMPORTANT: This event fires when a player is PERMANENTLY removed from the game
  -- This is different from being kicked, banned, or disconnected - those players
  -- can still rejoin. on_player_removed means the player is deleted from the save
  -- and their player object will have player.valid == false.
  
  local player = game.get_player(event.player_index)
  if not player then
    ErrorHandler.warn_log("Cannot handle player removed: invalid player index", {
      player_index = event.player_index
    })
    return
  end
  local player_name = player.name
  local reset_count = ChartTagOwnershipManager.reset_ownership_for_player(player_name)
  if reset_count > 0 then
    ErrorHandler.debug_log("Reset chart tag ownership due to player removal", {
      player_name = player_name,
      reset_count = reset_count
    })
  end
end

return ChartTagOwnershipManager
