---@diagnostic disable: undefined-global

-- gui/tag_editor/tag_editor.lua
-- TeleportFavorites Factorio Mod
-- Modal Tag Editor for creating/editing map tags.
--
-- Element Hierarchy:
-- tag_editor_modal (frame, modal)
-- ├─ frame_titlebar (flow, horizontal)
-- │  ├─ draggable_grip (sprite)
-- │  └─ close_button (sprite-button)
-- ├─ tag_icon_picker (sprite-button)
-- ├─ tag_text_field (textfield)
-- ├─ action_buttons_flow (flow, horizontal)
-- │  ├─ move_button (sprite-button)
-- │  ├─ delete_button (sprite-button)
-- │  ├─ teleport_button (sprite-button)
-- │  ├─ favorite_button (sprite-button)
-- │  ├─ confirm_button (button)
-- │  └─ cancel_button (button)
-- └─ error_row (label, visible on error)

local Enum = require("prototypes.enums.enum")
local GuiBase = require("gui.gui_base")
local GuiValidation = require("core.utils.gui_validation")
local GuiElementBuilders = require("core.utils.gui_element_builders")
local ErrorMessageHelpers = require("core.utils.error_message_helpers")
local BasicHelpers = require("core.utils.basic_helpers")
local ValidationUtils = require("core.utils.validation_utils")
local Cache = require("core.cache.cache")
local AdminUtils = require("core.utils.admin_utils")
local PlayerFavorites = require("core.favorite.player_favorites")


local tag_editor = {}

