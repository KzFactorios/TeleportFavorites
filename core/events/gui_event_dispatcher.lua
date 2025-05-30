---@diagnostic disable: undefined-global

-- gui_event_dispatcher.lua
-- Centralized GUI event dispatcher for TeleportFavorites
-- Wires up all shared GUI event handlers for favorites bar, tag editor, etc.

local control_fave_bar = require("core.control.control_fave_bar")
local control_tag_editor = require("core.control.control_tag_editor")
local Constants = require("constants")
local get_or_create_main_flow = require("gui.data_viewer.data_viewer").get_or_create_main_flow
local helpers = require("core.utils.helpers_suite")
local control_data_viewer = require("core.control.control_data_viewer")

local M = {}

local FAVE_BAR_SLOT_PREFIX = Constants.settings.FAVE_BAR_SLOT_PREFIX

--- Returns true if the element is a favorite bar slot button
local function is_fave_bar_slot_button(element)
  return element and element.name and tostring(element.name):find(FAVE_BAR_SLOT_PREFIX, 1, true)
end

--- Returns true if the element is a blank favorite bar slot button (no caption and no sprite)
local function is_blank_fave_bar_slot_button(element)
  if not is_fave_bar_slot_button(element) then return false end
  local has_text = element.caption and tostring(element.caption):match("%S")
  local has_icon = element.sprite and tostring(element.sprite):match("%S")
  return not has_text and not has_icon
end

--- Register shared GUI event handler for all GUIs
-- Call this from control.lua, passing script and defines
function M.register_gui_handlers(script)
  local Cache = require("core.cache.cache")
  local function shared_on_gui_click(event)
    -- Defensive: ensure persistent storage subfields are initialized (Factorio 2.0+)
    Cache.init()
    if _tf_gui_click_guard then return end
    _tf_gui_click_guard = true

    local ok, err = xpcall(function()
      local element = event.element
      if not element or not element.valid then return end
      -- Ignore clicks on blank/empty favorite slots
      if is_blank_fave_bar_slot_button(element) then return end
      if element.name == "fave_bar_visible_btns_toggle" or is_fave_bar_slot_button(element) then
        ---@diagnostic disable-next-line: undefined-global
        control_fave_bar.on_fave_bar_gui_click(event)
      elseif (element.parent and element.parent.name == "tag_editor_frame")
          or element.name == "tf_confirm_dialog_confirm_btn"
          or element.name == "tf_confirm_dialog_cancel_btn"
          or element.name == "tag_editor_icon_btn"
          or element.name == "last_user_row_move_button"
          or element.name == "last_user_row_delete_button"
          or element.name == "tag_editor_teleport_button"
          or element.name == "tag_editor_favorite_btn"
          or element.name == "tag_editor_cancel_btn"
          or element.name == "last_row_cancel_button"
          or element.name == "last_row_confirm_button"
          or element.name == "tag_editor_textfield"
      then
        control_tag_editor.on_tag_editor_gui_click(event, script)
      elseif element.name == "data_viewer_close_btn" then
        -- Data viewer close button logic (robust to parent)
        local player = game.get_player(event.player_index)
        if player then
          -- Try both player.gui.top and player.gui as parent
          for _, parent in ipairs({player.gui.top, player.gui}) do
            local main_flow = helpers.find_child_by_name(parent, "tf_main_gui_flow")
            if main_flow then
              helpers.safe_destroy_frame(main_flow, "data_viewer_frame")
            end
          end
        end
      elseif element.tags and element.tags.tab_key then
        -- Data Viewer tab button clicked
        control_data_viewer.on_data_viewer_tab_click(event)
        return
      end
    end, function(e)
      _tf_gui_click_guard = false
      local err_str = "[TeleportFavorites] GUI event error: " .. tostring(e)
      if log then log(err_str) end
      print(err_str)
      -- Log traceback
      local tb = debug and debug.traceback and debug.traceback() or "<no traceback>"
      if log then log("[TeleportFavorites] Traceback:\n" .. tb) end
      -- Extra debug info
      if log then
        local el = event and event.element
        local ename = el and el.name or "<no element>"
        local etype = el and el.type or "<no type>"
        log("[TeleportFavorites] Event element: name=" .. tostring(ename) .. ", type=" .. tostring(etype))
        log("[TeleportFavorites] Event.player_index: " .. tostring(event and event.player_index))
        -- Log the event table (shallow)
        for k, v in pairs(event or {}) do
          if type(v) ~= "table" and type(v) ~= "userdata" then
            log("[TeleportFavorites] event[" .. tostring(k) .. "] = " .. tostring(v))
          end
        end
      end
      -- Do not return a value from the error handler
    end)
    _tf_gui_click_guard = false
    if not ok then
      -- Always show the real error, do not mask with a generic mes      error(err)
    end
  end
  script.on_event(defines.events.on_gui_click, shared_on_gui_click)
end

return M
