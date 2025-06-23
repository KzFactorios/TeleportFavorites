---@diagnostic disable: undefined-global
--[[
Tag Editor GUI for TeleportFavorites
====================================
Module: gui/tag_editor/tag_editor.lua

Provides the modal Tag Editor interface for creating and editing map tags in the TeleportFavorites mod.

Features:
- Modal dialog for editing tag icon, text, and actions (move, delete, teleport, favorite, confirm, cancel).
- Ownership and favorite state logic for enabling/disabling controls.
- Error message display and move mode visual feedback.
- Modularized UI construction for maintainability and clarity.
- Vanilla dialog structure: uses a 'inside_shallow_frame' for the outer frame, a 'frame_titlebar' for the title bar (with draggable grip), and a close button handled by event logic.
- Sets player.opened for modal/ESC support; titlebar is draggable and visually matches vanilla Factorio dialogs.

Main Functions:
- tag_editor.build
    Constructs and returns the tag editor modal frame for the given player and tag data.
    Handles all UI element creation, state logic, tooltips, error display, and move mode visuals.
    The tag_editor is always presented in the player.gui.screen.

- tag_editor.build_confirmation_dialog
    Shows a modal confirmation dialog for destructive actions (e.g., tag deletion).

- setup_tag_editor_ui(refs, tag_data, player):
    Sets state, tooltips, and styles for all controls after construction.
--]]

local Cache = require("core.cache.cache")
local Enum = require("prototypes.enums.enum")
local GuiBase = require("gui.gui_base")
local GuiUtils = require("core.utils.gui_utils")
local GPSUtils = require("core.utils.gps_utils")
local BasicHelpers = require("core.utils.basic_helpers")
local ValidationUtils = require("core.utils.validation_utils")
local ErrorHandler = require("core.utils.error_handler")
local Cache = require("core.cache.cache")
local AdminUtils = require("core.utils.admin_utils")
local CollectionUtils = require("core.utils.collection_utils")


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

    -- Can delete if player is owner AND no other players have favorited this tag
    can_delete = is_owner
    if can_delete and tag.faved_by_players then
      for _, player_index in ipairs(tag.faved_by_players) do
        if player_index ~= player.index then
          can_delete = false
          break
        end
      end
    end
  else
    -- New tag (no chart_tag yet) - player can't edit and delete yet
    is_owner = false
    can_delete = false
  end

  -- Admin trumps
  if AdminUtils.is_admin(player) then
    is_owner = true
  end

  -- Set button enablement
  if refs.icon_btn then GuiUtils.set_button_state(refs.icon_btn, is_owner) end
  if refs.teleport_btn then GuiUtils.set_button_state(refs.teleport_btn, true) end
  if refs.favorite_btn then GuiUtils.set_button_state(refs.favorite_btn, true) end
  if refs.rich_text_input then GuiUtils.set_button_state(refs.rich_text_input, is_owner) end

  -- Disable move/delete for temp (yet-to-be-created) tags: if tag_data.tag or tag_data.chart_tag are not nil, it's a temp tag
  -- old way: local is_temp_tag = tag_data.chart_tag and CollectionUtils.table_is_empty(tag_data.chart_tag) or false
  local is_temp_tag = (not tag_data.chart_tag) or
      (type(tag_data.chart_tag) == "userdata" and not tag_data.chart_tag.valid)
  if refs.move_btn then
    -- Move button only enabled if player is owner AND in chart mode AND not a temp tag
    local in_chart_mode = (player.render_mode == defines.render_mode.chart)
    local can_move = is_owner and in_chart_mode and not is_temp_tag
    GuiUtils.set_button_state(refs.move_btn, can_move)
  end

  if refs.delete_btn then
    GuiUtils.set_button_state(refs.delete_btn, is_owner and can_delete and not is_temp_tag)
    -- Button event handlers must be registered via script.on_event, not by setting .onclick
    -- The actual delete logic should be handled in the event handler for the delete button name
  end

  -- Confirm button enabled if text input has content OR icon is selected
  local has_text = tag_data.text and tag_data.text ~= ""
  local has_icon = ValidationUtils.has_valid_icon(tag_data.icon)
  local can_confirm = has_text or has_icon

  if refs.confirm_btn then
    GuiUtils.set_button_state(refs.confirm_btn, can_confirm)
  end

  -- Button style/tooltips
  if refs.icon_btn then refs.icon_btn.tooltip = { "tf-gui.icon_tooltip" } end
  if refs.move_btn then refs.move_btn.tooltip = { "tf-gui.move_tooltip" } end
  if refs.delete_btn then refs.delete_btn.tooltip = { "tf-gui.delete_tooltip" } end
  if refs.teleport_btn then refs.teleport_btn.tooltip = { "tf-gui.teleport_tooltip" } end
  if refs.favorite_btn then refs.favorite_btn.tooltip = { "tf-gui.favorite_tooltip" } end
  if refs.confirm_btn then refs.confirm_btn.tooltip = { "tf-gui.confirm_tooltip" } end
  if refs.cancel_btn then refs.cancel_btn.tooltip = { "tf-gui.cancel_tooltip" } end

  -- Move mode visual
  if refs.inner then
    if tag_data.move_mode then
      refs.inner.tooltip = { "tf-gui.move_mode_active" }
    else
      refs.inner.tooltip = nil
    end
  end

  local error_label = refs.error_label
  if error_label then
    error_label.caption = tag_data.error_message or ""
    error_label.visible = (tag_data.error_message ~= nil and tag_data.error_message ~= "") and true or false
  end

  -- In move mode, disable all controls except cancel
  if tag_data.move_mode then
    if refs.icon_btn then GuiUtils.set_button_state(refs.icon_btn, false) end
    if refs.teleport_btn then GuiUtils.set_button_state(refs.teleport_btn, false) end
    if refs.favorite_btn then GuiUtils.set_button_state(refs.favorite_btn, false) end
    if refs.rich_text_input then GuiUtils.set_button_state(refs.rich_text_input, false) end
    if refs.move_btn then GuiUtils.set_button_state(refs.move_btn, false) end
    if refs.delete_btn then GuiUtils.set_button_state(refs.delete_btn, false) end
    if refs.confirm_btn then GuiUtils.set_button_state(refs.confirm_btn, false) end
    -- Optionally, enable a cancel move button if present
  end
