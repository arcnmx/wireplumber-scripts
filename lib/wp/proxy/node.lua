local Proxy = require("wp.proxy")
local ProxyNode = {
	type = "WpNode",
}
Proxy.Node = ProxyNode

function ProxyNode.wrap(node)
	local self = {
		node = node,
	}
	function self:props()
		return ProxyNode.props(self.node)
	end
	return self
end

function ProxyNode.props(node)
	local params = require("wp.params").new()

	for param in node:iterate_params("Props") do
		local pod = param:parse()
		if pod.pod_type == "Object" and pod.properties.volume ~= nil then
			params:set_from_pod(pod)
		end
	end

	return params
end

return ProxyNode
