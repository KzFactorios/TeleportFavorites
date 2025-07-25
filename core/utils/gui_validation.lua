---@diagnostic disable: undefined-global

-- core/utils/gui_validation.lua
-- TeleportFavorites Factorio Mod
-- Provides validation and safety utilities for GUI elements and operations.

local Logger = require("core.utils.error_handler")
local Enum = require("prototypes.enums.ui_enums")
local BasicHelpers = require("core.utils.basic_helpers")

---@class GuiValidation
local GuiValidation = {}

--- Generic validator for GUI elements (Factorio runtime objects)
---@param element LuaGuiElement|nil
---@param type_name string
---@return boolean is_valid, string? error_message
function GuiValidation.validate_gui_runtime_element(element, type_name)
  if not element then return false, type_name .. " is nil" end
  if not element.valid then return false, type_name .. " is not valid" end
  return true, nil
end

--- Validate GUI element exists and is valid
---@param element LuaGuiElement? Element to validate
---@return boolean is_valid True if element is valid
function GuiValidation.validate_gui_element(element)
  local is_valid = GuiValidation.validate_gui_runtime_element(element, "GUI element")
  return is_valid
end

--- Apply style properties to element with validation
---@param element LuaGuiElement? Element to style
---@param style_props table Style properties to apply
---@return boolean success True if successfully applied
function GuiValidation.apply_style_properties(element, style_props)
  if not GuiValidation.validate_gui_element(element) or type(style_props) ~= "table" then
    return false
  end
  ---@cast element -nil

  local success, error_msg = pcall(function()
    for prop, value in pairs(style_props) do
      element.style[prop] = value
    end
  end)

  if not success then
    Logger.warn_log("Failed to apply style properties", {
      element_name = element.name or "<no name>",
      element_type = element.type or "<no type>",
      error = error_msg
    })
  end

  return success
end

--- Safe GUI frame destruction
---@param parent LuaGuiElement Parent element containing the frame
---@param frame_name string Name of the frame to destroy
function GuiValidation.safe_destroy_frame(parent, frame_name)
  if not parent or not frame_name then return end

  if parent[frame_name] and parent[frame_name].valid and type(parent[frame_name].destroy) == "function" then
    parent[frame_name].destroy()
  end
end

--- Set button state and apply style overrides
---@param element LuaGuiElement Button element to modify
---@param enabled boolean? Whether the button should be enabled (default: true)
---@param style_overrides table? Style properties to override
function GuiValidation.set_button_state(element, enabled, style_overrides)
  if not BasicHelpers.is_valid_element(element) then
    Logger.debug_log("set_button_state: element is nil or invalid")
    return
  end

  if not (element.type == "button" or element.type == "sprite-button" or
        element.type == "textfield" or element.type == "text-box" or
        element.type == "choose-elem-button") then
    Logger.debug_log("set_button_state: Unexpected element type", {
      type = element.type,
      name = element.name
    })
    return
  end

  element.enabled = enabled ~= false

  if (element.type == "button" or element.type == "sprite-button" or element.type == "choose-elem-button") and
      style_overrides and type(style_overrides) == "table" then
    for k, v in pairs(style_overrides) do
      element.style[k] = v
    end
  end
end

--- Get the top-level GUI frame that contains an element
---@param element LuaGuiElement Element to search from
---@return LuaGuiElement|nil Top-level frame or nil if not found
function GuiValidation.get_gui_frame_by_element(element)
  if not BasicHelpers.is_valid_element(element) then return nil end
  local current = element
  local iterations = 0
  local max_iterations = 20
  while current and current.valid and iterations < max_iterations do
    iterations = iterations + 1
    if current.type == "frame" then
      local name = current.name or ""
      -- Use enum constants instead of hardcoded strings
      if name == Enum.GuiEnum.GUI_FRAME.TAG_EDITOR or
          name == Enum.GuiEnum.GUI_FRAME.TAG_EDITOR_DELETE_CONFIRM or
          name == Enum.GuiEnum.GUI_FRAME.FAVE_BAR or
          name == Enum.GuiEnum.GUI_FRAME.TELEPORT_HISTORY_MODAL then
        return current
      end
    end
    if not current.parent then break end
    current = current.parent
  end
  return nil
end

--- Recursively find child element by name
---@param parent LuaGuiElement Parent element to search in
---@param child_name string Name of child to find
---@return LuaGuiElement|nil Found child element or nil
function GuiValidation.find_child_by_name(parent, child_name)
  if not parent or not parent.valid or not child_name then return nil end

  -- Direct child check
  local direct_child = parent[child_name]
  if direct_child and direct_child.valid then
    return direct_child
  end

  -- Recursive search with depth limit
  local function recursive_search(element, name, depth)
    if depth > 10 then return nil end

    for _, child in pairs(element.children) do
      if child.valid then
        if child.name == name then
          return child
        end

        local found = recursive_search(child, name, depth + 1)
        if found then return found end
      end
    end
    return nil
  end

  return recursive_search(parent, child_name, 0)
