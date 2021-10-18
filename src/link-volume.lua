--[[
arguments should be a table consisting of:
{
	node: list of constraints
	follower: list of constraints
	mappings: list of tables of `node` and `follower` constraint lists
}
]]--
local config = ...

return require("scripts.link-volume")(config)
