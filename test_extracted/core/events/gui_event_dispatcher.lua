---@diagnostic disable: undefined-global


local control_fave_bar = require("core.control.control_fave_bar")
local control_tag_editor = require("core.control.control_tag_editor")
local DebugCommands = require("core.commands.debug_commands")
local Constants = require("constants")
local Enum = require("prototypes.enums.enum")
local ErrorHandler = require("core.utils.error_handler")
local Cache = require("core.cache.cache")
local GuiValidation = require("core.utils.gui_validation")
local PlayerHelpers = require("core.utils.player_helpers")
local CursorUtils = require("core.utils.cursor_utils")
local FavoriteUtils = require("core.favorite.favorite_utils")
local BasicHelpers = require("core.utils.basic_helpers")

local M = {}

---@type boolean Global guard to prevent GUI event recursion
local _tf_gui_click_guard = false

local function is_fave_bar_slot_button(element)
  return BasicHelpers.is_valid_element(element) and
  tostring(element.name or ""):find(tostring(Constants.settings.FAVE_BAR_SLOT_PREFIX), 1, true) ~= nil
end

local function is_blank_fave_bar_slot_button(element, player)
  if not is_fave_bar_slot_button(element) or not BasicHelpers.is_valid_player(player) then return false end
  local slot = tonumber(element.name:match("fave_bar_slot_(%d+)"))
  if not slot then return false end
  local favorites = Cache.get_player_favorites(player)
  local fav = favorites and favorites[slot]
  return FavoriteUtils.is_blank_favorite(fav)
end

