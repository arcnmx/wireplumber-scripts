{ pkgs, lib, ... }: with lib; let
  repo = import ./. { inherit pkgs; };
in {
  name = "wireplumber-scripts";
  ci.gh-actions.enable = true;
  cache.cachix.arc.publicKey = "arc.cachix.org-1:DZmhclLkB6UO0rc0rBzNpwFbbaeLfyn+fYccuAy7YVY=";
  channels.nixpkgs = "unstable";

  tasks.wireplumber-scripts = {
    name = "build scripts";
    inputs = singleton repo.wireplumber-scripts;
  };
}
