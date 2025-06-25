# Development Performance Monitoring Implementation Guide

*This document describes the simple development-only performance monitoring system implemented in TeleportFavorites.*

## Overview and Limitations

TeleportFavorites includes a **simple development-only performance monitoring system** designed to help with mod optimization and debugging. This system addresses the fundamental limitation that **Factorio mods cannot centralize data collection** - each game instance operates independently.

### **System Scope**
- **Development Mode Only**: Monitoring only activates when debug level is DEBUG or higher
- **Local Instance Only**: All data is local to the specific game instance
- **Lightweight**: Minimal performance impact when disabled
- **In-Game Dashboard**: Simple text-based performance display

### **What This System Provides**
- Operation timing measurement
- Cache hit/miss statistics  
- Memory usage estimation
- Performance bottleneck identification
- Development debugging tools

### **What This System Does NOT Provide**
- Cross-server data aggregation
- External monitoring integration
- Centralized performance analytics
- Production monitoring dashboards
- Real-time external alerts

## Implemented Components

### 1. Development Performance Monitor (`core/utils/dev_performance_monitor.lua`)

The core monitoring module that tracks performance metrics during development.

#### **Key Features**
- **Operation Measurement**: Times function execution
- **Cache Statistics**: Tracks cache hits, misses, and hit rates
- **Memory Snapshots**: Periodic memory usage estimation
- **Ring Buffer Storage**: Keeps recent operations for analysis
- **Development Mode Guard**: Only active when debug level ≥ DEBUG

#### **Usage Examples**
```lua
local Logger = require("core.utils.enhanced_error_handler")

-- Measure operation performance
local result = Logger.measure_operation("my_operation", function()
  -- Your code here
  return some_value
end, {context = "additional_info"})

-- Record cache operations
Logger.record_cache_operation("hit", "player_data")
Logger.record_cache_operation("miss", "chart_tags")
```

### 2. Enhanced Debug Commands

Extended debug commands for performance monitoring control.

#### **New Commands**
- `/tf_perf_dashboard` - Show development performance dashboard
- `/tf_perf_reset` - Reset performance monitoring data  
- `/tf_debug_development` - Enable debug mode and initialize performance monitoring

#### **Dashboard Output Example**
```
=== TeleportFavorites Development Performance Dashboard ===
Monitoring since tick: 12000
Current tick: 15000

Recent Operations (15 total):
  Average duration: 1.2 ticks
  Slow operations (>3 ticks): 2
  GUI operations: 5

Cache Performance:
  Total lookups: 45
  Cache hits: 38
  Cache misses: 7
  Hit rate: 84.4%

Recent Slow Operations:
  cache_get_player_favorites: 4 ticks (GUI: fave_bar)
  gui_create: 5 ticks (GUI: tag_editor)
```

### 3. Integrated Performance Tracking

Performance monitoring is integrated into key mod components:

#### **Cache Module Integration**
```lua
-- Automatic performance tracking in Cache.get_player_data()
function Cache.get_player_data(player)
  return Logger.measure_operation("cache_get_player_data", function()
    Logger.record_cache_operation("hit", "player_data")
    return init_player_data(player)
  end, {player_index = player.index})
end
```

#### **Event Handler Integration**
- Periodic memory snapshots via `on_tick` handler
- Automatic cache operation tracking
- GUI operation measurement

### 4. Testing Framework

Comprehensive test suite for the performance monitoring system.

#### **Test Coverage**
- Operation measurement accuracy
- Cache statistics tracking
- Memory snapshot functionality
- Dashboard display
- Debug level integration

#### **Running Tests**
```lua
-- In-game console
/c remote.call("TeleportFavorites", "test_performance_monitor", "your_player_name")
```

## Usage Guide

### **Enable Development Performance Monitoring**

1. **Set Debug Level**: `/tf_debug_development`
2. **Verify Activation**: Check that performance monitoring is mentioned in chat
3. **Use Mod Normally**: Perform typical mod operations (teleport, edit tags, etc.)
4. **View Dashboard**: `/tf_perf_dashboard`

### **Interpreting Results**

#### **Operation Performance**
- **Average Duration**: Overall performance trend
- **Slow Operations**: Operations taking >3 ticks (potential bottlenecks)
- **Operation Types**: Distribution between GUI, cache, and other operations

#### **Cache Performance**
- **Hit Rate**: Higher is better (>80% is good)
- **Miss Patterns**: Identify cache optimization opportunities
- **Lookup Frequency**: Understand cache usage patterns

#### **Memory Trends**
- **Player Count**: Server load indicator
- **Cache Entries**: Memory usage estimation
- **Operation Frequency**: System activity level

### **Performance Optimization Workflow**

1. **Enable Monitoring**: Set debug level to DEBUG
2. **Establish Baseline**: Reset data and use mod normally
3. **Identify Issues**: Look for slow operations and low cache hit rates
4. **Optimize Code**: Focus on bottlenecks found in dashboard
5. **Measure Improvement**: Reset data and compare new performance
6. **Disable Monitoring**: Return to production debug level

## Practical Benefits

### **For Mod Development**
- **Identify Bottlenecks**: Find slow operations during development
- **Optimize Cache Usage**: Improve cache hit rates
- **Validate Optimizations**: Measure improvement after changes
- **Debug Performance Issues**: Real-time feedback on code performance

### **For Testing**
- **Performance Regression Testing**: Detect performance changes
- **Load Testing**: Understand performance under different conditions
- **Cache Testing**: Validate cache behavior
- **GUI Performance**: Measure GUI operation costs

### **Limitations Acknowledged**
- **Development Only**: Not useful for production monitoring
- **Local Scope**: Cannot compare across servers or instances
- **Manual Analysis**: No automated optimization or alerts
- **Simple Metrics**: Basic timing and counting, not advanced profiling

## Future Considerations

While this system provides valuable development insights, **centralized monitoring remains impossible** due to Factorio's architecture. Potential future improvements could include:

- **Enhanced Local Analytics**: More sophisticated local analysis
- **Export Functionality**: Better data export for manual analysis
- **GUI Integration**: Visual performance graphs (if feasible)
- **Automated Recommendations**: Simple optimization suggestions

However, these would still be **local-only improvements** and cannot address the fundamental limitation of isolated game instances.

## Conclusion

The implemented development performance monitoring system provides **practical value for mod development** while acknowledging the realistic constraints of the Factorio modding environment. It focuses on:

- **Local development optimization**
- **Real-time performance feedback**
- **Simple, actionable insights**
- **Minimal production impact**

This approach is much more practical than attempting comprehensive monitoring that would be limited by the inability to centralize data across game instances.

---

*This system is implemented and ready for use. Enable with `/tf_debug_development` and view results with `/tf_perf_dashboard`.*
