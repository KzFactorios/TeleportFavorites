local Helpers = require("core.utils.helpers")

---@class Favorite
-- Represents a favorite location with a GPS string and a locked state.
-- @field gps string The GPS string identifying the location
-- @field locked boolean Whether the favorite is locked (default: false)

local Favorite = {}
Favorite.__index = Favorite

--- Constructor for Favorite
-- @param gps string The GPS string
-- @param locked boolean|nil Optional, defaults to false
-- @return Favorite
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

--- Toggle the locked state of this favorite
function Favorite:toggle_locked()
  self.locked = not self.locked
end

--- Create a new blank Favorite object
-- @return Favorite
function Favorite.get_blank_favorite()
  return Favorite:new("")
end

function Favorite:valid()
  return type(self) == "table" and type(self.gps) == "string" and self.gps ~= ""
end

--- Format a tooltip string for this Favorite
-- @return string Tooltip text
function Favorite:formatted_tooltip()
  if not self.gps or self.gps == "" then return "Empty favorite slot" end
  local tooltip = Helpers.map_position_to_pos_string(self.gps)
  if self.map_tag ~= nil and type(self.map_tag) == "table" and self.map_tag.text ~= nil and self.map_tag.text ~= "" then
    tooltip = tooltip .. "\n" .. self.map_tag.text
  end
  return tooltip
end

return Favorite
