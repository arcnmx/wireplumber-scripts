use {
	futures::{channel::mpsc, future, FutureExt, StreamExt},
	glib::{once_cell::unsync::OnceCell, prelude::*, Error, SourceId, Variant},
	serde::{Deserialize, Serialize},
	std::{cell::RefCell, collections::BTreeMap, future::Future, iter, pin::Pin, rc::Rc},
	wireplumber::{
		core::{Core, Object, ObjectFeatures},
		error, info,
		lua::from_variant,
		plugin::{self, AsyncPluginImpl, SimplePlugin, SimplePluginObject, SourceHandlesCell},
		prelude::*,
		pw::{self, Device, Link, Node, PipewireObject, Port, Properties, ProxyFeatures},
		registry::{Constraint, ConstraintType, Interest, ObjectManager},
		spa::SpaRoutes,
		warning,
	},
};

mod link_volume;
use link_volume::LinkVolume;

const LOG_DOMAIN: &'static str = "static-link";

/// A list of user-specified [Constraints](Constraint)
/// used to find each end of the port to be linked.
#[derive(Debug, Clone, Deserialize, Serialize)]
pub struct PortMapping {
	/// A description of the output ports to link.
	///
	/// The constraint `port.direction=out` is implied.
	output: Vec<Constraint>,
	/// A description of the input ports to link.
	///
	/// The constraint `port.direction=in` is implied.
	input: Vec<Constraint>,
}

/// serde boolean default
#[doc(hidden)]
fn true_() -> bool {
	true
}

/// User configuration for the [StaticLink] plugin
#[derive(Debug, Clone, Deserialize, Serialize)]
#[serde(rename_all = "snake_case")]
pub struct StaticLinkArgs {
	/// The source node to link to `input`
	output: Vec<Constraint>,
	/// The sink node to link to `output`
	input: Vec<Constraint>,
	/// Describes how to link the ports of the `input` node to the `output`
	#[serde(default, rename = "mappings")]
	port_mappings: Vec<PortMapping>,
	#[serde(default)]
	link_volume: Option<LinkVolume>,
	/// Whether to mark any created links as `link.passive`
	///
	/// Defaults to `true`
	#[serde(default = "true_")]
	passive: bool,
	/// Whether to mark any created links as `object.linger`
	///
	/// A lingering link will remain in place even after this module's parent process has exited.
	///
	/// Defaults to `true`
	#[serde(default = "true_")]
	linger: bool,
}

enum EventSignal {
	ObjectsChanged,
	PortsChanged(Node),
	ParamsChanged(PipewireObject, String),
}

fn link_ports<'a>(
	mappings: &'a [PortMapping],
	core: &'a Core,
	output: &'a Node,
	input: &'a Node,
	link_props: &'a Properties,
) -> impl Iterator<Item = Result<Link, Error>> + 'a {
	mappings.iter().flat_map(move |mapping| {
		let port_input_interest: Interest<Port> = mapping
			.input
			.iter()
			.chain(iter::once(&Constraint::compare(
				ConstraintType::default(),
				pw::PW_KEY_PORT_DIRECTION,
				"in",
				true,
			)))
			.collect();
		let port_inputs = port_input_interest.filter(input);

		let port_output_interest: Interest<Port> = mapping
			.output
			.iter()
			.chain(iter::once(&Constraint::compare(
				ConstraintType::default(),
				pw::PW_KEY_PORT_DIRECTION,
				"out",
				true,
			)))
			.collect();
		let port_outputs = move || port_output_interest.clone().filter(output);

		port_inputs.flat_map(move |i| port_outputs().map(move |o| Link::new(&core, &o, &i, link_props)))
	})
}

