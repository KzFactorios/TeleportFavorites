---@diagnostic disable: undefined-global

--[[
gui_event_dispatcher.lua
TeleportFavorites Factorio Mod
-----------------------------
Centralized GUI event dispatcher for all mod GUI interactions.

Architecture:
-------------
- Single point of registration for GUI events across all mod GUIs
- Routes events to appropriate control modules based on element names and parent GUI detection
- Implements comprehensive error handling with detailed logging and recovery
- Uses global click guard to prevent event recursion issues

Supported Events:
-----------------
- on_gui_click: Dispatches to control_fave_bar, control_tag_editor, control_data_viewer
- on_gui_text_changed: Handles immediate text input storage (tag editor)
- on_gui_elem_changed: Handles icon picker changes (tag editor)
- on_gui_confirmed: Handles modal dialog confirmations

Integration Pattern:
--------------------
Each GUI control module implements standardized event handler signatures:
- control_fave_bar.on_fave_bar_gui_click(event)
- control_tag_editor.on_tag_editor_gui_click(event, script)
- control_data_viewer.on_data_viewer_gui_click(event)

Error Handling:
---------------
- Comprehensive xpcall usage with detailed error logging
- Safe element access with validity checks and pcall wrappers
- Automatic click guard reset on error to prevent deadlocks
- Multi-channel logging (log + print) for different debug scenarios

Usage:
------
-- Register all GUI event handlers (called from control.lua)
gui_event_dispatcher.register_gui_handlers(script)
--]]

-- gui_event_dispatcher.lua
-- Centralized GUI event dispatcher for TeleportFavorites
-- Wires up all shared GUI event handlers for favorites bar, tag editor, etc.

local control_fave_bar = require("core.control.control_fave_bar")
local control_tag_editor = require("core.control.control_tag_editor")
local DebugCommands = require("core.commands.debug_commands")
local Constants = require("constants")
local Enum = require("prototypes.enums.enum")
local ErrorHandler = require("core.utils.error_handler")
local control_data_viewer = require("core.control.control_data_viewer")
local Cache = require("core.cache.cache")
local GuiUtils = require("core.utils.gui_utils")
local GameHelpers = require("core.utils.game_helpers")
local CursorUtils = require("core.utils.cursor_utils")
local FavoriteUtils = require("core.favorite.favorite")

local M = {}

---@type boolean Global guard to prevent GUI event recursion
local _tf_gui_click_guard = false

--- Returns true if the element is a favorite bar slot button
local function is_fave_bar_slot_button(element)
  if not element or not element.name then return false end
  local name = tostring(element.name)
  local prefix = tostring(Constants.settings.FAVE_BAR_SLOT_PREFIX)
  return name:find(prefix, 1, true) ~= nil
end

local function is_blank_fave_bar_slot_button(element, player)
  if not is_fave_bar_slot_button(element) then return false end
  if not player or not player.valid then return false end
  local slot = tonumber(element.name:match("fave_bar_slot_(%d+)"))
  if not slot then return false end
  local favorites = Cache.get_player_favorites(player)
  local fav = favorites and favorites[slot]
  return FavoriteUtils.is_blank_favorite(fav)
end

