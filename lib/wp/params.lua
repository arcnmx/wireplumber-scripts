local Params = { }
Params.types = {
	Props = "Spa:Pod:Object:Param:Props",
	Route = "Spa:Pod:Object:Param:Route",
}

function Params.new(ty, id, props)
	local self = {
		object_type = ty,
		object_id = id,
		pod_type = "Object",
		properties = props,
		changed_keys = nil,
	}

	Params._wrap(self)

	return self
end

function Params.wrap(pod)
	local pod = pod:parse()
	local self = Params.new(nil, pod.object_id, pod.properties)
	self.changed_keys = { }
	self.pod = pod
	return self
end

function Params._wrap(self)
	function self:prop(key)
		return self.properties[key]
	end

	function self:mark_dirty()
		self.changed_keys = nil
	end

	function self:type_id()
		if self.object_type ~= nil then
			return self.object_type
		else
			return Params.types[self.object_id]
		end
	end

	function self:to_pod()
		local pod = {
			self:type_id(), -- type_name = Spa:Pod:Object:Param:Props (262146)
			self.object_id, -- name_id = Spa:Enum:ParamId:Props (2)
		}
		local keys
		if self.changed_keys == nil then
			keys = pairs(self.properties)
		else
			keys = pairs(self.changed_keys)
		end
		for key, _ in keys do
			Log.info(node, string.format("setting %s", key))
			local value = self:prop(key)
			if type(value) == "table" then
				if value.pod_type == "Array" then
					local value_type = value.value_type
					if value_type == "Spa:Id" then
						-- TODO: get this from PropInfo if possible?
						if key == "channelMap" then
							value_type = "Spa:Enum:AudioChannel"
						else
							error(string.format("unknown Spa:Id table for %s", key))
						end
					end
					local con = {
						value_type,
					}
					for _, v in ipairs(value) do
						table.insert(con, v)
					end
					pod[key] = Pod.Array(con)
				else
					error(string.format("unsupported SpaPod type: %s", value.pod_type))
				end
			else
				pod[key] = value
			end
		end

		return pod
	end

	function self:apply(target)
		if next(self.changed_keys) == nil then
			return
		end
		local pod = self:to_pod()
		Log.debug(pod, "setting props")
		target:set_param(self.pod.object_id, pod)
	end
end

return Params
