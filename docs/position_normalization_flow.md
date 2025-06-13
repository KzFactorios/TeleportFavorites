# Position Normalization Flow

This document outlines the detailed process of position normalization used in the TeleportFavorites mod. Position normalization is a critical component that handles the conversion of raw cursor coordinates to valid, grid-aligned positions that can be used for tag creation and teleportation.

## Overview

The position normalization process takes a raw cursor position from a right-click event and transforms it into a validated, normalized position that can be used for tag creation and teleportation. This involves several steps, including GPS string conversion, existing tag detection, nearby tag searching, grid alignment, and validation.

## Visual Workflow Diagram

```
                   ┌───────────────────┐
                   │   Right Click     │
                   │ cursor_position   │
                   └─────────┬─────────┘
                             │
                             ▼
                   ┌───────────────────┐
                   │    Convert to     │
                   │     GPS string    │
                   └─────────┬─────────┘
                             │
                             ▼
┌───────────────────────────────────────────────────┐
│          normalize_landing_position_with_cache    │
│                                                   │
│  ┌─────────────────────┐                          │
│  │ Context Validation  │                          │
│  └──────────┬──────────┘                          │
│             │                                     │
│             ▼                          YES        │
│  ┌─────────────────────┐      ┌──────────────┐   │
│  │   Exact Match?      ├─────►│ Use existing │   │
│  └──────────┬──────────┘      │ tag/chart tag│   │
│             │ NO              └──────────────┘   │
│             ▼                                    │
│  ┌─────────────────────┐      ┌──────────────┐   │
│  │ Check Nearby Tags?  ├─────►│ Use nearby   │   │
│  └──────────┬──────────┘ YES  │ tag/chart tag│   │
│             │ NO              └──────────────┘   │
│             ▼                                    │
│  ┌─────────────────────┐                         │
│  │   Grid Snap Check   │                         │
│  │                     │                         │
│  │ Create/align chart  │                         │
│  │ tag to ensure whole │                         │
│  │ number coordinates  │                         │
│  └──────────┬──────────┘                         │
│             │                                    │
│             ▼                                    │
│  ┌─────────────────────┐                         │
│  │ Position Validation │                         │
│  │                     │                         │
│  │ Check for water/    │                         │
│  │ space tiles and     │                         │
│  │ find valid nearby   │                         │
│  │ position if needed  │                         │
│  └──────────┬──────────┘                         │
│             │                                    │
│             ▼                                    │
│  ┌─────────────────────┐                         │
│  │ Favorite Check      │                         │
│  └──────────┬──────────┘                         │
│             │                                    │
└─────────────┼────────────────────────────────────┘
              │
              ▼
  ┌───────────────────────────┐
  │  Return normalized data:  │
  │  - Position (nrm_pos)     │
  │  - Tag object (nrm_tag)   │
  │  - Chart tag (nrm_chart)  │
  │  - Favorite (nrm_favorite)│
  └───────────────────────────┘
```

## Detailed Process Steps

#### i. Notes on tag, chart_tag structure and some other workflow notes
  - A tag must have a valid chart_tag
  - The tag's gps reflects the chart_tag's position property and the surface it was created on
  - The tag's locked property is by default false and can only be changed in the fave bar 
  - A chart_tag may exist with or without a tag
  - Chart_tags can be created outside of our mod's interfaces so we need to be able to convert them to follow some of our constraints
  - * if we are using an existing chart tag that has no matching tag, we need to be prepared to convert that chart tag's position (which means we have to delete the old and create a new one) if the tag editor ultimately confirms the changes. the workflow should use a gps that is based on the existing chart tag but uses normalized positions (no fractional x or y), create a "fake" chart tag at the new position (this will validate a selected location) to be used for the entire flow. Upon confirm, commit the fake chart tag and destroy the original. The corresponding new tag info should be derived from this fake chart_tag and used when confirmed
  - if a tag's gps is changed, a new chart_tag will need to be recreated at the specified position and the old chart_tag ultimately should be destroyed
  -  for tag's and chart_tags being created or edited in our mod, we will use whole numbers for the gps and map_position values. Any existing chart tags that are selected and do not have whole numbers for position coords will need to be recreated at the adjusted gps position (and the old chart tag deleted) upon positive confirmation in the tag editor. If the confirmation is not made or rejected or the editor is closed, the original chart tag should remain unaffected on our map

  - if a chart tag is identified for deletion/destroy by events outside of our mod, aka we can still delete a chart tag via the vanilla tag dialogs, we must capture that event and handle the cascading deletion of the related map tag. A tag can only be deleted by it's owner which is the value of the chart_tag's last_user. Furthermore, if a chart_tag is related to a tag and that tag has is_faved_by_players other than the owner, it cannot be deleted and the player trying to delete it should be notified via player print.
  - if an existing tag's position is updated/moved, it must also update/recreate the linked chart_tag. It also needs to update the gps of any player's favorites that orginally matched the tag's gps. Favorites need to be resynced when the tag.chart_tag position is changed. Any player that has a favorite where the gps was changed should be notified via player print

