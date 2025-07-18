---@diagnostic disable: undefined-global
--[[
core/commands/debug_commands.lua
TeleportFavorites Factorio Mod
-----------------------------
Debug commands for runtime debug level control.

This module provides console commands and GUI controls for changing
debug levels during gameplay without requiring restarts.

Commands:
- /tf_debug_level <level> - Set debug level (0-5)
- /tf_debug_info - Show current debug configuration
- /tf_debug_production - Enable production mode (minimal logging)
- /tf_debug_development - Enable development mode (verbose logging)
]]
local basic_helpers = require("core.utils.basic_helpers")
local ValidationUtils = require("core.utils.validation_utils")
local Cache = require("core.cache.cache")

local DebugCommands = {}

-- Dependency management
local function get_deps(deps)
  deps = deps or {}
  return {
    DebugConfig = deps.DebugConfig or require("core.utils.debug_config"),
    Logger = deps.Logger or require("core.utils.enhanced_error_handler"),
    PlayerHelpers = deps.PlayerHelpers or require("core.utils.player_helpers"),
    FaveBar = deps.FaveBar or require("gui.favorites_bar.fave_bar"),
    GuiHelpers = deps.GuiHelpers or require("core.utils.gui_helpers"),
    GuiValidation = deps.GuiValidation or require("core.utils.gui_validation"),
    BasicHelpers = deps.BasicHelpers or require("core.utils.basic_helpers"),
    Cache = deps.Cache or require("core.cache.cache"),
    fave_bar = deps.fave_bar or require("gui.favorites_bar.fave_bar"),
  }
end

DebugCommands._deps = get_deps()
function DebugCommands._inject(deps) DebugCommands._deps = get_deps(deps) end

-- All handlers now take explicit deps as first argument for testability
local function tf_debug_level_handler(deps, command)
  local DebugConfig = deps.DebugConfig
  local PlayerHelpers = deps.PlayerHelpers
  local player = game.players[command.player_index]
  if not player then return end
  local level = tonumber(command.parameter)
  if not level then
    PlayerHelpers.safe_player_print(player, "Usage: /tf_debug_level <number> (0-5)")
    PlayerHelpers.safe_player_print(player, "Levels: 0=NONE, 1=ERROR, 2=WARN, 3=INFO, 4=DEBUG, 5=TRACE")
    PlayerHelpers.safe_player_print(player,
      "Current level: " .. DebugConfig.get_level() .. " (" .. DebugConfig.get_level_name() .. ")")
    return
  end
  if level < 0 or level > 5 then
    PlayerHelpers.safe_player_print(player, "Debug level must be between 0 and 5")
    return
  end
  DebugConfig.set_level(level)
  PlayerHelpers.safe_player_print(player,
    "Debug level set to: " .. level .. " (" .. DebugConfig.get_level_name(level) .. ")")
end

local function tf_debug_info_handler(deps, command)
  local DebugConfig = deps.DebugConfig
  local PlayerHelpers = deps.PlayerHelpers
  local player = game.players[command.player_index]
  if not player then return end
  PlayerHelpers.safe_player_print(player, "=== TeleportFavorites Debug Info ===")
  PlayerHelpers.safe_player_print(player,
    "Current Level: " .. DebugConfig.get_level() .. " (" .. DebugConfig.get_level_name() .. ")")
  PlayerHelpers.safe_player_print(player,
    "Mode: " .. (DebugConfig.get_level() <= DebugConfig.LEVELS.WARN and "Production" or "Development"))
  PlayerHelpers.safe_player_print(player, "Available Levels:")
  for name, level in pairs(DebugConfig.LEVELS) do
    local indicator = (level == DebugConfig.get_level()) and " <== CURRENT" or ""
    PlayerHelpers.safe_player_print(player, "  " .. level .. " = " .. name .. indicator)
  end
end

local function tf_debug_production_handler(deps, command)
  local DebugConfig = deps.DebugConfig
  local PlayerHelpers = deps.PlayerHelpers
  local player = game.players[command.player_index]
  if not player then return end
  PlayerHelpers.debug_print_to_player(player, "tf_debug_production_handler")
  DebugConfig.enable_production_mode()
  PlayerHelpers.safe_player_print(player, "Production mode enabled (debug level: " .. DebugConfig.get_level_name() .. ")")
