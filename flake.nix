{
  description = "Meeseeks - Look at me! Project templates.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    {
      # nix flake init -t github:viking66/meeseeks#haskell
      templates.haskell = {
        path = ./templates/haskell;
        description = "Haskell project with GHC2024, HLS, fourmolu, hlint, hspec, and Nix flake";
      };

      templates.default = self.templates.haskell;
    }
    //
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };

        init-haskell = pkgs.writeShellScriptBin "init-haskell"
          (builtins.replaceStrings
            [ "@templateDir@" ]
            [ "${./templates/haskell}" ]
            (builtins.readFile ./scripts/init-haskell.sh));
      in {
        # nix run github:viking66/meeseeks#haskell -- myproject
        apps.haskell = {
          type = "app";
          program = "${init-haskell}/bin/init-haskell";
        };

        apps.default = self.apps.${system}.haskell;
      }
    );
}
