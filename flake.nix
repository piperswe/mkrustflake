{
  description = "Helper functions for generating Rust flakes";

  inputs = {
    nixpkgs.url = github:nixos/nixpkgs;
    flake-utils.url = github:numtide/flake-utils;
    rust-overlay.url = github:oxalica/rust-overlay;
  };

  outputs = { self, nixpkgs, flake-utils, rust-overlay }:
    with nixpkgs.lib;
    {
      lib = {
        tiers = {
          tier1_with_host_tools = [
            "aarch64-linux"
            "i686-windows"
            "i686-linux"
            "x86_64-darwin"
            "x86_64-windows"
            "x86_64-linux"
          ];
          tier1 = [ ];
          tier2_with_host_tools = [
            "aarch64-darwin"
            "aarch64-windows"
            "aarch64-linux"
            "armv6l-linux"
            "armv7l-linux"
            "mips-linux"
            "mips64-linux"
            "mips64el-linux"
            "mipsel-linux"
            "powerpc-linux"
            "powerpc64-linux"
            "powerpc64le-linux"
            "riscv64-linux"
            "s390-linux"
            "x86_64-freebsd"
            "x86_64-netbsd"
          ];
          tier2 = [
            "armv5tel-linux"
            "i686-freebsd"
            "wasm32-wasi"
            "x86_64-solaris"
            "x86_64-redox"
          ];
          tier3 = [
            "aarch64-netbsd"
            "armv7l-netbsd"
            "i686-netbsd"
          ];
        };
        systems = {
          tier1_with_host_tools = self.lib.tiers.tier1_with_host_tools;
          tier1 = self.lib.systems.tier1_with_host_tools ++ self.lib.tiers.tier1;
          tier2_with_host_tools = self.lib.systems.tier1_with_host_tools ++ self.lib.tiers.tier2_with_host_tools;
          tier2 = self.lib.systems.tier2_with_host_tools ++ self.lib.tiers.tier1 ++ self.lib.tiers.tier2;
          tier3 = self.lib.systems.tier2 ++ self.lib.tiers.tier3;
        };
        mkRustFlake =
          { name
          , version
          , src
          , cargoLock
          , nativeSystems ? self.lib.systems.tier2_with_host_tools
          , crossSystems ? self.lib.systems.tier2
          , rust ? pkgs:
              if elem pkgs.stdenv.system flake-utils.lib.defaultSystems
              then
                pkgs.rust-bin.stable.latest.default.override
                  {
                    extensions = [ "rust-src" "clippy" ];
                  }
              else pkgs.rust-bin.stable.latest.minimal
          }:
          let
            systemOutputs =
              (pkgs:
                let
                  r = rust pkgs;
                in
                rec {
                  packages.${name} = pkgs.rustPlatform.buildRustPackage {
                    pname = name;
                    version = version;
                    nativeBuildInputs = [
                      r
                    ];

                    inherit src;
                    cargoLock.lockFile = cargoLock;

                    meta.platforms = nativeSystems ++ crossSystems;
                  };
                  defaultPackage = packages.${name};

                  devShell = defaultPackage;

                  hydraJobs = {
                    inherit packages;
                  };
                });
          in
          (flake-utils.lib.eachSystem nativeSystems (system:
          let
            pkgs = import nixpkgs {
              inherit system;
              overlays = [
                rust-overlay.overlay
              ];
            };
          in
          systemOutputs pkgs)) // rec {
            cross = genAttrs nativeSystems
              (system:
                genAttrs crossSystems
                  (crossSystem:
                    let
                      pkgs = import nixpkgs {
                        inherit system crossSystem;
                        overlays = [
                          rust-overlay.overlay
                        ];
                      };
                    in
                    systemOutputs pkgs
                  )
              );
            hydraJobs.cross = genAttrs nativeSystems (system:
              genAttrs crossSystems (crossSystem: cross.${system}.${crossSystem}.hydraJobs)
            );
          };
      };
    };
}
