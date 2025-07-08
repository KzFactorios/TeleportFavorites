-- DEPRECATED: This file is obsolete and should be deleted. All player mocks should use PlayerFavoritesMocks.mock_player from player_favorites_mocks.lua.
-- This file is retained temporarily for reference only.

-- tests/mocks/mock_player_data.lua
-- Mock for player data using FakeDataFactory for test integration

local FakeDataFactory = require("tests.fakes.fake_data_factory")

local function create_mock_player_data(opts)
  opts = opts or {}
  local tag_ids = opts.tag_ids or {}
  local chart_tags = opts.chart_tags or {}
  local player_names = opts.player_names or {"TestPlayer"}
  local factory = FakeDataFactory.new(chart_tags, tag_ids, player_names)
  local favorites = factory:generate_favorites_distribution(opts.favorites_config)
  local histories = {}
  for _, name in ipairs(player_names) do
    histories[name] = factory:generate_teleport_history(opts.history_count or 10, opts.history_opts)
  end
  local players = factory:generate_players(favorites, histories, opts.players_config)
  return {
    factory = factory,
    favorites = favorites,
    histories = histories,
    players = players
  }
end

return {
  create_mock_player_data = create_mock_player_data
}