end

local function tf_debug_development_handler(deps, command)
  local DebugConfig = deps.DebugConfig
  local PlayerHelpers = deps.PlayerHelpers
  local player = game.players[command.player_index]
  if not player then return end
  PlayerHelpers.debug_print_to_player(player, "tf_debug_development_handler")
  DebugConfig.enable_development_mode()
  PlayerHelpers.safe_player_print(player,
    "Development mode enabled (debug level: " .. DebugConfig.get_level_name() .. ")")
end

local function tf_test_controller_handler(deps, command)
  local PlayerHelpers = deps.PlayerHelpers
  local FaveBar = deps.FaveBar
  local GuiHelpers = deps.GuiHelpers
  local GuiValidation = deps.GuiValidation
  local player = game.players[command.player_index]
  if not player then return end
  PlayerHelpers.debug_print_to_player(player, "tf_test_controller_handler")
  PlayerHelpers.safe_player_print(player, "=== CONTROLLER TEST ===")
  PlayerHelpers.safe_player_print(player, "Current controller: " .. tostring(player.controller_type))
  PlayerHelpers.safe_player_print(player, "Character controller constant: " .. tostring(defines.controllers.character))
  PlayerHelpers.safe_player_print(player, "Editor controller constant: " .. tostring(defines.controllers.editor))
  -- Check if favorites bar exists
  local main_flow = GuiHelpers.get_or_create_gui_flow_from_gui_top(player)
  local fave_bar_frame = main_flow and GuiValidation.find_child_by_name(main_flow, "fave_bar_frame")
  PlayerHelpers.safe_player_print(player, "Favorites bar exists: " .. tostring(fave_bar_frame ~= nil))
  -- Test build function
  PlayerHelpers.safe_player_print(player, "Attempting to build favorites bar...")
  FaveBar.build(player)
  -- Check again
  fave_bar_frame = main_flow and GuiValidation.find_child_by_name(main_flow, "fave_bar_frame")
  PlayerHelpers.safe_player_print(player, "Favorites bar exists after build: " .. tostring(fave_bar_frame ~= nil))
  PlayerHelpers.safe_player_print(player,
    "Test commands: /editor (toggle editor), /c game.player.character = nil (god mode)")
end

local function tf_force_build_bar_handler(deps, command)
  local PlayerHelpers = deps.PlayerHelpers
  local FaveBar = deps.FaveBar
  local GuiHelpers = deps.GuiHelpers
  local GuiValidation = deps.GuiValidation
  local player = game.players[command.player_index]
  if not player then return end
  PlayerHelpers.debug_print_to_player(player, "tf_force_build_bar_handler")
  PlayerHelpers.safe_player_print(player, "Force building favorites bar...")
  FaveBar.build(player, true) -- Force show
  local main_flow = GuiHelpers.get_or_create_gui_flow_from_gui_top(player)
  local fave_bar_frame = main_flow and GuiValidation.find_child_by_name(main_flow, "fave_bar_frame")
  PlayerHelpers.safe_player_print(player, "Favorites bar built successfully: " .. tostring(fave_bar_frame ~= nil))
end

