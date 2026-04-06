title: "TeleportFavorites Coding Standards"
description: "Strict Lua patterns and Factorio 2.0 API usage"
applyTo: "**/*.lua"


# TeleportFavorites: Lua Coding Standards (v2.0+)

## 1. STRUCTURE & DEPENDENCIES

Note: For global policies such as `require()` placement, no-hoisting, and other contributor policies, see `.github/copilot-instructions.md`.

- **Circulars**: 1. Refactor to `core/utils/basic_helpers.lua`. 2. Lazy-load via `if not M then M = require() end` ONLY if refactor fails.
-- **No Hoisting**: Declare all locals/functions before use. No nested functions.

## 2. NAMING & ANNOTATIONS
- **EmmyLua**: Mandatory `---@class`, `---@field`, `---@param`, `---@return`.
- **GUI Naming**: `tp_fav_{context}_{purpose}_{type}` (e.g., `tp_fav_bar_slot_button`).

## 3. DATA & PERSISTENCE
- **Source of Truth**: ALWAYS read from `storage`/`Cache`. NEVER read state from GUI elements.
- **GPS Format**: `"x.y.surface_index"` (e.g., `"100.200.1"`).
- **Refer to**: #.project/data_schema.md for table structures.

## 4. FACTORIO API & SAFETY
- **Validity**: Use `BasicHelpers.is_valid_player(p)` or `if not p.valid then`. 
- **Teleport/Tags**: Use `Tag.update_gps_and_surface_mapping` for moves. 
- **Tick Handlers**: Use `on_nth_tick(N, ...)` (N >= 2). NEVER use `on_tick(1)`.

## 5. GUI & DRAG-DROP
- **Builders**: Use `GuiElementBuilders`.
- **Drag-Drop**: Use `DragDropUtils.reorder_slots` (Blank-seeking cascade algorithm).