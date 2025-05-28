# Tag Editor GUI Behavior and Rules

The tag editor is a modal GUI for creating, editing, moving, and deleting map tags and their associated favorites. It is designed for multiplayer, surface-aware, and robust operation, and should closely mimic the vanilla "add tag" dialog in Factorio 2.0, with additional features for favorites and tag management. The GUI is built using the builder pattern for construction and the command pattern for user/event handling. It is auto-centered, screen-anchored, and only active in chart or chart_zoomed_in modes (except when opened from the favorites bar in game mode).

## Core Features and Interactions
- **Builder/Command Patterns:** Use builder pattern for GUI construction and command pattern for all user/event interactions.
- **Styling:** Mimic vanilla "add tag" dialog, omitting the snap_position editor. Use vanilla styles, spacing, and iconography where possible.
- **Modal Behavior:** Mouse clicks outside the tag editor's outer frame are ignored. ESC closes the GUI. The "e" key, when no fields are focused, confirms and saves/closes the dialog.
- **Lifecycle:**
  - If the editor remains open after switching to game mode (not from the favorites bar), it self-closes after 30 ticks via on_tick. The on_tick event is unregistered on close.
  - On open, set `player.opened` to enable ESC to close the GUI.
- **Button Enablement:**
  - Only certain buttons are enabled depending on the player and tag state (see below).
  - The close button is always enabled and closes the dialog without saving.
  - The move button is only enabled in chart mode and when the current player is the last user (or last_user is nil/empty). Clicking it enters move_mode, allowing the user to pick a new location. Right-click cancels move_mode. Left-click attempts to move the tag and all linked favorites, validating the new location. If valid, updates all relevant objects and reopens the dialog at the new location.
  - The delete button is enabled only if the current player is the last user and no other players have favorited the tag. Clicking it asks for confirmation, then deletes the tag, chart tag, and resets all linked favorites.
  - The teleport button is always enabled (background orange). Clicking it teleports the player and closes the dialog, unless there is an error (which is shown in the error message label).
  - The favorite button is always available. Its state is tied to `is_player_favorite`. If true, shows a green checkmark; if false, no icon. Clicking toggles the state, but changes are only saved on confirm.
  - The icon button shows the current icon or blank. Clicking opens the signalID selector. Selecting a signal saves the icon and closes the selector. The value is saved to the tag/chart_tag on confirm or during move_mode.
  - The text box reflects `tag.chart_tag.text` and records input back to that field. Max length is 256 chars (see `constants.settings`). Validator trims right whitespace and checks length before saving. Shows an error if exceeded.
  - The cancel button is always enabled and closes the dialog without saving.
  - The confirm button is enabled if either the icon is set or the trimmed text box is not blank. Clicking validates and saves all fields, closes the dialog if valid, or shows an error if not.
- **last_user:** If `last_user` is empty, any changes record the current player as the new last_user.

## Button Enablement Logic
- If `player == tag.chart_tag.last_user` (by name) or `last_user` is nil/empty:
  - Enable: move, delete, icon, and text box buttons.
- The move button is only enabled in chart mode and when above conditions are met.
- The delete button is only enabled if the tag is not favorited by any other player.

## Move Mode
- Clicking the move button enters move_mode, changing the cursor to indicate selection. Right-click cancels move_mode. Left-click attempts to move the tag and all linked favorites, validating the new location. If valid, updates all relevant objects and reopens the dialog at the new location. If not valid, plays a beep and remains in move_mode.

## Teleport Button
- Always enabled. Clicking teleports the player to the tag location and closes the dialog. If teleport fails, shows an error and keeps the dialog open.

## Favorite Button
- The favorite button should always be enabled, except in the case when a player already has Constants.settings.MAX_FAVORITE_SLOTS non-blank favorites.  An easier way to manage the enablement is to ask if the current tag is_player_favorite, then the button should be enabled, otherwise it is only enabled if the player has favorit_slots_available == true (count of blank favorites in the collection > 0 == true ) 

10 If the players non-blank favorites are = to the constant specified, then the button should be di State is tied to `is_player_favorite`. Clicking toggles the state, but changes are only saved on confirm.

## Icon Button
- Shows current icon or blank. Clicking opens the signalID selector. Selecting a signal saves the icon and closes the selector. Value is saved on confirm or during move_mode.

