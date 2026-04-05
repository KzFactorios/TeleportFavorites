---@diagnostic disable: undefined-global

-- core/events/modal_input_blocker.lua
-- TeleportFavorites Factorio Mod
--
 
-- (on_built_entity, on_pre_build, on_player_mined_item, etc.) that fired on every
-- build/mine/transfer action. The handlers only performed an early-return check for
-- modal dialog state, but Factorio event handlers cannot cancel events (the action
-- has already occurred by the time the handler runs). The handlers were pure overhead
-- causing UPS spikes during heavy gameplay.

local ModalInputBlocker = {}

--- No-op: Modal input blocking has been removed for UPS optimization.
--- Factorio event handlers cannot cancel events — returning from an event handler
--- does not undo the build/mine/transfer action, making these handlers ineffective.
---@param script table The Factorio script object
function ModalInputBlocker.register_handlers(script)
  return true
end

return ModalInputBlocker
