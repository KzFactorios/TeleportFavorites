---
name: "TeleportFavorites Testing Standards"
description: "Smoke testing patterns and mock usage"
applyTo: "tests/**/*.lua, **/*_spec.lua"
---
# TeleportFavorites: Testing Standards

## 1. SMOKE TESTING PHILOSOPHY
- **Focus**: Execution validation (does it load/expose API?) over deep behavior.
- **Location**: All specs in `tests/specs/*_spec.lua`.

## 2. BOILERPLATE PATTERN
```lua
require("test_bootstrap")
require("mocks.factorio_test_env")

describe("ModuleName", function()
    it("should load without errors", function()
        local success, err = pcall(function()
            local M = require("path.to.module")
            assert(M ~= nil)
        end)
        assert(success, "Load failed: " .. tostring(err))
    end)
end)