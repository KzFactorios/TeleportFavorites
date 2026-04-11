-- Cycle-safe barrel: the 5 universal modules that do NOT require core.cache.cache.
-- Use require("core.base_deps_barrel") (not deps.lua) in any module transitively required by
-- core/cache/cache.lua (e.g. lookups.lua, settings.lua, favorite_utils.lua)
-- to avoid the circular-require that would result from loading deps.lua there.
local BasicHelpers = require("core.utils.basic_helpers")
local ErrorHandler = require("core.utils.error_handler")
local Constants    = require("core.constants_impl")
local GpsUtils     = require("core.utils.gps_utils")
local Enum         = require("prototypes.enums.enum")
return {
  BasicHelpers = BasicHelpers,
  ErrorHandler = ErrorHandler,
  Constants    = Constants,
  GpsUtils     = GpsUtils,
  Enum         = Enum,
}
