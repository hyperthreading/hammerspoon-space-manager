-- Palette factory — delegates to the configured backend
-- Usage unchanged: require("lib.palette").create(opts) / .bind(opts)

local config = require("config")

local backend = config.paletteBackend or "builtin"
local impl = require("lib." .. backend .. "-palette")

return impl
