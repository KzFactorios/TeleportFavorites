-- prototypes/item/selection_tool.lua
-- Custom selection tool for tag move mode

data:extend({
  {
    type = "selection-tool",
    name = "tf-move-tag-selector",
    icon = "__TeleportFavorites__/graphics/square-custom-tag-in-map-view.png",
    --scale = .5,
    flags = { "only-in-cursor", "not-stackable" },
    subgroup = "tool",
    order = "z[tf-move-tag-selector]",
    stack_size = 1,
    draw_label_for_cursor_render = true,
    select = {
      type = "position",
      mode = { "any-tile" },
      border_color = { r = 1, g = 0.7, b = 0.1, a = 1 },
      cursor_box_type = "entity",
      tile_filters = { "water", "deepwater", "deepwater-green", "water-green" },
      tile_filter_mode = "blacklist"
    },
    alt_select = {
      type = "position",
      mode = { "any-tile" },
      border_color = { r = 1, g = 0.7, b = 0.1, a = 1 },
      cursor_box_type = "entity",
      tile_filters = { "water", "deepwater", "deepwater-green", "water-green" },
      tile_filter_mode = "blacklist"
    }
  }
})
