---@class Singleton
-- Base class for the Singleton pattern. Ensures only one instance exists.
-- Extend this class to create a globally accessible, single-instance object.

local Singleton = {}
Singleton.__index = Singleton
Singleton._instance = nil

--- Get the singleton instance, creating it if necessary
function Singleton:getInstance()
    if not self._instance then
        self._instance = setmetatable({}, self)
        if self.init then self._instance:init() end
    end
    return self._instance
end

--- Optional: Initialization logic for the singleton
function Singleton:init()
    -- Override in subclass if needed
end

-- Example usage (at end of file):
--[[
local MySingleton = setmetatable({}, { __index = Singleton })
function MySingleton:init()
    self.value = 42
end
local s1 = MySingleton:getInstance()
local s2 = MySingleton:getInstance()
print(s1 == s2) -- true
print(s1.value) -- 42
]]

return Singleton
