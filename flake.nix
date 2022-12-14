{
  description = "Nix Flake";

  inputs = {
    nixpkgs.url =
      "github:nix-ocaml/nix-overlays/029bcd66be430e4f1d0a73b771780564b4e95aa4";
    flake-utils.url = "github:numtide/flake-utils";
    nix-filter.url = "github:numtide/nix-filter";

    ocaml-overlays.url =
      "github:nix-ocaml/nix-overlays/029bcd66be430e4f1d0a73b771780564b4e95aa4";
    ocaml-overlays.inputs = {
      nixpkgs.follows = "nixpkgs";
      flake-utils.follows = "flake-utils";
    };
  };

  outputs = { self, nixpkgs, ocaml-overlays, nix-filter, flake-utils }:
    let supportedSystems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" ];
    in with flake-utils.lib;
    eachSystem supportedSystems (system:
      let
        pkgs = (ocaml-overlays.makePkgs {
          inherit system;
          extraOverlays = [ (import ./nix/overlay.nix) ];
        }).extend (self: super: {
          ocamlPackages = super.ocaml-ng.ocamlPackages_5_0.overrideScope'
            (oself: osuper: {
              ocaml = osuper.ocaml.overrideAttrs (oa: {
                src = self.fetchFromGitHub {
                  owner = "kayceesrk";
                  repo = "ocaml";
                  rev = "64c443d7a3d52fefffd1a5227c7c58b6dbacae00";
                  sha256 =
                    "sha256-/0x7NlZVIByXSF21XuKo43ER7Ppo5iXDtX4Ic/V4GTI=";
                };
                postPatch = ''
                  substituteInPlace configure --replace "OCAML_VERSION_MINOR=1" "OCAML_VERSION_MINOR=0"
                  substituteInPlace configure --replace "OCAML_VERSION_MINOR 1" "OCAML_VERSION_MINOR 0"
                  substituteInPlace configure --replace 'OCAML_VERSION_STRING \"5.1.0+dev1' 'OCAML_VERSION_STRING \"5.0.0+dev1'
                '';
              });
            });
        });

        pkgs_static = pkgs.pkgsCross.musl64;

        example_static = pkgs.callPackage ./nix {
          pkgs = pkgs_static;
          doCheck = true;
          static = true;
          inherit nix-filter;
        };

        example = pkgs.callPackage ./nix {
          doCheck = true;
          inherit nix-filter;
        };
      in {
        devShell = import ./nix/shell.nix { inherit pkgs example; };
        packages = {
          inherit example example_static;

          ocaml = pkgs.ocamlPackages.ocaml;
          docker = import ./nix/docker.nix {
            inherit pkgs;
            example = example_static;
          };
        };

        formatter = pkgs.callPackage ./nix/formatter.nix { };
      }) // {
        hydraJobs = {
          x86_64-linux = self.packages.x86_64-linux;
          aarch64-darwin = {
            # darwin doesn't support static builds and docker
            inherit (self.packages.aarch64-darwin) example;
          };
        };
      };
}
