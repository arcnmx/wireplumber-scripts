{ rustPlatform
, nix-gitignore
, wireplumber, pipewire, glib
, stdenv, libclang
, pkg-config
, buildType ? "release"
, lib
}: with lib; let
in rustPlatform.buildRustPackage {
  pname = "wireplumber-scripts-arc";
  version = "0.1.0";

  buildInputs = [ wireplumber pipewire glib ];
  nativeBuildInputs = [ pkg-config ];

  src = nix-gitignore.gitignoreSourcePure [ ./.gitignore ''
    /testing/
    /.github
    /.git
    *.nix
  '' ] ./.;
  cargoSha256 = "09483mbydb2qwdn9acsr4km8lnly9l4v1dkf9v2z64i9145sd5pn";
  #cargoLock = importToml ./Cargo.lock;
  inherit buildType;

  pluginExt = stdenv.hostPlatform.extensions.sharedLibrary;
  wpLibDir = "${placeholder "out"}/lib/wireplumber-${versions.majorMinor wireplumber.version}";
  postInstall = ''
    install -d $wpLibDir
    for pluginName in wpscripts_static_link wpscripts_json_config; do
      mv $out/lib/lib$pluginName$pluginExt $wpLibDir/
    done
  '';

  # bindgen garbage, please clean up your act pipewire-rs :(
  LIBCLANG_PATH = "${libclang.lib}/lib";
  BINDGEN_EXTRA_CLANG_ARGS = [
    "-I${stdenv.cc.cc}/lib/gcc/${stdenv.hostPlatform.config}/${stdenv.cc.cc.version}/include"
    "-I${stdenv.cc.libc.dev}/include"
  ];
}
