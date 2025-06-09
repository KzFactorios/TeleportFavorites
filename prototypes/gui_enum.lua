local GuiEnum = {
  GUI_FRAMES = {},
  GUI_ELEMENTS = {}
}

local GUI_FRAMES = {
  DATA_VIEWER = "data_viewer_frame",
  FAVE_BAR = "fave_bar_frame",
  TAG_EDITOR = "tag_editor_frame",
}

local GUI_ELEMENTS = {
  TELEPORT_BUTTON = "tf_teleport_button"
}

for k, v in pairs(GUI_FRAMES) do
  GuiEnum.GUI_FRAMES[k] = v
end

for k, v in pairs(GUI_ELEMENTS) do
  GuiEnum.GUI_ELEMENTS[k] = v
end

return GuiEnum
