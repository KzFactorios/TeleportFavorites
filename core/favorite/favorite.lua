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
    gps = gps or (Constants.settings.BLANK_GPS --[[@as string]]),
    locked = locked or false,
    tag = tag or nil
  }
end

--- Update the GPS string for this favorite
---@param fav Favorite
---@param new_gps string
function FavoriteUtils.update_gps(fav, new_gps)
  FavoriteUtils.update_property(fav, "gps", new_gps)
end

--- Toggle the locked state of this favorite
---@param fav Favorite
function FavoriteUtils.toggle_locked(fav)
  FavoriteUtils.update_property(fav, "locked")
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
  return FavoriteUtils.new((Constants.settings.BLANK_GPS --[[@as string]]), false, nil)
end

--- Generic state checking method for favorites
---@param fav Favorite? The favorite to check
---@param check_type string Type of check: "blank", "valid", "locked", "empty"
---@return boolean
function FavoriteUtils.check_state(fav, check_type)
  if check_type == "blank" then
    if type(fav) ~= "table" then return false end
    if next(fav) == nil then return true end
    return (fav.gps == "" or fav.gps == nil or fav.gps == (Constants.settings.BLANK_GPS --[[@as string]])) and (fav.locked == false or fav.locked == nil)
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

---@param fav Favorite?
---@return boolean
function FavoriteUtils.valid(fav)
  return FavoriteUtils.check_state(fav, "valid")
end

---@param fav Favorite?
---@return string|table
function FavoriteUtils.formatted_tooltip(fav)
  if not fav or not fav.gps or fav.gps == "" or fav.gps == (Constants.settings.BLANK_GPS --[[@as string]]) then
    return {"tf-gui.favorite_slot_empty"}
  end
  local tooltip = coords_string_from_gps(fav.gps) or fav.gps
  if fav.tag ~= nil and type(fav.tag) == "table" and fav.tag.text ~= nil and fav.tag.text ~= "" then
    tooltip = tooltip .. "\n" .. fav.tag.text
  end
  return tooltip
end

--- Generic formatting method for favorites with flexible output options
---@param fav Favorite The favorite to format
---@param format_type string Format type: "tooltip", "display", "debug", "compact"
---@param options table? Optional formatting options (max_length, include_coords, include_tag, empty_text, etc.)
---@return string|table
function FavoriteUtils.format_output(fav, format_type, options)
  options = options or {}
  
  if format_type == "tooltip" then
    -- Use existing logic for backward compatibility
    return FavoriteUtils.formatted_tooltip(fav)
  elseif format_type == "display" then
    if FavoriteUtils.check_state(fav, "blank") then
      return options.empty_text or "Empty"
    end
    local result = options.include_coords ~= false and (coords_string_from_gps(fav.gps) or fav.gps) or ""
    if options.include_tag ~= false and fav.tag and fav.tag.text then
      local tag_text = fav.tag.text
      if options.max_length and #tag_text > options.max_length then
        tag_text = tag_text:sub(1, options.max_length) .. "..."
      end
      result = result .. (result ~= "" and " - " or "") .. tag_text
    end
    return result
  elseif format_type == "debug" then
    return string.format("Favorite{gps='%s', locked=%s, tag=%s}", 
      fav.gps or "nil", 
      tostring(fav.locked), 
      fav.tag and "present" or "nil")
  elseif format_type == "compact" then
    if FavoriteUtils.check_state(fav, "blank") then
      return options.empty_text or "Empty"
    end
    return coords_string_from_gps(fav.gps) or fav.gps
  end
  
  return ""
end

--- Generic factory method for creating favorites with different patterns
---@param factory_type string Type of favorite to create: "new", "blank", "copy", "from_tag", "from_coords"
---@param ... any Variable arguments based on factory type
---@return Favorite|nil
function FavoriteUtils.create_favorite(factory_type, ...)
  local args = {...}
    if factory_type == "new" then
    local gps, locked, tag = args[1], args[2], args[3]
    return FavoriteUtils.new(gps, locked, tag)
  elseif factory_type == "blank" then
    return FavoriteUtils.new((Constants.settings.BLANK_GPS --[[@as string]]), false, nil)
  elseif factory_type == "copy" then
    local fav = args[1]
    return FavoriteUtils.copy(fav)
  elseif factory_type == "from_tag" then
    local tag, locked = args[1], args[2]
    if not tag or not tag.gps then return nil end
    return FavoriteUtils.new(tag.gps, locked or false, tag)
  elseif factory_type == "from_coords" then
    local x, y, surface, locked = args[1], args[2], args[3], args[4]
    if not x or not y then return nil end
    local gps = string.format("%d.%d.%s", x, y, surface or "1")
    return FavoriteUtils.new(gps, locked or false, nil)
  end
  
  return nil
end


return FavoriteUtils