Agent questions answered:
1 - i don't think this exists. it may also require tracking in the tag_editor_data (tag_data) for old vs new state
2 - there may be code in place, but I would prefer a rewrite that would take into consideration the explanation of the tag/chart_tag/favorite relationship I have described here
3 - a tag object has a property faved_by_players, which is a list of all the player's indexes who have favorited the particular tag. It needs to be curated in lock step with any location changes
4 - as it is only allowed to have a single tag/chart_tag per gps coordinate, this will not be an issue re batch notifications
5 there is an event, or possibly a few, (i am guessing on the actual names of the events but they are similar to the following) on_chart_tag_deleted, on_chart_tag_modified, on_chart_tag_created. In fact, if there is a on_chart_tag_created, we could use that event to correct any new chart tags to using our system of whole number coords
6 - yes there is a transactional aspect to all of this. we must ensure the integrity of any existing tag/chart_tag until the confirm button is successfully clicked. We need to be prepared to rollback any changes made in the process
7 use the normalize_index function in basic_helpers
8 after a tag is updated, its value in storage should be immediately updated in storage. For chart_tags, changes made should trigger a reset (clearing) of the appropriate lookup to force a lazy  load rebuild of the collection on the next access

There may be code in place to handle some of this already but it should be consolidated where possible and rewritten to match our current discussion points


Next round of agent questions answered
1. no. any data related to ongoing changes to the data in the workflow, should be tracked in the player's tag_editor_data (tag_data). The tag object should be unaware of these data objects
2. The main pain point is the lack of the current code to address the tag object/chart_tag (LuaCustomChartTag)/Favorite relations. To this point, it has been somewhat ad-hoc. We are now trying to define the sloppy system that is currently in use. There is a ton of duplication going and a lack of consolidated workflow
3. the names are on_chart_tag_added, on_chart_tag_modified and on_chart_tag_removed and the api info  exists here: https://lua-api.factorio.com/latest/events.html#on_chart_tag_added
4. i prefer temp, but it may not be possible when dealing with LuaCustomChartTag - https://lua-api.factorio.com/latest/classes/LuaCustomChartTag.html
5. there exists a method to clear the lookups collection in either the lookups.lua or cache.lua. we are specifically dealing with the lookups.surface[surface_index].chart_tags
6. The positionator should follow the current methodology being used in the mod's current version
7. keep it simple, these are generally not life-changing events. It would just be nice to have a short message telling the player's that the location of their favorite has been moved. identify the old and new location and include the chart_tag's text and/or the chart_tags icon in rich text
8. no - and i think we have covered most of the ownership issues by enabling/disabling controls in the tag editor based on ownership and other factors

Next round of questions answered
1. tags are kept in the storage.surfaces[surface_index].tags - another point to make is that there is a map table that allows for quick access to the tags, I am unsure of it's name. This map table as well as the map table for the lookups.surfaces[surface_index].chart_tags has a similar table. These tables need to be maintained when changes are made to the underlying objects alongside the actual collections
2. i don't think i have a rich text formatter - create one
3. it was my uunderstanding that the event handlers mentioned occur after the vanilla action was taken. We just need to play catchup to keep our listings concurrent
4. the handlers are in place. how complete they are is in question
5. no. and if any  do exist they are stale
















### 1. Initial Conversion

