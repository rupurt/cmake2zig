{
  description = "Zig library to convert CMake bulds to the Zig build system";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixpkgs-unstable";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
  }: let
    systems = ["x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"];
    outputs = flake-utils.lib.eachSystem systems (system: let
      pkgs = import nixpkgs {
        inherit system;
        overlays = [
          self.overlay
        ];
      };
    in {
      # packages exported by the flake
      packages = rec {
        cmake2zig = pkgs.zigStdenv.mkDerivation {
          name = "cmake2zig";
          src = self;
        };
        default = cmake2zig;
      };

      # nix fmt
      formatter = pkgs.alejandra;

      # nix develop -c $SHELL
      devShells.default = pkgs.mkShell {
        buildInputs = with pkgs; [
          argc
          cmake
          zls
          zig
        ];

        shellHook = ''
          export IN_NIX_DEVSHELL=1;
        '';
      };
    });
  in
    outputs
    // {
      # Overlay that can be imported so you can access the packages
      # using cmake2zig.overlay
      overlay = final: prev: {
        cmake2zig = outputs.packages.${prev.system};
      };
    };
}
