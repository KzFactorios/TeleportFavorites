

-- core/utils/gui_element_builders.lua
-- TeleportFavorites Factorio Mod
-- Consolidates common GUI element creation patterns for mod GUIs.
-- Provides specialized builders for buttons, dialogs, rows, and flows.

local GuiBase = require("gui.gui_base")
local GuiValidation = require("core.utils.gui_validation")
local Enum = require("prototypes.enums.enum")
local BasicHelpers = require("core.utils.basic_helpers")
local GPSUtils = require("core.utils.gps_utils")

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
  return GuiBase.create_icon_button(parent, name, 
    is_favorite and Enum.SpriteEnum.STAR or Enum.SpriteEnum.STAR_DISABLED,
    enabled and { "tf-gui.favorite_tooltip" } or { "tf-gui.max_favorites_warning" },
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
  local button = GuiBase.create_icon_button(parent, name, "", { "tf-gui.teleport_tooltip" }, "tf_teleport_button", enabled ~= false)
  button.caption = {"tf-gui.teleport_to", tostring(coords)}
  return button
end

--- Create a delete button with proper styling
---@param parent LuaGuiElement Parent element
---@param name string Button name  
---@param enabled boolean Whether the button should be enabled
---@return LuaGuiElement button The created button
function GuiElementBuilders.create_delete_button(parent, name, enabled)
  return GuiBase.create_icon_button(parent, name, Enum.SpriteEnum.TRASH, 
    { "tf-gui.delete_tooltip" }, "tf_delete_button", enabled)
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
  local frame = parent.add {
    type = "frame",
    name = name,
    caption = "",
    direction = "vertical",
    style = "tf_confirm_dialog_frame",
    force_auto_center = true,
    modal = true
  }
  frame.auto_center = true
  frame.visible = true
  frame.style.minimal_height = 80

  -- Ensure message is a valid LocalisedString
  if type(message) == "string" then
    message = { message }
  elseif type(message) ~= "table" then
    message = { "tf-gui.confirm_delete_message" }
  end
  
  GuiBase.create_label(frame, "confirm_dialog_label", message, "tf_dlg_confirm_title")

  -- Button row with left and right alignment
  local btn_row = frame.add {
    type = "flow",
    name = "confirm_dialog_btn_row",
    direction = "horizontal",
    style = "tf_confirm_dialog_btn_row"
  }
  btn_row.style.horizontally_stretchable = true

  -- Left flow for cancel button
  local left_flow = btn_row.add {
    type = "flow",
    name = "confirm_dialog_left_flow",
    direction = "horizontal"
  }
  left_flow.style.horizontally_stretchable = false

  -- Right flow for confirm button
  local right_flow = btn_row.add {
    type = "flow", 
    name = "confirm_dialog_right_flow",
    direction = "horizontal"
  }
  right_flow.style.horizontally_stretchable = true
  right_flow.style.horizontal_align = "right"

  local cancel_btn = left_flow.add {
    type = "button",
    name = cancel_button_name,
    caption = { "tf-gui.confirm_delete_cancel" },
    style = "back_button"
  }
  cancel_btn.tags = { action = "cancel_delete" }

  local confirm_btn = right_flow.add {
    type = "button",
    name = confirm_button_name,
    caption = { "tf-gui.confirm_delete_confirm" },
    style = "tf_dlg_confirm_button"
  }
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

--- Set button state and tooltip in one call (consolidates repeated pattern)
---@param button LuaGuiElement Button element
---@param enabled boolean Whether button should be enabled
---@param tooltip LocalisedString|string|nil Tooltip to set
function GuiElementBuilders.set_button_state_and_tooltip(button, enabled, tooltip)
  if not BasicHelpers.is_valid_element(button) then return end
  
  GuiValidation.set_button_state(button, enabled)
  if tooltip then
    button.tooltip = tooltip
  end
end

return GuiElementBuilders
