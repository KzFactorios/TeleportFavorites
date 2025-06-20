-- prototypes/item/selection_tool.lua
-- Custom selection tool for tag move mode

data:extend({
  {
    type = "selection-tool",
    name = "tf-move-tag-selector",
    icon = "__TeleportFavorites__/graphics/square-custom-tag-in-map-view.png",
    --scale = .5,
    priority = "extra-high-no-scale",
    flags = { "only-in-cursor", "not-stackable" },
    subgroup = "tool",
    order = "z[tf-move-tag-selector]",
    stack_size = 1,
    selection_mode = { "any-tile" },
    alt_selection_mode = { "any-tile" },
    selection_color = { r = 1, g = 0.7, b = 0.1 },
    alt_selection_color = { r = 1, g = 0.7, b = 0.1 },
    selection_cursor_box_type = "entity",
    alt_selection_cursor_box_type = "entity",
    show_in_library = false,
    show_on_created = false,
    draw_label_for_cursor_render = true,
    icon_mipmaps = 1,
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
