---@diagnostic disable
-- tests/mocks/mock_helpers.lua
-- Additional helpers for test mocks

local M = {}

function M.set_global_game(mock_game)
  _G.game = mock_game
end

function M.table_count(tbl)
  local n = 0
  for _, _ in pairs(tbl) do n = n + 1 end
  return n
end

return M
