---@alias defines_inventory table<string, integer>
---@class defines
---@field inventory defines_inventory  -- Inventory types, e.g., "player_main", "player_quickbar", etc.

---@class LuaPlayer
---@field index uint
---@field name string
---@field connected boolean
---@field surface LuaSurface
---@field position MapPosition
---@field force LuaForce
---@field print fun(self: LuaPlayer, message: string)
---@field open_map fun(self: LuaPlayer, position: MapPosition, scale?: double)
---@field teleport fun(self: LuaPlayer, position: MapPosition, surface?: LuaSurface)
---@field get_inventory fun(self: LuaPlayer, inventory: defines_inventory): LuaInventory
---@field is_player fun(self: LuaPlayer): boolean
---@field admin boolean
---@field online_time uint
---@field afk_time uint
---@field permissions LuaPermissionGroup
---@field tag string
---@field color Color
---@field opened any
---@field selected any
---@field mod_settings table<string, any>

---@class LuaPermissionGroup
---@field index uint
---@field name string
---@field group_id uint
---@field players LuaPlayer[]
---@field add_player fun(self: LuaPermissionGroup, player: LuaPlayer)
---@field remove_player fun(self: LuaPermissionGroup, player: LuaPlayer)
---@field destroy fun(self: LuaPermissionGroup)
---@class uint: number
---@class double: number

--- @class LuaCustomTable
--- Represents a custom table in Factorio, behaves like a Lua table but with additional API features
--- @field [any] any  -- Can be indexed with any key, returns any value

---@class Color
---@field r double  -- Red component (0.0 - 1.0)
---@field g double  -- Green component (0.0 - 1.0)
---@field b double  -- Blue component (0.0 - 1.0)
---@field a? double -- Optional alpha component (0.0 - 1.0)

---@class MapPosition
---@field x number
---@field y number

--- @class ChunkPosition
--- @field x number
--- @field y number
--- A MapPosition can be translated to a ChunkPosition by dividing the x/y values by 32.

---@class LuaInventory
---@field valid boolean
---@field is_empty fun(self: LuaInventory): boolean
---@field get_item_count fun(self: LuaInventory, item_name?: string): uint
---@field insert fun(self: LuaInventory, item: {name: string, count: uint}): uint
---@field remove fun(self: LuaInventory, item: {name: string, count: uint}): uint
---@field clear fun(self: LuaInventory)
---@field get_contents fun(self: LuaInventory): table<string, uint>
---@field set_filter fun(self: LuaInventory, index: uint, filter: string)
---@field get_filter fun(self: LuaInventory, index: uint): string

---@class chartTagSpec
---@field position MapPosition
---@field text string
---@field icon? SignalID[]        -- Optional: array of SignalID for tag icons
---@field last_user string        -- Player name of last user to edit
---@field surface LuaSurface      -- Surface where the tag is placed
---@field color? Color            -- Optional: color of the tag
---@field tag_id? uint            -- Optional: unique identifier for the tag

---@class LuaForce
---@field name string
---@field index uint
---@field players LuaPlayer[]
---@field technologies table<string, LuaTechnology>
---@field is_player fun(self: LuaForce): boolean
---@field get_spawn_position fun(self: LuaForce, surface: LuaSurface): MapPosition
---@field set_spawn_position fun(self: LuaForce, position: MapPosition, surface: LuaSurface)

---@class LuaSurface
---@field index uint
---@field name string
---@field map_gen_settings table
---@field freeze_daytime boolean
---@field darkness double
---@field always_day boolean
---@field daytime double
---@field valid boolean
---@field create_entity fun(self: LuaSurface, params: table): LuaEntity
---@field find_entities fun(self: LuaSurface, area?: BoundingBox): LuaEntity[]
---@field find_chart_tags fun(self: LuaSurface, force: LuaForce): chartTagSpec[]
---@field get_tile fun(self: LuaSurface, position: MapPosition): LuaTile
---@field request_to_generate_chunks fun(self: LuaSurface, position: MapPosition, radius: uint)

---@class LuaEntity
---@field name string
---@field position MapPosition
---@field surface LuaSurface
---@field force LuaForce
---@field valid boolean
---@field destroy fun(self: LuaEntity)
---@field teleport fun(self: LuaEntity, position: MapPosition, surface?: LuaSurface)
---@field get_inventory fun(self: LuaEntity, inventory: defines_inventory): LuaInventory

---@class LuaTile
---@field name string
---@field position MapPosition
---@field valid boolean
---@field surface LuaSurface

---@class BoundingBox
---@field left_top MapPosition
---@field right_bottom MapPosition

---@class LuaTechnology
---@field name string
---@field enabled boolean
---@field researched boolean
---@field level uint
---@field research_unit_count uint
---@field valid boolean

---@class SignalID
---@field type string   -- "item", "fluid", or "virtual"
---@field name string   -- Name of the signal (item/fluid/virtual signal name)

---@class LuaCustomChartTag
---@field tag chartTagSpec
---@field player LuaPlayer
---@field surface LuaSurface
---@field valid boolean
---@field destroy fun(self: LuaCustomChartTag)