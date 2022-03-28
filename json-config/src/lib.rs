use serde::{Serialize, Deserialize};
use glib::{Variant, Error};
use std::fs::File;

use wireplumber::{
	prelude::*,
	plugin::*,
	core::Core,
	util::Transition,
	lua::LuaVariant,
	error, warning,
};

const LOG_DOMAIN: &'static str = "json-config";
const JSON_CONFIG: &'static str = "config/json";

#[derive(Debug, Clone, Deserialize, Serialize)]
pub struct ModuleConfig {
	name: String,
	#[serde(rename = "type")]
	type_: String,
	#[serde(default)]
	optional: bool,
	#[serde(default, skip_serializing_if = "Option::is_none")]
	args: Option<LuaVariant<'static>>,
}

#[derive(Default)]
pub struct JsonConfig;

impl ComponentLoaderImpl for JsonConfig {
	fn load(&self, this: &Self::Type, component: String, type_: String, args: Option<Variant>) -> Result<(), Error> {
		assert_eq!(type_, JSON_CONFIG);
		if let Some(args) = args {
			warning!(domain: LOG_DOMAIN, "unexpected loader arguments: {}", args);
		}

		let path = Core::find_file(LookupDirs::ENV_CONFIG | LookupDirs::ETC | LookupDirs::PREFIX_SHARE, &component, None)
			.ok_or_else(|| error::invalid_argument(format_args!("file not found: {}", component)))?;
		let file = File::open(&path)
			.map_err(error::operation_failed)?;

		let core = this.upcast_ref::<Plugin>().core();
		serde_json::from_reader::<_, Vec<ModuleConfig>>(file)
			.map_err(error::operation_failed)?
			.into_iter()
			.map(|arg| core.load_component(&arg.name, &arg.type_, arg.args.as_ref().map(|a| a.as_variant()))
				.or_else(|err| match arg.optional {
					true => {
						warning!("Failed to load {}: {}", component, err);
						Ok(())
					},
					false => Err(err),
				})
			).collect()
	}

	fn supports_type(&self, _this: &Self::Type, type_: String) -> bool {
		match &type_[..] {
			JSON_CONFIG => true,
			_ => false,
		}
	}
}

impl PluginImpl for JsonConfig {
	fn enable(&self, plugin: &Self::Type, _error_handler: Transition) {
		plugin.upcast_ref::<Plugin>().update_features(PluginFeatures::ENABLED, PluginFeatures::empty());
	}

	fn disable(&self, _plugin: &Self::Type) { }
}

impl SimplePlugin for JsonConfig {
	type Args = ();
	fn init_args(&self, _args: Self::Args) { }
	fn decode_args(_args: Option<Variant>) -> Result<Self::Args, Error> { Ok(()) }
}

simple_plugin_subclass! {
	impl ObjectSubclass<ComponentLoader> for LOG_DOMAIN as JsonConfig { }
}

plugin_export!(JsonConfig);
