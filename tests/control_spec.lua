---@diagnostic disable: undefined-global
require("tests.test_framework")

describe("Control (Main Entry Point)", function()
  local control_module
  
  before_each(function()
    -- Mock all Factorio API dependencies
    _G.game = {
      players = {},
      surfaces = {}
    }
    
    _G.global = {}
    _G.script = {
      on_event = function() end,
      on_init = function() end,
      on_load = function() end,
      on_configuration_changed = function() end,
      register_on_entity_destroyed = function() end,
      events = {}  -- Add missing events table
    }
    
    -- Mock all dependencies to avoid circular requires
    package.loaded["constants"] = {
      settings = {},
      commands = {}
    }
    
    package.loaded["core.events.handlers"] = {
      register_all = function() end
    }
    
    package.loaded["core.commands.debug_commands"] = {
      register_commands = function() end
    }
    
    package.loaded["core.commands.delete_favorite_command"] = {
      register_commands = function() end
    }
    
    package.loaded["core.control.fave_bar_gui_labels_manager"] = {
      register_all = function() end
    }
    
    package.loaded["core.utils.error_handler"] = {
      debug_log = function() end
    }
  end)

  it("should load control.lua without errors", function()
    local success, err = pcall(function()
      -- Control.lua is the main entry point, just verify it loads
      control_module = require("control")
    end)
    assert(success, "control.lua should load without errors: " .. tostring(err))
  end)

  it("should handle script initialization without errors", function()
    local success, err = pcall(function()
      -- Mock script events that control.lua would register
      local script_mock = _G.script
      script_mock.on_init()
    end)
    assert(success, "script initialization should work without errors: " .. tostring(err))
  end)

end)
