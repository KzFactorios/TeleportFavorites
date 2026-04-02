# 🛑 LUA FUNCTION/VARIABLE ORDERING NOTE

**Lua does NOT hoist function or variable declarations.**
- All functions, tables, and variables must be defined before they are referenced or used in the file.
- If you reference a function or table before its definition, you will get a runtime error (nil value).
- Always declare helper functions and handler tables at the top of the file, before any code that uses them.
- This is different from JavaScript, where function declarations are hoisted.

# 🚨 CRITICAL: FACTORIO REQUIRE STATEMENT RULES

**Factorio's runtime STRICTLY PROHIBITS `require()` calls inside functions or after module load time.**

When you see the error: `"Require can't be used outside of control.lua parsing"` - this means you placed a `require()` call inside a function, event handler, or anywhere other than the top-level module scope.

## ✅ CORRECT Pattern (Module-Level Requires):
```lua
-- ✅ ALL requires at the very top, before any logic
local Cache = require("core.cache.cache")
local PlayerHelpers = require("core.utils.player_helpers")
local ErrorHandler = require("core.utils.error_handler")

---@class MyModule
local MyModule = {}

function MyModule.some_function()
  -- Use already-loaded modules here
  ErrorHandler.debug_log("Message")
  local data = Cache.get_something()
end

return MyModule
```

## ❌ FORBIDDEN Pattern (Runtime Requires):
```lua
-- ❌ NEVER EVER DO THIS - Will cause "Require can't be used outside of control.lua parsing"
function MyModule.some_function()
  local ErrorHandler = require("core.utils.error_handler")  -- FORBIDDEN!
  ErrorHandler.debug_log("Message")
end

function MyModule.log(level, message, data)
  local ErrorHandler = require("core.utils.error_handler")  -- FORBIDDEN!
end
```

## 🔄 Circular Dependency Exception (Lazy Loading):
**ONLY use this pattern when you have a genuine circular dependency that cannot be refactored:**

```lua
-- Declare as nil at module level
local CircularModule = nil

local OtherModule = require("some.other.module")

---@class MyModule
local MyModule = {}

function MyModule.function_that_needs_circular()
  -- Lazy-load ONLY on first call to break circular dependency
  if not CircularModule then
    CircularModule = require("module.that.requires.me")
  end
  
  CircularModule.do_something()
end

return MyModule
```

**When to use lazy loading:**
- ✅ Genuine circular dependency (A requires B, B requires A)
- ✅ Module is only used in runtime functions (never in module initialization)
- ✅ You've verified refactoring into a third module is not viable

**When NOT to use lazy loading:**
- ❌ "Convenience" - just because a module is only used in one function
- ❌ To avoid thinking about module organization
- ❌ Any non-circular dependency scenario

## 🔍 How to Detect Your Mistake:

**If you see this error:**
```
__ModName__/path/to/file.lua:XX: Require can't be used outside of control.lua parsing.
```

**Check the line number - you will find:**
1. A `require()` call inside a function body
2. A `require()` call inside an if statement or loop
3. A `require()` call anywhere other than the top-level of the file

**Fix by:**
1. Move the `require()` to the top of the file (line 1-10, before any logic)
2. Order alphabetically with other requires
3. If you get a circular dependency error, use the lazy loading pattern above

# IMPORTANT: All code, API usage, and modding guidance in this project MUST target Factorio v2.0+ and above. Do not use deprecated or legacy patterns from earlier versions. Always verify compatibility and reference the v2.0+ documentation for all features, prototypes, and runtime logic.
# TeleportFavorites Factorio Mod — AI Agent Instructions

## 🎯 PROJECT OVERVIEW

TeleportFavorites is a **multiplayer-safe Factorio mod** that enables instant teleportation to favorite locations via map tags. Key features:

## 🏗️ ARCHITECTURE QUICK START

### Module Structure
```
core/
├── cache/           # Data persistence (storage.players, storage.surfaces)
├── control/         # GUI controllers & lifecycle management  
├── events/          # Event handlers & dispatcher patterns
├── favorite/        # Favorite object logic & player favorite management
├── tag/             # Map tag objects & synchronization
├── teleport/        # Teleportation logic & history
└── utils/           # Helper modules (GPS, validation, GUI builders)

gui/
├── favorites_bar/   # Top-screen favorites bar interface
└── tag_editor/      # Right-click map tag creation/editing

prototypes/          # Factorio data-stage definitions
tests/              # Custom test framework with smoke testing
```

