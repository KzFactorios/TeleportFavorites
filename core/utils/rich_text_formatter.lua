local MOD_NAME = "TeleportFavorites"

local RichTextFormatter = {}

-- Format a GPS string for display in rich text format
-- @param gps_string The GPS string to format
-- @return A rich text formatted GPS string
function RichTextFormatter.format_gps(gps_string)
    if not gps_string then return "[invalid GPS]" end
    return string.format("[gps=%s]", gps_string)
end

-- Format a chart tag for display in rich text format
-- @param chart_tag The LuaCustomChartTag object
-- @param label Optional label text (defaults to chart tag text)
-- @return A rich text string representation of the chart tag
function RichTextFormatter.format_chart_tag(chart_tag, label)
    if not chart_tag or not chart_tag.valid then
        return "[invalid chart tag]"
    end
    
    local text = label or chart_tag.text or ""
    local position_str = ""
    
    if chart_tag.position then
        position_str = string.format("[gps=%d,%d,%d]", 
            math.floor(chart_tag.position.x), 
            math.floor(chart_tag.position.y), 
            chart_tag.surface.index)
    end
    
    -- Format the icon if present
    local icon_str = ""
    if chart_tag.icon and chart_tag.icon.type and chart_tag.icon.name then
        icon_str = string.format("[img=%s/%s]", chart_tag.icon.type, chart_tag.icon.name)
    end
    
    return string.format("%s %s %s", icon_str, text, position_str)
end

-- Generate a position change notification message
-- @param player The player to notify
-- @param chart_tag The chart tag that was changed
-- @param old_position The previous position {x=X, y=Y}
-- @param new_position The new position {x=X, y=Y}
-- @param surface_index The surface index
-- @return A formatted notification message
function RichTextFormatter.position_change_notification(player, chart_tag, old_position, new_position, surface_index)
    if not player or not player.valid or not old_position or not new_position or not surface_index then
        return "[Invalid position change data]"
    end
    
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
        
        if chart_tag.icon and chart_tag.icon.type and chart_tag.icon.name then
            icon_str = string.format("[img=%s/%s] ", chart_tag.icon.type, chart_tag.icon.name)
        end
    end
    
    return string.format("[%s] %sLocation %s changed from %s to %s", 
        MOD_NAME, icon_str, tag_text, old_gps, new_gps)
end

-- Format a deletion prevention message
-- @param chart_tag The chart tag that couldn't be deleted
-- @return A formatted message explaining why the chart tag couldn't be deleted
function RichTextFormatter.deletion_prevention_notification(chart_tag)
    if not chart_tag or not chart_tag.valid then
        return "[Invalid chart tag data]"
    end
    
    local tag_text = chart_tag.text or ""
    local icon_str = ""
    
    if chart_tag.icon and chart_tag.icon.type and chart_tag.icon.name then
        icon_str = string.format("[img=%s/%s] ", chart_tag.icon.type, chart_tag.icon.name)
    end
    
    local position_str = ""
    if chart_tag.position then
        position_str = string.format("[gps=%d,%d,%d]", 
            math.floor(chart_tag.position.x), 
            math.floor(chart_tag.position.y), 
            chart_tag.surface.index)
    end
    
    return string.format("[%s] %s%s %s cannot be deleted because it is favorited by other players", 
        MOD_NAME, icon_str, tag_text, position_str)
end

return RichTextFormatter
