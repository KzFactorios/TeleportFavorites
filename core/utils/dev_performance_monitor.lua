---@diagnostic disable: undefined-global
--[[
core/utils/dev_performance_monitor.lua
TeleportFavorites Factorio Mod
-----------------------------
Simple development-only performance monitoring system.

This module provides basic performance tracking during development to help
identify bottlenecks and optimize code. Only active when debug level is DEBUG or higher.

Features:
- Event timing measurement
- Memory usage tracking
- GUI operation performance
- Cache hit/miss statistics
- Simple in-game performance dashboard

Note: This system is designed for development use only and has minimal overhead
when disabled in production.
]]

local DebugConfig = require("core.utils.debug_config")
local ErrorHandler = require("core.utils.error_handler") -- Use basic error handler to avoid circular dependency
local GameHelpers = require("core.utils.game_helpers")

---@class DevPerformanceMonitor
local DevPerformanceMonitor = {}

-- Performance metrics storage (only in development)
local performance_data = {
  event_timings = {},
  memory_snapshots = {},
  gui_operations = {},
  cache_stats = {hits = 0, misses = 0, lookups = 0},
  recent_operations = {} -- Ring buffer for last 50 operations
}

-- Configuration
local RING_BUFFER_SIZE = 50
local MEMORY_SNAPSHOT_INTERVAL = 300 -- ticks (5 seconds)

-- Only track performance in development mode
local function is_monitoring_active()
  return DebugConfig.get_level() >= DebugConfig.LEVELS.DEBUG
end

--- Initialize the performance monitoring system
function DevPerformanceMonitor.initialize()
  if not is_monitoring_active() then return end
  
  ErrorHandler.debug_log("Development performance monitor initialized")
  performance_data.start_time = game.tick
  performance_data.last_memory_snapshot = game.tick
end

--- Record an operation in the ring buffer
---@param operation table Operation data to record
local function record_operation(operation)
  if not is_monitoring_active() then return end
  
  table.insert(performance_data.recent_operations, 1, operation)
  
  -- Keep only the most recent operations
  if #performance_data.recent_operations > RING_BUFFER_SIZE then
    table.remove(performance_data.recent_operations)
  end
end

--- Measure the performance of a function
---@param operation_name string Name of the operation being measured
---@param func function Function to measure
---@param context table? Optional context data
---@return any result Function result
function DevPerformanceMonitor.measure_operation(operation_name, func, context)
  if not is_monitoring_active() then
    return func() -- Skip monitoring in production
  end
  
  local start_tick = game.tick
  local result = func()
  local end_tick = game.tick
  
  local duration = end_tick - start_tick
  
  -- Record the operation
  local operation_data = {
    name = operation_name,
    duration_ticks = duration,
    timestamp = end_tick,
    context = context or {}
  }
  
  record_operation(operation_data)
  
  -- Log slow operations
  if duration > 5 then -- More than 5 ticks is significant
    ErrorHandler.warn_log("Slow operation detected", {
      operation = operation_name,
      duration_ticks = duration,
      context = context
    })
  end
  
  return result
end

--- Record GUI operation performance
---@param gui_name string Name of the GUI being operated on
---@param operation string Type of operation (create, update, destroy)
---@param func function Function to measure
---@return any result Function result
function DevPerformanceMonitor.measure_gui_operation(gui_name, operation, func)
  return DevPerformanceMonitor.measure_operation(
    "gui_" .. operation,
    func,
    {gui_name = gui_name, operation_type = operation}
  )
end

--- Record cache statistics
---@param operation string "hit" or "miss"
---@param cache_type string Type of cache (favorites, chart_tags, etc.)
function DevPerformanceMonitor.record_cache_operation(operation, cache_type)
  if not is_monitoring_active() then return end
  
  performance_data.cache_stats.lookups = performance_data.cache_stats.lookups + 1
  
  if operation == "hit" then
    performance_data.cache_stats.hits = performance_data.cache_stats.hits + 1
  elseif operation == "miss" then
    performance_data.cache_stats.misses = performance_data.cache_stats.misses + 1
  end
  
  record_operation({
    name = "cache_" .. operation,
    cache_type = cache_type,
    timestamp = game.tick,
    hit_rate = performance_data.cache_stats.lookups > 0 and 
               (performance_data.cache_stats.hits / performance_data.cache_stats.lookups) or 0
  })
end

--- Take a memory snapshot (called periodically)
function DevPerformanceMonitor.take_memory_snapshot()
  if not is_monitoring_active() then return end
  
  local current_tick = game.tick
  if current_tick - performance_data.last_memory_snapshot < MEMORY_SNAPSHOT_INTERVAL then
    return
  end
  
  -- Simple memory usage estimation based on data structures
  local estimated_memory = {
    player_count = #game.players,
    surface_count = #game.surfaces,
    recent_operations_count = #performance_data.recent_operations,
    cache_entries = performance_data.cache_stats.lookups,
    timestamp = current_tick
  }
  
  table.insert(performance_data.memory_snapshots, estimated_memory)
  
  -- Keep only recent snapshots
  if #performance_data.memory_snapshots > 20 then
    table.remove(performance_data.memory_snapshots, 1)
  end
  
  performance_data.last_memory_snapshot = current_tick
  
  ErrorHandler.debug_log("Memory snapshot taken", estimated_memory)
