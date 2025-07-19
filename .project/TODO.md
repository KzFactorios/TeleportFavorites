-- This is a work in progress

# TODOs for TeleportFavorites
- [TeleportFavorites GUI Experiments (Copilot Space)](https://github.com/copilot/spaces/kurtzilla/1)  

<!--
  This file tracks outstanding tasks, design notes, and technical debt for the TeleportFavorites mod.
  Please keep entries concise and actionable. Use checkboxes for task tracking.
  When adding new items, prefer actionable language and reference relevant modules/files if possible.
-->

- [ ] Review and finalize all custom button styles for the tag editor GUI, ensuring vanilla-like appearance and consistent sizing/alignment. 
- [ ] Add more unit tests for helpers and GUI logic as the project matures.
- [ ] Add localization for any new user-facing strings.



- [ ] Check for map editor functionality and ensure compatibility.
- [ ] When a chart_tag is destroyed, ensure it destroys any linked tags (and vice versa). Refactor tag<->chart_tag destruction logic to a shared helper if possible.
- [ ] Multiplayer: test and document tag ownership edge cases.
- [ ] In control.lua.events.on_player_changed_surface, event.surface_index is not guaranteed. Use player.surface.index for the new surface.
- [ ] Handle events from the vanilla tag editor and ensure mod GUI stays in sync.

- [ ] Check for conflicts with other mods. Especially with all those buttons in the top gui. Find alternative display locations?

- [ ] Ensure that any "development" settings, flags, constants are not being used when deployed to production. Create a script that will package the code for production use that doesn't include such things as notes, tests, comments, etc and optimizes files for production

- [ ] Make a note! that this mod does not support cross-server implementations. It may work for multiplayer - but not cross server (at least no guarantess)