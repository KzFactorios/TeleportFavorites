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


Notes:
------
- GPS string must always be a string in the format 'xxx.yyy.s'. Never store or pass GPS as a table except for temporary parsing/conversion.
- See README and gps_helpers.lua for details and valid examples.
]]

local Constants = require("constants")
local TableHelpers = require("core.utils.table_helpers")
local gps_core = require("core.utils.gps_core")

---@class Favorite
---@field gps string GPS coordinates in 'xxx.yyy.s' format
---@field locked boolean Whether the favorite is locked (prevents removal/editing)
---@field tag table? Optional tag table for tooltip formatting and richer UI

-- Use centralized coordinate string function instead of local duplication
local coords_string_from_gps = gps_core.coords_string_from_gps


local FavoriteUtils = {}

---@param gps string?
---@param locked boolean?
---@param tag table?
---@return Favorite
function FavoriteUtils.new(gps, locked, tag)
  return {
    gps = gps or Constants.settings.BLANK_GPS,
    locked = locked or false,
    tag = tag or nil
  }
end

--- Update the GPS string for this favorite
---@param fav Favorite
---@param new_gps string
function FavoriteUtils.update_gps(fav, new_gps)
  fav.gps = new_gps
end

--- Toggle the locked state of this favorite
---@param fav Favorite
function FavoriteUtils.toggle_locked(fav)
  fav.locked = not fav.locked
end

---@param fav Favorite
---@return Favorite?
function FavoriteUtils.copy(fav)
  if type(fav) ~= "table" then return nil end
  local copy = FavoriteUtils.new(fav.gps, fav.locked, fav.tag and TableHelpers.deep_copy(fav.tag) or nil)
  for k, v in pairs(fav) do
    if copy[k] == nil then copy[k] = v end
  end
  return copy
end

---@param a Favorite
---@param b Favorite
---@return boolean
function FavoriteUtils.equals(a, b)
  if type(a) ~= "table" or type(b) ~= "table" then return false end
  return a.gps == b.gps and a.locked == b.locked and (a.tag and a.tag.text or nil) == (b.tag and b.tag.text or nil)
end

---@return Favorite
function FavoriteUtils.get_blank_favorite()
  return FavoriteUtils.new(Constants.settings.BLANK_GPS, false, nil)
end

---@param fav Favorite?
---@return boolean
function FavoriteUtils.is_blank_favorite(fav)
  if type(fav) ~= "table" then return false end
  if next(fav) == nil then return true end
  return (fav.gps == "" or fav.gps == nil or fav.gps == Constants.settings.BLANK_GPS) and (fav.locked == false or fav.locked == nil)
end

---@param fav Favorite
---@return boolean
function FavoriteUtils.valid(fav)
  return type(fav) == "table" and type(fav.gps) == "string" and fav.gps ~= "" and fav.gps ~= Constants.settings.BLANK_GPS
end

---@param fav Favorite
---@return string|table
function FavoriteUtils.formatted_tooltip(fav)
  if not fav.gps or fav.gps == "" or fav.gps == Constants.settings.BLANK_GPS then
    return {"tf-gui.favorite_slot_empty"}
  end
  local tooltip = coords_string_from_gps(fav.gps) or fav.gps
  if fav.tag ~= nil and type(fav.tag) == "table" and fav.tag.text ~= nil and fav.tag.text ~= "" then
    tooltip = tooltip .. "\n" .. fav.tag.text
  end
  return tooltip
end


return FavoriteUtils
