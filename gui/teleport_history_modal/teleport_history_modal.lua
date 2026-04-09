---@diagnostic disable: undefined-global

-- gui/teleport_history_modal/teleport_history_modal.lua
-- TeleportFavorites Factorio Mod
-- Modal Teleport History interface for viewing and navigating teleport history.
local Deps = require("deps")
local BasicHelpers, ErrorHandler, Cache, Constants, GPSUtils, Enum =
  Deps.BasicHelpers, Deps.ErrorHandler, Deps.Cache, Deps.Constants, Deps.GpsUtils, Deps.Enum
local GuiBase = require("gui.gui_base")
local GuiValidation = require("core.utils.gui_validation")
local HistoryItem = Cache.HistoryItem
local Lookups = require("core.cache.lookups")
local TeleportHistory = require("core.teleport.teleport_history")
local ChartTagUtils = require("core.utils.chart_tag_utils")
local ProfilerExport = require("core.utils.profiler_export")


local teleport_history_modal = {}
if teleport_history_modal._observer_registered == nil then
  teleport_history_modal._observer_registered = false
end


--- Check if the teleport history modal is open for the player
---@param player LuaPlayer
---@return boolean
function teleport_history_modal.is_open(player)
  if not BasicHelpers.is_valid_player(player) then return false end
  local modal_frame = player.gui.screen[Enum.GuiEnum.GUI_FRAME.TELEPORT_HISTORY_MODAL]
  return modal_frame and modal_frame.valid or false
end

--- Handles GUI close events for teleport history modal
---@param event table GUI close event from Factorio
function teleport_history_modal.on_gui_closed(event)
  local player = game.players[event.player_index]
  if not player or not player.valid then return end
  if not event.element or not event.element.valid then return end

  -- Fallback for gui_closed_reason if not defined
  local gui_closed_reason = { closed = 0, escaped = 1, switch_guis = 2, unknown = 3 }

  local gui_frame = GuiValidation.get_gui_frame_by_element(event.element)
  if (gui_frame and gui_frame.name == Enum.GuiEnum.GUI_FRAME.TELEPORT_HISTORY_MODAL) or event.element.name == Enum.GuiEnum.GUI_FRAME.TELEPORT_HISTORY_MODAL then
    -- Only clear modal state for user-initiated closes (ESC, close button)
    local reason = event.reason or gui_closed_reason.unknown
    if reason == gui_closed_reason.escaped or reason == gui_closed_reason.closed then
      teleport_history_modal.destroy(player, false) -- user-initiated, clear state
    else
      teleport_history_modal.destroy(player, true)  -- view switch, preserve state
    end
    return
  end
end

