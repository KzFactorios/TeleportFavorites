--[[
UI Enums - TeleportFavorites
===========================
Consolidated UI-related enumerations including colors, sprites, and GUI elements.

This module consolidates:
- color_enum.lua - Color definitions for styling
- sprite_enum.lua - Valid Factorio sprite paths
- gui_enum.lua - GUI element identifiers

Provides a unified API for all UI-related constants.
]]

---@class UIEnums
local UIEnums = {}

-- ========================================
-- COLOR ENUMERATIONS
-- ========================================

--- @class ColorEnum
UIEnums.Colors = {
  -- Basic colors
  BLACK = { r = 0, g = 0, b = 0, a = 1 },
  BLUE = { r = .5, g = .81, b = .94, a = 1 },
  GREEN = { r = 0, g = 1, b = 0, a = 1 },
  GREY = { r = 0.5, g = 0.5, b = 0.5, a = 1 },
  ORANGE = { r = 0.98, g = 0.66, b = 0.22, a = 1 },
  RED = { r = 1, g = .56, b = .56, a = 1 },
  WHITE = { r = 1, g = 1, b = 1, a = 1 },

  -- UI-specific colors
  CAPTION = { r = 1, g = .9, b = .75, a = 1 },

  -- Effect colors
  DEFAULT_GLOW_COLOR = { r = .88, g = .69, b = .42, a = 1 },
  DEFAULT_SHADOW_COLOR = { r = 0, g = 0, b = 0, a = .35 },
  HARD_SHADOW_COLOR = { r = 0, g = 0, b = 0, a = 1 },
  DEFAULT_DIRT_COLOR = { r = .06, g = .03, b = .01, a = .39 },
  DEFAULT_DIRT_COLOR_FILLER = { r = .06, g = .03, b = .01, a = .22 },

  -- Button glow colors
  GREEN_BUTTON_GLOW_COLOR = { r = .53, g = .85, b = .55, a = .5 },
  ORANGE_BUTTON_GLOW_COLOR = { r = .8, g = .56, b = .12, a = .5 },
  RED_BUTTON_GLOW_COLOR = { r = .99, g = .35, b = .35, a = .5 },
}

-- ========================================
-- SPRITE ENUMERATIONS
-- ========================================

--- Valid vanilla Factorio utility sprite names
--- Reference: https://github.com/wube/factorio-data/blob/master/core/prototypes/utility-sprites.lua
UIEnums.Sprites = {
  -- Navigation arrows
  -- note that the utility/hint_button_xxx is only available in space age
  ARROW_UP = "tf_hint_arrow_up",
  ARROW_RIGHT = "tf_hint_arrow_right",
  ARROW_DOWN = "tf_hint_arrow_down",
  ARROW_LEFT = "tf_hint_arrow_left",

  -- Action icons
  CHECK_MARK = "utility/check_mark",
  CLOSE = "utility/close",
  CONFIRM = "utility/confirm_slot",
  COPY = "utility/copy",
  EDIT = "utility/edit",
  ENTER = "utility/enter",
  MOVE = "move_tag_icon",
  REFRESH = "utility/refresh",
  RESET = "utility/reset", -- core/graphics/icons/mip/reset.png
  TRASH = "utility/trash",

  -- Status icons
  DANGER = "utility/danger_icon",
  INFO = "utility/info",
  WARNING = "utility/warning_icon",

  -- Import/Export
  EXPORT = "utility/export_slot",
  IMPORT = "utility/import_slot",

  -- Interface elements
  LIST_VIEW = "utility/list_view",
  LOCK = "tf_slot_lock",
  EYE = "tf_eye",
  EYELASH = "tf_eyelash",
  PIN = "tf_tag_in_map_view_small",
  PLAY = "utility/play",
  SEARCH = "utility/search_icon",
  SETTINGS = "utility/settings",
  SIGNAL_A = "virtual-signal/signal_A",

  -- Special symbols
  HEART = "virtual-signal/signal-heart",
  STAR = "virtual-signal/signal-star",
  STAR_DISABLED = "tf_star_disabled",
  QUESTION_MARK = "utility/questionmark",
}

-- ========================================
-- GUI ELEMENT ENUMERATIONS
-- ========================================

UIEnums.GUI = {
  Frame = {},
  FaveBar = {},
  TagEditor = {},
  Shared = {}
}

UIEnums.GUI.Frame = {
  DATA_VIEWER = "data_viewer_frame",
  FAVE_BAR = "fave_bar_frame",
  TAG_EDITOR = "tag_editor_frame",
  TAG_EDITOR_DELETE_CONFIRM = "tf_confirm_dialog_frame"
}

--- Favorites bar specific GUI elements
UIEnums.GUI.FaveBar = {
  -- Containers and flows
  FAVE_BAR_FLOW = "fave_bar_flow",
  TOGGLE_CONTAINER = "fave_bar_toggle_container",
  SLOTS_FLOW = "fave_bar_slots_flow",

  -- Buttons
  TOGGLE_BUTTON = "fave_bar_visibility_toggle",
  SLOT_BUTTON_PREFIX = "fave_bar_slot_", -- Append slot number (1-10)
}

--- Tag editor specific GUI elements
UIEnums.GUI.TagEditor = {
  -- Main structure
  OUTER_FRAME = "tag_editor_frame",
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
  CONFIRM_BUTTON = "tag_editor_confirm_button",

  -- Confirmation dialog
  CONFIRM_DIALOG_FRAME = "tf_confirm_dialog_frame",
  CONFIRM_DIALOG_LABEL = "tag_editor_tf_confirm_dialog_label",
  CONFIRM_DIALOG_BTN_ROW = "tag_editor_tf_confirm_dialog_btn_row",
  CONFIRM_DIALOG_CONFIRM_BTN = "tf_confirm_dialog_confirm_btn",
  CONFIRM_DIALOG_CANCEL_BTN = "tf_confirm_dialog_cancel_btn",
}

--- GUI elements shared across multiple contexts
UIEnums.GUI.Shared = {
  -- Generic buttons that might appear in multiple GUIs
  TELEPORT_BUTTON = "tf_teleport_button", -- Style name, not element name

  -- Titlebar elements (used across multiple GUIs)
  TITLEBAR_CLOSE_BUTTON = "titlebar_close_btn",
  TITLEBAR_DRAGGABLE = "tf_titlebar_draggable",

  -- Generic flows and containers
  MAIN_GUI_FLOW = "tf_main_gui_flow",
}

-- ========================================
-- BACKWARD COMPATIBILITY ALIASES
-- ========================================

-- Maintain backward compatibility with old structure
UIEnums.ColorEnum = UIEnums.Colors
UIEnums.SpriteEnum = UIEnums.Sprites
UIEnums.GuiEnum = {
  GUI_FRAME = UIEnums.GUI.Frame,
  FAVE_BAR_ELEMENT = UIEnums.GUI.FaveBar,
  TAG_EDITOR_ELEMENT = UIEnums.GUI.TagEditor,
  SHARED_ELEMENT = UIEnums.GUI.Shared
}

return UIEnums
