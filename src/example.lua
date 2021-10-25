local static_config = {
	output = {
		{ "node.name", "=", "amp" }
	},
	input = {
		{ "node.name", "=", "onboard" }
	},
	mappings = {
		{
			output = {
				{ "audio.channel", "=", "FL" }
			},
			input = {
				{ "audio.channel", "=", "SL" }
			},
		},
		{
			output = {
				{ "audio.channel", "=", "FR" }
			},
			input = {
				{ "audio.channel", "=", "SR" }
			},
		},
	},
}
handle_static = require("scripts.static-link")(static_config)

local volume_config = {
	node = {
		{ "node.name", "=", "amp" }
	},
	follower = {
		{ "node.name", "=", "onboard" }
	},
	mappings = {
		{
			node = {
				{ "audio.channel", "=", "FL" }
			},
			follower = {
				{ "audio.channel", "=", "SL" }
			},
		},
		{
			node = {
				{ "audio.channel", "=", "FR" }
			},
			follower = {
				{ "audio.channel", "=", "SR" }
			},
		},
	},
}
handle_volume = require("scripts.link-volume")(volume_config)