-- Debug command to test settings functionality
local function tf_test_settings_handler(deps, command)
  local PlayerHelpers = deps.PlayerHelpers

  local player = game.players[command.player_index]
  if not player then return end

  PlayerHelpers.safe_player_print(player, "=== TeleportFavorites Settings Test ===")

  -- Test direct access to Factorio's settings
  PlayerHelpers.safe_player_print(player, "Direct Factorio settings access:")
  local success_fav, direct_favorites = pcall(function() return settings["runtime-per-user"][player.index]["favorites_on"] end)
  local success_hist, direct_history = pcall(function() return settings["runtime-per-user"][player.index]["enable_teleport_history"] end)
  
  if success_fav and direct_favorites then
    PlayerHelpers.safe_player_print(player, "  Direct favorites_on: " .. tostring(direct_favorites.value))
  else
    PlayerHelpers.safe_player_print(player, "  Direct favorites_on: ERROR - " .. tostring(direct_favorites))
  end
  
  if success_hist and direct_history then
    PlayerHelpers.safe_player_print(player, "  Direct enable_teleport_history: " .. tostring(direct_history.value))
  else
    PlayerHelpers.safe_player_print(player, "  Direct enable_teleport_history: ERROR - " .. tostring(direct_history))
  end

  -- Get current settings via cache
  local player_settings = Cache.Settings.get_player_settings(player)
  PlayerHelpers.safe_player_print(player, "Cached settings:")
  PlayerHelpers.safe_player_print(player, "  favorites_on: " .. tostring(player_settings.favorites_on))
  PlayerHelpers.safe_player_print(player, "  enable_teleport_history: " .. tostring(player_settings.enable_teleport_history))

  -- Check if they match
  local direct_fav_value = (success_fav and direct_favorites) and direct_favorites.value or nil
  local direct_hist_value = (success_hist and direct_history) and direct_history.value or nil
  local favorites_match = (player_settings.favorites_on == direct_fav_value)
  local history_match = (player_settings.enable_teleport_history == direct_hist_value)
  PlayerHelpers.safe_player_print(player, "Settings comparison:")
  PlayerHelpers.safe_player_print(player, "  favorites_on matches: " .. tostring(favorites_match))
  PlayerHelpers.safe_player_print(player, "  enable_teleport_history matches: " .. tostring(history_match))

  -- Test cache invalidation
  Cache.Settings.invalidate_player_cache(player)
  PlayerHelpers.safe_player_print(player, "Cache invalidated")

  -- Get fresh settings
  local fresh_settings = Cache.Settings.get_player_settings(player)
  PlayerHelpers.safe_player_print(player, "Fresh cached settings:")
  PlayerHelpers.safe_player_print(player, "  favorites_on: " .. tostring(fresh_settings.favorites_on))
  PlayerHelpers.safe_player_print(player, "  enable_teleport_history: " .. tostring(fresh_settings.enable_teleport_history))

  -- Check if fresh settings now match direct access
  local fresh_favorites_match = (fresh_settings.favorites_on == direct_fav_value)
  local fresh_history_match = (fresh_settings.enable_teleport_history == direct_hist_value)
  PlayerHelpers.safe_player_print(player, "Fresh settings comparison:")
  PlayerHelpers.safe_player_print(player, "  favorites_on matches: " .. tostring(fresh_favorites_match))
  PlayerHelpers.safe_player_print(player, "  enable_teleport_history matches: " .. tostring(fresh_history_match))

  -- Test fave bar rebuild
  PlayerHelpers.safe_player_print(player, "Testing favorites bar rebuild...")
  deps.fave_bar.build(player, true)
  PlayerHelpers.safe_player_print(player, "Favorites bar rebuild complete")

  PlayerHelpers.safe_player_print(player, "=== Settings Test Complete ===")
end

-- Debug command to manually trigger settings change event
local function tf_trigger_settings_event_handler(deps, command)
  local PlayerHelpers = deps.PlayerHelpers

  local player = game.players[command.player_index]
  if not player then return end

  PlayerHelpers.safe_player_print(player, "=== Manually Triggering Settings Event ===")

  -- Create a fake settings change event for teleport history
  local fake_event = {
    player_index = player.index,
    setting = "enable_teleport_history"
  }

  -- Try to get the registered event handler directly
  local success, result = pcall(function()
    -- Get the event registration dispatcher
    local EventRegistrationDispatcher = require("core.events.event_registration_dispatcher") 
    
    -- Try to trigger the actual registered handler by firing the event
    local event_id = defines.events.on_runtime_mod_setting_changed
    script.raise_event(event_id, fake_event)
    
    return true
  end)

  if success then
    PlayerHelpers.safe_player_print(player, "✓ Settings event triggered successfully via script.raise_event")
  else
    PlayerHelpers.safe_player_print(player, "✗ Failed to trigger event: " .. tostring(result))
    
    -- Fallback: call the handler function directly
    PlayerHelpers.safe_player_print(player, "Trying direct handler call...")
    local fallback_success, fallback_result = pcall(function()
      local EventRegistrationDispatcher = require("core.events.event_registration_dispatcher")
      -- This won't work directly, but we can call the fave bar rebuild manually
      local fave_bar = require("gui.favorites_bar.fave_bar")
      fave_bar.build(player, true)
      return true
    end)
    
    if fallback_success then
      PlayerHelpers.safe_player_print(player, "✓ Manually rebuilt favorites bar")
    else
      PlayerHelpers.safe_player_print(player, "✗ Manual rebuild failed: " .. tostring(fallback_result))
    end
  end

  PlayerHelpers.safe_player_print(player, "=== Manual Event Trigger Complete ===")
