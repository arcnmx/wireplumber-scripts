local Proxy = {
	-- https://gitlab.freedesktop.org/pipewire/wireplumber/-/blob/master/lib/wp/proxy.h
	WP_PROXY_FEATURE_BOUND = 1,
	WP_PIPEWIRE_OBJECT_FEATURE_INFO = 16,
	WP_PIPEWIRE_OBJECT_FEATURE_PARAM_PROPS = 32,
	WP_PIPEWIRE_OBJECT_FEATURE_PARAM_FORMAT = 64,
	WP_PIPEWIRE_OBJECT_FEATURE_PARAM_PROFILE = 128,
	WP_PIPEWIRE_OBJECT_FEATURE_PARAM_PORT_CONFIG = 256,
	WP_PIPEWIRE_OBJECT_FEATURE_PARAM_ROUTE = 512,

	types = {
		Port = "WpPort",
		Node = "WpNode",
		Client = "WpClient",
		Metadata = "WpMetadata",
	},
}
Proxy.WP_PIPEWIRE_OBJECT_FEATURES_MINIMAL = Proxy.WP_PROXY_FEATURE_BOUND + Proxy.WP_PIPEWIRE_OBJECT_FEATURE_INFO

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
