local Params = { }

function Params.new()
	local self = {
		changed_keys = { },
	}

	function self:props()
		return self.pod.properties
	end

	function self:mute(ch)
		local props = self:props()
		return props.mute or false
	end

	function self:channel_volume(ch)
		local props = self:props()
		if props.channelVolumes ~= nil then
			return props.channelVolumes[ch]
		else
			return props.volume
		end
	end

	function self:set_channel_volume(ch, volume)
		local props = self:props()
		if props.channelVolumes ~= nil then
			props.channelVolumes[ch] = volume
			self.changed_keys.channelVolumes = true
		else
			props.volume = volume
			self.changed_keys.volume = true
		end
	end

	function self:set_from_pod(pod)
		self.pod = pod
	end

	function self:mark_dirty()
		for key, _ in pairs(self.pod.properties) do
			self.changed_keys[key] = true
		end
	end

	function self:apply(node)
		if next(self.changed_keys) == nil then
			return
		end
		local pod = {
			"Spa:Pod:Object:Param:Props", -- type_name = Spa:Pod:Object:Param:Props (262146)
			self.pod.object_id, -- name_id = Spa:Enum:ParamId:Props (2)
		}
		for key, _ in pairs(self.changed_keys) do
			Log.info(node, string.format("setting %s", key))
			local value = self.pod.properties[key]
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
		local newpod = Pod.Object(pod)
		Log.debug(newpod, "setting props")
		node:set_param("Props", Pod.Object(pod))
	end

	return self
end

return Params
