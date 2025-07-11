-- Simple debug script to check GuiBase module
local GuiBase = require("gui.gui_base")

print("GuiBase type:", type(GuiBase))
print("GuiBase.create_element:", GuiBase.create_element)

if GuiBase.create_element then
    print("SUCCESS: create_element exists")
else
    print("ERROR: create_element missing!")
    print("Available functions:")
    for k, v in pairs(GuiBase) do
        if type(v) == "function" then
            print("  " .. k .. ": " .. type(v))
        end
    end
end
