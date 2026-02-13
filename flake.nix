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

      # nix flake init -t github:viking66/meeseeks#fullstack
      templates.fullstack = {
        path = ./templates/fullstack;
        description = "Haskell backend + PureScript frontend with Servant, Halogen, and Nix flake";
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

        init-fullstack = pkgs.writeShellApplication {
          name = "init-fullstack";
          runtimeInputs = [ pkgs.purescript pkgs.spago pkgs.nodejs_24 ];
          text = builtins.replaceStrings
            [ "@templateDir@" ]
            [ "${./templates/fullstack}" ]
            (builtins.readFile ./scripts/init-fullstack.sh);
        };
      in {
        # nix run github:viking66/meeseeks#haskell -- myproject
        apps.haskell = {
          type = "app";
          program = "${init-haskell}/bin/init-haskell";
        };

        # nix run github:viking66/meeseeks#fullstack -- myproject
        apps.fullstack = {
          type = "app";
          program = "${init-fullstack}/bin/init-fullstack";
        };

        apps.default = self.apps.${system}.haskell;
      }
    );
}
