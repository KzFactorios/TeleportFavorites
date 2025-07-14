---@diagnostic disable: undefined-global
--[[
core/commands/delete_favorite_command.lua
TeleportFavorites Factorio Mod
-----------------------------
Commands for deleting favorites by slot number.

This module provides a console command for deleting favorites by slot number,
using the same deletion logic as tag_destroy_helper.

Command:
- /tf-delete-favorite-slot <slot_number> - Delete favorite in the specified slot
]]


local Constants = require("constants")
local Cache = require("core.cache.cache")
local PlayerHelpers = require("core.utils.player_helpers")
local tag_destroy_helper = require("core.tag.tag_destroy_helper")
local ErrorHandler = require("core.utils.error_handler")
local FavoriteUtils = require("core.favorite.favorite")
local GPSUtils = require("core.utils.gps_utils")
local PlayerFavorites = require("core.favorite.player_favorites")

---@class DeleteFavoriteCommand
local DeleteFavoriteCommand = {}

--- Handler for the delete favorite by slot command
---@param command table Command data from Factorio API
function DeleteFavoriteCommand._handle_delete_favorite_by_slot(command)
    local player = game.get_player(command.player_index)
    if not player or not player.valid then return end

    local args = command.parameter or ""
    local slot_number = tonumber(args)

    -- Validate input
    if not slot_number then
        PlayerHelpers.safe_player_print(player, {"teleport-favorites.command-delete-favorite-invalid-format"})
        return
    end

    -- Validate slot number
    local player_favorites = Cache.get_player_favorites(player)
    if not player_favorites then
        PlayerHelpers.safe_player_print(player, {"teleport-favorites.no-favorites-found"})
        return
    end

    -- Check if the slot exists and has a valid favorite
    if not player_favorites[slot_number] then
        PlayerHelpers.safe_player_print(player, {"teleport-favorites.command-delete-favorite-invalid-slot", slot_number})
        return
    end

    -- Get the favorite data
    local favorite = player_favorites[slot_number]
    if not favorite then
        PlayerHelpers.safe_player_print(player, {"teleport-favorites.command-delete-favorite-invalid-slot", slot_number})
        return
    end
    
    -- If there's no GPS or it's a blank favorite, there's nothing to delete
    if not favorite.gps or favorite.gps == Constants.settings.BLANK_GPS then
        PlayerHelpers.safe_player_print(player, {"teleport-favorites.command-delete-favorite-blank-slot", slot_number})
        return
    end

    -- Remove the favorite using PlayerFavorites logic to update all references
    local pf = PlayerFavorites.new(player)
    local gps = favorite.gps
    local removed, err = pf:remove_favorite(gps)

    -- After removal, fetch the tag from storage (not from the blanked favorite)
    local tag = Cache.get_tag_by_gps(player, gps)
    local chart_tag = tag and tag.chart_tag
    local success = true
    
    -- Only attempt destruction if we have both tag and a valid chart_tag
    if tag and chart_tag and chart_tag.valid then
        success = tag_destroy_helper.destroy_tag_and_chart_tag(tag, chart_tag)
    elseif tag then
        -- Tag exists but chart_tag is invalid/missing - just clean up the tag
        success = tag_destroy_helper.destroy_tag_and_chart_tag(tag, nil)
    end

    -- Invalidate chart tag lookup cache for this surface
    local surface_index = player.surface.index
    if Cache and Cache.Lookups and Cache.Lookups.invalidate_surface_chart_tags then
        Cache.Lookups.invalidate_surface_chart_tags(surface_index)
    end

    -- Notify observers to refresh the favorites bar
    local ok, GuiObserver = pcall(require, "core.events.gui_observer")
    if ok and GuiObserver and GuiObserver.GuiEventBus and GuiObserver.GuiEventBus.notify then
        pcall(function()
            GuiObserver.GuiEventBus.notify("favorite_removed", { player_index = player.index })
        end)
    end
    -- Also try remote interface as fallback
    if remote and remote.interfaces and remote.interfaces["TeleportFavorites"] and remote.interfaces["TeleportFavorites"].refresh_favorites_bar then
        pcall(function() remote.call("TeleportFavorites", "refresh_favorites_bar", player.index) end)
    end

    if removed and success then
        PlayerHelpers.safe_player_print(player, {"teleport-favorites.command-delete-favorite-success", slot_number})
    else
        PlayerHelpers.safe_player_print(player, {"teleport-favorites.command-delete-favorite-failed", slot_number})
        ErrorHandler.debug_log("Failed to delete favorite using tag_destroy_helper", { 
            slot = slot_number,
            gps = gps,
            err = err
        })
    end
end

--- Register all delete favorite commands

--- Register all delete favorite commands
function DeleteFavoriteCommand.register_commands()
    commands.add_command(
        Constants.COMMANDS.DELETE_FAVORITE_BY_SLOT,
        {"teleport-favorites.command-delete-favorite-help"},
        DeleteFavoriteCommand._handle_delete_favorite_by_slot
    )
end

return DeleteFavoriteCommand
