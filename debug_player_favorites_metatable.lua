-- Debug script to check PlayerFavorites metatable and methods

-- Setup required globals and mocks for testing
_G.storage = { players = {} }
_G.global = {}
_G.game = {
    players = {
        [1] = {
            index = 1,
            valid = true,
            name = "test_player",
            surface = { index = 1 },
            print = function() end
        }
    },
    tick = 123456
}

-- Setup settings
_G.settings = {
    global = {
        ["tf-max-favorite-slots"] = { value = 10 },
        ["tf-enable-teleport-history"] = { value = true },
        ["tf-max-teleport-history"] = { value = 20 }
    },
    get_player_settings = function(player)
        return { ["show-player-coords"] = { value = true } }
    end
}

-- Setup observer mock
_G.GuiObserver = {
    GuiEventBus = {
        notify = function(event_type, data)
            print("Observer notification:", event_type)
        end
    }
}

-- Require the PlayerFavorites module
print("Loading PlayerFavorites module...")
local PlayerFavorites = require("core.favorite.player_favorites")
print("PlayerFavorites module loaded:", type(PlayerFavorites))

-- Debug the metatable
print("PlayerFavorites metatable:", getmetatable(PlayerFavorites))
if getmetatable(PlayerFavorites) then
    local mt = getmetatable(PlayerFavorites)
    print("Metatable __index:", mt.__index)
    if mt.__index then
        for k, v in pairs(mt.__index) do
            print("  Method:", k, type(v))
        end
    end
end

-- Check direct methods on PlayerFavorites
print("\nDirect methods on PlayerFavorites:")
for k, v in pairs(PlayerFavorites) do
    print("  ", k, type(v))
end

-- Test creating an instance
print("\nCreating PlayerFavorites instance...")
local player = game.players[1]
local success, result = pcall(function()
    return PlayerFavorites.new(player)
end)

if success then
    print("Instance created successfully:", type(result))
    print("Instance metatable:", getmetatable(result))
    
    if getmetatable(result) then
        local inst_mt = getmetatable(result)
        print("Instance metatable __index:", inst_mt.__index)
        if inst_mt.__index then
            print("Available methods on instance:")
            for k, v in pairs(inst_mt.__index) do
                print("  ", k, type(v))
            end
        end
    end
    
    -- Test if methods are callable
    if result.add_favorite then
        print("add_favorite method exists:", type(result.add_favorite))
    else
        print("add_favorite method is missing!")
    end
    
    if result.get_favorite_by_slot then
        print("get_favorite_by_slot method exists:", type(result.get_favorite_by_slot))
    else
        print("get_favorite_by_slot method is missing!")
    end
    
    -- Check the favorites array
    print("Instance.favorites:", type(result.favorites))
    if result.favorites then
        print("Favorites length:", #result.favorites)
    end
    
else
    print("Failed to create instance:", result)
end
