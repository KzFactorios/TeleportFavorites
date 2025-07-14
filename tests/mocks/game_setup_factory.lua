-- tests/mocks/game_setup_factory.lua
-- Centralized factory for common game setup patterns in tests

local GameSetupFactory = {}

--- Create a standard mock surface
---@param index number? Surface index (default 1)
---@param name string? Surface name (default "nauvis")
---@return table surface Mock surface object
function GameSetupFactory.create_mock_surface(index, name)
  return {
    index = index or 1,
    name = name or "nauvis",
    valid = true,
    get_tile = function() return { name = "grass-1" } end
  }
end

--- Create a standard mock player
---@param player_index number Player index
---@param name string? Player name
---@param surface_index number? Surface index (default 1)
---@param additional_fields table? Additional fields to merge
---@return table player Mock player object
function GameSetupFactory.create_mock_player(player_index, name, surface_index, additional_fields)
  local surface = GameSetupFactory.create_mock_surface(surface_index or 1)
  
  local player = {
    index = player_index,
    name = name or ("Player" .. tostring(player_index)),
    valid = true,
    surface = surface,
    mod_settings = {
      ["favorites-on"] = { value = true },
      ["show-player-coords"] = { value = true },
      ["show-teleport-history"] = { value = true },
      ["chart-tag-click-radius"] = { value = 10 }
    },
    admin = false,
    render_mode = "game",
    controller_type = "character",
    position = { x = 0, y = 0 },
    gui = {
      screen = {},
      top = {},
      relative = {}
    }
  }
  
  if additional_fields then
    for k, v in pairs(additional_fields) do
      player[k] = v
    end
  end
  
  return player
end

--- Create a standard mock game object
---@param player_configs table[] Array of player configurations {index, name, surface_index}
---@param surface_configs table[]? Array of surface configurations {index, name}
---@return table game Mock game object
function GameSetupFactory.create_mock_game(player_configs, surface_configs)
  local players = {}
  local surfaces = {}
  
  -- Create surfaces first
  if surface_configs then
    for _, config in ipairs(surface_configs) do
      local surface = GameSetupFactory.create_mock_surface(config.index, config.name)
      surfaces[config.index] = surface
    end
  else
    -- Default surface
    surfaces[1] = GameSetupFactory.create_mock_surface(1, "nauvis")
  end
  
  -- Create players
  for _, config in ipairs(player_configs or {}) do
    local player = GameSetupFactory.create_mock_player(
      config.index, 
      config.name, 
      config.surface_index,
      config.additional_fields
    )
    players[config.index] = player
  end
  
  return {
    players = players,
    surfaces = surfaces,
    get_player = function(index) return players[index] end,
    tick = 1000,
    forces = {
      player = {
        find_chart_tags = function() return {} end
      }
    }
  }
end

--- Create a standard test environment with game, defines, and common globals
---@param player_configs table[] Array of player configurations
---@param surface_configs table[]? Array of surface configurations
---@return table environment Environment with game, defines, script globals
function GameSetupFactory.create_test_environment(player_configs, surface_configs)
  local game = GameSetupFactory.create_mock_game(player_configs, surface_configs)
  
  local defines = {
    render_mode = {
      chart = "chart",
      chart_zoomed_in = "chart-zoomed-in", 
      game = "game"
    },
    events = {
      on_player_selected_area = 1,
      on_player_alt_selected_area = 2
    },
    controllers = {
      character = 1,
      god = 2
    },
    disconnect_reason = {
      switching_servers = 1,
      kicked_and_deleted = 2,
      banned = 3
    }
  }
  
  local script = {
    on_nth_tick = function(_, callback) 
      if callback then callback() end
      return true
    end,
    on_event = function() end,
    register_on_entity_destroyed = function() end
  }
  
  return {
    game = game,
    defines = defines,
    script = script
  }
end

--- Set up standard test globals (modifies _G)
---@param player_configs table[] Array of player configurations
---@param surface_configs table[]? Array of surface configurations
function GameSetupFactory.setup_test_globals(player_configs, surface_configs)
  local env = GameSetupFactory.create_test_environment(player_configs, surface_configs)
  
  _G.game = env.game
  _G.defines = env.defines
  _G.script = env.script
end

--- Quick setup for single player tests
---@param player_index number? Player index (default 1)
---@param player_name string? Player name (default "test_player")
---@param surface_index number? Surface index (default 1)
function GameSetupFactory.setup_single_player_test(player_index, player_name, surface_index)
  GameSetupFactory.setup_test_globals({
    {
      index = player_index or 1,
      name = player_name or "test_player",
      surface_index = surface_index or 1
    }
  })
end

--- Quick setup for multiplayer tests
---@param player_count number Number of players to create
---@param surface_count number? Number of surfaces to create (default 1)
function GameSetupFactory.setup_multiplayer_test(player_count, surface_count)
  local player_configs = {}
  local surface_configs = {}
  
  -- Create surface configurations
  for i = 1, (surface_count or 1) do
    table.insert(surface_configs, { index = i, name = i == 1 and "nauvis" or ("surface_" .. i) })
  end
  
  -- Create player configurations
  for i = 1, player_count do
    table.insert(player_configs, {
      index = i,
      name = "Player" .. i,
      surface_index = ((i - 1) % (surface_count or 1)) + 1
    })
  end
  
  GameSetupFactory.setup_test_globals(player_configs, surface_configs)
end

--- Basic game setup that returns game state information
---@return table game_state Contains surface and player references
function GameSetupFactory.setup_basic_game()
  GameSetupFactory.setup_single_player_test(1, "test_player", 1)
  return {
    surface = _G.game.surfaces[1],
    player = _G.game.players[1]
  }
end

return GameSetupFactory
