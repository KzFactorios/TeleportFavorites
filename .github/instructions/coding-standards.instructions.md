---
description: "Use when writing, reviewing, or refactoring any Lua file in the TeleportFavorites mod. Covers EmmyLua annotations, class patterns, GUI element naming, storage-as-source-of-truth, drag-drop algorithm, Factorio-specific patterns, and sprite usage rules."
applyTo: "**/*.lua"
---
# TeleportFavorites Lua Coding Standards

## EmmyLua Annotation Requirements
All classes, fields, and methods must be annotated for strictness and IDE support. Use `---@class`, `---@field`, `---@param`, and `---@return` for documentation and static analysis. See `core/types/factorio.emmy.lua` for Factorio runtime types and type aliases.

## Helper/Module Structure & Circular Dependency Policy
- All require statements must be at the very top of each file (lines 1-10), ordered alphabetically, before any logic or function definitions.
- **Circular Dependencies** — two options:
  1. **PREFERRED**: Refactor shared logic into a third, dependency-free helper module (see `core/utils/basic_helpers.lua`)
  2. **ONLY IF REFACTORING IS NOT VIABLE**: Use lazy-loading pattern (declare module as `nil` at module level, load on first function call)
- Helper modules must not depend on higher-level modules. Move shared helpers to lower-level, dependency-free modules.

## GUI Element Naming Convention
All interactive and structural GUI element names must be prefixed with their GUI/module context:
`{gui_context}_{purpose}_{type}` — e.g., `tag_editor_move_button`, `fave_bar_slot_button_1`.
Update all event handler checks and variable references when refactoring.

## No Leading Underscores for Private Fields
Use `chart_tag` not `_chart_tag` for private or internal fields in classes.

## Comment Policy
Prefer self-documenting code — clear naming over inline explanation. Add comments only to:
- Explain quirky or non-obvious Factorio API behavior (e.g. why `LuaCustomChartTag` cannot be stored in `storage`)
- Explain intentional workarounds or create-then-validate patterns
- Mark deliberate architectural decisions that might otherwise look like mistakes
Do not add comments that restate what the code already clearly expresses.

## Module Size
Target ~200 lines per file. When a module grows beyond this, split at logical boundaries — not at an arbitrary line count. Keep cohesive logic together even if it means exceeding 200 lines. Prefer a slightly larger file over a split that separates tightly related functions.

## Error Handling and Logging
- **`pcall`**: Acceptable as a short-term fix, but expensive. Plan to eliminate `pcall` wrappers in optimization passes once the happy path is well understood. Never use `pcall` to suppress an error you could have prevented with a validity check.
- **`error()` / `assert()`**: Use for genuine programming errors — unexpected nil, violated invariants, states that should never occur.
- **Validity checks**: Always prefer explicit guards (`if not player or not player.valid then return end`) over wrapping in `pcall`.
- **Logging**: Use `ErrorHandler` for all logging. Route by level: `debug_log` for development detail, `warn_log` for recoverable issues, `error_log` for runtime failures displayed to the player in standard Factorio fashion. In production builds, logging output should be near-zero — debug and info calls must be gated by log level. Runtime errors that reach the player should use Factorio's standard error display mechanism.
All code contributions must be free of syntax errors, runtime errors, and Factorio data-stage errors before being applied. Fix immediately on detection.

## Paradigms and Patterns
- **Class-based OOP**: Idiomatic Lua class patterns with strict EmmyLua annotations.
- **Design Patterns**: Adapter, Facade, Proxy, Singleton, Observer, Builder, Command, Strategy, Composite.
- **Surface Awareness**: All helpers and accessors must be surface-aware and multiplayer-safe.
- **Event-driven Architecture**: Use Factorio's event system for initialization, surface management, and runtime cache handling. Register event handlers in `control.lua`.
- **Persistent vs. Runtime Data**: Persistent data → `core/cache` module → `storage`. Runtime-only data → `core/cache/lookups.lua`.
- **Shared Tag Mutation Helper**: Always use `Tag.update_gps_and_surface_mapping(old_gps, new_gps, chart_tag, player, preserve_owner_name)` for chart tag position changes.
- **Validation Helpers**: Use `BasicHelpers.is_valid_player(player)` and `BasicHelpers.is_valid_element(element)` for all validity checks. There is no `SafeHelpers` module — it does not exist.

## Vanilla Factorio Utility Sprite Usage
✅ Allowed:
- `utility/list_view`, `utility/close`, `utility/refresh`, `utility/arrow-up`, `utility/arrow-down`, `utility/arrow-left`, `utility/arrow-right`

❌ Do NOT use — these do NOT exist in vanilla Factorio and will cause exceptions:
- `utility/minus`, `utility/plus`, `utility/remove`, `utility/add`, `utility/tab_icon`, `utility/up_arrow`, `utility/down_arrow`

## Commit & Review Process
- Lint before commit; run `.\.test.ps1` before submitting
- Document all changes in `.project/` docs for significant decisions

## Storage as Source of Truth
```lua
-- ❌ NEVER read from GUI
local text = element.text

-- ✅ ALWAYS read from storage
local tag_data = Cache.get_tag_editor_data(player)
local text = tag_data.text
```

## Function Structure
- All functions must be top-level (never nested inside other functions)
- Match every `function` with corresponding `end` at same indentation
- Use `:` for method calls, `.` for property access

## GUI Development
- Use `GuiElementBuilders` for consistent element creation
- Follow **storage-first** pattern: save immediately on input, read from storage for logic
- Tag editor state stored in `cache.players[index].tag_editor_data`
- Favorites bar state in `cache.players[index].surfaces[surface].favorites`

## Drag-Drop Algorithm (`DragDropUtils.reorder_slots`)
The favorites bar uses a custom **blank-seeking cascade algorithm**:

**Special Cases:**
- **Move to blank**: Direct swap with no cascade
- **Adjacent slots**: Simple swap operation
- **Locked slots**: Cannot be source, destination, or cascade targets

**Cascade Algorithm (Non-Adjacent, Non-Blank):**
1. Source slot becomes blank immediately
2. Search between source and destination for existing blank slots
3. Items shift toward the newly-created blank at source position
4. Source item placed at destination, displacing what was there
5. Displaced items flow into available blanks (natural compaction)

**Returns**: `(modified_slots, success, error_message)` tuple. Creates a deep copy. Respects locked slot boundaries throughout cascade.

## Factorio-Specific Patterns

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
```lua
storage.players[player_index].surfaces[surface_index].favorites
storage.surfaces[surface_index].tags[gps_string]
```

### Tick Handlers
Never use `script.on_event(defines.events.on_tick, ...)` for non-critical work. Use `script.on_nth_tick(N, ...)` with an appropriate interval (minimum 2). Register handlers permanently at startup — do not register/deregister dynamically. Unconditional `on_tick(1)` is the primary cause of UPS spikes in this mod.


