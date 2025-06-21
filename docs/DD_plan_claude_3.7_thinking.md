come up with a plan to implement drag and drop functionality, for re-ordering the favorite slots in the fave bar
the indication that a drag has been initiated is when we detect a shift+left-click on a favorite slot in the fave bar.
we are limited in that there is no built-in drag and drop functionality, so we need to get creative

I would like to see, at the very least, that when i shift+left-click on a favorite, the icon for that favorite is added to the mouse cursor stack (more on this below ) and when i let go of the mouse or the shift, the favorite will be re-inserted into the favorites collection according to the rules i will lay out shortly.the cursor stack should remove whatever we have added to it at this as well

we need an indicator of some sort and i would like to propse that we add an item to the cursor stack. The best option would be to show a slot button with the icon of the favorite, just like the drag slot, that we could attach.
next best: just the icon of the drag slot (defaults to tf_slot_button_smallfont_map_pin if no icon )
next best: use tf_slot_button_smallfont_map_pin
if none of those options are workable then disregard the cursor stack change


some aspects to the slots.
slots can be locked and locked slots cannot move from their current position and should not be highlighted on hover if possible
if the drag slot's original slot is to the left of the insert position, then items should shift left
if the drag slot's original slot is to the right of the insert position, then items should shift right

some thoughts on how to handle the intended landing
if the mouse is over the left side of a slot, insert the drag slot prior to the hovered slot. the reverse for the right side where it would insert after the hovered slot

create the appropriate and idomatic factorio, styling to indicate our dra and drop movements and highlighting

Create a complete plan/report on how to achieve this in this codebase