end

-- Debug command to check event registration status
local function tf_check_events_handler(deps, command)
  local PlayerHelpers = deps.PlayerHelpers

  local player = game.players[command.player_index]
  if not player then return end

  PlayerHelpers.safe_player_print(player, "=== Event Registration Check ===")

  -- Check if script events are accessible
  local success, handler = pcall(function()
    return script.get_event_handler and script.get_event_handler(defines.events.on_runtime_mod_setting_changed)
  end)
  
  if success and handler then
    PlayerHelpers.safe_player_print(player, "✓ on_runtime_mod_setting_changed event IS registered")
  elseif success then
    PlayerHelpers.safe_player_print(player, "✗ on_runtime_mod_setting_changed event NOT registered")
  else
    PlayerHelpers.safe_player_print(player, "Cannot check script event handlers (API not available)")
  end

  PlayerHelpers.safe_player_print(player, "=== Event Check Complete ===")
end

-- Expose for test and registration
DebugCommands.tf_debug_level_handler = function(cmd) return tf_debug_level_handler(DebugCommands._deps, cmd) end
DebugCommands.tf_debug_info_handler = function(cmd) return tf_debug_info_handler(DebugCommands._deps, cmd) end
DebugCommands.tf_debug_production_handler = function(cmd) return tf_debug_production_handler(DebugCommands._deps, cmd) end
DebugCommands.tf_debug_development_handler = function(cmd) return tf_debug_development_handler(DebugCommands._deps, cmd) end
DebugCommands.tf_test_controller_handler = function(cmd) return tf_test_controller_handler(DebugCommands._deps, cmd) end
DebugCommands.tf_force_build_bar_handler = function(cmd) return tf_force_build_bar_handler(DebugCommands._deps, cmd) end
DebugCommands.tf_test_settings_handler = function(cmd) return tf_test_settings_handler(DebugCommands._deps, cmd) end
DebugCommands.tf_trigger_settings_event_handler = function(cmd) return tf_trigger_settings_event_handler(DebugCommands._deps, cmd) end
DebugCommands.tf_check_events_handler = function(cmd) return tf_check_events_handler(DebugCommands._deps, cmd) end
DebugCommands.tf_settings_diagnostics_handler = function(cmd) return tf_settings_diagnostics_handler(cmd) end
DebugCommands.tf_rebuild_fave_bar_handler = function(cmd) return tf_rebuild_fave_bar_handler(cmd) end

function DebugCommands.register_commands()
  basic_helpers.register_module_commands(DebugCommands, {
    { "tf_debug_level",       "Set debug level (0-5)",                     "tf_debug_level_handler" },
    { "tf_debug_info",        "Show current debug configuration",          "tf_debug_info_handler" },
    { "tf_debug_production",  "Enable production mode (minimal logging)",  "tf_debug_production_handler" },
    { "tf_debug_development", "Enable development mode (verbose logging)", "tf_debug_development_handler" },
    { "tf_test_controller",   "Print controller test info",                "tf_test_controller_handler" },
    { "tf_force_build_bar",   "Force build favorites bar",                 "tf_force_build_bar_handler" },
    { "tf_test_settings",     "Test settings system functionality",        "tf_test_settings_handler" },
    { "tf_trigger_settings_event", "Manually trigger settings change event", "tf_trigger_settings_event_handler" },
    { "tf_check_events",      "Check event registration status",           "tf_check_events_handler" },
    { "tf_settings_diag",     "Run comprehensive settings diagnostics",    "tf_settings_diagnostics_handler" },
    { "tf_rebuild_fave_bar",  "Manually rebuild favorites bar",            "tf_rebuild_fave_bar_handler" }
  })
  local Logger = DebugCommands._deps.Logger
  Logger.info("Debug commands registered")
end

