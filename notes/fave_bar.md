# TeleportFavorites Favorites Bar (Fave Bar)

The favorites bar (fave_bar) is a persistent, player-specific GUI element that provides quick access to teleportation favorites. It is designed to be idiomatic for Factorio 2.0, robust in multiplayer, and visually consistent with vanilla UI paradigms. The bar is managed automatically by the GUI and mod settings; there is no dedicated hotkey or custom event for opening it. The bar should be built using the builder pattern for GUI construction and the command pattern for user/event handling.

## Core Features and Interactions
- The fave_bar exists in the player's top GUI, ideally as the rightmost item.
- The parent element is `fave_bar_frame`, which contains two horizontal containers:
  - `fave_bar_toggle_flow`: Holds the `fave_bar_visible_btns_toggle` button (red star icon). Clicking toggles visibility of the favorite buttons container. State is persisted in `storage.players[player_index].toggle_fave_bar_buttons`.
  - `fave_bar_slots_flow` container: Contains `MAX_FAVORITE_SLOTS` slot buttons, each representing a favorite. Each slot button:
    - Shows the icon for the matched chart_tag, or `default_map_tag.png` if none.
    - Tooltip: First line is GPS (without surface), second line is chart_tag text (trimmed to 50 chars, see constant), no second line if no text.
    - Caption: Slot number (1-0), small font.
    - Size: 36x36, use slot button style.
    - Left-click: Teleport to favorite's GPS.
    - Right-click: Open tag editor for editing.
    - Ctrl+left-click: Toggle locked state (with highlight and lock icon if possible).
    - Locked slots cannot be moved.
    - Drag-and-drop: Reorder favorites (locked slots cannot move).
    - Distinct styles for default, hovered, clicked, disabled, locked, etc.
- The bar is only built if the per-player mod setting `favorites_on` is true.
- The bar is visible in game, chart, and chart_zoomed_in render modes.
- The bar should scale and style properly for all UI scales and resolutions.
- All GUI state and slot order is persisted per player.
- Use shared styles and idiomatic Factorio GUI patterns wherever possible.

## Best Practices & Modern Factorio v2 Considerations
- Use the builder pattern for all GUIs.
- Use the command pattern for all user/event interactions.
- Use vanilla icons, spacing, and style classes where possible.
- Provide clear visual feedback for all button states and actions.
- Ensure all user-facing strings are localizable.
- Avoid GUI thrashing or excessive updates; debounce where needed.
- Support multiplayer and hot-reload scenarios robustly.

## Open Questions / Suggestions for Improvement

1. **Drag-and-Drop Feedback:** Should there be a visual indicator (e.g., ghost image, highlight) when dragging a favorite slot? yes, it should look as if a slot_button with the dragged favorites icon is being moved around
2. **Slot Locking UI:** If layering icons is not possible, should a tooltip or color change indicate locked state?
Yes. pretty sure I mentioned this below, but a locked favorite should show with a different color border. Use orange for now. And if it is possible to put another locked icon over the button, we should do that as well
3. **Favorite Slot Overflow:** What should happen if a player tries to add more favorites than `MAX_FAVORITE_SLOTS`? Should there be a message or animation?
There should be a beep, and a message that indictaes that the player already has the max number of available slots.

4. **Slot Button Accessibility:** Should slot buttons have tooltips for all states (locked, disabled, etc.)?
yes and no. locked buttons sould just not react to any left clicks. right clicks should open the tag_editor with the faves info and a ctrl+left-click should toggle the locked state immediatley. ctrl-right-click should be ignored. Blank favorites should not show as disabled, they just shouldn't do anything if left,right, ctrl+? clicked. A blank favorite cannot be locked, and a blank favorite should have no tooltip and no icon
5. **Favorite Removal:** Is there a quick way to remove a favorite (e.g., middle-click or context menu)?
You can delete by right clicking the favorite thereby open the tag editor with the favorites' information and the ability to delete if not locked and with all of the other ownership rules which are handled in the tag_editor
6. **Favorite Sorting:** Should there be an option to auto-sort favorites (e.g., by name, location, last used)?
No. instead we are going to offer drag and drop
7. **Favorite Import/Export:** Should players be able to import/export their favorites (e.g., for sharing or backup)?
Not now. although this is something to consider in future versions
8. **Favorite Bar Customization:** Should players be able to customize the number of slots, bar position, or appearance?
Not at this time
9. **Performance:** Are there any performance concerns with large numbers of favorites or frequent GUI updates?
There will only be MAX_FAVORITE_SLOTS available and I don't see the number going much higher due to the fact that we just can't steal that many hotkeys away from the vanilla game :)!
10. **Mod Compatibility:** Are there known issues with other mods that modify the top GUI or add similar bars?
No known issues, but I would like to keep the fave bar as the last element in the top gui
11. **Hotkey Support:** There is no hotkey for toggling the favorites bar, jumping to a favorite, or reordering slots. All bar visibility and interaction is managed by the GUI and mod settings.
12. **Favorite State Sync:** How is favorite state synced if the player changes settings or reloads the mod?
I am not sure exactly what you mean but player favorites are persisted in storage and the default settings keep favorite false until toggeled 
13. **Favorite Bar Visibility:** Should the bar auto-hide in certain situations (e.g., cutscenes, map editor)?
yes it should not be shown in anything other than game chart or chart_zzoomed_in mode
14. **Favorite Button Animations:** Should there be subtle animations for adding/removing/reordering favorites?
yes and i am counting on you to provdie a modern efficient, easy to maintain, system or look
15. **Favorite Bar API:** Should there be a remote interface for other mods to interact with the favorites bar?
Not at this time

