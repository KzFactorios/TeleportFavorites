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

local teleport_history_modal = {}

--- Handles GUI close events for teleport history modal
---@param event table GUI close event from Factorio
function teleport_history_modal.on_gui_closed(event)
  local player = game.players[event.player_index]
  if not player or not player.valid then return end
  if not event.element or not event.element.valid then return end

  local Enum = require("prototypes.enums.enum")
  local gui_frame = require("core.utils.gui_validation").get_gui_frame_by_element(event.element)
  if (gui_frame and gui_frame.name == Enum.GuiEnum.GUI_FRAME.TELEPORT_HISTORY_MODAL) or event.element.name == "teleport_history_modal" then
    teleport_history_modal.destroy(player)
    return
  end
end

--- Build the teleport history modal dialog
---@param player LuaPlayer
function teleport_history_modal.build(player)
  if not BasicHelpers.is_valid_player(player) then return end

  -- Destroy any existing modal first
  teleport_history_modal.destroy(player)

  -- Set modal dialog state in cache
  Cache.set_modal_dialog_state(player, "teleport_history")

  -- Destroy any existing modal first to prevent naming conflicts
  local existing_modal = player.gui.screen["teleport_history_modal"]
  if existing_modal and existing_modal.valid then
    existing_modal.destroy()
    ErrorHandler.debug_log("Destroyed existing teleport history modal")
  end

  -- Create the main modal frame (following tag editor pattern)
  local modal_frame = player.gui.screen.add {
    type = "frame",
    name = "teleport_history_modal",
    direction = "vertical",
    style = "tf_teleport_history_modal_frame",
    modal = true
  }
  
  -- Critical error check: Ensure modal was created successfully
  if not modal_frame or not modal_frame.valid then
    ErrorHandler.debug_log("CRITICAL: Modal frame creation failed", {
      modal_frame_nil = modal_frame == nil,
      modal_frame_valid = modal_frame and modal_frame.valid or false,
      player_valid = player and player.valid,
      screen_valid = player.gui and player.gui.screen and player.gui.screen.valid
    })
    return  -- Abort modal creation
  end
  
  -- Position modal dynamically relative to the history toggle button
  -- This is done after content creation to ensure GUI elements have valid locations
  ErrorHandler.debug_log("Teleport history modal positioning debug", {
    player_name = player.name,
    player_index = player.index
  })

  -- Create titlebar (following tag editor pattern)
  local titlebar, title_label = GuiBase.create_titlebar(modal_frame, "teleport_history_modal_titlebar", "teleport_history_modal_close_button")
  title_label.caption = {"tf-gui.teleport_history_modal_title"}

  -- Create content frame (following tag editor pattern)
  local content_frame = GuiBase.create_frame(modal_frame, "teleport_history_modal_content", "vertical", "tf_teleport_history_modal_content")

  -- Create scroll pane for history list
  local scroll_pane = GuiBase.create_element("scroll-pane", content_frame, {
    name = "teleport_history_scroll_pane",
    direction = "vertical"
  })
  scroll_pane.style.width = 270
  scroll_pane.style.maximal_height = 300
  scroll_pane.style.vertically_stretchable = false

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
  local modal_frame = player.gui.screen["teleport_history_modal"]
  if modal_frame and modal_frame.valid then
    player.opened = nil
    modal_frame.destroy()
  end
end

