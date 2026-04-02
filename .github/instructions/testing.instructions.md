---
description: "Use when writing, reviewing, or running tests in TeleportFavorites. Covers the smoke-testing philosophy, standard test patterns, and mock strategy."
applyTo: "tests/**"
---
# TeleportFavorites Testing Philosophy & Patterns

## Simplified Smoke Testing
Focus on **execution validation** over deep behavior testing. Verify modules load without errors and expose their expected API surface.

## Standard Test Pattern

```lua
require("test_bootstrap")
require("mocks.factorio_test_env")

describe("ModuleName", function()
    it("should load module without errors", function()
        local success, err = pcall(function()
            local Module = require("path.to.module")
            assert(Module ~= nil, "Module should load")
        end)
        assert(success, "Module should load without errors: " .. tostring(err))
    end)

    it("should expose expected API methods", function()
        local Module = require("path.to.module")
        assert(type(Module.method_name) == "function", "method should exist")
    end)
end)
```

## Mock Strategy
- Mock dependencies via `package.loaded["module.path"] = mock_table`
- Use `PlayerFavoritesMocks.mock_player(1, "TestPlayer", 1)` for player objects
- All tests in `tests/specs/*_spec.lua` with describe/it structure
- Focus on smoke testing: execution validation over behavior verification

## Running Tests
```powershell
.\.test.ps1    # Run full test suite (from workspace root)
```