async fn main_loop(
	om: ObjectManager,
	core: Core,
	arg: StaticLinkArgs,
	input_interest: Interest<Node>,
	output_interest: Interest<Node>,
	device_routes: Rc<RefCell<BTreeMap<u32, SpaRoutes>>>,
	mut rx: mpsc::Receiver<EventSignal>,
) {
	let link_props = Properties::new_empty();
	link_props.insert(pw::PW_KEY_LINK_PASSIVE, arg.passive);
	link_props.insert(pw::PW_KEY_OBJECT_LINGER, arg.linger);
	while let Some(event) = rx.next().await {
		match event {
			EventSignal::ObjectsChanged | EventSignal::PortsChanged(..) => {
				let inputs = input_interest.clone().filter(&om);
				let outputs = || output_interest.clone().filter(&om);
				let pairs = inputs.flat_map(|i| outputs().map(move |o| (i.clone(), o)));

				// TODO: if link_volume is set, trigger a refresh here

				let mut links = Vec::new();
				for (input, output) in pairs {
					info!(domain: LOG_DOMAIN, "linking {} to {}", input, output);
					if arg.port_mappings.is_empty() {
						links.push(Link::new(&core, &output, &input, &link_props));
					} else {
						links.extend(link_ports(&arg.port_mappings, &core, &output, &input, &link_props));
					}
				}
				let links = links.into_iter().filter_map(|l| match l {
					Ok(link) => Some(link.activate_future(ProxyFeatures::MINIMAL).map(|res| match res {
						Err(e) if Link::error_is_exists(&e) => info!(domain: LOG_DOMAIN, "{:?}", e),
						Err(e) => warning!(domain: LOG_DOMAIN, "Failed to activate link: {:?}", e),
						Ok(_) => (),
					})),
					Err(e) => {
						warning!(domain: LOG_DOMAIN, "Failed to create link: {:?}", e);
						None
					},
				});
				future::join_all(links).await;
			},
			EventSignal::ParamsChanged(obj, name) =>
				if let Some(device) = obj.dynamic_cast_ref::<Device>() {
					if name != "Route" {
						continue
					}
					let routes = match SpaRoutes::from_object(device).await {
						Err(e) => {
							warning!(domain: LOG_DOMAIN, "failed to get routes for {:?}: {:?}", device, e);
							continue
						},
						Ok(routes) => routes,
					};
					device_routes.borrow_mut().insert(device.bound_id(), routes);
				} else if let Some(node) = obj.dynamic_cast_ref::<Node>() {
					// TODO: we might also want to re-sync volume on other events too!
					if name != "Props" {
						continue
					}
					let link_volume = match arg.link_volume {
						Some(l) => l,
						None => continue,
					};
					let follower_interest = link_volume.invert().select(&input_interest, &output_interest);
					let follower = match follower_interest.clone().lookup(&om) {
						Some(follower) => follower,
						None => {
							warning!(domain: LOG_DOMAIN, "could not find node to follow {}", node);
							continue
						},
					};
					let device = match follower.device_details() {
						Err(e) => todo!(),
						Ok(Some((device_id, Some(device_index)))) =>
							if let Some(routes) = device_routes.borrow().get(&device_id) {
								match routes.by_device_index(device_index) {
									Some(route) if route.has_volume() => {
										let interest: Interest<Device> = iter::once(Constraint::compare(
											ConstraintType::default(),
											pw::PW_KEY_OBJECT_ID,
											device_id,
											true,
										))
										.collect();
										interest.lookup(&om).map(|dev| (dev, route.clone()))
									},
									_ => None,
								}
							} else {
								None
							},
						Ok(_) => None,
					};
					let (follower_target, route) = match &device {
						Some((device, route)) => (device.as_ref(), Some(route)),
						None => (follower.as_ref(), None),
					};
					let mapping = arg.port_mappings.iter().flat_map(|mapping| {
						let port_input_interest: Interest<Port> = mapping
							.input
							.iter()
							.chain(iter::once(&Constraint::compare(
								ConstraintType::default(),
								pw::PW_KEY_PORT_DIRECTION,
								"in",
								true,
							)))
							.collect();
						let port_output_interest: Interest<Port> = mapping
							.output
							.iter()
							.chain(iter::once(&Constraint::compare(
								ConstraintType::default(),
								pw::PW_KEY_PORT_DIRECTION,
								"out",
								true,
							)))
							.collect();

						let follower_interest = link_volume
							.invert()
							.select(port_input_interest.clone(), port_output_interest.clone());
						let node_interest = link_volume.select(&port_input_interest, &port_output_interest);

						let ports_node = node_interest.clone().filter(node);
						let follower = &follower;
						let ports_follower = move || follower_interest.clone().filter(follower);
						ports_node.flat_map(move |i| ports_follower().map(move |o| (i.clone(), o)))
					});

					match link_volume::link(&node, &follower, follower_target, route, mapping).await {
						Ok(()) => (),
						Err(e) => warning!(
							domain: LOG_DOMAIN,
							"failed to follow {} with {}: {:?}",
							node,
							follower,
							e
						),
					}
				},
		}
	}
}

