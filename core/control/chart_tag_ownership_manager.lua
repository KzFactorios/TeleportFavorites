-- filepath: v:\Fac2orios\2_Gemini\mods\TeleportFavorites\core\control\chart_tag_ownership_manager.lua
---@diagnostic disable: undefined-global
--[[
chart_tag_ownership_manager.lua
TeleportFavorites Factorio Mod
-----------------------------
Manages chart tag ownership lifecycle and cleanup operations.

Features:
---------
- Handles chart tag ownership when players leave/are removed
- Resets chart tag ownership to "" when owner leaves
- Updates lookup collections when ownership changes
- Provides utilities for ownership validation and transfer

Core Principle:
---------------
- Only the player who CREATES a tag becomes the owner
- Ownership does NOT change when other players edit the tag
- Ownership only resets when the owner leaves/is removed from the game
- When ownership is reset, all related lookup collections are updated
--]]

local Cache = require("core.cache.cache")
local ErrorHandler = require("core.utils.error_handler")
local CollectionUtils = require("core.utils.collection_utils")

--- Ensure Cache is initialized before accessing Lookups
local function ensure_cache_initialized()
  if not Cache.Lookups then
    Cache.init()
  end
end

---@class ChartTagOwnershipManager
local ChartTagOwnershipManager = {}

--- Reset ownership for all chart tags owned by a specific player
---@param player_name string Name of the player whose ownership should be reset
---@return number count Number of chart tags that had ownership reset
function ChartTagOwnershipManager.reset_ownership_for_player(player_name)
  if not player_name or player_name == "" then
    ErrorHandler.warn_log("Cannot reset ownership: invalid player name")
    return 0
  end
  ErrorHandler.debug_log("Starting ownership reset for player", {
    player_name = player_name
  })
  local reset_count = 0
  local affected_surfaces = {}

  -- Ensure Cache is initialized before accessing Lookups
  ensure_cache_initialized()

  -- Use our lookup cache to find chart tags instead of non-existent find_chart_tags API
  for _, surface in pairs(game.surfaces) do
    if surface and surface.valid then
      local surface_cache = Cache.Lookups.get_chart_tag_cache(surface.index)

      for _, chart_tag in pairs(surface_cache or {}) do
        if chart_tag and chart_tag.valid and chart_tag.last_user == player_name then
          -- Reset ownership to empty string
          ---@diagnostic disable-next-line: assign-type-mismatch
          chart_tag.last_user = ""
          reset_count = reset_count + 1
          affected_surfaces[surface.index] = true

          ErrorHandler.debug_log("Reset chart tag ownership", {
            surface = surface.name,
            position = chart_tag.position,
            old_owner = player_name,
            text = chart_tag.text or ""
          })
        end
      end
    end
  end

  -- Invalidate lookup caches for affected surfaces
  for surface_index, _ in pairs(affected_surfaces) do
    Cache.Lookups.invalidate_surface_chart_tags(surface_index)
    ErrorHandler.debug_log("Invalidated chart tag cache for surface", {
      surface_index = surface_index
    })
  end
  ErrorHandler.debug_log("Ownership reset completed", {
    player_name = player_name,
    reset_count = reset_count,
    affected_surfaces_count = CollectionUtils.table_count(affected_surfaces)
  })

  return reset_count
end

--- Check if a player owns any chart tags
---@param player_name string Name of the player to check
---@return boolean has_owned_tags True if player owns any chart tags
---@return number count Number of chart tags owned by the player
function ChartTagOwnershipManager.player_owns_chart_tags(player_name)
  if not player_name or player_name == "" then
    return false, 0
  end

  -- Ensure Cache is initialized before accessing Lookups  
  ensure_cache_initialized()

  local owned_count = 0
  -- Use our lookup cache instead of non-existent find_chart_tags API
  for _, surface in pairs(game.surfaces) do
    if surface and surface.valid then
      local surface_cache = Cache.Lookups.get_chart_tag_cache(surface.index)

      for _, chart_tag in pairs(surface_cache or {}) do
        if chart_tag and chart_tag.valid and chart_tag.last_user == player_name then
          owned_count = owned_count + 1
        end
      end
    end
  end

  return owned_count > 0, owned_count
end

--- Validate chart tag ownership against a player
---@param chart_tag LuaCustomChartTag Chart tag to validate
---@param player LuaPlayer Player to check ownership against
---@return boolean is_owner True if player owns the chart tag
function ChartTagOwnershipManager.validate_ownership(chart_tag, player)
  if not chart_tag or not chart_tag.valid then
    return false
  end

  if not player or not player.valid then
    return false
  end

  -- If no owner set, anyone can claim ownership (for legacy tags)
  if not chart_tag.last_user or chart_tag.last_user == "" then
    return true
  end

  return chart_tag.last_user == player.name
end

