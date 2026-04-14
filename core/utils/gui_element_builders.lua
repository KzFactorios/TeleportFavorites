---@diagnostic disable: undefined-global, assign-type-mismatch, param-type-mismatch, undefined-field

-- core/utils/gui_element_builders.lua
-- TeleportFavorites Factorio Mod
-- Consolidates common GUI element creation patterns for mod GUIs.
-- Provides specialized builders for buttons, dialogs, rows, and flows.

local Deps = require("core.deps_barrel")
local BasicHelpers, GPSUtils, Enum =
  Deps.BasicHelpers, Deps.GpsUtils, Deps.Enum
local GuiBase = require("gui.gui_base")
local GuiValidation = require("core.utils.gui_validation")

local GuiElementBuilders = {}

-- ===========================
-- BUTTON BUILDERS
-- ===========================

--- Create a stateful favorite button with proper icon and style
---@param parent LuaGuiElement Parent element
---@param name string Button name
---@param is_favorite boolean Whether the item is favorited
---@param enabled boolean Whether the button should be enabled
---@return LuaGuiElement button The created button
function GuiElementBuilders.create_favorite_button(parent, name, is_favorite, enabled)
  local tooltip_on ---@type any
  tooltip_on = { "tf-gui.favorite_tooltip" }
  local tooltip_off ---@type any
  tooltip_off = { "tf-gui.max_favorites_warning" }
  local tooltip = enabled and tooltip_on or tooltip_off
  return GuiBase.create_icon_button(parent, name,
    is_favorite and Enum.SpriteEnum.STAR or Enum.SpriteEnum.STAR_DISABLED,
    tooltip,
    is_favorite and "slot_orange_favorite_on" or "slot_orange_favorite_off", enabled)
end

--- Create a teleport button with GPS coordinates in caption
---@param parent LuaGuiElement Parent element  
---@param name string Button name
---@param gps string GPS string for coordinates
---@param enabled boolean Whether the button should be enabled (default: true)
---@return LuaGuiElement button The created button
function GuiElementBuilders.create_teleport_button(parent, name, gps, enabled)
  local coords = GPSUtils.coords_string_from_gps(gps) or ""
  local tt ---@type any
  tt = { "tf-gui.teleport_tooltip" }
  local button = GuiBase.create_icon_button(parent, name, "", tt, "tf_teleport_button", enabled ~= false)
  local cap ---@type any
  cap = { "tf-gui.teleport_to", tostring(coords) }
  button.caption = cap
  return button
end

--- Create a delete button with proper styling
---@param parent LuaGuiElement Parent element
---@param name string Button name  
---@param enabled boolean Whether the button should be enabled
---@return LuaGuiElement button The created button
function GuiElementBuilders.create_delete_button(parent, name, enabled)
  local tt ---@type any
  tt = { "tf-gui.delete_tooltip" }
  return GuiBase.create_icon_button(parent, name, Enum.SpriteEnum.TRASH, tt, "tf_delete_button", enabled)
end

--- Create a visibility toggle button with proper sprite and style
---@param parent LuaGuiElement Parent element
---@param name string Button name
---@param slots_visible boolean Whether slots are currently visible
---@param tooltip LocalisedString|string Tooltip for the button
---@return LuaGuiElement button The created button
function GuiElementBuilders.create_visibility_toggle_button(parent, name, slots_visible, tooltip)
  return GuiBase.create_sprite_button(parent, name, 
    slots_visible and Enum.SpriteEnum.EYELASH or Enum.SpriteEnum.EYE,
    tooltip, slots_visible and "tf_fave_bar_visibility_on" or "tf_fave_bar_visibility_off")
end

-- ===========================
-- DIALOG BUILDERS
-- ===========================

--- Create a confirmation dialog with standard layout
---@param parent LuaGuiElement Parent element (usually player.gui.screen)
---@param name string Dialog frame name
---@param message LocalisedString|string Confirmation message
---@param confirm_button_name string Name for confirm button
---@param cancel_button_name string Name for cancel button
---@return LuaGuiElement frame, LuaGuiElement confirm_btn, LuaGuiElement cancel_btn
function GuiElementBuilders.create_confirmation_dialog(parent, name, message, confirm_button_name, cancel_button_name)
  -- modal=true: overlay must capture input; player.opened should reference this frame (not nil).
  local frame = parent.add({
    type = "frame",
    name = name,
    caption = "",
    direction = "vertical",
    style = "tf_confirm_dialog_frame",
    force_auto_center = true,
    modal = true,
  })
  frame.auto_center = true
  frame.visible = true

  -- Normalize message to a LocalisedString
  if type(message) == "string" then
    message = { message }
  elseif type(message) ~= "table" then
    message = { "tf-gui.confirm_delete_message" }
  end

  GuiBase.create_label(frame, "confirm_dialog_label", message, "tf_dlg_confirm_title")

  -- Button row with left and right alignment
  local btn_row = frame.add({
    type = "flow",
    name = "confirm_dialog_btn_row",
    direction = "horizontal",
    style = "tf_confirm_dialog_btn_row"
  })

  -- Left flow for cancel button
  local left_flow = btn_row.add({
    type = "flow",
    name = "confirm_dialog_left_flow",
    direction = "horizontal"
  })

  -- Right flow for confirm button
  local right_flow = btn_row.add({
    type = "flow",
    name = "confirm_dialog_right_flow",
    direction = "horizontal"
  })

  local cancel_btn = left_flow.add({
    type = "button",
    name = cancel_button_name,
    caption = { "tf-gui.confirm_delete_cancel" },
    style = "back_button"
  })
  cancel_btn.tags = { action = "cancel_delete" }

  local confirm_btn = right_flow.add({
    type = "button",
    name = confirm_button_name,
    caption = { "tf-gui.confirm_delete_confirm" },
    style = "tf_dlg_confirm_button"
  })
  confirm_btn.tags = { action = "confirm_delete" }
  confirm_btn.visible = true

  return frame, confirm_btn, cancel_btn
