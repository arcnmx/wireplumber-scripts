{ config, channels, pkgs, env, lib, ... }: with pkgs; with lib; let
  importShell = config: writeText "shell.nix" ''
    import ${builtins.unsafeDiscardStringContext config.shell.drvPath}
  '';
  cargo = config: name: command: ci.command {
    name = "cargo-${name}";
    command = ''
      nix-shell ${importShell config} --run ${escapeShellArg ("cargo " + command)}
    '';
    impure = true;
  };
  todo = writeShellScriptBin "todo" ''
    cd ${toString ./.}
    exec ${gir}/bin/gir -m not_bound
  '';
  wpscripts = callPackage ./derivation.nix {
    inherit (config.rustChannel) rustPlatform;
  };
in {
  config = {
    name = "wireplumber-scripts";
    ci.gh-actions = {
      enable = true;
      emit = true;
    };
    cache.cachix.arc.enable = true;
    channels = {
      nixpkgs = mkIf (env.platform != "impure") "22.05";
      rust = "master";
    };
    environment = {
      test = {
        inherit (config.rustChannel.buildChannel) cargo;
      };
    };
    tasks = {
      build.inputs = [
        (cargo config "test" "test --workspace")
        wpscripts
      ];
    };
    jobs = {
      dev = { config, ... }: {
        ci.gh-actions.emit = mkForce false;
        channels.nixpkgs = config.parentConfig.channels.nixpkgs;
        enableDev = true;
      };
    };
  };

  options = {
    enableDev = mkEnableOption "dev shell generation";
    rustChannel = mkOption {
      type = types.unspecified;
      default = channels.rust.stable; # arc.pkgs.rustPlatforms.nightly.hostChannel
    };
    shell = mkOption {
      type = types.unspecified;
      default = with pkgs; config.rustChannel.mkShell {
        rustTools = optional config.enableDev "rust-analyzer";
        inherit (wpscripts)
          buildInputs nativeBuildInputs
          LIBCLANG_PATH BINDGEN_EXTRA_CLANG_ARGS;
      };
    };
  };
}
