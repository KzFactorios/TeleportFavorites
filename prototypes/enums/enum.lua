-- Centralized enum access point for TeleportFavorites
---@class Enum
---@field SpriteEnum SpriteEnum
---@field ColorEnum table
---@field GuiEnum table
local Enum = {}

Enum.SpriteEnum = require("prototypes.enums.sprite_enum")
Enum.ColorEnum = require("prototypes.enums.color_enum")
Enum.GuiEnum = require("prototypes.enums.gui_enum")


--- Generic: Given a value to match and an enum table, return the key for the matching value (or nil if not found)
--- @return COLOR_ENUM|GUI_FRAME|GUI_ELEMENT|SPRITE_ENUM|nil
function Enum.get_enum_by_value(value, enum)
  if type(enum) ~= "table" then return nil end
  for k, v in pairs(enum) do
    if v == value then
      return k
    end
  end
  return nil
end

--- Generic: Check if a value exists in an enum table
--- @param value string
--- @param enum table
--- @return boolean
function Enum.is_value_member_enum(value, enum)
  if not value then return false end
  if type(enum) ~= "table" then return false end
  for _, v in pairs(enum) do
    if v == value then
      return true
    end
  end
  return false
end

--- Generic: Return a list of key names for an enum table
--- @return string[]
function Enum.get_key_names(enum)
  if type(enum) ~= "table" then return {} end
  local keys = {}
  for k, _ in pairs(enum) do
    table.insert(keys, k)
  end
  return keys
end

--- Generic: Return a list of values for an enum table
--- @return any[]
function Enum.get_key_values(enum)
  if type(enum) ~= "table" then return {} end
  local values = {}
  for _, v in pairs(enum) do
    table.insert(values, v)
  end
  return values
end

return Enum