--- Build the teleport history modal dialog
---@param player LuaPlayer
function teleport_history_modal.build(player)
  ProfilerExport.start_section("thm_build")
  if not teleport_history_modal._observer_registered then
    TeleportHistory.register_observer(function(obs_player)
      if obs_player and obs_player.valid and teleport_history_modal.is_open(obs_player) then
        teleport_history_modal.update_history_list(obs_player)
      end
    end)
    teleport_history_modal._observer_registered = true
  end
  if not BasicHelpers.is_valid_player(player) then
    ProfilerExport.stop_section("thm_build")
    return
  end

  if not BasicHelpers.is_planet_surface(player.surface) then
    ProfilerExport.stop_section("thm_build")
    return
  end

  -- Destroy any existing modal first
  teleport_history_modal.destroy(player, true)

  -- Get persistent position if available
  local pos = Cache.get_history_modal_position(player)
  local modal_width = (pos and type(pos.width) == "number") and pos.width or 350
  local modal_height = (pos and type(pos.height) == "number") and pos.height or 392

  -- Create the main modal frame via GuiBase helper
  local modal_frame = GuiBase.create_frame(
    player.gui.screen,
    Enum.GuiEnum.GUI_FRAME.TELEPORT_HISTORY_MODAL,
    "vertical",
    "tf_teleport_history_modal_frame"
  )
  -- Sizing is defined by style; do not mutate style fields at runtime

  -- Critical error check: Ensure modal was created successfully
  if not modal_frame or not modal_frame.valid then
    ErrorHandler.debug_log("CRITICAL: Modal frame creation failed", {
      modal_frame_nil = modal_frame == nil,
      modal_frame_valid = modal_frame and modal_frame.valid or false,
      player_valid = player and player.valid,
      screen_valid = player.gui and player.gui.screen and player.gui.screen.valid
    })
    ProfilerExport.stop_section("thm_build")
    return
  end

  -- Create custom titlebar with close button
  local titlebar = GuiBase.create_element('flow', modal_frame, {
    name = "teleport_history_modal_titlebar",
    direction = "horizontal",
    style = "tf_titlebar_flow"
  })

  local title_label = GuiBase.create_label(titlebar, "teleport_history_modal_title_label",
    { "tf-gui.teleport_history_modal_title" }, "tf_frame_title")

  -- Draggable space between title and close button
  local draggable = GuiBase.create_draggable(titlebar, "tf_titlebar_draggable")
  if draggable and draggable.valid then
    draggable.drag_target = modal_frame
  end

  -- Close button
  local close_button = GuiBase.create_icon_button(titlebar, "teleport_history_modal_close_button",
    Enum.SpriteEnum.CLOSE, { "tf-gui.close" }, "tf_frame_action_button")
  -- Create content frame (following tag editor pattern)
  local content_frame = GuiBase.create_frame(modal_frame, "teleport_history_modal_content", "vertical",
    "tf_teleport_history_modal_content")

  -- Create scroll pane for history list
  local scroll_pane = GuiBase.create_element("scroll-pane", content_frame, {
    name = "teleport_history_scroll_pane",
    direction = "vertical"
  })
  -- Set style via prototype or use default styles; do not assign directly to style fields

  -- Create list container inside scroll pane
  local history_list = GuiBase.create_frame(
    scroll_pane,
    "teleport_history_list",
    "vertical",
    "inside_shallow_frame"
  )

  -- Populate the history list
  teleport_history_modal.update_history_list(player)

  -- Do not set player.opened for teleport history modal; ESC key should not close it
  player.opened = nil

  -- Initial placement: use storage position if available, else auto-center
  local pos = Cache.get_history_modal_position(player)
  if not pos or type(pos.x) ~= "number" or type(pos.y) ~= "number" then
    -- Set default position in center of screen
    local screen_resolution = player.display_resolution
    local screen_scale = player.display_scale
    local x = (screen_resolution.width / screen_scale - modal_width) / 2
    local y = (screen_resolution.height / screen_scale - modal_height) / 2
    modal_frame.location = { x = x, y = y }
    -- Save the centered position to storage
    Cache.set_history_modal_position(player, { x = x, y = y })
  else
    modal_frame.location = { x = pos.x, y = pos.y }
  end

  ProfilerExport.stop_section("thm_build")
  return modal_frame
end

--- Destroy the teleport history modal
---@param player LuaPlayer|nil
---@param preserve_state boolean|nil If true, do not clear modal dialog state in cache
function teleport_history_modal.destroy(player, preserve_state)
  if not BasicHelpers.is_valid_player(player) then return end
  -- Always clear modal dialog state when closing teleport history modal (should never block input)
  Cache.set_modal_dialog_state(player, nil)

  -- Close the modal if it exists
  local modal_frame = player.gui.screen[Enum.GuiEnum.GUI_FRAME.TELEPORT_HISTORY_MODAL]
  if modal_frame and modal_frame.valid then
    -- Save modal position before destroying (do not attempt to read style.width/height)
    if modal_frame.location and type(modal_frame.location.x) == "number" and type(modal_frame.location.y) == "number" then
      Cache.set_history_modal_position(player, { x = modal_frame.location.x, y = modal_frame.location.y })
    end
    player.opened = nil
    modal_frame.destroy()
  end
end

