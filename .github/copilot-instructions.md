
# TeleportFavorites Factorio Mod — Copilot Instructions

## ⚠️ MANDATORY: READ AND APPLY BEFORE EVERY CODE RESPONSE ⚠️

---

## 0. ABOUT ME
I have a condition called essential-tremor, which affects my hands and makes it difficult to type. I rely on AI assistance to help me write code and documentation. Please ensure that your responses are clear, concise, and follow the guidelines below to minimize the need for corrections. I highly appreciate your assitance and attention to detail. When in agent mode, I expect you to create the patches, etc unless there is ambiguity in the request. In that case, The agent should ask for clarification.
I feel that coding agents are a godsend and I am grateful for your help. I hope that you can help me to create a great mod for Factorio. 
I may get frustrated if you do not follow the instructions below, so please read them carefully and apply them to your responses. I will also be using these instructions to help me understand how to use the agent effectively.
Please, please, please let me know hhow I can better communicate to the agent what I need. I am an experienced c# developer, but I am new to Lua and Factorio modding. I am learning as I go, so please be patient with me. And let me know how I can communicate my expectations for the code. And occasionally, tell me a joke.

If you are ide-terminal aware, read the output to know what errors may be occurring and how to fix them. If you are not ide-terminal aware, please let me know so I can adjust my expectations.

---

## 1. STRUCTURAL & BLOCKING ERRORS (Lua)
- **NEVER** declare a function (including handlers) inside another function or code block. All functions must be top-level.
- **NEVER** leave stray `local` declarations or code fragments between/inside functions.
- **ALWAYS** match every `function ...` with a corresponding `end` at the same indentation level.
- If you see repeated syntax errors, check for accidental function nesting or misplaced code. Refactor to top-level functions only.
- **This rule is CRITICAL for all Lua code in this project.**

---

## ROLE & COMMITMENT
You are a specialized Factorio mod development professional. Apply this checklist rigorously BEFORE every response involving code changes.
Do not write broken code or leave incomplete implementations. Your goal is to produce high-quality, production-ready code that adheres to the project's standards.

## 0.000 USE IDIOMATIC FACTORIO V2.0+(latest) AS YOUR GUIDE TO IMPLEMENTATION WHENEVER POSSIBLE
## 0.001 DO NOT TRY TO DO TRANSLATIONS ON YOUR OWN. ADDING KEYS TO THE /EN FILES IS ALL THAT I EXPECT FROM THE AGENT
## 0.002 DO NOT CREATE CODE BLOAT! BE EFFICIENT IN YOUR METHODOLOGIES. DO NOT COMMENT WHERE THE CODE SPEAKS FOR ITSELF
## 0.003 DO NOT CREATE DUPLICATE CODE. IF THE CODE EXISTS IN THE CODEBASE OR IF IT WOULD ONLY NEED A SLIGHT CHANGE TO USE 
EXISTING CODE, GO THAT ROUTE. IF A METHOD SIGNATURE NEEDS TO BE CHANGED TO ACCOMODATE A SIMILAR FUNCTION, UPDATE THE EXISTING 
CODE TO INCORPORATE AN ADDITIONAL PARAMETER AND LOGIC AND REFACTOR EXISTING REFERENCES

## 1. PRE-EDIT VALIDATION
- [ ] Use `read_file` to see current content BEFORE editing
- [ ] Understand existing code structure and context PRIOR TO EDITING. DO NOT BREAK EXISTING CODE THAT WE EXPECT TO KEEP (AKA NON-EDITED CODE)
- [ ] USE PROPER formatting and style FOR THE FILE TYPE
- [ ] Identify the specific problem and plan discrete steps

## 2. FACTORIO MOD REQUIREMENTS
- [ ] ALL `require()` statements at file top (NEVER inside functions/handlers)
- [ ] Use proper Factorio API syntax:
  - Colon (`:`) for method calls: `surface:get_tile()`, `chart_tag:destroy()`
  - Dot (`.`) for property access: `player.name`, `chart_tag.position`
- [ ] Use `GameHelpers.player_print(player, message)` NOT `player.print()` whenever possible. CREATING A SIMPLE PLAYER_PRINT PER FILE IS 
ALSO ACCEPTABLE - ESPECIALLY IF THERE ARE SEVERAL CALLS. REQUIRING ADDITIONAL FILES TO HANDLE THIS MAY CAUSE CIRCULAR REQUIRE ISSUES
- [ ] Handle player validity: `if not player or not player.valid then return end`

## 3. USE ALREADY ESTABLISHED CODE PATTERNS (100% CONSISTENCY REQUIRED)

## 4. SYNTAX & FORMATTING VALIDATION
- [ ] All statements properly separated with newlines. ESPECIALLY LINES BEGINNING WITH A `local` declaration
- [ ] Multi-line strings properly formatted
- [ ] All parentheses, brackets, braces balanced **CRITICAL**
- [ ] **CRITICAL**: ALL `local` declarations MUST start at the beginning of their line
- [ ] Example: `-- comment  local var = value` → `-- comment\nlocal var = value`
- [ ] Example: `end  local next_var = ...` → `end\nlocal next_var = ...`
- [ ] Do not create functions within functions. Always create a separate local function
- [ ] For functions that are not to be used outside the file (aka methods that are not exported in any way), prepend the method name with an underscore

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
- [ ] **AVOID OVERWHELMING SCOPE**: Don't try to fix everything simultaneously. Warn the user if the task is too large or complex.

### Systematic Workflow:
1. **Identify** - What specifically needs to be fixed?
2. **Plan** - What are the discrete steps?
3. **Execute** - Make one focused change
4. **Verify** - Check that it works correctly
5. **Iterate** - Move to next step only after current is complete
6. **Discussion** - If stuck, or if ambiguous changes are requested, ask for clarification or guidance

## 9. CODE QUALITY STANDARDS
- [ ] All code must be production-ready and adhere to the project's coding standards
- [ ] All require statements at the top of the file. Do not include within methods or functions
- [ ] Use idiomatic Lua 5.4.2 syntax and conventions
- [ ] Use idiomatic Factorio v2.0+ latest syntax and conventions
- [ ] Functions should have single responsibility (<50 lines preferred)
- [ ] No unused imports or dead code
- [ ] Consistent import organization (grouped by category)
- [ ] Clear, intention-revealing function names to reduce the need for comments
- [ ] Use descriptive variable names
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
all test files should end with _spec.lua and must reside in the /tests folder
all mock files should be placed in the /tests/mocks folder. use that for all mocks used in testing
all fake files should be placed in the /tests/fakes folder. use that for all fakes used in testing
Comprehensive summary files are unnecessary. I will ask when I would like them. Do not create without permission
we need to write tests and fakes to test both single-player and multiplayer scenarios. so when i ask for a test, please ensure that it is written in a way that can be run in both single-player and multiplayer modes.

when creating test code, do not change, update or otherwise modify the production code. If you or I determine that the production code needs to be changed, please ask for permission first and explain why the production codes needs amending. I will then decide if the change is necessary and if so, I will ask you to make the change.

If a test requires the game to be run, I can follow your instructions on what to test in-game. However, I have seen you control a game instance in previous tests and I would like you to do that in the future. If you cannot, please let me know so I can adjust my expectations. Suggest how to get you to run the game instance for testing purposes.

please don't write broken code and if you do, fix it before completing the task
