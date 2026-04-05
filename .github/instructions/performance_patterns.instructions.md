---
name: "TeleportFavorites Performance Patterns"
description: "Caching strategies, O(1) lookups, and tick optimization"
applyTo: "core/events/**/*.lua, core/cache/**/*.lua, **/*.lua"
---
# TeleportFavorites: Performance & Optimization

## 1. GUI THROTTLING (Dirty-Player Set)
- **Problem**: Redundant redraws from multiple events in one tick.
- **Pattern**: Use `GuiEventBus._dirty_players = { [player_index] = true }`.
- **Execution**: `notify()` marks a player dirty (idempotent). `process_deferred_notifications()` iterates the set ONCE per tick via `on_nth_tick(2)`.

## 2. O(1) LOOKUP STRATEGY
- **Rule**: NEVER iterate `storage.surfaces[i].tags` to find a single tag.
- **Lookup**: Use `_G["Lookups"].get_chart_tag_by_gps(gps, s_idx)`.
- **Lifecycle**: Rebuild this runtime-only map during `on_load`/`on_init` via `warm_surface_gps_map(surface)`.

## 3. TICK HANDLER RULES (STRICT)
- **Forbidden**: `script.on_event(defines.events.on_tick, ...)` for periodic work.
- **Mandatory**: Use `script.on_nth_tick(N, handler)` where `N >= 2`.
- **Registration**: Register handlers PERMANENTLY at startup. NEVER register/deregister dynamically at runtime.

## 4. CACHING & LATENCY
- **Settings**: Use the Settings TTL cache in `core/cache/settings.lua` instead of calling the Factorio API `get_player_settings` inside loops.
- **Render Snapshots**: For the Favorites Bar, use `Cache.get_favorites_render_snapshot` for instant startup hydration.
- **Fallback**: Snapshots are "hints." If invalid/missing, fall back to full runtime rehydration.

## 5. ITERATION PRINCIPLE
- **Build-Once, Read-Many**: Compute derived data (like surface maps) at cache-build time. 
- Avoid iterating `storage` tables inside GUI render paths or tight loops.