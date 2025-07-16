---@diagnostic disable: undefined-global

--[[
modal_input_blocker.lua
TeleportFavorites Factorio Mod
-----------------------------
Blocks all player input when modal dialogs are active to ensure proper modal behavior.
Intercepts key input events and prevents them from executing when a modal dialog is open.

Events Blocked:
- Mouse clicks on game world (building, selecting, etc.)
- Keyboard shortcuts and hotkeys
- Built entity events (placing, building)
- Mining and demolition events
- Player movement and selection events
- Custom input events (except modal-related ones)

This ensures that when the teleport history modal (or other modals) are open,
the player cannot interact with the game world until the modal is closed.
--]]

local Cache = require("core.cache.cache")
local BasicHelpers = require("core.utils.basic_helpers")
local ErrorHandler = require("core.utils.error_handler")

local ModalInputBlocker = {}

--- Check if input should be blocked for the given player
---@param player_index number
---@return boolean should_block
local function should_block_input(player_index)
  local player = game.players[player_index]
  if not BasicHelpers.is_valid_player(player) then return false end
  
  return Cache.is_modal_dialog_active(player)
end

--- Generic input blocker that blocks events when modal is active
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
    return true -- Block the event
  end
  
  return false -- Allow the event
end

--- Block built entity events (placing buildings)
---@param event table
function ModalInputBlocker.on_built_entity(event)
  if block_input_event(event, "on_built_entity") then return end
  -- Event is allowed, no further action needed
end

--- Block pre-build events (planning to build)
---@param event table  
function ModalInputBlocker.on_pre_build(event)
  if block_input_event(event, "on_pre_build") then return end
  -- Event is allowed, no further action needed
end

--- Block mining events
---@param event table
function ModalInputBlocker.on_pre_player_mined_item(event)
  if block_input_event(event, "on_pre_player_mined_item") then return end
  -- Event is allowed, no further action needed
end

--- Block player mined item events
---@param event table
function ModalInputBlocker.on_player_mined_item(event)
  if block_input_event(event, "on_player_mined_item") then return end
  -- Event is allowed, no further action needed
end

--- Block player cursor stack changed events (item selection)
---@param event table
function ModalInputBlocker.on_player_cursor_stack_changed(event)
  if block_input_event(event, "on_player_cursor_stack_changed") then return end
  -- Event is allowed, no further action needed
end

--- Block player main inventory changed events
---@param event table
function ModalInputBlocker.on_player_main_inventory_changed(event)
  if block_input_event(event, "on_player_main_inventory_changed") then return end
  -- Event is allowed, no further action needed
end

--- Block player fast transferred events
---@param event table
function ModalInputBlocker.on_player_fast_transferred(event)
  if block_input_event(event, "on_player_fast_transferred") then return end
  -- Event is allowed, no further action needed
end

--- Block player selected area events
---@param event table
function ModalInputBlocker.on_player_selected_area(event)
  if block_input_event(event, "on_player_selected_area") then return end
  -- Event is allowed, no further action needed
end

--- Block player alt selected area events
---@param event table
function ModalInputBlocker.on_player_alt_selected_area(event)
  if block_input_event(event, "on_player_alt_selected_area") then return end
  -- Event is allowed, no further action needed
end

--- Block player setup blueprint events
---@param event table
function ModalInputBlocker.on_player_setup_blueprint(event)
  if block_input_event(event, "on_player_setup_blueprint") then return end
  -- Event is allowed, no further action needed
end

--- Block player configured blueprint events
---@param event table
function ModalInputBlocker.on_player_configured_blueprint(event)
  if block_input_event(event, "on_player_configured_blueprint") then return end
  -- Event is allowed, no further action needed
end

--- Block player deconstructed area events
---@param event table
function ModalInputBlocker.on_player_deconstructed_area(event)
  if block_input_event(event, "on_player_deconstructed_area") then return end
  -- Event is allowed, no further action needed
end

--- Register all modal input blocking event handlers
---@param script table The Factorio script object
function ModalInputBlocker.register_handlers(script)
  if not script or type(script.on_event) ~= "function" then
    ErrorHandler.warn_log("Invalid script object for modal input blocker registration")
    return false
  end

  ErrorHandler.debug_log("Registering modal input blocking handlers")

  -- Register handlers for events that definitely exist in Factorio
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

  -- Conditionally register events that might not exist in all versions
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

  -- Register all events
  for _, event_data in ipairs(events_to_register) do
    local event_id, handler = event_data[1], event_data[2]
    script.on_event(event_id, handler)
  end

  ErrorHandler.debug_log("Modal input blocking handlers registered successfully")
  return true
end

return ModalInputBlocker
