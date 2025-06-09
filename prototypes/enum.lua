-- Centralized enum access point for TeleportFavorites
local Enum = {}

Enum.ColorEnum = require("prototypes.color_enum")
Enum.SpriteEnum = require("prototypes.sprite_enum")
Enum.GuiEnum = require("prototypes.gui_enum")



-- Generic: Given a value to match and an enum table, return the key for the matching value (or nil if not found)
function Enum.get_enum_by_value(value, enum_tbl)
  if type(enum_tbl) ~= "table" then return nil end
  for k, v in pairs(enum_tbl) do
    if v == value then
      return k
    end
  end
  return nil
end

-- Generic: Check if a value exists in an enum table
function Enum.is_enum_member(value, enum_tbl)
  if type(enum_tbl) ~= "table" then return false end
  for _, v in pairs(enum_tbl) do
    if v == value then
      return true
    end
  end
  return false
end

-- Generic: Return a list of key names for an enum table
function Enum.get_key_names(enum_tbl)
  if type(enum_tbl) ~= "table" then return {} end
  local keys = {}
  for k, _ in pairs(enum_tbl) do
    table.insert(keys, k)
  end
  return keys
end

-- Generic: Return a list of values for an enum table
function Enum.get_key_values(enum_tbl)
  if type(enum_tbl) ~= "table" then return {} end
  local values = {}
  for _, v in pairs(enum_tbl) do
    table.insert(values, v)
  end
  return values
end

return Enum