## Text Box
- Reflects `tag.chart_tag.text`. Max length is 256 chars (see `constants.settings`). Validator trims right whitespace and checks length before saving. Shows an error if exceeded.

## Confirm/Cancel Buttons
- Cancel always enabled, closes dialog without saving.
- Confirm enabled if icon is set or trimmed text is not blank. Clicking validates and saves all fields, closes dialog if valid, or shows an error if not.

---
## Open Questions / Missing Functionality

1. **Undo/Redo Support:** Should the tag editor support undo/redo for text or icon changes before confirmation?
Absolutely!
2. **Keyboard Navigation:** Are there keyboard shortcuts for moving between fields, or for toggling favorite/move modes?
it would be great if the tab key facilitated moving through focusing the next field and shift-tab the opposite.
nothing for toggling favorite or move_mode
3. **Accessibility:** Should the GUI provide tooltips, ARIA labels, or other accessibility features for visually impaired users? Yes, for now, unless already mentioned, tootltips should be used to reflect the value of their controls or input is such
4. **Multiplayer Race Conditions:** How should the editor handle cases where another player modifies or deletes the tag while the dialog is open?
whoever is first to successfully save to storage wins. the loser should be shown an error that they lost. Howevere, because the player=last_user state should ward off virtually all race-conditions
5. **Concurrent Edits:** What happens if two players edit the same tag at the same time? Is there a locking or merge strategy?
-- se above
6. **Tag Color/Style:** Is there a way to customize the color or style of a tag beyond the icon and text?
no at this time
7. **Error Handling Granularity:** Should errors be shown per-field (inline) or only in the error row? Should errors be cleared automatically on input change?
only in the error row and should be cleared on input change
8. **Localization:** Are all user-facing strings (including error messages) localized and translatable?
we will handle localization at another time
9. **History/Audit Trail:** Should changes to tags (text, icon, location, last_user) be logged for audit/history purposes?
-- yes. it should be simple stuff and not each up much in the log file. is it acceptable to use factorio-current.log for this or should we create our own file? what does everyone else do :)?
10. **Favorite Limit Enforcement:** Is there a maximum number of favorites per player, and is this enforced/communicated in the UI?
I have rewritten the rules and explanation for this. Please let me know if the new explanation is adequate
11. **Tag Sharing:** Can tags be shared or transferred between players, or are they strictly per-user?
tags are strictly per-user in the sense that the icon be changed or the text updated only by the player == last_user of the associated chart_tag. If there is no last_user, assign the current player to last_user (and this should enable the fields forr editing). All other players can favorite an existing tag.
Disabled controls should reflect that  staus in the styling
12. **Chart Tag Sync:** How is the chart tag kept in sync with the tag editor and player favorites if changes are made outside the editor?
it is possible that a data error or sync issue could occur while the tag editor is open. In the past, we had tracked the tag_editor_positions per player. Looking at this question I think that wee could just expand on this concept and use the tag_editor_positions storage object to hold all of the current input field data for the editor and clear it out, for the playerss index, when  the tag editor is closed. So let's implement that strategy and at the same time rename the tag_editor_positions collection to tag_editor_data. the key/value should be located at storage.players[player_index].tag_editor_data
13. **GUI Scaling:** Does the tag editor scale properly with different screen resolutions and UI scales? the tag editor should scale properly with different screen resolutions an UI scales. Correct me if I use styling that goes against achieving this goal
14. **Input Validation:** Are there additional validation rules for text (e.g., forbidden characters, profanity filter)?
not yet. 
15. **Move Mode Feedback:** Is there visual feedback (cursor, highlight) when in move_mode, and is it clear when move_mode is active? This is something I neeed your help. Research to see if you can find out how others have done similar things. My thought was that at least the cursor or something held by the currsor stack should be displayed/animated/etc to visually display the fact that we are in move mode.
16. **Favorite State Persistence:** If the dialog is closed without confirming, is the favorite state reverted or left as-is? The state of the data is not persisted until the confirm button has been clicked and everything goes successfully
17. **Performance:** Are there any performance concerns with large numbers of tags or favorites in multiplayer?
I am pretty sure we have some mapping structures in place for the fastest possible access to surface chart_tags and tags
18. **Mod Compatibility:** Are there known compatibility issues with other mods that modify tags or the map GUI?
not at this time, however, I have heard of some conflicts with "Map Editor" or similar. We will address as progress occurs, but if you see a known conflict with another mod, or bad-practice, please let me know.
19. **Tag Expiry/Auto-Removal:** Should tags have an expiry or auto-removal mechanism (e.g., after X days or if unused)?
No. the tags cache should be refreshed after a player makes an edit or creates or deletes a tag. The chart_tag cache should be rest whenever a new chart_tag is added or update, etc
20. **Custom Signals:** Can custom signals (beyond vanilla) be used as icons, and how are they handled?
Yes, allow whatever signals are available in the current game. If a mod change removes a signal or some other game changes the availability or validty of a signal, then the signal should be set to nil or empty table

