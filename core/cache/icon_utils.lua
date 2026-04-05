---@diagnostic disable: undefined-global

-- core/cache/icon_utils.lua
-- Centralized icon normalization and conversion helpers.

local GuiValidation = require("core.utils.gui_validation")
local ErrorHandler = require("core.utils.error_handler")

local IconUtils = {}

-- Icon type lookup cache (non-persistent)
IconUtils.icon_type_lookup = IconUtils.icon_type_lookup or {}

--- Dynamically resolves the icon type for rich text using prototype tables
---@param icon table { name: string, type?: string }
---@return string icon_type
local function get_icon_type(icon)
  if not icon or type(icon) ~= "table" or not icon.name or icon.name == "" then return "item" end
  local icon_name = icon.name
  local lookup = IconUtils.icon_type_lookup
  if lookup[icon_name] then return lookup[icon_name] end
  local icon_type = icon.type
  if icon_type == "virtual" then icon_type = "virtual_signal" end
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

--- Erase the icon type lookup cache
function IconUtils.reset_icon_type_lookup()
  IconUtils.icon_type_lookup = {}
end

--- Formats an icon object into Factorio rich text for display in GUIs
---@param icon table { name: string, type?: string }
---@return string # Rich text string for the icon (e.g. [item=iron-plate])
local function format_icon_as_rich_text(icon)
  local ok, result = pcall(function()
    if not icon or type(icon) ~= "table" or not icon.name or type(icon.name) ~= "string" or icon.name == "" then
      return ""
    end
    local icon_type = get_icon_type(icon)
    if type(icon_type) ~= "string" or icon_type == "" then icon_type = "item" end
    if icon_type == "virtual_signal" then icon_type = "virtual-signal" end
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

IconUtils.get_icon_type = get_icon_type
IconUtils.format_icon_as_rich_text = format_icon_as_rich_text

--- Return a canonical icon table or nil. Ensures `type` is set to normalized internal token.
---@param icon string|table|nil
---@return table|nil canonical_icon
function IconUtils.get_canonical_icon(icon)
  if not icon then return nil end
  if type(icon) == "string" and icon ~= "" then
    return { name = icon, type = IconUtils.get_icon_type({ name = icon }) }
  end
  if type(icon) ~= "table" then return nil end
  if not icon.name or icon.name == "" then return nil end
  local t = icon.type and icon.type ~= "" and icon.type or IconUtils.get_icon_type(icon)
  if t == "virtual" then t = "virtual_signal" end
  return { name = icon.name, type = t }
end

--- Convert canonical/partial icon into a sprite path usable in GUI (`type/name`), with validation.
---@param icon string|table|nil
---@param opts table? { fallback=string, log_context=table }
---@return string sprite_path, boolean used_fallback, table debug_info
function IconUtils.to_sprite_path(icon, opts)
  opts = opts or {}
  local fallback = opts.fallback or "utility/unknown"
  local log_context = opts.log_context or {}
  local debug_info = { original = icon }

  local canonical = IconUtils.get_canonical_icon(icon)
  if not canonical then
    debug_info.reason = "no canonical icon"
    return fallback, true, debug_info
  end

  local prefix = canonical.type or "item"
  if prefix == "virtual_signal" then prefix = "virtual-signal" end
  local path = prefix .. "/" .. canonical.name
  debug_info.generated = path

  local ok, err = GuiValidation.validate_sprite(path)
  if not ok then
    debug_info.reason = err
    if ErrorHandler and ErrorHandler.warn_log then
      ErrorHandler.warn_log("IconUtils.to_sprite_path validation failed, using fallback", { path = path, reason = err })
    end
    return fallback, true, debug_info
  end
  return path, false, debug_info
end

--- Convert icon into choose-elem-button options. Returns an opts table (may be empty for full chooser)
---@param icon string|table|nil
---@return table opts
function IconUtils.to_choose_elem_opts(icon)
  local canonical = IconUtils.get_canonical_icon(icon)
  if not canonical then return {} end
  local name = canonical.name
  local t = canonical.type
  if t == "item" then return { elem_type = "item", item = name } end
  if t == "fluid" then return { elem_type = "fluid", fluid = name } end
  if t == "virtual_signal" then return { elem_type = "signal", signal = { type = "virtual", name = name } } end
  if t == "recipe" then return { elem_type = "recipe", recipe = name } end
  return {}
end

--- Return rich-text representation for display in labels
---@param icon string|table|nil
---@return string rich_text
function IconUtils.to_rich_text(icon)
  local canonical = IconUtils.get_canonical_icon(icon)
  if not canonical then return "" end
  return IconUtils.format_icon_as_rich_text(canonical)
end

return IconUtils
