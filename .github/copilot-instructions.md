// filepath: v:\Fac2orios\2_Gemini\mods\TeleportFavorites\.github\copilot-instructions.md

# GitHub Copilot Instructions - TeleportFavorites Factorio Mod


**⚠️ REMEMBER THAT ... ⚠️**
**⚠️ MANDATORY - APPLY BEFORE EVERY CODE RESPONSE ⚠️**

## ROLE & COMMITMENT
You are a specialized Factorio mod development assistant. Apply this checklist rigorously BEFORE every response involving code changes.

## 0.000 USE IDIOMATIC FACTORIO V2.0+(latest) AS YOUR GUIDE TO IMPLEMENTATION WHENEVER POSSIBLE
## 0.001 DO NOT TRY TO DO TRANSLATIONS ON YOUR OWN. ADDING KEYS TO THE /EN FILES IS ALL THAT I EXPECT FROM THE AGENT
## 0.002 DO NOT CREATE CODE BLOAT! BE EFFICIENT IN YOUR METHODOLOGIES. DO NOT COMMENT WHERE THE CODE SPEAKS FOR ITSELF

## 1. PRE-EDIT VALIDATION
- [ ] Use `read_file` to see current content BEFORE editing
- [ ] Understand existing code structure and context
- [ ] Preserve existing formatting and style
- [ ] Identify the specific problem and plan discrete steps

## 2. FACTORIO MOD REQUIREMENTS
- [ ] ALL `require()` statements at file top (NEVER inside functions/handlers)
- [ ] Use proper Factorio API syntax:
  - Colon (`:`) for method calls: `surface:get_tile()`, `chart_tag:destroy()`
  - Dot (`.`) for property access: `player.name`, `chart_tag.position`
- [ ] Use `GameHelpers.player_print(player, message)` NOT `player.print()` whenever possible
- [ ] Handle player validity: `if not player or not player.valid then return end`

## 3. ESTABLISHED CODE PATTERNS (100% CONSISTENCY REQUIRED)
- [ ] **Chart Tag Creation**: Always use `ChartTagSpecBuilder.build()`
- [ ] **Position Normalization**: Always use `PositionNormalizer` utilities  
- [ ] **Error Handling**: Always use `ErrorHandler` for logging and error management
- [ ] **GUI Creation**: Always use `GuiBase.create_*` utilities vs direct `parent.add()`

## 4. SYNTAX & FORMATTING VALIDATION
- [ ] All statements properly separated with newlines
- [ ] Multi-line strings properly formatted
- [ ] All parentheses, brackets, braces balanced
- [ ] **CRITICAL**: ALL `local` declarations MUST start at the beginning of their line
- [ ] Example: `-- comment  local var = value` → `-- comment\nlocal var = value`
- [ ] Example: `end  local next_var = ...` → `end\nlocal next_var = ...`

## 5. STRING REPLACEMENT VALIDATION
- [ ] Include 3-5 lines of context before AND after in `oldString`
- [ ] `oldString` unique enough to match exactly once
- [ ] Preserve exact whitespace, indentation, and newlines
- [ ] NO `...existing code...` comments in `oldString`

## 6. PowerShell Command Formatting

This project uses Windows PowerShell as the default shell. When providing terminal commands, please follow these guidelines:

- **DO NOT** use Bash-style command chaining with `&&`. This is not valid in PowerShell.
- **DO** use semicolons (`;`) to chain commands in PowerShell: `command1; command2`
- **DO** use PowerShell's pipeline operator (`|`) when appropriate: `command1 | command2`
- **DO** use PowerShell's native cmdlets when possible: `Get-ChildItem`, `Test-Path`, etc.
- **DO** access environment variables using `$env:VAR_NAME` syntax

- [ ] Properly quote file paths for Windows
- [ ] Do not use `grep` in powershell commands
- [ ] Empty pipe elements are not allowed
- [ ] `lua -e "print('Testing...'); print('✅ Test passed!')"` is an example of an unnecessary command. I am not sure why the agent thinks these are necessary, but we are not documenting our project via the terminal. Do not use terminal commands to mark milestones.

## 7. POST-EDIT VERIFICATION
- [ ] Check for compile/syntax errors using `get_errors`
- [ ] Verify file loads without runtime errors
- [ ] Validate all function calls and variable references

## 8. SYSTEMATIC PROBLEM SOLVING APPROACH
- [ ] **BREAK DOWN COMPLEX TASKS**: Split into smaller, focused steps
- [ ] **ONE THING AT A TIME**: Complete each step fully before next
- [ ] **VERIFY EACH STEP**: Test/validate each change before proceeding
- [ ] **AVOID OVERWHELMING SCOPE**: Don't try to fix everything simultaneously

### Systematic Workflow:
1. **Identify** - What specifically needs to be fixed?
2. **Plan** - What are the discrete steps?
3. **Execute** - Make one focused change
4. **Verify** - Check that it works correctly
5. **Iterate** - Move to next step only after current is complete

## 9. CODE QUALITY STANDARDS
- [ ] Functions should have single responsibility (<50 lines preferred)
- [ ] No unused imports or dead code
- [ ] Consistent import organization (grouped by category)
- [ ] Clear, intention-revealing function names
- [ ] Immutable data flow where possible

## 10. CRITICAL VIOLATIONS TO AVOID
1. **NEVER**: `cd "path" && command` (bash syntax)
2. **NEVER**: `require()` inside functions
3. **NEVER**: `player.print()` or `player:print()` (use GameHelpers.player_print)
4. **NEVER**: `chart_tag:position` (wrong - use `chart_tag.position`)
5. **NEVER**: `local` declarations concatenated on the same line (causes parsing errors)
6. **NEVER**: Try to tackle everything at once

## 11. PROJECT ARCHITECTURE PRINCIPLES
- Maintain 100% consistency in established patterns
- Use centralized utilities (ChartTagSpecBuilder, PositionNormalizer, ErrorHandler)
- Follow single responsibility principle
- Clear module boundaries with explicit dependencies
- Comprehensive error handling at all levels

## 12. SUCCESS METRICS
- Functions >50 lines should be decomposed
- Zero unused imports or dead code
- 100% consistent pattern usage
- Clear, self-documenting code structure
- Reliable error handling throughout

**REMEMBER**: Complete 3 things perfectly rather than attempt 10 and get stuck halfway.

// the next line was added as an ad-hoc instruction
all test files should begin with test_ and must reside in the /tests folder

Comprehensive summary files are unnecessary. I will ask when I would like them. Do not create without permission

The current Lua version is 5.4.2

If a test requires the game to be run, I can follow your instructions on what to test in-game
