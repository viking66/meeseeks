{
  description = "rambutan";

  inputs = {
    nixpkgs.url     = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ self.overlays.default ];
        };
      in {
        packages = {
          default = pkgs.myHsPkgs.rambutan;
          rambutan = pkgs.myHsPkgs.rambutan;
        };

        devShells.default = pkgs.myHsPkgs.shellFor {
          packages = hpkgs: [
            hpkgs.rambutan
          ];

          nativeBuildInputs = [
            # Haskell
            pkgs.myHsPkgs.haskell-language-server
            pkgs.myHsPkgs.cabal-install
            pkgs.myHsPkgs.fourmolu
            pkgs.myHsPkgs.hlint
            pkgs.ghciwatch

            # PureScript
            pkgs.purescript
            pkgs.spago
            pkgs.esbuild
            pkgs.nodePackages.concurrently

            # Shared
            pkgs.zlib
            pkgs.zlib.dev
            pkgs.just
            pkgs.nodejs_24
            pkgs.gh
          ];

          withHoogle = true;
        };
      }
    ) // {
      overlays.default = self: super: {
        myHsPkgs = self.haskell.packages.ghc912.override (old: {
          overrides =
            let
              hlib = self.haskell.lib.compose;
            in
            self.lib.composeManyExtensions [
              (hlib.packageSourceOverrides {
                rambutan = ./backend;
              })
            ];
        });
      };
    };
}
