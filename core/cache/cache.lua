---@diagnostic disable: undefined-global
---@class Cache
local Cache = {}

--- Initialize the cache if not already present
function Cache.init()
    if storage then
        storage.cache = storage.cache or {}
    end
end

--- Get a value from the cache by key
---@param key string
---@return any
function Cache.get(key)
    if not storage then return nil end
    if not storage.cache then Cache.init() end
    return storage.cache and storage.cache[key] or nil
end

--- Set a value in the cache by key
---@param key string
---@param value any
function Cache.set(key, value)
    if not storage then return end
    if not storage.cache then Cache.init() end
    if storage.cache then
        storage.cache[key] = value
    end
end

--- Remove a value from the cache by key
---@param key string
function Cache.remove(key)
    if not storage or not storage.cache then return end
    storage.cache[key] = nil
end

--- Clear the entire cache
function Cache.clear()
    if storage then
        storage.cache = {}
    end
end

return Cache