---@param script table The Factorio script object
function M.register_gui_handlers(script)
  if not script or type(script.on_event) ~= "function" then
    error("[TeleportFavorites] Invalid script object provided to register_gui_handlers")
  end

  local function shared_on_gui_click(event)
      ErrorHandler.debug_log("[DISPATCH] shared_on_gui_click TOP", {
        element_name = event and event.element and event.element.name or "<none>",
        player_index = event and event.player_index or "<none>"
      })
    Cache.init()

    if event.button == defines.mouse_button_type.right and event.shift then return end
    if event.button == defines.mouse_button_type.left and event.shift and not is_fave_bar_slot_button(event.element) then return end

    ErrorHandler.debug_log("[DISPATCH] shared_on_gui_click called",
      { event_type = "on_gui_click", element = event and event.element and event.element.name or "<none>" })

    if _tf_gui_click_guard then return end

    _tf_gui_click_guard = true

    local ok, result = xpcall(function()
      local player = game.get_player(event.player_index)
      if not player or not player.valid then return end

      if Cache.is_modal_dialog_active(player) then
        local element = event.element
        if not BasicHelpers.is_valid_element(element) then return end

        local active_modal_type = Cache.get_modal_dialog_type(player)
        local parent_gui = GuiValidation.get_gui_frame_by_element(element)

        local is_allowed_interaction = false

          if active_modal_type == "delete_confirmation" then
        if element.name == Enum.UIEnums.GUI.TagEditor.CONFIRM_DIALOG_CONFIRM_BTN or
          element.name == Enum.UIEnums.GUI.TagEditor.CONFIRM_DIALOG_CANCEL_BTN then
              is_allowed_interaction = true
            else
              is_allowed_interaction = false
            end
          elseif active_modal_type == "tag_editor" then
            if parent_gui and (
              parent_gui.name == Enum.GuiEnum.GUI_FRAME.TAG_EDITOR or
              parent_gui.name == Enum.GuiEnum.GUI_FRAME.TAG_EDITOR_DELETE_CONFIRM
            ) then
              is_allowed_interaction = true
            end

        elseif active_modal_type == "teleport_history" then
          is_allowed_interaction = (parent_gui and parent_gui.name == Enum.GuiEnum.GUI_FRAME.TELEPORT_HISTORY_MODAL)
            or (parent_gui and parent_gui.name == Enum.GuiEnum.GUI_FRAME.FAVE_BAR)
            or (element.name and tostring(element.name):find(tostring(Constants.settings.FAVE_BAR_SLOT_PREFIX), 1, true) ~= nil)
        end

        if not is_allowed_interaction then
          ErrorHandler.debug_log("[DISPATCH] Blocking GUI interaction due to active modal dialog", {
            player = player.name,
            element_name = element.name,
            parent_gui_name = parent_gui and parent_gui.name or "none",
            active_modal_type = active_modal_type,
            ENUM_TAG_EDITOR_DELETE_CONFIRM = Enum.GuiEnum.GUI_FRAME.TAG_EDITOR_DELETE_CONFIRM,
            ENUM_CONFIRM_BTN = Enum.UIEnums.GUI.TagEditor.CONFIRM_DIALOG_CONFIRM_BTN,
            ENUM_CANCEL_BTN = Enum.UIEnums.GUI.TagEditor.CONFIRM_DIALOG_CANCEL_BTN
          })
          return
        end
      end

      if event.button == defines.mouse_button_type.right then
        local player_data = Cache.get_player_data(player)
        if not player_data.drag_favorite then
          player_data.drag_favorite = { active = false, source_slot = nil, favorite = nil }
        end
        if player_data.drag_favorite.active then
          ErrorHandler.debug_log("[DISPATCH] Right-click detected during drag operation, cancelling drag", {
            player = player.name,
            source_slot = player_data.drag_favorite.source_slot,
            raw_button = event.button
          })
          CursorUtils.end_drag_favorite(player)
          PlayerHelpers.safe_player_print(player, { "tf-gui.fave_bar_drag_canceled" })

          if not player_data.suppress_tag_editor then
            player_data.suppress_tag_editor = {}
          end
          player_data.suppress_tag_editor.tick = game.tick

          _tf_gui_click_guard = false
          return true
        end
      end

      local element = event.element
      if not BasicHelpers.is_valid_element(element) then return end

      if element.name and string.match(element.name, "^tf_debug_set_level_") then
        DebugCommands.on_debug_level_button_click(event)
        return true
      end

      if is_blank_fave_bar_slot_button(element, player) then
        if CursorUtils.is_dragging_favorite(player) then
          control_fave_bar.on_fave_bar_gui_click(event)
          return true
        end
        return
      end

      if element.name == "fave_bar_visibility_toggle" or element.name == "fave_bar_history_toggle" or is_fave_bar_slot_button(element) then
        control_fave_bar.on_fave_bar_gui_click(event)
        return true
      end

      local parent_gui = GuiValidation.get_gui_frame_by_element(element)
      if not parent_gui then
        ErrorHandler.debug_log("[DISPATCH] Element parent GUI not found, skipping", {
          element_name = element.name,
          element_type = element.type or "unknown"
        })
        return
      end
      if parent_gui.name == Enum.GuiEnum.GUI_FRAME.TAG_EDITOR or parent_gui.name == Enum.GuiEnum.GUI_FRAME.TAG_EDITOR_DELETE_CONFIRM then
        control_tag_editor.on_tag_editor_gui_click(event)
        return true
      elseif parent_gui.name == Enum.GuiEnum.GUI_FRAME.TELEPORT_HISTORY_MODAL then
        control_fave_bar.on_teleport_history_modal_gui_click(event)
        return true
      else
        local element_name = element.name or ""
        if element_name:find("tag_editor") then
          control_tag_editor.on_tag_editor_gui_click(event)
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

      if log then
        local el = event and event.element
        local ename, etype = "<no element>", "<no type>"
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
      ErrorHandler.warn_log("GUI click handler failed", {
        error = tostring(result),
        event_player_index = event and event.player_index
      })
    end
  end
  script.on_event(defines.events.on_gui_click, shared_on_gui_click)

  local function shared_on_gui_text_changed(event)
    if not event or not event.element then return end

    local player = game.get_player(event.player_index)
    if not player or not player.valid then return end

    local element = event.element
    local parent_gui = GuiValidation.get_gui_frame_by_element(element)
    if parent_gui and parent_gui.name == Enum.GuiEnum.GUI_FRAME.TAG_EDITOR then
      control_tag_editor.on_tag_editor_gui_text_changed(event)
    end
  end
  script.on_event(defines.events.on_gui_text_changed, shared_on_gui_text_changed)

  local function shared_on_gui_elem_changed(event)
    if not event or not event.element then return end

    local player = game.get_player(event.player_index)
    if not player or not player.valid then return end

    local element = event.element
    local parent_gui = GuiValidation.get_gui_frame_by_element(element)
    if parent_gui and parent_gui.name == Enum.GuiEnum.GUI_FRAME.TAG_EDITOR then
      control_tag_editor.on_tag_editor_gui_elem_changed(event)
    end
  end
  script.on_event(defines.events.on_gui_elem_changed, shared_on_gui_elem_changed)

  local function shared_on_gui_confirmed(event)
    if not event or not event.element then return end
    local element = event.element
    local parent_gui = GuiValidation.get_gui_frame_by_element(element)
    if parent_gui and parent_gui.name == Enum.GuiEnum.GUI_FRAME.TAG_EDITOR then
      control_tag_editor.on_tag_editor_gui_click(event)
    end
  end
  script.on_event(defines.events.on_gui_confirmed, shared_on_gui_confirmed)
end

return M
