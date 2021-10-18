local ProxyNode = {
	type = "WpNode",
}
local Proxy

if package.preload["wp.proxy"] ~= nil then
	Proxy = require("wp.proxy")
	Proxy.Node = ProxyNode
end

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
