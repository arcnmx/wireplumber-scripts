local Proxy = {
	types = {
		Port = "PipeWire:Interface:Port",
		Node = "PipeWire:Interface:Node",
		Client = "PipeWire:Interface:Client",
		Metadata = "PipeWire:Interface:Metadata",
	},
}

function Proxy.is_type(ty, obj)
	-- luacheck: no unused
	local name, version = obj:get_interface_type()
	if type(ty) ~= "string" then
		return name == ty.type
	else
		return name == ty
	end
end

return Proxy
