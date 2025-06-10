local ColorEnum = {}

--- @class COLOR_ENUM
local COLOR_ENUM = {
  BLACK = { r = 0, g = 0, b = 0, a = 1 },
  BLUE = { r = .5, g = .81, b = .94, a = 1 },
  CAPTION = { r = 1, g = .9, b = .75, a = 1 },
  GREEN = { r = 0, g = 1, b = 0, a = 1 },
  GREY = { r = 0.5, g = 0.5, b = 0.5, a = 1 },
  ORANGE = { r = 0.98, g = 0.66, b = 0.22, a = 1 },
  RED = { r = 1, g = .56, b = .56, a = 1 },
  WHITE = { r = 1, g = 1, b = 1, a = 1 },

  DEFAULT_GLOW_COLOR = { r = .88, g = .69, b = .42, a = 1 },
  DEFAULT_SHADOW_COLOR = { r = 0, g = 0, b = 0, a = .35 },
  HARD_SHADOW_COLOR = { r = 0, g = 0, b = 0, a = 1 },
  DEFAULT_DIRT_COLOR = { r = .06, g = .03, b = .01, a = .39 },
  DEFAULT_DIRT_COLOR_FILLER = { r = .06, g = .03, b = .01, a = .22 },
  GREEN_BUTTON_GLOW_COLOR = { r = .53, g = .85, b = .55, a = .5 },
  ORANGE_BUTTON_GLOW_COLOR = { r = .8, g = .56, b = .12, a = .5 },
  RED_BUTTON_GLOW_COLOR = { r = .99, g = .35, b = .35, a = .5 },
}

return ColorEnum