--- Create debug level GUI controls (for integration into existing GUIs)
---@param parent LuaGuiElement Parent element to add controls to
---@param player LuaPlayer Player who owns the GUI
---@return LuaGuiElement debug_flow Debug controls flow
function DebugCommands.create_debug_level_controls(parent, player)
  local DebugConfig = DebugCommands._deps.DebugConfig
  local debug_flow = parent.add { type = "flow", name = "tf_debug_level_controls", direction = "horizontal" }
  debug_flow.add { type = "label", caption = "Debug Level:" } -- Label
  local current_level = DebugConfig.get_level()            -- Current level display
  local level_label = debug_flow.add { type = "label", name = "tf_debug_current_level", caption = current_level .. " (" .. DebugConfig.get_level_name(current_level) .. ")" }
  -- Level buttons
  local levels = {
    { level = DebugConfig.LEVELS.NONE,  name = "NONE", color = { r = 0.5, g = 0.5, b = 0.5 } },
    { level = DebugConfig.LEVELS.ERROR, name = "ERR",  color = { r = 1.0, g = 0.3, b = 0.3 } },
    { level = DebugConfig.LEVELS.WARN,  name = "WARN", color = { r = 1.0, g = 0.8, b = 0.3 } },
    { level = DebugConfig.LEVELS.INFO,  name = "INFO", color = { r = 0.3, g = 0.8, b = 1.0 } },
    { level = DebugConfig.LEVELS.DEBUG, name = "DBG",  color = { r = 0.6, g = 1.0, b = 0.6 } },
    { level = DebugConfig.LEVELS.TRACE, name = "TRC",  color = { r = 1.0, g = 0.6, b = 1.0 } }
  }
  for _, level_info in ipairs(levels) do
    local button = debug_flow.add { type = "button", name = "tf_debug_set_level_" .. level_info.level, caption = level_info.name, tooltip = "Set debug level to " .. level_info.level .. " (" .. level_info.name .. ")" }
    if level_info.level == current_level then button.enabled = false end
  end
  return debug_flow
end

--- Handle debug level button clicks
---@param event table GUI click event
function DebugCommands.on_debug_level_button_click(event)
  local DebugConfig = DebugCommands._deps.DebugConfig
  local PlayerHelpers = DebugCommands._deps.PlayerHelpers
  local BasicHelpers = DebugCommands._deps.BasicHelpers
  local element = event.element
  local valid = require("core.utils.validation_utils").validate_gui_element(element)
  if not valid then return end
  local player = game.players[event.player_index]
  if not ValidationUtils.validate_player(player) then return end
  local level_str = string.match(element.name, "tf_debug_set_level_(%d+)") -- Parse level from button name
  if not level_str then return end
  local level = tonumber(level_str)
  if not level then return end
  DebugConfig.set_level(level)
  local parent = element.parent -- Update the GUI to reflect new level
  if parent and parent.valid then
    local level_label = parent["tf_debug_current_level"]
    if level_label and level_label.valid then level_label.caption = level ..
      " (" .. DebugConfig.get_level_name(level) .. ")" end
    for _, child in pairs(parent.children) do
      if child.name and string.match(child.name, "tf_debug_set_level_") then
        local child_level = tonumber(string.match(child.name, "tf_debug_set_level_(%d+)"))
        if child_level == level then child.enabled = false else child.enabled = true end
      end
    end
  end
  PlayerHelpers.safe_player_print(player,
    "Debug level changed to: " .. level .. " (" .. DebugConfig.get_level_name(level) .. ")")
end

