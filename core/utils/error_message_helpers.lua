--[[
Error Message Helpers for TeleportFavorites
==========================================
Module: core/utils/error_message_helpers.lua

Consolidates error message display patterns used across GUIs.
Provides centralized error row creation, show/hide, and update functionality.
]]

local GuiBase = require("gui.gui_base")
local GuiValidation = require("core.utils.gui_validation")
local BasicHelpers = require("core.utils.basic_helpers")
local BasicHelpers = require("core.utils.basic_helpers")

local ErrorMessageHelpers = {}

--- Create or update an error row in a GUI frame (unified function)
---@param parent LuaGuiElement Parent GUI element
---@param error_frame_name string Name for the error frame
---@param error_label_name string Name for the error label
---@param message LocalisedString? Error message to display (nil/empty to hide)
---@param error_frame_style string? Style for error frame
---@param error_label_style string? Style for error label
---@return LuaGuiElement? error_frame, LuaGuiElement? error_label
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

--- Hide an error row
function ErrorMessageHelpers.hide_error_row(parent, error_frame_name)
  ErrorMessageHelpers.show_or_update_error_row(parent, error_frame_name, "", nil)
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
  error_label.visible = message and message ~= ""
end

--- Clear simple error label
function ErrorMessageHelpers.clear_simple_error_label(parent, label_name)
  ErrorMessageHelpers.show_simple_error_label(parent, nil, label_name)
end

return ErrorMessageHelpers
