-- factorio_defines_mock.lua
-- Mock implementation of Factorio's defines table

local defines = {
    controllers = {
        character = 1,
        god = 2,
        editor = 3,
        spectator = 4,
        cutscene = 5,
        ghost = 6
    },
    
    riding = { 
        acceleration = {
            none = 0,
            accelerating = 1,
            braking = 2
        },
        direction = {
            left = 1,
            straight = 2, 
            right = 3
        }
    },

    mouse_button_type = {
        none = 0,
        left = 1,
        right = 2,
        middle = 3
    }
}

return defines