end

--- Validate sprite path exists and is usable
---@param sprite_path string|nil Sprite path to validate
---@return boolean is_valid Whether sprite is valid
---@return string? error_message Error message if invalid
function GuiValidation.validate_sprite(sprite_path)
  if not sprite_path or type(sprite_path) ~= "string" or sprite_path == "" then
    return false, "Sprite path is nil or empty"
  end

  -- Basic format validation
  if not sprite_path:match("^[%w_%-/%.]+$") then
    return false, "Sprite path contains invalid characters"
  end

  -- Check for common patterns including Space Age content
  local valid_prefixes = {
    "item/", "entity/", "technology/", "recipe/",
    "fluid/", "tile/", "signal/", "utility/",
  "virtual-signal/", "equipment/", "achievement/",
    "quality/", "space-location/" -- Space Age prefixes
  }

  local has_valid_prefix = false
  for _, prefix in ipairs(valid_prefixes) do
    if sprite_path:sub(1, #prefix) == prefix then
      has_valid_prefix = true
      break
    end
  end

  if not has_valid_prefix then
    return false, "Sprite path does not have a recognized prefix"
  end

  return true, nil
end

--- Get a validated sprite path for an icon, with fallback and debug info
---@param icon string|table|nil Icon definition (string path or table)
---@param opts table? Options: fallback (string), allow_blank (bool), log_context (table)
---@return string sprite_path Valid sprite path (never blank unless allow_blank)
---@return boolean used_fallback True if fallback was used
---@return table debug_info Debug info for logging
function GuiValidation.get_validated_sprite_path(icon, opts)
  opts = opts or {}
  local fallback = opts.fallback or "utility/unknown"
  local allow_blank = opts.allow_blank or false
  local log_context = opts.log_context or {}
  local sprite_path, used_fallback, debug_info
  used_fallback = false
  debug_info = { original_icon = icon, fallback = fallback }

  -- Normalize icon.type = "virtual" to "virtual_signal" at the very start
  local normalized_icon = icon
  if type(icon) == "table" and icon.type == "virtual" then
    normalized_icon = {}
    for k, v in pairs(icon) do normalized_icon[k] = v end
  normalized_icon.type = "virtual_signal"
  debug_info.normalized_type = "virtual_signal"
  end

  if not normalized_icon or normalized_icon == "" then
    sprite_path = allow_blank and "" or fallback
    used_fallback = not allow_blank
    debug_info.reason = "icon is nil or blank"
  elseif type(normalized_icon) == "string" then
    sprite_path = normalized_icon
  elseif type(normalized_icon) == "table" then
    if normalized_icon.type and normalized_icon.type ~= "" and normalized_icon.name and normalized_icon.name ~= "" then
      sprite_path = normalized_icon.type .. "/" .. normalized_icon.name
      debug_info.generated_path = sprite_path
      debug_info.final_icon_type = normalized_icon.type
      debug_info.final_icon_name = normalized_icon.name
    elseif normalized_icon.name and normalized_icon.name ~= "" then
      -- Default to item type when type is missing
      sprite_path = "item/" .. normalized_icon.name
      debug_info.generated_path = sprite_path
      debug_info.defaulted_type = "item"
    else
      sprite_path = fallback
      used_fallback = true
      debug_info.reason = "icon table missing type or name"
      debug_info.icon_table_details = {
        has_type = normalized_icon.type ~= nil,
        has_name = normalized_icon.name ~= nil,
        type_value =
            normalized_icon.type,
        name_value = normalized_icon.name
      }
    end
  else
    sprite_path = fallback
    used_fallback = true
    debug_info.reason = "icon is not string or table"
  end

  -- Extra debug: log the normalized sprite path and fallback usage
  Logger.debug_log("[GUI_VALIDATION] Sprite path normalization", {
    original_icon = icon,
    normalized_sprite_path = sprite_path,
    debug_info = debug_info
  })

  local is_valid, error_msg = GuiValidation.validate_sprite(sprite_path)
  if not is_valid then
    debug_info.reason = (debug_info.reason or "") .. (error_msg and (": " .. error_msg) or "")
    sprite_path = fallback
    used_fallback = true

    Logger.debug_log("[GUI_VALIDATION] Sprite validation failed, using fallback", {
      attempted_sprite_path = sprite_path,
      error_msg = error_msg,
      fallback = fallback
    })
  end

  debug_info.log_context = log_context

  return sprite_path, used_fallback, debug_info
end

return GuiValidation
