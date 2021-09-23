{ pkgs ? import <nixpkgs> { } }: let
  wireplumber-scripts = import ./default.nix { inherit pkgs; };
in wireplumber-scripts.shell
