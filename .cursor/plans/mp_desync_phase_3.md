# Multiplayer desync — phase 3 (TeleportFavorites-attributed)

## Status

- **Phase 1 / 2:** Addressed common nondeterminism sources (stable `game.players` / `connected_players` iteration, sorted surfaces/tags ownership reset, tick deferrals, GUI observer slot merge order, lookup validity sweep order, etc.). See changelog under 0.0.98 and prior MP fixes.
- **Post–phase 2:** Desync still occurs immediately after `TryingToCatchUp` (e.g. reports on 2026-04-14 with varying `crcTick`).
- **Attribution (confirmed):** With **TeleportFavorites removed on both host and client**, **no desync**. With TF enabled, desync returns. Treat as **TF-caused** (or TF-triggered) until a narrower minimal repro says otherwise.

## Goal

Eliminate **catch-up / early-tick** multiplayer CRC failures with **TeleportFavorites enabled**, without regressing SP behavior or GUI responsiveness.

## Non-goals (for this phase)

- Rewriting large GUI subsystems unless bisection points at them.
- “Papering over” with client-only hacks that skip simulation on one peer.

## Working hypotheses (prioritized)

1. **Remaining nondeterministic ordering** — `pairs()` / undefined iteration on tables that influence **`storage`**, **script-global queues**, or **event side effects** in the first ticks after join (including paths not yet converted).
2. **Catch-up-only divergence** — code that behaves differently when the local peer is **joining vs. host**, or when `game.tick` is small, without using `script.is_simulation` / `is_server` incorrectly (audit for any such branches).
3. **One-shot registration / globals** — `script.on_nth_tick(1, …)` or other **dynamic** registration, `remote.add_interface`, `commands.add_command`, or mutation of **non-`storage`** globals that diverge between peers for the same tick.
4. **Side effects outside deterministic simulation** — `helpers.write_file`, profiler paths, or logging that accidentally touches **serialized** state (rare; verify profiler is off in MP repro).

## Investigation strategy

**Preference (current):** pursue **static audit** and **external tooling** first. **Do not** add temporary subsystem gating / compile-time no-op flags until explicitly revisited (see **Deferred** below).

### A. Static audit (primary for now)

- Grep: `pairs(`, `ipairs(`, `math.random`, `script.on_nth_tick%(1`, `remote%.`, `commands%.add`, `helpers.write_file`, `game%.print` in [`control.lua`](control.lua), [`core/events/event_registration_dispatcher.lua`](core/events/event_registration_dispatcher.lua), [`core/cache/`](core/cache/), [`gui/`](gui/).
- Trace **first tick after `on_load`**: [`control.lua`](control.lua) `custom_on_load` → [`handlers.on_load`](core/events/handlers.lua) → [`fave_bar.on_load_cleanup`](gui/favorites_bar/fave_bar_progressive.lua) / [`teleport_history_modal.on_load_cleanup`](gui/teleport_history_modal/teleport_history_modal.lua) / [`tag_editor.on_load_cleanup`](gui/tag_editor/tag_editor.lua) → dispatcher `on_tick` / `on_nth_tick(2)`.
- Confirm **no** `storage` mutation from **session-local flags** without matching writes on all peers (e.g. `_fave_bar_queue_has_work` must stay derived from `storage` only in `on_load_cleanup`).

### B. External tooling

- Use Factorio’s desync package compare workflow on **`level-heuristic-*`** / tagged snapshots if available, to see whether divergence is **Lua global** vs **entities** first.

### Deferred: subsystem bisection via temporary flags

**Implemented:** runtime-global mod setting **`tf-mp-bisect-mode`** (`none` | `no_fave_bar_queue` | `no_tag_editor` | `no_history_modal` | `no_lookups_sweep` | `no_chart_and_remote`). Map → Mod settings → Teleport Favorites — value must match on all peers. Code: [`core/utils/mp_bisect.lua`](core/utils/mp_bisect.lua), gates in [`event_registration_dispatcher.lua`](core/events/event_registration_dispatcher.lua), remote stubs in [`teleport_history.lua`](core/teleport/teleport_history.lua). Rejoin MP after each change; first mode that **stops** desync narrows the suspect layer.

## Likely code targets (after phase 2)

Re-audit these even if partially fixed; catch-up may exercise rare branches:

