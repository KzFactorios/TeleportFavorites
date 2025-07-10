-- tests/mocks/mock_collection_utils.lua
local MockCollectionUtils = {}
function MockCollectionUtils.table_count(tbl)
  local count = 0
  for _ in pairs(tbl or {}) do count = count + 1 end
  return count
end
return MockCollectionUtils