```lua
-- Get the position we right-clicked upon
local cursor_position = event.cursor_position
if not cursor_position or not (cursor_position.x and cursor_position.y) then
  return
end

-- Normalize the clicked position and convert to GPS string
local normalized_gps = gps_parser.gps_from_map_position(cursor_position, player.surface.index)

-- this gets rid of the possibility that we would use a fractional gps coordinate for targeting a landing location
```

The first step converts the raw cursor position (x, y coordinates) into a canonical GPS string format in the format `xxx.yyy.s` where x/y are normalized, padded numbers and s is the surface index.

### 2. Context Validation

```lua
local function validate_and_prepare_context(player, intended_gps)
  if not player or not player.valid then
    return nil, ErrorHandler.error("Invalid player reference")
  end
  
  if not intended_gps or intended_gps == "" then
    return nil, ErrorHandler.error("Invalid GPS string provided")
  end

  local landing_position = GPSCore.map_position_from_gps(intended_gps)
  if not landing_position then
    return nil, ErrorHandler.error("Could not parse GPS coordinates")
  end
  
  local player_settings = Settings:getPlayerSettings(player)
  local search_radius = player_settings.teleport_radius or Constants.settings.TELEPORT_RADIUS_DEFAULT
  
  -- ... validation successful, prepare context object
  return context, ErrorHandler.success()
end
```

The context validation step ensures:
- Player object is valid
- GPS string is valid and can be parsed
- Creates a context object with player settings and search radius information

### 3. Exact Match Search

--- Match tag/chart_tag to the gps we clicked on, if there is no exact match, continue on to the next search - area
--- If the chart_tag is pre-existing and does not use whole numbers for position x and y, we will need to update/recreate upon final confirmation
```lua
local function find_exact_matches(context, callbacks)
  -- Check if there's a tag at this exact GPS coordinate
  local tag = callbacks.get_tag_by_gps_func(context.intended_gps)
  local adjusted_gps = context.intended_gps
  local chart_tag = nil
  local check_for_grid_snap = true

  if tag and tag.gps then
    -- Found exact tag match
    chart_tag = tag.chart_tag
    adjusted_gps = tag.gps
    check_for_grid_snap = false
  else
    -- Check for standalone chart tag
    chart_tag = callbacks.get_chart_tag_by_gps_func(context.intended_gps)
    if chart_tag and chart_tag.position then
      adjusted_gps = GPSCore.gps_from_map_position(chart_tag.position, context.player.surface.index)
      check_for_grid_snap = true
    end
  end
  
  return tag, chart_tag, adjusted_gps, check_for_grid_snap
end
```

The exact match search:
1. Checks if there's a Tag object at this exact GPS
2. If found, retrieves the associated chart tag
3. If not, checks if there's a standalone chart tag at this position

### 4. Nearby Match Search

```lua
local function find_nearby_matches(context, callbacks, tag, chart_tag, adjusted_gps, check_for_grid_snap)
  if not chart_tag then    -- Search for the nearest chart tag to the clicked position
    local in_area_chart_tag = Helpers.get_nearest_tag_to_click_position(context.player, context.landing_position, context.search_radius)
    
    if in_area_chart_tag and in_area_chart_tag.position then
      local in_area_gps = GPSCore.gps_from_map_position(in_area_chart_tag.position, context.player.surface.index)
      
      -- Check if found chart tag has associated tag
      local in_area_tag = callbacks.get_tag_by_gps_func(in_area_gps)
      if in_area_tag and in_area_tag.gps then
        tag = in_area_tag
        chart_tag = in_area_tag.chart_tag
        adjusted_gps = in_area_tag.gps
        check_for_grid_snap = chart_tag == nil
      else
        tag = nil
        chart_tag = in_area_chart_tag
        check_for_grid_snap = true
      end
    end
  end
  
  return tag, chart_tag, adjusted_gps, check_for_grid_snap
end
```

The nearby match search:
1. Only runs if no exact chart tag was found
2. Uses player's teleport radius setting to search for nearby tags
3. If found, gets the associated tag object or uses the chart tag directly

### 5. Grid Snap Processing

