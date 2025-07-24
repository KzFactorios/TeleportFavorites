---@diagnostic disable: undefined-global


local Cache = require("core.cache.cache")
local BasicHelpers = require("core.utils.basic_helpers")
local ErrorHandler = require("core.utils.error_handler")

local ModalInputBlocker = {}

---@param player_index number
---@return boolean should_block
local function should_block_input(player_index)
  local player = game.players[player_index]
  if not BasicHelpers.is_valid_player(player) then return false end

  return Cache.is_modal_dialog_active(player)
end

---@param event table
---@param event_name string
local function block_input_event(event, event_name)
  if not event or not event.player_index then return false end

  if should_block_input(event.player_index) then
    ErrorHandler.debug_log("[MODAL BLOCKER] Blocking input event", {
      event_name = event_name,
      player_index = event.player_index,
      modal_type = Cache.get_modal_dialog_type(game.players[event.player_index])
    })
    return true
  end

  return false
end

---@param event table
function ModalInputBlocker.on_built_entity(event)
  if block_input_event(event, "on_built_entity") then return end
end

---@param event table
function ModalInputBlocker.on_pre_build(event)
  if block_input_event(event, "on_pre_build") then return end
end

---@param event table
function ModalInputBlocker.on_pre_player_mined_item(event)
  if block_input_event(event, "on_pre_player_mined_item") then return end
end

---@param event table
function ModalInputBlocker.on_player_mined_item(event)
  if block_input_event(event, "on_player_mined_item") then return end
end

---@param event table
function ModalInputBlocker.on_player_cursor_stack_changed(event)
  if block_input_event(event, "on_player_cursor_stack_changed") then return end
end

---@param event table
function ModalInputBlocker.on_player_main_inventory_changed(event)
  if block_input_event(event, "on_player_main_inventory_changed") then return end
end

---@param event table
function ModalInputBlocker.on_player_fast_transferred(event)
  if block_input_event(event, "on_player_fast_transferred") then return end
end

---@param event table
function ModalInputBlocker.on_player_selected_area(event)
  if block_input_event(event, "on_player_selected_area") then return end
end

---@param event table
function ModalInputBlocker.on_player_alt_selected_area(event)
  if block_input_event(event, "on_player_alt_selected_area") then return end
end

---@param event table
function ModalInputBlocker.on_player_setup_blueprint(event)
  if block_input_event(event, "on_player_setup_blueprint") then return end
end

---@param event table
function ModalInputBlocker.on_player_configured_blueprint(event)
  if block_input_event(event, "on_player_configured_blueprint") then return end
end

---@param event table
function ModalInputBlocker.on_player_deconstructed_area(event)
  if block_input_event(event, "on_player_deconstructed_area") then return end
end

---@param script table The Factorio script object
function ModalInputBlocker.register_handlers(script)
  if not script or type(script.on_event) ~= "function" then
    ErrorHandler.warn_log("Invalid script object for modal input blocker registration")
    return false
  end

  ErrorHandler.debug_log("Registering modal input blocking handlers")

  local events_to_register = {
    {defines.events.on_built_entity, ModalInputBlocker.on_built_entity},
    {defines.events.on_pre_player_mined_item, ModalInputBlocker.on_pre_player_mined_item},
    {defines.events.on_player_mined_item, ModalInputBlocker.on_player_mined_item},
    {defines.events.on_player_fast_transferred, ModalInputBlocker.on_player_fast_transferred},
    {defines.events.on_player_selected_area, ModalInputBlocker.on_player_selected_area},
    {defines.events.on_player_alt_selected_area, ModalInputBlocker.on_player_alt_selected_area},
    {defines.events.on_player_setup_blueprint, ModalInputBlocker.on_player_setup_blueprint},
    {defines.events.on_player_configured_blueprint, ModalInputBlocker.on_player_configured_blueprint}
  }

  if defines.events.on_pre_build then
    table.insert(events_to_register, {defines.events.on_pre_build, ModalInputBlocker.on_pre_build})
  end

  if defines.events.on_player_cursor_stack_changed then
    table.insert(events_to_register, {defines.events.on_player_cursor_stack_changed, ModalInputBlocker.on_player_cursor_stack_changed})
  end

  if defines.events.on_player_main_inventory_changed then
    table.insert(events_to_register, {defines.events.on_player_main_inventory_changed, ModalInputBlocker.on_player_main_inventory_changed})
  end

  if defines.events.on_player_deconstructed_area then
    table.insert(events_to_register, {defines.events.on_player_deconstructed_area, ModalInputBlocker.on_player_deconstructed_area})
  end

  for _, event_data in ipairs(events_to_register) do
    local event_id, handler = event_data[1], event_data[2]
    script.on_event(event_id, handler)
  end

  ErrorHandler.debug_log("Modal input blocking handlers registered successfully")
  return true
end

return ModalInputBlocker
