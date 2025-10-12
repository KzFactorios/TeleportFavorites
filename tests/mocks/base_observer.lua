-- base_observer.lua
-- Base class for GUI event observers

local BaseObserver = {}
BaseObserver.__index = BaseObserver

function BaseObserver:new(player)
    local observer = {
        player = player,
        id = player.name .. "_" .. tostring(player.index)
    }
    setmetatable(observer, self)
    return observer
end

function BaseObserver:handle_event(event)
    error("BaseObserver:handle_event must be implemented by derived class")
end

function BaseObserver:is_valid()
    return self.player and self.player.valid and self.player.connected
end

return BaseObserver