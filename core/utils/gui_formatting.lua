---@diagnostic disable: undefined-global
--[[
GUI Formatting Utilities for TeleportFavorites
=============================================
Module: core/utils/gui_formatting.lua

Provides rich text formatting and display utilities for GUI elements.

Functions:
- format_gps() - Format GPS string for rich text display
- format_chart_tag() - Format chart tag for rich text display
- position_change_notification() - Generate position change notification
- deletion_prevention_notification() - Format deletion prevention message
- build_favorite_tooltip() - Build tooltip for favorites
]]

local GPSUtils = require("core.utils.gps_utils")
local LocaleUtils = require("core.utils.locale_utils")

---@class GuiFormatting
local GuiFormatting = {}

local MOD_NAME = "TeleportFavorites"

--- Format a GPS string for display in rich text format
---@param gps_string string GPS string to format
---@return string formatted_gps Rich text formatted GPS string
function GuiFormatting.format_gps(gps_string)
  if not gps_string then return LocaleUtils.get_error_string(nil, "invalid_gps_fallback") end
  return string.format("[gps=%s]", gps_string)
end

--- Format a chart tag for display in rich text format
---@param chart_tag LuaCustomChartTag Chart tag object
---@param label string? Optional label text (defaults to chart tag text)
---@return string formatted_tag Rich text string representation
function GuiFormatting.format_chart_tag(chart_tag, label)
  if not chart_tag or not chart_tag.valid then
    return LocaleUtils.get_error_string(nil, "invalid_chart_tag_fallback")
  end
  local text = label or chart_tag.text or ""
  local position_str = string.format("[gps=%d,%d,%d]",
    math.floor(chart_tag.position.x),
    math.floor(chart_tag.position.y),
    chart_tag.surface.index)
  local icon_str = chart_tag.icon and string.format("[img=%s/%s]", chart_tag.icon.type, chart_tag.icon.name) or ""
  return string.format("%s %s %s", icon_str, text, position_str)
end

--- Generate a position change notification message
---@param player LuaPlayer Player to notify
---@param chart_tag LuaCustomChartTag Chart tag that was changed
---@param old_position MapPosition Previous position
---@param new_position MapPosition New position
---@return string notification_message Formatted notification message
function GuiFormatting.position_change_notification(player, chart_tag, old_position, new_position)
  if not player or not player.valid or not old_position or not new_position then
    return LocaleUtils.get_error_string(player, "invalid_position_change_fallback")
  end
  local surface_index = player.surface.index
  local old_gps = string.format("[gps=%d,%d,%d]",
    math.floor(old_position.x),
    math.floor(old_position.y),
    surface_index)
  local new_gps = string.format("[gps=%d,%d,%d]",
    math.floor(new_position.x),
    math.floor(new_position.y),
    surface_index)
  local tag_text = ""
  local icon_str = ""
  if chart_tag and chart_tag.valid then
    tag_text = chart_tag.text or ""
    icon_str = chart_tag.icon and string.format("[img=%s/%s] ", chart_tag.icon.type, chart_tag.icon.name) or ""
  end
  return LocaleUtils.get_error_string(player, "location_changed", {icon_str .. tag_text, old_gps, new_gps})
end

--- Format a deletion prevention message
---@param chart_tag LuaCustomChartTag Chart tag that couldn't be deleted
---@return string deletion_message Formatted message explaining why deletion failed
function GuiFormatting.deletion_prevention_notification(chart_tag)
  if not chart_tag or not chart_tag.valid then
    return LocaleUtils.get_error_string(nil, "invalid_chart_tag_fallback")
  end
  local tag_text = chart_tag.text or ""
  local icon_str = chart_tag.icon and string.format("[img=%s/%s] ", chart_tag.icon.type, chart_tag.icon.name) or ""
  local position_str = string.format("[gps=%d,%d,%d]",
    math.floor(chart_tag.position.x),
    math.floor(chart_tag.position.y),
    chart_tag.surface.index)
  return LocaleUtils.get_error_string(nil, "tag_deletion_prevented", {icon_str .. tag_text .. " " .. position_str})
end

--- Build tooltip for favorites
---@param fav table Favorite object
---@param opts table? Options including gps, text, max_len
---@return table tooltip Localized tooltip table
function GuiFormatting.build_favorite_tooltip(fav, opts)
  opts = opts or {}
  local gps_str = fav and fav.gps or opts.gps or "?"
  local tag_text = fav and fav.tag and fav.tag.chart_tag and fav.tag.chart_tag.text or opts.text or nil
  
  -- Truncate long tag text
  if type(tag_text) == "string" and #tag_text > (opts.max_len or 50) then
    tag_text = tag_text:sub(1, opts.max_len or 50) .. "..."
  end

  if not tag_text or tag_text == "" then
    return { "tf-gui.fave_slot_tooltip_one", GPSUtils.coords_string_from_gps(gps_str) }
  else
    return { "tf-gui.fave_slot_tooltip_both", tag_text or "", gps_str }
  end
end

return GuiFormatting
