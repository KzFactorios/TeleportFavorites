the fave_bar will exist in the player's top gui. it should strive to be displayed as the rightmost item in the top gui. the parent element of the gui is fave_bar_frame

the fave_bar_frame will have two horizontal containers. The first, the fave_toggle_container, will hold one button, fave_toggle. this button should use a red star as an icon. clicking on this button will immediately show or hide the next container in this gui, the favorite_buttons container. These containers sohuld sit side by side with the fave_toggle to the of the parent container. to keep the state of the fave_toggle button, it should live in persistent storage, like so:
storage.players[player_index] = {
  toggle_fave_bar_buttons = boolean,
  ... other
}

the fave_buttons container: will have MAX_FAVORITE_SLOTS and show the player's favorites respective for the slot they are in. If the favorite's gps is not nil or == "", then the icon for the slot button will display the matched chart_tag's icon and if this is not specified, then use the default_map_tag.png, the tooltip will show, on the first line, the value of the gps without the surface component. I believe there is a coords_string method in GPS for this. The second line should show the text of the matched chart_tag, trimmed to reasonable number of allowed chars (50? create a constant to hold this value). If there is no text, then a second line should not be displayed. Each slot should also show a caption for it's slot number (1-0), the caption text should be rather small.

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
