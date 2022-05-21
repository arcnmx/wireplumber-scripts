{
  description = "useful plugins for WirePlumber";
  inputs = {
    flakelib.url = "github:flakelib/fl";
    nixpkgs.url = "github:NixOS/nixpkgs";
  };
  outputs = { flakelib, ... }@inputs: flakelib {
    inherit inputs;
    config = {
      name = "wireplumber-scripts-arc";
    };
    packages.wireplumber-scripts-arc = {
      __functor = _: import ./derivation.nix;
      fl'config.args = {
        pkg-config.offset = "build";
        _arg'wireplumber-scripts-arc.fallback = inputs.self.outPath;
      };
    };
    defaultPackage = "wireplumber-scripts-arc";
  };
}
