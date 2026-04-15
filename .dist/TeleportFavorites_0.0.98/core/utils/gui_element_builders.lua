local Deps = require("core.deps_barrel")
local BasicHelpers, GPSUtils, Enum =
  Deps.BasicHelpers, Deps.GpsUtils, Deps.Enum
local GuiBase = require("gui.gui_base")
local GuiValidation = require("core.utils.gui_validation")
local GuiElementBuilders = {}
function GuiElementBuilders.create_favorite_button(parent, name, is_favorite, enabled)
  local tooltip_on
  tooltip_on = { "tf-gui.favorite_tooltip" }
  local tooltip_off
  tooltip_off = { "tf-gui.max_favorites_warning" }
  local tooltip = enabled and tooltip_on or tooltip_off
  return GuiBase.create_icon_button(parent, name,
    is_favorite and Enum.SpriteEnum.STAR or Enum.SpriteEnum.STAR_DISABLED,
    tooltip,
    is_favorite and "slot_orange_favorite_on" or "slot_orange_favorite_off", enabled)
end
function GuiElementBuilders.create_teleport_button(parent, name, gps, enabled)
  local coords = GPSUtils.coords_string_from_gps(gps) or ""
  local tt
  tt = { "tf-gui.teleport_tooltip" }
  local button = GuiBase.create_icon_button(parent, name, "", tt, "tf_teleport_button", enabled ~= false)
  local cap
  cap = { "tf-gui.teleport_to", tostring(coords) }
  button.caption = cap
  return button
end
function GuiElementBuilders.create_delete_button(parent, name, enabled)
  local tt
  tt = { "tf-gui.delete_tooltip" }
  return GuiBase.create_icon_button(parent, name, Enum.SpriteEnum.TRASH, tt, "tf_delete_button", enabled)
end
function GuiElementBuilders.create_visibility_toggle_button(parent, name, slots_visible, tooltip)
  return GuiBase.create_sprite_button(parent, name,
    slots_visible and Enum.SpriteEnum.EYELASH or Enum.SpriteEnum.EYE,
    tooltip, slots_visible and "tf_fave_bar_visibility_on" or "tf_fave_bar_visibility_off")
end
function GuiElementBuilders.create_confirmation_dialog(parent, name, message, confirm_button_name, cancel_button_name)
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
  if type(message) == "string" then
    message = { message }
  elseif type(message) ~= "table" then
    message = { "tf-gui.confirm_delete_message" }
  end
  GuiBase.create_label(frame, "confirm_dialog_label", message, "tf_dlg_confirm_title")
  local btn_row = frame.add({
    type = "flow",
    name = "confirm_dialog_btn_row",
    direction = "horizontal",
    style = "tf_confirm_dialog_btn_row"
  })
  local left_flow = btn_row.add({
    type = "flow",
    name = "confirm_dialog_left_flow",
    direction = "horizontal"
  })
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
function GuiElementBuilders.create_label_button_row(parent, name, style)
  local row_frame = GuiBase.create_frame(parent, name, "horizontal", style)
  local label_flow = GuiBase.create_hflow(row_frame, name .. "_label_flow")
  local button_flow = GuiBase.create_hflow(row_frame, name .. "_button_flow")
  return row_frame, label_flow, button_flow
end
function GuiElementBuilders.create_two_element_row(parent, name, style)
  if style then
    return GuiBase.create_frame(parent, name, "horizontal", style)
  else
    return GuiBase.create_hflow(parent, name)
  end
end
local function localised_string_equal(a, b)
  if a == b then return true end
  local ta, tb = type(a), type(b)
  if ta ~= tb then return false end
  if ta == "string" then return a == b end
  if ta == "table" then
    local len = #a
    if len ~= #b then return false end
    for i = 1, len do
      if a[i] ~= b[i] then return false end
    end
    return true
  end
  return false
end
function GuiElementBuilders.set_button_state_and_tooltip(button, enabled, tooltip)
  if not BasicHelpers.is_valid_element(button) then return end
  GuiValidation.set_button_state(button, enabled)
  if tooltip then
    button.tooltip = tooltip
  end
end
function GuiElementBuilders.set_button_state_and_tooltip_if_changed(button, enabled, tooltip)
  if not BasicHelpers.is_valid_element(button) then return end
  local want_enabled = enabled ~= false
  if button.enabled ~= want_enabled then
    GuiValidation.set_button_state(button, enabled)
  end
  if tooltip then
    if not localised_string_equal(button.tooltip, tooltip) then
      button.tooltip = tooltip
    end
  end
end
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
