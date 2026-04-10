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

local Deps = require("deps")
local BasicHelpers, Cache, Enum =
  Deps.BasicHelpers, Deps.Cache, Deps.Enum
local GuiBase = require("gui.gui_base")
local GuiValidation = require("core.utils.gui_validation")
local GuiElementBuilders = require("core.utils.gui_element_builders")
local ChartTagUtils = require("core.utils.chart_tag_utils")
local PlayerFavorites = require("core.favorite.player_favorites")
local ProfilerExport = require("core.utils.profiler_export")


local tag_editor = {}

-- Sets up the tag editor UI, including all controls and their state
-- This function now only sets state, tooltips, and styles. It does NOT create any elements.
local function compute_can_confirm(tag_data)
  return (tag_data.text and tag_data.text ~= "") or GuiValidation.has_valid_icon(tag_data.icon)
end

local function setup_tag_editor_ui(refs, tag_data, player)
  -- Determine ownership and delete permissions
  local tag = tag_data.tag
  local is_owner = false
  local can_delete = false

  if tag then
    -- Use Tag.owner_name as source of truth for ownership
    is_owner = (not tag.owner_name or tag.owner_name == "" or tag.owner_name == player.name)
    -- Can delete if player is owner
    can_delete = is_owner
  else
    -- No existing tag means we're creating a new one - player is the owner
    is_owner = true
    can_delete = false
  end

  -- Admin trumps - admins can always edit and delete
  if ChartTagUtils.is_admin(player) then
    is_owner = true
    can_delete = true
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

  GuiElementBuilders.set_button_state_and_tooltip(refs.confirm_btn, compute_can_confirm(tag_data), { "tf-gui.confirm_tooltip" })

  if refs.cancel_btn then refs.cancel_btn.tooltip = { "tf-gui.cancel_tooltip" } end

  -- Update error message display from stage-C refs (avoids redundant tree search).
  local error_frame = refs.tag_editor_error_row_frame
  local error_label = refs.error_label
  local should_show = tag_data.error_message and BasicHelpers.trim(tostring(tag_data.error_message)) ~= ""
  if error_frame and error_frame.valid then
    error_frame.visible = should_show
    if error_label and error_label.valid then
      if should_show then
        error_label.caption = tag_data.error_message
      end
      error_label.visible = should_show
    end
  else
    -- Fallback for safety (should be rare if stage-C refs are present).
    tag_editor.update_error_message(player, tag_data.error_message)
  end
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

