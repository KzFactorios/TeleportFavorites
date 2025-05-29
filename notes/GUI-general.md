# General GUI Implementation Questions – TeleportFavorites

## Sprite Reference
- For a comprehensive, up-to-date list of all valid vanilla Factorio utility sprites, see:
  https://github.com/wube/factorio-data/blob/master/core/prototypes/utility-sprites.lua
- Use this as the canonical source for sprite names when updating or adding GUI icons.


This document collects open questions and considerations for the implementation of all major GUIs in the mod: the favorites bar, data viewer, and tag editor. These questions are intended to guide robust, idiomatic, and user-friendly Factorio mod development.

## Data & Storage
- How should per-player GUI state (e.g., open/closed, font size, opacity, bar visibility) be stored and synchronized? Should all GUI state be persisted in `storage.players[player_index]`?
Yes - until further notice
- What is the best way to handle migration of GUI-related data if the schema changes in future versions?
Not an issue at this time
- Should there be a versioning system for stored GUI state to aid in migration and debugging?
The version should be tied to the mod_version
- How should temporary GUI state (e.g., drag-and-drop, move_mode) be managed to avoid desyncs or stale data?
Save the current data before manipulating. Consider a structure in storage.players[player_index] to use as a backing store for the changing data and original data. Erase the data key when the drag-drop is complete or at the start of a game, opening a save, etc
- Are there any performance concerns with storing large or complex GUI state in multiplayer?
Not at this time

## User Interaction & UX
- What accessibility features should be included (tooltips, keyboard navigation, ARIA labels, colorblind support)?
For all guis, these should be employed to the extent that Factorio v2 has capabilites for. Always do your best to include support for handicapped users
- Should all GUIs support hotkeys for opening, closing, and common actions? If so, which keys?
No. I will specify when warranted. But do not shy way from telling me that idiomatic Factorio v2 says otherwise
- How should the GUIs handle rapid user input (e.g., spamming buttons, dragging quickly, resizing)?
Great question! I haven't considered yet. 
Do what you can to keep drag and drop functionality under control. Make it adjustable and use keys in the Constants file to handle
- What is the best way to provide visual feedback for disabled, locked, or error states across all GUIs?
liberal use of the color red. Orange should be a highlight to draw attention to the fact that a button usses a slightly different action than the average player may be accustomed to. But errors or attention items sohuld alwyas show red as a baseline. Subject to interpretation
- Should there be a consistent approach to undo/redo or confirmation dialogs for destructive actions?
A confirm dialog
- How should the GUIs handle multiplayer race conditions (e.g., two players editing the same tag or favorite)?
By ensuring that only owners of a tag or where a tag's owner is unspecified can be edited by the current player
- Should there be a notification or message system for important GUI events (e.g., favorite added, tag deleted, error occurred)?
Erros yes! If not specified use flying text

## Modularity & Extensibility
- How can GUI code be structured for maximum maintainability and extensibility (e.g., builder/command patterns, modular files)?
Stick to specified patterns and best practices and common sense
- Should there be a shared style/theme system for all GUIs to ensure consistency?
Absolutely. Idiomatic factorio v2 wins, but next is my preferences for orange and red mentioned earlier. All animations should be shared consistently
- Is it desirable to expose a remote interface/API for other mods to interact with the GUIs?
Not at this time
- How should GUI code handle compatibility with other mods that modify the top GUI or add similar elements?
Because this mod uses a fair amount of the top gui real-estate, I decree that it's display prefs should always win
- Should there be a mechanism for developers to easily add new tabs, buttons, or features to the GUIs?
Not at this time

## Performance & Scaling
- How should GUIs scale with different screen resolutions, UI scales, and large numbers of tags/favorites/data entries?
I was under the impression that it should follow best practices. Follow all rules. Storage issues have been addressed for some data structures. If you see the potential for pitfalls, bring them to my attention
- Are there any best practices for minimizing GUI update frequency and avoiding performance bottlenecks?
Research to find out
- Should there be lazy loading, paging, or virtualization for large data sets in the data viewer or favorites bar?
As this will be mostly a developer tool, I dont' think so or it shouldn't matter at this time

## Error Handling & Recovery
- What is the best way to handle runtime errors in GUI code to avoid UI lockup or desync?
There should never be a lockup. Handle all errors gracefully with logging and fairly descriptive error messghaes. Try to include relevant line numbers when possible. This is not mission critical code, so exposing true error data will only help me to trouble shoot. Include comments to alrt the deleoper that so and so happened so that hopefully the user will copy/paste the error msg into their correspondence with me so that I can access the context more clearly
- Should there be an auto-recovery or fallback mechanism if a GUI fails to load or update?
Yes. Log to factorio-current.log and if a gui fails, don't show it or let it impede the progress of the game. The last thing I want is for the game to crash ungracefully
- How should the GUIs handle missing or corrupted data (e.g., missing tags, invalid favorites, nil player data)?
I am hoping we have covered most of this issue within the notes folder and proper documentation

## Multiplayer & Sync
- How should GUI state and actions be synchronized across players in multiplayer?
Each player sohuld have their own namespace to track their state. Alert me if this is not the case
- Are there any known desync risks with the current GUI/event handling approach?
Not at this time
- Should there be admin-only or per-player restrictions for certain GUI features (e.g., data viewer access)?
Not at this time. But remind to revist prior to deploying

## Analytics & Debugging
- Should GUI usage (opens, edits, errors) be logged for analytics or debugging?
absolutely!
- What is the best way to provide developers with insight into GUI usage and issues in multiplayer?
Document state of relevant storage, what action was performed to cause an issue

---
This list is not exhaustive. Please add further questions or considerations as the mod evolves.
