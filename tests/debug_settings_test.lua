--[[
Debug test to simulate settings changes and see debug output
This is a standalone test to diagnose the settings issue
--]]

-- Mock the debug environment
local function mock_factorio_environment()
  -- Mock game object
  game = {
    tick = 100,
    connected_players = {},
    players = {}
  }
  
  -- Mock defines
  defines = {
    events = {
      on_runtime_mod_setting_changed = 1001
    },
    render_mode = {
      game = 1,
      chart = 2,
      chart_zoomed_in = 3
    },
    controllers = {
      god = 1,
      spectator = 2
    }
  }
  
  -- Mock storage
  storage = {
    players = {},
    surfaces = {}
  }
  
  -- Mock script
  script = {
    on_event = function(event_id, handler)
      print("Registered event: " .. tostring(event_id))
    end
  }
end

local function create_mock_player(name, index)
  local player = {
    name = name,
    index = index,
    valid = true,
    controller_type = defines.render_mode.game,
    render_mode = defines.render_mode.game,
    mod_settings = {
      favorites_on = { value = true },
      enable_teleport_history = { value = true }
    },
    gui = {
      top = {
        children = {},
        add = function() return {} end
      }
    }
  }
  
  game.players[index] = player
  game.connected_players[#game.connected_players + 1] = player
  return player
end

-- Initialize mock environment
mock_factorio_environment()

-- Load required modules
package.path = package.path .. ";.\\?.lua;.\\core\\?.lua;.\\core\\cache\\?.lua;.\\core\\utils\\?.lua;.\\core\\events\\?.lua"

print("=== Debug Settings Test ===")

-- Basic settings test
print("Testing if we can load constants...")
local success, result = pcall(require, "constants")
if success then
  print("Constants loaded successfully")
  print("DEFAULT_HISTORY_UPDATE_INTERVAL:", result.settings.DEFAULT_HISTORY_UPDATE_INTERVAL)
else  
  print("Failed to load constants:", result)
end

print("\n=== End Debug Test ===")
