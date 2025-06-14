--[[
gui_helpers.lua
TeleportFavorites Factorio Mod
-----------------------------
GUI-related utilities: button creation, frame management, error handling, tooltips, etc.
Extracted from helpers_suite.lua for better organization and maintainability.
]]

---@diagnostic disable: undefined-global

local Enum = require("prototypes.enums.enum")

---@class GuiHelpers
local GuiHelpers = {}

---
-- Centralized error handling and user feedback
-- @param player LuaPlayer|nil: The player to notify (optional)
-- @param message string|table: The error or info message to show
-- @param level string: 'error', 'info', or 'warn' (default: 'error')
-- @param log_to_console boolean: Whether to log to Factorio console (default: true)
function GuiHelpers.handle_error(player, message, level, log_to_console)
  level = level or 'error'
  log_to_console = log_to_console ~= false
  local msg = (type(message) == 'table' and table.concat(message, ' ')) or tostring(message)
  if player and player.valid and type(player.print) == 'function' then
    if level == 'error' then
      player.print({ '', '[color=red][ERROR] ', msg, '[/color]' }, { r = 1, g = 0.2, b = 0.2 })
    elseif level == 'warn' then
      player.print({ '', '[color=orange][WARN] ', msg, '[/color]' }, { r = 1, g = 0.5, b = 0 })
    else
      player.print({ '', '[color=white][INFO] ', msg, '[/color]' }, { r = 1, g = 1, b = 1 })
    end
  end
  if log_to_console then
    -- Fallback to print() for logging
    local log_msg = '[TeleportFavorites][' .. level:upper() .. '] ' .. msg
    print(log_msg)
  end
end

-- Safe GUI destruction
function GuiHelpers.safe_destroy_frame(parent, frame_name)
  if parent and parent[frame_name] and parent[frame_name].valid and type(parent[frame_name].destroy) == "function" then
    parent[frame_name].destroy()
  end
end

-- Error label/message handling
function GuiHelpers.show_error_label(parent, message)
  if not parent or not message then return end
  local label = parent.error_row_error_message or parent.add {
    type = "label", name = "error_row_error_message", caption = "", style = "bold_label"
  }
  label.caption = message or ""
  label.style.font_color = { r = 1, g = 0.2, b = 0.2 }
  label.visible = (message and message ~= "")
  return label
end

function GuiHelpers.clear_error_label(parent)
  if parent and parent.error_row_error_message then
    parent.error_row_error_message.caption = ""
    parent.error_row_error_message.visible = false
  end
end

-- Button state/style logic
function GuiHelpers.set_button_state(element, enabled, style_overrides)
  if not element or not element.valid then
    _G.print("[TeleportFavorites] set_button_state: element is nil or invalid")
    return
  end  if not (element.type == "button" or element.type == "sprite-button" or element.type == "textfield" or element.type == "text-box" or element.type == "choose-elem-button") then
    _G.print("[TeleportFavorites] set_button_state: Unexpected element type: " ..
    tostring(element.type) .. " (name: " .. tostring(element.name) .. ")")
    return
  end
  element.enabled = enabled ~= false
  if (element.type == "button" or element.type == "sprite-button" or element.type == "choose-elem-button") and style_overrides and type(style_overrides) == "table" then
    for k, v in pairs(style_overrides) do
      element.style[k] = v
    end
  end
end

-- Tooltip construction
function GuiHelpers.build_favorite_tooltip(fav, opts)
  opts = opts or {}
  local gps_str = fav and fav.gps or opts.gps or "?"
  local tag_text = fav and fav.tag and fav.tag.text or opts.text or nil
  if type(tag_text) == "string" and #tag_text > (opts.max_len or 50) then
    tag_text = tag_text:sub(1, opts.max_len or 50) .. "..."
  end
  if fav and fav.locked then
    return { "tf-gui.fave_slot_locked_tooltip", gps_str, tag_text or "" }
  end
  return { "tf-gui.fave_slot_tooltip", gps_str, tag_text or "" }
end

-- Slot button creation and styling
function GuiHelpers.create_slot_button(parent, name, icon, tooltip, opts)
  opts = opts or {}
  local sprite = icon
  -- Robust dynamic icon validation
  if sprite and sprite ~= "" then
    local is_valid = false
    if remote and remote.interfaces and remote.interfaces["__core__"] and remote.interfaces["__core__"].is_valid_sprite_path then
      is_valid = remote.call("__core__", "is_valid_sprite_path", sprite)
    else
      is_valid = true -- fallback for test/mocks
    end
    if not is_valid then
      print("[TeleportFavorites] WARNING: Invalid sprite '" ..
      tostring(sprite) .. "' for button '" .. tostring(name) .. "'. Using fallback icon.")
      sprite = opts.fallback_icon or nil -- fallback to nil (blank) or allow override
    end
  else
    sprite = nil -- treat empty string as no icon
  end
  local btn = parent.add {
    type = "sprite-button",
    name = name,
    sprite = sprite,
    tooltip = tooltip,
    style = opts.style or "tf_slot_button"
  }
  btn.style.width = opts.width or 36
  btn.style.height = opts.height or 36
  btn.style.font = opts.font or "default-small"
  if opts.enabled ~= nil then btn.enabled = opts.enabled end
  if opts.locked then
    local lock_sprite = (Enum.SpriteEnum and Enum.SpriteEnum["LOCK"]) or "utility/lock"
    local lock_icon = btn.add { type = "sprite", sprite = lock_sprite, name = "lock_overlay" }
    lock_icon.style.width, lock_icon.style.height = 16, 16
    lock_icon.style.left_margin, lock_icon.style.top_margin = 0, 0
    lock_icon.ignored_by_interaction = true
  elseif btn.lock_overlay then
    btn.lock_overlay.destroy()
  end
  return btn
end

--- Recursively search for a child element by name in a GUI element tree
local function find_child_by_name(parent_element, target_name)
  if not (parent_element and parent_element.valid and parent_element.children) then return nil end
  for _, child in pairs(parent_element.children) do
    if child.name == target_name then
      return child
    end
    local found = find_child_by_name(child, target_name)
    if found then return found end
  end
  return nil
end

--- Returns the name of the top-level GUI frame for a given LuaGuiElement, or nil if not found.
--- Traverses up the parent chain until it finds the matching element
--- @param element LuaGuiElement
--- @return LuaGuiElement|nil: The top-level GUI frame, or nil if not found
function GuiHelpers.get_gui_frame_by_element(element)
  local current = element
  while current and current.valid do
    if (Enum.is_value_member_enum(current.name, Enum.GuiEnum.GUI_FRAME)) then
      return current
    end
    if not current.parent then break end
    current = current.parent
  end
  return nil
end

GuiHelpers.find_child_by_name = find_child_by_name

return GuiHelpers
