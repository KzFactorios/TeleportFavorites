---@diagnostic disable: undefined-global
--[[
GUI Formatting Utilities for TeleportFavorites
=============================================
Module: core/utils/gui_formatting.lua

Provides rich text formatting and display utilities for GUI elements.
]]

local GPSUtils = require("core.utils.gps_utils")

---@class GuiFormatting
local GuiFormatting = {}

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
