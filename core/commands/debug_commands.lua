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

local DebugConfig = require("core.utils.debug_config")
local Logger = require("core.utils.enhanced_error_handler")
local GameHelpers = require("core.utils.game_helpers")


---@class DebugCommands
local DebugCommands = {}

--- Register all debug commands
function DebugCommands.register_commands()
  -- Main debug level command
  commands.add_command("tf_debug_level", "Set TeleportFavorites debug level (0=NONE, 1=ERROR, 2=WARN, 3=INFO, 4=DEBUG, 5=TRACE)", function(command)
    local player = game.get_player(command.player_index)
    if not player then return end
    
    local level = tonumber(command.parameter)
    if not level then
      GameHelpers.player_print(player, "Usage: /tf_debug_level <number> (0-5)")
      GameHelpers.player_print(player, "Levels: 0=NONE, 1=ERROR, 2=WARN, 3=INFO, 4=DEBUG, 5=TRACE")
      GameHelpers.player_print(player, "Current level: " .. DebugConfig.get_level() .. " (" .. DebugConfig.get_level_name() .. ")")
      return
    end
    
    if level < 0 or level > 5 then
      GameHelpers.player_print(player, "Debug level must be between 0 and 5")
      return
    end
    
    DebugConfig.set_level(level)
    GameHelpers.player_print(player, "Debug level set to: " .. level .. " (" .. DebugConfig.get_level_name(level) .. ")")
  end)
  
  -- Debug info command
  commands.add_command("tf_debug_info", "Show current TeleportFavorites debug configuration", function(command)
    local player = game.get_player(command.player_index)
    if not player then return end
    
    GameHelpers.player_print(player, "=== TeleportFavorites Debug Info ===")
    GameHelpers.player_print(player, "Current Level: " .. DebugConfig.get_level() .. " (" .. DebugConfig.get_level_name() .. ")")
    GameHelpers.player_print(player, "Mode: " .. (DebugConfig.get_level() <= DebugConfig.LEVELS.WARN and "Production" or "Development"))
    GameHelpers.player_print(player, "Available Levels:")
    for name, level in pairs(DebugConfig.LEVELS) do
      local indicator = (level == DebugConfig.get_level()) and " 0 CURRENT" or ""
      GameHelpers.player_print(player, "  " .. level .. " = " .. name .. indicator)
    end
  end)
  
  -- Quick production mode
  commands.add_command("tf_debug_production", "Enable TeleportFavorites production mode (minimal logging)", function(command)
    local player = game.get_player(command.player_index)
    if not player then return end
    
    DebugConfig.enable_production_mode()
    GameHelpers.player_print(player, "Production mode enabled (debug level: " .. DebugConfig.get_level_name() .. ")")
  end)
  
  -- Quick development mode
  commands.add_command("tf_debug_development", "Enable TeleportFavorites development mode (verbose logging)", function(command)
    local player = game.get_player(command.player_index)
    if not player then return end
    
    DebugConfig.enable_development_mode()
    GameHelpers.player_print(player, "Development mode enabled (debug level: " .. DebugConfig.get_level_name() .. ")")
  end)
  
  Logger.info("Debug commands registered")
end

--- Create debug level GUI controls (for integration into existing GUIs)
---@param parent LuaGuiElement Parent element to add controls to
---@param player LuaPlayer Player who owns the GUI
---@return LuaGuiElement debug_flow Debug controls flow
function DebugCommands.create_debug_level_controls(parent, player)
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
  -- Note: font_color cannot be set directly on LuaStyle
  
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
    
    -- Highlight current level
    if level_info.level == current_level then
      -- Note: font_color cannot be set directly on LuaStyle
      button.enabled = false  -- Indicate current level by disabling
    end
  end
  
  return debug_flow
end

--- Handle debug level button clicks
---@param event table GUI click event
function DebugCommands.on_debug_level_button_click(event)
  local element = event.element
  if not element or not element.valid then return end
  
  local player = game.get_player(event.player_index)
  if not player then return end
  
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
    
    -- Update button highlighting
    for _, child in pairs(parent.children) do
      if child.name and string.match(child.name, "tf_debug_set_level_") then
        local child_level = tonumber(string.match(child.name, "tf_debug_set_level_(%d+)"))
        if child_level == level then
          child.enabled = false  -- Disable current level button
        else
          child.enabled = true   -- Enable other level buttons
        end
      end
    end
  end
  
  GameHelpers.player_print(player, "Debug level changed to: " .. level .. " (" .. DebugConfig.get_level_name(level) .. ")")
end

return DebugCommands
