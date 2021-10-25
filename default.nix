{ pkgs ? import <nixpkgs> { } }: with pkgs; with lib; let
  lua = pkgs.lua5_3; # nixpkgs ships with ancient/incompatible luarocks :<
  buildLuarocksPackage = lua.pkgs.buildLuarocksPackage;
  lua-amalg = buildLuarocksPackage rec {
    pname = "lua-amalg";
    version = "0.8";
    src = fetchFromGitHub {
      owner = "siffiejoe";
      repo = pname;
      rev = "v${version}";
      sha256 = "1a569hrras5wm4gw5hr2i5hz899bwihz1hb31gfnd9z4dsi8wymb";
    };
    rockspecFilename = "amalg-scm-0.rockspec";
  };
  shell = mkShell {
    nativeBuildInputs = [ lua lua-amalg lua.pkgs.luacheck ];
  };
  wireplumber-scripts = callPackage ./derivation.nix (optionalAttrs (! pkgs ? lua-amalg) {
    inherit lua-amalg;
  } // {
    lua5_4 = lua;
    inherit (lua.pkgs) luacheck;
  });
in wireplumber-scripts // {
  inherit lua-amalg wireplumber-scripts shell;
}