--- Set initial ownership for a chart tag (only if no owner exists)
---@param chart_tag LuaCustomChartTag Chart tag to set ownership for
---@param player LuaPlayer Player to set as owner
---@return boolean success True if ownership was set
function ChartTagOwnershipManager.set_initial_ownership(chart_tag, player)
  if not chart_tag or not chart_tag.valid then
    return false
  end

  if not player or not player.valid then
    return false
  end
  -- Only set ownership if no owner exists
  if not chart_tag.last_user or chart_tag.last_user == "" then
    ---@diagnostic disable-next-line: assign-type-mismatch
    chart_tag.last_user = player.name

    ErrorHandler.debug_log("Set initial chart tag ownership", {
      owner = player.name,
      position = chart_tag.position,
      text = chart_tag.text or ""
    })

    return true
  end

  return false
end

--- Handle player leaving the game - reset their chart tag ownership
---@param event table Player left game event
function ChartTagOwnershipManager.on_player_left_game(event)
  local player = game.get_player(event.player_index)
  if not player then
    ErrorHandler.warn_log("Cannot handle player left: invalid player index", {
      player_index = event.player_index
    })
    return
  end

  local player_name = player.name
  ErrorHandler.debug_log("Player left game - checking chart tag ownership", {
    player_name = player_name,
    player_index = event.player_index
  })
  local reset_count = 0
  local reason = event.reason or ""
  if reason == (defines.disconnect_reason.switching_servers or defines.disconnect_reason.kicked_and_deleted or defines.disconnect_reason.banned) then
    -- Reset ownership for all chart tags owned by this player
    ---@diagnostic disable-next-line: assign-type-mismatch
    reset_count = ChartTagOwnershipManager.reset_ownership_for_player(player_name)
  end

  --[[ These are the other reasons
   defines.disconnect_reason.afk	
  defines.disconnect_reason.quit	
  defines.disconnect_reason.dropped	
  defines.disconnect_reason.reconnect	
  defines.disconnect_reason.wrong_input	
  defines.disconnect_reason.desync_limit_reached	
  defines.disconnect_reason.cannot_keep_up	
  defines.disconnect_reason.kicked
  ]]

  if reset_count > 0 then
    ErrorHandler.debug_log("Reset chart tag ownership due to player leaving", {
      player_name = player_name,
      reset_count = reset_count
    })
  end
end

--- Handle player being removed from the game - reset their chart tag ownership
---@param event table Player removed event
function ChartTagOwnershipManager.on_player_removed(event)
  local player = game.get_player(event.player_index)
  if not player then
    ErrorHandler.warn_log("Cannot handle player removed: invalid player index", {
      player_index = event.player_index
    })
    return
  end

  local player_name = player.name
  ErrorHandler.debug_log("Player removed - checking chart tag ownership", {
    player_name = player_name,
    player_index = event.player_index
  })
  -- Reset ownership for all chart tags owned by this player
  ---@diagnostic disable-next-line: assign-type-mismatch
  local reset_count = ChartTagOwnershipManager.reset_ownership_for_player(player_name)

  if reset_count > 0 then
    ErrorHandler.debug_log("Reset chart tag ownership due to player removal", {
      player_name = player_name,
      reset_count = reset_count
    })
  end
end

--- Reset ownership for orphaned chart tags (players who no longer have mod data)
--- This handles cases where players removed the mod but their chart tags remain
---@return number count Number of orphaned chart tags that had ownership reset
function ChartTagOwnershipManager.reset_orphaned_ownership()
  ErrorHandler.debug_log("Starting orphaned ownership cleanup")

  -- Ensure Cache is initialized before accessing Lookups
  ensure_cache_initialized()

  local reset_count = 0
  local affected_surfaces = {}
  local valid_players = {} -- Build set of valid player names who currently have mod data
  for player_index, player in pairs(game.players) do
    -- Try to get player data - if it fails, player doesn't have mod data
    ---@cast player LuaPlayer
    local success, player_data = pcall(Cache.get_player_data, player)
    if success and player_data then
      valid_players[player.name] = true
    end
  end
  -- Check all chart tags for ownership by players who no longer have mod data
  for _, surface in pairs(game.surfaces) do
    if surface and surface.valid then
      local surface_cache = Cache.Lookups.get_chart_tag_cache(surface.index)

      for _, chart_tag in pairs(surface_cache or {}) do
        if chart_tag and chart_tag.valid and chart_tag.last_user and chart_tag.last_user ~= "" then
          -- If the owner no longer has mod data, reset ownership
          if not valid_players[chart_tag.last_user] then
            local orphaned_owner = chart_tag.last_user
            ---@diagnostic disable-next-line: assign-type-mismatch
            chart_tag.last_user = ""
            reset_count = reset_count + 1
            affected_surfaces[surface.index] = true

            ErrorHandler.debug_log("Reset orphaned chart tag ownership", {
              surface = surface.name,
              position = chart_tag.position,
              orphaned_owner = orphaned_owner,
              text = chart_tag.text or ""
            })
          end
        end
      end
    end
  end

  -- Invalidate lookup caches for affected surfaces
  for surface_index, _ in pairs(affected_surfaces) do
    Cache.Lookups.invalidate_surface_chart_tags(surface_index)
    ErrorHandler.debug_log("Invalidated chart tag cache for surface", {
      surface_index = surface_index
    })
  end
  ErrorHandler.debug_log("Orphaned ownership cleanup completed", {
    reset_count = reset_count,
    affected_surfaces_count = CollectionUtils.table_count(affected_surfaces)
  })

  return reset_count
end

return ChartTagOwnershipManager
