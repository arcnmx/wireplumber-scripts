local Proxy = {
	types = {
		by_wp_type = { },
		by_pw_type = { },
	},
}

function Proxy.new(native)
	local self = {
		native = native,
		_proxy = Proxy,
	}

	function self:is_type(ty)
		return Proxy.is_type(self.native, ty)
	end

	function self:pw_type()
		return Proxy.pw_type(self.native)
	end

	function self:id()
		return self:gprop("bound-id")
	end

	function self:object_id()
		return self:prop("object.id")
	end

	function self:prop(key)
		return self.native.properties[key]
	end

	function self:gprop(key)
		return self.native[key]
	end

	function self:matches(interest)
		return interest:matches(self.native)
	end

	function self:connect(key, handler)
		local proxy = self._proxy
		return self.native:connect(key, function(this, ...)
			handler(proxy.wrap(this), ...)
		end)
	end

	return self
end

function Proxy.wrap(native)
	local ty = Proxy.types.by_pw_type[Proxy.pw_type(Proxy.unwrap(native))]

	if ty ~= nil then
		return ty.wrap(native)
	else
		return Proxy.new(native)
	end
end

function Proxy.unwrap(obj)
	if type(obj) == "table" and obj._proxy ~= nil then
		return obj.native
	else
		return obj
	end
end

function Proxy.pw_type(obj)
	-- luacheck: no unused
	local name, version = obj:get_interface_type()
	return name
end

function Proxy.is_type(obj, ty)
	local name = Proxy.pw_type(obj)
	if type(ty) ~= "string" then
		return name == ty.type
	else
		return name == ty
	end
end

function Proxy.register(clazz)
	Proxy[clazz.type] = clazz
	Proxy.types.by_wp_type[clazz.wp_type] = clazz
	Proxy.types.by_pw_type[clazz.pw_type] = clazz

	function clazz.is(obj)
		return Proxy.pw_type(Proxy.unwrap(obj)) == clazz.pw_type
	end

	function clazz.wrap(native)
		local self = Proxy.new(native)

		self._proxy = clazz
		clazz._wrap(self)

		return self
	end
end

return Proxy
