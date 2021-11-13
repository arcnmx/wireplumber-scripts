local Proxy = require("wp.proxy")
local ProxyNode = {
	type = "Node",
	wp_type = "WpNode",
	pw_type = "PipeWire:Interface:Node",
}
Proxy.register(ProxyNode)

function ProxyNode._wrap(self)
	function self:props()
		return ProxyNode.props(self.native)
	end

	function self:device_index()
		return self:prop("card.profile.device")
	end

	function self:ports(interest)
		local iter = self.native:iterate_ports(interest)
		local Port = require("wp.port")
		return function()
			local node = iter()
			if node ~= nil then
				return Port.wrap(node)
			else
				return nil
			end
		end
	end
end

function ProxyNode.props(node)
	local params = require("wp.props").new()

	for param in node:iterate_params("Props") do
		local pod = param:parse()
		if pod.pod_type == "Object" and pod.properties.volume ~= nil then
			params:init_from_pod(pod)
		end
	end

	return params
end

return ProxyNode
