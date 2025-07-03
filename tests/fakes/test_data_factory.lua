
-- tests/fakes/test_data_factory.lua
-- Comprehensive test driver for fake_data_factory (formerly multiplayer_data_factory)

local FakeDataFactory = require("tests.fakes.fake_data_factory")

local function table_count(t)
  local c = 0
  for _ in pairs(t) do c = c + 1 end
  return c
end

local function test_all()
  -- Setup test data
  local tag_ids = {}
  for i = 1, 100 do tag_ids[i] = "tag" .. i end
  local chart_tags = {}
  for i = 1, 100 do chart_tags[i] = { id = tag_ids[i], position = { x = i, y = -i }, surface = (i % 2 == 0) and "nauvis" or "orbit" } end

  -- Multiplayer config
  local player_names = {"AdaLovelace", "NikolaTesla", "GraceHopper", "AlanTuring", "HedyLamarr", "KatherineJohnson"}
  local factory = FakeDataFactory.new(chart_tags, tag_ids, player_names)

  -- Test favorites distribution (multiplayer)
  local favorites = factory:generate_favorites_distribution()
  assert(type(favorites) == "table" and table_count(favorites) == #player_names, "Favorites distribution (multiplayer) failed")
  assert(#favorites.AdaLovelace > 0, "AdaLovelace should have favorites")
  assert(#favorites.KatherineJohnson >= 0, "KatherineJohnson should exist")

  -- Test teleport history (various counts)
  local history_0 = factory:generate_teleport_history(0)
  assert(type(history_0) == "table" and #history_0 == 0, "Teleport history (0) failed")
  local history_1 = factory:generate_teleport_history(1)
  assert(type(history_1) == "table" and #history_1 == 1, "Teleport history (1) failed")
  local history_100 = factory:generate_teleport_history(100)
  assert(type(history_100) == "table" and #history_100 == 100, "Teleport history (100) failed")
  assert(history_100[10].tag_id == nil, "Every 10th tag_id should be nil")

  -- Test players (multiplayer, full config)
  local histories = {}
  for _, name in ipairs(player_names) do histories[name] = factory:generate_teleport_history(10) end
  local players = factory:generate_players(favorites, histories)
  assert(type(players) == "table" and #players == #player_names, "Players (multiplayer) failed")
  assert(players[1].player_name == player_names[1], "Player name mismatch")
  assert(players[1].favorites == favorites[player_names[1]] or type(players[1].favorites) == "table", "Favorites assignment failed")

  -- Single player config: test empty, partial, and full bar
  local single_name = "SoloPlayer"
  local single_factory = FakeDataFactory.new(chart_tags, tag_ids, {single_name})
  local single_favorites = single_factory:generate_favorites_distribution({single_cases = {0, 5, 10}})
  assert(type(single_favorites[single_name .. "_0"]) == "table" and #single_favorites[single_name .. "_0"] == 0, "Single player empty bar failed")
  assert(type(single_favorites[single_name .. "_5"]) == "table" and #single_favorites[single_name .. "_5"] == 5, "Single player partial bar failed")
  assert(type(single_favorites[single_name .. "_10"]) == "table" and #single_favorites[single_name .. "_10"] == 10, "Single player full bar failed")

  -- Single player: test players
  local single_histories = {[single_name] = single_factory:generate_teleport_history(7)}
  local single_players = single_factory:generate_players(single_favorites, single_histories)
  assert(type(single_players) == "table" and #single_players == 1, "Single player: players failed")
  assert(single_players[1].player_name == single_name, "Single player: player name mismatch")

  -- Edge: test with no tag_ids
  local empty_factory = FakeDataFactory.new({}, {}, player_names)
  local empty_favorites = empty_factory:generate_favorites_distribution()
  for _, name in ipairs(player_names) do assert(type(empty_favorites[name]) == "table", "Empty favorites for " .. name .. " failed") end
  local empty_history = empty_factory:generate_teleport_history(5)
  assert(type(empty_history) == "table" and #empty_history == 5, "Empty tag_ids: teleport history failed")

  print("All FakeDataFactory tests passed.")
end

test_all()
