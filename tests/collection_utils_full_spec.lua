-- tests/collection_utils_full_spec.lua
-- 100% coverage for core.utils.collection_utils

local CollectionUtils = require("core.utils.collection_utils")

describe("CollectionUtils", function()
  it("should compare tables for equality", function()
    assert.is_true(CollectionUtils.tables_equal({}, {}))
    assert.is_true(CollectionUtils.tables_equal({a=1}, {a=1}))
    assert.is_false(CollectionUtils.tables_equal({a=1}, {a=2}))
    assert.is_false(CollectionUtils.tables_equal({a=1}, {b=1}))
    assert.is_true(CollectionUtils.tables_equal({a={b=2}}, {a={b=2}}))
    assert.is_false(CollectionUtils.tables_equal({a={b=2}}, {a={b=3}}))
  end)

  it("should deep copy tables", function()
    local orig = {a=1, b={c=2}}
    local copy = CollectionUtils.deep_copy(orig)
    assert.not_equals(orig, copy)
    assert.same(orig, copy)
    copy.b.c = 3
    assert.not_equals(orig.b.c, copy.b.c)
  end)

  it("should shallow copy tables", function()
    local orig = {a=1, b={c=2}}
    local copy = CollectionUtils.shallow_copy(orig)
    assert.not_equals(orig, copy)
    assert.equals(orig.b, copy.b)
    copy.a = 2
    assert.not_equals(orig.a, copy.a)
  end)

  it("should count table elements", function()
    assert.equals(CollectionUtils.table_count({}), 0)
    assert.equals(CollectionUtils.table_count({1,2,3}), 3)
    assert.equals(CollectionUtils.table_count({a=1,b=2}), 2)
    assert.equals(CollectionUtils.table_count(nil), 0)
  end)
end)
