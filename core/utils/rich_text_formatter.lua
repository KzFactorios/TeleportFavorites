---@diagnostic disable: undefined-global
--[[
RichTextFormatter - Rich text formatting utilities for TeleportFavorites mod

This module provides consistent rich text formatting for user notifications
throughout the mod, including position changes, tag relocations, and other
player messaging.

Key Features:
- Consistent notification formatting
- GPS coordinate formatting
- Position change notifications
- Tag relocation messages
- Deletion prevention messages
]]

local LocaleUtils = require("core.utils.locale_utils")
local GPSUtils = require("core.utils.gps_utils")

---@class RichTextFormatter
local RichTextFormatter = {}

--[[
Format a position change notification for the player
@param player - The player object
@param chart_tag - The chart tag that was moved
@param old_position - The old position
@param new_position - The new position  
@return formatted notification string
]]
function RichTextFormatter.position_change_notification(player, chart_tag, old_position, new_position)
    if not player or not chart_tag then return "" end
    
    local surface_index = player.surface.index
    local old_gps = GPSUtils.gps_from_map_position(old_position, surface_index)
    local new_gps = GPSUtils.gps_from_map_position(new_position, surface_index)
    
    return LocaleUtils.get_handler_string(player, "position_normalized", {
        chart_tag.text or "",
        old_gps,
        new_gps
    })
end

--[[
Format a tag relocated notification for terrain changes
@param chart_tag - The chart tag that was relocated
@param old_position - The old position
@param new_position - The new position
@return formatted notification string
]]
function RichTextFormatter.tag_relocated_notification(chart_tag, old_position, new_position)
    if not chart_tag then return "" end
    
    local surface_index = chart_tag.surface and chart_tag.surface.index or 1
    local old_gps = GPSUtils.gps_from_map_position(old_position, surface_index)
    local new_gps = GPSUtils.gps_from_map_position(new_position, surface_index)
    
    return string.format("[color=yellow]Tag '%s' relocated from %s to %s due to terrain changes[/color]",
        chart_tag.text or "Unknown Tag",
        old_gps,
        new_gps
    )
end

--[[
Format a position change notification for terrain handling
@param chart_tag - The chart tag 
@param old_position - The old position
@param new_position - The new position
@return formatted notification string
]]
function RichTextFormatter.position_change_notification_terrain(chart_tag, old_position, new_position)
    if not chart_tag then return "" end
    
    local surface_index = chart_tag.surface and chart_tag.surface.index or 1
    local old_gps = GPSUtils.gps_from_map_position(old_position, surface_index)
    local new_gps = GPSUtils.gps_from_map_position(new_position, surface_index)
    
    return string.format("[color=orange]Tag '%s' moved from %s to %s due to terrain changes[/color]",
        chart_tag.text or "Unknown Tag",
        old_gps,
        new_gps
    )
end

--[[
Format a deletion prevention notification
@param chart_tag - The chart tag that would have been deleted
@return formatted notification string
]]
function RichTextFormatter.deletion_prevention_notification(chart_tag)
    if not chart_tag then return "" end
    
    return string.format("[color=red]Tag '%s' could not be relocated and was preserved at its current location[/color]",
        chart_tag.text or "Unknown Tag"
    )
end

--[[
Format a GPS coordinate string with color coding
@param position - The position to format
@param surface_index - The surface index
@param color - Optional color (default: cyan)
@return formatted GPS string
]]
function RichTextFormatter.format_gps_with_color(position, surface_index, color)
    color = color or "cyan"
    local gps_string = GPSUtils.gps_from_map_position(position, surface_index)
    return string.format("[color=%s]%s[/color]", color, gps_string)
end

--[[
Format a success message with green color
@param message - The message to format
@return formatted success message
]]
function RichTextFormatter.success_message(message)
    return string.format("[color=green]%s[/color]", message or "")
end

--[[
Format a warning message with yellow color
@param message - The message to format
@return formatted warning message
]]
function RichTextFormatter.warning_message(message)
    return string.format("[color=yellow]%s[/color]", message or "")
end

--[[
Format an error message with red color
@param message - The message to format
@return formatted error message
]]
function RichTextFormatter.error_message(message)
    return string.format("[color=red]%s[/color]", message or "")
end

return RichTextFormatter
