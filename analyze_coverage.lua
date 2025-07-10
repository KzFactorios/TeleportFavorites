-- Simple script to analyze the existing coverage report
-- This can be used when LuaCov is not available directly

local function read_file(path)
  local file = io.open(path, "r")
  if not file then return nil end
  local content = file:read("*all")
  file:close()
  return content
end

local function extract_module_coverage(content)
  local modules = {}
  
  -- Find the summary section
  local summary_start = content:find("==============================================================================\nSummary\n==============================================================================")
  if not summary_start then
    return modules
  end
  
  -- Extract lines from the summary section
  local summary_section = content:sub(summary_start)
  local lines = {}
  for line in summary_section:gmatch("[^\r\n]+") do
    table.insert(lines, line)
  end
  
  -- Parse the summary table
  for _, line in ipairs(lines) do
    -- Look for lines with format: filename.lua   hits missed coverage%
    local filename, hits, missed, coverage = line:match("^([^%s]+%.lua)%s+(%d+)%s+(%d+)%s+([%d%.]+)%%")
    if filename and hits and missed and coverage then
      local hits_num = tonumber(hits)
      local missed_num = tonumber(missed)
      local coverage_num = tonumber(coverage)
      
      if hits_num and missed_num and coverage_num then
        local total_lines = hits_num + missed_num
        modules[filename] = {
          covered = hits_num,
          total = total_lines,
          coverage = coverage_num
        }
      end
    end
  end
  
  return modules
end

local function filter_project_modules(modules)
  local project_modules = {}
  local total_covered = 0
  local total_lines = 0
  
  for module, stats in pairs(modules) do
    -- Include modules that are file paths (contain .lua) or are project-related
    if module:match("%.lua$") or module:match("TeleportFavorites") then
      project_modules[module] = stats
      total_covered = total_covered + stats.covered
      total_lines = total_lines + stats.total
    end
  end
  
  return project_modules, total_covered, total_lines
end

local function print_production_file_summary(modules)
  print("\n==== Production File Coverage Summary ====")
  print("(Coverage of production modules, sorted best to worst)")
  
  -- Convert modules to array for sorting
  local module_list = {}
  for name, stats in pairs(modules) do
    table.insert(module_list, {
      filename = name,
      coverage = stats.coverage,
      covered = stats.covered,
      total = stats.total
    })
  end
  
  -- Sort by coverage percentage (descending - best to worst)
  table.sort(module_list, function(a, b)
    return a.coverage > b.coverage
  end)
  
  print(string.format("%-45s %8s %8s %8s %-8s", "Production File", "Lines", "Hit", "Miss", "Coverage"))
  print(string.rep("-", 80))
  
  for _, data in ipairs(module_list) do
    local miss = data.total - data.covered
    local truncated_name = data.filename
    if #truncated_name > 44 then
      truncated_name = string.sub(truncated_name, 1, 41) .. "..."
    end
    
    print(string.format("%-45s %8d %8d %8d %7.2f%%", 
                       truncated_name, data.total, data.covered, miss, data.coverage))
  end
  
  print(string.rep("-", 80))
  print(string.format("Total production files: %d", #module_list))
  
  local perfect_coverage = 0
  local good_coverage = 0  -- 75%+
  local fair_coverage = 0  -- 50%+
  local poor_coverage = 0  -- <50%
  
  for _, data in ipairs(module_list) do
    if data.coverage >= 100 then
      perfect_coverage = perfect_coverage + 1
    elseif data.coverage >= 75 then
      good_coverage = good_coverage + 1
    elseif data.coverage >= 50 then
      fair_coverage = fair_coverage + 1
    else
      poor_coverage = poor_coverage + 1
    end
  end
  
  print(string.format("Coverage breakdown: Perfect(100%%):%d, Good(75%%+):%d, Fair(50%%+):%d, Poor(<50%%):%d", 
                     perfect_coverage, good_coverage, fair_coverage, poor_coverage))
end

local function print_coverage_summary(modules, total_covered, total_lines)
  print("\n==== Coverage Summary ====")
  
  if total_lines == 0 then
    print("No coverage data found for project modules.")
    return
  end
  
  local total_coverage = (total_covered / total_lines) * 100
  print(string.format("Overall coverage: %.2f%% (%d/%d lines)", 
                     total_coverage, total_covered, total_lines))
  
  -- Sort modules by coverage percentage (ascending)
  local sorted_modules = {}
  for name, stats in pairs(modules) do
    table.insert(sorted_modules, {name = name, stats = stats})
  end
  
  table.sort(sorted_modules, function(a, b) 
    return a.stats.coverage < b.stats.coverage
  end)
  
  print("\nModules with lowest coverage:")
  for i = 1, math.min(5, #sorted_modules) do
    local module = sorted_modules[i]
    print(string.format("  %s: %.2f%% (%d/%d lines)", 
                       module.name, module.stats.coverage, 
                       module.stats.covered, module.stats.total))
  end
  
  print("\nModules with highest coverage:")
  for i = #sorted_modules, math.max(#sorted_modules - 4, 1), -1 do
    local module = sorted_modules[i]
    print(string.format("  %s: %.2f%% (%d/%d lines)", 
                       module.name, module.stats.coverage, 
                       module.stats.covered, module.stats.total))
  end
end

-- Main execution
local report_content = read_file("luacov.report.out")

if not report_content then
  print("Error: Could not find luacov.report.out file")
  print("Please make sure tests have been run with LuaCov enabled.")
  os.exit(1)
end

local modules = extract_module_coverage(report_content)
local project_modules, total_covered, total_lines = filter_project_modules(modules)

print_coverage_summary(project_modules, total_covered, total_lines)
print_production_file_summary(project_modules)