---
## Additional Open Questions / Considerations

21. **Tag Deletion Confirmation:** Should there be an option to undo a tag deletion immediately after confirming, or is deletion always final? No there shouldn't be a need to confirm as hitting the delete button, which brings up a confirmation dialog, should handle this. if the deletion is confirmed then, if valid for deletion, the tag will be immediately deleted and the confirmation dialog and the tag editor should be closed. If the dlete confirmation is negative, than the confirmation should be closed and the tag_editor, already open with it's current data should be remained open. The confirmation dialog should also set player.opened correctly
22. **Favorite Button Disabled State:** Should the favorite button show a tooltip or message when disabled due to reaching the favorite slot limit? tooltip
23. **Chart Tag/Tag Data Migration:** If the tag schema changes in a future version, how should migration of tag_editor_data and chart_tag data be handled? we are not concerning ourseleves with migrations just yet
24. **Signal Selector Usability:** Should the signal selector for the icon button support search/filtering for large modded signal lists? absolutely
25. **Tag Editor Re-entrancy:** Can the tag editor be opened for multiple tags at once (e.g., by different scripts or hotkeys), or is it strictly single-instance per player? strict single-instance for player. thee confirmation dialog should open in a layer over the tag editor
26. **Player Disconnect Handling:** If a player disconnects with the tag editor open, should their tag_editor_data be cleared immediately or on reconnect? The tag_editor should be closed, which should also clear any data. ensure the data is reset (or rather the player's entry in the tag_editor_data is set to nil)
27. **Tag Editor API Exposure:** Should there be a remote interface or API for other mods to open/close the tag editor or interact with its data? no
28. **Input Method Support:** Is the tag editor usable with gamepads or other non-mouse input devices? I am not sure and this will have to be tested separately at another time. Follow best practices and know fixes and idiomatic methods to resolve this. Let me know when I am creating conflicts to that goal
29. **Tag Editor Analytics:** Should usage of the tag editor (opens, edits, deletes) be tracked for analytics or debugging? Not at this time
30. **Error Recovery:** If a runtime error occurs while the tag editor is open, is there a recovery or auto-close strategy to prevent UI lockup? No, but we should emplore a way to handle

---

# Tag Editor GUI Hierarchy

```
tag_editor_frame (frame)
└─ tag_editor_inner_flow (flow, vertical)
    └─ tag_editor_titlebar_flow (flow, horizontal)
      ├─ tag_editor_titlebar_label (label) localised text = "Tag Editor"
      ├─ tag_editor_titlebar_filler (empty-widget) - drag-handle, draggable = true
      └─ tag_editor_titlebar_close_btn (sprite-button) "X"
    └─ tag_editor_content_flow (flow, vertical)
      └─ tag_editor_last_user_row (flow, horizontal) - dark background
          └─ tag_editor_last_user_label (label)
      └─ tag_editor_teleport_row (flow, horizontal)
          ├─ tag_editor_teleport_label (label - localised text = "Teleport to")
          └─ tag_editor_teleport_to_btn (btn)
      └─ tag_editor_favorite_row (flow, horizontal)
          ├─ tag_editor_favorite_label (label - localised text = "Favorite")
          └─ tag_editor_favorite_btn (choose-elem-btn) - default blank, shows green checkmark for true, toggle
      └─ tag_editor_icon_row (flow, horizontal)
          ├─ tag_editor_icon_label (label - localised text = "Icon")
          └─ tag_editor_icon_btn (choose-elem-btn) - signalid
      └─ tag_editor_text_row (flow, horizontal)
          ├─ tag_editor_text_label (label - localised text = "Text")
          └─ tag_editor_input_text (textfield)
    └─ tag_editor_lower_actions_flow (flow, horizontal)
      ├─ tag_editor_cancel_btn (sprite-button) localised text = "Cancel"
      └─ tag_editor_confirm_btn (sprite-button) localised text = "Confirm"

```
- All element names use (for the most part) the `{gui_context}_{purpose}_{type}` convention.
- The content and controls may vary depending on the tag being edited.


---
<!--
Original detailed notes for reference:

the tag editor:


tag_editor_outer_frame = {
  tag_editor_inner_frame = {
    tag_editor_top_row = {
      tag_editor_title_row = {
        title_row_label.text = {'tag_editor_title'}
        title_row_draggable -- a draggable handle
        title_row_close_button -- a close button with a bold X
      }
    }
    tag_editor_content_frame = {
      tag_editor_content_inner_frame -- invisible frame = {
        tag_editor_last_user_row = {
          last_user_row_last_user_container = {
            last_user_row_last_user_title.text = {'last_user_row_title'}
            last_user_row_last_user_name.text = player.name
          },
          last_user_row_button_container = {
            last_user_row_move_button -- mipmapped move icon, light-grey
            last_user_row_delete_button -- trash can icon, red
          }
        },

        tag_editor_teleport_row = {
          teleport_row_label.text = {'teleport_to'},
          teleport_row_teleport_button.text = gps coord string
        },

        tag_editor_favorite_row = {
          favorite_row_label.text = {'favorite_row_label'},
          favorite_row_favorite_button = PlayerFavorites.is_player_favorite(player) (or similar)
        },

        tag_editor_icon_row = {
          icon_row_label.text = {'icon_row_label'},
          icon_row_icon_button = tag.chart_tag.icon or blank
        },

        tag_editor_text_row = {
          text_row_label.text = {'text_row_label'},
          text_row_text_box.text = tag.chart_tag.text
        }
      }
    }
    tag_editor_error_row_frame = {
      error_row_inner_frame -- invisible frame
      error_row_error_message -- is a label
    },
    tag_editor_last_row = {
      last_row_cancel_button.text = {'cancel_button'}
      last_row_confirm_button.text = {'confirm_button'}
    }
  }
}

use the builder pattern for this and all guis! use command pattern to handle user and event interaction

the styling should mimic the vanilla "add tag" dialog as much as possible, without the snap_position editor

place this gui into the screen gui and auto-center it

for the most part, this gui should only be active in chart view or chart_zoomed_in

the only time it should show in game mode is when the tag_editor is opened from a fave_bar button click. 

when the tag_editor is open, any mouse clicks outside the tag editor's outer frame should be ignored

upon opening the player.opened should be set to enable esc to close the gui.

if, for some reason, it is possible to have the tag_editor still open when exiting chart or chart_zoomed mode to game mode, then i would like to create an on_tick event to see if the editor is in game view and the editor was not opened by the fave_bar while in game view, then after 30 ticks the tag_editor should self-close. when the tag_editor is closed, the on_tick event should be unregistered (and re-registered upon opening)

if it is possible to have the tag_editor handle the "e" input while the tag_editor is open, then "e", when no other fields are in focus, should be a signal to confirm the input and save/close the dialog

How buttons are enabled:
Only certain buttons should be enabled depending on some factors. And the requirements should be checked when the dialog is open and any field mentioned meets the requirements

if the player == tag.chart_tag.last_user (hopefully matched by name) or if the tag.chart_tag.last_user is nil or "" then
  the following buttons should be enabled (and in all other conditions enabled == false)
  last_user_row_move_button, last_user_row_delete_button, icon_button, text_box
end

- the title_row_close_button should always be enabled and if clicked, it should immediately close the dialog without saving or making changes to any data

- the last_user_row_move_button is a special button, it will allow us to move the current tag's location to another location on the map. in addition to the enabled rules above, it should also only be enabled when render_mode = chart only. Help me to envision and employ the click action for this button. My initial thought is that clicking on this button brings up a special cursor that shows that we are searching for a new spot. A special type of pointer. It also puts us into "move_mode". In move_mode a right-click will cancel "move_mod" and the cursor should reset. A left-click in move_mode will first verify that the tag can be moved to the location, so this will immediateley trigger a normalization of the cursor_position location and aligned_for_landing check for the locations validty. If the location is not valid a beep sound should be played. We remain in move_mode until a valid selection is selected (and verified, more on that later) or until a right-click occurs. 
A left-click in move_mode will try to move the tag and all it's components, including the chart tag and any and all matched player favorites to the new location. If the new location cannot be verified, the tag_editor should remain open displaying the information from the original opening of the dialog.
If the new location is verified, update all the tag objects, other player's favorites (in addition to the current player), etc, save to storage and then upon success, turn off move_mode and close the already open dialog and then re-open, from scratch, with the information from the newly created tag.

- the last_user_row_delete button should only be enabled when
  - the current player == tag.chart.tag.last_user (try to match on player.name) or the last_user is nil or ""
  - the tag.faved_by_players does not contain any index but the current player's index or is empty. A tag cannot be deleted if any other players have favorited it
- when the delete button is clicked, it should ask for confirmation "Are you sure you want to delete?", and then, on confirmation, it should delete the tag and the related chart tag as well as update any players favorites to reset linked favorites to a blank favorite. when all of those operations are done, close the dialog

- the teleport_button should always be enabled - can we make the background of this button orange? When clicked it should immediately try to teleport the player to the location indicated and then the dialog should be closed. if there is an error, do not automatically close the dialog and show the error in the error_row_error_messaage label

- the favorite_button should always be available. the state of the favorite button should be tied to is_player_favorite. If it is_player_favorite == true, then the icon should be set to a green chackmark. If false then the favorite_button should be cleared of any icons. Clicking on the favorite_button should toggle the state of the button. The value will not be reflected back into storage until the confirm button is clicked and then all fields will be checked for validity before updating any associate storage objects (this behavior regarding saving the value should apply accross all input fields)

- the icon button should display the icon for the current chart_tag.icon or display no icon when chart_tag.icon is nil or empty. clicking on the button will bring up the signalID selector. selecting a signal id will immediately save the input's icon and close the signal id selector and the tag_editor should now display the chosen signal id. The selected signal id or empty should be saved to the tag.chart_tag upon confirmation or during move_mode

- the text_box should reflect the value of tag.chart_tag.text and record the input back to the tag.chart_tag.text field upon update. We need to avoid excessive length here. set a maximum of 256 chars for this field. Make an appropriate entry in constants.settings to manage the exact length. set up a validator to show an error if the chars exceed the number. all string values returned should trim the right end whitespace. the validator should check this format (trim right) prior to validating as well.

- the cancel_button should always be enabled and clicking on it should close the editor dialog
- the confirm button should only be enabled if either icon_button is set or text_box.text (trimmed) is not blank or nil in the dialog. check this in real time. if clicked, the input data should be validated immediately and saved back to the appropriate storage objects. Close the dialog box and save the data back to storage, where applicable and close the dialog box if there are no errors, otherwise display a user friendly error in the error_row_error_message and keep the dialog box open.

-- if the last_user is empty, then any changes made should record the current player as the new last_user
-->
<!--
Current tag editor structure (as of 2025-05-27):

The tag editor dialog is structured as follows, matching vanilla Factorio dialog idioms:

inside_shallow_frame_with_padding
- tag_editor_inner_frame (frame, vertical)
- tag_editor_titlebar (frame, style: 'frame_titlebar_flow', horizontal)
- titlebar_label (label, style: 'frame_title')
- titlebar_draggable (empty-widget, style: 'draggable_space_header', horizontally stretchable, drag_target = outer_frame)
- titlebar_close_button (sprite-button, close icon, handled in event logic)
- tag_editor_content_frame (frame, vertical)
- tag_editor_content_inner_frame (frame, vertical)
- tag_editor_last_user_row (flow, horizontal)
- tag_editor_teleport_row (flow, horizontal)
- tag_editor_favorite_row (flow, horizontal)
- tag_editor_icon_row (flow, horizontal)
- tag_editor_text_row (flow, horizontal)
- tag_editor_error_row_frame (frame, vertical)
- error_row_inner_frame (frame, vertical)
- error_row_error_message (label)
- tag_editor_last_row (flow, horizontal)
- last_row_cancel_button (sprite-button)
- last_row_confirm_button (sprite-button)

This structure ensures:
- The titlebar is a frame styled as 'frame_titlebar_flow', with a draggable grip and close button, matching vanilla dialogs.
- No top_row or title_row: the titlebar is built directly as a frame.
- The close button is handled in event logic and closes the dialog.
- The dialog is modal, sets player.opened, and supports ESC/drag as in vanilla.
-->
