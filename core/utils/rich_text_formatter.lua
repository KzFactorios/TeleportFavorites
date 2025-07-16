---@diagnostic disable: undefined-global

--[[
TeleportFavorites – Rich Text Formatter Utility
===============================================
Utilities for creating rich text strings with icons and formatting for display in Factorio GUI elements.

Features:
- Format text with icons using Factorio's rich text syntax
- Support for signal icons, sprites, and items
- Text alignment and styling options
]]

local ErrorHandler = require("core.utils.error_handler")
local ValidationUtils = require("core.utils.validation_utils")

local RichTextFormatter = {}

--- Create a rich text string with an icon and text
--- @param icon string|table|nil Icon definition (signal name, sprite path, or table)
--- @param text string|nil Text to display
--- @param options table|nil Options for formatting {align = "left|center|right"}
--- @return string Rich text formatted string
function RichTextFormatter.format_with_icon(icon, text, options)
  if not icon and not text then
    return ""
  end
  
  options = options or {}
  local parts = {}
  
  -- Add icon if provided
  if icon then
    local icon_string = RichTextFormatter.format_icon(icon)
    if icon_string and icon_string ~= "" then
      table.insert(parts, icon_string)
    end
  end
  
  -- Add text if provided
  if text and text ~= "" then
    table.insert(parts, text)
  end
  
  local result = table.concat(parts, " ")
  
  -- Apply alignment if specified
  if options.align and options.align ~= "left" then
    if options.align == "center" then
      result = "[center]" .. result .. "[/center]"
    elseif options.align == "right" then
      result = "[right]" .. result .. "[/right]"
    end
  end
  
  return result
end

--- Format an icon as a rich text string
--- @param icon string|table|nil Icon definition
--- @return string|nil Rich text icon string or nil if invalid
function RichTextFormatter.format_icon(icon)
  if not icon then
    return nil
  end
  
  -- Handle string icon (signal name)
  if type(icon) == "string" then
    if icon == "" then
      return nil
    end
    return "[img=virtual-signal/" .. icon .. "]"
  end
  
  -- Handle table icon (signal definition from chart_tag.icon)
  if type(icon) == "table" then
    if icon.name and icon.name ~= "" then
      local icon_type = icon.type or "virtual-signal"
      return "[img=" .. icon_type .. "/" .. icon.name .. "]"
    end
  end
  
  return nil
end

--- Format GPS coordinates (without alignment tags since CSS alignment is used)
--- @param coords_string string GPS coordinates string (e.g., "056.023")
--- @return string GPS coordinates string
function RichTextFormatter.format_gps_coords(coords_string)
  if not coords_string or coords_string == "" then
    return ""
  end
  
  return coords_string
end

--- Create a formatted teleport history entry with icon and GPS coordinates
--- @param icon string|table|nil Chart tag icon
--- @param coords_string string GPS coordinates
--- @return string Formatted rich text string
function RichTextFormatter.format_teleport_history_entry(icon, coords_string)
  if not coords_string or coords_string == "" then
    return ""
  end
  
  local parts = {}
  
  -- Add icon if available
  if icon then
    local icon_string = RichTextFormatter.format_icon(icon)
    if icon_string then
      table.insert(parts, icon_string)
    end
  end
  
  -- Add coordinates (no alignment tags since CSS handles alignment)
  table.insert(parts, coords_string)
  
  return table.concat(parts, " ")
end

return RichTextFormatter