-- Sets up the tag editor UI, including all controls and their state
-- This function now only sets state, tooltips, and styles. It does NOT create any elements.
local function setup_tag_editor_ui(refs, tag_data, player)
  -- Determine ownership and delete permissions
  local tag = tag_data.tag
  local is_owner = false
  local can_delete = false

  if tag and tag.chart_tag then
    is_owner = tag.chart_tag.last_user and tag.chart_tag.last_user.name == player.name or false
    -- Can delete if player is owner (we'll implement multi-player favorite checking later if needed)
    can_delete = is_owner
  else
    is_owner = false
    can_delete = false
  end

  -- Admin trumps
  if AdminUtils.is_admin(player) then
    is_owner = true
  end

  -- Set button enablement using consolidated helper
  GuiElementBuilders.set_button_state_and_tooltip(refs.icon_btn, is_owner, { "tf-gui.icon_tooltip" })
  GuiElementBuilders.set_button_state_and_tooltip(refs.teleport_btn, true, { "tf-gui.teleport_tooltip" })

  -- Favorite button: disable if at max favorites for this surface
  local player_faves = PlayerFavorites.new(player)
  local at_max_faves = player_faves:available_slots() == 0
  if refs.favorite_btn then
    if at_max_faves and not (tag_data and tag_data.is_favorite) then
  GuiElementBuilders.set_button_state_and_tooltip(refs.favorite_btn, false, { "tf-gui.max_favorites_warning" })
    else
  GuiElementBuilders.set_button_state_and_tooltip(refs.favorite_btn, true, { "tf-gui.favorite_tooltip" })
    end
  end
  GuiElementBuilders.set_button_state_and_tooltip(refs.rich_text_input, is_owner, { "tf-gui.text_tooltip" })

  -- Delete button logic
  if refs.delete_btn then
    local is_temp_tag = (not tag_data.chart_tag) or (type(tag_data.chart_tag) == "userdata" and not tag_data.chart_tag.valid)
    GuiElementBuilders.set_button_state_and_tooltip(refs.delete_btn, is_owner and can_delete and not is_temp_tag, { "tf-gui.delete_tooltip" })
  end

  -- Confirm button enabled if text input has content OR icon is selected
  local has_text = tag_data.text and tag_data.text ~= ""
  local has_icon = ValidationUtils.has_valid_icon(tag_data.icon)
  local can_confirm = has_text or has_icon

  GuiElementBuilders.set_button_state_and_tooltip(refs.confirm_btn, can_confirm, { "tf-gui.confirm_tooltip" })

  if refs.cancel_btn then refs.cancel_btn.tooltip = { "tf-gui.cancel_tooltip" } end

  -- Update error message display using centralized helper
  tag_editor.update_error_message(refs.player, tag_data.error_message)
end

-- Confirmation dialog for destructive actions (e.g., tag deletion)
function tag_editor.build_confirmation_dialog(player, opts)
  -- opts: { message }
  -- Present the confirm dialog as a modal overlay, do NOT close the tag editor dialog
  local message = opts and opts.message or { "tf-gui.confirm_delete_message" }
  
  local frame, confirm_btn, cancel_btn = GuiElementBuilders.create_confirmation_dialog(
    player.gui.screen,
    Enum.GuiEnum.GUI_FRAME.TAG_EDITOR_DELETE_CONFIRM,
    message,
    "tf_confirm_dialog_confirm_btn",
    "tf_confirm_dialog_cancel_btn"
  )

  return frame, confirm_btn, cancel_btn
end

-- Modular builder functions for each section of the tag editor
local function build_titlebar(parent)
  local titlebar, title_label, _cb = GuiBase.create_titlebar(parent, "tag_editor_titlebar",
    "tag_editor_title_row_close")
  ---@diagnostic disable-next-line: assign-type-mismatch
  -- Set caption on the label, not the titlebar flow
  title_label.caption = { "tf-gui.tag_editor_title" }
  return titlebar, title_label
end

local function build_owner_row(parent, tag_data)
  -- Create a frame with a fixed height for the owner row
  local row_frame, label_flow, button_flow = GuiElementBuilders.create_label_button_row(
    parent, "tag_editor_owner_row_frame", "tf_owner_row_frame")
  
  local label = GuiBase.create_label(label_flow, "tag_editor_owner_label",
    "", "tf_tag_editor_owner_label")
  local delete_button = GuiElementBuilders.create_delete_button(button_flow, "tag_editor_delete_button", false)

  return row_frame, label, nil, delete_button
end

local function build_teleport_favorite_row(parent, tag_data)
  -- Style must be set at creation time for Factorio GUIs
  local row = GuiBase.create_frame(parent, "tag_editor_teleport_favorite_row", "horizontal",
    "tf_tag_editor_teleport_favorite_row")
  local is_favorite = tag_data and tag_data.is_favorite == true
  local favorite_btn = GuiElementBuilders.create_favorite_button(row, "tag_editor_is_favorite_button", is_favorite, true)
  local teleport_btn = GuiElementBuilders.create_teleport_button(row, "tag_editor_teleport_button", tag_data.gps, true)
  return row, favorite_btn, teleport_btn
end

local function create_icon_button(row, tag_data)
  local sprite_path, used_fallback, debug_info = GuiValidation.get_validated_sprite_path(tag_data.icon,
    { fallback = Enum.SpriteEnum.PIN, log_context = { context = "tag_editor", gps = tag_data.gps } })
  
  local icon_btn = GuiBase.create_element("choose-elem-button", row, {
    name = "tag_editor_icon_button",
    tooltip = { "tf-gui.icon_tooltip" },
    style = "tf_slot_button",
    elem_type = "signal",
    signal = tag_data.icon,
    sprite = sprite_path
  })
  return icon_btn
end

local function create_text_input(row, tag_data)
  return GuiBase.create_textbox(row, "tag_editor_rich_text_input",
    tag_data.text or "", "tf_tag_editor_text_input", true)
end

local function build_rich_text_row(parent, tag_data)
  local row = GuiElementBuilders.create_two_element_row(parent, "tag_editor_rich_text_row")
  local icon_btn = create_icon_button(row, tag_data)
  local text_input = create_text_input(row, tag_data)
  text_input.focus()
  return row, icon_btn, text_input
end

local function build_error_row(parent, tag_data)
  -- Use the centralized error message helper
  local error_row_frame, error_label = ErrorMessageHelpers.show_or_update_error_row(
    parent, "tag_editor_error_row_frame", "error_row_error_message", tag_data and tag_data.error_message)
  return error_row_frame, error_label
end

local function build_last_row(parent)
  local row = GuiBase.create_hflow(parent, "tag_editor_last_row")

  local draggable = GuiBase.create_element("empty-widget", row, {
    name = "tag_editor_last_row_draggable",
    style = "tf_tag_editor_last_row_draggable"
  })

  -- Set drag target for the draggable space
  local drag_target = GuiValidation.get_gui_frame_by_element(parent)
  if drag_target and drag_target.name == Enum.GuiEnum.GUI_FRAME.TAG_EDITOR then
    draggable.drag_target = drag_target
  end

  local confirm_btn = GuiBase.create_element('button', row, {
    name = "tag_editor_confirm_button",
    caption = { "tf-gui.confirm" },
    tooltip = { "tf-gui.confirm_tooltip" },
    style = "tf_dlg_confirm_button",
    sprite = nil
  })
  return row, confirm_btn
end

-- Main builder for the tag editor, matching the full semantic/nested structure from .project/tag_editor.md
---
---@param player LuaPlayer
function tag_editor.build(player)
  if not BasicHelpers.is_valid_player(player) then return end
  local tag_data = Cache.get_player_data(player).tag_editor_data or Cache.create_tag_editor_data()
  if not tag_data.gps or tag_data.gps == "" then
    tag_data.gps = tag_data.move_gps or ""
  end
  -- Do NOT attempt to find or create chart tags here. Only use tag_data.tag and tag_data.chart_tag as provided.

  local gps = tag_data.gps
  local parent = player.gui.screen
  local outer = GuiValidation.find_child_by_name(parent, Enum.GuiEnum.GUI_FRAME.TAG_EDITOR)
  if outer ~= nil then outer.destroy() end

  -- Create modal tag editor frame to block map interactions (idiomatic Factorio)
  local tag_editor_outer_frame = parent.add {
    type = "frame",
    name = "tag_editor_frame", 
    direction = "vertical",
    style = "tf_tag_editor_outer_frame",
    modal = true
  }
  tag_editor_outer_frame.auto_center = true

  local titlebar, title_label = build_titlebar(tag_editor_outer_frame)

  local tag_editor_content_frame = GuiBase.create_frame(tag_editor_outer_frame, "tag_editor_content_frame", "vertical",
    "tf_tag_editor_content_frame")
  local tag_editor_owner_row, owner_label, _, delete_button = build_owner_row(tag_editor_content_frame,
    tag_data) -- Simple owner lookup logic as requested

  local owner_value = ""
  -- First, if there is a tag, use the tag's chart_tag.last_user
  if tag_data.tag and tag_data.tag.chart_tag and tag_data.tag.chart_tag.last_user then
    owner_value = tag_data.tag.chart_tag.last_user.name
    -- If still no last user, check if a chart_tag exists and use chart_tag's last_user
  elseif tag_data.chart_tag and tag_data.chart_tag.last_user then
    owner_value = tag_data.chart_tag.last_user.name
  end
  
  -- Set the owner label using proper localization
  ---@diagnostic disable-next-line: assign-type-mismatch
  owner_label.caption = { "tf-gui.owner_label", owner_value or "" }

  local tag_editor_content_inner_frame = GuiBase.create_frame(tag_editor_content_frame,
    "tag_editor_content_inner_frame", "vertical", "tf_tag_editor_content_inner_frame")

  local tag_editor_teleport_favorite_row, tag_editor_is_favorite_button, tag_editor_teleport_button =
      build_teleport_favorite_row(tag_editor_content_inner_frame, tag_data)

  -- NOTE: The built-in Factorio signal/icon picker (used for icon selection) always requires the user to confirm their selection
  -- with a checkmark button. There is no property or style that allows auto-accepting the selection on click; this is a limitation
  -- of the Factorio engine as of 1.1.x.
  local tag_editor_rich_text_row, tag_editor_icon_button, tag_editor_rich_text_input =
      build_rich_text_row(tag_editor_content_inner_frame, tag_data)

  local tag_editor_error_row_frame, error_row_error_message = build_error_row(tag_editor_outer_frame, tag_data)
  local tag_editor_last_row, tag_editor_confirm_button = build_last_row(tag_editor_outer_frame)

  local refs = {
    titlebar = titlebar,
    owner_row = tag_editor_owner_row,
    delete_btn = delete_button,
    teleport_favorite_row = tag_editor_teleport_favorite_row,
    teleport_btn = tag_editor_teleport_button,
    favorite_btn = tag_editor_is_favorite_button,
    rich_text_row = tag_editor_rich_text_row,
    icon_btn = tag_editor_icon_button,
    rich_text_input = tag_editor_rich_text_input,
    error_label = error_row_error_message,
    confirm_btn = tag_editor_confirm_button,
    tag_editor_error_row_frame = tag_editor_error_row_frame,
    tag_editor_last_row = tag_editor_last_row,
    gps = gps
  }

  setup_tag_editor_ui(refs, tag_data, player)

  player.opened = tag_editor_outer_frame or nil

  return refs
end

-- Helper function to update confirm button state based on current tag data
function tag_editor.update_confirm_button_state(player, tag_data)
  local confirm_btn = GuiValidation.find_child_by_name(player.gui.screen, "tag_editor_confirm_button")
  if not confirm_btn then return end

  -- Check if text input has content or icon is selected
  local has_text = tag_data.text and tag_data.text ~= ""
  local has_icon = ValidationUtils.has_valid_icon(tag_data.icon)
  local can_confirm = has_text or has_icon

  GuiValidation.set_button_state(confirm_btn, can_confirm)
end

-- Partial update functions for specific UI elements without full rebuild

--- Update only the error message display without rebuilding the entire tag editor
---@param player LuaPlayer
---@param message LocalisedString? Error message to display, nil/empty to hide
function tag_editor.update_error_message(player, message)
  if not player or not player.valid then return end
  local outer_frame = GuiValidation.find_child_by_name(player.gui.screen, Enum.GuiEnum.GUI_FRAME.TAG_EDITOR)
  if not outer_frame then return end

  -- Use the centralized error message helper
  ErrorMessageHelpers.show_or_update_error_row(
    outer_frame, "tag_editor_error_row_frame", "error_row_error_message", message)
end

--- Update favorite button state and icon without rebuilding
---@param player LuaPlayer
---@param is_favorite boolean Whether the tag is currently favorited
function tag_editor.update_favorite_state(player, is_favorite)
  local outer_frame = GuiValidation.find_child_by_name(player.gui.screen, Enum.GuiEnum.GUI_FRAME.TAG_EDITOR)
  if not outer_frame then return end

  local favorite_btn = GuiValidation.find_child_by_name(outer_frame, "tag_editor_is_favorite_button")
  if favorite_btn then
    local star_state = is_favorite and Enum.SpriteEnum.STAR or Enum.SpriteEnum.STAR_DISABLED
    local fave_style = is_favorite and "slot_orange_favorite_on" or "slot_orange_favorite_off"
    
    favorite_btn.sprite = star_state
    ---@diagnostic disable-next-line: assign-type-mismatch
    favorite_btn.style = fave_style
  end

  -- Update tag data
  local tag_data = Cache.get_player_data(player).tag_editor_data
  if tag_data then
    tag_data.is_favorite = is_favorite
  end
end

return tag_editor