end

-- Confirmation dialog for destructive actions (e.g., tag deletion)
function tag_editor.build_confirmation_dialog(player, opts)
  -- opts: { message }
  -- Present the confirm dialog as a modal overlay, do NOT close the tag editor dialog
  local frame = player.gui.screen.add {
    type = "frame",
    name = Enum.GuiEnum.GUI_FRAME.TAG_EDITOR_DELETE_CONFIRM,
    caption = "",
    direction = "vertical",
    style = "tf_confirm_dialog_frame",
    force_auto_center = true, -- idiomatic for modal overlays
    modal = true -- idiomatic: blocks interaction with other GUIs
  }
  frame.auto_center = true
  frame.visible = true
  frame.style.minimal_height = 80

  -- Defensive: ensure message is a valid LocalisedString
  local message = opts and opts.message
  if type(message) == "table" then
    -- Accept as-is
  elseif type(message) == "string" then
    message = { message }
  else
    message = { "tf-gui.confirm_delete_message" }
  end
  GuiBase.create_label(frame, "tag_editor_tf_confirm_dialog_label", message, "tf_dlg_confirm_title")

  -- Button row: idiomatic horizontal flow with left/right flows for true alignment
  local btn_row = frame.add{
    type = "flow",
    name = "tag_editor_tf_confirm_dialog_btn_row",
    direction = "horizontal",
    style = "tf_confirm_dialog_btn_row"
  }
  btn_row.style.horizontally_stretchable = true

  -- Left-aligned flow for Cancel
  local left_flow = btn_row.add{
    type = "flow",
    name = "tag_editor_tf_confirm_dialog_left_flow",
    direction = "horizontal"
  }
  left_flow.style.horizontally_stretchable = false

  -- Right-aligned flow for Confirm
  local right_flow = btn_row.add{
    type = "flow",
    name = "tag_editor_tf_confirm_dialog_right_flow",
    direction = "horizontal"
  }
  right_flow.style.horizontally_stretchable = true
  right_flow.style.horizontal_align = "right"

  local cancel_btn = left_flow.add{
    type = "button",
    name = "tf_confirm_dialog_cancel_btn",
    caption = {"tf-gui.confirm_delete_cancel"},
    style = "back_button"
  }
  cancel_btn.tags = { action = "cancel_delete" }

  local confirm_btn = right_flow.add{
    type = "button",
    name = "tf_confirm_dialog_confirm_btn",
    caption = {"tf-gui.confirm_delete_confirm"},
    style = "tf_dlg_confirm_button"
  }
  confirm_btn.tags = { action = "confirm_delete" }
  confirm_btn.visible = true

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
  -- Create a horizontal flow for the label - this will take up all available space
  local row_frame = GuiBase.create_frame(parent, "tag_editor_owner_row_frame", "horizontal", "tf_owner_row_frame")
  -- Create the label within the flow - it will stretch with its container
  local label_flow = GuiBase.create_hflow(row_frame, "tag_editor_label_flow")
  -- Create a flow for the buttons
  local label = GuiBase.create_label(label_flow, "tag_editor_owner_label",
    "", "tf_tag_editor_owner_label") -- Add buttons to the button flow
  local button_flow = GuiBase.create_hflow(row_frame, "tag_editor_button_flow")
  ---@diagnostic disable-next-line: param-type-mismatch
  local move_button = GuiBase.create_icon_button(button_flow, "tag_editor_move_button", Enum.SpriteEnum.MOVE, { "tf-gui.move_tooltip" }, "tf_move_button")
  ---@diagnostic disable-next-line: param-type-mismatch
  local delete_button = GuiBase.create_icon_button(button_flow, "tag_editor_delete_button", Enum.SpriteEnum.TRASH, { "tf-gui.delete_tooltip" }, "tf_delete_button")

  return row_frame, label, move_button, delete_button
