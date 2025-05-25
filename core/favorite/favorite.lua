local ok, GPSorErr = pcall(require, "core.gps.gps")
if not ok then
  error("[TeleportFavorites] Could not load GPS module: " .. tostring(GPSorErr))
end
local GPS = GPSorErr

local Helpers = require("core.utils.helpers")

---@class Favorite
---@field gps string The GPS string identifying the location
---@field locked boolean Whether the favorite is locked (default: false)
---@field map_tag? table Optional map tag table for tooltip formatting
local Favorite = {}
Favorite.__index = Favorite

local BLANK_GPS = "1000000.1000000.1"

--- Constructor for Favorite
-- @param gps string The GPS string
-- @param locked boolean|nil Optional, defaults to false
-- @param map_tag table|nil Optional, defaults to nil
-- @return Favorite
function Favorite:new(gps, locked, map_tag)
  local obj = setmetatable({}, self)
  ---@type string
  if type(gps) == "string" and gps:match("^%[gps=") then
    -- Parse [gps=x,y,s] format and normalize
    local x, y, s = gps:match("%[gps=(%-?%d+),(%-?%d+),(%-?%d+)%]")
    x, y, s = tonumber(x), tonumber(y), tonumber(s)
    if x and y and s then
      obj.gps = GPS.gps_from_map_position({x=x, y=y}, math.floor(s))
    else
      obj.gps = BLANK_GPS
    end
  else
    obj.gps = gps or BLANK_GPS
  end
  ---@type boolean
  obj.locked = locked or false
  ---@type table|nil
  obj.map_tag = map_tag
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
