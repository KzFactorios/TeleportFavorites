# TeleportFavorites – Performance Patterns

Documents the caching strategies and performance-critical patterns established in this codebase. Follow these when writing new code that touches GUI updates, storage access, or tick handlers.

---

## Coalescing Dirty-Player Set (`_dirty_players`)

**Where:** `core/events/gui_observer.lua` — `GuiEventBus`

**Problem:** Multiple events in a single tick (e.g. tag deleted + favorite removed) would previously enqueue multiple GUI update jobs for the same player, causing redundant redraws.

**Solution:** `_dirty_players` is a set (`{ [player_index] = true }`) rather than a queue. Any number of `notify()` calls for the same player within a tick collapses into one entry. `process_deferred_notifications()` iterates the set once per tick, redraws each dirty player's GUI once, then clears the set.

```lua
-- notify: mark player dirty (idempotent)
GuiEventBus._dirty_players[player_index] = true

-- process: one redraw per player per tick
for player_index in pairs(GuiEventBus._dirty_players) do
    -- redraw GUI for player
end
GuiEventBus._dirty_players = {}
```

---

## O(1) GPS Lookup Cache (`Lookups`)

**Where:** `core/cache/lookups.lua` — `_G["Lookups"]`

**Problem:** Finding a `LuaCustomChartTag` by GPS position requires iterating all tags on a surface — O(n) per lookup.

**Solution:** A runtime-only mirror table maps `gps_string → LuaCustomChartTag` for each surface. Built at startup via `warm_surface_gps_map()`, updated incrementally on tag add/move/remove events.

```lua
-- O(1) lookup
local chart_tag = Lookups.get_chart_tag_by_gps(gps, surface_index)

-- Never iterate storage.surfaces[i].tags for a single-tag lookup
```

**Important:** `LuaCustomChartTag` is userdata and cannot be stored in `storage` (causes multiplayer desyncs). It lives only in `_G["Lookups"]`, which is rebuilt after `on_load`.

---

## Warm Cache at Startup

**Where:** `core/cache/cache.lua` — called from `on_init` / `on_load` / `on_configuration_changed`

**Problem:** Runtime caches (`_G["Lookups"]`) are not persisted. They must be rebuilt on every load.

**Solution:** `warm_surface_gps_map(surface)` pre-builds the GPS → chart_tag map for each surface by iterating all tags once at startup. Subsequent runtime lookups are O(1).

```lua
-- Called at startup for each surface
Cache.warm_surface_gps_map(surface)
```

---

## Settings TTL Cache

**Where:** `core/cache/settings.lua`

**Problem:** `settings.get_player_settings(player)` is called frequently (on every GUI event). Reading player settings through the Factorio API on every call adds measurable overhead at scale.

**Solution:** Settings are cached per-player with a TTL. The cache is invalidated on `on_runtime_mod_setting_changed`. During normal gameplay, settings reads hit the cache, not the API.

---

## `on_nth_tick` over `on_tick`

**Where:** All tick-based handlers in `core/events/event_registration_dispatcher.lua`

**Rule:** Never register `script.on_event(defines.events.on_tick, ...)` for non-critical periodic work. Use `script.on_nth_tick(N, handler)` with the minimum N that satisfies the use case (minimum 2).

**Rationale:** `on_tick(1)` fires 60 times per second. Even an empty handler adds overhead. The GUI dirty-player flush runs on `on_nth_tick(2)`, halving handler invocations with no perceptible latency.

```lua
-- Correct
script.on_nth_tick(2, function(event)
    GuiEventBus.process_deferred_notifications()
end)

-- Never do this for non-critical work
script.on_event(defines.events.on_tick, function(event)
    GuiEventBus.process_deferred_notifications()
end)
```

Tick handlers must be registered permanently at startup. Do not register/deregister dynamically — that pattern caused the duplicate-handler UPS spike.

---

## Build-Once, Read-Many Iteration

When a derived data structure is needed repeatedly, compute it once at cache-build time rather than re-computing on each access.

- Surface tag maps are built once in `warm_surface_gps_map`, not on each lookup.
- Player favorites arrays are materialized from storage once per GUI refresh cycle, not re-filtered on each slot render.

Avoid patterns that iterate `storage` inside tight loops or GUI render paths.

---

## Startup Render Snapshot (Favorites Bar)

**Where:** `core/cache/cache.lua`, `gui/favorites_bar/fave_bar.lua`

**Problem:** Startup hydration of favorites slots can trigger chart-tag lookup and rehydration work before first paint, causing visible bar population delay and init spikes.

**Solution:** Persist a lightweight per-slot render snapshot (gps, locked, icon, text) in player surface storage during full rehydration passes, then use snapshot data for startup slot hydration first. Slots without valid snapshot entries fall back to normal runtime rehydration.

```lua
-- Snapshot read (startup)
local snapshot = Cache.get_favorites_render_snapshot(player, surface_index, max_slots)

-- Snapshot write (full rehydration path)
surface_data.favorites_render_snapshot = snapshot
```

**Rules:**
- Snapshot entries must stay userdata-free (no `LuaCustomChartTag` in storage).
- Startup code must treat snapshot as a fast-path hint, not source of truth.
- Missing or stale snapshot entries must always fall back to runtime rehydration.
- Keep chart-tag update paths invalidating/rebuilding runtime cache as usual; snapshot does not replace correctness paths.
