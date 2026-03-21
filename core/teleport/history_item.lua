---@diagnostic disable: undefined-global

---@class HistoryItem
---@field gps string GPS string for the teleport destination (required, not nil)
---@field timestamp integer Tick timestamp of the teleport event (required, not nil)
---@field from_gps string|nil GPS string for the departure location (nil when sequential mode is off)
--- HistoryItem class for teleport history stack entries
local HistoryItem = {}
HistoryItem.__index = HistoryItem


--- Create a new HistoryItem
---@param gps string Destination GPS
---@param from_gps string|nil Departure GPS (only set when sequential history mode is enabled)
---@return HistoryItem|nil
function HistoryItem.new(gps, from_gps)
    if type(gps) ~= "string" or gps == "" then
        return nil
    end
    local self = setmetatable({}, HistoryItem)
    self.gps = gps
    self.timestamp = game and game.tick or 0
    if type(from_gps) == "string" and from_gps ~= "" then
        self.from_gps = from_gps
    end
    return self
end

--- Check if a HistoryItem was recorded in sequential mode (has departure GPS)
---@param item HistoryItem
---@return boolean
function HistoryItem.is_sequential(item)
    return item and type(item.from_gps) == "string" and item.from_gps ~= ""
end

--- Validate that a HistoryItem is well-formed
---@param item HistoryItem
---@return boolean
function HistoryItem.is_valid(item)
    return item and type(item.gps) == "string" and item.gps ~= "" and type(item.timestamp) == "number" and
    item.timestamp > 0
end

---@param player LuaPlayer
---@param item HistoryItem
---@return string
function HistoryItem.get_locale_time(player, item)
    if not item or type(item) ~= "table" or type(item.timestamp) ~= "number" then
        return ""
    end
    if not player or not player.valid then
        return ""
    end
    
    local now = game and game.tick or 0
    local ticks_ago = now - item.timestamp
    if ticks_ago < 0 then ticks_ago = 0 end
    local seconds_ago = math.floor(ticks_ago / 60)
    local minutes_ago = math.floor(seconds_ago / 60)
    local hours_ago = math.floor(minutes_ago / 60)
    if hours_ago > 0 then
        return tostring(hours_ago) .. "h " .. tostring(minutes_ago % 60) .. "m ago"
    elseif minutes_ago > 0 then
        return tostring(minutes_ago) .. "m ago"
    else
        return tostring(seconds_ago) .. "s ago"
    end
end

return HistoryItem
