local UIEnums = require("prototypes.enums.ui_enums")
local CoreEnums = require("prototypes.enums.core_enums")

---@class Enum
---@field UIEnums table UI-related enums (colors, sprites, GUI elements)
---@field CoreEnums table Core system enums (events, return states, utilities)
---@field SpriteEnum table Backward compatibility alias
---@field ColorEnum table Backward compatibility alias
---@field GuiEnum table Backward compatibility alias
---@field ReturnStateEnum table Backward compatibility alias
---@field EventEnum table Backward compatibility alias
local Enum = {}

Enum.UIEnums = UIEnums
Enum.CoreEnums = CoreEnums

Enum.SpriteEnum = UIEnums.Sprites
Enum.ColorEnum = UIEnums.Colors
Enum.GuiEnum = UIEnums.GuiEnum
Enum.ReturnStateEnum = CoreEnums.ReturnStates
Enum.EventEnum = CoreEnums.Events

Enum.get_enum_by_value = CoreEnums.get_enum_by_value
Enum.is_value_member_enum = CoreEnums.is_value_member_enum
Enum.get_key_names = CoreEnums.get_key_names
Enum.get_key_values = CoreEnums.get_key_values
Enum.map_enum = CoreEnums.map_enum

return Enum
