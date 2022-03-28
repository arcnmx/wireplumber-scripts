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
  cargoSha256 = "1hb5y4wk9is6wiflqn1jljbrz11xpb2j9mn9afl1ajhdfiv35jj7";
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
