-- test_teleport_history.lua
-- Tests for core.teleport.teleport_history

local TeleportHistory = require("core.teleport.teleport_history")

local function mock_player(index, surface_index, x, y)
  return {
    index = index,
    valid = true,
    surface = { index = surface_index },
    position = { x = x or 0, y = y or 0 },
    teleported = false,
    teleport = function(self, pos, surface)
      self.teleported = { pos = pos, surface = surface }
    end
  }
end

local function reset_global()
  global = {}
end

-- Test: Add GPS to history, no duplicates at top
reset_global()
local player = mock_player(1, 1)
TeleportHistory.add_gps(player, { x = 10, y = 20, surface = 1 })
TeleportHistory.add_gps(player, { x = 10, y = 20, surface = 1 }) -- duplicate, should not add
TeleportHistory.add_gps(player, { x = 11, y = 21, surface = 1 })
assert(#global.teleport_history[1][1].stack == 2, "Stack should have 2 unique entries")

-- Test: Stack trims oldest when exceeding HISTORY_STACK_SIZE
reset_global()
player = mock_player(1, 1)
for i = 1, 130 do
  TeleportHistory.add_gps(player, { x = i, y = i, surface = 1 })
end
assert(#global.teleport_history[1][1].stack == 128, "Stack should trim to HISTORY_STACK_SIZE")
assert(global.teleport_history[1][1].stack[1].x == 3, "Oldest entry should be x=3 after trim")

-- Test: Pointer moves and clamps
reset_global()
player = mock_player(1, 1)
TeleportHistory.add_gps(player, { x = 1, y = 1, surface = 1 })
TeleportHistory.add_gps(player, { x = 2, y = 2, surface = 1 })
TeleportHistory.add_gps(player, { x = 3, y = 3, surface = 1 })
local hist = global.teleport_history[1][1]
assert(hist.pointer == 3, "Pointer should be at latest")
TeleportHistory.move_pointer(player, -1, false)
assert(hist.pointer == 2, "Pointer should move down")
TeleportHistory.move_pointer(player, 1, false)
assert(hist.pointer == 3, "Pointer should move up")
TeleportHistory.move_pointer(player, 1, false)
assert(hist.pointer == 3, "Pointer should not move past end")
TeleportHistory.move_pointer(player, -1, true)
assert(hist.pointer == 1, "Pointer should jump to first")
TeleportHistory.move_pointer(player, 1, true)
assert(hist.pointer == 3, "Pointer should jump to last")

-- Test: Clear stack
reset_global()
player = mock_player(1, 1)
TeleportHistory.add_gps(player, { x = 1, y = 1, surface = 1 })
TeleportHistory.clear(player)
assert(#global.teleport_history[1][1].stack == 0, "Stack should be empty after clear")
assert(global.teleport_history[1][1].pointer == 0, "Pointer should be 0 after clear")

print("All teleport history tests passed.")
