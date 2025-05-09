-- lua/vimtaskie/init.lua
local core = require("vimtaskie.core")

local M = {}

function M.setup(opts)
	opts = opts or {}
	core.init_db()
	core.register_commands()
	require("vimtaskie.panel").refresh_panels()
end

return M