end

local function build_teleport_favorite_row(parent, tag_data)
  -- Style must be set at creation time for Factorio GUIs
  local row = GuiBase.create_frame(parent, "tag_editor_teleport_favorite_row", "horizontal",
    "tf_tag_editor_teleport_favorite_row") -- Simplify the favorite button state logic
  local is_favorite = tag_data and tag_data.is_favorite == true
  local star_state = is_favorite and Enum.SpriteEnum.STAR or Enum.SpriteEnum.STAR_DISABLED
  local fave_style = is_favorite and "slot_orange_favorite_on" or "slot_orange_favorite_off"
  local favorite_btn = GuiBase.create_icon_button(row, "tag_editor_is_favorite_button", star_state, { "tf-gui.favorite_tooltip" }, fave_style)
  local teleport_btn = GuiBase.create_icon_button(row, "tag_editor_teleport_button", "", { "tf-gui.teleport_tooltip" }, "tf_teleport_button")
---@diagnostic disable-next-line: assign-type-mismatch
  teleport_btn.caption = { "tf-gui.teleport_to", GPSUtils.coords_string_from_gps(tag_data.gps) }
  return row, favorite_btn, teleport_btn
end

local function build_rich_text_row(parent, tag_data)
  local row = GuiBase.create_hflow(parent, "tag_editor_rich_text_row")
  -- Centralized icon validation and sprite path building
  local sprite_path, used_fallback, debug_info = GuiUtils.get_validated_sprite_path(tag_data.icon, { fallback = Enum.SpriteEnum.PIN, log_context = { context = "tag_editor", gps = tag_data.gps } })
  local icon_btn = GuiBase.create_element("choose-elem-button", row, {
    name = "tag_editor_icon_button",
    tooltip = { "tf-gui.icon_tooltip" },
    style = "tf_slot_button",
    elem_type = "signal",
    signal = tag_data.icon,
    sprite = sprite_path
  })
  if used_fallback then
    ErrorHandler.debug_log("[TAG_EDITOR] Fallback icon used for tag editor icon button", { sprite_path = sprite_path, debug_info = debug_info })
  end
  -- Create textbox and set value from storage (tag_data)
  local text_input = GuiBase.create_textbox(row, "tag_editor_rich_text_input",
    tag_data.text or "", "tf_tag_editor_text_input", true)
  return row, icon_btn, text_input
end

local function build_error_row(parent, tag_data)
  local error_row_frame, error_label = nil, nil
  if tag_data and tag_data.error_message and BasicHelpers.trim(tag_data.error_message) ~= "" then
    error_row_frame = GuiBase.create_frame(parent, "tag_editor_error_row_frame", "vertical",
      "tf_tag_editor_error_row_frame")
    error_label = GuiBase.create_label(error_row_frame, "error_row_error_message", tag_data.error_message or "",
      "tf_tag_editor_error_label")
  end
  return error_row_frame, error_label
