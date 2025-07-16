# TeleportFavorites Factorio Mod — AI Agent Instructions

## 🎯 PROJECT OVERVIEW

TeleportFavorites is a **multiplayer-safe Factorio mod** that enables instant teleportation to favorite locations via map tags. Key features:
- **Favorites Bar**: 10-slot GUI for quick teleportation (accessible via hotkeys 1-0)
- **Map Tag Editor**: Right-click map interface for creating/editing teleportable tags
- **Drag & Drop**: Custom drag-drop system for favorite slot management
- **Multiplayer Safety**: Ownership-based tag editing with admin override capabilities

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
- Storage is the **single source of truth** - never read from GUI elements
- All persistent data flows through `core/cache/cache.lua`
- Surface-aware data management for multiplayer compatibility

## ⚠️ CRITICAL RULES (NON-NEGOTIABLE)

### 1. Require Statement Policy
```lua
-- ✅ ALWAYS at file top
local Cache = require("core.cache.cache")
local PlayerHelpers = require("core.utils.player_helpers")

-- ❌ NEVER inside functions, conditionals, or at file end
function some_function()
  local Module = require("some.module")  -- FORBIDDEN!
end
```

### 2. Storage as Source of Truth
```lua
-- ❌ NEVER read from GUI
local text = text_element.text

-- ✅ ALWAYS read from storage
local tag_data = Cache.get_tag_editor_data(player)
local text = tag_data.text
```

### 3. Function Structure
- All functions must be **top-level** (never nested inside other functions)
- Match every `function` with corresponding `end` at same indentation
- Use proper Factorio API syntax: `:` for methods, `.` for properties

## 🔧 DEVELOPMENT WORKFLOW

### Testing Commands (Universal - Work from Any Directory)
```powershell
# Run full test suite
.\.test.ps1        # PowerShell (recommended)
.test.bat         # Batch file  
lua .test.lua     # Direct Lua

# Check code line count (target: under 10,000 lines production code)
python .scripts\analyze_lua_lines.py
```

### PowerShell Environment Notes
**This project is developed on Windows with PowerShell as the default shell.** When generating terminal commands:
- Use PowerShell syntax: `Get-ChildItem`, `Select-Object`, `Where-Object` 
- NOT Unix commands: `ls`, `head`, `tail`, `grep`
- Use `Select-String` instead of `grep`
- Use `-First N` instead of `head -N`
- Use proper PowerShell pipe syntax and object handling

## ⚠️ COST EFFICIENCY AND COMMAND ACCURACY

**CRITICAL**: Misconfigured or erroneous commands cost money per request. The agent must stay vigilant and maintain accurate PowerShell command patterns. **If an antipattern is discovered that has not been documented, it MUST be documented in these instructions before using a corrected command.**

### PowerShell Anti-Patterns to Avoid

**❌ COMMON COMMAND FAILURES:**
```powershell
# BROKEN: Select-String with -A parameter (After context)
.\.test.ps1 | Select-String -Pattern "Total tests.*:" -A 2
# ERROR: "The input object cannot be bound to any parameters"

# BROKEN: Select-String with -A parameter on script output (After context lines)
.\.test.ps1 | Select-String -Pattern "Failed|Failures" -A 10
# ERROR: "The input object cannot be bound to any parameters for the command"

# BROKEN: Complex regex patterns in Select-String with pipeline from scripts
.\.test.ps1 | Select-String -Pattern "Failed|Total tests passed|Total tests failed" -Context 1
# ERROR: Parameter binding exceptions when script output contains objects

# BROKEN: Using Unix-style commands
ls -la | grep pattern
head -10 file.txt
tail -f log.txt

# BROKEN: Using Unix && operator for command chaining
.\.test.ps1 > test_output.txt 2>&1 && Get-Content test_output.txt
# ERROR: "The token '&&' is not a valid statement separator"

# BROKEN: Complex pipeline combinations with script output
.\.test.ps1 | Out-String | Select-String "Overall Test Summary" -A 10
# ERROR: Parameter binding exceptions due to object/string conversion issues

# BROKEN: Trying to pipe script objects directly to Select-String with context
(.\.test.ps1) | Select-String "Total tests" | Select-Object -Last 3
# ERROR: PowerShell treats script output as objects, not strings, causing binding failures

# BROKEN: Using lua -c for syntax checking (incorrect parameter)
lua -c tests\specs\drag_drop_utils_spec.lua
# ERROR: "-c" is not a valid parameter for lua.exe - shows usage help instead

# BROKEN: Mixing Unix dir command with PowerShell in complex pipelines  
Set-Location tests; dir /b "specs\*_spec.lua" | Select-String "drag_drop"
# ERROR: "dir /b" is cmd syntax, creates path confusion and pipeline errors in PowerShell
```

### File Organization Rules

**❌ NEVER place test-related files in root directory:**
- test_output.txt, test_output_latest.txt, debug_test_runner.lua, debug_vehicle_test.lua
- All test files belong in tests/ directory or subdirectories
- Root directory should only contain production mod files and essential config files

**✅ CORRECT file placement:**
- Production code: core/, gui/, prototypes/, graphics/
- Test files: tests/specs/, tests/output/, tests/mocks/
- Config files: .vscode/, .github/, .project/

