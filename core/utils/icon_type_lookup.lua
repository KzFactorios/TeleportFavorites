-- core/utils/icon_type_lookup.lua
-- Builds and provides O(1) lookup for icon types by name

local IconTypeLookup = {}

---@class IconTypeLookup
---@field icon_type_by_name table<string, string>
local icon_type_by_name = {}

--- Initialize the lookup table (call once at mod init)
function IconTypeLookup.initialize()
  icon_type_by_name = {}
  for name, _ in pairs(game.item_prototypes) do
    icon_type_by_name[name] = "item"
  end
  for name, _ in pairs(game.fluid_prototypes) do
    icon_type_by_name[name] = "fluid"
  end
  for name, _ in pairs(game.virtual_signal_prototypes) do
    icon_type_by_name[name] = "virtual-signal"
  end
  for name, _ in pairs(game.entity_prototypes) do
    icon_type_by_name[name] = "entity"
  end
  for name, _ in pairs(game.recipe_prototypes) do
    icon_type_by_name[name] = "recipe"
  end
  for name, _ in pairs(game.technology_prototypes) do
    icon_type_by_name[name] = "technology"
  end
end

--- Get icon type by name (O(1) lookup)
---@param icon_name string
---@return string|nil
function IconTypeLookup.get_icon_type(icon_name)
  return icon_type_by_name[icon_name]
end

return IconTypeLookup