end

-- ===========================
-- ROW BUILDERS
-- ===========================

--- Create a horizontal row with label and button flows (common tag editor pattern)
---@param parent LuaGuiElement Parent element
---@param name string Row frame name  
---@param style string? Optional style name
---@return LuaGuiElement row_frame, LuaGuiElement label_flow, LuaGuiElement button_flow
function GuiElementBuilders.create_label_button_row(parent, name, style)
  local row_frame = GuiBase.create_frame(parent, name, "horizontal", style)
  local label_flow = GuiBase.create_hflow(row_frame, name .. "_label_flow")
  local button_flow = GuiBase.create_hflow(row_frame, name .. "_button_flow")
  return row_frame, label_flow, button_flow
end

--- Create a two-element horizontal row (common pattern)
---@param parent LuaGuiElement Parent element
---@param name string Row name
---@param style string? Optional frame style
---@return LuaGuiElement row The created row
function GuiElementBuilders.create_two_element_row(parent, name, style)
  if style then
    return GuiBase.create_frame(parent, name, "horizontal", style)
  else
    return GuiBase.create_hflow(parent, name)
  end
end

-- ===========================
-- STATE MANAGEMENT HELPERS
-- ===========================

---@param a LocalisedString|nil
---@param b LocalisedString|nil
---@return boolean
local function localised_string_equal(a, b)
  if a == b then return true end
  local ta, tb = type(a), type(b)
  if ta ~= tb then return false end
  if ta == "string" then return a == b end
  if ta == "table" then
    ---@cast a table
    ---@cast b table
    local len = #a
    if len ~= #b then return false end
    for i = 1, len do
      if a[i] ~= b[i] then return false end
    end
    return true
  end
  return false
end

--- Set button state and tooltip in one call (consolidates repeated pattern)
---@param button LuaGuiElement Button element
---@param enabled boolean Whether button should be enabled
---@param tooltip LocalisedString|string|nil Tooltip to set
function GuiElementBuilders.set_button_state_and_tooltip(button, enabled, tooltip)
  if not BasicHelpers.is_valid_element(button) then return end

  GuiValidation.set_button_state(button, enabled)
  if tooltip then
    ---@cast tooltip LocalisedString|string
    button.tooltip = tooltip
  end
end

--- Like set_button_state_and_tooltip but skips assignments when state and tooltip already match (reduces GUI churn).
---@param button LuaGuiElement Button element
---@param enabled boolean Whether button should be enabled
---@param tooltip LocalisedString|string|nil Tooltip to set
function GuiElementBuilders.set_button_state_and_tooltip_if_changed(button, enabled, tooltip)
  if not BasicHelpers.is_valid_element(button) then return end

  local want_enabled = enabled ~= false
  if button.enabled ~= want_enabled then
    GuiValidation.set_button_state(button, enabled)
  end
  if tooltip then
    ---@cast tooltip LocalisedString|string
    if not localised_string_equal(button.tooltip, tooltip) then
      button.tooltip = tooltip
    end
  end
end

-- ===========================
-- ERROR MESSAGE HELPERS (from error_message_helpers.lua)
-- ===========================

--- Create or update an error row in a GUI frame
---@param parent LuaGuiElement Parent GUI element
---@param error_frame_name string Name for the error frame
function GuiElementBuilders.show_or_update_error_row(parent, error_frame_name, error_label_name, message, error_frame_style, error_label_style)
  if not BasicHelpers.is_valid_element(parent) then return nil, nil end
  local error_frame = GuiValidation.find_child_by_name(parent, error_frame_name)
  local error_label = error_frame and GuiValidation.find_child_by_name(error_frame, error_label_name)
  local should_show = message and BasicHelpers.trim(tostring(message)) ~= ""
  if should_show then
    if not error_frame then
      error_frame = GuiBase.create_frame(parent, error_frame_name, "vertical", error_frame_style or "tf_tag_editor_error_row_frame")
      error_label = GuiBase.create_label(error_frame, error_label_name, message or "", error_label_style or "tf_tag_editor_error_label")
    else
      if error_label then
        ---@cast message LocalisedString
        error_label.caption = message
        error_label.visible = true
      end
    end
    error_frame.visible = true
  else
    if error_frame then error_frame.visible = false end
  end
  return error_frame, error_label
end

--- Show/clear simple error label (compact version for basic use)
function GuiElementBuilders.show_simple_error_label(parent, message, label_name, label_style)
  if not BasicHelpers.is_valid_element(parent) then return end
  label_name = label_name or "tf_error_label"
  local error_label = GuiValidation.find_child_by_name(parent, label_name)
  if not error_label then
    error_label = GuiBase.create_label(parent, label_name, "", label_style or "tf_error_label")
  end
  error_label.caption = type(message) == "string" and {message} or (message or "")
  error_label.visible = (message ~= nil and message ~= "")
end

return GuiElementBuilders
