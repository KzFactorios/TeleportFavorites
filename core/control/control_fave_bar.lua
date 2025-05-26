-- control_fave_bar.lua
-- Handles favorites bar GUI events for TeleportFavorites

local defines = _G.defines
local game = _G.game

local PlayerFavorites = require("core.favorite.player_favorites")
local Favorite = require("core.favorite.favorite")
local GPS = require("core.gps.gps")
local fave_bar = require("gui.favorites_bar.fave_bar")
local Cache = require("core.cache.cache")
local helpers = require("core.utils.helpers")
local safe_destroy_frame = helpers.safe_destroy_frame
local player_print = helpers.player_print
local safe_teleport = helpers.safe_teleport
local tag_editor = require("gui.tag_editor.tag_editor")

local M = {}

local function lstr(key, ...)
  return {key, ...}
end

--- Register favorites bar event handlers
--- @param script table The Factorio script object
function M.register(script)
  script.on_event(defines.events.on_gui_click, function(event)
    local element = event.element
    if not element or not element.valid then return end
    local player = game.get_player(event.player_index)
    if not player then return end
    local favorites = PlayerFavorites.new(player)
    local function clear_drag_state()
      if _G.storage and _G.storage.players and _G.storage.players[player.index] then
        _G.storage.players[player.index].drag_favorite_index = nil
      end
    end
    if element.name:find("^favorite_slot_") then
      local slot = tonumber(element.name:match("favorite_slot_(%d+)"))
      if not slot then return end
      local fav = favorites.favorites[slot]
      local drag_index = _G.storage.players[player.index].drag_favorite_index
      if event.button == defines.mouse_button_type.left and not event.control then
        if not drag_index then
          if fav and not Favorite.is_blank_favorite(fav) and not fav.locked then
            _G.storage.players[player.index].drag_favorite_index = slot
            player_print(player, lstr("tf-gui.fave_bar_drag_start", slot))
          end
        else
          local favs = favorites.favorites
          if drag_index ~= slot then
            if favs and drag_index and favs[drag_index] and favs[drag_index].locked then
              player_print(player, lstr("tf-gui.fave_bar_locked_move"))
              clear_drag_state()
              return
            end
            local moved = table.remove(favs, drag_index)
            table.insert(favs, slot, moved)
            favorites:set_favorites(favs)
            local parent = player.gui.top
            safe_destroy_frame(parent, "fave_bar_frame")
            fave_bar.build(player, parent)
            player_print(player, lstr("tf-gui.fave_bar_reordered", drag_index, slot))
          end
          clear_drag_state()
        end
      end
      if event.button == defines.mouse_button_type.left and not event.control then
        if fav and not Favorite.is_blank_favorite(fav) then
          local pos = GPS.map_position_from_gps(fav.gps)
          if pos then
            safe_teleport(player, pos, player.surface)
            player_print(player, lstr("tf-gui.teleported_to_favorite", slot))
          else
            player_print(player, lstr("tf-gui.teleport_failed"))
          end
        end
      elseif event.button == defines.mouse_button_type.right then
        if fav and not Favorite.is_blank_favorite(fav) then
          local parent = player.gui.screen
          safe_destroy_frame(parent, "tag_editor_frame")
          tag_editor.build(player, parent, fav.tag or {})
        end
      end
    elseif element.name == "fave_toggle" then
      local parent = player.gui.top
      parent["fave_bar_frame"].visible = not parent["fave_bar_frame"].visible
    end
  end)
end

return M
