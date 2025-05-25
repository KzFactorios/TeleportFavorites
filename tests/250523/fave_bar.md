# TeleportFavorites TODO

_This is a work in progress._

---

## GUI Improvements

- [ ] **Change the color of the teleport button** in the tag editor.
- [ ] **Test** the `ft_teleport_button` with `parent = "confirm_button"` and minimal overrides for best vanilla look.
- [ ] **Confirm label widths and alignments** are consistent across the tag editor dialog.
- [ ] **Match vanilla styling** for delete and move button in the tag editor.
- [ ] **Test for display of unforeseen large strings** (e.g., player names, chart tag text).  
      _Limit string length in GUI where appropriate._
- [ ] **Check limits on size for chart tag text** and enforce in GUI logic/helpers.
- [ ] **Document further style or layout tweaks** in this file for future reference.
- [ ] **Add localization** for any new user-facing strings.

---

## Testing & Coverage

- [ ] **Add more unit tests** for helpers and GUI logic as the project matures.
- [ ] **Test for map editor functionality** and ensure compatibility.
- [ ] **Multiplayer:** Test and document tag ownership edge cases.
- [ ] **Player favorites:**  
      - Should mimic a first-in last-out (FILO) pattern.  
      - If trimming is needed, remove last-in items first to preserve oldest entries.

---

## Persistence & State

- [ ] **Persist `tag_editor_positions` for all players** if the tag editor can be available at game start.

---

## Event Handling & Sync

- [ ] **Implement GUI desync detection and recovery**  
      _See `notes/specs_after_agent_discussion.md`._
- [ ] **Handle events from the vanilla tag editor** and ensure mod GUI stays in sync.
- [ ] **In `control.lua.events.on_player_changed_surface`,**  
      `event.surface_index` is not guaranteed. Use `player.surface.index` for the new surface.

---

## Tag & Chart Tag Logic

- [ ] **When a `chart_tag` is destroyed, ensure it destroys any linked tags (and vice versa).**  
      _Refactor tag <-> chart_tag destruction logic to a shared helper if possible._

---

## References

- The only place `"map_tag"` should be used is for the reference to the sprite:  
  `graphics/default_map_tag.png`

---
