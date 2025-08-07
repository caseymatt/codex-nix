{
  description = "Nix package for OpenAI Codex CLI with daily auto-update from GitHub releases";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    let
      overlay = final: prev: {
        codex = final.callPackage ./package.nix { };
      };
    in
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ overlay ];
        };
      in
      {
        packages = {
          default = pkgs.codex;
          codex = pkgs.codex;
        };

        apps = {
          default = {
            type = "app";
            program = "${pkgs.codex}/bin/codex";
          };
          codex = {
            type = "app";
            program = "${pkgs.codex}/bin/codex";
          };
        };

        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            nixpkgs-fmt
            jq
            curl
            git
            cachix
            gh
          ];
        };
      }) // {
        overlays.default = overlay;
      };
}
