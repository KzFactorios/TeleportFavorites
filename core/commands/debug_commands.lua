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

local DebugCommands = {}

local basic_helpers = require("core.utils.basic_helpers")

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
    SafeHelpers = deps.SafeHelpers or require("core.utils.basic_helpers")
  }
end

DebugCommands._deps = get_deps()

function DebugCommands._inject(deps)
  DebugCommands._deps = get_deps(deps)
end

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
    PlayerHelpers.safe_player_print(player, "Current level: " .. DebugConfig.get_level() .. " (" .. DebugConfig.get_level_name() .. ")")
    return
  end
  if level < 0 or level > 5 then
    PlayerHelpers.safe_player_print(player, "Debug level must be between 0 and 5")
    return
  end
  DebugConfig.set_level(level)
  PlayerHelpers.safe_player_print(player, "Debug level set to: " .. level .. " (" .. DebugConfig.get_level_name(level) .. ")")
end

local function tf_debug_info_handler(deps, command)
  local DebugConfig = deps.DebugConfig
  local PlayerHelpers = deps.PlayerHelpers
  local player = game.players[command.player_index]
  if not player then return end
  PlayerHelpers.safe_player_print(player, "=== TeleportFavorites Debug Info ===")
  PlayerHelpers.safe_player_print(player, "Current Level: " .. DebugConfig.get_level() .. " (" .. DebugConfig.get_level_name() .. ")")
  PlayerHelpers.safe_player_print(player, "Mode: " .. (DebugConfig.get_level() <= DebugConfig.LEVELS.WARN and "Production" or "Development"))
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
  PlayerHelpers.safe_player_print(player, "Development mode enabled (debug level: " .. DebugConfig.get_level_name() .. ")")
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
  PlayerHelpers.safe_player_print(player, "Test commands: /editor (toggle editor), /c game.player.character = nil (god mode)")
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

-- Expose for test and registration
DebugCommands.tf_debug_level_handler = function(cmd)
  return tf_debug_level_handler(DebugCommands._deps, cmd)
end
DebugCommands.tf_debug_info_handler = function(cmd)
  return tf_debug_info_handler(DebugCommands._deps, cmd)
end
DebugCommands.tf_debug_production_handler = function(cmd)
  return tf_debug_production_handler(DebugCommands._deps, cmd)
end
DebugCommands.tf_debug_development_handler = function(cmd)
  return tf_debug_development_handler(DebugCommands._deps, cmd)
end
DebugCommands.tf_test_controller_handler = function(cmd)
  return tf_test_controller_handler(DebugCommands._deps, cmd)
end
DebugCommands.tf_force_build_bar_handler = function(cmd)
  return tf_force_build_bar_handler(DebugCommands._deps, cmd)
end

function DebugCommands.register_commands()
  basic_helpers.register_module_commands(DebugCommands, {
    {"tf_debug_level", "Set debug level (0-5)", "tf_debug_level_handler"},
    {"tf_debug_info", "Show current debug configuration", "tf_debug_info_handler"},
    {"tf_debug_production", "Enable production mode (minimal logging)", "tf_debug_production_handler"},
    {"tf_debug_development", "Enable development mode (verbose logging)", "tf_debug_development_handler"},
    {"tf_test_controller", "Print controller test info", "tf_test_controller_handler"},
    {"tf_force_build_bar", "Force build favorites bar", "tf_force_build_bar_handler"}
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
  local debug_flow = parent.add{
    type = "flow",
    name = "tf_debug_level_controls",
    direction = "horizontal"
  }
  -- Label
  debug_flow.add{
    type = "label",
    caption = "Debug Level:"
  }
  -- Current level display
  local current_level = DebugConfig.get_level()
  local level_label = debug_flow.add{
    type = "label",
    name = "tf_debug_current_level",
    caption = current_level .. " (" .. DebugConfig.get_level_name(current_level) .. ")"
  }
  -- Level buttons
  local levels = {
    {level = DebugConfig.LEVELS.NONE, name = "NONE", color = {r = 0.5, g = 0.5, b = 0.5}},
    {level = DebugConfig.LEVELS.ERROR, name = "ERR", color = {r = 1.0, g = 0.3, b = 0.3}},
    {level = DebugConfig.LEVELS.WARN, name = "WARN", color = {r = 1.0, g = 0.8, b = 0.3}},
    {level = DebugConfig.LEVELS.INFO, name = "INFO", color = {r = 0.3, g = 0.8, b = 1.0}},
    {level = DebugConfig.LEVELS.DEBUG, name = "DBG", color = {r = 0.6, g = 1.0, b = 0.6}},
    {level = DebugConfig.LEVELS.TRACE, name = "TRC", color = {r = 1.0, g = 0.6, b = 1.0}}
  }
  for _, level_info in ipairs(levels) do
    local button = debug_flow.add{
      type = "button",
      name = "tf_debug_set_level_" .. level_info.level,
      caption = level_info.name,
      tooltip = "Set debug level to " .. level_info.level .. " (" .. level_info.name .. ")"
    }
    if level_info.level == current_level then
      button.enabled = false
    end
  end
  return debug_flow
end

--- Handle debug level button clicks
---@param event table GUI click event
function DebugCommands.on_debug_level_button_click(event)
  local DebugConfig = DebugCommands._deps.DebugConfig
  local PlayerHelpers = DebugCommands._deps.PlayerHelpers
  local SafeHelpers = DebugCommands._deps.SafeHelpers
  local element = event.element
  if not SafeHelpers.is_valid_element(element) then return end
  local player = game.players[event.player_index]
  if not SafeHelpers.is_valid_player(player) then return end
  -- Parse level from button name
  local level_str = string.match(element.name, "tf_debug_set_level_(%d+)")
  if not level_str then return end
  local level = tonumber(level_str)
  if not level then return end
  DebugConfig.set_level(level)
  -- Update the GUI to reflect new level
  local parent = element.parent
  if parent and parent.valid then
    local level_label = parent["tf_debug_current_level"]
    if level_label and level_label.valid then
      level_label.caption = level .. " (" .. DebugConfig.get_level_name(level) .. ")"
    end
    for _, child in pairs(parent.children) do
      if child.name and string.match(child.name, "tf_debug_set_level_") then
        local child_level = tonumber(string.match(child.name, "tf_debug_set_level_(%d+)") )
        if child_level == level then
          child.enabled = false
        else
          child.enabled = true
        end
      end
    end
  end
  PlayerHelpers.safe_player_print(player, "Debug level changed to: " .. level .. " (" .. DebugConfig.get_level_name(level) .. ")")
end

return DebugCommands
