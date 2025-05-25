local Constants = require("constants")
local Tag = require("core.tag.tag")
local PlayerFavorites = require("core.favorite.player_favorites")
local tag_destroy_helper = require("core.tag.tag_destroy_helper")
local GPS = require("core.gps.gps")
local handlers = require("core.events.handlers")

---@diagnostic disable: undefined-global
---@class Control
local Control = {}
Control.__index = Control

--- Called once when the mod is first initialized (new save or mod added)
script.on_init(handlers.on_init)

--- Called every time a save is loaded (including after on_init)
script.on_load(handlers.on_load)

script.on_event(defines.events.on_player_changed_surface, handlers.on_player_changed_surface)

-- Register custom input for opening tag editor (right-click or hotkey)
--[[script.on_event(Constants.enums.events.ON_OPEN_TAG_EDITOR, handlers.on_open_tag_editor)]]

-- Register teleport hotkeys
for i = 1, Constants.settings.MAX_FAVORITE_SLOTS do
  local event_name = Constants.enums.events.TELEPORT_TO_FAVORITE .. tostring(i)
  script.on_event(event_name, function(event)
    handlers.on_teleport_to_favorite(event, i)
  end)
end

-- Factorio chart tag events (see https://lua-api.factorio.com/latest/events.html)
script.on_event(defines.events.on_chart_tag_added, handlers.on_chart_tag_added)
script.on_event(defines.events.on_chart_tag_modified, handlers.on_chart_tag_modified)
script.on_event(defines.events.on_chart_tag_removed, handlers.on_chart_tag_removed)

return Control
