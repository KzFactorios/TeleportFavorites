---@diagnostic disable: undefined-global

--[[
helpers_suite.lua
TeleportFavorites Factorio Mod
-----------------------------
Unified interface for all helper utilities used throughout the mod.

This module imports and re-exports functions from specialized helper modules:
- MathHelpers: mathematical operations
- TableHelpers: table manipulation utilities
- FunctionalHelpers: functional programming utilities (map, filter, reduce, etc.)
- GameHelpers: game-specific utilities (teleport, sound, tag collision, etc.)
- GuiHelpers: GUI-related utilities (button creation, error handling, etc.)
- PositionHelpers: position calculations (already in separate file)

All helpers are static and namespaced under Helpers for backward compatibility.
]]

-- Import specialized helper modules
local MathHelpers = require("core.utils.math_helpers")
local TableHelpers = require("core.utils.table_helpers")
local FunctionalHelpers = require("core.utils.functional_helpers")
local GameHelpers = require("core.utils.game_helpers")
local GuiHelpers = require("core.utils.gui_helpers")

---@class Helpers
local Helpers = {}

-- Re-export Math helpers
Helpers.math_round = MathHelpers.math_round

-- Re-export Table helpers
Helpers.tables_equal = TableHelpers.tables_equal
Helpers.deep_copy = TableHelpers.deep_copy
Helpers.shallow_copy = TableHelpers.shallow_copy
Helpers.remove_first = TableHelpers.remove_first
Helpers.table_is_empty = TableHelpers.table_is_empty
Helpers.create_empty_indexed_array = TableHelpers.create_empty_indexed_array
Helpers.array_sort_by_index = TableHelpers.array_sort_by_index
Helpers.index_is_in_table = TableHelpers.index_is_in_table
Helpers.find_by_predicate = TableHelpers.find_by_predicate
Helpers.table_count = TableHelpers.table_count
Helpers.table_find = TableHelpers.table_find
Helpers.table_remove_value = TableHelpers.table_remove_value
Helpers.find_first_match = TableHelpers.find_first_match
Helpers.process_until_match = TableHelpers.process_until_match

-- Re-export Functional programming helpers
Helpers.map = FunctionalHelpers.map
Helpers.filter = FunctionalHelpers.filter
Helpers.reduce = FunctionalHelpers.reduce
Helpers.for_each = FunctionalHelpers.for_each
Helpers.partition = FunctionalHelpers.partition

-- Re-export Game helpers
Helpers.is_on_space_platform = GameHelpers.is_on_space_platform
Helpers.get_nearest_tag_to_click_position = GameHelpers.get_nearest_tag_to_click_position
Helpers.is_walkable_position = GameHelpers.is_walkable_position
Helpers.is_water_tile = GameHelpers.is_water_tile
Helpers.is_space_tile = GameHelpers.is_space_tile
Helpers.safe_teleport = GameHelpers.safe_teleport
Helpers.safe_play_sound = GameHelpers.safe_play_sound
Helpers.player_print = GameHelpers.player_print
Helpers.update_favorite_state = GameHelpers.update_favorite_state
Helpers.update_tag_chart_fields = GameHelpers.update_tag_chart_fields
Helpers.update_tag_position = GameHelpers.update_tag_position

-- Re-export GUI helpers
Helpers.handle_error = GuiHelpers.handle_error
Helpers.safe_destroy_frame = GuiHelpers.safe_destroy_frame
Helpers.show_error_label = GuiHelpers.show_error_label
Helpers.clear_error_label = GuiHelpers.clear_error_label
Helpers.set_button_state = GuiHelpers.set_button_state
Helpers.build_favorite_tooltip = GuiHelpers.build_favorite_tooltip
Helpers.create_slot_button = GuiHelpers.create_slot_button
Helpers.get_gui_frame_by_element = GuiHelpers.get_gui_frame_by_element
Helpers.find_child_by_name = GuiHelpers.find_child_by_name

return Helpers
