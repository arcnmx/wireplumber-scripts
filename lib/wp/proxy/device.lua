local Proxy = require("wp.proxy")
local ProxyDevice = {
	type = "Device",
	wp_type = "WpDevice",
	pw_type = "PipeWire:Interface:Device",
}
Proxy.register(ProxyDevice)

function ProxyDevice._wrap(self)
	function self:props()
		return ProxyDevice.props(self.native)
	end

	function self:routes()
		return ProxyDevice.routes(self.native)
	end
end

function ProxyDevice.props(device)
	local params = require("wp.params").new()

	for param in device:iterate_params("Props") do
		local pod = param:parse()
		if pod.pod_type == "Object" and pod.properties.volume ~= nil then
			params:set_from_pod(pod)
		end
	end

	return params
end

function ProxyDevice.routes(device)
	local Route = require("wp.route")
	local routes = Route.Routes.new()
	for param in device:iterate_params("Route") do
		routes:insert_route(Route.wrap(param))
	end
	return routes
end

return ProxyDevice