```lua
local function handle_grid_snap_requirements(context, tag, chart_tag)
  -- Case 1: We have tag but no valid chart_tag - create new chart_tag
  if tag and tag.gps and (not chart_tag or not chart_tag.valid) then
    local tag_position = GPSCore.map_position_from_gps(tag.gps)
    if not tag_position then return tag, chart_tag, context.intended_gps end
    
    -- Create new chart_tag at tag's position
    local chart_tag_spec = {
      position = tag_position,
      icon = {},
      text = "tag gps: " .. tag.gps,
      last_user = context.player.name
    }

    local new_chart_tag = GPSChartHelpers.create_and_validate_chart_tag(context.player, chart_tag_spec)
    tag.chart_tag = new_chart_tag
    chart_tag = new_chart_tag
    
    if chart_tag and chart_tag.position then
      local adjusted_gps = GPSCore.gps_from_map_position(chart_tag.position, context.player.surface.index)
      return tag, chart_tag, adjusted_gps
    end
    
  -- Case 2: We have chart_tag but position needs alignment
  elseif chart_tag and chart_tag.valid and chart_tag.position then
    if not basic_helpers.is_whole_number(chart_tag.position.x) or not basic_helpers.is_whole_number(chart_tag.position.y) then
      -- Align to whole numbers
      local x = basic_helpers.normalize_index(chart_tag.position.x)
      local y = basic_helpers.normalize_index(chart_tag.position.y)
      if x and y then
        local rehomed_chart_tag = GPSChartHelpers.align_chart_tag_position(context.player, chart_tag)
        if rehomed_chart_tag then
          chart_tag = rehomed_chart_tag
        end
      }
    }
    
    -- Return aligned position
    if chart_tag and chart_tag.position then
      local adjusted_gps = GPSCore.gps_from_map_position(chart_tag.position, context.player.surface.index)
      return tag, chart_tag, adjusted_gps
    }
    
  -- Case 3: No tag or chart_tag - create temporary one for validation
  else
    local intended_position = GPSCore.map_position_from_gps(context.intended_gps)
    if not intended_position then return nil, nil, context.intended_gps end
    
    -- Create temporary chart_tag for validation
    local chart_tag_spec = {
      position = intended_position,
      icon = {},
      text = "tag gps: " .. context.intended_gps,
      last_user = context.player.name
    }

    local temp_chart_tag = GPSChartHelpers.create_and_validate_chart_tag(context.player, chart_tag_spec)
    if temp_chart_tag and temp_chart_tag.position then
      local adjusted_gps = GPSCore.gps_from_map_position(temp_chart_tag.position, context.player.surface.index)
      -- Destroy temporary chart_tag
      temp_chart_tag.destroy()
      return nil, nil, adjusted_gps
    }
  }
  
  return tag, chart_tag, context.intended_gps
}
```

The grid snap processing:
1. If tag exists but chart tag doesn't: creates a new chart tag at the tag's position
2. If chart tag exists: ensures coordinates are whole numbers
3. If neither exists: creates temporary chart tag to validate position, then destroys it

### 5. Position Validation

```lua
-- Check if the position is on water or space
local map_position = GPSCore.map_position_from_gps(adjusted_gps)
if map_position and not PositionValidator.is_valid_tag_position(player, map_position, true) then
  -- Try to find valid position nearby
  local valid_position = PositionValidator.find_valid_position(player, map_position, context.search_radius)
  if valid_position then
    adjusted_gps = GPSCore.gps_from_map_position(valid_position, player.surface.index)
    ErrorHandler.debug_log("Adjusted position to avoid water/space", { 
      new_position = valid_position,
      new_gps = adjusted_gps
    })
  else
    -- Could not find valid position
    ErrorHandler.debug_log("Could not find valid position nearby")
    -- Return nil to indicate invalid position
    return nil, nil, nil, nil
  end
end
```

The position validation step:
1. Checks if the normalized position is on water or space tiles
2. If invalid, searches for a valid position within the search radius
3. Updates the GPS if a valid nearby position is found
4. Returns nil if no valid position can be found

### 6. Favorites Association

