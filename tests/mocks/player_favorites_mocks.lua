-- player_favorites_mocks.lua
-- Mock implementations of player favorites functionality for testing

local PlayerFavoritesMocks = {}

-- Mock favorite data generator
local defines = require("tests.mocks.factorio_defines_mock")

local function create_mock_favorite(index, gps, name)
    return {
        gps = gps or "1000000.1000000.1",
        name = name or ("Test Favorite " .. tostring(index)),
        surface = "nauvis",
        locked = false,
        hidden = false
    }
end

-- Mock storage data generator
local function create_mock_storage()
    return {
        slots = {},
        favorites = {},
        bar_visible = true,
        settings = {
            show_teleport_history = true,
            max_favorite_slots = 10
        }
    }
end

-- Mock player object generator
---@param index number The player index
---@param name string The player name
---@param surface_index number The surface index
---@return table mock_player Mock player object with favorites functionality
function PlayerFavoritesMocks.mock_player(index, name, surface_index)
  index = math.floor(index or 1)
  name = name or "TestPlayer"
  surface_index = math.floor(surface_index or 1)
  _G.global = _G.global or {}
  _G.global.storage = _G.global.storage or {players = {}}
  _G.global.storage.players[index] = {
    slots = {}, favorites = {},
    bar_visible = true,
    settings = {
      show_teleport_history = true,
      max_favorite_slots = 10
    }
  }
  local mock = {
    index = index,
    name = name,
    surface = {
      index = surface_index,
      name = "nauvis",
      valid = true
    },
    valid = true,
    connected = true,
    admin = false,
    controller_type = 1,
    print = function(self, msg) print("[PLAYER] " .. tostring(msg)) end,
    is_cursor_empty = function() return true end,
    clear_cursor = function() end,
    get_favorites = function(self) return _G.global.storage.players[self.index] end,
    add_favorite = function(self, gps, name)
      local favs = self:get_favorites()
      local fav = {
        gps = gps or "1000000.1000000.1", 
        name = name or ("Test Favorite " .. #favs.favorites + 1),
        surface = "nauvis",
        locked = false,
        hidden = false
      }
      table.insert(favs.favorites, fav)
      return fav
    end,
    remove_favorite = function(self, idx)
      local favs = self:get_favorites()
      if idx and favs.favorites[idx] then
        table.remove(favs.favorites, idx)
        return true
      end
      return false
    end
  }
  return mock
end

-- Mock favorites data access functions
function PlayerFavoritesMocks.get_favorites(player)
    local storage = global.storage or {}
    storage.players = storage.players or {}
    storage.players[player.index] = storage.players[player.index] or create_mock_storage()
    return storage.players[player.index]
end

-- Mock favorites manipulation functions
function PlayerFavoritesMocks.add_favorite(player, gps, name)
    local favorites = PlayerFavoritesMocks.get_favorites(player)
    local favorite = create_mock_favorite(#favorites.favorites + 1, gps, name)
    table.insert(favorites.favorites, favorite)
    return favorite
end

function PlayerFavoritesMocks.remove_favorite(player, index)
    local favorites = PlayerFavoritesMocks.get_favorites(player)
    if index and favorites.favorites[index] then
        table.remove(favorites.favorites, index)
        return true
    end
    return false
end

-- Mock favorites bar state functions
function PlayerFavoritesMocks.is_favorites_bar_visible(player)
    local favorites = PlayerFavoritesMocks.get_favorites(player)
    return favorites.bar_visible
end

function PlayerFavoritesMocks.set_favorites_bar_visible(player, visible)
    local favorites = PlayerFavoritesMocks.get_favorites(player)
    favorites.bar_visible = visible
end

-- Mock settings functions
function PlayerFavoritesMocks.get_max_favorite_slots(player)
    local favorites = PlayerFavoritesMocks.get_favorites(player)
    return favorites.settings.max_favorite_slots
end

function PlayerFavoritesMocks.set_max_favorite_slots(player, max_slots)
    local favorites = PlayerFavoritesMocks.get_favorites(player)
    favorites.settings.max_favorite_slots = max_slots
end

return PlayerFavoritesMocks