-- tests/mocks/mock_collection_utils.lua
local MockCollectionUtils = {}

function MockCollectionUtils.table_count(tbl)
  local count = 0
  for _ in pairs(tbl or {}) do count = count + 1 end
  return count
end

function MockCollectionUtils.deep_copy(orig)
  if type(orig) ~= 'table' then return orig end
  local copy = {}
  for k, v in pairs(orig) do
    copy[k] = (type(v) == 'table') and MockCollectionUtils.deep_copy(v) or v
  end
  return copy
end

return MockCollectionUtils