### Data Flow Pattern
**User Input** → **Event Handler** → **Storage Update** → **GUI Refresh**
- All persistent data flows through `core/cache/cache.lua`
- Surface-aware data management for multiplayer compatibility

## 🛡️ CODING STANDARDS & BEST PRACTICES (STRICT)
See `.github/instructions/coding-standards.instructions.md` for full Lua coding standards (EmmyLua annotations, GUI naming, sprite usage, storage patterns, drag-drop algorithm, Factorio-specific patterns).

## 🔧 DEVELOPMENT WORKFLOW

### Testing
```powershell
.\.test.ps1    # Run full test suite
```

### Shell Commands (PowerShell on Windows)
- Use `;` for chaining (NOT `&&`). Use `Get-ChildItem`/`Select-String`/`Where-Object` (NOT Unix commands).
- Save script output before piping: `.\.test.ps1 > out.txt 2>&1; Get-Content out.txt -Tail 20; Remove-Item out.txt`
- See `.github/instructions/powershell.instructions.md` for full antipatterns reference.

## 📋 ACTIVE TASKS
Before starting any implementation work, read `.project/TODO.md` for outstanding tasks.

## 📚 KEY DOCUMENTATION REFERENCES

**ALWAYS check these before making changes:**
- `.project/TODO.md` - Outstanding tasks and technical debt
- `.project/architecture.md` - Overall system design & patterns
- `.project/data_schema.md` - Storage structure & data relationships  
- `.project/coding_standards.md` - Critical rules & "storage as source of truth"
- `.project/game_rules.md` - Multiplayer permissions & tag ownership
- `tests/docs/README.md` - Test execution & framework usage


## 🚨 FACTORIO API ESSENTIALS (v2.0+)

### Syntax Rules (v2.0+)
```lua
surface:get_tile(position)      # Method calls with ':'
chart_tag.position             # Property access with '.'
player.force:add_chart_tag()   # Chain method calls properly
```

### Common Validations (v2.0+)
```lua
if not player or not player.valid then return end
if not chart_tag or not chart_tag.valid then return end  
if not surface or not surface.valid then return end
```

### Event Registration Pattern
```lua
-- Via event_registration_dispatcher.lua
script.on_event(defines.events.on_gui_click, handlers.on_gui_click)
script.on_event(defines.events.on_chart_tag_added, handlers.on_chart_tag_added)
```

---

*This is a multiplayer-safe Factorio mod with complex GUI interactions. When in doubt, prioritize data consistency and player safety over convenience features.*
## 💡 DEVELOPMENT TIPS

### Quick Problem Solving
- **Read the error**: Factorio provides detailed error messages with stack traces
- **Check storage first**: Most issues stem from incorrect data access patterns
- **Validate inputs**: Always check player/element validity before operations
- **Use the cache**: Never access `storage` directly - use `Cache.*` methods

### Common Patterns
```lua
-- Safe player operations
local function safe_operation(player)
  if not player or not player.valid then return end
  -- ... your code here
end

-- Error handling pattern
local function handle_input(input)
  if not input then return end  -- Graceful nil handling
  -- ... process input
end

-- Event handler template  
local function on_some_event(event)
  local player = game.players[event.player_index]
  if not player or not player.valid then return end
  
  -- Read from storage
  local data = Cache.get_some_data(player)
  
  -- Update storage
  data.field = new_value
  Cache.set_some_data(player, data)
  
  -- Optional: refresh UI
  refresh_ui_if_needed(player)
end
```

### Best Practices
- **Start simple**: Get basic functionality working before adding complexity
- **Test incrementally**: Use the test suite to catch regressions early
- **Document decisions**: Update `.project/` docs for significant changes
- **Follow the patterns**: Consistency is key to maintainability

---

*Remember: This mod prioritizes multiplayer safety and data consistency. When in doubt, choose the more conservative approach that preserves data integrity.*
