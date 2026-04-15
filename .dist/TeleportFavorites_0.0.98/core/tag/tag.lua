local Deps = require("core.deps_barrel")
local Cache, GPSUtils =
  Deps.Cache, Deps.GpsUtils
local Tag = {}
Tag.__index = Tag
function Tag.new(gps, faved_by_players, owner_name)
  return setmetatable({ gps = gps, faved_by_players = faved_by_players or {}, owner_name = owner_name }, Tag)
end
function Tag.update_gps_and_surface_mapping(old_gps, new_gps, chart_tag, player, preserve_owner_name)
  if not old_gps or not new_gps then return end
  if not player or not player.valid then return end
  local old_tag = Cache.get_tag_by_gps(player, old_gps)
  if old_tag == nil and new_gps then
    old_tag = Tag.new(new_gps, {}, preserve_owner_name)
  end
  if type(old_tag) == "table" then
    old_tag.gps = new_gps or ""
    old_tag.chart_tag = nil
    if preserve_owner_name then
      old_tag.owner_name = preserve_owner_name
    end
  end
  local surface_index = old_gps and GPSUtils.get_surface_index_from_gps(old_gps) or nil
  if surface_index and old_gps and new_gps and old_gps ~= new_gps then
    local uint_surface_index = math.floor(tonumber(surface_index) or 1)
    local surface_tags = Cache.get_surface_tags(uint_surface_index)
    if type(surface_tags) == "table" and surface_tags[old_gps] then
      surface_tags[new_gps] = surface_tags[old_gps]
      surface_tags[old_gps] = nil
    end
    if type(surface_tags) == "table" and new_gps and type(old_tag) == "table" then
      surface_tags[new_gps] = old_tag
    end
    Cache.Lookups.evict_chart_tag_cache_entry(old_gps)
    Cache.invalidate_rehydrated_favorites()
  end
end
return Tag