- [`core/events/event_registration_dispatcher.lua`](core/events/event_registration_dispatcher.lua) — full `on_tick` / `on_nth_tick(2)` bundle; `on_runtime_mod_setting_changed`; `ChartTagOwnershipManager`.
- [`core/control/control_tag_editor_core.lua`](core/control/control_tag_editor_core.lua) — `script.on_nth_tick(1, …)` confirm single-flight and identical on all peers.
- [`core/teleport/teleport_history.lua`](core/teleport/teleport_history.lua) — `remote.add_interface` timing.
- [`core/utils/profiler_export.lua`](core/utils/profiler_export.lua) — ensure MP repro uses **off** / no `storage` mutation on `on_load`.
- [`core/cache/cache.lua`](core/cache/cache.lua) / [`storage_migrations.lua`](core/cache/storage_migrations.lua) — any `pairs(storage.*)` migration touching multiple players in one tick without sort.

## Test / verification

- **MP smoke:** Host + 1 client, same mod zip, **matching** `Checksum for script __TeleportFavorites__/control.lua` in both logs; join **twice** (fresh client state).
- **Regression:** `.\.test.ps1 basic_helpers_spec` (and full suite when `gui_observer` cycle is addressed).
- **Success:** No CRC error for **≥ 60 s** after join on test save; optional longer soak.

## Evidence log (update as you go)

| Date | TF script checksum | First failing `crcTick` | Notes |
|------|-------------------|-------------------------|--------|
| 2026-04-14 | (from log) | ~1705 | Post–phase 2; `script.dat` differed in archive client vs server |
| 2026-04-14 | — | — | **Phase 3 code (static audit):** sorted core `script.on_event` registration, custom inputs, `StorageMigrations` / `apply_player_max_slots` / `tag_destroy_helper` / `handlers` favorite scan; `TeleportHistory` malformed-GPS `log` |
| 2026-04-14 | 127845210 | 1507 | Archive `desync-report-2026-04-14_14-48-49.zip`; post–phase 3; `TryingToCatchUp` tick 1504; nested `script.dat` matched (2339 B client/server) |
| 2026-04-14 | 1709456018 | 1461 | Archive `desync-report-2026-04-14_15-03-02.zip`; post–`tf-mp-bisect-mode` prototype bump (`Checksum of TeleportFavorites` 2070420553); `TryingToCatchUp` tick 1457; nested `script.dat` matched (2339 B client/server) |
| … | … | … | … |

## Static audit (phase 4 — code pass)

Classified remaining `pairs` / deferral paths that affect MP determinism or correctness:

- **[`core/cache/cache.lua`](core/cache/cache.lua):** `Cache.init` migration collects player/surface indices then `table.sort` before writes. `apply_player_max_slots` sorts surface indices. `sanitize_for_storage` / `set_tag_editor_data` / `get_tag_by_gps` meta shallow-copy: order does not change final table contents for persisted data. **Safe** as audited.
- **[`core/cache/lookups.lua`](core/cache/lookups.lua):** validity sweep collects tag numbers then sorts. **Safe.**
- **[`core/utils/chart_tag_utils.lua`](core/utils/chart_tag_utils.lua):** `can_delete_chart_tag` / `count_faved_player_entries` use `pairs` only for commutative boolean/count; documented in source. **Safe.**
- **[`gui/favorites_bar/fave_bar.lua`](gui/favorites_bar/fave_bar.lua):** `prune_stale_favorites` builds a GPS membership set from `pairs(tag_cache)`; order irrelevant. **Safe.**
- **[`gui/favorites_bar/fave_bar_slots.lua`](gui/favorites_bar/fave_bar_slots.lua):** `partial_rehydrate` / `flush_all_dirty_slots` now sort player indices and slot indices before GUI updates (aligns with [`gui_observer.lua`](core/events/gui_observer.lua) dirty-slot policy).
- **[`core/control/control_tag_editor_core.lua`](core/control/control_tag_editor_core.lua):** `script.on_nth_tick(1, …)` is single-flight per tick (`_tag_editor_defer_nth1_armed`) so a second confirm the same tick does not replace the handler; `flush_deferred_api_work` closes the tag editor for every player in the drained queue, sorted by player index.
- **`control.lua` / [`event_registration_dispatcher.lua`](core/events/event_registration_dispatcher.lua):** no `remote.` / `commands.add` in hot paths beyond init; `game.print` on max-slots runtime setting change is informational only (not serialized). Profiler `write_file` is documented on [`ProfilerExport`](core/utils/profiler_export.lua) tick path — keep profiling off for MP repro.

## References

- Project rules: [`.github/instructions/data-schema.instructions.md`](.github/instructions/data-schema.instructions.md), performance / MP comments in [`event_registration_dispatcher.lua`](core/events/event_registration_dispatcher.lua).
- Prior desync discussion: early catch-up CRC, identical scenario `control.lua` in many reports.
