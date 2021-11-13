local Proxy = require("wp.proxy")
local ProxyLink = {
	type = "Link",
	wp_type = "WpLink",
	pw_type = "PipeWire:Interface:Link",
}
Proxy.register(ProxyLink)

function ProxyLink._wrap(self)
	function self:activate(error_handler)
		return ProxyLink.activate(self.native, error_handler)
	end
end

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

	local function set_port_props(dir, obj)
		local ProxyPort = require("wp.proxy.port")
		local port = Proxy.wrap(obj)
		if ProxyPort.is(port) then
			props[string.format("link.%s.port", dir)] = port:object_id()
			props[string.format("link.%s.node", dir)] = port:node_id()
		else
			props[string.format("link.%s.node", dir)] = port:object_id()
		end
	end
	set_port_props("output", output)
	set_port_props("input", input)

	return ProxyLink.wrap(Link(factory, props))
end

function ProxyLink.activate(link, error_handler)
	local function callback(link, error_message)
		if error_handler ~= nil and (error_message == nil or string.match(error_message, ": File exists") == nil) then
			return error_handler(link, error_message)
		end
	end
	link:activate(Features.PipewireObject.MINIMAL, callback)
end

return ProxyLink
