---@diagnostic disable: undefined-global


local icon_typing = {}

---@type table<string, string>
icon_typing.icon_type_lookup = {}


---@param icon table { name: string, type?: string }
---@return string icon_type
local function get_icon_type(icon)
  if not icon or type(icon) ~= "table" or not icon.name or icon.name == "" then return "item" end
  local icon_name = icon.name
  local lookup = icon_typing.icon_type_lookup
  if lookup[icon_name] then
    return lookup[icon_name]
  end
  local icon_type = icon.type
  if icon_type == "virtual" then
    icon_type = "virtual_signal"
  end
  if icon_type and type(icon_type) == "string" and icon_type ~= "" then
    local valid_types = {
      ["item"] = true, ["fluid"] = true, ["virtual_signal"] = true, ["entity"] = true, ["equipment"] = true,
      ["technology"] = true, ["recipe"] = true, ["tile"] = true
    }
    if valid_types[icon_type] then
      local proto_table = prototypes[icon_type]
      if proto_table and proto_table[icon_name] then
        lookup[icon_name] = icon_type
        return icon_type
      end
    end
  end
  local vanilla_types = { "item", "fluid", "virtual_signal", "entity", "equipment", "technology", "recipe", "tile" }
  for _, t in ipairs(vanilla_types) do
    local proto_table = prototypes[t]
    if proto_table and proto_table[icon_name] then
      lookup[icon_name] = t
      return t
    end
  end
  for proto_type, proto_table in pairs(prototypes) do
    if type(proto_table) == "table" and proto_table[icon_name] then
      lookup[icon_name] = proto_type
      return proto_type
    end
  end
  if ErrorHandler and ErrorHandler.warn_log then
    ErrorHandler.warn_log("Unknown icon type or prototype lookup failed", { icon = icon, icon_name = icon_name, icon_type = icon_type })
  end
  lookup[icon_name] = "item"
  return "item"
end

---@param icon table { name: string, type?: string }
---@return string # Rich text string for the icon (e.g. [item=iron-plate])
function icon_typing.format_icon_as_rich_text(icon)
  local ok, result = pcall(function()
    if not icon or type(icon) ~= "table" or not icon.name or type(icon.name) ~= "string" or icon.name == "" then
      return ""
    end
    local icon_type = get_icon_type(icon)
    if type(icon_type) ~= "string" or icon_type == "" then icon_type = "item" end
    if icon_type == "virtual_signal" then
      icon_type = "virtual-signal"
    end
    local icon_name = icon.name
    return string.format("[%s=%s]", icon_type, icon_name)
  end)
  if ok and type(result) == "string" then
    return result
  else
    if ErrorHandler and ErrorHandler.warn_log then
      ErrorHandler.warn_log("format_icon_as_rich_text failed, returning blank", { icon = icon, error = result })
    end
    return ""
  end
end

function icon_typing.reset_icon_type_lookup()
  icon_typing.icon_type_lookup = {}
end

return icon_typing
