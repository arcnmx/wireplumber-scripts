local Proxy = require("wp.proxy")
local ProxyLink = {
	type = "WpLink",
}
Proxy.Link = ProxyLink

function ProxyLink.new(output, input, args)
	if args == nil then
		args = { }
	end
	local props = { }
	local factory = args.factory or "link-factory"

	if args.passive ~= nil then
		props["link.passive"] = args.passive
	end

	if args.linger ~= nil then
		props["object.linger"] = args.linger
	end

	local set_port_props = function(dir, obj)
		if Proxy.is_type(Proxy.types.Port, obj) then
			props[string.format("link.%s.port", dir)] = obj.properties["object.id"]
			props[string.format("link.%s.node", dir)] = obj.properties["node.id"]
		else
			props[string.format("link.%s.node", dir)] = obj.properties["object.id"]
		end
	end
	set_port_props("output", output)
	set_port_props("input", input)

	local self = {
		link = Link(factory, props),
	}
	function self:activate(error_handler)
		return ProxyLink.activate(self.link, error_handler)
	end
	return self
end

function ProxyLink.activate(link, error_handler)
	local callback = function (link, error_message)
		if error_handler ~= nil and (error_message == nil or string.match(error_message, ": File exists") == nil) then
			return error_handler(link, error_message)
		end
	end
	link:activate(Features.PipewireObject.MINIMAL, callback)
end

return ProxyLink
