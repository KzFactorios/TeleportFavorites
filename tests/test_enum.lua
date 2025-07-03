local Enum = require("prototypes.enums.enum")

describe("Enum utility functions", function()
  it("should find enum key by value", function()
    local key = Enum.get_enum_by_value("success", Enum.CoreEnums.ReturnStates)
    assert.equals(key, "SUCCESS")
  end)

  it("should check if value is member of enum", function()
    assert.is_true(Enum.is_value_member_enum("failure", Enum.CoreEnums.ReturnStates))
    assert.is_false(Enum.is_value_member_enum("not-a-state", Enum.CoreEnums.ReturnStates))
  end)

  it("should return key names for an enum", function()
    local keys = Enum.get_key_names(Enum.CoreEnums.ReturnStates)
    assert.is_table(keys)
    assert.is_true(#keys > 0)
  end)
end)
