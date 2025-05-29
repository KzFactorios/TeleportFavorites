-- tests/test_bootstrap.lua
-- Factorio integration test bootstrap

-- Patch Factorio globals
if not _G.defines then
  _G.defines = setmetatable({
    render_mode = { game = 0, chart = 1, chart_zoomed_in = 2 },
    events = {},
    gui_type = {},
    direction = {},
    inventory = {},
  }, { __index = function() return {} end })
end

if not _G.game then _G.game = {} end
_G.game.get_player = function(index)
  return _G.__test_player
end

-- Patch persistent storage
global = _G.global or {}
_G.global = global
storage = _G.storage or {}
_G.storage = storage

-- Patch Cache.get_player_data to always return storage.players[player.index]
package.loaded["core.cache.cache"] = nil
local Cache = require("core.cache.cache")
Cache.get_player_data = function(player)
  return storage.players[player.index]
end
if package.loaded["core.cache.cache"] ~= nil then
  package.loaded["core.cache.cache"].get_player_data = Cache.get_player_data
end

-- Utility to reload a module
function reload_module(name)
  package.loaded[name] = nil
  return require(name)
end

-- Debug utility: print addresses and key state
function debug_state(label, player, bar_flow)
  print("[DEBUG]", label)
  print("  player:", tostring(player))
  print("  storage.players[player.index]:", tostring(storage.players[player.index]))
  if bar_flow then
    print("  bar_flow:", tostring(bar_flow))
    for i, child in ipairs(bar_flow.children or {}) do
      print("    child", i, "name:", child.name, "address:", tostring(child), "visible:", tostring(child.visible))
    end
  end
  print("  toggle_fav_bar_buttons:", storage.players[player.index] and storage.players[player.index].toggle_fav_bar_buttons)
end