```lua
local function finalize_position_data(context, adjusted_gps, tag, chart_tag, callbacks)
  -- Check if this is a player favorite
  local matching_player_favorite = callbacks.is_player_favorite_func(context.player, adjusted_gps)
  
  local adjusted_pos = GPSCore.map_position_from_gps(adjusted_gps)
  if not adjusted_pos then return nil, nil, nil, nil end
  
  return adjusted_pos, tag, chart_tag, matching_player_favorite
end
```

The favorites association step:
1. Checks if the normalized position matches any of the player's favorites
2. Returns the final normalized data

## Validation Rules

The position normalization process includes several validation rules to ensure only valid positions can be tagged:

### Player Permission Checks

```lua
if not (player && player.force && player.surface && player.force.is_chunk_charted) then 
  return false
end
```

- Player must have a valid force and surface
- Player must be able to check chart status

### Chunk Charting Requirement

```lua
local chunk = { x = math.floor(map_position.x / 32), y = math.floor(map_position.y / 32) }
if not player.force.is_chunk_charted(player.surface, chunk) then
  player:print("[TeleportFavorites] You are trying to create a tag in uncharted territory")
  return false
end
```

- The chunk must be charted by the player's force
- Players cannot tag unexplored areas

### Terrain Restrictions

```lua
if Helpers.is_water_tile(player.surface, map_position) or Helpers.is_space_tile(player.surface, map_position) then
  player:print("[TeleportFavorites] You cannot tag water or space in this interface")
  return false
end
```

- Cannot tag water tiles
- Cannot tag space tiles

### Chart Tag Validation

The `create_and_validate_chart_tag` function creates a temporary chart tag and checks if the Factorio API allows it. This handles any edge cases not covered by the explicit checks above.

## Outcome

The position normalization process returns four key pieces of data:

1. `nrm_pos`: The normalized map position coordinates (whole-number aligned)
2. `nrm_tag`: The associated Tag object, if any
3. `nrm_chart_tag`: The associated ChartTag object, if any
4. `nrm_favorite`: The associated player favorite, if any

This data is then used to create the tag editor data structure:

```lua
local tag_data = Cache.create_tag_editor_data({
  gps = gps,
  locked = nrm_favorite and nrm_favorite.locked or false,
  is_favorite = nrm_favorite ~= nil,
  icon = nrm_chart_tag and nrm_chart_tag.icon or "",
  text = nrm_chart_tag and nrm_chart_tag.text or "",
  tag = nrm_tag or nil,
  chart_tag = nrm_chart_tag or nil
})
```

## Related Files

The position normalization logic is primarily implemented in these files:

- `core/utils/gps_position_normalizer.lua`: Main normalization logic
- `core/utils/gps_core.lua`: Core GPS utility functions  
- `core/utils/gps_chart_helpers.lua`: Chart tag creation and validation
- `core/utils/position_validator.lua`: Position validation and terrain checking
- `core/utils/basic_helpers.lua`: Grid alignment and number normalization utilities
- `core/utils/error_handler.lua`: Error handling and logging
- `core/utils/settings_access.lua`: Player settings access

### Removed Files

**NOTE: All developer mode and Positionator files have been removed from the codebase.**

The following files were part of the Positionator system but have been removed:
- ~~`core/utils/positionator.lua`~~: Position adjustment dialog and visualization (REMOVED)
- ~~`docs/positionator_dev_tool.md`~~: Documentation for the Positionator tool (REMOVED)
- ~~`core/utils/dev_environment.lua`~~: Detection of development mode and feature toggles (REMOVED)
- ~~`core/utils/dev_init.lua`~~: Initialization of development features (REMOVED)
- ~~`core/utils/dev_mode.lua`~~: Development mode utilities (REMOVED)

## Key Benefits

This complex normalization process ensures:

1. **Grid Alignment**: Tags align properly to the game's grid system (whole numbers only)
2. **Smart Detection**: Existing tags and chart tags are properly associated
3. **Nearby Search**: Nearby tags are found if the player didn't click exactly on a tag
4. **Position Validation**: Only valid positions that can be tagged are processed, with automatic adjustment away from water/space tiles
5. **Relationship Management**: All related objects (tags, chart tags, favorites) are properly linked
6. **Error Handling**: Comprehensive validation and error reporting throughout the process

The normalization process is designed to be robust and handle edge cases while maintaining data integrity and providing a smooth user experience.
