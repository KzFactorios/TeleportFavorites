---@diagnostic disable: undefined-global

-- gui/teleport_history_modal/teleport_history_modal.lua
-- TeleportFavorites Factorio Mod
-- Modal Teleport History interface for viewing and navigating teleport history.
--[[
Element Hierarchy:
teleport_history_modal (frame, modal)
├─ modal_titlebar (flow, horizontal)
│  └─ close_button (sprite-button)
├─ history_scroll_pane (scroll-pane, vertical)
│  ├─ history_location_1 (button)
│  ├─ history_location_2 (button)
│  ├─ ...
│  └─ history_location_N (button)
└─ pointer_highlight (label, highlights current pointer)
]]

local GuiBase = require("gui.gui_base")
local GuiValidation = require("core.utils.gui_validation")
local Cache = require("core.cache.cache")
local BasicHelpers = require("core.utils.basic_helpers")
local GPSUtils = require("core.utils.gps_utils")
local Lookups = require("core.cache.lookups")
local ErrorHandler = require("core.utils.error_handler")
local Enum = require("prototypes.enums.enum")
local HistoryItem = require("core.teleport.history_item")
local TeleportHistory = require("core.teleport.teleport_history")
local IconTypeLookup = require("core.utils.icon_type_lookup")


local teleport_history_modal = {}
if teleport_history_modal._observer_registered == nil then
  teleport_history_modal._observer_registered = false
end


--- Destroy the teleport history modal for the given player
---@param player LuaPlayer

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

  local gui_frame = GuiValidation.get_gui_frame_by_element(event.element)
  if (gui_frame and gui_frame.name == Enum.GuiEnum.GUI_FRAME.TELEPORT_HISTORY_MODAL) or event.element.name == Enum.GuiEnum.GUI_FRAME.TELEPORT_HISTORY_MODAL then
    teleport_history_modal.destroy(player)
    return
  end
end

--- Build the teleport history modal dialog
---@param player LuaPlayer
function teleport_history_modal.build(player)
  -- Register observer to auto-refresh modal if not already registered
  if not teleport_history_modal._observer_registered then
    TeleportHistory.register_observer(function(obs_player)
      if obs_player and obs_player.valid and teleport_history_modal.is_open(obs_player) then
        teleport_history_modal.update_history_list(obs_player)
      end
    end)
    teleport_history_modal._observer_registered = true
  end
  ErrorHandler.debug_log("[MODAL] build called", { player = player and player.name or "<nil>" })
  if not BasicHelpers.is_valid_player(player) then return end

  -- Destroy any existing modal first
  teleport_history_modal.destroy(player)

  -- Set modal dialog state in cache
  Cache.set_modal_dialog_state(player, "teleport_history")

  -- Destroy any existing modal first to prevent naming conflicts
  local existing_modal = player.gui.screen[Enum.GuiEnum.GUI_FRAME.TELEPORT_HISTORY_MODAL]
  if existing_modal and existing_modal.valid then
    existing_modal.destroy()
    ErrorHandler.debug_log("Destroyed existing teleport history modal")
  end

  -- Create the main modal frame (following tag editor pattern)
  local modal_frame = player.gui.screen.add {
    type = "frame",
    name = Enum.GuiEnum.GUI_FRAME.TELEPORT_HISTORY_MODAL,
    direction = "vertical",
    style = "tf_teleport_history_modal_frame",
    modal = false
  }

  -- Critical error check: Ensure modal was created successfully
  if not modal_frame or not modal_frame.valid then
    ErrorHandler.debug_log("CRITICAL: Modal frame creation failed", {
      modal_frame_nil = modal_frame == nil,
      modal_frame_valid = modal_frame and modal_frame.valid or false,
      player_valid = player and player.valid,
      screen_valid = player.gui and player.gui.screen and player.gui.screen.valid
    })
    return -- Abort modal creation
  end

  -- Position modal dynamically relative to the history toggle button
  -- This is done after content creation to ensure GUI elements have valid locations
  ErrorHandler.debug_log("Teleport history modal positioning debug", {
    player_name = player.name,
    player_index = player.index
  })

  -- Create titlebar (following tag editor pattern)
  local titlebar, title_label = GuiBase.create_titlebar(modal_frame, "teleport_history_modal_titlebar",
    "teleport_history_modal_close_button")
  if title_label and title_label.valid then
    title_label.caption = { "tf-gui.teleport_history_modal_title" }
  end

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

  -- Set player.opened for ESC key support
  player.opened = modal_frame

  -- Position modal with single calculation: center screen, then offset halfway toward top-left
  local screen_width = player.display_resolution.width / player.display_scale
  local screen_height = player.display_resolution.height / player.display_scale

  -- Modal dimensions (updated to match new style definitions)
  local modal_width = 350  -- Match maximal_width from style
  local modal_height = 200 -- Estimated height for typical content

  -- Calculate center position
  local center_x = (screen_width - modal_width) / 2
  local center_y = (screen_height - modal_height) / 2

  -- Offset halfway toward top-left (25% of the distance from center to top-left corner)
  local final_x = center_x - (center_x * 0.25)
  local final_y = center_y - (center_y * 0.25)

  -- Move modal 10% higher on screen (split the difference)
  final_y = final_y - (screen_height * 0.10)

  modal_frame.location = { x = final_x, y = final_y }

  return modal_frame
