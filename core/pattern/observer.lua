---@class Observer
-- Base class for the Observer pattern. Use this to implement event subscription and notification.
-- Extend this class to allow objects to subscribe to and receive updates from a subject.

local Observer = {}
Observer.__index = Observer
Observer._listeners = {}

--- Register a listener for a specific event type
-- @param event_type string
-- @param listener function
function Observer.register(event_type, listener)
    Observer._listeners[event_type] = Observer._listeners[event_type] or {}
    table.insert(Observer._listeners[event_type], listener)
end

--- Unregister a listener for a specific event type
-- @param event_type string
-- @param listener function
function Observer.unregister(event_type, listener)
    local list = Observer._listeners[event_type]
    if not list then return end
    for i, l in ipairs(list) do
        if l == listener then
            table.remove(list, i)
            break
        end
    end
end

--- Notify all listeners of an event
-- @param event table (should have a 'type' field)
function Observer.notify_all(event)
    local list = Observer._listeners[event.type]
    if not list then return end
    for _, listener in ipairs(list) do
        listener(event)
    end
end

-- Example usage (at end of file):
--[[]
local MyObserver = setmetatable({}, { __index = Observer })
function MyObserver:on_event(event)
    print("Received event:", event.type)
end
MyObserver.register("test_event", function(e) MyObserver:on_event(e) end)
MyObserver.notify_all({type = "test_event", data = 123}) -- prints "Received event: test_event"
MyObserver.unregister("test_event", function(e) MyObserver:on_event(e) end) -- removes the listener
]]

return Observer
