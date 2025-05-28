--[[
core/favorite/favorite.lua
TeleportFavorites Factorio Mod
-----------------------------
Favorite class for representing a player's favorite teleport location.

- Each Favorite is identified by a GPS string (always in 'xxx.yyy.s' format).
- Supports locked state (prevents removal or editing in the UI).
- Optionally holds a tag table for tooltip formatting and richer UI.
- Provides helpers for construction, copying, equality, blank/unused slot detection, and tooltip formatting.
- Used throughout the mod for favorites bar, tag editor, and persistent player data.

API:
-----
- Favorite.new(gps, locked, tag)         -- Constructor (supports both :new and .new).
- Favorite:move(new_gps)                 -- Move this favorite to a new GPS location.
- Favorite:update_gps(new_gps)           -- Update the GPS string for this favorite.
- Favorite:toggle_locked()               -- Toggle the locked state.
- Favorite.copy(fav)                     -- Deep copy a Favorite.
- Favorite.equals(a, b)                  -- Equality check for two Favorites.
- Favorite.get_blank_favorite()          -- Returns a blank favorite (sentinel for unused slot).
- Favorite.is_blank_favorite(fav)        -- Checks if a favorite is blank (unused slot).
- Favorite:valid()                       -- Returns true if this favorite is valid (not blank).
- Favorite:formatted_tooltip()           -- Returns a formatted tooltip string for UI.

Notes:
------
- GPS string must always be a string in the format 'xxx.yyy.s'. Never store or pass GPS as a table except for temporary parsing/conversion.
- See README and gps_helpers.lua for details and valid examples.
]]

local helpers = require("core.utils.helpers_suite")
local gps_helpers = require("core.utils.gps_helpers")
local parse_and_normalize_gps = gps_helpers.parse_and_normalize_gps

---@class Favorite
---@field gps string The GPS string identifying the location (must always be a string in the format 'xxx.yyy.s', see GPS String Format section)
---@field locked boolean Whether the favorite is locked (default: false)
---@field tag? table Optional tag table for tooltip formatting
local Favorite = {}
Favorite.__index = Favorite

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
  obj.gps = parse_and_normalize_gps(gps)
  obj.locked = locked or false
  obj.tag = tag
  return obj
end

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
  local copy = Favorite:new(fav.gps, fav.locked, fav.tag and helpers.deep_copy(fav.tag) or nil)
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
  return Favorite:new(gps_helpers.BLANK_GPS, false, nil)
end

--- Checks if a favorite is blank (unused slot)
function Favorite.is_blank_favorite(fav)
  if type(fav) ~= "table" then return false end
  if next(fav) == nil then return true end
  return (fav.gps == "" or fav.gps == nil or fav.gps == gps_helpers.BLANK_GPS) and (fav.locked == false or fav.locked == nil)
end

function Favorite:valid()
  return type(self) == "table" and type(self.gps) == "string" and self.gps ~= "" and self.gps ~= gps_helpers.BLANK_GPS
end

--- Format a tooltip string for this Favorite
-- @return string Tooltip text
function Favorite:formatted_tooltip()
  if not self.gps or self.gps == "" or self.gps == gps_helpers.BLANK_GPS then
    return {"tf-gui.favorite_slot_empty"}
  end
  local GPS = require("core.gps.gps")
  local tooltip = GPS.coords_string_from_gps(self.gps) or self.gps
  if self.tag ~= nil and type(self.tag) == "table" and self.tag.text ~= nil and self.tag.text ~= "" then
    tooltip = tooltip .. "\n" .. self.tag.text
  end
  return tooltip
end

--- Move this favorite to a new GPS location
-- @param new_gps string The new GPS string (must be validated before calling)
function Favorite:move(new_gps)
  if type(new_gps) ~= "string" or new_gps == "" or new_gps == gps_helpers.BLANK_GPS then return false, "Invalid GPS string" end
  self.gps = new_gps
  if type(self.tag) == "table" then
    if self.tag.position then
      local parsed = gps_helpers.parse_gps_string(new_gps)
      if parsed then
        self.tag.position = {x = parsed.x, y = parsed.y}; self.tag.surface = parsed.surface_index
      end
    end
    if self.tag.gps then self.tag.gps = new_gps end
  end
  return true
end

-- GPS string must always be a string in the format 'xxx.yyy.s'.
-- Never store or pass GPS as a table except for temporary parsing/conversion.

return Favorite
