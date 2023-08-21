{
  description = "useful plugins for WirePlumber";
  inputs = {
    flakelib.url = "github:flakelib/fl";
    nixpkgs = { };
    rust = {
      url = "github:arcnmx/nixexprs-rust";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs = { self, flakelib, nixpkgs, rust, ... }@inputs: let
    nixlib = nixpkgs.lib;
  in flakelib {
    inherit inputs;
    systems = [ "x86_64-linux" "aarch64-linux" ];
    devShells = {
      plain = {
        mkShell, writeShellScriptBin, hostPlatform
      , udev
      , wireplumber-scripts-arc
      , enableRust ? true, cargo
      , rustTools ? [ ]
      }: mkShell {
        inherit rustTools;
        nativeBuildInputs = wireplumber-scripts-arc.nativeBuildInputs
          ++ nixlib.optional enableRust cargo
          ++ [
            (writeShellScriptBin "generate" ''nix run .#generate ''${FLAKE_OPTS-} "$@"'')
          ];
        inherit (wireplumber-scripts-arc) buildInputs LIBCLANG_PATH BINDGEN_EXTRA_CLANG_ARGS;
        RUST_LOG = "wireplumber=debug";
      };
      stable = { rust'stable, outputs'devShells'plain }: outputs'devShells'plain.override {
        inherit (rust'stable) mkShell;
        enableRust = false;
      };
      dev = { rust'unstable, outputs'devShells'plain }: outputs'devShells'plain.override {
        inherit (rust'unstable) mkShell;
        enableRust = false;
        rustTools = [ "rust-analyzer" ];
      };
      default = { outputs'devShells }: outputs'devShells.plain;
    };
    packages = {
      wireplumber-scripts-arc = {
        __functor = _: import ./derivation.nix;
        fl'config.args = {
          crate.fallback = self.lib.crate;
        };
      };
      default = { wireplumber-scripts-arc }: wireplumber-scripts-arc;
    };
    legacyPackages = {
      source = { rust'builders }: rust'builders.wrapSource self.lib.crate.src;

      generate = { rust'builders, outputHashes }: rust'builders.generateFiles {
        paths = {
          "lock.nix" = outputHashes;
        };
      };
      outputHashes = { rust'builders }: rust'builders.cargoOutputHashes {
        inherit (self.lib) crate;
      };
    };
    checks = {
      wpscripts = { wireplumber-scripts-arc }: wireplumber-scripts-arc.override {
        buildType = "debug";
      };
      rustfmt = { rust'builders, wireplumber-scripts-arc }: rust'builders.check-rustfmt-unstable {
        inherit (wireplumber-scripts-arc) src;
        config = ./.rustfmt.toml;
        cargoFmtArgs = with nixlib; concatLists (
          mapAttrsToList (_: c: [ "-p" c.package.name ]) self.lib.crate.members
        );
      };
    };
    lib = with nixlib; {
      crate = rust.lib.importCargo {
        path = ./Cargo.toml;
        inherit (import ./lock.nix) outputHashes;
        name = "wireplumber-scripts-arc";
        version = "0.1.0";
      };
      inherit (self.lib.crate) version;
    };
    config = rec {
      name = "wireplumber-scripts-arc";
    };
  };
}
