{ stdenvNoCC, nix-gitignore, lua-amalg, luacheck ? lua5_4.pkgs.luacheck, lua5_4 ? lua5_3, lua5_3 ? lua, lua }: stdenvNoCC.mkDerivation {
  pname = "wireplumber-scripts";
  version = "git";

  src = nix-gitignore.gitignoreSourcePure [./.gitignore ''
    *.nix
    .git
  ''] ./.;

  nativeBuildInputs = [ lua-amalg ];
  checkInputs = [ lua5_4 luacheck ];

  installFlags = [ "INSTALLDIR=${placeholder "out"}" ];
  doCheck = true;
}
