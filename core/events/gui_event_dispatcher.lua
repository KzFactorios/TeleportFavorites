---@diagnostic disable: undefined-global

-- gui_event_dispatcher.lua
-- Centralized GUI event dispatcher for TeleportFavorites
-- Wires up all shared GUI event handlers for favorites bar, tag editor, etc.

local control_fave_bar = require("core.control.control_fave_bar")
local control_tag_editor = require("core.control.control_tag_editor")
local Constants = require("constants")
local Helpers = require("core.utils.helpers_suite")
local Enum = require("prototypes.enums.enum")
local control_data_viewer = require("core.control.control_data_viewer")
local Cache = require("core.cache.cache")

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
  local function shared_on_gui_click(event)
    Cache.init()
    if _tf_gui_click_guard then return end
    _tf_gui_click_guard = true

    local ok, err = xpcall(function()
      local element = event.element
      if not element or not element.valid then return end

      -- Global/utility buttons (not tied to a specific GUI)
      -- Ignore clicks on blank/empty favorite slots
      if is_blank_fave_bar_slot_button(element) then return end
      if element.name == "fave_bar_visible_btns_toggle" or is_fave_bar_slot_button(element) then
        control_fave_bar.on_fave_bar_gui_click(event)
        return true
      end

      local parent_gui = Helpers.get_gui_frame_by_element(element)
      if not parent_gui then
        error("Element: " .. element.name .. ", parent GUI not found")
      end      -- Dispatch based on parent_gui
      if parent_gui.name == Enum.GuiEnum.GUI_FRAME.TAG_EDITOR then
        control_tag_editor.on_tag_editor_gui_click(event, script)
        return true
      elseif parent_gui.name == Enum.GuiEnum.GUI_FRAME.FAVE_BAR then
        control_fave_bar.on_fave_bar_gui_click(event)
        return true
      elseif parent_gui.name == Enum.GuiEnum.GUI_FRAME.DATA_VIEWER then
        control_data_viewer.on_data_viewer_gui_click(event)
        return true
      else
        if log then log("[TeleportFavorites] Unknown parent GUI: " .. tostring(parent_gui.name)) end
      end
    end, function(e)
      _tf_gui_click_guard = false
      local err_str = "[TeleportFavorites] GUI event error: " .. tostring(e)
      if log then log(err_str) end
      print(err_str)
      local tb = debug and debug.traceback and debug.traceback() or "<no traceback>"
      if log then log("[TeleportFavorites] Traceback:\n" .. tb) end
      if log then
        local el = event and event.element
        local ename, etype = "<no element>", "<no type>"
        -- Safely check if element is valid before accessing properties
        if el and type(el) == "userdata" then
          pcall(function()
            if el.valid then
              ename = el.name or "<no name>"
              etype = el.type or "<no type>"
            else
              ename = "<invalid element>"
              etype = "<invalid element>"
            end
          end)
        end
        log("[TeleportFavorites] Event element: name=" .. tostring(ename) .. ", type=" .. tostring(etype))
        log("[TeleportFavorites] Event.player_index: " .. tostring(event and event.player_index))
        for k, v in pairs(event or {}) do
          if type(v) ~= "table" and type(v) ~= "userdata" then
            log("[TeleportFavorites] event[" .. tostring(k) .. "] = " .. tostring(v))
          end
        end
      end
    end)
    _tf_gui_click_guard = false
    if not ok then
      error(err)
    end  end
  script.on_event(defines.events.on_gui_click, shared_on_gui_click)
  
  -- Register text change handler for immediate storage saving
  local function shared_on_gui_text_changed(event)
    if not event or not event.element then return end
    control_tag_editor.on_tag_editor_gui_text_changed(event)
  end
  script.on_event(defines.events.on_gui_text_changed, shared_on_gui_text_changed)
  
  -- Register elem changed handler for immediate storage saving (for icon picker)
  local function shared_on_gui_elem_changed(event)
    if not event or not event.element then return end
    -- Handle icon picker changes in tag editor
    local element = event.element
    if element.name and element.name:find("tag_editor") then
      control_tag_editor.on_tag_editor_gui_click(event, script)
    end
  end
  script.on_event(defines.events.on_gui_elem_changed, shared_on_gui_elem_changed)
end

return M
