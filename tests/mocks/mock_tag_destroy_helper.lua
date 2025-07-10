-- tests/mocks/mock_tag_destroy_helper.lua
local calls = {}
local MockTagDestroyHelper = {}

function MockTagDestroyHelper.destroy_tag_and_chart_tag(tag, chart_tag)
    table.insert(calls, { tag = tag, chart_tag = chart_tag })
    return true
end

function MockTagDestroyHelper.set_destroy_result(result)
    MockTagDestroyHelper._result = result
end

function MockTagDestroyHelper.clear()
    for i = #calls, 1, -1 do table.remove(calls, i) end
    MockTagDestroyHelper._result = true
end

function MockTagDestroyHelper.get_calls()
    return calls
end

return MockTagDestroyHelper
