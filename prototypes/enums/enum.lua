
-- prototypes/enums/enum.lua
-- TeleportFavorites Factorio Mod
-- Centralized enum access point for all system and UI enumerations.
-- ui_enums and core_enums are inlined here to avoid two extra file evaluations on every game load.

---@class UIEnums
local UIEnums = {}

-- ========================================
-- COLOR ENUMERATIONS
-- ========================================

---@class ColorEnum
UIEnums.Colors = {
  DEFAULT_DIRT_COLOR = { r = .06, g = .03, b = .01, a = .39 },
  ORANGE_BUTTON_GLOW_COLOR = { r = .8, g = .56, b = .12, a = .5 },
}

-- ========================================
-- SPRITE ENUMERATIONS
-- ========================================

UIEnums.Sprites = {
  ARROW_RIGHT = "tf_hint_arrow_right",
  ARROW_LEFT = "tf_hint_arrow_left",
  CHECK_MARK = "utility/check_mark",
  CLOSE = "utility/close",
  CONFIRM = "utility/confirm_slot",
  COPY = "utility/copy",
  EDIT = "utility/edit",
  ENTER = "utility/enter",
  MOVE = "move_tag_icon",
  REFRESH = "utility/refresh",
  RESET = "utility/reset",
  TRASH = "utility/trash",
  DANGER = "utility/danger_icon",
  INFO = "utility/info",
  WARNING = "utility/warning_icon",
  EXPORT = "utility/export_slot",
  IMPORT = "utility/import_slot",
  LIST_VIEW = "utility/list_view",
  EYE = "tf_eye",
  EYELASH = "tf_eyelash",
  PIN = "tf_tag_in_map_view_small",
  PLAY = "utility/play",
  SEARCH = "utility/search_icon",
  SETTINGS = "utility/settings",
  SIGNAL_A = "virtual-signal/signal_A",
  TIME_MACHINE = "utility/time-machine",
  SCROLL_HISTORY = "tf_scroll_history",
  STD_HISTORY_MODE = "tf_std_history_mode",
  SEQUENTIAL_HISTORY_MODE = "tf_sequential_history_mode",
  HEART = "virtual-signal/signal-heart",
  STAR = "virtual-signal/signal-star",
  STAR_DISABLED = "tf_star_disabled",
  QUESTION_MARK = "utility/questionmark",
}

-- ========================================
-- GUI ELEMENT ENUMERATIONS
-- ========================================

UIEnums.GUI = { Frame = {}, FaveBar = {}, TagEditor = {}, Shared = {}, TeleportHistory = {} }

UIEnums.GUI.Frame = {
  FAVE_BAR = "fave_bar_frame",
  TAG_EDITOR = "tag_editor_frame",
  TAG_EDITOR_DELETE_CONFIRM = "tf_confirm_dialog_frame",
  TELEPORT_HISTORY_MODAL = "teleport_history_modal"
}

UIEnums.GUI.FaveBar = {
  FAVE_BAR_FLOW = "fave_bar_flow",
  HISTORY_CONTAINER = "fave_bar_history_container",
  TOGGLE_CONTAINER = "fave_bar_toggle_container",
  SLOTS_FLOW = "fave_bar_slots_flow",
  HISTORY_TOGGLE_BUTTON = "fave_bar_history_toggle",
  HISTORY_MODE_TOGGLE_BUTTON = "fave_bar_history_mode_toggle",
  TOGGLE_BUTTON = "fave_bar_visibility_toggle",
  SLOT_BUTTON_PREFIX = "fave_bar_slot_",
}

