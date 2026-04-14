---@diagnostic disable: undefined-global

-- Tag editor no longer draws world/map preview markers (LuaRendering circles).
-- Call sites still invoke these hooks so cleanup paths stay centralized.

local M = {}

--- No-op: nothing to destroy when preview rendering is disabled.
---@param _player LuaPlayer
function M.destroy_for_player(_player) end

--- No-op: kept for API compatibility with `tag_editor.build`.
---@param _player LuaPlayer
---@param _tag_data table|nil
function M.sync_for_tag_data(_player, _tag_data) end

return M
