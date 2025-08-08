# TeleportFavorites – Architecture
## Overview

---

## GUI Builder Pattern (Updated 2025-07-19)
All GUI modules use shared builder functions from `gui_base.lua` for consistent style and maintainability.

**GuiBase Builder Functions:**
```
GuiBase
├── create_frame(parent, name, direction, style)
├── create_button(parent, name, caption, style)
├── create_label(parent, name, caption, style)
├── create_sprite_button(parent, name, sprite, tooltip, style, enabled)
├── create_element(element_type, parent, opts)
├── create_hflow(parent, name, style)
├── create_vflow(parent, name, style)
├── create_flow(parent, name, direction, style)
├── create_draggable(parent, name)
├── create_titlebar(parent, name, close_button_name)
└── create_textbox(parent, name, text, style, icon_selector)
```
All builder functions use defensive checks and default styles for robust GUI creation. See `gui_base.lua` for details.
All require statements MUST be placed at the very top of each Lua file, before any function or logic.

Do NOT place require statements inside functions, event handlers, or conditional blocks.
This rule is enforced to prevent circular dependencies, recursion errors, and stack overflows (e.g., "too many C levels" errors).
If a circular dependency is encountered, refactor the code to break the cycle, but never move require inside a function as a workaround.
This is a strict project policy. All agents and contributors must follow it.
See also:

gui_base.lua for an example and rationale.
This policy applies to all Lua modules in the codebase.

---

## High-Level Structure
- **Persistent Data:** All persistent data is stored in `storage` and managed via the `core/cache` module.
- **Core Modules:** Handle tag/favorite logic, context, and multiplayer safety.
- **GUI Modules:** Provide user interfaces for managing favorites, tags, and settings.
- **Sync:** Ensures tag/favorite consistency across multiplayer and surfaces. Part of the tag folder
- **Lifecycle & Events:** Manage mod initialization, configuration changes, and event registration.

---

## Teleport History Modal Access (Hotkey)
- The Teleport History modal can be toggled at any time using the custom input Ctrl + Shift + T ("teleport_history-toggle").
- The toggle respects the per-player setting `enable_teleport_history`; when disabled, the toggle does nothing.
- The modal is non-blocking (not modal=true) and does not set `player.opened`; ESC doesn’t auto-close it. Use the close button or the toggle hotkey.

---

## Module Breakdown
### Shared Tag Mutation & Surface Mapping Helper (2025-07-19)
The helper `Tag.update_gps_and_surface_mapping(old_gps, new_gps, chart_tag, player)` centralizes all logic for moving tag data between GPS keys, updating tag objects, and synchronizing runtime lookup caches. This replaces inline logic in event handlers and ensures multiplayer and surface consistency. Always use this helper for chart tag position changes.
- All modules should use a class paradigm. Use emmylua definitions to achieve this goal. Store external type in the core/types folder
- `core/cache/` – Persistent data cache, schema, init methods and helpers.
- `core/control/` – Lifecycle, event, and utility modules. Top-level event handlers are now split into extension modules (see `control_fave_bar.lua`, `control_tag_editor.lua`).
- `core/pattern/` – eg: Observer, singleton, etc modules. Base files to handle design pattern logic
- `core/tag/sync.lua` – tag synchronization and migration logic.
- `core/types/` – for external type definitions
- `core/utils/` – will hold a variety of helper files
- Version information retrieved dynamically from Factorio API via `game.active_mods[script.mod_name]`
- `core/favorite.lua` – Favorite object logic and helpers.
- `core/tag.lua` – Map tag object logic and helpers.
- `core/error_handling.lua` – Centralizes error handling and displying the information to the user and/or logging to the correct files
- `gui/` – GUI modules for favorite bar, tag editor.
- `core/gps.lua` - used for helper file for gps conversion to a map position and vice versa. Includes any helper methods related to gps

---

## Data Flow

---

## Migration Note (2025-07-19)
Legacy teleport history stack migration now ensures unique timestamps for each migrated entry. During migration, each raw GPS string is converted to a `HistoryItem` object with a timestamp incremented by at least 1 second from the previous, guaranteeing uniqueness and correct chronological ordering. This logic is implemented in `core/cache/cache.lua` and uses the updated `HistoryItem.new(gps, timestamp)` constructor.
1. **Player Action:** Player interacts with the GUI or map.
2. **GUI/Event Handler:** Calls into core logic (e.g., add favorite, move tag). 
3. **Core Logic:** Updates persistent data in `storage` via `Cache`.
4. **sync tag:** Ensures multiplayer and surface consistency.
5. **GUI Update:** Observers update the GUI to reflect changes.

```
┌─────────────┐     ┌────────────────┐     ┌───────────────┐
│   Player    │     │  GUI/Event     │     │  Core Logic   │
│   Action    │────>│  Handler       │────>│  (via Cache)  │
└─────────────┘     └────────────────┘     └───────┬───────┘
                                                  │
┌─────────────┐     ┌────────────────┐     ┌──────▼────────┐
│    GUI      │     │    Observer    │     │   Tag Sync    │
│   Update    │<────│    Pattern     │<────│               │
└─────────────┘     └────────────────┘     └───────────────┘
```

---

## Key Patterns
- **Surface Awareness:** All helpers and accessors are surface-aware.
- **Observer Pattern:** Used for GUI updates and event notification.
- **Command Pattern:** Used for event handling.
- **Builder Pattern:** Used for constructing user-interfaces. In our case, the tag editor and the favorites bar.
- **Strategy Pattern:** Used for validation and error handling
- **Modularization:** Each concern (cache, GUI, tag sync, etc.) is in its own module.
- **Testability:** All logic is testable and covered by automated tests.

---

## Chart Tag Validation Pattern

### The Create-Then-Validate Problem

**Issue:** The Factorio API doesn't provide a comprehensive way to validate chart tag positions without actually creating the chart tag. Our `position_can_be_tagged()` function covers common validation cases:
- Player/force/surface existence
- Chunk charted status
- Water/space tile detection

**However**, the actual `LuaForce.add_chart_tag()` method may have additional internal validation that we cannot predict or replicate.

### Current Solution: Create-Then-Validate Pattern

```lua
-- Pattern used in normalize_landing_position():
local temp_chart_tag = player.force:add_chart_tag(player.surface, chart_tag_spec)
if not position_can_be_tagged(player, temp_chart_tag and temp_chart_tag.position or nil) then
  temp_chart_tag.destroy()
  temp_chart_tag = nil
end
```

**Rationale:**
1. Pre-validation with `position_can_be_tagged()` catches most invalid positions
2. Chart tag creation reveals any additional Factorio API restrictions
3. Immediate destruction minimizes resource waste
4. This ensures 100% compatibility with Factorio's internal validation

### Trade-offs:
- **Pro:** Guaranteed compatibility with all Factorio validation rules
- **Pro:** Catches edge cases we might not anticipate
- **Con:** Temporary resource allocation (chart tag creation/destruction)
- **Con:** Slightly less efficient than pure pre-validation

### When This Pattern is Used:
- `gps_helpers.lua`: `normalize_landing_position()` function
- Any location where chart tag viability must be absolutely certain
- Areas where position validation requirements may change between Factorio versions

**Note:** This pattern should be preserved unless a comprehensive Factorio API validation method becomes available.

---

## See Also
- `design_specs.md` – Project goals and feature overview.
- `data_schema.md` – Persistent data schema and structure.
- `coding_standards.md` – Coding conventions and best practices.
- `factorio_specs.md` – Notes regarding how factorio modding works
