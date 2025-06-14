# CODING STANDARDS - TeleportFavorites Factorio Mod

## CRITICAL VIOLATIONS - NEVER DO THESE:

### ❌ NEVER USE REQUIRE() IN RUNTIME HANDLERS
```lua
-- ❌ WRONG - This will cause "Require can't be used outside of control.lua parsing" error
function some_event_handler(event)
    local MyModule = require("some.module")  -- NEVER DO THIS
end

-- ✅ CORRECT - All requires at top of file
local MyModule = require("some.module")  -- At top during parsing phase
function some_event_handler(event)
    -- Use MyModule here
end
```

### ❌ NEVER USE && IN POWERSHELL COMMANDS
```powershell
# ❌ WRONG - && is bash syntax, not PowerShell
cd "path" && some-command

# ✅ CORRECT - Use semicolon or separate commands
cd "path"; some-command
# OR
cd "path"
some-command
```

### ❌ NEVER CONFUSE DOT VS COLON IN FACTORIO API
```lua
-- ❌ WRONG - Using dot for method calls
surface.get_tile(pos)
chart_tag.destroy()

-- ❌ WRONG - Using colon for property access  
local name = player:name
local pos = chart_tag:position

-- ❌ WRONG - Direct player print calls
player.print("message")
player:print("message")

-- ✅ CORRECT - Colon for method calls (functions)
surface:get_tile(pos)
chart_tag:destroy()

-- ✅ CORRECT - Dot for property access (data)
local name = player.name
local pos = chart_tag.position
local valid = entity.valid

-- ✅ CORRECT - Use GameHelpers for player messages
GameHelpers.player_print(player, "message")
GameHelpers.player_print(player, {"locale.key"})
```

### ❌ NEVER MERGE COMMENTS WITH CODE
```lua
-- ❌ WRONG - Comment and code on same line without proper separation
-- Some comment  local variable = value

-- ❌ WRONG - Control flow merged with previous line
if condition then return end  -- Comment
while loop do something() end  if other_condition then

-- ❌ WRONG - Function calls merged
func1() func2()

-- ✅ CORRECT - Proper separation with newlines
-- Some comment
local variable = value

-- ✅ CORRECT - Control flow properly separated
if condition then 
    return 
end
-- Comment
if other_condition then
    -- code
end

-- ✅ CORRECT - Function calls on separate lines
func1()
func2()
```

## FACTORIO MOD RULES:

### Module Loading
- ALL `require()` statements MUST be at the top of files during parsing phase
- NEVER use `require()` inside functions, event handlers, or runtime code
- Use proper module architecture with explicit dependencies

### Event Handlers
- Event handlers are pure functions that receive event objects
- Always validate `player` objects with null checks
- Use `game.get_player(event.player_index)` pattern consistently

### Error Handling
- Wrap potentially failing operations in `pcall()`
- Log errors with descriptive context
- Provide user-friendly error messages

### Code Formatting & Syntax
- Always separate comments and code with proper newlines
- Never merge multiple statements on single lines
- Use consistent indentation (spaces or tabs, not mixed)
- Ensure balanced parentheses, brackets, and braces
- Validate syntax before committing changes

## AI AGENT EDITING PROTOCOLS:

### File Reading Before Editing
- ALWAYS use `read_file` to understand existing code structure
- Never make blind edits without context
- Preserve existing formatting patterns and style

### String Replacement Guidelines
- Use `replace_string_in_file` with 3-5 lines of context before and after
- Ensure `oldString` matches exactly (whitespace, indentation, newlines)
- Make `oldString` unique enough to avoid multiple matches
- NEVER use `...existing code...` comments in `oldString` parameter
- Test changes with `get_errors` tool after editing

### Post-Edit Validation
- Check for syntax errors immediately after editing
- Verify all function calls and variable references are valid
- Ensure proper require statement placement
- Validate Factorio API usage (dot vs colon notation)

## COMMUNICATION PROTOCOLS:

### When I Violate These Standards:
1. **Reference this file**: "This violates CODING_STANDARDS.md rule X"
2. **Use strong language**: "CRITICAL VIOLATION - fix immediately"
3. **Point to specific rule**: "See NEVER USE REQUIRE() IN RUNTIME HANDLERS"

### Command Syntax:
- **PowerShell**: Use `;` not `&&` for command chaining
- **File Paths**: Use absolute paths with proper quoting
- **Background processes**: Use appropriate PowerShell job syntax

## ARCHITECTURE PATTERNS:

### File Organization
- Keep all requires at file top
- Group related functionality
- Use clear module boundaries
- Avoid circular dependencies

### Factorio API Usage
- Use dot notation vs colon notation consistently
- Validate entity prototypes before use
- Handle invalid positions gracefully
- Use proper surface and player validation

## FACTORIO API SYNTAX RULES:

### Colon (:) - Method Calls (Functions)
```lua
-- Surface methods  
surface:get_tile(x, y)
surface:find_non_colliding_position(prototype, center, radius, precision)
surface:create_entity(spec)

-- Entity methods
entity:destroy()
chart_tag:destroy()
force:add_chart_tag(surface, spec)

-- GUI methods
element:destroy()
parent:add(spec)

-- NOTE: Use GameHelpers.player_print() instead of player:print()
```

### Dot (.) - Property Access (Data)
```lua
-- Player properties
local name = player.name
local index = player.index
local pos = player.position
local surface = player.surface

-- Chart tag properties
local position = chart_tag.position
local text = chart_tag.text
local icon = chart_tag.icon
local valid = chart_tag.valid

-- Surface properties
local name = surface.name
local index = surface.index

-- Event properties
local player_index = event.player_index
local tag = event.tag
```

### Memory Aid:
- **Colon (:)** = "Call" (methods/functions that DO something)
- **Dot (.)** = "Data" (properties that ARE something)

## 🚨 ENFORCEMENT PROTOCOL

### FOR AI AGENTS:
- **REFERENCE AI_CHECKLIST.md BEFORE EVERY RESPONSE**
- **MANDATORY**: Check terminal command syntax for PowerShell compatibility
- **MANDATORY**: Verify no `require()` statements in functions
- **MANDATORY**: Use `;` not `&&` in PowerShell commands

### VIOLATION RESPONSE PROTOCOL:
When AI agent violates these standards:

1. **User Response**: "CRITICAL VIOLATION - CODING_STANDARDS.md rule [SPECIFIC_RULE]"
2. **Required AI Action**: 
   - Acknowledge the violation
   - Reference this standards file
   - Correct the violation immediately
   - Confirm understanding of the rule

### COMMON VIOLATIONS:
1. **PowerShell Syntax**: Using `&&` instead of `;`
2. **Module Loading**: Putting `require()` inside functions
3. **Factorio API**: Wrong method call syntax

## TERMINAL COMMAND EXAMPLES:

### ❌ WRONG (Bash syntax):
```powershell
cd "v:\path" && some-command
```

### ✅ CORRECT (PowerShell syntax):
```powershell
cd "v:\path"; some-command
# OR
cd "v:\path"
some-command
```

### Player Message Helper Standard
```lua
-- ❌ WRONG - Direct player print calls
player:print("message")
player.print("message")

-- ✅ CORRECT - Use GameHelpers standardized function
GameHelpers.player_print(player, "message")
GameHelpers.player_print(player, {"locale.key"})
GameHelpers.player_print(player, {"locale.key", param1, param2})

-- Benefits of GameHelpers.player_print():
-- - Consistent error handling and validation
-- - Standardized locale support
-- - Better debugging and logging
-- - Centralized player communication logic
```
