local sandbox_exports = {
	"Debug", "Id", "Features", "Feature",
	"GLib", "Log", "Core", "Plugin", "ObjectManager", "Interest", "SessionItem", "Constraint",
	"Device", "SpaDevice", "Node", "LocalNode", "Link", "Pod", "State", "LocalModule",
}
local conf = {
	redefined = false,
	allow_defined = true,
	unused_args = false,
	read_globals = sandbox_exports,
	std = {
		globals = {
			"_ENV",
			"package", "require",
		},
		read_globals = {
			-- https://pipewire.pages.freedesktop.org/wireplumber/lua_api/lua_introduction.html#sandbox
			"_VERSION", "assert", "error", "ipairs", "next", "pairs", "print",
			"pcall", "select", "tonumber", "tostring", "type", "xpcall",
			"table", "utf8",
			"math", "string",
			"os",
		},
	},
}

return conf

-- vim: set ft=lua :
