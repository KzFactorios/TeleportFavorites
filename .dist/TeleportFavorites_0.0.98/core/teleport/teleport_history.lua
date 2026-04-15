local Deps = require("core.deps_barrel")
local BasicHelpers, Cache, GPSUtils =
  Deps.BasicHelpers, Deps.Cache, Deps.GpsUtils
local HistoryItem = Cache.HistoryItem
local ProfilerExport = require("core.utils.profiler_export")
local MpBisect = require("core.utils.mp_bisect")
local HISTORY_STACK_SIZE = 128
local STD_RESOLUTION_TILES = 20
local SEQ_RESOLUTION_TILES = 32
local TeleportHistory = {}
local function ensure_history_meta(hist)
	if not hist then return end
	if type(hist.stack_revision) ~= "number" then
		hist.stack_revision = 0
	end
end
local function bump_stack_revision(hist)
	ensure_history_meta(hist)
	hist.stack_revision = hist.stack_revision + 1
end
local function gps_within_resolution(gps_a, gps_b, resolution)
	if not gps_a or not gps_b then return false end
	local surface_a = GPSUtils.get_surface_index_from_gps(gps_a)
	local surface_b = GPSUtils.get_surface_index_from_gps(gps_b)
	if not surface_a or not surface_b then return false end
	if math.floor(surface_a) ~= math.floor(surface_b) then return false end
	if gps_a == gps_b then return true end
	local pos_a = GPSUtils.map_position_from_gps(gps_a)
	local pos_b = GPSUtils.map_position_from_gps(gps_b)
	if not pos_a or not pos_b then return false end
	local dx = pos_a.x - pos_b.x
	local dy = pos_a.y - pos_b.y
	return (dx * dx + dy * dy) <= (resolution * resolution)
end
function TeleportHistory.remove_history_item(player, surface_index, index)
	if not BasicHelpers.is_valid_player(player) then return end
	local hist = Cache.get_player_teleport_history(player, surface_index)
	ensure_history_meta(hist)
	local stack = hist.stack
	if not stack or #stack == 0 then return end
	local idx = tonumber(index)
	if not idx or idx < 1 or idx > #stack then return end
	table.remove(stack, math.floor(idx))
	bump_stack_revision(hist)
	if hist.pointer > #stack then
		hist.pointer = #stack
	end
	TeleportHistory.notify_observers(player)
end
TeleportHistory._observers = {}
function TeleportHistory.register_observer(callback)
	table.insert(TeleportHistory._observers, callback)
end
function TeleportHistory.notify_observers(player, context)
	for _, cb in ipairs(TeleportHistory._observers) do
		pcall(cb, player, context)
	end
end
function TeleportHistory.add_gps(player, gps)
	local valid = BasicHelpers.is_valid_player(player)
	if not valid or not gps then return end
	local surface_index = GPSUtils.get_surface_index_from_gps(gps)
	if not surface_index or type(surface_index) ~= "number" then
		log("[TeleportFavorites] WARNING: Malformed GPS string, using player's current surface index for history. gps=" .. tostring(gps))
		surface_index = player.surface and player.surface.index or 1
	else
		surface_index = math.floor(surface_index)
	end
	local hist = Cache.get_player_teleport_history(player, surface_index)
	ensure_history_meta(hist)
	local stack = hist.stack
	local top = stack[#stack]
	if gps_within_resolution(top and top.gps, gps, STD_RESOLUTION_TILES) then
		hist.pointer = #stack
		TeleportHistory.notify_observers(player)
		return
	end
	if #stack >= HISTORY_STACK_SIZE then
		table.remove(stack, 1)
	end
	local item = HistoryItem.new(gps)
	table.insert(stack, item)
	bump_stack_revision(hist)
	hist.pointer = #stack
	TeleportHistory.notify_observers(player)
end
function TeleportHistory.add_teleport(player, from_gps, to_gps)
	if not BasicHelpers.is_valid_player(player) then return end
	if not to_gps then return end
	local is_sequential = Cache.get_sequential_history_mode(player)
	if not is_sequential then
		TeleportHistory.add_gps(player, to_gps)
		return
	end
	if from_gps and gps_within_resolution(from_gps, to_gps, SEQ_RESOLUTION_TILES) then
		return
	end
	if from_gps then
		TeleportHistory.add_gps(player, from_gps)
	end
	TeleportHistory.add_gps(player, to_gps)
end
function TeleportHistory.set_pointer(player, surface_index, index)
	if not BasicHelpers.is_valid_player(player) then return end
	local action_id = ProfilerExport.get_action_trace_id(player.index)
	local hist = Cache.get_player_teleport_history(player, surface_index)
	ensure_history_meta(hist)
	local stack = hist.stack
	if #stack == 0 then
		hist.pointer = 0
		TeleportHistory.notify_observers(player, { action_id = action_id })
		return
	end
	if index < 1 then
		hist.pointer = 1
	elseif index > #stack then
		hist.pointer = #stack
	else
		hist.pointer = index
	end
	TeleportHistory.notify_observers(player, { action_id = action_id })
end
function TeleportHistory.clear_history(player, surface_index)
	if not BasicHelpers.is_valid_player(player) then return end
	local hist = Cache.get_player_teleport_history(player, surface_index)
	ensure_history_meta(hist)
	hist.stack = {}
	hist.pointer = 0
	bump_stack_revision(hist)
	TeleportHistory.notify_observers(player)
end
function TeleportHistory.register_remote_interface()
	if remote.interfaces["TeleportFavorites_History"] then
		pcall(remote.remove_interface, "TeleportFavorites_History")
	end
	remote.add_interface("TeleportFavorites_History", {
		add_to_history = function(player_index, gps)
			if MpBisect.no_chart_and_remote() then return end
			TeleportHistory.add_gps(game.players[player_index], gps)
		end,
		add_teleport = function(player_index, from_gps, to_gps)
			if MpBisect.no_chart_and_remote() then return end
			TeleportHistory.add_teleport(game.players[player_index], from_gps, to_gps)
		end,
	})
end
return TeleportHistory
