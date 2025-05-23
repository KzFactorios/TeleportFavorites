-- This is a work in progress

# TODOs for TeleportFavorites

<!--
  This file tracks outstanding tasks, design notes, and technical debt for the TeleportFavorites mod.
  Please keep entries concise and actionable. Use checkboxes for task tracking.
  When adding new items, prefer actionable language and reference relevant modules/files if possible.
-->

- [ ] Review and finalize all custom button styles for the tag editor GUI, ensuring vanilla-like appearance and consistent sizing/alignment. 
- [ ] Change the color of the teleport button in the tag_editor
- [ ] Test the ft_teleport_button with parent = "confirm_button" and minimal overrides for best vanilla look.
- [ ] Confirm that all label widths and alignments are consistent across the tag editor dialog.
- [ ] Add more unit tests for helpers and GUI logic as the project matures.
- [ ] Implement GUI desync detection and recovery (see notes/specs_after_agent_discussion.md).
- [ ] Add localization for any new user-facing strings.
- [ ] Document any further style or layout tweaks in this file for future reference.
- [ ] Test for the display of unforeseen large strings (e.g., player names, chart tag text). Limit string length in GUI where appropriate.
- [ ] Check limits on size for chart tag text and enforce in GUI logic/helpers.
- [ ] Check for map editor functionality and ensure compatibility.
- [ ] When a chart_tag is destroyed, ensure it destroys any linked tags (and vice versa). Refactor tag<->chart_tag destruction logic to a shared helper if possible.
- [ ] Multiplayer: test and document tag ownership edge cases.
- [ ] Match vanilla styling for delete and move button in the tag editor.
- [ ] If the tag_editor can be available at game start, persist tag_editor_positions for all players.
- [ ] Player favorites should mimic a first-in last-out (FILO) pattern. If trimming is needed, remove last-in items first to preserve oldest entries.
- [ ] In control.lua.events.on_player_changed_surface, event.surface_index is not guaranteed. Use player.surface.index for the new surface.
- [ ] Handle events from the vanilla tag editor and ensure mod GUI stays in sync.
