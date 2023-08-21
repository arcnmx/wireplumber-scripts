{ config, pkgs, lib, ... }: with pkgs; with lib; let
  inherit (import ./. { }) checks;
in {
  config = {
    name = "wireplumber-scripts";
    ci.version = "v0.6";
    ci.gh-actions.enable = true;
    cache.cachix = {
      ci.signingKey = "";
      arc.enable = true;
    };
    channels = {
      nixpkgs = "23.05";
    };
    tasks = {
      build.inputs = singleton checks.wpscripts;
      fmt.inputs = singleton checks.rustfmt;
    };
  };
}
