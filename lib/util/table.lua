local t = { }
local util

if package.preload["util"] ~= nil then
	util = require("util")
	util.table = t
end

function t.map_to(f, dest, src)
	for k, v in pairs(src) do
		dest[k] = f(v)
	end
	return dest
end

function t.map(f, values)
	return t.map_to(f, { }, values)
end

function t.map_inplace(f, values)
	return t.map_to(f, values, values)
end

function t.copy_to(dest, src)
	for k, v in pairs(src) do
		dest[k] = v
	end
	return dest
end

function t.copy(src)
	return t.copy_to({ }, src)
end

function t.merge(a, b)
	return t.copy_to(t.copy(a), b)
end

return t
