---@diagnostic disable: undefined-global

-- core/teleport/teleport_history.lua
-- TeleportFavorites Factorio Mod
-- Manages player teleport history stack, pointer navigation, and GPS string conversion for history modal.

local Cache = require("core.cache.cache")
local GPSUtils = require("core.utils.gps_utils")
local ValidationUtils = require("core.utils.validation_utils")
local HistoryItem = require("core.teleport.history_item")
local ErrorHandler = require("core.utils.error_handler")


local HISTORY_STACK_SIZE = 128 -- Only 128 allowed for now (TBA for future options)
local STD_RESOLUTION_TILES = 20  -- Standard mode: consecutive locations within this distance are collapsed
local SEQ_RESOLUTION_TILES = 32  -- Sequential mode: FROM→TO hops shorter than this are not recorded

local TeleportHistory = {}

---@param parsed_gps table|nil
---@return string|nil
local function normalize_parsed_gps(parsed_gps)
  if not parsed_gps or type(parsed_gps.x) ~= "number" or type(parsed_gps.y) ~= "number" or type(parsed_gps.s) ~= "number" then
    return nil
  end

  return GPSUtils.gps_from_map_position({ x = parsed_gps.x, y = parsed_gps.y }, math.floor(parsed_gps.s))
end

--- Check if two parsed GPS values are within a given tile resolution (same surface only).
---@param parsed_a table|nil
---@param parsed_b table|nil
---@param resolution number Tile distance threshold
---@return boolean
local function parsed_gps_within_resolution(parsed_a, parsed_b, resolution)
	if not parsed_a or not parsed_b then return false end
	if math.floor(parsed_a.s) ~= math.floor(parsed_b.s) then return false end
	if parsed_a.x == parsed_b.x and parsed_a.y == parsed_b.y then return true end
	local dx = parsed_a.x - parsed_b.x
	local dy = parsed_a.y - parsed_b.y
	return (dx * dx + dy * dy) <= (resolution * resolution)
end

--- Check if two GPS strings are within a given tile resolution of each other (same surface only).
---@param gps_a string|nil
---@param gps_b string|nil
---@param resolution number Tile distance threshold
---@return boolean
local function gps_within_resolution(gps_a, gps_b, resolution)
	if not gps_a or not gps_b then return false end
	return parsed_gps_within_resolution(GPSUtils.parse_gps_string(gps_a), GPSUtils.parse_gps_string(gps_b), resolution)
end

