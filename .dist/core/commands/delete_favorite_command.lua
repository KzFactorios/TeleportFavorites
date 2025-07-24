---@diagnostic disable: undefined-global


local Constants = require("constants")
local Cache = require("core.cache.cache")
local PlayerHelpers = require("core.utils.player_helpers")
local tag_destroy_helper = require("core.tag.tag_destroy_helper")
local ErrorHandler = require("core.utils.error_handler")
local PlayerFavorites = require("core.favorite.player_favorites")

---@class DeleteFavoriteCommand
local DeleteFavoriteCommand = {}

---@param command table Command data from Factorio API
function DeleteFavoriteCommand._handle_delete_favorite_by_slot(command)
    local player = game.get_player(command.player_index)
    if not player or not player.valid then return end

    local args = command.parameter or ""
    local slot_number = tonumber(args)

    if not slot_number then
        PlayerHelpers.safe_player_print(player, {"teleport-favorites.command-delete-favorite-invalid-format"})
        return
    end

    local player_favorites = Cache.get_player_favorites(player)
    if not player_favorites then
        PlayerHelpers.safe_player_print(player, {"teleport-favorites.no-favorites-found"})
        return
    end

    if not player_favorites[slot_number] then
        PlayerHelpers.safe_player_print(player, {"teleport-favorites.command-delete-favorite-invalid-slot", slot_number})
        return
    end

    local favorite = player_favorites[slot_number]
    if not favorite then
        PlayerHelpers.safe_player_print(player, {"teleport-favorites.command-delete-favorite-invalid-slot", slot_number})
        return
    end

    if not favorite.gps or favorite.gps == Constants.settings.BLANK_GPS then
        PlayerHelpers.safe_player_print(player, {"teleport-favorites.command-delete-favorite-blank-slot", slot_number})
        return
    end

    local pf = PlayerFavorites.new(player)
    local gps = favorite.gps
    local removed, err = pf:remove_favorite(gps)

    local tag = Cache.get_tag_by_gps(player, gps)
    local chart_tag = tag and tag.chart_tag
    local success = true

    if tag and chart_tag and chart_tag.valid then
        success = tag_destroy_helper.destroy_tag_and_chart_tag(tag, chart_tag)
    elseif tag then
        success = tag_destroy_helper.destroy_tag_and_chart_tag(tag, nil)
    end

    local surface_index = player.surface.index
    if Cache and Cache.Lookups and Cache.Lookups.invalidate_surface_chart_tags then
        Cache.Lookups.invalidate_surface_chart_tags(surface_index)
    end

    local ok, GuiObserver = pcall(require, "core.events.gui_observer")
    if ok and GuiObserver and GuiObserver.GuiEventBus and GuiObserver.GuiEventBus.notify then
        pcall(function()
            GuiObserver.GuiEventBus.notify("favorite_removed", { player_index = player.index })
        end)
    end
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


function DeleteFavoriteCommand.register_commands()
    commands.add_command(
        Constants.COMMANDS.DELETE_FAVORITE_BY_SLOT,
        {"teleport-favorites.command-delete-favorite-help"},
        DeleteFavoriteCommand._handle_delete_favorite_by_slot
    )
end

return DeleteFavoriteCommand