pub async fn main_async(
	plugin: &SimplePluginObject<StaticLink>,
	core: Core,
	arg: StaticLinkArgs,
) -> Result<impl IntoIterator<Item = impl Future<Output = ()>>, Error> {
	let om = ObjectManager::new();

	let output_interest: Interest<Node> = arg.output.iter().collect();
	om.add_interest(output_interest.clone());

	let input_interest: Interest<Node> = arg.input.iter().collect();
	om.add_interest(input_interest.clone());

	let device_interest = Interest::<Device>::new();
	om.add_interest(device_interest);

	let device_routes = Rc::new(RefCell::new(BTreeMap::new()));

	let (link_nodes_signal, rx) = mpsc::channel(1);

	let port_signals = {
		let mut object_added = om.signal_stream(ObjectManager::SIGNAL_OBJECT_ADDED);
		let link_nodes_signal = link_nodes_signal.clone();
		let input_interest = input_interest.clone();
		let output_interest = output_interest.clone();
		let device_routes = device_routes.clone();
		let link_volume = arg.link_volume;
		let plugin = plugin.downgrade();
		fn map_obj<O: ObjectType, T: ObjectType, F: FnOnce(T) -> EventSignal, E>(
			node: Option<O>,
			e: F,
		) -> future::Ready<Option<Result<EventSignal, E>>> {
			future::ready(node.map(|o| o.dynamic_cast().unwrap()).map(e).map(Ok))
		}
		async move {
			while let Some((obj,)) = object_added.next().await {
				let plugin = match plugin.upgrade() {
					Some(plugin) => plugin,
					None => break,
				};
				if let Some(node) = obj.dynamic_cast_ref::<Node>() {
					plugin.spawn_local(
						node
							.signal_stream(Node::SIGNAL_PORTS_CHANGED)
							.attach_target()
							.filter_map(|(node, _)| map_obj(node, EventSignal::PortsChanged))
							.forward(link_nodes_signal.clone())
							.map(drop),
					);
					if let Some(link_volume) = link_volume {
						let interest = link_volume.select(&input_interest, &output_interest);
						if interest.matches_object(node) {
							let pw_obj: &PipewireObject = node.as_ref();
							plugin.spawn_local(
								pw_obj
									.signal_stream(PipewireObject::SIGNAL_PARAMS_CHANGED)
									.attach_target()
									.filter_map(|(node, (param_name,))| {
										map_obj(node, |node| EventSignal::ParamsChanged(node, param_name))
									})
									.forward(link_nodes_signal.clone())
									.map(drop),
							);
						}
					}
				} else if let Some(device) = obj.dynamic_cast_ref::<Device>() {
					if let Ok(routes) = SpaRoutes::from_object(device).await {
						device_routes.borrow_mut().insert(device.bound_id(), routes);
					}

					let pw_obj: &PipewireObject = device.as_ref();
					plugin.spawn_local(
						pw_obj
							.signal_stream(PipewireObject::SIGNAL_PARAMS_CHANGED)
							.attach_target()
							.filter_map(|(device, (param_name,))| {
								map_obj(device, |device| EventSignal::ParamsChanged(device, param_name))
							})
							.forward(link_nodes_signal.clone())
							.map(drop),
					);
				}
			}
		}
	};
	let object_signals = om
		.signal_stream(ObjectManager::SIGNAL_OBJECTS_CHANGED)
		.map(|_| Ok(EventSignal::ObjectsChanged))
		.forward(link_nodes_signal)
		.map(drop);

	let signal_installed = om.signal_stream(ObjectManager::SIGNAL_INSTALLED);

	om.request_object_features(Object::static_type(), ObjectFeatures::ALL);
	core.install_object_manager(&om);

	// NOTE: waiting for `installed` really isn't necessary since the loop waits for a signal anyway...
	signal_installed.once().await?;

	let main_loop = main_loop(om, core, arg, input_interest, output_interest, device_routes, rx);

	Ok([
		port_signals.boxed_local(),
		object_signals.boxed_local(),
		main_loop.boxed_local(),
	])
}

#[derive(Default)]
pub struct StaticLink {
	args: OnceCell<Vec<StaticLinkArgs>>,
	handles: SourceHandlesCell,
}

impl AsyncPluginImpl for StaticLink {
	type EnableFuture = Pin<Box<dyn Future<Output = Result<(), Error>>>>;

	fn register_source(&self, source: SourceId) {
		self.handles.push(source);
	}

	fn enable(&self, this: Self::Type) -> Self::EnableFuture {
		let core = this.plugin_core();
		let context = this.plugin_context();
		let res = self
			.handles
			.try_init(context.clone())
			.map_err(|_| error::invariant(format_args!("{} plugin has already been enabled", LOG_DOMAIN)));
		async move {
			res?;
			let loops = this
				.args
				.get()
				.unwrap()
				.iter()
				.map(|arg| main_async(&this, core.clone(), arg.clone()));
			for spawn in future::try_join_all(loops).await?.into_iter().flat_map(|l| l) {
				this.spawn_local(spawn);
			}
			Ok(())
		}
		.boxed_local()
	}

	fn disable(&self) {
		self.handles.clear();
	}
}

impl SimplePlugin for StaticLink {
	type Args = Vec<StaticLinkArgs>;

	fn init_args(&self, args: Self::Args) {
		self.args.set(args).unwrap();
	}

	fn decode_args(args: Option<Variant>) -> Result<Self::Args, Error> {
		args
			.map(|args| from_variant(&args).map_err(error::invalid_argument))
			.unwrap_or(Ok(Default::default()))
	}
}

plugin::simple_plugin_subclass! {
	impl ObjectSubclass for LOG_DOMAIN as StaticLink { }
}

plugin::plugin_export!(StaticLink);
