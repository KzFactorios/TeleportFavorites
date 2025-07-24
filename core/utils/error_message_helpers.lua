---@diagnostic disable: undefined-global

-- core/utils/error_message_helpers.lua
-- TeleportFavorites Factorio Mod
-- Centralized error message display helpers for GUIs.
-- Provides multiplayer-safe functions to create, show, hide, and update error rows and labels in GUI frames.
-- Integrates with GuiBase, GuiValidation, and BasicHelpers for robust error display.
--
-- API:
--   ErrorMessageHelpers.show_or_update_error_row(parent, error_frame_name, error_label_name, message, error_frame_style, error_label_style): Create or update an error row in a GUI frame.
--   ErrorMessageHelpers.show_simple_error_label(parent, message, label_name, label_style): Show or clear a simple error label in a GUI frame.

local GuiBase = require("gui.gui_base")
local GuiValidation = require("core.utils.gui_validation")
local BasicHelpers = require("core.utils.basic_helpers")

local ErrorMessageHelpers = {}

--- Create or update an error row in a GUI frame (unified function)
---@param parent LuaGuiElement Parent GUI element
---@param error_frame_name string Name for the error frame
function ErrorMessageHelpers.show_or_update_error_row(parent, error_frame_name, error_label_name, message, error_frame_style, error_label_style)
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
function ErrorMessageHelpers.show_simple_error_label(parent, message, label_name, label_style)
  if not BasicHelpers.is_valid_element(parent) then return end
  label_name = label_name or "tf_error_label"
  local error_label = GuiValidation.find_child_by_name(parent, label_name)
  if not error_label then
    error_label = GuiBase.create_label(parent, label_name, "", label_style or "tf_error_label")
  end
  error_label.caption = type(message) == "string" and {message} or (message or "")
  -- Ensure visible property is always a boolean (nil message means hide)
  error_label.visible = (message ~= nil and message ~= "")
end


return ErrorMessageHelpers
