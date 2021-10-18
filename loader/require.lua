-- https://stackoverflow.com/a/36892318
package = {}
local preload, loaded = {}, {
	string = string,
	package = package,
	os = os,
	table = table,
	math = math,
}
package.preload, package.loaded = preload, loaded

function require( mod )
	if not loaded[ mod ] then
		local f = preload[ mod ]
		if f == nil then
			error( "module '"..mod..[[' not found: no field package.preload[']]..mod.."']", 1 )
		end
		local v = f( mod )
		if v ~= nil then
			loaded[ mod ] = v
		elseif loaded[ mod ] == nil then
			loaded[ mod ] = true
		end
	end
	return loaded[ mod ]
end