--- Register shared GUI event handler for all GUIs
---@param script table The Factorio script object
function M.register_gui_handlers(script)
  -- Validate script object
  if not script or type(script.on_event) ~= "function" then
    error("[TeleportFavorites] Invalid script object provided to register_gui_handlers")
  end

  local function shared_on_gui_click(event)    Cache.init()    -- Ignore shift+right-click everywhere (Factorio native move-tag behavior)
    if event.button == defines.mouse_button_type.right and event.shift then return end
    -- Ignore shift+left-click everywhere EXCEPT on a fave bar slot button
    if event.button == defines.mouse_button_type.left and event.shift and not is_fave_bar_slot_button(event.element) then return end

    -- Add comprehensive event debugging including button type analysis
    ErrorHandler.debug_log("[DISPATCH RAW_EVENT] Raw event received", {
      event_type = "on_gui_click",
      element_name = event and event.element and event.element.name or "<none>",
      raw_button_value = event and event.button or "<none>",
      define_values = {
        left = defines.mouse_button_type.left,
        right = defines.mouse_button_type.right,
        middle = defines.mouse_button_type.middle
      },
      button_analysis = event and event.button and (
        event.button == defines.mouse_button_type.left and "LEFT_CLICK" or
        event.button == defines.mouse_button_type.right and "RIGHT_CLICK" or
        event.button == defines.mouse_button_type.middle and "MIDDLE_CLICK" or
        "UNKNOWN_BUTTON_" .. tostring(event.button)
      ) or "<none>",
      shift = event and event.shift or false,
      control = event and event.control or false,
      alt = event and event.alt or false,
      player_index = event and event.player_index or "<none>",
      tick = event and event.tick or "<none>",
      element_type = event and event.element and event.element.type or "<none>",
      element_style = event and event.element and event.element.style and event.element.style.name or "<none>"
    })    ErrorHandler.debug_log("[DISPATCH] shared_on_gui_click called",
      { event_type = "on_gui_click", element = event and event.element and event.element.name or "<none>" })

    if _tf_gui_click_guard then return end

    _tf_gui_click_guard = true
    
    local ok, result = xpcall(function()      
    local player = game.get_player(event.player_index)
      if not player or not player.valid then return end
      
      -- Check for right-click during drag operation
      if event.button == defines.mouse_button_type.right then
        local is_dragging = false
        local player_data = Cache.get_player_data(player)
        -- Ensure drag_favorite is properly initialized
        if not player_data.drag_favorite then
          player_data.drag_favorite = {active = false, source_slot = nil, favorite = nil}
        end
        if player_data.drag_favorite.active then
          is_dragging = true
          ErrorHandler.debug_log("[DISPATCH] Right-click detected during drag operation, cancelling drag", { 
            player = player.name, 
            source_slot = player_data.drag_favorite.source_slot,
            raw_button = event.button
          })
          CursorUtils.end_drag_favorite(player)
          GameHelpers.player_print(player, {"tf-gui.fave_bar_drag_canceled"})
          
          -- Set a flag to prevent tag editor opening on this tick
          if not player_data.suppress_tag_editor then
            player_data.suppress_tag_editor = {}
          end
          player_data.suppress_tag_editor.tick = game.tick
          
          _tf_gui_click_guard = false
          return true -- Return true to indicate event was handled and stop propagation
        end
      end
      
      -- Continue with normal processing
      local element = event.element
      if not element or not element.valid then return end 
        
      -- Global/utility buttons (not tied to a specific GUI)
      -- Check for debug level buttons first
      if element.name and string.match(element.name, "^tf_debug_set_level_") then
        ErrorHandler.debug_log("[DISPATCH] Routing to DebugCommands.on_debug_level_button_click", { element = element.name })
        DebugCommands.on_debug_level_button_click(event)
        return true
      end
      
      -- Ignore clicks on blank/empty favorite slots

      ErrorHandler.debug_log("[DISPATCH] Check for blank fave. end if blank", { element = element.name })
      if is_blank_fave_bar_slot_button(element, player) then
        if CursorUtils.is_dragging_favorite(player) then
          control_fave_bar.on_fave_bar_gui_click(event)
          return true
        end
        return
      end
      
      if element.name == "fave_bar_visible_btns_toggle" or is_fave_bar_slot_button(element) then
        ErrorHandler.debug_log("[DISPATCH] Routing to control_fave_bar.on_fave_bar_gui_click", { element = element.name })
        control_fave_bar.on_fave_bar_gui_click(event)
        return true
      end
      
      local parent_gui = GuiUtils.get_gui_frame_by_element(element)
      ErrorHandler.debug_log("[DISPATCH] parent_gui detected",
        { element = element.name, parent_gui = parent_gui and parent_gui.name or "<nil>" })
      ErrorHandler.debug_log("GUI Event Dispatcher: Frame detection result", {
        element_name = element.name,
        parent_gui_found = parent_gui ~= nil,
        parent_gui_name = parent_gui and parent_gui.name or "nil",
        expected_tag_editor = Enum.GuiEnum.GUI_FRAME.TAG_EDITOR
      })
      if not parent_gui then
        error("Element: " .. element.name .. ", parent GUI not found")
      end -- Dispatch based on parent_gui
      if parent_gui.name == Enum.GuiEnum.GUI_FRAME.TAG_EDITOR or parent_gui.name == Enum.GuiEnum.GUI_FRAME.TAG_EDITOR_DELETE_CONFIRM then
        ErrorHandler.debug_log("[DISPATCH] Routing to control_tag_editor.on_tag_editor_gui_click",
          { element = element.name, parent_gui = parent_gui.name })
        control_tag_editor.on_tag_editor_gui_click(event, script)
        return true
      elseif parent_gui.name == Enum.GuiEnum.GUI_FRAME.DATA_VIEWER then
        ErrorHandler.debug_log("[DISPATCH] Routing to control_data_viewer.on_data_viewer_gui_click",
          { element = element.name, parent_gui = parent_gui.name })
        control_data_viewer.on_data_viewer_gui_click(event)
        return true
      else
        -- Special handling for tag editor elements that might have wrong parent detection
        local element_name = element.name or ""
        if element_name:find("tag_editor") then
          ErrorHandler.debug_log("[DISPATCH] Forcing tag editor handler due to element name",
            {
              element_name = element_name,
              parent_gui_name = parent_gui.name,
              expected_frame = Enum.GuiEnum.GUI_FRAME
                  .TAG_EDITOR
            })
          control_tag_editor.on_tag_editor_gui_click(event, script)
          return true
        end
        ErrorHandler.debug_log("[DISPATCH] Unknown parent GUI", { parent_gui_name = tostring(parent_gui.name) })
      end
    end, function(e)
      _tf_gui_click_guard = false
      ErrorHandler.warn_log("GUI event error", {
        error = tostring(e),
        event_player_index = event and event.player_index
      })
      local tb = debug and debug.traceback and debug.traceback() or "<no traceback>"
      ErrorHandler.debug_log("GUI event error traceback", {
        traceback = tb
      })
      if log then
        local el = event and event.element
        local ename, etype = "<no element>", "<no type>"
        -- Safely check if element is valid before accessing properties
        if el and type(el) == "userdata" then
          pcall(function()
            ---@diagnostic disable-next-line: undefined-field
            if el.valid then
              ---@diagnostic disable-next-line: undefined-field
              ename = el.name or "<no name>"
              ---@diagnostic disable-next-line: undefined-field
              etype = el.type or "<no type>"
            else
              ename = "<invalid element>"
              etype = "<invalid element>"
            end
          end)
        end
        ErrorHandler.debug_log("GUI event debug info", {
          element_name = tostring(ename),
          element_type = tostring(etype),
          player_index = event and event.player_index
        })
        for k, v in pairs(event or {}) do
          if type(v) ~= "table" and type(v) ~= "userdata" then
            ErrorHandler.debug_log("GUI event property", {
              property = tostring(k),
              value = tostring(v)
            })
          end
        end
      end
    end)
    _tf_gui_click_guard = false
    if not ok then
      -- Log the error but don't re-throw it to prevent cascading errors
      ErrorHandler.warn_log("GUI click handler failed", {
        error = tostring(result),
        event_player_index = event and event.player_index
      })
    end
  end
  script.on_event(defines.events.on_gui_click, shared_on_gui_click)

  -- Register text change handler for immediate storage saving
  local function shared_on_gui_text_changed(event)
    if not event or not event.element then return end
    control_tag_editor.on_tag_editor_gui_text_changed(event)
  end
  script.on_event(defines.events.on_gui_text_changed, shared_on_gui_text_changed) -- Register elem changed handler for immediate storage saving (for icon picker)

  local function shared_on_gui_elem_changed(event)
    if not event or not event.element then return end
    -- Handle icon picker changes in tag editor
    local element = event.element
    local parent_gui = GuiUtils.get_gui_frame_by_element(element)
    if parent_gui and parent_gui.name == Enum.GuiEnum.GUI_FRAME.TAG_EDITOR then
      control_tag_editor.on_tag_editor_gui_elem_changed(event)
    end
  end
  script.on_event(defines.events.on_gui_elem_changed, shared_on_gui_elem_changed)

  -- Register GUI confirmed handler for modal dialogs
  local function shared_on_gui_confirmed(event)
    if not event or not event.element then return end
    -- Handle confirmation dialog events in tag editor
    local element = event.element
    local parent_gui = GuiUtils.get_gui_frame_by_element(element)
    if parent_gui and parent_gui.name == Enum.GuiEnum.GUI_FRAME.TAG_EDITOR then
      control_tag_editor.on_tag_editor_gui_click(event, script)
    end
  end
  script.on_event(defines.events.on_gui_confirmed, shared_on_gui_confirmed)
end

return M