local function build_owner_row(parent)
  local row_frame = GuiBase.create_frame(parent, "tag_editor_owner_row_frame", "horizontal", "tf_owner_row_frame")
  local label = GuiBase.create_label(row_frame, "tag_editor_owner_label", "", "tf_tag_editor_owner_label")
  local delete_button = GuiElementBuilders.create_delete_button(row_frame, "tag_editor_delete_button", false)
  return row_frame, label, delete_button
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
  local sprite_path = GuiValidation.get_validated_sprite_path(tag_data.icon,
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
  local error_row_frame, error_label = GuiElementBuilders.show_or_update_error_row(
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

-- Stage A: structural chrome — titlebar, content frame, owner row, inner frame.
-- Runs on the first on_nth_tick(2) after build(). Returns partial_refs for stage B.
---@param player LuaPlayer
---@param outer LuaGuiElement
---@param tag_data table
local function build_interior_a(player, outer, tag_data)
  ProfilerExport.start_section("tag_editor_build_a")

  -- Set player.opened here (deferred from build()) so the engine modal-stack cost
  -- lands on this on_nth_tick(2) tick rather than on the click event tick.
  player.opened = outer

  local titlebar, _title_label = build_titlebar(outer)

  local content_frame = GuiBase.create_frame(outer, "tag_editor_content_frame", "vertical",
    "tf_tag_editor_content_frame")

  local owner_row, owner_label, delete_button = build_owner_row(content_frame)
  local owner_value = (tag_data.tag and tag_data.tag.owner_name) or ""
  ---@diagnostic disable-next-line: assign-type-mismatch
  owner_label.caption = { "tf-gui.owner_label", owner_value }

  local content_inner_frame = GuiBase.create_frame(content_frame,
    "tag_editor_content_inner_frame", "vertical", "tf_tag_editor_content_inner_frame")

  ProfilerExport.stop_section("tag_editor_build_a")

  return {
    titlebar            = titlebar,
    owner_row           = owner_row,
    delete_btn          = delete_button,
    content_inner_frame = content_inner_frame,
    gps                 = tag_data.gps,
  }
end

-- Stage B: interactive rows — teleport/fave row + rich text row (choose-elem-button + textbox).
-- Runs on the second on_nth_tick(2) after build(). Returns partial_refs for stage C.
---@param player LuaPlayer
---@param outer LuaGuiElement
---@param tag_data table
---@param partial_refs table
local function build_interior_b(player, outer, tag_data, partial_refs)
  ProfilerExport.start_section("tag_editor_build_b")

  local inner = partial_refs.content_inner_frame

  local tele_row, fave_btn, tele_btn = build_teleport_favorite_row(inner, tag_data)

  -- NOTE: The built-in Factorio signal/icon picker always requires the user to confirm their
  -- selection with a checkmark; auto-accepting is a Factorio engine limitation.
  local rich_row, icon_btn, text_input = build_rich_text_row(inner, tag_data)

  ProfilerExport.stop_section("tag_editor_build_b")

  return {
    titlebar              = partial_refs.titlebar,
    owner_row             = partial_refs.owner_row,
    delete_btn            = partial_refs.delete_btn,
    teleport_favorite_row = tele_row,
    teleport_btn          = tele_btn,
    favorite_btn          = fave_btn,
    rich_text_row         = rich_row,
    icon_btn              = icon_btn,
    rich_text_input       = text_input,
    gps                   = partial_refs.gps,
  }
end

-- Stage C: error row + last row element creation only.
-- Runs on the third on_nth_tick(2) after build(). Returns refs for stage D.
---@param player LuaPlayer
---@param outer LuaGuiElement
---@param tag_data table
---@param partial_refs table
local function build_interior_c(player, outer, tag_data, partial_refs)
  ProfilerExport.start_section("tag_editor_build_c")

  local error_frame, error_label = build_error_row(outer, tag_data)
  local last_row, confirm_btn    = build_last_row(outer)

  ProfilerExport.stop_section("tag_editor_build_c")

  return {
    titlebar                   = partial_refs.titlebar,
    owner_row                  = partial_refs.owner_row,
    delete_btn                 = partial_refs.delete_btn,
    teleport_favorite_row      = partial_refs.teleport_favorite_row,
    teleport_btn               = partial_refs.teleport_btn,
    favorite_btn               = partial_refs.favorite_btn,
    rich_text_row              = partial_refs.rich_text_row,
    icon_btn                   = partial_refs.icon_btn,
    rich_text_input            = partial_refs.rich_text_input,
    error_label                = error_label,
    confirm_btn                = confirm_btn,
    tag_editor_error_row_frame = error_frame,
    tag_editor_last_row        = last_row,
    gps                        = partial_refs.gps,
  }
end

-- Stage D: state wiring only via setup_tag_editor_ui. No element creation.
-- Runs on the fourth on_nth_tick(2) after build(). Completes the editor.
---@param player LuaPlayer
---@param outer LuaGuiElement
---@param tag_data table
---@param partial_refs table
local function build_interior_d(player, outer, tag_data, partial_refs)
  ProfilerExport.start_section("tag_editor_build_d")
  setup_tag_editor_ui(partial_refs, tag_data, player)
  ProfilerExport.stop_section("tag_editor_build_d")
end

-- Main builder for the tag editor.
-- Tick 0 (event handler): creates the outer modal frame and sets player.opened immediately
-- so map interaction is blocked. Interior elements are enqueued for the next on_nth_tick(2).
---@param player LuaPlayer
function tag_editor.build(player)
  ProfilerExport.start_section("tag_editor_build_outer")
  if not BasicHelpers.is_valid_player(player) then
    ProfilerExport.stop_section("tag_editor_build_outer")
    return
  end
  local tag_data = Cache.get_player_data(player).tag_editor_data or Cache.create_tag_editor_data()
  if not tag_data.gps or tag_data.gps == "" then
    tag_data.gps = tag_data.move_gps or ""
  end
  -- Do NOT attempt to find or create chart tags here. Only use tag_data.tag and tag_data.chart_tag as provided.

  local parent = player.gui.screen
  local outer = parent[Enum.GuiEnum.GUI_FRAME.TAG_EDITOR]
  if outer and outer.valid then outer.destroy() end

  -- Create outer modal frame immediately. player.opened is deferred to build_interior_a
  -- (on_nth_tick(2)) so the ~8ms engine modal-stack cost lands on a deferred tick, not the click tick.
  local tag_editor_outer_frame = parent.add {
    type      = "frame",
    name      = "tag_editor_frame",
    direction = "vertical",
    style     = "tf_tag_editor_outer_frame",
    modal     = true,
  }
  tag_editor_outer_frame.auto_center = true

  -- Enqueue interior build for the next on_nth_tick(2).
  storage._tf_tag_editor_build_queue = storage._tf_tag_editor_build_queue or {}
  -- Cancel any existing queued build for this player (e.g. rapid re-open).
  for i = #storage._tf_tag_editor_build_queue, 1, -1 do
    if storage._tf_tag_editor_build_queue[i].player_index == player.index then
      table.remove(storage._tf_tag_editor_build_queue, i)
    end
  end
  table.insert(storage._tf_tag_editor_build_queue, {
    player_index = player.index,
    tag_data     = tag_data,
    stage        = "a",
  })
  ProfilerExport.stop_section("tag_editor_build_outer")
end

--- Called from on_nth_tick(2). Drains up to a bounded number of queued stages.
-- Stage "a": builds structural chrome, re-enqueues stage "b" at the front.
-- Stage "b": builds action rows.
-- Stage "c": builds error/last rows.
-- Stage "d": final state wiring.
function tag_editor.process_build_queue()
  if not storage or not storage._tf_tag_editor_build_queue then return end
  if #storage._tf_tag_editor_build_queue == 0 then return end

  local stage_budget = 2
  local processed = 0

  while processed < stage_budget and #storage._tf_tag_editor_build_queue > 0 do
    local entry = table.remove(storage._tf_tag_editor_build_queue, 1)
    local player = game.players[entry.player_index]
    if player and player.valid then
      -- If the outer frame was closed before we got here, discard.
      local outer = player.gui.screen[Enum.GuiEnum.GUI_FRAME.TAG_EDITOR]
      if outer and outer.valid then
        if entry.stage == "a" then
          local partial_refs = build_interior_a(player, outer, entry.tag_data)
          -- Insert stage B at the front so it runs as soon as budget allows.
          table.insert(storage._tf_tag_editor_build_queue, 1, {
            player_index = player.index,
            tag_data     = entry.tag_data,
            stage        = "b",
            partial_refs = partial_refs,
          })
        elseif entry.stage == "b" then
          local partial_refs = build_interior_b(player, outer, entry.tag_data, entry.partial_refs)
          -- Insert stage C at the front so it runs as soon as budget allows.
          table.insert(storage._tf_tag_editor_build_queue, 1, {
            player_index = player.index,
            tag_data     = entry.tag_data,
            stage        = "c",
            partial_refs = partial_refs,
          })
        elseif entry.stage == "c" then
          local partial_refs = build_interior_c(player, outer, entry.tag_data, entry.partial_refs)
          -- Insert stage D at the front so it runs as soon as budget allows.
          table.insert(storage._tf_tag_editor_build_queue, 1, {
            player_index = player.index,
            tag_data     = entry.tag_data,
            stage        = "d",
            partial_refs = partial_refs,
          })
        elseif entry.stage == "d" then
          build_interior_d(player, outer, entry.tag_data, entry.partial_refs)
        end
      end
    end
    processed = processed + 1
  end
end

--- Clear the build queue on save-load (stale GUI refs; must NOT mutate storage).
function tag_editor.on_load_cleanup()
  -- Intentionally blank: storage is not accessible during on_load.
  -- Stale queue entries self-discard in process_build_queue when the frame is gone.
end

-- Helper function to update confirm button state based on current tag data
function tag_editor.update_confirm_button_state(player, tag_data)
  local confirm_btn = GuiValidation.find_child_by_name(player.gui.screen, "tag_editor_confirm_button")
  if not confirm_btn then return end

  GuiValidation.set_button_state(confirm_btn, compute_can_confirm(tag_data))
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
  GuiElementBuilders.show_or_update_error_row(
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
