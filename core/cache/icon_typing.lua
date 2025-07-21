---@diagnostic disable: undefined-global


local icon_typing = {}

--- Non-persistent O(1) lookup table: icon name -> type
---@type table<string, string>
icon_typing.icon_type_lookup = {}


--- Dynamically resolves the icon type for rich text using game.get_filtered_prototypes (Factorio v2.0+)
---@param icon table { name: string, type?: string }
---@return string icon_type
local function get_icon_type(icon)
  if not icon or type(icon) ~= "table" or not icon.name or icon.name == "" then return "item" end
  local icon_name = icon.name
  local lookup = icon_typing.icon_type_lookup
  -- O(1) lookup first
  if lookup[icon_name] then
    return lookup[icon_name]
  end
  -- Try explicit type first
  if icon.type and type(icon.type) == "string" and icon.type ~= "" then
    local proto_table = prototypes[icon.type]
    if proto_table and proto_table[icon_name] then
      lookup[icon_name] = icon.type
      return icon.type
    end
  end
  -- Try all known vanilla types
  local vanilla_types = { "item", "fluid", "virtual_signal", "entity", "equipment", "technology", "recipe", "tile" }
  for _, t in ipairs(vanilla_types) do
    local proto_table = prototypes[t]
    if proto_table and proto_table[icon_name] then
      lookup[icon_name] = t
      return t
    end
  end
  -- Try all modded types
  for proto_type, proto_table in pairs(prototypes) do
    if type(proto_table) == "table" and proto_table[icon_name] then
      lookup[icon_name] = proto_type
      return proto_type
    end
  end
  lookup[icon_name] = "item"
  return "item"
end

--- Formats an icon object into Factorio rich text for display in GUIs
---@param icon table { name: string, type?: string }
---@return string # Rich text string for the icon (e.g. [item=iron-plate])
function icon_typing.format_icon_as_rich_text(icon)
  if not icon or type(icon) ~= "table" or not icon.name or type(icon.name) ~= "string" or icon.name == "" then
    return ""
  end
  local icon_type = get_icon_type(icon)
  if type(icon_type) ~= "string" or icon_type == "" then icon_type = "item" end
  local icon_name = icon.name
  return string.format("[%s=%s]", icon_type, icon_name)
end

--- Erases all entries in the icon_type_lookup table (non-persistent)
function icon_typing.reset_icon_type_lookup()
  icon_typing.icon_type_lookup = {}
end

return icon_typing
