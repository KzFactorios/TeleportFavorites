-- admin_utils_mock.lua
-- Mock implementation of admin utilities for testing

local AdminUtils = {}

-- Mock admin check that always returns false by default
AdminUtils.is_admin = function(player)
    return player and player.valid and player.name == "AdminPlayer"
end

-- Mock chart tag edit permission check
AdminUtils.can_edit_chart_tag = function(player, tag)
    if not player or not player.valid then return false end
    if not tag then return false end
    
    -- Admin can always edit
    if AdminUtils.is_admin(player) then return true end
    
    -- Owner can edit their own tags
    if tag.last_user == player.name then return true end
    
    return false
end

-- Mock player permission check
AdminUtils.has_permission = function(player, permission)
    return player and player.valid and (
        AdminUtils.is_admin(player) or
        (player.permission_group and player.permission_group.allows_action and 
         player.permission_group.allows_action(permission))
    )
end

-- Mock setting manipulation check
AdminUtils.can_write_setting = function(player, setting_name)
    return AdminUtils.has_permission(player, "write-setting")
end

return AdminUtils