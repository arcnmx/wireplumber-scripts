return function(config)

if config.node == nil then
	error("node argument missing")
end
if config.follower == nil then
	error("follower argument missing")
end

Proxy = require("wp.proxy")
local Params = require("wp.params")
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

local function on_param_changed(om, node, follower_nodes, port_mappings, device_routes)
	if true then return nil end
	local props = node:props()
	local follower_props = { }
	for _, pair in ipairs(port_mappings) do
		for port_node in node:ports(pair.node) do
			local port_node_index = port_node:port_number()
			for fkey, follower in pairs(follower_nodes) do
				local device_id = follower:prop("device.id")
				local follower_device
				if device_id ~= nil then
					follower_device = Proxy.Device.wrap(om.lookup(Interest {
						type = "device",
						Constraint { type = "gobject", "bound-id", "=", device_id },
					}))
				end

				if follower_props[fkey] == nil then
					if device_id ~= nil then
						follower_props[fkey] = follower_device:props()
					else
						follower_props[fkey] = follower:props()
					end
				end
				for port_follower in follower:ports(pair.follower) do
					local mute, volume = props:mute(port_node_index), props:channel_volume(port_node_index)
					if mute then
						volume = 0.0
					end
					follower_props[fkey]:set_channel_volume(port_follower:port_number(), volume)
				end
			end
		end
	end
	for fkey, fprops in pairs(follower_props) do
		local device_id = follower:prop("device.id")
		local device_has_volume = true
		if device_id ~= nil and device_has_volume then
			local route = device_routes[device_id]:by_device_index(follower_nodes[fkey]:device_index())
			fprops.object_type = Params.types.Props
			fprops.object_id = "Route"
			local params = Params.new(nil, "Route", {
				index = route:index(),
				device = route:device_index(),
				props = fprops,
				save = true,
			})
			params:apply(follower_device)
		else
			fprops:apply(follower_nodes[fkey])
		end
	end
end

local function process_device(device, device_routes)
	device_routes[device:id()] = device:routes()
end

local device_interest = Interest {
	-- used to query for associated device objects
	type = "device",
	Constraint { "media.class", "=", "Audio/Device" },
}

local follower_nodes = { }
local device_routes = { }
local om = ObjectManager {
	node_interest,
	follower_interest,
	device_interest,
}

om:connect("object-added", function(om, obj)
	local obj = Proxy.wrap(obj)
	if obj:matches(node_interest) then
		obj:connect("params-changed", function (node, name)
			if name == "Props" then
				-- TODO: use a devices table to cache devices instead!!!
				on_param_changed(om, node, follower_nodes, port_mappings, device_routes)
			end
		end)
	elseif obj:matches(follower_interest) then
		follower_nodes[obj:id()] = obj
	elseif obj:matches(device_interest) then
		process_device(obj, device_routes)
	end
end)

om:connect("objects-changed", function(om)
	for node in om:iterate(node_interest) do
		on_param_changed(om, node, follower_nodes, port_mappings, device_routes)
	end
end)

om:connect("object-removed", function(om, obj)
	local obj = Proxy.new(obj)
	if obj:matches(follower_interest) then
		follower_nodes[obj:id()] = nil
	end
end)

om:activate()

return {
	om,
}

end