UIEnums.GUI.TagEditor = {
  OUTER_FRAME = "tag_editor_frame",
  CONTENT_FRAME = "tag_editor_content_frame",
  CONTENT_INNER_FRAME = "tag_editor_content_inner_frame",
  TITLEBAR = "tag_editor_titlebar",
  TITLE_CLOSE_BUTTON = "tag_editor_title_row_close",
  OWNER_ROW_FRAME = "tag_editor_owner_row_frame",
  LABEL_FLOW = "tag_editor_label_flow",
  OWNER_LABEL = "tag_editor_owner_label",
  BUTTON_FLOW = "tag_editor_button_flow",
  MOVE_BUTTON = "tag_editor_move_button",
  DELETE_BUTTON = "tag_editor_delete_button",
  TELEPORT_FAVORITE_ROW = "tag_editor_teleport_favorite_row",
  FAVORITE_BUTTON = "tag_editor_is_favorite_button",
  TELEPORT_BUTTON = "tag_editor_teleport_button",
  RICH_TEXT_ROW = "tag_editor_rich_text_row",
  ICON_BUTTON = "tag_editor_icon_button",
  TEXT_INPUT = "tag_editor_rich_text_input",
  ERROR_ROW_FRAME = "tag_editor_error_row_frame",
  ERROR_MESSAGE = "error_row_error_message",
  LAST_ROW = "tag_editor_last_row",
  LAST_ROW_DRAGGABLE = "tag_editor_last_row_draggable",
  CONFIRM_BUTTON = "tag_editor_confirm_button",
  CONFIRM_DIALOG_FRAME = "tf_confirm_dialog_frame",
  CONFIRM_DIALOG_LABEL = "tag_editor_tf_confirm_dialog_label",
  CONFIRM_DIALOG_BTN_ROW = "tag_editor_tf_confirm_dialog_btn_row",
  CONFIRM_DIALOG_CONFIRM_BTN = "tf_confirm_dialog_confirm_btn",
  CONFIRM_DIALOG_CANCEL_BTN = "tf_confirm_dialog_cancel_btn",
}

UIEnums.GUI.Shared = {
  TELEPORT_BUTTON = "tf_teleport_button",
  TITLEBAR_CLOSE_BUTTON = "titlebar_close_btn",
  TITLEBAR_DRAGGABLE = "tf_titlebar_draggable",
  MAIN_GUI_FLOW = "tf_main_gui_flow",
  TELEPORT_HISTORY_MODAL_TITLEBAR = "teleport_history_modal_titlebar",
  TELEPORT_HISTORY_MODAL_CLOSE_BUTTON = "teleport_history_modal_close_button",
  TELEPORT_HISTORY_SCROLL_PANE = "teleport_history_scroll_pane",
  TELEPORT_HISTORY_LIST = "teleport_history_list",
}

UIEnums.GUI.TeleportHistory = {
  CONFIRM_DIALOG_FRAME = "tf_history_confirm_dialog_frame",
  CONFIRM_DIALOG_CONFIRM_BTN = "tf_history_confirm_dialog_confirm_btn",
  CONFIRM_DIALOG_CANCEL_BTN = "tf_history_confirm_dialog_cancel_btn"
}

UIEnums.ColorEnum = UIEnums.Colors
UIEnums.SpriteEnum = UIEnums.Sprites
UIEnums.GuiEnum = {
  GUI_FRAME = UIEnums.GUI.Frame,
  FAVE_BAR_ELEMENT = UIEnums.GUI.FaveBar,
  TAG_EDITOR_ELEMENT = UIEnums.GUI.TagEditor,
  SHARED_ELEMENT = UIEnums.GUI.Shared
}

-- ========================================
-- CORE ENUMS (from core_enums.lua)
-- ========================================

---@class CoreEnums
local CoreEnums = {}

CoreEnums.Events = {
  TELEPORT_TO_FAVORITE = "teleport_to_favorite-",
}

CoreEnums.ReturnStates = {
  SUCCESS = "success",
  FAILURE = "failure"
}


-- ========================================
-- COMBINED ENUM MODULE
-- ========================================

---@class Enum
local Enum = {}

Enum.UIEnums   = UIEnums
Enum.CoreEnums = CoreEnums

-- Backward compatibility aliases
Enum.SpriteEnum     = UIEnums.Sprites
Enum.ColorEnum      = UIEnums.Colors
Enum.GuiEnum        = UIEnums.GuiEnum
Enum.ReturnStateEnum = CoreEnums.ReturnStates
Enum.EventEnum      = CoreEnums.Events

return Enum
