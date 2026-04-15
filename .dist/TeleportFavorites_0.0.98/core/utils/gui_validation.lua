local Deps = require("core.deps_barrel")
local BasicHelpers, Logger = Deps.BasicHelpers, Deps.ErrorHandler
local Enum = require("prototypes.enums.enum")
local constants = require("core.constants_impl")
local GuiValidation = {}
function GuiValidation.validate_gui_runtime_element(element, type_name)
  if not element then return false, type_name .. " is nil" end
  if not element.valid then return false, type_name .. " is not valid" end
  return true, nil
end
function GuiValidation.validate_gui_element(element)
  return (GuiValidation.validate_gui_runtime_element(element, "GUI element"))
end
function GuiValidation.apply_style_properties(element, style_props)
  if not GuiValidation.validate_gui_element(element) or type(style_props) ~= "table" then
    return false
  end
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
function GuiValidation.safe_destroy_frame(parent, frame_name)
  if not parent or not frame_name then return end
  if parent[frame_name] and parent[frame_name].valid and type(parent[frame_name].destroy) == "function" then
    parent[frame_name].destroy()
  end
end
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
function GuiValidation.get_gui_frame_by_element(element)
  if not BasicHelpers.is_valid_element(element) then return nil end
  local current = element
  local iterations = 0
  local max_iterations = 20
  while current and current.valid and iterations < max_iterations do
    iterations = iterations + 1
    if current.type == "frame" then
      local name = current.name or ""
      if name == Enum.GuiEnum.GUI_FRAME.TAG_EDITOR or
          name == Enum.GuiEnum.GUI_FRAME.TAG_EDITOR_DELETE_CONFIRM or
          name == Enum.GuiEnum.GUI_FRAME.FAVE_BAR or
          name == Enum.GuiEnum.GUI_FRAME.TELEPORT_HISTORY_MODAL or
          name == Enum.UIEnums.GUI.TeleportHistory.CONFIRM_DIALOG_FRAME or
          name == Enum.UIEnums.GUI.TagEditor.CONFIRM_DIALOG_FRAME then
        return current
      end
    end
    if not current.parent then break end
    current = current.parent
  end
  return nil
end
function GuiValidation.find_child_by_name(parent, child_name)
  if not parent or not parent.valid or not child_name then return nil end
  local direct_child = parent[child_name]
  if direct_child and direct_child.valid then
    return direct_child
  end
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
function GuiValidation.validate_sprite(sprite_path)
  if not sprite_path or type(sprite_path) ~= "string" or sprite_path == "" then
    return false, "Sprite path is nil or empty"
  end
  if not sprite_path:match("^[%w_%-/%.]+$") then
    return false, "Sprite path contains invalid characters"
  end
  local valid_prefixes = {
    "item/", "entity/", "technology/", "recipe/",
    "fluid/", "tile/", "signal/", "utility/",
  "virtual-signal/", "equipment/", "achievement/",
    "quality/", "space-location/"
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
function GuiValidation.get_validated_sprite_path(icon, opts)
  opts = opts or {}
  local fallback = opts.fallback or "utility/unknown"
  local allow_blank = opts.allow_blank or false
  local log_context = opts.log_context or {}
  local sprite_path, used_fallback, debug_info
  used_fallback = false
  debug_info = { original_icon = icon, fallback = fallback }
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
  local is_valid, error_msg = GuiValidation.validate_sprite(sprite_path)
  if not is_valid then
    debug_info.reason = (debug_info.reason or "") .. (error_msg and (": " .. error_msg) or "")
    sprite_path = fallback
    used_fallback = true
  end
  debug_info.log_context = log_context
  return sprite_path, used_fallback, debug_info
end
function GuiValidation.has_valid_icon(icon)
  if not icon or icon == "" then return false end
  if type(icon) == "string" then return true end
  if type(icon) == "table" then return (icon.name ~= nil) or (icon.type ~= nil) end
  return false
end
function GuiValidation.validate_text_length(text, max_length, field_name)
  max_length = max_length or (constants.settings.CHART_TAG_TEXT_MAX_LENGTH )
  field_name = field_name or "Text"
  if text == nil then text = "" end
  if type(text) ~= "string" then return false, field_name .. " must be a string" end
  if #text > max_length then
    return false, field_name .. " exceeds maximum length of " .. max_length .. " characters"
  end
  return true, nil
end
return GuiValidation
