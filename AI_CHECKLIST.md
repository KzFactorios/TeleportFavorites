# AI AGENT PRE-RESPONSE CHECKLIST
**⚠️ MANDATORY - CHECK BEFORE EVERY RESPONSE ⚠️**

## MY COMMITMENT:
I will apply this checklist rigorously BEFORE every response involving code changes.

## 1. READ BEFORE EDIT VALIDATION
- [ ] Did I use `read_file` to see current content BEFORE editing?
- [ ] Do I understand the existing code structure and context?
- [ ] Am I preserving existing formatting and style?

## 2. SYNTAX & FORMATTING VALIDATION
- [ ] Are there any merged comments with code (comment + code on same line)?
- [ ] Are all statements properly separated with newlines?
- [ ] Are multi-line strings properly formatted?
- [ ] Are all parentheses, brackets, and braces balanced?
- [ ] Example: `-- comment  local var = value` should be `-- comment\nlocal var = value`

## 3. STRING REPLACEMENT VALIDATION
- [ ] When using `replace_string_in_file`, did I include 3-5 lines of context before AND after?
- [ ] Is my `oldString` unique enough to match exactly once?
- [ ] Does my `oldString` preserve exact whitespace, indentation, and newlines?
- [ ] Am I NOT using `...existing code...` comments in `oldString`?

## 4. TERMINAL COMMANDS
- [ ] If using `run_in_terminal`, is this PowerShell?
- [ ] Am I using `;` instead of `&&` for command chaining?
- [ ] Are file paths properly quoted for Windows?
- [ ] Example: `cd "v:\path"; command` NOT `cd "v:\path" && command`

## 5. FACTORIO MOD CODE
- [ ] Are ALL `require()` statements at the top of files?
- [ ] Am I NEVER putting `require()` inside functions or event handlers?
- [ ] Am I using proper Factorio API syntax (`:` vs `.`)?
- [ ] Colon (`:`) for method calls: `surface:get_tile()`, `chart_tag:destroy()`
- [ ] Dot (`.`) for property access: `player.name`, `chart_tag.position`
- [ ] Use `GameHelpers.player_print()` NOT `player:print()` or `player.print()`

## 6. POST-EDIT VERIFICATION
- [ ] After editing, did I check for compile/syntax errors using `get_errors`?
- [ ] Did I verify the file still loads without runtime errors?
- [ ] Are all function calls and variable references valid?

## 7. CRITICAL VIOLATIONS TO AVOID
1. **NEVER**: `cd "path" && command` (bash syntax)
2. **ALWAYS**: `cd "path"; command` (PowerShell syntax)
3. **NEVER**: `require()` inside functions
4. **ALWAYS**: `require()` at file top
5. **NEVER**: `player.print()` or `player:print()` (wrong - use helper)
6. **ALWAYS**: `GameHelpers.player_print(player, message)` (standardized helper)
7. **NEVER**: `chart_tag:position` (wrong syntax)
8. **ALWAYS**: `chart_tag.position` (property access uses dot)
9. **NEVER**: Comments merged with code on same line
10. **ALWAYS**: Proper newline separation between comments and code

## 8. COMMON FORMATTING ERRORS TO AVOID
- **Merged comments**: `-- comment  local var = value`
- **Missing newlines**: `end  if condition then`
- **Malformed strings**: Missing quotes, improper escaping
- **Unbalanced brackets**: Missing closing `)`, `]`, `}`
- **Invalid require placement**: `require()` inside functions

## IF I VIOLATE THESE:
The user should respond with: "CRITICAL VIOLATION - CODING_STANDARDS.md rule [X]"


