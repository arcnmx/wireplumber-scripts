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
require("scripts.static-link")(static_config)
