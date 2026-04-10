-- core/cache/storage_migrations.lua
-- One-time and versioned migrations for `storage`. Runs from Cache.init (on_init / on_load).
-- Does not require core.cache.cache (avoid circular require).

---@diagnostic disable: undefined-global

local Deps = require("base_deps")
local ErrorHandler = Deps.ErrorHandler

local StorageMigrations = {}

--- Monotonic integer; bump when adding a new migration step.
StorageMigrations.CURRENT_SCHEMA_VERSION = 1

--- Normalize tag.faved_by_players to map [player_index] = player_index.
--- Idempotent. Matches reader logic in chart_tag_helpers / chart_tag_utils.
---@param fbp table|nil
---@return table
local function normalize_faved_by_players(fbp)
  if type(fbp) ~= "table" then return {} end
  local map = {}
  for k, v in pairs(fbp) do
    local pid = nil
    if type(v) == "number" and v >= 1 and math.floor(v) == v then
      pid = v
    elseif type(k) == "number" and k >= 1 and (v == true or v == k) then
      pid = k
    end
    if pid then
      map[pid] = pid
    end
  end
  return map
end

--- Schema v1: canonical map form for faved_by_players (legacy array or mixed tables).
function StorageMigrations.migrate_faved_by_players_v1()
  local surfaces = storage.surfaces
  if type(surfaces) ~= "table" then return end
  local tags_updated = 0
  for _, surf in pairs(surfaces) do
    local tags = surf and surf.tags
    if type(tags) == "table" then
      for _, tag in pairs(tags) do
        if type(tag) == "table" and type(tag.faved_by_players) == "table" then
          tag.faved_by_players = normalize_faved_by_players(tag.faved_by_players)
          tags_updated = tags_updated + 1
        end
      end
    end
  end
  if tags_updated > 0 and ErrorHandler and ErrorHandler.debug_log then
    ErrorHandler.debug_log("[STORAGE] Migration v1: normalized faved_by_players", { tags_updated = tags_updated })
  end
end

--- Apply all pending migrations based on `storage._tf_schema_version`.
function StorageMigrations.apply_all()
  local v = storage._tf_schema_version or 0
  if v >= StorageMigrations.CURRENT_SCHEMA_VERSION then
    return
  end

  if v < 1 then
    StorageMigrations.migrate_faved_by_players_v1()
  end

  storage._tf_schema_version = StorageMigrations.CURRENT_SCHEMA_VERSION
end

return StorageMigrations