end

local function build_last_row(parent)
  local row = GuiBase.create_hflow(parent, "tag_editor_last_row")

  local draggable = GuiBase.create_element("empty-widget", row, {
    name = "tag_editor_last_row_draggable",
    style = "tf_tag_editor_last_row_draggable"
  })

  -- Set drag target for the draggable space
  local drag_target = GuiUtils.get_gui_frame_by_element(parent)
  if drag_target and drag_target.name == Enum.GuiEnum.GUI_FRAME.TAG_EDITOR then
    draggable.drag_target = drag_target
  end

  local confirm_btn = GuiBase.create_element('button', row, {
    name = "last_row_confirm_button",
    caption = { "tf-gui.confirm" },
    tooltip = { "tf-gui.confirm_tooltip" },
    style = "tf_dlg_confirm_button",
    sprite = nil
  })
  return row, confirm_btn
end

-- Main builder for the tag editor, matching the full semantic/nested structure from notes/tag_editor.md
---
--- @param player LuaPlayer
function tag_editor.build(player)
  if not player or not player.valid then return end
  -- Only use tag_data as provided, do not perform any additional chart tag search or validation
  local tag_data = Cache.get_player_data(player).tag_editor_data or Cache.create_tag_editor_data()
  if not tag_data.gps or tag_data.gps == "" then
    tag_data.gps = tag_data.move_gps or ""
  end
  -- Do NOT attempt to find or create chart tags here. Only use tag_data.tag and tag_data.chart_tag as provided.

  local gps = tag_data.gps
  local parent = player.gui.screen
  local outer = GuiUtils.find_child_by_name(parent, Enum.GuiEnum.GUI_FRAME.TAG_EDITOR)
  if outer ~= nil then outer.destroy() end

  local tag_editor_outer_frame = GuiBase.create_frame(parent, Enum.GuiEnum.GUI_FRAME.TAG_EDITOR, "vertical",
    "tf_tag_editor_outer_frame")
  tag_editor_outer_frame.auto_center = true

  local titlebar, title_label = build_titlebar(tag_editor_outer_frame)

  local tag_editor_content_frame = GuiBase.create_frame(tag_editor_outer_frame, "tag_editor_content_frame", "vertical",
    "tf_tag_editor_content_frame")
  local tag_editor_owner_row, owner_label, move_button, delete_button = build_owner_row(tag_editor_content_frame,
    tag_data) -- Simple owner lookup logic as requested

  local owner_value = ""
  -- First, if there is a tag, use the tag's chart_tag.last_user
  if tag_data.tag and tag_data.tag.chart_tag and tag_data.tag.chart_tag.last_user then
    owner_value = tag_data.tag.chart_tag.last_user.name
    -- If still no last user, check if a chart_tag exists and use chart_tag's last_user
  elseif tag_data.chart_tag and tag_data.chart_tag.last_user then
    owner_value = tag_data.chart_tag.last_user.name
  end
  ---@diagnostic disable-next-line: assign-type-mismatch
  owner_label.caption = { "tf-gui.owner_label", owner_value }

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
  local tag_editor_last_row, last_row_confirm_button = build_last_row(tag_editor_outer_frame)

  local refs = {
    titlebar = titlebar,
    owner_row = tag_editor_owner_row,
    move_btn = move_button,
    delete_btn = delete_button,
    teleport_favorite_row = tag_editor_teleport_favorite_row,
    teleport_btn = tag_editor_teleport_button,
    favorite_btn = tag_editor_is_favorite_button,
    rich_text_row = tag_editor_rich_text_row,
    icon_btn = tag_editor_icon_button,
    rich_text_input = tag_editor_rich_text_input,
    error_label = error_row_error_message,
    confirm_btn = last_row_confirm_button,
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
  local confirm_btn = GuiUtils.find_child_by_name(player.gui.screen, "last_row_confirm_button")
  if not confirm_btn then return end

  -- Check if text input has content or icon is selected
  local has_text = tag_data.text and tag_data.text ~= ""
  local has_icon = ValidationUtils.has_valid_icon(tag_data.icon)
  local can_confirm = has_text or has_icon

  GuiUtils.set_button_state(confirm_btn, can_confirm)
end

return tag_editor