**✅ CORRECT POWERSHELL PATTERNS:**
```powershell
# Use parentheses to force string output before piping
(.\.test.ps1) | Select-String -Pattern "pattern"

# Use Out-String to convert objects to strings
.\.test.ps1 | Out-String | Select-String -Pattern "Failed"

# Use PowerShell native cmdlets
Get-ChildItem -Recurse | Where-Object { $_.Name -match "pattern" }
Get-Content file.txt | Select-Object -First 10
Get-Content file.txt -Wait -Tail 10

# Use proper PowerShell operators for text replacement
(Get-Content "file.lua") -replace "old_pattern", "new_pattern" | Set-Content "file.lua"

# Use semicolon for command chaining (not &&)
.\.test.ps1 > test_output.txt 2>&1; Get-Content test_output.txt

# For test output, run tests separately then check results
.\.test.ps1
# Then check specific output files or use simpler commands
```

**❌ NEWLY DISCOVERED ANTIPATTERN:**
```powershell
# BROKEN: Incorrect path navigation in Get-ChildItem
Get-ChildItem "tests\specs\*_spec.lua"  # When already in tests directory
# ERROR: Looks for tests\tests\specs instead of specs

# BROKEN: PowerShell path confusion with relative directories
cd tests; Get-ChildItem "tests\specs\*_spec.lua" 
# ERROR: Double-nests the path when already in subdirectory

# BROKEN: Select-String with -A parameter on any script output (CONFIRMED ANTIPATTERN)
(.\.test.ps1) | Select-String "Overall Test Summary" -A 5
# ERROR: "The input object cannot be bound to any parameters for the command either because the command does not take pipeline input or the input and its properties do not match any of the parameters that take pipeline input"
# This fails because PowerShell script output creates objects, not strings, and Select-String -A parameter cannot bind to these objects
```

**✅ CORRECT POWERSHELL PATTERNS:**
```powershell
# Use proper relative paths based on current directory
Get-ChildItem "specs\*_spec.lua"  # When in tests directory  
Set-Location ..; Get-ChildItem "tests\specs\*_spec.lua"  # From subdirectory to root
Get-ChildItem -Path ".\specs\*_spec.lua"  # Explicit current directory

# Check for empty files correctly
Get-ChildItem "specs\*_spec.lua" | Where-Object { (Get-Content $_.FullName -Raw -ErrorAction SilentlyContinue).Trim() -eq "" }

# CORRECT: Avoid Select-String -A entirely with script output - use direct execution instead
.\.test.ps1                                    # Run script directly and read full output
.\.test.ps1 > output.txt; Get-Content output.txt -Tail 10  # Save output then read specific lines
.\.test.ps1 2>&1 | Tee-Object -FilePath "test_results.txt"  # Capture output to file while displaying

# For Lua syntax checking, use proper lua execution
lua -e "loadfile('tests\\specs\\drag_drop_utils_spec.lua')"  # Load and check syntax without execution
lua tests\specs\drag_drop_utils_spec.lua                     # Execute the file directly (if it's standalone)
Get-Content tests\specs\drag_drop_utils_spec.lua | lua       # Pipe file content to lua interpreter

# For file searches, use PowerShell native commands
Get-ChildItem "specs\*_spec.lua" | Where-Object { $_.Name -match "pattern" }
Get-ChildItem -Path ".\specs\*_spec.lua" -Filter "*drag_drop*"
```

### Key File Patterns
- **Entry Points**: `control.lua` (runtime), `data.lua` (data stage), `settings.lua` (mod settings)
- **Constants**: `constants.lua` - Central configuration values and limits
- **Cache Access**: Always use `Cache.get_*()` / `Cache.set_*()` - never access `storage` directly
- **Player Safety**: Use `PlayerHelpers.safe_player_print()` instead of `player.print()`
- **Validation**: Use `SafeHelpers.is_valid_player()` / `SafeHelpers.is_valid_element()`

### GUI Development
- Use `GuiElementBuilders` for consistent element creation
- Follow **storage-first** pattern: save immediately on input, read from storage for logic
- Tag editor state stored in `cache.players[index].tag_editor_data`
- Favorites bar state in `cache.players[index].surfaces[surface].favorites`

## 🎮 FACTORIO-SPECIFIC PATTERNS

### Chart Tag Ownership System
```lua
-- Only tag owner OR admin can edit
local can_edit = AdminUtils.can_edit_chart_tag(player, chart_tag)
-- Ownership tracked via chart_tag.last_user (player name string)
```

### GPS & Position Handling
```lua
-- GPS format: "x.y.surface_index" (e.g., "100.200.1")
local position = GPSUtils.map_position_from_gps(gps_string)
local gps = GPSUtils.gps_from_map_position(position, surface)
```

### Surface-Aware Data Management
All player data is organized by surface to handle multiple worlds:
```lua
storage.players[player_index].surfaces[surface_index].favorites
storage.surfaces[surface_index].tags[gps_string]
```

## 🧪 TESTING PHILOSOPHY

**Simplified Smoke Testing**: Focus on execution validation over deep behavior testing.

### Test Pattern (Standard)
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

### Mock Strategy
- Mock dependencies via `package.loaded["module.path"] = mock_table`
- Use `PlayerFavoritesMocks.mock_player(1, "TestPlayer", 1)` for player objects
- Focus on smoke testing: execution validation over behavior verification
- All tests in `tests/specs/*_spec.lua` with describe/it structure

## 📚 KEY DOCUMENTATION REFERENCES

**ALWAYS check these before making changes:**
- `.project/architecture.md` - Overall system design & patterns
- `.project/data_schema.md` - Storage structure & data relationships  
- `.project/coding_standards.md` - Critical rules & "storage as source of truth"
- `.project/game_rules.md` - Multiplayer permissions & tag ownership
- `tests/docs/README.md` - Test execution & framework usage

## 🚨 FACTORIO API ESSENTIALS

### Syntax Rules
```lua
surface:get_tile(position)      # Method calls with ':'
chart_tag.position             # Property access with '.'
player.force:add_chart_tag()   # Chain method calls properly
```

### Common Validations
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
