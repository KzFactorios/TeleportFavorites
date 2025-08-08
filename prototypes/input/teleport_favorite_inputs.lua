---@diagnostic disable: undefined-global

-- Custom input definitions for favorite slot teleport hotkeys (Ctrl+1..Ctrl+0)

data:extend({
  {
    type = "custom-input",
    name = "teleport_history-toggle",
    key_sequence = "CONTROL + SHIFT + T",
    consuming = "none",
    order = "tf-history-00"
  },
  {
    type = "custom-input",
    name = "teleport_history-prev",
    key_sequence = "CONTROL + MINUS",
    consuming = "none"
  },
  {
    type = "custom-input",
    name = "teleport_history-next",
    key_sequence = "CONTROL + EQUALS",
    consuming = "none"
  },
  {
    type = "custom-input",
    name = "teleport_history-first",
    key_sequence = "CONTROL + SHIFT + MINUS",
    consuming = "none"
  },
  {
    type = "custom-input",
    name = "teleport_history-last",
    key_sequence = "CONTROL + SHIFT + EQUALS",
    consuming = "none"
  },
  {
    type = "custom-input",
    name = "teleport_history-clear",
    key_sequence = "CONTROL + SHIFT + BACKSPACE",
    consuming = "none"
  },
  {
    type = "custom-input",
    name = "teleport_to_favorite-1",
    key_sequence = "CONTROL + 1",
    consuming = "none"
  },
  {
    type = "custom-input",
    name = "teleport_to_favorite-2",
    key_sequence = "CONTROL + 2",
    consuming = "none"
  },
  {
    type = "custom-input",
    name = "teleport_to_favorite-3",
    key_sequence = "CONTROL + 3",
    consuming = "none"
  },
  {
    type = "custom-input",
    name = "teleport_to_favorite-4",
    key_sequence = "CONTROL + 4",
    consuming = "none"
  },
  {
    type = "custom-input",
    name = "teleport_to_favorite-5",
    key_sequence = "CONTROL + 5",
    consuming = "none"
  },
  {
    type = "custom-input",
    name = "teleport_to_favorite-6",
    key_sequence = "CONTROL + 6",
    consuming = "none"
  },
  {
    type = "custom-input",
    name = "teleport_to_favorite-7",
    key_sequence = "CONTROL + 7",
    consuming = "none"
  },
  {
    type = "custom-input",
    name = "teleport_to_favorite-8",
    key_sequence = "CONTROL + 8",
    consuming = "none"
  },
  {
    type = "custom-input",
    name = "teleport_to_favorite-9",
    key_sequence = "CONTROL + 9",
    consuming = "none"
  },
  {
    type = "custom-input",
    name = "teleport_to_favorite-10",
    key_sequence = "CONTROL + 0",
    consuming = "none"
  }
})
