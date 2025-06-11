# Source of Truth for Factorio Modding

The following resources are considered the absolute source of truth for all Factorio modding, development, and API usage in this codebase. All design decisions, code implementations, and documentation should reference these sources for canonical answers to Factorio's runtime, data, and GUI APIs.

## 1. Factorio Lua API Documentation

- **URL:** https://lua-api.factorio.com/latest
- **Purpose:** The official, always up-to-date API reference for the Factorio modding environment. Includes all classes, prototypes, events, and scripting interfaces.  
- **Usage:** Consult for every question regarding accessible objects, methods, events, persistent data, GUI construction, mod lifecycle, and serialization rules.

## 2. Factorio Data Definitions

- **URL:** https://github.com/wube/factorio-data
- **Purpose:** The canonical repository for all vanilla game data, including prototypes, GUI style definitions, item/entity specs, and core mod files.  
- **Usage:** Reference for vanilla style definitions, entity/item IDs, default values, GUI layouts, and any mod that intends to match or extend the vanilla Factorio experience.

---

## TeleportFavorites Mod: Storage as Source of Truth

### Core Principle

**Storage is the single source of truth for all GUI state.** GUI elements are never read from - they only display data from storage and immediately save changes back to storage.

### Implementation Pattern

1. **User Input** → **Immediate Storage Save** → **UI Refresh from Storage**
2. **Never read from GUI elements** - always read from stored data
3. **UI elements are write-only displays** of stored state
4. **All validation and logic** operates on stored data, not GUI state

### Tag Editor Example

```lua
-- ❌ WRONG: Reading from GUI elements
local text = element.text
local icon = icon_button.elem_value

-- ✅ CORRECT: Reading from storage
local text = tag_data.text
local icon = tag_data.icon

-- ❌ WRONG: Collecting state from UI on action
local state = collect_gui_state()
handle_action(state)

-- ✅ CORRECT: Immediate save on change, use storage on action
-- On text change:
tag_data.text = element.text
Cache.set_tag_editor_data(player, tag_data)

-- On action:
local text = tag_data.text  -- Always current from storage
```

### Benefits

- **Eliminates sync issues** between GUI and data
- **Prevents nil errors** from missing GUI elements  
- **Immediate persistence** of user changes
- **Reliable state management** in multiplayer environments
- **Simpler debugging** - single source of truth
- **Event-driven updates** - storage changes drive UI updates

### Event Flow

1. **Text Input Change** → `on_gui_text_changed` → Save to `tag_editor_data` immediately
2. **Icon Selection** → `on_gui_elem_changed` → Save to `tag_editor_data` immediately
3. **Button Click** → Load current `tag_editor_data` → Execute action using stored values
4. **UI Refresh** → Rebuild GUI from `tag_editor_data` values only

This pattern ensures storage and UI never get out of sync because UI elements never hold authoritative state.

---

## Policy

- All technical disputes or ambiguities in modding conventions, runtime object fields, GUI element options, or vanilla styles should be resolved by consulting these sources.
- When documenting or implementing features, always cite the relevant section of these sources when applicable.
- Keep these URLs in project documentation and as a quick reference in onboarding guides.

_Last updated: 2025-06-04_