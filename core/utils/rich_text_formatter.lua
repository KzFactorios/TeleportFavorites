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

return RichTextFormatter
