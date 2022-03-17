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
  cargoSha256 = "0hagd9vgdbkclnx9wr35q5g5i1vqb6ysr9jiw017mq5wdxym34jb";
  #cargoLock = importToml ./Cargo.lock;
  inherit buildType;

  pluginExt = stdenv.hostPlatform.extensions.sharedLibrary;
  wpLibDir = "${placeholder "out"}/lib/wireplumber-${versions.majorMinor wireplumber.version}";
  postInstall = ''
    install -d $wpLibDir
    for pluginName in wpscripts_static_link; do
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
