-- tests/mocks/mock_error_handler.lua
-- Minimal mock for core.utils.error_handler


local calls = {}
local MockErrorHandler = {}

function MockErrorHandler.debug_log(msg, data)
    print("[MOCK ERROR HANDLER] debug_log called: ", msg)
    table.insert(calls, { type = "debug", msg = msg, data = data })
end

function MockErrorHandler.warn_log(msg, data)
    table.insert(calls, { type = "warn", msg = msg, data = data })
end

function MockErrorHandler.get_calls()
    return calls
end

function MockErrorHandler.clear()
    for i = #calls, 1, -1 do table.remove(calls, i) end
end

return MockErrorHandler
