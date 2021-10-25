return function(config)

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
t = require("util.table")

local output_interest = Interest(t.merge({ type = "node" }, t.map(Constraint, config.output)))
local input_interest = Interest(t.merge({ type = "node" }, t.map(Constraint, config.input)))

local function link_node(output, input)
	Log.info(string.format("linking %s to %s", input.properties["node.name"], output.properties["node.name"]))

	local links = { }
	local link_args = {
		passive = config.passive,
		linger = config.linger,
	}
	if config.mappings == nil then
		table.insert(links, Proxy.Link.new(output, input, link_args))
	else
		for _, pair in ipairs(config.mappings) do
			local port_input_interest = Interest {
				type = "port",
				Constraint { "port.direction", "=", "in" },
				table.unpack(t.map(Constraint, pair.input))
			}
			local port_output_interest = Interest {
				type = "port",
				Constraint { "port.direction", "=", "out" },
				table.unpack(t.map(Constraint, pair.output))
			}

			for port_input in input:iterate_ports(port_input_interest) do
				for port_output in output:iterate_ports(port_output_interest) do
					table.insert(links, Proxy.Link.new(port_output, port_input, link_args))
				end
			end
		end
	end
	local function callback(link, error_message)
		if error_message ~= nil then
			Log.warning(error_message)
		end
	end
	for _, link in ipairs(links) do
		link:activate(callback)
	end
end

local function link_nodes(om)
	for input in om:iterate(input_interest) do
		for output in om:iterate(output_interest) do
			link_node(output, input)
		end
	end
end

local watched = { }
local om = ObjectManager {
	output_interest,
	input_interest,
}

om:connect("objects-changed", function (om)
	Log.debug("interests changed")
	for node in om:iterate() do
		if watched[node["bound-id"]] == nil then
			node:connect("ports-changed", function () link_nodes(om) end) -- WARN: om ref cycle?
			watched[node["bound-id"]] = true
		end
	end
	link_nodes(om)
end)
om:connect("object-removed", function (om, node)
	watched[node["bound-id"]] = nil
end)

om:activate()

return {
	om,
}

end