## Slot Count Changes

- The number of favorite slots (`MAX_FAVORITE_SLOTS`) is not expected to change frequently. If it does change (e.g., via a mod setting), the entire favorites bar GUI should be rebuilt for affected players to reflect the new slot count.
- This is handled by listening for the `on_runtime_mod_setting_changed` event and triggering a full GUI rebuild for all players if the slot count setting changes.
- Normal drag-and-drop reordering only rebuilds the slot row, not the entire bar, for efficiency. Only a slot count change requires a full bar rebuild.

## Blank Favorite Slot Click Handling

- Blank favorite slot buttons in the favorites bar remain enabled for consistent styling and UX.
- All click events on blank favorite slots are ignored in the event handler (`handle_favorite_slot_click`). No action is taken and no error is raised.
- This ensures blank slots are visually present and styled, but never trigger any logic or errors when clicked.
- This is a strict design rule for the favorites bar and must be preserved in future refactors.

---

# Favorites Bar GUI Hierarchy

```
fave_bar_frame (frame)
└─ fave_bar_inner_flow (frame, invisible frame)
    └─ fave_bar_toggle_flow (flow, horizontal)
      └─ fave_bar_visible_btns_toggle (sprite-button)
    └─ fave_bar_slots_flow (flow, horizontal)
          ├─ Constants.settings.FAVE_BAR_SLOT_PREFIX_1 (sprite-button)
          ├─ Constants.settings.FAVE_BAR_SLOT_PREFIX_2 (sprite-button)
          ├─ ...
          └─ Constants.settings.FAVE_BAR_SLOT_PREFIX_ .. Constants.settings.MAX_FAVORITE_SLOTS (sprite-button)
```
- All element names use (for the most part) the `{gui_context}_{purpose}_{type}` convention.
- The number of slot buttons depends on the user’s settings.


<!--
the fave_bar will exist in the player's top gui. it should strive to be displayed as the rightmost item in the top gui. the parent element of the gui is fave_bar_frame

the fave_bar_slots_flow container: will have MAX_FAVORITE_SLOTS and show the player's favorites respective for the slot they are in. If the favorite's gps is not nil or == "", then the icon for the slot button will display the matched chart_tag's icon and if this is not specified, then use the default_map_tag.png, the tooltip will show, on the first line, the value of the gps without the surface component. I believe there is a coords_string method in GPS for this. The second line should show the text of the matched chart_tag, trimmed to 50 chars. If there is no text, omit the second line. Each slot should also show a caption for it's slot number (1-0), the caption text should be rather small.

all slot buttons (including toggle_favorite), should be slot buttons, at the standard size of 36x36

do your best to share styles among same elements

Because the slot buttons are a representation of the order of a player's favorites collection, this gives us a responsibility to provide a rich, robust interface, with idiomatic and modern factorio style, to manage the ordering of the favorites with an easy to use drag and drop system (using left-click and drag) to reorder the slots. if a slot is locked, it cannot move. but clicking and dragging should be employed to manage the arranging of favorites. Any animations or styling tricks to acheive a modern, idiomatic factorio experience with a bit of panache are welcome. if a tag is locked, it can be unlocked/locked/toggled by entering crtl+left-click - this action will toggle the locked state which should give a bit of a highlight to the slot button to indicate it is locked. if it is possible to layer icons or images on a button, then do so for locked buttons and include a small lock icon or closest approximation to the top layer. if this cannot be done (layered images/icons) then nevermind. All buttons should have distinctly styled indicators as to the state of the button: default, hovered,  clicked, disabled, etc. 
When a slot button is left-clicked, it should immediately teleport the player to the favorited's gps coords
When a slot button is right-clicked, it should immediately bring up the tag_editor, loaded with the favorite's current data, for editing
And recall that when a button is ctrl+left-clicked, it should toggle the locked state of the favorite and update style, icons, etc, for that slot immediately.  This allows for the player to change the is_favorite state for that favorite and easily allows removal of the favorite state and also should allow, if the player is the same as the matching tag.chart_tag.last_user or last_user is nil or "", editing of that tag. whever possible use the player.name to record the last_user

Also, there should be a mechanism to skip building the gui if a mod_setting is set. the favorites_on mod setting can be set, per-player (correct me if I am wrong) to true or false. If the setting is true, the fave_bar_frame should show in the gui, and if the setting is false, the favorites_bar_frame if this setting is changed

The fave_bar should show when defines.render_mode  = game, chart, chart_zoomed_in (or whatever it's called)

the fave_bar_frame should probably have an inner_frame to make styling easier

use the builder pattern for this and all guis! use command pattern to handle user and event interaction
-->