end

--- Get performance summary for display
---@return table performance_summary Summary of current performance data
function DevPerformanceMonitor.get_performance_summary()
  if not is_monitoring_active() then
    return {active = false, message = "Performance monitoring disabled (debug level too low)"}
  end
  
  local recent_ops = {}
  local slow_ops = {}
  
  -- Analyze recent operations
  for _, op in ipairs(performance_data.recent_operations) do
    if op.duration_ticks and op.duration_ticks > 0 then
      table.insert(recent_ops, op)
      
      if op.duration_ticks > 3 then
        table.insert(slow_ops, op)
      end
    end
  end
  
  -- Calculate averages
  local total_duration = 0
  local gui_operations = 0
  local cache_operations = 0
  
  for _, op in ipairs(recent_ops) do
    total_duration = total_duration + (op.duration_ticks or 0)
    
    if string.match(op.name or "", "^gui_") then
      gui_operations = gui_operations + 1
    elseif string.match(op.name or "", "^cache_") then
      cache_operations = cache_operations + 1
    end
  end
  
  local avg_duration = #recent_ops > 0 and (total_duration / #recent_ops) or 0
  local cache_hit_rate = performance_data.cache_stats.lookups > 0 and 
                        (performance_data.cache_stats.hits / performance_data.cache_stats.lookups) or 0
  
  return {
    active = true,
    monitoring_since = performance_data.start_time,
    current_tick = game.tick,
    recent_operations_count = #recent_ops,
    slow_operations_count = #slow_ops,
    average_operation_duration = avg_duration,
    gui_operations_count = gui_operations,
    cache_operations_count = cache_operations,
    cache_hit_rate = cache_hit_rate,
    cache_stats = performance_data.cache_stats,
    memory_snapshots_count = #performance_data.memory_snapshots,
    recent_slow_operations = slow_ops
  }
end

--- Create a simple performance dashboard GUI
---@param player LuaPlayer Player to show dashboard to
function DevPerformanceMonitor.show_performance_dashboard(player)
  if not is_monitoring_active() then
    GameHelpers.player_print(player, "Performance monitoring is disabled. Enable DEBUG level to use.")
    return
  end
  
  local summary = DevPerformanceMonitor.get_performance_summary()
  
  GameHelpers.player_print(player, "=== TeleportFavorites Development Performance Dashboard ===")
  GameHelpers.player_print(player, "Monitoring since tick: " .. (summary.monitoring_since or 0))
  GameHelpers.player_print(player, "Current tick: " .. summary.current_tick)
  GameHelpers.player_print(player, "")
  
  GameHelpers.player_print(player, "Recent Operations (" .. summary.recent_operations_count .. " total):")
  GameHelpers.player_print(player, "  Average duration: " .. string.format("%.2f", summary.average_operation_duration) .. " ticks")
  GameHelpers.player_print(player, "  Slow operations (>3 ticks): " .. summary.slow_operations_count)
  GameHelpers.player_print(player, "  GUI operations: " .. summary.gui_operations_count)
  GameHelpers.player_print(player, "")
  
  GameHelpers.player_print(player, "Cache Performance:")
  GameHelpers.player_print(player, "  Total lookups: " .. summary.cache_stats.lookups)
  GameHelpers.player_print(player, "  Cache hits: " .. summary.cache_stats.hits)
  GameHelpers.player_print(player, "  Cache misses: " .. summary.cache_stats.misses)
  GameHelpers.player_print(player, "  Hit rate: " .. string.format("%.1f%%", summary.cache_hit_rate * 100))
  GameHelpers.player_print(player, "")
  
  GameHelpers.player_print(player, "Memory Snapshots: " .. summary.memory_snapshots_count)
  
  if #summary.recent_slow_operations > 0 then
    GameHelpers.player_print(player, "")
    GameHelpers.player_print(player, "Recent Slow Operations:")
    for i, op in ipairs(summary.recent_slow_operations) do
      if i <= 5 then -- Show only top 5
        local context_str = ""
        if op.context and op.context.gui_name then
          context_str = " (GUI: " .. op.context.gui_name .. ")"
        end
        GameHelpers.player_print(player, "  " .. (op.name or "unknown") .. ": " .. 
                                         (op.duration_ticks or 0) .. " ticks" .. context_str)
      end
    end
  end
  
  GameHelpers.player_print(player, "========================================")
end

--- Reset performance data (useful for testing)
function DevPerformanceMonitor.reset_data()
  if not is_monitoring_active() then return end
  
  performance_data = {
    event_timings = {},
    memory_snapshots = {},
    gui_operations = {},
    cache_stats = {hits = 0, misses = 0, lookups = 0},
    recent_operations = {},
    start_time = game.tick,
    last_memory_snapshot = game.tick
  }
  
  ErrorHandler.debug_log("Performance monitoring data reset")
end

return DevPerformanceMonitor
