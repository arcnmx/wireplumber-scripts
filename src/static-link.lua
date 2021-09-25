--[[
arguments should be a table consisting of:
{
	output: list of constraints
	input: list of constraints
	mappings: list of tables of `output` and `input` constraint lists
	passive: bool (optional, default true)
	linger: bool (optional, default true)
	linkvolume: nil | "input" | "output" (default nil)
}
]]--
local config = ...

if config.output == nil then
	error("output argument missing")
end
if config.input == nil then
	error("input argument missing")
end
if config.passive == nil then
	config.passive = true
end
if config.linger == nil then
	config.linger = true
end

Proxy = require("wp.proxy")
require("wp.proxy.link")
require("wp.proxy.node")
Params = require("wp.params")
t = require("util.table")

function on_param_changed(follower_node, port_mappings)
	return function(leader_node, name)
		on_param_changed_(leader_node, name, follower_node, port_mappings)
	end
end

function on_param_changed_(leader_node, name, follower_node, port_mappings)
	if name ~= "Props" then
		return
	end
	Log.debug(leader_node, "node props changed")
	local leader_params = Proxy.Node.props(leader_node)
	local follower_params = Proxy.Node.props(follower_node)

	for _, pair in ipairs(port_mappings) do
		local leader_port_channels = pair[leader_node["bound-id"]]
		local follower_port_channels = pair[follower_node["bound-id"]]
		for _, lp in ipairs(leader_port_channels) do
			for _, fp in ipairs(follower_port_channels) do
				local mute, volume = leader_params:mute(lp), leader_params:channelVolume(lp)
				if mute then
					volume = 0.0
				end
				follower_params:setChannelVolume(fp, volume)
			end
		end
	end
	follower_params:apply(follower_node)
end

function link_volume(leader_node, follower_node, port_mappings)
	if watched.props[leader_node["bound-id"]] == nil then
		leader_node:connect("params-changed", on_param_changed(follower_node, port_mappings))
		watched.props[leader_node["bound-id"]] = true
	end
end

function link_nodes()
	for input in om:iterate(input_interest) do
		for output in om:iterate(output_interest) do
			link_node(output, input)
		end
	end
end

function link_node(output, input)
	Log.info(string.format("linking %s to %s", input["properties"]["node.name"], output["properties"]["node.name"]))

	local links = { }
	local link_args = {
		passive = config.passive,
		linger = config.linger,
	}
	if config.mappings == nil then
		table.insert(links, Proxy.Link.new(output, input, link_args))
	else
		local port_mappings = { }
		for _, pair in ipairs(config.mappings) do
			local input_constraints = { table.unpack(pair.input) }
			table.insert(input_constraints, { "port.direction", "=", "in" })

			local output_constraints = { table.unpack(pair.output) }
			table.insert(output_constraints, { "port.direction", "=", "out" })

			local port_input_interest = Interest(t.merge({ type = "port" }, t.map(Constraint, input_constraints)))
			local port_output_interest = Interest(t.merge({ type = "port" }, t.map(Constraint, output_constraints)))

			local input_ports, output_ports = { }, { }
			for port_input in input:iterate_ports(port_input_interest) do
				table.insert(input_ports, port_input["properties"]["port.id"] + 1)

				output_ports = { }
				for port_output in output:iterate_ports(port_output_interest) do
					table.insert(output_ports, port_output["properties"]["port.id"] + 1)

					table.insert(links, Proxy.Link.new(port_output, port_input, link_args))
				end
			end
			table.insert(port_mappings, {
				[input["bound-id"]] = input_ports,
				[output["bound-id"]] = output_ports,
			})
		end

		if config.linkvolume == "input" then
			link_volume(input, output, port_mappings)
		elseif config.linkvolume == "output" then
			link_volume(output, input, port_mappings)
		end
	end
	local callback = function (link, error_message)
		if error_message ~= nil then
			Log.warning(error_message)
		end
	end
	for _, link in ipairs(links) do
		link:activate(callback)
	end
end

output_interest = Interest(t.merge({ type = "node" }, t.map(Constraint, config.output)))
input_interest = Interest(t.merge({ type = "node" }, t.map(Constraint, config.input)))

watched = {
	ports = { },
	props = { },
}
om = ObjectManager {
	output_interest,
	input_interest,
}

om:connect("objects-changed", function (om)
	Log.debug("interests changed")
	for node in om:iterate() do
		local is_output = output_interest:matches(node)
		if watched.ports[node["bound-id"]] == nil then
			node:connect("ports-changed", function () link_nodes() end)
			watched.ports[node["bound-id"]] = true
		end
	end
	link_nodes()
end)

om:activate()
