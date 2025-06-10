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
local basic_helpers = require("core.utils.basic_helpers")

local function deep_copy(orig)
  if type(orig) ~= 'table' then return orig end
  local copy = {}
  for k, v in pairs(orig) do
    copy[k] = type(v) == 'table' and deep_copy(v) or v
  end
  return copy
end

local function coords_string_from_gps(gps)
  if not gps or gps == "" or gps == Constants.settings.BLANK_GPS then return nil end
  local x, y, s = gps:match("^([^%.]+)%.([^%.]+)%.(.+)$")
  if not (x and y and s) then return nil end
  local padlen = Constants.settings.GPS_PAD_NUMBER
  return basic_helpers.pad(tonumber(x), padlen) .. "." .. basic_helpers.pad(tonumber(y), padlen)
end


local FavoriteUtils = {}

function FavoriteUtils.new(gps, locked, tag)
  return {
    gps = gps or Constants.settings.BLANK_GPS,
    locked = locked or false,
    tag = tag or nil
  }
end
--- Update the GPS string for this favorite
function FavoriteUtils.update_gps(fav, new_gps)
  fav.gps = new_gps
end

--- Toggle the locked state of this favorite
function FavoriteUtils.toggle_locked(fav)
  fav.locked = not fav.locked
end

function FavoriteUtils.copy(fav)
  if type(fav) ~= "table" then return nil end
  local copy = FavoriteUtils.new(fav.gps, fav.locked, fav.tag and deep_copy(fav.tag) or nil)
  for k, v in pairs(fav) do
    if copy[k] == nil then copy[k] = v end
  end
  return copy
end

function FavoriteUtils.equals(a, b)
  if type(a) ~= "table" or type(b) ~= "table" then return false end
  return a.gps == b.gps and a.locked == b.locked and (a.tag and a.tag.text or nil) == (b.tag and b.tag.text or nil)
end

function FavoriteUtils.get_blank_favorite()
  return FavoriteUtils.new(Constants.settings.BLANK_GPS, false, nil)
end

function FavoriteUtils.is_blank_favorite(fav)
  if type(fav) ~= "table" then return false end
  if next(fav) == nil then return true end
  return (fav.gps == "" or fav.gps == nil or fav.gps == Constants.settings.BLANK_GPS) and (fav.locked == false or fav.locked == nil)
end

function FavoriteUtils.valid(fav)
  return type(fav) == "table" and type(fav.gps) == "string" and fav.gps ~= "" and fav.gps ~= Constants.settings.BLANK_GPS
end

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

function FavoriteUtils.move(fav, new_gps)
  if type(new_gps) ~= "string" or new_gps == "" or new_gps == Constants.settings.BLANK_GPS then return false, "Invalid GPS string" end
  fav.gps = new_gps
  -- Note: Tag position updates are handled by caller if needed
  if type(fav.tag) == "table" then
    if fav.tag.gps then fav.tag.gps = new_gps end
  end
  return true
end

-- GPS string must always be a string in the format 'xxx.yyy.s'.
-- Never store or pass GPS as a table except for temporary parsing/conversion.

return FavoriteUtils