--- Update the history list display
---@param player LuaPlayer
function teleport_history_modal.update_history_list(player)
  ProfilerExport.start_section("thm_update_list")
  if not BasicHelpers.is_valid_player(player) then
    ProfilerExport.stop_section("thm_update_list")
    return
  end

  local modal_frame = player.gui.screen[Enum.GuiEnum.GUI_FRAME.TELEPORT_HISTORY_MODAL]
  if not modal_frame or not modal_frame.valid then
    ProfilerExport.stop_section("thm_update_list")
    return
  end

  local history_list = GuiValidation.find_child_by_name(modal_frame, "teleport_history_list")
  if not history_list or not history_list.valid then
    ProfilerExport.stop_section("thm_update_list")
    return
  end

  -- Clear existing list items in deterministic order
  -- CRITICAL: Use deterministic iteration, not pairs() - prevents multiplayer desyncs
  local children = history_list.children
  for i = 1, #children do
    if children[i] and children[i].valid then
      children[i].destroy()
    end
  end

  -- Get teleport history for current surface
  local surface_index = player.surface.index
  local hist = Cache.get_player_teleport_history(player, surface_index)
  local stack = hist.stack
  local pointer = hist.pointer

  if #stack == 0 then
    GuiBase.create_label(history_list, "empty_history_label",
      { "tf-gui.teleport_history_empty" }, "tf_teleport_history_empty_label")
    ProfilerExport.stop_section("thm_update_list")
    return
  end

  -- Create list items for each history entry (in reverse order, newest first)
  for i = #stack, 1, -1 do
    local entry = stack[i] -- HistoryItem object
    local is_current = (i == pointer)
    if entry and type(entry) == "table" and entry.gps then
      local coords_string = GPSUtils.coords_string_from_gps(entry.gps)
      local chart_tag = Lookups.get_chart_tag_by_gps(entry.gps)
      local tag_icon = chart_tag and chart_tag.icon

      -- Create horizontal flow for this row

      local row_flow = GuiBase.create_element("flow", history_list, {
        name = "teleport_history_row_" .. tostring(i),
        direction = "horizontal",
        style = "tf_teleport_history_flow"
      })

      -- Add red trash can button to the left
      local trash_button = GuiBase.create_icon_button(row_flow,
        "teleport_history_trash_button_" .. tostring(i),
        Enum.SpriteEnum.TRASH, -- use the same icon as tag editor delete button
        { "tf-gui.delete_tooltip" },
        "tf_teleport_history_trash_button", true)
      if trash_button and trash_button.valid then
        trash_button.tags = { teleport_history_index = i }
      end

      -- Build composite caption: [icon] tag_text   coords  [dim date]
      local button_style = is_current and "tf_teleport_history_item_current" or "tf_teleport_history_item"
      local button_name = "teleport_history_item_" .. tostring(i)
      local chart_tag_text = chart_tag and chart_tag.text or ""
      local truncated_text = BasicHelpers.truncate_rich_text(chart_tag_text, Constants.settings.TELEPORT_HISTORY_LABEL_MAX_DISPLAY)

      local icon_prefix = ""
      if tag_icon and tag_icon.name then
        icon_prefix = ChartTagUtils.format_icon_as_rich_text(tag_icon) .. " "
      end

      local date_string = ""
      local ok, result = pcall(HistoryItem.get_locale_time, player, entry)
      if ok then date_string = result end

      local display_text = icon_prefix .. truncated_text .. "   " .. (coords_string or entry.gps or "Invalid GPS")
        .. "  [font=tf_font_8][color=0.4,0.4,0.4]" .. date_string .. "[/color][/font]"

      local success_button, item_button = pcall(function()
        return GuiBase.create_button(
          row_flow,
          button_name,
          display_text,
          button_style
        )
      end)
      if success_button and item_button and item_button.valid then
        local tooltip_success = pcall(function()
          local coords_str = tostring(coords_string or entry.gps or "")
          item_button.tooltip = { "tf-gui.teleport_history_item_tooltip", coords_str }
        end)
        item_button.tags = { teleport_history_index = i }
      end
    else
      ErrorHandler.debug_log("Invalid HistoryItem in history stack", {
        index = i,
        type = type(entry),
        value = entry
      })
    end
  end
  ProfilerExport.stop_section("thm_update_list")
end

return teleport_history_modal