end

--- Destroy the teleport history modal
---@param player LuaPlayer
function teleport_history_modal.destroy(player)
  if not BasicHelpers.is_valid_player(player) then return end

  -- Clear modal dialog state
  Cache.set_modal_dialog_state(player, nil)

  -- Close the modal if it exists
  local modal_frame = player.gui.screen[Enum.GuiEnum.GUI_FRAME.TELEPORT_HISTORY_MODAL]
  if modal_frame and modal_frame.valid then
    player.opened = nil
    modal_frame.destroy()
  end
end

--- Update the history list display
---@param player LuaPlayer
function teleport_history_modal.update_history_list(player)
  ErrorHandler.debug_log("[MODAL] update_history_list called", { player = player and player.name or "<nil>" })
  if not BasicHelpers.is_valid_player(player) then return end

  local modal_frame = player.gui.screen[Enum.GuiEnum.GUI_FRAME.TELEPORT_HISTORY_MODAL]
  if not modal_frame or not modal_frame.valid then return end

  local scroll_pane = GuiValidation.find_child_by_name(modal_frame, "teleport_history_scroll_pane")
  if not scroll_pane or not scroll_pane.valid then return end

  local history_list = GuiValidation.find_child_by_name(scroll_pane, "teleport_history_list")
  if not history_list or not history_list.valid then return end

  -- Clear existing list items
  for _, child in pairs(history_list.children) do
    if child and child.valid then
      child.destroy()
    end
  end

  -- Get teleport history for current surface
  local surface_index = player.surface.index
  local hist = Cache.get_player_teleport_history(player, surface_index)
  local stack = hist.stack
  local pointer = hist.pointer

  -- Debug logging
  ErrorHandler.debug_log("Teleport history debug", {
    surface_index = surface_index,
    stack_length = #stack,
    pointer = pointer,
    has_history = hist ~= nil
  })

  if #stack == 0 then
    GuiBase.create_label(history_list, "empty_history_label", "tf-gui.teleport_history_empty",
      "tf_teleport_history_empty_label")
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
      local tag = Cache.get_tag_by_gps(player, entry.gps) or nil
      

      -- Create horizontal flow for this row
      local row_flow = GuiBase.create_element("flow", history_list, {
        name = "teleport_history_row_" .. tostring(i),
        direction = "horizontal",
        style = "tf_teleport_history_flow"
      })


      -- Add GPS button - gps button has children
      local button_style = is_current and "tf_teleport_history_item_current" or "tf_teleport_history_item"
      local button_name = "teleport_history_item_" .. tostring(i)
      local display_text = coords_string or entry.gps or "Invalid GPS"
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
          item_button.tooltip = display_text
        end)
        if not tooltip_success then
          ErrorHandler.debug_log("Failed to set teleport history button tooltip", {
            display_text = display_text,
            item_index = i
          })
        end
        item_button.tags = { teleport_history_index = i }
        ErrorHandler.debug_log("Created teleport history item button", {
          button_name = item_button.name,
          button_tags = item_button.tags,
          item_index = i
        })
      else
        ErrorHandler.debug_log("Failed to create teleport history button", {
          button_style = button_style,
          display_text = display_text,
          item_index = i,
          error = item_button
        })
      end

      
      -- Add date label inline
      GuiBase.create_label(
        item_button,
        "teleport_history_date_label_" .. tostring(i),
        tostring(entry.timestamp),
        "tf_teleport_history_date_label"
      )


      -- Add icon (if any)
      local icon_rich_text = nil
      if tag_icon and tag_icon.name then
        local icon_name = tag_icon.name
        local icon_type = IconTypeLookup.get_icon_type(icon_name) or tag_icon.type or "item"
        icon_rich_text = "[" .. icon_type .. "=" .. icon_name .. "]"
      end
      if icon_rich_text then
        GuiBase.create_label(item_button, "teleport_history_icon_label_" .. tostring(i), icon_rich_text,
          "tf_teleport_history_date_label")
      end


    else
      ErrorHandler.debug_log("Invalid HistoryItem in history stack", {
        index = i,
        type = type(entry),
        value = entry
      })
    end
  end
end

return teleport_history_modal
