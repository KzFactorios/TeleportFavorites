# TeleportFavorites – Architecture

## Overview
This document describes the architecture of the TeleportFavorites mod, including its modular structure, data flow, and key design patterns. It is intended to help developers understand how the mod is organized and how its components interact.

---

## Require Statements Policy
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

## Module Breakdown
- All modules should use a class paradigm. Use emmylua definitions to achieve this goal. Store external type in the core/types folder
- `core/cache/` – Persistent data cache, schema, init methods and helpers.
- `core/control/` – Lifecycle, event, and utility modules. Top-level event handlers are now split into extension modules (see `control_fave_bar.lua`, `control_tag_editor.lua`, `control_data_viewer.lua`).
- `core/pattern/` – eg: Observer, singleton, etc modules. Base files to handle design pattern logic
- `core/tag/sync.lua` – tag synchronization and migration logic.
- `core/types/` – for external type definitions
- `core/utils/` – will hold a variety of helper files
- `core/utils/version.lua` – a utility file to record the version information
    from the info.json file to make the version number readily available
    to the codebase. It is created and updated by update_version.py
- `core/favorite.lua` – Favorite object logic and helpers.
- `core/tag.lua` – Map tag object logic and helpers.
- `core/error_handling.lua` – Centralizes error handling and displying the information to the user and/or logging to the correct files
- `gui/` – GUI modules for favorite bar, tag editor, and cache viewer.
- `core/gps.lua` - used for helper file for gps conversion to a map position and vice versa. Includes any helper methods related to gps

---

## Data Flow
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
