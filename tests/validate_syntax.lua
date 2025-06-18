--[[
Simple syntax validation script for TeleportFavorites mod
Checks core files for basic Lua syntax errors without requiring Factorio runtime
]]

print("🔍 Validating TeleportFavorites Lua Syntax...")
print("=" .. string.rep("=", 50))

local files_to_check = {
  "core/utils/chart_tag_utils.lua",
  "core/cache/cache.lua",
  "core/cache/lookups.lua",
  "core/control/control_tag_editor.lua",
  "core/tag/tag.lua",
  "control.lua"
}

local function check_syntax(file_path)
  local file = io.open(file_path, "r")
  if not file then
    print("❌ " .. file_path .. " - File not found")
    return false
  end
  
  local content = file:read("*all")
  file:close()
  
  -- Try to compile the Lua code
  local chunk, error_msg = load(content, file_path)
  
  if chunk then
    print("✅ " .. file_path .. " - Syntax OK")
    return true
  else
    print("❌ " .. file_path .. " - Syntax Error:")
    print("   " .. (error_msg or "Unknown error"))
    return false
  end
end

local success_count = 0
local total_count = #files_to_check

print("Checking " .. total_count .. " core files...\n")

for _, file_path in ipairs(files_to_check) do
  if check_syntax(file_path) then
    success_count = success_count + 1
  end
end

print("\n" .. string.rep("=", 50))
print("📊 Results: " .. success_count .. "/" .. total_count .. " files passed syntax validation")

if success_count == total_count then
  print("🎉 All files have valid Lua syntax!")
  os.exit(0)
else
  print("⚠️  Some files have syntax errors that need to be fixed")
  os.exit(1)
end
