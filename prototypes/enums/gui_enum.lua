
---@class GuiEnum
---@field GUI_FRAME table<string, string>
---@field FAVE_BAR_ELEMENT table<string, string>
---@field TAG_EDITOR_ELEMENT table<string, string>
---@field SHARED_ELEMENT table<string, string>
local GuiEnum = {
  GUI_FRAME = {},
  FAVE_BAR_ELEMENT = {},
  TAG_EDITOR_ELEMENT = {},
  SHARED_ELEMENT = {}
}

--- @class GUI_FRAME
local GUI_FRAME = {
  DATA_VIEWER = "data_viewer_frame",
  FAVE_BAR = "fave_bar_frame",
  TAG_EDITOR = "tag_editor_frame",
}

--- @class FAVE_BAR_ELEMENT
--- Favorites bar specific GUI elements
local FAVE_BAR_ELEMENT = {
  -- Containers and flows
  FAVE_BAR_FLOW = "fave_bar_flow",
  TOGGLE_CONTAINER = "fave_bar_toggle_container",
  SLOTS_FLOW = "fave_bar_slots_flow",
  
  -- Buttons
  TOGGLE_BUTTON = "fave_bar_visible_btns_toggle",
  SLOT_BUTTON_PREFIX = "fave_bar_slot_", -- Append slot number (1-10)
}

--- @class TAG_EDITOR_ELEMENT
--- Tag editor specific GUI elements
local TAG_EDITOR_ELEMENT = {
  -- Main structure
  OUTER_FRAME = "tag_editor_frame", -- Note: duplicates GUI_FRAME.TAG_EDITOR but needed for consistency
  CONTENT_FRAME = "tag_editor_content_frame",
  CONTENT_INNER_FRAME = "tag_editor_content_inner_frame",
  
  -- Titlebar
  TITLEBAR = "tag_editor_titlebar",
  TITLE_CLOSE_BUTTON = "tag_editor_title_row_close",
  
  -- Owner row
  OWNER_ROW_FRAME = "tag_editor_owner_row_frame",
  LABEL_FLOW = "tag_editor_label_flow",
  OWNER_LABEL = "tag_editor_owner_label",
  BUTTON_FLOW = "tag_editor_button_flow",
  MOVE_BUTTON = "tag_editor_move_button",
  DELETE_BUTTON = "tag_editor_delete_button",
  
  -- Teleport/Favorite row
  TELEPORT_FAVORITE_ROW = "tag_editor_teleport_favorite_row",
  FAVORITE_BUTTON = "tag_editor_is_favorite_button",
  TELEPORT_BUTTON = "tag_editor_teleport_button",
  
  -- Rich text input row
  RICH_TEXT_ROW = "tag_editor_rich_text_row",
  ICON_BUTTON = "tag_editor_icon_button",
  TEXT_INPUT = "tag_editor_rich_text_input",
  
  -- Error handling
  ERROR_ROW_FRAME = "tag_editor_error_row_frame",
  ERROR_MESSAGE = "error_row_error_message",
  
  -- Action row
  LAST_ROW = "tag_editor_last_row",
  LAST_ROW_DRAGGABLE = "tag_editor_last_row_draggable",
  CONFIRM_BUTTON = "last_row_confirm_button",
  
  -- Confirmation dialog
  CONFIRM_DIALOG_FRAME = "tf_confirm_dialog_frame",
  CONFIRM_DIALOG_LABEL = "tag_editor_tf_confirm_dialog_label",
  CONFIRM_DIALOG_BTN_ROW = "tag_editor_tf_confirm_dialog_btn_row",
  CONFIRM_DIALOG_CONFIRM_BTN = "tf_confirm_dialog_confirm_btn",
  CONFIRM_DIALOG_CANCEL_BTN = "tf_confirm_dialog_cancel_btn",
}

--- @class SHARED_ELEMENT
--- GUI elements shared across multiple contexts or generic elements
local SHARED_ELEMENT = {
  -- Generic buttons that might appear in multiple GUIs
  TELEPORT_BUTTON = "tf_teleport_button", -- Style name, not element name
  
  -- Titlebar elements (used across multiple GUIs)
  TITLEBAR_CLOSE_BUTTON = "titlebar_close_btn",
  TITLEBAR_DRAGGABLE = "tf_titlebar_draggable",
  
  -- Generic flows and containers
  MAIN_GUI_FLOW = "tf_main_gui_flow",
}

for k, v in pairs(GUI_FRAME) do
  GuiEnum.GUI_FRAME[k] = v
end

for k, v in pairs(FAVE_BAR_ELEMENT) do
  GuiEnum.FAVE_BAR_ELEMENT[k] = v
end

for k, v in pairs(TAG_EDITOR_ELEMENT) do
  GuiEnum.TAG_EDITOR_ELEMENT[k] = v
end

for k, v in pairs(SHARED_ELEMENT) do
  GuiEnum.SHARED_ELEMENT[k] = v
end

return GuiEnum
