---@param fav Favorite?
---@return Favorite?
function FavoriteUtils.normalize_blank_favorite(fav)
  if fav and (fav.gps == nil or fav.gps == "") then
    fav.gps = Constants.settings.BLANK_GPS
  end
  return fav
end
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
local CollectionUtils = require("core.utils.collection_utils")

---@class Favorite
---@field gps string GPS coordinates in 'xxx.yyy.s' format
---@field locked boolean Whether the favorite is locked (prevents removal/editing)
---@field tag table? Optional tag table for tooltip formatting and richer UI


local FavoriteUtils = {}

---@param gps string?
---@param locked boolean?
---@param tag table?
---@return Favorite
function FavoriteUtils.new(gps, locked, tag)
  return {
    gps = gps or (Constants.settings.BLANK_GPS --[[@as string]]),
    locked = locked or false,
    tag = tag or nil
  }
end

--- Toggle the locked state of this favorite
---@param fav Favorite
function FavoriteUtils.toggle_locked(fav)
  FavoriteUtils.update_property(fav, "locked")
end

--- Generic state checking method for favorites
---@param fav Favorite? The favorite to check
---@param check_type string Type of check: "blank", "valid", "locked", "empty"
---@return boolean
function FavoriteUtils.check_state(fav, check_type)
  if check_type == "blank" then
    if type(fav) ~= "table" then 
      return false 
    end
    if next(fav) == nil then 
      return true 
    end
    local is_blank = (fav.gps == "" or fav.gps == nil or fav.gps == (Constants.settings.BLANK_GPS --[[@as string]])) 
      and (fav.locked == false or fav.locked == nil)
    return is_blank
  elseif check_type == "valid" then
    return type(fav) == "table" and type(fav.gps) == "string" and fav.gps ~= "" and fav.gps ~= (Constants.settings.BLANK_GPS --[[@as string]])
  elseif check_type == "locked" then
    return type(fav) == "table" and fav.locked == true
  elseif check_type == "empty" then
    return type(fav) ~= "table" or next(fav) == nil
  end
  return false
end

---@param fav Favorite?
---@return boolean
function FavoriteUtils.is_blank_favorite(fav)
  return FavoriteUtils.check_state(fav, "blank")
end

---@return Favorite
function FavoriteUtils.get_blank_favorite()
  return FavoriteUtils.new((Constants.settings.BLANK_GPS --[[@as string]]), false, nil)
end

---@param fav Favorite?
---@return boolean
function FavoriteUtils.valid(fav)
  return FavoriteUtils.check_state(fav, "valid")
end

---@param fav Favorite
---@return Favorite?
function FavoriteUtils.copy(fav)
  if type(fav) ~= "table" then return nil end
  local copy = FavoriteUtils.new(fav.gps, fav.locked, fav.tag and CollectionUtils.deep_copy(fav.tag) or nil)
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

--- Generic property update method for favorites
---@param fav Favorite The favorite to modify
---@param property string Property name ("gps", "locked", "tag")
---@param value any? New value for the property (nil for toggle operations on booleans)
function FavoriteUtils.update_property(fav, property, value)
  if property == "gps" and type(value) == "string" then
    fav.gps = value
  elseif property == "locked" then
    if value ~= nil then
      fav.locked = value
    else
      -- Toggle if no value provided
      fav.locked = not fav.locked
    end
  elseif property == "tag" then
    fav.tag = value
  end
end

return FavoriteUtils