--- Comprehensive settings diagnostics handler
---@param command table Command data
function tf_settings_diagnostics_handler(command)
  local Cache = DebugCommands._deps.Cache
  local PlayerHelpers = DebugCommands._deps.PlayerHelpers

  local player = game.players[command.player_index]
  if not player or not player.valid then return end

  PlayerHelpers.safe_player_print(player, "=== TeleportFavorites Settings Diagnostics ===")

  -- Test 1: Check if our mod settings exist in Factorio's settings system
  PlayerHelpers.safe_player_print(player, "1. Checking Factorio settings registration:")
  local mod_settings = {"favorites_on", "enable_teleport_history", "history-update-interval", "chart-tag-click-radius"}
  for _, setting_name in ipairs(mod_settings) do
    local player_setting = player.mod_settings[setting_name]
    local has_setting = player_setting ~= nil
    PlayerHelpers.safe_player_print(player, "  " .. setting_name .. ": " .. (has_setting and "✓ Found" or "✗ Missing"))
    if has_setting then
      PlayerHelpers.safe_player_print(player, "    Type: " .. tostring(player_setting.setting_type or "unknown"))
      PlayerHelpers.safe_player_print(player, "    Value: " .. tostring(player_setting.value))
    end
  end

  -- Test 2: Check current values through multiple access methods
  PlayerHelpers.safe_player_print(player, "2. Current setting values (multiple access methods):")
  
  -- Method A: Direct Factorio API via player.mod_settings
  local factorio_favorites_on = player.mod_settings["favorites_on"]
  local factorio_teleport_history = player.mod_settings["enable_teleport_history"]
  PlayerHelpers.safe_player_print(player, "  Direct API - favorites_on: " .. tostring(factorio_favorites_on and factorio_favorites_on.value or "nil"))
  PlayerHelpers.safe_player_print(player, "  Direct API - enable_teleport_history: " .. tostring(factorio_teleport_history and factorio_teleport_history.value or "nil"))

  -- Method B: Through our cache system
  local cached_settings = Cache.Settings.get_player_settings(player)
  PlayerHelpers.safe_player_print(player, "  Cache API - favorites_on: " .. tostring(cached_settings.favorites_on))
  PlayerHelpers.safe_player_print(player, "  Cache API - enable_teleport_history: " .. tostring(cached_settings.enable_teleport_history))

  -- Test 3: Check if values match
  local values_match = (factorio_favorites_on and factorio_favorites_on.value == cached_settings.favorites_on) and
                      (factorio_teleport_history and factorio_teleport_history.value == cached_settings.enable_teleport_history)
  PlayerHelpers.safe_player_print(player, "  Values match: " .. (values_match and "✓ Yes" or "✗ No"))

  -- Test 4: Event system test - manually register a simple test handler
  PlayerHelpers.safe_player_print(player, "3. Event system test:")
  
  -- Store original handler if any
  local success, result = pcall(function()
    -- Create a test event handler
    local test_fired = false
    local test_handler = function(event)
      test_fired = true
      PlayerHelpers.safe_player_print(player, "*** TEST EVENT FIRED *** Setting: " .. tostring(event.setting))
    end
    
    -- Try to register the test handler temporarily
    script.on_event(defines.events.on_runtime_mod_setting_changed, test_handler)
    
    PlayerHelpers.safe_player_print(player, "  Test handler registered successfully")
    return true
  end)
  
  if success then
    PlayerHelpers.safe_player_print(player, "  ✓ Event handler registration works")
  else
    PlayerHelpers.safe_player_print(player, "  ✗ Event handler registration failed: " .. tostring(result))
  end

  -- Test 5: Check mod loading state
  PlayerHelpers.safe_player_print(player, "4. Mod state check:")
  PlayerHelpers.safe_player_print(player, "  Game state: " .. tostring(game and "Available" or "Not Available"))
  PlayerHelpers.safe_player_print(player, "  Script state: " .. tostring(script and "Available" or "Not Available"))
  PlayerHelpers.safe_player_print(player, "  Connected players: " .. tostring(#game.connected_players))
  PlayerHelpers.safe_player_print(player, "  Player index: " .. tostring(player.index))

  PlayerHelpers.safe_player_print(player, "=== Diagnostics Complete ===")
  PlayerHelpers.safe_player_print(player, "Next steps:")
  PlayerHelpers.safe_player_print(player, "1. Change a setting through the mod settings menu")
  PlayerHelpers.safe_player_print(player, "2. Watch for debug messages or use /tf_test_settings to verify")
  PlayerHelpers.safe_player_print(player, "3. If no event fires, this is a Factorio engine or timing issue")
end

--- Manual favorites bar rebuild handler
---@param command table Command data
function tf_rebuild_fave_bar_handler(command)
  local PlayerHelpers = DebugCommands._deps.PlayerHelpers
  local fave_bar = DebugCommands._deps.fave_bar

  local player = game.players[command.player_index]
  if not player or not player.valid then return end

  PlayerHelpers.safe_player_print(player, "=== Manual Favorites Bar Rebuild ===")
  
  -- Force rebuild the favorites bar
  fave_bar.build(player, true)
  
  PlayerHelpers.safe_player_print(player, "✓ Favorites bar rebuilt manually")
  PlayerHelpers.safe_player_print(player, "This simulates what should happen when settings change")
end

return DebugCommands
