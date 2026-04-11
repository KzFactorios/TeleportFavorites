title: "TeleportFavorites Performance Patterns"
description: "Caching strategies, O(1) lookups, and tick optimization"
applyTo: "core/events/**/*.lua, core/cache/**/*.lua, **/*.lua"


# TeleportFavorites: Performance & Optimization

## Player expectations and the UPS overlay

Many players never read mod docs; they still judge quality using **Show-time (mod)** in the UPS overlay. Small recurring costs and spikes are **visible** and create support noise even when absolute milliseconds look low.

- Optimize for **low sustained mod time** and **avoidable spikes**: prefer targeted GUI updates (e.g. slot row refresh, single control updates) over `fave_bar.build(player, true)` when only a small part of state changed.
- **Periodic** work (`on_nth_tick`, sweeps, queues) should stay **bounded** and cheap when idle; new periodic logic should be reviewed for overlay impact.
- When changing [`event_registration_dispatcher.lua`](../../core/events/event_registration_dispatcher.lua), adding `on_nth_tick` periods, or hot GUI paths, **sanity-check** with the mod’s profiling commands (`/tf_profile_start` / `/tf_profile_stop` or project profiler) when practical—not as CI, but as author/reviewer habit. Treat **before/after mod time** as part of review for those changes, not only correctness.
- New **periodic** `script.on_nth_tick` registrations should include a **brief code comment** (period in ticks and purpose) at the registration site so future work does not stack cost blindly.

## 1. GUI THROTTLING (Dirty-Player Set)
- **Problem**: Redundant redraws from multiple events in one tick.
- **Pattern**: Use `GuiEventBus._dirty_players = { [player_index] = true }`.
- **Execution**: `notify()` marks a player dirty (idempotent). `process_deferred_notifications()` iterates the set ONCE per tick via `on_nth_tick(2)`.

## 2. O(1) LOOKUP STRATEGY
- **Rule**: NEVER iterate `storage.surfaces[i].tags` to find a single tag at runtime for resolve-by-GPS.
- **Lookup**: Use `Cache.Lookups.get_chart_tag_by_gps(gps)` (same as `_G.Lookups` in [core/cache/lookups.lua](core/cache/lookups.lua)). Session-local cache: `tags[tag_number]` plus reverse index `gps_to_tag_number[gps]`; misses use a bounded `find_chart_tags` query, then seed the cache.
- **Lifecycle**: `Lookups.init()` runs from `Cache.init()` on `on_init` / `on_load`. Entries are filled on demand and via `seed_chart_tag_in_cache`. **Not** persisted in `storage` (no save migration for this cache).
- **Validity**: Stale `LuaCustomChartTag` refs are pruned on a fixed interval via `script.on_nth_tick(Cache.Lookups.VALIDITY_SWEEP_TICKS, ...)` (registered in [core/events/event_registration_dispatcher.lua](core/events/event_registration_dispatcher.lua)); use direct `.valid` checks in hot paths, not `pcall` around `.valid`.

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