local Helpers = require("core.utils.helpers")
local gps_helpers = require("core.utils.gps_helpers")

---@class Favorite
---@field gps string The GPS string identifying the location (must always be a string in the format 'xxx.yyy.s', see GPS String Format section)
---@field locked boolean Whether the favorite is locked (default: false)
---@field tag? table Optional tag table for tooltip formatting
local Favorite = {}
Favorite.__index = Favorite

local BLANK_GPS = gps_helpers.BLANK_GPS

--- Constructor for Favorite
-- @param gps string The GPS string
-- @param locked boolean|nil Optional, defaults to false
-- @param tag table|nil Optional, defaults to nil
-- @return Favorite
function Favorite.new(self, gps, locked, tag)
  -- Support both Favorite.new(...) and Favorite:new(...)
  if self ~= Favorite then
    tag = locked
    locked = gps
    gps = self
    self = Favorite
  end
  local obj = setmetatable({}, self)
  ---@type string
  if type(gps) == "string" and gps:match("^%[gps=") then
    -- Parse [gps=x,y,s] format and normalize
    local x, y, s = gps:match("%[gps=(%-?%d+),(%-?%d+),(%-?%d+)%]")
    x, y, s = tonumber(x), tonumber(y), tonumber(s)
    if x and y and s then
      obj.gps = gps_helpers.gps_from_map_position({x=x, y=y}, math.floor(s))
    else
      obj.gps = BLANK_GPS
    end
  else
    obj.gps = gps or BLANK_GPS
  end
  ---@type boolean
  obj.locked = locked or false
  ---@type table|nil
  obj.tag = tag
  return obj
end

Favorite.__index = Favorite

setmetatable(Favorite, {
  __call = function(cls, ...)
    return cls:new(...)
  end
})

--- Update the GPS string for this favorite
-- @param new_gps string The new GPS string
function Favorite:update_gps(new_gps)
  self.gps = new_gps
end

--- Toggle the locked state of this favorite
function Favorite:toggle_locked()
  self.locked = not self.locked
end

function Favorite.copy(fav)
  if type(fav) ~= "table" then return nil end
  local copy = Favorite:new(fav.gps, fav.locked, fav.tag and Helpers.deep_copy(fav.tag) or nil)
  for k, v in pairs(fav) do
    if copy[k] == nil then copy[k] = v end
  end
  return copy
end

function Favorite.equals(a, b)
  if type(a) ~= "table" or type(b) ~= "table" then return false end
  return a.gps == b.gps and a.locked == b.locked and (a.tag and a.tag.text or nil) == (b.tag and b.tag.text or nil)
end

--- Returns a blank favorite (sentinel for unused slot)
function Favorite.get_blank_favorite()
  return Favorite:new(BLANK_GPS, false, nil)
end

--- Checks if a favorite is blank (unused slot)
function Favorite.is_blank_favorite(fav)
  if type(fav) ~= "table" then return false end
  if next(fav) == nil then return true end
  return (fav.gps == "" or fav.gps == nil or fav.gps == BLANK_GPS) and (fav.locked == false or fav.locked == nil)
end

function Favorite:valid()
  return type(self) == "table" and type(self.gps) == "string" and self.gps ~= "" and self.gps ~= BLANK_GPS
end

--- Format a tooltip string for this Favorite
-- @return string Tooltip text
function Favorite:formatted_tooltip()
  if not self.gps or self.gps == "" or self.gps == BLANK_GPS then return "Empty favorite slot" end
  local GPS = require("core.gps.gps")
  local tooltip = GPS.coords_string_from_gps(self.gps) or self.gps
  if self.tag ~= nil and type(self.tag) == "table" and self.tag.text ~= nil and self.tag.text ~= "" then
    tooltip = tooltip .. "\n" .. self.tag.text
  end
  return tooltip
end

-- GPS string must always be a string in the format 'xxx.yyy.s'.
-- Never store or pass GPS as a table except for temporary parsing/conversion.
-- See README and gps_helpers.lua for details and valid examples.

return Favorite
