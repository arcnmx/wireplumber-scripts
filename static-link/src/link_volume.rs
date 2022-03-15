use serde::{Serialize, Deserialize};
use anyhow::{Result, format_err};
use wireplumber::{
	pw::{Node, Port, PipewireObject},
	spa::{self, SpaProps, SpaRoute, SpaRoutes, SpaPodBuilder},
	warning,
};

use crate::LOG_DOMAIN;

pub async fn link<I: IntoIterator<Item=(Port, Port)>>(node: &Node, follower: &Node, follower_target: &PipewireObject, route: Option<&SpaRoute>, mapping: I) -> Result<()> {
	let props = SpaProps::from_object(node).await?; // TODO: this can be cached and passed to this fn

	let follower_props = if let Some(route) = route {
		let route_index = route.index();
		let routes = SpaRoutes::from_object(follower_target).await?;
		let route = routes
			.by_index(route_index).ok_or_else(|| format_err!("route index {} on {:?} not found", route_index, routes))?;
		route.props().ok_or_else(|| format_err!("expected props on route {:?}", route))?
	} else {
		SpaProps::from_object(follower_target).await?
	};

	for (port, follower_port) in mapping {
		let (mute, volume) = (props.mute(), props.channel_volume(port.port_index()?));

		let volume = if mute { 0.0f32 } else { volume }; // TODO: if mappings cover all follower ports, you could mute the follower instead!
		if let Err(_) = follower_props.set_channel_volume(follower_port.port_index()?, volume) {
			warning!(domain: LOG_DOMAIN, "failed to set channel {} volume on {:?}", follower_port.port_index()?, follower);
		}
		// TODO: set the relevant softVolumes to 1.0? it's unclear how exactly this works...
	}

	if let Some(route) = route {
		let new = SpaPodBuilder::new_object("Spa:Pod:Object:Param:Route", "Route");

		new.add_object_property(&spa::ffi::spa_param_route_SPA_PARAM_ROUTE_index, route.index() as i32);
		new.add_object_property(&spa::ffi::spa_param_route_SPA_PARAM_ROUTE_device, route.device_index() as i32);
		new.add_object_property(&spa::ffi::spa_param_route_SPA_PARAM_ROUTE_save, true);
		// TODO: recreate `follower_props` with object_id="Route" if necessary? (it might already be due to coming from route?)
		new.add_object_property(&spa::ffi::spa_param_route_SPA_PARAM_ROUTE_props, follower_props.into_params());

		new.end().unwrap().apply(follower_target)?;
	} else {
		follower_props.into_params().apply(follower_target)?; // TODO: follower_target
	}

	Ok(())
}

#[repr(u8)]
#[derive(Debug, Copy, Clone, Deserialize, Serialize)]
#[serde(rename_all = "kebab-case")]
pub enum LinkVolume {
	Input,
	Output,
}

impl LinkVolume {
	pub fn select<T>(&self, input: T, output: T) -> T {
		match self {
			LinkVolume::Input => input,
			LinkVolume::Output => output,
		}
	}

	pub fn invert(self) -> Self {
		match self {
			LinkVolume::Input => LinkVolume::Output,
			LinkVolume::Output => LinkVolume::Input,
		}
	}
}
