return function(config)

if config.node == nil then
	error("node argument missing")
end
if config.follower == nil then
	error("follower argument missing")
end

Proxy = require("wp.proxy")
require("wp.proxy.node")
t = require("util.table")

local port_mappings = { }
for _, pair in ipairs(config.mappings) do
	table.insert(port_mappings, {
		follower = Interest {
			type = "port",
			Constraint { "port.direction", "=", "in" },
			table.unpack(t.map(Constraint, pair.follower))
		},
		node = Interest {
			type = "port",
			Constraint { "port.direction", "=", "out" },
			table.unpack(t.map(Constraint, pair.node))
		},
	})
end

local node_interest = Interest(t.merge({ type = "node" }, t.map(Constraint, config.node)))
local follower_interest = Interest(t.merge({ type = "node" }, t.map(Constraint, config.follower)))

local function on_param_changed(node, follower_nodes, port_mappings)
	local props = Proxy.Node.props(node)
	local follower_props = { }
	for _, pair in ipairs(port_mappings) do
		for port_node in node:iterate_ports(pair.node) do
			local port_node_index = port_node.properties["port.id"] + 1
			for fkey, follower in pairs(follower_nodes) do
				if follower_props[fkey] == nil then
					follower_props[fkey] = Proxy.Node.props(follower)
				end
				for port_follower in follower:iterate_ports(pair.follower) do
					local mute, volume = props:mute(port_node_index), props:channel_volume(port_node_index)
					if mute then
						volume = 0.0
					end
					follower_props[fkey]:set_channel_volume(port_follower.properties["port.id"] + 1, volume)
				end
			end
		end
	end
	for fkey, fprops in pairs(follower_props) do
		fprops:apply(follower_nodes[fkey])
	end
end

local follower_nodes = { }
local om = ObjectManager {
	node_interest,
	follower_interest,
}

om:connect("object-added", function(om, node)
	if node_interest:matches(node) then
		node:connect("params-changed", function (node, name)
			if name == "Props" then
				on_param_changed(node, follower_nodes, port_mappings)
			end
		end)
	else
		follower_nodes[node["bound-id"]] = node
	end
end)

om:connect("objects-changed", function(om)
	for node in om:iterate(node_interest) do
		on_param_changed(node, follower_nodes, port_mappings)
	end
end)

om:connect("object-removed", function(om, node)
	if follower_interest:matches(node) then
		follower_nodes[node["bound-id"]] = nil
	end
end)

om:activate()

return {
	om,
}

end
