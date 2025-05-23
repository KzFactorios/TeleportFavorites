---@class Favorite
-- Represents a favorite location with a GPS string and a locked state.
-- @field gps string The GPS string identifying the location
-- @field locked boolean Whether the favorite is locked (default: false)

local Favorite = {}
Favorite.__index = Favorite

--- Constructor for Favorite
-- @param gps string The GPS string
-- @param locked boolean|nil Optional, defaults to false
function Favorite:new(gps, locked)
    local obj = setmetatable({}, self)
    obj.gps = gps
    obj.locked = locked or false
    return obj
end

--- Update the GPS string for this favorite
-- @param new_gps string The new GPS string
function Favorite:update_gps(new_gps)
    self.gps = new_gps
end

--- Toggle the locked state
function Favorite:toggle_locked()
    self.locked = not self.locked
end

--- Create a new blank Favorite object
function Favorite.get_blank_favorite()
    return Favorite:new("")
end

return Favorite
