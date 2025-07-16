---@diagnostic disable: undefined-global
--[[
Migration System Example - How to use the new version comparison API

This example shows how migration logic would be implemented when needed.
The Cache module now properly preserves the stored version until after 
migrations are complete.
]]

local Cache = require("core.cache.cache")

-- Example migration handler that would be called from control.lua on_init
local function handle_migrations()
  -- Check if migration is needed
  local needs_migration, stored_version, current_version = Cache.check_migration_needed()
  
  if needs_migration then
    print(string.format("Migration needed: %s -> %s", stored_version or "nil", current_version))
    
    -- Example migration logic based on version comparison
    if stored_version == "0.0.124" and current_version == "0.0.125" then
      -- Migrate from 0.0.124 to 0.0.125
      migrate_124_to_125()
    elseif stored_version == "0.0.123" then
      -- Chain migrations if needed
      migrate_123_to_124()
      migrate_124_to_125()
    end
    
    -- Mark migration complete - this updates storage.mod_version
    Cache.complete_migration()
    print("Migration completed")
  else
    print("No migration needed")
  end
end

-- Example migration functions
local function migrate_124_to_125()
  print("Running migration from 0.0.124 to 0.0.125")
  -- Example: Add new field to all player data
  for player_index, player_data in pairs(storage.players or {}) do
    if not player_data.new_field_added_in_125 then
      player_data.new_field_added_in_125 = true
      print(string.format("Updated player %d with new field", player_index))
    end
  end
end

local function migrate_123_to_124()
  print("Running migration from 0.0.123 to 0.0.124")
  -- Example: Restructure surface data
  for surface_index, surface_data in pairs(storage.surfaces or {}) do
    if surface_data.old_format then
      surface_data.new_format = convert_old_to_new_format(surface_data.old_format)
      surface_data.old_format = nil
      print(string.format("Migrated surface %d to new format", surface_index))
    end
  end
end

local function convert_old_to_new_format(old_data)
  -- Convert old data structure to new format
  return {
    tags = old_data.tags or {},
    metadata = {
      converted_from_old_format = true,
      conversion_time = game and game.tick or 0
    }
  }
end

return {
  handle_migrations = handle_migrations,
  migrate_124_to_125 = migrate_124_to_125,
  migrate_123_to_124 = migrate_123_to_124
}
