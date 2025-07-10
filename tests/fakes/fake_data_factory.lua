-- tests/fakes/fake_data_factory.lua
-- Utility class for generating fake player, favorite, and teleport history data for tests (formerly multiplayer_data_factory)

local FakeDataFactory = {}
FakeDataFactory.__index = FakeDataFactory

function FakeDataFactory.new(chart_tags, tag_ids, player_names)
  local self = setmetatable({}, FakeDataFactory)
  self.chart_tags = chart_tags or {}
  self.tag_ids = tag_ids or {}
  self.player_names = player_names or {
    "AdaLovelace", "NikolaTesla", "GraceHopper", "AlanTuring", "HedyLamarr", "KatherineJohnson"
  }
  return self
end

function FakeDataFactory:generate_favorites_distribution(config)
  config = config or {}
  local MAX_FAVORITE_SLOTS = config.max_favorite_slots or 10
  local total_tags = #self.tag_ids
  local percent = config.percent or 0.6
  local num_favorites = math.floor(total_tags * percent)
  local favorites = {}
  for _, name in ipairs(self.player_names) do favorites[name] = {} end
  if #self.player_names == 1 then
    -- Single player: test empty, partial, and full bar
    local single_name = self.player_names[1]
    local cases = config.single_cases or {0, math.floor(MAX_FAVORITE_SLOTS/2), MAX_FAVORITE_SLOTS}
    for _, count in ipairs(cases) do
      favorites[single_name .. "_" .. tostring(count)] = {}
      for i = 1, math.min(count, total_tags) do
        table.insert(favorites[single_name .. "_" .. tostring(count)], self.tag_ids[i])
      end
    end
    -- Default: fill up to max or as specified
    if not config.single_cases then
      for i = 1, math.min(num_favorites, MAX_FAVORITE_SLOTS) do
        table.insert(favorites[single_name], self.tag_ids[i])
      end
    end
  else
    -- Multiplayer: uneven distribution
    for i = 1, num_favorites do
      if i <= MAX_FAVORITE_SLOTS then
        table.insert(favorites.AdaLovelace, self.tag_ids[i])
      elseif i <= MAX_FAVORITE_SLOTS + 3 then
        table.insert(favorites.GraceHopper, self.tag_ids[i])
      elseif i <= MAX_FAVORITE_SLOTS + 3 + 6 then
        table.insert(favorites.AlanTuring, self.tag_ids[i])
      elseif i <= MAX_FAVORITE_SLOTS + 3 + 6 + 1 then
        table.insert(favorites.HedyLamarr, self.tag_ids[i])
      else
        table.insert(favorites.KatherineJohnson, self.tag_ids[i])
      end
    end
  end
  return favorites
end

function FakeDataFactory:generate_teleport_history(count, opts)
  opts = opts or {}
  local t = {}
  for i = 1, count do
    local tag_id = nil
    if i % 10 ~= 0 then
      if self.tag_ids and #self.tag_ids > 0 then
        tag_id = self.tag_ids[((i - 1) % #self.tag_ids) + 1]
      else
        tag_id = "tag" .. i
      end
    end
    local x = (opts.x_base or 0) + (i * (opts.x_step or 10))
    local y = (opts.y_base or 0) - (i * (opts.y_step or 5))
    local surface = (i % 2 == 0) and (opts.surface_even or "nauvis") or (opts.surface_odd or "orbit")
    t[i] = { x = x, y = y, surface = surface, tag_id = tag_id, time = (opts.time_base or 1000) + i * (opts.time_step or 100) }
  end
  return t
end

function FakeDataFactory:generate_players(favorites, histories, config)
  config = config or {}
  local players = {}
  for idx, name in ipairs(self.player_names) do
    local history = histories and histories[name] or {}
    local render_mode = config.render_modes and config.render_modes[idx] or ((idx % 3 == 0) and "chart" or ((idx % 5 == 0) and "chart_zoomed_in" or "game"))
    local font_size = config.font_sizes and config.font_sizes[idx] or (12 + (idx - 1) * 2)
    local bar_visible = config.fave_bar_slots_visible and config.fave_bar_slots_visible[idx] or (idx % 2 == 1)
    players[idx] = {
      player_name = name,
      render_mode = render_mode,
      favorites = favorites and favorites[name] or {},
      teleport_history = history,
      fave_bar_slots_visible = bar_visible
    }
  end
  return players
end

return FakeDataFactory
