-- Single-require barrel for the 6 universally-required modules.
-- All entries are cached by Lua's require system after first load; no overhead penalty.
-- NOTE: modules that are transitively required BY core.cache.cache must use
--       base_deps.lua instead to avoid a circular-require at load time.
-- Usage:
--   local Deps = require("deps")
--   local BasicHelpers, ErrorHandler = Deps.BasicHelpers, Deps.ErrorHandler
local BasicHelpers = require("core.utils.basic_helpers")
local ErrorHandler = require("core.utils.error_handler")
local Cache        = require("core.cache.cache")
local Constants    = require("constants")
local GpsUtils     = require("core.utils.gps_utils")
local Enum         = require("prototypes.enums.enum")
return {
  BasicHelpers = BasicHelpers,
  ErrorHandler = ErrorHandler,
  Cache        = Cache,
  Constants    = Constants,
  GpsUtils     = GpsUtils,
  Enum         = Enum,
}
