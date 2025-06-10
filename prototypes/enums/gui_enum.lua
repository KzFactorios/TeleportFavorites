local GuiEnum = {
  GUI_FRAME = {},
  GUI_ELEMENT = {}
}

--- @class GUI_FRAME
local GUI_FRAME = {
  DATA_VIEWER = "data_viewer_frame",
  FAVE_BAR = "fave_bar_frame",
  TAG_EDITOR = "tag_editor_frame",
}

--- @class GUI_ELEMENT
local GUI_ELEMENT = {
  TELEPORT_BUTTON = "tf_teleport_button"
}

for k, v in pairs(GUI_FRAME) do
  GuiEnum.GUI_FRAME[k] = v
end

for k, v in pairs(GUI_ELEMENT) do
  GuiEnum.GUI_ELEMENT[k] = v
end

return GuiEnum