---@param player LuaPlayer
---@param gps string
---@param notify boolean|nil
---@return boolean changed
local function add_gps_internal(player, gps, notify)
	local parsed_gps = GPSUtils.parse_gps_string(gps)
	if not parsed_gps then
		game.print("[TeleportFavorites] WARNING: Malformed GPS string, skipping history entry. gps=" .. tostring(gps))
		return false
	end

	local surface_index = math.floor(parsed_gps.s)
	local normalized_gps = normalize_parsed_gps(parsed_gps)
	if not normalized_gps then return false end

	local hist = Cache.get_player_teleport_history(player, surface_index)
	local stack = hist.stack
	local top = stack[#stack]
	local top_parsed = top and top.gps and GPSUtils.parse_gps_string(top.gps) or nil

	if parsed_gps_within_resolution(top_parsed, parsed_gps, STD_RESOLUTION_TILES) then
		hist.pointer = #stack
		if notify ~= false then
			TeleportHistory.notify_observers(player)
		end
		return false
	end

	if #stack >= HISTORY_STACK_SIZE then
		table.remove(stack, 1)
	end

	local item = HistoryItem.new(normalized_gps)
	if not item then return false end

	table.insert(stack, item)
	hist.pointer = #stack
	if notify ~= false then
		TeleportHistory.notify_observers(player)
	end
	return true
	end


--- Remove a history item at a specific index
---@param player LuaPlayer
---@param surface_index integer
---@param index integer|string
function TeleportHistory.remove_history_item(player, surface_index, index)
	if not ValidationUtils.validate_player(player) then return end
	local hist = Cache.get_player_teleport_history(player, surface_index)
	local stack = hist.stack
	if not stack or #stack == 0 then return end
	local idx = tonumber(index)
	if not idx or idx < 1 or idx > #stack then return end
	table.remove(stack, math.floor(idx))
	-- Adjust pointer if needed
	if hist.pointer > #stack then
		hist.pointer = #stack
	end
	TeleportHistory.notify_observers(player)
end

-- Observer pattern for history changes
TeleportHistory._observers = {}

--- Register an observer callback for history changes
---@param callback fun(player: LuaPlayer)
function TeleportHistory.register_observer(callback)
	table.insert(TeleportHistory._observers, callback)
end

--- Notify all observers of a history change for a player
---@param player LuaPlayer
function TeleportHistory.notify_observers(player)
	for _, cb in ipairs(TeleportHistory._observers) do
		pcall(cb, player)
	end
end

--- Add a GPS location to the teleport history stack.
--- Applies the consecutive-duplicate rule: if the new location is within
--- STD_RESOLUTION_TILES of the current stack top it is silently dropped.
---@param player LuaPlayer
---@param gps string GPS location to record
function TeleportHistory.add_gps(player, gps)
	local valid = ValidationUtils.validate_player(player)
	if not valid or not gps then return end
	add_gps_internal(player, gps, true)
end

--- Record a teleport in history, applying mode-specific deduplication logic.
--- Standard mode: records only the destination.
--- Sequential mode: records both FROM and TO with two deduplication rules:
---   Rule B — FROM within SEQ_RESOLUTION_TILES of TO (trivial hop) → nothing recorded.
---   Rule A — FROM within STD_RESOLUTION_TILES of the stack top → FROM silently skipped by add_gps.
---@param player LuaPlayer
---@param from_gps string|nil GPS where the player departed from (may be nil if unknown)
---@param to_gps string GPS where the player teleported to
function TeleportHistory.add_teleport(player, from_gps, to_gps)
	if not ValidationUtils.validate_player(player) then return end
	if not to_gps then return end
	local parsed_to_gps = GPSUtils.parse_gps_string(to_gps)
	if not parsed_to_gps then return end
	local normalized_to_gps = normalize_parsed_gps(parsed_to_gps)
	if not normalized_to_gps then return end

	local is_sequential = Cache.get_sequential_history_mode(player)

	if not is_sequential then
		-- Standard mode: record destination only
		add_gps_internal(player, normalized_to_gps, true)
		return
	end

	local parsed_from_gps = from_gps and GPSUtils.parse_gps_string(from_gps) or nil
	local normalized_from_gps = parsed_from_gps and normalize_parsed_gps(parsed_from_gps) or nil

	-- Sequential mode
	-- Rule B: trivial hop — FROM is within SEQ_RESOLUTION_TILES of TO, record nothing
	if parsed_from_gps and parsed_gps_within_resolution(parsed_from_gps, parsed_to_gps, SEQ_RESOLUTION_TILES) then
		return
	end

	local did_change = false

	-- Record FROM first (add_gps top-check handles Rule A implicitly)
	if normalized_from_gps then
		did_change = add_gps_internal(player, normalized_from_gps, false) or did_change
	end

	-- Record TO (add_gps consecutive-duplicate check prevents dup when TO ≈ FROM)
	did_change = add_gps_internal(player, normalized_to_gps, false) or did_change
	if did_change then
		TeleportHistory.notify_observers(player)
	end
end

-- Set pointer to specific index (for teleport history modal navigation)
function TeleportHistory.set_pointer(player, surface_index, index)
	if not ValidationUtils.validate_player(player) then return end
	local hist = Cache.get_player_teleport_history(player, surface_index)
	local stack = hist.stack

	if #stack == 0 then
		hist.pointer = 0
		TeleportHistory.notify_observers(player)
		return
	end

	-- Clamp index to valid range
	if index < 1 then
		hist.pointer = 1
	elseif index > #stack then
		hist.pointer = #stack
	else
		hist.pointer = index
	end
	TeleportHistory.notify_observers(player)
end

-- Register the remote interface for teleport history tracking
function TeleportHistory.register_remote_interface()
	if not remote.interfaces["TeleportFavorites_History"] then
		remote.add_interface("TeleportFavorites_History", {
			add_to_history = function(player_index, gps)
				local player = game.players[player_index]
				if not player or not player.valid then return end
				TeleportHistory.add_gps(player, gps)
			end,
			add_teleport = function(player_index, from_gps, to_gps)
				local player = game.players[player_index]
				if not player or not player.valid then return end
				TeleportHistory.add_teleport(player, from_gps, to_gps)
			end,
		})
	end
end

return TeleportHistory
