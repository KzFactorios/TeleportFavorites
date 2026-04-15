local Deps = require("core.base_deps_barrel")
local ErrorHandler = Deps.ErrorHandler
local StorageMigrations = {}
StorageMigrations.CURRENT_SCHEMA_VERSION = 1
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
function StorageMigrations.migrate_faved_by_players_v1()
  local surfaces = storage.surfaces
  if type(surfaces) ~= "table" then return end
  local tags_updated = 0
  local surface_indices = {}
  for sidx in pairs(surfaces) do
    if type(sidx) == "number" then
      surface_indices[#surface_indices + 1] = sidx
    end
  end
  table.sort(surface_indices)
  for si = 1, #surface_indices do
    local surf = surfaces[surface_indices[si]]
    local tags = surf and surf.tags
    if type(tags) == "table" then
      local gps_keys = {}
      for gps, _ in pairs(tags) do
        if type(gps) == "string" then
          gps_keys[#gps_keys + 1] = gps
        end
      end
      table.sort(gps_keys)
      for gi = 1, #gps_keys do
        local tag = tags[gps_keys[gi]]
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
