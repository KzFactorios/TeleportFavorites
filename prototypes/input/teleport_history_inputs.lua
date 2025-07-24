data:extend({
    type = "custom-input",
    name = "teleport_history-prev",
    key_sequence = "CONTROL + MINUS", -- Changed format from CONTROL-- to CONTROL + MINUS
    consuming = "none"
  },
  {
    type = "custom-input",
    name = "teleport_history-next",
    key_sequence = "CONTROL + EQUALS", -- Changed from CONTROL-+ to CONTROL + EQUALS (+ is typically the EQUALS key)
    consuming = "none"
  },
  {
    type = "custom-input",
    name = "teleport_history-first",
    key_sequence = "CONTROL + SHIFT + MINUS", -- Changed format
    consuming = "none"
  },
  {
    type = "custom-input",
    name = "teleport_history-last",
    key_sequence = "CONTROL + SHIFT + EQUALS", -- Changed format
    consuming = "none"
  },
  {
    type = "custom-input",
    name = "teleport_history-clear",
    key_sequence = "CONTROL + SHIFT + BACKSPACE", -- Restored original key sequence
    consuming = "none"
  }
})
