return function(config)

if config.node == nil then
	error("node argument missing")
end
if config.follower == nil then
	error("follower argument missing")
end

Proxy = require("wp.proxy")
require("wp.proxy.node")
require("wp.proxy.device")
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

local function on_param_changed(om, node, follower_nodes, port_mappings)
	local props = Proxy.Node.props(node)
	local follower_props = { }
	for _, pair in ipairs(port_mappings) do
		for port_node in node:iterate_ports(pair.node) do
			local port_node_index = port_node.properties["port.id"] + 1
			for fkey, follower in pairs(follower_nodes) do
				local device_id = follower.properties["device.id"]
				local follower_device
				if device_id ~= nil then
					follower_device = om.lookup(Interest {
						type = "device",
						Constraint { type = "gobject", "bound-id", "=", device_id },
					})
				end

				if follower_props[fkey] == nil then
					if device_id ~= nil then
						follower_props[fkey] = Proxy.Device.props(follower_device)
					else
						follower_props[fkey] = Proxy.Node.props(follower)
					end
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
		local device_id = follower.properties["device.id"]
		local device_has_volume = true
		if device_id ~= nil && device_has_volume then
			follower_nodes[fkey]:set_param("Route", Pod.Object {
				"Spa:Pod:Object:Param:Route",
				"Route",
				index = route.index,
				device = route.device,
				props = fprops,
				save = true,
			})
		else
			fprops:apply(follower_nodes[fkey])
		end
	end
end

local follower_nodes = { }
local om = ObjectManager {
	node_interest,
	follower_interest,
	Interest {
		-- used to query for associated device objects
		type = "device",
		Constraint { "media.class", "=", "Audio/Device" },
	},
}

om:connect("object-added", function(om, node)
	if node_interest:matches(node) then
		node:connect("params-changed", function (node, name)
			if name == "Props" then
				-- TODO: use a devices table to cache devices instead!!!
				on_param_changed(om, node, follower_nodes, port_mappings)
			end
		end)
	else
		follower_nodes[node["bound-id"]] = node
	end
end)

om:connect("objects-changed", function(om)
	for node in om:iterate(node_interest) do
		on_param_changed(om, node, follower_nodes, port_mappings)
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