--- Update the history list display
---@param player LuaPlayer
function teleport_history_modal.update_history_list(player)
  if not BasicHelpers.is_valid_player(player) then return end

  local modal_frame = player.gui.screen["teleport_history_modal"]
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
    -- Show empty message
    GuiBase.create_label(history_list, "empty_history_label", {"tf-gui.teleport_history_empty"}, "tf_teleport_history_empty_label")
    return
  end

  -- Create list items for each history entry (in reverse order, newest first)
  for i = #stack, 1, -1 do
    local gps_string = stack[i]  -- Stack entries are now GPS strings directly
    local is_current = (i == pointer)

    -- Validate GPS string and process only if valid
    if type(gps_string) == "string" then
      -- GPS string is already available, no conversion needed
      local coords_string = GPSUtils.coords_string_from_gps(gps_string)
      
      -- Debug coordinate conversion
      ErrorHandler.debug_log("Processing history entry", {
        index = i,
        gps_string = gps_string,
        coords_string = coords_string,
        is_current = is_current
      })
      
      -- Try to find a chart tag for this GPS location to get the icon
      local chart_tag = Lookups.get_chart_tag_by_gps(gps_string)
      local tag_icon = chart_tag and chart_tag.icon
      
      -- Use the coordinates string for display text, with fallback to the GPS string
      local display_text = coords_string or gps_string or "Invalid GPS"
      
      -- Add rich text icon prefix if chart tag has an icon
      if tag_icon and tag_icon.name then
        local icon_type = tag_icon.type
        local icon_name = tag_icon.name
        
        -- Debug logging for icon processing
        ErrorHandler.debug_log("Processing chart tag icon", {
          index = i,
          original_type = icon_type,
          original_name = icon_name,
          gps = gps_string
        })
        
        -- Normalize icon type for virtual signals and handle missing types
        if icon_type == "virtual" then
          icon_type = "virtual-signal"
        elseif not icon_type or icon_type == "" then
          -- Try to determine type based on icon name patterns
          if icon_name == "substation" or icon_name == "artillery-targeting-remote" then
            icon_type = "item"
          elseif icon_name == "defender-capsule" then
            icon_type = "item"
          elseif icon_name == "plastic-bar" or icon_name == "solar-panel" or icon_name == "flamethrower-ammo" then
            icon_type = "item"
          elseif string.find(icon_name, "%-bar$") or string.find(icon_name, "%-panel$") or string.find(icon_name, "%-ammo$") then
            -- Pattern matching for common item types
            icon_type = "item"
          elseif string.find(icon_name, "^signal%-") then
            -- Explicit virtual signals start with "signal-"
            icon_type = "virtual-signal"
          else
            -- For unknown types, try item first as it's more common
            icon_type = "item"
          end
        end
        
        -- Dynamic rich text formatting - works with any icon type
        -- Format: [type=name] where type and name come directly from the chart tag icon
        local rich_text_icon = "[" .. icon_type .. "=" .. icon_name .. "]"
        
        -- Debug final rich text format
        ErrorHandler.debug_log("Generated rich text icon", {
          index = i,
          final_type = icon_type,
          final_name = icon_name,
          rich_text_format = rich_text_icon
        })
        
        -- Use rich text formatting to embed the icon directly in the button text
        display_text = rich_text_icon .. "  " .. display_text
      end
      
      local button_style = is_current and "tf_teleport_history_item_current" or "tf_teleport_history_item"
      
      -- Create a simple button with rich text (no need for separate flow or sprite elements)
      local success_button, item_button = pcall(function()
        return GuiBase.create_button(
          history_list,
          "teleport_history_item_" .. i,
          display_text,
          button_style
        )
      end)
      
      if success_button and item_button and item_button.valid then
        -- Set tooltip after creation
        local tooltip_success = pcall(function()
          item_button.tooltip = {"tf-gui.teleport_history_item_tooltip", display_text}
        end)
        
        if not tooltip_success then
          ErrorHandler.debug_log("Failed to set teleport history button tooltip", {
            display_text = display_text,
            item_index = i
          })
        end

        -- Store the index in tags for click handling
        item_button.tags = {teleport_history_index = i}
      else
        ErrorHandler.debug_log("Failed to create teleport history button", {
          button_style = button_style,
          display_text = display_text,
          item_index = i,
          error = item_button
        })
      end
    else
      ErrorHandler.debug_log("Invalid GPS string in history stack", {
        index = i,
        type = type(gps_string),
        value = gps_string
      })
    end
  end
end

return teleport_history_modal
