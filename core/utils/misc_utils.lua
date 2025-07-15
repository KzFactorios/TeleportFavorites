---@diagnostic disable: undefined-global
--[[
misc_utils.lua - Consolidated miscellaneous utilities
TeleportFavorites Factorio Mod
-----------------------------
Combines several small utility modules to reduce file overhead.
]]

local LocaleUtils = require("core.utils.locale_utils")
local GPSUtils = require("core.utils.gps_utils")
local TeleportStrategies = require("core.utils.teleport_strategy")

local MiscUtils = {}

-- ====== VERSION ======
MiscUtils.VERSION = "0.0.125"

-- ====== RICH TEXT FORMATTER ======
local RichTextFormatter = {}

function RichTextFormatter.format_position_change_notification(player, chart_tag, old_position, new_position)
  if not chart_tag or not old_position or not new_position then return "" end
  local old_gps = GPSUtils.gps_from_map_position(chart_tag.surface_index, old_position)
  local new_gps = GPSUtils.gps_from_map_position(chart_tag.surface_index, new_position)
  return LocaleUtils.get_gui_string(player, "position_updated", {old_gps, new_gps})
end

function RichTextFormatter.format_tag_relocation_message(player, chart_tag, new_position)
  if not chart_tag or not new_position then return "" end
  local gps = GPSUtils.gps_from_map_position(chart_tag.surface_index, new_position)
  return LocaleUtils.get_gui_string(player, "tag_relocated", {chart_tag.text or "Unnamed", gps})
end

function RichTextFormatter.format_deletion_prevention_message(player, chart_tag)
  if not chart_tag then return "" end
  return LocaleUtils.get_gui_string(player, "deletion_prevented", {chart_tag.text or "Unnamed"})
end

MiscUtils.RichTextFormatter = RichTextFormatter

-- ====== GAME HELPERS ======
local GameHelpers = {}

function GameHelpers.safe_play_sound(player, sound_path, volume)
  if not player or not player.valid or not sound_path then return false end
  local success, err = pcall(function()
    if player.play_sound then
      player.play_sound{path = sound_path, volume_modifier = volume or 1.0}
      return true
    end
  end)
  return success
end

function GameHelpers.player_print(player, message, color)
  if not player or not player.valid or not message then return false end
  local success, err = pcall(function()
    if color then
      player.print(message, color)
    else
      player.print(message)
    end
  end)
  return success
end

function GameHelpers.safe_teleport_to_gps(player, gps, context)
  if not player or not player.valid or not gps then return false end
  local TeleportUtils = TeleportStrategies.TeleportUtils
  return TeleportUtils.teleport_to_gps(player, gps, context)
end

MiscUtils.GameHelpers = GameHelpers

-- ====== ERROR MESSAGE HELPERS ======
local ErrorMessageHelpers = {}

function ErrorMessageHelpers.create_error_message(key, params)
  return {type = "error", key = key, params = params or {}}
end

function ErrorMessageHelpers.create_warning_message(key, params)
  return {type = "warning", key = key, params = params or {}}
end

function ErrorMessageHelpers.create_info_message(key, params)
  return {type = "info", key = key, params = params or {}}
end

function ErrorMessageHelpers.format_error_for_player(player, error_msg)
  if not error_msg or not error_msg.key then return "" end
  return LocaleUtils.get_error_string(player, error_msg.key, error_msg.params)
end

MiscUtils.ErrorMessageHelpers = ErrorMessageHelpers

return MiscUtils
