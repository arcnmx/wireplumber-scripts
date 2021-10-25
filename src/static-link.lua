--[[
arguments should be a table consisting of:
{
	output: list of constraints
	input: list of constraints
	mappings: list of tables of `output` and `input` constraint lists
	passive: bool (optional, default true)
	linger: bool (optional, default true)
}
]]--
local config = ...

-- luacheck: no global
handle = require("scripts.static-link")(config)
