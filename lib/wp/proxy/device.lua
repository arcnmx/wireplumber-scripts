local ProxyDevice = {
	type = "WpDevice",
}
local Proxy

if package.preload["wp.proxy"] ~= nil then
	Proxy = require("wp.proxy")
	Proxy.Device = ProxyDevice
end

function ProxyDevice.wrap(device)
	local self = {
		device = device,
	}
	function self:props()
		return ProxyDevice.props(self.device)
	end
	function self:routes()
		return ProxyDevice.routes(self.device)
	end
	return self
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
	for param in device:iterate_params("Routes") do
		error("aaaa")
	end
end

return ProxyDevice
