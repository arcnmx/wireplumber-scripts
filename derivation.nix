let
  self = import ./. { pkgs = null; system = null; };
in {
  rustPlatform
, wireplumber, pipewire, glib, pkg-config
, stdenv, libclang
, lib
, buildType ? "release"
, cargoLock ? crate.cargoLock
, source ? crate.src
, crate ? self.lib.crate
, scriptNames ? lib.attrNames crate.members
}: with lib; rustPlatform.buildRustPackage {
  pname = crate.name;
  inherit (crate) version;

  buildInputs = [ wireplumber pipewire glib ];
  nativeBuildInputs = [ pkg-config ];

  src = source;
  inherit cargoLock buildType;
  doCheck = buildType != "release";

  pluginNames = mapAttrsToList (_: c: c.package.name) (getAttrs scriptNames crate.members);
  pluginExt = stdenv.hostPlatform.extensions.sharedLibrary;
  wpLibDir = "${placeholder "out"}/lib/wireplumber-${versions.majorMinor wireplumber.version}";
  postInstall = ''
    install -d $wpLibDir
    for pluginName in ''${pluginNames//-/_}; do
      mv $out/lib/lib$pluginName$pluginExt $wpLibDir/
    done
  '';

  # bindgen garbage, please clean up your act pipewire-rs :(
  LIBCLANG_PATH = "${libclang.lib}/lib";
  BINDGEN_EXTRA_CLANG_ARGS = [
    "-I${stdenv.cc.cc}/lib/gcc/${stdenv.hostPlatform.config}/${stdenv.cc.cc.version}/include"
    "-I${stdenv.cc.libc.dev}/include"
  ];

  meta = {
    description = "useful plugins for WirePlumber";
    homepage = "https://github.com/arcnmx/wireplumber-scripts";
    license = licenses.mit;
    maintainers = [ maintainers.arcnmx ];
    inherit (wireplumber.meta) platforms;
  };
}
